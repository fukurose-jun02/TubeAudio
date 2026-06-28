//
//  TubeAudioApp.swift
//  TubeAudio
//
//  Created by 袋瀬淳 on 2026/06/19.
//

import SwiftUI
import AVFoundation

@main
struct TubeAudioApp: App {
    @State private var audioPlayer = AudioPlayerManager()

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(audioPlayer)
        }
    }
}
