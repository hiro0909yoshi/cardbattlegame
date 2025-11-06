class_name CardUIHelper
extends RefCounted

## カードUI計算用のヘルパークラス
## 手札表示やカード選択UIで使用される共通計算ロジックを提供

# カード表示の定数
const CARDFRAME_WIDTH = 220  # Card.tscnの実際のサイズ
const CARDFRAME_HEIGHT = 293
const GAME_CARD_WIDTH = 290   # ゲーム内での表示サイズ
const GAME_CARD_HEIGHT = 390
const BASE_SCALE = 1.318      # 290 / 220 = 1.318 (CardFrameをゲーム内サイズに拡大)
const CARD_SPACING = 30
const MAX_SCREEN_WIDTH_RATIO = 0.77

# 後方互換性のため
const CARD_WIDTH = GAME_CARD_WIDTH
const CARD_HEIGHT = GAME_CARD_HEIGHT

## カードレイアウトを計算
## @param viewport_size: ビューポートのサイズ
## @param card_count: 表示するカード枚数
## @return Dictionary: レイアウト情報（scale, card_width, card_height, spacing, total_width, start_x, card_y）
static func calculate_card_layout(viewport_size: Vector2, card_count: int) -> Dictionary:
	# 画面幅の80%を最大幅とする
	var max_width = viewport_size.x * MAX_SCREEN_WIDTH_RATIO
	
	# ゲーム内表示サイズ（290×390）での全体幅を計算
	var normal_total_width = card_count * GAME_CARD_WIDTH + (card_count - 1) * CARD_SPACING
	
	# スケール率を計算（最大幅を超える場合は縮小）
	var scale = 1.0
	if normal_total_width > max_width:
		scale = max_width / normal_total_width
	
	# BASE_SCALEを適用（220×293 → 290×390）
	var final_scale = scale * BASE_SCALE
	
	
	# 拡大・縮小後のサイズを計算（CardFrameサイズ × final_scale）
	var scaled_card_width = CARDFRAME_WIDTH * final_scale
	var scaled_card_height = CARDFRAME_HEIGHT * final_scale
	var scaled_spacing = CARD_SPACING * scale  # スペーシングは通常のscaleのみ
	
	# 実際の全体幅を計算
	var total_width = card_count * scaled_card_width + (card_count - 1) * scaled_spacing
	var start_x = (viewport_size.x - total_width) / 2
	var card_y = viewport_size.y - scaled_card_height - 20
	
	return {
		"scale": final_scale,  # CardFrame用の最終スケール
		"card_width": scaled_card_width,
		"card_height": scaled_card_height,
		"spacing": scaled_spacing,
		"total_width": total_width,
		"start_x": start_x,
		"card_y": card_y
	}
