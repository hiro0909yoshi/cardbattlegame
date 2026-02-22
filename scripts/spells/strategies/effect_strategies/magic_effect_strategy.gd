## MagicEffectStrategy - EP/Magic 操作効果の戦略実装
## drain_magic, drain_magic_conditional, drain_magic_by_land_count, drain_magic_by_lap_diff
## gain_magic, gain_magic_by_rank, gain_magic_by_lap, gain_magic_from_destroyed_count
## gain_magic_from_spell_cost, balance_all_magic, gain_magic_from_land_chain
## mhp_to_magic, drain_magic_by_spell_count
class_name MagicEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_phase_handler", "spell_magic"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_phase_handler", "spell_magic"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_magic の実体確認（直接参照）
	var spell_magic = context.get("spell_magic")
	if not spell_magic:
		_log_error("spell_magic が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	# effect_type の有効性確認（13個）
	var valid_types = [
		"drain_magic", "drain_magic_conditional", "drain_magic_by_land_count", "drain_magic_by_lap_diff",
		"gain_magic", "gain_magic_by_rank", "gain_magic_by_lap", "gain_magic_from_destroyed_count",
		"gain_magic_from_spell_cost", "balance_all_magic", "gain_magic_from_land_chain",
		"mhp_to_magic", "drain_magic_by_spell_count"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（EP/Magic 操作系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_magic = context.get("spell_magic")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_magic:
		_log_error("spell_magic が初期化されていません")
		return { "effect_message": "" }

	if not handler:
		_log_error("spell_phase_handler が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)
	print("[MagicEffectStrategy] execute(): effect_type=%s, player_id=%d" % [effect_type, current_player_id])

	# context 構築（元のロジックを再現）
	var magic_context = {
		"rank": handler.get_player_ranking(current_player_id),
		"from_player_id": target_data.get("player_id", -1),
		"tile_index": target_data.get("tile_index", -1),
		"card_system": handler.card_system if handler else null
	}

	# spell_magic に委譲（await 必須）
	print("[MagicEffectStrategy] spell_magic.apply_effect() 呼び出し")
	var result = await spell_magic.apply_effect(effect, current_player_id, magic_context)
	print("[MagicEffectStrategy] spell_magic.apply_effect() 完了")

	# ★ NEW: effect_message を構築
	var effect_message = ""
	match effect_type:
		"drain_magic":
			effect_message = "EP%d獲得！" % effect.get("amount", 0)
		"drain_magic_conditional":
			effect_message = "条件付きドレイン発動"
		"drain_magic_by_land_count":
			effect_message = "土地数でドレイン"
		"drain_magic_by_lap_diff":
			effect_message = "周回差でドレイン"
		"gain_magic":
			effect_message = "EP%d獲得！" % effect.get("amount", 0)
		"gain_magic_by_rank":
			effect_message = "順位で蓄魔"
		"gain_magic_by_lap":
			effect_message = "周回ボーナス蓄魔"
		"gain_magic_from_destroyed_count":
			effect_message = "破壊数で蓄魔"
		"gain_magic_from_spell_cost":
			effect_message = "スペルコストで蓄魔"
		"balance_all_magic":
			effect_message = "EP平均化発動"
		"gain_magic_from_land_chain":
			effect_message = "土地チェーンで蓄魔"
		"mhp_to_magic":
			effect_message = "最大HPから蓄魔"
		"drain_magic_by_spell_count":
			effect_message = "スペル数でドレイン"
		_:
			effect_message = "魔法効果実行"

	# next_effect がある場合は処理（spell_magic は内部で next_effect を返す場合がある）
	if result.has("next_effect") and not result.get("next_effect", {}).is_empty():
		# フォールバック: SpellEffectExecutor に再帰的に処理を依頼する必要がある
		# ここでは spell_effect_executor への参照が必要
		var spell_effect_executor = context.get("spell_effect_executor")
		if spell_effect_executor:
			await spell_effect_executor.apply_single_effect(result["next_effect"], target_data)
		else:
			_log("next_effect を検出したが spell_effect_executor が未設定")

	_log("効果実行完了")
	print("[MagicEffectStrategy] execute() 完了")

	return {
		"effect_message": effect_message,
		"success": result.get("success", true)
	}
