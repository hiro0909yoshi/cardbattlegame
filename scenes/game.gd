extends Node2D

# メインゲーム管理スクリプト（リファクタリング版）

# システムの参照
var board_system: BoardSystem
var card_system: CardSystem
var player_system: PlayerSystem
var battle_system: BattleSystem
var skill_system: SkillSystem

# ゲーム状態
enum GamePhase {
	SETUP,
	DICE_ROLL,
	MOVING,
	TILE_ACTION,
	BATTLE,
	END_TURN
}

var current_phase = GamePhase.SETUP
var player_count = 2  # プレイヤー数

# UI要素
var dice_button: Button
var turn_label: Label
var magic_label: Label
var phase_label: Label

func _ready():
	print("=== カルドセプト風ゲーム開始 ===")
	initialize_systems()
	setup_game()
	create_ui()
	start_game()

# システムを初期化
func initialize_systems():
	# 各システムをインスタンス化
	board_system = BoardSystem.new()
	card_system = CardSystem.new()
	player_system = PlayerSystem.new()
	battle_system = BattleSystem.new()
	skill_system = SkillSystem.new()
	
	# シーンツリーに追加
	add_child(board_system)
	add_child(card_system)
	add_child(player_system)
	add_child(battle_system)
	add_child(skill_system)
	
	# シグナル接続
	connect_signals()
	
	print("全システム初期化完了")

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

# ゲームをセットアップ
func setup_game():
	# BoardMapノードがなければ作成
	if not has_node("BoardMap"):
		var board_map_node = Node2D.new()
		board_map_node.name = "BoardMap"
		add_child(board_map_node)
	
	# ボードを作成
	board_system.create_board($BoardMap)
	
	# プレイヤーを初期化
	player_system.initialize_players(player_count, self)
	
	# 各プレイヤーに初期手札を配る
	if not has_node("Hand"):
		var hand_node = Node2D.new()
		hand_node.name = "Hand"
		add_child(hand_node)
	
	card_system.deal_initial_hand($Hand)
	
	# 初期配置
	for i in range(player_count):
		player_system.place_player_at_tile(i, 0, board_system)

# UIを作成
func create_ui():
	# フェーズ表示
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	phase_label.position = Vector2(350, 50)
	phase_label.add_theme_font_size_override("font_size", 24)
	add_child(phase_label)
	
	# ターン表示
	turn_label = Label.new()
	turn_label.position = Vector2(50, 30)
	turn_label.add_theme_font_size_override("font_size", 16)
	add_child(turn_label)
	
	# 魔力表示
	magic_label = Label.new()
	magic_label.position = Vector2(50, 60)
	magic_label.add_theme_font_size_override("font_size", 16)
	add_child(magic_label)
	
	# サイコロボタン
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	dice_button.position = Vector2(350, 250)
	dice_button.size = Vector2(120, 40)
	dice_button.pressed.connect(_on_dice_button_pressed)
	dice_button.disabled = true
	add_child(dice_button)
	
	update_ui()

# ゲーム開始
func start_game():
	print("ゲーム開始！")
	current_phase = GamePhase.DICE_ROLL
	dice_button.disabled = false
	update_ui()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	print("\n--- ", current_player.name, "のターン開始 ---")
	
	# カードを1枚引く
	if card_system.get_hand_size() < card_system.max_hand_size:
		card_system.draw_card()
	
	current_phase = GamePhase.DICE_ROLL
	dice_button.disabled = false
	update_ui()

# サイコロボタンが押された
func _on_dice_button_pressed():
	if current_phase != GamePhase.DICE_ROLL:
		return
	
	dice_button.disabled = true
	current_phase = GamePhase.MOVING
	
	# サイコロを振る
	var dice_value = player_system.roll_dice()
	
	# スキルシステムでダイス目を修正
	var modified_dice = skill_system.modify_dice_roll(dice_value, player_system.current_player_index)
	if modified_dice != dice_value:
		print("ダイス目修正: ", dice_value, " → ", modified_dice)
	
	# ダイス結果表示
	show_dice_result(modified_dice)
	
	# 移動開始
	var current_player = player_system.get_current_player()
	await get_tree().create_timer(1.0).timeout
	player_system.move_player_steps(current_player.id, modified_dice, board_system)

# ダイス結果を表示
func show_dice_result(value: int):
	var dice_label = Label.new()
	dice_label.text = "🎲 " + str(value)
	dice_label.add_theme_font_size_override("font_size", 48)
	dice_label.position = Vector2(350, 300)
	add_child(dice_label)
	
	# 1秒後に消す
	await get_tree().create_timer(1.0).timeout
	dice_label.queue_free()

# ダイスロール完了
func _on_dice_rolled(value: int):
	print("ダイス: ", value)

# 移動完了
func _on_movement_completed(final_tile: int):
	current_phase = GamePhase.TILE_ACTION
	print("到着: マス", final_tile)
	
	# タイル情報を取得
	var tile_info = board_system.get_tile_info(final_tile)
	var current_player = player_system.get_current_player()
	
	# タイルの種類による処理
	match tile_info.type:
		BoardSystem.TileType.START:
			print("スタート地点！追加ボーナス100G")
			player_system.add_magic(current_player.id, 100)
			end_turn()
			
		BoardSystem.TileType.CHECKPOINT:
			print("チェックポイント！ボーナス100G")
			player_system.add_magic(current_player.id, 100)
			end_turn()
			
		BoardSystem.TileType.NORMAL:
			process_normal_tile(tile_info)

# 通常タイルの処理
func process_normal_tile(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	if tile_info.owner == -1:
		# 空き地
		print("空き地です")
		show_land_acquisition_dialog()
	elif tile_info.owner == current_player.id:
		# 自分の土地
		print("自分の土地です")
		show_land_upgrade_dialog()
	else:
		# 他人の土地
		print("他人の土地！")
		process_enemy_land(tile_info)

# 土地取得ダイアログ（仮実装）
func show_land_acquisition_dialog():
	var current_player = player_system.get_current_player()
	
	# まず土地を取得（無料）
	board_system.set_tile_owner(current_player.current_tile, current_player.id)
	print("土地を取得しました！")
	
	# デバッグ情報
	print("DEBUG: プレイヤー", current_player.id + 1, "の手札枚数 = ", card_system.get_hand_size())
	
	# 手札がある場合のみクリーチャー召喚の選択
	if card_system.get_hand_size() > 0:
		print("クリーチャーを召喚しますか？")
		
		# 仮実装：自動で最初のカードを使用
		await get_tree().create_timer(1.0).timeout
		
		# もう一度チェック
		if card_system.get_hand_size() == 0:
			print("手札がなくなりました")
			end_turn()
			return
		
		# カードデータを安全に取得
		var card_data = card_system.get_card_data(0)
		if card_data.is_empty():
			print("ERROR: カードデータが取得できません")
			end_turn()
			return
		
		# コスト計算
		var base_cost = card_data.get("cost", 1)
		if base_cost == null:
			base_cost = 1
		var cost = skill_system.modify_card_cost(base_cost * 10, card_data, current_player.id)
		
		# 魔力チェック
		if current_player.magic_power >= cost:
			# カードを使用
			var used_card = card_system.use_card(0)
			if not used_card.is_empty():
				board_system.place_creature(current_player.current_tile, used_card)
				player_system.add_magic(current_player.id, -cost)
				print("クリーチャー「", used_card.get("name", "不明"), "」を召喚！(-", cost, "G)")
		else:
			print("魔力が足りません！必要: ", cost, "G 所持: ", current_player.magic_power, "G")
	else:
		print("手札がないためクリーチャーは召喚できません")
	
	end_turn()

# 土地レベルアップダイアログ（仮実装）
func show_land_upgrade_dialog():
	print("土地をレベルアップしますか？（未実装）")
	end_turn()

# 敵の土地での処理
func process_enemy_land(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	if tile_info.creature.is_empty():
		# クリーチャーがいない場合は通行料
		var toll = board_system.calculate_toll(tile_info.index)
		toll = skill_system.modify_toll(toll, current_player.id, tile_info.owner)
		
		print("通行料: ", toll, "G")
		player_system.pay_toll(current_player.id, tile_info.owner, toll)
		end_turn()
	else:
		# クリーチャーがいる場合はバトル
		print("バトル発生！（未実装）")
		# TODO: バトル処理
		end_turn()

# カード使用時
func _on_card_used(card_data: Dictionary):
	print("カード使用: ", card_data.name)

# 手札更新時
func _on_hand_updated():
	print("手札: ", card_system.get_hand_size(), "枚")

# 魔力変更時
func _on_magic_changed(player_id: int, new_value: int):
	update_ui()

# バトル終了時
func _on_battle_ended(winner: String, result: Dictionary):
	print("バトル終了: ", winner, "の勝利")
	end_turn()

# プレイヤー勝利時
func _on_player_won(player_id: int):
	var player = player_system.players[player_id]
	print("\n🎉 ゲーム終了！", player.name, "の勝利！🎉")
	current_phase = GamePhase.SETUP
	dice_button.disabled = true
	phase_label.text = player.name + "の勝利！"

# ターン終了
func end_turn():
	print("ターン終了")
	current_phase = GamePhase.END_TURN
	
	# スキル効果のクリーンアップ
	skill_system.end_turn_cleanup()
	
	# 次のプレイヤーへ
	player_system.next_player()
	
	# 次のターン開始
	await get_tree().create_timer(1.0).timeout
	start_turn()

# UI更新
func update_ui():
	var current_player = player_system.get_current_player()
	
	if current_player:
		turn_label.text = current_player.name + "のターン"
		magic_label.text = "魔力: " + str(current_player.magic_power) + " / " + str(current_player.target_magic) + " G"
	
	# フェーズ表示
	match current_phase:
		GamePhase.SETUP:
			phase_label.text = "準備中..."
		GamePhase.DICE_ROLL:
			phase_label.text = "サイコロを振ってください"
		GamePhase.MOVING:
			phase_label.text = "移動中..."
		GamePhase.TILE_ACTION:
			phase_label.text = "アクション選択"
		GamePhase.BATTLE:
			phase_label.text = "バトル！"
		GamePhase.END_TURN:
			phase_label.text = "ターン終了"
