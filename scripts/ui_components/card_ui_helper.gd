class_name CardUIHelper
extends RefCounted

## カードUI計算用のヘルパークラス
## 手札表示やカード選択UIで使用される共通計算ロジックを提供

# カード表示の定数
const CARD_WIDTH = 290
const CARD_HEIGHT = 390
const CARD_SPACING = 30
const MAX_SCREEN_WIDTH_RATIO = 0.77

## カードレイアウトを計算
## @param viewport_size: ビューポートのサイズ
## @param card_count: 表示するカード枚数
## @return Dictionary: レイアウト情報（scale, card_width, card_height, spacing, total_width, start_x, card_y）
static func calculate_card_layout(viewport_size: Vector2, card_count: int) -> Dictionary:
	# 画面幅の80%を最大幅とする
	var max_width = viewport_size.x * MAX_SCREEN_WIDTH_RATIO
	
	# 通常サイズでの全体幅を計算
	var normal_total_width = card_count * CARD_WIDTH + (card_count - 1) * CARD_SPACING
	
	# スケール率を計算（最大幅を超える場合は縮小）
	var scale = 1.0
	if normal_total_width > max_width:
		scale = max_width / normal_total_width
	
	# 縮小後のサイズを計算
	var scaled_card_width = CARD_WIDTH * scale
	var scaled_card_height = CARD_HEIGHT * scale
	var scaled_spacing = CARD_SPACING * scale
	
	# 実際の全体幅を計算
	var total_width = card_count * scaled_card_width + (card_count - 1) * scaled_spacing
	var start_x = (viewport_size.x - total_width) / 2
	var card_y = viewport_size.y - scaled_card_height - 20
	
	return {
		"scale": scale,
		"card_width": scaled_card_width,
		"card_height": scaled_card_height,
		"spacing": scaled_spacing,
		"total_width": total_width,
		"start_x": start_x,
		"card_y": card_y
	}
