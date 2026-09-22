# サーバー起動とMac接続先設定の自動化 - 設計書

前提: [requirements.md](requirements.md) の要件・決定事項に基づく。

###### 全体構成

```
Macログイン
   │  launchd（RunAtLoad + KeepAlive）
   ▼
python3 server/app.py が自動起動・自動再起動
   │  0.0.0.0:5001 で待受（Bonjour/mDNSで <ホスト名>.local として名前解決可能）
   ▼
iPhone（TubeAudioアプリ）
   │  デフォルト接続先: http://<Macのホスト名>.local:5001
   ▼
既存の変換・検索・ライブラリ機能（変更なし）
```

macOSは標準でBonjour（mDNS）が有効なため、追加のサーバー側実装なしに`<ホスト名>.local`での名前解決が可能（本セッションで`ping fukuroseatsushinomacbook-air.local`により動作確認済み）。iOS側もBonjour解決に標準対応している。

###### 自動起動（launchd LaunchAgent）

**新規ファイル: `server/com.fukurose.tubeaudio.plist`**（テンプレートとしてリポジトリに含め、インストール時にユーザーのホームディレクトリ配下へコピーする）

- `Label`: `com.fukurose.tubeaudio`
- `ProgramArguments`: `[<python3の絶対パス>, <server/app.pyの絶対パス>]`
- `WorkingDirectory`: `server/`ディレクトリの絶対パス（`downloads/`等の相対パス解決のため）
- `RunAtLoad`: `true`（ログイン時に自動起動）
- `KeepAlive`: `true`（プロセスが終了したら自動再起動）
- `StandardOutPath` / `StandardErrorPath`: `server/run.log`（gitignore対象、`server/README.md`にログの見方を記載）

**インストール手順（`server/setup.sh`に追記）**

1. plistテンプレート内のプレースホルダ（python3パス・プロジェクトパス）を実際の環境の値に置換
2. `~/Library/LaunchAgents/com.fukurose.tubeaudio.plist`にコピー
3. `launchctl load -w ~/Library/LaunchAgents/com.fukurose.tubeaudio.plist` で登録・起動

**アンインストール手順（`server/README.md`に記載）**

```bash
launchctl unload ~/Library/LaunchAgents/com.fukurose.tubeaudio.plist
rm ~/Library/LaunchAgents/com.fukurose.tubeaudio.plist
```

###### 接続先の安定化（iOS側）

**変更ファイル: `ios/TubeAudio/APIClient.swift`**

- `serverURL`の初期値（`UserDefaults`未設定時のデフォルト）を、固定IPアドレスからMacのBonjourホスト名ベースのURLに変更する
  - 例: `http://fukuroseatsushinomacbook-air.local:5001`
- 既存ユーザー（すでにIPアドレスを設定済み）の`UserDefaults`には影響しない。あくまで「初期値」のみの変更
- `ios/README.md`または`SettingsView`のヘルプ文言に、IPアドレスの代わりに`.local`ホスト名が使える旨を追記する

###### 動作しなくなるケースと対処

- ルーター・WiFi環境によってはmDNS（Bonjour）が制限されている場合がある。その場合は従来どおりIPアドレスを手動設定すれば動作する（設定画面のテキストフィールドはIP・ホスト名どちらも入力可能な自由記述のまま変更しない）
- Macがスリープ状態だとlaunchdで起動したサーバーにも到達できない。これは今回のスコープ外（Macを起こしておく必要がある旨をREADMEに明記する）

###### 影響範囲まとめ

| ファイル | 変更内容 |
|---|---|
| `server/com.fukurose.tubeaudio.plist`（新規） | launchd用のLaunchAgent定義テンプレート |
| `server/setup.sh` | LaunchAgentのインストール手順を追加 |
| `server/.gitignore` | `run.log`を追加 |
| `server/README.md` | 自動起動のインストール・アンインストール手順、ログの見方を追記 |
| `ios/TubeAudio/APIClient.swift` | デフォルト接続先をBonjourホスト名に変更 |
