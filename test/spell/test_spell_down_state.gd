extends GutTest

## ダウン操作系テスト
## ダウン状態の設定/解除 + JSON定義確認

const Helper = preload("res://test/spell/spell_test_helper.gd")


## JSON定義からeffect_typeを取得
func _get_effect_type(spell_id: int) -> String:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		var et = e.get("effect_type", "")
		if et == "set_down" or et == "clear_down" or et == "down_clear":
			return et
	return ""


# ========================================
# JSON定義確認
# ========================================

## ラリー(2005): down_clear
func test_rally_json():
	var et = _get_effect_type(2005)
	assert_true(et == "down_clear" or et == "clear_down", "ラリー: down_clear or clear_down")

## リジェネ(2121): clear_down（full_healも持つ）
func test_regen_json():
	var card = CardLoader.get_card_by_id(2121)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var has_clear_down = false
	var has_heal = false
	for e in effects:
		var et = e.get("effect_type", "")
		if et == "clear_down" or et == "down_clear":
			has_clear_down = true
		if et == "full_heal":
			has_heal = true
	assert_true(has_clear_down, "リジェネ: clear_down持ち")
	assert_true(has_heal, "リジェネ: full_heal持ち")

## スリープ(9037): set_down
func test_sleep_json():
	assert_eq(_get_effect_type(9037), "set_down", "スリープ: set_down")

## リバイブ(9044): clear_down
func test_revive_json():
	var et = _get_effect_type(9044)
	assert_true(et == "clear_down" or et == "down_clear", "リバイブ: clear_down or down_clear")


# ========================================
# ダウン状態の設定/解除（MockTile直接操作）
# ========================================

## set_down: ダウン状態にする
func test_set_down_state():
	var tile = Helper.MockTile.new()
	assert_false(tile.is_down(), "初期: ダウンなし")
	tile.set_down_state(true)
	assert_true(tile.is_down(), "ダウン状態設定")


## clear_down: ダウン状態を解除する
func test_clear_down_state():
	var tile = Helper.MockTile.new()
	tile.set_down_state(true)
	assert_true(tile.is_down(), "ダウン状態")
	tile.clear_down_state()
	assert_false(tile.is_down(), "ダウン解除")


## 連続操作: ダウン→解除→再ダウン
func test_down_toggle():
	var tile = Helper.MockTile.new()
	tile.set_down_state(true)
	assert_true(tile.is_down(), "1回目ダウン")
	tile.clear_down_state()
	assert_false(tile.is_down(), "解除")
	tile.set_down_state(true)
	assert_true(tile.is_down(), "2回目ダウン")


## 複数タイルの一括ダウン解除
func test_clear_down_multiple():
	var tiles = Helper.create_tile_nodes()
	# 3つのタイルをダウンにする
	tiles[1].set_down_state(true)
	tiles[3].set_down_state(true)
	tiles[5].set_down_state(true)
	assert_true(tiles[1].is_down(), "タイル1: ダウン")
	assert_true(tiles[3].is_down(), "タイル3: ダウン")
	assert_true(tiles[5].is_down(), "タイル5: ダウン")

	# 一括解除
	for i in tiles:
		tiles[i].clear_down_state()
	assert_false(tiles[1].is_down(), "タイル1: 解除")
	assert_false(tiles[3].is_down(), "タイル3: 解除")
	assert_false(tiles[5].is_down(), "タイル5: 解除")


## ダウン状態はクリーチャー配置とは独立
func test_down_independent_of_creature():
	var tile = Helper.MockTile.new()
	tile.creature_data = Helper.make_creature("テスト", 30, 20)
	tile.set_down_state(true)
	assert_true(tile.is_down(), "クリーチャーあり+ダウン")
	# クリーチャーを除去してもダウンは残る
	tile.remove_creature()
	assert_true(tile.is_down(), "クリーチャー除去後もダウン維持")


## ダウンなしタイルのclear_downは無害
func test_clear_down_on_non_down():
	var tile = Helper.MockTile.new()
	assert_false(tile.is_down(), "ダウンなし")
	tile.clear_down_state()
	assert_false(tile.is_down(), "clear_downしても問題なし")
