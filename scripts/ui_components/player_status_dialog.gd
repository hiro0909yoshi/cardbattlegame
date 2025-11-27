extends Node
class_name PlayerStatusDialog

# プレイヤーステータスダイアログ
# 土地情報と保有クリーチャーを表示するモーダルダイアログ

# UIノード
var dialog_panel: PanelContainer = null
var title_label: Label = null
var status_label: RichTextLabel = null
var close_button: Button = null

# 背景（フェードアウト）
var background_rect: ColorRect = null

# システム参照
var player_system_ref = null
var board_system_ref = null
var game_flow_manager_ref = null
var player_info_panel: PlayerInfoPanel = null

# 状態
var current_player_id = -1
var is_visible = false

func _ready():
	pass

# 初期化
func initialize(parent: Node, player_system, board_system, player_info_panel_ref, game_flow_manager = null):
	player_system_ref = player_system
	board_system_ref = board_system
	player_info_panel = player_info_panel_ref
	game_flow_manager_ref = game_flow_manager
	
	create_dialog_ui(parent)

# ダイアログUIを作成
func create_dialog_ui(parent: Node):
	# 背景レイヤー（クリックを遮断する）
	background_rect = ColorRect.new()
	background_rect.color = Color(0, 0, 0, 0.5)
	background_rect.anchor_left = 0.0
	background_rect.anchor_top = 0.0
	background_rect.anchor_right = 1.0
	background_rect.anchor_bottom = 1.0
	background_rect.visible = false
	background_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(background_rect)
	background_rect.gui_input.connect(_on_background_clicked)
	
	# メインダイアログパネル
	dialog_panel = PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(800, 800)
	dialog_panel.visible = false
	
	# パネルの位置（上寄りに配置）
	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_top = 0.5
	dialog_panel.anchor_right = 0.5
	dialog_panel.anchor_bottom = 0.5
	dialog_panel.offset_left = -400
	dialog_panel.offset_top = -580  # さらに上に移動
	
	# パネルスタイル
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	
	# VBoxContainer（ダイアログの内容）
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog_panel.add_child(vbox)
	
	# タイトルラベル
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.text = ""
	vbox.add_child(title_label)
	
	# ステータス表示ラベル
	status_label = RichTextLabel.new()
	status_label.custom_minimum_size = Vector2(750, 700)
	status_label.bbcode_enabled = true
	status_label.scroll_active = true
	status_label.fit_content = false
	status_label.clip_contents = true
	status_label.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(status_label)
	
	# 閉じるボタン
	close_button = Button.new()
	close_button.text = "閉じる"
	close_button.custom_minimum_size = Vector2(0, 30)
	close_button.pressed.connect(_on_close_button_pressed)
	vbox.add_child(close_button)
	
	# ダイアログをUIレイヤーに追加
	parent.add_child(dialog_panel)
	
	# ESCキー検出用
	set_process_input(true)

# プレイヤーのステータスを表示
func show_for_player(player_id: int):
	if player_id < 0 or not player_system_ref:
		return
	
	if player_id >= player_system_ref.players.size():
		return
	
	current_player_id = player_id
	
	# ダイアログの内容を更新
	var player = player_system_ref.players[player_id]
	title_label.text = player.name + "のステータス"
	
	# ステータス情報を生成
	var status_text = build_status_text(player_id)
	status_label.text = status_text
	
	# ダイアログを表示
	background_rect.visible = true
	dialog_panel.visible = true
	is_visible = true

# ステータステキストを構築
func build_status_text(player_id: int) -> String:
	var text = ""
	
	if not player_system_ref:
		return text
	
	var player = player_system_ref.players[player_id]
	
	# 基本情報とマップ情報を横並びで表示（3列: 左、スペーサー、右）
	text += "[table=3]"
	
	# 左列: 基本情報
	text += "[cell][b][color=yellow]基本情報[/color][/b]\n"
	text += player.name
	
	# プレイヤー呪いがあればアイコン表示
	if player.curse and not player.curse.is_empty():
		var curse_name = player.curse.get("name", "呪い")
		text += " [" + curse_name + "]"
	
	text += "\n"
	text += "魔力: " + str(player.magic_power) + "G\n"
	text += "総魔力: " + str(calculate_total_assets(player_id)) + "G[/cell]"
	
	# 中央: スペーサー
	text += "[cell]          [/cell]"
	
	# 右列: マップ情報
	text += "[cell][b][color=yellow]マップ情報[/color][/b]\n"
	if game_flow_manager_ref:
		var lap_count = game_flow_manager_ref.get_lap_count(player_id)
		var current_turn = game_flow_manager_ref.get_current_turn()
		var destroy_count = game_flow_manager_ref.get_destroy_count()
		text += "周回数: " + str(lap_count) + "\n"
		text += "ターン数: " + str(current_turn) + "\n"
		text += "破壊数: " + str(destroy_count)
	else:
		text += "データなし"
	text += "[/cell]"
	
	text += "[/table]\n\n"
	
	# 土地情報
	text += "[b][color=yellow]保有土地[/color][/b]\n"
	if player_info_panel:
		var lands = player_info_panel.get_lands_by_element(player_id)
		text += "火: " + str(lands.get("火", 0)) + "個\n"
		text += "水: " + str(lands.get("水", 0)) + "個\n"
		text += "風: " + str(lands.get("風", 0)) + "個\n"
		text += "土: " + str(lands.get("土", 0)) + "個\n"
		text += "無: " + str(lands.get("無", 0)) + "個\n\n"
	
	# 保有クリーチャー
	text += "[b][color=yellow]保有クリーチャー[/color][/b]\n"
	if player_info_panel:
		var creatures = player_info_panel.get_creatures_on_lands(player_id)
		if creatures.is_empty():
			text += "なし\n"
		else:
			for creature in creatures:
				# クリーチャーデータ構造に応じて対応
				if creature is Dictionary:
					# HP: current_hp が現在値、max_hp = hp + base_up_hp
					var current_hp = creature.get("current_hp", 0)
					var base_hp = creature.get("hp", 0)
					var base_up_hp = creature.get("base_up_hp", 0)
					var max_hp = base_hp + base_up_hp
					
					# AP: max_ap = ap + base_up_ap（current_ap はない）
					var base_ap = creature.get("ap", 0)
					var base_up_ap = creature.get("base_up_ap", 0)
					var max_ap = base_ap + base_up_ap
					
					# 1行表示: 名前 HP: XX / XX AP: XX
					var creature_name = creature.get("name", "不明")
					var display_name = creature_name
					
					# クリーチャー呪いがあればアイコン表示
					if creature.has("curse") and not creature.get("curse", {}).is_empty():
						var curse = creature.get("curse", {})
						var curse_name = str(curse.get("name", "呪い"))
						display_name += " [" + curse_name + "]"
					
					text += display_name + "  HP: " + str(current_hp) + " / " + str(max_hp) + "  AP: " + str(max_ap) + "\n"
				elif creature.has_method("get_name"):
					text += creature.get_name() + "\n"
					if creature.has_method("get_current_hp") and creature.has_method("get_max_hp"):
						text += "  HP: " + str(creature.get_current_hp()) + " / " + str(creature.get_max_hp()) + "\n"
					if creature.has_method("get_current_ap"):
						text += "  AP: " + str(creature.get_current_ap()) + "\n"
				else:
					text += str(creature) + "\n"
	
	return text

# 総資産を計算
func calculate_total_assets(player_id: int) -> int:
	if not player_system_ref or not board_system_ref:
		return 0
	
	var assets = player_system_ref.players[player_id].magic_power
	
	if board_system_ref != null and "tile_nodes" in board_system_ref:
		var GameConstants = preload("res://scripts/game_constants.gd")
		for i in board_system_ref.tile_nodes:
			var tile = board_system_ref.tile_nodes[i]
			if tile.owner_id == player_id:
				var level_value = GameConstants.LEVEL_VALUES.get(tile.level, 0)
				assets += level_value
	
	return assets

# ダイアログを非表示にする
func hide_dialog():
	background_rect.visible = false
	dialog_panel.visible = false
	is_visible = false
	current_player_id = -1

# 背景をクリックしたときのハンドラ
func _on_background_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_dialog()

# 閉じるボタン
func _on_close_button_pressed():
	hide_dialog()

# ESCキー検出
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_visible:
			hide_dialog()
			get_tree().root.set_input_as_handled()
