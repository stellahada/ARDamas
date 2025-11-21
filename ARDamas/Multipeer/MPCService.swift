import Foundation
import MultipeerConnectivity
import Combine

// --- ESTRUTURAS DE MENSAGEM ---

// O movimento que será enviado pela rede
struct GameMove: Codable {
    let from: Position
    let to: Position
}

// Tipos de mensagens que o jogo suporta
enum MessageType: String, Codable {
    case gameMove
    // Futuro: case worldMap (para compartilhar a RA)
}

// O envelope da mensagem
struct GameMessage: Codable {
    let type: MessageType
    let payload: Data
}

// --- O SERVIÇO PRINCIPAL ---

class MPCService: NSObject, ObservableObject {
    
    // Identificador único deste dispositivo
    private let serviceType = "ardamas-game" // Deve ser curto e único (max 15 chars)
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    
    private var serviceAdvertiser: MCNearbyServiceAdvertiser
    private var serviceBrowser: MCNearbyServiceBrowser
    private var session: MCSession
    
    // Publica para a UI quem está conectado
    @Published var connectedPeers: [MCPeerID] = []
    
    // Publica mensagens recebidas para o CheckersModel ou ARViewContainer reagir
    // O PassthroughSubject age como um "gatilho" de evento
    let messageReceived = PassthroughSubject<GameMessage, Never>()
    
    override init() {
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        
        super.init()
        
        // Configura os delegados
        self.session.delegate = self
        self.serviceAdvertiser.delegate = self
        self.serviceBrowser.delegate = self
    }
    
    // Inicia a busca por jogadores
    func start() {
        print("MPC: Iniciando busca e anúncio...")
        self.serviceAdvertiser.startAdvertisingPeer()
        self.serviceBrowser.startBrowsingForPeers()
    }
    
    // Para tudo
    func stop() {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
        self.session.disconnect()
    }
    
    // Envia uma mensagem para todos os conectados
    func send(message: GameMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        
        do {
            // Transforma a mensagem em bits (Data)
            let data = try JSONEncoder().encode(message)
            
            // Envia
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("MPC: Mensagem enviada (\(message.type.rawValue))")
        } catch {
            print("MPC: Erro ao enviar mensagem: \(error.localizedDescription)")
        }
    }
    
    // Envia um movimento de jogo específico (atalho)
    func sendMove(from: Position, to: Position) {
        let move = GameMove(from: from, to: to)
        do {
            let moveData = try JSONEncoder().encode(move)
            let message = GameMessage(type: .gameMove, payload: moveData)
            send(message: message)
        } catch {
            print("MPC: Erro ao codificar movimento: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate (Gerencia a conexão)
extension MPCService: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            // Atualiza a lista de conectados
            self.connectedPeers = session.connectedPeers
            
            switch state {
            case .connected:
                print("MPC: Conectado a \(peerID.displayName)")
            case .connecting:
                print("MPC: Conectando a \(peerID.displayName)...")
            case .notConnected:
                print("MPC: Desconectado de \(peerID.displayName)")
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // MENSAGEM RECEBIDA!
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)
            
            // Avisa quem estiver ouvindo (na Main Thread)
            DispatchQueue.main.async {
                self.messageReceived.send(message)
            }
        } catch {
            print("MPC: Erro ao decodificar mensagem recebida: \(error)")
        }
    }
    
    // Funções obrigatórias, mas que não vamos usar agora (streams e recursos)
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (Recebe convites)
extension MPCService: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Aceita convites automaticamente (para simplificar)
        print("MPC: Convite recebido de \(peerID.displayName). Aceitando...")
        invitationHandler(true, self.session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (Encontra pessoas)
extension MPCService: MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Encontrou alguém! Convida automaticamente.
        print("MPC: Jogador encontrado: \(peerID.displayName). Convidando...")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("MPC: Jogador perdido: \(peerID.displayName)")
    }
}
