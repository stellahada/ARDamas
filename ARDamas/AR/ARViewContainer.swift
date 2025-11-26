import SwiftUI
import RealityKit
import ARKit
import Combine

struct ARViewContainer: UIViewRepresentable {
    
    var gameModel: CheckersModel
    var mpcService: MPCService
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        // Gestos
        arView.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap)))
        arView.addGestureRecognizer(UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch)))
        arView.addGestureRecognizer(UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan)))
        
        context.coordinator.arView = arView
        context.coordinator.gameModel = gameModel
        context.coordinator.mpcService = mpcService
        context.coordinator.setupBindings()
        
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.onShareMapRequest), name: NSNotification.Name("ShareMap"), object: nil)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.onLocalRestart), name: NSNotification.Name("LocalRestart"), object: nil)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        
        weak var gameModel: CheckersModel?
        weak var mpcService: MPCService?
        weak var arView: ARView?
        
        var boardIsPlaced = false
        var boardEntity: ModelEntity?
        var selection: (position: Position, validMoves: [Position])? = nil
        
        // --- CORREÇÃO AQUI: Usamos RealityKit.Material explicitamente ---
        var savedMaterials: [ModelEntity: [RealityKit.Material]] = [:]
        
        var cancellables = Set<AnyCancellable>()
        var lastScale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
        
        func setupBindings() {
            guard let mpcService = mpcService else { return }
            mpcService.messageReceived
                .sink { [weak self] message in
                    self?.handleNetworkMessage(message)
                }
                .store(in: &cancellables)
        }
        
        @objc func onShareMapRequest() {
            guard let arView = arView else { return }
            arView.session.getCurrentWorldMap { worldMap, error in
                guard let map = worldMap else { return }
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                    self.mpcService?.sendWorldMap(data: data)
                } catch { print("AR: Erro mapa: \(error)") }
            }
        }
        
        @objc func onLocalRestart() {
            resetBoardVisuals()
        }
        
        // --- GESTOS ---
        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let board = boardEntity else { return }
            if sender.state == .began { lastScale = board.scale }
            else if sender.state == .changed {
                let newScale = Float(sender.scale)
                board.scale = lastScale * max(0.1, min(5.0, newScale))
            }
        }
        
        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            guard let arView = arView, let board = boardEntity, boardIsPlaced else { return }
            let location = sender.location(in: arView)
            if sender.state == .changed {
                let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
                if let firstResult = results.first {
                    let worldTransform = firstResult.worldTransform
                    let worldPosition = SIMD3<Float>(worldTransform.columns.3.x, worldTransform.columns.3.y, worldTransform.columns.3.z)
                    board.setPosition(worldPosition, relativeTo: nil)
                }
            }
        }

        func handleNetworkMessage(_ message: GameMessage) {
            switch message.type {
            case .gameMove:
                if let move = try? JSONDecoder().decode(GameMove.self, from: message.payload) {
                    if let result = gameModel?.movePiece(from: move.from, to: move.to) {
                        animateMove(from: move.from, to: move.to, result: result)
                    }
                }
            case .worldMap:
                do {
                    if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: message.payload) {
                        let config = ARWorldTrackingConfiguration()
                        config.initialWorldMap = worldMap
                        config.planeDetection = [.horizontal]
                        arView?.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                        self.boardIsPlaced = true
                    }
                } catch { print("MPC: Erro mapa: \(error)") }
            case .gameRestart:
                gameModel?.resetGame()
                resetBoardVisuals()
            }
        }
        
        func orientBoard() {
            guard let board = boardEntity, let model = gameModel else { return }
            if model.localPlayerColor == .black {
                board.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            } else {
                board.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            }
        }
        
        func resetBoardVisuals() {
            boardEntity?.removeFromParent()
            boardEntity = nil
            selection = nil
            removeHighlights()
            if let anchor = arView?.scene.anchors.first(where: { $0.name == "CheckersBoardAnchor" }) {
                let newBoard = GameAssets.createCheckersBoard()
                self.boardEntity = newBoard
                anchor.addChild(newBoard)
                orientBoard()
            } else {
                boardIsPlaced = false
            }
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView, let gameModel = gameModel else { return }
            let tapLocation = sender.location(in: arView)
            
            if !boardIsPlaced {
                placeBoard(at: tapLocation, in: arView)
                return
            }
            if gameModel.winner != nil { return }
            
            if let entity = arView.entity(at: tapLocation) {
                if let boardComponent = entity.components[BoardPositionComponent.self] {
                    let tappedPosition = boardComponent.position
                    
                    if let modelEntity = entity as? ModelEntity, modelEntity.model?.mesh === GameAssets.pieceMesh {
                        let piece = gameModel.board[tappedPosition.row][tappedPosition.col]
                        let isMyTurn = (piece?.player == gameModel.currentPlayer)
                        let isMyPiece = (piece?.player == gameModel.localPlayerColor)
                        
                        if let requiredPos = gameModel.mustCaptureFrom {
                            if tappedPosition != requiredPos { return }
                        }
                        
                        if isMyTurn && isMyPiece {
                            removeHighlights()
                            let validMoves = gameModel.getValidMoves(from: tappedPosition)
                            self.selection = (position: tappedPosition, validMoves: validMoves)
                            highlightSelection(piece: modelEntity, moves: validMoves)
                        }
                        
                    } 
                    else if let selection = self.selection {
                        if selection.validMoves.contains(tappedPosition) {
                            let fromPos = selection.position
                            let toPos = tappedPosition
                            
                            removeHighlights()
                            
                            let result = gameModel.movePiece(from: fromPos, to: toPos)
                            
                            self.selection = nil
                            
                            animateMove(from: fromPos, to: toPos, result: result)
                            mpcService?.sendMove(from: fromPos, to: toPos)
                            
                            if !result.turnChanged {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                    self?.autoSelectForCombo(at: toPos)
                                }
                            }
                            
                        } else {
                            if gameModel.mustCaptureFrom == nil {
                                self.selection = nil
                                removeHighlights()
                            }
                        }
                    } else {
                        if gameModel.mustCaptureFrom == nil {
                            self.selection = nil
                            removeHighlights()
                        }
                    }
                }
            }
        }
        
        func autoSelectForCombo(at position: Position) {
            guard let gameModel = gameModel else { return }
            guard let pieceEntity = findEntity(at: position, for: GameAssets.pieceMesh) else { return }
            
            let validMoves = gameModel.getValidMoves(from: position)
            
            if !validMoves.isEmpty {
                self.selection = (position: position, validMoves: validMoves)
                highlightSelection(piece: pieceEntity, moves: validMoves)
            }
        }
        
        func animateMove(from: Position, to: Position, result: MoveResult) {
                    guard let pieceEntity = findEntity(at: from, for: GameAssets.pieceMesh),
                          let targetSquareEntity = findEntity(at: to, for: GameAssets.squareMesh)
                    else { return }
                    
                    // Toca som e vibração
                    if result.capturedPosition != nil {
                        AudioManager.shared.playSound("capture") // Certifique-se de ter o arquivo
                        AudioManager.shared.hapticSuccess()
                    } else {
                        AudioManager.shared.playSound("move") // Certifique-se de ter o arquivo
                        AudioManager.shared.hapticTap()
                    }
                    
                    // Cálculos de Posição
                    let startPos = pieceEntity.position(relativeTo: boardEntity)
                    let targetPos3D = targetSquareEntity.position
                    let endY = (0.01 / 2.0) + (GameAssets.pieceHeight / 2.0)
                    let endPos = SIMD3<Float>(x: targetPos3D.x, y: endY, z: targetPos3D.z)
                    
                    // Ponto médio (Pico do pulo)
                    let midX = (startPos.x + endPos.x) / 2
                    let midZ = (startPos.z + endPos.z) / 2
                    let jumpHeight: Float = 0.07 // Altura do pulo (15cm)
                    let midPos = SIMD3<Float>(x: midX, y: jumpHeight, z: midZ)
                    
                    // Criar animação de Pulo (Subir -> Descer)
                    // RealityKit nativo não tem curva de bezier fácil, então fazemos sequencial:
                    // Movemos para o meio (alto) e depois para o fim (baixo)
                    
                    let duration = 0.5
                    
                    // 1. Configura a Transformação do Pico
                    var midTransform = pieceEntity.transform
                    midTransform.translation = midPos
                    
                    // 2. Configura a Transformação Final
                    var endTransform = pieceEntity.transform
                    endTransform.translation = endPos
                    
                    // Mover para cima (metade do tempo)
                    pieceEntity.move(to: midTransform, relativeTo: boardEntity, duration: duration / 2, timingFunction: .easeOut)
                    
                    // Agendar a descida
                    DispatchQueue.main.asyncAfter(deadline: .now() + (duration / 2)) {
                        pieceEntity.move(to: endTransform, relativeTo: self.boardEntity, duration: duration / 2, timingFunction: .easeIn)
                    }
                    
                    // Atualiza componente lógico
                    pieceEntity.components[BoardPositionComponent.self] = BoardPositionComponent(position: to)
                    
                    // Efeitos de Captura e Promoção
                    if let capturedPos = result.capturedPosition {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Delay para sincronizar com a aterrissagem
                            self.performVisualCapture(at: capturedPos)
                        }
                    }
                    if result.isPromotion {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            AudioManager.shared.playSound("king")
                            self.performVisualPromotion(on: pieceEntity)
                        }
                    }
                }        
        func performVisualCapture(at position: Position) {
            if let capturedEntity = findEntity(at: position, for: GameAssets.pieceMesh) {
                var shrinkTransform = capturedEntity.transform
                shrinkTransform.scale = SIMD3<Float>(0.1, 0.1, 0.1)
                capturedEntity.move(to: shrinkTransform, relativeTo: capturedEntity.parent, duration: 0.2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { capturedEntity.removeFromParent() }
            }
        }
        
        func performVisualPromotion(on pieceEntity: ModelEntity) {
            let crown = ModelEntity(mesh: GameAssets.pieceMesh, materials: pieceEntity.model?.materials ?? [])
            crown.position = SIMD3<Float>(0, GameAssets.pieceHeight, 0)
            pieceEntity.addChild(crown)
        }
        
        func placeBoard(at tapLocation: CGPoint, in arView: ARView) {
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = results.first {
                let anchor = AnchorEntity(world: firstResult.worldTransform)
                anchor.name = "CheckersBoardAnchor"
                let boardEntity = GameAssets.createCheckersBoard()
                self.boardEntity = boardEntity
                anchor.addChild(boardEntity)
                arView.scene.addAnchor(anchor)
                orientBoard()
                self.boardIsPlaced = true
            }
        }
        
        func findEntity(at position: Position, for mesh: MeshResource) -> ModelEntity? {
            if self.boardEntity == nil {
                 if let anchor = arView?.scene.anchors.first(where: { $0.name == "CheckersBoardAnchor" }),
                    let board = anchor.children.first as? ModelEntity {
                     self.boardEntity = board
                 }
            }
            guard let boardEntity = self.boardEntity else { return nil }
            for entity in boardEntity.children {
                guard let modelEntity = entity as? ModelEntity,
                      modelEntity.model?.mesh === mesh
                else { continue }
                if let component = entity.components[BoardPositionComponent.self],
                   component.position == position {
                    return modelEntity
                }
            }
            return nil
        }
        
        func highlightSelection(piece: ModelEntity, moves: [Position]) {
            // Salva material original (RealityKit.Material)
            if let currentMats = piece.model?.materials {
                savedMaterials[piece] = currentMats
            }
            piece.model?.materials = [GameAssets.highlightPieceMat]
            
            for pos in moves {
                if let squareEntity = findEntity(at: pos, for: GameAssets.squareMesh) {
                    if let currentMats = squareEntity.model?.materials {
                        savedMaterials[squareEntity] = currentMats
                    }
                    squareEntity.model?.materials = [GameAssets.highlightSquareMat]
                }
            }
        }
        
        func removeHighlights() {
            for (entity, mats) in savedMaterials {
                entity.model?.materials = mats
            }
            savedMaterials.removeAll()
        }
    }
}
