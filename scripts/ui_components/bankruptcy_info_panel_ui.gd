## 破産情報パネルUI管理
## BankruptcyHandler から分離された破産情報表示パネル
## Phase 8-C: UI層分離 Signal駆動化
class_name BankruptcyInfoPanelUI
extends RefCounted

# UI要素
var _panel: Panel = null
var _ui_layer: CanvasLayer = null


func _init(p_ui_layer: CanvasLayer) -> void:
	_ui_layer = p_ui_layer


## 破産情報パネルを表示
func show_panel(current_magic: int, land_value: int) -> void:
	hide_panel()

	if not _ui_layer:
		push_error("[BankruptcyInfoPanelUI] ui_layer が設定されていません")
		return

	_panel = Panel.new()
	_panel.name = "BankruptcyInfoPanel"

	var viewport_size = _ui_layer.get_viewport().get_visible_rect().size

	# サイズと位置
	var panel_width = 280 * 4
	var panel_height = 120 * 3
	var margin = 30
	var panel_x = viewport_size.x - panel_width - margin - 200 - 600 + 200 + 100
	var panel_y = (viewport_size.y - panel_height) / 2 - 50 - 500

	_panel.position = Vector2(panel_x, panel_y)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.z_index = 1000

	# パネルスタイル
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.1, 0.95)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.8, 0.2, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)

	# 現在のEP
	var current_label = Label.new()
	current_label.text = "現在のEP: %dEP" % current_magic
	current_label.position = Vector2(60, 60)
	current_label.add_theme_font_size_override("font_size", 80)
	if current_magic < 0:
		current_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		current_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_panel.add_child(current_label)

	# 売却後のEP
	var after_magic = current_magic + land_value
	var after_label = Label.new()
	after_label.text = "売却後: %dEP (+%dEP)" % [after_magic, land_value]
	after_label.position = Vector2(60, 180)
	after_label.add_theme_font_size_override("font_size", 80)
	if after_magic >= 0:
		after_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		after_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_panel.add_child(after_label)

	_ui_layer.add_child(_panel)


## 破産情報パネルを非表示
func hide_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
