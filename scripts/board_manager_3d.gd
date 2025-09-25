extends Node3D
class_name BoardManager3D

# タイル管理
var tile_nodes = {}
var player_node = null
var current_tile = 0

# 移動制御
var is_moving = false
var move_speed = 2.0
var is_waiting_for_card_selection = false

# デバッグ機能
var debug_mode = false
var fixed_dice_value = 0

# カメラ参照
var camera = null

# システム参照
var ui_manager = null
var player_system = null
var card_system = null
var board_system = null
var skill_system = null

# ゲーム定数
const GameConstants = preload("res://scripts/game_constants.gd")

func _ready():
	collect_tiles()
	setup_connections()
	find_player()
	setup_camera()
	setup_ui_system()
	
	print("=== BoardManager初期化 ===")
	print("タイル総数: ", tile_nodes.size())
	print("\n【操作方法】")
	print("スペース: サイコロを振る")
	print("6-9キー: サイコロ固定")
	print("0キー: 固定解除")

# UIシステムのセットアップ
func setup_ui_system():
	print("UIシステムのセットアップ開始...")
	
	# PlayerSystemを作成
	player_system = Node.new()
	player_system.name = "PlayerSystem"
	player_system.set_script(load("res://scripts/player_system.gd"))
	add_child(player_system)
	
	# プレイヤーデータを初期化
	player_system.players = []
	for i in range(2):
		var player_data = player_system.PlayerData.new()
		player_data.id = i
		player_data.name = "プレイヤー" + str(i + 1)
		player_data.magic_power = GameConstants.INITIAL_MAGIC
		player_data.target_magic = GameConstants.TARGET_MAGIC
		player_data.current_tile = 0
		player_system.players.append(player_data)
	player_system.current_player_index = 0
	
	# CardSystemを作成
	card_system = Node.new()
	card_system.name = "CardSystem"
	card_system.set_script(load("res://scripts/card_system.gd"))
	add_child(card_system)
	
	# BoardSystemを作成
	board_system = Node.new()
	board_system.name = "BoardSystem"
	board_system.set_script(load("res://scripts/board_system.gd"))
	add_child(board_system)
	
	# BoardSystemを初期化
	if board_system.has_method("initialize_tile_data"):
		board_system.initialize_tile_data()
	
	# SkillSystemを作成
	skill_system = Node.new()
	skill_system.name = "SkillSystem"
	add_child(skill_system)
	
	# UILayerを作成
	if not has_node("UILayer"):
		var ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		add_child(ui_layer)
	
	# UIManagerを作成
	var UIManagerClass = load("res://scripts/ui_manager.gd")
	if UIManagerClass:
		ui_manager = UIManagerClass.new()
		ui_manager.name = "UIManager"
		$UILayer.add_child(ui_manager)
		
		# UIを作成
		ui_manager.create_ui(self)
		
		# Handノードを確認・作成
		await get_tree().process_frame
		if not $UILayer.has_node("Hand"):
			var hand_node = Node2D.new()
			hand_node.name = "Hand"
			$UILayer.add_child(hand_node)
		
		await get_tree().create_timer(0.1).timeout
		
		# サイコロボタンを接続
		if ui_manager.get("dice_button") != null:
			var dice_btn = ui_manager.get("dice_button")
			if dice_btn and dice_btn is Button:
				dice_btn.pressed.connect(_on_dice_button_pressed)
				ui_manager.set_dice_button_enabled(true)
		
		# シグナルを接続
		if ui_manager.has_signal("dice_button_pressed"):
			if not ui_manager.dice_button_pressed.is_connected(_on_dice_button_pressed):
				ui_manager.dice_button_pressed.connect(_on_dice_button_pressed)
		
		if ui_manager.has_signal("card_selected"):
			ui_manager.card_selected.connect(on_card_selected)
		
		if ui_manager.has_signal("pass_button_pressed"):
			ui_manager.pass_button_pressed.connect(on_summon_pass)
		
		# フェーズ表示を初期化
		if ui_manager.phase_label:
			ui_manager.phase_label.text = "サイコロを振ってください"
	
	# 初期手札を配る
	await get_tree().process_frame
	
	var original_name = self.name
	self.name = "Game"  # CardSystemがHandノードを見つけるため
	
	if card_system and card_system.has_method("deal_initial_hands_all_players"):
		card_system.deal_initial_hands_all_players(2)
		print("初期手札を配りました")
		print("プレイヤー1の手札: ", card_system.get_hand_size_for_player(0), "枚")
		print("プレイヤー2の手札: ", card_system.get_hand_size_for_player(1), "枚")
	
	self.name = original_name

# カメラを設定
func setup_camera():
	camera = get_node_or_null("Camera3D")
	if camera and player_node:
		var offset = Vector3(0, 10, 10)
		camera.global_position = player_node.global_position + offset
		camera.look_at(player_node.global_position, Vector3.UP)

# タイルを収集
func collect_tiles():
	for child in get_children():
		if child is BaseTile:
			tile_nodes[child.tile_index] = child

# タイル間の接続設定
func setup_connections():
	for i in range(20):
		if tile_nodes.has(i):
			var next_index = (i + 1) % 20
			tile_nodes[i].connections["next"] = next_index

# プレイヤーを探す
func find_player():
	for child in get_children():
		if child.name == "Player":
			player_node = child
			if tile_nodes.has(0):
				var start_pos = tile_nodes[0].global_position
				start_pos.y += 1.0
				player_node.global_position = start_pos

# タイル位置を取得
func get_tile_position(index: int) -> Vector3:
	if tile_nodes.has(index):
		var pos = tile_nodes[index].global_position
		pos.y += 1.0
		return pos
	return Vector3.ZERO

# サイコロボタンが押された時
func _on_dice_button_pressed():
	roll_dice_and_move()

# サイコロを振って移動
func roll_dice_and_move():
	if is_moving:
		return
		
	is_moving = true
	
	if ui_manager and ui_manager.dice_button:
		ui_manager.set_dice_button_enabled(false)
	
	var dice_value
	if debug_mode and fixed_dice_value > 0:
		dice_value = fixed_dice_value
		print("\n🎲 サイコロ: ", dice_value, " (固定)")
	else:
		dice_value = randi_range(1, 6)
		print("\n🎲 サイコロ: ", dice_value)
	
	if ui_manager:
		ui_manager.show_dice_result(dice_value, self)
	
	# 経路を作成
	var path = []
	var temp_tile = current_tile
	for i in range(dice_value):
		temp_tile = (temp_tile + 1) % 20
		path.append(temp_tile)
	
	await move_along_path(path)
	
	print("移動完了: タイル", current_tile, "に到着")
	
	if tile_nodes.has(current_tile):
		var tile = tile_nodes[current_tile]
		print("タイル種類: ", tile.tile_type)
		
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "タイル: " + tile.tile_type
		
		process_tile_landing()
	
	if ui_manager and ui_manager.dice_button:
		ui_manager.set_dice_button_enabled(true)
	
	is_moving = false

# 経路に沿って移動
func move_along_path(path: Array):
	for tile_index in path:
		current_tile = tile_index
		var target_pos = get_tile_position(tile_index)
		
		print("  → タイル", tile_index)
		
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		
		# プレイヤー移動
		tween.tween_property(player_node, "global_position", target_pos, 0.5)
		
		# カメラ移動
		if camera:
			var cam_offset = Vector3(0, 10, 10)
			var cam_target = target_pos + cam_offset
			tween.tween_property(camera, "global_position", cam_target, 0.5)
			
		await tween.finished
		
		if camera:
			camera.look_at(player_node.global_position, Vector3.UP)
		
		# スタート地点通過チェック
		if tile_index == 0:
			print("スタート地点通過！ボーナス: ", GameConstants.START_BONUS, "G")
			if player_system and player_system.players.size() > 0:
				player_system.players[0]["magic_power"] += GameConstants.START_BONUS
				if ui_manager:
					ui_manager.update_player_info_panels()

# タイル到着時の処理
func process_tile_landing():
	if not tile_nodes.has(current_tile):
		return
	
	var tile = tile_nodes[current_tile]
	var current_player_id = player_system.current_player_index
	var tile_info = tile.get_tile_info()
	
	# 所有者チェック
	if tile_info.owner == -1:
		# 空き地
		print("空き地です。モンスターを召喚して土地を取得できます")
		show_summon_ui()
	elif tile_info.owner == current_player_id:
		# 自分の土地
		print("自分の土地です（レベル", tile_info.level, "）")
		end_turn()  # 一旦スキップ
	else:
		# 敵の土地
		print("敵の土地です！")
		if tile_info.creature.is_empty():
			print("守るクリーチャーがいません。侵略可能です")
		else:
			print("クリーチャーがいます。バトルまたは通行料")
		end_turn()  # 一旦スキップ

# 召喚UIを表示
func show_summon_ui():
	var current_player_id = player_system.current_player_index
	
	var hand_size = card_system.get_hand_size_for_player(current_player_id)
	if hand_size == 0:
		print("手札がありません！")
		end_turn()
		return
	
	var current_magic = player_system.players[current_player_id].magic_power
	print("現在の魔力: ", current_magic, "G")
	
	if ui_manager.has_method("show_card_selection_ui"):
		print("カード選択UIを表示します")
		ui_manager.phase_label.text = "召喚するクリーチャーを選択"
		
		if current_player_id == 0:  # プレイヤー1のみ
			ui_manager.show_card_selection_ui(player_system.players[current_player_id])
			is_waiting_for_card_selection = true
			await get_tree().process_frame
			setup_card_selection()

# カード選択を設定
func setup_card_selection():
	if card_system.has_method("set_cards_selectable"):
		card_system.set_cards_selectable(true)

# カードが選択された時
func on_card_selected(card_index: int):
	print("カード選択: インデックス ", card_index)
	
	if not is_waiting_for_card_selection:
		return
	
	is_waiting_for_card_selection = false
	var current_player_id = player_system.current_player_index
	
	var card_data = card_system.get_card_data_for_player(current_player_id, card_index)
	if card_data.is_empty():
		print("カードデータが取得できません")
		return
	
	print("選択されたカード: ", card_data.get("name", "不明"))
	
	var cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	print("カードコスト: ", cost, "G")
	
	if player_system.players[current_player_id].magic_power < cost:
		print("魔力不足！現在: ", player_system.players[current_player_id].magic_power, "G")
		return
	
	var used_card = card_system.use_card_for_player(current_player_id, card_index)
	if not used_card.is_empty():
		player_system.players[current_player_id].magic_power -= cost
		acquire_land_with_summon(used_card)
		ui_manager.hide_card_selection_ui()
		ui_manager.update_player_info_panels()
		print("「", used_card.get("name", "不明"), "」を召喚しました！")
		end_turn()

# 土地を取得
func acquire_land_with_summon(creature_data: Dictionary = {}):
	if not tile_nodes.has(current_tile):
		return
	
	var tile = tile_nodes[current_tile]
	var current_player_id = player_system.current_player_index
	
	tile.set_tile_owner(current_player_id)
	
	if not creature_data.is_empty():
		tile.place_creature(creature_data)
	
	if board_system:
		board_system.tile_owners[current_tile] = current_player_id
	
	print("土地を取得しました！")
	
	if ui_manager:
		ui_manager.update_player_info_panels()

# 召喚をパス
func on_summon_pass():
	print("召喚をパスしました")
	is_waiting_for_card_selection = false
	ui_manager.hide_card_selection_ui()
	end_turn()

# ターン終了
func end_turn():
	print("ターン終了")
	if ui_manager:
		ui_manager.set_dice_button_enabled(true)
		ui_manager.phase_label.text = "サイコロを振ってください"

# サイコロ値を固定
func set_fixed_dice(value: int):
	if value >= 1 and value <= 6:
		debug_mode = true
		fixed_dice_value = value
		print("【デバッグ】サイコロ固定: ", value)
	elif value == 0:
		debug_mode = false
		fixed_dice_value = 0
		print("【デバッグ】サイコロ固定解除")

# 入力処理
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_on_dice_button_pressed()
			KEY_6:
				set_fixed_dice(6)
			KEY_7:
				set_fixed_dice(1)
			KEY_8:
				set_fixed_dice(2)
			KEY_9:
				set_fixed_dice(3)
			KEY_0:
				set_fixed_dice(0)
			KEY_D:
				if ui_manager:
					ui_manager.toggle_debug_mode()
