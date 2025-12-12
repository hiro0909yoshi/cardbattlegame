# クリーチャー情報パネルUI
# タイル配置クリーチャーの詳細表示と召喚時の確認ダイアログ
extends Control

class_name CreatureInfoPanelUI

# シグナル
signal selection_confirmed(card_data: Dictionary)
signal selection_cancelled
signal panel_closed

# UI要素
var background_overlay: ColorRect
var main_container: HBoxContainer
var left_panel: Control  # カードUI
var right_panel: VBoxContainer  # 詳細情報

# 右パネルのラベル
var name_label: Label
var element_label: Label
var cost_label: Label
var hp_ap_label: Label
var restriction_label: Label
var curse_label: Label
var skill_container: VBoxContainer
var skill_label: Label
var mystic_container: VBoxContainer
var mystic_label: Label

# UIManager参照（グローバルボタン用）
var ui_manager_ref = null

# カード表示用
var card_display: Control

# 状態
var is_visible_panel: bool = false
var is_selection_mode: bool = false
var current_creature_data: Dictionary = {}
var current_tile_index: int = -1
var current_confirmation_text: String = ""

# 参照
var card_system = null

# 定数（画面比率ベース）
const PANEL_MARGIN_RATIO = 0.02  # 画面幅の2%
const CARD_WIDTH_RATIO = 0.18    # 画面幅の18%（カード幅）
const RIGHT_PANEL_WIDTH_RATIO = 0.375  # 画面幅の37.5%（元の1.5倍）
const CENTER_PANEL_WIDTH_RATIO = 0.12  # 画面幅の12%
const FONT_SIZE_RATIO = 0.018    # 画面高さの1.8%


func _ready():
	_setup_ui()
	hide_panel()


func set_card_system(system) -> void:
	card_system = system


func _setup_ui():
	# 自身をフルスクリーンに
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 背景オーバーレイ
	background_overlay = ColorRect.new()
	background_overlay.color = Color(0, 0, 0, 0.6)
	background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	background_overlay.gui_input.connect(_on_overlay_input)
	add_child(background_overlay)
	
	# メインコンテナ（水平配置）- positionで中央配置
	main_container = HBoxContainer.new()
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(main_container)
	
	# 左パネル（カードUI）
	_setup_left_panel()
	
	# 右パネル（詳細情報）
	_setup_right_panel()
	
	# 画面サイズ変更に対応
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_update_sizes()


func _setup_left_panel():
	left_panel = Control.new()
	# サイズは_update_sizes()で設定
	left_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 垂直中央揃え
	main_container.add_child(left_panel)


func _setup_right_panel():
	right_panel = VBoxContainer.new()
	right_panel.name = "RightPanel"
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL  # 縦方向拡張
	main_container.add_child(right_panel)
	
	# 背景パネル
	var panel_bg = PanelContainer.new()
	panel_bg.name = "RightPanelBg"
	panel_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL  # 背景も縦方向拡張
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	panel_bg.add_theme_stylebox_override("panel", style)
	right_panel.add_child(panel_bg)
	
	var vbox = VBoxContainer.new()
	vbox.name = "RightPanelVBox"
	panel_bg.add_child(vbox)
	
	# 名前 + レア度
	name_label = Label.new()
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(name_label)
	
	# 属性
	element_label = Label.new()
	vbox.add_child(element_label)
	
	# コスト
	cost_label = Label.new()
	vbox.add_child(cost_label)
	
	# HP / AP
	hp_ap_label = Label.new()
	vbox.add_child(hp_ap_label)
	
	# 配置制限 / アイテム制限
	restriction_label = Label.new()
	restriction_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(restriction_label)
	
	# セパレータ
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# 呪い
	curse_label = Label.new()
	curse_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(curse_label)
	
	# スキルコンテナ（条件付き表示）
	skill_container = VBoxContainer.new()
	vbox.add_child(skill_container)
	
	var skill_header = Label.new()
	skill_header.text = "【スキル】"
	skill_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	skill_container.add_child(skill_header)
	
	skill_label = Label.new()
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_container.add_child(skill_label)
	
	# 秘術コンテナ（条件付き表示）
	mystic_container = VBoxContainer.new()
	vbox.add_child(mystic_container)
	
	var mystic_header = Label.new()
	mystic_header.text = "【秘術】"
	mystic_header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.8))
	mystic_container.add_child(mystic_header)
	
	mystic_label = Label.new()
	mystic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mystic_container.add_child(mystic_label)


func _on_viewport_size_changed():
	_update_sizes()


func _update_sizes():
	var viewport = get_viewport()
	if not viewport:
		return
	var viewport_size = viewport.get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# フォントサイズ計算（全体を1.65倍に拡大）
	var base_font_size = int(screen_height * FONT_SIZE_RATIO * 1.65)
	var title_font_size = int(base_font_size * 1.4)
	var small_font_size = int(base_font_size * 0.85)
	
	# パネル間の間隔
	var panel_separation = int(screen_width * 0.02)
	main_container.add_theme_constant_override("separation", panel_separation)
	
	# 左パネル（カード）サイズ
	var card_width = screen_width * CARD_WIDTH_RATIO
	var card_height = card_width * (293.0 / 220.0)  # カードの縦横比を維持
	left_panel.custom_minimum_size = Vector2(card_width, card_height)
	
	# 右パネルサイズ（高さを2/3に縮小）
	var right_width = screen_width * RIGHT_PANEL_WIDTH_RATIO
	var right_height = card_height * 1.4  # カードの約1.3倍の高さ（元の2/3）
	right_panel.custom_minimum_size = Vector2(right_width, right_height)
	
	# 右パネルの内部設定
	var right_bg = right_panel.get_node_or_null("RightPanelBg")
	if right_bg:
		var style = right_bg.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			var margin = int(screen_width * 0.012)
			style.content_margin_left = margin
			style.content_margin_right = margin
			style.content_margin_top = margin
			style.content_margin_bottom = margin
		
		var vbox = right_bg.get_node_or_null("RightPanelVBox") as VBoxContainer
		if vbox:
			vbox.add_theme_constant_override("separation", int(screen_height * 0.01))
	
	# 右パネルのフォントサイズ更新
	if name_label:
		name_label.add_theme_font_size_override("font_size", title_font_size)
	if element_label:
		element_label.add_theme_font_size_override("font_size", base_font_size)
	if cost_label:
		cost_label.add_theme_font_size_override("font_size", base_font_size)
	if hp_ap_label:
		hp_ap_label.add_theme_font_size_override("font_size", base_font_size)
	if restriction_label:
		restriction_label.add_theme_font_size_override("font_size", small_font_size)
	if curse_label:
		curse_label.add_theme_font_size_override("font_size", base_font_size)
	if skill_label:
		skill_label.add_theme_font_size_override("font_size", small_font_size)
	if mystic_label:
		mystic_label.add_theme_font_size_override("font_size", small_font_size)
	
	# スキル・秘術ヘッダー
	if skill_container and skill_container.get_child_count() > 0:
		var header = skill_container.get_child(0)
		if header is Label:
			header.add_theme_font_size_override("font_size", base_font_size)
	if mystic_container and mystic_container.get_child_count() > 0:
		var header = mystic_container.get_child(0)
		if header is Label:
			header.add_theme_font_size_override("font_size", base_font_size)
	
	# カード表示の更新
	if card_display:
		card_display.scale = Vector2(card_width / 220.0, card_width / 220.0)
	
	# メインコンテナの位置を画面中央に設定
	# コンテナの合計サイズを計算（中央パネル廃止）
	var total_width = card_width + panel_separation + right_width
	var total_height = max(card_height, right_height)
	
	# 中央配置（画面中央からコンテナサイズの半分を引く）+ 上に180px移動
	var center_x = (screen_width - total_width) / 2.0
	var center_y = (screen_height - total_height) / 2.0 - 158
	
	main_container.position = Vector2(center_x, center_y)
	main_container.size = Vector2(total_width, total_height)


# === 公開メソッド ===

## UIManager参照を設定
func set_ui_manager(manager) -> void:
	ui_manager_ref = manager


## 閲覧モードで表示（タイル配置クリーチャー）
func show_view_mode(creature_data: Dictionary, tile_index: int = -1):
	current_creature_data = creature_data
	current_tile_index = tile_index
	is_selection_mode = false
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# グローバルボタン設定（閲覧モード：戻るのみ）
	if ui_manager_ref:
		ui_manager_ref.register_back_action(_on_back_action, "閉じる")


## 選択モードで表示（召喚/バトル時）
func show_selection_mode(creature_data: Dictionary, confirmation_text: String = "召喚しますか？"):
	current_creature_data = creature_data
	current_confirmation_text = confirmation_text
	is_selection_mode = true
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# グローバルボタン設定（選択モード：決定と戻る）
	if ui_manager_ref:
		# 確認テキストから決定ボタンのテキストを決定
		var confirm_btn_text = "召喚"
		if "バトル" in confirmation_text:
			confirm_btn_text = "バトル"
		elif "侵略" in confirmation_text:
			confirm_btn_text = "侵略"
		elif "交換" in confirmation_text:
			confirm_btn_text = "交換"
		ui_manager_ref.register_global_actions(_on_confirm_action, _on_back_action, confirm_btn_text, "戻る")


## パネルを閉じる
## clear_buttons: グローバルボタンをクリアするかどうか（デフォルト: true）
func hide_panel(clear_buttons: bool = true):
	visible = false
	is_visible_panel = false
	current_creature_data = {}
	current_tile_index = -1
	
	# グローバルボタンをクリア（オプション）
	if clear_buttons and ui_manager_ref:
		ui_manager_ref.clear_global_actions()
	
	# カード表示をクリア
	if card_display and is_instance_valid(card_display):
		card_display.queue_free()
		card_display = null
	
	panel_closed.emit()


## パネル表示中かどうか
func is_panel_visible() -> bool:
	return is_visible_panel


# === 内部メソッド ===

func _update_display():
	_update_card_display()
	_update_right_panel()


func _update_card_display():
	# 既存のカード表示をクリア
	if card_display and is_instance_valid(card_display):
		card_display.queue_free()
		card_display = null
	
	# カードシーンをロードして表示
	var card_scene = preload("res://scenes/Card.tscn")
	card_display = card_scene.instantiate()
	
	# 画面サイズに基づいてスケール計算
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		var card_width = viewport_size.x * CARD_WIDTH_RATIO
		var scale_factor = card_width / 220.0  # 220は元のカード幅
		card_display.scale = Vector2(scale_factor, scale_factor)
	
	left_panel.add_child(card_display)
	
	# カード位置を上に調整
	card_display.position.y = 0
	card_display.position.x = -30
	
	# カードデータを設定（IDで読み込み）
	var card_id = current_creature_data.get("id", 0)
	if card_display.has_method("load_card_data"):
		card_display.load_card_data(card_id)


func _update_right_panel():
	var data = current_creature_data
	
	# 名前 + レア度
	var rarity = data.get("rarity", "")
	name_label.text = "%s [%s]" % [data.get("name", "不明"), rarity]
	
	# 属性
	var element = data.get("element", "")
	element_label.text = _get_element_display_name(element)
	element_label.add_theme_color_override("font_color", _get_element_color(element))
	
	# コスト + 必要土地
	var cost_value = data.get("cost", 0)
	var mp_cost = 0
	var lands_required = []
	if typeof(cost_value) == TYPE_DICTIONARY:
		mp_cost = cost_value.get("mp", 0)
		lands_required = cost_value.get("lands_required", [])
	else:
		mp_cost = cost_value if typeof(cost_value) == TYPE_INT else 0
		# 正規化されたフィールドも確認
		lands_required = data.get("cost_lands_required", [])
	var cost_text = "コスト: %dG" % mp_cost
	if not lands_required.is_empty():
		var lands_str = ""
		for land in lands_required:
			lands_str += _get_element_short_name(land)
		cost_text += " (%s)" % lands_str
	cost_label.text = cost_text
	
	# HP / AP
	var hp = data.get("hp", 0)
	var ap = data.get("ap", 0)
	var current_hp = data.get("current_hp", hp)
	var max_hp = hp + data.get("base_up_hp", 0)
	var total_ap = ap + data.get("base_up_ap", 0)
	hp_ap_label.text = "HP: %d / %d    AP: %d" % [current_hp, max_hp, total_ap]
	
	# 配置制限 / アイテム制限
	var restrictions = data.get("restrictions", {})
	var restriction_parts = []
	
	var cannot_summon = restrictions.get("cannot_summon", [])
	if not cannot_summon.is_empty():
		var summon_str = ""
		for elem in cannot_summon:
			summon_str += _get_element_short_name(elem)
		restriction_parts.append("配置制限: %s不可" % summon_str)
	else:
		restriction_parts.append("配置制限: なし")
	
	var cannot_use = restrictions.get("cannot_use", [])
	if not cannot_use.is_empty():
		restriction_parts.append("アイテム: %s" % ",".join(cannot_use))
	else:
		restriction_parts.append("アイテム: なし")
	
	restriction_label.text = "  ".join(restriction_parts)
	
	# 呪い
	var curse = data.get("curse", {})
	if curse.is_empty():
		curse_label.text = "【呪い】なし"
	else:
		var curse_name = curse.get("name", "不明")
		var duration = curse.get("duration", -1)
		if duration > 0:
			curse_label.text = "【呪い】%s（残り%dターン）" % [curse_name, duration]
		else:
			curse_label.text = "【呪い】%s" % curse_name
	
	# スキル
	var ability_parsed = data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if not keywords.is_empty():
		skill_container.visible = true
		var ability_detail = data.get("ability_detail", data.get("ability", ""))
		skill_label.text = ability_detail
	else:
		skill_container.visible = false
	
	# 秘術
	var mystic_art = ability_parsed.get("mystic_art", {})
	var mystic_arts = ability_parsed.get("mystic_arts", [])
	if not mystic_art.is_empty() or not mystic_arts.is_empty():
		mystic_container.visible = true
		var mystic_text = ""
		if not mystic_art.is_empty():
			mystic_text = "%s (%dG)" % [mystic_art.get("name", ""), mystic_art.get("cost", 0)]
		elif not mystic_arts.is_empty():
			var parts = []
			for ma in mystic_arts:
				parts.append("%s (%dG)" % [ma.get("name", ""), ma.get("cost", 0)])
			mystic_text = "\n".join(parts)
		mystic_label.text = mystic_text
	else:
		mystic_container.visible = false


func _get_element_display_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		"neutral": return "無"
		_: return element


func _get_element_short_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		_: return element


func _get_element_color(element: String) -> Color:
	match element:
		"fire": return Color(1.0, 0.4, 0.3)
		"water": return Color(0.3, 0.6, 1.0)
		"earth": return Color(0.6, 0.5, 0.3)
		"wind": return Color(0.4, 0.9, 0.5)
		"neutral": return Color(0.7, 0.7, 0.7)
		_: return Color.WHITE


# === イベントハンドラ ===

func _on_overlay_input(event: InputEvent):
	# 閲覧モードの場合、どこでもタップで閉じる
	if not is_selection_mode:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide_panel()
		elif event is InputEventScreenTouch and event.pressed:
			hide_panel()


func _on_confirm_action():
	if is_selection_mode:
		var data = current_creature_data
		hide_panel()
		selection_confirmed.emit(data)


func _on_back_action():
	if is_selection_mode:
		hide_panel()
		selection_cancelled.emit()
	else:
		# 閲覧モード：単純に閉じる
		hide_panel()
