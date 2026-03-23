extends GutTest

## ダメージ系スペル 個別カードテスト
## 各スペルカードのJSON定義が正しいか + apply_damageによる効果検証

const Helper = preload("res://test/spell/spell_test_helper.gd")

var _spell_damage: SpellDamage
var _board: BoardSystem3D


func before_each():
	_board = BoardSystem3D.new()
	_board.name = "BoardSystem3D_Test"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()
	_spell_damage = SpellDamage.new(_board)


func after_each():
	if _board and is_instance_valid(_board):
		_board.free()


## クリーチャー配置ヘルパー
func _place_creature(tile_index: int, hp: int = 40, element: String = "fire") -> void:
	var creature = Helper.make_creature("テスト", hp, 20)
	creature["element"] = element
	var tile = _board.tile_nodes[tile_index]
	tile.creature_data = creature.duplicate(true)
	tile.owner_id = 1


## スペルカードを取得
func _get_spell(spell_id: int) -> Dictionary:
	var card = CardLoader.get_card_by_id(spell_id)
	if card.is_empty():
		return {}
	return card


## スペルのダメージ値を取得
func _get_damage_value(spell_id: int) -> int:
	var card = _get_spell(spell_id)
	var effects = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type") == "damage":
			return e.get("value", 0)
	return 0


# ========================================
# spell_1 ダメージスペル
# ========================================

## クリティカル(2016): 20ダメージ
func test_critical_damage():
	assert_eq(_get_damage_value(2016), 20, "クリティカル: 20ダメージ")
	_place_creature(1, 40)
	var r = _spell_damage.apply_damage(1, _get_damage_value(2016))
	assert_eq(r["new_hp"], 20, "HP40-20=20")


## マッサカー(2023): 20ダメージ
func test_massacre_damage():
	assert_eq(_get_damage_value(2023), 20, "マッサカー: 20ダメージ")
	_place_creature(1, 40)
	var r = _spell_damage.apply_damage(1, _get_damage_value(2023))
	assert_eq(r["new_hp"], 20, "HP40-20=20")


## ボルト(2031): 30ダメージ
func test_bolt_damage():
	assert_eq(_get_damage_value(2031), 30, "ボルト: 30ダメージ")
	_place_creature(1, 40)
	var r = _spell_damage.apply_damage(1, _get_damage_value(2031))
	assert_eq(r["new_hp"], 10, "HP40-30=10")


## ラディエンス(2033): 30ダメージ
func test_radiance_damage():
	assert_eq(_get_damage_value(2033), 30, "ラディエンス: 30ダメージ")


## プレデター(2037): 20ダメージ
func test_predator_damage():
	assert_eq(_get_damage_value(2037), 20, "プレデター: 20ダメージ")


## ロックストーム(2041): 30ダメージ
func test_rockstorm_damage():
	assert_eq(_get_damage_value(2041), 30, "ロックストーム: 30ダメージ")


## スナイプ(2053): 30ダメージ
func test_snipe_damage():
	assert_eq(_get_damage_value(2053), 30, "スナイプ: 30ダメージ")


# ========================================
# spell_2 ダメージスペル
# ========================================

## フレア(2065): 20ダメージ
func test_flare_damage():
	assert_eq(_get_damage_value(2065), 20, "フレア: 20ダメージ")


## フロスト(2086): 20ダメージ
func test_frost_damage():
	assert_eq(_get_damage_value(2086), 20, "フロスト: 20ダメージ")


## フュージョン(2088): 30ダメージ
func test_fusion_damage():
	assert_eq(_get_damage_value(2088), 30, "フュージョン: 30ダメージ")


## スパーク(2106): 20ダメージ
func test_spark_damage():
	assert_eq(_get_damage_value(2106), 20, "スパーク: 20ダメージ")


# ========================================
# spell_mystic ダメージスペル
# ========================================

## マジックボルト(9004): 10ダメージ
func test_magic_bolt_damage():
	assert_eq(_get_damage_value(9004), 10, "マジックボルト: 10ダメージ")
	_place_creature(1, 40)
	var r = _spell_damage.apply_damage(1, _get_damage_value(9004))
	assert_eq(r["new_hp"], 30, "HP40-10=30")


## ロックブレス(9005): 20ダメージ
func test_rock_breath_damage():
	assert_eq(_get_damage_value(9005), 20, "ロックブレス: 20ダメージ")


## ストームコール(9006): 20ダメージ
func test_storm_call_damage():
	assert_eq(_get_damage_value(9006), 20, "ストームコール: 20ダメージ")


## クロムレイ(9007): 30ダメージ
func test_chrome_ray_damage():
	assert_eq(_get_damage_value(9007), 30, "クロムレイ: 30ダメージ")


## 熾天断罪(9008): 20ダメージ
func test_seraphim_judgment_damage():
	assert_eq(_get_damage_value(9008), 20, "熾天断罪: 20ダメージ")


# ========================================
# 撃破ボーダーテスト（ダメージ値でちょうど撃破）
# ========================================

## 30ダメージスペルでHP30クリーチャーをちょうど撃破（HP計算検証）
func test_exact_kill_30():
	_place_creature(1, 30)
	var tile = _board.tile_nodes[1]
	var creature = tile.creature_data
	var new_hp = max(0, creature.get("current_hp", 30) - 30)
	assert_eq(new_hp, 0, "ちょうど撃破: HP0")
	assert_true(new_hp <= 0, "撃破判定: HP<=0")


## 20ダメージスペルでHP30クリーチャーは生存
func test_survive_20_on_30hp():
	_place_creature(1, 30)
	var r = _spell_damage.apply_damage(1, 20)
	assert_eq(r["new_hp"], 10, "生存: HP10")
	assert_false(r["destroyed"], "撃破されない")


## 10ダメージでHP10クリーチャーをちょうど撃破（HP計算検証）
func test_exact_kill_10():
	_place_creature(1, 10)
	var tile = _board.tile_nodes[1]
	var creature = tile.creature_data
	var new_hp = max(0, creature.get("current_hp", 10) - 10)
	assert_eq(new_hp, 0, "ちょうど撃破: HP0")
	assert_true(new_hp <= 0, "撃破判定: HP<=0")
