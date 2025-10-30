extends Node
class_name BattleSystem

# バトル管理システム - 3D専用版（リファクタリング版）
# サブシステムに処理を委譲し、コア機能のみを保持

signal invasion_completed(success: bool, tile_index: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const TransformProcessor = preload("res://scripts/battle/battle_transform_processor.gd")

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
var game_flow_manager_ref = null  # GameFlowManager

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
	battle_execution.setup_systems(card_system)  # 追加: CardSystemの参照を渡す
	battle_skill_processor.setup_systems(board_system, game_flow_manager_ref, card_system_ref)
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
	
	# バトル実行（通常侵略なので from_tile_index = -1）
	_execute_battle_core(attacker_index, card_data, tile_info, attacker_item, defender_item, -1)

# バトル実行（カードデータ直接指定版）- カード使用処理は呼び出し側で行う
func execute_3d_battle_with_data(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}, from_tile_index: int = -1) -> void:
	if not validate_systems():
		print("Error: システム参照が設定されていません")
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# 防御クリーチャーがいない場合（侵略）
	if tile_info.get("creature", {}).is_empty():
		execute_invasion_3d(attacker_index, card_data, tile_info)
		return
	
	# バトル実行
	_execute_battle_core(attacker_index, card_data, tile_info, attacker_item, defender_item, from_tile_index)

# バトルコア処理（共通化）
func _execute_battle_core(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary, defender_item: Dictionary, from_tile_index: int = -1) -> void:
	print("========== バトル開始 ==========")
	
	# 1. 両者の準備
	var participants = battle_preparation.prepare_participants(attacker_index, card_data, tile_info, attacker_item, defender_item)
	var attacker = participants["attacker"]
	var defender = participants["defender"]
	var battle_result = participants.get("transform_result", {})
	
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
	
	# 4. 攻撃シーケンス実行（戦闘結果情報を取得）
	var attack_result = battle_execution.execute_attack_sequence(attack_order, tile_info, battle_special_effects, battle_skill_processor)
	# 戦闘結果を統合（空でない値のみマージ）
	for key in attack_result.keys():
		var value = attack_result[key]
		# 復活フラグはtrueの場合のみ上書き
		if key in ["attacker_revived", "defender_revived"]:
			if value == true:
				battle_result[key] = value
		# 変身情報は値が空でない場合のみ上書き
		elif key in ["attacker_transformed", "defender_transformed"]:
			if value == true:
				battle_result[key] = value
		elif key in ["attacker_original", "defender_original"]:
			if not value.is_empty():
				battle_result[key] = value
		else:
			battle_result[key] = value
	
	# 5. 結果判定
	var result = battle_execution.resolve_battle_result(attacker, defender)
	
	# 6. 結果に応じた処理（死者復活情報も渡す）
	_apply_post_battle_effects(result, attacker_index, card_data, tile_info, attacker, defender, battle_result, from_tile_index)
	
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
	_card_data: Dictionary,
	tile_info: Dictionary,
	attacker: BattleParticipant,
	defender: BattleParticipant,
	battle_result: Dictionary = {},
	from_tile_index: int = -1
) -> void:
	var tile_index = tile_info["index"]
	
	# 再生スキル処理
	battle_special_effects.apply_regeneration(attacker)
	battle_special_effects.apply_regeneration(defender)
	
	match result:
		BattleResult.ATTACKER_WIN:
			print("
【結果】侵略成功！土地を獲得")
			
			# 破壊カウンター更新
			if game_flow_manager_ref:
				game_flow_manager_ref.on_creature_destroyed()
			
			# 攻撃側の永続バフ適用（バルキリー・ダスクドウェラー）
			_apply_on_destroy_permanent_buffs(attacker)
			
			# 防御側が破壊されたので、防御側の永続バフも適用（相互破壊の可能性）
			if defender.current_hp <= 0:
				_apply_on_destroy_permanent_buffs(defender)
			
			# バトル後の永続変化を適用（ロックタイタン・リーンタイタン）
			_apply_after_battle_permanent_changes(attacker)
			_apply_after_battle_permanent_changes(defender)
			
			# 🔄 一時変身の場合、先に元に戻す（バルダンダース専用）
			if battle_result.get("attacker_original", {}).has("name"):
				TransformProcessor.revert_transform(attacker, battle_result["attacker_original"])
				print("[変身復帰] 攻撃側が元に戻りました")
			
			# 土地を奪取してクリーチャーを配置
			board_system_ref.set_tile_owner(tile_index, attacker_index)
			
			# 🔄 死者復活した場合は復活後のクリーチャーデータを使用
			# 🔄 一時変身の場合は元に戻ったクリーチャーデータを使用
			var place_creature_data = attacker.creature_data.duplicate(true)
			# 戦闘後の残りHPを保存
			place_creature_data["current_hp"] = attacker.current_hp
			board_system_ref.place_creature(tile_index, place_creature_data)
			
			emit_signal("invasion_completed", true, tile_index)
		
		BattleResult.DEFENDER_WIN:
			print("
【結果】防御成功！侵略側を撃破")
			
			# 破壊カウンター更新
			if game_flow_manager_ref:
				game_flow_manager_ref.on_creature_destroyed()
			
			# 防御側の永続バフ適用（バルキリー・ダスクドウェラー）
			_apply_on_destroy_permanent_buffs(defender)
			
			# バトル後の永続変化を適用（ロックタイタン・リーンタイタン）
			_apply_after_battle_permanent_changes(attacker)
			_apply_after_battle_permanent_changes(defender)
			
			# 🔄 一時変身の場合、先に元に戻す（バルダンダース専用）
			if battle_result.get("attacker_original", {}).has("name"):
				TransformProcessor.revert_transform(attacker, battle_result["attacker_original"])
				print("[変身復帰] 攻撃側が元に戻りました")
			
			# 防御側クリーチャーのHPを更新（ダメージを受けたまま）
			battle_special_effects.update_defender_hp(tile_info, defender)
			
			# 侵略失敗：攻撃側カードは破壊される（手札に戻らない）
			print("[侵略失敗] 攻撃側クリーチャーは破壊されました")
			
			emit_signal("invasion_completed", false, tile_index)
		
		BattleResult.ATTACKER_SURVIVED:
			print("
【結果】侵略失敗！攻撃側が生き残り")
			
			# バトル後の永続変化を適用（ロックタイタン・リーンタイタン）
			_apply_after_battle_permanent_changes(attacker)
			_apply_after_battle_permanent_changes(defender)
			
			# 🔄 一時変身の場合、先に元に戻す（バルダンダース専用）
			if battle_result.get("attacker_original", {}).has("name"):
				TransformProcessor.revert_transform(attacker, battle_result["attacker_original"])
				print("[変身復帰] 攻撃側が元に戻りました")
			
			# 移動侵略の場合は移動元タイルに戻す、通常侵略は手札に戻す
			if from_tile_index >= 0:
				# 移動侵略：移動元タイルに戻す
				print("[移動侵略敗北] クリーチャーを移動元タイル%d に戻します" % from_tile_index)
				var from_tile = board_system_ref.tile_nodes[from_tile_index]
				
				# クリーチャーデータを更新（戦闘後の残りHPを反映）
				var return_data = attacker.creature_data.duplicate(true)
				
				# 現在HPを保存
				return_data["current_hp"] = attacker.current_hp
				
				from_tile.creature_data = return_data
				from_tile.owner_id = attacker_index
				
				# ダウン状態にする（不屈チェック）
				if from_tile.has_method("set_down_state"):
					if not SkillSystem.has_unyielding(return_data):
						from_tile.set_down_state(true)
					else:
						print("[移動侵略敗北] 不屈により戻った後もダウンしません")
				
				if from_tile.has_method("update_display"):
					from_tile.update_display()
			else:
				# 通常侵略：カードを手札に戻す
				print("[通常侵略敗北] カードを手札に戻します")
				# 🔄 死者復活した場合は復活後のクリーチャーデータを使用
				# 🔄 一時変身の場合は元に戻ったクリーチャーデータを使用
				var return_card_data = attacker.creature_data.duplicate(true)
				# HPは元の最大値にリセット（手札に戻る時はダメージを回復）
				# creature_data["hp"]は元の最大HP値を保持している
				# （注：base_hpは現在の残りHPなので使わない）
				card_system_ref.return_card_to_hand(attacker_index, return_card_data)
			
			# 防御側クリーチャーのHPを更新（ダメージを受けたまま）
			battle_special_effects.update_defender_hp(tile_info, defender)
			
			emit_signal("invasion_completed", false, tile_index)
	
	# 🔄 防御側の変身を元に戻す（バルダンダース専用）
	# 戦闘後に復帰が必要な変身の場合のみ
	if not battle_result.is_empty():
		if battle_result.get("defender_original", {}).has("name"):
			TransformProcessor.revert_transform(defender, battle_result["defender_original"])
			print("[変身復帰] 防御側が元に戻りました")
	
	# 🔄 永続変身のタイル更新（コカトリス用）
	# 防御側が変身した場合、タイルのcreature_dataを更新
	if battle_result.get("defender_transformed", false):
		print("[デバッグ] 防御側変身検出: ", defender.creature_data.get("name", "?"))
		print("[デバッグ] defender_original: ", battle_result.get("defender_original", {}))
		if not battle_result.get("defender_original", {}).has("name"):
			# 永続変身の場合（元データなし = 戻さない）
			# tile_indexは既に関数の上部で定義済み
			var updated_creature = defender.creature_data.duplicate(true)
			updated_creature["hp"] = defender.base_hp  # 現在のHPを保持
			board_system_ref.update_tile_creature(tile_index, updated_creature)
			print("[永続変身] タイルのクリーチャーを更新しました: ", updated_creature.get("name", "?"))
	
	# 🔄 死者復活のタイル更新
	# 死者復活は常に永続なので、タイルのcreature_dataを更新する
	if battle_result.get("defender_revived", false):
		# 防御側が復活した場合、タイルのクリーチャーを更新
		var updated_creature = defender.creature_data.duplicate(true)
		updated_creature["hp"] = defender.base_hp  # 復活後のHPを保持
		board_system_ref.update_tile_creature(tile_index, updated_creature)
		print("[死者復活] タイルのクリーチャーを更新しました: ", updated_creature.get("name", "?"))
	
	if battle_result.get("attacker_revived", false):
		# 攻撃側が復活した場合も、タイルのクリーチャーを更新
		# 攻撃側が復活する場合は侵略成功の場合のみ
		if result == BattleResult.ATTACKER_WIN:
			var updated_creature = attacker.creature_data.duplicate(true)
			updated_creature["hp"] = attacker.base_hp  # 復活後のHPを保持
			board_system_ref.update_tile_creature(tile_index, updated_creature)
			print("[死者復活] タイルのクリーチャーを更新しました: ", updated_creature.get("name", "?"))
	
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

# ========================================
# 永続バフ処理（破壊時）
# ========================================

# 敵破壊時の永続バフ適用（バルキリー・ダスクドウェラー）
func _apply_on_destroy_permanent_buffs(participant: BattleParticipant):
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "on_enemy_destroy_permanent":
			var stat_changes = effect.get("stat_changes", {})
			
			for stat in stat_changes:
				var value = stat_changes[stat]
				if stat == "ap":
					if not participant.creature_data.has("base_up_ap"):
						participant.creature_data["base_up_ap"] = 0
					participant.creature_data["base_up_ap"] += value
					print("[永続バフ] ", participant.creature_data.get("name", ""), " ST+", value)
				
				elif stat == "max_hp":
					if not participant.creature_data.has("base_up_hp"):
						participant.creature_data["base_up_hp"] = 0
					participant.creature_data["base_up_hp"] += value
					print("[永続バフ] ", participant.creature_data.get("name", ""), " MHP+", value)

# バトル後の永続的な変化を適用（勝敗問わず）
# ロックタイタン (ID: 446)、リーンタイタン (ID: 439) など
func _apply_after_battle_permanent_changes(participant: BattleParticipant):
	if not participant or not participant.creature_data:
		return
	
	# バイロマンサー専用処理（敵から攻撃を受けた場合のみ発動）
	var creature_id = participant.creature_data.get("id", -1)
	if creature_id == 34:  # バイロマンサー
		# 敵から攻撃を受けた、かつ生き残っている、かつまだ発動していない
		if participant.was_attacked_by_enemy and participant.is_alive():
			if not participant.creature_data.get("bairomancer_triggered", false):
				# ST=20（完全上書き）、MHP-30
				var old_ap = participant.creature_data.get("ap", 0)
				var old_base_up_ap = participant.creature_data.get("base_up_ap", 0)
				
				participant.creature_data["ap"] = 20  # 基礎APを20に上書き
				participant.creature_data["base_up_ap"] = 0  # base_up_apをリセット
				
				if not participant.creature_data.has("base_up_hp"):
					participant.creature_data["base_up_hp"] = 0
				participant.creature_data["base_up_hp"] -= 30
				
				# 発動フラグを設定
				participant.creature_data["bairomancer_triggered"] = true
				
				print("[バイロマンサー発動] 敵の攻撃を受けて変化！")
				print("  ST: ", old_ap + old_base_up_ap, " → 20")
				print("  MHP-30 (合計MHP:", participant.creature_data.get("hp", 0) + participant.creature_data["base_up_hp"], ")")
	
	# ブルガサリ専用処理（敵がアイテムを使用した戦闘後、MHP+10）
	if creature_id == 339:  # ブルガサリ
		if participant.enemy_used_item and participant.is_alive():
			if not participant.creature_data.has("base_up_hp"):
				participant.creature_data["base_up_hp"] = 0
			participant.creature_data["base_up_hp"] += 10
			print("[ブルガサリ発動] 敵のアイテム使用後 MHP+10 (合計MHP:", participant.creature_data.get("hp", 0) + participant.creature_data["base_up_hp"], ")")
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "after_battle_permanent_change":
			var stat_changes = effect.get("stat_changes", {})
			
			for stat in stat_changes:
				var value = stat_changes[stat]
				if stat == "ap":
					if not participant.creature_data.has("base_up_ap"):
						participant.creature_data["base_up_ap"] = 0
					# 下限チェック: ST（base_ap + base_up_ap）が0未満にならないようにする
					var _current_total_ap = participant.creature_data.get("ap", 0) + participant.creature_data["base_up_ap"]
					var new_base_up_ap = participant.creature_data["base_up_ap"] + value
					var new_total_ap = participant.creature_data.get("ap", 0) + new_base_up_ap
					
					if new_total_ap < 0:
						# 合計STが0になるように調整
						new_base_up_ap = -participant.creature_data.get("ap", 0)
						print("[永続変化] ", participant.creature_data.get("name", ""), " ST", value, " → 下限0に制限")
					
					participant.creature_data["base_up_ap"] = new_base_up_ap
					print("[永続変化] ", participant.creature_data.get("name", ""), " ST", value if value >= 0 else "", value, " (合計ST:", participant.creature_data.get("ap", 0) + new_base_up_ap, ")")
				
				elif stat == "max_hp":
					if not participant.creature_data.has("base_up_hp"):
						participant.creature_data["base_up_hp"] = 0
					# 下限チェック: MHP（hp + base_up_hp）が0未満にならないようにする
					var _current_total_hp = participant.creature_data.get("hp", 0) + participant.creature_data["base_up_hp"]
					var new_base_up_hp = participant.creature_data["base_up_hp"] + value
					var new_total_hp = participant.creature_data.get("hp", 0) + new_base_up_hp
					
					if new_total_hp < 0:
						# 合計MHPが0になるように調整
						new_base_up_hp = -participant.creature_data.get("hp", 0)
						print("[永続変化] ", participant.creature_data.get("name", ""), " MHP", value, " → 下限0に制限")
					
					participant.creature_data["base_up_hp"] = new_base_up_hp
					print("[永続変化] ", participant.creature_data.get("name", ""), " MHP", value if value >= 0 else "", value, " (合計MHP:", participant.creature_data.get("hp", 0) + new_base_up_hp, ")")
	
	# スペクター専用処理（戦闘後にランダムステータスをリセット）
	if creature_id == 321:  # スペクター
		# random_statエフェクトを持つ場合、base_hp/base_apを元の値に戻す
		var has_random_stat = false
		for effect in effects:
			if effect.get("effect_type") == "random_stat":
				has_random_stat = true
				break
		
		if has_random_stat and participant.is_alive():
			# 元のカードデータからbase_hp/base_apを取得
			var original_hp = CardLoader.get_card_by_id(321).get("hp", 20)
			var original_ap = CardLoader.get_card_by_id(321).get("ap", 20)
			
			# creature_dataのhp/apを元の値に戻す
			participant.creature_data["hp"] = original_hp
			participant.creature_data["ap"] = original_ap
			
			print("[ランダムステータスリセット] スペクターの能力値を初期値に戻しました (ST:", original_ap, ", HP:", original_hp, ")")
