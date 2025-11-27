# SpellPhaseHandler - スペルフェーズの処理を担当
extends Node
class_name SpellPhaseHandler

## シグナル
signal spell_phase_started()
signal spell_phase_completed()
signal spell_passed()
signal spell_used(spell_card: Dictionary)
signal target_selection_required(spell_card: Dictionary, target_type: String)

## 状態
enum State {
	INACTIVE,
	WAITING_FOR_INPUT,  # スペル選択またはダイス待ち
	SELECTING_TARGET,    # 対象選択中
	EXECUTING_EFFECT     # 効果実行中
}

var current_state: State = State.INACTIVE
var current_player_id: int = -1
var selected_spell_card: Dictionary = {}
var spell_used_this_turn: bool = false  # 1ターン1回制限

## カード選択ハンドラー（敵手札選択、デッキカード選択）
var card_selection_handler: CardSelectionHandler = null

## 秘術選択状態
var selected_mystic_art: Dictionary = {}
var selected_mystic_creature: Dictionary = {}
var spell_failed: bool = false  # 復帰[ブック]フラグ（条件不成立でデッキに戻る）

## デバッグ設定
## 密命カードのテストを一時的に無効化
## true: 密命カードを通常カードとして扱う（失敗判定・復帰[ブック]をスキップ）
## false: 通常通り密命として動作
## 使い方: GameFlowManagerのセットアップ後に設定
##   spell_phase_handler.debug_disable_secret_cards = true
var debug_disable_secret_cards: bool = false

## ターゲット選択（領地コマンドと同じ構造）
var available_targets: Array = []
var current_target_index: int = 0
var selection_marker: MeshInstance3D = null

## 参照
var ui_manager = null
var game_flow_manager = null
var card_system = null
var player_system = null
var board_system = null
var creature_manager = null
var spell_mystic_arts = null  # 秘術システム
var spell_phase_ui_manager = null  # UIボタン管理
var spell_cast_notification_ui = null  # 発動通知UI
var spell_damage: SpellDamage = null  # ダメージ・回復処理

func _ready():
	pass

func _process(delta):
	# 選択マーカーを回転
	TargetSelectionHelper.rotate_selection_marker(self, delta)

## 初期化
func initialize(ui_mgr, flow_mgr, c_system = null, p_system = null, b_system = null):
	ui_manager = ui_mgr
	game_flow_manager = flow_mgr
	card_system = c_system if c_system else (flow_mgr.card_system if flow_mgr else null)
	player_system = p_system if p_system else (flow_mgr.player_system if flow_mgr else null)
	board_system = b_system if b_system else (flow_mgr.board_system_3d if flow_mgr else null)
	
	# CreatureManagerを取得
	if board_system:
		creature_manager = board_system.get_node_or_null("CreatureManager")
	
	# SpellMysticArts を初期化
	if not spell_mystic_arts and board_system and player_system and card_system:
		spell_mystic_arts = SpellMysticArts.new(
			board_system,
			player_system,
			card_system,
			self
		)
	
	# SpellDamage を初期化
	if not spell_damage and board_system:
		spell_damage = SpellDamage.new(board_system)
	
	# SpellPhaseUIManager を初期化
	_initialize_spell_phase_ui()
	
	# 発動通知UIを初期化
	_initialize_spell_cast_notification_ui()
	
	# SpellDamageに通知UIを設定
	if spell_damage and spell_cast_notification_ui:
		spell_damage.set_notification_ui(spell_cast_notification_ui)
	
	# カード選択ハンドラーを初期化
	_initialize_card_selection_handler()

## スペルフェーズ開始
func start_spell_phase(player_id: int):
	if current_state != State.INACTIVE:
		return
	
	current_state = State.WAITING_FOR_INPUT
	current_player_id = player_id
	spell_used_this_turn = false
	selected_spell_card = {}
	
	spell_phase_started.emit()
	
	# UIを更新（スペルカードのみ選択可能にする）
	if ui_manager:
		_update_spell_phase_ui()
		_show_spell_phase_buttons()
	
	# CPUの場合は簡易AI
	if is_cpu_player(player_id):
		_handle_cpu_spell_turn()
	else:
		# 人間プレイヤーの場合は入力待ち
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "スペルを使用するか、ダイスを振ってください"

## スペルフェーズUIの更新
func _update_spell_phase_ui():
	# 手札のスペルカード以外をグレーアウト
	if not ui_manager or not card_system:
		return
	
	var current_player = player_system.get_current_player() if player_system else null
	if not current_player:
		return
	
	# 手札を取得
	var hand_data = card_system.get_all_cards_for_player(current_player.id)
	
	# スペルカードのみ選択可能にする設定
	if ui_manager:
		ui_manager.card_selection_filter = "spell"
		# 手札表示を更新してグレーアウトを適用
		if ui_manager.hand_display:
			ui_manager.hand_display.update_hand_display(current_player.id)
	
	# スペル選択UIを表示（人間プレイヤーのみ）
	if not is_cpu_player(current_player.id):
		_show_spell_selection_ui(hand_data, current_player.magic_power)
	
	# ダイスボタンのテキストはそのまま「ダイスを振る」

## スペル選択UIを表示
func _show_spell_selection_ui(hand_data: Array, _available_magic: int):
	if not ui_manager or not ui_manager.card_selection_ui:
		return
	
	# スペルカードのみフィルター
	var spell_cards = []
	for card in hand_data:
		if card.get("type", "") == "spell":
			spell_cards.append(card)
	
	if spell_cards.is_empty():
		return
	
	# 現在のプレイヤー情報を取得
	var current_player = player_system.get_current_player() if player_system else null
	if not current_player:
		return
	
	# CardSelectionUIを使用してスペル選択
	if ui_manager.card_selection_ui.has_method("show_selection"):
		ui_manager.card_selection_ui.show_selection(current_player, "spell")

## 秘術フェーズ開始
func start_mystic_arts_phase():
	"""秘術選択フェーズを開始"""
	if not spell_mystic_arts:
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術システムが初期化されていません"
		return
	
	if not player_system:
		return
	
	# 現在のプレイヤーを取得
	var current_player = player_system.get_current_player()
	if not current_player:
		return
	
	# 秘術を持つクリーチャーを取得
	var available_creatures = spell_mystic_arts.get_available_creatures(current_player.id)
	
	if available_creatures.is_empty():
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術を持つクリーチャーがありません"
		return
	
	# クリーチャー選択UIを表示
	await _select_mystic_arts_creature(available_creatures, current_player.id)

## クリーチャー選択
func _select_mystic_arts_creature(available_creatures: Array, player_id: int):
	"""秘術を持つクリーチャーを選択"""
	if not ui_manager:
		return
	
	# SpellAndMysticUI を取得または作成
	var spell_and_mystic_ui = ui_manager.get_node_or_null("SpellAndMysticUI")
	if not spell_and_mystic_ui:
		# 動的にロード
		var SpellAndMysticUIClass = load("res://scripts/ui_components/spell_and_mystic_ui.gd")
		if not SpellAndMysticUIClass:
			return
		
		# 新規作成
		spell_and_mystic_ui = SpellAndMysticUIClass.new()
		spell_and_mystic_ui.name = "SpellAndMysticUI"
		ui_manager.add_child(spell_and_mystic_ui)
	
	# クリーチャー選択UIを表示
	spell_and_mystic_ui.show_creature_selection(available_creatures)
	
	# クリーチャー選択を待機
	var selected_index = await spell_and_mystic_ui.creature_selected
	
	if selected_index < 0 or selected_index >= available_creatures.size():
		spell_and_mystic_ui.hide_all()
		return
	
	var selected_creature = available_creatures[selected_index]
	
	# 秘術選択に進む
	await _select_mystic_art(selected_creature, spell_and_mystic_ui)

## 秘術選択
func _select_mystic_art(selected_creature: Dictionary, spell_and_mystic_ui: Control):
	"""クリーチャーの秘術を選択"""
	var mystic_arts = selected_creature.get("mystic_arts", [])
	
	if mystic_arts.is_empty():
		spell_and_mystic_ui.hide_all()
		return
	
	# 秘術選択UIを表示
	spell_and_mystic_ui.show_mystic_art_selection(mystic_arts)
	
	# 秘術選択を待機
	var selected_index = await spell_and_mystic_ui.mystic_art_selected
	
	if selected_index < 0 or selected_index >= mystic_arts.size():
		spell_and_mystic_ui.hide_all()
		return
	
	var selected_mystic_art = mystic_arts[selected_index]
	
	# UIを非表示
	spell_and_mystic_ui.hide_all()
	
	# ターゲット選択に進む
	var current_player = player_system.get_current_player()
	await _select_mystic_arts_target(selected_creature, selected_mystic_art, current_player.id)

## ターゲット選択
func _select_mystic_arts_target(selected_creature: Dictionary, mystic_art: Dictionary, player_id: int):
	"""秘術のターゲットを選択（既存のターゲット選択UIを流用）"""
	var target_type = mystic_art.get("target_type", "")
	var target_filter = mystic_art.get("target_filter", "any")
	var target_info = {}
	
	# spell_idがある場合はスペルデータからターゲット情報を取得
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var effect_parsed = spell_data.get("effect_parsed", {})
			target_type = effect_parsed.get("target_type", target_type)
			target_info = effect_parsed.get("target_info", {})
			target_filter = target_info.get("owner_filter", target_info.get("target_filter", "any"))
	
	# セルフターゲット時はUI表示なし（target_typeまたはtarget_filterが"self"）
	if target_type == "self" or target_filter == "self":
		var target_data = {
			"type": target_type,
			"tile_index": selected_creature.get("tile_index", -1),
			"player_id": player_id
		}
		await _execute_mystic_art(selected_creature, mystic_art, target_data, player_id)
		return
	
	# 全クリーチャー対象時はターゲット選択なしで実行
	if target_type == "all_creatures":
		var target_data = {
			"type": "all",
			"target_info": target_info
		}
		await _execute_mystic_art_all_creatures(selected_creature, mystic_art, target_info, player_id)
		return
	
	# 秘術選択状態を保存（ターゲット確定時に使用）
	selected_mystic_creature = selected_creature
	selected_mystic_art = mystic_art
	
	# 通常ターゲット選択（spell_idがない場合のみtarget_infoを設定）
	if target_info.is_empty():
		target_info = {
			"filter": target_filter
		}
	
	var targets = TargetSelectionHelper.get_valid_targets(self, target_type, target_info)
	
	if targets.is_empty():
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "有効なターゲットがありません"
		_clear_mystic_art_selection()
		return
	
	# スペルと同じ方式でターゲット選択開始
	available_targets = targets
	current_target_index = 0
	current_state = State.SELECTING_TARGET
	
	# 最初の対象を表示
	_update_target_selection()

## 非同期効果を含む秘術かどうかを判定
func _is_async_mystic_art(mystic_art: Dictionary) -> bool:
	# カード選択UIが必要な効果タイプ
	const ASYNC_EFFECT_TYPES = [
		"destroy_and_draw", "swap_creature",
		"destroy_selected_card", "steal_selected_card",
		"destroy_from_deck_selection", "draw_from_deck_selection"
	]
	
	# spell_id参照の場合
	var spell_id = mystic_art.get("spell_id", -1)
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var effects = spell_data.get("effect_parsed", {}).get("effects", [])
			for effect in effects:
				if effect.get("effect_type", "") in ASYNC_EFFECT_TYPES:
					return true
		return false
	
	# 直接effects定義の場合
	var effects = mystic_art.get("effects", [])
	for effect in effects:
		if effect.get("effect_type", "") in ASYNC_EFFECT_TYPES:
			return true
	
	return false

## 秘術実行
func _execute_mystic_art(creature: Dictionary, mystic_art: Dictionary, target_data: Dictionary, player_id: int):
	"""秘術効果を実行"""
	current_state = State.EXECUTING_EFFECT
	
	# 発動判定
	var context = {
		"player_id": player_id,
		"player_magic": player_system.get_magic(player_id),
		"spell_used_this_turn": spell_used_this_turn,
		"tile_index": creature.get("tile_index", -1)
	}
	
	if not spell_mystic_arts.can_cast_mystic_art(mystic_art, context):
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術発動条件を満たしていません"
		_clear_mystic_art_selection()
		current_state = State.WAITING_FOR_INPUT
		return
	
	# 発動通知を表示（秘術発動クリーチャー名を使用、クリック待ち）
	var caster_name = creature.get("creature_data", {}).get("name", "クリーチャー")
	await _show_spell_cast_notification(caster_name, target_data, mystic_art, true)
	
	# 非同期効果かどうかを事前判定
	var is_async = _is_async_mystic_art(mystic_art)
	
	# 秘術効果を適用
	var success = spell_mystic_arts.apply_mystic_art_effect(mystic_art, target_data, context)
	
	if success:
		# 魔力消費
		var cost = mystic_art.get("cost", 0)
		player_system.add_magic(player_id, -cost)
		spell_used_this_turn = true
		
		# キャスターをダウン状態に設定
		spell_mystic_arts._set_caster_down_state(creature.get("tile_index", -1), board_system)
		
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "『%s』を発動しました！" % mystic_art.get("name", "Unknown")
		
		# 排他制御：秘術使用後はスペルUI非表示
		_on_mystic_art_used()
	else:
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術の発動に失敗しました"
	
	# 秘術選択状態をクリア
	_clear_mystic_art_selection()
	
	# ターゲット選択をクリア
	TargetSelectionHelper.clear_selection(self)
	
	# 非同期効果の場合はここで終了（CardSelectionHandler完了後にスペルフェーズ完了）
	if is_async:
		return
	
	# スペルフェーズ完了
	await get_tree().create_timer(0.5).timeout
	complete_spell_phase()


## 秘術実行（全クリーチャー対象）
func _execute_mystic_art_all_creatures(creature: Dictionary, mystic_art: Dictionary, target_info: Dictionary, player_id: int):
	"""全クリーチャー対象の秘術を実行（ニルーバーナ等）"""
	current_state = State.EXECUTING_EFFECT
	
	# 発動判定
	var context = {
		"player_id": player_id,
		"player_magic": player_system.get_magic(player_id),
		"spell_used_this_turn": spell_used_this_turn,
		"tile_index": creature.get("tile_index", -1)
	}
	
	if not spell_mystic_arts.can_cast_mystic_art(mystic_art, context):
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術発動条件を満たしていません"
		_clear_mystic_art_selection()
		current_state = State.WAITING_FOR_INPUT
		return
	
	# 発動通知を表示
	var caster_name = creature.get("creature_data", {}).get("name", "クリーチャー")
	var target_data_for_notification = {"type": "all"}
	await _show_spell_cast_notification(caster_name, target_data_for_notification, mystic_art, true)
	
	# spell_idからeffectsを取得
	var spell_id = mystic_art.get("spell_id", -1)
	var effects = []
	if spell_id > 0:
		var spell_data = CardLoader.get_card_by_id(spell_id)
		if not spell_data.is_empty():
			var effect_parsed = spell_data.get("effect_parsed", {})
			effects = effect_parsed.get("effects", [])
	
	# ダメージ/回復効果をSpellDamageに委譲
	if spell_damage:
		await spell_damage.execute_all_creatures_effects(self, effects, target_info)
	
	# 魔力消費
	var cost = mystic_art.get("cost", 0)
	player_system.add_magic(player_id, -cost)
	spell_used_this_turn = true
	
	# キャスターをダウン状態に設定
	spell_mystic_arts._set_caster_down_state(creature.get("tile_index", -1), board_system)
	
	if ui_manager and ui_manager.phase_label:
		ui_manager.phase_label.text = "『%s』を発動しました！" % mystic_art.get("name", "Unknown")
	
	# 排他制御
	_on_mystic_art_used()
	
	# 秘術選択状態をクリア
	_clear_mystic_art_selection()
	
	# スペルフェーズ完了
	await get_tree().create_timer(0.5).timeout
	_return_camera_to_player()
	await get_tree().create_timer(0.5).timeout
	complete_spell_phase()


## CPUのスペル使用判定（簡易版）
func _handle_cpu_spell_turn():
	await get_tree().create_timer(1.0).timeout
	
	# 簡易AI: 30%の確率でスペルを使用
	if randf() < 0.3 and card_system:
		var spells = _get_available_spells(current_player_id)
		if not spells.is_empty():
			# ランダムに1つ選択
			var spell = spells[randi() % spells.size()]
			if _can_afford_spell(spell):
				use_spell(spell)
				return
	
	# スペルを使わない
	pass_spell()

## 利用可能なスペルカードを取得
func _get_available_spells(player_id: int) -> Array:
	if not card_system:
		return []
	
	var hand = card_system.get_all_cards_for_player(player_id)
	var spells = []
	
	for card in hand:
		if card.get("type", "") == "spell":
			spells.append(card)
	
	return spells

## スペルが使用可能か（コスト的に）
func _can_afford_spell(spell_card: Dictionary) -> bool:
	if not player_system:
		return false
	
	var current_player = player_system.get_current_player()
	if not current_player:
		return false
	
	# costがnullの場合は空のDictionaryとして扱う
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	
	return current_player.magic_power >= cost

## スペルを使用
func use_spell(spell_card: Dictionary):
	if current_state != State.WAITING_FOR_INPUT:
		return
	
	if spell_used_this_turn:
		return
	
	if not _can_afford_spell(spell_card):
		return
	
	selected_spell_card = spell_card
	spell_used_this_turn = true
	
	# コストを支払う
	var cost_data = spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	
	if player_system:
		player_system.add_magic(current_player_id, -cost)
	
	# 対象選択が必要かチェック
	var parsed = spell_card.get("effect_parsed", {})
	var target_type = parsed.get("target_type", "")
	var target_filter = parsed.get("target_filter", "")
	var target_info = parsed.get("target_info", {})
	
	# target_filter または target_type が "self" の場合は、即座に効果発動（対象選択UIなし）
	if target_filter == "self" or target_type == "self":
		# 対象選択なし。効果実行時に current_player_id を使用
		var target_data = {"type": "player", "player_id": current_player_id}
		execute_spell_effect(spell_card, target_data)
	elif target_type == "all_creatures":
		# 全クリーチャー対象（条件付き）
		_execute_spell_on_all_creatures(spell_card, target_info)
	elif not target_type.is_empty() and target_type != "none":
		# 対象選択が必要
		current_state = State.SELECTING_TARGET
		target_selection_required.emit(spell_card, target_type)
		
		# target_filterをtarget_infoに追加（get_valid_targetsで使用）
		if not target_filter.is_empty():
			target_info["target_filter"] = target_filter
		
		# 対象選択UIを表示
		_show_target_selection_ui(target_type, target_info)
	else:
		# 即座に効果発動（target_type が空または "none" の場合）
		execute_spell_effect(spell_card, {})

## 対象選択UIを表示（領地コマンドと同じ方式）
func _show_target_selection_ui(target_type: String, target_info: Dictionary):
	# 有効な対象を取得（ヘルパー使用）
	var targets = TargetSelectionHelper.get_valid_targets(self, target_type, target_info)
	
	if targets.is_empty():
		cancel_spell()
		return
	
	# 領地コマンドと同じ方式で選択開始
	available_targets = targets
	current_target_index = 0
	current_state = State.SELECTING_TARGET
	
	# 最初の対象を表示
	_update_target_selection()

## 選択を更新
func _update_target_selection():
	if available_targets.is_empty():
		return
	
	var target = available_targets[current_target_index]
	
	# 汎用ヘルパーを使用して視覚的に選択
	TargetSelectionHelper.select_target_visually(self, target)
	
	# UI更新
	_update_selection_ui()

## 選択UIを更新（領地コマンドと同じ形式）
func _update_selection_ui():
	if not ui_manager or not ui_manager.phase_label:
		return
	
	if available_targets.is_empty():
		return
	
	var target = available_targets[current_target_index]
	
	# ヘルパーを使用してテキスト生成
	var text = TargetSelectionHelper.format_target_info(target, current_target_index + 1, available_targets.size())
	ui_manager.phase_label.text = text




## 入力処理
func _input(event):
	if current_state != State.SELECTING_TARGET:
		return
	
	if event is InputEventKey and event.pressed:
		
		# ↑キーまたは←キー: 前の対象
		if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			if TargetSelectionHelper.move_target_previous(self):
				_update_target_selection()
			get_viewport().set_input_as_handled()
		
		# ↓キーまたは→キー: 次の対象
		elif event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			if TargetSelectionHelper.move_target_next(self):
				_update_target_selection()
			get_viewport().set_input_as_handled()
		
		# Enterキー: 確定
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_confirm_target_selection()
			get_viewport().set_input_as_handled()
		
		# 数字キー1-9, 0: 直接選択して即確定
		elif TargetSelectionHelper.is_number_key(event.keycode):
			var index = TargetSelectionHelper.get_number_from_key(event.keycode)
			if TargetSelectionHelper.select_target_by_index(self, index):
				_update_target_selection()
				# 数字キーの場合は即座に確定
				_confirm_target_selection()
			get_viewport().set_input_as_handled()
		
		# Cキーまたはエスケープ: キャンセル
		elif event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			_cancel_target_selection()
			get_viewport().set_input_as_handled()

## 対象選択を確定
func _confirm_target_selection():
	if available_targets.is_empty():
		return
	
	var selected_target = available_targets[current_target_index]
	
	# 選択をクリア
	TargetSelectionHelper.clear_selection(self)
	
	# 秘術かスペルかで分岐
	if not selected_mystic_art.is_empty():
		# 秘術実行
		var player_id = player_system.get_current_player().id if player_system else current_player_id
		_execute_mystic_art(selected_mystic_creature, selected_mystic_art, selected_target, player_id)
	else:
		# スペル実行
		execute_spell_effect(selected_spell_card, selected_target)

## 対象選択をキャンセル
func _cancel_target_selection():
	# 選択をクリア
	TargetSelectionHelper.clear_selection(self)
	
	# 秘術かスペルかで分岐
	if not selected_mystic_art.is_empty():
		# 秘術キャンセル
		_clear_mystic_art_selection()
		current_state = State.WAITING_FOR_INPUT
	else:
		# スペルキャンセル
		cancel_spell()

## スペルをキャンセル
func cancel_spell():
	# コストを返却
	var cost_data = selected_spell_card.get("cost", {})
	if cost_data == null:
		cost_data = {}
	
	var cost = 0
	if typeof(cost_data) == TYPE_DICTIONARY:
		cost = cost_data.get("mp", 0)
	
	if player_system and cost > 0:
		player_system.add_magic(current_player_id, cost)
	
	selected_spell_card = {}
	spell_used_this_turn = false
	current_state = State.WAITING_FOR_INPUT

## スペル効果を実行
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary):
	current_state = State.EXECUTING_EFFECT
	
	# 復帰[ブック]フラグをリセット
	spell_failed = false
	
	# 発動通知を表示（クリック待ち）
	var caster_name = "プレイヤー%d" % (current_player_id + 1)
	if player_system and current_player_id >= 0 and current_player_id < player_system.players.size():
		caster_name = player_system.players[current_player_id].name
	await _show_spell_cast_notification(caster_name, target_data, spell_card, false)
	
	# スペル効果を実行
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# 効果を適用
	for effect in effects:
		await _apply_single_effect(effect, target_data)
	
	# カードを捨て札に（復帰[ブック]時はスキップ）
	if card_system and not spell_failed:
		# 手札からカードのインデックスを探す
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	elif spell_failed:
		pass  # 復帰[ブック]: カードはデッキに戻される
	
	# 効果発動完了
	spell_used.emit(spell_card)
	
	# カード選択中の場合は、選択完了後に complete_spell_phase を呼ぶ
	if card_selection_handler and card_selection_handler.is_selecting():
		return
	
	# 少し待機してからカメラを戻す
	await get_tree().create_timer(0.5).timeout
	
	# カメラを使用者（現在のプレイヤー）に戻す
	_return_camera_to_player()
	
	# さらに待機してからスペルフェーズ完了
	await get_tree().create_timer(0.5).timeout
	complete_spell_phase()

## 単一の効果を適用
func _apply_single_effect(effect: Dictionary, target_data: Dictionary):
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"damage":
			# クリーチャーにダメージ - SpellDamageに委譲
			if spell_damage and target_data.get("type", "") == "creature":
				var tile_index = target_data.get("tile_index", -1)
				var value = effect.get("value", 0)
				await spell_damage.apply_damage_effect(self, tile_index, value)
		
		"drain_magic", "gain_magic", "gain_magic_by_rank":
			# 魔力操作系 - SpellMagicに委譲
			if game_flow_manager and game_flow_manager.spell_magic:
				var context = {
					"rank": _get_player_ranking(current_player_id),
					"from_player_id": target_data.get("player_id", -1)
				}
				game_flow_manager.spell_magic.apply_effect(effect, current_player_id, context)
		
		"dice_fixed", "dice_range", "dice_multi", "dice_range_magic":
			# ダイス系効果（統合処理）
			if game_flow_manager and game_flow_manager.spell_dice:
				game_flow_manager.spell_dice.apply_effect_from_parsed(effect, target_data, current_player_id)
		
		"stat_boost", "stat_reduce":
			# ステータス呪い系（統合処理）
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse_stat:
					game_flow_manager.spell_curse_stat.apply_curse_from_effect(effect, tile_index)
		
		"skill_nullify", "battle_disable", "ap_nullify", "stat_reduce", "random_stat_curse", "command_growth_curse":
			# 戦闘制限呪い系 - SpellCurseに委譲
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse:
					game_flow_manager.spell_curse.apply_effect(effect, tile_index)
		
		"grant_mystic_arts":
			# 秘術付与呪い（シュリンクシジル等）- SpellCurseに委譲
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse:
					game_flow_manager.spell_curse.apply_effect(effect, tile_index)
		
		"toll_share", "toll_disable", "toll_fixed", "toll_multiplier", "peace", "curse_toll_half":
			# 通行料呪い系（統合処理）
			if game_flow_manager and game_flow_manager.spell_curse_toll:
				var tile_index = target_data.get("tile_index", -1)
				var target_player_id = target_data.get("player_id", -1)
				game_flow_manager.spell_curse_toll.apply_curse_from_effect(effect, tile_index, target_player_id, current_player_id)
		
		"draw", "draw_cards", "draw_by_rank", "draw_by_type", "discard_and_draw_plus", "check_hand_elements", \
		"destroy_curse_cards", "destroy_expensive_cards", "destroy_duplicate_cards", \
		"destroy_selected_card", "steal_selected_card", "destroy_from_deck_selection", \
		"draw_from_deck_selection", "steal_item_conditional", \
		"add_specific_card", "destroy_and_draw", "swap_creature":
			# ドロー・手札操作系 - SpellDrawに委譲
			if game_flow_manager and game_flow_manager.spell_draw:
				var context = {
					"rank": _get_player_ranking(current_player_id),
					"target_player_id": target_data.get("player_id", current_player_id),
					"tile_index": target_data.get("tile_index", -1)
				}
				var result = game_flow_manager.spell_draw.apply_effect(effect, current_player_id, context)
				# 条件分岐効果の場合は次の効果を再帰適用
				if result.has("next_effect") and not result["next_effect"].is_empty():
					_apply_single_effect(result["next_effect"], target_data)
		
		"change_element", "change_level", "abandon_land", "destroy_creature", \
		"change_element_bidirectional", "change_element_to_dominant", \
		"find_and_change_highest_level", "conditional_level_change", \
		"align_mismatched_lands":
			# 土地操作系効果はSpellLandに委譲
			if game_flow_manager and game_flow_manager.spell_land:
				var success = game_flow_manager.spell_land.apply_land_effect(effect, target_data, current_player_id)
				
				# 復帰[ブック]判定（条件不成立の場合）
				if not success and effect.get("return_to_deck_on_fail", false):
					if game_flow_manager.spell_land.return_spell_to_deck(current_player_id, selected_spell_card):
						spell_failed = true
		
		"clear_down":
			# ダウン解除 - SpellDamageに委譲
			if spell_damage:
				var tile_index = target_data.get("tile_index", -1)
				await spell_damage.apply_clear_down_effect(self, tile_index)
		
		"full_heal":
			# HP全回復 - SpellDamageに委譲
			if spell_damage:
				var tile_index = target_data.get("tile_index", -1)
				await spell_damage.apply_full_heal_effect(self, tile_index)
		
		"heal":
			# 固定値HP回復 - SpellDamageに委譲
			if spell_damage:
				var tile_index = target_data.get("tile_index", -1)
				var value = effect.get("value", 0)
				await spell_damage.apply_heal_effect(self, tile_index, value)
		
		"permanent_hp_change", "permanent_ap_change":
			# 恒久的なステータス変更（グロースボディ、ファットボディ等）
			await _apply_permanent_stat_change(effect, target_data)
		
		"secret_tiny_army":
			# 密命: タイニーアーミー（MHP30以下5体以上でMHP+10、G500）
			await _apply_secret_tiny_army(effect)

## 全クリーチャー対象スペルを実行（ディラニー、全体ダメージ等）
func _execute_spell_on_all_creatures(spell_card: Dictionary, target_info: Dictionary):
	current_state = State.EXECUTING_EFFECT
	
	# 発動通知を表示
	var caster_name = "プレイヤー%d" % (current_player_id + 1)
	if player_system and current_player_id >= 0 and current_player_id < player_system.players.size():
		caster_name = player_system.players[current_player_id].name
	
	var target_data_for_notification = {"type": "all"}
	await _show_spell_cast_notification(caster_name, target_data_for_notification, spell_card, false)
	
	# スペル効果を取得
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	# ダメージ/回復効果をSpellDamageに委譲
	var handled = false
	if spell_damage:
		handled = await spell_damage.execute_all_creatures_effects(self, effects, target_info)
	
	# 未処理（呪い効果等）はSpellCurseBattleに委譲
	if not handled:
		for effect in effects:
			SpellCurseBattle.apply_to_all_creatures(board_system, effect, target_info)
	
	# カードを捨て札に
	if card_system:
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	
	# 効果発動完了
	spell_used.emit(spell_card)
	
	# 少し待機してからスペルフェーズ完了
	await get_tree().create_timer(0.5).timeout
	_return_camera_to_player()
	await get_tree().create_timer(0.5).timeout
	complete_spell_phase()

## カメラを使用者に戻す
func _return_camera_to_player():
	if not player_system or not board_system:
		return
	
	# MovementControllerからプレイヤーの実際の位置を取得
	if board_system.movement_controller:
		var player_tile_index = board_system.movement_controller.get_player_tile(current_player_id)
		
		if board_system.camera and board_system.tile_nodes.has(player_tile_index):
			var tile_pos = board_system.tile_nodes[player_tile_index].global_position
			
			# MovementControllerと同じカメラオフセットを使用
			const CAMERA_OFFSET = Vector3(19, 19, 19)
			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + CAMERA_OFFSET
			
			board_system.camera.position = new_camera_pos
			board_system.camera.look_at(tile_pos + Vector3(0, 1.0, 0), Vector3.UP)

## スペルをパス
func pass_spell():
	spell_passed.emit()
	complete_spell_phase()

## スペルフェーズ完了
func complete_spell_phase():
	if current_state == State.INACTIVE:
		return
	
	current_state = State.INACTIVE
	selected_spell_card = {}
	
	# スペルフェーズのフィルターをクリア
	if ui_manager:
		ui_manager.card_selection_filter = ""
		# 手札表示を更新してグレーアウトを解除
		if ui_manager.hand_display and player_system:
			var current_player = player_system.get_current_player()
			if current_player:
				ui_manager.hand_display.update_hand_display(current_player.id)
	
	# スペルフェーズボタンを非表示
	_hide_spell_phase_buttons()
	
	spell_phase_completed.emit()
	
	# 次のフェーズ（ダイスフェーズ）への遷移は GameFlowManager が行う

## CPUプレイヤーかどうか
func is_cpu_player(player_id: int) -> bool:
	if not game_flow_manager:
		return false
	
	var cpu_settings = game_flow_manager.player_is_cpu
	var debug_mode = game_flow_manager.debug_manual_control_all
	
	if debug_mode:
		return false  # デバッグモードでは全員手動
	
	return player_id < cpu_settings.size() and cpu_settings[player_id]

## プレイヤーの順位を取得（UIパネルから）
func _get_player_ranking(player_id: int) -> int:
	if ui_manager and ui_manager.player_info_panel:
		return ui_manager.player_info_panel.get_player_ranking(player_id)
	# フォールバック: 常に1位を返す
	return 1

## アクティブか
func is_spell_phase_active() -> bool:
	return current_state != State.INACTIVE

# ============ 秘術システム対応（新規追加）============

## 秘術選択状態をクリア
func _clear_mystic_art_selection():
	selected_mystic_art = {}
	selected_mystic_creature = {}

## 秘術が利用可能か確認
func has_available_mystic_arts(player_id: int) -> bool:
	if not has_spell_mystic_arts():
		return false
	
	var available = spell_mystic_arts.get_available_creatures(player_id)
	return available.size() > 0

## SpellMysticArtsクラスが存在するか
func has_spell_mystic_arts() -> bool:
	return spell_mystic_arts != null and spell_mystic_arts is SpellMysticArts

# ============ UIボタン管理 ============

## SpellPhaseUIManager を初期化
func _initialize_spell_phase_ui():
	if not spell_phase_ui_manager:
		spell_phase_ui_manager = SpellPhaseUIManager.new()
		add_child(spell_phase_ui_manager)
		
		# UIレイヤーへの参照を設定
		if ui_manager and ui_manager.card_selection_ui and ui_manager.card_selection_ui.parent_node:
			# CardUIHelper と spell_phase_handler への参照を渡す
			spell_phase_ui_manager.card_ui_helper = load("res://scripts/ui_components/card_ui_helper.gd")
			spell_phase_ui_manager.spell_phase_handler_ref = self
			var ui_parent = ui_manager.card_selection_ui.parent_node
			spell_phase_ui_manager.create_mystic_button(ui_parent)
			spell_phase_ui_manager.create_spell_skip_button(ui_parent)

## スペルフェーズ開始時にボタンを表示
func _show_spell_phase_buttons():
	if spell_phase_ui_manager:
		# 現在の手札枚数を取得
		var hand_count = 6  # デフォルト値
		if card_system and player_system:
			var current_player = player_system.get_current_player()
			if current_player:
				var hand_data = card_system.get_all_cards_for_player(current_player.id)
				hand_count = hand_data.size()
		
		# 秘術ボタンは使用可能なクリーチャーがいる場合のみ表示
		if has_available_mystic_arts(current_player_id):
			spell_phase_ui_manager.show_mystic_button(hand_count)
		spell_phase_ui_manager.show_spell_skip_button(hand_count)

## スペルフェーズ終了時にボタンを非表示
func _hide_spell_phase_buttons():
	if spell_phase_ui_manager:
		spell_phase_ui_manager.hide_mystic_button()
		spell_phase_ui_manager.hide_spell_skip_button()

## 秘術ボタンの表示状態を更新（外部から呼び出し可能）
func update_mystic_button_visibility():
	if not spell_phase_ui_manager or current_state == State.INACTIVE:
		return
	
	var hand_count = 6
	if card_system and player_system:
		var current_player = player_system.get_current_player()
		if current_player:
			var hand_data = card_system.get_all_cards_for_player(current_player.id)
			hand_count = hand_data.size()
	
	if has_available_mystic_arts(current_player_id):
		spell_phase_ui_manager.show_mystic_button(hand_count)
	else:
		spell_phase_ui_manager.hide_mystic_button()

## 秘術使用時にスペルボタンを隠す
func _on_mystic_art_used():
	if spell_phase_ui_manager:
		spell_phase_ui_manager.on_mystic_art_used()

# ============ 発動通知UI ============

## 発動通知UIを初期化
func _initialize_spell_cast_notification_ui():
	if spell_cast_notification_ui:
		return
	
	spell_cast_notification_ui = SpellCastNotificationUI.new()
	spell_cast_notification_ui.name = "SpellCastNotificationUI"
	
	# UIマネージャーの直下に追加（最前面に表示されるように）
	if ui_manager:
		ui_manager.add_child(spell_cast_notification_ui)
	else:
		add_child(spell_cast_notification_ui)

## カード選択ハンドラーを初期化
func _initialize_card_selection_handler():
	if card_selection_handler:
		return
	
	card_selection_handler = CardSelectionHandler.new()
	card_selection_handler.name = "CardSelectionHandler"
	add_child(card_selection_handler)
	
	# 参照を設定
	card_selection_handler.setup(
		ui_manager,
		player_system,
		card_system,
		game_flow_manager.spell_draw if game_flow_manager else null,
		spell_phase_ui_manager
	)
	
	# SpellDrawにもcard_selection_handlerを設定
	if game_flow_manager and game_flow_manager.spell_draw:
		game_flow_manager.spell_draw.set_card_selection_handler(card_selection_handler)
	
	# 選択完了シグナルを接続
	card_selection_handler.selection_completed.connect(_on_card_selection_completed)

## カード選択完了時のコールバック
func _on_card_selection_completed():
	complete_spell_phase()

## スペル/秘術発動通知を表示（クリック待ち）
func _show_spell_cast_notification(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool = false) -> void:
	if not spell_cast_notification_ui:
		return
	
	# 効果名を取得
	var effect_name: String
	if is_mystic:
		effect_name = SpellCastNotificationUI.get_mystic_art_display_name(spell_or_mystic)
	else:
		effect_name = SpellCastNotificationUI.get_effect_display_name(spell_or_mystic)
	
	# 対象名を取得
	var target_name = SpellCastNotificationUI.get_target_display_name(target_data, board_system, player_system)
	
	# 通知を表示してクリック待ち
	spell_cast_notification_ui.show_spell_cast_and_wait(caster_name, target_name, effect_name)
	await spell_cast_notification_ui.click_confirmed

# ============ 恒久的ステータス変更 ============

## 恒久的なステータス変更を適用（グロースボディ、ファットボディ等）
func _apply_permanent_stat_change(effect: Dictionary, target_data: Dictionary) -> void:
	var tile_index = target_data.get("tile_index", -1)
	if tile_index < 0 or not board_system:
		return
	
	var tile_info = board_system.get_tile_info(tile_index)
	if tile_info.is_empty() or not tile_info.has("creature"):
		return
	
	var creature_data = tile_info["creature"]
	if creature_data.is_empty():
		return
	
	var effect_type = effect.get("effect_type", "")
	var value = effect.get("value", 0)
	var creature_name = creature_data.get("name", "クリーチャー")
	var notification_text = ""
	
	match effect_type:
		"permanent_hp_change":
			# 旧値を保存
			var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
			var old_current_hp = creature_data.get("current_hp", old_mhp)
			
			# MHP変更（current_hpも同時更新）
			EffectManager.apply_max_hp_effect(creature_data, value)
			
			# 新値を取得
			var new_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
			var new_current_hp = creature_data.get("current_hp", new_mhp)
			
			var sign = "+" if value >= 0 else ""
			notification_text = "%s MHP%s%d\nMHP: %d → %d / HP: %d → %d" % [
				creature_name, sign, value, old_mhp, new_mhp, old_current_hp, new_current_hp
			]
			print("[恒久変更] ", creature_name, " MHP ", sign, value)
		
		"permanent_ap_change":
			# AP変更（下限0でクランプ）
			if not creature_data.has("base_up_ap"):
				creature_data["base_up_ap"] = 0
			
			var base_ap = creature_data.get("ap", 0)
			var old_base_up_ap = creature_data.get("base_up_ap", 0)
			var old_total_ap = base_ap + old_base_up_ap
			var new_base_up_ap = old_base_up_ap + value
			
			# 最終APが0未満にならないよう調整
			var new_total_ap = base_ap + new_base_up_ap
			if new_total_ap < 0:
				new_base_up_ap = -base_ap  # 最終APを0に
				new_total_ap = 0
			
			creature_data["base_up_ap"] = new_base_up_ap
			
			var sign = "+" if value >= 0 else ""
			notification_text = "%s AP%s%d\nAP: %d → %d" % [
				creature_name, sign, value, old_total_ap, new_total_ap
			]
			print("[恒久変更] ", creature_name, " AP ", sign, value, " (合計AP: ", new_total_ap, ")")
	
	# 通知表示
	if not notification_text.is_empty() and spell_cast_notification_ui:
		spell_cast_notification_ui.show_notification_and_wait(notification_text)
		await spell_cast_notification_ui.click_confirmed

# ============ 密命スペル ============

## 密命: タイニーアーミー（MHP30以下5体以上でMHP+10、G500）
func _apply_secret_tiny_army(effect: Dictionary) -> void:
	if not board_system or not player_system:
		return
	
	var mhp_threshold = effect.get("mhp_threshold", 30)
	var required_count = effect.get("required_count", 5)
	var hp_bonus = effect.get("hp_bonus", 10)
	var gold_bonus = effect.get("gold_bonus", 500)
	
	# MHP30以下の自クリーチャーを収集
	var qualifying_creatures: Array[Dictionary] = []
	
	for tile_index in board_system.tile_nodes.keys():
		var tile_info = board_system.get_tile_info(tile_index)
		var tile_owner = tile_info.get("owner", -1)
		
		# 自分の土地のみ
		if tile_owner != current_player_id:
			continue
		
		var creature = tile_info.get("creature", {})
		if creature.is_empty():
			continue
		
		# MHPを計算
		var base_hp = creature.get("hp", 0)
		var base_up_hp = creature.get("base_up_hp", 0)
		var mhp = base_hp + base_up_hp
		
		# MHP閾値以下か
		if mhp <= mhp_threshold:
			qualifying_creatures.append({
				"tile_index": tile_index,
				"creature_data": creature,
				"mhp": mhp
			})
	
	print("[タイニーアーミー] MHP%d以下のクリーチャー: %d体 (必要: %d体)" % [mhp_threshold, qualifying_creatures.size(), required_count])
	
	# 条件判定
	if qualifying_creatures.size() < required_count:
		# 失敗: 復帰[ブック]
		print("[タイニーアーミー] 密命失敗 - クリーチャー不足")
		spell_failed = true
		
		# 失敗通知
		if spell_cast_notification_ui:
			var fail_text = "密命失敗！\nMHP%d以下のクリーチャー: %d体\n（必要: %d体）" % [mhp_threshold, qualifying_creatures.size(), required_count]
			spell_cast_notification_ui.show_notification_and_wait(fail_text)
			await spell_cast_notification_ui.click_confirmed
		
		# カードをデッキに戻す
		_return_spell_to_deck()
		return
	
	# 成功: 各クリーチャーにMHP+10を適用（1体ずつ通知）
	print("[タイニーアーミー] 密命成功！")
	
	for creature_info in qualifying_creatures:
		var tile_index = creature_info["tile_index"]
		var creature_data = creature_info["creature_data"]
		var creature_name = creature_data.get("name", "クリーチャー")
		
		# カメラをターゲットにフォーカス
		TargetSelectionHelper.focus_camera_on_tile(self, tile_index)
		
		# 旧値を保存
		var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
		var old_current_hp = creature_data.get("current_hp", old_mhp)
		
		# MHP+10を適用
		EffectManager.apply_max_hp_effect(creature_data, hp_bonus)
		
		# 新値を取得
		var new_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
		var new_current_hp = creature_data.get("current_hp", new_mhp)
		
		# 通知
		if spell_cast_notification_ui:
			var notification_text = "%s MHP+%d\nMHP: %d → %d / HP: %d → %d" % [
				creature_name, hp_bonus, old_mhp, new_mhp, old_current_hp, new_current_hp
			]
			spell_cast_notification_ui.show_notification_and_wait(notification_text)
			await spell_cast_notification_ui.click_confirmed
	
	# G500獲得（魔力として加算）
	player_system.add_magic(current_player_id, gold_bonus)
	print("[タイニーアーミー] G%d獲得" % gold_bonus)
	
	# G獲得通知
	if spell_cast_notification_ui:
		var gold_text = "G%d 獲得！" % gold_bonus
		spell_cast_notification_ui.show_notification_and_wait(gold_text)
		await spell_cast_notification_ui.click_confirmed

## スペルカードをデッキに戻す（復帰[ブック]）
func _return_spell_to_deck() -> void:
	if not card_system or selected_spell_card.is_empty():
		return
	
	var card_id = selected_spell_card.get("id", -1)
	var card_name = selected_spell_card.get("name", "?")
	
	# 手札からカードを探して削除
	var hand = card_system.get_all_cards_for_player(current_player_id)
	for i in range(hand.size()):
		if hand[i].get("id", -1) == card_id:
			# 手札から削除
			hand.remove_at(i)
			# デッキに戻す（IDを追加してシャッフル）
			card_system.player_decks[current_player_id].append(card_id)
			card_system.player_decks[current_player_id].shuffle()
			print("[復帰ブック] ", card_name, " をデッキに戻しました")
			break
