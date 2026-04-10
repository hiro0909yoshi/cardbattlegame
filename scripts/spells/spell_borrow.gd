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
var _card_selection_service: Object = null
var _message_service: Object = null


## サービス直接注入（Phase 8-P: 3段チェーン解消）
func set_services(css: Object, msg_service: Object) -> void:
	_card_selection_service = css
	_message_service = msg_service


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
	if selected_spell.is_empty():
		return {"success": false, "reason": "invalid_selection"}

	# 3. 選択スペルの効果を canonical spell pipeline に委譲して実行
	# 仕様(b): 手札スペル選択完了後はターゲット不在/キャンセルでもアルカナアーツ確定使用扱い
	await _execute_borrowed_spell(selected_spell, caster_player_id)

	return {
		"success": true,
		"spell_name": selected_spell.get("name", "スペル")
	}


## 手札スペル選択UI
func _select_hand_spell(spells: Array, _message: String) -> Dictionary:
	var css = _card_selection_service

	if not css:
		# UIなしの場合は最初のスペルを選択
		if spells.size() > 0:
			return {"spell": spells[0], "hand_index": _find_hand_index(spells[0]), "cancelled": false}
		return {"cancelled": true}

	# カード選択UIを表示（単体対象スペルのみハイライト）
	var current_player_id = spell_phase_handler_ref.spell_state.current_player_id
	if player_system_ref:
		var player = player_system_ref.players[current_player_id]
		if _card_selection_service:
			_card_selection_service.card_selection_filter = "single_target_spell"
		css.show_card_selection_ui_mode(player, "spell_borrow")

	# カード選択を待つ（CardSelectionService 経由）
	var selected_index = await css.card_selected

	# UIを閉じる
	css.hide_card_selection_ui()
	if _card_selection_service:
		_card_selection_service.card_selection_filter = ""

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


## 借用スペルの効果を実行（canonical spell pipeline に委譲）
##
## 通常スペル詠唱と同じ経路 (use_spell → execute_spell_effect → complete_spell_phase) を流用する。
## is_hand_borrow_mode フラグにより:
##   - スペル本体コストの支払いをスキップ
##   - カード犠牲を無効化
##   - キャンセル時の cost 返却をスキップ
## カード手札消費は is_external_spell_mode (execute_external_spell が自動設定) でスキップされる。
## 完了時は execute_external_spell が external_spell_finished を await して戻ってくる。
func _execute_borrowed_spell(selected_spell: Dictionary, caster_player_id: int) -> Dictionary:
	if not spell_phase_handler_ref:
		return {"success": false, "reason": "no_handler"}

	var spell_state = spell_phase_handler_ref.spell_state
	if not spell_state:
		return {"success": false, "reason": "no_state"}

	# 手札借用モードを有効化（cost/犠牲/cost返却スキップ）
	spell_state.set_hand_borrow_mode(true)

	# canonical pipeline で実行（execute_external_spell が完了処理まで一括処理）
	# selected_spell は手札参照ではなくコピーを渡す（手札消費はモードにより自動スキップされるが念のため）
	var spell_copy = selected_spell.duplicate(true)
	var result = await spell_phase_handler_ref.execute_external_spell(spell_copy, caster_player_id, false)

	# 借用モード解除
	spell_state.set_hand_borrow_mode(false)

	# ワープ系スペル(テレポ等)が使われた場合は skip_dice_phase を立て直す
	# execute_external_spell が内部で skip_dice_phase をリセットするため、
	# アルカナアーツ完了→GFM のサイコロスキップ判定に伝わるよう再設定する
	if result.get("warped", false):
		spell_state.set_skip_dice_phase(true)

	return result


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
