import SwiftUI
import AVFoundation

// MARK: - Main App

struct ContentView: View {
    @State var api = APIClient()

    var body: some View {
        TabView {
            ConvertView()
                .tabItem { Label("変換", systemImage: "arrow.down.circle.fill") }
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
    @State private var files: [URL] = []
    @State private var playingURL: URL?
    @State private var player: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            Group {
                if files.isEmpty {
                    ContentUnavailableView("ライブラリが空です", systemImage: "music.note",
                        description: Text("変換タブから音楽を追加しましょう"))
                } else {
                    List {
                        ForEach(files, id: \.self) { file in
                            HStack {
                                Image(systemName: playingURL == file ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(playingURL == file ? Color.orange : Color.accentColor)
                                VStack(alignment: .leading) {
                                    Text(file.deletingPathExtension().lastPathComponent)
                                        .font(.subheadline).fontWeight(.medium).lineLimit(1)
                                    Text(file.pathExtension.uppercased())
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                ShareLink(item: file) {
                                    Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { togglePlay(file) }
                        }
                        .onDelete(perform: deleteFiles)
                    }
                }
            }
            .navigationTitle("ライブラリ")
            .onAppear(perform: loadFiles)
        }
    }

    func loadFiles() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        files = (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil))?
            .filter { ["m4a", "mp3"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }

    func togglePlay(_ url: URL) {
        if playingURL == url {
            player?.stop(); playingURL = nil
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play(); playingURL = url
        }
    }

    func deleteFiles(at offsets: IndexSet) {
        for i in offsets { try? FileManager.default.removeItem(at: files[i]) }
        loadFiles()
    }
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
            }
            .navigationTitle("設定")
        }
    }
}

#Preview {
    ContentView()
}
