extends Node
class_name BattleSystem

# バトル管理システム - 3D専用版（リファクタリング版）
# サブシステムに処理を委譲し、コア機能のみを保持

signal invasion_completed(success: bool, tile_index: int)

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")
var _skill_item_return = preload("res://scripts/battle/skills/skill_item_return.gd")

# バトル結果
enum BattleResult {
	ATTACKER_WIN,           # 侵略成功（土地獲得）
	DEFENDER_WIN,           # 防御成功（侵略側カード破壊）
	ATTACKER_SURVIVED,      # 侵略失敗（侵略側カード手札に戻る）
	BOTH_DEFEATED           # 相打ち（土地は無所有になる）
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

# SpellDraw/SpellMagic参照
var spell_draw = null
var spell_magic = null

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
	
	# SpellDraw/SpellMagicの参照を先に取得
	if game_flow_manager_ref:
		if game_flow_manager_ref.spell_draw:
			spell_draw = game_flow_manager_ref.spell_draw
		if game_flow_manager_ref.spell_magic:
			spell_magic = game_flow_manager_ref.spell_magic
	
	# サブシステムにも参照を設定
	battle_preparation.setup_systems(board_system, card_system, player_system, spell_magic)
	battle_execution.setup_systems(card_system)  # 追加: CardSystemの参照を渡す
	battle_skill_processor.setup_systems(board_system, game_flow_manager_ref, card_system_ref)
	battle_special_effects.setup_systems(board_system, spell_draw, spell_magic, card_system)
	
	# アイテム復帰スキルの初期化
	_skill_item_return.setup_systems(card_system)

# バトル実行（3D版メイン処理）
func execute_3d_battle(attacker_index: int, card_index: int, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}):
	if not validate_systems():
		print("Error: システム参照が設定されていません")
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# カードインデックスが-1の場合は支払い処理なし（end_turn()で一本化）
	if card_index < 0:
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	var card_data = card_system_ref.get_card_data_for_player(attacker_index, card_index)
	if card_data.is_empty():
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
	else:
		cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
	var current_player = player_system_ref.get_current_player()
	
	if current_player.magic_power < cost:
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# カード使用
	card_system_ref.use_card_for_player(attacker_index, card_index)
	player_system_ref.add_magic(attacker_index, -cost)
	
	# 防御クリーチャーがいない場合（侵略）
	if tile_info.get("creature", {}).is_empty():
		execute_invasion_3d(attacker_index, card_data, tile_info)
		return
	
	# バトル実行（通常侵略なので from_tile_index = -1）
	await _execute_battle_core(attacker_index, card_data, tile_info, attacker_item, defender_item, -1)

# バトル実行（カードデータ直接指定版）- カード使用処理は呼び出し側で行う
func execute_3d_battle_with_data(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}, from_tile_index: int = -1):
	if not validate_systems():
		print("Error: システム参照が設定されていません")
		emit_signal("invasion_completed", false, tile_info.get("index", 0))
		return
	
	# 防御クリーチャーがいない場合（侵略）
	if tile_info.get("creature", {}).is_empty():
		execute_invasion_3d(attacker_index, card_data, tile_info)
		return
	
	# バトル実行
	await _execute_battle_core(attacker_index, card_data, tile_info, attacker_item, defender_item, from_tile_index)

# バトルコア処理（共通化）
func _execute_battle_core(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary, defender_item: Dictionary, from_tile_index: int = -1):
	print("========== バトル開始 ==========")
	
	var tile_index = tile_info.get("index", -1)
	
	# ミラーワールドチェック: 同名クリーチャーなら戦闘前に両者破壊
	if _check_mirror_world_destroy(card_data, tile_info, attacker_index, tile_index, from_tile_index):
		return  # 相殺で戦闘終了
	
	# バトルタイルのインデックスを取得
	var battle_tile_index = tile_info.get("index", -1)
	
	# 1. 両者の準備
	var participants = battle_preparation.prepare_participants(attacker_index, card_data, tile_info, attacker_item, defender_item, battle_tile_index)
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
	var attacker_total_hp = attacker.current_hp + attacker.resonance_bonus_hp + attacker.land_bonus_hp + attacker.temporary_bonus_hp + attacker.item_bonus_hp + attacker.spell_bonus_hp
	print("  HP:", attacker_total_hp, " (基本:", attacker.current_hp, " 感応:", attacker.resonance_bonus_hp, " 土地:", attacker.land_bonus_hp, " 一時:", attacker.temporary_bonus_hp, " アイテム:", attacker.item_bonus_hp, " スペル:", attacker.spell_bonus_hp, ")")
	print("  AP:", attacker.current_ap)
	print("防御側: ", defender.creature_data.get("name", "?"))
	var defender_total_hp = defender.current_hp + defender.resonance_bonus_hp + defender.land_bonus_hp + defender.temporary_bonus_hp + defender.item_bonus_hp + defender.spell_bonus_hp
	print("  HP:", defender_total_hp, " (基本:", defender.current_hp, " 感応:", defender.resonance_bonus_hp, " 土地:", defender.land_bonus_hp, " 一時:", defender.temporary_bonus_hp, " アイテム:", defender.item_bonus_hp, " スペル:", defender.spell_bonus_hp, ")")
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
	await _apply_post_battle_effects(result, attacker_index, card_data, tile_info, attacker, defender, battle_result, from_tile_index)
	
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

# ミラーワールド: 同名クリーチャー複数配置禁止チェック
# 戦闘時、自フィールドに同名クリーチャーがいる側が破壊される
func _check_mirror_world_destroy(card_data: Dictionary, tile_info: Dictionary, attacker_index: int, tile_index: int, from_tile_index: int) -> bool:
	if not game_flow_manager_ref or not game_flow_manager_ref.spell_world_curse:
		return false
	
	var spell_world_curse = game_flow_manager_ref.spell_world_curse
	
	# ミラーワールドが有効かチェック
	if not spell_world_curse.is_mirror_world_active():
		return false
	
	var attacker_name = card_data.get("name", "")
	var defender_creature = tile_info.get("creature", {})
	var defender_name = defender_creature.get("name", "")
	var defender_owner = tile_info.get("owner", -1)
	
	# 攻撃側: 自分のフィールドに同名クリーチャーがいるか
	var attacker_has_duplicate = spell_world_curse.check_has_same_name_creature(
		board_system_ref, attacker_index, attacker_name, from_tile_index
	)
	
	# 防御側: 自分のフィールドに同名クリーチャーが他にいるか（自身のタイルを除外）
	var defender_has_duplicate = spell_world_curse.check_has_same_name_creature(
		board_system_ref, defender_owner, defender_name, tile_index
	)
	
	# どちらも条件を満たさない場合は発動しない
	if not attacker_has_duplicate and not defender_has_duplicate:
		return false
	
	print("【ミラーワールド】同名クリーチャー複数配置チェック")
	var destroy_count = 0
	
	# 攻撃側が条件を満たす場合 → 攻撃側破壊
	if attacker_has_duplicate:
		print("  攻撃側 ", attacker_name, " を破壊（同名クリーチャーが既に配置済み）")
		
		# 移動侵略の場合、元のタイルのクリーチャーを破壊
		if from_tile_index >= 0:
			# 破壊時効果を処理
			var attacker_hp = card_data.get("hp", 0) + card_data.get("base_up_hp", 0)
			var attacker_ap = card_data.get("ap", 0) + card_data.get("base_up_ap", 0)
			var attacker_participant = BattleParticipant.new(card_data, attacker_hp, 0, attacker_ap, true, attacker_index)
			var dummy_opponent = BattleParticipant.new({}, 0, 0, 0, false, -1)
			battle_special_effects.check_on_death_effects(attacker_participant, dummy_opponent, CardLoader)
			
			board_system_ref.remove_creature(from_tile_index)
			board_system_ref.set_tile_owner(from_tile_index, -1)
		else:
			# 手札からの侵略の場合、破壊時効果を処理（カード自体は手札から既に消費済み）
			var attacker_hp = card_data.get("hp", 0) + card_data.get("base_up_hp", 0)
			var attacker_ap = card_data.get("ap", 0) + card_data.get("base_up_ap", 0)
			var attacker_participant = BattleParticipant.new(card_data, attacker_hp, 0, attacker_ap, true, attacker_index)
			var dummy_opponent = BattleParticipant.new({}, 0, 0, 0, false, -1)
			battle_special_effects.check_on_death_effects(attacker_participant, dummy_opponent, CardLoader)
		
		destroy_count += 1
	
	# 防御側が条件を満たす場合 → 防御側破壊
	if defender_has_duplicate:
		print("  防御側 ", defender_name, " を破壊（同名クリーチャーが既に配置済み）")
		
		# 破壊時効果を処理
		var defender_hp = defender_creature.get("hp", 0) + defender_creature.get("base_up_hp", 0)
		var defender_ap = defender_creature.get("ap", 0) + defender_creature.get("base_up_ap", 0)
		var defender_participant = BattleParticipant.new(defender_creature, defender_hp, 0, defender_ap, false, defender_owner)
		var dummy_opponent = BattleParticipant.new({}, 0, 0, 0, true, -1)
		battle_special_effects.check_on_death_effects(defender_participant, dummy_opponent, CardLoader)
		
		board_system_ref.remove_creature(tile_index)
		board_system_ref.set_tile_owner(tile_index, -1)
		destroy_count += 1
	
	# UI更新
	if board_system_ref.has_method("update_all_tile_displays"):
		board_system_ref.update_all_tile_displays()
	
	# 破壊カウント更新
	if game_flow_manager_ref.has_method("increment_destroy_count"):
		for i in range(destroy_count):
			game_flow_manager_ref.increment_destroy_count()
	
	# バトル完了シグナル
	# 攻撃側だけ破壊 → 侵略失敗
	# 防御側だけ破壊 → 侵略成功（タイル取得）
	# 両方破壊 → 侵略失敗
	var invasion_success = defender_has_duplicate and not attacker_has_duplicate
	if invasion_success:
		# 攻撃側がタイルを取得
		board_system_ref.set_tile_owner(tile_index, attacker_index)
		if from_tile_index < 0:
			# 手札から侵略の場合、クリーチャーを配置
			board_system_ref.place_creature(tile_index, card_data, attacker_index)
		else:
			# 移動侵略の場合、移動元から移動
			board_system_ref.place_creature(tile_index, card_data, attacker_index)
	
	emit_signal("invasion_completed", invasion_success, tile_index)
	
	return true

# システム検証
func validate_systems() -> bool:
	return board_system_ref != null and card_system_ref != null and player_system_ref != null

# バトル後の処理（非同期：バウンティハント通知等）
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
	
	# 💰 魔力獲得処理（ゴールドハンマー: 敵生存時に魔力獲得）
	_apply_magic_on_enemy_survive(result, attacker, defender)
	
	match result:
		BattleResult.ATTACKER_WIN:
			print("
【結果】侵略成功！土地を獲得")
			
			# 破壊カウンター更新
			if game_flow_manager_ref:
				game_flow_manager_ref.on_creature_destroyed()
			
			# バウンティハント（賞金首）報酬チェック - 防御側が敗者
			await _check_and_apply_bounty_reward(defender, attacker)
			
			# 攻撃側の永続バフ適用（バルキリー・ダスクドウェラー）
			SkillPermanentBuff.apply_on_destroy_buffs(attacker)
			
			# 防御側が破壊されたので、防御側の永続バフも適用（相互破壊の可能性）
			if defender.current_hp <= 0:
				SkillPermanentBuff.apply_on_destroy_buffs(defender)
			
			# バトル後の永続変化を適用（ロックタイタン・リーンタイタン）
			SkillPermanentBuff.apply_after_battle_changes(attacker)
			SkillPermanentBuff.apply_after_battle_changes(defender)
			
			# 🔄 一時変身の場合、先に元に戻す（バルダンダース専用）
			if battle_result.get("attacker_original", {}).has("name"):
				TransformSkill.revert_transform(attacker, battle_result["attacker_original"])
				print("[変身復帰] 攻撃側が元に戻りました")
			
			# 土地を奪取してクリーチャーを配置
			board_system_ref.set_tile_owner(tile_index, attacker_index)
			
			# 🔄 死者復活した場合は復活後のクリーチャーデータを使用
			# 🔄 一時変身の場合は元に戻ったクリーチャーデータを使用
			var place_creature_data = attacker.creature_data.duplicate(true)
			# BattleParticipantのプロパティから永続バフを反映
			print("[侵略成功] タイル配置時の永続バフ反映:")
			print("  base_up_hp: ", attacker.base_up_hp)
			print("  base_up_ap: ", attacker.base_up_ap)
			place_creature_data["base_up_hp"] = attacker.base_up_hp
			place_creature_data["base_up_ap"] = attacker.base_up_ap
			# 戦闘後の残りHPを保存
			place_creature_data["current_hp"] = attacker.current_hp
			# 移動中フラグを削除（応援スキル用）
			place_creature_data.erase("is_moving")
			board_system_ref.place_creature(tile_index, place_creature_data)
			
			# 移動侵略の場合、移動元のクリーチャーを削除（配置の後に行う）
			if from_tile_index >= 0:
				board_system_ref.remove_creature(from_tile_index)
				print("[移動侵略成功] 移動元タイル%d のクリーチャーを削除" % from_tile_index)
			
			# 🆙 土地レベルアップ効果（シルバープロウ）
			_apply_level_up_effect(attacker, tile_index)
			
			# 🌍 戦闘勝利時の土地効果（土地変性・土地破壊）
			SkillLandEffects.check_and_apply_on_battle_won(attacker.creature_data, tile_index, board_system_ref)
			
			# 💀 抹消効果（アネイマブル）
			battle_special_effects.check_and_apply_annihilate(attacker, defender)
			
			emit_signal("invasion_completed", true, tile_index)
		
		BattleResult.DEFENDER_WIN:
			print("【結果】防御成功！侵略側を撃破")
			
			# 破壊カウンター更新
			if game_flow_manager_ref:
				game_flow_manager_ref.on_creature_destroyed()
			
			# バウンティハント（賞金首）報酬チェック - 攻撃側が敗者
			# 注: 攻撃側には通常呪いはないが、移動侵略の場合はあり得る
			await _check_and_apply_bounty_reward(attacker, defender)
			
			# 防御側の永続バフ適用（バルキリー・ダスクドウェラー）
			SkillPermanentBuff.apply_on_destroy_buffs(defender)
			
			# バトル後の永続変化を適用（ロックタイタン・リーンタイタン）
			SkillPermanentBuff.apply_after_battle_changes(attacker)
			SkillPermanentBuff.apply_after_battle_changes(defender)
			
			# 🔄 一時変身の場合、先に元に戻す（バルダンダース専用）
			if battle_result.get("attacker_original", {}).has("name"):
				TransformSkill.revert_transform(attacker, battle_result["attacker_original"])
				print("[変身復帰] 攻撃側が元に戻りました")
			
			# 防御側クリーチャーのHPを更新（ダメージを受けたまま）
			# 重要：tile_infoを新しく取得（バトル中の永続バフ反映のため）
			var updated_tile_info = board_system_ref.get_tile_info(tile_index)
			battle_special_effects.update_defender_hp(updated_tile_info, defender)
			
			# 🆙 土地レベルアップ効果（シルバープロウ - 防御成功時）
			_apply_level_up_effect(defender, tile_index)
			
			# 🌍 戦闘勝利時の土地効果（土地変性 - 防御成功時も発動）
			SkillLandEffects.check_and_apply_on_battle_won(defender.creature_data, tile_index, board_system_ref)
			
			# 💀 抹消効果（アネイマブル）
			battle_special_effects.check_and_apply_annihilate(defender, attacker)
			
			# 移動侵略の場合、移動元のクリーチャーも削除
			if from_tile_index >= 0:
				board_system_ref.remove_creature(from_tile_index)
				print("[移動侵略失敗] 移動元タイル%d のクリーチャーを削除（破壊）" % from_tile_index)
			else:
				print("[侵略失敗] 攻撃側クリーチャーは破壊されました")
			
			emit_signal("invasion_completed", false, tile_index)
		
		BattleResult.ATTACKER_SURVIVED:
			print("
【結果】侵略失敗！攻撃側が生き残り")
			
			# バトル後の永続変化を適用（ロックタイタン・リーンタイタン）
			SkillPermanentBuff.apply_after_battle_changes(attacker)
			SkillPermanentBuff.apply_after_battle_changes(defender)
			
			# 🔄 一時変身の場合、先に元に戻す（バルダンダース専用）
			if battle_result.get("attacker_original", {}).has("name"):
				TransformSkill.revert_transform(attacker, battle_result["attacker_original"])
				print("[変身復帰] 攻撃側が元に戻りました")
			
			# 移動侵略の場合は移動元タイルに戻す、通常侵略は手札に戻す
			if from_tile_index >= 0:
				# 移動侵略：移動元タイルに戻す
				print("[移動侵略敗北] クリーチャーを移動元タイル%d に戻します" % from_tile_index)
				var from_tile = board_system_ref.tile_nodes[from_tile_index]
				
				# クリーチャーデータを更新（戦闘後の残りHPを反映）
				var return_data = attacker.creature_data.duplicate(true)
				
				# BattleParticipantのプロパティから永続バフを反映
				return_data["base_up_hp"] = attacker.base_up_hp
				return_data["base_up_ap"] = attacker.base_up_ap
				
				# 現在HPを保存
				return_data["current_hp"] = attacker.current_hp
				# 移動中フラグを削除（応援スキル用）
				return_data.erase("is_moving")
				
				# 所有者を設定してからクリーチャーを配置（3Dカード表示を再作成）
				from_tile.owner_id = attacker_index
				from_tile.place_creature(return_data)
				
				# ダウン状態にする（不屈チェック）
				if from_tile.has_method("set_down_state"):
					if not PlayerBuffSystem.has_unyielding(return_data):
						from_tile.set_down_state(true)
					else:
						print("[移動侵略敗北] 不屈により戻った後もダウンしません")
				
				from_tile.update_visual()
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
			# 重要：tile_infoを新しく取得（バトル中の永続バフ反映のため）
			var updated_tile_info = board_system_ref.get_tile_info(tile_index)
			battle_special_effects.update_defender_hp(updated_tile_info, defender)
			
			emit_signal("invasion_completed", false, tile_index)
		
		BattleResult.BOTH_DEFEATED:
			print("【結果】相打ち！土地は無所有になります")
			
			# 破壊カウンター更新（両方破壊）
			if game_flow_manager_ref:
				game_flow_manager_ref.on_creature_destroyed()
				game_flow_manager_ref.on_creature_destroyed()
			
			# バウンティハント: 相打ちの場合は報酬なし（勝者がいない）
			
			# バトル後の永続変化を適用（ロックタイタン・リーンタイタン）
			SkillPermanentBuff.apply_after_battle_changes(attacker)
			SkillPermanentBuff.apply_after_battle_changes(defender)
			
			# 🔄 一時変身の場合、先に元に戻す（バルダンダース専用）
			if battle_result.get("attacker_original", {}).has("name"):
				TransformSkill.revert_transform(attacker, battle_result["attacker_original"])
				print("[変身復帰] 攻撃側が元に戻りました")
			if battle_result.get("defender_original", {}).has("name"):
				TransformSkill.revert_transform(defender, battle_result["defender_original"])
				print("[変身復帰] 防御側が元に戻りました")
			
			# 土地を無所有にする（クリーチャーを削除）
			board_system_ref.set_tile_owner(tile_index, -1)  # 無所有
			board_system_ref.remove_creature(tile_index)
			
			# 移動侵略の場合、移動元のクリーチャーも削除
			if from_tile_index >= 0:
				board_system_ref.remove_creature(from_tile_index)
				print("[相打ち] 移動元タイル%d のクリーチャーも削除" % from_tile_index)
			
			# 攻撃側カードは破壊される（手札に戻らない）
			print("[相打ち] 両方のクリーチャーが破壊されました")
			
			emit_signal("invasion_completed", false, tile_index)
	
	# 🔄 防御側の変身を元に戻す（バルダンダース専用）
	# 戦闘後に復帰が必要な変身の場合のみ
	if not battle_result.is_empty():
		if battle_result.get("defender_original", {}).has("name"):
			TransformSkill.revert_transform(defender, battle_result["defender_original"])
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
	
	# 🔄 手札復活処理はcheck_on_death_effects内で即座に実行済み
	
	# 📦 アイテム復帰処理
	_apply_item_return(attacker, attacker_index)
	_apply_item_return(defender, defender.player_id)
	
	# 表示更新
	if board_system_ref.has_method("update_all_tile_displays"):
		board_system_ref.update_all_tile_displays()


## 💰 バトル結果確定後の魔力獲得処理（ゴールドハンマー用）
func _apply_magic_on_enemy_survive(result: BattleResult, attacker: BattleParticipant, defender: BattleParticipant):
	"""
	バトル結果が確定した直後に魔力獲得効果をチェック
	
	ゴールドハンマー: 「攻撃で敵非破壊時、魔力獲得」
	- 攻撃側がアイテムを使用し、防御側が生存している場合に発動
	- DEFENDER_WIN（防御成功）: 防御側生存 → 発動
	- ATTACKER_SURVIVED（侵略失敗）: 防御側生存 → 発動
	"""
	if not spell_magic:
		return
	
	# 攻撃側のゴールドハンマーをチェック（防御側が生存している場合）
	if result == BattleResult.DEFENDER_WIN or result == BattleResult.ATTACKER_SURVIVED:
		_check_attacker_gold_hammer(attacker, defender)
	
	# 防御側のアイテムもチェック（攻撃側生存時）
	# 防御側が武器を使用し、攻撃側が生存している場合
	if result == BattleResult.ATTACKER_SURVIVED:
		_check_defender_magic_on_enemy_survive(defender, attacker)

## 攻撃側のゴールドハンマー効果をチェック
func _check_attacker_gold_hammer(attacker: BattleParticipant, defender: BattleParticipant):
	"""
	攻撃側のアイテムをチェックして、敵非破壊時の魔力獲得効果を適用
	攻撃側が死亡していても、防御側が生存していれば発動する
	"""
	if not attacker or not defender:
		return
	
	# 防御側が生存していない場合は発動しない（敵非破壊が条件）
	if not defender.is_alive():
		return
	
	var items = attacker.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type", "") == "magic_on_enemy_survive":
				var amount = effect.get("amount", 200)
				print("【魔力獲得(敵非破壊)】", attacker.creature_data.get("name", "?"), "の", item.get("name", "?"), 
					  " → プレイヤー", attacker.player_id + 1, "が", amount, "G獲得")
				spell_magic.add_magic(attacker.player_id, amount)

## 防御側の魔力獲得効果をチェック（攻撃側生存時）
func _check_defender_magic_on_enemy_survive(defender: BattleParticipant, attacker: BattleParticipant):
	"""
	防御側のアイテムをチェックして、敵非破壊時の魔力獲得効果を適用
	"""
	if not defender or not attacker:
		return
	
	# 攻撃側が生存していない場合は発動しない
	if not attacker.is_alive():
		return
	
	var items = defender.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type", "") == "magic_on_enemy_survive":
				# 防御側の場合、condition: "attacker_win_enemy_alive" は適用されない
				# （防御側は攻撃側ではないため）
				var condition = effect.get("condition", "")
				if condition == "attacker_win_enemy_alive":
					continue  # この条件は攻撃側専用
				
				var amount = effect.get("amount", 200)
				print("【魔力獲得(敵非破壊)】", defender.creature_data.get("name", "?"), "の", item.get("name", "?"), 
					  " → プレイヤー", defender.player_id + 1, "が", amount, "G獲得")
				spell_magic.add_magic(defender.player_id, amount)

# バウンティハント（賞金首）呪いの報酬処理 - SpellMagicに委譲
func _check_and_apply_bounty_reward(loser: BattleParticipant, winner: BattleParticipant) -> void:
	if not loser or not loser.creature_data:
		return
	
	if not spell_magic:
		print("[バウンティハント] spell_magicが未設定")
		return
	
	# SpellMagicに委譲（通知付き）
	await spell_magic.apply_bounty_reward_with_notification(loser.creature_data, winner.creature_data)

# アイテム復帰処理
func _apply_item_return(participant: BattleParticipant, player_id: int):
	if not participant or not participant.creature_data:
		return
	
	# 使用したアイテムを取得
	var used_items = participant.creature_data.get("items", [])
	if used_items.is_empty():
		return
	
	# アイテム復帰スキルをチェックして適用
	var return_result = _skill_item_return.check_and_apply_item_return(participant, used_items, player_id)
	
	if return_result.get("returned", false):
		var count = return_result.get("count", 0)
		print("【アイテム復帰完了】", count, "個のアイテムが復帰しました")

# 土地レベルアップ効果（シルバープロウ）
func _apply_level_up_effect(participant: BattleParticipant, tile_index: int):
	if not participant or not participant.creature_data:
		return
	
	# アイテムから土地レベルアップ効果を探す
	var items = participant.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type") == "level_up_on_win" and effect.get("trigger") == "on_battle_win":
				# 現在の土地レベルを取得
				var tile_info = board_system_ref.get_tile_info(tile_index)
				var current_level = tile_info.get("level", 1)
				
				# レベル5が上限
				if current_level >= 5:
					print("【土地レベルアップ】", item.get("name", "?"), " - すでにレベル5のため効果なし")
					return
				
				# レベルを1上げる
				var new_level = current_level + 1
				var tile = board_system_ref.tile_nodes[tile_index]
				if tile and tile.has_method("set_level"):
					tile.set_level(new_level)
					print("【土地レベルアップ】", item.get("name", "?"), " - レベル", current_level, " → ", new_level)
				
				return  # 最初の1つだけ適用
