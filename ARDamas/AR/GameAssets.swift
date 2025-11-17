import RealityKit
import SwiftUI

class GameAssets {
    
    // Constantes do tabuleiro
    static let squareSize: Float = 0.05   // 5cm
    static let pieceRadius: Float = 0.02   // 2cm de raio (4cm diâmetro)
    static let pieceHeight: Float = 0.02   // 2cm de altura
    static let boardSize: Int = 8
    
    // --- NOVO: Tornamos as malhas (Mesh) estáticas e reutilizáveis ---
    static let pieceMesh = MeshResource.generateCylinder(height: pieceHeight, radius: pieceRadius)
    static let squareMesh = MeshResource.generateBox(width: squareSize, height: 0.01, depth: squareSize) // Tabuleiro fino
    
    // Função principal que constrói e retorna o tabuleiro completo
    static func createCheckersBoard() -> ModelEntity {
        
        // 1. Criar a entidade "raiz" que segura todas as peças
        let boardEntity = ModelEntity()
        
        // 2. Definir materiais
        let whiteMat = SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)
        let blackMat = SimpleMaterial(color: .black, roughness: 0.8, isMetallic: false)
        let redPieceMat = SimpleMaterial(color: .red, roughness: 0.3, isMetallic: false)
        let blackPieceMat = SimpleMaterial(color: .darkGray, roughness: 0.3, isMetallic: false)
        
        // Para centralizar o tabuleiro, calculamos um offset
        // Metade da largura total do tabuleiro, menos metade de um quadrado
        let offset = (Float(boardSize) * squareSize) / 2.0 - (squareSize / 2.0)
        
        // 3. Loop 8x8 para criar as casas do tabuleiro
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                
                let isBlackSquare = (row + col) % 2 == 1
                let currentPosition = Position(row: row, col: col) // Posição atual
                
                // --- A Casa (Square) ---
                let square = ModelEntity(mesh: squareMesh, // Reutiliza a malha
                                         materials: [isBlackSquare ? blackMat : whiteMat])
                
                // --- LÓGICA DE POSIÇÃO CORRIGIDA ---
                let xPos = (Float(col) * squareSize) - offset
                let zPos = (Float(row) * squareSize) - offset
                square.position = SIMD3<Float>(x: xPos, y: 0, z: zPos)
                
                // --- Adicionar "inteligência" à casa ---
                square.components[BoardPositionComponent.self] = BoardPositionComponent(position: currentPosition)
                square.generateCollisionShapes(recursive: false)
                
                boardEntity.addChild(square) // Adiciona a casa
                
                // --- As Peças (Pieces) ---
                if isBlackSquare {
                    var pieceMat: SimpleMaterial? = nil
                    
                    // --- LÓGICA DE PEÇAS CORRIGIDA ---
                    // Coloca as peças pretas (cinza-escuro) nas 3 primeiras fileiras
                    if row < 3 {
                        pieceMat = blackPieceMat
                    }
                    // Coloca as peças vermelhas nas 3 últimas fileiras
                    else if row > 4 {
                        pieceMat = redPieceMat
                    }
                    
                    // Se um material foi definido, crie a peça
                    if let material = pieceMat {
                        // Reutiliza a malha 'pieceMesh'
                        let piece = ModelEntity(mesh: pieceMesh, materials: [material])
                        
                        // --- LÓGICA DE POSIÇÃO CORRIGIDA ---
                        // Posição da peça (mesmo x, z da casa, mas mais alto em y)
                        let yPos = (0.01 / 2.0) + (pieceHeight / 2.0)
                        piece.position = SIMD3<Float>(x: xPos, y: yPos, z: zPos)
                        
                        // --- Adicionar "inteligência" à peça ---
                        piece.components[BoardPositionComponent.self] = BoardPositionComponent(position: currentPosition)
                        piece.generateCollisionShapes(recursive: false)
                        
                        boardEntity.addChild(piece) // Adiciona a peça
                    }
                }
            }
        }
        
        return boardEntity
    }
}
