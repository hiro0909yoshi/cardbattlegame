## TollCurseEffectStrategy - 通行料呪い効果の戦略実装
## toll_share, toll_disable, toll_fixed, toll_multiplier, peace, curse_toll_half (6個)
class_name TollCurseEffectStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_curse_toll"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_curse_toll"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_curse_toll の実体確認（直接参照）
	var spell_curse_toll = context.get("spell_curse_toll")
	if not spell_curse_toll:
		_log_error("spell_curse_toll が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（6個）
	var valid_types = ["toll_share", "toll_disable", "toll_fixed", "toll_multiplier", "peace", "curse_toll_half"]
	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（toll_curse 系のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> void:
	var spell_curse_toll = context.get("spell_curse_toll")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})

	# null チェック（直接参照）
	if not spell_curse_toll:
		_log_error("spell_curse_toll が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect.get("effect_type", ""))

	# 元のロジック (spell_effect_executor.gd Line 176-180) を再現
	var tile_index = target_data.get("tile_index", -1)
	var target_player_id = target_data.get("player_id", -1)
	var current_player_id = handler.spell_state.current_player_id if (handler and handler.spell_state) else 0
	spell_curse_toll.apply_curse_from_effect(effect, tile_index, target_player_id, current_player_id)

	_log("効果実行完了")
