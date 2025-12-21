extends CanvasLayer

## アイテムフェーズ用バトルステータスオーバーレイ
## 通常画面上に攻撃側・防御側のクリーチャー情報を1つのパネルで表示

const OVERLAY_LAYER = 80  # 通常UIより上、バトル画面より下

var _container: Control
var _panel: Panel
var _attacker_labels: Dictionary = {}
var _defender_labels: Dictionary = {}
var _current_side: String = "attacker"

# 属性色
const ELEMENT_COLORS = {
	"fire": Color(1.0, 0.3, 0.2),
	"water": Color(0.2, 0.5, 1.0),
	"earth": Color(0.6, 0.4, 0.2),
	"wind": Color(0.2, 0.8, 0.4),
	"neutral": Color(0.7, 0.7, 0.7)
}

const ELEMENT_NAMES = {
	"fire": "火",
	"water": "水",
	"earth": "地",
	"wind": "風",
	"neutral": "無"
}

# パネルサイズ
const PANEL_WIDTH = 1110  # +150
const PANEL_HEIGHT = 1130  # +50
const PANEL_MARGIN = 40

# 土地ボーナス色（HPバーと同じ）
const COLOR_LAND_BONUS = Color("#FFC107")


func _ready() -> void:
	layer = OVERLAY_LAYER
	_setup_ui()
	hide()


func _setup_ui() -> void:
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	
	# 統合パネル（画面右側）
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	style.border_color = Color(0.5, 0.5, 0.6, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_container.add_child(_panel)
	
	# 攻撃側セクション
	_attacker_labels = _create_creature_section(0, "▼ 攻撃側")
	
	# 区切り線
	var separator = ColorRect.new()
	separator.color = Color(0.5, 0.5, 0.5, 0.5)
	separator.position = Vector2(45, 520)
	separator.size = Vector2(PANEL_WIDTH - 90, 4)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(separator)
	
	# 防御側セクション
	_defender_labels = _create_creature_section(540, "▼ 防御側")
	
	_update_panel_position()


func _create_creature_section(y_start: int, header_text: String) -> Dictionary:
	var labels = {}
	var y_offset = y_start + 36
	var line_height = 100
	
	# ヘッダー
	labels["header"] = _create_label(Vector2(45, y_offset), 64, Color(0.9, 0.9, 0.5))
	labels["header"].text = header_text
	y_offset += line_height
	
	# 名前
	labels["name"] = _create_label(Vector2(45, y_offset), 88, Color.WHITE)
	y_offset += line_height + 16
	
	# 属性
	labels["element"] = _create_label(Vector2(45, y_offset), 64, Color.WHITE)
	y_offset += line_height
	
	# HP（緑）+ 土地ボーナス（黄）+ AP（深めの赤）- 横並び
	labels["hp"] = _create_label(Vector2(45, y_offset), 88, Color(0.4, 1.0, 0.4))
	labels["hp_bonus"] = _create_label(Vector2(320, y_offset), 88, COLOR_LAND_BONUS)
	labels["ap"] = _create_label(Vector2(580, y_offset), 88, Color(0.85, 0.2, 0.2))
	
	return labels


func _create_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.position = pos
	label.size = Vector2(PANEL_WIDTH - 90, 100)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	_panel.add_child(label)
	return label


func _update_panel_position() -> void:
	var viewport_size = Vector2(1920, 1080)
	if get_viewport():
		viewport_size = get_viewport().get_visible_rect().size
	# 画面中央から右に200ピクセル
	_panel.position = Vector2(viewport_size.x / 2 + 200, 80)


## アイテムフェーズ開始時に表示
func show_battle_status(attacker_data: Dictionary, defender_data: Dictionary, current_side: String = "attacker"):
	_update_creature_data(_attacker_labels, attacker_data)
	_update_creature_data(_defender_labels, defender_data)
	highlight_side(current_side)
	_update_panel_position()
	show()


func _update_creature_data(labels: Dictionary, data: Dictionary) -> void:
	labels["name"].text = data.get("name", "???")
	
	var element = data.get("element", "neutral")
	labels["element"].text = "属性: " + ELEMENT_NAMES.get(element, element)
	labels["element"].add_theme_color_override("font_color", ELEMENT_COLORS.get(element, Color.WHITE))
	
	# HP表示（カレントHP + 土地ボーナス）
	var hp = data.get("hp", 0)
	var land_bonus = data.get("land_bonus_hp", 0)
	labels["hp"].text = "HP: %d" % hp
	
	# 土地ボーナスは0でなければ表示
	if land_bonus > 0:
		labels["hp_bonus"].text = "+%d" % land_bonus
	else:
		labels["hp_bonus"].text = ""
	
	labels["ap"].text = "AP: %d" % data.get("ap", 0)


## 現在のアイテム選択側を強調
func highlight_side(side: String) -> void:
	_current_side = side
	if side == "attacker":
		_attacker_labels["header"].text = "▶ 攻撃側"
		_attacker_labels["header"].add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
		_defender_labels["header"].text = "▼ 防御側"
		_defender_labels["header"].add_theme_color_override("font_color", Color(0.6, 0.6, 0.4))
	else:
		_attacker_labels["header"].text = "▼ 攻撃側"
		_attacker_labels["header"].add_theme_color_override("font_color", Color(0.6, 0.6, 0.4))
		_defender_labels["header"].text = "▶ 防御側"
		_defender_labels["header"].add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))


## アイテムフェーズ終了時に非表示
func hide_battle_status() -> void:
	hide()
