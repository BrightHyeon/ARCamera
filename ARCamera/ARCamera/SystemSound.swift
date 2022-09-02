//
//  Player.swift
//  ARCamera
//
//  Created by Hyeonsoo Kim on 2022/09/02.
//

import AVFoundation

class SystemSound {
    static let shared = SystemSound()
    
    func playSystemSound(id: SystemSoundID) {
        let systemSoundID = id
        AudioServicesPlaySystemSound(systemSoundID)
    }
}
