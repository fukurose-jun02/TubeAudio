import AVFoundation
import MediaPlayer

@Observable
final class AudioPlayerManager: NSObject {
    var playingURL: URL?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private let positionsKey = "playbackPositions"

    override init() {
        super.init()
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .commandFailed }
            self.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .commandFailed }
            self.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let url = self.playingURL else { return .commandFailed }
            self.togglePlay(url)
            return .success
        }
    }

    func togglePlay(_ url: URL) {
        if playingURL == url {
            isPlaying ? pause() : resume()
        } else {
            play(url: url)
        }
    }

    func seek(to time: TimeInterval) {
        guard let player, let url = playingURL else { return }
        player.currentTime = time
        currentTime = time
        savePosition(time, for: url)
        updateNowPlaying()
    }

    private func play(url: URL) {
        player?.stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.currentTime = loadPosition(for: url)
        player = newPlayer
        player?.delegate = self
        player?.play()
        playingURL = url
        isPlaying = true
        currentTime = newPlayer.currentTime
        duration = newPlayer.duration
        startTimer()
        updateNowPlaying()
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        if let url = playingURL {
            savePosition(currentTime, for: url)
        }
        updateNowPlaying()
    }

    private func resume() {
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    private func stop() {
        if let url = playingURL {
            clearPosition(for: url)
        }
        player?.stop()
        player = nil
        playingURL = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func startTimer() {
        stopTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func tick() {
        guard let player, let url = playingURL else { return }
        currentTime = player.currentTime
        duration = player.duration
        savePosition(currentTime, for: url)
        updateNowPlaying()
    }

    private func loadPosition(for url: URL) -> TimeInterval {
        let positions = UserDefaults.standard.dictionary(forKey: positionsKey) as? [String: TimeInterval] ?? [:]
        return positions[url.lastPathComponent] ?? 0
    }

    private func savePosition(_ time: TimeInterval, for url: URL) {
        var positions = UserDefaults.standard.dictionary(forKey: positionsKey) as? [String: TimeInterval] ?? [:]
        positions[url.lastPathComponent] = time
        UserDefaults.standard.set(positions, forKey: positionsKey)
    }

    private func clearPosition(for url: URL) {
        var positions = UserDefaults.standard.dictionary(forKey: positionsKey) as? [String: TimeInterval] ?? [:]
        positions.removeValue(forKey: url.lastPathComponent)
        UserDefaults.standard.set(positions, forKey: positionsKey)
    }

    private func updateNowPlaying() {
        guard let url = playingURL, let player else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: url.deletingPathExtension().lastPathComponent,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}
