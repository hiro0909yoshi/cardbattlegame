# SpellConfirmationHandler - スペル発動確認処理を担当
extends Node
class_name SpellConfirmationHandler

## 親ハンドラー（SpellPhaseHandler）への参照
var _spell_phase_handler = null  # SpellPhaseHandler（循環参照回避）

## システム参照
var _ui_manager = null
var _board_system = null
var _player_system = null
var _game_3d_ref = null

## 発動通知UI
var _spell_cast_notification_ui: SpellCastNotificationUI = null

## 確認用UI状態
var _waiting_for_notification_click: bool = false

func _ready() -> void:
	pass

## 初期化（setup() 時に呼ぶ）
func setup(
	spell_phase_handler,  # 型アノテーションなし（循環参照回避）
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

## 発動通知UIを初期化
func initialize_spell_cast_notification_ui() -> void:
	if _spell_cast_notification_ui:
		return

	_spell_cast_notification_ui = SpellCastNotificationUI.new()
	_spell_cast_notification_ui.name = "SpellCastNotificationUI"

	# UIマネージャーの直下に追加（最前面に表示されるように）
	if _ui_manager:
		_ui_manager.add_child(_spell_cast_notification_ui)
	else:
		if _spell_phase_handler:
			_spell_phase_handler.add_child(_spell_cast_notification_ui)

## スペル/アルカナアーツ発動通知を表示（クリック待ち）
## NOTE: async 関数（呼び出し側で await する必要がある）
func show_spell_cast_notification(caster_name: String, target_data: Dictionary, spell_or_mystic: Dictionary, is_mystic: bool = false):
	if not _spell_cast_notification_ui:
		return

	# 効果名を取得
	var effect_name: String
	if is_mystic:
		effect_name = SpellCastNotificationUI.get_mystic_art_display_name(spell_or_mystic)
	else:
		effect_name = SpellCastNotificationUI.get_effect_display_name(spell_or_mystic)

	# 対象名を取得
	var target_name = SpellCastNotificationUI.get_target_display_name(target_data, _board_system, _player_system)

	# 通知を表示してクリック待ち
	_spell_cast_notification_ui.show_spell_cast_and_wait(caster_name, target_name, effect_name)
	await _spell_cast_notification_ui.click_confirmed

## 発動通知UIを取得
func get_spell_cast_notification_ui() -> SpellCastNotificationUI:
	return _spell_cast_notification_ui

## 発動通知UIをクリア
func clear_spell_cast_notification() -> void:
	if _spell_cast_notification_ui and _spell_cast_notification_ui.is_visible():
		_spell_cast_notification_ui.hide()
		_waiting_for_notification_click = false
