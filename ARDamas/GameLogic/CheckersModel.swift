import Foundation
import Combine

// MARK: - Tipos de Dados Auxiliares

// --- ALTERAÇÃO: Adicionado 'Codable' ---
// Isso permite que a Posição seja enviada via rede (convertida para JSON/Data).
struct Position: Equatable, Hashable, Codable {
    let row: Int
    let col: Int
}

// Define de quem é a peça
enum Player: String, Codable { // Adicionado String, Codable para facilitar envio se necessário
    case red
    case black
}

// Define o tipo da peça (e seu "dono")
enum PieceType {
    case red
    case black
    case redKing
    case blackKing
    
    var player: Player {
        switch self {
        case .red, .redKing:
            return .red
        case .black, .blackKing:
            return .black
        }
    }
}

// MARK: - O Modelo Principal do Jogo

class CheckersModel: ObservableObject {
    
    @Published var board: [[PieceType?]]
    @Published var currentPlayer: Player = .red
    
    private let boardSize = 8
    
    init() {
        self.board = Array(repeating: Array(repeating: nil, count: boardSize), count: boardSize)
        populateInitialBoard()
    }
    
    func populateInitialBoard() {
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                let isBlackSquare = (row + col) % 2 == 1
                if isBlackSquare {
                    if row < 3 {
                        board[row][col] = .black
                    } else if row > 4 {
                        board[row][col] = .red
                    }
                }
            }
        }
    }
    
    func movePiece(from: Position, to: Position) {
        guard let piece = board[from.row][from.col] else { return }
        
        board[to.row][to.col] = piece
        board[from.row][from.col] = nil
        
        // Troca o turno
        currentPlayer = (currentPlayer == .red) ? .black : .red
    }
    
    func getValidMoves(from: Position) -> [Position] {
        guard let piece = board[from.row][from.col] else { return [] }
        
        var validMoves: [Position] = []
        
        // Lógica simplificada de movimento
        if piece.player == .red {
            let m1 = Position(row: from.row - 1, col: from.col - 1)
            if isPositionValid(m1) { validMoves.append(m1) }
            
            let m2 = Position(row: from.row - 1, col: from.col + 1)
            if isPositionValid(m2) { validMoves.append(m2) }
            
        } else if piece.player == .black {
            let m1 = Position(row: from.row + 1, col: from.col - 1)
            if isPositionValid(m1) { validMoves.append(m1) }
            
            let m2 = Position(row: from.row + 1, col: from.col + 1)
            if isPositionValid(m2) { validMoves.append(m2) }
        }
        
        return validMoves
    }
    
    func isPositionValid(_ position: Position) -> Bool {
        return position.row >= 0 && position.row < boardSize &&
               position.col >= 0 && position.col < boardSize
    }
}
