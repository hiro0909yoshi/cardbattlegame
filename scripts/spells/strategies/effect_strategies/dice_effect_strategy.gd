## DiceEffectStrategy - ダイス効果の戦略実装
class_name DiceEffectStrategy
extends SpellStrategy

## ダイス効果の Strategy
##
## 担当 effect_type:
## - dice_fixed: 固定ダイス
## - dice_range: 範囲ダイス
## - dice_multi: 複数ダイス
## - dice_range_magic: 範囲ダイス（マジック）


## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "target_data", "spell_dice"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_dice"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_dice の実体確認（直接参照）
	var spell_dice = context.get("spell_dice")
	if not spell_dice:
		_log_error("spell_dice が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認
	if effect_type not in ["dice_fixed", "dice_range", "dice_multi", "dice_range_magic"]:
		_log_error("無効な effect_type: %s（dice_fixed/dice_range/dice_multi/dice_range_magic のみ対応）" % effect_type)
		return false

	# dice 系スペルはターゲット不要（自分のダイスロールを操作）
	# tile_index = -1 は正常な値なので、チェック不要

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true


## 実行（スペル効果の適用）
func execute(context: Dictionary) -> void:
	var spell_dice = context.get("spell_dice")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")

	# null チェック（直接参照）
	if not spell_dice:
		_log_error("spell_dice が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# spell_dice に委譲
	var current_player_id = handler.spell_state.current_player_id if (handler and handler.spell_state) else 0
	spell_dice.apply_effect_from_parsed(effect, target_data, current_player_id)

	_log("効果実行完了")
