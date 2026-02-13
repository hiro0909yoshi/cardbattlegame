extends Control
class_name PlayerStatusDialog

# プレイヤーステータスダイアログ
# 土地情報と保有クリーチャーを表示するモーダルダイアログ
# シーン: scenes/ui/player_status_dialog.tscn

# UIノード（シーンから取得）
@onready var background_rect: ColorRect = $BackgroundRect
@onready var main_panel: Control = $MainPanel
@onready var title_label: Label = $MainPanel/ContentMargin/VBoxContainer/TitleLabel
@onready var status_label: RichTextLabel = $MainPanel/ContentMargin/VBoxContainer/StatusLabel


# システム参照
var player_system_ref = null
var board_system_ref = null
var game_flow_manager_ref = null
var card_system_ref = null
var player_info_panel: PlayerInfoPanel = null

# === 直接参照（GFM経由を廃止） ===
var lap_system = null  # LapSystem: 周回管理

# 状態
var current_player_id = -1

func _ready():
	# 初期状態は非表示
	hide_dialog()
	
	# 背景は入力を下層に通す（カードタップ等を妨げない）
	# パネル外クリックでの閉じ処理は_input()で行う
	if background_rect:
		background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	
	# ESCキー検出用
	set_process_input(true)

# 初期化
func initialize(_parent: Node, player_system, board_system, player_info_panel_ref, game_flow_manager = null, card_system = null):
	player_system_ref = player_system
	board_system_ref = board_system
	player_info_panel = player_info_panel_ref
	card_system_ref = card_system
	game_flow_manager_ref = game_flow_manager

	# lap_systemの直接参照を設定
	if game_flow_manager_ref and game_flow_manager_ref.lap_system:
		lap_system = game_flow_manager_ref.lap_system

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
	visible = true

# ステータステキストを構築
func build_status_text(player_id: int) -> String:
	var text = ""
	
	if not player_system_ref:
		return text
	
	var player = player_system_ref.players[player_id]
	
	# 基本情報、マップ情報、手札を横並びで表示（5列: 左、スペーサー、中央、スペーサー、右）
	text += "[table=5]"
	
	# 左列: 基本情報
	text += "[cell][b][color=yellow]基本情報[/color][/b]\n"
	text += player.name
	
	# プレイヤー呪いがあればアイコン表示
	if player.curse and not player.curse.is_empty():
		var curse_name = player.curse.get("name", "呪い")
		text += " [" + curse_name + "]"
	
	text += "\n"
	text += "EP: " + str(player.magic_power) + "EP\n"
	text += "TEP: " + str(calculate_total_assets(player_id)) + "EP[/cell]"
	
	# スペーサー1
	text += "[cell]     [/cell]"
	
	# 中央列: マップ情報
	text += "[cell][b][color=yellow]マップ情報[/color][/b]\n"
	if game_flow_manager_ref:
		var lap_count = 0
		var destroy_count = 0
		if lap_system:
			lap_count = lap_system.get_lap_count(player_id)
			destroy_count = lap_system.get_destroy_count()
		var current_turn = game_flow_manager_ref.get_current_turn()
		text += "周回数: " + str(lap_count) + "\n"
		text += "ターン数: " + str(current_turn) + "\n"
		text += "破壊数: " + str(destroy_count)
	else:
		text += "データなし"
	text += "[/cell]"
	
	# スペーサー2（手札を右に配置するため広めに）
	text += "[cell]                    [/cell]"
	
	# 右列: 手札情報
	text += "[cell][b][color=yellow]手札[/color][/b]\n"
	text += build_hand_text(player_id)
	text += "[/cell]"
	
	text += "[/table]\n\n"
	
	# 世界呪い情報
	if game_flow_manager_ref and "game_stats" in game_flow_manager_ref:
		var world_curse = game_flow_manager_ref.game_stats.get("world_curse", {})
		if not world_curse.is_empty():
			var curse_name = world_curse.get("name", "不明")
			var duration = world_curse.get("duration", 0)
			text += "[b][color=purple]世界呪い[/color][/b]\n"
			text += curse_name + " (残り" + str(duration) + "R)\n\n"
	
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

# 手札テキストを構築
func build_hand_text(player_id: int) -> String:
	if not card_system_ref:
		return "データなし"
	
	# CardSystemから手札を取得（player_hands[player_id]["data"]）
	if not card_system_ref.player_hands.has(player_id):
		return "なし"
	
	var hand = card_system_ref.player_hands[player_id].get("data", [])
	if hand.is_empty():
		return "なし"
	
	var text = "[font_size=55]"
	for card in hand:
		if card is Dictionary:
			var card_name = card.get("name", "不明")
			var symbol = _get_card_symbol(card)
			text += symbol + " " + card_name + "\n"
		else:
			text += str(card) + "\n"
	text += "[/font_size]"
	
	return text.strip_edges()

# カードの記号を取得（タイプと属性/種類で色分け）
func _get_card_symbol(card: Dictionary) -> String:
	var card_type = card.get("type", "")
	
	match card_type:
		"creature":
			# クリーチャー: ● 属性色
			var element = card.get("element", "neutral")
			var color = _get_element_color(element)
			return "[color=" + color + "]●[/color]"
		
		"item":
			# アイテム: ▲ 種類色
			var item_type = card.get("item_type", "")
			var color = _get_item_type_color(item_type)
			return "[color=" + color + "]▲[/color]"
		
		"spell":
			# スペル: ◆ スペルタイプ色
			var spell_type = card.get("spell_type", "")
			var color = _get_spell_type_color(spell_type)
			return "[color=" + color + "]◆[/color]"
		
		_:
			return "□"

# 属性の色を取得
func _get_element_color(element: String) -> String:
	match element:
		"fire":
			return "#ff4444"  # 赤
		"water":
			return "#4488ff"  # 青
		"earth":
			return "#88cc44"  # 緑
		"wind":
			return "#ffcc44"  # 黄
		"neutral":
			return "#aaaaaa"  # グレー
		_:
			return "#ffffff"  # 白

# アイテム種類の色を取得
func _get_item_type_color(item_type: String) -> String:
	match item_type:
		"武器":
			return "#ff6644"  # オレンジ
		"防具":
			return "#4466ff"  # 青
		"アクセサリ":
			return "#44cc88"  # 緑
		"巻物":
			return "#cc44ff"  # 紫
		_:
			return "#ffffff"  # 白

# スペルタイプの色を取得
func _get_spell_type_color(spell_type: String) -> String:
	match spell_type:
		"単体対象":
			return "#ff4444"  # 赤
		"単体特殊能力付与":
			return "#44ff88"  # 緑
		"複数対象":
			return "#ffaa44"  # オレンジ
		"複数特殊能力付与":
			return "#44ccff"  # 水色
		"世界呪":
			return "#aa44ff"  # 紫
		_:
			return "#ffffff"  # 白

# TEPを計算（PlayerSystemに委譲）
func calculate_total_assets(player_id: int) -> int:
	if not player_system_ref:
		return 0
	return player_system_ref.calculate_total_assets(player_id)

# ダイアログを非表示にする
func hide_dialog():
	visible = false
	current_player_id = -1

# 表示中かどうか
func is_dialog_visible() -> bool:
	return visible

# 背景をクリックしたときのハンドラ
func _on_background_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_dialog()



# ESCキーおよびパネル外クリック検出
func _input(event):
	if not visible:
		return
	
	# ESCキー
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_dialog()
		get_tree().root.set_input_as_handled()
		return
	
	# マウスクリック: MainPanel外なら閉じる
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if main_panel:
			var panel_rect = Rect2(main_panel.global_position, main_panel.size)
			if not panel_rect.has_point(event.global_position):
				hide_dialog()
				get_tree().root.set_input_as_handled()
