# MysticArtsHandler - アルカナアーツ関連処理を担当
extends Node
class_name MysticArtsHandler

## 親ハンドラー（SpellPhaseHandler）への参照
var _spell_phase_handler = null  # SpellPhaseHandler（循環参照回避）

## システム参照
var _ui_manager = null
var _board_system = null
var _player_system = null
var _card_system = null
var _game_3d_ref = null

## SpellMysticArts（アルカナアーツシステム）
var _spell_mystic_arts = null

## CPU処理参照
var _cpu_spell_phase_handler = null

func _ready() -> void:
	pass

## 初期化（setup() 時に呼ぶ）
func setup(
	spell_phase_handler,  # 型アノテーションなし（循環参照回避）
	ui_manager,
	board_system,
	player_system,
	card_system,
	game_3d_ref
) -> void:
	_spell_phase_handler = spell_phase_handler
	_ui_manager = ui_manager
	_board_system = board_system
	_player_system = player_system
	_card_system = card_system
	_game_3d_ref = game_3d_ref

## SpellMysticArtsシステムを初期化（set_game_stats()時に呼ぶ）
func initialize_spell_mystic_arts() -> void:
	if _spell_mystic_arts:
		return  # 既に初期化済み

	if not _board_system or not _player_system or not _card_system:
		push_error("[MAH] 必要なシステム参照が設定されていません")
		return

	_spell_mystic_arts = SpellMysticArts.new(
		_board_system,
		_player_system,
		_card_system,
		_spell_phase_handler
	)

	# シグナル接続
	if not _spell_mystic_arts.mystic_phase_completed.is_connected(_on_mystic_phase_completed):
		_spell_mystic_arts.mystic_phase_completed.connect(_on_mystic_phase_completed)

	if not _spell_mystic_arts.mystic_art_used.is_connected(_on_mystic_art_used):
		_spell_mystic_arts.mystic_art_used.connect(_on_mystic_art_used)

	if not _spell_mystic_arts.target_selection_requested.is_connected(_on_mystic_target_selection_requested):
		_spell_mystic_arts.target_selection_requested.connect(_on_mystic_target_selection_requested)

	if not _spell_mystic_arts.ui_message_requested.is_connected(_on_mystic_ui_message_requested):
		_spell_mystic_arts.ui_message_requested.connect(_on_mystic_ui_message_requested)

	print("[MAH] SpellMysticArts を初期化しました")

## SpellMysticArtsシステムを取得
func get_spell_mystic_arts():
	return _spell_mystic_arts

## アルカナアーツフェーズ開始（SpellMysticArtsに委譲）
func start_mystic_arts_phase():
	"""アルカナアーツ選択フェーズを開始"""
	if not _spell_mystic_arts:
		if _ui_manager and _ui_manager.phase_display:
			_ui_manager.show_toast("アルカナアーツシステムが初期化されていません")
		return

	if not _player_system:
		return

	var current_player = _player_system.get_current_player()
	if not current_player:
		return

	# SpellMysticArtsに委譲
	await _spell_mystic_arts.start_mystic_phase(current_player.id)

## CPUがアルカナアーツを実行
func _execute_cpu_mystic_arts(decision: Dictionary):
	if not _spell_phase_handler:
		push_error("[MAH] SpellPhaseHandler が初期化されていません")
		return

	# CPUSpellPhaseHandlerで準備処理（ダウンチェック含む）
	if not _cpu_spell_phase_handler:
		const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
		_cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
		_cpu_spell_phase_handler.initialize(_spell_phase_handler)

	var prep = _cpu_spell_phase_handler.prepare_mystic_execution(decision, _spell_phase_handler.spell_state.current_player_id)
	if not prep.get("success", false):
		if _spell_phase_handler and _spell_phase_handler.spell_flow:
			_spell_phase_handler.spell_flow.pass_spell(false)
		else:
			push_error("[MysticArtsHandler] spell_flow が初期化されていません")
		return

	var mystic = prep.get("mystic", {})
	var mystic_data = prep.get("mystic_data", {})
	var creature_info = prep.get("creature_info", {})
	var target_data = prep.get("target_data", {})
	var target = prep.get("target", {})

	# 注意: コストはspell_mystic_arts.execute_mystic_art()内で支払われる
	# ここで先に支払うと、can_cast_mystic_artで失敗した場合にコストが戻らない

	# 発動通知表示
	if _spell_phase_handler.spell_cast_notification_ui:
		var caster_name = creature_info.get("creature_data", {}).get("name", "クリーチャー")
		await _spell_phase_handler.show_spell_cast_notification(caster_name, target, mystic_data, true)

	# アルカナアーツ効果を実行（コスト支払いはexecute_mystic_art内で行われる）
	if _spell_mystic_arts:
		_spell_mystic_arts.current_mystic_player_id = _spell_phase_handler.spell_state.current_player_id
		await _spell_mystic_arts.execute_mystic_art(creature_info, mystic, target_data)
		return

	_spell_phase_handler.complete_spell_phase()

## アルカナアーツが利用可能か確認
func has_available_mystic_arts(player_id: int) -> bool:
	if not _has_spell_mystic_arts():
		return false

	var available = _spell_mystic_arts.get_available_creatures(player_id)
	return available.size() > 0

## SpellMysticArtsクラスが存在するか
func _has_spell_mystic_arts() -> bool:
	return _spell_mystic_arts != null and _spell_mystic_arts is SpellMysticArts

## アルカナアーツボタンの表示状態を更新（外部から呼び出し可能）
func update_mystic_button_visibility():
	if not _ui_manager or not _spell_phase_handler:
		return

	if _spell_phase_handler.spell_state.current_state == SpellStateHandler.State.INACTIVE:
		return

	if has_available_mystic_arts(_spell_phase_handler.spell_state.current_player_id):
		_ui_manager.show_mystic_button(func(): start_mystic_arts_phase())
	else:
		_ui_manager.hide_mystic_button()

## アルカナアーツ使用時にボタンを隠す
func _on_mystic_art_used():
	# アルカナアーツ使用時はアルカナアーツボタンを非表示
	if _ui_manager:
		_ui_manager.hide_mystic_button()

## アルカナアーツフェーズ完了時
func _on_mystic_phase_completed():
	if not _spell_phase_handler:
		return

	# spell_stateを完全にリセット（spell_used_this_turn を false に）
	_spell_phase_handler.spell_state.reset_turn_state()
	_spell_phase_handler.spell_state.set_current_player_id(_spell_phase_handler.spell_state.current_player_id)
	_spell_phase_handler.spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)

	if _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow.return_to_spell_selection()
	else:
		push_error("[MysticArtsHandler] spell_flow が初期化されていません")

## アルカナアーツターゲット選択要求時
func _on_mystic_target_selection_requested(targets: Array) -> void:
	if not _spell_phase_handler or not _ui_manager:
		return

	# ★ 検証ログ: disable_navigation() 呼び出しを確認
	print("[MAH-Flow] _on_mystic_target_selection_requested: targets=%d, disable_navigation() 実行開始" % targets.size())

	# ★ NEW: 前のナビゲーション状態をクリア
	_ui_manager.disable_navigation()
	print("[MAH-Flow] disable_navigation() 呼び出し完了")

	_spell_phase_handler.spell_state.transition_to(SpellStateHandler.State.SELECTING_TARGET)

	# SpellTargetSelectionHandlerに状態を同期
	if _spell_phase_handler.spell_target_selection_handler and not targets.is_empty():
		_spell_phase_handler.spell_target_selection_handler.set_available_targets(targets)
		_spell_phase_handler.spell_target_selection_handler.set_current_target_index(0)

	# TapTargetManagerでタップ選択を開始（アルカナアーツ用）
	if _ui_manager.tap_target_manager:
		_spell_phase_handler._start_mystic_tap_target_selection(targets)

	# グローバルナビゲーション設定（対象選択用 - アルカナアーツでも戻るボタンを表示）
	if _spell_phase_handler and _spell_phase_handler.spell_navigation_controller:
		_spell_phase_handler.spell_navigation_controller._setup_target_selection_navigation()
	else:
		push_error("[MAH] spell_navigation_controller が初期化されていません")

## アルカナアーツUIメッセージ表示要求時
func _on_mystic_ui_message_requested(message: String):
	if _ui_manager and _ui_manager.phase_display:
		_ui_manager.show_action_prompt(message)

## CPUスペル/アルカナアーツターンハンドラーを実行
func execute_cpu_mystic_turn(decision: Dictionary):
	"""CPUのアルカナアーツ実行判定（SpellPhaseHandler._handle_cpu_spell_turn()から呼ぶ）"""
	await _execute_cpu_mystic_arts(decision)
