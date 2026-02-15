## CreaturePlaceEffectStrategy - クリーチャー配置効果の戦略実装
## place_creature (1個)
class_name CreaturePlaceEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_creature_place", "board_system", "player_system"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_creature_place", "board_system", "player_system"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_creature_place の実体確認（直接参照）
	var spell_creature_place = context.get("spell_creature_place")
	if not spell_creature_place:
		_log_error("spell_creature_place が初期化されていません（context を確認）")
		return false
		# ★ NEW: コンテキスト内容をダンプ
		print("[CreaturePlaceEffectStrategy] === context contents ===")
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

	# effect_type の有効性確認（1個）
	if effect_type != "place_creature":
		_log_error("無効な effect_type: %s（place_creature のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> Dictionary:
	var spell_creature_place = context.get("spell_creature_place")
	var board_system = context.get("board_system")
	var player_system = context.get("player_system")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_creature_place:
		_log_error("spell_creature_place が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: place_creature)")

	# spell_creature_place に委譲（元のロジックを再現）
	var result = spell_creature_place.apply_place_effect(
		effect, target_data, current_player_id, board_system, player_system
	)

	# ★ NEW: effect_message を構築
	var effect_message = "クリーチャー配置"

	if not result.get("success", false):
		_log("クリーチャー配置失敗")

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": result.get("success", false)
	}
