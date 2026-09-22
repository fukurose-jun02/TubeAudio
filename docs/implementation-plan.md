# YouTube動画キーワード検索機能 - 実装計画書

前提: [requirements.md](requirements.md)・[design.md](design.md) を参照。

###### この文書の役割（重要）

この`docs/`配下の3文書は、このタスクの「状態を書き出した記憶」として運用する。

- 作業開始時、AIはこの3文書（requirements.md / design.md / implementation-plan.md）を読み込んでから提案・実装を行う
- 実装中に仕様・設計・進捗が変わった場合、AIは該当箇所（特に下記「現在の状態」とタスク一覧のチェック）を自分で書き換えて最新に保ち、変更した旨をユーザーに報告する
- これにより、別セッション・別AIが引き継いでも、この文書を読むだけで「どこまで終わっていて、次に何をするか」が分かる状態を維持する

###### 現在の状態

- **フェーズ**: 実装完了・mainにマージ済み（[PR #10](https://github.com/fukurose-jun02/TubeAudio/pull/10)、2026-09-22マージ）
- **最終更新**: 2026-09-22
- **次にやること**: 実機（Mac+iPhone同一WiFi）での最終確認

###### 役割分担

| タスク | 担当 | 状態 |
|---|---|---|
| Google Cloud ConsoleでYouTube Data API v3を有効化し、APIキーを取得する | ユーザー | 完了 |
| Macサーバーの起動環境に`YOUTUBE_API_KEY`を設定する | ユーザー | 完了（`server/.env`に設定済み） |
| `server/app.py`に`/api/search`エンドポイントを実装する | AI | 完了 |
| `server/README.md`にAPIエンドポイント・環境変数を追記する | AI | 完了 |
| `ios/TubeAudio/APIClient.swift`に検索メソッドを追加する | AI | 完了 |
| `ios/TubeAudio/SearchView.swift`を新規作成する | AI | 完了 |
| `ios/TubeAudio/ContentView.swift`のタブ構成を更新する | AI | 完了 |
| iOS Simulatorでビルド・動作確認する | AI | 完了（検索→タップ→変換→ライブラリ保存まで確認） |
| PRレビュー・マージ | ユーザー | 完了（[PR #10](https://github.com/fukurose-jun02/TubeAudio/pull/10)、2026-09-22マージ） |
| 実機（Mac+iPhone同一WiFi）での検索→変換→ライブラリ保存の一連確認 | ユーザー＋AI | 未着手 |

###### 実装ステップ詳細

1. **サーバー: 検索エンドポイント実装**
   - `os.environ.get("YOUTUBE_API_KEY")`を読み込み、未設定時は`/api/search`が`503`を返すようにする
   - `requests`（未導入なら`requirements.txt`に追加）でYouTube Data API v3を呼び出す
   - レスポンスを`design.md`記載のJSON形式に整形する
2. **サーバー: ドキュメント更新**
   - `server/README.md`のAPIエンドポイント表・セットアップ手順に環境変数の設定方法を追記する
3. **iOS: APIClient拡張**
   - `SearchResult`構造体、`search(query:)`メソッドを追加
   - サーバーエラー時、レスポンスの`error`メッセージをそのまま`errorMessage`として使えるようにする
4. **iOS: 検索タブUI**
   - `SearchView.swift`を新規作成し、`ContentView`の`TabView`に追加
   - 検索結果タップで即座に変換を開始する処理を実装する（`ConvertView`の変換ロジックとの重複を許容するか共通化するかは実装時に判断し、この文書に結果を追記する）
5. **動作確認**
   - `xcodebuild ... -sdk iphonesimulator ... build`でビルド成功を確認
   - サーバーを起動し、`curl "http://localhost:5001/api/search?q=test"`でレスポンスを確認
   - 実機で検索→タップ→変換→ライブラリ保存までを確認

###### ユーザー側タスク（着手前に必要な準備）

1. [Google Cloud Console](https://console.cloud.google.com/)でプロジェクトを作成（または既存のものを使用）
2. 「APIとサービス」→「ライブラリ」から **YouTube Data API v3** を有効化
3. 「認証情報」からAPIキーを発行（用途を絞りたい場合はYouTube Data API v3への制限を推奨）
4. 発行したAPIキーをAIに渡すか、Macのサーバー起動環境（例: `server/.env`や起動シェルの`export YOUTUBE_API_KEY=...`）に設定する

###### 完了条件（Definition of Done）

- [x] `requirements.md`の受け入れ基準をすべて満たす（Simulatorで確認済み）
- [x] サーバー・iOS双方でビルド／起動確認済み
- [ ] `logs/`に作業ログを記録し、判断ポイントがあれば`judgments.jsonl`に追記
- [x] 本ワークスペースルールに従い、コード変更はPR経由でmainにマージする（[PR #10](https://github.com/fukurose-jun02/TubeAudio/pull/10)、2026-09-22マージ済み）
- [x] `docs/`3文書を実装後の最終状態に更新する
