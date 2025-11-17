import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    
    // --- NOVO: Propriedade para receber o modelo ---
    // O SwiftUI vai injetar o 'gameModel' do ContentView aqui.
    var gameModel: CheckersModel
    
    // 1. makeUIView (modificado)
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
        
        // --- NOVO: Passar o modelo para o Coordinator ---
        // Agora o Coordinator tem uma referência ao "cérebro" do jogo.
        context.coordinator.gameModel = gameModel
        
        return arView
    }
    
    // 2. updateUIView (sem mudanças)
    func updateUIView(_ uiView: ARView, context: Context) {
        // Deixe em branco por agora
    }
    
    // 3. makeCoordinator (sem mudanças)
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // 4. Coordinator (modificado)
    class Coordinator: NSObject {
        
        // --- NOVO: Propriedade para "segurar" o modelo ---
        // (Usamos 'weak' para evitar "ciclos de retenção")
        weak var gameModel: CheckersModel?
        var boardEntity: ModelEntity?
        
        weak var arView: ARView?
        var boardIsPlaced = false
        
        // --- NOVO: Variáveis para o fluxo dojogo ---
        // Armazena a peça selecionada E seus movimentos válidos
        var selection: (position: Position, validMoves: [Position])? = nil
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            
            guard let arView = arView else { return }
            let tapLocation = sender.location(in: arView)
            
            // --- LÓGICA DE COLOCAR O TABULEIRO (Movida para uma função) ---
            if !boardIsPlaced {
                placeBoard(at: tapLocation, in: arView)
                return // Saia da função após tentar colocar o tabuleiro
            }
            
            // --- NOVO: Garantir que o modelo existe antes de jogar ---
            guard let gameModel = gameModel else {
                print("Erro: Modelo do jogo não encontrado no Coordinator.")
                return
            }
            
            // --- LÓGICA NOVA DE JOGO (Interagir com o Tabuleiro) ---
            if let entity = arView.entity(at: tapLocation) {
                
                if let boardComponent = entity.components[BoardPositionComponent.self] {
                    let tappedPosition = boardComponent.position
                    
                    // TENTAR SELECIONAR UMA PEÇA
                    // (Verifica se tocamos numa entidade que é uma peça 3D)
                    if let modelEntity = entity as? ModelEntity, modelEntity.model?.mesh === GameAssets.pieceMesh {
                        
                        // 1. Verificar se a peça é do jogador atual
                        let piece = gameModel.board[tappedPosition.row][tappedPosition.col]
                        if piece?.player == gameModel.currentPlayer {
                            
                            // 2. Pedir os movimentos válidos ao "Cérebro"
                            let validMoves = gameModel.getValidMoves(from: tappedPosition)
                            
                            print(">>> PEÇA SELECIONADA: \(tappedPosition)")
                            print(">>> TURNO DO JOGADOR: \(gameModel.currentPlayer)")
                            print(">>> MOVIMENTOS VÁLIDOS (Lógica): \(validMoves)")
                            
                            // 3. Armazenar a seleção
                            self.selection = (position: tappedPosition, validMoves: validMoves)
                            
                            // TODO: Destacar a peça e os movimentos válidos
                            
                        } else {
                            print(">>> Peça do oponente! (Turno de \(gameModel.currentPlayer))")
                        }
                        
                        // TENTAR MOVER A PEÇA SELECIONADA
                        // (O toque NÃO foi numa peça, então deve ser numa casa...
                        // E já tínhamos uma peça selecionada?)
                    } else if let selection = self.selection {
                        
                        let fromPosition = selection.position
                        
                        if selection.validMoves.contains(tappedPosition) {
                            
                            let toPosition = tappedPosition // Apenas para clareza
                            
                            print(">>> TENTANDO MOVER: \(fromPosition) -> \(toPosition)")
                            
                            // 1. Avisar o "Cérebro" para mover a peça
                            gameModel.movePiece(from: fromPosition, to: toPosition)
                            
                            // 2. Limpar a seleção
                            self.selection = nil
                            
                            // --- NOVO: PREENCHER O TODO DA ANIMAÇÃO ---
                            
                            // 3. Encontrar as entidades 3D correspondentes
                            guard let pieceEntity = findEntity(at: fromPosition, for: GameAssets.pieceMesh),
                                  let targetSquareEntity = findEntity(at: toPosition, for: GameAssets.squareMesh)
                            else {
                                print("Erro de Animação: Não foi possível encontrar a peça ou a casa 3D.")
                                return
                            }
                            
                            // 4. Calcular a nova posição 3D
                            // A peça deve ficar "em cima" da casa de destino.
                            
                            // Posição (x, z) da casa de destino
                            let targetPos3D = targetSquareEntity.position
                            
                            // Altura (y) da peça (metade da casa + metade da peça)
                            let yPos = (0.01 / 2.0) + (GameAssets.pieceHeight / 2.0)
                            
                            // Criar a nova 'transform' (posição) para a peça
                            var newTransform = targetSquareEntity.transform
                            newTransform.translation = SIMD3<Float>(x: targetPos3D.x, y: yPos, z: targetPos3D.z)
                            
                            // 5. Executar a animação!
                            // Move a peça 'relativeTo: boardEntity' para garantir que as
                            // coordenadas (newTransform) estão corretas dentro do sistema do tabuleiro.
                            pieceEntity.move(to: newTransform, relativeTo: boardEntity, duration: 0.4, timingFunction: .easeInOut)
                            
                            // 6. Atualizar a "etiqueta" da peça!
                            // A peça 3D está agora numa nova 'Position'.
                            // Temos de atualizar o seu 'BoardPositionComponent' para corresponder.
                            pieceEntity.components[BoardPositionComponent.self] = BoardPositionComponent(position: toPosition)
                            
                            // TODO: Remover o destaque
                            
                            print(">>> PEÇA MOVIDA (com animação)! Próximo turno: \(gameModel.currentPlayer)")
                            
                        } else {
                            // O usuário tocou em uma casa vazia sem ter uma peça selecionada
                            print(">>> TOQUE em uma CASA VAZIA: \(tappedPosition)")
                        }
                    }
                }
            } // Fim de handleTap
            
            // --- NOVA FUNÇÃO AJUDANTE (Lógica antiga movida para cá) ---
            func placeBoard(at tapLocation: CGPoint, in arView: ARView) {
                let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
                
                if let firstResult = results.first {
                    let anchor = AnchorEntity(world: firstResult.worldTransform)
                    
                    // --- CORREÇÃO DO ERRO DE DIGITAÇÃO ---
                    // O nome correto da função é 'createCheckersBoard'
                    let boardEntity = GameAssets.createCheckersBoard()
                    self.boardEntity = boardEntity
                    
                    anchor.addChild(boardEntity)
                    arView.scene.addAnchor(anchor)
                    
                    self.boardIsPlaced = true
                    print(">>> Tabuleiro colocado com sucesso!")
                }
            }
            
            func findEntity(at position: Position, for mesh: MeshResource) -> ModelEntity? {
                
                // 1. Garantir que o tabuleiro 3D existe
                guard let boardEntity = self.boardEntity else { return nil }
                
                // 2. Procurar em todos os "filhos" do tabuleiro
                // (As 64 casas e as 24 peças)
                for entity in boardEntity.children {
                    
                    // 3. Verificar se é uma ModelEntity e se a malha 3D é a que procuramos
                    //    (Isto é mais rápido do que verificar o componente primeiro)
                    guard let modelEntity = entity as? ModelEntity,
                          modelEntity.model?.mesh === mesh
                    else {
                        continue // Próximo, este não é (ex: é uma peça, mas procuramos uma casa)
                    }
                    
                    // 4. Verificar se a "etiqueta" de Posição corresponde
                    if let component = entity.components[BoardPositionComponent.self],
                       component.position == position {
                        
                        // 5. Encontrado!
                        return modelEntity
                    }
                }
                
                // Não foi encontrado
                return nil
            }
        } // Fim de Coordinator
    } // Fim de ARViewContainer
}
