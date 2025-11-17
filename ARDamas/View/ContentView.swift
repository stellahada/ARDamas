import SwiftUI

struct ContentView: View {
    
    // 1. Cria o "cérebro" do jogo.
    // @StateObject garante que ele só seja criado UMA vez
    // e que a view "observe" suas mudanças (@Published).
    @StateObject private var gameModel = CheckersModel()
    
    var body: some View {
        
        // 2. Passa o "cérebro" (gameModel) para dentro da ARViewContainer.
        ARViewContainer(gameModel: gameModel)
            .edgesIgnoringSafeArea(.all)
        
        // TODO: No futuro, podemos adicionar botões 2D aqui em cima da ARView
        // ex: Text("Turno: \(gameModel.currentPlayer == .red ? "Vermelho" : "Preto")")
    }
}
