extends Node
class_name BattleSystem

# バトル管理システム - 3D専用版（リファクタリング版）
# サブシステムに処理を委譲し、コア機能のみを保持

signal invasion_completed(success: bool, tile_index: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# バトル結果
enum BattleResult {
	ATTACKER_WIN,           # 侵略成功（土地獲得）
	DEFENDER_WIN,           # 防御成功（侵略側カード破壊）
	ATTACKER_SURVIVED       # 侵略失敗（侵略側カード手札に戻る）
}

# 属性相性テーブル（火→風→土→水→火）
var element_advantages = {
	"火": "風",
	"風": "土", 
	"土": "水",
	"水": "火"
}

# システム参照
var board_system_ref = null  # BoardSystem3D
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null

# サブシステム
var battle_preparation: BattlePreparation
var battle_execution: BattleExecution
var battle_skill_processor: BattleSkillProcessor
var battle_special_effects: BattleSpecialEffects

func _ready():
	# サブシステムを初期化
	battle_preparation = BattlePreparation.new()
	battle_preparation.name = "BattlePreparation"
	add_child(battle_preparation)
	
	battle_execution = BattleExecution.new()
	battle_execution.name = "BattleExecution"
	add_child(battle_execution)
	
	battle_skill_processor = BattleSkillProcessor.new()
	battle_skill_processor.name = "BattleSkillProcessor"
	add_child(battle_skill_processor)
	
	battle_special_effects = BattleSpecialEffects.new()
	battle_special_effects.name = "BattleSpecialEffects"
	add_child(battle_special_effects)

# システム参照を設定
func setup_systems(board_system, card_system: CardSystem, player_system: PlayerSystem):
	board_system_ref = board_system
	card_system_ref = card_system
	player_system_ref = player_system
	
	# サブシステムにも参照を設定
	battle_preparation.setup_systems(board_system, card_system, player_system)
	battle_skill_processor.setup_systems(board_system)
	battle_special_effects.setup_systems(board_system)

# バトル実行（3D版メイン処理）
func execute_3d_battle(attacker_index: int, card_index: int, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}) -> void:
	if not validate_systems():
		print("Error: システム参照が設定されていません")
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# カードインデックスが-1の場合は通行料支払い
	if card_index < 0:
		pay_toll_3d(attacker_index, tile_info)
		return
	
	var card_data = card_system_ref.get_card_data_for_player(attacker_index, card_index)
	if card_data.is_empty():
		pay_toll_3d(attacker_index, tile_info)
		return
	
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
	else:
		cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system_ref.get_current_player()
	
	if current_player.magic_power < cost:
		pay_toll_3d(attacker_index, tile_info)
		return
	
	# カード使用
	card_system_ref.use_card_for_player(attacker_index, card_index)
	player_system_ref.add_magic(attacker_index, -cost)
	
	# 防御クリーチャーがいない場合（侵略）
	if tile_info.get("creature", {}).is_empty():
		execute_invasion_3d(attacker_index, card_data, tile_info)
		return
	
	# バトル実行
	_execute_battle_core(attacker_index, card_data, tile_info, attacker_item, defender_item)

# バトル実行（カードデータ直接指定版）- カード使用処理は呼び出し側で行う
func execute_3d_battle_with_data(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}) -> void:
	if not validate_systems():
		print("Error: システム参照が設定されていません")
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# 防御クリーチャーがいない場合（侵略）
	if tile_info.get("creature", {}).is_empty():
		execute_invasion_3d(attacker_index, card_data, tile_info)
		return
	
	# バトル実行
	_execute_battle_core(attacker_index, card_data, tile_info, attacker_item, defender_item)

# バトルコア処理（共通化）
func _execute_battle_core(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary, defender_item: Dictionary) -> void:
	print("========== バトル開始 ==========")
	
	# 1. 両者の準備
	var participants = battle_preparation.prepare_participants(attacker_index, card_data, tile_info, attacker_item, defender_item)
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	
	print("侵略側: ", attacker.creature_data.get("name", "?"), " [", attacker.creature_data.get("element", "?"), "]")
	print("  基本HP:", attacker.base_hp, " + 土地ボーナス:", attacker.land_bonus_hp, " = MHP:", attacker.current_hp)
	var attacker_speed = "アイテム先制" if attacker.has_item_first_strike else ("後手" if attacker.has_last_strike else ("先制" if attacker.has_first_strike else "通常"))
	print("  AP:", attacker.current_ap, " 攻撃:", attacker_speed)
	
	print("防御側: ", defender.creature_data.get("name", "?"), " [", defender.creature_data.get("element", "?"), "]")
	print("  基本HP:", defender.base_hp, " + 土地ボーナス:", defender.land_bonus_hp, " = MHP:", defender.current_hp)
	var defender_speed = "アイテム先制" if defender.has_item_first_strike else ("後手" if defender.has_last_strike else ("先制" if defender.has_first_strike else "通常"))
	print("  AP:", defender.current_ap, " 攻撃:", defender_speed)
	
	# 2. バトル前スキル適用
	battle_skill_processor.apply_pre_battle_skills(participants, tile_info, attacker_index)
	
	# スキル適用後の最終ステータス表示
	print("\n【スキル適用後の最終ステータス】")
	print("侵略側: ", attacker.creature_data.get("name", "?"))
	print("  HP:", attacker.current_hp, " (基本:", attacker.base_hp, " 感応:", attacker.resonance_bonus_hp, " 土地:", attacker.land_bonus_hp, ")")
	print("  AP:", attacker.current_ap)
	print("防御側: ", defender.creature_data.get("name", "?"))
	print("  HP:", defender.current_hp, " (基本:", defender.base_hp, " 感応:", defender.resonance_bonus_hp, " 土地:", defender.land_bonus_hp, ")")
	print("  AP:", defender.current_ap)
	
	# 3. 攻撃順決定
	var attack_order = battle_execution.determine_attack_order(attacker, defender)
	var order_str = "侵略側 → 防御側" if attack_order[0].is_attacker else "防御側 → 侵略側"
	print("\n【攻撃順】", order_str)
	
	# 4. 攻撃シーケンス実行
	battle_execution.execute_attack_sequence(attack_order, tile_info, battle_special_effects)
	
	# 5. 結果判定
	var result = battle_execution.resolve_battle_result(attacker, defender)
	
	# 6. 結果に応じた処理
	_apply_post_battle_effects(result, attacker_index, card_data, tile_info, attacker, defender)
	
	print("================================")

# 侵略処理（防御クリーチャーなし）
func execute_invasion_3d(attacker_index: int, card_data: Dictionary, tile_info: Dictionary):
	print("侵略成功！土地を奪取")
	
	# 土地を奪取
	board_system_ref.set_tile_owner(tile_info["index"], attacker_index)
	board_system_ref.place_creature(tile_info["index"], card_data)
	
	# UI更新
	if board_system_ref.has_method("update_all_tile_displays"):
		board_system_ref.update_all_tile_displays()
	
	emit_signal("invasion_completed", true, tile_info["index"])

# 通行料支払い
func pay_toll_3d(payer_index: int, tile_info: Dictionary):
	var toll = board_system_ref.calculate_toll(tile_info["index"])
	var receiver_id = tile_info["owner"]
	
	if receiver_id >= 0 and receiver_id < player_system_ref.players.size():
		player_system_ref.pay_toll(payer_index, receiver_id, toll)
		print("通行料 ", toll, "G を支払いました")
	
	emit_signal("invasion_completed", false, tile_info["index"])

# システム検証
func validate_systems() -> bool:
	return board_system_ref != null and card_system_ref != null and player_system_ref != null

# バトル後の処理
func _apply_post_battle_effects(
	result: BattleResult,
	attacker_index: int,
	card_data: Dictionary,
	tile_info: Dictionary,
	attacker: BattleParticipant,
	defender: BattleParticipant
) -> void:
	var tile_index = tile_info["index"]
	
	# 再生スキル処理
	battle_special_effects.apply_regeneration(attacker)
	battle_special_effects.apply_regeneration(defender)
	
	match result:
		BattleResult.ATTACKER_WIN:
			print("\n【結果】侵略成功！土地を獲得")
			# 土地を奪取
			board_system_ref.set_tile_owner(tile_index, attacker_index)
			# クリーチャー配置（HPは現在値）
			var placement_data = card_data.duplicate()
			placement_data["hp"] = attacker.base_hp  # ダメージを受けた状態で配置
			board_system_ref.place_creature(tile_index, placement_data)
			
			emit_signal("invasion_completed", true, tile_index)
		
		BattleResult.DEFENDER_WIN:
			print("\n【結果】防御成功！侵略側カード破壊")
			# カードは既に捨て札に行っているので何もしない
			
			# 防御側クリーチャーのHPを更新（ダメージを受けたまま）
			battle_special_effects.update_defender_hp(tile_info, defender)
			
			emit_signal("invasion_completed", false, tile_index)
		
		BattleResult.ATTACKER_SURVIVED:
			print("\n【結果】両者生存 → 侵略失敗、カード手札に戻る")
			# カードを手札に戻す
			card_system_ref.return_card_to_hand(attacker_index, card_data)
			
			# 防御側クリーチャーのHPを更新（ダメージを受けたまま）
			battle_special_effects.update_defender_hp(tile_info, defender)
			
			emit_signal("invasion_completed", false, tile_index)
	
	# 表示更新
	if board_system_ref.has_method("update_all_tile_displays"):
		board_system_ref.update_all_tile_displays()

# ========================================
# 効果システム - Phase 2実装
# ========================================

## 効果IDを生成（一意性を保証）
var _effect_counter: int = 0
func _generate_unique_effect_id() -> String:
	_effect_counter += 1
	return "effect_%d_%d" % [Time.get_ticks_msec(), _effect_counter]

## スペル効果を追加（上書き処理あり）
## @param tile_index: 対象タイルのインデックス
## @param effect: 効果辞書 {type, stat, value, source, source_name, removable, lost_on_move}
func add_spell_effect_to_creature(tile_index: int, effect: Dictionary) -> bool:
	if not board_system_ref:
		print("エラー: board_system_refが設定されていません")
		return false
	
	var tile_info = board_system_ref.get_tile_info(tile_index)
	var creature_data = tile_info.get("creature", {})
	
	if creature_data.is_empty():
		print("エラー: タイル", tile_index, "にクリーチャーがいません")
		return false
	
	# 一時効果 or 永続効果を判定
	var effects_key = "temporary_effects" if effect.get("lost_on_move", true) else "permanent_effects"
	
	# 同名効果を削除（上書き）
	var new_effects = []
	for existing_effect in creature_data.get(effects_key, []):
		if existing_effect.get("source_name") != effect.get("source_name"):
			new_effects.append(existing_effect)
	
	# 新しい効果を追加
	effect["id"] = _generate_unique_effect_id()
	new_effects.append(effect)
	creature_data[effects_key] = new_effects
	
	print("[効果追加] ", effect.get("source_name"), " → ", creature_data.get("name"), " (", effects_key, ")")
	print("  ", effect.get("stat"), " +", effect.get("value"))
	
	return true

## マスグロース効果を適用（全自クリーチャーのMHP+5）
## @param player_id: 対象プレイヤーID
## @param bonus_hp: 上昇HP量
func apply_mass_growth(player_id: int, bonus_hp: int = 5) -> int:
	if not board_system_ref:
		print("エラー: board_system_refが設定されていません")
		return 0
	
	var affected_count = 0
	
	# プレイヤーの全タイルを取得
	for tile_index in range(board_system_ref.tile_nodes.size()):
		var tile_info = board_system_ref.get_tile_info(tile_index)
		
		# プレイヤーの土地でクリーチャーがいる場合
		if tile_info.get("owner") == player_id and not tile_info.get("creature", {}).is_empty():
			var creature_data = tile_info["creature"]
			creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + bonus_hp
			affected_count += 1
			
			print("[マスグロース] ", creature_data.get("name"), " MHP +", bonus_hp, " (合計:", creature_data["base_up_hp"], ")")
	
	print("[マスグロース完了] ", affected_count, "体のクリーチャーに適用")
	return affected_count

## ドミナントグロース効果を適用（指定属性の全自クリーチャーのMHP上昇）
## @param player_id: 対象プレイヤーID
## @param element: 対象属性（"fire", "water", "wind", "earth"）
## @param bonus_hp: 上昇HP量
func apply_dominant_growth(player_id: int, element: String, bonus_hp: int = 10) -> int:
	if not board_system_ref:
		print("エラー: board_system_refが設定されていません")
		return 0
	
	var affected_count = 0
	
	# プレイヤーの全タイルを取得
	for tile_index in range(board_system_ref.tile_nodes.size()):
		var tile_info = board_system_ref.get_tile_info(tile_index)
		
		# プレイヤーの土地でクリーチャーがいる場合
		if tile_info.get("owner") == player_id and not tile_info.get("creature", {}).is_empty():
			var creature_data = tile_info["creature"]
			
			# 属性が一致する場合のみ適用
			if creature_data.get("element") == element:
				creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + bonus_hp
				affected_count += 1
				
				print("[ドミナントグロース] ", creature_data.get("name"), " MHP +", bonus_hp, " (合計:", creature_data["base_up_hp"], ")")
	
	print("[ドミナントグロース完了] ", element, "属性 ", affected_count, "体に適用")
	return affected_count

## クリーチャー移動時の一時効果削除
## @param tile_index: 移動元のタイルインデックス
func clear_temporary_effects_on_move(tile_index: int) -> bool:
	if not board_system_ref:
		print("エラー: board_system_refが設定されていません")
		return false
	
	var tile_info = board_system_ref.get_tile_info(tile_index)
	var creature_data = tile_info.get("creature", {})
	
	if creature_data.is_empty():
		return false
	
	# temporary_effectsをクリア（移動で消える効果）
	var cleared_count = creature_data.get("temporary_effects", []).size()
	creature_data["temporary_effects"] = []
	
	if cleared_count > 0:
		print("[移動] ", creature_data.get("name"), " の一時効果 ", cleared_count, "個をクリア")
	
	return true

## 効果を削除（打ち消し効果用）
## @param tile_index: 対象タイルのインデックス
## @param removable_only: trueの場合、removable=trueの効果のみ削除
func remove_effects_from_creature(tile_index: int, removable_only: bool = true) -> int:
	if not board_system_ref:
		print("エラー: board_system_refが設定されていません")
		return 0
	
	var tile_info = board_system_ref.get_tile_info(tile_index)
	var creature_data = tile_info.get("creature", {})
	
	if creature_data.is_empty():
		return 0
	
	var removed_count = 0
	
	# permanent_effectsから削除
	var new_permanent = []
	for effect in creature_data.get("permanent_effects", []):
		if not removable_only or effect.get("removable", true):
			removed_count += 1
			print("[打ち消し] ", effect.get("source_name"), " を削除")
		else:
			new_permanent.append(effect)
	creature_data["permanent_effects"] = new_permanent
	
	# temporary_effectsから削除
	var new_temporary = []
	for effect in creature_data.get("temporary_effects", []):
		if not removable_only or effect.get("removable", true):
			removed_count += 1
			print("[打ち消し] ", effect.get("source_name"), " を削除")
		else:
			new_temporary.append(effect)
	creature_data["temporary_effects"] = new_temporary
	
	if removed_count > 0:
		print("[打ち消し完了] ", creature_data.get("name"), " から ", removed_count, "個の効果を削除")
	
	return removed_count
