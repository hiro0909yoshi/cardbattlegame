extends Node
class_name CardSelectionUI

const GC = preload("res://scripts/game_constants.gd")

# カード選択UI管理クラス
# 召喚・バトル時のカード選択インターフェース

signal card_selected(card_index: int)
signal selection_cancelled()
signal card_info_shown(card_index: int)  # インフォパネル表示時

# 定数をpreload
# GameSettingsはclass_nameで定義されているためグローバルアクセス可能

# UI要素
var selection_buttons = []     # 追加ボタン配列
var pass_button: Button = null # パスボタン
var parent_node: Node          # 親ノード参照
var phase_label_ref: Label     # フェーズラベル参照

# 状態
var is_active = false          # 選択UI表示中か
var selection_mode = ""        # "summon" or "battle"
var current_selection_player_id: int = 0  # 現在選択中のプレイヤーID
var current_selection_hand_data: Array = []  # 現在選択中のカードデータ配列
var pending_card_index: int = -1  # クリーチャー情報パネル確認待ちのカードインデックス
var creature_info_panel_connected: bool = false  # シグナル接続済みフラグ
var item_creature_panel_connected: bool = false  # アイテムフェーズ用シグナル接続済みフラグ

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
	
	# 前回の選択状態をリセット（ダブルクリック検出誤動作防止）
	pending_card_index = -1
	
	# 入力ロックを解除（選択待ち状態になった）
	if game_flow_manager_ref:
		game_flow_manager_ref.unlock_input()
	
	# 既存のボタンをクリア
	cleanup_buttons()
	
	# プレイヤーの手札を取得
	var hand_data = card_system_ref.get_all_cards_for_player(current_player.id)
	if hand_data.is_empty():
		emit_signal("selection_cancelled")
		return
	
	is_active = true
	selection_mode = mode
	current_selection_player_id = current_player.id  # 選択中のプレイヤーIDを保存
	
	# フェーズラベルを更新
	update_phase_label(current_player, mode)
	
	# デバッグモード（全員手動）またはプレイヤー1の場合、カード選択・パスボタン有効
	var allow_manual = (current_player.id == 0) or (game_flow_manager_ref and game_flow_manager_ref.debug_manual_control_all)
	
	# カード選択状態の更新（グレーアウト含む）- CPU/プレイヤー共通
	enable_card_selection(hand_data, current_player.magic_power, current_player.id)
	
	# パスボタンはプレイヤー操作時のみ作成
	if allow_manual and mode != "spell":
		create_pass_button(hand_data.size())

# フェーズラベルを更新
func update_phase_label(current_player, mode: String):
	if not phase_label_ref:
		return
	
	# アクション指示パネルで表示
	var message = ""
	match mode:
		"summon":
			message = "召喚するクリーチャーを選択"
		"battle":
			message = "バトルするクリーチャーを選択、または×でパス"
		"discard":
			var hand_size = card_system_ref.get_hand_size_for_player(current_player.id)
			var cards_to_discard = hand_size - 6
			message = "手札を6枚まで減らしてください（%d枚捨てる）" % cards_to_discard
		"spell":
			message = "スペルを選択してください"
		"item":
			if ui_manager_ref and ui_manager_ref.card_selection_filter == "item_or_assist":
				message = "アイテムまたは援護クリーチャーを選択"
			else:
				message = "アイテムを選択、または×でバトル開始"
		"sacrifice":
			message = "犠牲にするカードを選択"
		"spell_borrow":
			message = "使用するスペルを選択してください"
		_:
			message = "カードを選択してください"
	
	if ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.show_action_prompt(message)
	else:
		phase_label_ref.text = message

# カード選択を有効化
func enable_card_selection(hand_data: Array, available_magic: int, player_id: int = 0):
	if not ui_manager_ref:
		return
	
	# 選択UIを有効化
	is_active = true
	
	# カードデータとプレイヤーIDを保存（_get_card_data_for_indexで使用）
	current_selection_hand_data = hand_data
	current_selection_player_id = player_id
	
	# UIManagerのフィルター設定を確認
	var filter_mode = ui_manager_ref.card_selection_filter
	
	# UIManagerから手札ノードを取得（指定されたプレイヤーの手札）
	var hand_nodes = ui_manager_ref.get_player_card_nodes(player_id)
	
	# 最初に全カードのmodulateをリセット（前の状態をクリア）
	for card_node in hand_nodes:
		if card_node and is_instance_valid(card_node):
			card_node.modulate = Color(1.0, 1.0, 1.0)
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
			var card_id = card_data.get("id", -1)
			
			# 選択可能状態を判定
			var is_selectable = true
			
			# チュートリアル制限チェック
			if not _check_tutorial_card_allowed(card_id):
				is_selectable = false
			# disabledモード: すべて選択不可
			elif filter_mode == "disabled":
				is_selectable = false
			# 捨て札モードではすべて選択可能
			elif selection_mode == "discard":
				is_selectable = true
			# 犠牲モードではすべて選択可能（ただし召喚カード自身は除外）
			elif selection_mode == "sacrifice":
				var is_excluded = false
				# インデックスで除外
				if ui_manager_ref and ui_manager_ref.excluded_card_index == i:
					is_excluded = true
				# IDで除外
				if ui_manager_ref and ui_manager_ref.excluded_card_id != "" and card_data.get("id", "") == ui_manager_ref.excluded_card_id:
					is_excluded = true
				is_selectable = not is_excluded
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
				# ルーンアデプトアルカナアーツ用: 単体対象スペルのみ選択可能
				is_selectable = card_type == "spell" and card_data.get("spell_type") == "単体対象"
			elif filter_mode == "creature":
				# レムレースアルカナアーツ用: クリーチャーのみ選択可能
				is_selectable = card_type == "creature"
			else:
				# 召喚フェーズ等: クリーチャーカードのみ選択可能
				is_selectable = card_type == "creature"
			
				# 土地条件チェック（召喚/バトルフェーズでクリーチャーの場合）
			# 犠牲/捨て札モードではスキップ
			if is_selectable and card_type == "creature" and (filter_mode == "" or filter_mode == "battle"):
				if selection_mode != "sacrifice" and selection_mode != "discard":
					if not _check_lands_required(card_data, player_id):
						is_selectable = false
			
			# 配置制限チェック（召喚/バトルフェーズでクリーチャーの場合）
			# 犠牲/捨て札モードではスキップ
			if is_selectable and card_type == "creature" and (filter_mode == "" or filter_mode == "battle"):
				if selection_mode != "sacrifice" and selection_mode != "discard":
					if not _check_cannot_summon(card_data, player_id):
						is_selectable = false
			
			# 犠牲/捨て札モードは最優先で全カード選択可能（ただし除外カードはグレーアウト）
			if selection_mode == "sacrifice" or selection_mode == "discard":
				var is_excluded = false
				if selection_mode == "sacrifice" and ui_manager_ref:
					if ui_manager_ref.excluded_card_index == i:
						is_excluded = true
					if ui_manager_ref.excluded_card_id != "" and card_data.get("id", "") == ui_manager_ref.excluded_card_id:
						is_excluded = true
				
				# 除外カード以外は全て選択可能
				if not is_excluded:
					card_node.set_selectable(true, i)
					card_node.is_grayed_out = false
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				else:
					card_node.set_selectable(false, -1)
					card_node.card_index = i
					card_node.is_grayed_out = true
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
			else:
				# 通常モード: カードを選択可能/不可にする
				if card_node.has_method("set_selectable") and is_selectable:
					card_node.set_selectable(true, i)
					card_node.is_grayed_out = false
				elif card_node.has_method("set_selectable"):
					card_node.set_selectable(false, -1)
					card_node.card_index = i
					card_node.is_grayed_out = true
				
				# グレーアウト処理
				if filter_mode == "disabled":
					# disabledモード: すべてグレーアウト
					card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
				elif filter_mode == "battle":
					# バトルフェーズ中: 非クリーチャー + 防御型クリーチャー + 土地条件未達 + 配置制限をグレーアウト
					if card_type != "creature":
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						var creature_type = card_data.get("creature_type", "normal")
						if creature_type == "defensive":
							card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
						elif not _check_lands_required(card_data, player_id):
							card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
						elif not _check_cannot_summon(card_data, player_id):
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
					# スペル不可呪い中: スペルカードをグレーアウト（アルカナアーツは使用可能）
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
						var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
						if "アイテムクリーチャー" in keywords:
							should_gray = false
					if not should_gray and ui_manager_ref and "blocked_item_types" in ui_manager_ref:
						var item_type = card_data.get("item_type", "")
						if item_type in ui_manager_ref.blocked_item_types:
							should_gray = true
					if should_gray:
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				elif filter_mode == "item_or_assist":
					# アイテムフェーズ（援護あり）
					var should_gray_out = true
					if card_type == "item":
						should_gray_out = false
						if ui_manager_ref and "blocked_item_types" in ui_manager_ref:
							var item_type = card_data.get("item_type", "")
							if item_type in ui_manager_ref.blocked_item_types:
								should_gray_out = true
					elif card_type == "creature":
						var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
						if "アイテムクリーチャー" in keywords:
							should_gray_out = false
						else:
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
					if card_type == "creature":
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				elif filter_mode == "item_or_spell":
					if card_type == "creature":
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				elif filter_mode == "destroy_any":
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				elif filter_mode == "destroy_spell":
					if card_type != "spell":
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				elif filter_mode == "single_target_spell":
					if card_type != "spell" or card_data.get("spell_type") != "単体対象":
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				elif filter_mode == "creature":
					if card_type != "creature":
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				elif filter_mode == "":
					# 通常フェーズ（召喚等）
					if card_type == "spell" or card_type == "item":
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					elif card_type == "creature" and not _check_lands_required(card_data, player_id):
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					elif card_type == "creature" and not _check_cannot_summon(card_data, player_id):
						card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
					else:
						card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
				else:
					card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
			# 制限理由を設定（犠牲/捨て札モードでは設定しない）
			if card_node.has_method("set_restriction_reason"):
				if selection_mode in ["sacrifice", "discard"]:
					card_node.set_restriction_reason("")  # 制限なし
				else:
					var reason = _get_restriction_reason(card_data, card_type, filter_mode, player_id, available_magic)
					card_node.set_restriction_reason(reason)
			
			# 犠牲/捨て札モードでは全て選択可能、それ以外はコストチェック
			if selection_mode in ["sacrifice", "discard"]:
				add_card_highlight(card_node, card_data, 999999, true)  # 全て選択可能
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
		cost = cost_data.get("ep", 0)
	else:
		cost = cost_data
	if cost > available_magic:
		# EP不足の場合
		card_node.modulate = GC.COLOR_GRAYOUT_MODULATE
		highlight.color = Color(0.5, 0.5, 0.5, 0.3)
	else:
		# 選択可能
		highlight.color = GC.COLOR_HIGHLIGHT
	
	card_node.add_child(highlight)


# 制限理由を判定（選択可能でも制限がある場合はアイコン表示）
# 戻り値: "ep"（EP不足/土地条件）, "restriction"（配置制限/呪い等）, ""（制限なし）
func _get_restriction_reason(card_data: Dictionary, card_type: String, filter_mode: String, player_id: int, available_magic: int) -> String:
	# フェーズで使えないカード（タイプ不一致）は制限アイコンなし（グレーアウトのみ）
	match filter_mode:
		"spell":
			if card_type != "spell":
				return ""  # フェーズ不一致はアイコンなし
		"spell_disabled":
			pass  # 後でチェック
		"item", "item_or_assist":
			if card_type != "item":
				var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
				if "アイテムクリーチャー" not in keywords:
					# 援護対象の場合もアイコンなし
					if filter_mode == "item_or_assist" and card_type == "creature":
						pass  # 援護対象は後でチェック
					else:
						return ""  # フェーズ不一致はアイコンなし
		"battle":
			if card_type != "creature":
				return ""  # フェーズ不一致はアイコンなし
		"":
			if card_type != "creature":
				return ""  # フェーズ不一致はアイコンなし
	
	# EP不足チェック
	var card_cost = card_data.get("cost", 0)
	if typeof(card_cost) == TYPE_DICTIONARY:
		card_cost = card_cost.get("ep", 0)
	
	if card_cost > available_magic:
		# フェーズに合ったカードタイプの場合のみ
		if filter_mode == "spell" and card_type == "spell":
			return "ep"
		if filter_mode in ["item", "item_or_assist"] and card_type == "item":
			return "ep"
		if filter_mode in ["", "battle"] and card_type == "creature":
			return "ep"
	
	# クリーチャーカードの場合、土地条件/配置制限をチェック
	if card_type == "creature" and filter_mode in ["", "battle"]:
		# 土地条件未達
		if not _check_lands_required(card_data, player_id):
			return "ep"
		
		# 配置制限
		if not _check_cannot_summon(card_data, player_id):
			return "restriction"
		
		# 防御型クリーチャー（バトルフェーズ）
		if filter_mode == "battle":
			var creature_type = card_data.get("creature_type", "normal")
			if creature_type == "defensive":
				return "restriction"
	
	# スペル不可呪い
	if filter_mode == "spell_disabled" and card_type == "spell":
		return "restriction"
	
	# ブロックされたアイテムタイプ
	if card_type == "item" and ui_manager_ref and "blocked_item_types" in ui_manager_ref:
		var item_type = card_data.get("item_type", "")
		if item_type in ui_manager_ref.blocked_item_types:
			return "restriction"
	
	return ""


# カードインデックスから制限理由を取得
func _get_card_restriction_reason(card_index: int) -> String:
	if not ui_manager_ref or not ui_manager_ref.hand_display:
		return ""
	
	var card_node = ui_manager_ref.hand_display.get_card_node(card_index)
	if card_node and "restriction_reason" in card_node:
		return card_node.restriction_reason
	return ""


# パスボタンを作成
func create_pass_button(_hand_count: int):
	# 捨て札モードではパスボタンを作らない
	if selection_mode == "discard":
		return
	
	# グローバルボタンに戻るアクションを登録
	if ui_manager_ref:
		var back_text = "パス"
		match selection_mode:
			"summon":
				back_text = "召喚しない"
			"battle":
				back_text = "バトルしない"
			"spell":
				back_text = "スペルを使わない"
			"item":
				back_text = "アイテムを使わない"
			"swap":
				back_text = "交換しない"
			"move":
				back_text = "移動しない"
			"sacrifice":
				back_text = "召喚をキャンセル"
		
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
	current_selection_hand_data = []  # カードデータをクリア
	
	# グローバルボタンをクリア
	if ui_manager_ref:
		ui_manager_ref.clear_back_action()
	
	# カード選択モードを解除
	if card_system_ref:
		disable_card_selection()
	
	# ボタンをクリア
	cleanup_buttons()
	
	# アクション指示パネルを閉じる
	if ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.hide_action_prompt()

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
	# 注意: modulateのリセットはenable_card_selection側で行う
	# ここでリセットすると、グレーアウト状態が意図せず解除されてしまう

# ボタンをクリーンアップ
func cleanup_buttons():
	for button in selection_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	selection_buttons.clear()
	pass_button = null


# カード選択を確定し、シグナルを発火する（入力ロック付き）
func _confirm_card_selection(card_index: int):
	# 入力をロック（連打防止）
	if game_flow_manager_ref:
		game_flow_manager_ref.lock_input()
	
	# アクション指示パネルを閉じる
	if ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.hide_action_prompt()
	
	hide_selection()
	emit_signal("card_selected", card_index)


# カードが選択された（外部から呼ばれる）
func on_card_selected(card_index: int):
	print("[CardSelectionUI] on_card_selected called: index=%d, is_active=%s, selection_mode=%s" % [card_index, is_active, selection_mode])
	
	# プレイヤーステータスダイアログが開いていたら閉じる
	if ui_manager_ref and ui_manager_ref.player_status_dialog and ui_manager_ref.player_status_dialog.is_dialog_visible():
		ui_manager_ref.player_status_dialog.hide_dialog()
	
	if not is_active:
		print("[CardSelectionUI] not active, returning")
		return
	
	var card_data = _get_card_data_for_index(card_index)
	if not card_data:
		print("[CardSelectionUI] no card_data for index %d" % card_index)
		return
	
	# チュートリアル制限チェック（タップ時に弾く）
	var card_id = card_data.get("id", -1)
	if not _check_tutorial_card_allowed(card_id):
		print("[CardSelectionUI] card %d blocked by tutorial restriction" % card_id)
		return
	
	print("[CardSelectionUI] card_type=%s, card_name=%s" % [card_data.get("type", "?"), card_data.get("name", "?")])
	
	# スペルフェーズでスペルカードの場合 → スペル情報パネル表示
	if selection_mode == "spell" and card_data.get("type") == "spell":
		_show_spell_info_panel(card_index, card_data)
		emit_signal("card_info_shown", card_index)
		return
	
	# アイテムフェーズの場合
	if selection_mode == "item":
		var card_type = card_data.get("type", "")
		if card_type == "item":
			# アイテムカード → アイテム情報パネル表示
			_show_item_info_panel(card_index, card_data)
			return
		elif card_type == "creature":
			# アイテムクリーチャーまたは援護クリーチャー → クリーチャー情報パネル表示
			_show_creature_info_panel_for_item(card_index, card_data)
			return
	
	# クリーチャー情報パネルを使用するか判定
	# 召喚/交換/犠牲モードでクリーチャーカードの場合
	if GameSettings.use_creature_info_panel and selection_mode in ["summon", "swap", "sacrifice", "discard"]:
		if card_data.get("type") == "creature":
			print("[CardSelectionUI] showing creature_info_panel for sacrifice/summon/swap/discard")
			_show_creature_info_panel(card_index, card_data)
			emit_signal("card_info_shown", card_index)
			return
	
	# 犠牲/捨て札モードでスペル/アイテムカードの場合も確認パネル表示
	if selection_mode in ["sacrifice", "discard"]:
		var card_type = card_data.get("type", "")
		if card_type == "spell":
			_show_spell_info_panel(card_index, card_data)
			return
		elif card_type == "item":
			_show_item_info_panel(card_index, card_data)
			return
	
	print("[CardSelectionUI] fallback to _confirm_card_selection")
	# 既存の動作
	_confirm_card_selection(card_index)


# クリーチャー情報パネルを表示
func _show_creature_info_panel(card_index: int, card_data: Dictionary):
	if not ui_manager_ref or not ui_manager_ref.creature_info_panel_ui:
		# フォールバック：既存の動作
		_confirm_card_selection(card_index)
		return
	
	# カードノードから制限理由を取得（犠牲/捨て札モードでは無視）
	var restriction_reason = ""
	if selection_mode not in ["sacrifice", "discard"]:
		restriction_reason = _get_card_restriction_reason(card_index)
	
	# ダブルクリック検出：同じカードを再度クリックした場合は即確定（制限がない場合のみ）
	if pending_card_index == card_index and ui_manager_ref.creature_info_panel_ui.is_visible_panel and restriction_reason == "":
		var confirm_data = card_data.duplicate()
		confirm_data["hand_index"] = card_index
		_on_creature_panel_confirmed(confirm_data)
		return
	
	# 他のパネルを閉じる（ボタンはクリアしない）
	if ui_manager_ref.creature_info_panel_ui.is_visible_panel:
		ui_manager_ref.creature_info_panel_ui.hide_panel(false)
	if ui_manager_ref.spell_info_panel_ui and ui_manager_ref.spell_info_panel_ui.is_panel_visible():
		ui_manager_ref.spell_info_panel_ui.hide_panel(false)
	if ui_manager_ref.item_info_panel_ui and ui_manager_ref.item_info_panel_ui.is_visible_panel:
		ui_manager_ref.item_info_panel_ui.hide_panel(false)
	
	pending_card_index = card_index
	
	# アイテム用のシグナル接続を切断（重複呼び出し防止）
	if item_creature_panel_connected:
		if ui_manager_ref.creature_info_panel_ui.selection_confirmed.is_connected(_on_item_creature_panel_confirmed):
			ui_manager_ref.creature_info_panel_ui.selection_confirmed.disconnect(_on_item_creature_panel_confirmed)
		if ui_manager_ref.creature_info_panel_ui.selection_cancelled.is_connected(_on_item_creature_panel_cancelled):
			ui_manager_ref.creature_info_panel_ui.selection_cancelled.disconnect(_on_item_creature_panel_cancelled)
		item_creature_panel_connected = false
	
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
	elif selection_mode == "swap":
		confirmation_text = "このクリーチャーに交換しますか？"
	elif selection_mode == "sacrifice":
		confirmation_text = "犠牲にしますか？"
	elif selection_mode == "discard":
		confirmation_text = "このカードを捨てますか？"
	
	ui_manager_ref.creature_info_panel_ui.show_selection_mode(panel_data, confirmation_text, restriction_reason)
	
	# 召喚/バトルフェーズの場合、ドミニオコマンドボタンを再表示
	if selection_mode in ["summon", "battle"]:
		ui_manager_ref.show_dominio_order_button()


# スペル情報パネルを表示
func _show_spell_info_panel(card_index: int, card_data: Dictionary):
	if not ui_manager_ref or not ui_manager_ref.spell_info_panel_ui:
		# フォールバック：既存の動作
		_confirm_card_selection(card_index)
		return
	
	# 他のパネルを閉じる
	if ui_manager_ref.creature_info_panel_ui and ui_manager_ref.creature_info_panel_ui.is_visible_panel:
		ui_manager_ref.creature_info_panel_ui.hide_panel(false)
	if ui_manager_ref.item_info_panel_ui and ui_manager_ref.item_info_panel_ui.is_visible_panel:
		ui_manager_ref.item_info_panel_ui.hide_panel()
	
	# カードノードから制限理由を取得
	var restriction_reason = _get_card_restriction_reason(card_index)
	
	# ダブルクリック検出：同じカードを再度クリックした場合は即確定（制限がない場合のみ）
	if pending_card_index == card_index and ui_manager_ref.spell_info_panel_ui.is_panel_visible() and restriction_reason == "":
		var confirm_data = card_data.duplicate()
		confirm_data["hand_index"] = card_index
		_on_spell_panel_confirmed(confirm_data)
		return
	
	pending_card_index = card_index
	
	# シグナル接続（初回のみ）
	if not ui_manager_ref.spell_info_panel_ui.selection_confirmed.is_connected(_on_spell_panel_confirmed):
		ui_manager_ref.spell_info_panel_ui.selection_confirmed.connect(_on_spell_panel_confirmed)
		ui_manager_ref.spell_info_panel_ui.selection_cancelled.connect(_on_spell_panel_cancelled)
	
	# スペル情報パネルを表示
	ui_manager_ref.spell_info_panel_ui.show_spell_info(card_data, card_index, restriction_reason, selection_mode)


# スペル情報パネルで確認された
func _on_spell_panel_confirmed(card_data: Dictionary):
	var card_index = card_data.get("hand_index", pending_card_index)
	pending_card_index = -1
	
	# 情報パネルを閉じる（ダブルクリック時にも確実に閉じる）
	if ui_manager_ref and ui_manager_ref.spell_info_panel_ui:
		ui_manager_ref.spell_info_panel_ui.hide_panel()
	
	_confirm_card_selection(card_index)


# スペル情報パネルでキャンセルされた
func _on_spell_panel_cancelled():
	# card_selection_handlerが選択中の場合はそちらに任せる
	if game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
		var handler = game_flow_manager_ref.spell_phase_handler.card_selection_handler
		if handler and handler.is_selecting():
			return
	
	pending_card_index = -1
	# パネルを閉じるだけで選択UIは維持（再選択可能）
	
	# 選択中のカードのホバー状態を解除
	var card_script = load("res://scripts/card.gd")
	if card_script.currently_selected_card and card_script.currently_selected_card.has_method("deselect_card"):
		card_script.currently_selected_card.deselect_card()
	
	# 犠牲/捨て札モードの場合はフェーズコメントとボタンを復元
	if selection_mode in ["sacrifice", "discard"]:
		restore_phase_comment()
		_register_back_button_for_current_mode()
		return
	
	# SpellPhaseHandler経由でスペル選択画面に戻る
	if game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
		game_flow_manager_ref.spell_phase_handler._return_to_spell_selection()
	else:
		# フォールバック
		_setup_spell_phase_back_button()


# アイテム情報パネルを表示
func _show_item_info_panel(card_index: int, card_data: Dictionary):
	if not ui_manager_ref or not ui_manager_ref.item_info_panel_ui:
		# フォールバック：既存の動作
		_confirm_card_selection(card_index)
		return
	
	# 他のパネルを閉じる
	if ui_manager_ref.creature_info_panel_ui and ui_manager_ref.creature_info_panel_ui.is_visible_panel:
		ui_manager_ref.creature_info_panel_ui.hide_panel(false)
	if ui_manager_ref.spell_info_panel_ui and ui_manager_ref.spell_info_panel_ui.is_panel_visible():
		ui_manager_ref.spell_info_panel_ui.hide_panel(false)
	
	# カードノードから制限理由を取得
	var restriction_reason = _get_card_restriction_reason(card_index)
	
	# ダブルクリック検出：同じカードを再度クリックした場合は即確定（制限がない場合のみ）
	if pending_card_index == card_index and ui_manager_ref.item_info_panel_ui.is_visible_panel and restriction_reason == "":
		var confirm_data = card_data.duplicate()
		confirm_data["hand_index"] = card_index
		_on_item_panel_confirmed(confirm_data)
		return
	
	pending_card_index = card_index
	
	# シグナル接続（初回のみ）
	if not ui_manager_ref.item_info_panel_ui.selection_confirmed.is_connected(_on_item_panel_confirmed):
		ui_manager_ref.item_info_panel_ui.selection_confirmed.connect(_on_item_panel_confirmed)
		ui_manager_ref.item_info_panel_ui.selection_cancelled.connect(_on_item_panel_cancelled)
	
	# アイテム情報パネルを表示
	ui_manager_ref.item_info_panel_ui.show_item_info(card_data, card_index, restriction_reason, selection_mode)
	
	# インフォパネル表示シグナル発火
	emit_signal("card_info_shown", card_index)


# アイテム情報パネルで確認された
func _on_item_panel_confirmed(card_data: Dictionary):
	var card_index = card_data.get("hand_index", pending_card_index)
	pending_card_index = -1
	
	# 情報パネルを閉じる
	if ui_manager_ref and ui_manager_ref.item_info_panel_ui:
		ui_manager_ref.item_info_panel_ui.hide_panel()
	
	_confirm_card_selection(card_index)


# アイテム情報パネルでキャンセルされた
func _on_item_panel_cancelled():
	# card_selection_handlerが選択中の場合はそちらに任せる
	if game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
		var handler = game_flow_manager_ref.spell_phase_handler.card_selection_handler
		if handler and handler.is_selecting():
			return
	
	pending_card_index = -1
	# パネルを閉じるだけで選択UIは維持（再選択可能）
	
	# 選択中のカードのホバー状態を解除
	var card_script = load("res://scripts/card.gd")
	if card_script.currently_selected_card and card_script.currently_selected_card.has_method("deselect_card"):
		card_script.currently_selected_card.deselect_card()
	
	# 犠牲/捨て札モードの場合はフェーズコメントとボタンを復元
	if selection_mode in ["sacrifice", "discard"]:
		restore_phase_comment()
		_register_back_button_for_current_mode()
		return
	
	# アイテム選択に戻る（ナビゲーション再設定）
	_setup_item_phase_back_button()


# アイテムフェーズでクリーチャー（アイテムクリーチャーまたは援護）の情報パネルを表示
func _show_creature_info_panel_for_item(card_index: int, card_data: Dictionary):
	if not ui_manager_ref or not ui_manager_ref.creature_info_panel_ui:
		# フォールバック：既存の動作
		_confirm_card_selection(card_index)
		return
	
	# 他のパネルを閉じる
	if ui_manager_ref.item_info_panel_ui and ui_manager_ref.item_info_panel_ui.is_visible_panel:
		ui_manager_ref.item_info_panel_ui.hide_panel(false)
	
	# ダブルクリック検出：同じカードを再度クリックした場合は即確定
	if pending_card_index == card_index and ui_manager_ref.creature_info_panel_ui.is_visible_panel:
		var confirm_data = card_data.duplicate()
		confirm_data["hand_index"] = card_index
		_on_item_creature_panel_confirmed(confirm_data)
		return
	
	pending_card_index = card_index
	
	# 召喚用のシグナル接続を一時的に切断（重複呼び出し防止）
	if creature_info_panel_connected:
		if ui_manager_ref.creature_info_panel_ui.selection_confirmed.is_connected(_on_creature_panel_confirmed):
			ui_manager_ref.creature_info_panel_ui.selection_confirmed.disconnect(_on_creature_panel_confirmed)
		if ui_manager_ref.creature_info_panel_ui.selection_cancelled.is_connected(_on_creature_panel_cancelled):
			ui_manager_ref.creature_info_panel_ui.selection_cancelled.disconnect(_on_creature_panel_cancelled)
		creature_info_panel_connected = false
	
	# シグナル接続（初回のみ）- アイテムフェーズ用の専用ハンドラを使用
	if not item_creature_panel_connected:
		ui_manager_ref.creature_info_panel_ui.selection_confirmed.connect(_on_item_creature_panel_confirmed)
		ui_manager_ref.creature_info_panel_ui.selection_cancelled.connect(_on_item_creature_panel_cancelled)
		item_creature_panel_connected = true
	
	# カードデータにhand_indexを追加
	var panel_data = card_data.duplicate()
	panel_data["hand_index"] = card_index
	
	# 確認テキストを設定
	var confirmation_text = "このクリーチャーを使用しますか？"
	if SkillItemCreature.is_item_creature(card_data):
		confirmation_text = "アイテムとして使用しますか？"
	else:
		confirmation_text = "援護として使用しますか？"
	
	ui_manager_ref.creature_info_panel_ui.show_selection_mode(panel_data, confirmation_text)


# アイテムフェーズでクリーチャー情報パネルが確認された
func _on_item_creature_panel_confirmed(card_data: Dictionary):
	var card_index = card_data.get("hand_index", pending_card_index)
	pending_card_index = -1
	
	# 情報パネルを閉じる
	if ui_manager_ref and ui_manager_ref.creature_info_panel_ui:
		ui_manager_ref.creature_info_panel_ui.hide_panel()
	
	_confirm_card_selection(card_index)


# アイテムフェーズでクリーチャー情報パネルがキャンセルされた
func _on_item_creature_panel_cancelled():
	# card_selection_handlerが選択中の場合はそちらに任せる
	if game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
		var handler = game_flow_manager_ref.spell_phase_handler.card_selection_handler
		if handler and handler.is_selecting():
			return
	
	pending_card_index = -1
	# パネルを閉じるだけで選択UIは維持（再選択可能）
	
	# 選択中のカードのホバー状態を解除
	var card_script = load("res://scripts/card.gd")
	if card_script.currently_selected_card and card_script.currently_selected_card.has_method("deselect_card"):
		card_script.currently_selected_card.deselect_card()
	
	# アイテム選択に戻る（ナビゲーション再設定）
	_setup_item_phase_back_button()


# アイテムフェーズの戻るボタン設定
func _setup_item_phase_back_button():
	if ui_manager_ref:
		ui_manager_ref.enable_navigation(
			Callable(),  # 決定なし
			func(): _on_pass_button_pressed()  # 戻る→パス
		)


# スペルフェーズ用のナビゲーションを設定（決定 = サイコロへ）
func _setup_spell_phase_back_button():
	if ui_manager_ref:
		ui_manager_ref.enable_navigation(
			func(): _on_spell_phase_skip(),  # 決定 = スペルを使わない → サイコロ
			Callable()  # 戻るなし
		)


# スペルフェーズをスキップ（スペルを使わない）
func _on_spell_phase_skip():
	hide_selection()
	
	# SpellPhaseHandlerのpass_spell()を直接呼ぶ
	if game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
		game_flow_manager_ref.spell_phase_handler.pass_spell()
	else:
		emit_signal("selection_cancelled")


# クリーチャー情報パネルで確認された
func _on_creature_panel_confirmed(card_data: Dictionary):
	var card_index = card_data.get("hand_index", pending_card_index)
	pending_card_index = -1
	
	# 情報パネルを閉じる
	if ui_manager_ref and ui_manager_ref.creature_info_panel_ui:
		ui_manager_ref.creature_info_panel_ui.hide_panel()
	
	_confirm_card_selection(card_index)


# クリーチャー情報パネルでキャンセルされた
func _on_creature_panel_cancelled():
	# card_selection_handlerが選択中の場合はそちらに任せる
	if game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
		var handler = game_flow_manager_ref.spell_phase_handler.card_selection_handler
		if handler and handler.is_selecting():
			return
	
	pending_card_index = -1
	# パネルを閉じるだけで選択UIは維持（再選択可能）
	
	# 選択中のカードのホバー状態を解除
	var card_script = load("res://scripts/card.gd")
	if card_script.currently_selected_card and card_script.currently_selected_card.has_method("deselect_card"):
		card_script.currently_selected_card.deselect_card()
	
	# フェーズコメントを復元
	restore_phase_comment()
	
	# グローバルボタンを再登録
	_register_back_button_for_current_mode()
	
	# 召喚/バトルフェーズの場合、ドミニオコマンドボタンを再表示
	if selection_mode in ["summon", "battle"] and ui_manager_ref:
		ui_manager_ref.show_dominio_order_button()


# 現在のモードに応じたグローバル戻るボタンを登録
func _register_back_button_for_current_mode():
	if not ui_manager_ref:
		return
	
	# 捨て札モードは戻るボタンなし（強制）
	if selection_mode == "discard":
		ui_manager_ref.clear_back_action()
		# 入力ロック解除（カード選択は継続）
		if game_flow_manager_ref:
			game_flow_manager_ref.unlock_input()
		return
	
	var back_text = "パス"
	match selection_mode:
		"summon":
			back_text = "召喚しない"
		"battle":
			back_text = "バトルしない"
		"spell":
			back_text = "スペルを使わない"
		"item":
			back_text = "アイテムを使わない"
		"swap":
			back_text = "交換しない"
		"move":
			back_text = "移動しない"
		"sacrifice":
			back_text = "召喚をキャンセル"
	
	ui_manager_ref.register_back_action(_on_pass_button_pressed, back_text)


# フェーズコメントを再表示（グレーアウトカード閲覧後など）
func restore_phase_comment():
	if not ui_manager_ref or not ui_manager_ref.phase_display:
		return
	
	var message = ""
	match selection_mode:
		"summon":
			message = "召喚するクリーチャーを選択"
		"battle":
			message = "バトルするクリーチャーを選択、または×でパス"
		"spell":
			message = "スペルを使用するか、ダイスを振ってください"
		"item":
			if ui_manager_ref.card_selection_filter == "item_or_assist":
				message = "アイテムまたは援護クリーチャーを選択"
			else:
				message = "アイテムを選択、または×でバトル開始"
		"sacrifice":
			message = "犠牲にするカードを選択"
		"swap":
			message = "交換する新しいクリーチャーを選択"
		"move":
			message = "移動先のクリーチャーを選択"
		_:
			message = "カードを選択してください"
	
	ui_manager_ref.phase_display.show_action_prompt(message)


# カードインデックスからカードデータを取得
func _get_card_data_for_index(card_index: int) -> Dictionary:
	# enable_card_selectionで保存したカードデータを優先使用（デッキカード選択等に対応）
	if not current_selection_hand_data.is_empty():
		if card_index >= 0 and card_index < current_selection_hand_data.size():
			return current_selection_hand_data[card_index]
		return {}
	
	# フォールバック: CardSystemから取得
	if not card_system_ref:
		return {}
	
	# 選択中のプレイヤーIDを使用（防衛側アイテムフェーズなどに対応）
	var hand_data = card_system_ref.get_all_cards_for_player(current_selection_player_id)
	if card_index >= 0 and card_index < hand_data.size():
		return hand_data[card_index]
	return {}

# パスボタンが押された
func _on_pass_button_pressed():
	# 開いているインフォパネルがあれば閉じるだけ（パスしない）
	var info_panel_was_open = false
	if ui_manager_ref:
		if ui_manager_ref.creature_info_panel_ui and ui_manager_ref.creature_info_panel_ui.is_visible_panel:
			ui_manager_ref.creature_info_panel_ui.hide_panel(false)
			info_panel_was_open = true
		if ui_manager_ref.spell_info_panel_ui and ui_manager_ref.spell_info_panel_ui.is_panel_visible():
			ui_manager_ref.spell_info_panel_ui.hide_panel(false)
			info_panel_was_open = true
		if ui_manager_ref.item_info_panel_ui and ui_manager_ref.item_info_panel_ui.is_visible_panel:
			ui_manager_ref.item_info_panel_ui.hide_panel(false)
			info_panel_was_open = true
	
	# インフォパネルが開いていた場合は閉じてナビゲーションを復元
	if info_panel_was_open:
		# ドミニオコマンド中またはアルカナアーツ中かどうか確認
		var is_special_phase_active = false
		if game_flow_manager_ref:
			# ドミニオコマンド中
			if game_flow_manager_ref.dominio_command_handler:
				var dominio = game_flow_manager_ref.dominio_command_handler
				if dominio.current_state != dominio.State.CLOSED:
					is_special_phase_active = true
			# アルカナアーツ中
			if game_flow_manager_ref.spell_phase_handler and game_flow_manager_ref.spell_phase_handler.spell_mystic_arts:
				if game_flow_manager_ref.spell_phase_handler.spell_mystic_arts.is_active():
					is_special_phase_active = true
		
		# 特殊フェーズ中は何もしない（各フェーズ側でナビゲーション管理）
		if is_special_phase_active:
			return
		
		# スペルフェーズとアイテムフェーズは専用のナビゲーション設定
		if selection_mode == "spell":
			_setup_spell_phase_back_button()
		elif selection_mode == "item":
			_setup_item_phase_back_button()
		else:
			_register_back_button_for_current_mode()
		return
	
	if is_active:
		# 交換/移動モードの場合はアクションメニューに戻る
		if selection_mode in ["swap", "move"]:
			_cancel_dominio_order_and_return_to_action_menu()
		elif selection_mode == "sacrifice":
			# 犠牲モードの場合はcard_selectedに-1を送って召喚をキャンセル
			hide_selection()
			if ui_manager_ref:
				ui_manager_ref.emit_signal("card_selected", -1)
		else:
			hide_selection()
			emit_signal("selection_cancelled")


# 交換/移動モードをキャンセルしてアクションメニューに戻る
func _cancel_dominio_order_and_return_to_action_menu():
	hide_selection()
	
	# dominio_command_handlerのcancel()を呼ぶ（状態管理を統一）
	if game_flow_manager_ref and game_flow_manager_ref.dominio_command_handler:
		game_flow_manager_ref.dominio_command_handler.cancel()

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
	
	# リリース呪い（制限解除）が発動中ならOK
	if game_flow_manager_ref and game_flow_manager_ref.player_system:
		var p_system = game_flow_manager_ref.player_system
		if player_id >= 0 and player_id < p_system.players.size():
			var player = p_system.players[player_id]
			var player_dict = {"curse": player.curse}
			if SpellRestriction.is_summon_condition_released(player_dict):
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
	var cost_dict = card_data.get("cost", {})
	if typeof(cost_dict) == TYPE_DICTIONARY:
		var lands = cost_dict.get("lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
	return []


# 配置制限チェック（true: 配置OK、false: 配置不可）
# cannot_summon: 特定属性の土地には配置できない制限
func _check_cannot_summon(card_data: Dictionary, player_id: int) -> bool:
	# ブライトワールド（召喚条件解除）が発動中ならOK
	if game_flow_manager_ref:
		var game_stats = game_flow_manager_ref.game_stats
		if SpellWorldCurse.is_summon_condition_ignored(game_stats):
			return true
	
	# リリース呪い（制限解除）が発動中ならOK
	if game_flow_manager_ref and game_flow_manager_ref.player_system:
		var p_system = game_flow_manager_ref.player_system
		if player_id >= 0 and player_id < p_system.players.size():
			var player = p_system.players[player_id]
			var player_dict = {"curse": player.curse}
			if SpellRestriction.is_summon_condition_released(player_dict):
				return true
	
	# デバッグフラグで無効化されている場合はOK
	if game_flow_manager_ref and game_flow_manager_ref.board_system_3d:
		var board = game_flow_manager_ref.board_system_3d
		if board.tile_action_processor and board.tile_action_processor.debug_disable_cannot_summon:
			return true
	
	# 配置制限を取得
	var restrictions = card_data.get("restrictions", {})
	var cannot_summon = restrictions.get("cannot_summon", [])
	if cannot_summon.is_empty():
		return true  # 制限なし
	
	# 現在のタイル属性を取得
	var current_tile_element = _get_current_tile_element(player_id)
	if current_tile_element.is_empty():
		return true  # タイル情報取得不可の場合はOK
	
	# 配置制限に引っかかるかチェック
	if current_tile_element in cannot_summon:
		return false
	
	return true


# プレイヤーの現在タイル属性を取得
func _get_current_tile_element(player_id: int) -> String:
	if not game_flow_manager_ref or not game_flow_manager_ref.board_system_3d:
		return ""
	
	var board = game_flow_manager_ref.board_system_3d
	if not board.movement_controller:
		return ""
	
	var tile_index = board.movement_controller.get_player_tile(player_id)
	if tile_index < 0:
		return ""
	
	if not board.tile_nodes.has(tile_index):
		return ""
	
	var tile = board.tile_nodes[tile_index]
	return tile.tile_type if tile else ""


# チュートリアル制限チェック
func _check_tutorial_card_allowed(card_id: int) -> bool:
	# TutorialManagerを取得
	var tutorial_manager = _get_tutorial_manager()
	if not tutorial_manager or not tutorial_manager.is_active:
		return true  # チュートリアルでなければ制限なし
	
	return tutorial_manager.is_card_allowed(card_id)


# TutorialManagerを取得
func _get_tutorial_manager():
	if not game_flow_manager_ref:
		return null
	
	# game_flow_managerの親（Game3D）からTutorialManagerを取得
	var game_3d = game_flow_manager_ref.get_parent()
	if game_3d and game_3d.has_node("TutorialManager"):
		return game_3d.get_node("TutorialManager")
	return null
