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
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
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

## クリック待ち用のシグナル
signal click_confirmed

## クリック待ちフラグ
var waiting_for_click: bool = false

## クリック待ちの最大時間（秒）
var click_wait_timeout: float = 7.0

## タイムアウト用タイマー
var timeout_timer: Timer = null

## 通知を表示してクリック待ち（全スペル・秘術共通）
## message: 表示するメッセージ
## await で待機可能
func show_notification_and_wait(message: String) -> void:
	# 既存のアニメーションをキャンセル
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# テキスト設定（中央揃え + クリック待ちの案内）
	var text = "[center]" + message + "\n\n[color=gray][クリックで次へ][/color][/center]"
	label.text = text
	
	# 表示
	modulate.a = 1.0
	visible = true
	waiting_for_click = true
	
	# マウス入力を受け付ける
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# パネルを中央に配置（座標計算）
	_center_panel()
	
	# タイムアウトタイマー開始
	_start_timeout_timer()

## パネルを画面中央に配置
func _center_panel():
	var panel = get_node_or_null("BackgroundPanel")
	if not panel:
		return
	
	# 1フレーム待ってサイズを確定させる
	await get_tree().process_frame
	
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = panel.size
	panel.position = Vector2(
		(viewport_size.x - panel_size.x) / 2,
		(viewport_size.y - panel_size.y) / 2
	)

## スペル発動通知を表示してクリック待ち
## 「AはBにCを使った」形式
func show_spell_cast_and_wait(caster_name: String, target_name: String, effect_name: String) -> void:
	var text = "%s は、%s に [color=yellow]%s[/color] を使った！" % [
		caster_name,
		target_name,
		effect_name
	]
	await show_notification_and_wait(text)

## 非推奨: 旧API互換（クリック待ちなし自動フェード）
## 新規コードでは show_notification_and_wait を使用してください
func show_notification(caster_name: String, target_name: String, effect_name: String):
	# クリック待ち版を呼び出す（互換性のため残すが非推奨）
	show_spell_cast_and_wait(caster_name, target_name, effect_name)

## タイムアウトタイマーを開始
func _start_timeout_timer():
	# 既存タイマーを停止
	_stop_timeout_timer()
	
	# 新しいタイマーを作成
	timeout_timer = Timer.new()
	timeout_timer.one_shot = true
	timeout_timer.wait_time = click_wait_timeout
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)
	timeout_timer.start()

## タイムアウトタイマーを停止
func _stop_timeout_timer():
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()
		timeout_timer = null

## タイムアウト時の処理
func _on_timeout():
	if waiting_for_click:
		_confirm_and_close()

## クリック確認して閉じる（共通処理）
func _confirm_and_close():
	_stop_timeout_timer()
	waiting_for_click = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_confirmed.emit()

func _input(event):
	if not waiting_for_click:
		return
	
	# クリックまたはEnterキーで確認
	var confirmed = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		confirmed = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			confirmed = true
	
	if confirmed:
		_confirm_and_close()
		get_viewport().set_input_as_handled()

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
			if player_id >= 0 and player_system and player_id < player_system.players.size():
				var player = player_system.players[player_id]
				if player:
					return player.name
			return "プレイヤー"
		
		"all", "all_lands", "all_creatures":
			return "全体"
		
		"world":
			return "世界"
		
		_:
			return "対象"
