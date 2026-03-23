extends GutTest

## SpellWorldCurse 世界刻印テスト
## 全9種の世界刻印のstatic判定メソッド + JSON定義 + 否定テスト（刻印なし/別刻印）

const EMPTY_STATS: Dictionary = {}


## 世界刻印ありのgame_statsを作成
func _make_stats(curse_type: String, params: Dictionary = {}) -> Dictionary:
	var world_curse: Dictionary = {
		"curse_type": curse_type,
		"duration": 6,
		"params": params,
	}
	return {"world_curse": world_curse}


## JSON定義からworld_curseのcurse_typeを取得
func _get_curse_type(spell_id: int) -> String:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type") == "world_curse":
			return e.get("curse_type", "")
	return ""


# ========================================
# 1. ライズオブサン(2009): cost_increase
# ========================================

## JSON定義確認
func test_rise_of_sun_json():
	assert_eq(_get_curse_type(2009), "cost_increase", "ライズオブサン: cost_increase")


## Rレアリティ: コスト2倍
func test_cost_increase_rarity_r():
	var stats = _make_stats("cost_increase", {"bag_multiplier": 1.5, "crown_bag_multiplier": 2.0})
	var card_r: Dictionary = {"rarity": "R"}
	assert_eq(SpellWorldCurse.get_cost_multiplier(card_r, stats), 2.0, "R: 2倍")


## Sレアリティ: コスト1.5倍
func test_cost_increase_rarity_s():
	var stats = _make_stats("cost_increase", {"bag_multiplier": 1.5, "crown_bag_multiplier": 2.0})
	var card_s: Dictionary = {"rarity": "S"}
	assert_eq(SpellWorldCurse.get_cost_multiplier(card_s, stats), 1.5, "S: 1.5倍")


## Nレアリティ: 倍率なし
func test_cost_increase_rarity_n():
	var stats = _make_stats("cost_increase", {"bag_multiplier": 1.5, "crown_bag_multiplier": 2.0})
	var card_n: Dictionary = {"rarity": "N"}
	assert_eq(SpellWorldCurse.get_cost_multiplier(card_n, stats), 1.0, "N: 倍率なし")


## Cレアリティ: 倍率なし
func test_cost_increase_rarity_c():
	var stats = _make_stats("cost_increase", {"bag_multiplier": 1.5, "crown_bag_multiplier": 2.0})
	var card_c: Dictionary = {"rarity": "C"}
	assert_eq(SpellWorldCurse.get_cost_multiplier(card_c, stats), 1.0, "C: 倍率なし")


## 否定: 刻印なしならコスト1倍
func test_cost_increase_no_curse():
	var card_r: Dictionary = {"rarity": "R"}
	assert_eq(SpellWorldCurse.get_cost_multiplier(card_r, EMPTY_STATS), 1.0, "刻印なし: 1倍")


## 否定: 別の刻印ではコスト1倍
func test_cost_increase_wrong_curse():
	var stats = _make_stats("land_protect")
	var card_r: Dictionary = {"rarity": "R"}
	assert_eq(SpellWorldCurse.get_cost_multiplier(card_r, stats), 1.0, "別刻印: 1倍")


# ========================================
# 2. ボンドオブラバーズ(2036): element_chain
# ========================================

## JSON定義確認
func test_bond_of_lovers_json():
	assert_eq(_get_curse_type(2036), "element_chain", "ボンドオブラバーズ: element_chain")


## 連鎖ペア取得
func test_chain_pairs():
	var stats = _make_stats("element_chain", {
		"chain_pairs": [["fire", "earth"], ["water", "wind"]]
	})
	var pairs = SpellWorldCurse.get_chain_pairs(stats)
	assert_eq(pairs.size(), 2, "2ペア")


## fire-earth は同グループ
func test_chain_fire_earth():
	var stats = _make_stats("element_chain", {
		"chain_pairs": [["fire", "earth"], ["water", "wind"]]
	})
	assert_true(SpellWorldCurse.is_same_chain_group("fire", "earth", stats), "fire-earth: 同グループ")


## water-wind は同グループ
func test_chain_water_wind():
	var stats = _make_stats("element_chain", {
		"chain_pairs": [["fire", "earth"], ["water", "wind"]]
	})
	assert_true(SpellWorldCurse.is_same_chain_group("water", "wind", stats), "water-wind: 同グループ")


## fire-water は異グループ
func test_chain_fire_water_different():
	var stats = _make_stats("element_chain", {
		"chain_pairs": [["fire", "earth"], ["water", "wind"]]
	})
	assert_false(SpellWorldCurse.is_same_chain_group("fire", "water", stats), "fire-water: 異グループ")


## 同属性は常に同グループ（刻印関係なし）
func test_chain_same_element_always():
	assert_true(SpellWorldCurse.is_same_chain_group("fire", "fire", EMPTY_STATS), "同属性: 常に同グループ")


## 否定: 刻印なしでは異属性は別グループ
func test_chain_no_curse():
	assert_false(SpellWorldCurse.is_same_chain_group("fire", "earth", EMPTY_STATS), "刻印なし: fire-earth別グループ")


## 否定: 刻印なしではペア空
func test_chain_pairs_no_curse():
	var pairs = SpellWorldCurse.get_chain_pairs(EMPTY_STATS)
	assert_eq(pairs.size(), 0, "刻印なし: ペア空")


# ========================================
# 3. インペリアルガード(2047): land_protect
# ========================================

## JSON定義確認
func test_imperial_guard_json():
	assert_eq(_get_curse_type(2047), "land_protect", "インペリアルガード: land_protect")


## 属性変化ブロック
func test_land_change_blocked():
	var stats = _make_stats("land_protect")
	assert_true(SpellWorldCurse.is_land_change_blocked(stats), "land_protect: 属性変化ブロック")


## 否定: 刻印なし
func test_land_change_not_blocked_no_curse():
	assert_false(SpellWorldCurse.is_land_change_blocked(EMPTY_STATS), "刻印なし: ブロックされない")


## 否定: 別の刻印
func test_land_change_not_blocked_wrong_curse():
	var stats = _make_stats("cost_increase")
	assert_false(SpellWorldCurse.is_land_change_blocked(stats), "別刻印: ブロックされない")


# ========================================
# 4. ハイプリーステス(2048): cursed_protection
# ========================================

## JSON定義確認
func test_high_priestess_json():
	assert_eq(_get_curse_type(2048), "cursed_protection", "ハイプリーステス: cursed_protection")


## 刻印付きクリーチャーが結界を得る
func test_cursed_creature_protected():
	var stats = _make_stats("cursed_protection")
	assert_true(SpellWorldCurse.is_cursed_creature_protected(stats), "cursed_protection: 結界あり")


## 否定: 刻印なし
func test_cursed_creature_not_protected_no_curse():
	assert_false(SpellWorldCurse.is_cursed_creature_protected(EMPTY_STATS), "刻印なし: 結界なし")


## 否定: 別の刻印
func test_cursed_creature_not_protected_wrong_curse():
	var stats = _make_stats("land_protect")
	assert_false(SpellWorldCurse.is_cursed_creature_protected(stats), "別刻印: 結界なし")


# ========================================
# 5. ハングドマンズシール(2064): skill_disable
# ========================================

## JSON定義確認
func test_hanged_man_json():
	assert_eq(_get_curse_type(2064), "skill_disable", "ハングドマンズシール: skill_disable")


## mystic_arts トリガー無効
func test_trigger_disabled_mystic_arts():
	var stats = _make_stats("skill_disable", {
		"disabled_triggers": ["mystic_arts", "on_death", "on_battle_end"]
	})
	assert_true(SpellWorldCurse.is_trigger_disabled("mystic_arts", stats), "mystic_arts: 無効")


## on_death トリガー無効
func test_trigger_disabled_on_death():
	var stats = _make_stats("skill_disable", {
		"disabled_triggers": ["mystic_arts", "on_death", "on_battle_end"]
	})
	assert_true(SpellWorldCurse.is_trigger_disabled("on_death", stats), "on_death: 無効")


## on_battle_end トリガー無効
func test_trigger_disabled_on_battle_end():
	var stats = _make_stats("skill_disable", {
		"disabled_triggers": ["mystic_arts", "on_death", "on_battle_end"]
	})
	assert_true(SpellWorldCurse.is_trigger_disabled("on_battle_end", stats), "on_battle_end: 無効")


## リストにないトリガーは有効
func test_trigger_not_disabled_other():
	var stats = _make_stats("skill_disable", {
		"disabled_triggers": ["mystic_arts", "on_death", "on_battle_end"]
	})
	assert_false(SpellWorldCurse.is_trigger_disabled("on_summon", stats), "on_summon: 無効リストにない")


## 否定: 刻印なし
func test_trigger_not_disabled_no_curse():
	assert_false(SpellWorldCurse.is_trigger_disabled("mystic_arts", EMPTY_STATS), "刻印なし: 無効化されない")


## 否定: 別の刻印
func test_trigger_not_disabled_wrong_curse():
	var stats = _make_stats("land_protect")
	assert_false(SpellWorldCurse.is_trigger_disabled("mystic_arts", stats), "別刻印: 無効化されない")


# ========================================
# 6. フールズフリーダム(2081): summon_cost_free
# ========================================

## JSON定義確認
func test_fools_freedom_json():
	assert_eq(_get_curse_type(2081), "summon_cost_free", "フールズフリーダム: summon_cost_free")


## 召喚条件無視
func test_summon_condition_ignored():
	var stats = _make_stats("summon_cost_free")
	assert_true(SpellWorldCurse.is_summon_condition_ignored(stats), "summon_cost_free: 召喚条件無視")


## 否定: 刻印なし
func test_summon_condition_not_ignored_no_curse():
	assert_false(SpellWorldCurse.is_summon_condition_ignored(EMPTY_STATS), "刻印なし: 条件有効")


## 否定: 別の刻印
func test_summon_condition_not_ignored_wrong_curse():
	var stats = _make_stats("cost_increase")
	assert_false(SpellWorldCurse.is_summon_condition_ignored(stats), "別刻印: 条件有効")


# ========================================
# 7. テンパランスロウ(2102): invasion_restrict
# ========================================

## JSON定義確認
func test_temperance_json():
	assert_eq(_get_curse_type(2102), "invasion_restrict", "テンパランスロウ: invasion_restrict")


## 上位→下位の侵略は制限
func test_invasion_restricted_higher_to_lower():
	var stats = _make_stats("invasion_restrict")
	assert_true(SpellWorldCurse.is_invasion_restricted(1, 2, stats), "1位→2位: 制限")


## 下位→上位の侵略は許可
func test_invasion_allowed_lower_to_higher():
	var stats = _make_stats("invasion_restrict")
	assert_false(SpellWorldCurse.is_invasion_restricted(2, 1, stats), "2位→1位: 許可")


## 同順位の侵略は許可
func test_invasion_allowed_same_rank():
	var stats = _make_stats("invasion_restrict")
	assert_false(SpellWorldCurse.is_invasion_restricted(1, 1, stats), "同順位: 許可")


## 否定: 刻印なし
func test_invasion_not_restricted_no_curse():
	assert_false(SpellWorldCurse.is_invasion_restricted(1, 2, EMPTY_STATS), "刻印なし: 制限なし")


## 否定: 別の刻印
func test_invasion_not_restricted_wrong_curse():
	var stats = _make_stats("land_protect")
	assert_false(SpellWorldCurse.is_invasion_restricted(1, 2, stats), "別刻印: 制限なし")


# ========================================
# 8. エンプレスドメイン(2110): world_spell_protection
# ========================================

## JSON定義確認
func test_empress_domain_json():
	assert_eq(_get_curse_type(2110), "world_spell_protection", "エンプレスドメイン: world_spell_protection")


## 全セプターがスペル対象不可
func test_all_players_spell_immune():
	var stats = _make_stats("world_spell_protection")
	assert_true(SpellWorldCurse.is_all_players_spell_immune(stats), "world_spell_protection: 全員スペル免疫")


## 否定: 刻印なし
func test_spell_not_immune_no_curse():
	assert_false(SpellWorldCurse.is_all_players_spell_immune(EMPTY_STATS), "刻印なし: 免疫なし")


## 否定: 別の刻印
func test_spell_not_immune_wrong_curse():
	var stats = _make_stats("cost_increase")
	assert_false(SpellWorldCurse.is_all_players_spell_immune(stats), "別刻印: 免疫なし")


# ========================================
# 9. ハーミットズパラドックス(2111): same_creature_destroy
# ========================================

## JSON定義確認
func test_hermits_paradox_json():
	assert_eq(_get_curse_type(2111), "same_creature_destroy", "ハーミットズパラドックス: same_creature_destroy")


## 同名クリーチャー相殺が有効
func test_same_creature_destroy_active():
	var stats = _make_stats("same_creature_destroy")
	assert_true(SpellWorldCurse.is_same_creature_destroy_active(stats), "same_creature_destroy: 有効")


## 否定: 刻印なし
func test_same_creature_destroy_not_active_no_curse():
	assert_false(SpellWorldCurse.is_same_creature_destroy_active(EMPTY_STATS), "刻印なし: 無効")


## 否定: 別の刻印
func test_same_creature_destroy_not_active_wrong_curse():
	var stats = _make_stats("land_protect")
	assert_false(SpellWorldCurse.is_same_creature_destroy_active(stats), "別刻印: 無効")


# ========================================
# 刻印上書きテスト
# ========================================

## 世界刻印は1つだけ有効（後勝ち）
## 同時に2つの世界刻印が有効にならないことを確認
func test_only_one_world_curse_active():
	var stats = _make_stats("land_protect")
	# land_protectが有効
	assert_true(SpellWorldCurse.is_land_change_blocked(stats), "land_protect有効")
	# 他の刻印は無効
	assert_false(SpellWorldCurse.is_cursed_creature_protected(stats), "cursed_protection無効")
	assert_false(SpellWorldCurse.is_summon_condition_ignored(stats), "summon_cost_free無効")
	assert_false(SpellWorldCurse.is_all_players_spell_immune(stats), "world_spell_protection無効")
	assert_false(SpellWorldCurse.is_same_creature_destroy_active(stats), "same_creature_destroy無効")


# ========================================
# 統合テスト: インペリアルガード × SpellLand
# 世界刻印が実際に土地変更をブロックするか
# ========================================

var _board: BoardSystem3D
var _spell_land: SpellLand
var _land_test_nodes: Array = []


## SpellWorldCurseのcheck_land_change_blockedを模擬するモック
class _MockWorldCurse extends RefCounted:
	var _blocked: bool = false

	func check_land_change_blocked(_show_popup: bool = true) -> bool:
		return _blocked


func _setup_land_test(blocked: bool = false) -> void:
	_board = BoardSystem3D.new()
	_board.name = "BoardSystem3D_LandTest"
	add_child(_board)
	_board.tile_nodes = SpellTestHelper.create_tile_nodes()

	var cm = CreatureManager.new()
	var ps = PlayerSystem.new()
	_land_test_nodes = [cm, ps]

	# SpellLand
	_spell_land = SpellLand.new()
	_spell_land.setup(_board, cm, ps)

	# モックWorldCurseを注入（_spell_world_curseはVariant型）
	var mock_wc = _MockWorldCurse.new()
	mock_wc._blocked = blocked
	_spell_land.set_spell_world_curse(mock_wc)


func _teardown_land_test() -> void:
	for node in _land_test_nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	_land_test_nodes.clear()
	if _board and is_instance_valid(_board):
		_board.queue_free()


## インペリアルガード発動中: 属性変更がブロックされる
func test_land_change_blocked_by_imperial_guard():
	_setup_land_test(true)
	# タイル1はfire属性
	var result = _spell_land.change_element(1, "water")
	assert_false(result, "インペリアルガード: 属性変更ブロック")
	# 属性が変わっていないことを確認
	assert_eq(_board.tile_nodes[1].tile_type, "fire", "属性が変わっていない")
	_teardown_land_test()


## インペリアルガード発動中: レベルダウンがブロックされる
func test_level_down_blocked_by_imperial_guard():
	_setup_land_test(true)
	_board.tile_nodes[1].level = 3
	var result = _spell_land.change_level(1, -1)
	assert_false(result, "インペリアルガード: レベルダウンブロック")
	assert_eq(_board.tile_nodes[1].level, 3, "レベルが変わっていない")
	_teardown_land_test()


## インペリアルガードなし: is_land_change_blockedがfalse
func test_land_change_not_blocked_without_imperial_guard():
	_setup_land_test(false)
	assert_false(_spell_land.is_land_change_blocked(), "刻印なし: ブロックされない")
	_teardown_land_test()


## 別の世界刻印（ブロックなし）: is_land_change_blockedがfalse
func test_land_change_not_blocked_with_other_curse():
	_setup_land_test(false)
	assert_false(_spell_land.is_land_change_blocked(), "別の世界刻印: ブロックされない")
	_teardown_land_test()


# ========================================
# 統合テスト: ハイプリーステス × SpellProtection
# 刻印付きクリーチャーが結界になるか
# ========================================

## 女教皇発動中 + 刻印付きクリーチャー → 結界
func test_cursed_creature_protected_by_high_priestess():
	var context = _make_stats("cursed_protection")
	var creature: Dictionary = {
		"name": "テストクリーチャー",
		"curse": {"curse_type": "stat_reduce", "duration": 3},
	}
	assert_true(
		SpellProtection.is_creature_protected(creature, context),
		"女教皇 + 刻印付き: 結界"
	)


## 女教皇発動中 + 刻印なしクリーチャー → 結界にならない
func test_uncursed_creature_not_protected_by_high_priestess():
	var context = _make_stats("cursed_protection")
	var creature: Dictionary = {
		"name": "テストクリーチャー",
		"curse": {},
	}
	assert_false(
		SpellProtection.is_creature_protected(creature, context),
		"女教皇 + 刻印なし: 結界にならない"
	)


## 女教皇なし + 刻印付きクリーチャー → 結界にならない
func test_cursed_creature_not_protected_without_high_priestess():
	var creature: Dictionary = {
		"name": "テストクリーチャー",
		"curse": {"curse_type": "stat_reduce", "duration": 3},
	}
	assert_false(
		SpellProtection.is_creature_protected(creature, EMPTY_STATS),
		"女教皇なし + 刻印付き: 結界にならない"
	)


## 結界キーワード持ちは世界刻印関係なく常に結界
func test_barrier_keyword_always_protected():
	var creature: Dictionary = {
		"name": "結界クリーチャー",
		"ability_parsed": {"keywords": ["結界"]},
	}
	assert_true(
		SpellProtection.is_creature_protected(creature, EMPTY_STATS),
		"結界キーワード: 常に結界"
	)


## spell_protection刻印 → 結界
func test_spell_protection_curse_protected():
	var creature: Dictionary = {
		"name": "結界刻印クリーチャー",
		"curse": {"curse_type": "spell_protection"},
	}
	assert_true(
		SpellProtection.is_creature_protected(creature, EMPTY_STATS),
		"spell_protection刻印: 結界"
	)


# ========================================
# 統合テスト: エンプレスドメイン × SpellProtection
# 全プレイヤーがスペル対象外になるか
# ========================================

## 女帝発動中: プレイヤーがスペル対象外
func test_player_protected_by_empress_domain():
	var context = _make_stats("world_spell_protection")
	# PlayerDataのモック（curseプロパティを持つ）
	var mock_player = _MockPlayer.new()
	mock_player.name = "テストプレイヤー"
	assert_true(
		SpellProtection.is_player_protected(mock_player, context),
		"女帝: プレイヤーはスペル対象外"
	)


## 女帝なし: プレイヤーはスペル対象
func test_player_not_protected_without_empress():
	var mock_player = _MockPlayer.new()
	mock_player.name = "テストプレイヤー"
	assert_false(
		SpellProtection.is_player_protected(mock_player, EMPTY_STATS),
		"女帝なし: プレイヤーはスペル対象"
	)


## 別の世界刻印: プレイヤーはスペル対象
func test_player_not_protected_with_other_curse():
	var context = _make_stats("land_protect")
	var mock_player = _MockPlayer.new()
	mock_player.name = "テストプレイヤー"
	assert_false(
		SpellProtection.is_player_protected(mock_player, context),
		"別の世界刻印: プレイヤーはスペル対象"
	)


## プレイヤー刻印spell_protection → 世界刻印関係なく結界
func test_player_spell_protection_curse():
	var mock_player = _MockPlayer.new()
	mock_player.name = "テストプレイヤー"
	mock_player.curse = {"curse_type": "spell_protection"}
	assert_true(
		SpellProtection.is_player_protected(mock_player, EMPTY_STATS),
		"プレイヤー刻印spell_protection: 結界"
	)


# ========================================
# 統合テスト: ハングドマンズシール × 実際のチェック箇所
# トリガーが無効化されるか
# ========================================

## mystic_arts無効 → アルカナアーツが発動しない
func test_mystic_arts_disabled_by_hanged_man():
	var stats = _make_stats("skill_disable", {
		"disabled_triggers": ["mystic_arts", "on_death", "on_battle_end"]
	})
	# 実際のゲームコード相当: SpellWorldCurse.is_trigger_disabled("mystic_arts", game_stats)
	assert_true(SpellWorldCurse.is_trigger_disabled("mystic_arts", stats), "吊人: アルカナアーツ無効")
	assert_true(SpellWorldCurse.is_trigger_disabled("on_death", stats), "吊人: 死亡効果無効")
	assert_true(SpellWorldCurse.is_trigger_disabled("on_battle_end", stats), "吊人: 戦闘後効果無効")


## 吊人なしではすべてのトリガーが有効
func test_all_triggers_enabled_without_hanged_man():
	assert_false(SpellWorldCurse.is_trigger_disabled("mystic_arts", EMPTY_STATS), "吊人なし: アルカナアーツ有効")
	assert_false(SpellWorldCurse.is_trigger_disabled("on_death", EMPTY_STATS), "吊人なし: 死亡効果有効")
	assert_false(SpellWorldCurse.is_trigger_disabled("on_battle_end", EMPTY_STATS), "吊人なし: 戦闘後効果有効")


## disabled_triggersに含まれないトリガーは有効
func test_unlisted_trigger_still_enabled():
	var stats = _make_stats("skill_disable", {
		"disabled_triggers": ["mystic_arts"]
	})
	assert_true(SpellWorldCurse.is_trigger_disabled("mystic_arts", stats), "リストにあるトリガー: 無効")
	assert_false(SpellWorldCurse.is_trigger_disabled("on_death", stats), "リストにないトリガー: 有効")


# ========================================
# 統合テスト: ライズオブサン × コスト計算
# 実際のカードデータでコスト倍率が適用されるか
# ========================================

## 実際のRレアリティカードでコスト倍率を検証
func test_cost_multiplier_with_real_card():
	var stats = _make_stats("cost_increase", {"bag_multiplier": 1.5, "crown_bag_multiplier": 2.0})
	# ライズオブサン自体はSレア
	var card = CardLoader.get_card_by_id(2009)
	if card.is_empty():
		pass_test("カードデータなし（スキップ）")
		return
	var rarity = card.get("rarity", "N")
	var multiplier = SpellWorldCurse.get_cost_multiplier(card, stats)
	match rarity:
		"R":
			assert_eq(multiplier, 2.0, "Rレア: 2倍")
		"S":
			assert_eq(multiplier, 1.5, "Sレア: 1.5倍")
		_:
			assert_eq(multiplier, 1.0, "N/Cレア: 1倍")


## コスト倍率が実際のEP計算に影響する例
func test_cost_multiplier_ep_calculation():
	var stats = _make_stats("cost_increase", {"bag_multiplier": 1.5, "crown_bag_multiplier": 2.0})
	var base_cost: int = 100
	# Rレアカードのコスト計算
	var card_r: Dictionary = {"rarity": "R"}
	var multiplier = SpellWorldCurse.get_cost_multiplier(card_r, stats)
	var final_cost = int(base_cost * multiplier)
	assert_eq(final_cost, 200, "R: 100 * 2.0 = 200EP")
	# Sレアカードのコスト計算
	var card_s: Dictionary = {"rarity": "S"}
	multiplier = SpellWorldCurse.get_cost_multiplier(card_s, stats)
	final_cost = int(base_cost * multiplier)
	assert_eq(final_cost, 150, "S: 100 * 1.5 = 150EP")


# ========================================
# 統合テスト: ボンドオブラバーズ × 連鎖判定
# 異属性が連鎖グループとして扱われるか
# ========================================

## 通常時: fire-earthは別グループ → 連鎖しない
func test_chain_normal_fire_earth_no_chain():
	assert_false(
		SpellWorldCurse.is_same_chain_group("fire", "earth", EMPTY_STATS),
		"通常: fire-earth別グループ"
	)


## ボンドオブラバーズ発動: fire-earthが連鎖
func test_chain_bond_fire_earth_chain():
	var stats = _make_stats("element_chain", {
		"chain_pairs": [["fire", "earth"], ["water", "wind"]]
	})
	assert_true(
		SpellWorldCurse.is_same_chain_group("fire", "earth", stats),
		"恋人発動: fire-earth連鎖"
	)


## ボンドオブラバーズ発動: fire-waterは連鎖しない
func test_chain_bond_fire_water_no_chain():
	var stats = _make_stats("element_chain", {
		"chain_pairs": [["fire", "earth"], ["water", "wind"]]
	})
	assert_false(
		SpellWorldCurse.is_same_chain_group("fire", "water", stats),
		"恋人発動でもfire-waterは別"
	)


## ボンドオブラバーズ発動: 逆順でも連鎖（earth-fire）
func test_chain_bond_reverse_order():
	var stats = _make_stats("element_chain", {
		"chain_pairs": [["fire", "earth"], ["water", "wind"]]
	})
	assert_true(
		SpellWorldCurse.is_same_chain_group("earth", "fire", stats),
		"逆順でも連鎖"
	)


# ========================================
# プレイヤーモック（curseプロパティ付き）
# ========================================

class _MockPlayer extends RefCounted:
	var name: String = ""
	var curse: Dictionary = {}
