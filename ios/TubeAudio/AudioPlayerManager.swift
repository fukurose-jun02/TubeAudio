import AVFoundation
import MediaPlayer

private struct PlaybackProgress: Codable {
    var position: TimeInterval
    var duration: TimeInterval
    var isFinished: Bool
}

@Observable
final class AudioPlayerManager: NSObject {
    var playingURL: URL?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private let progressKey = "playbackProgress"

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
        saveProgress(position: time, duration: duration, isFinished: false, for: url)
        updateNowPlaying()
    }

    /// 0...1の再生進捗率。再生中のファイルはライブ値を、それ以外は保存済みの値を返す。
    func fractionCompleted(for url: URL) -> Double {
        if url == playingURL, duration > 0 {
            return min(max(currentTime / duration, 0), 1)
        }
        guard let entry = loadProgressStore()[url.lastPathComponent], entry.duration > 0 else { return 0 }
        return entry.isFinished ? 1 : min(max(entry.position / entry.duration, 0), 1)
    }

    /// 再生位置に関係なく、一度でも再生を開始したファイルかを返す。
    func hasStarted(_ url: URL) -> Bool {
        playingURL == url || loadProgressStore()[url.lastPathComponent] != nil
    }

    /// ファイル削除前に再生を停止し、保存済みの再生状態も破棄する。
    func removePlaybackState(for url: URL) {
        if playingURL == url {
            stop(finished: false)
        }
        clearProgress(for: url)
    }

    func clearProgress(for url: URL) {
        var store = loadProgressStore()
        store.removeValue(forKey: url.lastPathComponent)
        saveProgressStore(store)
    }

    private func play(url: URL) {
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return }
        newPlayer.currentTime = loadPosition(for: url)
        guard newPlayer.prepareToPlay() else { return }

        if playingURL != nil {
            stop(finished: false)
        }

        player = newPlayer
        newPlayer.delegate = self
        playingURL = url
        currentTime = newPlayer.currentTime
        duration = newPlayer.duration
        isPlaying = newPlayer.play()
        if isPlaying {
            startTimer()
        } else {
            resetActivePlayer()
            return
        }
        updateNowPlaying()
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
        if let url = playingURL {
            saveProgress(position: currentTime, duration: duration, isFinished: false, for: url)
        }
        updateNowPlaying()
    }

    private func resume() {
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    private func stop(finished: Bool) {
        if let url = playingURL {
            saveProgress(position: finished ? duration : currentTime, duration: duration, isFinished: finished, for: url)
        }
        resetActivePlayer()
    }

    /// 保存済み進捗を変更せず、実行中のプレイヤー状態だけを破棄する。
    private func resetActivePlayer() {
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
        saveProgress(position: currentTime, duration: duration, isFinished: false, for: url)
        updateNowPlaying()
    }

    private func loadPosition(for url: URL) -> TimeInterval {
        let entry = loadProgressStore()[url.lastPathComponent]
        return entry?.isFinished == true ? 0 : (entry?.position ?? 0)
    }

    private func loadProgressStore() -> [String: PlaybackProgress] {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let store = try? JSONDecoder().decode([String: PlaybackProgress].self, from: data) else { return [:] }
        return store
    }

    private func saveProgressStore(_ store: [String: PlaybackProgress]) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: progressKey)
    }

    private func saveProgress(position: TimeInterval, duration: TimeInterval, isFinished: Bool, for url: URL) {
        var store = loadProgressStore()
        store[url.lastPathComponent] = PlaybackProgress(position: position, duration: duration, isFinished: isFinished)
        saveProgressStore(store)
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
        stop(finished: flag)
    }
}
