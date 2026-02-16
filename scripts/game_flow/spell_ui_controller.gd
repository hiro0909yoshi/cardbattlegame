# SpellUIController - スペルフェーズの基本的なUI制御を担当
extends Node
class_name SpellUIController

## 親ハンドラー（SpellPhaseHandler）への参照
var _spell_phase_handler = null  # SpellPhaseHandler（循環参照回避）

## システム参照
var _ui_manager = null
var _board_system = null
var _player_system = null
var _game_3d_ref = null
var _card_system = null

## UI状態
var _spell_phase_ui_manager = null

func _ready() -> void:
	pass

## 初期化（setup() 時に呼ぶ）
func setup(
	spell_phase_handler,  # 型アノテーションなし（循環参照回避）
	ui_manager,
	board_system,
	player_system,
	game_3d_ref,
	card_system = null
) -> void:
	_spell_phase_handler = spell_phase_handler
	_ui_manager = ui_manager
	_board_system = board_system
	_player_system = player_system
	_game_3d_ref = game_3d_ref
	_card_system = card_system

## スペルフェーズUIの更新
func update_spell_phase_ui() -> void:
	# 手札のスペルカード以外をグレーアウト
	if not _ui_manager or not _card_system:
		push_error("[SPUC] ui_manager または card_system が初期化されていません")
		return

	var current_player = _player_system.get_current_player() if _player_system else null
	if not current_player:
		push_error("[SPUC] current_player が取得できません")
		return

	# 手札を取得
	var hand_data = _card_system.get_all_cards_for_player(current_player.id)

	# スペル不可呪いチェック
	var context = _build_spell_context()
	var is_spell_disabled = SpellProtection.is_player_spell_disabled(current_player, context)

	# フィルターモードを設定
	if not _ui_manager:
		push_error("[SPUC] ui_manager が初期化されていません")
		return

	if is_spell_disabled:
		_ui_manager.card_selection_filter = "spell_disabled"
		if _ui_manager.phase_display and _ui_manager.phase_display.has_method("show_toast"):
			_ui_manager.phase_display.show_toast("スペル不可の呪いがかかっています")
	else:
		_ui_manager.card_selection_filter = "spell"
	# 手札表示を更新してグレーアウトを適用
	if _spell_phase_handler and _spell_phase_handler.hand_display:
		_spell_phase_handler.hand_display.update_hand_display(current_player.id)

	# スペル選択UIを表示（人間プレイヤーのみ）
	if not (_spell_phase_handler and _spell_phase_handler.game_flow_manager and _spell_phase_handler.game_flow_manager.is_cpu_player(current_player.id)):
		show_spell_selection_ui(hand_data, current_player.magic_power)

	# ダイスボタンのテキストはそのまま「ダイスを振る」

## スペル選択UIを表示
func show_spell_selection_ui(_hand_data: Array, _available_magic: int) -> void:
	if not _ui_manager or not _ui_manager.card_selection_ui:
		return

	# 現在のプレイヤー情報を取得
	var current_player = _player_system.get_current_player() if _player_system else null
	if not current_player:
		return

	# フィルターを設定してスペル選択UIを表示
	# スペルカードがなくても表示する（全グレイアウトでもカード閲覧を可能にする）
	_ui_manager.card_selection_filter = "spell"
	if _ui_manager.card_selection_ui.has_method("show_selection"):
		_ui_manager.card_selection_ui.show_selection(current_player, "spell")

## カメラを使用者に戻す
func return_camera_to_player() -> void:
	if not _player_system or not _board_system:
		return

	if not _spell_phase_handler or not _spell_phase_handler.spell_state:
		return

	# MovementControllerからプレイヤーの実際の位置を取得
	if _board_system:
		var player_tile_index = _board_system.get_player_tile(_spell_phase_handler.spell_state.current_player_id)

		if _board_system.camera and _board_system.tile_nodes.has(player_tile_index):
			var tile_pos = _board_system.tile_nodes[player_tile_index].global_position

			var new_camera_pos = tile_pos + Vector3(0, 1.0, 0) + GameConstants.CAMERA_OFFSET

			_board_system.camera.position = new_camera_pos
			_board_system.camera.look_at(tile_pos + Vector3(0, 1.0 + GameConstants.CAMERA_LOOK_OFFSET_Y, 0), Vector3.UP)

## SpellPhaseUIManager を初期化
func initialize_spell_phase_ui() -> void:
	if not _spell_phase_ui_manager:
		_spell_phase_ui_manager = SpellPhaseUIManager.new()
		if _spell_phase_handler:
			_spell_phase_handler.add_child(_spell_phase_ui_manager)

		# 参照を設定（spell_phase_ui_managerはSpellAndMysticUI等に使用）
		if _spell_phase_ui_manager:
			_spell_phase_ui_manager.spell_phase_handler_ref = _spell_phase_handler

## スペルフェーズ開始時にボタンを表示
func show_spell_phase_buttons() -> void:
	if not _spell_phase_handler:
		return

	# アルカナアーツボタンは使用可能なクリーチャーがいる場合のみ表示（特殊ボタン使用）
	if _ui_manager and _spell_phase_handler and _spell_phase_handler.spell_state:
		var current_player_id = _spell_phase_handler.spell_state.current_player_id
		if _spell_phase_handler.mystic_arts_handler and _spell_phase_handler.mystic_arts_handler.has_available_mystic_arts(current_player_id):
			_ui_manager.show_mystic_button(func(): _spell_phase_handler.mystic_arts_handler.start_mystic_arts_phase())
	# 「スペルを使わない」ボタンは✓ボタンに置き換えたため表示しない

## スペルフェーズ終了時にボタンを非表示
func hide_spell_phase_buttons() -> void:
	# 特殊ボタンをクリア
	if _ui_manager:
		_ui_manager.hide_mystic_button()

## スペル関連のコンテキストを構築（世界呪い等）
func _build_spell_context() -> Dictionary:
	var context = {}

	if _spell_phase_handler and _spell_phase_handler.game_flow_manager and "game_stats" in _spell_phase_handler.game_flow_manager:
		context["world_curse"] = _spell_phase_handler.game_flow_manager.game_stats.get("world_curse", {})

	return context
