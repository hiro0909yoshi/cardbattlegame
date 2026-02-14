## LandChangeEffectStrategy - 土地変更効果の戦略実装
class_name LandChangeEffectStrategy
extends SpellStrategy

## 土地操作系の Strategy
##
## 担当 effect_type:
## - change_element: 属性変更
## - change_level: レベル変更（増減）
## - set_level: レベル設定
## - abandon_land: 土地放棄
## - destroy_creature: クリーチャー破壊
## - change_element_bidirectional: 相互属性変更
## - change_element_to_dominant: 最多属性に変更
## - find_and_change_highest_level: 最高レベルを変更
## - conditional_level_change: 条件付きレベル変更
## - align_mismatched_lands: 不一致タイルを整列
## - self_destruct: 自滅
## - change_caster_tile_element: キャスターのタイル属性変更


## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["effect", "target_data", "spell_land"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["spell_land"]
	if not _validate_references(context, refs):
		return false

	# Level 3: spell_land の実体確認（直接参照）
	var spell_land = context.get("spell_land")
	if not spell_land:
		_log_error("spell_land が初期化されていません")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認
	var valid_types = [
		"change_element",
		"change_level",
		"set_level",
		"abandon_land",
		"destroy_creature",
		"change_element_bidirectional",
		"change_element_to_dominant",
		"find_and_change_highest_level",
		"conditional_level_change",
		"align_mismatched_lands",
		"self_destruct",
		"change_caster_tile_element"
	]

	if effect_type not in valid_types:
		_log_error("無効な effect_type: %s（%s のみ対応）" % [effect_type, ", ".join(valid_types)])
		return false

	var target_data = context.get("target_data", {})
	var tile_index = target_data.get("tile_index", -1)

	# ターゲットタイルの有効性確認
	if tile_index < 0:
		_log_error("ターゲットタイルが選択されていません (tile_index: %d)" % tile_index)
		return false

	_log("バリデーション成功 (effect_type: %s, tile_index: %d)" % [effect_type, tile_index])
	return true


## 実行（スペル効果の適用）
func execute(context: Dictionary) -> void:
	var spell_land = context.get("spell_land")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", -1)
	var effect_type = effect.get("effect_type", "")

	# null チェック（直接参照）
	if not spell_land:
		_log_error("spell_land が初期化されていません")
		return

	_log("効果実行開始 (effect_type: %s, tile_index: %d)" % [effect_type, target_data.get("tile_index", -1)])

	# spell_land に委譲
	# apply_land_effect は (effect, target_data, player_id) の形で呼び出す
	spell_land.apply_land_effect(effect, target_data, current_player_id)

	_log("効果実行完了")
