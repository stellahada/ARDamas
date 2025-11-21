import SwiftUI
import RealityKit
import ARKit
import Combine // Importante para ouvir eventos de rede

struct ARViewContainer: UIViewRepresentable {
    
    var gameModel: CheckersModel
    var mpcService: MPCService // Recebe o serviço de multiplayer
    
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
        context.coordinator.mpcService = mpcService // Passa o serviço
        
        // Inicia a escuta de mensagens da rede
        context.coordinator.setupBindings()
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        
        weak var gameModel: CheckersModel?
        weak var mpcService: MPCService? // Referência ao serviço
        weak var arView: ARView?
        
        var boardIsPlaced = false
        var boardEntity: ModelEntity?
        var selection: (position: Position, validMoves: [Position])? = nil
        var highlightedEntities: [ModelEntity] = []
        
        // Para gerenciar a assinatura do Combine
        var cancellables = Set<AnyCancellable>()
        
        // --- FUNÇÃO NOVA: Configurar a Escuta de Rede ---
        func setupBindings() {
            guard let mpcService = mpcService else { return }
            
            // Ouve o canal 'messageReceived'
            mpcService.messageReceived
                .sink { [weak self] message in
                    self?.handleNetworkMessage(message)
                }
                .store(in: &cancellables)
        }
        
        // Lida com mensagens recebidas
        func handleNetworkMessage(_ message: GameMessage) {
            switch message.type {
            case .gameMove:
                // Decodifica o movimento
                if let move = try? JSONDecoder().decode(GameMove.self, from: message.payload) {
                    print("MPC: Movimento recebido do oponente: \(move.from) -> \(move.to)")
                    
                    // 1. Atualiza a Lógica Local
                    // (O modelo já sabe de quem é o turno, então só executa)
                    gameModel?.movePiece(from: move.from, to: move.to)
                    
                    // 2. Executa a Animação Visual
                    animateMove(from: move.from, to: move.to)
                    
                    print("MPC: Tabuleiro sincronizado. Turno atual: \(gameModel?.currentPlayer ?? .red)")
                }
            }
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView, let gameModel = gameModel else { return }
            let tapLocation = sender.location(in: arView)
            
            if !boardIsPlaced {
                placeBoard(at: tapLocation, in: arView)
                return
            }
            
            if let entity = arView.entity(at: tapLocation) {
                if let boardComponent = entity.components[BoardPositionComponent.self] {
                    let tappedPosition = boardComponent.position
                    
                    // SELECIONAR PEÇA
                    if let modelEntity = entity as? ModelEntity, modelEntity.model?.mesh === GameAssets.pieceMesh {
                        let piece = gameModel.board[tappedPosition.row][tappedPosition.col]
                        
                        if piece?.player == gameModel.currentPlayer {
                            removeHighlights()
                            let validMoves = gameModel.getValidMoves(from: tappedPosition)
                            self.selection = (position: tappedPosition, validMoves: validMoves)
                            highlightSelection(piece: modelEntity, moves: validMoves)
                        }
                        
                    // MOVER PEÇA
                    } else if let selection = self.selection {
                        let fromPosition = selection.position
                        
                        if selection.validMoves.contains(tappedPosition) {
                            let toPosition = tappedPosition
                            
                            // 1. Mover Localmente
                            gameModel.movePiece(from: fromPosition, to: toPosition)
                            self.selection = nil
                            
                            // 2. Animar Localmente
                            animateMove(from: fromPosition, to: toPosition)
                            
                            // 3. ENVIAR PARA A REDE!
                            mpcService?.sendMove(from: fromPosition, to: toPosition)
                            
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
        
        // --- FUNÇÃO REFATORADA: Animação ---
        // Extraímos isto para ser usado tanto pelo Tap quanto pela Rede
        func animateMove(from: Position, to: Position) {
            guard let pieceEntity = findEntity(at: from, for: GameAssets.pieceMesh),
                  let targetSquareEntity = findEntity(at: to, for: GameAssets.squareMesh)
            else { return }
            
            let targetPos3D = targetSquareEntity.position
            let yPos = (0.01 / 2.0) + (GameAssets.pieceHeight / 2.0)
            
            var newTransform = targetSquareEntity.transform
            newTransform.translation = SIMD3<Float>(x: targetPos3D.x, y: yPos, z: targetPos3D.z)
            
            pieceEntity.move(to: newTransform, relativeTo: boardEntity, duration: 0.4, timingFunction: .easeInOut)
            
            // Atualiza a posição lógica da entidade 3D
            pieceEntity.components[BoardPositionComponent.self] = BoardPositionComponent(position: to)
        }
        
        // --- FUNÇÕES AUXILIARES (placeBoard, findEntity, highlight...) ---
        // (Mantenha as funções auxiliares exatamente como estavam no código anterior)
        
        func placeBoard(at tapLocation: CGPoint, in arView: ARView) {
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
            if let firstResult = results.first {
                let anchor = AnchorEntity(world: firstResult.worldTransform)
                let boardEntity = GameAssets.createCheckersBoard()
                self.boardEntity = boardEntity
                anchor.addChild(boardEntity)
                arView.scene.addAnchor(anchor)
                self.boardIsPlaced = true
            }
        }
        
        func findEntity(at position: Position, for mesh: MeshResource) -> ModelEntity? {
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
    }
}
