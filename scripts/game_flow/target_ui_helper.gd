# TargetUIHelper - ターゲット選択UI補助
#
# ターゲット選択時のUI表示・入力処理を担当
# - ターゲット情報のテキストフォーマット
# - 確認テキスト生成
# - 入力ヘルパー（数字キー判定）
# - クリーチャー情報パネル表示
# - ターゲットインデックス操作
#
# 使用例:
#   var text = TargetUIHelper.format_target_info(target, 1, 5)
#   if TargetUIHelper.is_number_key(event.keycode):
#       var index = TargetUIHelper.get_number_from_key(event.keycode)
extends RefCounted
class_name TargetUIHelper

# ============================================
# 内部ヘルパー
# ============================================

## ハンドラーの実際の所有者を取得（SpellPhaseHandlerの場合はspell_target_selection_handlerを返す）
static func _get_actual_handler(handler):
	if handler and "spell_target_selection_handler" in handler and handler.spell_target_selection_handler:
		return handler.spell_target_selection_handler
	return handler

# ============================================
# テキストフォーマット
# ============================================

## ターゲット情報を日本語テキストに変換
## 
## target_data: ターゲット情報
## current_index: 現在のインデックス（1始まり）
## total_count: 総ターゲット数
## 戻り値: 表示用テキスト
static func format_target_info(target_data: Dictionary, current_index: int, total_count: int) -> String:
	var text = "対象を選択: [↑↓で切替]\n"
	text += "対象 %d/%d: " % [current_index, total_count]
	
	# ターゲット情報表示
	match target_data.get("type", ""):
		"land":
			var tile_idx = target_data.get("tile_index", -1)
			var element = target_data.get("element", "neutral")
			var level = target_data.get("level", 1)
			var owner_id = target_data.get("owner", -1)
			
			# 属性名を日本語に変換
			var element_name = _get_element_name_jp(element)
			
			var owner_id_text = ""
			if owner_id >= 0:
				owner_id_text = " (P%d)" % (owner_id + 1)
			
			text += "タイル%d %s Lv%d%s" % [tile_idx, element_name, level, owner_id_text]
		
		"creature":
			var tile_idx = target_data.get("tile_index", -1)
			var creature_name = target_data.get("creature", {}).get("name", "???")
			text += "タイル%d %s" % [tile_idx, creature_name]
		
		"player":
			var player_id = target_data.get("player_id", -1)
			text += "プレイヤー%d" % (player_id + 1)
		
		"gate":
			var tile_idx = target_data.get("tile_index", -1)
			var gate_key = target_data.get("gate_key", "")
			var gate_name = "北ゲート" if gate_key == "N" else "南ゲート"
			text += "%s (タイル%d)" % [gate_name, tile_idx]
	
	text += "\n[Enter: 次へ] [C: 閉じる]"
	return text


## 確認フェーズ用：対象の説明テキストを生成
## 
## target_type: "self", "all_creatures", "all_players", "world", "none"
## target_count: ハイライトされた対象数
## 戻り値: 説明テキスト
static func get_confirmation_text(target_type: String, target_count: int) -> String:
	match target_type:
		"self":
			return "自分自身に効果を発動します"
		"none":
			return "効果を発動します"
		"all_creatures":
			if target_count > 0:
				return "クリーチャー %d体に効果を発動します" % target_count
			else:
				return "対象となるクリーチャーがいません"
		"all_players":
			if target_count > 0:
				return "プレイヤー %d人に効果を発動します" % target_count
			else:
				return "対象となるプレイヤーがいません"
		"world":
			return "世界全体に効果を発動します"
		_:
			return "効果を発動します"


## 属性名を日本語に変換
static func _get_element_name_jp(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		"neutral": return "無"
		_: return element


# ============================================
# 入力ヘルパー
# ============================================

## 数字キーかどうか
static func is_number_key(keycode: int) -> bool:
	return keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]


## キーコードから数字を取得（0-9）
static func get_number_from_key(keycode: int) -> int:
	var key_to_index = {
		KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4,
		KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9
	}
	return key_to_index.get(keycode, -1)


# ============================================
# ターゲットインデックス操作
# ============================================

## ターゲットインデックスを次へ移動
##
## handler: available_targets, current_target_index を持つオブジェクト
## 戻り値: インデックスが変更されたか
static func move_target_next(handler) -> bool:
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return false

	if actual_handler.current_target_index < actual_handler.available_targets.size() - 1:
		actual_handler.current_target_index += 1
		return true
	return false


## ターゲットインデックスを前へ移動
##
## handler: available_targets, current_target_index を持つオブジェクト
## 戻り値: インデックスが変更されたか
static func move_target_previous(handler) -> bool:
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return false

	if actual_handler.current_target_index > 0:
		actual_handler.current_target_index -= 1
		return true
	return false


## ターゲットを数字で直接選択
##
## handler: available_targets, current_target_index を持つオブジェクト
## index: 選択するインデックス
## 戻り値: 選択が成功したか
static func select_target_by_index(handler, index: int) -> bool:
	var actual_handler = _get_actual_handler(handler)
	if not actual_handler:
		return false

	if index < actual_handler.available_targets.size():
		actual_handler.current_target_index = index
		return true
	return false


# ============================================
# クリーチャー情報パネル
# ============================================

## ターゲットがクリーチャーの場合、情報パネルを表示
static func show_creature_info_panel(handler, target_data: Dictionary) -> void:
	var target_type = target_data.get("type", "")
	var tile_index = target_data.get("tile_index", -1)

	# クリーチャー対象でない場合はパネルを閉じる
	if target_type != "creature":
		hide_creature_info_panel(handler)
		return

	var creature_data = target_data.get("creature", {})

	# クリーチャーデータがない場合はパネルを閉じる
	if creature_data.is_empty():
		hide_creature_info_panel(handler)
		return

	# handlerから InfoPanelService を取得
	var info_panel_service = _get_info_panel_service(handler)

	if not info_panel_service:
		return

	# setup_buttons=false でナビゲーションボタンを設定しない
	info_panel_service.show_card_info_only(creature_data, tile_index)


## クリーチャー情報パネルを非表示
static func hide_creature_info_panel(handler) -> void:
	var info_panel_service = _get_info_panel_service(handler)

	if not info_panel_service:
		return

	info_panel_service.hide_all_info_panels(false)


## handlerから InfoPanelService を取得
static func _get_info_panel_service(handler):
	# handler直接に _info_panel_service がある場合
	if "_info_panel_service" in handler and handler._info_panel_service:
		return handler._info_panel_service

	# ui_manager 経由で取得
	var ui_mgr = _get_ui_manager(handler)
	if ui_mgr and ui_mgr.has_meta("info_panel_service"):
		return ui_mgr.get_meta("info_panel_service")
	elif ui_mgr and "info_panel_service" in ui_mgr:
		return ui_mgr.info_panel_service

	return null

## handlerからui_managerを取得（後方互換性）
static func _get_ui_manager(handler):
	if "ui_manager" in handler and handler.ui_manager:
		return handler.ui_manager
	# Phase 6: SpellPhaseHandler は spell_ui_manager 経由でアクセス
	if "spell_ui_manager" in handler and handler.spell_ui_manager:
		return handler.spell_ui_manager._ui_manager
	return null
