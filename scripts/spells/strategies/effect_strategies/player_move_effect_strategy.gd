## PlayerMoveEffectStrategy - プレイヤー移動・ワープ効果の戦略実装
class_name PlayerMoveEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	var required = ["effect", "spell_player_move"]
	if not _validate_context_keys(context, required):
		return false

	var refs = ["spell_player_move"]
	if not _validate_references(context, refs):
		return false

	var spell_player_move = context.get("spell_player_move")
	if not spell_player_move:
		_log_error("spell_player_move が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	var valid_types = [
		"warp_to_nearest_vacant", "warp_to_nearest_gate", "warp_to_target",
		"curse_movement_reverse", "gate_pass", "grant_direction_choice"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（プレイヤー移動系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_player_move = context.get("spell_player_move")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	if not spell_player_move:
		_log_error("spell_player_move が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# effect_type に応じて処理を分岐（元のロジックを再現）
	match effect_type:
		"warp_to_nearest_vacant":
			var result = spell_player_move.warp_to_nearest_vacant(current_player_id)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))
			if result.get("success", false) and handler:
				handler.skip_dice_phase = true

		"warp_to_nearest_gate":
			var result = spell_player_move.warp_to_nearest_gate(current_player_id)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))
			if result.get("success", false) and handler:
				handler.skip_dice_phase = true

		"warp_to_target":
			var tile_idx = target_data.get("tile_index", -1)
			var result = spell_player_move.warp_to_target(current_player_id, tile_idx)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))
			if result.get("success", false) and handler:
				handler.skip_dice_phase = true

		"curse_movement_reverse":
			var duration = effect.get("duration", 1)
			spell_player_move.apply_movement_reverse_curse(duration)

		"gate_pass":
			var gate_key = target_data.get("gate_key", target_data.get("checkpoint", ""))
			var result = spell_player_move.trigger_gate_pass(current_player_id, gate_key)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))

		"grant_direction_choice":
			var target_player_id = target_data.get("player_id", current_player_id)
			var duration = effect.get("duration", 1)
			spell_player_move.grant_direction_choice(target_player_id, duration)

	_log("効果実行完了")
