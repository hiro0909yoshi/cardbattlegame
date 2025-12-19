#!/bin/bash

# Web開発サーバー起動スクリプト（Cloudflare Tunnel版）
# - Python HTTPサーバー
# - Cloudflare Tunnel
# - ファイル監視 → Safari自動リロード

cd /Users/andouhiroyuki/cardbattlegame/web_build

echo "=== Web開発環境起動 (Cloudflare Tunnel) ==="

# 既存プロセスを終了
pkill -f "python3 server.py" 2>/dev/null
pkill -f "cloudflared tunnel" 2>/dev/null

# Pythonサーバーをバックグラウンドで起動
python3 server.py &
SERVER_PID=$!
echo "✅ Python サーバー起動 (PID: $SERVER_PID)"

sleep 1

# Cloudflare Tunnelをバックグラウンドで起動
cloudflared tunnel --url http://localhost:8000 2>&1 | tee /tmp/cloudflared.log &
TUNNEL_PID=$!
echo "✅ Cloudflare Tunnel 起動中..."

# URLが表示されるまで待つ
sleep 5
TUNNEL_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' /tmp/cloudflared.log | head -1)

echo ""
echo "🌐 Cloudflare URL: $TUNNEL_URL"
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
    kill $TUNNEL_PID 2>/dev/null
    pkill -f "python3 server.py" 2>/dev/null
    pkill -f "cloudflared tunnel" 2>/dev/null
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
