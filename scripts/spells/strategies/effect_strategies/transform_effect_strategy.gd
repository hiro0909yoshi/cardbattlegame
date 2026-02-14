## TransformEffectStrategy - クリーチャー変身効果の戦略実装
## transform, discord_transform (2個)
class_name TransformEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "spell_transform"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_transform"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_transform の実体確認（直接参照）
	var spell_transform = context.get("spell_transform")
	if not spell_transform:
		_log_error("spell_transform が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（2個）
	if effect_type not in ["transform", "discord_transform"]:
		_log_error("無効な effect_type: %s（transform/discord_transform のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_transform = context.get("spell_transform")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var effect_type = effect.get("effect_type", "")
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_transform:
		_log_error("spell_transform が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s)" % effect_type)

	# effect_type に応じて処理を分岐（元のロジックを再現）
	match effect_type:
		"transform":
			spell_transform.apply_effect(effect, target_data, current_player_id)

		"discord_transform":
			spell_transform.apply_discord_transform(current_player_id)

	_log("効果実行完了")
