import Foundation
import Combine

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
    let turnChanged: Bool 
}

class CheckersModel: ObservableObject {
    
    @Published var board: [[PieceType?]]
    @Published var currentPlayer: Player = .red
    @Published var winner: Player? = nil
    @Published var localPlayerColor: Player = .red
    
    @Published var mustCaptureFrom: Position? = nil
    
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
        winner = nil
        mustCaptureFrom = nil
    }
    
    func resetGame() {
        populateInitialBoard()
    }
    
    @discardableResult
    func movePiece(from: Position, to: Position) -> MoveResult {
        guard let piece = board[from.row][from.col] else {
            return MoveResult(capturedPosition: nil, isPromotion: false, turnChanged: false)
        }
        
        var capturedPos: Position? = nil
        var isPromo = false
        var turnChanged = true
        
        // 1. Detectar Captura
        // Na dama voadora, a captura não é necessariamente rowDiff >= 2, mas sim se pulou algo.
        // Vamos verificar se havia peças no caminho.
        
        let rowDiff = to.row - from.row
        let colDiff = to.col - from.col
        let stepRow = rowDiff > 0 ? 1 : -1
        let stepCol = colDiff > 0 ? 1 : -1
        
        var r = from.row + stepRow
        var c = from.col + stepCol
        var foundCapture = false
        
        while r != to.row {
            if let target = board[r][c] {
                if target.player != piece.player {
                    capturedPos = Position(row: r, col: c)
                    board[r][c] = nil // Remove a peça comida
                    foundCapture = true
                }
            }
            r += stepRow
            c += stepCol
        }
        
        // 2. Mover a peça
        board[to.row][to.col] = piece
        board[from.row][from.col] = nil
        
        // 3. Verifica Promoção
        if !piece.isKing {
            if (piece.player == .red && to.row == 0) || (piece.player == .black && to.row == 7) {
                board[to.row][to.col] = piece.promoted()
                isPromo = true
            }
        }
        
        // 4. Lógica de Sequência (Combo)
        if foundCapture && !isPromo {
            // Se capturou, verifica se pode capturar mais a partir da NOVA posição
            if canCapture(from: to) {
                turnChanged = false
                mustCaptureFrom = to
            } else {
                mustCaptureFrom = nil
                turnChanged = true
            }
        } else {
            mustCaptureFrom = nil
            turnChanged = true
        }
        
        if turnChanged {
            currentPlayer = currentPlayer.opponent
        }
        
        checkWinCondition()
        
        return MoveResult(capturedPosition: capturedPos, isPromotion: isPromo, turnChanged: turnChanged)
    }
    
    // --- LÓGICA DE MOVIMENTOS VÁLIDOS (ATUALIZADA) ---
    
    func getValidMoves(from: Position) -> [Position] {
        // Se estiver travado em combo, só retorna moves daquela peça
        if let required = mustCaptureFrom {
            if from != required { return [] }
        }
        
        guard let piece = board[from.row][from.col] else { return [] }
        var moves: [Position] = []
        let directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        
        // Se houver capturas disponíveis no tabuleiro para este jogador, 
        // e a regra for "captura obrigatória", deveríamos filtrar.
        // Aqui vamos focar nos movimentos possíveis DA PEÇA selecionada.
        
        // --- 1. SE FOR DAMA (KING) ---
        if piece.isKing {
            // Verificar Capturas à distância primeiro (prioridade)
            var captureMoves: [Position] = []
            
            for d in directions {
                var distance = 1
                var foundEnemy = false
                
                while true {
                    let r = from.row + (d.0 * distance)
                    let c = from.col + (d.1 * distance)
                    let pos = Position(row: r, col: c)
                    
                    if !isPositionValid(pos) { break } // Saiu do tabuleiro
                    
                    if let target = board[r][c] {
                        if target.player == piece.player {
                            break // Bloqueado por amiga
                        } else {
                            // Encontrou inimigo
                            if foundEnemy { break } // Já tinha achado um antes (2 peças juntas não pode)
                            foundEnemy = true
                        }
                    } else {
                        // Casa vazia
                        if foundEnemy {
                            // Se já passamos por um inimigo e agora está vazio, é um destino de captura válido!
                            captureMoves.append(pos)
                        }
                    }
                    distance += 1
                }
            }
            
            // Se tiver capturas, retorna elas. Se não, verifica movimento normal (slide)
            if !captureMoves.isEmpty || mustCaptureFrom != nil {
                return captureMoves
            }
            
            // Movimento Normal (Slide) - Dama Voadora
            for d in directions {
                var distance = 1
                while true {
                    let r = from.row + (d.0 * distance)
                    let c = from.col + (d.1 * distance)
                    let pos = Position(row: r, col: c)
                    
                    if !isPositionValid(pos) { break }
                    if !isEmpty(pos) { break } // Parar se encontrar qualquer peça
                    
                    moves.append(pos)
                    distance += 1
                }
            }
            
        } 
        // --- 2. SE FOR PEÇA COMUM ---
        else {
            // Captura Simples (adjacente)
            // Nota: Regra brasileira permite peça comum capturar pra trás
            for d in directions {
                let capturePos = Position(row: from.row + (d.0 * 2), col: from.col + (d.1 * 2))
                if isPositionValid(capturePos) && isEmpty(capturePos) {
                    let midPos = Position(row: from.row + d.0, col: from.col + d.1)
                    if let midPiece = board[midPos.row][midPos.col], midPiece.player != piece.player {
                        moves.append(capturePos)
                    }
                }
            }
            
            // Se tiver capturas ou estiver em combo, retorna só as capturas
            if !moves.isEmpty || mustCaptureFrom != nil {
                return moves
            }
            
            // Movimento Normal (apenas frente)
            let forwardDirs = piece.player == .red ? [(-1, -1), (-1, 1)] : [(1, -1), (1, 1)]
            for d in forwardDirs {
                let pos = Position(row: from.row + d.0, col: from.col + d.1)
                if isPositionValid(pos) && isEmpty(pos) {
                    moves.append(pos)
                }
            }
        }
        
        return moves
    }
    
    // --- LÓGICA DE "POSSO CAPTURAR?" (ATUALIZADA) ---
    func canCapture(from: Position) -> Bool {
        guard let piece = board[from.row][from.col] else { return false }
        let directions = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        
        if piece.isKing {
            // Dama Voadora detecta captura longe
            for d in directions {
                var distance = 1
                var foundEnemy = false
                
                while true {
                    let r = from.row + (d.0 * distance)
                    let c = from.col + (d.1 * distance)
                    
                    if !isPositionValid(Position(row: r, col: c)) { break }
                    
                    if let target = board[r][c] {
                        if target.player == piece.player { break } // Amiga bloqueia
                        if foundEnemy { break } // Duas peças seguidas bloqueiam
                        foundEnemy = true // Achou inimigo
                    } else {
                        // Vazio
                        if foundEnemy { return true } // Achou inimigo e tem espaço depois -> PODE CAPTURAR
                    }
                    distance += 1
                }
            }
        } else {
            // Peça comum
            for d in directions {
                let destPos = Position(row: from.row + (d.0 * 2), col: from.col + (d.1 * 2))
                if isPositionValid(destPos) && isEmpty(destPos) {
                    let midPos = Position(row: from.row + d.0, col: from.col + d.1)
                    if let midPiece = board[midPos.row][midPos.col], midPiece.player != piece.player {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private func isPositionValid(_ p: Position) -> Bool {
        return p.row >= 0 && p.row < boardSize && p.col >= 0 && p.col < boardSize
    }
    
    private func isEmpty(_ p: Position) -> Bool {
        return board[p.row][p.col] == nil
    }
    
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
}
