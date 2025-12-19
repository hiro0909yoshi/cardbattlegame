#!/bin/bash

# Godot Web エクスポート & ブラウザリロード スクリプト

echo "=== Web エクスポート開始 ==="

# Godotのパス
GODOT_PATH="/Users/andouhiroyuki/Downloads/Godot.app/Contents/MacOS/Godot"

# エクスポート実行
$GODOT_PATH --headless --export-release "Web" web_build/index.html

if [ $? -eq 0 ]; then
    echo "=== エクスポート完了 ==="
    
    # Safariをリロード
    osascript -e 'tell application "Safari" to set URL of document 1 to URL of document 1'
    
    echo "=== ブラウザリロード完了 ==="
else
    echo "=== エクスポート失敗 ==="
    exit 1
fi
