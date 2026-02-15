## SpellBorrowEffectStrategy - スペル借用効果の戦略実装
## use_hand_spell, use_target_mystic_art (2個)
class_name SpellBorrowEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

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
		_log_error("spell_borrow が初期化されていません（context を確認）")
		return false
		# ★ NEW: コンテキスト内容をダンプ
		print("[SpellBorrowEffectStrategy] === context contents ===")
		for key in context.keys():
			var val = context[key]
			if val == null:
				print("  - %s: null ⚠️" % key)
			elif val is Object and not (val is Dictionary):
				print("  - %s: %s (object)" % [key, val.get_class()])
			else:
				print("  - %s: %s" % [key, typeof(val)])
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認
	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

	# effect_type の有効性確認（2個）
	if effect_type not in ["use_hand_spell", "use_target_mystic_art"]:
		_log_error("無効な effect_type: %s（use_hand_spell/use_target_mystic_art のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> Dictionary:
	var spell_borrow = context.get("spell_borrow")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_borrow:
		_log_error("spell_borrow が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# ★ NEW: effect_message を構築
	var effect_message = ""

	# effect_type に応じて処理を分岐（await - 元のロジックを再現）
	match effect_type:
		"use_hand_spell":
			await spell_borrow.apply_use_hand_spell(current_player_id)
			effect_message = "手札のスペルを使用"

		"use_target_mystic_art":
			await spell_borrow.apply_use_target_mystic_art(target_data, current_player_id)
			effect_message = "対象の神秘術を使用"

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}
