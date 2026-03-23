extends GutTest

## SpellCurse テスト
## 各種刻印の付与、取得、削除を検証

const Helper = preload("res://test/spell/spell_test_helper.gd")

var _spell_curse: SpellCurse
var _board: BoardSystem3D
var _cm: CreatureManager
var _player_system: PlayerSystem


func before_each():
	_board = BoardSystem3D.new()
	_board.name = "BoardSystem3D_Test"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()

	_cm = CreatureManager.new()
	_cm.name = "CreatureManager_Test"
	add_child(_cm)

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_Test"
	add_child(_player_system)
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 500
	_player_system.players = [p0]
	_player_system.current_player_index = 0

	_spell_curse = SpellCurse.new()
	_spell_curse.name = "SpellCurse_Test"
	add_child(_spell_curse)
	_spell_curse.setup(_board, _cm, _player_system, null)


func after_each():
	for node in [_spell_curse, _board, _cm, _player_system]:
		if is_instance_valid(node):
			node.free()


## クリーチャー配置ヘルパー
func _place(tile_index: int, creature_name: String = "テストクリーチャー") -> void:
	var creature = Helper.make_creature(creature_name, 40, 30)
	Helper.place_creature(_board.tile_nodes, _cm, tile_index, creature, 0)


# ========================================
# 基本刻印付与テスト
# ========================================

## 錯乱（skill_nullify）刻印
func test_curse_skill_nullify():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "skill_nullify", "name": "錯乱", "duration": 3}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_false(curse.is_empty(), "刻印が付与された")
	assert_eq(curse["curse_type"], "skill_nullify", "刻印タイプ: skill_nullify")
	assert_eq(curse["name"], "錯乱", "刻印名: 錯乱")
	assert_eq(curse["duration"], 3, "持続: 3ターン")


## 消沈（battle_disable）刻印
func test_curse_battle_disable():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "battle_disable", "name": "消沈", "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "battle_disable", "消沈刻印")
	assert_eq(curse["duration"], -1, "永続")


## AP無効（ap_nullify）刻印
func test_curse_ap_nullify():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "ap_nullify", "name": "AP=0", "duration": 2}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "ap_nullify", "AP無効刻印")


## 奮闘（indomitable）刻印
func test_curse_indomitable():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "indomitable", "name": "奮闘", "duration": 5}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "indomitable", "奮闘刻印")
	assert_eq(curse["duration"], 5, "持続: 5ターン")


## ステータス減少（stat_reduce）刻印
func test_curse_stat_reduce():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "stat_reduce", "name": "零落", "stat": "both", "value": -10, "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "stat_reduce", "ステータス減少刻印")
	assert_eq(curse["params"]["stat"], "both", "HP&AP両方")
	assert_eq(curse["params"]["value"], -10, "減少値-10")


## 衰弱（plague）刻印
func test_curse_plague():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "plague_curse", "name": "衰弱", "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "plague", "衰弱刻印")


## 停滞（forced_stop）刻印
func test_curse_forced_stop():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "forced_stop", "name": "停滞", "uses": 1, "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "forced_stop", "停滞刻印")
	assert_eq(curse["params"]["uses_remaining"], 1, "使用回数1")


## クリーチャー汎用刻印（creature_curse: 枷）
func test_curse_creature_move_disable():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "creature_curse", "curse_type": "move_disable", "name": "枷", "duration": 3}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "move_disable", "枷刻印")


# ========================================
# 刻印上書きテスト
# ========================================

## 既存刻印を別の刻印で上書き
func test_curse_overwrite():
	_place(1, "ゴブリン")
	_spell_curse.apply_effect({"effect_type": "skill_nullify", "name": "錯乱", "duration": 3}, 1)
	assert_eq(_spell_curse.get_creature_curse(1)["name"], "錯乱")

	_spell_curse.apply_effect({"effect_type": "battle_disable", "name": "消沈", "duration": -1}, 1)
	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["name"], "消沈", "刻印が上書きされた")
	assert_eq(curse["curse_type"], "battle_disable", "新しい刻印タイプ")


# ========================================
# 刻印削除テスト
# ========================================

## 刻印を削除
func test_remove_curse():
	_place(1, "ゴブリン")
	_spell_curse.apply_effect({"effect_type": "skill_nullify", "name": "錯乱", "duration": 3}, 1)
	assert_false(_spell_curse.get_creature_curse(1).is_empty(), "刻印あり")

	_spell_curse.remove_curse_from_creature(1)
	assert_true(_spell_curse.get_creature_curse(1).is_empty(), "刻印削除済み")


## 刻印なしクリーチャーの削除は安全
func test_remove_curse_no_curse():
	_place(1, "ゴブリン")
	_spell_curse.remove_curse_from_creature(1)
	assert_true(_spell_curse.get_creature_curse(1).is_empty(), "エラーなし")


# ========================================
# クリーチャーなしタイルへの刻印
# ========================================

## クリーチャーなしタイルへの刻印はスキップ
func test_curse_empty_tile():
	_spell_curse.apply_effect({"effect_type": "skill_nullify", "name": "錯乱", "duration": 3}, 1)
	var curse = _spell_curse.get_creature_curse(1)
	assert_true(curse.is_empty(), "クリーチャーなしには付与されない")


# ========================================
# 秘術付与（grant_mystic_arts）テスト
# ========================================

## spell_id参照方式でアルカナアーツ付与
func test_curse_grant_mystic_arts_spell_id():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "grant_mystic_arts",
		"name": "ドレインシジル",
		"spell_id": 9012,
		"cost": 30,
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "mystic_grant", "秘術付与刻印")
	assert_eq(curse["name"], "ドレインシジル", "刻印名")
	assert_eq(curse["params"]["spell_id"], 9012, "spell_id")
	assert_eq(curse["params"]["cost"], 30, "コスト")
	assert_eq(curse["duration"], -1, "永続")


## mystic_arts配列方式でアルカナアーツ付与
func test_curse_grant_mystic_arts_array():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "grant_mystic_arts",
		"name": "サイフォン",
		"mystic_arts": [{"id": 9004, "cost": 0}],
		"duration": 3
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "mystic_grant", "秘術付与刻印")
	assert_eq(curse["params"]["mystic_arts"].size(), 1, "秘術1つ")
	assert_eq(curse["duration"], 3, "持続3ターン")


# ========================================
# ランダムステータス刻印（random_stat_curse）テスト
# ========================================

## ランダムステータス刻印の付与とパラメータ検証
func test_curse_random_stat():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "random_stat_curse",
		"name": "狂星",
		"stat": "both",
		"min": 10,
		"max": 70,
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "random_stat", "ランダムステータス刻印")
	assert_eq(curse["name"], "狂星", "刻印名")
	assert_eq(curse["params"]["stat"], "both", "HP&AP両方")
	assert_eq(curse["params"]["min"], 10, "最小値10")
	assert_eq(curse["params"]["max"], 70, "最大値70")


# ========================================
# 昇華刻印（command_growth_curse）テスト
# ========================================

## 昇華刻印の付与
func test_curse_command_growth():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "command_growth_curse",
		"name": "昇華",
		"hp_bonus": 20,
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "command_growth", "昇華刻印")
	assert_eq(curse["params"]["hp_bonus"], 20, "HP+20")


## 昇華刻印のトリガーでMHP増加
func test_curse_command_growth_trigger():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "command_growth_curse",
		"name": "昇華",
		"hp_bonus": 20,
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var creature = _cm.get_data_ref(1)
	var old_mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)

	var result = _spell_curse.trigger_command_growth(1)
	assert_true(result["triggered"], "トリガー発動")
	assert_eq(result["hp_bonus"], 20, "HP+20")
	assert_eq(result["new_mhp"], old_mhp + 20, "MHP増加")


## 昇華刻印なしではトリガー不発
func test_curse_command_growth_no_curse():
	_place(1, "ゴブリン")
	var result = _spell_curse.trigger_command_growth(1)
	assert_false(result["triggered"], "刻印なしでは不発")


# ========================================
# 賞金刻印（bounty_curse）テスト
# ========================================

## 賞金刻印の付与とパラメータ検証
func test_curse_bounty():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "bounty_curse",
		"name": "賞金首",
		"reward": 300,
		"requires_weapon": true,
		"prevent_move": true,
		"prevent_swap": true,
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "bounty", "賞金刻印")
	assert_eq(curse["params"]["reward"], 300, "報酬300EP")
	assert_true(curse["params"]["requires_weapon"], "武器必須")
	assert_true(curse["params"]["prevent_move"], "移動禁止")
	assert_true(curse["params"]["prevent_swap"], "交換禁止")
	assert_eq(curse["params"]["caster_id"], 0, "術者ID=0")


# ========================================
# 土地刻印（land_curse）テスト
# ========================================

## 土地刻印の付与とパラメータ検証
func test_curse_land_trap():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "land_curse",
		"name": "ブラストトラップ",
		"curse_type": "land_trap",
		"trigger": "on_enemy_stop",
		"one_shot": true,
		"curse_effects": [{"effect_type": "damage", "value": 30}],
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "land_trap", "土地トラップ刻印")
	assert_eq(curse["params"]["trigger"], "on_enemy_stop", "敵停止時発動")
	assert_true(curse["params"]["one_shot"], "1回限り")
	assert_eq(curse["params"]["curse_effects"].size(), 1, "効果1つ")
	assert_eq(curse["params"]["curse_effects"][0]["value"], 30, "30ダメージ")


# ========================================
# 汎用刻印（apply_curse）テスト
# ========================================

## 汎用刻印（グラナイト等）の付与
func test_curse_apply_generic():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "apply_curse",
		"curse_type": "stone_skin",
		"name": "石化",
		"duration": 3
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "stone_skin", "汎用刻印タイプ")
	assert_eq(curse["name"], "石化", "刻印名")
	assert_eq(curse["duration"], 3, "持続3ターン")


# ========================================
# creature_curse サブタイプテスト
# ========================================

## 天駆（fly）刻印
func test_curse_creature_fly():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "creature_curse",
		"curse_type": "fly",
		"name": "天駆",
		"duration": 5
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "fly", "天駆刻印")
	assert_eq(curse["name"], "天駆", "刻印名")
	assert_eq(curse["duration"], 5, "持続5ターン")


## 結界（spell_protection）刻印
func test_curse_creature_spell_protection():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "creature_curse",
		"curse_type": "spell_protection",
		"name": "結界",
		"spell_protection": true,
		"duration": 3
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "spell_protection", "結界刻印")
	assert_true(curse["params"]["spell_protection"], "スペル防御有効")


## 防御態勢（defensive_form）刻印
func test_curse_creature_defensive_form():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "creature_curse",
		"curse_type": "defensive_form",
		"name": "防御態勢",
		"defensive_form": true,
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var curse = _spell_curse.get_creature_curse(1)
	assert_eq(curse["curse_type"], "defensive_form", "防御態勢刻印")
	assert_true(curse["params"]["defensive_form"], "防御態勢有効")


# ========================================
# SpellCurseBattle経路 - 付与テストのみ
# ========================================

## 暗転（land_effect_disable）刻印の付与
func test_curse_land_effect_disable():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "land_effect_disable", "name": "暗転", "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var creature = _cm.get_data_ref(1)
	var curse = creature.get("curse", {})
	assert_eq(curse["curse_type"], "land_effect_disable", "暗転刻印")
	assert_eq(curse["name"], "暗転", "刻印名")
	assert_true(SpellCurseBattle.has_land_effect_disable(creature), "has_land_effect_disableチェック")


## 恩寵（land_effect_grant）刻印の付与
func test_curse_land_effect_grant():
	_place(1, "ゴブリン")
	var effect = {
		"effect_type": "land_effect_grant",
		"name": "恩寵",
		"grant_elements": ["fire", "water"],
		"duration": -1
	}
	_spell_curse.apply_effect(effect, 1)

	var creature = _cm.get_data_ref(1)
	var curse = creature.get("curse", {})
	assert_eq(curse["curse_type"], "land_effect_grant", "恩寵刻印")
	assert_eq(curse["params"]["grant_elements"].size(), 2, "2属性付与")
	assert_true(SpellCurseBattle.has_land_effect_grant(creature), "has_land_effect_grantチェック")


## メタルフォーム（metal_form）刻印の付与
func test_curse_metal_form():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "metal_form", "name": "メタルフォーム", "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var creature = _cm.get_data_ref(1)
	var curse = creature.get("curse", {})
	assert_eq(curse["curse_type"], "metal_form", "メタルフォーム刻印")
	assert_true(SpellCurseBattle.has_metal_form(creature), "has_metal_formチェック")


## 魔力障壁（magic_barrier）刻印の付与
func test_curse_magic_barrier():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "magic_barrier", "name": "マジックバリア", "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var creature = _cm.get_data_ref(1)
	var curse = creature.get("curse", {})
	assert_eq(curse["curse_type"], "magic_barrier", "魔力障壁刻印")
	assert_eq(curse["params"]["ep_transfer"], 100, "EP移動量100")
	assert_true(SpellCurseBattle.has_magic_barrier(creature), "has_magic_barrierチェック")


## 崩壊（destroy_after_battle）刻印の付与
func test_curse_destroy_after_battle():
	_place(1, "ゴブリン")
	var effect = {"effect_type": "destroy_after_battle", "name": "崩壊", "duration": -1}
	_spell_curse.apply_effect(effect, 1)

	var creature = _cm.get_data_ref(1)
	var curse = creature.get("curse", {})
	assert_eq(curse["curse_type"], "destroy_after_battle", "崩壊刻印")
	assert_true(SpellCurseBattle.has_destroy_after_battle(creature), "has_destroy_after_battleチェック")


# ========================================
# エンジェルギフト（life_force_curse）テスト
# SpellCostModifier経由でプレイヤーに付与
# ========================================

## エンジェルギフト刻印の付与
func test_angel_gift_apply():
	var cost_modifier = SpellCostModifier.new()
	cost_modifier.setup(_spell_curse, _player_system)

	var result = cost_modifier.apply_life_force(0)
	assert_true(result["success"], "付与成功")
	assert_true(cost_modifier.has_life_force(0), "天使刻印あり")

	var player_curse = _player_system.players[0].curse
	assert_eq(player_curse["curse_type"], "life_force", "プレイヤー刻印タイプ")
	assert_eq(player_curse["name"], "天使", "刻印名")
	assert_true(player_curse["params"]["nullify_spell"], "スペル無効化フラグ")


## エンジェルギフト: スペル使用時に無効化＋刻印解除
func test_angel_gift_spell_nullify():
	var cost_modifier = SpellCostModifier.new()
	cost_modifier.setup(_spell_curse, _player_system)
	cost_modifier.apply_life_force(0)
	assert_true(cost_modifier.has_life_force(0), "付与後: 天使刻印あり")

	var result = cost_modifier.check_spell_nullify(0)
	assert_true(result["nullified"], "スペル無効化された")
	assert_true(result["curse_removed"], "刻印が解除された")
	assert_false(cost_modifier.has_life_force(0), "解除後: 天使刻印なし")


## エンジェルギフト: 刻印なしプレイヤーはスペル無効化されない
func test_angel_gift_no_curse_no_nullify():
	var cost_modifier = SpellCostModifier.new()
	cost_modifier.setup(_spell_curse, _player_system)

	var result = cost_modifier.check_spell_nullify(0)
	assert_false(result["nullified"], "刻印なしでは無効化されない")


## エンジェルギフト: クリーチャーカードのコスト0化
func test_angel_gift_creature_cost_zero():
	var cost_modifier = SpellCostModifier.new()
	cost_modifier.setup(_spell_curse, _player_system)
	cost_modifier.apply_life_force(0)

	var creature_card = {"name": "ゴブリン", "type": "creature", "cost": {"ep": 80}}
	var cost = cost_modifier.get_modified_cost(0, creature_card)
	assert_eq(cost, 0, "クリーチャーコスト0")


## エンジェルギフト: アイテムカードのコスト0化
func test_angel_gift_item_cost_zero():
	var cost_modifier = SpellCostModifier.new()
	cost_modifier.setup(_spell_curse, _player_system)
	cost_modifier.apply_life_force(0)

	var item_card = {"name": "剣", "type": "item", "cost": {"ep": 50}}
	var cost = cost_modifier.get_modified_cost(0, item_card)
	assert_eq(cost, 0, "アイテムコスト0")


## エンジェルギフト: スペルカードのコストは変わらない
func test_angel_gift_spell_cost_unchanged():
	var cost_modifier = SpellCostModifier.new()
	cost_modifier.setup(_spell_curse, _player_system)
	cost_modifier.apply_life_force(0)

	var spell_card = {"name": "ボルト", "type": "spell", "cost": {"ep": 100}}
	var cost = cost_modifier.get_modified_cost(0, spell_card)
	assert_eq(cost, 100, "スペルコストは変わらない")


## エンジェルギフト: 刻印なしプレイヤーのコストは変わらない
func test_angel_gift_no_curse_cost_unchanged():
	var cost_modifier = SpellCostModifier.new()
	cost_modifier.setup(_spell_curse, _player_system)

	var creature_card = {"name": "ゴブリン", "type": "creature", "cost": {"ep": 80}}
	var cost = cost_modifier.get_modified_cost(0, creature_card)
	assert_eq(cost, 80, "刻印なしではコスト変わらない")
