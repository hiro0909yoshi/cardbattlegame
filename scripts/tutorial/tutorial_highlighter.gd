extends Node
class_name TutorialHighlighter
## 全てのハイライト処理を一元管理

# 外部参照
var board_system_3d = null
var ui_manager = null

# オーバーレイ（既存のTutorialOverlayを活用）
var _overlay: Control = null

# アクティブなハイライト
var _active_highlights: Array = []

func setup(bsys, uim):
	board_system_3d = bsys
	ui_manager = uim
	
	_create_overlay()

## オーバーレイを作成
func _create_overlay():
	var TutorialOverlayClass = load("res://scripts/tutorial/tutorial_overlay.gd")
	_overlay = TutorialOverlayClass.new()
	_overlay.name = "TutorialOverlay"
	
	# GlobalActionButtonsへの参照を設定
	if ui_manager and ui_manager.global_action_buttons:
		_overlay.set_global_action_buttons(ui_manager.global_action_buttons)
	
	var canvas = CanvasLayer.new()
	canvas.name = "HighlighterCanvas"
	canvas.layer = 99
	canvas.add_child(_overlay)
	add_child(canvas)

## ハイライトを適用
func apply_highlights(highlights: Array):
	clear_all()
	
	if highlights.is_empty():
		return
	
	for h in highlights:
		var h_type = h.get("type", "")
		match h_type:
			"button":
				_highlight_buttons(h.get("targets", []))
			"card":
				_highlight_cards(h.get("filter", ""))
			"tile_toll":
				_highlight_tile_toll(h.get("target", ""))
			"3d_object":
				_highlight_3d_object(h.get("target", {}))
		
		_active_highlights.append(h)

## ボタンをハイライト
func _highlight_buttons(targets: Array):
	if _overlay and targets.size() > 0:
		_overlay.highlight_buttons(targets, false)

## カードをハイライト
func _highlight_cards(filter: String):
	if not _overlay or not ui_manager:
		return
	
	var card_nodes = _get_hand_card_nodes(filter)
	if card_nodes.size() > 0:
		_overlay.highlight_hand_cards(card_nodes, false)

## 通行料ラベルをハイライト
func _highlight_tile_toll(target):
	if not _overlay or not board_system_3d:
		return
	
	var tile_index: int = -1
	
	if target is String:
		match target:
			"player_creature":
				tile_index = _find_player_creature_tile(0)
			"player_position":
				if board_system_3d.game_flow_manager and board_system_3d.game_flow_manager.player_system:
					tile_index = board_system_3d.game_flow_manager.player_system.get_player_position(0)
	elif target is int:
		tile_index = target
	
	if tile_index < 0:
		return
	
	# TileInfoDisplayからラベルを取得
	var tile_info_display = board_system_3d.tile_info_display
	if not tile_info_display:
		return
	
	var label = tile_info_display.tile_labels.get(tile_index)
	if not label or not label.visible:
		return
	
	var camera = board_system_3d.camera
	if not camera:
		return
	
	_overlay.highlight_3d_object(label, camera, Vector2(200, 80))

## 3Dオブジェクトをハイライト
func _highlight_3d_object(target: Dictionary):
	# 将来の拡張用
	pass

## プレイヤーのクリーチャーがいるタイルを探す
func _find_player_creature_tile(player_id: int) -> int:
	if not board_system_3d:
		return -1
	
	for tile_index in board_system_3d.tile_nodes.keys():
		var tile = board_system_3d.tile_nodes[tile_index]
		if tile and tile.owner_id == player_id and not tile.creature_data.is_empty():
			return tile_index
	
	return -1

## 手札のカードノードを取得
func _get_hand_card_nodes(filter: String = "") -> Array:
	var result = []
	
	if not ui_manager or not ui_manager.card_selection_ui:
		return result
	
	var card_ui = ui_manager.card_selection_ui
	if not card_ui.has_method("get_card_buttons"):
		# フォールバック: 直接子ノードを探す
		var card_container = card_ui.get_node_or_null("CardContainer")
		if card_container:
			for child in card_container.get_children():
				if filter == "" or _card_matches_filter(child, filter):
					result.append(child)
		return result
	
	var card_buttons = card_ui.get_card_buttons()
	for btn in card_buttons:
		if filter == "" or _card_matches_filter(btn, filter):
			result.append(btn)
	
	return result

## カードがフィルタにマッチするか
func _card_matches_filter(card_node, filter: String) -> bool:
	if filter == "":
		return true
	
	# card_dataを持っている場合
	if card_node.has_method("get_card_data"):
		var data = card_node.get_card_data()
		var card_id = str(data.get("id", ""))
		var card_name = data.get("name", "")
		return card_id == filter or filter in card_name.to_lower()
	
	# card_idプロパティを持っている場合
	if "card_id" in card_node:
		return str(card_node.card_id) == filter
	
	return false

## 全てクリア
func clear_all():
	_active_highlights.clear()
	if _overlay:
		_overlay.hide_overlay()

## ボタンを全て無効化（ハイライトなし）
func disable_all_buttons():
	if _overlay:
		_overlay.disable_all_buttons()
