#!/bin/bash

# Web開発サーバー起動スクリプト
# - Python HTTPサーバー
# - ngrok トンネル
# - ファイル監視 → Safari自動リロード

cd /Users/andouhiroyuki/cardbattlegame/web_build

echo "=== Web開発環境起動 ==="

# 既存プロセスを終了
pkill -f "python3 server.py" 2>/dev/null
pkill -f "ngrok http 8000" 2>/dev/null

# Pythonサーバーをバックグラウンドで起動
python3 server.py &
SERVER_PID=$!
echo "✅ Python サーバー起動 (PID: $SERVER_PID)"

# 少し待つ
sleep 1

# ngrokをバックグラウンドで起動
ngrok http 8000 > /dev/null &
NGROK_PID=$!
echo "✅ ngrok 起動 (PID: $NGROK_PID)"

# ngrok URLを取得して表示
sleep 2
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | cut -d'"' -f4)
echo ""
echo "🌐 ngrok URL: $NGROK_URL"
echo ""

# 監視開始
echo "=== ファイル監視開始 ==="
echo "Godotでエクスポートすると自動でSafariがリロードされます"
echo "終了するには Ctrl+C"
echo ""

WATCH_FILE="/Users/andouhiroyuki/cardbattlegame/web_build/index.html"
LAST_MODIFIED=$(stat -f %m "$WATCH_FILE" 2>/dev/null || echo "0")

cleanup() {
    echo ""
    echo "=== 終了処理 ==="
    kill $SERVER_PID 2>/dev/null
    kill $NGROK_PID 2>/dev/null
    pkill -f "python3 server.py" 2>/dev/null
    pkill -f "ngrok http 8000" 2>/dev/null
    echo "✅ 全プロセス終了"
    exit 0
}

trap cleanup SIGINT SIGTERM

while true; do
    sleep 1
    
    CURRENT_MODIFIED=$(stat -f %m "$WATCH_FILE" 2>/dev/null || echo "0")
    
    if [ "$CURRENT_MODIFIED" != "$LAST_MODIFIED" ] && [ "$CURRENT_MODIFIED" != "0" ]; then
        echo "[$(date +%H:%M:%S)] エクスポート検出 → Safariリロード"
        sleep 0.5
        osascript -e 'tell application "Safari" to set URL of document 1 to URL of document 1'
        LAST_MODIFIED=$CURRENT_MODIFIED
    fi
done
