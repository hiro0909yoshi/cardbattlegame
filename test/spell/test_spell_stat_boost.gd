extends GutTest

## ステータスブースト系テスト
## SpellCurseStat.apply_stat_boost + JSON定義確認 + 刻印構造体検証

const Helper = preload("res://test/spell/spell_test_helper.gd")

var _spell_curse: SpellCurse
var _spell_curse_stat: SpellCurseStat
var _creature_manager: CreatureManager


func before_each():
	_creature_manager = CreatureManager.new()
	_spell_curse = SpellCurse.new()
	_spell_curse.creature_manager = _creature_manager

	_spell_curse_stat = SpellCurseStat.new()
	_spell_curse_stat.setup(_spell_curse, _creature_manager)


func after_each():
	if _spell_curse_stat and is_instance_valid(_spell_curse_stat):
		_spell_curse_stat.queue_free()


## クリーチャーを配置
func _place_creature(tile_index: int, name: String = "テスト", hp: int = 40, ap: int = 30) -> void:
	_creature_manager.creatures[tile_index] = Helper.make_creature(name, hp, ap)


## JSON定義からstat_boostのeffectを取得
func _get_stat_boost_effect(spell_id: int) -> Dictionary:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "stat_boost":
			return e
	return {}


# ========================================
# JSON定義確認
# ========================================

## エンハンス(2066): stat_boost + draw
func test_enhance_json():
	var effect = _get_stat_boost_effect(2066)
	assert_eq(effect.get("effect_type", ""), "stat_boost", "エンハンス: stat_boost")
	assert_eq(int(effect.get("value", 0)), 20, "エンハンス: value=20")
	assert_eq(effect.get("name", ""), "暁光", "エンハンス: name=暁光")

## エンハンス(2066): drawも持つ
func test_enhance_has_draw():
	var card = CardLoader.get_card_by_id(2066)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var has_draw = false
	for e in effects:
		if e.get("effect_type", "") == "draw":
			has_draw = true
	assert_true(has_draw, "エンハンス: draw効果も持つ")

## 暁光刻印付与(9030): stat_boost
func test_dawn_mystic_json():
	var effect = _get_stat_boost_effect(9030)
	assert_eq(effect.get("effect_type", ""), "stat_boost", "暁光刻印: stat_boost")
	assert_eq(int(effect.get("value", 0)), 20, "暁光刻印: value=20")
	assert_eq(effect.get("name", ""), "暁光", "暁光刻印: name=暁光")


# ========================================
# apply_stat_boost: 刻印付与テスト
# ========================================

## 基本付与: クリーチャーに暁光刻印
func test_apply_stat_boost_basic():
	_place_creature(5)
	var effect: Dictionary = {"effect_type": "stat_boost", "name": "暁光", "value": 20, "duration": -1}
	_spell_curse_stat.apply_stat_boost(5, effect)

	var curse = _spell_curse.get_creature_curse(5)
	assert_eq(curse.get("curse_type", ""), "stat_boost", "curse_type=stat_boost")
	assert_eq(curse.get("name", ""), "暁光", "name=暁光")
	assert_eq(curse.get("duration", 0), -1, "duration=-1（永続）")
	var params = curse.get("params", {})
	assert_eq(params.get("value", 0), 20, "params.value=20")


## apply_curse_from_effect経由
func test_apply_curse_from_effect():
	_place_creature(3)
	var effect: Dictionary = {"effect_type": "stat_boost", "name": "暁光", "value": 20, "duration": -1}
	_spell_curse_stat.apply_curse_from_effect(effect, 3)

	var curse = _spell_curse.get_creature_curse(3)
	assert_eq(curse.get("curse_type", ""), "stat_boost", "経由: stat_boost付与")
	assert_eq(curse.get("params", {}).get("value", 0), 20, "経由: value=20")


## デフォルト値テスト: value/name/durationを省略
func test_apply_stat_boost_defaults():
	_place_creature(5)
	var effect: Dictionary = {"effect_type": "stat_boost"}
	_spell_curse_stat.apply_stat_boost(5, effect)

	var curse = _spell_curse.get_creature_curse(5)
	assert_eq(curse.get("curse_type", ""), "stat_boost", "デフォルト: stat_boost")
	assert_eq(curse.get("name", ""), "暁光", "デフォルト: name=暁光")
	assert_eq(curse.get("duration", 0), -1, "デフォルト: duration=-1")
	assert_eq(curse.get("params", {}).get("value", 0), 20, "デフォルト: value=20")


## カスタム値テスト
func test_apply_stat_boost_custom_value():
	_place_creature(5)
	var effect: Dictionary = {"effect_type": "stat_boost", "name": "強化", "value": 50, "duration": 3}
	_spell_curse_stat.apply_stat_boost(5, effect)

	var curse = _spell_curse.get_creature_curse(5)
	assert_eq(curse.get("name", ""), "強化", "カスタム: name=強化")
	assert_eq(curse.get("duration", 0), 3, "カスタム: duration=3")
	assert_eq(curse.get("params", {}).get("value", 0), 50, "カスタム: value=50")


## 既存刻印の上書き
func test_stat_boost_overwrite():
	_place_creature(5)
	# 零落を先に付与
	_spell_curse.curse_creature(5, "stat_reduce", -1, {"name": "零落", "value": -10})
	var curse_before = _spell_curse.get_creature_curse(5)
	assert_eq(curse_before.get("curse_type", ""), "stat_reduce", "上書き前: stat_reduce")

	# 暁光で上書き
	var effect: Dictionary = {"effect_type": "stat_boost", "name": "暁光", "value": 20, "duration": -1}
	_spell_curse_stat.apply_stat_boost(5, effect)
	var curse_after = _spell_curse.get_creature_curse(5)
	assert_eq(curse_after.get("curse_type", ""), "stat_boost", "上書き後: stat_boost")
	assert_eq(curse_after.get("name", ""), "暁光", "上書き後: 暁光")
