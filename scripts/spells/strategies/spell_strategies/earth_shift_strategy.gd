## EarthShiftStrategy - アースシフト（土地属性変更）スペルの戦略実装
class_name EarthShiftStrategy
extends SpellStrategy

## バリデーション（実行前の条件チェック）
func validate(context: Dictionary) -> bool:
	# Level 1: 必須キーの存在確認
	var required = ["spell_card", "current_player_id", "board_system", "spell_phase_handler"]
	if not _validate_context_keys(context, required):
		return false

	# Level 2: 参照実体のnull確認
	var refs = ["board_system", "spell_phase_handler"]
	if not _validate_references(context, refs):
		return false

	# Level 3: スペル固有の条件確認
	var target_data = context.get("target_data", {})
	var tile_index = target_data.get("tile_index", -1)
	var board_system = context.get("board_system")

	# ターゲットタイルの有効性確認
	if tile_index < 0:
		_log_error("ターゲットタイルが選択されていません（tile_index: %d）" % tile_index)
		return false

	if not board_system.tile_nodes.has(tile_index):
		_log_error("無効なターゲットタイル (tile_index: %d)" % tile_index)
		return false

	# ターゲットタイルが自分のドミニオであることを確認
	var tile_data = board_system.get_tile_data(tile_index)
	if not tile_data:
		_log_error("ターゲットタイルのデータが見つかりません (tile_index: %d)" % tile_index)
		return false

	var target_owner = tile_data.get("owner", -1)
	var current_player_id = context.get("current_player_id", -1)

	if target_owner != current_player_id:
		_log_error("ターゲットが自分のドミニオではありません (owner: %d, current: %d)" % [target_owner, current_player_id])
		return false

	_log("バリデーション成功 (tile_index: %d, element: earth)" % tile_index)
	return true

## 実行（スペル効果の適用）
func execute(context: Dictionary) -> void:
	var spell_phase_handler = context.get("spell_phase_handler")
	var spell_effect_executor = spell_phase_handler.spell_effect_executor if spell_phase_handler else null

	# null チェック
	if not spell_effect_executor:
		_log_error("spell_effect_executor が初期化されていません")
		return

	var spell_card = context.get("spell_card", {})
	var target_data = context.get("target_data", {})

	_log("効果実行開始 (spell: %s)" % spell_card.get("name", "Unknown"))

	# SpellEffectExecutor に委譲
	await spell_effect_executor.execute_spell_effect(spell_card, target_data)

	_log("効果実行完了")
