import AVFoundation
import MediaPlayer

@Observable
final class AudioPlayerManager: NSObject {
    var playingURL: URL?
    private var player: AVAudioPlayer?

    override init() {
        super.init()
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self, let url = playingURL else { return .commandFailed }
            play(url: url)
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if let url = playingURL { togglePlay(url) }
            return .success
        }
    }

    func togglePlay(_ url: URL) {
        if playingURL == url {
            stop()
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
        updateNowPlaying()
    }

    private func stop() {
        player?.stop()
        player = nil
        playingURL = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func updateNowPlaying() {
        guard let url = playingURL, let player else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: url.deletingPathExtension().lastPathComponent,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingURL = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
