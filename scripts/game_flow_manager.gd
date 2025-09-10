extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム - 特殊マス対応版

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
var waiting_for_battle = false

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var board_system: BoardSystem
var skill_system: SkillSystem
var ui_manager: UIManager
var battle_system: BattleSystem
var special_tile_system: SpecialTileSystem  # 追加

func _ready():
	pass

# システム参照を設定
func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BoardSystem, s_system: SkillSystem, ui_system: UIManager, bt_system: BattleSystem = null, st_system: SpecialTileSystem = null):
	player_system = p_system
	card_system = c_system
	board_system = b_system
	skill_system = s_system
	ui_manager = ui_system
	battle_system = bt_system
	special_tile_system = st_system  # 追加

# ゲーム開始
func start_game():
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	
	# カードを1枚引く
	if hand_size < card_system.max_hand_size:
		var drawn_card = card_system.draw_card_for_player(current_player.id)
		if not drawn_card.is_empty():
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
	
	var dice_value = player_system.roll_dice()
	var modified_dice = skill_system.modify_dice_roll(dice_value, player_system.current_player_index)
	if modified_dice != dice_value:
		print("ダイス目修正: ", dice_value, " → ", modified_dice)
	
	ui_manager.show_dice_result(modified_dice, get_parent())
	
	var current_player = player_system.get_current_player()
	await get_tree().create_timer(1.0).timeout
	player_system.move_player_steps(current_player.id, modified_dice, board_system)

# 移動完了
func on_movement_completed(final_tile: int):
	change_phase(GamePhase.TILE_ACTION)
	
	var tile_info = board_system.get_tile_info(final_tile)
	var current_player = player_system.get_current_player()
	
	# まずチェックポイントや特殊地形の処理を優先
	# （通過型ワープで到着した場合も処理される）
	if tile_info.type == BoardSystem.TileType.CHECKPOINT:
		print("チェックポイント到着！100G獲得")
		player_system.add_magic(current_player.id, 100)
		end_turn()
		return
	elif tile_info.type == BoardSystem.TileType.START:
		player_system.add_magic(current_player.id, 100)
		end_turn()
		return
	
	# 停止型ワープマスチェック
	if special_tile_system and special_tile_system.is_special_tile(final_tile):
		var special_type = special_tile_system.get_special_type(final_tile)
		
		# 停止型ワープの場合
		if special_type == special_tile_system.SpecialType.WARP_POINT:
			var special_result = special_tile_system.activate_special_tile(final_tile, current_player.id)
			var new_tile = special_result.get("warp_to", final_tile)
			
			if new_tile != final_tile:
				await get_tree().create_timer(1.0).timeout
				tile_info = board_system.get_tile_info(new_tile)
				final_tile = new_tile
				
				# ワープ先が特殊マスの場合、その効果も発動
				if special_tile_system.is_special_tile(new_tile):
					var warp_dest_type = special_tile_system.get_special_type(new_tile)
					if warp_dest_type == special_tile_system.SpecialType.CARD:
						special_tile_system.activate_special_tile(new_tile, current_player.id)
						print("ワープ先でカードを引きました！")
						end_turn()
						return
		
		# カードマスの場合
		elif special_type == special_tile_system.SpecialType.CARD:
			special_tile_system.activate_special_tile(final_tile, current_player.id)
			print("カードを引きました！")
			end_turn()
			return
		
		# 無属性マスの場合（土地として処理）
		elif special_type == special_tile_system.SpecialType.NEUTRAL:
			print("無属性マス - 属性連鎖が切れます")
			# 通常の土地処理を続行
	
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
			
		BoardSystem.TileType.SPECIAL:
			# カードマス、ワープマス以外の特殊マス
			# 無属性マスは通常土地として処理
			if special_tile_system:
				var special_type = special_tile_system.get_special_type(final_tile)
				if special_type == special_tile_system.SpecialType.NEUTRAL:
					process_normal_tile(tile_info)
				else:
					end_turn()

# 通常タイルの処理
func process_normal_tile(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	if tile_info.owner == -1:
		# 空き地
		process_land_acquisition()
	elif tile_info.owner == current_player.id:
		# 自分の土地
		process_own_land(tile_info)
	else:
		# 他人の土地
		process_enemy_land(tile_info)

# 土地取得処理
func process_land_acquisition():
	var current_player = player_system.get_current_player()
	
	# 土地を取得（無料）
	board_system.set_tile_owner(current_player.current_tile, current_player.id)
	print("空き地を取得しました！")
	
	# 手札がある場合のみクリーチャー召喚の選択
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size > 0:
		if current_player.id == 0:
			await show_summon_choice()
		else:
			await cpu_summon_decision(current_player)
	
	end_turn()

# 自分の土地での処理（複数レベルアップ対応）
func process_own_land(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	print("自分の土地です（レベル", tile_info.get("level", 1), "）")
	
	# レベルアップ可能かチェック
	var current_level = tile_info.get("level", 1)
	if current_level >= 5:
		print("この土地は最大レベルです")
		end_turn()
		return
	
	if current_player.id == 0:
		# プレイヤー1：レベルアップ選択UI
		await show_level_up_choice(tile_info)
	else:
		# CPU：自動判断（1レベルずつ）
		var upgrade_cost = board_system.get_upgrade_cost(tile_info.get("index", 0))
		if current_player.magic_power >= upgrade_cost and randf() < 0.5:  # 50%の確率
			print("CPU: 土地をレベルアップします（コスト: ", upgrade_cost, "G）")
			board_system.upgrade_tile_level(tile_info.get("index", 0))
			player_system.add_magic(current_player.id, -upgrade_cost)
		else:
			print("CPU: レベルアップをスキップ")
	
	end_turn()

# レベルアップ選択UIを表示（複数レベル対応）
func show_level_up_choice(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	# レベルアップUIを表示（複数レベル選択対応）
	ui_manager.show_level_up_ui(tile_info, current_player.magic_power)
	
	waiting_for_choice = true
	player_choice = ""
	
	# UI選択を待つ
	while waiting_for_choice:
		await get_tree().process_frame

# 敵の土地での処理
func process_enemy_land(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	if tile_info.creature.is_empty():
		# クリーチャーがいない場合
		print("敵の土地ですが、守るクリーチャーがいません")
		
		# 侵略可能かチェック（手札にクリーチャーがあるか）
		var hand_size = card_system.get_hand_size_for_player(current_player.id)
		if hand_size > 0:
			if current_player.id == 0:
				# プレイヤー：侵略選択
				await show_invasion_choice(tile_info)
			else:
				# CPU：自動判断（80%の確率で侵略）
				if randf() < 0.8:
					await cpu_invasion_decision(current_player, tile_info)
				else:
					print("CPU: 侵略をスキップして通行料を支払います")
					pay_toll_and_end(tile_info)
		else:
			# 手札がなければ通行料
			print("侵略する手札がないため通行料を支払います")
			pay_toll_and_end(tile_info)
	else:
		# クリーチャーがいる場合はバトル
		change_phase(GamePhase.BATTLE)
		await process_battle(tile_info)

# 侵略選択UIを表示
func show_invasion_choice(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	print("\n守備クリーチャーがいません。侵略しますか？")
	ui_manager.phase_label.text = "無防備な土地！侵略するクリーチャーを選択（またはパスで通行料）"
	ui_manager.show_card_selection_ui(current_player)
	
	waiting_for_battle = true
	player_choice = ""
	
	while waiting_for_battle:
		await get_tree().process_frame
	
	if player_choice != "pass" and player_choice != "":
		# 侵略実行
		var card_index = int(player_choice)
		execute_invasion(current_player, card_index, tile_info)
	else:
		# 通行料支払い
		pay_toll_and_end(tile_info)

# CPU侵略判断
func cpu_invasion_decision(current_player, tile_info: Dictionary):
	# 最も安いカードで侵略
	var card_index = card_system.get_cheapest_card_index_for_player(current_player.id)
	if card_index >= 0:
		var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
		var cost = skill_system.modify_card_cost(
			card_data.get("cost", 1) * 10,
			card_data,
			current_player.id
		)
		
		if current_player.magic_power >= cost:
			print("CPU: 無防備な土地を侵略します！")
			execute_invasion(current_player, card_index, tile_info)
			return
	
	print("CPU: 侵略できるカードがないため通行料を支払います")
	pay_toll_and_end(tile_info)

# 侵略実行（守備なし）
func execute_invasion(current_player, card_index: int, tile_info: Dictionary):
	var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
	var cost = skill_system.modify_card_cost(
		card_data.get("cost", 1) * 10,
		card_data,
		current_player.id
	)
	
	if current_player.magic_power >= cost:
		# カードを使用
		card_system.use_card_for_player(current_player.id, card_index)
		player_system.add_magic(current_player.id, -cost)
		
		# 土地を奪取
		board_system.set_tile_owner(tile_info.get("index", 0), current_player.id)
		board_system.place_creature(tile_info.get("index", 0), card_data)
		
		print(">>> 侵略成功！土地を奪取しました！")
		print("「", card_data.get("name", "不明"), "」を配置")
		
		# CPU手札更新
		if current_player.id > 0:
			ui_manager.update_cpu_hand_display(current_player.id)
	else:
		print("魔力不足で侵略できません")
		pay_toll_and_end(tile_info)
	
	end_turn()

# 通行料支払い処理
func pay_toll_and_end(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	var toll = board_system.calculate_toll(tile_info.get("index", 0))
	toll = skill_system.modify_toll(toll, current_player.id, tile_info.get("owner", -1))
	
	print("通行料: ", toll, "G")
	player_system.pay_toll(current_player.id, tile_info.get("owner", -1), toll)
	end_turn()

# バトル処理
func process_battle(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	# 敵クリーチャー情報を表示
	var enemy_creature = tile_info.get("creature", {})
	if not enemy_creature.is_empty():
		print("\n敵クリーチャーがいます！")
		print("敵クリーチャー: ", enemy_creature.get("name", "不明"), 
			  " (ST:", enemy_creature.get("damage", 0), 
			  " HP:", enemy_creature.get("block", 0), 
			  " ", enemy_creature.get("element", "?"), "属性)")
		print("バトルするか選択してください")
	
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size == 0:
		print("手札がないため通行料を支払います")
		pay_toll_and_end(tile_info)
		return
	
	if current_player.id == 0:
		await show_battle_choice(tile_info)
	else:
		await cpu_battle_decision(current_player, tile_info)

# バトル選択UIを表示
func show_battle_choice(tile_info: Dictionary):
	var current_player = player_system.get_current_player()
	
	ui_manager.phase_label.text = "バトルするクリーチャーを選択（またはパスで通行料）"
	ui_manager.show_card_selection_ui(current_player)
	
	waiting_for_battle = true
	player_choice = ""
	
	while waiting_for_battle:
		await get_tree().process_frame
	
	if player_choice != "pass" and player_choice != "":
		var card_index = int(player_choice)
		await execute_player_battle(current_player, card_index, tile_info)
	else:
		pay_toll_and_end(tile_info)

# プレイヤーのバトル実行（修正版：バトル結果に応じて通行料処理）
func execute_player_battle(current_player, card_index: int, tile_info: Dictionary):
	if not battle_system:
		print("ERROR: BattleSystemが設定されていません")
		pay_toll_and_end(tile_info)
		return
	
	var result = battle_system.execute_invasion_battle(
		current_player.id,
		card_index,
		tile_info,
		card_system,
		board_system
	)
	
	if result.success:
		var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
		var cost = skill_system.modify_card_cost(
			card_data.get("cost", 1) * 10,
			card_data,
			current_player.id
		)
		
		# カードを使用
		card_system.use_card_for_player(current_player.id, card_index)
		player_system.add_magic(current_player.id, -cost)
		
		# バトル結果に応じた処理
		if result.winner == "attacker":
			# 攻撃側勝利：土地を奪取（通行料なし）
			print("侵略成功！土地を獲得しました")
			end_turn()
		elif result.winner == "defender":
			# 防御側勝利：通行料を支払う
			print("バトルに敗北！通行料を支払います")
			pay_toll_and_end(tile_info)
		elif result.winner == "draw_capture":
			# 相討ちで土地獲得（通行料なし）
			print("相討ち！土地を獲得しました")
			end_turn()
		else:
			# 膠着状態：通行料を支払う
			print("決着つかず！通行料を支払います")
			pay_toll_and_end(tile_info)
	else:
		# バトル実行失敗
		print("バトル実行に失敗しました")
		pay_toll_and_end(tile_info)

# CPU バトル判断
func cpu_battle_decision(current_player, tile_info: Dictionary):
	print("CPU思考中...")
	
	var defender = tile_info.creature
	var best_card_index = -1
	var best_score = -999
	
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	for i in range(hand_size):
		var card = card_system.get_card_data_for_player(current_player.id, i)
		if card.is_empty():
			continue
		
		# 予測計算（エラー回避のため引数3つに戻す）
		var prediction = battle_system.predict_battle_outcome(card, defender, tile_info)
		var score = prediction.attacker_st - prediction.defender_hp
		
		var cost = skill_system.modify_card_cost(card.get("cost", 1) * 10, card, current_player.id)
		if cost > current_player.magic_power:
			continue
		
		if score > best_score:
			best_score = score
			best_card_index = i
	
	if best_card_index >= 0 and best_score > -10 and randf() < 0.7:
		print("CPU: バトルを仕掛けます！")
		await execute_player_battle(current_player, best_card_index, tile_info)
	else:
		print("CPU: 通行料を支払います")
		pay_toll_and_end(tile_info)

# CPU召喚判断
func cpu_summon_decision(current_player):
	var affordable_cards = card_system.find_affordable_cards_for_player(
		current_player.id, 
		current_player.magic_power
	)
	
	if affordable_cards.is_empty():
		return
	
	if randf() > 0.1:
		var card_index = card_system.get_cheapest_card_index_for_player(current_player.id)
		if card_index >= 0:
			var card_data = card_system.get_card_data_for_player(current_player.id, card_index)
			var cost = skill_system.modify_card_cost(
				card_data.get("cost", 1) * 10, 
				card_data, 
				current_player.id
			)
			
			try_summon_creature_for_player(current_player, card_index)

# 召喚選択UIを表示
func show_summon_choice():
	var current_player = player_system.get_current_player()
	
	var hand_size = card_system.get_hand_size_for_player(0)
	if hand_size == 0:
		return
	
	ui_manager.show_card_selection_ui(current_player)
	waiting_for_choice = true
	player_choice = ""
	
	while waiting_for_choice:
		await get_tree().process_frame
	
	if player_choice != "pass" and player_choice != "":
		var card_index = int(player_choice)
		try_summon_creature_for_player(current_player, card_index)

# カード選択された
func on_card_selected(card_index: int):
	if waiting_for_choice:
		player_choice = str(card_index)
		waiting_for_choice = false
		ui_manager.hide_card_selection_ui()
	elif waiting_for_battle:
		player_choice = str(card_index)
		waiting_for_battle = false
		ui_manager.hide_card_selection_ui()

# レベルアップ選択の処理（複数レベル対応）
func on_level_up_selected(target_level: int, cost: int):
	if waiting_for_choice:
		if target_level > 0:
			var current_player = player_system.get_current_player()
			var tile_index = current_player.current_tile
			var current_level = board_system.tile_levels[tile_index]
			
			# 複数レベル分アップグレード
			for i in range(current_level, target_level):
				board_system.upgrade_tile_level(tile_index)
			
			player_system.add_magic(current_player.id, -cost)
			print("土地をレベル", target_level, "にアップグレードしました！（コスト: ", cost, "G）")
		else:
			print("レベルアップをキャンセル")
		
		waiting_for_choice = false

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
				
				if current_player.id > 0:
					ui_manager.update_cpu_hand_display(current_player.id)

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
	skill_system.end_turn_cleanup()
	player_system.next_player()
	
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
