# YouTube動画キーワード検索機能 - 設計書

前提: [requirements.md](requirements.md) の要件・決定事項に基づく。

###### 全体構成

```
iOS App (SearchView)
   │  GET /api/search?q=キーワード
   ▼
Flask Server (app.py)
   │  YouTube Data API v3: search.list （APIキーはサーバー環境変数）
   ▼
YouTube Data API v3
```

- 既存の変換フロー（`ConvertView` → `/api/info` → `/api/convert` → `/api/status` → `/api/download`）はそのまま流用する
- 検索は「URLを取得する手段」を1つ増やすだけで、変換ロジック自体には手を入れない

###### サーバー側設計（`server/app.py`）

**環境変数**

- `YOUTUBE_API_KEY`: YouTube Data API v3のAPIキー。未設定時は`/api/search`が明確なエラーを返す
- `.env`等での管理も可とするが、リポジトリにはコミットしない（`.gitignore`確認済み・追加が必要なら追記する）

**新規エンドポイント**

```
GET /api/search?q=<キーワード>
```

- YouTube Data API v3 `https://www.googleapis.com/youtube/v3/search` を呼び出す
  - `part=snippet&type=video&maxResults=20&q=<キーワード>&key=<YOUTUBE_API_KEY>`
- レスポンス整形例:

```json
{
  "results": [
    {
      "video_id": "xxxxxxxxxxx",
      "url": "https://www.youtube.com/watch?v=xxxxxxxxxxx",
      "title": "動画タイトル",
      "channel": "チャンネル名",
      "thumbnail": "https://i.ytimg.com/vi/xxxxxxxxxxx/mqdefault.jpg"
    }
  ]
}
```

- `search.list`のレスポンスには再生時間が含まれないため、初期スコープでは再生時間は表示しない（F2の「取得できれば」に対応。必要になれば`videos.list`を追加で1回呼び、`contentDetails.duration`を合成する拡張を将来検討）
- エラーハンドリング:
  - `YOUTUBE_API_KEY`未設定 → `503`、`{"error": "サーバーにYouTube APIキーが設定されていません"}`
  - Google API側のクォータ超過・エラー → `502`、Google側のエラーメッセージを含めて返す
  - キーワード未指定 → `400`

###### iOS側設計

**新規ファイル: `ios/TubeAudio/SearchView.swift`**

- `ContentView`の`TabView`に3番目のタブとして追加（変換・検索・ライブラリ・設定の順、または変換の直後）
- 画面構成:
  - 検索バー（`TextField` + 検索ボタン、`onSubmit`対応）
  - 結果一覧（`List`）: サムネイル・タイトル・チャンネル名
  - 状態: `idle` / `searching` / `results` / `empty` / `error`

**タップ時の挙動（F3）**

- 検索結果タップ → 選択した動画の`url`を保持 → `ConvertView`と同等の処理（`fetchInfo` → `startConvert` → ポーリング → ダウンロード → `LibraryMetadataStore.save`）を実行し、進捗を検索タブ内に表示する
- 実装方針: `ConvertView`内の変換ロジック（`fetchInfo`/`startConvert`/`pollUntilDone`）を再利用できるよう、共通処理を小さなヘルパー（例: `ConversionRunner`のような構造体 or 既存関数の外出し）に切り出すか、`SearchView`から`ConvertView`のロジックを直接呼べる形にする。既存の`ConvertView`の実装を壊さないよう、まずは重複実装を許容し、動作確認後に共通化するかを判断する（実装計画で決定）

**APIClient拡張（`ios/TubeAudio/APIClient.swift`）**

```swift
struct SearchResult: Decodable {
    let video_id: String
    let url: String
    let title: String
    let channel: String
    let thumbnail: String
}

func search(query: String) async throws -> [SearchResult] {
    var comps = URLComponents(string: "\(serverURL)/api/search")!
    comps.queryItems = [URLQueryItem(name: "q", value: query)]
    let (data, response) = try await URLSession.shared.data(from: comps.url!)
    // ステータスコードに応じてサーバー側のエラーメッセージをthrowする
    ...
    struct Wrapper: Decodable { let results: [SearchResult] }
    return try JSONDecoder().decode(Wrapper.self, from: data).results
}
```

###### エラー表示方針

- サーバー未起動・APIキー未設定・クォータ超過のいずれも、`ConvertView`と同様に「原因がユーザーに伝わる日本語メッセージ」を表示する（既存の`errorMessage`パターンを踏襲）

###### 影響範囲まとめ

| ファイル | 変更内容 |
|---|---|
| `server/app.py` | `/api/search`エンドポイント追加、`YOUTUBE_API_KEY`読み込み |
| `server/README.md` | APIエンドポイント表に`/api/search`を追記、環境変数の説明を追記 |
| `ios/TubeAudio/APIClient.swift` | `SearchResult`構造体、`search(query:)`メソッド追加 |
| `ios/TubeAudio/SearchView.swift`（新規） | 検索タブのUIとロジック |
| `ios/TubeAudio/ContentView.swift` | `TabView`に検索タブを追加 |
