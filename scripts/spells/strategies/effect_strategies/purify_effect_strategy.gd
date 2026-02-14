## PurifyEffectStrategy - 呪い除去効果の戦略実装
class_name PurifyEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	var required = ["effect"]
	if not _validate_context_keys(context, required):
		return false

	var spell_phase_handler = context.get("spell_phase_handler")
	if not spell_phase_handler or not spell_phase_handler.spell_purify:
		_log_error("spell_purify が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	var valid_types = [
		"purify_all", "remove_creature_curse", "remove_world_curse", "remove_all_player_curses"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（呪い除去系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	if not handler or not handler.spell_purify:
		_log_error("spell_purify が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# effect_type に応じて処理を分岐（元のロジックを再現）
	match effect_type:
		"purify_all":
			var result = handler.spell_purify.purify_all(current_player_id)
			# UI メッセージ表示（await）
			if handler.ui_manager and handler.ui_manager.global_comment_ui:
				var type_count = result.removed_types.size()
				var message = "%d種類の呪いを消去 %dEP獲得" % [type_count, result.ep_gained]
				await handler.ui_manager.show_comment_and_wait(message)

		"remove_creature_curse":
			var tile_index = target_data.get("tile_index", -1)
			handler.spell_purify.remove_creature_curse(tile_index)

		"remove_world_curse":
			handler.spell_purify.remove_world_curse()

		"remove_all_player_curses":
			handler.spell_purify.remove_all_player_curses()

	_log("効果実行完了")
