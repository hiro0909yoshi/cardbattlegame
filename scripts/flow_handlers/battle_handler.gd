extends Node
class_name BattleHandler

# バトル処理専用クラス
# 侵略、防衛、通行料処理を管理

signal battle_completed(result: Dictionary)
signal invasion_completed(success: bool)
signal toll_paid(amount: int)
signal card_selection_required(mode: String)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# システム参照
var battle_system: BattleSystem
var board_system: BoardSystem
var card_system: CardSystem
var player_system: PlayerSystem
var skill_system: SkillSystem

# 現在の処理状態
var current_battle_context = {}
var is_processing = false

func _ready():
	pass

# システム参照を設定
func setup_systems(bt_system: BattleSystem, b_system: BoardSystem, c_system: CardSystem, p_system: PlayerSystem, s_system: SkillSystem):
	battle_system = bt_system
	board_system = b_system
	card_system = c_system
	player_system = p_system
	skill_system = s_system

# バトル処理を開始
func start_battle_sequence(tile_info: Dictionary, current_player):
	if is_processing:
		return
	
	is_processing = true
	current_battle_context = {
		"tile_info": tile_info,
		"player": current_player,
		"mode": determine_battle_mode(tile_info, current_player)
	}
	
	# 敵クリーチャー情報を表示
	if not tile_info.creature.is_empty():
		display_enemy_creature(tile_info.creature)
	
	# 手札チェック
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size == 0:
		print("手札がないため通行料を支払います")
		process_toll_payment()
	else:
		# カード選択を要求
		emit_signal("card_selection_required", current_battle_context.mode)

# バトルモードを判定
func determine_battle_mode(tile_info: Dictionary, current_player) -> String:
	if tile_info.creature.is_empty():
		return "invasion"  # 無防備な土地への侵略
	else:
		return "battle"     # クリーチャーとのバトル

# 敵クリーチャー情報を表示
func display_enemy_creature(creature: Dictionary):
	print("\n敵クリーチャーがいます！")
	print("敵クリーチャー: ", creature.get("name", "不明"), 
		  " (ST:", creature.get("damage", 0), 
		  " HP:", creature.get("block", 0), 
		  " ", creature.get("element", "?"), "属性)")

# 侵略処理（無防備な土地）
func process_invasion(card_index: int):
	var player = current_battle_context.player
	var tile_info = current_battle_context.tile_info
	
	var card_data = card_system.get_card_data_for_player(player.id, card_index)
	var cost = calculate_card_cost(card_data, player.id)
	
	if player.magic_power >= cost:
		# カードを使用
		card_system.use_card_for_player(player.id, card_index)
		player_system.add_magic(player.id, -cost)
		
		# 土地を奪取
		board_system.set_tile_owner(tile_info.get("index", 0), player.id)
		board_system.place_creature(tile_info.get("index", 0), card_data)
		
		print(">>> 侵略成功！土地を奪取しました！")
		print("「", card_data.get("name", "不明"), "」を配置")
		
		emit_signal("invasion_completed", true)
		is_processing = false
		emit_signal("battle_completed", {"success": true, "type": "invasion"})
	else:
		print("魔力不足で侵略できません")
		process_toll_payment()

# バトル実行
func execute_battle(card_index: int):
	var player = current_battle_context.player
	var tile_info = current_battle_context.tile_info
	
	if not battle_system:
		print("ERROR: BattleSystemが設定されていません")
		process_toll_payment()
		return
	
	# バトルを実行
	var result = battle_system.execute_invasion_battle(
		player.id,
		card_index,
		tile_info,
		card_system,
		board_system
	)
	
	if result.success:
		var card_data = card_system.get_card_data_for_player(player.id, card_index)
		var cost = calculate_card_cost(card_data, player.id)
		
		# カードを使用
		card_system.use_card_for_player(player.id, card_index)
		player_system.add_magic(player.id, -cost)
		
		# バトル結果に応じた処理
		handle_battle_result(result, tile_info)
	else:
		print("バトル実行に失敗しました")
		process_toll_payment()

# バトル結果を処理
func handle_battle_result(result: Dictionary, tile_info: Dictionary):
	match result.winner:
		"attacker":
			# 攻撃側勝利：土地を奪取（通行料なし）
			print("侵略成功！土地を獲得しました")
			is_processing = false
			emit_signal("battle_completed", {"success": true, "type": "victory"})
			
		"defender":
			# 防御側勝利：通行料を支払う
			print("バトルに敗北！通行料を支払います")
			process_toll_payment()
			
		"draw_capture":
			# 相討ちで土地獲得（通行料なし）
			print("相討ち！土地を獲得しました")
			is_processing = false
			emit_signal("battle_completed", {"success": true, "type": "mutual_defeat"})
			
		_:
			# 膠着状態：通行料を支払う
			print("決着つかず！通行料を支払います")
			process_toll_payment()

# 通行料処理
func process_toll_payment():
	var tile_info = current_battle_context.tile_info
	var player = current_battle_context.player
	
	var toll = calculate_toll(tile_info)
	print("通行料: ", toll, "G")
	
	player_system.pay_toll(player.id, tile_info.get("owner", -1), toll)
	emit_signal("toll_paid", toll)
	is_processing = false
	emit_signal("battle_completed", {"success": false, "type": "toll"})

# 通行料を計算
func calculate_toll(tile_info: Dictionary) -> int:
	var base_toll = board_system.calculate_toll(tile_info.get("index", 0))
	
	if skill_system:
		var player = current_battle_context.player
		return skill_system.modify_toll(base_toll, player.id, tile_info.get("owner", -1))
	
	return base_toll

# カードコストを計算
func calculate_card_cost(card_data: Dictionary, player_id: int) -> int:
	var base_cost = card_data.get("cost", 1) * GameConstants.CARD_COST_MULTIPLIER
	
	if skill_system:
		return skill_system.modify_card_cost(base_cost, card_data, player_id)
	
	return base_cost

# バトルをキャンセル（パス選択時）
func cancel_battle():
	print("バトル/侵略をキャンセルしました")
	process_toll_payment()

# カード選択に対応
func on_card_selected(card_index: int):
	if not is_processing:
		return
	
	match current_battle_context.mode:
		"invasion":
			process_invasion(card_index)
		"battle":
			execute_battle(card_index)

# 現在のバトルコンテキストを取得
func get_current_context() -> Dictionary:
	return current_battle_context

# 処理中かチェック
func is_battle_processing() -> bool:
	return is_processing

# クリーンアップ
func cleanup():
	current_battle_context = {}
	is_processing = false
