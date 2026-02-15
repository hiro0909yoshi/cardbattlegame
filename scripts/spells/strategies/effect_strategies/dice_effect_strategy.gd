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
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

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
		_log_error("spell_dice が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	# effect_type の有効性確認
	if effect_type not in ["dice_fixed", "dice_range", "dice_multi", "dice_range_magic"]:
		_log_error("無効な effect_type: %s（dice_fixed/dice_range/dice_multi/dice_range_magic のみ対応）" % effect_type)
		return false

	# dice 系スペルはターゲット不要（自分のダイスロールを操作）
	# tile_index = -1 は正常な値なので、チェック不要

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true


## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_dice = context.get("spell_dice")
	var handler = context.get("spell_phase_handler")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")

	# null チェック（直接参照）
	if not spell_dice:
		_log_error("spell_dice が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# spell_dice に委譲
	var current_player_id = handler.spell_state.current_player_id if (handler and handler.spell_state) else 0
	spell_dice.apply_effect_from_parsed(effect, target_data, current_player_id)

	# ★ NEW: effect_message を構築
	var effect_message = ""
	match effect_type:
		"dice_fixed":
			var value = effect.get("value", 0)
			effect_message = "ダイスを%dに固定" % value
		"dice_range":
			var min_val = effect.get("min", 0)
			var max_val = effect.get("max", 6)
			effect_message = "ダイスを%d～%dに設定" % [min_val, max_val]
		"dice_multi":
			var times = effect.get("times", 2)
			effect_message = "ダイスを%d回振る" % times
		"dice_range_magic":
			effect_message = "マジックダイス発動"
		_:
			effect_message = "ダイス効果実行"

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}
