## DownStateEffectStrategy - ダウン状態操作効果の戦略実装
## down_clear, set_down (2個)
class_name DownStateEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	# Level 1: 必須キーの存在確認
	var required = ["effect", "board_system"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["board_system"]
	if not _validate_references(context, refs):
		return false

	# Level 3: board_system の実体確認（直接参照）
	var board_system = context.get("board_system")
	if not board_system:
		_log_error("board_system が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認
	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	# effect_type の有効性確認（2個）
	if effect_type not in ["down_clear", "set_down"]:
		_log_error("無効な effect_type: %s（down_clear/set_down のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> Dictionary:
	var board_system = context.get("board_system")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not board_system:
		_log_error("board_system が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# ★ NEW: effect_message を構築
	var effect_message = ""

	# effect_type に応じて処理を分岐（元のロジックを再現）
	match effect_type:
		"down_clear":
			board_system.clear_down_state_for_player(current_player_id)
			effect_message = "ダウン状態をクリア"

		"set_down":
			var tile_index = target_data.get("tile_index", -1)
			if tile_index >= 0:
				board_system.set_down_state_for_tile(tile_index)
			effect_message = "ダウン状態を設定"

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}
