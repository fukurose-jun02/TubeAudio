#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "📦 依存パッケージをインストール中..."
pip3 install -r requirements.txt

echo ""
echo "✅ セットアップ完了！"
echo ""
echo "起動するには:"
echo "  python3 app.py"
echo ""
echo "ブラウザで以下を開いてください:"
echo "  http://localhost:5001"

echo ""
read -p "Macのログイン時にサーバーを自動起動しますか？ (y/N): " AUTOSTART
if [[ "$AUTOSTART" =~ ^[Yy]$ ]]; then
    PYTHON3_PATH="$(command -v python3)"
    PLIST_NAME="com.fukurose.tubeaudio.plist"
    DEST_PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME"

    mkdir -p "$HOME/Library/LaunchAgents"
    sed \
        -e "s|__PYTHON3_PATH__|$PYTHON3_PATH|g" \
        -e "s|__SERVER_DIR__|$SCRIPT_DIR|g" \
        "$SCRIPT_DIR/$PLIST_NAME" > "$DEST_PLIST"

    launchctl unload "$DEST_PLIST" 2>/dev/null || true
    launchctl load -w "$DEST_PLIST"

    echo ""
    echo "✅ 自動起動を設定しました（$DEST_PLIST）"
    echo "   ログは $SCRIPT_DIR/run.log に出力されます"
    echo "   解除するには: launchctl unload $DEST_PLIST && rm $DEST_PLIST"
fi
