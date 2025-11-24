import Foundation
import MultipeerConnectivity
import Combine

struct GameMove: Codable {
    let from: Position
    let to: Position
}

enum MessageType: String, Codable {
    case gameMove
    case worldMap
    case gameRestart // --- NOVO: Tipo para reiniciar o jogo
}

struct GameMessage: Codable {
    let type: MessageType
    let payload: Data
}

class MPCService: NSObject, ObservableObject {
    
    private let serviceType = "ardamas-game"
    private var myPeerId: MCPeerID
    private var serviceAdvertiser: MCNearbyServiceAdvertiser?
    private var serviceBrowser: MCNearbyServiceBrowser?
    private var session: MCSession?
    
    @Published var connectedPeers: [MCPeerID] = []
    let messageReceived = PassthroughSubject<GameMessage, Never>()
    
    override init() {
        self.myPeerId = MCPeerID(displayName: UIDevice.current.name)
        super.init()
        setupConnectivity()
    }
    
    private func setupConnectivity() {
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        self.session?.delegate = self
        self.serviceAdvertiser?.delegate = self
        self.serviceBrowser?.delegate = self
    }
    
    func changePeerName(to newName: String) {
        stop()
        self.myPeerId = MCPeerID(displayName: newName)
        setupConnectivity()
        start()
    }
    
    func start() {
        self.serviceAdvertiser?.startAdvertisingPeer()
        self.serviceBrowser?.startBrowsingForPeers()
    }
    
    func stop() {
        self.serviceAdvertiser?.stopAdvertisingPeer()
        self.serviceBrowser?.stopBrowsingForPeers()
        self.session?.disconnect()
        self.connectedPeers.removeAll()
    }
    
    func send(message: GameMessage) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("MPC: Erro envio: \(error)")
        }
    }
    
    func sendMove(from: Position, to: Position) {
        let move = GameMove(from: from, to: to)
        do {
            let moveData = try JSONEncoder().encode(move)
            let message = GameMessage(type: .gameMove, payload: moveData)
            send(message: message)
        } catch { print("MPC: Erro encode move: \(error)") }
    }
    
    func sendWorldMap(data: Data) {
        let message = GameMessage(type: .worldMap, payload: data)
        send(message: message)
    }
    
    // --- NOVO: Enviar sinal de reiniciar ---
    func sendRestart() {
        let message = GameMessage(type: .gameRestart, payload: Data())
        send(message: message)
    }
}

extension MPCService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.connectedPeers = session.connectedPeers }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)
            DispatchQueue.main.async { self.messageReceived.send(message) }
        } catch { print("MPC: Erro decode: \(error)") }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MPCService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, self.session)
    }
}

extension MPCService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: self.session!, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
