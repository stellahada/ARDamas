import Foundation
import Combine

// --- TIPOS AUXILIARES ---

struct Position: Equatable, Hashable, Codable {
    let row: Int
    let col: Int
}

enum Player: String, Codable {
    case red
    case black
    
    var opponent: Player {
        return self == .red ? .black : .red
    }
}

enum PieceType: Codable, Equatable {
    case red
    case black
    case redKing
    case blackKing
    
    var player: Player {
        switch self {
        case .red, .redKing: return .red
        case .black, .blackKing: return .black
        }
    }
    
    var isKing: Bool {
        return self == .redKing || self == .blackKing
    }
    
    func promoted() -> PieceType {
        return self.player == .red ? .redKing : .blackKing
    }
}

struct MoveResult {
    let capturedPosition: Position?
    let isPromotion: Bool
}

// --- O MODELO PRINCIPAL ---

class CheckersModel: ObservableObject {
    
    @Published var board: [[PieceType?]]
    @Published var currentPlayer: Player = .red
    
    // --- NOVO: Vencedor do jogo ---
    @Published var winner: Player? = nil
    
    private let boardSize = 8
    
    init() {
        self.board = Array(repeating: Array(repeating: nil, count: boardSize), count: boardSize)
        populateInitialBoard()
    }
    
    func populateInitialBoard() {
        board = Array(repeating: Array(repeating: nil, count: boardSize), count: boardSize)
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                if (row + col) % 2 == 1 {
                    if row < 3 { board[row][col] = .black }
                    else if row > 4 { board[row][col] = .red }
                }
            }
        }
        currentPlayer = .red
        winner = nil // Reseta vencedor
    }
    
    // --- NOVO: Função para reiniciar o jogo ---
    func resetGame() {
        populateInitialBoard()
    }
    
    @discardableResult
    func movePiece(from: Position, to: Position) -> MoveResult {
        guard let piece = board[from.row][from.col] else {
            return MoveResult(capturedPosition: nil, isPromotion: false)
        }
        
        var capturedPos: Position? = nil
        var isPromo = false
        
        // 1. Detectar Captura
        let rowDiff = to.row - from.row
        let colDiff = to.col - from.col
        
        if abs(rowDiff) == abs(colDiff) {
            let stepRow = rowDiff > 0 ? 1 : -1
            let stepCol = colDiff > 0 ? 1 : -1
            var r = from.row + stepRow
            var c = from.col + stepCol
            
            while r != to.row {
                if let targetPiece = board[r][c] {
                    if targetPiece.player != piece.player {
                        capturedPos = Position(row: r, col: c)
                        board[r][c] = nil
                        break
                    }
                }
                r += stepRow
                c += stepCol
            }
        }
        
        // 2. Mover a peça
        board[to.row][to.col] = piece
        board[from.row][from.col] = nil
        
        // 3. Detectar Promoção
        if !piece.isKing {
            if (piece.player == .red && to.row == 0) || (piece.player == .black && to.row == 7) {
                board[to.row][to.col] = piece.promoted()
                isPromo = true
            }
        }
        
        // 4. Trocar Turno
        currentPlayer = currentPlayer.opponent
        
        // --- NOVO: Verificar se alguém ganhou ---
        checkWinCondition()
        
        return MoveResult(capturedPosition: capturedPos, isPromotion: isPromo)
    }
    
    // --- NOVO: Lógica de Vitória ---
    private func checkWinCondition() {
        var redCount = 0
        var blackCount = 0
        
        for row in board {
            for piece in row {
                if let p = piece {
                    if p.player == .red { redCount += 1 }
                    else { blackCount += 1 }
                }
            }
        }
        
        if redCount == 0 { winner = .black }
        else if blackCount == 0 { winner = .red }
    }
    
    func getValidMoves(from: Position) -> [Position] {
        guard let piece = board[from.row][from.col] else { return [] }
        var moves: [Position] = []
        
        if piece.isKing {
            let directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
            for d in directions {
                var r = from.row + d.0
                var c = from.col + d.1
                var foundEnemy = false
                while isPositionValid(Position(row: r, col: c)) {
                    if let target = board[r][c] {
                        if target.player == piece.player { break }
                        if foundEnemy { break }
                        foundEnemy = true
                    } else {
                        moves.append(Position(row: r, col: c))
                    }
                    r += d.0
                    c += d.1
                }
            }
        } else {
            let forwardDirs = piece.player == .red ? [(-1, -1), (-1, 1)] : [(1, -1), (1, 1)]
            for d in forwardDirs {
                let oneStep = Position(row: from.row + d.0, col: from.col + d.1)
                if isPositionValid(oneStep) && isEmpty(oneStep) {
                    moves.append(oneStep)
                }
                let twoStep = Position(row: from.row + (d.0 * 2), col: from.col + (d.1 * 2))
                if isPositionValid(twoStep) && isEmpty(twoStep) {
                    let midPos = Position(row: from.row + d.0, col: from.col + d.1)
                    if let midPiece = board[midPos.row][midPos.col], midPiece.player != piece.player {
                        moves.append(twoStep)
                    }
                }
            }
        }
        return moves
    }
    
    private func isPositionValid(_ p: Position) -> Bool {
        return p.row >= 0 && p.row < boardSize && p.col >= 0 && p.col < boardSize
    }
    
    private func isEmpty(_ p: Position) -> Bool {
        return board[p.row][p.col] == nil
    }
}
