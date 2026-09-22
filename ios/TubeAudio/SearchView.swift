import SwiftUI

struct SearchView: View {
    @Environment(APIClient.self) var api
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var phase: Phase = .idle
    @State private var progress: Double = 0
    @State private var progressLabel = ""
    @State private var convertingTitle = ""
    @State private var errorMessage = ""

    enum Phase { case idle, searching, results, converting, done, error }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                switch phase {
                case .idle:
                    ContentUnavailableView(
                        "動画を検索",
                        systemImage: "magnifyingglass",
                        description: Text("キーワードを入力してYouTube動画を探しましょう")
                    )
                    .frame(maxHeight: .infinity)
                case .searching:
                    ProgressView("検索中...").frame(maxHeight: .infinity)
                case .results:
                    if results.isEmpty {
                        ContentUnavailableView.search
                            .frame(maxHeight: .infinity)
                    } else {
                        resultList
                    }
                case .converting:
                    convertingView.frame(maxHeight: .infinity)
                case .done:
                    doneView.frame(maxHeight: .infinity)
                case .error:
                    errorView.frame(maxHeight: .infinity)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("検索")
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("キーワードで検索", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await runSearch() } }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button("検索") { Task { await runSearch() } }
                .buttonStyle(.borderedProminent)
                .disabled(query.isEmpty || phase == .searching || phase == .converting)
        }
        .padding()
    }

    private var resultList: some View {
        List(results) { result in
            Button {
                Task { await startConvert(for: result) }
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: result.thumbnail)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: { Color(.systemGray5) }
                    .frame(width: 100, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title).font(.subheadline).fontWeight(.semibold).lineLimit(2)
                            .foregroundStyle(.primary)
                        Text(result.channel).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }

    private var convertingView: some View {
        VStack(spacing: 12) {
            Text(convertingTitle).font(.subheadline).fontWeight(.semibold).multilineTextAlignment(.center)
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
        .padding()
    }

    private var doneView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44)).foregroundStyle(.green)
            Text(convertingTitle)
                .font(.subheadline).fontWeight(.semibold).multilineTextAlignment(.center)
            Text("ライブラリに保存されました")
                .font(.caption).foregroundStyle(.secondary)
            Button("別のキーワードで検索") { resetToResults() }.buttonStyle(.bordered)
        }
        .padding()
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36)).foregroundStyle(.red)
            Text(errorMessage)
                .font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            Button("もう一度試す") { resetToResults() }.buttonStyle(.bordered)
        }
        .padding()
    }

    private func runSearch() async {
        guard !query.isEmpty else { return }
        phase = .searching
        do {
            results = try await api.search(query: query)
            phase = .results
        } catch {
            errorMessage = "検索に失敗しました。\nMacのサーバーが起動しているか確認してください。\n\(error.localizedDescription)"
            phase = .error
        }
    }

    private func startConvert(for result: SearchResult) async {
        convertingTitle = result.title
        phase = .converting
        progress = 0
        progressLabel = "変換を開始しています..."
        do {
            let videoInfo = try? await api.fetchInfo(url: result.url)
            let jobId = try await api.startConvert(url: result.url, format: "m4a", quality: "192")
            try await pollUntilDone(jobId: jobId, channelIcon: videoInfo?.channel_icon)
        } catch {
            errorMessage = error.localizedDescription
            phase = .error
        }
    }

    private func pollUntilDone(jobId: String, channelIcon: String?) async throws {
        let labels = ["queued": "待機中...", "starting": "開始中...", "downloading": "ダウンロード中...", "converting": "変換中..."]
        while true {
            try await Task.sleep(nanoseconds: 800_000_000)
            let status = try await api.pollStatus(jobId: jobId)
            await MainActor.run {
                progress = Double(status.progress ?? 0)
                progressLabel = labels[status.status] ?? status.status
            }
            if status.status == "done" {
                let filename = status.filename ?? "audio.m4a"
                let fileURL = try await api.downloadFile(jobId: jobId, filename: filename)
                LibraryMetadataStore.save(
                    AudioMetadata(
                        channel: status.channel ?? "",
                        duration: status.duration ?? 0,
                        uploadDate: status.upload_date ?? "",
                        viewCount: status.view_count ?? 0,
                        channelIconURL: channelIcon
                    ),
                    for: fileURL
                )
                await MainActor.run { phase = .done }
                return
            } else if status.status == "error" {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: status.error ?? "不明なエラー"])
            }
        }
    }

    private func resetToResults() {
        phase = results.isEmpty ? .idle : .results
        progress = 0
        errorMessage = ""
    }
}

#Preview {
    SearchView().environment(APIClient())
}
