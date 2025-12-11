extends Node
class_name CardSelectionUI

# カード選択UI管理クラス
# 召喚・バトル時のカード選択インターフェース

signal card_selected(card_index: int)
signal selection_cancelled()

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
# GameSettingsはclass_nameで定義されているためグローバルアクセス可能

# UI要素
var selection_buttons = []     # 追加ボタン配列
var pass_button: Button = null # パスボタン
var parent_node: Node          # 親ノード参照
var phase_label_ref: Label     # フェーズラベル参照

# 状態
var is_active = false          # 選択UI表示中か
var selection_mode = ""        # "summon" or "battle"
var pending_card_index: int = -1  # クリーチャー情報パネル確認待ちのカードインデックス
var creature_info_panel_connected: bool = false  # シグナル接続済みフラグ

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
		"sacrifice":
			phase_label_ref.text = "犠牲にするカードを選択"
		"spell_borrow":
			phase_label_ref.text = "使用するスペルを選択してください"
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
			# 犠牲モードではすべて選択可能
			elif selection_mode == "sacrifice":
				is_selectable = true
			elif filter_mode == "spell":
				# スペルフェーズ中: スペルカードのみ選択可能
				is_selectable = card_type == "spell"
			elif filter_mode == "item":
				# アイテムフェーズ中: アイテムカード、またはアイテムクリーチャーが選択可能
				if card_type == "item":
					is_selectable = true
				elif card_type == "creature":
					# アイテムクリーチャー判定
					var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
					is_selectable = "アイテムクリーチャー" in keywords
				else:
					is_selectable = false
				# ブロックされたアイテムタイプをチェック
				if is_selectable and ui_manager_ref and "blocked_item_types" in ui_manager_ref:
					var item_type = card_data.get("item_type", "")
					if item_type in ui_manager_ref.blocked_item_types:
						is_selectable = false
			elif filter_mode == "item_or_assist":
				# アイテムフェーズ（援護あり）: アイテムカード、アイテムクリーチャー、援護対象クリーチャーが選択可能
				if card_type == "item":
					is_selectable = true
					# ブロックされたアイテムタイプをチェック
					if ui_manager_ref and "blocked_item_types" in ui_manager_ref:
						var item_type = card_data.get("item_type", "")
						if item_type in ui_manager_ref.blocked_item_types:
							is_selectable = false
				elif card_type == "creature":
					# アイテムクリーチャー判定
					var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
					if "アイテムクリーチャー" in keywords:
						is_selectable = true
					else:
						# 援護対象判定
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
			elif filter_mode == "item_or_spell":
				# メタモルフォシス用: アイテム/スペルのみ選択可能
				is_selectable = card_type == "item" or card_type == "spell"
			elif filter_mode == "destroy_any":
				# スクイーズ用: 全カード選択可能
				is_selectable = true
			elif filter_mode == "destroy_spell":
				# セフト用: スペルのみ選択可能
				is_selectable = card_type == "spell"
			elif filter_mode == "single_target_spell":
				# ルーンアデプト秘術用: 単体対象スペルのみ選択可能
				is_selectable = card_type == "spell" and card_data.get("spell_type") == "単体対象"
			elif filter_mode == "creature":
				# レムレース秘術用: クリーチャーのみ選択可能
				is_selectable = card_type == "creature"
			else:
				# 召喚フェーズ等: クリーチャーカードのみ選択可能
				is_selectable = card_type == "creature"
			
			# 土地条件チェック（召喚/バトルフェーズでクリーチャーの場合）
			if is_selectable and card_type == "creature" and (filter_mode == "" or filter_mode == "battle"):
				if not _check_lands_required(card_data, player_id):
					is_selectable = false
			
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
				# バトルフェーズ中: 防御型クリーチャー + 土地条件未達をグレーアウト
				var creature_type = card_data.get("creature_type", "normal")
				if creature_type == "defensive":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				elif card_type == "creature" and not _check_lands_required(card_data, player_id):
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "spell":
				# スペルフェーズ中: スペルカード以外をグレーアウト
				if card_type != "spell":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "spell_disabled":
				# スペル不可呪い中: スペルカードをグレーアウト（秘術は使用可能）
				if card_type == "spell":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif filter_mode == "item":
				# アイテムフェーズ中: アイテムカード、アイテムクリーチャー以外をグレーアウト
				var should_gray = true
				if card_type == "item":
					should_gray = false
				elif card_type == "creature":
					# アイテムクリーチャー判定
					var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
					if "アイテムクリーチャー" in keywords:
						should_gray = false
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
				# アイテムフェーズ（援護あり）: アイテムカード、アイテムクリーチャー、援護対象クリーチャー以外をグレーアウト
				var should_gray_out = true
				
				if card_type == "item":
					should_gray_out = false
					# ブロックされたアイテムタイプをチェック
					if ui_manager_ref and "blocked_item_types" in ui_manager_ref:
						var item_type = card_data.get("item_type", "")
						if item_type in ui_manager_ref.blocked_item_types:
							should_gray_out = true
				elif card_type == "creature":
					# アイテムクリーチャー判定
					var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
					if "アイテムクリーチャー" in keywords:
						should_gray_out = false
					else:
						# 援護対象判定
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
			elif filter_mode == "item_or_spell":
				# メタモルフォシス用: クリーチャーをグレーアウト
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
			elif filter_mode == "single_target_spell":
				# ルーンアデプト秘術用: 単体対象スペル以外をグレーアウト
				if card_type != "spell" or card_data.get("spell_type") != "単体対象":
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
				# + 土地条件未達のクリーチャーもグレーアウト
				if card_type == "spell" or card_type == "item":
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				elif card_type == "creature" and not _check_lands_required(card_data, player_id):
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
func create_pass_button(_hand_count: int):
	# 捨て札モードではパスボタンを作らない
	if selection_mode == "discard":
		return
	
	# 交換/移動など領地コマンド内のモードではパスボタンを作らない
	# （領地コマンドの「閉じる」ボタンが使われる）
	if selection_mode in ["swap", "move"]:
		return
	
	# グローバルボタンに戻るアクションを登録
	if ui_manager_ref:
		var back_text = "パス"
		match selection_mode:
			"summon":
				back_text = "召喚しない"
			"battle":
				back_text = "バトルしない"
			"invasion":
				back_text = "侵略しない"
			"spell":
				back_text = "スペルを使わない"
			"item":
				back_text = "アイテムを使わない"
		
		ui_manager_ref.register_back_action(_on_pass_button_pressed, back_text)

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
	
	# グローバルボタンをクリア
	if ui_manager_ref:
		ui_manager_ref.clear_back_action()
	
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
	if not is_active:
		return
	
	# クリーチャー情報パネルを使用するか判定
	# 召喚/交換モードでクリーチャーカードの場合
	if GameSettings.use_creature_info_panel and selection_mode in ["summon", "swap"]:
		var card_data = _get_card_data_for_index(card_index)
		if card_data and card_data.get("type") == "creature":
			_show_creature_info_panel(card_index, card_data)
			return
	
	# 既存の動作
	hide_selection()
	emit_signal("card_selected", card_index)


# クリーチャー情報パネルを表示
func _show_creature_info_panel(card_index: int, card_data: Dictionary):
	if not ui_manager_ref or not ui_manager_ref.creature_info_panel_ui:
		# フォールバック：既存の動作
		hide_selection()
		emit_signal("card_selected", card_index)
		return
	
	# ダブルクリック検出：同じカードを再度クリックした場合は即確定
	if pending_card_index == card_index and ui_manager_ref.creature_info_panel_ui.is_visible_panel:
		var confirm_data = card_data.duplicate()
		confirm_data["hand_index"] = card_index
		_on_creature_panel_confirmed(confirm_data)
		return
	
	pending_card_index = card_index
	
	# シグナル接続（初回のみ）
	if not creature_info_panel_connected:
		ui_manager_ref.creature_info_panel_ui.selection_confirmed.connect(_on_creature_panel_confirmed)
		ui_manager_ref.creature_info_panel_ui.selection_cancelled.connect(_on_creature_panel_cancelled)
		creature_info_panel_connected = true
	
	# カードデータにhand_indexを追加
	var panel_data = card_data.duplicate()
	panel_data["hand_index"] = card_index
	
	# 確認テキストを設定
	var confirmation_text = "召喚しますか？"
	if selection_mode == "battle":
		confirmation_text = "このクリーチャーで戦いますか？"
	elif selection_mode == "invasion":
		confirmation_text = "侵略しますか？"
	elif selection_mode == "swap":
		confirmation_text = "このクリーチャーに交換しますか？"
	
	ui_manager_ref.creature_info_panel_ui.show_selection_mode(panel_data, confirmation_text)


# クリーチャー情報パネルで確認された
func _on_creature_panel_confirmed(card_data: Dictionary):
	var card_index = card_data.get("hand_index", pending_card_index)
	pending_card_index = -1
	
	# 情報パネルを閉じる
	if ui_manager_ref and ui_manager_ref.creature_info_panel_ui:
		ui_manager_ref.creature_info_panel_ui.hide_panel()
	
	hide_selection()
	emit_signal("card_selected", card_index)


# クリーチャー情報パネルでキャンセルされた
func _on_creature_panel_cancelled():
	pending_card_index = -1
	# パネルを閉じるだけで選択UIは維持（再選択可能）
	
	# 選択中のカードのホバー状態を解除
	var card_script = load("res://scripts/card.gd")
	if card_script.currently_selected_card and card_script.currently_selected_card.has_method("deselect_card"):
		card_script.currently_selected_card.deselect_card()
	
	# 交換/移動モードの場合、領地のクリーチャー情報パネルを再表示
	if selection_mode in ["swap", "move"] and game_flow_manager_ref and game_flow_manager_ref.land_command_handler:
		var handler = game_flow_manager_ref.land_command_handler
		var tile_index = handler._swap_tile_index if selection_mode == "swap" else handler._move_from_tile_index
		if tile_index >= 0 and game_flow_manager_ref.board_system_3d:
			var board = game_flow_manager_ref.board_system_3d
			if board.tile_nodes.has(tile_index):
				var tile = board.tile_nodes[tile_index]
				var creature = tile.creature_data if tile else {}
				if not creature.is_empty() and ui_manager_ref and ui_manager_ref.creature_info_panel_ui:
					ui_manager_ref.creature_info_panel_ui.show_view_mode(creature, tile_index)
	
	# グローバルボタンを再登録
	_register_back_button_for_current_mode()


# 現在のモードに応じたグローバル戻るボタンを登録
func _register_back_button_for_current_mode():
	if not ui_manager_ref:
		return
	
	var back_text = "パス"
	match selection_mode:
		"summon":
			back_text = "召喚しない"
		"battle":
			back_text = "バトルしない"
		"invasion":
			back_text = "侵略しない"
		"spell":
			back_text = "スペルを使わない"
		"item":
			back_text = "アイテムを使わない"
		"swap":
			back_text = "交換しない"
		"move":
			back_text = "移動しない"
	
	ui_manager_ref.register_back_action(_on_pass_button_pressed, back_text)


# カードインデックスからカードデータを取得
func _get_card_data_for_index(card_index: int) -> Dictionary:
	if not card_system_ref:
		return {}
	
	# 現在のプレイヤーIDを取得
	var player_id = 0
	if game_flow_manager_ref and game_flow_manager_ref.player_system:
		var current_player = game_flow_manager_ref.player_system.get_current_player()
		if current_player:
			player_id = current_player.id
	
	var hand_data = card_system_ref.get_all_cards_for_player(player_id)
	if card_index >= 0 and card_index < hand_data.size():
		return hand_data[card_index]
	return {}

# パスボタンが押された
func _on_pass_button_pressed():
	if is_active:
		# 交換/移動モードの場合は召喚フェーズに戻る（ターン終了しない）
		if selection_mode in ["swap", "move"]:
			_cancel_land_command_and_return_to_summon()
		else:
			hide_selection()
			emit_signal("selection_cancelled")


# 領地コマンドをキャンセルして召喚フェーズに戻る
func _cancel_land_command_and_return_to_summon():
	hide_selection()
	
	# 領地コマンドの状態をリセット
	if game_flow_manager_ref and game_flow_manager_ref.land_command_handler:
		var handler = game_flow_manager_ref.land_command_handler
		handler._swap_mode = false
		handler._swap_old_creature = {}
		handler._swap_tile_index = -1
		handler.close_land_command()
	
	# TileActionProcessorのフラグもリセット
	if game_flow_manager_ref and game_flow_manager_ref.board_system_3d:
		var tap = game_flow_manager_ref.board_system_3d.tile_action_processor
		if tap:
			tap.is_action_processing = false
	
	# 召喚フェーズに戻る（カード選択UIを再初期化）
	if game_flow_manager_ref and game_flow_manager_ref.has_method("_reinitialize_card_selection"):
		game_flow_manager_ref._reinitialize_card_selection()

# 選択中かチェック
func is_selection_active() -> bool:
	return is_active

# 現在の選択モードを取得
func get_selection_mode() -> String:
	return selection_mode


# 土地条件チェック（true: 条件OK、false: 条件未達）
func _check_lands_required(card_data: Dictionary, player_id: int) -> bool:
	# ブライトワールド（召喚条件解除）が発動中ならOK
	if game_flow_manager_ref:
		var game_stats = game_flow_manager_ref.game_stats
		if SpellWorldCurse.is_summon_condition_ignored(game_stats):
			return true
	
	# デバッグフラグで無効化されている場合はOK
	if game_flow_manager_ref and game_flow_manager_ref.board_system_3d:
		var board = game_flow_manager_ref.board_system_3d
		if board.tile_action_processor and board.tile_action_processor.debug_disable_lands_required:
			return true
	
	# 土地条件を取得（属性の配列）
	var lands_required = _get_lands_required_array(card_data)
	if lands_required.is_empty():
		return true  # 条件なし
	
	# プレイヤーの所有土地の属性をカウント
	var owned_elements = {}  # {"fire": 2, "water": 1, ...}
	if game_flow_manager_ref and game_flow_manager_ref.board_system_3d:
		var board = game_flow_manager_ref.board_system_3d
		var player_tiles = board.get_player_tiles(player_id)
		for tile in player_tiles:
			var element = tile.tile_type if tile else ""
			if element != "" and element != "neutral":
				owned_elements[element] = owned_elements.get(element, 0) + 1
	
	# 必要な属性をカウント
	var required_elements = {}  # {"fire": 2, ...}
	for element in lands_required:
		required_elements[element] = required_elements.get(element, 0) + 1
	
	# 各属性の条件を満たしているかチェック
	for element in required_elements.keys():
		var required_count = required_elements[element]
		var owned_count = owned_elements.get(element, 0)
		if owned_count < required_count:
			return false
	
	return true


# 土地条件の配列を取得
func _get_lands_required_array(card_data: Dictionary) -> Array:
	# 正規化されたフィールドをチェック
	if card_data.has("cost_lands_required"):
		var lands = card_data.get("cost_lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
		return []
	# 正規化されていない場合、元のcostフィールドもチェック
	var cost = card_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		var lands = cost.get("lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
	return []
