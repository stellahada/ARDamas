import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var gameModel = CheckersModel()
    @StateObject private var mpcService = MPCService()
    @State private var isInGame = false
    @State private var username: String = UIDevice.current.name
    
    var body: some View {
        ZStack {
            if isInGame {
                GameView(gameModel: gameModel, mpcService: mpcService, isInGame: $isInGame)
                    .transition(.move(edge: .trailing))
            } else {
                LobbyView(mpcService: mpcService, username: $username, onStart: {
                    withAnimation { isInGame = true }
                })
                .transition(.move(edge: .leading))
            }
        }
        .onAppear { mpcService.start() }
    }
}

struct LobbyView: View {
    @ObservedObject var mpcService: MPCService
    @Binding var username: String
    var onStart: () -> Void
    @State private var nameSaved = false
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing).edgesIgnoringSafeArea(.all)
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Image(systemName: "checkerboard.rectangle").resizable().frame(width: 80, height: 80).foregroundColor(.white).padding().background(Circle().fill(Color.white.opacity(0.2)))
                    Text("AR Damas").font(.system(size: 42, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("Realidade Aumentada Multiplayer").font(.subheadline).foregroundColor(.white.opacity(0.8))
                }.padding(.top, 50)
                
                VStack(alignment: .leading) {
                    Text("SEU NOME").font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.6))
                    HStack {
                        TextField("Apelido", text: $username).padding().background(Color.white.opacity(0.2)).cornerRadius(12).foregroundColor(.white)
                        Button(action: {
                            mpcService.changePeerName(to: username)
                            withAnimation { nameSaved = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { nameSaved = false } }
                        }) {
                            Image(systemName: nameSaved ? "checkmark" : "arrow.triangle.2.circlepath").font(.headline).foregroundColor(.white).padding().background(nameSaved ? Color.green : Color.white.opacity(0.3)).cornerRadius(12)
                        }
                    }
                }.padding(.horizontal, 40)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("JOGADORES").font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        if mpcService.connectedPeers.isEmpty { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                    }
                    ScrollView {
                        if mpcService.connectedPeers.isEmpty {
                            Text("Procurando...").font(.caption).foregroundColor(.white.opacity(0.4)).padding(.top, 20).frame(maxWidth: .infinity)
                        } else {
                            ForEach(mpcService.connectedPeers, id: \.self) { peer in
                                HStack {
                                    Image(systemName: "iphone").foregroundColor(.green)
                                    Text(peer.displayName).fontWeight(.semibold).foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }.padding().background(Color.white.opacity(0.15)).cornerRadius(10)
                            }
                        }
                    }.frame(height: 150)
                }.padding(.horizontal, 40)
                
                Spacer()
                Button(action: onStart) {
                    Text("ENTRAR NO JOGO").font(.headline).fontWeight(.bold).frame(maxWidth: .infinity).padding().background(Color.white).foregroundColor(.purple).cornerRadius(15).shadow(radius: 10)
                }.padding(.horizontal, 40).padding(.bottom, 40).disabled(mpcService.connectedPeers.isEmpty).opacity(mpcService.connectedPeers.isEmpty ? 0.6 : 1.0)
            }
        }
    }
}

// MARK: - GAME VIEW
struct GameView: View {
    @ObservedObject var gameModel: CheckersModel
    @ObservedObject var mpcService: MPCService
    @Binding var isInGame: Bool
    
    var opponentName: String { mpcService.connectedPeers.first?.displayName ?? "Oponente" }
    
    // Para identificar quem ganhou visualmente
    var winnerName: String {
        guard let w = gameModel.winner else { return "" }
        return w == .red ? "VERMELHO" : "PRETO"
    }
    
    var winnerColor: Color {
        guard let w = gameModel.winner else { return .gray }
        return w == .red ? .red : .black
    }
    
    var body: some View {
        ZStack {
            ARViewContainer(gameModel: gameModel, mpcService: mpcService).edgesIgnoringSafeArea(.all)
            
            VStack {
                // HUD
                HStack {
                    Button(action: { withAnimation { isInGame = false } }) {
                        Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.white).shadow(radius: 2)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Vs \(opponentName)").font(.caption).fontWeight(.bold).foregroundColor(.white)
                        Text("Turno: \(gameModel.currentPlayer == .red ? "Vermelho" : "Preto")").font(.system(.body, design: .rounded)).fontWeight(.bold).foregroundColor(gameModel.currentPlayer == .red ? .red : .black)
                    }.padding(.vertical, 8).padding(.horizontal, 16).background(Material.ultraThinMaterial).cornerRadius(20)
                    Spacer()
                    HStack(spacing: 4) { Circle().fill(Color.green).frame(width: 8, height: 8) }.padding(8).background(Color.black.opacity(0.6)).cornerRadius(12)
                }.padding(.top, 50).padding(.horizontal)
                
                Spacer()
                
            }
            
            // --- TELA DE FIM DE JOGO ---
            if gameModel.winner != nil {
                Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text("FIM DE JOGO!")
                        .font(.largeTitle).fontWeight(.heavy).foregroundColor(.white)
                    
                    VStack {
                        Text("VENCEDOR")
                            .font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.7))
                        Text(winnerName)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(winnerColor)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                    }
                    
                    Button(action: {
                        // 1. Reseta localmente
                        gameModel.resetGame()
                        // 2. Reseta o tabuleiro 3D localmente (via Notification ou Observable, mas aqui vamos forçar via MPC)
                        // Para simplificar, o ARViewContainer ouve o model resetado, mas precisamos enviar para o outro jogador
                        mpcService.sendRestart()
                        
                        // Nota: Precisamos forçar o ARViewContainer a limpar as peças.
                        // Enviar .gameRestart para MIM MESMO é um truque para usar a mesma lógica
                        // de limpeza que usamos quando recebemos do oponente.
                        NotificationCenter.default.post(name: NSNotification.Name("LocalRestart"), object: nil)
                        
                    }) {
                        Text("JOGAR NOVAMENTE")
                            .font(.headline).fontWeight(.bold)
                            .padding()
                            .frame(width: 200)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(25)
                            .shadow(radius: 10)
                    }
                }
                .padding(40)
                .background(Material.regular)
                .cornerRadius(30)
                .shadow(radius: 20)
                .transition(.scale)
            }
        }
    }
}
