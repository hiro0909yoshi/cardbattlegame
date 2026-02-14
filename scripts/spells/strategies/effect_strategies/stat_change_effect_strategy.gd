## StatChangeEffectStrategy - ステータス増減効果の戦略実装
class_name StatChangeEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	var required = ["effect", "spell_curse_stat"]
	if not _validate_context_keys(context, required):
		return false

	var refs = ["spell_curse_stat"]
	if not _validate_references(context, refs):
		return false

	var spell_curse_stat = context.get("spell_curse_stat")
	if not spell_curse_stat:
		_log_error("spell_curse_stat が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	var valid_types = [
		"permanent_hp_change", "permanent_ap_change", "conditional_ap_change", "secret_tiny_army"
	]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（ステータス増減系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_curse_stat = context.get("spell_curse_stat")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", 0)

	if not spell_curse_stat:
		_log_error("spell_curse_stat が初期化されていません")
		return

	if not handler:
		_log_error("spell_phase_handler が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect.get("effect_type", ""))

	# spell_curse_stat に委譲（元のロジックを再現）
	# 注意: spell_curse_stat.apply_effect() には handler, effect, target_data, current_player_id, selected_spell_card を渡す
	spell_curse_stat.apply_effect(handler, effect, target_data, current_player_id, handler.selected_spell_card)

	_log("効果実行完了")
