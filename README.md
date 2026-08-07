# TubeAudio

YouTubeの音声をiPhoneでダウンロード・再生できるアプリ一式。iOSアプリ（クライアント）とMacで動くFlaskサーバーの2つで構成されています。

```
TubeAudio/
  ios/      SwiftUI製iOSアプリ（TubeAudio.xcodeproj）
  server/   Flask製変換サーバー（app.py）
```

## 構成

| ディレクトリ | 役割 | 詳細 |
|---|---|---|
| [`ios/`](ios/README.md) | iPhone側アプリ。URL入力・変換指示・ライブラリ再生を行う | [ios/README.md](ios/README.md) |
| [`server/`](server/README.md) | Mac側サーバー。yt-dlp/ffmpegでYouTube音声をM4A/MP3に変換する | [server/README.md](server/README.md) |

両者は同一WiFi内でHTTP通信し、iOSアプリがMacのサーバーAPI（`/api/info`, `/api/convert` など）を呼び出す構成です。

## セットアップ

1. Mac側でサーバーを起動
   ```bash
   cd server
   pip3 install -r requirements.txt
   python3 app.py
   ```
2. iOS側をXcodeでビルド
   ```bash
   open ios/TubeAudio.xcodeproj
   ```
   iPhoneをMacにUSB接続し、▶ボタンでビルド・インストール後、「設定」タブでMacのIPアドレスを指定する。

詳しい機能・使い方は各ディレクトリのREADMEを参照してください。
