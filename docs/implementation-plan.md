# サーバー起動とMac接続先設定の自動化 - 実装計画書

前提: [requirements.md](requirements.md)・[design.md](design.md) を参照。

###### この文書の役割（重要）

この`docs/`配下の3文書は、このタスクの「状態を書き出した記憶」として運用する。作業開始時、AIはこの3文書を読み込んでから提案・実装を行う。実装中に仕様・設計・進捗が変わった場合、AIは該当箇所を自分で書き換えて最新に保ち、変更した旨をユーザーに報告する。

###### 現在の状態

- **フェーズ**: 完了（実機確認済み・[PR #13](https://github.com/fukurose-jun02/TubeAudio/pull/13)マージ済み）
- **最終更新**: 2026-09-22
- **次にやること**: なし。本機能はクローズ

###### 役割分担

| タスク | 担当 | 状態 |
|---|---|---|
| `server/com.fukurose.tubeaudio.plist`テンプレートを作成する | AI | 完了 |
| `server/setup.sh`にLaunchAgentインストール手順を追加する | AI | 完了 |
| `server/README.md`に自動起動・アンインストール手順を追記する | AI | 完了 |
| `ios/TubeAudio/APIClient.swift`のデフォルト接続先をBonjourホスト名に変更する | AI | 完了 |
| 実際に`~/Library/LaunchAgents/`へplistを配置し`launchctl load`で登録する | AI（ユーザー許可のもと実行） | 完了（このMacに登録済み） |
| サーバーの自動起動・自動再起動を確認する | AI | 完了（`kill -9`後の自動再起動をPID変化で確認） |
| iPhoneから`.local`ホスト名でアクセスできることを確認する | ユーザー | 未確認（Mac自身からの`curl`とSimulatorでは確認済み。実機iPhoneでの確認は任意） |
| PRレビュー・マージ | ユーザー | 完了（[PR #13](https://github.com/fukurose-jun02/TubeAudio/pull/13)、2026-09-22マージ） |

###### 実装ステップ詳細

1. **LaunchAgent plistテンプレート作成**
   - `server/com.fukurose.tubeaudio.plist`に、このMac環境のpython3絶対パス・プロジェクト絶対パスを埋め込んで作成する
2. **setup.sh更新**
   - LaunchAgentのインストール手順（コピー＋`launchctl load -w`）を追記する
3. **README更新**
   - `server/README.md`に自動起動の仕組み・ログの場所（`server/run.log`）・アンインストール手順を追記する
4. **iOS側デフォルト接続先変更**
   - `APIClient.swift`の初期値をこのMacのBonjourホスト名（`http://fukuroseatsushinomacbook-air.local:5001`）に変更する
5. **実際の登録・動作確認**
   - `~/Library/LaunchAgents/com.fukurose.tubeaudio.plist`にコピーし`launchctl load -w`で登録
   - `launchctl kickstart`等でプロセスを再起動させ、自動再起動することを確認
   - `curl http://<ホスト名>.local:5001/`で疎通確認

###### ユーザー側タスク

- 実機での最終確認：Macを再ログインしてもサーバーが起動していること、iPhoneからアプリを使えることを確認する

###### 完了条件（Definition of Done）

- [ ] `requirements.md`の受け入れ基準をすべて満たす
- [ ] `logs/`に作業ログを記録し、判断ポイントがあれば`judgments.jsonl`に追記
- [ ] コード変更（iOS・server）はPR経由でmainにマージする
- [ ] `docs/`3文書を実装後の最終状態に更新する
