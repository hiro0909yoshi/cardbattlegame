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
	
	# BattleParticipant作成
	var attacker = BattleParticipant.new(
		att_card_data,
		att_card_data.hp,
		0,  # 攻撃側は土地ボーナスなし
		att_card_data.ap,
		true,  # is_attacker
		0  # player_id
	)
	
	# 防御側の土地ボーナス計算（仮のタイル情報）
	var def_land_bonus = 0
	var tile_element = config.defender_battle_land
	if att_card_data.element == tile_element:
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
	
	# TODO: アイテム効果適用
	
	# BattleSystemを使用してバトル実行
	var battle_system = BattleSystem.new()
	
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
		"level": 1,
		"index": 0,
		"owner": 1,
		"creature": def_card_data
	}
	
	# 攻撃順を決定
	var attack_order = battle_system._determine_attack_order(attacker, defender)
	
	# スキル適用
	var participants = {"attacker": attacker, "defender": defender}
	battle_system._apply_pre_battle_skills(participants, tile_info, 0)
	
	# 攻撃シーケンス実行
	battle_system._execute_attack_sequence(attack_order)
	
	# 結果判定
	var battle_result = battle_system._resolve_battle_result(attacker, defender)
	
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
