# SpellBorrow - スペル借用効果
# ルーンアデプトアルカナアーツ「自手札のスペルカードの効果を使用」
# テンプテーション「対象クリーチャーのアルカナアーツを使用」
class_name SpellBorrow
extends RefCounted


# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var card_system_ref: Object
var spell_phase_handler_ref: Object


## UIManagerへの参照を取得（Phase 6: ui_manager は spell_ui_manager 経由でアクセス）
func _get_ui_manager():
	if spell_phase_handler_ref and spell_phase_handler_ref.spell_ui_manager:
		return spell_phase_handler_ref.spell_ui_manager._ui_manager
	return null

## CardSelectionServiceへの参照を取得
func _get_card_selection_service():
	var ui_mgr = _get_ui_manager()
	if ui_mgr and ui_mgr.get("card_selection_service"):
		return ui_mgr.card_selection_service
	return null


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, card_sys: Object, spell_phase_handler: Object = null) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler


# ============ ルーンアデプトアルカナアーツ ============

## 手札から「単体対象」スペルのみを取得
func get_hand_single_target_spells(player_id: int) -> Array:
	if not card_system_ref:
		return []
	
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	return hand.filter(func(card): 
		return card.get("type") == "spell" and card.get("spell_type") == "単体対象"
	)


## ルーンアデプトアルカナアーツの発動可能判定
func can_cast_use_hand_spell(player_id: int) -> bool:
	return get_hand_single_target_spells(player_id).size() > 0


## 手札スペル借用（ルーンアデプトアルカナアーツ）
func apply_use_hand_spell(caster_player_id: int) -> Dictionary:
	# 1. 手札から単体対象スペルを取得
	var spells = get_hand_single_target_spells(caster_player_id)
	if spells.is_empty():
		return {"success": false, "reason": "no_single_target_spell"}
	
	# 2. スペル選択UI
	var selected_result = await _select_hand_spell(spells, "使用するスペルを選択")
	if selected_result.get("cancelled", false):
		return {"success": false, "reason": "cancelled"}
	
	var selected_spell = selected_result.get("spell", {})
	var hand_index = selected_result.get("hand_index", -1)
	
	if selected_spell.is_empty() or hand_index < 0:
		return {"success": false, "reason": "invalid_selection"}
	
	# 3. 選択スペルの効果を実行（ターゲット選択含む）
	var effect_parsed = selected_spell.get("effect_parsed", {})
	if effect_parsed.is_empty():
		return {"success": false, "reason": "no_effect_parsed"}
	
	# ターゲット選択と効果適用
	var spell_result = await _execute_borrowed_spell(effect_parsed, caster_player_id)
	
	if spell_result.get("cancelled", false):
		return {"success": false, "reason": "cancelled"}
	
	# スペル借用はカードを消費しない（効果だけ使用）
	
	return {
		"success": true,
		"spell_name": selected_spell.get("name", "スペル")
	}


## 手札スペル選択UI
func _select_hand_spell(spells: Array, message: String) -> Dictionary:
	var css = _get_card_selection_service()

	if not css:
		# UIなしの場合は最初のスペルを選択
		if spells.size() > 0:
			return {"spell": spells[0], "hand_index": _find_hand_index(spells[0]), "cancelled": false}
		return {"cancelled": true}

	# メッセージ表示（UIManager固有 — set_message はサービス未実装）
	var ui_manager = _get_ui_manager()
	if ui_manager and ui_manager.has_method("set_message"):
		ui_manager.set_message(message)

	# カード選択UIを表示（単体対象スペルのみハイライト）
	var current_player_id = spell_phase_handler_ref.spell_state.current_player_id
	if player_system_ref:
		var player = player_system_ref.players[current_player_id]
		css.card_selection_filter = "single_target_spell"
		css.show_card_selection_ui_mode(player, "spell_borrow")

	# カード選択を待つ（CardSelectionService 経由）
	var selected_index = await css.card_selected

	# UIを閉じる
	css.hide_card_selection_ui()
	css.card_selection_filter = ""
	
	# キャンセル判定
	if selected_index < 0:
		return {"cancelled": true}
	
	# 選択されたカードを取得
	var hand = card_system_ref.get_all_cards_for_player(current_player_id)
	if selected_index >= hand.size():
		return {"cancelled": true}
	
	var selected_card = hand[selected_index]
	
	# 単体対象スペルかチェック
	if selected_card.get("type") != "spell" or selected_card.get("spell_type") != "単体対象":
		return {"cancelled": true}
	
	return {
		"spell": selected_card,
		"hand_index": selected_index,
		"cancelled": false
	}


## 手札内のインデックスを検索
func _find_hand_index(spell: Dictionary) -> int:
	if not card_system_ref or not spell_phase_handler_ref:
		return -1

	var player_id = spell_phase_handler_ref.spell_state.current_player_id
	var hand = card_system_ref.get_all_cards_for_player(player_id)
	
	for i in range(hand.size()):
		if hand[i].get("id") == spell.get("id"):
			return i
	
	return -1


## 借用スペルの効果を実行
func _execute_borrowed_spell(effect_parsed: Dictionary, _caster_player_id: int) -> Dictionary:
	if not spell_phase_handler_ref:
		return {"success": false, "reason": "no_handler"}
	
	var target_type = effect_parsed.get("target_type", "")
	var target_info = effect_parsed.get("target_info", {})
	var effects = effect_parsed.get("effects", [])
	
	# 借用スペルモードを有効化
	spell_phase_handler_ref.spell_state.set_borrow_spell_mode(true)
	
	# ターゲット選択UI表示（内部でターゲット取得も行われる）
	spell_phase_handler_ref.show_target_selection_ui(target_type, target_info)
	
	# ターゲット選択を待機
	var target_data = await spell_phase_handler_ref.target_confirmed
	
	if target_data.is_empty() or target_data.get("cancelled", false):
		TargetSelectionHelper.clear_selection(spell_phase_handler_ref)
		return {"cancelled": true}
	
	# 効果適用
	for effect in effects:
		await spell_phase_handler_ref.apply_single_effect(effect, target_data)
	
	# ターゲット選択クリア
	TargetSelectionHelper.clear_selection(spell_phase_handler_ref)
	
	return {"success": true}


## 手札のカードを破棄
func _destroy_card_at_hand_index(player_id: int, hand_index: int) -> void:
	if not card_system_ref:
		return
	
	var hand = card_system_ref.player_hands.get(player_id, {}).get("data", [])
	if hand_index < 0 or hand_index >= hand.size():
		return
	
	hand.remove_at(hand_index)
	card_system_ref.emit_signal("hand_updated")


# ============ テンプテーション ============

## 対象クリーチャーのアルカナアーツを使用（テンプテーション）
func apply_use_target_mystic_art(target_data: Dictionary, caster_player_id: int) -> Dictionary:
	if not spell_phase_handler_ref:
		return {"success": false, "reason": "no_handler"}
	
	var spell_mystic_arts = spell_phase_handler_ref.spell_mystic_arts
	if not spell_mystic_arts:
		return {"success": false, "reason": "no_mystic_arts_handler"}
	
	# ターゲットクリーチャーのアルカナアーツを取得
	var creature_data = target_data.get("creature", {})
	var tile_index = target_data.get("tile_index", -1)
	
	if creature_data.is_empty():
		return {"success": false, "reason": "no_creature"}
	
	# アルカナアーツを取得（use_hand_spell は除外）
	var all_mystic_arts = spell_mystic_arts.get_all_mystic_arts(creature_data)
	var mystic_arts = all_mystic_arts.filter(func(art):
		var effects = art.get("effects", [])
		for effect in effects:
			if effect.get("effect_type", "") == "use_hand_spell":
				return false
		return true
	)
	
	if mystic_arts.is_empty():
		return {"success": false, "reason": "no_mystic_arts"}
	
	# アルカナアーツが1つなら自動選択、複数なら選択UI
	var selected_mystic_art: Dictionary
	if mystic_arts.size() == 1:
		selected_mystic_art = mystic_arts[0]
	else:
		# アルカナアーツ選択UI表示
		selected_mystic_art = _select_mystic_art(mystic_arts, creature_data.get("name", "クリーチャー"))
		if selected_mystic_art.is_empty():
			return {"cancelled": true}
	
	# アルカナアーツを実行（コスト無料）
	var selected_creature = {
		"tile_index": tile_index,
		"creature_data": creature_data,
		"mystic_arts": mystic_arts
	}
	
	# アルカナアーツのターゲット情報を取得
	var target_type = selected_mystic_art.get("target_type", "")
	var target_info = selected_mystic_art.get("target_info", {})
	
	# selfまたはnoneの場合はすぐ実行
	if target_type == "self" or target_type == "none" or target_type == "":
		var mystic_target_data = {
			"type": target_type,
			"tile_index": tile_index,
			"player_id": caster_player_id
		}
		await spell_mystic_arts.execute_mystic_art(selected_creature, selected_mystic_art, mystic_target_data)
	else:
		# ターゲット選択が必要
		spell_phase_handler_ref.spell_state.set_borrow_spell_mode(true)
		spell_phase_handler_ref.show_target_selection_ui(target_type, target_info)
		
		var mystic_target_data = await spell_phase_handler_ref.target_confirmed
		
		if mystic_target_data.is_empty() or mystic_target_data.get("cancelled", false):
			return {"cancelled": true}
		
		await spell_mystic_arts.execute_mystic_art(selected_creature, selected_mystic_art, mystic_target_data)
	
	return {"success": true}


## アルカナアーツ選択UI（複数ある場合）
func _select_mystic_art(mystic_arts: Array, _creature_name: String) -> Dictionary:
	# 簡易実装：複数アルカナアーツの場合は最初のものを選択
	# TODO: アルカナアーツ選択UIを実装
	if mystic_arts.size() > 0:
		return mystic_arts[0]
	return {}
