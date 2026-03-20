# バトルテスト実行エンジン
class_name BattleTestExecutor
extends RefCounted

## シーンツリーに追加するための親ノード（BattleSystemのawaitに必要）
var scene_tree_parent: Node = null

class MockCardSystem extends CardSystem:
	func _init():
		# ダミープレイヤー2人分のデッキ・手札を作成（ドロー系スキル用）
		for pid in [0, 1]:
			player_decks[pid] = []
			player_discards[pid] = []
			player_hands[pid] = {"data": []}

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

class MockTile extends RefCounted:
	var owner_id: int = -1
	var tile_type: String = "neutral"
	var level: int = 1
	var creature_data: Dictionary = {}
	var tile_index: int = 0
	var global_position: Vector3 = Vector3.ZERO
	var connections = []

	func set_level(new_level: int):
		level = new_level

	func level_up() -> bool:
		if level < 5:
			level += 1
			return true
		return false

## ダイアモンドボード（20タイル）のデフォルト属性
const DEFAULT_TILE_TYPES = [
	"checkpoint", "fire", "fire", "fire", "fire", "neutral",
	"water", "water", "water", "water", "checkpoint",
	"wind", "wind", "wind", "wind", "neutral",
	"earth", "earth", "earth", "earth"
]

## ダイアモンドボード（20タイル）の座標（XZ平面、距離4.0）
static var TILE_POSITIONS = [
	Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(8, 0, 0), Vector3(12, 0, 0), Vector3(16, 0, 0),
	Vector3(20, 0, 0), Vector3(20, 0, 4), Vector3(20, 0, 8), Vector3(20, 0, 12), Vector3(20, 0, 16),
	Vector3(20, 0, 20), Vector3(16, 0, 20), Vector3(12, 0, 20), Vector3(8, 0, 20), Vector3(4, 0, 20),
	Vector3(0, 0, 20), Vector3(0, 0, 16), Vector3(0, 0, 12), Vector3(0, 0, 8), Vector3(0, 0, 4)
]

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
## 実ゲームのフロー: prepare_participants → apply_pre_battle_skills → determine_attack_order → execute
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

	# ========== creature_dataへの事前反映 ==========
	# 実ゲームでは base_up_hp/ap, effect配列, curse は
	# creature_data に保持された状態で prepare_participants に渡される
	apply_buff_to_creature_data(att_card_data, config.attacker_buff_config)
	apply_buff_to_creature_data(def_card_data, config.defender_buff_config)

	if config.attacker_curse_spell_id > 0:
		set_curse_on_creature_data(att_card_data, config.attacker_curse_spell_id)
	if config.defender_curse_spell_id > 0:
		set_curse_on_creature_data(def_card_data, config.defender_curse_spell_id)

	# ========== BattleSystem作成 ==========
	var battle_system = BattleSystem.new()
	battle_system.name = "BattleSystem_Test"

	if scene_tree_parent:
		scene_tree_parent.add_child(battle_system)
	else:
		battle_system._ready()

	# ========== BattleParticipant作成（prepare_participantsと同じフロー） ==========

	# 攻撃側
	var attacker = BattleParticipant.new(
		att_card_data,
		att_card_data.hp,
		0,  # 攻撃側は土地ボーナスなし
		att_card_data.ap,
		true,  # is_attacker
		0  # player_id
	)
	attacker.base_up_hp = att_card_data.get("base_up_hp", 0)
	attacker.base_up_ap = att_card_data.get("base_up_ap", 0)
	var att_max_hp = att_card_data.get("hp", 0) + attacker.base_up_hp
	attacker.current_hp = att_card_data.get("current_hp", att_max_hp)

	# 防御側（土地ボーナスあり）
	# ダミータイル情報を先に作成（土地ボーナス計算に必要）
	var _battle_tile_idx = config.battle_tile_index if config.battle_tile_index >= 0 else 0
	var tile_info = {
		"element": config.defender_battle_land,
		"level": config.defender_battle_land_level,
		"index": _battle_tile_idx,
		"owner": 1,
		"creature": def_card_data
	}
	# 実ゲームと同じcalculate_land_bonus相当の計算
	var def_land_bonus = 0
	if SpellCurseBattle.can_get_land_bonus(def_card_data, config.defender_battle_land):
		def_land_bonus = config.defender_battle_land_level * 10

	var defender = BattleParticipant.new(
		def_card_data,
		def_card_data.hp,
		def_land_bonus,
		def_card_data.ap,
		false,  # is_attacker
		1  # player_id
	)
	defender.base_up_hp = def_card_data.get("base_up_hp", 0)
	defender.base_up_ap = def_card_data.get("base_up_ap", 0)
	var def_max_hp = def_card_data.get("hp", 0) + defender.base_up_hp
	defender.current_hp = def_card_data.get("current_hp", def_max_hp)

	# 効果配列を適用（prepare_participantsと同じタイミング）
	battle_system.battle_preparation.apply_effect_arrays(attacker, att_card_data)
	battle_system.battle_preparation.apply_effect_arrays(defender, def_card_data)

	# ========== アイテムをcreature_data["items"]にセット（効果は適用しない） ==========
	# 実ゲームのprepare_participants: items配列に追加するだけ
	# 効果適用は apply_pre_battle_skills() Phase 0-S で行われる
	attacker.creature_data["items"] = []
	defender.creature_data["items"] = []

	if att_item_id > 0:
		var att_item_data = CardLoader.get_card_by_id(att_item_id)
		if att_item_data:
			attacker.creature_data["items"].append(att_item_data)

	if def_item_id > 0:
		var def_item_data = CardLoader.get_card_by_id(def_item_id)
		if def_item_data:
			defender.creature_data["items"].append(def_item_data)

	# ========== モックシステムセットアップ ==========
	var mock_board = BoardSystem3D.new()
	mock_board.name = "BoardSystem3D_Test"
	battle_system.add_child(mock_board)

	mock_board.skill_index = {
		"support": {},
		"world_spell": {}
	}

	var tile_data_mgr = TileDataManager.new()
	tile_data_mgr.name = "TileDataManager"
	mock_board.add_child(tile_data_mgr)
	mock_board.tile_data_manager = tile_data_mgr
	tile_data_mgr.tile_nodes = {}

	# board_layout優先 → 旧形式にフォールバック
	if not config.board_layout.is_empty():
		_setup_mock_board(tile_data_mgr, mock_board, config)
	else:
		if not config.attacker_board_tiles.is_empty():
			_setup_mock_board_tiles(tile_data_mgr, 0, config.attacker_board_tiles)
		else:
			_setup_mock_lands_for_battle(tile_data_mgr, 0, config.attacker_owned_lands)
		if not config.defender_board_tiles.is_empty():
			_setup_mock_board_tiles(tile_data_mgr, 1, config.defender_board_tiles)
		else:
			_setup_mock_lands_for_battle(tile_data_mgr, 1, config.defender_owned_lands)

	var mock_card = MockCardSystem.new()
	var mock_player = MockPlayerSystem.new()

	var spell_magic = SpellMagic.new()
	spell_magic.setup(mock_player)

	var spell_draw = SpellDraw.new()
	spell_draw.setup(mock_card)

	battle_system.setup_systems(mock_board, mock_card, mock_player)

	battle_system.spell_magic = spell_magic
	battle_system.spell_draw = spell_draw
	battle_system.battle_special_effects.setup_systems(mock_board, spell_draw, spell_magic, mock_card)
	battle_system.battle_preparation.setup_systems(mock_board, mock_card, mock_player, spell_magic)

	attacker.spell_magic_ref = spell_magic
	defender.spell_magic_ref = spell_magic

	# ========== スキル状態スナップショット（pre-battle前） ==========
	var att_skills_before = _snapshot_skill_state(attacker)
	var def_skills_before = _snapshot_skill_state(defender)

	# ========== apply_pre_battle_skills（実ゲームと同一のPhase処理） ==========
	# Phase 0-C: 刻印適用（creature_data["curse"]から）
	# Phase 0-N: 沈黙チェック（ウォーロックディスク等）
	# Phase 0-D: アイテム破壊・盗み
	# Phase 0-T: 変身スキル
	# Phase 0-S: アイテム効果適用（残ったアイテムのstat_bonus + スキル付与）
	# Phase 0-T2: アイテムによる変身
	# Phase 0-A: ブルガサリ、ランダムステータス、戦闘開始時条件
	# Phase 1: 鼓舞スキル
	# Phase 2: 共鳴・強化等の各スキル
	# Phase 3: 刺突・術攻撃
	var participants = {
		"attacker": attacker,
		"defender": defender,
		"attacker_used_item": att_item_id > 0,
		"defender_used_item": def_item_id > 0
	}
	await battle_system.battle_skill_processor.apply_pre_battle_skills(participants, tile_info, 0)

	# ========== 追加バフ適用（スペルボーナス等、外部効果のシミュレーション用） ==========
	_apply_extra_buff(attacker, config.attacker_buff_config)
	_apply_extra_buff(defender, config.defender_buff_config)

	# ========== スキル付与記録（pre-battle後） ==========
	var attacker_granted_skills = _diff_skill_state(att_skills_before, attacker)
	var defender_granted_skills = _diff_skill_state(def_skills_before, defender)

	# ========== 攻撃順を決定（pre-battle後 = アイテムによる先制付与が反映済み） ==========
	var attack_order = battle_system.battle_execution.determine_attack_order(attacker, defender)

	# 攻撃シーケンス実行
	await battle_system.battle_execution.execute_attack_sequence(attack_order, tile_info, battle_system.battle_special_effects, battle_system.battle_skill_processor)

	# 結果判定
	var battle_result = battle_system.battle_execution.resolve_battle_result(attacker, defender)

	# ========== 結果を記録 ==========
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

# ==========================================================================
# ヘルパーメソッド
# ==========================================================================

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

## 発動したスキルを取得
func _get_triggered_skills(participant: BattleParticipant) -> Array:
	var skills: Array = []

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

## 効果情報を取得
func _get_effect_info(participant: BattleParticipant) -> Dictionary:
	var info = {
		"base_up_hp": participant.base_up_hp,
		"base_up_ap": participant.base_up_ap,
		"temporary_bonus_hp": participant.temporary_bonus_hp,
		"temporary_bonus_ap": participant.temporary_bonus_ap,
		"permanent_effects": [],
		"temporary_effects": []
	}

	for effect in participant.permanent_effects:
		info["permanent_effects"].append({
			"source_name": effect.get("source_name", "不明"),
			"stat": effect.get("stat", ""),
			"value": effect.get("value", 0)
		})

	for effect in participant.temporary_effects:
		info["temporary_effects"].append({
			"source_name": effect.get("source_name", "不明"),
			"stat": effect.get("stat", ""),
			"value": effect.get("value", 0)
		})

	return info

# ==========================================================================
# creature_data事前反映メソッド（BattleParticipant作成前に呼ぶ）
# ==========================================================================

## バフ設定をcreature_dataに反映
## 実ゲームでは base_up_hp/ap, permanent/temporary_effects は
## creature_data に保持された状態で prepare_participants に渡される
func apply_buff_to_creature_data(card_data: Dictionary, buff_config: Dictionary) -> void:
	if buff_config.is_empty():
		return

	if buff_config.get("base_up_hp", 0) != 0:
		card_data["base_up_hp"] = buff_config.get("base_up_hp", 0)
		print("[バフ→creature_data] ", card_data.get("name", "?"), " base_up_hp=", card_data["base_up_hp"])

	if buff_config.get("base_up_ap", 0) != 0:
		card_data["base_up_ap"] = buff_config.get("base_up_ap", 0)
		print("[バフ→creature_data] ", card_data.get("name", "?"), " base_up_ap=", card_data["base_up_ap"])

	# effect配列をcreature_dataに設定（apply_effect_arraysが読む）
	var perm = buff_config.get("permanent_effects", [])
	if not perm.is_empty():
		card_data["permanent_effects"] = perm.duplicate(true)

	var temp = buff_config.get("temporary_effects", [])
	if not temp.is_empty():
		card_data["temporary_effects"] = temp.duplicate(true)

## 刻印スペルをcreature_dataに設定
## Phase 0-Cの curse_applier.apply_creature_curses() がcreature_data["curse"]を読み取る
func set_curse_on_creature_data(card_data: Dictionary, spell_id: int) -> void:
	var spell_data = CardLoader.get_card_by_id(spell_id)
	if not spell_data:
		push_error("[BattleTestExecutor] 刻印スペルID ", spell_id, " が見つかりません")
		return

	print("[BattleTestExecutor] 刻印スペル設定: ", spell_data.get("name", "?"), " (ID:", spell_id, ")")

	var effect_parsed = spell_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])

	# effect_type → curse_type の変換マップ（spell_curse.gdと同じ変換）
	var curse_type_map = {
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
		var curse_type = effect.get("curse_type", curse_type_map.get(effect_type, effect_type))
		var curse_name = effect.get("name", spell_data.get("name", "不明"))
		var params = effect.duplicate(true)
		params["name"] = curse_name
		if curse_type == "magic_barrier":
			params["ep_transfer"] = effect.get("gold_transfer", 100)
		card_data["curse"] = {
			"curse_type": curse_type,
			"name": curse_name,
			"duration": effect.get("duration", -1),
			"params": params
		}
		print("  -> ", card_data.get("name", "?"), " に刻印設定: ", curse_name, " (", curse_type, ")")
		return

	push_warning("[BattleTestExecutor] スペルID ", spell_id, " に刻印効果が見つかりません")

## 追加バフ適用（apply_pre_battle_skills後に呼ぶ）
## spell_bonus_hp など、アイテムや刻印以外の外部効果をシミュレーションする
func _apply_extra_buff(participant: BattleParticipant, buff_config: Dictionary) -> void:
	if buff_config.is_empty():
		return

	var spell_hp = buff_config.get("spell_bonus_hp", 0)
	if spell_hp != 0:
		participant.spell_bonus_hp += spell_hp
		print("[追加バフ] ", participant.creature_data.get("name", "?"), " spell_bonus_hp +", spell_hp)

# ==========================================================================
# スキル状態スナップショット（pre-battle前後の比較用）
# ==========================================================================

## スキル状態のスナップショットを取得
func _snapshot_skill_state(participant: BattleParticipant) -> Dictionary:
	var keywords: Array = []
	if participant.creature_data.has("ability_parsed"):
		keywords = participant.creature_data.ability_parsed.get("keywords", []).duplicate()
	return {
		"has_first_strike": participant.has_first_strike,
		"has_item_first_strike": participant.has_item_first_strike,
		"has_last_strike": participant.has_last_strike,
		"keywords": keywords
	}

## スキル状態の差分からアイテム/スキルによって付与されたスキルを抽出
func _diff_skill_state(before: Dictionary, participant: BattleParticipant) -> Array:
	var granted: Array = []

	if participant.has_item_first_strike and not before.get("has_item_first_strike", false):
		granted.append("先制攻撃")

	if participant.has_last_strike and not before.get("has_last_strike", false):
		granted.append("後手")

	# 新しく追加されたキーワードを検出
	var before_keywords = before.get("keywords", [])
	if participant.creature_data.has("ability_parsed"):
		var current_keywords = participant.creature_data.ability_parsed.get("keywords", [])
		for keyword in current_keywords:
			if keyword not in before_keywords and keyword not in granted:
				granted.append(keyword)

	return granted

## テスト用：board_layoutから20タイルのダイアモンドボードを再現
func _setup_mock_board(tile_data_mgr: TileDataManager, mock_board: BoardSystem3D, config: BattleTestConfig):
	# 1. 20タイルをデフォルト属性・座標で作成
	for i in range(20):
		var mock_tile = MockTile.new()
		mock_tile.tile_index = i
		mock_tile.tile_type = DEFAULT_TILE_TYPES[i]
		mock_tile.global_position = TILE_POSITIONS[i]
		# サイクルグラフ: index±1 (mod 20)
		mock_tile.connections = [((i - 1) + 20) % 20, (i + 1) % 20]
		tile_data_mgr.tile_nodes[i] = mock_tile

	# 2. board_layoutでオーバーライド
	for entry in config.board_layout:
		var idx = entry.get("tile_index", -1)
		if idx < 0 or idx >= 20:
			continue
		var tile = tile_data_mgr.tile_nodes[idx]
		tile.owner_id = entry.get("owner_id", -1)
		tile.level = entry.get("level", 1)
		var creature_id = entry.get("creature_id", -1)
		if creature_id >= 0:
			var card_data = CardLoader.get_card_by_id(creature_id)
			if card_data:
				tile.creature_data = card_data.duplicate(true)

	# 3. TileNeighborSystemを作成して隣接キャッシュを構築
	var neighbor_system = TileNeighborSystem.new()
	neighbor_system.name = "TileNeighborSystem"
	mock_board.add_child(neighbor_system)
	neighbor_system.setup(tile_data_mgr.tile_nodes)
	mock_board.tile_neighbor_system = neighbor_system

## テスト用：board_tilesからTileDataManagerにタイル配置を設定
## board_tiles = [{"tile_element": "fire", "creature_id": 48}, ...] の形式
func _setup_mock_board_tiles(tile_data_mgr: TileDataManager, player_id: int, board_tiles: Array):
	var index_offset = player_id * 10
	for i in range(board_tiles.size()):
		var entry = board_tiles[i]
		var mock_tile = MockTile.new()
		mock_tile.owner_id = player_id
		mock_tile.tile_type = entry.get("tile_element", "neutral")
		var creature_id = entry.get("creature_id", -1)
		if creature_id >= 0:
			var card_data = CardLoader.get_card_by_id(creature_id)
			if card_data:
				mock_tile.creature_data = card_data.duplicate(true)
			else:
				mock_tile.creature_data = {"element": mock_tile.tile_type, "name": "unknown"}
		tile_data_mgr.tile_nodes[index_offset + i] = mock_tile

## テスト用：owned_landsからTileDataManagerにタイル配置を設定（後方互換）
## lands = {"fire": 3, "water": 2, ...} の形式
func _setup_mock_lands_for_battle(tile_data_mgr: TileDataManager, player_id: int, lands: Dictionary):
	var index_offset = player_id * 10
	var idx = index_offset
	for element in lands:
		for i in range(lands[element]):
			var mock_tile = MockTile.new()
			mock_tile.owner_id = player_id
			mock_tile.tile_type = element
			mock_tile.creature_data = {"element": element, "name": "mock_%s" % element}
			tile_data_mgr.tile_nodes[idx] = mock_tile
			idx += 1
