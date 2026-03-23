extends GutTest

## 刻印除去系テスト
## SpellPurify の各除去メソッド + purify_allの統合テスト

const Helper = preload("res://test/spell/spell_test_helper.gd")

var _player_system: PlayerSystem
var _creature_manager: CreatureManager
var _game_stats: Dictionary
var _purify_board: BoardSystem3D
var _purify_gfm: GameFlowManager


func before_each():
	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_Test"
	add_child(_player_system)
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "術者"
	p0.magic_power = 1000
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "対象"
	p1.magic_power = 500
	_player_system.players = [p0, p1]

	_creature_manager = CreatureManager.new()
	_creature_manager.name = "CreatureManager_Test"
	add_child(_creature_manager)
	_game_stats = {}


func after_each():
	if is_instance_valid(_purify_board):
		_purify_board.free()
	if is_instance_valid(_purify_gfm):
		_purify_gfm.free()
	if is_instance_valid(_player_system):
		_player_system.free()
	if is_instance_valid(_creature_manager):
		_creature_manager.free()


## SpellPurifyを生成（_initがGFM必須なのでモックを使う）
func _create_purify() -> SpellPurify:
	_purify_board = BoardSystem3D.new()
	_purify_board.name = "BoardSystem3D_Purify"
	add_child(_purify_board)
	_purify_board.tile_nodes = Helper.create_tile_nodes()
	# GFMモック
	_purify_gfm = GameFlowManager.new()
	_purify_gfm.name = "GFM_Purify"
	add_child(_purify_gfm)
	var purify = SpellPurify.new(_purify_board, _creature_manager, _player_system, _purify_gfm)
	purify.game_stats = _game_stats
	return purify


## JSON定義からeffect_typeを取得
func _get_effect_type(spell_id: int) -> String:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		var et = e.get("effect_type", "")
		if et.begins_with("purify") or et.begins_with("remove_"):
			return et
	return ""


# ========================================
# JSON定義確認
# ========================================

## キュア(2073): purify_all
func test_cure_json():
	assert_eq(_get_effect_type(2073), "purify_all", "キュア: purify_all")

## ディスペル(9024): remove_creature_curse
func test_dispel_json():
	assert_eq(_get_effect_type(9024), "remove_creature_curse", "ディスペル: remove_creature_curse")

## ワールドディスペル(9025): remove_world_curse
func test_world_dispel_json():
	assert_eq(_get_effect_type(9025), "remove_world_curse", "ワールドディスペル: remove_world_curse")

## 浄化の炎(9026): remove_all_player_curses
func test_purify_flame_json():
	assert_eq(_get_effect_type(9026), "remove_all_player_curses", "浄化の炎: remove_all_player_curses")


# ========================================
# remove_creature_curse: クリーチャー刻印除去
# ========================================

## 刻印付きクリーチャーの刻印を除去
func test_remove_creature_curse():
	# クリーチャーに刻印を付与
	_creature_manager.creatures[5] = {
		"name": "テストクリーチャー",
		"hp": 30, "ap": 20,
		"curse": {"curse_type": "stat_reduce", "name": "零落", "duration": 3},
	}
	var purify = _create_purify()
	var result = purify.remove_creature_curse(5)
	assert_true(result, "刻印除去成功")
	assert_false(_creature_manager.creatures[5].has("curse"), "curseキーが消えた")


## 刻印なしクリーチャー → 失敗
func test_remove_creature_curse_no_curse():
	_creature_manager.creatures[5] = {
		"name": "テストクリーチャー",
		"hp": 30, "ap": 20,
	}
	var purify = _create_purify()
	var result = purify.remove_creature_curse(5)
	assert_false(result, "刻印なし: 除去失敗")


# ========================================
# remove_world_curse: 世界刻印除去
# ========================================

## 世界刻印を除去
func test_remove_world_curse():
	_game_stats["world_curse"] = {
		"curse_type": "land_protect",
		"name": "皇帝",
		"duration": 6,
	}
	var purify = _create_purify()
	var result = purify.remove_world_curse()
	assert_true(result, "世界刻印除去成功")
	assert_false(_game_stats.has("world_curse"), "world_curseが消えた")


## 世界刻印なし → 失敗
func test_remove_world_curse_none():
	var purify = _create_purify()
	var result = purify.remove_world_curse()
	assert_false(result, "世界刻印なし: 除去失敗")


## 除去後、インペリアルガードが無効になる
func test_remove_world_curse_effect():
	_game_stats["world_curse"] = {
		"curse_type": "land_protect",
		"name": "皇帝",
		"duration": 6,
	}
	# 除去前: ブロック有効
	assert_true(SpellWorldCurse.is_land_change_blocked(_game_stats), "除去前: ブロック有効")
	var purify = _create_purify()
	purify.remove_world_curse()
	# 除去後: ブロック無効
	assert_false(SpellWorldCurse.is_land_change_blocked(_game_stats), "除去後: ブロック無効")


# ========================================
# remove_all_player_curses: 全プレイヤー刻印除去
# ========================================

## 2人のプレイヤー刻印を除去
func test_remove_all_player_curses():
	_player_system.players[0].curse = {"curse_type": "spell_disable", "name": "禁呪"}
	_player_system.players[1].curse = {"curse_type": "spell_protection", "name": "祝福"}
	var purify = _create_purify()
	var count = purify.remove_all_player_curses()
	assert_eq(count, 2, "2人分除去")
	assert_true(_player_system.players[0].curse.is_empty(), "P0刻印消えた")
	assert_true(_player_system.players[1].curse.is_empty(), "P1刻印消えた")


## 刻印なしプレイヤーは0
func test_remove_all_player_curses_none():
	var purify = _create_purify()
	var count = purify.remove_all_player_curses()
	assert_eq(count, 0, "刻印なし: 0")


## 除去後、禁呪が解除されスペル使用可能に
func test_remove_player_curse_effect():
	_player_system.players[0].curse = {"curse_type": "spell_disable", "name": "禁呪"}
	assert_true(SpellProtection.is_player_spell_disabled(_player_system.players[0], {}), "除去前: 禁呪有効")
	var purify = _create_purify()
	purify.remove_all_player_curses()
	assert_false(SpellProtection.is_player_spell_disabled(_player_system.players[0], {}), "除去後: スペル使用可能")


# ========================================
# purify_all: 全刻印除去+蓄魔
# ========================================

## クリーチャー刻印+プレイヤー刻印+世界刻印 → 全除去+蓄魔
func test_purify_all_comprehensive():
	# クリーチャー刻印
	_creature_manager.creatures[5] = {
		"name": "テスト", "hp": 30, "ap": 20,
		"curse": {"curse_type": "stat_reduce", "name": "零落"},
	}
	# プレイヤー刻印
	_player_system.players[0].curse = {"curse_type": "spell_disable", "name": "禁呪"}
	# 世界刻印
	_game_stats["world_curse"] = {"curse_type": "land_protect", "name": "皇帝", "duration": 6}

	var purify = _create_purify()
	var result = purify.purify_all(0)
	var removed = result.get("removed_types", [])
	var ep = result.get("ep_gained", 0)

	# 3種類の刻印が除去された
	assert_true(removed.size() >= 2, "2種類以上の刻印除去")
	# 蓄魔: 種類数 × 50EP
	assert_eq(ep, removed.size() * 50, "蓄魔: %d種 × 50EP = %dEP" % [removed.size(), ep])

	# 全刻印が消えていることを確認
	assert_false(_game_stats.has("world_curse"), "世界刻印消えた")
	assert_true(_player_system.players[0].curse.is_empty(), "P0刻印消えた")


## 刻印なし → 蓄魔0
func test_purify_all_no_curses():
	var purify = _create_purify()
	var result = purify.purify_all(0)
	assert_eq(result.get("ep_gained", -1), 0, "刻印なし: 蓄魔0")
	assert_eq(result.get("removed_types", []).size(), 0, "除去数0")
