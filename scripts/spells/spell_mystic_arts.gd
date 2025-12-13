class_name SpellMysticArts
extends RefCounted

# ============ シグナル ============

## 秘術フェーズ完了時（成功/キャンセル問わず）
signal mystic_phase_completed()

## 秘術使用完了時（スペル使用フラグ更新用）
signal mystic_art_used()

## ターゲット選択が必要な時
signal target_selection_requested(targets: Array)

## UIメッセージ表示要求
signal ui_message_requested(message: String)


# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var card_system_ref: Object
var spell_phase_handler_ref: Object  # ターゲット取得用


# ============ 秘術フェーズ状態 ============

var is_mystic_phase_active: bool = false
var selected_mystic_art: Dictionary = {}
var selected_mystic_creature: Dictionary = {}
var current_mystic_player_id: int = -1

# 確認フェーズ用
var is_confirming: bool = false
var confirmation_creature: Dictionary = {}
var confirmation_mystic_art: Dictionary = {}
var confirmation_target_type: String = ""
var confirmation_target_info: Dictionary = {}
var confirmation_target_data: Dictionary = {}


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, card_sys: Object, spell_phase_handler: Object) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler


# ============ 秘術フェーズ管理 ============

## 秘術フェーズを開始
func start_mystic_phase(player_id: int) -> void:
	is_mystic_phase_active = true
	current_mystic_player_id = player_id
	
	# ナチュラルワールドによる秘術無効化チェック
	if _is_mystic_arts_disabled():
		ui_message_requested.emit("ナチュラルワールド発動中：秘術は使用できません")
		_end_mystic_phase()
		return
	
	# 秘術を持つクリーチャーを取得
	var available_creatures = get_available_creatures(player_id)
	
	if available_creatures.is_empty():
		ui_message_requested.emit("秘術を持つクリーチャーがありません")
		_end_mystic_phase()
		return
	
	# クリーチャー選択UIを表示
	await _select_creature(available_creatures)


## 秘術フェーズ中かどうか
func is_active() -> bool:
	return is_mystic_phase_active


## 秘術選択状態をクリア
func clear_selection() -> void:
	selected_mystic_art = {}
	selected_mystic_creature = {}


## 秘術フェーズを終了
func _end_mystic_phase() -> void:
	is_mystic_phase_active = false
	clear_selection()
	current_mystic_player_id = -1
	mystic_phase_completed.emit()


## クリーチャー選択
func _select_creature(available_creatures: Array) -> void:
	var ui_manager = spell_phase_handler_ref.ui_manager if spell_phase_handler_ref else null
	if not ui_manager:
		_end_mystic_phase()
		return
	
	# ActionMenuUI を取得または作成
	var action_menu = ui_manager.get_node_or_null("MysticActionMenu")
	if not action_menu:
		var ActionMenuUIClass = load("res://scripts/ui_components/action_menu_ui.gd")
		if not ActionMenuUIClass:
			_end_mystic_phase()
			return
		
		action_menu = ActionMenuUIClass.new()
		action_menu.name = "MysticActionMenu"
		action_menu.set_ui_manager(ui_manager)
		action_menu.set_menu_size(650, 850, 130, 44, 40)  # 領地コマンドと同じサイズ
		action_menu.set_position_left(false)  # 右側（上下ボタンの左側）に配置
		ui_manager.add_child(action_menu)
	
	# クリーチャーメニュー項目を作成
	var menu_items: Array = []
	for creature in available_creatures:
		var creature_data = creature.get("creature_data", {})
		var name_text = creature_data.get("name", "Unknown")
		var tile_index = creature.get("tile_index", -1)
		menu_items.append({
			"text": "%s (タイル%d)" % [name_text, tile_index],
			"color": Color(0.3, 0.5, 0.7),
			"icon": "🐉",
			"disabled": false,
			"data": creature
		})
	
	# 選択変更時のカメラフォーカス
	if not action_menu.selection_changed.is_connected(_on_creature_selection_changed):
		action_menu.selection_changed.connect(_on_creature_selection_changed)
	
	# メニュー表示
	action_menu.show_menu(menu_items, "秘術を使うクリーチャー")
	
	# 最初のクリーチャーにカメラフォーカス
	if not available_creatures.is_empty():
		_focus_camera_on_creature(available_creatures[0])
	
	# 選択を待機
	var selected_index = await action_menu.item_selected
	
	if selected_index < 0 or selected_index >= available_creatures.size():
		# キャンセルされた場合、メニューを閉じてスペルフェーズに戻る
		action_menu.hide_menu()
		if spell_phase_handler_ref:
			spell_phase_handler_ref._return_to_spell_selection()
		_end_mystic_phase()
		return
	
	var selected_creature = available_creatures[selected_index]
	
	# 秘術選択に進む
	await _select_mystic_art_from_creature(selected_creature, action_menu)


## 秘術選択
func _select_mystic_art_from_creature(selected_creature: Dictionary, action_menu) -> void:
	var mystic_arts = selected_creature.get("mystic_arts", [])
	
	if mystic_arts.is_empty():
		action_menu.hide_menu()
		_end_mystic_phase()
		return
	
	# 秘術メニュー項目を作成
	var menu_items: Array = []
	for mystic_art in mystic_arts:
		var cost = mystic_art.get("cost", 0)
		var name_text = mystic_art.get("name", "Unknown")
		menu_items.append({
			"text": "%s [%dG]" % [name_text, cost],
			"color": Color(0.6, 0.3, 0.7),
			"icon": "✨",
			"disabled": false,
			"data": mystic_art
		})
	
	# メニュー表示
	action_menu.show_menu(menu_items, "使用する秘術")
	
	# 秘術選択を待機
	var selected_index = await action_menu.item_selected
	
	if selected_index < 0 or selected_index >= mystic_arts.size():
		action_menu.hide_menu()
		# キャンセルされた場合、スペルフェーズに戻る
		if spell_phase_handler_ref:
			spell_phase_handler_ref._return_to_spell_selection()
		_end_mystic_phase()
		return
	
	var mystic_art_selected = mystic_arts[selected_index]
	
	# UIを非表示
	action_menu.hide_menu()
	
	# ターゲット選択に進む
	await _select_target(selected_creature, mystic_art_selected)


## ターゲット選択
func _select_target(selected_creature: Dictionary, mystic_art: Dictionary) -> void:
	var target_type = mystic_art.get("target_type", "")
	var target_filter = mystic_art.get("target_filter", "any")
	var target_info = mystic_art.get("target_info", {})
	
	# target_infoからowner_filterを取得
	if not target_info.is_empty():
		target_filter = target_info.get("owner_filter", target_info.get("target_filter", target_filter))
	
	# spell_idがある場合はスペルデータからターゲット情報を取得
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var effect_parsed = spell_data.get("effect_parsed", {})
			target_type = effect_parsed.get("target_type", target_type)
			target_info = effect_parsed.get("target_info", target_info)
			# target_filterはeffect_parsed直下にある場合もある（land + creature等）
			var parsed_target_filter = effect_parsed.get("target_filter", "")
			if not parsed_target_filter.is_empty():
				target_info["target_filter"] = parsed_target_filter
			target_filter = target_info.get("owner_filter", target_info.get("target_filter", target_filter))
	
	# ターゲット不要（none）またはセルフターゲット時 → 確認フェーズへ
	if target_type == "none" or target_type == "self" or target_filter == "self":
		var target_data = {
			"type": target_type,
			"tile_index": selected_creature.get("tile_index", -1),
			"player_id": current_mystic_player_id
		}
		await _start_mystic_confirmation(selected_creature, mystic_art, "self", target_info, target_data)
		return
	
	# 全クリーチャー対象時 → 確認フェーズへ
	if target_type == "all_creatures":
		var target_data = {"type": "all_creatures"}
		await _start_mystic_confirmation(selected_creature, mystic_art, "all_creatures", target_info, target_data)
		return
	
	# 秘術選択状態を保存（ターゲット確定時に使用）
	selected_mystic_creature = selected_creature
	selected_mystic_art = mystic_art
	
	# ターゲット取得
	if target_info.is_empty():
		target_info = {"filter": target_filter}
	
	var targets = TargetSelectionHelper.get_valid_targets(spell_phase_handler_ref, target_type, target_info)
	
	if targets.is_empty():
		ui_message_requested.emit("有効なターゲットがありません")
		clear_selection()
		_end_mystic_phase()
		return
	
	# SpellPhaseHandlerにターゲット選択を依頼
	target_selection_requested.emit(targets)


## ターゲット確定時に呼ばれる（SpellPhaseHandlerから）
func on_target_confirmed(target_data: Dictionary) -> void:
	if selected_mystic_art.is_empty() or selected_mystic_creature.is_empty():
		return
	
	await execute_mystic_art(selected_mystic_creature, selected_mystic_art, target_data)


## 秘術実行
func execute_mystic_art(creature: Dictionary, mystic_art: Dictionary, target_data: Dictionary) -> void:
	var player_id = current_mystic_player_id
	
	# 発動判定
	var context = {
		"player_id": player_id,
		"player_magic": player_system_ref.get_magic(player_id) if player_system_ref else 0,
		"spell_used_this_turn": spell_phase_handler_ref.spell_used_this_turn if spell_phase_handler_ref else false,
		"tile_index": creature.get("tile_index", -1)
	}
	
	if not can_cast_mystic_art(mystic_art, context):
		ui_message_requested.emit("秘術発動条件を満たしていません")
		clear_selection()
		_end_mystic_phase()
		return
	
	# 発動通知を表示
	var caster_name = creature.get("creature_data", {}).get("name", "クリーチャー")
	if spell_phase_handler_ref:
		await spell_phase_handler_ref._show_spell_cast_notification(caster_name, target_data, mystic_art, true)
	
	# 非同期効果かどうかを事前判定
	var is_async = _is_async_mystic_art(mystic_art)
	
	# 秘術効果を適用
	var success = await apply_mystic_art_effect(mystic_art, target_data, context)
	
	if success:
		# 魔力消費
		var cost = mystic_art.get("cost", 0)
		if player_system_ref:
			player_system_ref.add_magic(player_id, -cost)
		if spell_phase_handler_ref:
			spell_phase_handler_ref.spell_used_this_turn = true
		
		# キャスターをダウン状態に設定
		_set_caster_down_state(creature.get("tile_index", -1), board_system_ref)
		
		ui_message_requested.emit("『%s』を発動しました！" % mystic_art.get("name", "Unknown"))
		
		# 排他制御
		mystic_art_used.emit()
	else:
		ui_message_requested.emit("秘術の発動に失敗しました")
	
	# 秘術選択状態をクリア
	clear_selection()
	
	# ターゲット選択をクリア
	if spell_phase_handler_ref:
		TargetSelectionHelper.clear_selection(spell_phase_handler_ref)
	
	# 少し待機してからカメラを戻す
	if spell_phase_handler_ref:
		await spell_phase_handler_ref.get_tree().create_timer(0.5).timeout
		spell_phase_handler_ref._return_camera_to_player()
	
	# 非同期効果の場合はCardSelectionHandler完了後に終了
	if is_async and spell_phase_handler_ref and spell_phase_handler_ref.card_selection_handler:
		if spell_phase_handler_ref.card_selection_handler.is_selecting():
			return
	
	# 秘術フェーズ完了
	if spell_phase_handler_ref:
		await spell_phase_handler_ref.get_tree().create_timer(0.5).timeout
	_end_mystic_phase()
	if spell_phase_handler_ref:
		spell_phase_handler_ref.complete_spell_phase()


## 秘術実行（全クリーチャー対象）
func _execute_all_creatures(creature: Dictionary, mystic_art: Dictionary, target_info: Dictionary) -> void:
	var player_id = current_mystic_player_id
	
	# 発動判定
	var context = {
		"player_id": player_id,
		"player_magic": player_system_ref.get_magic(player_id) if player_system_ref else 0,
		"spell_used_this_turn": spell_phase_handler_ref.spell_used_this_turn if spell_phase_handler_ref else false,
		"tile_index": creature.get("tile_index", -1)
	}
	
	if not can_cast_mystic_art(mystic_art, context):
		ui_message_requested.emit("秘術発動条件を満たしていません")
		clear_selection()
		_end_mystic_phase()
		return
	
	# 発動通知を表示
	var caster_name = creature.get("creature_data", {}).get("name", "クリーチャー")
	var target_data_for_notification = {"type": "all"}
	if spell_phase_handler_ref:
		await spell_phase_handler_ref._show_spell_cast_notification(caster_name, target_data_for_notification, mystic_art, true)
	
	# spell_idからeffectsを取得
	var spell_id = mystic_art.get("spell_id", -1)
	var effects = []
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var effect_parsed = spell_data.get("effect_parsed", {})
			effects = effect_parsed.get("effects", [])
	
	# ダメージ/回復効果をSpellDamageに委譲
	var handled = false
	if spell_phase_handler_ref and spell_phase_handler_ref.spell_damage:
		handled = await spell_phase_handler_ref.spell_damage.execute_all_creatures_effects(spell_phase_handler_ref, effects, target_info)
	
	# 未処理の場合、ステータス変更系はSpellCurseStatに委譲
	if not handled:
		for effect in effects:
			var effect_type = effect.get("effect_type", "")
			if effect_type in ["conditional_ap_change", "permanent_hp_change", "permanent_ap_change"]:
				if spell_phase_handler_ref and spell_phase_handler_ref.game_flow_manager and spell_phase_handler_ref.game_flow_manager.spell_curse_stat:
					var target_data = {"type": "all_creatures", "caster_tile_index": creature.get("tile_index", -1)}
					await spell_phase_handler_ref.game_flow_manager.spell_curse_stat.apply_effect(spell_phase_handler_ref, effect, target_data, player_id, mystic_art)
	
	# 魔力消費
	var cost = mystic_art.get("cost", 0)
	if player_system_ref:
		player_system_ref.add_magic(player_id, -cost)
	if spell_phase_handler_ref:
		spell_phase_handler_ref.spell_used_this_turn = true
	
	# キャスターをダウン状態に設定
	_set_caster_down_state(creature.get("tile_index", -1), board_system_ref)
	
	ui_message_requested.emit("『%s』を発動しました！" % mystic_art.get("name", "Unknown"))
	
	# 排他制御
	mystic_art_used.emit()
	
	# 秘術選択状態をクリア
	clear_selection()
	
	# スペルフェーズ完了
	if spell_phase_handler_ref:
		await spell_phase_handler_ref.get_tree().create_timer(0.5).timeout
		spell_phase_handler_ref._return_camera_to_player()
		await spell_phase_handler_ref.get_tree().create_timer(0.5).timeout
	
	_end_mystic_phase()
	if spell_phase_handler_ref:
		spell_phase_handler_ref.complete_spell_phase()


# ============ 確認フェーズ（全体対象/セルフ等） ============

## 確認フェーズを開始
func _start_mystic_confirmation(creature: Dictionary, mystic_art: Dictionary, target_type: String, target_info: Dictionary, target_data: Dictionary) -> void:
	is_confirming = true
	confirmation_creature = creature
	confirmation_mystic_art = mystic_art
	confirmation_target_type = target_type
	confirmation_target_info = target_info
	confirmation_target_data = target_data
	
	# 対象をハイライト表示
	var target_count = 0
	if spell_phase_handler_ref:
		target_count = TargetSelectionHelper.show_confirmation_highlights(spell_phase_handler_ref, target_type, target_info)
	
	# 対象がいない場合（all_creaturesで防魔等で0体）
	if target_type == "all_creatures" and target_count == 0:
		ui_message_requested.emit("対象となるクリーチャーがいません")
		_cancel_mystic_confirmation()
		return
	
	# 説明テキストを表示
	var confirmation_text = TargetSelectionHelper.get_confirmation_text(target_type, target_count)
	ui_message_requested.emit(confirmation_text)
	
	# ナビゲーションボタン設定（決定/戻る）
	if spell_phase_handler_ref and spell_phase_handler_ref.ui_manager:
		spell_phase_handler_ref.ui_manager.enable_navigation(
			func(): _confirm_mystic_effect(),  # 決定
			func(): _cancel_mystic_confirmation()  # 戻る
		)


## 確認フェーズ: 効果発動を確定
func _confirm_mystic_effect() -> void:
	if not is_confirming:
		return
	
	is_confirming = false
	
	# ハイライトとマーカーをクリア
	if spell_phase_handler_ref:
		TargetSelectionHelper.clear_all_highlights(spell_phase_handler_ref)
		TargetSelectionHelper.hide_selection_marker(spell_phase_handler_ref)
		TargetSelectionHelper.clear_confirmation_markers(spell_phase_handler_ref)
		
		# ナビゲーションを無効化
		if spell_phase_handler_ref.ui_manager:
			spell_phase_handler_ref.ui_manager.disable_navigation()
	
	# 保存した情報を取得
	var creature = confirmation_creature
	var mystic_art = confirmation_mystic_art
	var target_type = confirmation_target_type
	var target_info = confirmation_target_info
	var target_data = confirmation_target_data
	
	# 確認フェーズ変数をクリア
	confirmation_creature = {}
	confirmation_mystic_art = {}
	confirmation_target_type = ""
	confirmation_target_info = {}
	confirmation_target_data = {}
	
	# 対象タイプに応じて実行
	if target_type == "all_creatures":
		await _execute_all_creatures(creature, mystic_art, target_info)
	else:
		await execute_mystic_art(creature, mystic_art, target_data)


## 確認フェーズ: キャンセル
func _cancel_mystic_confirmation() -> void:
	is_confirming = false
	
	# ハイライトとマーカーをクリア
	if spell_phase_handler_ref:
		TargetSelectionHelper.clear_all_highlights(spell_phase_handler_ref)
		TargetSelectionHelper.hide_selection_marker(spell_phase_handler_ref)
		TargetSelectionHelper.clear_confirmation_markers(spell_phase_handler_ref)
	
	# 確認フェーズ変数をクリア
	confirmation_creature = {}
	confirmation_mystic_art = {}
	confirmation_target_type = ""
	confirmation_target_info = {}
	confirmation_target_data = {}
	
	# 秘術選択をクリアして秘術フェーズを終了
	clear_selection()
	_end_mystic_phase()
	
	# スペルフェーズに戻る（UI再表示 + ナビゲーション再設定）
	if spell_phase_handler_ref:
		spell_phase_handler_ref.current_state = spell_phase_handler_ref.State.WAITING_FOR_INPUT
		spell_phase_handler_ref._return_to_spell_selection()


## 非同期効果を含む秘術かどうかを判定
func _is_async_mystic_art(mystic_art: Dictionary) -> bool:
	const ASYNC_EFFECT_TYPES = [
		"destroy_and_draw", "swap_creature",
		"destroy_selected_card", "steal_selected_card",
		"destroy_from_deck_selection", "draw_from_deck_selection",
		"move_self", "move_steps", "move_to_adjacent_enemy", "destroy_and_move"
	]
	
	# spell_id参照の場合
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var spell_effects = spell_data.get("effect_parsed", {}).get("effects", [])
			for effect in spell_effects:
				if effect.get("effect_type", "") in ASYNC_EFFECT_TYPES:
					return true
		return false
	
	# 直接effects定義の場合
	var effects = mystic_art.get("effects", [])
	for effect in effects:
		if effect.get("effect_type", "") in ASYNC_EFFECT_TYPES:
			return true
	
	return false


# ============ 秘術情報取得 ============

## プレイヤーの秘術発動可能クリーチャーを取得
func get_available_creatures(player_id: int) -> Array:
	var available: Array = []
	
	var player_tiles = board_system_ref.get_player_tiles(player_id)
	if player_tiles.is_empty():
		return available
	
	for tile in player_tiles:
		if not tile or not tile.creature_data:
			continue
		
		# ダウン状態のクリーチャーは秘術使用不可
		if tile.is_down():
			continue
		
		# 秘術を取得（元々の秘術 + 呪いからの秘術）
		var mystic_arts = _get_all_mystic_arts(tile.creature_data)
		
		# 使用可能な秘術のみフィルタリング
		var usable_mystic_arts = _filter_usable_mystic_arts(mystic_arts, tile.creature_data, player_id)
		
		if usable_mystic_arts.size() > 0:
			available.append({
				"tile_index": tile.tile_index,
				"creature_data": tile.creature_data,
				"mystic_arts": usable_mystic_arts
			})
	
	return available


## 使用可能な秘術のみをフィルタリング
func _filter_usable_mystic_arts(mystic_arts: Array, creature_data: Dictionary, player_id: int) -> Array:
	var usable: Array = []
	
	for mystic_art in mystic_arts:
		if _can_use_mystic_art(mystic_art, creature_data, player_id):
			usable.append(mystic_art)
	
	return usable


## 秘術が使用可能かチェック
func _can_use_mystic_art(mystic_art: Dictionary, creature_data: Dictionary, player_id: int) -> bool:
	var effects = mystic_art.get("effects", [])
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		# 移動系秘術で移動不可呪いを持っている場合は使用不可
		if effect_type in ["move_self", "move_steps", "move_to_adjacent_enemy"]:
			var curse = creature_data.get("curse", {})
			if curse.get("curse_type", "") == "move_disable":
				return false
		
		# use_hand_spell: 手札に単体対象スペルがないと使用不可
		if effect_type == "use_hand_spell":
			if spell_phase_handler_ref and spell_phase_handler_ref.spell_borrow:
				if not spell_phase_handler_ref.spell_borrow.can_cast_use_hand_spell(player_id):
					return false
	
	return true


## クリーチャーの秘術一覧を取得（元々の秘術 + 呪いからの秘術）
func get_mystic_arts_for_creature(creature_data: Dictionary) -> Array:
	if creature_data.is_empty():
		return []
	
	return _get_all_mystic_arts(creature_data)


## 全秘術を取得（ability_parsed + 呪いの両方）
func _get_all_mystic_arts(creature_data: Dictionary) -> Array:
	var all_mystic_arts: Array = []
	
	# 1. 元々の秘術（creature_data直下のmystic_arts）
	var root_mystic_arts = creature_data.get("mystic_arts", {})
	if root_mystic_arts is Dictionary and not root_mystic_arts.is_empty():
		# 辞書形式（単体の秘術）
		all_mystic_arts.append(root_mystic_arts)
	elif root_mystic_arts is Array:
		# 配列形式（複数の秘術）
		all_mystic_arts.append_array(root_mystic_arts)
	
	# 2. ability_parsed内の秘術（従来方式）
	var ability_parsed = creature_data.get("ability_parsed", {})
	
	# 複数形 mystic_arts（配列）
	var original_arts = ability_parsed.get("mystic_arts", [])
	all_mystic_arts.append_array(original_arts)
	
	# 単数形 mystic_art（辞書）- 1つだけ持つクリーチャー用
	var single_art = ability_parsed.get("mystic_art", {})
	if not single_art.is_empty():
		all_mystic_arts.append(single_art)
	
	# 2. 呪いから付与された秘術
	var curse = creature_data.get("curse", {})
	if curse.get("curse_type", "") == "mystic_grant":
		var params = curse.get("params", {})
		
		# spell_id参照方式（新方式）
		var spell_id = params.get("spell_id", 0)
		if spell_id > 0:
			# CardLoaderからスペルデータを取得
			var spell_data = CardLoader.get_card_by_id(spell_id)
			if spell_data and not spell_data.is_empty():
				var mystic_art = {
					"name": params.get("name", spell_data.get("name", "秘術")),
					"cost": params.get("cost", 0),
					"spell_id": spell_id
				}
				all_mystic_arts.append(mystic_art)
				print("[秘術取得] 呪いから秘術付与: ", mystic_art.get("name"), " (spell_id: ", spell_id, ")")
			else:
				print("[秘術取得] spell_id ", spell_id, " のカードが見つかりません")
		else:
			# mystic_arts配列方式（旧方式）
			var curse_arts = params.get("mystic_arts", [])
			all_mystic_arts.append_array(curse_arts)
	
	return all_mystic_arts


# ============ 発動判定 ============

## 秘術発動可能か判定
func can_cast_mystic_art(mystic_art: Dictionary, context: Dictionary) -> bool:
	# 魔力確認
	var cost = mystic_art.get("cost", 0)
	var player_magic = context.get("player_magic", 0)
	
	if player_magic < cost:
		return false
	
	# スペル未使用確認
	if context.get("spell_used_this_turn", false):
		return false
	
	# クリーチャーが行動可能か確認（ダウン状態チェック）
	var caster_tile_index = context.get("tile_index", -1)
	if caster_tile_index != -1:
		var caster_tile = board_system_ref.tile_nodes.get(caster_tile_index)
		if caster_tile and caster_tile.is_down():
			return false  # ダウン状態のクリーチャーは秘術使用不可
	
	# ターゲット有無確認
	if not _has_valid_target(mystic_art, context):
		return false
	
	return true


## 有効なターゲットが存在するか確認
func _has_valid_target(mystic_art: Dictionary, _context: Dictionary) -> bool:
	var target_type = mystic_art.get("target_type", "")
	var target_info = {}
	
	# spell_idがある場合はスペルデータからターゲット情報を取得
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var effect_parsed = spell_data.get("effect_parsed", {})
			target_type = effect_parsed.get("target_type", target_type)
			
			# target_info構造がある場合はそれを使用
			if effect_parsed.has("target_info"):
				target_info = effect_parsed.get("target_info", {})
			else:
				# なければeffect_parsed直下から構築
				var target_filter = effect_parsed.get("target_filter", "any")
				target_info["target_filter"] = target_filter
	
	# ターゲット不要（none）または セルフターゲットは常に有効
	if target_type == "none" or target_type == "self" or target_info.get("target_filter") == "self":
		return true
	
	# 全クリーチャー対象の場合は条件付きで有効判定
	if target_type == "all_creatures":
		# 条件付き全体効果（has_curse等）の場合は対象存在チェック
		if not spell_phase_handler_ref:
			return false
		var all_targets = TargetSelectionHelper.get_valid_targets(spell_phase_handler_ref, "creature", target_info)
		return all_targets.size() > 0
	
	# TargetSelectionHelperを直接呼び出してターゲット取得
	if not spell_phase_handler_ref:
		push_error("[SpellMysticArts] spell_phase_handler_ref が無効です")
		return false
	
	var valid_targets = TargetSelectionHelper.get_valid_targets(spell_phase_handler_ref, target_type, target_info)
	return valid_targets.size() > 0


# ============ 効果適用 ============

## 秘術効果を適用（メインエンジン）
func apply_mystic_art_effect(mystic_art: Dictionary, target_data: Dictionary, context: Dictionary) -> bool:
	if mystic_art.is_empty():
		return false
	
	# spell_idがある場合は既存スペルの効果を使用
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		# effect_overrideがあればcontextに追加
		var effect_override = mystic_art.get("effect_override", {})
		return await _apply_spell_effect(spell_id, target_data, context, effect_override)
	
	# spell_idがない場合は秘術独自のeffectsを使用（従来方式）
	var effects = mystic_art.get("effects", [])
	var success = true
	
	for effect in effects:
		var applied = await _apply_single_effect(effect, target_data, context)
		if not applied:
			success = false
	
	return success


## スペル効果を適用（spell_id参照方式）
func _apply_spell_effect(spell_id: int, target_data: Dictionary, _context: Dictionary, effect_override: Dictionary = {}) -> bool:
	# CardLoaderからスペルデータを取得
	var spell_data = CardLoader.get_card_by_id(spell_id)
	if spell_data.is_empty():
		push_error("[SpellMysticArts] spell_id=%d のスペルが見つかりません" % spell_id)
		return false
	
	var effect_parsed = spell_data.get("effect_parsed", {})
	var effects = effect_parsed.get("effects", [])
	
	if effects.is_empty():
		push_error("[SpellMysticArts] spell_id=%d のeffectsが空です" % spell_id)
		return false
	
	# spell_phase_handlerに効果適用を委譲
	for effect in effects:
		# effect_overrideがあれば効果パラメータを上書き
		var applied_effect = effect.duplicate()
		if not effect_override.is_empty():
			for key in effect_override:
				applied_effect[key] = effect_override[key]
		
		if spell_phase_handler_ref and spell_phase_handler_ref.has_method("_apply_single_effect"):
			# 秘術発動者のタイルインデックスを追加（self_destroy等で必要）
			var extended_target_data = target_data.duplicate()
			if _context.has("tile_index"):
				extended_target_data["caster_tile_index"] = _context.get("tile_index", -1)
			await spell_phase_handler_ref._apply_single_effect(applied_effect, extended_target_data)
		else:
			push_error("[SpellMysticArts] spell_phase_handler_refが無効です")
			return false
	
	return true


## 1つの効果を適用（SpellPhaseHandlerに委譲）
func _apply_single_effect(effect: Dictionary, target_data: Dictionary, context: Dictionary) -> bool:
	if effect.is_empty():
		return false
	
	# 全効果をSpellPhaseHandlerに委譲
	if spell_phase_handler_ref and spell_phase_handler_ref.has_method("_apply_single_effect"):
		# target_dataにtile_indexがない場合のみcontextから追加
		var extended_target_data = target_data.duplicate()
		if not extended_target_data.has("tile_index") and context.has("tile_index"):
			extended_target_data["tile_index"] = context.get("tile_index", -1)
		# 秘術発動者のタイルインデックスも別キーで追加（self_destroy等で必要）
		if context.has("tile_index"):
			extended_target_data["caster_tile_index"] = context.get("tile_index", -1)
		await spell_phase_handler_ref._apply_single_effect(effect, extended_target_data)
		return true
	
	push_error("[SpellMysticArts] spell_phase_handler_refが無効です")
	return false


# ============ ダウン状態管理 ============

## 秘術発動後、キャスター（クリーチャー）をダウン状態に設定
func _set_caster_down_state(caster_tile_index: int, board_system_ref_param: Object) -> void:
	if caster_tile_index == -1:
		return
	
	var caster_tile = board_system_ref_param.tile_nodes.get(caster_tile_index)
	if not caster_tile:
		return
	
	var creature_data = caster_tile.creature_data
	if not creature_data:
		return
	
	# 不屈スキルで例外処理（ランドシステム仕様に準拠）
	# 不屈を持つクリーチャーはダウン状態にならない
	if _has_unyielding(creature_data):
				return
	
	# ダウン状態を設定
	if caster_tile.has_method("set_down_state"):
		caster_tile.set_down_state(true)
	elif caster_tile.has_method("set_down"):
		caster_tile.set_down(true)


## 不屈スキルまたは不屈呪いを持つか確認
func _has_unyielding(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	# 1. 不屈スキル判定
	var ability_detail = creature_data.get("ability_detail", "")
	if "不屈" in ability_detail:
		return true
	
	# 2. 不屈呪い判定
	if SpellMovement.has_indomitable_curse(creature_data):
		return true
	
	return false


## ナチュラルワールドで秘術が無効化されているか
func _is_mystic_arts_disabled() -> bool:
	var game_stats = _get_game_stats()
	return SpellWorldCurse.is_trigger_disabled("mystic_arts", game_stats)


## game_statsを取得
func _get_game_stats() -> Dictionary:
	if not spell_phase_handler_ref:
		return {}
	if not spell_phase_handler_ref.game_flow_manager:
		return {}
	return spell_phase_handler_ref.game_flow_manager.game_stats


# ============ カメラフォーカス ============

## クリーチャー選択変更時のコールバック
func _on_creature_selection_changed(_index: int, data: Variant) -> void:
	if data == null or not data is Dictionary:
		return
	_focus_camera_on_creature(data)


## クリーチャーのタイルにカメラをフォーカス
func _focus_camera_on_creature(creature_info: Dictionary) -> void:
	var tile_index = creature_info.get("tile_index", -1)
	if tile_index < 0:
		return
	
	if not board_system_ref or not board_system_ref.tile_nodes.has(tile_index):
		return
	
	var tile = board_system_ref.tile_nodes[tile_index]
	var camera = board_system_ref.camera
	
	if not camera:
		return
	
	# カメラを土地の上方に移動
	var tile_pos = tile.global_position
	var camera_offset = Vector3(12, 15, 12)
	camera.position = tile_pos + camera_offset
	camera.look_at(tile_pos, Vector3.UP)
