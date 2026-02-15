# SpellTargetSelectionHandler - スペル対象選択処理を担当
extends Node
class_name SpellTargetSelectionHandler

## 親ハンドラー（SpellPhaseHandler）への参照
var _spell_phase_handler: SpellPhaseHandler = null

## システム参照
var _ui_manager = null
var _board_system = null
var _player_system = null
var _game_3d_ref = null

## 対象選択用の状態
var _available_targets: Array = []
var _current_target_index: int = 0
var _selection_marker: MeshInstance3D = null
var _confirmation_markers: Array = []

## 状態フラグ
var _is_selecting: bool = false

# 互換性プロパティ（target_marker_system.gd, target_ui_helper.gd との互換性用）
var selection_marker: MeshInstance3D:
	get:
		return _selection_marker
	set(value):
		_selection_marker = value

var confirmation_markers: Array:
	get:
		return _confirmation_markers
	set(value):
		_confirmation_markers = value

var available_targets: Array:
	get:
		return _available_targets
	set(value):
		_available_targets = value

var current_target_index: int:
	get:
		return _current_target_index
	set(value):
		if value >= 0 and value < _available_targets.size():
			_current_target_index = value

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# 選択マーカーを回転
	if _is_selecting:
		TargetSelectionHelper.rotate_selection_marker(_spell_phase_handler, delta)
		# 確認フェーズ用マーカーを回転
		TargetSelectionHelper.rotate_confirmation_markers(_spell_phase_handler, delta)

## 初期化（setup() 時に呼ぶ）
func setup(
	spell_phase_handler: SpellPhaseHandler,
	ui_manager,
	board_system,
	player_system,
	game_3d_ref
) -> void:
	_spell_phase_handler = spell_phase_handler
	_ui_manager = ui_manager
	_board_system = board_system
	_player_system = player_system
	_game_3d_ref = game_3d_ref

## 対象選択UIを表示
## 戻り値: true=対象選択開始, false=対象なしでキャンセル
func show_target_selection_ui(target_type: String, target_info: Dictionary) -> bool:
	print("[STSH-DEBUG] show_target_selection_ui() 開始: target_type=%s" % target_type)

	# disable_navigation() 呼び出し直前
	print("[STSH-DEBUG] disable_navigation() 呼び出し直前:")
	if _ui_manager:
		print("  ui_manager: ✓")
		print("  on_confirm: %s" % ("✓" if _ui_manager._compat_confirm_cb.is_valid() else "✗"))
		print("  on_cancel: %s" % ("✓" if _ui_manager._compat_back_cb.is_valid() else "✗"))
		print("  on_prev: %s" % ("✓" if _ui_manager._compat_up_cb.is_valid() else "✗"))
		print("  on_next: %s" % ("✓" if _ui_manager._compat_down_cb.is_valid() else "✗"))
	else:
		print("  ui_manager: ✗")

	# ★ NEW: 前のナビゲーション設定をクリア
	if _ui_manager:
		print("[STSH-DEBUG] disable_navigation() 呼び出し実行")
		_ui_manager.disable_navigation()
		print("[STSH-DEBUG] disable_navigation() 呼び出し直後:")
		print("  on_confirm: %s" % ("✓" if _ui_manager._compat_confirm_cb.is_valid() else "✗"))
		print("  on_cancel: %s" % ("✓" if _ui_manager._compat_back_cb.is_valid() else "✗"))
		print("  on_prev: %s" % ("✓" if _ui_manager._compat_up_cb.is_valid() else "✗"))
		print("  on_next: %s" % ("✓" if _ui_manager._compat_down_cb.is_valid() else "✗"))
	else:
		print("[STSH-DEBUG] ⚠️ _ui_manager が NULL")

	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return false

	# 有効な対象を取得（ヘルパー使用）
	var targets: Array = TargetSelectionHelper.get_valid_targets(_spell_phase_handler, target_type, target_info)
	print("[STSH-Flow] get_valid_targets() 完了: %d個の対象を取得" % targets.size())

	if targets.is_empty():
		# 対象がいない場合はメッセージ表示
		print("[STSH-Flow] 対象なし - ユーザーメッセージ表示")
		if _ui_manager and _ui_manager.phase_display:
			_ui_manager.show_toast("対象がいません")
		await get_tree().create_timer(1.0).timeout
		return false

	# CPUの場合は自動で対象選択
	if _is_cpu_player(_spell_phase_handler.spell_state.current_player_id):
		print("[STSH-Flow] CPU プレイヤー - 自動対象選択開始")
		return _cpu_select_target(targets, target_type, target_info)

	# プレイヤーの場合：ドミニオコマンドと同じ方式で選択開始
	print("[STSH-Flow] プレイヤー対象選択開始")
	_available_targets = targets
	_current_target_index = 0
	_is_selecting = true
	print("[STSH-Flow] _available_targets設定: %d個" % _available_targets.size())
	print("[STSH-Flow] _current_target_index = 0")
	print("[STSH-Flow] _is_selecting = true")

	# TapTargetManagerでタップ選択を開始
	if _ui_manager and _ui_manager.tap_target_manager:
		print("[STSH-Flow] TapTargetManager 設定開始")
		_start_spell_tap_target_selection(targets, target_type)
		print("[STSH-Flow] TapTargetManager 設定完了")

	# グローバルナビゲーション設定（対象選択用）
	print("[STSH-Flow] _setup_target_selection_navigation() 呼び出し開始")
	_setup_target_selection_navigation()
	print("[STSH-Flow] _setup_target_selection_navigation() 完了")

	# 最初の対象を表示
	_update_target_selection()
	print("[STSH-Flow] show_target_selection_ui() 完了 - 入力待機開始")
	return true

## CPU用対象選択（自動）
func _cpu_select_target(targets: Array, _target_type: String, _target_info: Dictionary) -> bool:
	if targets.is_empty():
		return false

	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return false

	# CPUSpellPhaseHandlerで最適な対象を選択
	var cpu_spell_phase_handler = _spell_phase_handler.cpu_spell_phase_handler
	if not cpu_spell_phase_handler:
		const CPUSpellPhaseHandlerScript = preload("res://scripts/cpu_ai/cpu_spell_phase_handler.gd")
		cpu_spell_phase_handler = CPUSpellPhaseHandlerScript.new()
		cpu_spell_phase_handler.initialize(_spell_phase_handler)
		_spell_phase_handler.cpu_spell_phase_handler = cpu_spell_phase_handler

	var best_target: Dictionary = cpu_spell_phase_handler.select_best_target(
		targets,
		_spell_phase_handler.spell_state.selected_spell_card,
		_spell_phase_handler.spell_state.current_player_id
	)
	if best_target.is_empty():
		best_target = targets[0]

	# 選択した対象で確認フェーズへ
	var parsed: Dictionary = _spell_phase_handler.spell_state.selected_spell_card.get("effect_parsed", {})
	var target_info_for_confirm: Dictionary = parsed.get("target_info", {})
	if _spell_phase_handler and _spell_phase_handler.spell_flow:
		_spell_phase_handler.spell_flow._start_confirmation_phase(best_target.get("type", ""), target_info_for_confirm, best_target)
	else:
		push_error("[STSH] spell_flow が初期化されていません")
	return true

## 対象をログ用にフォーマット
func _format_target_for_log(target: Dictionary) -> String:
	if not _spell_phase_handler:
		return str(target)

	var cpu_spell_phase_handler = _spell_phase_handler.cpu_spell_phase_handler
	if cpu_spell_phase_handler:
		return cpu_spell_phase_handler.format_target_for_log(target)

	var target_type: String = target.get("type", "")
	match target_type:
		"creature":
			var creature: Dictionary = target.get("creature", {})
			return "クリーチャー: %s (タイル%d)" % [creature.get("name", "?"), target.get("tile_index", -1)]
		"land":
			return "土地: タイル%d" % target.get("tile_index", -1)
		"player":
			return "プレイヤー%d" % (target.get("player_id", 0) + 1)
		_:
			return str(target)

## 選択を更新
func _update_target_selection() -> void:
	if _available_targets.is_empty():
		return

	var target: Dictionary = _available_targets[_current_target_index]

	# 汎用ヘルパーを使用して視覚的に選択（クリーチャー情報パネルも自動表示）
	TargetSelectionHelper.select_target_visually(_spell_phase_handler, target)

	# select_target_visually→show_card_info(false)がナビゲーションをクリアするため再設定
	_setup_target_selection_navigation()

	# UI更新
	_update_selection_ui()

## 選択UIを更新
func _update_selection_ui() -> void:
	if not _ui_manager or not _ui_manager.phase_label:
		return

	if _available_targets.is_empty():
		return

	var target: Dictionary = _available_targets[_current_target_index]

	# ヘルパーを使用してテキスト生成
	var text: String = TargetSelectionHelper.format_target_info(target, _current_target_index + 1, _available_targets.size())
	if _ui_manager.phase_display:
		_ui_manager.show_action_prompt(text)

## 入力処理（_input イベント）
func _input(event: InputEvent) -> void:
	if not _is_selecting:
		return

	if not _spell_phase_handler:
		return

	if _spell_phase_handler.spell_state.current_state != SpellStateHandler.State.SELECTING_TARGET:
		return

	# キー入力時にログ出力
	if event is InputEventKey:
		print("[STSH-Flow] _input() 呼び出し: keycode=%d, pressed=%s" % [event.keycode, event.pressed])

	if event is InputEventKey and event.pressed:

		# ↑キーまたは←キー: 前の対象
		if event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			print("[STSH-Flow] UP キー検出 → _on_target_prev() 呼び出し")
			if TargetSelectionHelper.move_target_previous(_spell_phase_handler):
				_update_target_selection()
			get_viewport().set_input_as_handled()

		# ↓キーまたは→キー: 次の対象
		elif event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			print("[STSH-Flow] DOWN キー検出 → _on_target_next() 呼び出し")
			if TargetSelectionHelper.move_target_next(_spell_phase_handler):
				_update_target_selection()
			get_viewport().set_input_as_handled()

		# Enterキー: 確定
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("[STSH-Flow] ENTER キー検出 → _confirm_target_selection() 呼び出し")
			_confirm_target_selection()
			get_viewport().set_input_as_handled()

		# 数字キー1-9, 0: 直接選択して即確定
		elif TargetSelectionHelper.is_number_key(event.keycode):
			var index: int = TargetSelectionHelper.get_number_from_key(event.keycode)
			print("[STSH-Flow] 数字キー%d 検出 → インデックス%dで選択確定" % [index, index])
			if TargetSelectionHelper.select_target_by_index(_spell_phase_handler, index):
				_update_target_selection()
				# 数字キーの場合は即座に確定
				_confirm_target_selection()
			get_viewport().set_input_as_handled()

		# Cキーまたはエスケープ: キャンセル
		elif event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			print("[STSH-Flow] C/ESC キー検出 → _cancel_target_selection() 呼び出し")
			_cancel_target_selection()
			get_viewport().set_input_as_handled()

## 対象選択を確定
func _confirm_target_selection() -> void:
	if _available_targets.is_empty():
		return

	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return

	var selected_target: Dictionary = _available_targets[_current_target_index]

	# チュートリアルのターゲット制限チェック
	var target_type: String = selected_target.get("type", "")
	if target_type == "player":
		var player_id: int = selected_target.get("player_id", -1)
		if not _check_tutorial_player_target_allowed(player_id):
			print("[STSH] チュートリアル制限: プレイヤー%d は選択不可" % player_id)
			return
	else:
		if not _check_tutorial_target_allowed(selected_target.get("tile_index", -1)):
			print("[STSH] チュートリアル制限: タイル%d は選択不可" % selected_target.get("tile_index", -1))
			return

	# TapTargetManagerの選択を終了
	_end_spell_tap_target_selection()

	# 選択をクリア（クリーチャー情報パネルも自動で閉じる）
	TargetSelectionHelper.clear_selection(_spell_phase_handler)

	# 借用スペル実行中の場合（SpellBorrow用）
	if _spell_phase_handler.spell_state.is_in_borrow_spell_mode():
		_spell_phase_handler.target_confirmed.emit(selected_target)
		_spell_phase_handler.spell_state.set_borrow_spell_mode(false)
		_is_selecting = false
		return

	# アルカナアーツかスペルかで分岐
	if _spell_phase_handler.spell_mystic_arts and _spell_phase_handler.spell_mystic_arts.is_active():
		# アルカナアーツ実行（SpellMysticArtsに委譲）
		_spell_phase_handler.spell_mystic_arts.on_target_confirmed(selected_target)
	else:
		# スペル実行（SpellFlowHandler経由）
		if _spell_phase_handler and _spell_phase_handler.spell_flow:
			await _spell_phase_handler.spell_flow.execute_spell_effect(_spell_phase_handler.spell_state.selected_spell_card, selected_target)
		else:
			push_error("[STSH] spell_flow が初期化されていません")

	_is_selecting = false

## 対象選択をキャンセル
func _cancel_target_selection() -> void:
	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return

	# TapTargetManagerの選択を終了
	_end_spell_tap_target_selection()

	# 選択をクリア（クリーチャー情報パネルも自動で閉じる）
	TargetSelectionHelper.clear_selection(_spell_phase_handler)

	# 借用スペル実行中の場合（SpellBorrow用）
	if _spell_phase_handler.spell_state.is_in_borrow_spell_mode():
		_spell_phase_handler.target_confirmed.emit({"cancelled": true})
		_spell_phase_handler.spell_state.set_borrow_spell_mode(false)
		_is_selecting = false
		return

	# 外部スペルモードの場合（魔法タイル等）
	if _spell_phase_handler.spell_state.is_in_external_spell_mode():
		if _spell_phase_handler and _spell_phase_handler.spell_flow:
			_spell_phase_handler.spell_flow.cancel_spell()
		else:
			push_error("[STSH] spell_flow が初期化されていません")
		_is_selecting = false
		return

	# アルカナアーツかスペルかで分岐
	if _spell_phase_handler.spell_mystic_arts and _spell_phase_handler.spell_mystic_arts.is_active():
		# アルカナアーツキャンセル
		_spell_phase_handler.spell_mystic_arts.clear_selection()
		_spell_phase_handler.spell_mystic_arts.end_mystic_phase()
		_spell_phase_handler.spell_state.transition_to(SpellStateHandler.State.WAITING_FOR_INPUT)
		# スペル選択画面に戻る
		if _spell_phase_handler and _spell_phase_handler.spell_flow:
			_spell_phase_handler.spell_flow.return_to_spell_selection()
		else:
			push_error("[STSH] spell_flow が初期化されていません")
	else:
		# スペルキャンセル
		if _spell_phase_handler and _spell_phase_handler.spell_flow:
			_spell_phase_handler.spell_flow.cancel_spell()
		else:
			push_error("[STSH] spell_flow が初期化されていません")

	_is_selecting = false

## 対象選択フェーズを抜けるときの共通処理
func _exit_target_selection_phase() -> void:
	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return

	# 選択マーカーをクリア
	TargetSelectionHelper.clear_selection(_spell_phase_handler)

	# ナビゲーションをクリア
	_clear_spell_navigation()

	# カメラをプレイヤーに戻す
	_spell_phase_handler.return_camera_to_player()

	# アクション指示パネルを閉じる
	if _ui_manager and _ui_manager.phase_display:
		_ui_manager.hide_action_prompt()

	# UI更新
	if _ui_manager and _ui_manager.has_method("update_player_info_panels"):
		_ui_manager.update_player_info_panels()

	_is_selecting = false

## スペルターゲット選択用のタップ選択を開始
func _start_spell_tap_target_selection(targets: Array, target_type: String) -> void:
	if not _ui_manager or not _ui_manager.tap_target_manager:
		return

	# target_type: "player" の場合はタップターゲット選択をスキップ
	if target_type == "player":
		print("[STSH] タップターゲット選択スキップ (type: player - 手札選択UI使用)")
		return

	var ttm = _ui_manager.tap_target_manager
	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return

	ttm.set_current_player(_spell_phase_handler.spell_state.current_player_id)

	# シグナル接続（重複防止）
	if not ttm.target_selected.is_connected(_on_spell_tap_target_selected):
		ttm.target_selected.connect(_on_spell_tap_target_selected)

	# ターゲットからタイルインデックスを抽出
	var valid_tile_indices: Array = []
	for target in targets:
		var tile_index: int = target.get("tile_index", -1)
		if tile_index >= 0 and tile_index not in valid_tile_indices:
			valid_tile_indices.append(tile_index)

	# 選択タイプを決定
	var selection_type = TapTargetManager.SelectionType.CREATURE
	if target_type == "land" or target_type == "empty_land":
		selection_type = TapTargetManager.SelectionType.TILE
	elif target_type == "creature_or_land":
		selection_type = TapTargetManager.SelectionType.CREATURE_OR_TILE

	ttm.start_selection(
		valid_tile_indices,
		selection_type,
		"SpellPhaseHandler"
	)

	print("[STSH] タップターゲット選択開始: %d件 (type: %s)" % [valid_tile_indices.size(), target_type])

## スペルターゲット選択を終了
func _end_spell_tap_target_selection() -> void:
	if not _ui_manager or not _ui_manager.tap_target_manager:
		return

	var ttm = _ui_manager.tap_target_manager

	# シグナル切断
	if ttm.target_selected.is_connected(_on_spell_tap_target_selected):
		ttm.target_selected.disconnect(_on_spell_tap_target_selected)

	ttm.end_selection()
	print("[STSH] タップターゲット選択終了")

## チュートリアルのターゲット制限をチェック
func _check_tutorial_target_allowed(tile_index: int) -> bool:
	# TutorialManagerを取得（game_3d参照経由）
	if not _game_3d_ref:
		return true
	if not "tutorial_manager" in _game_3d_ref:
		return true  # チュートリアルなし = 制限なし

	var tutorial_manager = _game_3d_ref.tutorial_manager
	if not tutorial_manager or not tutorial_manager.is_active:
		return true  # チュートリアル非アクティブ = 制限なし

	return tutorial_manager.is_target_tile_allowed(tile_index)

## チュートリアルのプレイヤーターゲット制限をチェック
func _check_tutorial_player_target_allowed(player_id: int) -> bool:
	# TutorialManagerを取得（game_3d参照経由）
	if not _game_3d_ref:
		return true
	if not "tutorial_manager" in _game_3d_ref:
		return true  # チュートリアルなし = 制限なし

	var tutorial_manager = _game_3d_ref.tutorial_manager
	if not tutorial_manager or not tutorial_manager.is_active:
		return true  # チュートリアル非アクティブ = 制限なし

	return tutorial_manager.is_player_target_allowed(player_id)

## タップでターゲットが選択された時
func _on_spell_tap_target_selected(tile_index: int, _creature_data: Dictionary) -> void:
	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return

	print("[STSH] タップでタイル選択: %d" % tile_index)

	if _spell_phase_handler.spell_state.current_state != SpellStateHandler.State.SELECTING_TARGET:
		return

	# available_targetsから該当するターゲットを探す
	for i in range(_available_targets.size()):
		var target: Dictionary = _available_targets[i]
		if target.get("tile_index", -1) == tile_index:
			_current_target_index = i
			# UIを更新（確認待ち状態に）
			_update_target_selection()
			# 確認フェーズへ（即座に確定しない）
			# ユーザーがグローバルボタンの「決定」で確定する
			print("[STSH] ターゲット選択: タイル%d - 決定ボタンで確定してください" % tile_index)
			return

	print("[STSH] タップしたタイルは有効なターゲットではない: %d" % tile_index)

## アルカナアーツターゲット選択用のタップ選択を開始
func _start_mystic_tap_target_selection(targets: Array) -> void:
	if not _ui_manager or not _ui_manager.tap_target_manager:
		return

	if not _spell_phase_handler:
		push_error("[STSH] SpellPhaseHandler が初期化されていません")
		return

	var ttm = _ui_manager.tap_target_manager
	ttm.set_current_player(_spell_phase_handler.spell_state.current_player_id)

	# シグナル接続（重複防止）- スペルと同じハンドラを使用
	if not ttm.target_selected.is_connected(_on_spell_tap_target_selected):
		ttm.target_selected.connect(_on_spell_tap_target_selected)

	# ターゲットからタイルインデックスを抽出
	var valid_tile_indices: Array = []
	for target in targets:
		var tile_index: int = target.get("tile_index", -1)
		if tile_index >= 0 and tile_index not in valid_tile_indices:
			valid_tile_indices.append(tile_index)

	ttm.start_selection(
		valid_tile_indices,
		TapTargetManager.SelectionType.CREATURE,
		"SpellMysticArts"
	)

	print("[STSH] アルカナアーツタップターゲット選択開始: %d件" % valid_tile_indices.size())

## 対象選択時のナビゲーション設定
func _setup_target_selection_navigation() -> void:
	print("[STSH-Flow] _setup_target_selection_navigation() 開始")
	print("[STSH-Flow] _ui_manager=%s" % ("valid" if _ui_manager else "NULL"))

	if not _ui_manager:
		return

	print("[STSH-Flow] enable_navigation() 呼び出し開始")
	_ui_manager.enable_navigation(
		func(): _on_target_confirm(),   # 決定
		func(): _on_target_cancel(),    # 戻る
		func(): _on_target_prev(),      # 上
		func(): _on_target_next()       # 下
	)
	print("[STSH-Flow] enable_navigation() 完了")
	print("[STSH-Flow] グローバルボタンハンドラ登録完了")

## ナビゲーションをクリア
func _clear_spell_navigation() -> void:
	if not _ui_manager:
		return

	_ui_manager.disable_navigation()

## 対象選択：決定
func _on_target_confirm() -> void:
	if not _spell_phase_handler:
		return

	if _spell_phase_handler.spell_state.current_state != SpellStateHandler.State.SELECTING_TARGET:
		return
	_confirm_target_selection()

## 対象選択：キャンセル
func _on_target_cancel() -> void:
	if not _spell_phase_handler:
		return

	if _spell_phase_handler.spell_state.current_state != SpellStateHandler.State.SELECTING_TARGET:
		return
	_cancel_target_selection()

## 対象選択：前の対象へ
func _on_target_prev() -> void:
	if not _spell_phase_handler:
		return

	if _spell_phase_handler.spell_state.current_state != SpellStateHandler.State.SELECTING_TARGET:
		return
	if _available_targets.size() <= 1:
		return

	_current_target_index = (_current_target_index - 1 + _available_targets.size()) % _available_targets.size()
	_update_target_selection()

## 対象選択：次の対象へ
func _on_target_next() -> void:
	if not _spell_phase_handler:
		return

	if _spell_phase_handler.spell_state.current_state != SpellStateHandler.State.SELECTING_TARGET:
		return
	if _available_targets.size() <= 1:
		return

	_current_target_index = (_current_target_index + 1) % _available_targets.size()
	_update_target_selection()

## CPUプレイヤーかどうか
func _is_cpu_player(player_id: int) -> bool:
	if not _spell_phase_handler or not _spell_phase_handler.game_flow_manager:
		return false

	var cpu_settings: Array = _spell_phase_handler.game_flow_manager.player_is_cpu

	if DebugSettings.manual_control_all:
		return false  # デバッグモードでは全員手動

	return player_id < cpu_settings.size() and cpu_settings[player_id]

## 選択マーカーを取得（外部アクセス用）
func get_selection_marker() -> MeshInstance3D:
	return _selection_marker

## 選択マーカーを設定（外部アクセス用）
func set_selection_marker(marker: MeshInstance3D) -> void:
	_selection_marker = marker

## 確認マーカー配列を取得（外部アクセス用）
func get_confirmation_markers() -> Array:
	return _confirmation_markers

## 確認マーカーを追加（外部アクセス用）
func add_confirmation_marker(marker: MeshInstance3D) -> void:
	if marker:
		_confirmation_markers.append(marker)

## 確認マーカーをクリア（外部アクセス用）
func clear_confirmation_markers() -> void:
	_confirmation_markers.clear()

## 利用可能な対象リストを取得（外部アクセス用）
func get_available_targets() -> Array:
	return _available_targets

## 利用可能な対象リストを設定（外部アクセス用）
func set_available_targets(targets: Array) -> void:
	_available_targets = targets

## 現在の対象インデックスを取得（外部アクセス用）
func get_current_target_index() -> int:
	return _current_target_index

## 現在の対象インデックスを設定（外部アクセス用）
func set_current_target_index(index: int) -> void:
	if index >= 0 and index < _available_targets.size():
		_current_target_index = index

## 選択中かどうか
func is_selecting() -> bool:
	return _is_selecting
