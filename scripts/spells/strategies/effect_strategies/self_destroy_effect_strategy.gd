## SelfDestroyEffectStrategy - 自壊効果の戦略実装
## self_destroy (1個)
class_name SelfDestroyEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_magic"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_magic"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_magic の実体確認（直接参照）
	var spell_magic = context.get("spell_magic")
	if not spell_magic:
		_log_error("spell_magic が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（1個）
	if effect_type != "self_destroy":
		_log_error("無効な effect_type: %s（self_destroy のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_magic = context.get("spell_magic")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})

	# null チェック（直接参照）
	if not spell_magic:
		_log_error("spell_magic が初期化されていません")
		return

	_log("効果実行開始 (effect_type: self_destroy)")

	# tile_index の決定（caster_tile_index または tile_index - 元のロジックを再現）
	var tile_index = target_data.get("caster_tile_index", target_data.get("tile_index", -1))
	var clear_land = effect.get("clear_land", true)

	# spell_magic に委譲
	spell_magic.apply_self_destroy(tile_index, clear_land)

	_log("効果実行完了")
