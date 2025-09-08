extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム - バトル対応版

signal phase_changed(new_phase: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)

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
var waiting_for_choice = false
var player_choice = ""
var waiting_for_battle = false  # バトル選択待機フラグ

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var board_system: BoardSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var battle_system: BattleSystem  # 追加

func _ready():
	pass

# システム参照を設定（battle_system追加）
func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BoardSystem, s_system: SkillSystem, ui_system: UIManager, bt_system: BattleSystem = null):
	player_system = p_system
	card_system = c_system
	board_system = b_system
	skill_system = s_system
	ui_manager = ui_system
	battle_system = bt_system

# ゲーム開始
func start_game():
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	
	# 現在のプレイヤーの手札情報を表示
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	
	# カードを1枚引く
	if hand_size < card_system.max_hand_size:
		var drawn_card = card_system.draw_card_for_player(current_player.id)
		if not drawn_card.is_empty():
			# デバッグ表示を更新（CPUの場合）
			if current_player.id > 0:
				ui_manager.update_cpu_hand_display(current_player.id)
	
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()

# フェーズ変更
func change_phase(new_phase: GamePhase):
	current_phase = new_phase
	emit_signal("phase_changed", current_phase)
	update_ui()

# サイコロを振る
func roll_dice():
	if current_phase != GamePhase.DICE_ROLL:
		return
	
	ui_manager.set_dice_button_enabled(false)
	change_phase(GamePhase.MOVING)
	
	# サイコロを振る
	var dice_value = player_system.roll_dice()
	
	# スキルシステムでダイス目を修正
	var modified_dice = skill_system.modify_dice_roll(dice_value, player_system.current_player_index)
	if modified_dice != dice_value:
		print("ダイス目修正: ", dice_value, " → ", modified_dice)
	
	# ダイス結果表示
	ui_manager.show_dice_result(modified_dice, get_parent())
	
	# 移動開始
	var current_player = player_system.get_current_player()
	await get_tree().create_timer(1.0).timeout
	player_system.move_player_steps(current_player.id, modified_dice, board_system)

# 移動完了
func on_movement_completed(final_tile: int):
	change_phase(GamePhase.TILE_ACTION)
	
	# タイル情報を取得
	var tile_info = board_system.get_tile_info(final_tile)
	var current_player = player_system.get_current_player()
	
	# タイルの種類による処理
	match tile_info.type:
		BoardSystem.TileType.START:
			player_system.add_magic(current_player.id, 100)
			end_turn()
			
		BoardSystem.TileType.CHECKPOINT:
			player_system.add_magic(current_player.id, 100)
			end_turn()
			
		BoardSystem.TileType.NORMAL:
			process_normal_tile(tile_info)

# 通常タイルの処理
func process_normal_tile(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	if tile_info.owner == -1:
		# 空き地
		process_land_acquisition()
	elif tile_info.owner == current_player.id:
		# 自分の土地
		end_turn()
	else:
		# 他人の土地
		process_enemy_land(tile_info)

# 土地取得処理
func process_land_acquisition():
	var current_player = player_system.get_current_player()
	
	# 土地を取得（無料）
	board_system.set_tile_owner(current_player.current_tile, current_player.id)
	
	# 手札がある場合のみクリーチャー召喚の選択
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size > 0:
		if current_player.id == 0:
			# プレイヤー1の場合は選択UIを表示
			await show_summon_choice()
		else:
			# CPUの召喚処理
			await cpu_summon_decision(current_player)
	
	end_turn()

# CPU召喚判断
func cpu_summon_decision(current_player):
	# 支払い可能なカードを探す
	var affordable_cards = card_system.find_affordable_cards_for_player(
		current_player.id, 
		current_player.magic_power
	)
	
	if affordable_cards.is_empty():
		return
	
	# 90%の確率で召喚
	if randf() > 0.1:
		# 最も安いカードを選択
		var card_index = card_system.get_cheapest_card_index_for_player(current_player.id)
		if card_index >= 0:
			var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
			var cost = skill_system.modify_card_cost(
				card_data.get("cost", 1) * 10, 
				card_data, 
				current_player.id
			)
			
			try_summon_creature_for_player(current_player, card_index)

# 召喚選択UIを表示（プレイヤー1用）
func show_summon_choice():
	var current_player = player_system.get_current_player()
	
	var hand_size = card_system.get_hand_size_for_player(0)
	if hand_size == 0:
		return
	
	# カード選択UIを表示
	ui_manager.show_card_selection_ui(current_player)
	waiting_for_choice = true
	player_choice = ""
	
	# 選択を待つ
	while waiting_for_choice:
		await get_tree().process_frame
	
	# プレイヤーの選択に応じて処理
	if player_choice != "pass" and player_choice != "":
		var card_index = int(player_choice)
		try_summon_creature_for_player(current_player, card_index)

# カード選択された（UI経由）
func on_card_selected(card_index: int):
	if waiting_for_choice:
		player_choice = str(card_index)
		waiting_for_choice = false
		ui_manager.hide_card_selection_ui()
	elif waiting_for_battle:
		# バトル用のカード選択
		player_choice = str(card_index)
		waiting_for_battle = false
		ui_manager.hide_card_selection_ui()

# クリーチャー召喚を試みる
func try_summon_creature_for_player(current_player, card_index: int):
	var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
	if not card_data.is_empty():
		var cost = skill_system.modify_card_cost(
			card_data.get("cost", 1) * 10, 
			card_data, 
			current_player.id
		)
		
		if current_player.magic_power >= cost:
			var used_card = card_system.use_card_for_player(current_player.id, card_index)
			if not used_card.is_empty():
				board_system.place_creature(current_player.current_tile, used_card)
				player_system.add_magic(current_player.id, -cost)
				
				# CPUの手札表示を更新
				if current_player.id > 0:
					ui_manager.update_cpu_hand_display(current_player.id)

# 敵の土地での処理
func process_enemy_land(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	if tile_info.creature.is_empty():
		# クリーチャーがいない場合は通行料
		var toll = board_system.calculate_toll(tile_info.index)
		toll = skill_system.modify_toll(toll, current_player.id, tile_info.owner)
		
		player_system.pay_toll(current_player.id, tile_info.owner, toll)
		end_turn()
	else:
		# クリーチャーがいる場合はバトル
		change_phase(GamePhase.BATTLE)
		await process_battle(tile_info)

# バトル処理
func process_battle(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	print("\n敵クリーチャーがいます！バトルするか選択してください")
	
	# 手札がない場合は通行料支払い
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size == 0:
		print("手札がないため通行料を支払います")
		var toll = board_system.calculate_toll(tile_info.index)
		toll = skill_system.modify_toll(toll, current_player.id, tile_info.owner)
		player_system.pay_toll(current_player.id, tile_info.owner, toll)
		end_turn()
		return
	
	# プレイヤーかCPUかで処理を分岐
	if current_player.id == 0:
		# プレイヤー1: バトル選択UIを表示
		await show_battle_choice(tile_info)
	else:
		# CPU: 自動でバトル判断
		await cpu_battle_decision(current_player, tile_info)
	
	end_turn()

# バトル選択UIを表示
func show_battle_choice(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	# 選択UI表示（カード選択と同じUIを流用）
	ui_manager.phase_label.text = "バトルするクリーチャーを選択（またはパスで通行料）"
	ui_manager.show_card_selection_ui(current_player)
	
	waiting_for_battle = true
	player_choice = ""
	
	# 選択を待つ
	while waiting_for_battle:
		await get_tree().process_frame
	
	if player_choice != "pass" and player_choice != "":
		# バトル実行
		var card_index = int(player_choice)
		execute_player_battle(current_player, card_index, tile_info)
	else:
		# 通行料支払い
		var toll = board_system.calculate_toll(tile_info.index)
		toll = skill_system.modify_toll(toll, current_player.id, tile_info.owner)
		player_system.pay_toll(current_player.id, tile_info.owner, toll)

# プレイヤーのバトル実行
func execute_player_battle(current_player, card_index: int, tile_info: Dictionary):
	if not battle_system:
		print("ERROR: BattleSystemが設定されていません")
		return
	
	# バトル実行
	var result = battle_system.execute_invasion_battle(
		current_player.id,
		card_index,
		tile_info,
		card_system,
		board_system
	)
	
	if result.success:
		# カードを使用（コスト支払い）
		var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
		var cost = skill_system.modify_card_cost(
			card_data.get("cost", 1) * 10,
			card_data,
			current_player.id
		)
		
		card_system.use_card_for_player(current_player.id, card_index)
		player_system.add_magic(current_player.id, -cost)
		
		# 勝利時のボーナス
		if result.winner == "attacker":
			print("侵略成功！土地を獲得しました")

# CPU バトル判断
func cpu_battle_decision(current_player, tile_info: Dictionary):
	# 防御側クリーチャーの情報
	var defender = tile_info.creature
	
	# 手札から最も有利なカードを探す
	var best_card_index = -1
	var best_score = -999
	
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	for i in range(hand_size):
		var card = card_system.get_card_data_for_player(current_player.id, i)
		if card.is_empty():
			continue
		
		# バトル予測
		var prediction = battle_system.predict_battle_outcome(card, defender, tile_info)
		
		# スコア計算（ST差 + 属性ボーナス）
		var score = prediction.attacker_st - prediction.defender_hp
		
		# コストも考慮
		var cost = skill_system.modify_card_cost(card.get("cost", 1) * 10, card, current_player.id)
		if cost > current_player.magic_power:
			continue  # 魔力不足
		
		if score > best_score:
			best_score = score
			best_card_index = i
	
	# 勝てそうなら70%の確率でバトル
	if best_card_index >= 0 and best_score > -10 and randf() < 0.7:
		print("CPU: バトルを仕掛けます！")
		execute_player_battle(current_player, best_card_index, tile_info)
	else:
		# 通行料支払い
		print("CPU: 通行料を支払います")
		var toll = board_system.calculate_toll(tile_info.index)
		toll = skill_system.modify_toll(toll, current_player.id, tile_info.owner)
		player_system.pay_toll(current_player.id, tile_info.owner, toll)
	
	# CPU判断後にターン終了
	end_turn()

# パスボタンが押された
func on_pass_button_pressed():
	if waiting_for_choice:
		player_choice = "pass"
		waiting_for_choice = false
		ui_manager.hide_card_selection_ui()
	elif waiting_for_battle:
		player_choice = "pass"
		waiting_for_battle = false
		ui_manager.hide_card_selection_ui()

# ターン終了
func end_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_ended", current_player.id)
	
	change_phase(GamePhase.END_TURN)
	
	# スキル効果のクリーンアップ
	skill_system.end_turn_cleanup()
	
	# 次のプレイヤーへ
	player_system.next_player()
	
	# 次のターン開始
	await get_tree().create_timer(1.0).timeout
	start_turn()

# プレイヤー勝利処理
func on_player_won(player_id: int):
	var player = player_system.players[player_id]
	change_phase(GamePhase.SETUP)
	ui_manager.set_dice_button_enabled(false)
	ui_manager.phase_label.text = player.name + "の勝利！"

# UI更新
func update_ui():
	var current_player = player_system.get_current_player()
	ui_manager.update_ui(current_player, current_phase)
