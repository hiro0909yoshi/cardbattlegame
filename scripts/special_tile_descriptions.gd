class_name SpecialTileDescriptions
extends RefCounted

## 特殊タイル説明データ
## Help画面の一覧表示と、クエスト中の個別表示の両方で使用

# タイル表示順序
const TILE_ORDER = [
	"checkpoint", "warp", "warp_stop", "card_buy", "card_give",
	"magic", "magic_stone", "branch", "base"
]

# 各タイルの説明データ
const TILES = {
	"checkpoint": {
		"name": "チェックポイント",
		"color_hex": "FFE64D",
		"color": Color(1.0, 0.9, 0.3),
		"description": "・通過するとEPボーナスを獲得\n・全チェックポイント通過で周回完了、大きなボーナスが得られる\n・停止時に自分の全クリーチャーのダウン状態を解除"
	},
	"warp": {
		"name": "ワープ（通過型）",
		"color_hex": "FF8000",
		"color": Color(1.0, 0.5, 0.0),
		"description": "・停止せずに通過するワープゲート\n・対になるワープタイルへ即座に移動する"
	},
	"warp_stop": {
		"name": "ワープ（停止型）",
		"color_hex": "CC4DCC",
		"color": Color(0.8, 0.3, 0.8),
		"description": "・停止してからワープするタイル\n・対になるワープタイルへ移動後、移動先のタイルアクションが発生する"
	},
	"card_buy": {
		"name": "カード購入",
		"color_hex": "4DCCCC",
		"color": Color(0.3, 0.8, 0.8),
		"description": "・EPを支払ってカードを購入できるタイル\n・ランダムに提示されるカードから選んで手札に加える"
	},
	"card_give": {
		"name": "カード配布",
		"color_hex": "4DCCCC",
		"color": Color(0.3, 0.8, 0.8),
		"description": "・無料でカードを1枚もらえるタイル\n・ランダムなカードが手札に追加される"
	},
	"magic": {
		"name": "魔法陣",
		"color_hex": "E64DE6",
		"color": Color(0.9, 0.3, 0.9),
		"description": "・マップ上の好きなタイルへワープできる\n・プレイヤーが移動先を選択する"
	},
	"magic_stone": {
		"name": "魔法石",
		"color_hex": "B380E6",
		"color": Color(0.7, 0.5, 0.9),
		"description": "・魔法石を獲得できるタイル\n・魔法石は特殊な効果を持つアイテムとして使用できる"
	},
	"branch": {
		"name": "分岐",
		"color_hex": "FFB34D",
		"color": Color(1.0, 0.7, 0.3),
		"description": "・進行方向を選択できる分岐タイル\n・複数の経路から好きな方向を選んで進む"
	},
	"base": {
		"name": "拠点",
		"color_hex": "80E680",
		"color": Color(0.5, 0.9, 0.5),
		"description": "・空いている土地を選んでクリーチャーを遠隔召喚できる\n・手札からクリーチャーを選び、離れた場所に配置する"
	},
}

## 個別タイル説明を取得（クエスト中のインフォメーション表示用）
## tile_key: "checkpoint", "warp", "card_buy" 等
static func get_tile_info(tile_key: String) -> Dictionary:
	if TILES.has(tile_key):
		return TILES[tile_key]
	return {}

## BBCode形式で個別タイル説明を取得
static func get_bbcode(tile_key: String, font_size: int = 56) -> String:
	var info = get_tile_info(tile_key)
	if info.is_empty():
		return ""
	var text = "[font_size=%d]" % font_size
	text += "[b][color=%s]%s[/color][/b]\n" % [info.color_hex, info.name]
	text += "%s" % info.description
	text += "[/font_size]"
	return text
