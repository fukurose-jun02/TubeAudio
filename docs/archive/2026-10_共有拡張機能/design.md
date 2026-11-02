# YouTube共有メニューからのURL取り込み - 設計書

前提: [requirements.md](requirements.md) の要件に基づく。

###### 全体構成

```
YouTubeアプリ「共有」 → 共有メニュー「TubeAudio」
   │
   ▼
共有拡張機能 TubeAudioShare（別プロセス）
   │  URLを取り出し、YouTubeのものか検査
   │  App Group「group.com.fukurose.TubeAudio」のUserDefaultsに保存（キー: pendingSharedURL）
   │  「追加しました」を表示して閉じる
   ▼
（ユーザーがTubeAudioを開く）
   ▼
アプリ本体 TubeAudio
   │  前面に来たとき（scenePhase が active）に保管場所を読む
   │  あれば値を消し、「変換」タブへ切り替えてURLを入力欄へ
   ▼
既存の fetchInfo() が自動で動き、動画情報を表示
```

拡張機能はアプリ本体とは別プロセスで、メモリや実行時間の制約が厳しいため、通信や変換はしない。URLを渡すことだけに徹する。

###### 受け渡し方式の判断

| 案 | 採否 | 理由 |
|---|---|---|
| a. App Groupに保存し、アプリで続きをやる | **採用** | 確実で、iOSの制限に強い |
| b. 拡張機能がMacに直接変換を依頼 | 見送り（将来の拡張候補） | 変換待ちの管理が必要で実装が増える |
| c. 共有後にアプリを自動で起動 | 見送り | 拡張機能からアプリを開く公式手段がない |

###### 新規・変更ファイル

| ファイル | 変更内容 |
|---|---|
| `ios/TubeAudioShare/ShareViewController.swift`（新規） | 拡張機能の本体。共有項目からURLを取り出し、YouTubeか検査して保存し、結果を表示して閉じる |
| `ios/TubeAudioShare/Info.plist`（新規） | 共有拡張の定義（`com.apple.share-services`）。URLとテキストの共有を受け付ける設定 |
| `ios/TubeAudioShare/TubeAudioShare.entitlements`（新規） | App Group権限 |
| `ios/TubeAudio/TubeAudio.entitlements`（新規） | App Group権限 |
| `ios/TubeAudio/SharedURLInbox.swift`（新規） | 保管場所の読み書き（アプリ本体側）と、テキストからのURL抽出・YouTube判定の純粋関数 |
| `ios/TubeAudio/ContentView.swift` | タブ選択の状態を持たせ、前面に来たときに受け取り処理を呼ぶ。`ConvertView`が外から渡されたURLで取得を始められるようにする |
| `ios/TubeAudio.xcodeproj/project.pbxproj` | 拡張機能ターゲットの追加、アプリへの同梱設定、権限ファイルの指定、バージョン1.09 |
| `ios/README.md` | 機能・セットアップに共有拡張の説明を追記 |

###### 定数（アプリ本体と拡張機能で重複して持つ）

- App Group ID: `group.com.fukurose.TubeAudio`
- 保存キー: `pendingSharedURL`
- 拡張機能のBundle ID: `com.fukurose.TubeAudio.Share`

2つのターゲットで1ファイルを共有する構成は設定が複雑になるため、定数の重複を許容する（変更時は両方を直す旨をコードにコメントで残す）。

###### URLの取り出しとYouTube判定

- 共有項目（`NSExtensionItem`）の添付から、`public.url`を優先して読み、なければ`public.plain-text`を読む
- テキストの場合は、`NSDataDetector`でリンクを検出し、最初のものを使う（説明文とURLが混ざっていても対応）
- ホスト名が `youtube.com`、`youtu.be`、およびそのサブドメイン（`www.`、`m.`、`music.`）であれば受け付ける

###### アプリ側の受け取り

- `ContentView`が`@Environment(\.scenePhase)`を監視し、`.active`になったとき`SharedURLInbox.take()`を呼ぶ
- 値があれば、`selectedTab`を「変換」に切り替え、`ConvertView`に`incomingURL`として渡す
- `ConvertView`は`.onChange(of: incomingURL)`で`urlText`に入れて`fetchInfo()`を呼び、渡し終えたら`incomingURL`を`nil`に戻す

###### 動作しなくなるケースと対処

- 無料のApple IDではApp Groupが使えない可能性がある → 実機で確認し、使えなければ代替（クリップボード方式など）を再検討する
- 共有メニューに「TubeAudio」が出ない場合は、共有メニュー末尾の「その他」から有効にする（iOSの初期状態では未表示のことがある）
- Macに接続できない場合は既存のエラー表示になる（今回は変更なし）
