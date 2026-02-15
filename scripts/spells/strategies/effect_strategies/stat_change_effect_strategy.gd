## StatChangeEffectStrategy - ステータス増減効果の戦略実装
class_name StatChangeEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	var required = ["effect", "spell_curse_stat"]
	if not _validate_context_keys(context, required):
		return false

	var refs = ["spell_curse_stat"]
	if not _validate_references(context, refs):
		return false

	var spell_curse_stat = context.get("spell_curse_stat")
	if not spell_curse_stat:
		_log_error("spell_curse_stat が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	var valid_types = [
		"permanent_hp_change", "permanent_ap_change", "conditional_ap_change", "secret_tiny_army"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（ステータス増減系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> Dictionary:
	var spell_curse_stat = context.get("spell_curse_stat")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	if not spell_curse_stat:
		_log_error("spell_curse_stat が初期化されていません")
		return { "effect_message": "" }

	if not handler:
		_log_error("spell_phase_handler が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# spell_curse_stat に委譲（元のロジックを再現）
	# 注意: spell_curse_stat.apply_effect() には handler, effect, target_data, current_player_id, selected_spell_card を渡す
	var selected_spell_card = handler.spell_state.selected_spell_card if (handler and handler.spell_state) else {}
	spell_curse_stat.apply_effect(handler, effect, target_data, current_player_id, selected_spell_card)

	# ★ NEW: effect_message を構築
	var effect_message = ""
	match effect_type:
		"permanent_hp_change":
			var amount = effect.get("amount", 0)
			if amount > 0:
				effect_message = "最大HP+%d" % amount
			else:
				effect_message = "最大HP%d" % amount
		"permanent_ap_change":
			var amount = effect.get("amount", 0)
			if amount > 0:
				effect_message = "AP+%d" % amount
			else:
				effect_message = "AP%d" % amount
		"conditional_ap_change":
			effect_message = "条件付きAP変更"
		"secret_tiny_army":
			effect_message = "秘密の小軍隊発動"
		_:
			effect_message = "ステータス変更"

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}
