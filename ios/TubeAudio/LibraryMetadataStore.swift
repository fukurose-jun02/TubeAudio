import Foundation

/// ライブラリの分類。保存データにカテゴリがない音声は、すべてラジオとして扱う。
enum AudioCategory: String, Codable, CaseIterable, Identifiable {
    case radio
    case bgm

    var id: Self { self }
    var title: String { self == .radio ? "ラジオ" : "BGM" }
    var other: AudioCategory { self == .radio ? .bgm : .radio }
}

struct AudioMetadata: Codable {
    var channel: String
    var duration: Double
    var uploadDate: String
    var viewCount: Int
    var channelIconURL: String?
    var category: AudioCategory?
}

/// 変換時に取得した動画メタデータ（チャンネル名・再生時間・投稿日・再生回数・チャンネル画像）を
/// ファイル名をキーにUserDefaultsへ永続化する。
enum LibraryMetadataStore {
    private static let key = "libraryMetadata"

    static func metadata(for url: URL) -> AudioMetadata? {
        all()[url.lastPathComponent]
    }

    static func category(for url: URL) -> AudioCategory {
        metadata(for: url)?.category ?? .radio
    }

    /// メタデータがない古い音声でも移せるよう、なければ空の値を作ってカテゴリだけ入れる
    static func setCategory(_ category: AudioCategory, for url: URL) {
        var store = all()
        var metadata = store[url.lastPathComponent]
            ?? AudioMetadata(channel: "", duration: 0, uploadDate: "", viewCount: 0, channelIconURL: nil, category: nil)
        metadata.category = category
        store[url.lastPathComponent] = metadata
        saveAll(store)
    }

    static func save(_ metadata: AudioMetadata, for url: URL) {
        var store = all()
        store[url.lastPathComponent] = metadata
        saveAll(store)
    }

    static func remove(for url: URL) {
        var store = all()
        store.removeValue(forKey: url.lastPathComponent)
        saveAll(store)
    }

    private static func all() -> [String: AudioMetadata] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let store = try? JSONDecoder().decode([String: AudioMetadata].self, from: data) else { return [:] }
        return store
    }

    private static func saveAll(_ store: [String: AudioMetadata]) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
