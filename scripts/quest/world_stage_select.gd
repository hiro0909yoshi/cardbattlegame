extends Control

## ワールド・ステージ選択画面
## ワールドを選択→展開してステージ一覧表示→ステージ詳細→ブック選択へ

# UI参照
@onready var world_container: VBoxContainer = $MarginContainer/MainContainer/LeftPanel/WorldContainer
@onready var stage_container: HBoxContainer = $MarginContainer/MainContainer/LeftPanel/StageContainer
@onready var detail_panel: PanelContainer = $MarginContainer/MainContainer/RightPanel/DetailPanel
@onready var map_preview: TextureRect = $MarginContainer/MainContainer/RightPanel/DetailPanel/VBox/MapPreview
@onready var stage_name_label: Label = $MarginContainer/MainContainer/RightPanel/DetailPanel/VBox/StageNameLabel
@onready var reward_label: Label = $MarginContainer/MainContainer/RightPanel/DetailPanel/VBox/RewardLabel
@onready var record_label: Label = $MarginContainer/MainContainer/RightPanel/DetailPanel/VBox/RecordLabel
@onready var stats_label: Label = $MarginContainer/MainContainer/RightPanel/DetailPanel/VBox/StatsLabel
@onready var start_button: Button = $MarginContainer/MainContainer/RightPanel/StartButton
@onready var back_button: Button = $MarginContainer/MainContainer/RightPanel/BackButton

# ワールド定義（3ワールド × 8ステージ）
var worlds = [
	{
		"id": "world_1",
		"name": "ワールド1",
		"stages": ["stage_1_1", "stage_1_2", "stage_1_3", "stage_1_4", "stage_1_5", "stage_1_6", "stage_1_7", "stage_1_8"]
	},
	{
		"id": "world_2",
		"name": "ワールド2",
		"stages": ["stage_2_1", "stage_2_2", "stage_2_3", "stage_2_4", "stage_2_5", "stage_2_6", "stage_2_7", "stage_2_8"]
	},
	{
		"id": "world_3",
		"name": "ワールド3",
		"stages": ["stage_3_1", "stage_3_2", "stage_3_3", "stage_3_4", "stage_3_5", "stage_3_6", "stage_3_7", "stage_3_8"]
	}
]

# ステージデータキャッシュ
var stage_data_cache: Dictionary = {}

# 選択状態
var selected_world_index: int = -1
var selected_stage_id: String = ""
var world_buttons: Array = []
var stage_buttons: Array = []

# 定数
const STAGE_BUTTON_SIZE = 165
const STAGE_BUTTON_MARGIN = 40

# マッププレビュー画像キャッシュ
var map_preview_cache: Dictionary = {}

func _ready():
	# ボタン接続
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# 初期状態
	detail_panel.visible = false
	start_button.disabled = true
	stage_container.visible = false
	
	# ワールドボタン作成
	_create_world_buttons()

## ワールドボタンを作成
func _create_world_buttons():
	# 既存をクリア
	for child in world_container.get_children():
		child.queue_free()
	world_buttons.clear()
	
	for i in range(worlds.size()):
		var world = worlds[i]
		var btn = Button.new()
		btn.text = world.name
		btn.custom_minimum_size = Vector2(300, 80)
		btn.add_theme_font_size_override("font_size", 32)
		
		# アンロック判定
		var is_unlocked = _is_world_unlocked(i)
		btn.disabled = not is_unlocked
		if not is_unlocked:
			btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
		
		btn.pressed.connect(_on_world_selected.bind(i))
		world_container.add_child(btn)
		world_buttons.append(btn)

## ワールドがアンロック済みか判定
func _is_world_unlocked(world_index: int) -> bool:
	if world_index == 0:
		return true  # ワールド1は常にアンロック
	
	# 前のワールドの最終ステージをクリアしていればアンロック
	var prev_world = worlds[world_index - 1]
	var last_stage_id = prev_world.stages[prev_world.stages.size() - 1]
	return StageRecordManager.is_cleared(last_stage_id)

## ステージがアンロック済みか判定
func _is_stage_unlocked(world_index: int, stage_index: int) -> bool:
	if stage_index == 0:
		return _is_world_unlocked(world_index)  # 各ワールドの1面目はワールド解放と同時
	
	# 同じワールドの前のステージをクリアしていればアンロック
	var prev_stage_id = worlds[world_index].stages[stage_index - 1]
	return StageRecordManager.is_cleared(prev_stage_id)

## ワールド選択時
func _on_world_selected(world_index: int):
	selected_world_index = world_index
	selected_stage_id = ""
	detail_panel.visible = false
	start_button.disabled = true
	
	# ワールドボタンのハイライト更新
	for i in range(world_buttons.size()):
		var btn = world_buttons[i]
		if i == world_index:
			btn.add_theme_color_override("font_color", Color.YELLOW)
		else:
			btn.remove_theme_color_override("font_color")
	
	# ステージボタン表示
	_create_stage_buttons(world_index)
	stage_container.visible = true

## ステージボタン（丸いボッチ）を作成
func _create_stage_buttons(world_index: int):
	# 既存をクリア
	for child in stage_container.get_children():
		child.queue_free()
	stage_buttons.clear()
	
	var world = worlds[world_index]
	
	for i in range(world.stages.size()):
		var stage_id = world.stages[i]
		var is_unlocked = _is_stage_unlocked(world_index, i)
		var is_cleared = StageRecordManager.is_cleared(stage_id)
		var best_rank = StageRecordManager.get_best_rank(stage_id)
		
		# 丸いボタン作成
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(STAGE_BUTTON_SIZE, STAGE_BUTTON_SIZE)
		btn.text = str(i + 1)
		btn.add_theme_font_size_override("font_size", 54)
		
		# スタイル設定
		var style = StyleBoxFlat.new()
		var corner_radius := int(STAGE_BUTTON_SIZE / 2.0)
		style.corner_radius_top_left = corner_radius
		style.corner_radius_top_right = corner_radius
		style.corner_radius_bottom_left = corner_radius
		style.corner_radius_bottom_right = corner_radius
		
		if not is_unlocked:
			# ロック状態（グレー）
			style.bg_color = Color(0.3, 0.3, 0.3, 1.0)
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		elif is_cleared:
			# クリア済み（ランクに応じた色）
			style.bg_color = _get_rank_color(best_rank)
		else:
			# 未クリア（青）
			style.bg_color = Color(0.2, 0.4, 0.8, 1.0)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("disabled", style)
		
		if is_unlocked:
			btn.pressed.connect(_on_stage_selected.bind(stage_id))
		
		stage_container.add_child(btn)
		stage_buttons.append(btn)
		
		# スペーサー（最後以外）
		if i < world.stages.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(STAGE_BUTTON_MARGIN, 0)
			stage_container.add_child(spacer)

## ランクに応じた色を取得
func _get_rank_color(rank: String) -> Color:
	match rank:
		"SS":
			return Color(1.0, 0.84, 0.0, 1.0)  # ゴールド
		"S":
			return Color(0.75, 0.75, 0.75, 1.0)  # シルバー
		"A":
			return Color(0.8, 0.5, 0.2, 1.0)  # ブロンズ
		"B":
			return Color(0.4, 0.6, 0.4, 1.0)  # グリーン
		"C":
			return Color(0.5, 0.5, 0.6, 1.0)  # グレー
		_:
			return Color(0.2, 0.4, 0.8, 1.0)  # 未クリア（青）

## ステージ選択時
func _on_stage_selected(stage_id: String):
	selected_stage_id = stage_id
	
	# ステージボタンのハイライト更新
	var world = worlds[selected_world_index]
	for i in range(stage_buttons.size()):
		var btn = stage_buttons[i]
		if world.stages[i] == stage_id:
			btn.add_theme_color_override("font_color", Color.YELLOW)
		else:
			btn.remove_theme_color_override("font_color")
	
	# 詳細パネル表示
	_show_stage_detail(stage_id)
	detail_panel.visible = true
	start_button.disabled = false

## ステージ詳細を表示
func _show_stage_detail(stage_id: String):
	# ステージデータ読み込み
	var stage_data = _load_stage_data(stage_id)
	if stage_data.is_empty():
		stage_name_label.text = "ステージデータなし"
		reward_label.text = ""
		record_label.text = ""
		return
	
	# ステージ名（例: 1-2 草原の試練）
	var world_num = selected_world_index + 1
	var stage_num = worlds[selected_world_index].stages.find(stage_id) + 1
	var stage_name = stage_data.get("name", "不明")
	stage_name_label.text = "%d-%d %s" % [world_num, stage_num, stage_name]
	
	# 報酬（初回は通常、2回目以降は20%）
	var rewards = stage_data.get("rewards", {})
	var base_gold = rewards.get("gold", 0)
	var is_cleared = StageRecordManager.is_cleared(stage_id)
	var actual_gold: int
	if is_cleared:
		actual_gold = int(ceil(base_gold * 0.2))
	else:
		actual_gold = base_gold
	reward_label.text = "報酬: %dG" % actual_gold
	
	# クリアランク
	var best_rank = StageRecordManager.get_best_rank(stage_id)
	if best_rank != "":
		record_label.text = "クリアランク: %s" % best_rank
	else:
		record_label.text = "クリアランク: -"
	
	# 戦績（勝敗）
	var record = StageRecordManager.get_record(stage_id)
	var win_count = record.get("clear_count", 0)
	var lose_count = record.get("lose_count", 0)
	var total = win_count + lose_count
	if total > 0:
		stats_label.text = "戦績: %d戦%d勝%d敗" % [total, win_count, lose_count]
	else:
		stats_label.text = "戦績: なし"
	
	# マッププレビュー
	var map_id = stage_data.get("map_id", "")
	if not map_id.is_empty():
		_show_map_preview(map_id)
	else:
		map_preview.texture = null

## ステージデータを読み込み（キャッシュ付き）
func _load_stage_data(stage_id: String) -> Dictionary:
	if stage_data_cache.has(stage_id):
		return stage_data_cache[stage_id]
	
	var path = "res://data/master/stages/%s.json" % stage_id
	if not FileAccess.file_exists(path):
		print("[WorldStageSelect] ステージファイルが見つかりません: ", path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		print("[WorldStageSelect] JSONパースエラー: ", path)
		return {}
	
	var data = json.get_data()
	stage_data_cache[stage_id] = data
	return data

## 開始ボタン押下
func _on_start_pressed():
	if selected_stage_id.is_empty():
		return
	
	# 選択を保存
	GameData.selected_stage_id = selected_stage_id
	
	print("[WorldStageSelect] ステージ選択完了: ", selected_stage_id)
	
	# ブック選択画面へ遷移
	get_tree().call_deferred("change_scene_to_file", "res://scenes/BookSelect.tscn")

## 戻るボタン押下
func _on_back_pressed():
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")

## マッププレビューを表示
func _show_map_preview(map_id: String):
	# キャッシュ確認
	if map_preview_cache.has(map_id):
		map_preview.texture = map_preview_cache[map_id]
		return
	
	# マップデータ読み込み
	var path = "res://data/master/maps/%s.json" % map_id
	if not FileAccess.file_exists(path):
		print("[WorldStageSelect] マップファイルが見つかりません: ", path)
		map_preview.texture = null
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		map_preview.texture = null
		return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	
	if error != OK:
		map_preview.texture = null
		return
	
	var map_data = json.get_data()
	var tiles = map_data.get("tiles", [])
	
	if tiles.is_empty():
		map_preview.texture = null
		return
	
	# SubViewportを使ってプレビュー生成
	_generate_3d_map_preview(map_id, tiles)

## 3Dタイルを使ったマッププレビューを生成
func _generate_3d_map_preview(map_id: String, tiles: Array):
	# SubViewportを作成
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(600, 500)
	sub_viewport.transparent_bg = false
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# 背景色を設定するためのWorldEnvironment
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	world_env.environment = env
	sub_viewport.add_child(world_env)
	
	# ライトを追加
	var light = DirectionalLight3D.new()
	light.position = Vector3(10, 20, 10)
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.0
	sub_viewport.add_child(light)
	
	# タイルの座標範囲を計算
	var min_x = 999999.0
	var max_x = -999999.0
	var min_z = 999999.0
	var max_z = -999999.0
	
	for tile in tiles:
		var x = float(tile.get("x", 0))
		var z = float(tile.get("z", 0))
		min_x = min(min_x, x)
		max_x = max(max_x, x)
		min_z = min(min_z, z)
		max_z = max(max_z, z)
	
	# タイルコンテナを作成
	var tiles_container = Node3D.new()
	sub_viewport.add_child(tiles_container)
	
	# タイルを配置
	for tile_data in tiles:
		var tile_type = tile_data.get("type", "Neutral")
		var tile_scene = _get_tile_scene(tile_type)
		if tile_scene:
			var tile = tile_scene.instantiate()
			var x = float(tile_data.get("x", 0))
			var z = float(tile_data.get("z", 0))
			tile.position = Vector3(x, 0, z)
			tiles_container.add_child(tile)
	
	# カメラを追加（ゲーム画面と同じ斜め45度の見下ろしアングル）
	var camera = Camera3D.new()
	var center_x = (min_x + max_x) / 2.0
	var center_z = (min_z + max_z) / 2.0
	var range_x = max_x - min_x
	var range_z = max_z - min_z
	var map_size = max(range_x, range_z)
	
	# ゲーム画面と同じアングル（斜め45度から見下ろす）
	var cam_distance = map_size * 1.0 + 20
	var cam_height = cam_distance * 0.7
	var cam_z_offset = cam_distance * 0.7
	
	camera.position = Vector3(center_x, cam_height, center_z + cam_z_offset)
	camera.rotation_degrees = Vector3(-45, 0, 0)
	camera.fov = 45
	sub_viewport.add_child(camera)
	
	# シーンツリーに追加してレンダリング
	add_child(sub_viewport)
	
	# 1フレーム待ってからテクスチャを取得
	await get_tree().process_frame
	await get_tree().process_frame
	
	# テクスチャを取得
	var viewport_texture = sub_viewport.get_texture()
	var image = viewport_texture.get_image()
	var texture = ImageTexture.create_from_image(image)
	
	# キャッシュに保存
	map_preview_cache[map_id] = texture
	map_preview.texture = texture
	
	# クリーンアップ
	sub_viewport.queue_free()

## タイルシーンを取得
func _get_tile_scene(tile_type: String) -> PackedScene:
	var tile_scenes = {
		"Checkpoint": "res://scenes/Tiles/CheckpointTile.tscn",
		"Fire": "res://scenes/Tiles/FireTile.tscn",
		"Water": "res://scenes/Tiles/WaterTile.tscn",
		"Earth": "res://scenes/Tiles/EarthTile.tscn",
		"Wind": "res://scenes/Tiles/WindTile.tscn",
		"Neutral": "res://scenes/Tiles/NeutralTile.tscn",
		"Warp": "res://scenes/Tiles/WarpTile.tscn",
		"WarpStop": "res://scenes/Tiles/WarpStopTile.tscn",
		"CardBuy": "res://scenes/Tiles/CardBuyTile.tscn",
		"CardGive": "res://scenes/Tiles/CardGiveTile.tscn",
		"MagicStone": "res://scenes/Tiles/MagicStoneTile.tscn",
		"Magic": "res://scenes/Tiles/MagicTile.tscn",
		"Base": "res://scenes/Tiles/SpecialBaseTile.tscn",
		"Branch": "res://scenes/Tiles/BranchTile.tscn"
	}
	
	var path = tile_scenes.get(tile_type, tile_scenes.get("Neutral"))
	if ResourceLoader.exists(path):
		return load(path)
	return null
