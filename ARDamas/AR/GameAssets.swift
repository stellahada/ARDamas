import RealityKit
import SwiftUI

class GameAssets {
    
    // Constantes do tabuleiro
    static let squareSize: Float = 0.05   // 5cm
    static let pieceRadius: Float = 0.02   // 2cm de raio (4cm diâmetro)
    static let pieceHeight: Float = 0.02   // 2cm de altura
    static let boardSize: Int = 8
    
    // --- Malhas Estáticas (Reutilizáveis) ---
    static let pieceMesh = MeshResource.generateCylinder(height: pieceHeight, radius: pieceRadius)
    static let squareMesh = MeshResource.generateBox(width: squareSize, height: 0.01, depth: squareSize) // Tabuleiro fino
    
    // --- MATERIAIS ESTÁTICOS (Correção do Erro) ---
    // Agora eles são 'static let' para serem acessados pelo ARViewContainer
    
    // Materiais do Tabuleiro
    static let whiteMat = SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)
    static let blackMat = SimpleMaterial(color: .black, roughness: 0.8, isMetallic: false)
    
    // Materiais das Peças
    static let redPieceMat = SimpleMaterial(color: .red, roughness: 0.3, isMetallic: false)
    static let blackPieceMat = SimpleMaterial(color: .darkGray, roughness: 0.3, isMetallic: false)
    
    // Materiais de Destaque (Amarelo e Verde)
    static let highlightPieceMat = SimpleMaterial(color: .yellow, roughness: 0.1, isMetallic: true)
    static let highlightSquareMat = SimpleMaterial(color: .green, roughness: 0.8, isMetallic: false)
    
    
    // Função principal que constrói e retorna o tabuleiro completo
    static func createCheckersBoard() -> ModelEntity {
        
        let boardEntity = ModelEntity()
        
        // Offset para centralizar
        let offset = (Float(boardSize) * squareSize) / 2.0 - (squareSize / 2.0)
        
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                
                let isBlackSquare = (row + col) % 2 == 1
                let currentPosition = Position(row: row, col: col)
                
                // --- A Casa (Square) ---
                // Usamos os materiais estáticos aqui
                let square = ModelEntity(mesh: squareMesh,
                                         materials: [isBlackSquare ? blackMat : whiteMat])
                
                let xPos = (Float(col) * squareSize) - offset
                let zPos = (Float(row) * squareSize) - offset
                square.position = SIMD3<Float>(x: xPos, y: 0, z: zPos)
                
                square.components[BoardPositionComponent.self] = BoardPositionComponent(position: currentPosition)
                square.generateCollisionShapes(recursive: false)
                
                boardEntity.addChild(square)
                
                // --- As Peças (Pieces) ---
                if isBlackSquare {
                    var pieceMat: SimpleMaterial? = nil
                    
                    if row < 3 {
                        pieceMat = blackPieceMat // Usa o estático
                    } else if row > 4 {
                        pieceMat = redPieceMat   // Usa o estático
                    }
                    
                    if let material = pieceMat {
                        let piece = ModelEntity(mesh: pieceMesh, materials: [material])
                        
                        let yPos = (0.01 / 2.0) + (pieceHeight / 2.0)
                        piece.position = SIMD3<Float>(x: xPos, y: yPos, z: zPos)
                        
                        piece.components[BoardPositionComponent.self] = BoardPositionComponent(position: currentPosition)
                        piece.generateCollisionShapes(recursive: false)
                        
                        boardEntity.addChild(piece)
                    }
                }
            }
        }
        
        return boardEntity
    }
}
