## SpellBorrowEffectStrategy - スペル借用効果の戦略実装
## use_hand_spell, use_target_mystic_art (2個)
class_name SpellBorrowEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_borrow"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_borrow"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_borrow の実体確認（直接参照）
	var spell_borrow = context.get("spell_borrow")
	if not spell_borrow:
		_log_error("spell_borrow が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（2個）
	if effect_type not in ["use_hand_spell", "use_target_mystic_art"]:
		_log_error("無効な effect_type: %s（use_hand_spell/use_target_mystic_art のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_borrow = context.get("spell_borrow")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_borrow:
		_log_error("spell_borrow が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# effect_type に応じて処理を分岐（await - 元のロジックを再現）
	match effect_type:
		"use_hand_spell":
			await spell_borrow.apply_use_hand_spell(current_player_id)

		"use_target_mystic_art":
			await spell_borrow.apply_use_target_mystic_art(target_data, current_player_id)

	_log("効果実行完了")
