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

# バーサイズ（4倍 × 1.3 = 5.2倍）
const HP_BAR_WIDTH = 1040.0
const HP_BAR_HEIGHT = 125.0
const AP_BAR_WIDTH = 1040.0
const AP_BAR_HEIGHT = 83.0
const BAR_SPACING = 21.0

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

var _damage_flash_amount := 0.0

# ノード参照
var hp_label: Label
var ap_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT + AP_BAR_HEIGHT + BAR_SPACING)
	_setup_labels()
	queue_redraw()


func _setup_labels() -> void:
	# HPラベル（フォントサイズ5.2倍）
	hp_label = Label.new()
	hp_label.position = Vector2(0, 0)
	hp_label.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 72)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 10)
	add_child(hp_label)
	
	# APラベル（フォントサイズ5.2倍）
	ap_label = Label.new()
	ap_label.position = Vector2(0, HP_BAR_HEIGHT + BAR_SPACING)
	ap_label.size = Vector2(AP_BAR_WIDTH, AP_BAR_HEIGHT)
	ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ap_label.add_theme_font_size_override("font_size", 62)
	ap_label.add_theme_color_override("font_color", Color.WHITE)
	ap_label.add_theme_color_override("font_outline_color", Color.BLACK)
	ap_label.add_theme_constant_override("outline_size", 10)
	add_child(ap_label)


func _draw() -> void:
	_draw_hp_bar()
	_draw_ap_bar()


## HPバーを描画
## バトルシステムの実データに従って描画：
## - バーの最大値は100固定（100以上でもバーは100%で止まる）
## - 数値ラベルは実際の値を表示
func _draw_hp_bar() -> void:
	var bar_rect = Rect2(0, 0, HP_BAR_WIDTH, HP_BAR_HEIGHT)
	
	# 背景（灰色）
	draw_rect(bar_rect, COLOR_GRAY)
	
	# バーの最大値は100固定
	const BAR_MAX = 100.0
	
	# HP0チェック：current_hp <= 0なら全セグメントを0として描画
	var is_dead = hp_data.get("current_hp", 0) <= 0
	
	# 各セグメントの現在残り値（実データから直接取得）
	# マイナスのtemporary_bonus_hpはcurrent_hpに既に反映済み（スペクター、呪い等）
	var green_remaining = 0 if is_dead else hp_data["current_hp"] + hp_data["item_bonus_hp"]
	var cyan_remaining = 0 if is_dead else hp_data["resonance_bonus_hp"] + hp_data["temporary_bonus_hp"] + hp_data["spell_bonus_hp"]
	var yellow_remaining = 0 if is_dead else hp_data["land_bonus_hp"]
	
	# 描画（左から右: 緑 → 水色 → 黄）
	var x_offset = 0.0
	
	# 緑セグメント（current_hp + item_bonus_hp）
	if green_remaining > 0:
		var green_width = minf((float(green_remaining) / BAR_MAX) * HP_BAR_WIDTH, HP_BAR_WIDTH - x_offset)
		if green_width > 0:
			draw_rect(Rect2(x_offset, 0, green_width, HP_BAR_HEIGHT), COLOR_GREEN)
		x_offset += green_width
	
	# 水色セグメント（感応 + 一時 + スペル）
	if cyan_remaining > 0 and x_offset < HP_BAR_WIDTH:
		var cyan_width = minf((float(cyan_remaining) / BAR_MAX) * HP_BAR_WIDTH, HP_BAR_WIDTH - x_offset)
		if cyan_width > 0:
			draw_rect(Rect2(x_offset, 0, cyan_width, HP_BAR_HEIGHT), COLOR_CYAN)
		x_offset += cyan_width
	
	# 黄色セグメント（土地ボーナス）
	if yellow_remaining > 0 and x_offset < HP_BAR_WIDTH:
		var yellow_width = minf((float(yellow_remaining) / BAR_MAX) * HP_BAR_WIDTH, HP_BAR_WIDTH - x_offset)
		if yellow_width > 0:
			draw_rect(Rect2(x_offset, 0, yellow_width, HP_BAR_HEIGHT), COLOR_YELLOW)
	
	# ダメージフラッシュ（赤いオーバーレイ）
	if _damage_flash_amount > 0:
		var flash_color = COLOR_RED
		flash_color.a = _damage_flash_amount * 0.5
		draw_rect(bar_rect, flash_color)
	
	# 枠線（5.2倍の太さ）
	draw_rect(bar_rect, Color.WHITE, false, 10.0)


## APバーを描画
func _draw_ap_bar() -> void:
	var y_offset = HP_BAR_HEIGHT + BAR_SPACING
	var bar_rect = Rect2(0, y_offset, AP_BAR_WIDTH, AP_BAR_HEIGHT)
	
	# 背景（灰色）
	draw_rect(bar_rect, COLOR_GRAY)
	
	# APバー（単色青）- 最大値は100固定
	const BAR_MAX = 100.0
	var filled_width = minf((float(current_ap) / BAR_MAX) * AP_BAR_WIDTH, AP_BAR_WIDTH)
	if filled_width > 0:
		draw_rect(Rect2(0, y_offset, filled_width, AP_BAR_HEIGHT), COLOR_BLUE)
	
	# 枠線（5.2倍の太さ）
	draw_rect(bar_rect, Color.WHITE, false, 10.0)


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
## 表示形式: "現在HP / 基本HP+一時バフ+土地ボーナス"
## 例: "50 / 30+10+10"
func _update_hp_label() -> void:
	if hp_label:
		# 基本HP（緑セグメント: base + base_up + item）
		# HP0チェック：current_hp <= 0なら現在値を0として表示
		var is_dead = hp_data.get("current_hp", 0) <= 0
		
		var base_hp = hp_data["base_hp"] + hp_data["base_up_hp"] + hp_data["item_bonus_hp"]
		# 一時バフ（水色セグメント: 感応 + 一時 + スペル）
		var cyan_bonus = hp_data["resonance_bonus_hp"] + hp_data["temporary_bonus_hp"] + hp_data["spell_bonus_hp"]
		# 土地ボーナス（黄色セグメント）
		var yellow_bonus = hp_data["land_bonus_hp"]
		
		# 現在値 = current_hp + ボーナス（マイナスのtemporary_bonus_hpはcurrent_hpに反映済み）
		var current: int
		if is_dead:
			current = 0
		else:
			var temp_bonus = hp_data["temporary_bonus_hp"] if hp_data["temporary_bonus_hp"] > 0 else 0
			current = hp_data["current_hp"] + hp_data["item_bonus_hp"] + \
					  hp_data["resonance_bonus_hp"] + temp_bonus + \
					  hp_data["spell_bonus_hp"] + hp_data["land_bonus_hp"]
		
		# 表示文字列を構築
		var max_text = str(base_hp)
		if cyan_bonus != 0:
			if cyan_bonus > 0:
				max_text += "+%d" % cyan_bonus
			else:
				max_text += "%d" % cyan_bonus  # マイナスはそのまま表示
		if yellow_bonus > 0:
			max_text += "+%d" % yellow_bonus
		
		hp_label.text = "%d / %s" % [current, max_text]


## APラベルを更新
func _update_ap_label() -> void:
	if ap_label:
		ap_label.text = str(current_ap)


## HPをアニメーション付きで更新（全ボーナス値もアニメーション）
func animate_hp_change(new_hp_data: Dictionary, duration: float = 1.5):
	if not is_inside_tree():
		return
	var old_hp_data = hp_data.duplicate()
	var new_hp_data_copy = new_hp_data.duplicate()
	
	# 全HP合計の計算（ダメージフラッシュ用）
	var old_total = _get_total_hp(old_hp_data)
	var new_total = _get_total_hp(new_hp_data_copy)
	
	# ダメージの場合はフラッシュ
	if new_total < old_total:
		_damage_flash_amount = 1.0
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "_damage_flash_amount", 0.0, 0.2)
	
	# display_maxも更新
	hp_data["display_max"] = new_hp_data_copy.get("display_max", hp_data.get("display_max", 100))
	
	# アニメーション（0.0 → 1.0 の補間値を使用）
	var tween = create_tween()
	tween.tween_method(func(t: float): _interpolate_hp_data(old_hp_data, new_hp_data_copy, t), 0.0, 1.0, duration)
	await tween.finished
	
	# 最終値を確定
	set_hp_data(new_hp_data_copy)


## HP値を補間（右から順に消費：黄色→水色→緑）
func _interpolate_hp_data(old_data: Dictionary, new_data: Dictionary, t: float) -> void:
	# 各セグメントの元の値
	var old_yellow = old_data["land_bonus_hp"]
	var old_cyan = old_data["resonance_bonus_hp"] + old_data["temporary_bonus_hp"] + old_data["spell_bonus_hp"]
	var old_green = old_data["current_hp"] + old_data["item_bonus_hp"]
	
	# 各セグメントの最終値
	var new_yellow = new_data["land_bonus_hp"]
	var new_cyan = new_data["resonance_bonus_hp"] + new_data["temporary_bonus_hp"] + new_data["spell_bonus_hp"]
	var new_green = new_data["current_hp"] + new_data["item_bonus_hp"]
	
	# 総ダメージ量
	var old_total = old_yellow + old_cyan + old_green
	var new_total = new_yellow + new_cyan + new_green
	var total_damage = old_total - new_total
	
	if total_damage <= 0:
		# ダメージではなく回復の場合は単純補間
		hp_data["land_bonus_hp"] = int(lerp(float(old_yellow), float(new_yellow), t))
		hp_data["resonance_bonus_hp"] = int(lerp(float(old_data["resonance_bonus_hp"]), float(new_data["resonance_bonus_hp"]), t))
		hp_data["temporary_bonus_hp"] = int(lerp(float(old_data["temporary_bonus_hp"]), float(new_data["temporary_bonus_hp"]), t))
		hp_data["spell_bonus_hp"] = int(lerp(float(old_data["spell_bonus_hp"]), float(new_data["spell_bonus_hp"]), t))
		hp_data["current_hp"] = int(lerp(float(old_data["current_hp"]), float(new_data["current_hp"]), t))
		hp_data["item_bonus_hp"] = int(lerp(float(old_data["item_bonus_hp"]), float(new_data["item_bonus_hp"]), t))
	else:
		# ダメージの場合：右から順に削る
		var damage_applied = int(total_damage * t)
		var remaining_damage = damage_applied
		
		# 1. 黄色（土地ボーナス）から削る
		var yellow_damage = mini(remaining_damage, old_yellow)
		var current_yellow = old_yellow - yellow_damage
		remaining_damage -= yellow_damage
		
		# 2. 水色（感応+一時+スペル）から削る
		var cyan_damage = mini(remaining_damage, old_cyan)
		var current_cyan = old_cyan - cyan_damage
		remaining_damage -= cyan_damage
		
		# 3. 緑（current_hp + item_bonus_hp）から削る
		var green_damage = mini(remaining_damage, old_green)
		var current_green = old_green - green_damage
		
		# 値を設定
		hp_data["land_bonus_hp"] = current_yellow
		
		# 水色セグメントの内訳を比率で分配
		if old_cyan > 0:
			var cyan_ratio = float(current_cyan) / float(old_cyan)
			hp_data["resonance_bonus_hp"] = int(old_data["resonance_bonus_hp"] * cyan_ratio)
			hp_data["temporary_bonus_hp"] = int(old_data["temporary_bonus_hp"] * cyan_ratio)
			hp_data["spell_bonus_hp"] = int(old_data["spell_bonus_hp"] * cyan_ratio)
		else:
			hp_data["resonance_bonus_hp"] = 0
			hp_data["temporary_bonus_hp"] = 0
			hp_data["spell_bonus_hp"] = 0
		
		# 緑セグメントの内訳を比率で分配
		if old_green > 0:
			var green_ratio = float(current_green) / float(old_green)
			hp_data["current_hp"] = int(old_data["current_hp"] * green_ratio)
			hp_data["item_bonus_hp"] = int(old_data["item_bonus_hp"] * green_ratio)
		else:
			hp_data["current_hp"] = 0
			hp_data["item_bonus_hp"] = 0
	
	_update_hp_label()
	queue_redraw()


## 全HP合計を取得
func _get_total_hp(data: Dictionary) -> int:
	return data.get("current_hp", 0) + data.get("item_bonus_hp", 0) + \
		   data.get("resonance_bonus_hp", 0) + data.get("temporary_bonus_hp", 0) + \
		   data.get("spell_bonus_hp", 0) + data.get("land_bonus_hp", 0)


## APをアニメーション付きで更新
func animate_ap_change(new_ap: int, duration: float = 1.5):
	if not is_inside_tree():
		return
	var old_ap = current_ap
	var tween = create_tween()
	tween.tween_method(func(value: float): _update_displayed_ap(int(value)), float(old_ap), float(new_ap), duration)
	await tween.finished


## AP表示を更新（アニメーション用）
func _update_displayed_ap(value: int) -> void:
	current_ap = value
	_update_ap_label()
	queue_redraw()