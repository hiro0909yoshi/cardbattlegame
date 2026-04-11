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
	# ★ 第0段階: null チェック
	if not context:
		_log_error("context が null です")
		return false

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
		_log_error("spell_land が初期化されていません（context を確認）")
		return false

	var effect = context.get("effect", {})
	var effect_type = effect.get("effect_type", "")

	# effect_type の有効性確認
	# ★ ENHANCED: effect_type チェック
	if effect_type.is_empty():
		_log_error("effect_type が空です")
		return false

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

	# タイル指定不要な effect_type（プレイヤー指定、全体対象等）
	var tile_optional_types = [
		"find_and_change_highest_level",  # player_id の最高レベルを自動探索
		"conditional_level_change",       # player_id 配下の条件一致タイル
		"align_mismatched_lands",         # 全体対象
	]

	# ターゲットタイルの有効性確認（タイル必須 effect のみ）
	if effect_type not in tile_optional_types and tile_index < 0:
		_log_error("ターゲットタイルが選択されていません (tile_index: %d)" % tile_index)
		return false

	_log("バリデーション成功 (effect_type: %s, tile_index: %d)" % [effect_type, tile_index])
	return true


## 実行（スペル効果の適用）
func execute(context: Dictionary) -> Dictionary:
	var spell_land = context.get("spell_land")
	var effect = context.get("effect", {})
	var target_data = context.get("target_data", {})
	var current_player_id = context.get("current_player_id", -1)
	var effect_type = effect.get("effect_type", "")

	# null チェック（直接参照）
	if not spell_land:
		_log_error("spell_land が初期化されていません")
		return { "effect_message": "" }

	_log("効果実行開始 (effect_type: %s, tile_index: %d)" % [effect_type, target_data.get("tile_index", -1)])

	# ★ 特殊処理: ダウナー/グラウンド系はカメラ移動＋個別コメント表示
	if effect_type == "find_and_change_highest_level":
		return await _execute_find_highest(context, spell_land, effect, target_data)
	elif effect_type == "conditional_level_change":
		return await _execute_conditional_level(context, spell_land, effect, current_player_id)

	# ★ NEW: effect_message を構築
	var effect_message = ""
	match effect_type:
		"change_element":
			var element = effect.get("element", "?")
			effect_message = "属性を%sに変更" % element
		"change_level":
			var amount = effect.get("value", 0)
			if amount > 0:
				effect_message = "土地レベルを%d上げる" % amount
			elif amount < 0:
				effect_message = "土地レベルを%d下げる" % -amount
			else:
				effect_message = "土地レベル変更"
		"set_level":
			var level = effect.get("value", 0)
			effect_message = "土地レベルを%dに設定" % level
		"abandon_land":
			effect_message = "土地を放棄"
		"destroy_creature":
			effect_message = "クリーチャー破壊"
		"change_element_bidirectional":
			effect_message = "属性を相互に変更"
		"change_element_to_dominant":
			effect_message = "最多属性に変更"
		"find_and_change_highest_level":
			effect_message = "最高レベルを変更"
		"conditional_level_change":
			effect_message = "条件付きレベル変更"
		"align_mismatched_lands":
			effect_message = "不一致タイルを整列"
		"self_destruct":
			effect_message = "自滅発動"
		"change_caster_tile_element":
			effect_message = "キャスターのタイル属性変更"
		_:
			effect_message = "土地変更"

	# spell_land に委譲
	# apply_land_effect は (effect, target_data, player_id) の形で呼び出す
	spell_land.apply_land_effect(effect, target_data, current_player_id)

	_log("効果実行完了")

	return {
		"effect_message": effect_message,
		"success": true
	}


## プレイヤー名取得
func _get_player_name(player_system, player_id: int) -> String:
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		return player_system.players[player_id].name
	return "プレイヤー%d" % (player_id + 1)


## 指定タイルにカメラを寄せて、コメントを出してクリック待ち
func _focus_and_comment(context: Dictionary, tile_index: int, message: String) -> void:
	var handler = context.get("spell_phase_handler")
	var executor = context.get("spell_effect_executor")

	if handler and tile_index >= 0:
		TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
		# カメラ移動完了を少し待つ
		if handler.has_method("get_tree"):
			await handler.get_tree().create_timer(0.5).timeout

	if executor and message != "":
		executor.effect_ui_comment_and_wait_requested.emit(message)
		await executor.effect_ui_comment_and_wait_completed


## ダウナー系: 最高レベル土地を1つずつカメラ寄せ→レベル変更→コメント
func _execute_find_highest(context: Dictionary, spell_land, effect: Dictionary, target_data: Dictionary) -> Dictionary:
	var player_system = context.get("player_system")
	var all_players = effect.get("all_players", false)
	var level_change = effect.get("value", -1)

	var target_player_ids: Array[int] = []
	if all_players:
		for pid in range(player_system.players.size()):
			target_player_ids.append(pid)
	else:
		var tpid = target_data.get("player_id", -1)
		if tpid >= 0:
			target_player_ids.append(tpid)

	var success_count = 0
	var action_word = "下げた" if level_change < 0 else "上げた"

	for pid in target_player_ids:
		var highest_tile = spell_land.find_highest_level_land(pid)
		if highest_tile < 0:
			continue
		if not spell_land.change_level(highest_tile, level_change):
			continue
		success_count += 1
		var pname = _get_player_name(player_system, pid)
		var msg = "%sの最高レベルドミニオのレベルを1%s" % [pname, action_word]
		await _focus_and_comment(context, highest_tile, msg)

	return {
		"effect_message": "",
		"success": success_count > 0
	}


## グラウンド系: 条件一致土地を全てカメラ寄せ→レベル変更→コメント
func _execute_conditional_level(context: Dictionary, spell_land, effect: Dictionary, current_player_id: int) -> Dictionary:
	var board_system = context.get("board_system")
	var required_level = effect.get("required_level", 2)
	var required_count = effect.get("required_count", 5)
	var level_change = effect.get("value", 1)

	if not board_system:
		return { "effect_message": "", "success": false }

	# 条件一致タイルを収集
	var matching_tiles: Array[int] = []
	for tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[tile_index]
		if tile.owner_id == current_player_id and tile.level == required_level:
			matching_tiles.append(tile_index)

	# 条件不成立 → 復帰[ブック]
	if matching_tiles.size() < required_count:
		var fail_msg = "条件未達成（レベル%dの土地 %d個 / 必要 %d個）" % [required_level, matching_tiles.size(), required_count]
		var executor = context.get("spell_effect_executor")
		if executor:
			executor.effect_ui_comment_and_wait_requested.emit(fail_msg)
			await executor.effect_ui_comment_and_wait_completed
		return { "effect_message": "", "success": false }

	# 条件成立 → 各タイルを1つずつ処理
	var action_word = "上げた" if level_change > 0 else "下げた"
	var changed_count = 0
	for tile_index in matching_tiles:
		if spell_land.change_level(tile_index, level_change):
			changed_count += 1
			var msg = "土地レベルを1%s" % action_word
			await _focus_and_comment(context, tile_index, msg)

	return {
		"effect_message": "",
		"success": changed_count > 0
	}
