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
	EXECUTING_EFFECT    # 効果実行中
}

var current_state: State = State.INACTIVE
var current_player_id: int = -1
var selected_spell_card: Dictionary = {}
var spell_used_this_turn: bool = false  # 1ターン1回制限
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
		print("[SpellPhaseHandler.initialize()] SpellMysticArts 初期化完了")
	
	# SpellPhaseUIManager を初期化
	_initialize_spell_phase_ui()

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
		print("[spell_phase_handler] SpellMysticArts が初期化されていません")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術システムが初期化されていません"
		return
	
	if not player_system:
		print("[spell_phase_handler] player_system が設定されていません")
		return
	
	# 現在のプレイヤーを取得
	var current_player = player_system.get_current_player()
	if not current_player:
		print("[spell_phase_handler] 現在のプレイヤーを取得できません")
		return
	
	print("[spell_phase_handler] 秘術フェーズ開始 - プレイヤー %d" % current_player.id)
	
	# 秘術を持つクリーチャーを取得
	var available_creatures = spell_mystic_arts.get_available_creatures(current_player.id)
	
	if available_creatures.is_empty():
		print("[spell_phase_handler] 秘術を持つクリーチャーがありません")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術を持つクリーチャーがありません"
		return
	
	print("[spell_phase_handler] 秘術を持つクリーチャー数: %d" % available_creatures.size())
	
	# クリーチャー選択UIを表示
	await _select_mystic_arts_creature(available_creatures, current_player.id)

## クリーチャー選択
func _select_mystic_arts_creature(available_creatures: Array, player_id: int):
	"""秘術を持つクリーチャーを選択"""
	if not ui_manager:
		print("[spell_phase_handler] ui_manager が設定されていません")
		return
	
	# SpellAndMysticUI を取得または作成
	var spell_and_mystic_ui = ui_manager.get_node_or_null("SpellAndMysticUI")
	if not spell_and_mystic_ui:
		# 動的にロード
		var SpellAndMysticUIClass = load("res://scripts/ui_components/spell_and_mystic_ui.gd")
		if not SpellAndMysticUIClass:
			print("[spell_phase_handler] SpellAndMysticUI をロードできません")
			return
		
		# 新規作成
		spell_and_mystic_ui = SpellAndMysticUIClass.new()
		spell_and_mystic_ui.name = "SpellAndMysticUI"
		ui_manager.add_child(spell_and_mystic_ui)
		print("[spell_phase_handler] SpellAndMysticUI を新規作成")
	
	# クリーチャー選択UIを表示
	spell_and_mystic_ui.show_creature_selection(available_creatures)
	
	# クリーチャー選択を待機
	var selected_index = await spell_and_mystic_ui.creature_selected
	
	if selected_index < 0 or selected_index >= available_creatures.size():
		print("[spell_phase_handler] クリーチャー選択がキャンセルされました")
		spell_and_mystic_ui.hide_all()
		return
	
	var selected_creature = available_creatures[selected_index]
	print("[spell_phase_handler] クリーチャー選択: %s" % selected_creature.creature_data.get("name", "Unknown"))
	
	# 秘術選択に進む
	await _select_mystic_art(selected_creature, spell_and_mystic_ui)

## 秘術選択
func _select_mystic_art(selected_creature: Dictionary, spell_and_mystic_ui: Control):
	"""クリーチャーの秘術を選択"""
	var mystic_arts = selected_creature.get("mystic_arts", [])
	
	if mystic_arts.is_empty():
		print("[spell_phase_handler] 秘術がありません")
		spell_and_mystic_ui.hide_all()
		return
	
	# 秘術選択UIを表示
	spell_and_mystic_ui.show_mystic_art_selection(mystic_arts)
	
	# 秘術選択を待機
	var selected_index = await spell_and_mystic_ui.mystic_art_selected
	
	if selected_index < 0 or selected_index >= mystic_arts.size():
		print("[spell_phase_handler] 秘術選択がキャンセルされました")
		spell_and_mystic_ui.hide_all()
		return
	
	var selected_mystic_art = mystic_arts[selected_index]
	print("[spell_phase_handler] 秘術選択: %s" % selected_mystic_art.get("name", "Unknown"))
	
	# UIを非表示
	spell_and_mystic_ui.hide_all()
	
	# ターゲット選択に進む
	var current_player = player_system.get_current_player()
	await _select_mystic_arts_target(selected_creature, selected_mystic_art, current_player.id)

## ターゲット選択
func _select_mystic_arts_target(selected_creature: Dictionary, selected_mystic_art: Dictionary, player_id: int):
	"""秘術のターゲットを選択"""
	var target_type = selected_mystic_art.get("target_type", "")
	var target_filter = selected_mystic_art.get("target_filter", "any")
	
	print("[spell_phase_handler] ターゲット選択開始 - タイプ: %s, フィルター: %s" % [target_type, target_filter])
	
	# セルフターゲット時はUI表示なし
	if target_filter == "self":
		var target_data = {
			"type": target_type,
			"tile_index": selected_creature.get("tile_index", -1)
		}
		print("[spell_phase_handler] セルフターゲット自動選択")
		await _execute_mystic_art(selected_creature, selected_mystic_art, target_data, player_id)
		return
	
	# 通常ターゲット選択
	var target_info = {
		"filter": target_filter
	}
	
	var available_targets = TargetSelectionHelper.get_valid_targets(self, target_type, target_info)
	
	if available_targets.is_empty():
		print("[spell_phase_handler] 有効なターゲットがありません")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "有効なターゲットがありません"
		return
	
	print("[spell_phase_handler] 利用可能なターゲット数: %d" % available_targets.size())
	
	# ターゲット選択（最初のターゲットを自動選択）
	if available_targets.is_empty():
		print("[spell_phase_handler] ターゲット選択がキャンセルされました")
		TargetSelectionHelper.clear_selection(self)
		return
	
	# TODO: ターゲット選択UI（既存のスペルターゲット選択を流用する予定）
	# 暫定：最初のターゲットを自動選択
	var selected_target = available_targets[0]
	print("[spell_phase_handler] ターゲット選択完了（自動選択: %s）" % str(selected_target))
	
	# 秘術を実行
	await _execute_mystic_art(selected_creature, selected_mystic_art, selected_target, player_id)

## 秘術実行
func _execute_mystic_art(selected_creature: Dictionary, selected_mystic_art: Dictionary, target_data: Dictionary, player_id: int):
	"""秘術効果を実行"""
	print("[spell_phase_handler] 秘術実行開始")
	
	# 発動判定
	var context = {
		"player_id": player_id,
		"player_magic": player_system.get_magic(player_id),
		"spell_used_this_turn": spell_used_this_turn,
		"tile_index": selected_creature.get("tile_index", -1)
	}
	
	if not spell_mystic_arts.can_cast_mystic_art(selected_mystic_art, context):
		print("[spell_phase_handler] 秘術発動条件を満たしていません")
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術発動条件を満たしていません"
		return
	
	# 秘術効果を適用
	var success = spell_mystic_arts.apply_mystic_art_effect(selected_mystic_art, target_data, context)
	
	if success:
		# 魔力消費
		var cost = selected_mystic_art.get("cost", 0)
		player_system.consume_magic(player_id, cost)
		spell_used_this_turn = true
		
		# キャスターをダウン状態に設定
		spell_mystic_arts._set_caster_down_state(selected_creature.get("tile_index", -1))
		
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "『%s』を発動しました！" % selected_mystic_art.get("name", "Unknown")
		
		print("[spell_phase_handler] 秘術発動成功")
	else:
		if ui_manager and ui_manager.phase_label:
			ui_manager.phase_label.text = "秘術の発動に失敗しました"
		print("[spell_phase_handler] 秘術発動失敗")
	
	# ターゲット選択をクリア
	TargetSelectionHelper.clear_selection(self)

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
	
	# target_filter が "self" の場合は、即座に効果発動（対象選択UIなし）
	if target_filter == "self":
		# 対象選択なし。効果実行時に current_player_id を使用
		var target_data = {"type": "player", "player_id": current_player_id}
		execute_spell_effect(spell_card, target_data)
	elif not target_type.is_empty() and target_type != "none":
		# 対象選択が必要
		current_state = State.SELECTING_TARGET
		target_selection_required.emit(spell_card, target_type)
		
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
	
	execute_spell_effect(selected_spell_card, selected_target)

## 対象選択をキャンセル
func _cancel_target_selection():
	# 選択をクリア
	TargetSelectionHelper.clear_selection(self)
	
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
	
	print("[execute_spell_effect] カード名='%s', ID=%d" % [spell_card.get("name", "???"), spell_card.get("id", -1)])
	
	# 復帰[ブック]フラグをリセット
	spell_failed = false
	
	# スペル効果を実行
	
	var parsed = spell_card.get("effect_parsed", {})
	var effects = parsed.get("effects", [])
	
	print("[execute_spell_effect] effects配列: ", effects)
	
	for effect in effects:
		_apply_single_effect(effect, target_data)
	
	# カードを捨て札に（復帰[ブック]時はスキップ）
	if card_system and not spell_failed:
		# 手札からカードのインデックスを探す
		var hand = card_system.get_all_cards_for_player(current_player_id)
		for i in range(hand.size()):
			if hand[i].get("id", -1) == spell_card.get("id", -2):
				card_system.discard_card(current_player_id, i, "use")
				break
	elif spell_failed:
		print("[復帰[ブック]] カードは捨て札に送られず、デッキに戻されました")
	
	# 効果発動完了
	spell_used.emit(spell_card)
	
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
	
	print("[_apply_single_effect] effect_type='%s'" % effect_type)
	
	match effect_type:
		"damage":
			# クリーチャーにダメージ
			_apply_damage_effect(effect, target_data)
		
		"drain_magic":
			# 魔力を奪う
			_apply_drain_magic_effect(effect, target_data)
		
		"dice_fixed":
			# ダイス固定（ホーリーワード6など）
			if game_flow_manager and game_flow_manager.spell_dice:
				game_flow_manager.spell_dice.apply_dice_fixed_effect(effect, target_data, current_player_id)
		
		"dice_range":
			# ダイス範囲指定（ヘイスト）
			if game_flow_manager and game_flow_manager.spell_dice:
				game_flow_manager.spell_dice.apply_dice_range_effect(effect, target_data, current_player_id)
		
		"dice_multi":
			# 複数ダイスロール（フライ）
			if game_flow_manager and game_flow_manager.spell_dice:
				game_flow_manager.spell_dice.apply_dice_multi_effect(effect, target_data, current_player_id)
		
		"dice_range_magic":
			# 範囲指定 + 魔力獲得（チャージステップ）
			if game_flow_manager and game_flow_manager.spell_dice:
				game_flow_manager.spell_dice.apply_dice_range_magic_effect(effect, target_data, current_player_id)
		
		"stat_boost":
			# 能力値上昇呪い（バイタリティ等）
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse_stat:
					game_flow_manager.spell_curse_stat.apply_stat_boost(tile_index, effect)
		
		"stat_reduce":
			# 能力値減少呪い（ディジーズ等）
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse_stat:
					game_flow_manager.spell_curse_stat.apply_stat_reduce(tile_index, effect)
		
		"toll_share":
			# 通行料促進（ドリームトレイン）
			if target_data.get("type") == "player":
				var target_player_id = target_data.get("player_id", current_player_id)
				var duration = effect.get("duration", 5)
				if game_flow_manager and game_flow_manager.spell_curse_toll:
					# caster_id は現在のプレイヤー（スペルを使用した人）
					game_flow_manager.spell_curse_toll.apply_toll_share(target_player_id, duration, current_player_id)
		
		"toll_disable":
			# 通行料無効（ブラックアウト）
			if target_data.get("type") == "player":
				var target_player_id = target_data.get("player_id", -1)
				var duration = effect.get("duration", 2)
				if game_flow_manager and game_flow_manager.spell_curse_toll:
					game_flow_manager.spell_curse_toll.apply_toll_disable(target_player_id, duration)
		
		"toll_fixed":
			# 通行料固定（ユニフォーミティ）
			if target_data.get("type") == "player":
				var target_player_id = target_data.get("player_id", -1)
				var value = effect.get("value", 200)
				var duration = effect.get("duration", 3)
				if game_flow_manager and game_flow_manager.spell_curse_toll:
					game_flow_manager.spell_curse_toll.apply_toll_fixed(target_player_id, value, duration)
		
		"toll_multiplier":
			# 通行料倍率（グリード）
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				var multiplier = effect.get("multiplier", 1.5)
				if game_flow_manager and game_flow_manager.spell_curse_toll:
					game_flow_manager.spell_curse_toll.apply_toll_multiplier(tile_index, multiplier)
		
		"peace":
			# 平和（ピース）
			if target_data.get("type") == "land":
				var tile_index = target_data.get("tile_index", -1)
				if game_flow_manager and game_flow_manager.spell_curse_toll:
					game_flow_manager.spell_curse_toll.apply_peace(tile_index)
		
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

## クリーチャーダメージ効果
func _apply_damage_effect(effect: Dictionary, target_data: Dictionary):
	if target_data.get("type", "") != "creature":
		return
	
	var tile_index = target_data.get("tile_index", -1)
	var value = effect.get("value", 0)
	
	if not board_system or tile_index < 0 or not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	if not tile or not "creature_data" in tile:
		return
	
	var creature = tile.creature_data
	if creature.is_empty():
		return
	
	var current_hp = creature.get("hp", 0)
	var land_bonus_hp = creature.get("land_bonus_hp", 0)
	
	# ダメージを基本HPから優先的に減らす
	var damage_to_base = min(value, current_hp)
	creature["hp"] = current_hp - damage_to_base
	var remaining_damage = value - damage_to_base
	
	# 残りダメージを土地ボーナスHPから減らす
	if remaining_damage > 0:
		creature["land_bonus_hp"] = max(0, land_bonus_hp - remaining_damage)
	
	# クリーチャーが倒れた場合
	if creature["hp"] <= 0 and creature.get("land_bonus_hp", 0) <= 0:
		# 【SSoT同期】スペルで倒されたクリーチャーをタイルからクリア
		# この代入は自動的にCreatureManager.set_data(tile_index, {})を呼び出し
		# CreatureManager.creatures[tile_index]から削除される
		tile.creature_data = {}
		tile.owner_id = -1
		tile.level = 1
		tile.update_visual()

## 魔力奪取効果
func _apply_drain_magic_effect(effect: Dictionary, target_data: Dictionary):
	if target_data.get("type", "") != "player" or not player_system:
		return
	
	var target_player_id = target_data.get("player_id", -1)
	if target_player_id < 0:
		return
	
	var value = effect.get("value", 0)
	var current_magic = player_system.get_magic(target_player_id)
	var value_type = effect.get("value_type", "fixed")
	
	var drain_amount = 0
	if value_type == "percentage":
		drain_amount = int(current_magic * value / 100.0)
	else:
		drain_amount = value
	
	drain_amount = min(drain_amount, current_magic)  # 所持魔力以上は奪えない
	
	# 魔力を移動
	player_system.add_magic(target_player_id, -drain_amount)
	player_system.add_magic(current_player_id, drain_amount)

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

## アクティブか
func is_spell_phase_active() -> bool:
	return current_state != State.INACTIVE

# ============ 秘術システム対応（新規追加）============

## 秘術が利用可能か確認
func has_available_mystic_arts(player_id: int) -> bool:
	if not has_spell_mystic_arts():
		return false
	
	var available = spell_mystic_arts.get_available_creatures(player_id)
	return available.size() > 0

## SpellMysticArtsクラスが存在するか
func has_spell_mystic_arts() -> bool:
	return spell_mystic_arts != null and spell_mystic_arts is SpellMysticArts

## 有効なターゲットを取得（スペルと秘術で共用）
func _get_valid_targets(target_type: String, target_filter: String) -> Array:
	var targets: Array = []
	
	var target_info = {
		"target_filter": target_filter
	}
	
	match target_type:
		"creature":
			target_info["owner_filter"] = "enemy"
			targets = TargetSelectionHelper.get_valid_targets(self, "creature", target_info)
		"land":
			target_info["owner_filter"] = target_filter
			targets = TargetSelectionHelper.get_valid_targets(self, "land", target_info)
		"player":
			target_info["target_filter"] = target_filter
			targets = TargetSelectionHelper.get_valid_targets(self, "player", target_info)
		"world":
			# 世界呪は常に有効（ターゲット選択なし）
			targets = [{"type": "world"}]
	
	return targets

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
		spell_phase_ui_manager.show_mystic_button()
		spell_phase_ui_manager.show_spell_skip_button()

## スペルフェーズ終了時にボタンを非表示
func _hide_spell_phase_buttons():
	if spell_phase_ui_manager:
		spell_phase_ui_manager.hide_mystic_button()
		spell_phase_ui_manager.hide_spell_skip_button()

## スペル使用時に秘術ボタンを隠す
func _on_spell_used():
	if spell_phase_ui_manager:
		spell_phase_ui_manager.on_spell_used()

## 秘術使用時にスペルボタンを隠す
func _on_mystic_art_used():
	if spell_phase_ui_manager:
		spell_phase_ui_manager.on_mystic_art_used()
