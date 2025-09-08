extends Node
class_name GameFlowManager

# ゲームのフェーズ管理・ターン進行システム

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

# システム参照
var player_system: PlayerSystem
var card_system: CardSystem
var board_system: BoardSystem
var skill_system: SkillSystem
var ui_manager: UIManager

func _ready():
	print("GameFlowManager: 初期化")

# システム参照を設定
func setup_systems(p_system: PlayerSystem, c_system: CardSystem, b_system: BoardSystem, s_system: SkillSystem, ui_system: UIManager):
	player_system = p_system
	card_system = c_system
	board_system = b_system
	skill_system = s_system
	ui_manager = ui_system

# ゲーム開始
func start_game():
	print("ゲーム開始！")
	current_phase = GamePhase.DICE_ROLL
	ui_manager.set_dice_button_enabled(true)
	update_ui()

# ターン開始
func start_turn():
	var current_player = player_system.get_current_player()
	print("\n--- ", current_player.name, "のターン開始 ---")
	emit_signal("turn_started", current_player.id)
	
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
		process_land_acquisition()
	elif tile_info.owner == current_player.id:
		# 自分の土地
		print("自分の土地です（レベルアップは未実装）")
		end_turn()
	else:
		# 他人の土地
		print("他人の土地！")
		process_enemy_land(tile_info)

# 土地取得処理
func process_land_acquisition():
	var current_player = player_system.get_current_player()
	
	# 土地を取得（無料）
	board_system.set_tile_owner(current_player.current_tile, current_player.id)
	print("土地を取得しました！")
	
	# 手札がある場合のみクリーチャー召喚の選択
	if card_system.get_hand_size() > 0:
		if current_player.id == 0:
			# プレイヤー1の場合は選択UIを表示
			await show_summon_choice()
		else:
			# CPU（プレイヤー2）は30%の確率で召喚
			if randf() > 0.7:
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
	
	if card_system.get_hand_size() == 0:
		print("ERROR: 手札がないのに選択UIが呼ばれました")
		return
	
	# 最初のカードの情報を表示
	var card_data = card_system.get_card_data(0)
	if not card_data.is_empty():
		var cost = skill_system.modify_card_cost(card_data.get("cost", 1) * 10, card_data, current_player.id)
		
		# 魔力が足りない場合は自動的にパス
		if current_player.magic_power < cost:
			ui_manager.show_magic_shortage()
			print("魔力が足りないため召喚できません")
			await get_tree().create_timer(1.0).timeout
			return
		
		ui_manager.show_summon_choice(card_data, cost)
		waiting_for_choice = true
		player_choice = ""
		
		# 選択を待つ
		while waiting_for_choice:
			await get_tree().process_frame
		
		# プレイヤーの選択に応じて処理
		if player_choice == "summon":
			try_summon_creature(current_player)
		else:
			print("召喚をスキップしました")

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
		end_turn()

# 召喚ボタンが押された
func on_summon_button_pressed():
	if waiting_for_choice:
		player_choice = "summon"
		waiting_for_choice = false
		ui_manager.hide_summon_choice()

# パスボタンが押された
func on_pass_button_pressed():
	if waiting_for_choice:
		player_choice = "pass"
		waiting_for_choice = false
		ui_manager.hide_summon_choice()

# ターン終了
func end_turn():
	print("ターン終了")
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
	print("\n🎉 ゲーム終了！", player.name, "の勝利！🎉")
	change_phase(GamePhase.SETUP)
	ui_manager.set_dice_button_enabled(false)
	ui_manager.phase_label.text = player.name + "の勝利！"

# UI更新
func update_ui():
	var current_player = player_system.get_current_player()
	ui_manager.update_ui(current_player, current_phase)
