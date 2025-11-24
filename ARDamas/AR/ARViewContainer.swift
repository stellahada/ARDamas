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
        
        arView.addGestureRecognizer(UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        ))
        
        context.coordinator.arView = arView
        context.coordinator.gameModel = gameModel
        context.coordinator.mpcService = mpcService
        context.coordinator.setupBindings()
        
        // Ouvintes de Notificações da UI
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.onShareMapRequest), name: NSNotification.Name("ShareMap"), object: nil)
        
        // --- CORREÇÃO: Ouvir o pedido de reinício local ---
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
        var highlightedEntities: [ModelEntity] = []
        var cancellables = Set<AnyCancellable>()
        
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
        
        // --- CORREÇÃO: Ação chamada quando você clica em "Jogar Novamente" ---
        @objc func onLocalRestart() {
            print("AR: Reiniciando tabuleiro localmente...")
            resetBoardVisuals()
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
                print("MPC: Pedido de reinício recebido.")
                gameModel?.resetGame()
                resetBoardVisuals()
            }
        }
        
        func resetBoardVisuals() {
            // Remove o tabuleiro atual
            boardEntity?.removeFromParent()
            boardEntity = nil
            selection = nil
            removeHighlights()
            
            // Recria o tabuleiro no mesmo lugar (se a âncora ainda existir)
            if let anchor = arView?.scene.anchors.first(where: { $0.name == "CheckersBoardAnchor" }) {
                let newBoard = GameAssets.createCheckersBoard()
                self.boardEntity = newBoard
                anchor.addChild(newBoard)
            } else {
                // Se não achar âncora, força o usuário a colocar de novo
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
            
            // Impede movimentos se o jogo acabou
            if gameModel.winner != nil { return }
            
            if let entity = arView.entity(at: tapLocation) {
                if let boardComponent = entity.components[BoardPositionComponent.self] {
                    let tappedPosition = boardComponent.position
                    
                    if let modelEntity = entity as? ModelEntity, modelEntity.model?.mesh === GameAssets.pieceMesh {
                        let piece = gameModel.board[tappedPosition.row][tappedPosition.col]
                        if piece?.player == gameModel.currentPlayer {
                            removeHighlights()
                            let validMoves = gameModel.getValidMoves(from: tappedPosition)
                            self.selection = (position: tappedPosition, validMoves: validMoves)
                            highlightSelection(piece: modelEntity, moves: validMoves)
                        }
                    } else if let selection = self.selection {
                        if selection.validMoves.contains(tappedPosition) {
                            let fromPos = selection.position
                            let toPos = tappedPosition
                            let result = gameModel.movePiece(from: fromPos, to: toPos)
                            self.selection = nil
                            animateMove(from: fromPos, to: toPos, result: result)
                            mpcService?.sendMove(from: fromPos, to: toPos)
                            removeHighlights()
                        } else {
                            self.selection = nil
                            removeHighlights()
                        }
                    } else {
                        self.selection = nil
                        removeHighlights()
                    }
                }
            }
        }
        
        func animateMove(from: Position, to: Position, result: MoveResult) {
            guard let pieceEntity = findEntity(at: from, for: GameAssets.pieceMesh),
                  let targetSquareEntity = findEntity(at: to, for: GameAssets.squareMesh)
            else { return }
            
            let targetPos3D = targetSquareEntity.position
            let yPos = (0.01 / 2.0) + (GameAssets.pieceHeight / 2.0)
            var newTransform = targetSquareEntity.transform
            newTransform.translation = SIMD3<Float>(x: targetPos3D.x, y: yPos, z: targetPos3D.z)
            
            pieceEntity.move(to: newTransform, relativeTo: boardEntity, duration: 0.4, timingFunction: .easeInOut)
            pieceEntity.components[BoardPositionComponent.self] = BoardPositionComponent(position: to)
            
            if let capturedPos = result.capturedPosition {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.performVisualCapture(at: capturedPos)
                }
            }
            if result.isPromotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
            piece.model?.materials = [GameAssets.highlightPieceMat]
            highlightedEntities.append(piece)
            for pos in moves {
                if let squareEntity = findEntity(at: pos, for: GameAssets.squareMesh) {
                    squareEntity.model?.materials = [GameAssets.highlightSquareMat]
                    highlightedEntities.append(squareEntity)
                }
            }
        }
        
        func removeHighlights() {
            guard let gameModel = gameModel else { return }
            for entity in highlightedEntities {
                guard let component = entity.components[BoardPositionComponent.self] else { continue }
                let pos = component.position
                if entity.model?.mesh === GameAssets.pieceMesh {
                    if let pieceType = gameModel.board[pos.row][pos.col] {
                        let originalMat = (pieceType.player == .red) ? GameAssets.redPieceMat : GameAssets.blackPieceMat
                        entity.model?.materials = [originalMat]
                    }
                } else if entity.model?.mesh === GameAssets.squareMesh {
                    let isBlackSquare = (pos.row + pos.col) % 2 == 1
                    let originalMat = isBlackSquare ? GameAssets.blackMat : GameAssets.whiteMat
                    entity.model?.materials = [originalMat]
                }
            }
            highlightedEntities.removeAll()
        }
        
        func forceReset() {
             resetBoardVisuals()
        }
    }
}
