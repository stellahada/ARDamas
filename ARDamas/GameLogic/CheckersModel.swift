import Foundation
import Combine // Usaremos o Combine para "anunciar" mudanças no estado do jogo

// MARK: - Tipos de Dados Auxiliares

// Para facilitar, vamos usar um struct para posições
struct Position: Equatable, Hashable {
    let row: Int
    let col: Int
}

// Define de quem é a peça
enum Player {
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
    
    // O @Published faz com que qualquer View (SwiftUI)
    // que esteja "ouvindo" este objeto seja notificada quando o valor mudar.
    @Published var board: [[PieceType?]]
    @Published var currentPlayer: Player = .red // Damas vermelhas (claras) começam
    
    private let boardSize = 8
    
    init() {
        // Inicializa o tabuleiro com 8x8 casas vazias (nil)
        self.board = Array(repeating: Array(repeating: nil, count: boardSize), count: boardSize)
        // Preenche a configuração inicial
        populateInitialBoard()
    }
    
    /// Preenche o 'board' com a configuração inicial de Damas.
    func populateInitialBoard() {
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                
                // Apenas coloque peças nas casas pretas
                let isBlackSquare = (row + col) % 2 == 1
                
                if isBlackSquare {
                    // Coloca as peças pretas (cinza-escuro) nas 3 primeiras fileiras
                    if row < 3 {
                        board[row][col] = .black
                    }
                    // Coloca as peças vermelhas nas 3 últimas fileiras
                    else if row > 4 {
                        board[row][col] = .red
                    }
                }
            }
        }
    }
    
    /// Move uma peça no 'board' (lógica interna).
    /// Esta é uma versão SIMPLES. Não lida com capturas ou promoção.
    func movePiece(from: Position, to: Position) {
        
        // 1. Pega a peça na origem
        guard let piece = board[from.row][from.col] else {
            print("Erro: Nenhuma peça na posição de origem.")
            return
        }
        
        // 2. Move a peça para o destino
        board[to.row][to.col] = piece
        
        // 3. Limpa a casa de origem
        board[from.row][from.col] = nil
        
        // --- TODO: Lógica de Captura ---
        // (Verificar se foi um pulo e remover a peça do oponente)
        
        // --- TODO: Lógica de Promoção ---
        // (Verificar se a peça chegou ao final do tabuleiro e virou Dama/Rei)
        
        // 4. Troca o turno do jogador
        currentPlayer = (currentPlayer == .red) ? .black : .red
    }
    
    /// Retorna uma lista de posições válidas para onde a peça pode se mover.
    /// ESTA É A FUNÇÃO MAIS COMPLEXA (e por enquanto está vazia).
    func getValidMoves(from: Position) -> [Position] {
        guard let piece = board[from.row][from.col] else {
            return [] // Sem peça, sem movimentos
        }
        var validMoves: [Position] = []
        
        // --- TODO: Lógica de Movimento ---
        // 1. Verificar o 'piece.player' e 'piece.type' (normal vs. Dama)
        // 2. Verificar movimentos simples (diagonais para frente)
        // 3. Verificar movimentos de captura (pulos)
        // 4. Lógica de "captura obrigatória" (se houver um pulo, outros movimentos não são válidos)
        
        
        // (Por enquanto, vamos adicionar movimentos simples apenas para teste)
        // Esta lógica está INCOMPLETA e serve apenas para avançarmos
        if piece.player == .red {
            let simpleMove = Position(row: from.row - 1, col: from.col - 1)
            if isPositionValid(simpleMove) { validMoves.append(simpleMove) }
            
            let simpleMove2 = Position(row: from.row - 1, col: from.col + 1)
            if isPositionValid(simpleMove2) { validMoves.append(simpleMove2) }
            
        // --- NOVO: Lógica para movimentos das peças pretas ---
        } else if piece.player == .black {
            let simpleMove = Position(row: from.row + 1, col: from.col - 1)
            if isPositionValid(simpleMove) { validMoves.append(simpleMove) }
            
            let simpleMove2 = Position(row: from.row + 1, col: from.col + 1)
            if isPositionValid(simpleMove2) { validMoves.append(simpleMove2) }
        }
        
        return validMoves
    }
    
    /// Verifica se uma posição está dentro dos limites do tabuleiro.
    func isPositionValid(_ position: Position) -> Bool {
        return position.row >= 0 && position.row < boardSize &&
               position.col >= 0 && position.col < boardSize
    }
}
