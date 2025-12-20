# Web/モバイル対応ガイド

本ドキュメントは、GodotプロジェクトをWeb版としてエクスポートし、PCブラウザおよびモバイル端末（iPhone/Android）で動作させるためのガイドラインをまとめたものです。

---

## 1. ファイル命名規則

### ルール
- **日本語のファイル名・フォルダ名は使用禁止**
- 英数字、アンダースコア、ハイフンのみ使用する

### 理由
- Web版やモバイル端末ではUTF-8パスの処理が厳格
- PCでは動作してもiPhone/Androidで読み込みエラーになる

### 悪い例 → 良い例
```
assets/images/キャラクター/   → assets/images/characters/
assets/building_parts/床4.glb → assets/building_parts/floor4.glb
assets/building_parts/石床.tscn → assets/building_parts/stone_floor.tscn
```

### 既存ファイルのリネーム手順
1. ファイル/フォルダ名を変更
2. 参照しているシーンファイル（.tscn）のパスを更新
3. .importファイルを削除
4. Godotエディタを再起動（自動で再インポート）

---

## 2. テクスチャ圧縮設定

### 圧縮形式と対応デバイス

| 形式 | 対応デバイス |
|------|-------------|
| S3TC/BPTC | PC（Windows/Mac/Linux） |
| ETC2/ASTC | モバイル（iPhone/Android） |

### プロジェクト設定
`project.godot` に以下が必要：
```
[rendering]
textures/vram_compression/import_etc2_astc=true
```

### 設定方法
1. Godotエディタ → プロジェクト → プロジェクト設定
2. 「レンダリング」→「テクスチャ」→「VRAM圧縮」
3. 「Import ETC2 ASTC」を有効にする

または、エクスポート時に警告が出たら「インポートの修正」ボタンをクリック

---

## 3. エクスポート設定

### export_presets.cfg の必須設定
```ini
[preset.0.options]
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
```

### 確認方法
1. プロジェクト → エクスポート
2. Webプリセットを選択
3. 「VRAMテクスチャ圧縮」で「デスクトップ向け」「モバイル向け」両方をオン

---

## 4. シーン遷移のベストプラクティス

### Web版での問題
`change_scene_to_file()` を直接呼ぶと、Web版ではタイミングの違いにより `!is_inside_tree()` エラーが発生することがある。

### 解決策
`call_deferred()` を使用して次フレームまで待つ：

```gdscript
# ❌ 悪い例
get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ✅ 良い例
get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")
```

---

## 5. ノード削除

### Web版での問題
シーン遷移直前の `queue_free()` は、Web版でタイミング問題を引き起こす可能性がある。

### 解決策
状況に応じて `free()` を使用：

```gdscript
# 通常の削除（次フレームで削除）
node.queue_free()

# 即時削除（シーン遷移直前など）
node.free()
```

### 使い分け
- 通常は `queue_free()` を使用
- シーン遷移直前やループ内での削除は `free()` を検討

---

## 6. セーブデータ（Web版）

### Web版の保存先
- ブラウザのIndexedDB（`user://`）
- ブラウザのサイトデータをクリアすると消える

### 問題
空のセーブデータがIndexedDBに残り、正常に読み込めないことがある

### 解決策
`res://data/default_save.json` へのフォールバックを実装：

```gdscript
func load_from_file():
	# user://を試す
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var data = _parse_json(file)
			if _has_valid_deck(data):  # データが有効かチェック
				player_data = data
				return
	
	# 無効な場合はdefault_save.jsonを使用
	var file = FileAccess.open("res://data/default_save.json", FileAccess.READ)
	if file:
		player_data = _parse_json(file)
```

---

## 7. 開発環境セットアップ

### 必要なツール
- Python 3（HTTPサーバー用）
- Cloudflared（外部アクセス用）

### Cloudflare Tunnelのインストール
```bash
brew install cloudflare/cloudflare/cloudflared
```

### 開発サーバー起動
```bash
/Users/andouhiroyuki/cardbattlegame/start_web_dev_cf.sh
```

### 機能
- Python HTTPサーバー（localhost:8000）
- Cloudflare Tunnel（外部URL発行）
- ファイル監視 → Safari自動リロード

### 使い方
1. スクリプト実行
2. 表示された `🌐 Cloudflare URL:` をモバイルで開く
3. Godotでエクスポート → 自動リロード
4. 終了は `Ctrl+C`

---

## 8. iPhoneでのデバッグ

### 準備
1. iPhone: 設定 → Safari → 詳細 → Webインスペクタをオン
2. Mac: Safari → 設定 → 詳細 → 「メニューバーに"開発"メニューを表示」をオン

### デバッグ手順
1. iPhoneをMacにUSB接続
2. iPhoneのSafariでゲームを開く
3. Mac Safari → 開発メニュー → iPhoneの名前 → 該当ページを選択
4. コンソールログが表示される

---

## 9. よくあるエラーと対処法

### `Failed loading resource: res://path/to/file`
- 原因: 日本語ファイル名、または未インポート
- 対処: ファイル名を英語に変更、Godotエディタを再起動

### `No loader found for resource (expected type: CompressedTexture2D)`
- 原因: モバイル用圧縮形式が未生成
- 対処: ETC2/ASTC圧縮を有効化、.importファイル削除後に再起動

### `Condition "!is_inside_tree()" is true`
- 原因: シーン遷移のタイミング問題
- 対処: `call_deferred()` を使用

### `invalid UID` 警告
- 原因: ファイル移動後にUIDが古くなった
- 対処: .tscn/.tresファイルから該当UIDを削除、または .godot/imported/ を削除して再インポート

---

## 10. チェックリスト

### 新しい画像を追加する時
- [ ] ファイル名は英数字のみ
- [ ] フォルダ名も英数字のみ
- [ ] Godotエディタで開いてインポート確認

### エクスポート前
- [ ] VRAMテクスチャ圧縮でモバイル向けがオン
- [ ] ETC2/ASTC圧縮が有効

### リリース前
- [ ] PC Safariでテスト
- [ ] iPhoneでテスト
- [ ] Androidでテスト（可能であれば）

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025-12-21 | 初版作成 |
