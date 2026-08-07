# TubeAudio iOS

YouTubeの音声をiPhoneでダウンロード・再生できるSwiftUIアプリです。  
Macで動く [YouTube Audio Converter](https://github.com/fukurose-jun02/youtube-audio-converter) サーバーと連携して動作します。

![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![iOS](https://img.shields.io/badge/iOS-26.5+-blue) ![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green)

## 機能

- YouTube URLを貼り付けて動画情報を取得
- M4A / MP3 形式・音質（128〜320kbps）を選んで変換
- 変換進捗のリアルタイム表示
- ライブラリタブで再生・一時停止
- AirDrop・ファイルアプリへの共有

## 画面構成

| タブ | 内容 |
|---|---|
| 変換 | URL入力・フォーマット選択・変換実行 |
| ライブラリ | ダウンロード済みファイルの再生・共有 |
| 設定 | MacサーバーのIPアドレス設定 |

## 必要なもの

- iPhone（iOS 26.5 以上）
- Mac（同じWiFiに接続）
- Mac側で [YouTube Audio Converter](https://github.com/fukurose-jun02/youtube-audio-converter) が起動していること
- Xcode 26.5 以上

## セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/fukurose-jun02/TubeAudio-iOS.git
```

1. `TubeAudio.xcodeproj` を Xcode で開く
2. iPhoneをMacにUSB接続
3. ▶ ボタンでビルド・インストール
4. iPhoneの「設定 → 一般 → VPNとデバイス管理」で証明書を信頼

## 使い方

1. MacでFlaskサーバーを起動（`python3 app.py`）
2. アプリの「設定」タブでMacのIPアドレスを確認（デフォルト: `http://192.168.1.6:5001`）
3. 「変換」タブにYouTube URLを貼り付けて「取得」
4. フォーマット・品質を選んで「変換を開始」
5. 完了後「ライブラリ」タブで再生
