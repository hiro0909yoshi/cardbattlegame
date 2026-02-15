class_name CPUSpellPhaseHandler
extends RefCounted
## CPUのスペルフェーズ処理
##
## SpellPhaseHandlerからCPU専用ロジックを分離
## - スペル/アルカナアーツの使用判断呼び出し
## - CPU用ターゲットデータ構築
## - CPU用効果実行


# ============================================================
# システム参照
# ============================================================

var spell_phase_handler = null  # 親ハンドラー参照
var player_system = null
var board_system = null
var card_system = null
var spell_synthesis: SpellSynthesis = null
var spell_mystic_arts = null
var card_sacrifice_helper = null
var cpu_spell_ai: CPUSpellAI = null
var cpu_mystic_arts_ai: CPUMysticArtsAI = null


# ============================================================
# 初期化
# ============================================================

func initialize(handler) -> void:
	spell_phase_handler = handler
	_sync_references()


func _sync_references() -> void:
	"""親ハンドラーから参照を同期"""
	if not spell_phase_handler:
		return

	player_system = spell_phase_handler.player_system
	board_system = spell_phase_handler.board_system
	card_system = spell_phase_handler.card_system
	if spell_phase_handler.spell_systems:
		spell_synthesis = spell_phase_handler.spell_systems.spell_synthesis
		card_sacrifice_helper = spell_phase_handler.spell_systems.card_sacrifice_helper
	spell_mystic_arts = spell_phase_handler.spell_mystic_arts
	cpu_spell_ai = spell_phase_handler.cpu_spell_ai
	cpu_mystic_arts_ai = spell_phase_handler.cpu_mystic_arts_ai


func set_cpu_spell_ai(ai: CPUSpellAI) -> void:
	cpu_spell_ai = ai


func set_cpu_mystic_arts_ai(ai: CPUMysticArtsAI) -> void:
	cpu_mystic_arts_ai = ai


# ============================================================
# メイン処理
# ============================================================

## CPUのスペルターンを処理
## 戻り値: Dictionary {action: String, decision: Dictionary}
##   action: "spell", "mystic", "pass"
func decide_action(player_id: int) -> Dictionary:
	# 参照を同期
	_sync_references()
	
	# スペル判断
	var spell_decision = {"use": false}
	if cpu_spell_ai:
		spell_decision = cpu_spell_ai.decide_spell(player_id)
	
	# アルカナアーツ判断
	var mystic_decision = {"use": false}
	if cpu_mystic_arts_ai and spell_phase_handler and spell_phase_handler.has_available_mystic_arts(player_id):
		mystic_decision = cpu_mystic_arts_ai.decide_mystic_arts(player_id)
	
	# どちらも使わない場合
	if not spell_decision.use and not mystic_decision.use:
		return {"action": "pass", "decision": {}}
	
	# スコア比較してどちらを使うか決定
	var spell_score = spell_decision.get("score", 0.0)
	var mystic_score = mystic_decision.get("score", 0.0)
	
	if spell_decision.use and spell_score >= mystic_score:
		return {"action": "spell", "decision": spell_decision}
	elif mystic_decision.use:
		return {"action": "mystic", "decision": mystic_decision}
	else:
		return {"action": "pass", "decision": {}}


## CPUスペル実行の準備処理
## 戻り値: Dictionary {success: bool, spell_card: Dictionary, target_data: Dictionary, cost: int}
func prepare_spell_execution(decision: Dictionary, player_id: int) -> Dictionary:
	_sync_references()
	
	var spell_card = decision.get("spell", {})
	var target = decision.get("target", {})
	var sacrifice_card = decision.get("sacrifice_card", {})
	var should_synthesize = decision.get("should_synthesize", false)
	
	if spell_card.is_empty():
		return {"success": false}
	
	print("[CPU] スペル使用: %s" % spell_card.get("name", "?"))
	
	# コスト取得
	var cost = _get_spell_cost(spell_card)
	
	# カード犠牲処理
	var is_synthesized = false
	if not sacrifice_card.is_empty():
		print("[CPU] カード犠牲: %s" % sacrifice_card.get("name", "?"))
		
		# 合成条件判定
		if should_synthesize and spell_synthesis:
			is_synthesized = spell_synthesis.check_condition(spell_card, sacrifice_card)
			if is_synthesized:
				print("[CPU] 合成成立: %s" % spell_card.get("name", "?"))
		
		# カードを破棄
		_consume_sacrifice_card(player_id, sacrifice_card)
	
	# 合成成立時はeffect_parsedを書き換え
	if is_synthesized and spell_synthesis:
		var parsed = spell_synthesis.apply_overrides(spell_card, true)
		spell_card["effect_parsed"] = parsed
		spell_card["is_synthesized"] = true
	
	# ターゲットデータを構築
	var target_data = build_target_data(spell_card, target if target != null else {}, player_id)
	
	return {
		"success": true,
		"spell_card": spell_card,
		"target_data": target_data,
		"cost": cost,
		"target": target if target != null else {}
	}


## CPUアルカナアーツ実行の準備処理
## 戻り値: Dictionary {success: bool, mystic: Dictionary, mystic_data: Dictionary, creature_info: Dictionary, target_data: Dictionary, cost: int}
func prepare_mystic_execution(decision: Dictionary, player_id: int) -> Dictionary:
	_sync_references()
	
	var creature_tile = decision.get("creature_tile", -1)
	var mystic = decision.get("mystic", {})
	var mystic_data = decision.get("mystic_data", {})
	var target = decision.get("target", {})
	
	if creature_tile < 0 or mystic.is_empty():
		return {"success": false}
	
	# ダウン状態チェック（決定後に状態が変わっている可能性があるため再チェック）
	if _is_tile_down(creature_tile):
		print("[CPU] アルカナアーツ使用失敗: タイル%dはダウン中" % creature_tile)
		return {"success": false}
	
	print("[CPU] アルカナアーツ使用: %s (タイル%d)" % [mystic_data.get("name", "?"), creature_tile])
	
	# コスト取得
	var cost = mystic.get("cost", 0)
	
	# クリーチャー情報を構築
	var tile = board_system.get_tile_data(creature_tile) if board_system else {}
	var creature_info = {
		"tile_index": creature_tile,
		"creature_data": tile.get("creature", tile.get("placed_creature", {})) if tile else {}
	}
	
	# ターゲットデータを構築
	var target_data = build_target_data(mystic_data, target, player_id)
	
	return {
		"success": true,
		"mystic": mystic,
		"mystic_data": mystic_data,
		"creature_info": creature_info,
		"target_data": target_data,
		"cost": cost,
		"target": target
	}


## CPUターゲットデータを構築
func build_target_data(spell_or_mystic: Dictionary, target: Dictionary, player_id: int) -> Dictionary:
	var effect_parsed = spell_or_mystic.get("effect_parsed", {})
	var target_type = effect_parsed.get("target_type", "")
	
	# ターゲットタイプに応じてデータを構築
	match target.get("type", ""):
		"self":
			return {"type": "player", "player_id": player_id}
		"player":
			return {"type": "player", "player_id": target.get("player_id", player_id)}
		"gate", "unvisited_gate":
			# リミッション用: ゲートターゲット
			return {
				"type": "gate",
				"tile_index": target.get("tile_index", -1),
				"gate_key": target.get("gate_key", target.get("checkpoint", ""))
			}
		"land":
			var tile_index = target.get("tile_index", -1)
			if tile_index >= 0 and board_system:
				var tile = board_system.get_tile_data(tile_index)
				if tile:
					return {"type": "land", "tile_index": tile_index, "tile_data": tile}
			return {"type": "none"}
		_:
			# クリーチャーターゲット
			if target.has("tile_index"):
				var tile_index = target.get("tile_index", -1)
				if tile_index >= 0 and board_system:
					var tile = board_system.get_tile_data(tile_index)
					if tile:
						var result = {
							"type": "creature",
							"tile_index": tile_index,
							"creature_data": target.get("creature", tile.get("creature", tile.get("placed_creature", {})))
						}
						# CPUが選んだ移動先があれば追加（アウトレイジ等用）
						if target.has("enemy_tile_index"):
							result["enemy_tile_index"] = target.get("enemy_tile_index")
						return result
	
	# デフォルト: セルフまたはなし
	if target_type == "self" or target_type.is_empty() or target_type == "none":
		return {"type": "player", "player_id": player_id}
	
	return {"type": "none"}


## CPU対象選択（ターゲットリストから最適なものを選択）
func select_best_target(targets: Array, spell_card: Dictionary, player_id: int) -> Dictionary:
	if targets.is_empty():
		return {}
	
	# デフォルトは最初の対象
	var best_target = targets[0]
	
	# CPUSpellTargetSelectorで最適な対象を選択
	if cpu_spell_ai and cpu_spell_ai.target_selector:
		var selector = cpu_spell_ai.target_selector
		if selector.has_method("select_best_target_from_list"):
			var selected = selector.select_best_target_from_list(targets, spell_card, player_id)
			if selected:
				best_target = selected
	
	print("[CPUSpellPhaseHandler] 対象自動選択: %s" % format_target_for_log(best_target))
	return best_target


# ============================================================
# ヘルパー
# ============================================================

## スペルコストを取得
func _get_spell_cost(spell_card: Dictionary) -> int:
	var cost_data = spell_card.get("cost", {})
	if cost_data is Dictionary:
		return cost_data.get("ep", 0)
	return cost_data if cost_data is int else 0


## 犠牲カードを消費
func _consume_sacrifice_card(player_id: int, sacrifice_card: Dictionary) -> void:
	if card_sacrifice_helper:
		card_sacrifice_helper.consume_card(player_id, sacrifice_card)
	elif card_system:
		# card_sacrifice_helperがない場合の直接破棄
		var hand = card_system.get_all_cards_for_player(player_id)
		for i in range(hand.size()):
			if hand[i].get("id") == sacrifice_card.get("id"):
				card_system.discard_card(player_id, i, "sacrifice")
				break


## 対象をログ用にフォーマット
func format_target_for_log(target: Dictionary) -> String:
	var target_type = target.get("type", "")
	match target_type:
		"creature":
			var creature = target.get("creature", {})
			return "クリーチャー: %s (タイル%d)" % [creature.get("name", "?"), target.get("tile_index", -1)]
		"land":
			return "土地: タイル%d" % target.get("tile_index", -1)
		"player":
			return "プレイヤー%d" % (target.get("player_id", 0) + 1)
		_:
			return str(target)


## タイルがダウン状態かチェック
func _is_tile_down(tile_index: int) -> bool:
	if tile_index < 0:
		return false
	if not board_system:
		return false
	if not board_system.tile_nodes.has(tile_index):
		return false
	var tile_node = board_system.tile_nodes[tile_index]
	if tile_node == null:
		return false
	if not tile_node.has_method("is_down"):
		return false
	return tile_node.is_down()


# ==========================================================
# CPU スペルターン実行フロー全体
# ==========================================================

## CPU スペルターン全体を実行
func execute_cpu_spell_turn(player_id: int) -> void:
	"""
	CPU スペルターン全体を実行

	責務:
	1. 思考時間（CPU固有）
	2. 戦闘ポリシー判定（CPU固有）
	3. スペル/アルカナアーツ判定
	4. 準備処理
	5. コスト支払い
	6. 効果実行
	"""
	# 思考時間
	if spell_phase_handler:
		await spell_phase_handler.get_tree().create_timer(0.5).timeout

	# 戦闘ポリシー判定
	var battle_policy = _get_cpu_battle_policy()
	if battle_policy and not battle_policy.should_use_spell():
		if spell_phase_handler:
			spell_phase_handler.pass_spell(false)
		return

	# アクション判定
	var action_result = decide_action(player_id)
	var action = action_result.get("action", "pass")
	var decision = action_result.get("decision", {})

	match action:
		"spell":
			await _execute_cpu_spell(decision, player_id)
		"mystic":
			await _execute_cpu_mystic(decision, player_id)
		_:
			if spell_phase_handler:
				spell_phase_handler.pass_spell(false)

## CPU スペル実行
func _execute_cpu_spell(decision: Dictionary, player_id: int) -> void:
	"""CPU スペル実行（完全実装）"""
	if not spell_phase_handler or not spell_phase_handler.spell_state:
		return

	# 準備処理
	var prep = prepare_spell_execution(decision, player_id)
	if not prep or not prep.get("success", false):
		spell_phase_handler.pass_spell(false)
		return

	var spell_card = prep.get("spell_card", {})
	var target_data = prep.get("target_data", {})
	var cost = prep.get("cost", 0)
	var target = prep.get("target", {})

	# コスト支払い
	if spell_phase_handler.player_system:
		spell_phase_handler.player_system.add_magic(player_id, -cost)

	# 状態更新
	spell_phase_handler.spell_state.set_spell_card(spell_card)
	spell_phase_handler.spell_state.set_spell_used_this_turn(true)

	# 効果実行（target_type で分岐）
	var parsed = spell_card.get("effect_parsed", {})
	var target_type = parsed.get("target_type", "")

	if target_type == "all_creatures":
		var target_info = parsed.get("target_info", {})
		await spell_phase_handler._execute_spell_on_all_creatures(spell_card, target_info)
	else:
		# 発動通知
		if spell_phase_handler.spell_cast_notification_ui and spell_phase_handler.player_system:
			var caster_name = "CPU"
			if player_id >= 0 and player_id < spell_phase_handler.player_system.players.size():
				caster_name = spell_phase_handler.player_system.players[player_id].name
			await spell_phase_handler.show_spell_cast_notification(caster_name, target, spell_card, false)

		await spell_phase_handler.execute_spell_effect(spell_card, target_data)

## CPU アルカナアーツ実行
func _execute_cpu_mystic(decision: Dictionary, player_id: int) -> void:
	"""CPU アルカナアーツ実行"""
	if not spell_phase_handler or not spell_phase_handler.mystic_arts_handler:
		return

	await spell_phase_handler.mystic_arts_handler._execute_cpu_mystic_arts(decision)

## CPU 戦闘ポリシーを取得
func _get_cpu_battle_policy():
	"""現在のCPUのバトルポリシーを取得"""
	if not spell_phase_handler:
		return null

	if spell_phase_handler.spell_systems and spell_phase_handler.spell_systems.cpu_turn_processor and spell_phase_handler.spell_systems.cpu_turn_processor.cpu_ai_handler:
		return spell_phase_handler.spell_systems.cpu_turn_processor.cpu_ai_handler.battle_policy

	return null
