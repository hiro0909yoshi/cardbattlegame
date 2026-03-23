extends GutTest

## プレイヤー刻印系テスト
## curse_player による付与 + 実際の判定メソッドによる効果検証 + JSON定義確認

var _spell_curse: SpellCurse
var _player_system: PlayerSystem


func before_each():
	_player_system = PlayerSystem.new()
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 1000
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 500
	_player_system.players = [p0, p1]

	_spell_curse = SpellCurse.new()
	_spell_curse.player_system = _player_system


func after_each():
	if _spell_curse and is_instance_valid(_spell_curse):
		_spell_curse.queue_free()


## JSON定義からplayer_curseのcurse_typeを取得
func _get_player_curse_type(spell_id: int) -> String:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type") == "player_curse":
			return e.get("curse_type", "")
	return ""


# ========================================
# JSON定義確認
# ========================================

## ミュート(2027): spell_disable
func test_mute_json():
	assert_eq(_get_player_curse_type(2027), "spell_disable", "ミュート: spell_disable")

## トゥルース(2070): invasion_disable（休戦）
func test_truce_json():
	assert_eq(_get_player_curse_type(2070), "invasion_disable", "トゥルース: invasion_disable")

## ブレス(2071): spell_protection（祝福）
func test_bless_json():
	assert_eq(_get_player_curse_type(2071), "spell_protection", "ブレス: spell_protection")

## フリー(2125): restriction_release（解放）
func test_free_json():
	assert_eq(_get_player_curse_type(2125), "restriction_release", "フリー: restriction_release")

## 祝福刻印付与(9023): spell_protection
func test_blessing_mystic_json():
	assert_eq(_get_player_curse_type(9023), "spell_protection", "祝福刻印: spell_protection")


# ========================================
# spell_disable: スペル使用禁止
# ========================================

## 禁呪刻印付与 → スペル使用不可になる
func test_spell_disable_blocks_spell():
	_spell_curse.curse_player(0, "spell_disable", 1, {"name": "禁呪"})
	var player = _player_system.players[0]
	assert_true(
		SpellProtection.is_player_spell_disabled(player, {}),
		"禁呪: スペル使用不可"
	)


## 禁呪刻印なし → スペル使用可能
func test_no_curse_spell_enabled():
	var player = _player_system.players[0]
	assert_false(
		SpellProtection.is_player_spell_disabled(player, {}),
		"刻印なし: スペル使用可能"
	)


## 別の刻印 → スペル使用可能
func test_other_curse_spell_enabled():
	_spell_curse.curse_player(0, "spell_protection", 5, {"name": "祝福"})
	var player = _player_system.players[0]
	assert_false(
		SpellProtection.is_player_spell_disabled(player, {}),
		"別刻印: スペル使用可能"
	)


# ========================================
# spell_protection: スペル対象外（祝福/結界）
# ========================================

## 祝福刻印付与 → スペル対象外になる
func test_spell_protection_blocks_target():
	_spell_curse.curse_player(0, "spell_protection", 5, {"name": "祝福"})
	var player = _player_system.players[0]
	assert_true(
		SpellProtection.is_player_protected(player, {}),
		"祝福: スペル対象外"
	)


## 祝福刻印なし → スペル対象
func test_no_curse_is_target():
	var player = _player_system.players[0]
	assert_false(
		SpellProtection.is_player_protected(player, {}),
		"刻印なし: スペル対象"
	)


# ========================================
# invasion_disable: 侵略禁止（休戦）
# ========================================

## 休戦刻印付与 → 刻印が付いている
func test_invasion_disable_applied():
	_spell_curse.curse_player(0, "invasion_disable", 2, {"name": "休戦"})
	var curse = _spell_curse.get_player_curse(0)
	assert_eq(curse.get("curse_type", ""), "invasion_disable", "休戦刻印: curse_type一致")
	assert_eq(curse.get("duration", 0), 2, "duration=2")


## 休戦刻印なし → 刻印なし
func test_no_invasion_disable():
	var curse = _spell_curse.get_player_curse(0)
	assert_true(curse.is_empty(), "刻印なし")


# ========================================
# restriction_release: 制限解除（解放）
# ========================================

## 解放刻印付与 → 刻印確認
func test_restriction_release_applied():
	_spell_curse.curse_player(0, "restriction_release", 4, {
		"name": "解放",
		"ignore_item_restriction": true,
		"ignore_summon_condition": true,
	})
	var curse = _spell_curse.get_player_curse(0)
	assert_eq(curse.get("curse_type", ""), "restriction_release", "解放: curse_type一致")
	var params = curse.get("params", {})
	assert_true(params.get("ignore_item_restriction", false), "アイテム制限無視")
	assert_true(params.get("ignore_summon_condition", false), "召喚条件無視")


# ========================================
# 刻印上書きテスト
# ========================================

## 同じプレイヤーに2つ目の刻印 → 上書き
func test_curse_overwrite():
	_spell_curse.curse_player(0, "spell_disable", 1, {"name": "禁呪"})
	_spell_curse.curse_player(0, "spell_protection", 5, {"name": "祝福"})
	var curse = _spell_curse.get_player_curse(0)
	assert_eq(curse.get("curse_type", ""), "spell_protection", "上書き: 祝福が有効")
	var player = _player_system.players[0]
	assert_false(SpellProtection.is_player_spell_disabled(player, {}), "禁呪は消えた")
	assert_true(SpellProtection.is_player_protected(player, {}), "祝福が有効")


# ========================================
# 刻印除去テスト
# ========================================

## remove_curse_from_player: 刻印が消える
func test_remove_player_curse():
	_spell_curse.curse_player(0, "spell_disable", 1, {"name": "禁呪"})
	_spell_curse.remove_curse_from_player(0)
	var curse = _spell_curse.get_player_curse(0)
	assert_true(curse.is_empty(), "刻印除去後: 空")
	var player = _player_system.players[0]
	assert_false(SpellProtection.is_player_spell_disabled(player, {}), "禁呪解除済")
