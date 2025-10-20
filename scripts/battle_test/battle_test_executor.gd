# バトルテスト実行エンジン
class_name BattleTestExecutor
extends RefCounted

# モックシステム（BattleSystemが必要とする最小限の実装）
class MockBoardSystem extends RefCounted:
	var mock_lands: Dictionary = {}
	
	func get_player_lands_by_element(player_id: int) -> Dictionary:
		return mock_lands.get(player_id, {})
	
	func set_mock_lands(player_id: int, lands: Dictionary):
		mock_lands[player_id] = lands

class MockCardSystem extends CardSystem:
	func _init():
		pass  # CardSystemの初期化をスキップ

class MockPlayerSystem extends PlayerSystem:
	func _init():
		pass  # PlayerSystemの初期化をスキップ

## バトル実行
static func execute_all_battles(config: BattleTestConfig) -> Array:
	var results: Array = []
	var battle_id = 0
	
	print("[BattleTestExecutor] バトル実行開始")
	print("  攻撃側クリーチャー: ", config.attacker_creatures.size(), "体")
	print("  攻撃側アイテム: ", config.attacker_items.size(), "個")
	print("  防御側クリーチャー: ", config.defender_creatures.size(), "体")
	print("  防御側アイテム: ", config.defender_items.size(), "個")
	
	var start_time = Time.get_ticks_msec()
	
	# 攻撃側クリーチャーごと
	for att_creature_id in config.attacker_creatures:
		# 防御側クリーチャーごと
		for def_creature_id in config.defender_creatures:
			# 攻撃側アイテムごと（なしも含む）
			var att_items = config.attacker_items if config.attacker_items.size() > 0 else [-1]
			for att_item_id in att_items:
				# 防御側アイテムごと（なしも含む）
				var def_items = config.defender_items if config.defender_items.size() > 0 else [-1]
				for def_item_id in def_items:
					battle_id += 1
					
					var result = _execute_single_battle(
						battle_id,
						att_creature_id, att_item_id, config.attacker_spell,
						def_creature_id, def_item_id, config.defender_spell,
						config
					)
					
					if result:
						results.append(result)
	
	var end_time = Time.get_ticks_msec()
	var duration = end_time - start_time
	
	print("[BattleTestExecutor] バトル実行完了")
	print("  総バトル数: ", results.size())
	print("  実行時間: ", duration, "ms (", "%.2f" % (duration / 1000.0), "秒)")
	
	return results

## 単一バトル実行
static func _execute_single_battle(
	battle_id: int,
	att_creature_id: int, att_item_id: int, att_spell_id: int,
	def_creature_id: int, def_item_id: int, def_spell_id: int,
	config: BattleTestConfig
) -> BattleTestResult:
	
	var start_time = Time.get_ticks_msec()
	
	# カードデータ取得
	var att_card_data = CardLoader.get_card_by_id(att_creature_id)
	var def_card_data = CardLoader.get_card_by_id(def_creature_id)
	
	if not att_card_data or not def_card_data:
		push_error("カードデータ取得失敗")
		return null
	
	# BattleSystemを先に作成
	var battle_system = BattleSystem.new()
	
	# BattleParticipant作成
	var attacker = BattleParticipant.new(
		att_card_data,
		att_card_data.hp,
		0,  # 攻撃側は土地ボーナスなし
		att_card_data.ap,
		true,  # is_attacker
		0  # player_id
	)
	
	# 効果配列を適用（Phase 2追加）
	battle_system.battle_preparation.apply_effect_arrays(attacker, att_card_data)
	
	# 防御側の土地ボーナス計算（仮のタイル情報）
	var def_land_bonus = 0
	var tile_element = config.defender_battle_land
	if def_card_data.element == tile_element:
		# 土地レベルは1と仮定
		def_land_bonus = 10
	
	var defender = BattleParticipant.new(
		def_card_data,
		def_card_data.hp,
		def_land_bonus,
		def_card_data.ap,
		false,  # is_attacker
		1  # player_id
	)
	
	# 効果配列を適用（Phase 2追加）
	battle_system.battle_preparation.apply_effect_arrays(defender, def_card_data)
	
	# アイテム効果適用
	var attacker_granted_skills = []
	var defender_granted_skills = []
	
	if att_item_id > 0:
		attacker_granted_skills = _apply_item_effects_and_record(battle_system, attacker, att_item_id)
	
	if def_item_id > 0:
		defender_granted_skills = _apply_item_effects_and_record(battle_system, defender, def_item_id)
	
	# モックシステムをセットアップ
	var mock_board = MockBoardSystem.new()
	mock_board.set_mock_lands(0, config.attacker_owned_lands)
	mock_board.set_mock_lands(1, config.defender_owned_lands)
	
	var mock_card = MockCardSystem.new()
	var mock_player = MockPlayerSystem.new()
	
	battle_system.setup_systems(mock_board, mock_card, mock_player)
	
	# ダミータイル情報作成
	var tile_info = {
		"element": config.defender_battle_land,
		"level": config.defender_battle_land_level,  # 設定から取得
		"index": 0,
		"owner": 1,
		"creature": def_card_data
	}
	
	# 攻撃順を決定
	var attack_order = battle_system.battle_execution.determine_attack_order(attacker, defender)
	
	# スキル適用
	var participants = {"attacker": attacker, "defender": defender}
	battle_system.battle_skill_processor.apply_pre_battle_skills(participants, tile_info, 0)
	
	# 攻撃シーケンス実行
	battle_system.battle_execution.execute_attack_sequence(attack_order, tile_info, battle_system.battle_special_effects)
	
	# 結果判定
	var battle_result = battle_system.battle_execution.resolve_battle_result(attacker, defender)
	
	# 結果を記録
	var test_result = BattleTestResult.new()
	test_result.battle_id = battle_id
	
	# 攻撃側情報
	test_result.attacker_id = att_creature_id
	test_result.attacker_name = attacker.creature_data.get("name", "Unknown")
	test_result.attacker_item_id = att_item_id
	test_result.attacker_item_name = _get_item_name(att_item_id)
	test_result.attacker_spell_id = att_spell_id
	test_result.attacker_spell_name = _get_spell_name(att_spell_id)
	test_result.attacker_base_ap = attacker.creature_data.get("ap", 0)
	test_result.attacker_base_hp = attacker.creature_data.get("hp", 0)
	test_result.attacker_final_ap = attacker.current_ap
	test_result.attacker_final_hp = attacker.base_hp
	test_result.attacker_granted_skills = attacker_granted_skills
	test_result.attacker_skills_triggered = _get_triggered_skills(attacker)
	test_result.attacker_effect_info = _get_effect_info(attacker)
	
	# 防御側情報
	test_result.defender_id = def_creature_id
	test_result.defender_name = defender.creature_data.get("name", "Unknown")
	test_result.defender_item_id = def_item_id
	test_result.defender_item_name = _get_item_name(def_item_id)
	test_result.defender_spell_id = def_spell_id
	test_result.defender_spell_name = _get_spell_name(def_spell_id)
	test_result.defender_base_ap = defender.creature_data.get("ap", 0)
	test_result.defender_base_hp = defender.creature_data.get("hp", 0)
	test_result.defender_final_ap = defender.current_ap
	test_result.defender_final_hp = defender.base_hp
	test_result.defender_granted_skills = defender_granted_skills
	test_result.defender_skills_triggered = _get_triggered_skills(defender)
	test_result.defender_effect_info = _get_effect_info(defender)
	
	# バトル結果
	var winner_str = ""
	match battle_result:
		BattleSystem.BattleResult.ATTACKER_WIN:
			winner_str = "attacker"
		BattleSystem.BattleResult.DEFENDER_WIN:
			winner_str = "defender"
		BattleSystem.BattleResult.ATTACKER_SURVIVED:
			winner_str = "draw"
	
	test_result.winner = winner_str
	test_result.battle_duration_ms = Time.get_ticks_msec() - start_time
	
	# バトル条件
	test_result.battle_land = config.attacker_battle_land
	test_result.attacker_owned_lands = config.attacker_owned_lands.duplicate()
	test_result.defender_owned_lands = config.defender_owned_lands.duplicate()
	test_result.attacker_has_adjacent = config.attacker_has_adjacent
	test_result.defender_has_adjacent = config.defender_has_adjacent
	
	return test_result

## アイテム名取得
static func _get_item_name(item_id: int) -> String:
	if item_id <= 0:
		return "なし"
	# TODO: アイテムデータから名前取得
	return "アイテム(ID:%d)" % item_id

## スペル名取得
static func _get_spell_name(spell_id: int) -> String:
	if spell_id <= 0:
		return "なし"
	# TODO: スペルデータから名前取得
	return "スペル(ID:%d)" % spell_id

## アイテム効果適用とスキル付与記録
static func _apply_item_effects_and_record(battle_system: BattleSystem, participant: BattleParticipant, item_id: int) -> Array:
	var granted_skills = []
	
	# アイテムデータ取得
	var item_data = CardLoader.get_card_by_id(item_id)
	if not item_data:
		push_error("アイテムID %d が見つかりません" % item_id)
		return granted_skills
	
	# 付与前のスキル状態を記録
	var had_first_strike_before = participant.has_item_first_strike
	var had_last_strike_before = participant.has_last_strike
	var had_power_strike_before = false
	if participant.creature_data.has("ability_parsed"):
		var keywords = participant.creature_data.ability_parsed.get("keywords", [])
		had_power_strike_before = "強打" in keywords
	
	# BattleSystemのアイテム効果適用を使用
	battle_system.battle_preparation.apply_item_effects(participant, item_data)
	
	# 付与後のスキル状態をチェック
	if participant.has_item_first_strike and not had_first_strike_before:
		granted_skills.append("先制攻撃")
	
	if participant.has_last_strike and not had_last_strike_before:
		granted_skills.append("後手")
	
	# 強打の判定
	if participant.creature_data.has("ability_parsed"):
		var keywords = participant.creature_data.ability_parsed.get("keywords", [])
		var has_power_strike_now = "強打" in keywords
		if has_power_strike_now and not had_power_strike_before:
			granted_skills.append("強打")
	
	return granted_skills

## 発動したスキルを取得
static func _get_triggered_skills(participant: BattleParticipant) -> Array:
	var skills = []
	
	# クリーチャーの基本スキルをチェック
	if participant.creature_data.has("ability_parsed"):
		var ability = participant.creature_data.ability_parsed
		var keywords = ability.get("keywords", [])
		
		# 先制攻撃
		if participant.has_first_strike or participant.has_item_first_strike:
			if "先制攻撃" not in skills:
				skills.append("先制攻撃")
		
		# 後手
		if participant.has_last_strike:
			if "後手" not in skills:
				skills.append("後手")
		
		# 強打
		if "強打" in keywords:
			skills.append("強打")
		
		# 魔法攻撃
		if "魔法攻撃" in keywords:
			skills.append("魔法攻撃")
		
		# 貫通
		if "貫通" in keywords:
			skills.append("貫通")
		
		# 再生
		if "再生" in keywords:
			skills.append("再生")
		
		# 飛行
		if "飛行" in keywords:
			skills.append("飛行")
		
		# その他のキーワード
		for keyword in keywords:
			if keyword not in skills and keyword not in ["先制攻撃", "後手", "強打", "魔法攻撃", "貫通", "再生", "飛行"]:
				skills.append(keyword)
	
	return skills

## 効果情報を取得（Phase 2追加）
static func _get_effect_info(participant: BattleParticipant) -> Dictionary:
	var info = {
		"base_up_hp": participant.base_up_hp,
		"base_up_ap": participant.base_up_ap,
		"temporary_bonus_hp": participant.temporary_bonus_hp,
		"temporary_bonus_ap": participant.temporary_bonus_ap,
		"permanent_effects": [],
		"temporary_effects": []
	}
	
	# permanent_effectsから効果名と値を抽出
	for effect in participant.permanent_effects:
		info["permanent_effects"].append({
			"source_name": effect.get("source_name", "不明"),
			"stat": effect.get("stat", ""),
			"value": effect.get("value", 0)
		})
	
	# temporary_effectsから効果名と値を抽出
	for effect in participant.temporary_effects:
		info["temporary_effects"].append({
			"source_name": effect.get("source_name", "不明"),
			"stat": effect.get("stat", ""),
			"value": effect.get("value", 0)
		})
	
	return info
