extends Control
class_name SpellCastNotificationUI

## 画面中央にスペル/秘術発動を通知するUI
## 「Aは、BにCを使った」形式で表示

@onready var label: RichTextLabel

var display_duration: float = 2.0  # 表示時間
var fade_duration: float = 0.3     # フェードアウト時間
var current_tween: Tween

func _ready():
	_setup_ui()

func _setup_ui():
	# 自身を全画面に設定（マウス入力は透過）
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 背景パネル
	var panel = PanelContainer.new()
	panel.name = "BackgroundPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	# RichTextLabelを作成
	label = RichTextLabel.new()
	label.name = "NotificationLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# スタイル設定
	label.add_theme_font_size_override("normal_font_size", 24)
	label.add_theme_color_override("default_color", Color.WHITE)
	
	panel.add_child(label)
	add_child(panel)
	
	# 初期状態は非表示
	visible = false

## 通知を表示
## caster_name: 発動者名（プレイヤー名/クリーチャー名）
## target_name: 対象名（プレイヤー名/クリーチャー名/「全体」/「世界」）
## effect_name: 効果名
func show_notification(caster_name: String, target_name: String, effect_name: String):
	# 既存のアニメーションをキャンセル
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# テキスト設定
	var text = "%s は、%s に [color=yellow]%s[/color] を使った！" % [
		caster_name,
		target_name,
		effect_name
	]
	label.text = text
	
	# パネルを中央に配置
	var panel = get_node("BackgroundPanel")
	if panel:
		# パネルサイズを再計算させる
		await get_tree().process_frame
		
		var viewport_size = get_viewport().get_visible_rect().size
		var panel_size = panel.size
		panel.position = Vector2(
			(viewport_size.x - panel_size.x) / 2,
			(viewport_size.y - panel_size.y) / 2
		)
	
	# 表示
	modulate.a = 1.0
	visible = true
	
	# 表示 → フェードアウト
	current_tween = get_tree().create_tween()
	current_tween.tween_interval(display_duration)
	current_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	current_tween.tween_callback(_on_fade_complete)

func _on_fade_complete():
	visible = false
	modulate.a = 1.0

## スペルカードから効果名を取得
## 優先順位:
## 1. effect_parsed.effects[].name
## 2. effectテキストから \"...\" を抽出
## 3. スペル名（name）
static func get_effect_display_name(spell_card: Dictionary) -> String:
	# 1. effect_parsed.effects[].name を探す
	var effect_parsed = spell_card.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	for effect in effects:
		var effect_name = effect.get("name", "")
		if not effect_name.is_empty():
			return effect_name
	
	# 2. effectテキストから \"...\" を抽出
	var effect_text = spell_card.get("effect", "")
	if not effect_text.is_empty():
		var regex = RegEx.new()
		# \"...\" パターンを検索（エスケープされたダブルクォート）
		regex.compile('\\\\"([^"]+)\\\\"')
		var result = regex.search(effect_text)
		if result:
			return result.get_string(1)
	
	# 3. スペル名を使用
	return spell_card.get("name", "不明")

## 秘術から効果名を取得
static func get_mystic_art_display_name(mystic_art: Dictionary) -> String:
	# spell_idがある場合はスペルデータから取得
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			return get_effect_display_name(spell_data)
	
	# 秘術自体のnameを使用
	return mystic_art.get("name", "不明")

## 対象名を取得
static func get_target_display_name(target_data: Dictionary, board_system = null, player_system = null) -> String:
	var target_type = target_data.get("type", "")
	
	match target_type:
		"land", "creature":
			var tile_index = target_data.get("tile_index", -1)
			if tile_index >= 0 and board_system and board_system.tile_nodes.has(tile_index):
				var tile = board_system.tile_nodes[tile_index]
				if tile and "creature_data" in tile and not tile.creature_data.is_empty():
					return tile.creature_data.get("name", "クリーチャー")
			return "領地"
		
		"player":
			var player_id = target_data.get("player_id", -1)
			if player_id >= 0 and player_system:
				var player = player_system.get_player(player_id)
				if player:
					return player.get("name", "プレイヤー%d" % player_id)
			return "プレイヤー"
		
		"all", "all_lands", "all_creatures":
			return "全体"
		
		"world":
			return "世界"
		
		_:
			return "対象"
