# YouTube Audio Converter

YouTubeのURLを貼り付けるだけで、音声をM4A/MP3に変換してダウンロードできるローカルWebアプリです。

![Python](https://img.shields.io/badge/Python-3.12-blue) ![Flask](https://img.shields.io/badge/Flask-3.x-green) ![yt-dlp](https://img.shields.io/badge/yt--dlp-latest-red)

## 機能

- YouTube URLから動画情報（タイトル・サムネイル・再生時間）を取得
- M4A（AAC）/ MP3 形式で変換
- 音質選択（128 / 192 / 256 / 320 kbps）
- 変換進捗のリアルタイム表示
- 変換履歴の一覧表示

## 技術スタック

| 役割 | ライブラリ |
|---|---|
| Webサーバー | Flask |
| YouTube ダウンロード | yt-dlp |
| 音声変換 | ffmpeg（static-ffmpeg に内蔵） |

## セットアップ

```bash
# リポジトリをクローン
git clone https://github.com/fukurose-jun02/youtube-audio-converter.git
cd youtube-audio-converter

# 依存パッケージをインストール
pip3 install -r requirements.txt
```

### 動画検索を使う場合（任意）

キーワード検索機能を使うには、YouTube Data API v3のAPIキーが必要です。

1. [Google Cloud Console](https://console.cloud.google.com/)でYouTube Data API v3を有効化し、APIキーを発行する
2. `server/.env`に以下を書き込む（`.gitignore`で除外済み）
   ```
   YOUTUBE_API_KEY=発行したキー
   ```

未設定の場合、検索以外の機能（URL貼り付けでの変換）は従来どおり利用できます。

## 起動方法

```bash
python3 app.py
```

ブラウザで `http://localhost:5001` を開いてください。

## iPhoneから使う場合

MacとiPhoneを同じWiFiに接続した状態でサーバーを起動すると、iPhoneの [TubeAudio iOS アプリ](https://github.com/fukurose-jun02/TubeAudio-iOS) から利用できます。

## API エンドポイント

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/api/info` | 動画情報の取得 |
| GET | `/api/search?q=<キーワード>` | キーワードによる動画検索（YouTube Data API v3、要APIキー） |
| POST | `/api/convert` | 変換開始（job_id を返す） |
| GET | `/api/status/<job_id>` | 変換進捗の確認 |
| GET | `/api/download/<job_id>` | ファイルのダウンロード |
| GET | `/api/files` | 変換済みファイル一覧 |
