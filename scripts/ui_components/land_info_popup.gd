extends Control
class_name LandInfoPopup

# タイルクリック時に表示する土地情報パネル（属性＋レベル）
# action_menu_ui の land_info_panel と同じ見た目・配置

const _ELEMENT_NAMES: Dictionary = {
	"fire": "火", "water": "水", "earth": "地", "wind": "風", "neutral": "無", "blank": "変化"
}

const _SPECIAL_NAMES: Dictionary = {
	"card_buy": "カードショップ",
	"card_give": "カード配布",
	"magic": "スペル",
	"magic_stone": "魔法石",
	"warp": "ワープ",
	"warp_stop": "停止ワープ",
	"checkpoint": "チェックポイント",
	"base": "拠点",
	"branch": "分岐",
}

var _panel: Panel = null
var _info_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_info(element: String, level: int) -> void:
	if not _panel:
		_build_panel()
	_update_labels(element, level)
	visible = true


func show_special_info(tile_type: String) -> void:
	if not _panel:
		_build_panel()
	if not _info_label:
		return
	var name: String = _SPECIAL_NAMES.get(tile_type, tile_type)
	_info_label.text = name
	_info_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	visible = true


func hide_info() -> void:
	visible = false


func _build_panel() -> void:
	_panel = Panel.new()
	_panel.name = "LandInfoPanel"

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var info_panel_width: int = 260
	var info_panel_height: int = 120
	var margin: int = 19
	var nav_button_width: int = 200

	var panel_x: float = viewport_size.x - info_panel_width - margin - nav_button_width - 372
	var panel_y: float = (viewport_size.y - info_panel_height) / 2 - 78

	_panel.position = Vector2(panel_x, panel_y)
	_panel.size = Vector2(info_panel_width, info_panel_height)
	_panel.z_index = 1000

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.5, 0.5, 0.5, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(_panel)

	var title_label: Label = Label.new()
	title_label.text = "土地情報"
	title_label.position = Vector2(12, 10)
	title_label.size = Vector2(info_panel_width - 24, 28)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_panel.add_child(title_label)

	_info_label = Label.new()
	_info_label.position = Vector2(12, 48)
	_info_label.size = Vector2(info_panel_width - 24, 50)
	_info_label.add_theme_font_size_override("font_size", 30)
	_panel.add_child(_info_label)


func _update_labels(element: String, level: int) -> void:
	if not _info_label:
		return
	var element_name: String = _ELEMENT_NAMES.get(element, element)
	var element_color: Color = GameConstants.ELEMENT_COLORS.get(element, Color.WHITE)
	_info_label.text = "属性: %s　Lv: %d" % [element_name, level]
	_info_label.add_theme_color_override("font_color", element_color)
