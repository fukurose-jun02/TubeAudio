import AVFoundation
import MediaPlayer

@Observable
final class AudioPlayerManager: NSObject {
    var playingURL: URL?
    private(set) var isPlaying = false
    private var player: AVAudioPlayer?

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

    private func play(url: URL) {
        player?.stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        player = newPlayer
        player?.delegate = self
        player?.play()
        playingURL = url
        isPlaying = true
        updateNowPlaying()
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    private func resume() {
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    private func stop() {
        player?.stop()
        player = nil
        playingURL = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
