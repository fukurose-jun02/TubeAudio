import Foundation

struct AudioMetadata: Codable {
    var channel: String
    var duration: Double
    var uploadDate: String
    var viewCount: Int
    var channelIconURL: String?
}

/// 変換時に取得した動画メタデータ（チャンネル名・再生時間・投稿日・再生回数・チャンネル画像）を
/// ファイル名をキーにUserDefaultsへ永続化する。
enum LibraryMetadataStore {
    private static let key = "libraryMetadata"

    static func metadata(for url: URL) -> AudioMetadata? {
        all()[url.lastPathComponent]
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
