//
//  AudioManager.swift
//  ARDamas
//
//  Created by Henrique Leal on 26/11/25.
//

import AVFoundation
import UIKit

class AudioManager {
    static let shared = AudioManager()
    private var players: [String: AVAudioPlayer] = [:]
    
    // Feedback tátil (vibração)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    func playSound(_ name: String) {
        // Se o player já existe, toca. Se não, cria.
        if let player = players[name] {
            player.currentTime = 0
            player.play()
        } else {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                player.play()
                players[name] = player
            } catch { print("Erro som: \(error)") }
        }
    }
    
    func hapticTap() {
        impactGenerator.impactOccurred()
    }
    
    func hapticSuccess() {
        notificationGenerator.notificationOccurred(.success)
    }
    
    func hapticError() {
        notificationGenerator.notificationOccurred(.error)
    }
}
