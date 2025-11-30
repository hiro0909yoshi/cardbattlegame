extends Node
class_name CardSelectionUI

# カード選択UI管理クラス
# 召喚・バトル時のカード選択インターフェース

signal card_selected(card_index: int)
signal selection_cancelled()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# UI要素
var selection_buttons = []     # 追加ボタン配列
var pass_button: Button = null # パスボタン
var parent_node: Node          # 親ノード参照
var phase_label_ref: Label     # フェーズラベル参照

# 状態
var is_active = false          # 選択UI表示中か
var selection_mode = ""        # "summon" or "battle"

# システム参照
var card_system_ref: CardSystem = null
var ui_manager_ref = null  # UIManager参照を追加
var game_flow_manager_ref = null  # GameFlowManager参照

func _ready():
	pass

# 初期化
func initialize(parent: Node, card_system: CardSystem, phase_label: Label, ui_manager = null):
	parent_node = parent
	card_system_ref = card_system
	phase_label_ref = phase_label
	ui_manager_ref = ui_manager

# カード選択UIを表示
func show_selection(current_player, mode: String = "summon"):
	if not card_system_ref:
		print("Error: CardSystem reference not set")
		return
	
	# 既存のボタンをクリア
	cleanup_buttons()
	
	# プレイヤーの手札を取得
	var hand_data = card_system_ref.get_all_cards_for_player(current_player.id)
	if hand_data.is_empty():
		emit_signal("selection_cancelled")
		return
	
	is_active = true
	selection_mode = mode
	
	# フェーズラベルを更新
	update_phase_label(current_player, mode)
	
	# デバッグモード（全員手動）またはプレイヤー1の場合、カード選択可能
	var allow_manual = (current_player.id == 0) or (game_flow_manager_ref and game_flow_manager_ref.debug_manual_control_all)
	if allow_manual:
		enable_card_selection(hand_data, current_player.magic_power, current_player.id)
		
		# スペルフェーズではパスボタンを作らない（SpellPhaseUIManager で管理）
		if mode != "spell":
			create_pass_button(hand_data.size())

# フェーズラベルを更新
func update_phase_label(current_player, mode: String):
	if not phase_label_ref:
		return
	
	match mode:
		"summon":
			phase_label_ref.text = "召喚するクリーチャーを選択 (魔力: " + str(current_player.magic_power) + "G)"
		"battle":
			phase_label_ref.text = "バトルするクリーチャーを選択（またはパスで通行料）"
		"invasion":
			phase_label_ref.text = "無防備な土地！侵略するクリーチャーを選択（またはパスで通行料）"
		"discard":
			var hand_size = card_system_ref.get_hand_size_for_player(current_player.id)
			var cards_to_discard = hand_size - 6
			phase_label_ref.text = "手札を6枚まで減らしてください（" + str(cards_to_discard) + "枚捨てる）"
		"spell":
			phase_label_ref.text = "スペルを選択してください (魔力: " + str(current_player.magic_power) + "G)"
		"item":
			# 援護スキルの有無でメッセージを変更
			if ui_manager_ref and ui_manager_ref.card_selection_filter == "item_or_assist":
				phase_label_ref.text = "アイテムまたは援護クリーチャーを選択 (魔力: " + str(current_player.magic_power) + "G)"
			else:
				phase_label_ref.text = "アイテムを選択してください (魔力: " + str(current_player.magic_power) + "G)"
		_:
			phase_label_ref.text = "カードを選択してください"

# カード選択を有効化
func enable_card_selection(hand_data: Array, available_magic: int, player_id: int = 0):
	if not ui_manager_ref:
		return
	
	# 選択UIを有効化
	is_active = true
	
	# UIManagerのフィルター設定を確認
	var filter_mode = ui_manager_ref.card_selection_filter
	
	# UIManagerから手札ノードを取得（指定されたプレイヤーの手札）
	var hand_nodes = ui_manager_ref.get_player_card_nodes(player_id)
	for i in range(hand_nodes.size()):
		var card_node = hand_nodes[i]
		if card_node and is_instance_valid(card_node):
			var card_data = hand_data[i]
			
			# 密命カード対応: カードの所有者と閲覧者を設定
			if card_node.has_method("set_card_data_with_owner"):
				card_node.set_card_data_with_owner(card_data, player_id)
			if card_node.has_method("set_viewing_player"):
				# 常にプレイヤー0（人間）が見ている
				card_node.set_viewing_player(0)
			var card_type = card_data.get("type", "")
			
			# 選択可能状態を判定
			var is_selectable = true
			
			# disabledモード: すべて選択不可
			if filter_mode == "disabled":
				is_selectable = false
			# 捨て札モードではすべて選択可能
			elif selection_mode == "discard":
				is_selectable = true
			elif filter_mode == "spell":
				# スペルフェーズ中: スペルカードのみ選択可能
				is_selectable = card_type == "spell"
			elif filter_mode == "item":
				# アイテムフェーズ中: アイテムカードのみ選択可能
				is_selectable = card_type == "item"
				# ブロックされたアイテムタイプをチェック
				if is_selectable and ui_manager_ref and "blocked_item_types" in ui_manager_ref:
					var item_type = card_data.get("item_type", "")
					if item_type in ui_manager_ref.blocked_item_types:
						is_selectable = false
			elif filter_mode == "item_or_assist":
				# アイテムフェーズ（援護あり）: アイテムカードと援護対象クリーチャーが選択可能
				if card_type == "item":
					is_selectable = true
					# ブロックされたアイテムタイプをチェック
					if ui_manager_ref and "blocked_item_types" in ui_manager_ref:
						var item_type = card_data.get("item_type", "")
						if item_type in ui_manager_ref.blocked_item_types:
							is_selectable = false
				elif card_type == "creature":
					var assist_elements = []
					if ui_manager_ref and "assist_target_elements" in ui_manager_ref:
						assist_elements = ui_manager_ref.assist_target_elements
					
					var card_element = card_data.get("element", "")
					# 全属性対象、または属性が一致する場合
					is_selectable = ("all" in assist_elements) or (card_element in assist_elements)
				else:
					is_selectable = false
			elif filter_mode == "battle":
				# バトルフェーズ中: 防御型以外のクリーチャーカードのみ選択可能
				var creature_type = card_data.get("creature_type", "normal")
				is_selectable = card_type == "creature" and creature_type != "defensive"
			elif filter_mode == "destroy_item_spell":
				# シャッター用: アイテム/スペルのみ選択可能
				is_selectable = card_type == "item" or card_type == "spell"
			elif filter_mode == "destroy_any":
				# スクイーズ用: 全カード選択可能
				is_selectable = true
			elif filter_mode == "destroy_spell":
				# セフト用: スペルのみ選択可能
				is_selectable = card_type == "spell"
			elif filter_mode == "creature":
				# レムレース秘術用: クリーチャーのみ選択可能
				is_selectable = card_type == "creature"
			else:
				# 召喚フェーズ等: クリーチャーカードのみ選択可能
				is_selectable = card_type == "creature"
			
			# カードを選択可能/不可にする
			if card_node.has_method("set_selectable") and is_selectable:
				card_node.set_selectable(true, i)
			elif card_node.has_method("set_selectable"):
				card_node.set_selectable(false, -1)
			
			# グレーアウト処理を適用
			if filter_mode == "disabled":
				# disabledモード: すべてグレーアウト
				card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
			elif filter_mode == "battle":
				# バトルフェーズ中: 防御型クリーチャーをグレーアウト
				var creature_type = card_data.get("creature_type", "normal")
				if creature_type == "defensive":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "spell":
				# スペルフェーズ中: スペルカード以外をグレーアウト
				if card_type != "spell":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "item":
				# アイテムフェーズ中: アイテムカード以外をグレーアウト
				var should_gray = card_type != "item"
				# ブロックされたアイテムタイプもグレーアウト
				if not should_gray and ui_manager_ref and "blocked_item_types" in ui_manager_ref:
					var item_type = card_data.get("item_type", "")
					if item_type in ui_manager_ref.blocked_item_types:
						should_gray = true
				if should_gray:
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "item_or_assist":
				# アイテムフェーズ（援護あり）: アイテムカードと援護対象クリーチャー以外をグレーアウト
				var should_gray_out = true
				
				if card_type == "item":
					should_gray_out = false
					# ブロックされたアイテムタイプをチェック
					if ui_manager_ref and "blocked_item_types" in ui_manager_ref:
						var item_type = card_data.get("item_type", "")
						if item_type in ui_manager_ref.blocked_item_types:
							should_gray_out = true
				elif card_type == "creature":
					var assist_elements = []
					if ui_manager_ref and "assist_target_elements" in ui_manager_ref:
						assist_elements = ui_manager_ref.assist_target_elements
					
					var card_element = card_data.get("element", "")
					if ("all" in assist_elements) or (card_element in assist_elements):
						should_gray_out = false
				
				if should_gray_out:
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "destroy_item_spell":
				# シャッター用: クリーチャーをグレーアウト
				if card_type == "creature":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "destroy_any":
				# スクイーズ用: グレーアウトなし
				card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "destroy_spell":
				# セフト用: スペル以外をグレーアウト
				if card_type != "spell":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "creature":
				# レムレース秘術用: クリーチャー以外をグレーアウト
				if card_type != "creature":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "":
				# 通常フェーズ（召喚等）: スペルカードとアイテムカードをグレーアウト
				if card_type == "spell" or card_type == "item":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				# デフォルト: グレーアウトなし
				card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
			# 捨て札モードでは全て選択可能、それ以外はコストチェック
			if selection_mode == "discard":
				add_card_highlight(card_node, card_data, 999999, is_selectable)  # 全て選択可能
			else:
				add_card_highlight(card_node, card_data, available_magic, is_selectable)

# カードにハイライトを追加
func add_card_highlight(card_node: Node, card_data: Dictionary, available_magic: int, is_selectable: bool = true):
	# ハイライト枠を追加
	var highlight = ColorRect.new()
	highlight.name = "SelectionHighlight"
	highlight.size = card_node.size + Vector2(4, 4)
	highlight.position = Vector2(-2, -2)
	highlight.z_index = -1
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 選択不可の場合（スペルフェーズでスペルカード以外など）
	if not is_selectable:
		# グレーアウト状態を維持（既にグレーアウトされているはず）
		highlight.color = Color(0.3, 0.3, 0.3, 0.3)
		card_node.add_child(highlight)
		return
	
	# コストチェック（全て等倍）
	var cost_data = card_data.get("cost", 1)
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	else:
		cost = cost_data
	if cost > available_magic:
		# 魔力不足の場合
		card_node.modulate = Color(0.5, 0.5, 0.5)
		highlight.color = Color(0.5, 0.5, 0.5, 0.3)
	else:
		# 選択可能
		highlight.color = Color(1, 1, 0, 0.3)
	
	card_node.add_child(highlight)

# パスボタンを作成
func create_pass_button(hand_count: int):
	# 捨て札モードではパスボタンを作らない
	if selection_mode == "discard":
		return
	
	pass_button = Button.new()
	
	# ボタンテキスト設定
	match selection_mode:
		"summon":
			pass_button.text = "召喚しない"
		"battle":
			pass_button.text = "バトルしない"
		"invasion":
			pass_button.text = "侵略しない"
		"spell":
			pass_button.text = "スペルを使わない"
		"item":
			pass_button.text = "アイテムを使わない"
		_:
			pass_button.text = "パス"
	
	# 位置設定（手札の右側）
	# CardUIHelperを使用してレイアウト計算
	var viewport_size = get_viewport().get_visible_rect().size
	var layout = CardUIHelper.calculate_card_layout(viewport_size, hand_count)
	
	# 最後のカードの右側に配置（間隔を空けて）
	var last_card_x = layout.start_x + hand_count * layout.card_width + (hand_count - 1) * layout.spacing + layout.spacing
	pass_button.position = Vector2(last_card_x, layout.card_y)
	pass_button.size = Vector2(layout.card_width, layout.card_height)
	pass_button.pressed.connect(_on_pass_button_pressed)
	
	# ボタンスタイル設定
	apply_button_style(pass_button)
	
	parent_node.add_child(pass_button)
	selection_buttons.append(pass_button)

# ボタンスタイルを適用
func apply_button_style(button: Button):
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.border_color = Color(0.8, 0.8, 0.8)
	button.add_theme_stylebox_override("normal", button_style)

# 選択UIを非表示
func hide_selection():
	is_active = false
	selection_mode = ""
	
	# カード選択モードを解除
	if card_system_ref:
		disable_card_selection()
	
	# ボタンをクリア
	cleanup_buttons()
	
	# フェーズラベルを元に戻す
	if phase_label_ref:
		phase_label_ref.text = "アクション選択"

# カード選択を無効化
func disable_card_selection():
	if not ui_manager_ref:
		return
	
	# 全プレイヤーの手札ノードを取得して無効化
	for player_id in range(4):
		var hand_nodes = ui_manager_ref.get_player_card_nodes(player_id)
		for card_node in hand_nodes:
			if card_node and is_instance_valid(card_node):
				# カードを選択不可にする
				if card_node.has_method("set_selectable"):
					card_node.set_selectable(false)
				remove_card_highlight(card_node)

# カードのハイライトを削除
func remove_card_highlight(card_node: Node):
	# ハイライトを削除
	if card_node.has_node("SelectionHighlight"):
		card_node.get_node("SelectionHighlight").queue_free()
	# 明度を元に戻す
	card_node.modulate = Color(1, 1, 1)

# ボタンをクリーンアップ
func cleanup_buttons():
	for button in selection_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	selection_buttons.clear()
	pass_button = null

# カードが選択された（外部から呼ばれる）
func on_card_selected(card_index: int):
	if is_active:
		hide_selection()
		emit_signal("card_selected", card_index)

# パスボタンが押された
func _on_pass_button_pressed():
	if is_active:
		hide_selection()
		emit_signal("selection_cancelled")

# 選択中かチェック
func is_selection_active() -> bool:
	return is_active

# 現在の選択モードを取得
func get_selection_mode() -> String:
	return selection_mode

