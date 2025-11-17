import RealityKit

/// Um Componente que armazena a posição (linha, coluna)
/// de uma entidade no tabuleiro de Damas.
///
/// (Este 'Position' é o mesmo struct que definimos no CheckersModel.swift)
struct BoardPositionComponent: Component {
    var position: Position
}
