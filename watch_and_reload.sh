#!/bin/bash

# web_build フォルダを監視し、変更があったらSafariをリロード

echo "=== Web Build 監視開始 ==="
echo "Godotでエクスポートすると自動でSafariがリロードされます"
echo "終了するには Ctrl+C"
echo ""

WATCH_DIR="web_build"

# 初回のタイムスタンプ
LAST_MODIFIED=$(stat -f %m "$WATCH_DIR/index.html" 2>/dev/null || echo "0")

while true; do
    sleep 1
    
    CURRENT_MODIFIED=$(stat -f %m "$WATCH_DIR/index.html" 2>/dev/null || echo "0")
    
    if [ "$CURRENT_MODIFIED" != "$LAST_MODIFIED" ] && [ "$CURRENT_MODIFIED" != "0" ]; then
        echo "[$(date +%H:%M:%S)] エクスポート検出 → Safariリロード"
        sleep 0.5  # エクスポート完了を少し待つ
        osascript -e 'tell application "Safari" to set URL of document 1 to URL of document 1'
        LAST_MODIFIED=$CURRENT_MODIFIED
    fi
done
