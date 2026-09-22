import SwiftUI
import AVFoundation
import UIKit

// MARK: - Main App

struct ContentView: View {
    @State var api = APIClient()

    var body: some View {
        TabView {
            ConvertView()
                .tabItem { Label("変換", systemImage: "arrow.down.circle.fill") }
            SearchView()
                .tabItem { Label("検索", systemImage: "magnifyingglass") }
            LibraryView()
                .tabItem { Label("ライブラリ", systemImage: "music.note.list") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .environment(api)
    }
}

// MARK: - Convert View

struct ConvertView: View {
    @Environment(APIClient.self) var api
    @State private var urlText = ""
    @State private var videoInfo: VideoInfo?
    @State private var selectedFormat = "m4a"
    @State private var selectedQuality = "192"
    @State private var phase: Phase = .idle
    @State private var progress: Double = 0
    @State private var progressLabel = ""
    @State private var downloadedURL: URL?
    @State private var errorMessage = ""

    enum Phase { case idle, fetchingInfo, ready, converting, done, error }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // URL Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUTUBE URL").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("https://www.youtube.com/watch?v=...", text: $urlText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .onSubmit { Task { await fetchInfo() } }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Button("取得") { Task { await fetchInfo() } }
                                .buttonStyle(.borderedProminent)
                                .disabled(urlText.isEmpty || phase == .fetchingInfo)
                        }
                        if phase == .fetchingInfo {
                            HStack { ProgressView(); Text("取得中...").foregroundStyle(.secondary) }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8)

                    // Video Info
                    if let info = videoInfo {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: info.thumbnail)) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Color(.systemGray5) }
                            .frame(width: 100, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(info.title).font(.subheadline).fontWeight(.semibold).lineLimit(2)
                                Text(info.channel).font(.caption).foregroundStyle(.secondary)
                                Text(info.duration_str)
                                    .font(.caption2).padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(.systemGray5)).clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 8)
                    }

                    // Settings
                    if phase == .ready || phase == .done {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("フォーマット").font(.caption).foregroundStyle(.secondary)
                                HStack {
                                    ForEach(["m4a", "mp3"], id: \.self) { fmt in
                                        Button(fmt.uppercased()) { selectedFormat = fmt }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selectedFormat == fmt ? Color.accentColor : Color(.systemGray5))
                                            .foregroundStyle(selectedFormat == fmt ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("品質").font(.caption).foregroundStyle(.secondary)
                                HStack {
                                    ForEach(["128", "192", "256", "320"], id: \.self) { q in
                                        Button("\(q)k") { selectedQuality = q }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(selectedQuality == q ? Color.accentColor : Color(.systemGray5))
                                            .foregroundStyle(selectedQuality == q ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }

                            Button(action: { Task { await startConvert() } }) {
                                Text("変換を開始").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(phase == .converting)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 8)
                    }

                    // Progress
                    if phase == .converting {
                        VStack(spacing: 12) {
                            HStack {
                                Text(progressLabel).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(progress))%").fontWeight(.bold).foregroundStyle(Color.accentColor)
                            }
                            ProgressView(value: progress, total: 100).tint(Color.accentColor)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 8)
                    }

                    // Done
                    if phase == .done, let fileURL = downloadedURL {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44)).foregroundStyle(.green)
                            Text(fileURL.lastPathComponent)
                                .font(.subheadline).fontWeight(.semibold).multilineTextAlignment(.center)
                            Text("ライブラリに保存されました")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("別の動画を変換") { resetApp() }.buttonStyle(.bordered)
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 8)
                    }

                    // Error
                    if phase == .error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 36)).foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                            Button("もう一度試す") { resetApp() }.buttonStyle(.bordered)
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 8)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("TubeAudio")
        }
    }

    func fetchInfo() async {
        guard !urlText.isEmpty else { return }
        phase = .fetchingInfo
        videoInfo = nil
        do {
            videoInfo = try await api.fetchInfo(url: urlText)
            phase = .ready
        } catch {
            errorMessage = "動画情報の取得に失敗しました。\nMacのサーバーが起動しているか確認してください。\n\(error.localizedDescription)"
            phase = .error
        }
    }

    func startConvert() async {
        phase = .converting
        progress = 0
        progressLabel = "変換を開始しています..."
        do {
            let jobId = try await api.startConvert(url: urlText, format: selectedFormat, quality: selectedQuality)
            try await pollUntilDone(jobId: jobId)
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
    }

    func pollUntilDone(jobId: String) async throws {
        let labels = ["queued": "待機中...", "starting": "開始中...", "downloading": "ダウンロード中...", "converting": "変換中..."]
        while true {
            try await Task.sleep(nanoseconds: 800_000_000)
            let status = try await api.pollStatus(jobId: jobId)
            await MainActor.run {
                progress = Double(status.progress ?? 0)
                progressLabel = labels[status.status] ?? status.status
            }
            if status.status == "done" {
                let filename = status.filename ?? "audio.\(selectedFormat)"
                let fileURL = try await api.downloadFile(jobId: jobId, filename: filename)
                LibraryMetadataStore.save(
                    AudioMetadata(
                        channel: status.channel ?? "",
                        duration: status.duration ?? 0,
                        uploadDate: status.upload_date ?? "",
                        viewCount: status.view_count ?? 0,
                        channelIconURL: videoInfo?.channel_icon
                    ),
                    for: fileURL
                )
                await MainActor.run { downloadedURL = fileURL; phase = .done }
                return
            } else if status.status == "error" {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: status.error ?? "不明なエラー"])
            }
        }
    }

    func resetApp() {
        urlText = ""; videoInfo = nil; phase = .idle; progress = 0; downloadedURL = nil; errorMessage = ""
    }
}

// MARK: - Library View

struct LibraryView: View {
    @Environment(AudioPlayerManager.self) var audioPlayer
    @State private var files: [URL] = []
    @State private var modificationDates: [URL: Date] = [:]
    @State private var shareItem: ShareItem?
    @State private var filter: LibraryFilter = .all
    @State private var sortOrder: LibrarySortOrder = .newest

    var body: some View {
        NavigationStack {
            Group {
                if files.isEmpty {
                    ContentUnavailableView("ライブラリが空です", systemImage: "music.note",
                        description: Text("変換タブから音楽を追加しましょう"))
                } else {
                    VStack(spacing: 0) {
                        libraryControls

                        if displayedFiles.isEmpty {
                            ContentUnavailableView(
                                "未再生の音声はありません",
                                systemImage: "checkmark.circle",
                                description: Text("すべての音声を再生済みです")
                            )
                            .frame(maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(displayedFiles, id: \.self) { file in
                                    LibraryRow(
                                        file: file,
                                        onShare: { shareItem = ShareItem(url: file) }
                                    )
                                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            deleteFile(file)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                        Button {
                                            shareItem = ShareItem(url: file)
                                        } label: {
                                            Label("共有", systemImage: "square.and.arrow.up")
                                        }
                                        .tint(Color.accentColor)
                                    }
                                }
                                .onDelete(perform: deleteFiles)
                            }
                            .listStyle(.plain)
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("ライブラリ")
            .onAppear(perform: loadFiles)
            .sheet(item: $shareItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .safeAreaInset(edge: .bottom) {
                if audioPlayer.playingURL != nil {
                    PlaybackBar()
                }
            }
        }
    }

    func loadFiles() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        files = (try? FileManager.default.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ))?
            .filter { ["m4a", "mp3"].contains($0.pathExtension.lowercased()) }
            ?? []
        modificationDates = Dictionary(uniqueKeysWithValues: files.map { file in
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                ?? .distantPast
            return (file, date)
        })
    }

    func deleteFiles(at offsets: IndexSet) {
        let visibleFiles = displayedFiles
        for i in offsets {
            deleteFile(visibleFiles[i], reload: false)
        }
        loadFiles()
    }

    private func deleteFile(_ file: URL, reload: Bool = true) {
        audioPlayer.removePlaybackState(for: file)
        try? FileManager.default.removeItem(at: file)
        LibraryMetadataStore.remove(for: file)
        if reload { loadFiles() }
    }

    private var libraryControls: some View {
        HStack(spacing: 12) {
            Picker("表示", selection: $filter) {
                ForEach(LibraryFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                ForEach(LibrarySortOrder.allCases) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        if order == sortOrder {
                            Label(order.title, systemImage: "checkmark")
                        } else {
                            Text(order.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOrder.title)
                    Image(systemName: "arrow.up.arrow.down")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(minWidth: 84, alignment: .trailing)
            }
            .accessibilityLabel("並び順、\(sortOrder.title)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var displayedFiles: [URL] {
        let filtered = files.filter { file in
            filter == .all || !audioPlayer.hasStarted(file)
        }

        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .newest:
                return modificationDate(for: lhs) > modificationDate(for: rhs)
            case .oldest:
                return modificationDate(for: lhs) < modificationDate(for: rhs)
            case .title:
                return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
        }
    }

    private func modificationDate(for url: URL) -> Date {
        modificationDates[url] ?? .distantPast
    }
}

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case unplayed

    var id: Self { self }
    var title: String { self == .all ? "すべて" : "未再生" }
}

private enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case title

    var id: Self { self }

    var title: String {
        switch self {
        case .newest: "新しい順"
        case .oldest: "古い順"
        case .title: "タイトル順"
        }
    }
}

// MARK: - Formatting Helpers

func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

/// "YYYY-MM-DD"形式の投稿日を、Voicyのライブラリ画面のような相対表記に変換する。
func formatUploadDate(_ isoDate: String) -> String {
    let parser = DateFormatter()
    parser.dateFormat = "yyyy-MM-dd"
    parser.timeZone = TimeZone(identifier: "UTC")
    guard let date = parser.date(from: isoDate) else { return isoDate }

    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return "今日" }
    if calendar.isDateInYesterday(date) { return "昨日" }
    if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days == 2 {
        return "一昨日"
    }

    let display = DateFormatter()
    display.locale = Locale(identifier: "ja_JP")
    display.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year) ? "M月d日" : "yyyy年M月d日"
    return display.string(from: date)
}

/// 再生回数を "8,717" や "1.2万" のようにVoicy風に整形する。
func formatViewCount(_ count: Int) -> String {
    if count >= 10000 {
        return String(format: "%.1f万", Double(count) / 10000)
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
}

// MARK: - Library Row

/// Voicyのライブラリ画面を参考にした、角丸カード形式の1行。
struct LibraryRow: View {
    let file: URL
    let onShare: () -> Void
    @Environment(AudioPlayerManager.self) var audioPlayer

    var body: some View {
        let isPlayingThis = audioPlayer.playingURL == file && audioPlayer.isPlaying
        let meta = LibraryMetadataStore.metadata(for: file)

        HStack(spacing: 14) {
            LibraryArtwork(
                channelIconURL: meta?.channelIconURL,
                channelName: meta?.channel ?? "",
                progress: audioPlayer.fractionCompleted(for: file)
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(file.deletingPathExtension().lastPathComponent)
                    .font(.subheadline).fontWeight(.semibold).lineLimit(2)
                if let meta {
                    if !meta.channel.isEmpty {
                        Text(meta.channel)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill").font(.system(size: 8))
                            Text(formatDuration(meta.duration))
                        }
                        if !meta.uploadDate.isEmpty {
                            Text(formatUploadDate(meta.uploadDate))
                        }
                        if meta.viewCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "headphones").font(.system(size: 9))
                                Text("\(formatViewCount(meta.viewCount))回再生")
                            }
                        }
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(file.pathExtension.uppercased())
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button {
                audioPlayer.togglePlay(file)
            } label: {
                Image(systemName: isPlayingThis ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(isPlayingThis ? Color.orange : Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(file.deletingPathExtension().lastPathComponent)を\(isPlayingThis ? "一時停止" : "再生")"
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onShare) {
                Label("共有", systemImage: "square.and.arrow.up")
            }
        }
    }
}

// MARK: - Library Artwork

/// YouTubeチャンネルの画像を発信者アイコンとして表示し、その周囲に再生進捗を重ねる。
/// 古い保存データなど画像がない場合はチャンネル名の頭文字を表示する。
struct LibraryArtwork: View {
    let channelIconURL: String?
    let channelName: String
    let progress: Double

    var size: CGFloat = 60
    var ringWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            AsyncImage(url: channelIconURL.flatMap(URL.init(string:))) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    fallbackArtwork
                }
            }
            .frame(width: size - ringWidth * 2, height: size - ringWidth * 2)
            .clipShape(Circle())

            Circle()
                .stroke(Color(.systemGray4), lineWidth: ringWidth)
            if progress > 0 {
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var fallbackArtwork: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.75), Color.purple.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(channelInitial)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var channelInitial: String {
        let trimmed = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }
}

// MARK: - Playback Bar

struct PlaybackBar: View {
    @Environment(AudioPlayerManager.self) var audioPlayer
    @State private var isDragging = false
    @State private var dragTime: Double = 0

    var body: some View {
        if let url = audioPlayer.playingURL {
            let meta = LibraryMetadataStore.metadata(for: url)

            VStack(spacing: 7) {
                HStack(spacing: 10) {
                    LibraryArtwork(
                        channelIconURL: meta?.channelIconURL,
                        channelName: meta?.channel ?? "",
                        progress: audioPlayer.fractionCompleted(for: url),
                        size: 42,
                        ringWidth: 2.5
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.deletingPathExtension().lastPathComponent)
                            .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                        if let channel = meta?.channel, !channel.isEmpty {
                            Text(channel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Button {
                        audioPlayer.seek(to: max(audioPlayer.currentTime - 15, 0))
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("15秒戻る")
                    Button {
                        audioPlayer.togglePlay(url)
                    } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(audioPlayer.isPlaying ? "一時停止" : "再生")
                }
                HStack(spacing: 8) {
                    Text(formatDuration(isDragging ? dragTime : audioPlayer.currentTime))
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    Slider(
                        value: Binding(
                            get: { isDragging ? dragTime : audioPlayer.currentTime },
                            set: { newValue in
                                dragTime = newValue
                                if !isDragging {
                                    audioPlayer.seek(to: newValue)
                                }
                            }
                        ),
                        in: 0...max(audioPlayer.duration, 1),
                        onEditingChanged: { editing in
                            if editing {
                                dragTime = audioPlayer.currentTime
                                isDragging = true
                            } else {
                                isDragging = false
                                audioPlayer.seek(to: dragTime)
                            }
                        }
                    )
                    .tint(Color.accentColor)
                    .accessibilityLabel("再生位置")
                    Text(formatDuration(audioPlayer.duration))
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.bar)
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(APIClient.self) var api

    var body: some View {
        @Bindable var api = api
        NavigationStack {
            Form {
                Section("サーバー接続") {
                    HStack {
                        Text("Mac の IP")
                        Spacer()
                        TextField("http://192.168.x.x:5001", text: $api.serverURL)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.secondary)
                    }
                    Text("Mac で `python3 app.py` を起動し、同じWiFiに接続してください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("使い方") {
                    Label("URLを貼り付けて「取得」", systemImage: "1.circle.fill")
                    Label("フォーマット・品質を選択", systemImage: "2.circle.fill")
                    Label("「変換を開始」でダウンロード", systemImage: "3.circle.fill")
                    Label("ライブラリタブで再生・共有", systemImage: "4.circle.fill")
                }
                Section("バージョン情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersionString).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
        }
    }

    private var appVersionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Ver.\(shortVersion)"
    }
}

#Preview {
    ContentView()
}
