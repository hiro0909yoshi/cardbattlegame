extends Node
class_name SpellCurseStat

# ステータス増減スペル処理
# ドキュメント: docs/design/spells/ステータス増減.md

var spell_curse: SpellCurse
var creature_manager: CreatureManager
var board_system: Node = null
var player_system: Node = null
var card_system: Node = null
var spell_cast_notification_ui: Node = null

func setup(curse: SpellCurse, creature_mgr: CreatureManager):
	spell_curse = curse
	creature_manager = creature_mgr
	print("[SpellCurseStat] 初期化完了")

## システム参照を設定
func set_systems(board: Node, player: Node, card: Node = null) -> void:
	board_system = board
	player_system = player
	card_system = card

## 通知UIを設定
func set_notification_ui(ui: Node) -> void:
	spell_cast_notification_ui = ui

# ========================================
# 統合エントリポイント（SpellPhaseHandlerから呼び出し）
# ========================================

## ステータス増減スペル効果を適用（統合メソッド）
## 戻り値: 処理したかどうか
func apply_effect(handler: Node, effect: Dictionary, target_data: Dictionary, current_player_id: int, selected_spell_card: Dictionary) -> bool:
	var effect_type = effect.get("effect_type", "")
	var tile_index = target_data.get("tile_index", -1)
	
	match effect_type:
		"permanent_hp_change":
			await _apply_permanent_hp_change(handler, tile_index, effect)
			return true
		"permanent_ap_change":
			await _apply_permanent_ap_change(handler, tile_index, effect)
			return true
		"secret_tiny_army":
			await apply_secret_tiny_army(handler, effect, current_player_id, selected_spell_card)
			return true
	
	return false


# ========================================
# 恒久的ステータス変更
# ========================================


## 恒久MHP変更効果を適用（内部用）
func _apply_permanent_hp_change(handler: Node, tile_index: int, effect: Dictionary) -> void:
	if tile_index < 0 or not board_system:
		return
	
	var tile_info = board_system.get_tile_info(tile_index)
	if tile_info.is_empty() or not tile_info.has("creature"):
		return
	
	var creature_data = tile_info["creature"]
	if creature_data.is_empty():
		return
	
	var value = effect.get("value", 0)
	var creature_name = creature_data.get("name", "クリーチャー")
	
	# カメラをターゲットにフォーカス
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	
	# 旧値を保存
	var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
	var old_current_hp = creature_data.get("current_hp", old_mhp)
	
	# MHP変更（current_hpも同時更新）
	EffectManager.apply_max_hp_effect(creature_data, value)
	
	# 新値を取得
	var new_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
	var new_current_hp = creature_data.get("current_hp", new_mhp)
	
	var sign = "+" if value >= 0 else ""
	var notification_text = "%s MHP%s%d\nMHP: %d → %d / HP: %d → %d" % [
		creature_name, sign, value, old_mhp, new_mhp, old_current_hp, new_current_hp
	]
	print("[恒久変更] ", creature_name, " MHP ", sign, value)
	
	await _show_notification_and_wait(notification_text)


## 恒久AP変更効果を適用（内部用）
func _apply_permanent_ap_change(handler: Node, tile_index: int, effect: Dictionary) -> void:
	if tile_index < 0 or not board_system:
		return
	
	var tile_info = board_system.get_tile_info(tile_index)
	if tile_info.is_empty() or not tile_info.has("creature"):
		return
	
	var creature_data = tile_info["creature"]
	if creature_data.is_empty():
		return
	
	var value = effect.get("value", 0)
	var creature_name = creature_data.get("name", "クリーチャー")
	
	# カメラをターゲットにフォーカス
	TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
	
	# AP変更（下限0でクランプ）
	if not creature_data.has("base_up_ap"):
		creature_data["base_up_ap"] = 0
	
	var base_ap = creature_data.get("ap", 0)
	var old_base_up_ap = creature_data.get("base_up_ap", 0)
	var old_total_ap = base_ap + old_base_up_ap
	var new_base_up_ap = old_base_up_ap + value
	
	# 最終APが0未満にならないよう調整
	var new_total_ap = base_ap + new_base_up_ap
	if new_total_ap < 0:
		new_base_up_ap = -base_ap  # 最終APを0に
		new_total_ap = 0
	
	creature_data["base_up_ap"] = new_base_up_ap
	
	var sign = "+" if value >= 0 else ""
	var notification_text = "%s AP%s%d\nAP: %d → %d" % [
		creature_name, sign, value, old_total_ap, new_total_ap
	]
	print("[恒久変更] ", creature_name, " AP ", sign, value, " (合計AP: ", new_total_ap, ")")
	
	await _show_notification_and_wait(notification_text)


## 密命: タイニーアーミー（MHP30以下5体以上でMHP+10、G500）
## 失敗時の通知とカード復帰も含む
func apply_secret_tiny_army(handler: Node, effect: Dictionary, current_player_id: int, selected_spell_card: Dictionary) -> void:
	if not board_system or not player_system:
		return
	
	var mhp_threshold = effect.get("mhp_threshold", 30)
	var required_count = effect.get("required_count", 5)
	var hp_bonus = effect.get("hp_bonus", 10)
	var gold_bonus = effect.get("gold_bonus", 500)
	
	# MHP30以下の自クリーチャーを収集
	var qualifying_creatures: Array[Dictionary] = []
	
	for tile_index in board_system.tile_nodes.keys():
		var tile_info = board_system.get_tile_info(tile_index)
		var tile_owner = tile_info.get("owner", -1)
		
		# 自分の土地のみ
		if tile_owner != current_player_id:
			continue
		
		var creature = tile_info.get("creature", {})
		if creature.is_empty():
			continue
		
		# MHPを計算
		var base_hp = creature.get("hp", 0)
		var base_up_hp = creature.get("base_up_hp", 0)
		var mhp = base_hp + base_up_hp
		
		# MHP閾値以下か
		if mhp <= mhp_threshold:
			qualifying_creatures.append({
				"tile_index": tile_index,
				"creature_data": creature,
				"mhp": mhp
			})
	
	print("[タイニーアーミー] MHP%d以下のクリーチャー: %d体 (必要: %d体)" % [mhp_threshold, qualifying_creatures.size(), required_count])
	
	# 条件判定
	if qualifying_creatures.size() < required_count:
		# 失敗処理
		print("[タイニーアーミー] 条件未達成 - 失敗")
		
		# 失敗通知
		var fail_text = "密命失敗！\nMHP%d以下のクリーチャー: %d体\n（必要: %d体）" % [mhp_threshold, qualifying_creatures.size(), required_count]
		await _show_notification_and_wait(fail_text)
		
		# カードをデッキに戻す
		_return_spell_to_deck(current_player_id, selected_spell_card)
		return
	
	# 成功: 全対象にMHP+10
	print("[タイニーアーミー] 条件達成！ %d体にMHP+%d" % [qualifying_creatures.size(), hp_bonus])
	
	for target in qualifying_creatures:
		var tile_index = target["tile_index"]
		var creature_data = target["creature_data"]
		var creature_name = creature_data.get("name", "クリーチャー")
		
		# カメラをターゲットにフォーカス
		TargetSelectionHelper.focus_camera_on_tile(handler, tile_index)
		
		# 旧値を保存
		var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
		var old_current_hp = creature_data.get("current_hp", old_mhp)
		
		# MHP変更
		EffectManager.apply_max_hp_effect(creature_data, hp_bonus)
		
		# 新値を取得
		var new_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
		var new_current_hp = creature_data.get("current_hp", new_mhp)
		
		var notification_text = "%sのMHPが%d上昇！\nMHP: %d → %d / HP: %d → %d" % [
			creature_name, hp_bonus, old_mhp, new_mhp, old_current_hp, new_current_hp
		]
		
		await _show_notification_and_wait(notification_text)
	
	# G500獲得
	player_system.add_magic(current_player_id, gold_bonus)
	var gold_notification = "G%d獲得！" % gold_bonus
	await _show_notification_and_wait(gold_notification)


## スペルカードをデッキに戻す（復帰[ブック]）
func _return_spell_to_deck(player_id: int, spell_card: Dictionary) -> void:
	if not card_system or spell_card.is_empty():
		return
	
	var card_id = spell_card.get("id", -1)
	var card_name = spell_card.get("name", "?")
	
	# 手札からカードを探して削除
	var hand = card_system.get_all_cards_for_player(player_id)
	for i in range(hand.size()):
		if hand[i].get("id", -1) == card_id:
			# 手札から削除
			hand.remove_at(i)
			# デッキに戻す（IDを追加してシャッフル）
			card_system.player_decks[player_id].append(card_id)
			card_system.player_decks[player_id].shuffle()
			print("[復帰ブック] ", card_name, " をデッキに戻しました")
			break


## 通知表示＋クリック待ち（共通処理）
func _show_notification_and_wait(text: String) -> void:
	if spell_cast_notification_ui:
		spell_cast_notification_ui.show_notification_and_wait(text)
		await spell_cast_notification_ui.click_confirmed


# ========================================
# 呪い付与（SpellPhaseHandlerから呼ばれる）
# ========================================

# 能力値上昇呪いを付与
func apply_stat_boost(tile_index: int, effect: Dictionary):
	var value = effect.get("value", 20)
	var duration = effect.get("duration", -1)
	var curse_name = effect.get("name", "能力値+20")
	
	spell_curse.curse_creature(tile_index, "stat_boost", duration, {
		"name": curse_name,
		"value": value
	})

# 能力値減少呪いを付与
func apply_stat_reduce(tile_index: int, effect: Dictionary):
	var value = effect.get("value", -20)
	var duration = effect.get("duration", -1)
	var curse_name = effect.get("name", "能力値-20")
	
	spell_curse.curse_creature(tile_index, "stat_reduce", duration, {
		"name": curse_name,
		"value": value
	})

# ========================================
# 汎用効果適用（統合版）
# ========================================

## スペル効果から呪いを適用（統合メソッド）
func apply_curse_from_effect(effect: Dictionary, tile_index: int):
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"stat_boost":
			apply_stat_boost(tile_index, effect)
		
		"stat_reduce":
			apply_stat_reduce(tile_index, effect)
		
		_:
			print("[SpellCurseStat] 未対応の効果タイプ: ", effect_type)

# ========================================
# バトル時（BattlePreparationから呼ばれる）
# ========================================

# 呪いをtemporary_effectsに変換
func apply_to_creature_data(tile_index: int):
	var curse = spell_curse.get_creature_curse(tile_index)
	if curse.is_empty():
		return
	
	var creature = creature_manager.get_data_ref(tile_index)
	if creature.is_empty():
		return
	
	var curse_type = curse.get("curse_type", "")
	var params = curse.get("params", {})
	
	match curse_type:
		"stat_boost":
			var value = params.get("value", 20)
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "hp",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "ap",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			print("[呪い変換] stat_boost: HP+", value, ", AP+", value)
		
		"stat_reduce":
			var value = params.get("value", -20)
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "hp",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			creature["temporary_effects"].append({
				"type": "stat_bonus",
				"stat": "ap",
				"value": value,
				"source": "curse",
				"source_name": curse.get("name", "")
			})
			print("[呪い変換] stat_reduce: HP", value, ", AP", value)
