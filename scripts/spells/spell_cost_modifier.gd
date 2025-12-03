class_name SpellCostModifier
extends RefCounted

## コスト操作スペルシステム
## - ライフフォース（2117）: クリーチャー/アイテムG0、スペル無効化で解除
## - ウェイストワールド（2009）: カード使用コスト倍率（世界呪い）

var spell_curse = null
var player_system: PlayerSystem = null
var game_flow_manager = null  # 世界呪い取得用

## セットアップ
func setup(p_spell_curse, p_player_system: PlayerSystem, p_game_flow_manager = null):
	spell_curse = p_spell_curse
	player_system = p_player_system
	game_flow_manager = p_game_flow_manager
	print("[SpellCostModifier] 初期化完了")


# ========================================
# ライフフォース（2117）
# ========================================

## ライフフォース呪い付与
func apply_life_force(target_player_id: int) -> Dictionary:
	if not spell_curse or not player_system:
		return {"success": false, "message": "システム未初期化"}
	
	var params = {
		"name": "生命力",
		"cost_zero_types": ["creature", "item"],
		"nullify_spell": true
	}
	
	spell_curse.curse_player(target_player_id, "life_force", -1, params)
	
	var player_name = _get_player_name(target_player_id)
	print("[ライフフォース] %s に呪い「生命力」を付与" % player_name)
	
	return {"success": true, "message": "%s に生命力を付与" % player_name}


## ライフフォース呪いを持っているかチェック
func has_life_force(player_id: int) -> bool:
	if not player_system or player_id < 0 or player_id >= player_system.players.size():
		return false
	
	var player = player_system.players[player_id]
	var curse = player.curse  # player.curseを直接参照
	return curse.get("curse_type", "") == "life_force"


## スペル使用時の無効化チェック
## 戻り値: { "nullified": bool, "curse_removed": bool, "message": String }
func check_spell_nullify(player_id: int) -> Dictionary:
	if not has_life_force(player_id):
		return {"nullified": false, "curse_removed": false, "message": ""}
	
	# 呪いを解除
	if spell_curse:
		spell_curse.remove_curse_from_player(player_id)
	
	var player_name = _get_player_name(player_id)
	var message = "【生命力】%s のスペルは無効化された！呪いが解除された" % player_name
	print(message)
	
	return {
		"nullified": true,
		"curse_removed": true,
		"message": message
	}


## カードコスト修正（ライフフォース: クリーチャー/アイテムのコスト0化）
## 戻り値: 修正後のコスト
func get_modified_cost(player_id: int, card: Dictionary) -> int:
	var card_type = card.get("type", "")
	var original_cost = _get_card_cost(card)
	
	# ライフフォース呪いチェック（コスト0化）
	if has_life_force(player_id):
		if card_type == "creature" or card_type == "item":
			print("[ライフフォース] %s のコスト: %d → 0" % [card.get("name", "?"), original_cost])
			return 0
	
	# ウェイストワールド（世界呪い）チェック（コスト倍率）
	var multiplier = _get_world_curse_multiplier(card)
	if multiplier != 1.0:
		var modified_cost = int(ceil(original_cost * multiplier))
		print("[ウェイストワールド] %s のコスト: %d → %d (x%.1f)" % [card.get("name", "?"), original_cost, modified_cost, multiplier])
		return modified_cost
	
	return original_cost


## ウェイストワールド: コスト倍率を取得
func _get_world_curse_multiplier(card: Dictionary) -> float:
	if not game_flow_manager or not "game_stats" in game_flow_manager:
		return 1.0
	
	var world_curse = game_flow_manager.game_stats.get("world_curse", {})
	if world_curse.get("curse_type", "") != "cost_increase":
		return 1.0
	
	var params = world_curse.get("params", {})
	
	# 袋（S）= 1.5倍、冠袋（R）= 2倍
	var rarity = card.get("rarity", "N")
	
	if rarity == "R":
		return params.get("crown_bag_multiplier", 2.0)
	elif rarity == "S" or rarity == "SS":
		return params.get("bag_multiplier", 1.5)
	
	# N以下は倍率なし
	return 1.0


## カードの元のコストを取得
func _get_card_cost(card: Dictionary) -> int:
	var cost_data = card.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("mp", 0)
	return cost_data


## プレイヤー名を取得
func _get_player_name(player_id: int) -> String:
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		return player_system.players[player_id].name
	return "プレイヤー%d" % (player_id + 1)
