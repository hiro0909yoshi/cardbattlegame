class_name SpellCostModifier
extends RefCounted

## コスト操作スペルシステム
## - エンジェルギフト（2117）: クリーチャー/アイテム0EP、スペル無効化で解除
## - ライズオブサン（2009）: カード使用コスト倍率（世界刻印）

var spell_curse = null
var player_system: PlayerSystem = null
var game_flow_manager = null  # 後方互換用

# === 直接参照（GFM経由を廃止） ===
var spell_world_curse = null  # SpellWorldCurse: 世界刻印

## セットアップ
func setup(p_spell_curse, p_player_system: PlayerSystem, p_game_flow_manager = null):
	spell_curse = p_spell_curse
	player_system = p_player_system
	game_flow_manager = p_game_flow_manager

## 直接参照を設定（GFM経由を廃止）
func set_spell_world_curse(world_curse) -> void:
	spell_world_curse = world_curse


# ========================================
# エンジェルギフト（2117）
# ========================================

## エンジェルギフト刻印付与
func apply_life_force(target_player_id: int) -> Dictionary:
	if not spell_curse or not player_system:
		return {"success": false, "message": "システム未初期化"}
	
	var params = {
		"name": "天使",
		"cost_zero_types": ["creature", "item"],
		"nullify_spell": true
	}
	
	spell_curse.curse_player(target_player_id, "life_force", -1, params)
	
	var player_name = _get_player_name(target_player_id)
	print("[エンジェルギフト] %s に刻印「天使」を付与" % player_name)
	
	return {"success": true, "message": "%s に天使を付与" % player_name}


## エンジェルギフト刻印を持っているかチェック
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
	
	# 刻印を解除
	if spell_curse:
		spell_curse.remove_curse_from_player(player_id)
	
	var player_name = _get_player_name(player_id)
	var message = "【天使】%s のスペルは無効化された！刻印が解除された" % player_name
	print(message)
	
	return {
		"nullified": true,
		"curse_removed": true,
		"message": message
	}


## カードコスト修正（エンジェルギフト: クリーチャー/アイテムのコスト0化）
## 戻り値: 修正後のコスト
func get_modified_cost(player_id: int, card: Dictionary) -> int:
	var card_type = card.get("type", "")
	var original_cost = _get_card_cost(card)
	
	# エンジェルギフト刻印チェック（コスト0化）
	if has_life_force(player_id):
		if card_type == "creature" or card_type == "item":
			print("[エンジェルギフト] %s のコスト: %d → 0" % [card.get("name", "?"), original_cost])
			return 0
	
	# ライズオブサン（世界刻印）チェック - SpellWorldCurseに委譲
	if spell_world_curse:
		var multiplier = spell_world_curse.get_cost_multiplier_for_card(card)
		if multiplier != 1.0:
			var modified_cost = int(ceil(original_cost * multiplier))
			print("[ライズオブサン] %s のコスト: %d → %d (x%.1f)" % [card.get("name", "?"), original_cost, modified_cost, multiplier])
			return modified_cost
	
	return original_cost


## カードの元のコストを取得
func _get_card_cost(card: Dictionary) -> int:
	var cost_data = card.get("cost", 0)
	if typeof(cost_data) == TYPE_DICTIONARY:
		return cost_data.get("ep", 0)
	return cost_data


## プレイヤー名を取得
func _get_player_name(player_id: int) -> String:
	if player_system and player_id >= 0 and player_id < player_system.players.size():
		return player_system.players[player_id].name
	return "プレイヤー%d" % (player_id + 1)
