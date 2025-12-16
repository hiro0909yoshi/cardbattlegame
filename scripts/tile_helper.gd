class_name TileHelper
extends RefCounted

## タイル判定ヘルパー
##
## クリーチャー配置・移動・地形変化等のタイル判定を一元管理
## タイル追加時はこのファイルの定数のみ修正すればOK


# ===========================================
# タイルタイプ定数
# ===========================================

## 配置可能タイル（クリーチャーを置ける）6種
const PLACEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank"]

## 属性タイル（4属性）
const ELEMENT_TILES = ["fire", "water", "earth", "wind"]

## 停止不可タイル（通過型）
const NO_STOP_TILES = ["warp"]

## 特殊タイル（配置不可）
const SPECIAL_TILES = [
	"checkpoint", "warp", "warp_stop",
	"card_buy", "card_give",
	"magic", "magic_stone",
	"switch", "base"
]

## 地形変化可能タイル
const TERRAIN_CHANGEABLE_TILES = ["fire", "water", "earth", "wind", "neutral", "blank"]


# ===========================================
# 判定メソッド
# ===========================================

## 配置可能なタイルか（6種: fire/water/earth/wind/neutral/blank）
static func is_placeable_tile(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in PLACEABLE_TILES


## 特殊タイルか（配置不可）
static func is_special_tile(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in SPECIAL_TILES


## クリーチャー配置可能か（タイル種別＋空きチェック）
static func can_place_creature(tile) -> bool:
	if not is_placeable_tile(tile):
		return false
	# クリーチャーがいない
	if tile.creature_data != null and not tile.creature_data.is_empty():
		return false
	return true


## 空き地か（所有者がいない配置可能タイル）
static func is_empty_land(tile) -> bool:
	if not can_place_creature(tile):
		return false
	return tile.owner_id == -1


## 移動先として停止可能か
static func can_stop_at(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type not in NO_STOP_TILES


## 地形変化可能か
static func can_change_terrain(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in TERRAIN_CHANGEABLE_TILES


## 地形効果があるタイルか（属性タイル + neutral）
static func has_land_effect(tile) -> bool:
	if not tile:
		return false
	# 属性タイル + neutralは地形効果あり（blankは配置時に変化するので含まない）
	return tile.tile_type in ELEMENT_TILES or tile.tile_type == "neutral"


## 属性タイルか（4属性: fire/water/earth/wind）
static func is_element_tile(tile) -> bool:
	if not tile:
		return false
	return tile.tile_type in ELEMENT_TILES


## tile_typeから判定（tileオブジェクトがない場合用）
static func is_placeable_type(tile_type: String) -> bool:
	return tile_type in PLACEABLE_TILES


static func is_special_type(tile_type: String) -> bool:
	return tile_type in SPECIAL_TILES


static func is_element_type(tile_type: String) -> bool:
	return tile_type in ELEMENT_TILES


static func can_stop_at_type(tile_type: String) -> bool:
	return tile_type not in NO_STOP_TILES


static func can_change_terrain_type(tile_type: String) -> bool:
	return tile_type in TERRAIN_CHANGEABLE_TILES


## 地形効果を持つタイルか（属性タイル + neutral）- tile_type版
static func has_land_effect_type(tile_type: String) -> bool:
	return tile_type in ELEMENT_TILES or tile_type == "neutral"
