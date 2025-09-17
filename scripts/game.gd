extends Node2D
# メインゲーム管理スクリプト（ポリゴン背景対応版）

# システムの参照
var board_system: BoardSystem
var card_system: CardSystem
var player_system: PlayerSystem
var battle_system: BattleSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var game_flow: GameFlowManager
var special_tile_system: SpecialTileSystem
var camera_system = null  # CameraSystem（型指定なしで初期化）

var player_count = 2  # プレイヤー数

# マップ背景管理
var current_bg_index = 0
var background_paths = [
	"res://assets/images/map/map_background1.jpeg",
	"res://assets/images/map/map_background.png",
	"res://assets/images/map/map_background2.png",
	"res://assets/images/map/map_background3.png"
]
var current_background = null  # 現在の背景ノード

func _ready():
	print("=== カルドセプト風ゲーム開始 ===")
	
	initialize_systems()
	setup_game()
	connect_signals()
	
	# ゲーム開始時にカメラを初期フォーカス
	await get_tree().create_timer(0.1).timeout
	if camera_system:
		camera_system.focus_on_current_player()
	
	game_flow.start_game()

# システムを初期化
func initialize_systems():
	# 各システムをインスタンス化
	board_system = BoardSystem.new()
	card_system = CardSystem.new()
	player_system = PlayerSystem.new()
	battle_system = BattleSystem.new()
	skill_system = SkillSystem.new()
	ui_manager = UIManager.new()
	game_flow = GameFlowManager.new()
	special_tile_system = SpecialTileSystem.new()
	
	# CameraSystemをロードして作成
	var CameraSystemClass = load("res://scripts/camera_system.gd")
	if CameraSystemClass:
		camera_system = CameraSystemClass.new()
		camera_system.name = "CameraSystem"
		add_child(camera_system)
	else:
		print("WARNING: camera_system.gdが見つかりません")
	
	# デバッグコントローラーを作成
	var debug_controller = DebugController.new()
	debug_controller.name = "DebugController"
	add_child(debug_controller)
	
	# 名前を設定（参照用）
	board_system.name = "BoardSystem"
	card_system.name = "CardSystem"
	player_system.name = "PlayerSystem"
	battle_system.name = "BattleSystem"
	skill_system.name = "SkillSystem"
	ui_manager.name = "UIManager"
	game_flow.name = "GameFlowManager"
	special_tile_system.name = "SpecialTileSystem"
	
	# シーンツリーに追加
	add_child(board_system)
	add_child(card_system)
	add_child(player_system)
	add_child(battle_system)
	add_child(skill_system)
	add_child(ui_manager)
	add_child(game_flow)
	add_child(special_tile_system)
	
	# デバッグコントローラーにシステム参照を設定
	debug_controller.setup_systems(player_system, board_system, card_system, ui_manager)
	player_system.set_debug_controller(debug_controller)
	
	# SpecialTileSystemにシステム参照を設定
	special_tile_system.setup_systems(board_system, card_system, player_system)
	
	# GameFlowにシステム参照を設定
	game_flow.setup_systems(player_system, card_system, board_system, skill_system, ui_manager, battle_system, special_tile_system)
	
	print("全システム初期化完了")

# ゲームをセットアップ
func setup_game():
	# BoardMapノードがなければ作成
	if not has_node("BoardMap"):
		var board_map_node = Node2D.new()
		board_map_node.name = "BoardMap"
		add_child(board_map_node)
	
	# デフォルトでポリゴン背景を作成
	create_polygon_background()
	
	# ボードを作成
	board_system.create_board($BoardMap)
	
	# 特殊マスを配置
	special_tile_system.setup_special_tiles(board_system.total_tiles)
	
	# プレイヤーを初期化
	player_system.initialize_players(player_count, self)
	
	# カメラを初期化
	if camera_system:
		var created_camera = camera_system.initialize(self)
		
		# 初回のプレイヤーフォーカス設定
		if created_camera and player_system:
			var current_player = player_system.get_current_player()
			if current_player and current_player.piece_node:
				camera_system.focus_on_player(current_player.piece_node.position)
	
	# UIを作成（UILayerも作成される）
	ui_manager.create_ui(self)
	
	# 手札用ノードをUILayerに移動
	if has_node("UILayer"):
		var ui_layer = $UILayer
		if not ui_layer.has_node("Hand"):
			var hand_node = Node2D.new()
			hand_node.name = "Hand"
			ui_layer.add_child(hand_node)
	
	# UILayer作成後に手札を配る（重要！）
	card_system.deal_initial_hands_all_players(player_count)
	
	# 初期配置
	for i in range(player_count):
		player_system.place_player_at_tile(i, 0, board_system)
	
	# デバッグ表示用にCPU手札を更新
	if player_count > 1:
		ui_manager.update_cpu_hand_display(1)

# シグナルを接続
func connect_signals():
	# PlayerSystemのシグナル
	player_system.dice_rolled.connect(_on_dice_rolled)
	player_system.movement_completed.connect(_on_movement_completed)
	player_system.magic_changed.connect(_on_magic_changed)
	player_system.player_won.connect(_on_player_won)
	
	# CardSystemのシグナル
	card_system.card_used.connect(_on_card_used)
	card_system.hand_updated.connect(_on_hand_updated)
	
	# BattleSystemのシグナル
	battle_system.battle_ended.connect(_on_battle_ended)
	
	# UIManagerのシグナル
	ui_manager.dice_button_pressed.connect(_on_dice_button_pressed)
	ui_manager.pass_button_pressed.connect(_on_pass_button_pressed)
	ui_manager.card_selected.connect(_on_card_selected)
	ui_manager.level_up_selected.connect(_on_level_up_selected)
	
	# GameFlowManagerのシグナル
	game_flow.phase_changed.connect(_on_phase_changed)
	game_flow.turn_started.connect(_on_turn_started)
	game_flow.turn_ended.connect(_on_turn_ended)

# イベントハンドラー
func _on_level_up_selected(target_level: int, cost: int):
	game_flow.on_level_up_selected(target_level, cost)
	
func _on_dice_button_pressed():
	game_flow.roll_dice()

func _on_pass_button_pressed():
	game_flow.on_pass_button_pressed()

func _on_card_selected(card_index: int):
	game_flow.on_card_selected(card_index)

func _on_dice_rolled(value: int):
	print("ダイス: ", value)

func _on_movement_completed(final_tile: int):
	game_flow.on_movement_completed(final_tile)

func _on_card_used(card_data: Dictionary):
	print("カード使用: ", card_data.name)

func _on_hand_updated():
	# 現在のプレイヤーの手札数を表示
	var current_player = player_system.get_current_player()
	if current_player:
		var hand_size = card_system.get_hand_size_for_player(current_player.id)
		print(current_player.name, "の手札: ", hand_size, "枚")
		
		# デバッグモードの場合はCPU手札も更新
		if current_player.id > 0 and ui_manager.debug_mode:
			ui_manager.update_cpu_hand_display(current_player.id)

func _on_magic_changed(_player_id: int, _new_value: int):
	ui_manager.update_ui(player_system.get_current_player(), game_flow.current_phase)

func _on_battle_ended(winner: String, _result: Dictionary):
	print("バトル終了: ", winner, "の勝利")

func _on_player_won(player_id: int):
	game_flow.on_player_won(player_id)

func _on_phase_changed(new_phase: int):
	print("フェーズ変更: ", new_phase)

func _on_turn_started(player_id: int):
	print("ターン開始: プレイヤー", player_id + 1)
	# デバッグ表示を更新
	if player_id > 0 and ui_manager.debug_mode:
		ui_manager.update_cpu_hand_display(player_id)

func _on_turn_ended(player_id: int):
	print("ターン終了: プレイヤー", player_id + 1)

# 背景読み込み関数
func load_background(bg_path: String):
	# 既存の背景を削除
	if current_background and is_instance_valid(current_background):
		current_background.queue_free()
	
	if FileAccess.file_exists(bg_path):
		var texture = load(bg_path)
		if texture:
			var background = TextureRect.new()
			background.name = "MapBackground"
			background.z_index = -10
			
			# 統一サイズに設定
			var unified_size = Vector2(1500, 1000)
			background.custom_minimum_size = unified_size
			background.size = unified_size
			background.stretch_mode = TextureRect.STRETCH_SCALE
			background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			background.texture = texture
			
			# 中心に配置
			var board_center = Vector2(400, 300)
			background.position = board_center - (unified_size / 2)
			
			$BoardMap.add_child(background)
			current_background = background

# ポリゴン背景作成関数
func create_polygon_background():
	# 既存の背景を削除
	if current_background and is_instance_valid(current_background):
		current_background.queue_free()
	
	# 背景コンテナ
	var bg_container = Node2D.new()
	bg_container.name = "PolygonBackground"
	bg_container.z_index = -10
	$BoardMap.add_child(bg_container)
	current_background = bg_container
	
	# 宇宙背景（最背面）
	var space_bg = Polygon2D.new()
	space_bg.name = "SpaceBackground"
	space_bg.z_index = -3
	
	var space_points = PackedVector2Array([
		Vector2(-500, -400),
		Vector2(1300, -400),
		Vector2(1300, 1000),
		Vector2(-500, 1000)
	])
	space_bg.polygon = space_points
	space_bg.color = Color(0.05, 0.02, 0.1)
	
	var space_colors = PackedColorArray([
		Color(0.1, 0.05, 0.2),
		Color(0.02, 0.01, 0.05),
		Color(0.05, 0.02, 0.1),
		Color(0.08, 0.04, 0.15)
	])
	space_bg.vertex_colors = space_colors
	bg_container.add_child(space_bg)
	
	# 星雲効果
	create_nebula_effect(bg_container)
	
	# 浮遊する島
	var island = Polygon2D.new()
	island.name = "FloatingIsland"
	island.z_index = -1
	
	var island_points = PackedVector2Array([
		Vector2(100, 150),
		Vector2(250, 80),
		Vector2(550, 80),
		Vector2(700, 150),
		Vector2(700, 450),
		Vector2(550, 520),
		Vector2(250, 520),
		Vector2(100, 450),
	])
	island.polygon = island_points
	
	var island_colors = PackedColorArray([
		Color(0.4, 0.35, 0.3),
		Color(0.35, 0.3, 0.25),
		Color(0.3, 0.25, 0.2),
		Color(0.35, 0.3, 0.25),
		Color(0.25, 0.2, 0.15),
		Color(0.2, 0.15, 0.1),
		Color(0.25, 0.2, 0.15),
		Color(0.3, 0.25, 0.2)
	])
	island.vertex_colors = island_colors
	bg_container.add_child(island)
	
	# 島の側面
	var island_side = Polygon2D.new()
	island_side.name = "IslandSide"
	island_side.z_index = -2
	
	var side_points = PackedVector2Array([
		Vector2(100, 450),
		Vector2(250, 520),
		Vector2(550, 520),
		Vector2(700, 450),
		Vector2(650, 550),
		Vector2(400, 620),
		Vector2(150, 550),
	])
	island_side.polygon = side_points
	island_side.color = Color(0.15, 0.12, 0.1)
	bg_container.add_child(island_side)
	
	# 光るエッジ効果
	create_glow_edge(bg_container, island_points)
	
	# 星の追加
	create_stars(bg_container)

# 星雲効果を作成
func create_nebula_effect(parent: Node2D):
	var nebula = Polygon2D.new()
	nebula.name = "Nebula"
	nebula.z_index = -2
	nebula.modulate = Color(1, 1, 1, 0.3)
	
	var nebula_points = PackedVector2Array([
		Vector2(600, 50),
		Vector2(750, 100),
		Vector2(800, 250),
		Vector2(700, 350),
		Vector2(550, 300),
		Vector2(500, 150)
	])
	nebula.polygon = nebula_points
	
	var nebula_colors = PackedColorArray([
		Color(0.6, 0.3, 0.8, 0.3),
		Color(0.8, 0.4, 0.6, 0.2),
		Color(0.5, 0.3, 0.7, 0.1),
		Color(0.7, 0.4, 0.8, 0.2),
		Color(0.6, 0.3, 0.6, 0.3),
		Color(0.8, 0.5, 0.7, 0.2)
	])
	nebula.vertex_colors = nebula_colors
	parent.add_child(nebula)

# 光るエッジ効果
func create_glow_edge(parent: Node2D, island_points: PackedVector2Array):
	var glow = Line2D.new()
	glow.name = "GlowEdge"
	glow.z_index = 0
	glow.width = 3.0
	glow.default_color = Color(0.5, 0.7, 1.0, 0.5)
	
	for point in island_points:
		glow.add_point(point)
	glow.add_point(island_points[0])
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.3, 0.5, 0.8, 0.3))
	gradient.set_color(1, Color(0.6, 0.8, 1.0, 0.6))
	glow.gradient = gradient
	parent.add_child(glow)

# 星を散りばめる
func create_stars(parent: Node2D):
	var star_container = Node2D.new()
	star_container.name = "Stars"
	star_container.z_index = -2
	
	for i in range(30):
		var star = Polygon2D.new()
		var star_size = randf_range(2, 5)
		var star_points = PackedVector2Array([
			Vector2(-star_size, 0),
			Vector2(0, -star_size),
			Vector2(star_size, 0),
			Vector2(0, star_size)
		])
		star.polygon = star_points
		star.position = Vector2(
			randf_range(-400, 1200),
			randf_range(-300, 900)
		)
		var brightness = randf_range(0.5, 1.0)
		star.color = Color(brightness, brightness, brightness * 0.9)
		star.rotation = randf_range(0, PI/4)
		star_container.add_child(star)
	
	parent.add_child(star_container)

# 次の背景に切り替え
func switch_to_next_background():
	current_bg_index = (current_bg_index + 1) % background_paths.size()
	
	for i in range(background_paths.size()):
		var index = (current_bg_index + i) % background_paths.size()
		var path = background_paths[index]
		if FileAccess.file_exists(path):
			current_bg_index = index
			load_background(path)
			return

# 特定の背景に切り替え
func switch_to_background(index: int):
	if index >= 0 and index < background_paths.size():
		var path = background_paths[index]
		if FileAccess.file_exists(path):
			current_bg_index = index
			load_background(path)

# デバッグ入力処理
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M:  # Mキーで次の背景に切り替え
				switch_to_next_background()
			KEY_P:  # Pキーでポリゴン背景に切り替え
				create_polygon_background()
			KEY_B:  # Bキー + 数字で特定の背景に切り替え
				if Input.is_key_pressed(KEY_1):
					switch_to_background(0)
				elif Input.is_key_pressed(KEY_2):
					switch_to_background(1)
				elif Input.is_key_pressed(KEY_3):
					switch_to_background(2)
				elif Input.is_key_pressed(KEY_4):
					switch_to_background(3)
