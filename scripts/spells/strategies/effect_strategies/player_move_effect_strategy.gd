## PlayerMoveEffectStrategy - プレイヤー移動・ワープ効果の戦略実装
class_name PlayerMoveEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	var required = ["effect", "spell_player_move"]
	if not _validate_context_keys(context, required):
		return false

	var refs = ["spell_player_move"]
	if not _validate_references(context, refs):
		return false

	var spell_player_move = context.get("spell_player_move")
	if not spell_player_move:
		_log_error("spell_player_move が初期化されていません（context を確認）")
		# ★ NEW: コンテキスト内容をダンプ
		print("[PlayerMoveEffectStrategy] === context contents ===")
		for key in context.keys():
			var val = context[key]
			if val == null:
				print("  - %s: null ⚠️" % key)
			elif val is Object and not (val is Dictionary):
				print("  - %s: %s (object)" % [key, val.get_class()])
			else:
				print("  - %s: %s" % [key, typeof(val)])
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	var valid_types = [
		"warp_to_nearest_vacant", "warp_to_nearest_gate", "warp_to_target",
		"curse_movement_reverse", "gate_pass", "grant_direction_choice"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（プレイヤー移動系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> Dictionary:
	var spell_player_move = context.get("spell_player_move")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	if not spell_player_move:
		_log_error("spell_player_move が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# ★ NEW: effect_message を初期化
	var effect_message = ""

	# effect_type に応じて処理を分岐（元のロジックを再現）
	match effect_type:
		"warp_to_nearest_vacant":
			var result = spell_player_move.warp_to_nearest_vacant(current_player_id)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))
			effect_message = result.get("message", "空きタイルにワープ")
			if result.get("success", false) and handler and handler.spell_state:
				handler.spell_state.set_skip_dice_phase(true)

		"warp_to_nearest_gate":
			var result = spell_player_move.warp_to_nearest_gate(current_player_id)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))
			effect_message = result.get("message", "ゲートにワープ")
			if result.get("success", false) and handler and handler.spell_state:
				handler.spell_state.set_skip_dice_phase(true)

		"warp_to_target":
			var tile_idx = target_data.get("tile_index", -1)
			var result = spell_player_move.warp_to_target(current_player_id, tile_idx)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))
			effect_message = result.get("message", "指定タイルにワープ")
			if result.get("success", false) and handler and handler.spell_state:
				handler.spell_state.set_skip_dice_phase(true)

		"curse_movement_reverse":
			var duration = effect.get("duration", 1)
			spell_player_move.apply_movement_reverse_curse(duration)
			effect_message = "移動方向を反転"

		"gate_pass":
			var gate_key = target_data.get("gate_key", target_data.get("checkpoint", ""))
			var result = spell_player_move.trigger_gate_pass(current_player_id, gate_key)
			print("[PlayerMoveEffectStrategy] %s" % result.get("message", ""))
			effect_message = result.get("message", "ゲート通過")

		"grant_direction_choice":
			var target_player_id = target_data.get("player_id", current_player_id)
			var duration = effect.get("duration", 1)
			spell_player_move.grant_direction_choice(target_player_id, duration)
			effect_message = "方向選択権付与"

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}
