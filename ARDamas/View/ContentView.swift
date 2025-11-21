import SwiftUI

struct ContentView: View {
    
    // 1. Cria o "cérebro" do jogo (Lógica)
    @StateObject private var gameModel = CheckersModel()
    
    // 2. Cria o "carteiro" do jogo (Multiplayer)
    // O @StateObject mantém o serviço vivo enquanto o app roda.
    @StateObject private var mpcService = MPCService()
    
    var body: some View {
        ZStack {
            // A View de Realidade Aumentada (fundo)
            // Agora passamos tanto o modelo quanto o serviço MPC
            ARViewContainer(gameModel: gameModel, mpcService: mpcService)
                .edgesIgnoringSafeArea(.all)
            
            // UI 2D (frente) - Painel de Status
            VStack {
                HStack {
                    Text("Turno: \(gameModel.currentPlayer == .red ? "Vermelho" : "Preto")")
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    
                    Spacer()
                    
                    Text("Jogadores: \(mpcService.connectedPeers.count + 1)") // +1 sou eu
                        .padding()
                        .background(mpcService.connectedPeers.isEmpty ? Color.red.opacity(0.5) : Color.green.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.top, 40)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .onAppear {
            // Inicia a busca por outros iPhones assim que o app abre
            mpcService.start()
        }
    }
}
