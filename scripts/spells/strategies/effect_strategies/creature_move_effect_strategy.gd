## CreatureMoveEffectStrategy - クリーチャー移動効果の戦略実装
class_name CreatureMoveEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	# Level 1: 必須キーの存在確認
	var required = ["effect", "target_data", "spell_creature_move", "current_player_id"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_creature_move"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_creature_move の実体確認（直接参照）
	var spell_creature_move = context.get("spell_creature_move")
	if not spell_creature_move:
		_log_error("spell_creature_move が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認
	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	# effect_type の有効性確認
	var valid_types = ["move_to_adjacent_enemy", "move_steps", "move_self", "destroy_and_move"]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（%s のみ対応）" % [effect_type, str(valid_types)])
		return false

	var target_data = context.get("target_data", {})

	# move_steps, move_self, move_to_adjacent_enemy は tile_index チェック（move_self のみ不要）
	if effect_type != "move_self":
		var tile_index = target_data.get("tile_index", -1)
		if tile_index < 0:
			_log_error("ターゲットタイルが選択されていません (tile_index: %d)" % tile_index)
			return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_creature_move = context.get("spell_creature_move")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", -1)

	# null チェック（直接参照）
	if not spell_creature_move:
		_log_error("spell_creature_move が初期化されていません")
		return { "effect_message": "" }

	var effect_type = effect.get("effect_type", "")
	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# SpellCreatureMove に委譲
	var result = await spell_creature_move.apply_effect(effect, target_data, current_player_id)

	# ★ NEW: effect_message を構築
	var effect_message = ""
	match effect_type:
		"move_to_adjacent_enemy":
			effect_message = "敵の隣に移動"
		"move_steps":
			var steps = effect.get("steps", 1)
			effect_message = "%d マス移動" % steps
		"move_self":
			effect_message = "自動で移動"
		"destroy_and_move":
			effect_message = "破壊して移動"
		_:
			effect_message = "クリーチャー移動"

	if result.get("success", false):
		_log("効果実行完了 (成功)")
	else:
		_log_error("効果実行失敗 (reason: %s)" % result.get("reason", "unknown"))

	return {
		"effect_message": effect_message,
		"success": result.get("success", false)
	}
