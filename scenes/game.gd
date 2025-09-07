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
var summon_button: Button  # 追加
var pass_button: Button    # 追加
var waiting_for_choice = false  # 選択待ちフラグ
var player_choice = ""      # プレイヤーの選択

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
	
	# 召喚ボタン（新規追加）
	summon_button = Button.new()
	summon_button.text = "召喚する"
	summon_button.position = Vector2(300, 400)
	summon_button.size = Vector2(100, 40)
	summon_button.pressed.connect(_on_summon_button_pressed)
	summon_button.visible = false
	add_child(summon_button)
	
	# パスボタン（新規追加）
	pass_button = Button.new()
	pass_button.text = "召喚しない"
	pass_button.position = Vector2(420, 400)
	pass_button.size = Vector2(100, 40)
	pass_button.pressed.connect(_on_pass_button_pressed)
	pass_button.visible = false
	add_child(pass_button)
	
	update_ui()

# ゲーム開始
func start_game():
	print("ゲーム開始！")
	
	# 手札の表示を同期（エラーが出る場合はコメントアウト）
	# card_system.sync_hand_display()
	
	current_phase = GamePhase.DICE_ROLL
	dice_button.disabled = false
	update_ui()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	print("\n--- ", current_player.name, "のターン開始 ---")
	print("ドロー前: データ=", card_system.hand_data.size(), " 表示=", card_system.hand_cards.size())
	
	# カードを1枚引く
	if card_system.get_hand_size() < card_system.max_hand_size:
		print("ドロー実行中...")
		var drawn_card = card_system.draw_card()
		if drawn_card.is_empty():
			print("ドローに失敗しました")
		else:
			print("ドロー成功: ", drawn_card.get("name", "不明"))
	else:
		print("手札が上限です (", card_system.max_hand_size, "枚)")
	
	print("ドロー後: データ=", card_system.hand_data.size(), " 表示=", card_system.hand_cards.size())
	
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

# 土地レベルアップダイアログ
func show_land_upgrade_dialog():
	print("自分の土地です（レベルアップは未実装）")
	end_turn()

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

# 土地取得ダイアログ（選択式UI版）
func show_land_acquisition_dialog():
	var current_player = player_system.get_current_player()
	
	# まず土地を取得（無料）
	board_system.set_tile_owner(current_player.current_tile, current_player.id)
	print("土地を取得しました！")
	
	# 手札がある場合のみクリーチャー召喚の選択
	if card_system.get_hand_size() > 0:
		# プレイヤー1の場合は選択UIを表示
		if current_player.id == 0:
			show_summon_choice()
			# 選択を待つ
			while waiting_for_choice:
				await get_tree().process_frame
			
			# プレイヤーの選択に応じて処理
			if player_choice == "summon":
				try_summon_creature(current_player)
			else:
				print("召喚をスキップしました")
		else:
			# CPU（プレイヤー2）は30%の確率で召喚（デバッグ用に確率を下げる）
			if randf() > 0.7:  # 30%の確率
				print("CPU: クリーチャーを召喚します")
				try_summon_creature(current_player)
			else:
				print("CPU: 召喚をスキップ")
	else:
		print("手札がないためクリーチャーは召喚できません")
	
	end_turn()

# 召喚選択UIを表示
func show_summon_choice():
	print("クリーチャーを召喚しますか？")
	var current_player = player_system.get_current_player()
	
	# 手札チェック（念のため）
	if card_system.get_hand_size() == 0:
		print("ERROR: 手札がないのに選択UIが呼ばれました")
		waiting_for_choice = false
		return
	
	# 最初のカードの情報を表示
	var card_data = card_system.get_card_data(0)
	if not card_data.is_empty():
		var cost = skill_system.modify_card_cost(card_data.get("cost", 1) * 10, card_data, current_player.id)
		phase_label.text = card_data.get("name", "不明") + " (コスト: " + str(cost) + "G)"
		
		# 魔力が足りない場合は自動的にパス
		if current_player.magic_power < cost:
			phase_label.text = "魔力不足 - 召喚不可"
			print("魔力が足りないため召喚できません")
			waiting_for_choice = false
			await get_tree().create_timer(1.0).timeout
			return
	
	summon_button.visible = true
	pass_button.visible = true
	waiting_for_choice = true
	player_choice = ""

# クリーチャー召喚を試みる
func try_summon_creature(current_player):
	if card_system.get_hand_size() > 0:
		var card_data = card_system.get_card_data(0)
		if not card_data.is_empty():
			var cost = skill_system.modify_card_cost(card_data.get("cost", 1) * 10, card_data, current_player.id)
			
			if current_player.magic_power >= cost:
				var used_card = card_system.use_card(0)
				if not used_card.is_empty():
					board_system.place_creature(current_player.current_tile, used_card)
					player_system.add_magic(current_player.id, -cost)
					print("クリーチャー「", used_card.get("name", "不明"), "」を召喚！(-", cost, "G)")
			else:
				print("魔力が足りません！必要: ", cost, "G")

# 召喚ボタンが押された
func _on_summon_button_pressed():
	if waiting_for_choice:
		player_choice = "summon"
		waiting_for_choice = false
		summon_button.visible = false
		pass_button.visible = false
		phase_label.text = "アクション選択"

# パスボタンが押された
func _on_pass_button_pressed():
	if waiting_for_choice:
		player_choice = "pass"
		waiting_for_choice = false
		summon_button.visible = false
		pass_button.visible = false
		phase_label.text = "アクション選択"

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
