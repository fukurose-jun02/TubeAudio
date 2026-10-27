import Foundation

// 共有拡張機能（TubeAudioShare）が書き込んだURLを受け取る。
// appGroupID と pendingKey は TubeAudioShare/ShareViewController.swift と同じ値にすること（変更時は両方を直す）
enum SharedURLInbox {
    private static let appGroupID = "group.com.fukurose.TubeAudio"
    private static let pendingKey = "pendingSharedURL"

    // 受け取り済みのURLを1つ取り出し、保管場所からは消す（同じURLが再起動のたびに入らないようにする）
    static func take() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let url = defaults.string(forKey: pendingKey) else { return nil }
        defaults.removeObject(forKey: pendingKey)
        return url
    }
}
