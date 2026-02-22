## PurifyEffectStrategy - 呪い除去効果の戦略実装
class_name PurifyEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	var required = ["effect"]
	if not _validate_context_keys(context, required):
		return false

	var spell_phase_handler = context.get("spell_phase_handler")
	if not spell_phase_handler or not (spell_phase_handler.spell_systems and spell_phase_handler.spell_systems.spell_purify):
		_log_error("spell_purify が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	var valid_types = [
		"purify_all", "remove_creature_curse", "remove_world_curse", "remove_all_player_curses"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（呪い除去系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> Dictionary:
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	if not handler or not (handler.spell_systems and handler.spell_systems.spell_purify):
		_log_error("spell_purify が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# ★ NEW: effect_message を構築
	var effect_message = ""

	# effect_type に応じて処理を分岐（元のロジックを再現）
	var spell_purify = handler.spell_systems.spell_purify
	match effect_type:
		"purify_all":
			var result = spell_purify.purify_all(current_player_id)
			# UI メッセージ表示（await）
			var message_service = null
			if handler.spell_ui_manager:
				message_service = handler.spell_ui_manager.message_service
			if message_service:
				var type_count = result.removed_types.size()
				var message = "%d種類の呪いを消去 %d蓄魔" % [type_count, result.ep_gained]
				await message_service.show_comment_and_wait(message)
				effect_message = message
			else:
				effect_message = "全ての呪いを消去"

		"remove_creature_curse":
			var tile_index = target_data.get("tile_index", -1)
			spell_purify.remove_creature_curse(tile_index)
			effect_message = "クリーチャー呪いを消去"

		"remove_world_curse":
			spell_purify.remove_world_curse()
			effect_message = "ワールド呪いを消去"

		"remove_all_player_curses":
			spell_purify.remove_all_player_curses()
			effect_message = "プレイヤー呪いを全て消去"

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}
