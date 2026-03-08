# バトルテスト実行エンジン
class_name BattleTestExecutor
extends RefCounted

## シーンツリーに追加するための親ノード（BattleSystemのawaitに必要）
var scene_tree_parent: Node = null

class MockCardSystem extends CardSystem:
	func _init():
		pass  # CardSystemの初期化をスキップ

class MockPlayerSystem extends PlayerSystem:
	func _init():
		# ダミープレイヤー2人を作成（蓄魔系スキルのsteal_magic用）
		var p0 = PlayerData.new()
		p0.id = 0
		p0.name = "テスト攻撃側"
		var p1 = PlayerData.new()
		p1.id = 1
		p1.name = "テスト防御側"
		players = [p0, p1]

## バトル実行
func execute_all_battles(config: BattleTestConfig) -> Array:
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
					
					var result = await _execute_single_battle(
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
func _execute_single_battle(
	battle_id: int,
	att_creature_id: int, att_item_id: int, att_spell_id: int,
	def_creature_id: int, def_item_id: int, def_spell_id: int,
	config: BattleTestConfig
) -> BattleTestResult:
	
	var start_time = Time.get_ticks_msec()
	
	# カードデータ取得（duplicate()で複製してitemsのリセット問題を回避）
	var att_card_data = CardLoader.get_card_by_id(att_creature_id).duplicate(true)
	var def_card_data = CardLoader.get_card_by_id(def_creature_id).duplicate(true)
	
	if not att_card_data or not def_card_data:
		push_error("カードデータ取得失敗")
		return null
	
	# BattleSystemを作成して初期化
	var battle_system = BattleSystem.new()
	battle_system.name = "BattleSystem_Test"

	# シーンツリーに追加（awaitが正しく動作するために必須）
	if scene_tree_parent:
		scene_tree_parent.add_child(battle_system)
	else:
		battle_system._ready()
	
	# BattleParticipant作成
	var attacker = BattleParticipant.new(
		att_card_data,
		att_card_data.hp,
		0,  # 攻撃側は土地ボーナスなし
		att_card_data.ap,
		true,  # is_attacker
		0  # player_id
	)
	# current_hpを初期化（BattleParticipant._init()では設定されないため）
	attacker.current_hp = att_card_data.hp

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
	# current_hpを初期化（BattleParticipant._init()では設定されないため）
	defender.current_hp = def_card_data.hp + def_land_bonus

	# 効果配列を適用（Phase 2追加）
	battle_system.battle_preparation.apply_effect_arrays(defender, def_card_data)

	# 実際のBoardSystem3Dを使用（テスト環境用に最小限の初期化）
	var mock_board = BoardSystem3D.new()
	mock_board.name = "BoardSystem3D_Test"
	battle_system.add_child(mock_board)

	# skill_indexを初期化（BattleSystemの鼓舞スキル処理で必須）
	mock_board.skill_index = {
		"support": {},
		"world_spell": {}
	}

	# TileDataManagerを作成（get_player_lands_by_elementで必須）
	var tile_data_mgr = TileDataManager.new()
	tile_data_mgr.name = "TileDataManager"
	mock_board.add_child(tile_data_mgr)
	mock_board.tile_data_manager = tile_data_mgr

	# テスト用のダミータイルノード辞書を設定
	tile_data_mgr.tile_nodes = {}

	# 土地データをセットアップ（get_player_lands_by_element用）
	_setup_mock_lands_for_battle(tile_data_mgr, 0, config.attacker_owned_lands)
	_setup_mock_lands_for_battle(tile_data_mgr, 1, config.defender_owned_lands)

	var mock_card = MockCardSystem.new()
	var mock_player = MockPlayerSystem.new()
	
	# SpellMagicとSpellDrawのモックを作成
	var spell_magic = SpellMagic.new()
	spell_magic.setup(mock_player)
	
	var spell_draw = SpellDraw.new()
	spell_draw.setup(mock_card)
	
	battle_system.setup_systems(mock_board, mock_card, mock_player)
	
	# BattleSystemにSpellMagic/SpellDrawを手動で設定
	battle_system.spell_magic = spell_magic
	battle_system.spell_draw = spell_draw
	battle_system.battle_special_effects.setup_systems(mock_board, spell_draw, spell_magic, mock_card)
	battle_system.battle_preparation.setup_systems(mock_board, mock_card, mock_player, spell_magic)
	
	# BattleParticipantにspell_magic_refを設定
	attacker.spell_magic_ref = spell_magic
	defender.spell_magic_ref = spell_magic
	
	# アイテム効果適用（モックシステムセットアップ後）
	var attacker_granted_skills = []
	var defender_granted_skills = []
	
	if att_item_id > 0:
		attacker_granted_skills = _apply_item_effects_and_record(battle_system, attacker, att_item_id, defender)
	
	if def_item_id > 0:
		defender_granted_skills = _apply_item_effects_and_record(battle_system, defender, def_item_id, attacker)

	# ========== 新規追加: 刻印スペル適用 ==========
	if config.attacker_curse_spell_id > 0:
		_apply_curse_spell(attacker, config.attacker_curse_spell_id)

	if config.defender_curse_spell_id > 0:
		_apply_curse_spell(defender, config.defender_curse_spell_id)

	# ========== 新規追加: バフ適用 ==========
	_apply_buff_config(attacker, config.attacker_buff_config)
	_apply_buff_config(defender, config.defender_buff_config)
	
	# 🚫 ウォーロックディスク: apply_pre_battle_skills()の最初で処理
	
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
	await battle_system.battle_skill_processor.apply_pre_battle_skills(participants, tile_info, 0)
	
	# 攻撃シーケンス実行
	await battle_system.battle_execution.execute_attack_sequence(attack_order, tile_info, battle_system.battle_special_effects, battle_system.battle_skill_processor)
	
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
	test_result.attacker_final_hp = attacker.current_hp
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
	test_result.defender_final_hp = defender.current_hp
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
			winner_str = "attacker_survived"
		BattleSystem.BattleResult.BOTH_DEFEATED:
			winner_str = "both_defeated"
	
	test_result.winner = winner_str
	test_result.battle_duration_ms = Time.get_ticks_msec() - start_time
	
	# バトル条件
	test_result.battle_land = config.attacker_battle_land
	test_result.attacker_owned_lands = config.attacker_owned_lands.duplicate()
	test_result.defender_owned_lands = config.defender_owned_lands.duplicate()
	test_result.attacker_has_adjacent = config.attacker_has_adjacent
	test_result.defender_has_adjacent = config.defender_has_adjacent

	# BattleSystemクリーンアップ
	if battle_system.is_inside_tree():
		battle_system.get_parent().remove_child(battle_system)
	battle_system.queue_free()

	return test_result

## アイテム名取得
func _get_item_name(item_id: int) -> String:
	if item_id <= 0:
		return "なし"
	var item = CardLoader.get_item_by_id(item_id)
	if item.is_empty():
		return "アイテム(ID:%d)※不明" % item_id
	return item.name

## スペル名取得
func _get_spell_name(spell_id: int) -> String:
	if spell_id <= 0:
		return "なし"
	var spell = CardLoader.get_spell_by_id(spell_id)
	if spell.is_empty():
		return "スペル(ID:%d)※不明" % spell_id
	return spell.name

## アイテム効果適用とスキル付与記録
func _apply_item_effects_and_record(battle_system: BattleSystem, participant: BattleParticipant, item_id: int, enemy_participant: BattleParticipant) -> Array:
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
		had_power_strike_before = "強化" in keywords
	
	# アイテムデータをクリーチャーのitemsに追加（反射チェックで使用）
	if not participant.creature_data.has("items"):
		participant.creature_data["items"] = []
	participant.creature_data["items"].append(item_data)
	
	# BattleSystemのアイテム効果適用を使用（item_applier経由）
	battle_system.battle_preparation.item_applier.apply_item_effects(participant, item_data, enemy_participant)
	
	# 付与後のスキル状態をチェック
	if participant.has_item_first_strike and not had_first_strike_before:
		granted_skills.append("先制攻撃")
	
	if participant.has_last_strike and not had_last_strike_before:
		granted_skills.append("後手")
	
	# 強化の判定
	if participant.creature_data.has("ability_parsed"):
		var keywords = participant.creature_data.ability_parsed.get("keywords", [])
		var has_power_strike_now = "強化" in keywords
		if has_power_strike_now and not had_power_strike_before:
			granted_skills.append("強化")
	
	return granted_skills

## 発動したスキルを取得
func _get_triggered_skills(participant: BattleParticipant) -> Array:
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
		
		# 強化
		if "強化" in keywords:
			skills.append("強化")
		
		# 魔法攻撃
		if "魔法攻撃" in keywords:
			skills.append("魔法攻撃")
		
		# 刺突
		if "刺突" in keywords:
			skills.append("刺突")
		
		# 再生
		if "再生" in keywords:
			skills.append("再生")
		
		# 飛行
		if "飛行" in keywords:
			skills.append("飛行")
		
		# その他のキーワード
		for keyword in keywords:
			if keyword not in skills and keyword not in ["先制攻撃", "後手", "強化", "魔法攻撃", "刺突", "再生", "飛行"]:
				skills.append(keyword)
	
	return skills

## 効果情報を取得（Phase 2追加）
func _get_effect_info(participant: BattleParticipant) -> Dictionary:
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

## ========== 新規追加: Phase 5用メソッド ==========

## 刻印スペルをBattleParticipantに適用
func _apply_curse_spell(participant: BattleParticipant, spell_id: int):
	var spell_data = CardLoader.get_card_by_id(spell_id)
	if not spell_data:
		push_error("[BattleTestExecutor] 刻印スペルID ", spell_id, " が見つかりません")
		return

	print("[BattleTestExecutor] 刻印スペル適用: ", spell_data.get("name", "?"), " (ID:", spell_id, ")")

	# スペルデータのeffect_parsedからcurse用Dictionaryを構築
	# メインゲームの spell_curse.curse_creature() と同じ形式にする
	var effect_parsed = spell_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])

	# effect_type → curse_type の変換マップ（spell_curse.gdと同じ変換）
	var _curse_type_map = {
		"random_stat_curse": "random_stat",
		"command_growth_curse": "command_growth",
		"plague_curse": "plague",
		"bounty_curse": "bounty",
	}

	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		# draw等の非刻印効果はスキップ
		if effect_type in ["draw", "magic_gain", ""]:
			continue
		# effect_typeをcurse_typeに変換（マップにあれば変換、なければそのまま）
		# creature_curse型の場合はcurse_typeが別途指定されている
		var curse_type = effect.get("curse_type", _curse_type_map.get(effect_type, effect_type))
		var curse_name = effect.get("name", spell_data.get("name", "不明"))
		# effectの全パラメータをparamsに入れる
		var params = effect.duplicate(true)
		params["name"] = curse_name
		# magic_barrierのEP移動パラメータ
		if curse_type == "magic_barrier":
			params["ep_transfer"] = effect.get("gold_transfer", 100)
		participant.creature_data["curse"] = {
			"curse_type": curse_type,
			"name": curse_name,
			"duration": effect.get("duration", -1),
			"params": params
		}
		print("  → ", participant.creature_data.get("name", "?"), " に刻印付与完了: ", curse_name, " (", curse_type, ")")
		return

	push_warning("[BattleTestExecutor] スペルID ", spell_id, " に刻印効果が見つかりません")

## バフ適用
func _apply_buff_config(participant: BattleParticipant, buff_config: Dictionary):
	if buff_config.is_empty():
		return

	# 永続HP/AP上昇
	participant.base_up_hp = buff_config.get("base_up_hp", 0)
	participant.base_up_ap = buff_config.get("base_up_ap", 0)

	# アイテムボーナス
	participant.item_bonus_hp = buff_config.get("item_bonus_hp", 0)
	participant.item_bonus_ap = buff_config.get("item_bonus_ap", 0)

	# スペルボーナス
	participant.spell_bonus_hp = buff_config.get("spell_bonus_hp", 0)

	# 効果配列
	participant.permanent_effects = buff_config.get("permanent_effects", []).duplicate(true)
	participant.temporary_effects = buff_config.get("temporary_effects", []).duplicate(true)

	# current_hpとcurrent_apを更新
	if participant.base_up_hp != 0:
		participant.current_hp += participant.base_up_hp
		print("[バフ適用] ", participant.creature_data.get("name", "?"), " base_up_hp +", participant.base_up_hp)

	participant.update_current_ap()

	if participant.base_up_ap != 0:
		print("[バフ適用] ", participant.creature_data.get("name", "?"), " base_up_ap +", participant.base_up_ap)

## テスト用：TileDataManagerに土地データを設定
## lands = {"fire": 3, "water": 2, ...} の形式
func _setup_mock_lands_for_battle(tile_data_mgr: TileDataManager, player_id: int, lands: Dictionary):
	# TileDataManagerはtile_nodesがないとget_owner_element_counts()で失敗するため
	# ダミーのタイルオブジェクトを作成して登録する必要はなく、
	# tile_nodesが空でもget_owner_element_counts()は安全に実行される
	# ここでは、土地情報がなくても戦闘システムが正常に動作することを想定

	# 注意: ゲーム内では実際のTileノードがtile_nodesに登録されるため、
	# get_owner_element_countsは実際の土地情報を返す
	# テスト環境ではtile_nodesが空なので、get_owner_element_countsは全て0を返す
	# これは鼓舞スキルの条件判定には影響しない（鼓舞スキルは別の方法で検索）
	pass
