## CreaturePlaceEffectStrategy - クリーチャー配置効果の戦略実装
## place_creature (1個)
class_name CreaturePlaceEffectStrategy
extends SpellStrategy

func validate(context: Dictionary) -> bool:
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
		_log_error("spell_creature_place が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認（1個）
	if effect_type != "place_creature":
		_log_error("無効な effect_type: %s（place_creature のみ対応）" % effect_type)
		return false

	_log("バリデーション成功 (effect_type: %s)" % effect_type)
	return true

func execute(context: Dictionary) -> void:
	var spell_creature_place = context.get("spell_creature_place")
	var board_system = context.get("board_system")
	var player_system = context.get("player_system")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", 0)

	# null チェック（直接参照）
	if not spell_creature_place:
		_log_error("spell_creature_place が初期化されていません")
		return

	_log("効果実行開始 (effect_type: place_creature)")

	# spell_creature_place に委譲（元のロジックを再現）
	var result = spell_creature_place.apply_place_effect(
		effect, target_data, current_player_id, board_system, player_system
	)

	if not result.get("success", false):
		_log("クリーチャー配置失敗")

	_log("効果実行完了")
