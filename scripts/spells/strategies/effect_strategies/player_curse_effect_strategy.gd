## PlayerCurseEffectStrategy - プレイヤー呪い効果の戦略実装
## player_curse (1個)
class_name PlayerCurseEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_curse"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_curse"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_curse の実体確認（直接参照）
	var spell_curse = context.get("spell_curse")
	if not spell_curse:
		_log_error("spell_curse が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false


	if effect_type != "player_curse":
		_log_error("無効な effect_type: %s（player_curse のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: player_curse)")
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_curse = context.get("spell_curse")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})

	# null チェック（直接参照）
	if not spell_curse:
		_log_error("spell_curse が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: player_curse)")

	# 元のロジック (spell_effect_executor.gd Line 182-203) を再現
	var curse_type = effect.get("curse_type", "")
	var duration = effect.get("duration", -1)
	var curse_name = effect.get("name", "呪い")
	var params = {
		"name": curse_name,
		"description": effect.get("description", "")
	}

	# 追加パラメータをコピー
	for key in ["ignore_item_restriction", "ignore_summon_condition", "spell_protection"]:
		if effect.has(key):
			params[key] = effect.get(key)

	# all_players の場合は全プレイヤーに呪いをかける
	if effect.get("all_players", false) or target_data.get("type") == "all_players":
		var player_count = handler.player_system.players.size() if handler and handler.player_system else 2
		var current_player_id = handler.spell_state.current_player_id if (handler and handler.spell_state) else 0
		for pid in range(player_count):
			spell_curse.curse_player(pid, curse_type, duration, params, current_player_id)
	else:
		var current_player_id = handler.spell_state.current_player_id if (handler and handler.spell_state) else 0
		var target_player_id = target_data.get("player_id", current_player_id)
		spell_curse.curse_player(target_player_id, curse_type, duration, params, current_player_id)

	# ★ NEW: effect_message を構築
	var effect_message = "%sをプレイヤーにかけた" % curse_name

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}
