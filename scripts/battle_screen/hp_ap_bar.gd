class_name HpApBar
extends Control

## HP/APバーコンポーネント
## HPバーは複合セグメント構造、APバーは単色

# 色定義
const COLOR_GREEN = Color("#4CAF50")      # 緑: base_hp + base_up_hp + item_bonus_hp
const COLOR_CYAN = Color("#03A9F4")       # 水色: 感応 + 一時 + スペル
const COLOR_YELLOW = Color("#FFC107")     # 黄: 土地ボーナス
const COLOR_GRAY = Color("#424242")       # 灰: 空
const COLOR_RED = Color("#F44336")        # 赤: ダメージ演出
const COLOR_BLUE = Color("#2196F3")       # 青: APバー

# バーサイズ
const HP_BAR_WIDTH = 200.0
const HP_BAR_HEIGHT = 24.0
const AP_BAR_WIDTH = 200.0
const AP_BAR_HEIGHT = 16.0
const BAR_SPACING = 4.0

# HPデータ
var hp_data := {
	"base_hp": 0,
	"base_up_hp": 0,
	"item_bonus_hp": 0,
	"resonance_bonus_hp": 0,
	"temporary_bonus_hp": 0,
	"spell_bonus_hp": 0,
	"land_bonus_hp": 0,
	"current_hp": 0,
	"display_max": 100
}

# APデータ
var current_ap := 0
var max_ap := 100

# 内部状態
var _displayed_hp := 0.0  # アニメーション用
var _damage_flash_amount := 0.0

# ノード参照
var hp_label: Label
var ap_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT + AP_BAR_HEIGHT + BAR_SPACING)
	_setup_labels()
	queue_redraw()


func _setup_labels() -> void:
	# HPラベル
	hp_label = Label.new()
	hp_label.position = Vector2(0, 0)
	hp_label.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 2)
	add_child(hp_label)
	
	# APラベル
	ap_label = Label.new()
	ap_label.position = Vector2(0, HP_BAR_HEIGHT + BAR_SPACING)
	ap_label.size = Vector2(AP_BAR_WIDTH, AP_BAR_HEIGHT)
	ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ap_label.add_theme_font_size_override("font_size", 12)
	ap_label.add_theme_color_override("font_color", Color.WHITE)
	ap_label.add_theme_color_override("font_outline_color", Color.BLACK)
	ap_label.add_theme_constant_override("outline_size", 2)
	add_child(ap_label)


func _draw() -> void:
	_draw_hp_bar()
	_draw_ap_bar()


## HPバーを描画
func _draw_hp_bar() -> void:
	var bar_rect = Rect2(0, 0, HP_BAR_WIDTH, HP_BAR_HEIGHT)
	
	# 背景（灰色）
	draw_rect(bar_rect, COLOR_GRAY)
	
	# 各セグメントの幅を計算
	var display_max = max(hp_data["display_max"], 1)
	var green_value = hp_data["base_hp"] + hp_data["base_up_hp"] + hp_data["item_bonus_hp"]
	var cyan_value = hp_data["resonance_bonus_hp"] + hp_data["temporary_bonus_hp"] + hp_data["spell_bonus_hp"]
	var yellow_value = hp_data["land_bonus_hp"]
	
	# 現在HPに基づいて表示を調整
	var current = hp_data["current_hp"]
	
	# 消費は右から左（黄→水色→緑の順）
	# 現在HPから各セグメントの残り量を計算
	var remaining = current
	
	# 黄色セグメント（最初に消費される）- 残りから計算
	var yellow_remaining = 0
	if remaining > green_value + cyan_value:
		yellow_remaining = mini(remaining - green_value - cyan_value, yellow_value)
	
	# 水色セグメント
	var cyan_remaining = 0
	if remaining > green_value:
		cyan_remaining = mini(remaining - green_value, cyan_value)
	
	# 緑セグメント（最後に消費される）
	var green_remaining = mini(remaining, green_value)
	
	# 描画（左から右: 緑 → 水色 → 黄）
	var x_offset = 0.0
	
	# 緑セグメント
	if green_value > 0:
		var green_filled_width = (float(green_remaining) / display_max) * HP_BAR_WIDTH
		if green_filled_width > 0:
			draw_rect(Rect2(x_offset, 0, green_filled_width, HP_BAR_HEIGHT), COLOR_GREEN)
		x_offset += (float(green_value) / display_max) * HP_BAR_WIDTH
	
	# 水色セグメント
	if cyan_value > 0:
		var cyan_filled_width = (float(cyan_remaining) / display_max) * HP_BAR_WIDTH
		if cyan_filled_width > 0:
			draw_rect(Rect2(x_offset, 0, cyan_filled_width, HP_BAR_HEIGHT), COLOR_CYAN)
		x_offset += (float(cyan_value) / display_max) * HP_BAR_WIDTH
	
	# 黄色セグメント
	if yellow_value > 0:
		var yellow_filled_width = (float(yellow_remaining) / display_max) * HP_BAR_WIDTH
		if yellow_filled_width > 0:
			draw_rect(Rect2(x_offset, 0, yellow_filled_width, HP_BAR_HEIGHT), COLOR_YELLOW)
	
	# ダメージフラッシュ（赤いオーバーレイ）
	if _damage_flash_amount > 0:
		var flash_color = COLOR_RED
		flash_color.a = _damage_flash_amount * 0.5
		draw_rect(bar_rect, flash_color)
	
	# 枠線
	draw_rect(bar_rect, Color.WHITE, false, 2.0)


## APバーを描画
func _draw_ap_bar() -> void:
	var y_offset = HP_BAR_HEIGHT + BAR_SPACING
	var bar_rect = Rect2(0, y_offset, AP_BAR_WIDTH, AP_BAR_HEIGHT)
	
	# 背景（灰色）
	draw_rect(bar_rect, COLOR_GRAY)
	
	# APバー（単色青）
	var ap_ratio = float(current_ap) / max(max_ap, 1)
	var filled_width = ap_ratio * AP_BAR_WIDTH
	if filled_width > 0:
		draw_rect(Rect2(0, y_offset, filled_width, AP_BAR_HEIGHT), COLOR_BLUE)
	
	# 枠線
	draw_rect(bar_rect, Color.WHITE, false, 2.0)


## HPデータを設定
func set_hp_data(data: Dictionary) -> void:
	hp_data = data.duplicate()
	_update_hp_label()
	queue_redraw()


## APを設定
func set_ap(value: int, max_value: int = 100) -> void:
	current_ap = value
	max_ap = max_value
	_update_ap_label()
	queue_redraw()


## HPラベルを更新
func _update_hp_label() -> void:
	if hp_label:
		var total = hp_data["base_hp"] + hp_data["base_up_hp"] + hp_data["item_bonus_hp"] + \
					hp_data["resonance_bonus_hp"] + hp_data["temporary_bonus_hp"] + \
					hp_data["spell_bonus_hp"] + hp_data["land_bonus_hp"]
		hp_label.text = "%d / %d" % [hp_data["current_hp"], total]


## APラベルを更新
func _update_ap_label() -> void:
	if ap_label:
		ap_label.text = str(current_ap)


## HPをアニメーション付きで更新
func animate_hp_change(new_hp_data: Dictionary, duration: float = 0.3):
	var old_current = hp_data["current_hp"]
	var new_current = new_hp_data["current_hp"]
	
	# ダメージの場合はフラッシュ
	if new_current < old_current:
		_damage_flash_amount = 1.0
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "_damage_flash_amount", 0.0, 0.2)
	
	# HPデータを更新
	hp_data = new_hp_data.duplicate()
	
	# アニメーション
	var tween = create_tween()
	tween.tween_method(_update_displayed_hp, float(old_current), float(new_current), duration)
	await tween.finished
	
	_update_hp_label()
	queue_redraw()


func _update_displayed_hp(value: float) -> void:
	_displayed_hp = value
	hp_data["current_hp"] = int(value)
	_update_hp_label()
	queue_redraw()


## APをアニメーション付きで更新
func animate_ap_change(new_ap: int, duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_property(self, "current_ap", new_ap, duration)
	tween.tween_callback(_update_ap_label)
	tween.tween_callback(queue_redraw)