import UIKit
import SwiftUI
import UniformTypeIdentifiers

// 共有メニューから受け取ったYouTubeのURLを、App Group経由でアプリ本体に渡す拡張機能。
// 通信や変換はしない（拡張機能はメモリ・実行時間の制約が厳しいため）。
// appGroupID と pendingKey は TubeAudio/SharedURLInbox.swift と同じ値にすること（変更時は両方を直す）
private let appGroupID = "group.com.fukurose.TubeAudio"
private let pendingKey = "pendingSharedURL"

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await handleShare() }
    }

    private func handleShare() async {
        let text = await extractSharedText()
        if let url = text.flatMap(Self.youTubeURL(in:)) {
            UserDefaults(suiteName: appGroupID)?.set(url.absoluteString, forKey: pendingKey)
            show(message: "追加しました", detail: "TubeAudioを開くと変換できます", symbol: "checkmark.circle.fill", isSuccess: true)
        } else {
            show(message: "追加できません", detail: "YouTubeのURLを共有してください", symbol: "exclamationmark.triangle.fill", isSuccess: false)
        }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        extensionContext?.completeRequest(returningItems: nil)
    }

    // 共有項目から、URL（優先）またはテキストを文字列として取り出す
    private func extractSharedText() async -> String? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for type in [UTType.url, UTType.plainText] {
            for provider in providers where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                if let item = try? await provider.loadItem(forTypeIdentifier: type.identifier) {
                    if let url = item as? URL { return url.absoluteString }
                    if let string = item as? String { return string }
                }
            }
        }
        return nil
    }

    // テキストの中から最初のYouTube URLを取り出す（説明文とURLが混ざっていても対応）
    static func youTubeURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let links = detector?.matches(in: text, range: range).compactMap(\.url) ?? []
        return links.first { isYouTubeHost($0.host) }
    }

    private static func isYouTubeHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return ["youtube.com", "youtu.be"].contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    private func show(message: String, detail: String, symbol: String, isSuccess: Bool) {
        let content = UIHostingController(rootView: ResultView(message: message, detail: detail, symbol: symbol, isSuccess: isSuccess))
        addChild(content)
        content.view.frame = view.bounds
        content.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        content.view.backgroundColor = .clear
        view.addSubview(content.view)
        content.didMove(toParent: self)
    }
}

private struct ResultView: View {
    let message: String
    let detail: String
    let symbol: String
    let isSuccess: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(isSuccess ? .green : .orange)
            Text(message).font(.headline)
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
