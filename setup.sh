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
