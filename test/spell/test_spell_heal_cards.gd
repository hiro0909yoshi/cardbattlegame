extends GutTest

## 回復系 個別カードテスト
## スプリング(full_heal), リジェネ(clear_down+full_heal), ヒール(heal) のJSON定義確認+効果検証

const Helper = preload("res://test/spell/spell_test_helper.gd")

var _spell_damage: SpellDamage
var _board: BoardSystem3D


func before_each():
	_board = BoardSystem3D.new()
	_board.name = "BoardSystem3D_Heal"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()
	_spell_damage = SpellDamage.new(_board)


func after_each():
	if _board and is_instance_valid(_board):
		_board.free()


## クリーチャー配置
func _place_creature(tile_index: int, hp: int = 40, ap: int = 30) -> void:
	var creature = Helper.make_creature("テストクリーチャー", hp, ap)
	var tile = _board.tile_nodes[tile_index]
	tile.creature_data = creature.duplicate(true)
	tile.owner_id = 0


## ダメージを受けた状態にする
func _damage_creature(tile_index: int, damage: int) -> void:
	var creature = _board.tile_nodes[tile_index].creature_data
	var mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
	creature["current_hp"] = max(1, mhp - damage)


## JSON定義からeffect_typeを取得
func _get_effect_types(spell_id: int) -> Array[String]:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	return types


# ========================================
# JSON定義確認
# ========================================

## スプリング(2116): full_heal
func test_spring_json():
	var types = _get_effect_types(2116)
	assert_true(types.has("full_heal"), "スプリング: full_heal持ち")
	# target_type確認
	var card = CardLoader.get_card_by_id(2116)
	var target_type = card.get("effect_parsed", {}).get("target_type", "")
	assert_eq(target_type, "all_creatures", "スプリング: 全クリーチャー対象")


## リジェネ(2121): clear_down + full_heal
func test_regen_json():
	var types = _get_effect_types(2121)
	assert_true(types.has("full_heal"), "リジェネ: full_heal持ち")
	assert_true(types.has("clear_down"), "リジェネ: clear_down持ち")


## ヒール(9009): heal with value=30
func test_heal_json():
	var types = _get_effect_types(9009)
	assert_true(types.has("heal"), "ヒール: heal持ち")
	var card = CardLoader.get_card_by_id(9009)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "heal":
			assert_eq(int(e.get("value", 0)), 30, "ヒール: value=30")


# ========================================
# ヒール(9009): 固定値回復テスト
# ========================================

## ヒール: HP10/40 + heal(30) → HP40
func test_heal_basic():
	_place_creature(1, 40)
	_damage_creature(1, 30)  # HP10
	var result = _spell_damage.apply_heal(1, 30)
	assert_true(result.get("success", false), "ヒール成功")
	assert_eq(result.get("old_hp", 0), 10, "旧HP=10")
	assert_eq(result.get("new_hp", 0), 40, "新HP=40")


## ヒール: MHP上限キャップ HP35/40 + heal(30) → HP40
func test_heal_capped():
	_place_creature(1, 40)
	_damage_creature(1, 5)  # HP35
	var result = _spell_damage.apply_heal(1, 30)
	assert_eq(result.get("new_hp", 0), 40, "MHP上限: HP40")


## ヒール: base_up_hp考慮 HP20/(40+10) + heal(30) → HP50
func test_heal_with_base_up():
	_place_creature(1, 40)
	_board.tile_nodes[1].creature_data["base_up_hp"] = 10
	_board.tile_nodes[1].creature_data["current_hp"] = 20
	var result = _spell_damage.apply_heal(1, 30)
	assert_eq(result.get("new_hp", 0), 50, "base_up_hp込みMHP=50")
	assert_eq(result.get("max_hp", 0), 50, "max_hp=50")


# ========================================
# スプリング(2116): 全回復テスト
# ========================================

## スプリング: HP10/40 → HP40
func test_spring_full_heal():
	_place_creature(1, 40)
	_damage_creature(1, 30)  # HP10
	var result = _spell_damage.apply_full_heal(1)
	assert_true(result.get("success", false), "全回復成功")
	assert_eq(result.get("new_hp", 0), 40, "全回復: HP40")


## スプリング: base_up_hp込み HP15/(40+10) → HP50
func test_spring_full_heal_base_up():
	_place_creature(1, 40)
	_board.tile_nodes[1].creature_data["base_up_hp"] = 10
	_board.tile_nodes[1].creature_data["current_hp"] = 15
	var result = _spell_damage.apply_full_heal(1)
	assert_eq(result.get("new_hp", 0), 50, "base_up込み全回復: HP50")
	assert_eq(result.get("max_hp", 0), 50, "max_hp=50")


## スプリング: 満タンから全回復 → 変化なし
func test_spring_already_full():
	_place_creature(1, 40)
	var result = _spell_damage.apply_full_heal(1)
	assert_true(result.get("success", false), "全回復成功（変化なし）")
	assert_eq(result.get("new_hp", 0), 40, "変化なし: HP40")


# ========================================
# リジェネ(2121): clear_down + full_heal 複合テスト
# ========================================

## リジェネ: ダウン+ダメージ → ダウン解除+HP全回復
func test_regen_combined():
	_place_creature(1, 40)
	_damage_creature(1, 25)  # HP15
	var tile = _board.tile_nodes[1]
	tile.set_down_state(true)
	assert_true(tile.is_down(), "前提: ダウン状態")
	assert_eq(tile.creature_data["current_hp"], 15, "前提: HP15")

	# clear_down
	tile.clear_down_state()
	assert_false(tile.is_down(), "ダウン解除")

	# full_heal
	var result = _spell_damage.apply_full_heal(1)
	assert_eq(result.get("new_hp", 0), 40, "全回復: HP40")


## リジェネ: ダウンなし+ダメージあり → HP全回復のみ
func test_regen_no_down():
	_place_creature(1, 40)
	_damage_creature(1, 20)  # HP20
	var tile = _board.tile_nodes[1]
	assert_false(tile.is_down(), "ダウンなし")

	tile.clear_down_state()  # 無害
	assert_false(tile.is_down(), "変化なし")

	var result = _spell_damage.apply_full_heal(1)
	assert_eq(result.get("new_hp", 0), 40, "全回復: HP40")


## リジェネ: ダウン+満タン → ダウン解除のみ
func test_regen_down_full_hp():
	_place_creature(1, 40)
	var tile = _board.tile_nodes[1]
	tile.set_down_state(true)
	assert_true(tile.is_down(), "前提: ダウン状態")

	tile.clear_down_state()
	assert_false(tile.is_down(), "ダウン解除")

	var result = _spell_damage.apply_full_heal(1)
	assert_eq(result.get("new_hp", 0), 40, "HPは変化なし: HP40")
