# YouTube共有メニューからのURL取り込み - 実装計画書

前提: [requirements.md](requirements.md)・[design.md](design.md) を参照。

###### この文書の役割（重要）

この`docs/`配下の3文書は、このタスクの「状態を書き出した記憶」として運用する。作業開始時、AIはこの3文書を読み込んでから提案・実装を行う。実装中に仕様・設計・進捗が変わった場合、AIは該当箇所を自分で書き換えて最新に保ち、変更した旨をユーザーに報告する。

###### 現在の状態

- **フェーズ**: 完了（実機確認済み・[PR #18](https://github.com/fukurose-jun02/TubeAudio/pull/18)マージ待ち）
- **最終更新**: 2026-10-27
- **関連**: [Issue #17](https://github.com/fukurose-jun02/TubeAudio/issues/17)
- **次にやること**: なし（PR #18のマージ後、本機能はクローズ）
- 前の機能（サーバー自動起動、Issue #12・#14）の文書は `docs/archive/2026-09_サーバー自動起動/` に退避済み

###### 役割分担

| タスク | 担当 | 状態 |
|---|---|---|
| Issue作成 | AI | 完了（#17） |
| 開発文書の作成（既存docsはarchiveへ退避） | AI | 完了 |
| 拡張機能ターゲットの追加（pbxproj・Info.plist・entitlements） | AI | 完了 |
| 共有拡張のコード（URL抽出・判定・保存・表示） | AI | 完了 |
| アプリ側の受け取り処理（ContentView・SharedURLInbox） | AI | 完了 |
| バージョン1.09への更新、READMEの更新 | AI | 完了 |
| Simulatorでビルド・受け取り処理の確認 | AI | 完了（受け取りと取得まで確認。Simulatorの共有メニュー操作は不安定なため未確認。URL判定は単体で9ケース確認） |
| PR作成 | AI | 完了 |
| 実機にインストールし、YouTubeの共有から動作確認 | ユーザー | 完了（ビルド・インストール、共有メニューへの表示、「追加しました」の表示、URL入力と動画情報の取得の4点を確認。無料のApple IDでApp Groupと拡張機能が使えることも確認） |
| Xcodeで署名（Signing）の設定が必要な場合の対応 | ユーザー | 不要だった |
| PRレビュー・マージ | ユーザー | 未着手 |

###### 実装ステップ

1. ブランチ`feature/17-share-extension`を作る
2. 拡張機能のファイル（`ShareViewController.swift`、`Info.plist`、entitlements）を作る
3. `project.pbxproj`に拡張機能ターゲット・同梱設定・権限ファイル指定を追加し、バージョンを1.09にする
4. `SharedURLInbox.swift`と`ContentView.swift`を変更する
5. Simulator用にビルドし、保管場所へURLを書いた状態での受け取りを確認する
6. `ios/README.md`を更新し、PRを作る
7. ユーザーが実機で確認し、結果に応じてこの文書を完了状態へ更新する

###### 確認のポイント（実機）

- 無料のApple IDでApp Groupと拡張機能が署名・インストールできるか
- YouTubeアプリの共有メニューに「TubeAudio」が出るか（出ない場合は「その他」で有効化）
- 共有後にアプリを開くと、URLが入り動画情報が表示されるか
