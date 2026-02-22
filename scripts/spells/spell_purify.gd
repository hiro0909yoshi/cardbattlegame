extends Node
class_name SpellPurify

# 刻印除去システム
# 2073: ピュアリファイ - 全刻印を消し、種類×5EP0を得る
# アルカナアーツ9024: 対象ドミニオの刻印を消す（ギアリオン）
# アルカナアーツ9025: 世界刻印を消す（ウリエル）
# アルカナアーツ9026: 全セプターの刻印を消す（シャラザード）

# 参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var game_flow_manager: GameFlowManager
var creature_manager: CreatureManager

# === 直接参照（GFM経由を廃止） ===
var game_stats  # GameFlowManager.game_stats への直接参照

# 初期化
func _init(board: BoardSystem3D, creature: CreatureManager, player: PlayerSystem, flow: GameFlowManager):
	board_system = board
	creature_manager = creature
	player_system = player
	game_flow_manager = flow

## game_statsを設定（GFM経由を廃止）
func set_game_stats(p_game_stats) -> void:
	game_stats = p_game_stats

# ========================================
# 2073: ピュアリファイ
# ========================================

## 全刻印を消し、消した刻印の種類×50EPを得る
## @param caster_id: 術者のプレイヤーID
## @return Dictionary: {removed_types: Array, ep_gained: int}
func purify_all(caster_id: int) -> Dictionary:
	var removed_curse_types: Array = []

	# 1. クリーチャー刻印を収集・除去
	var creature_types = _remove_all_creature_curses()
	for curse_type in creature_types:
		if curse_type not in removed_curse_types:
			removed_curse_types.append(curse_type)

	# 2. プレイヤー刻印を収集・除去
	var player_types = _remove_all_player_curses()
	for curse_type in player_types:
		if curse_type not in removed_curse_types:
			removed_curse_types.append(curse_type)

	# 3. 世界刻印を収集・除去
	var world_type = _remove_world_curse_internal()
	if world_type != "" and world_type not in removed_curse_types:
		removed_curse_types.append(world_type)

	# 4. 蓄魔（種類×50EP）
	var ep_gained = removed_curse_types.size() * 50
	if ep_gained > 0 and caster_id >= 0 and caster_id < player_system.players.size():
		player_system.players[caster_id].magic_power += ep_gained
		print("[ピュアリファイ] プレイヤー%d: %d種類の刻印を消し、%dEPを得た" % [caster_id, removed_curse_types.size(), ep_gained])

	return {
		"removed_types": removed_curse_types,
		"ep_gained": ep_gained
	}

## 全クリーチャーの刻印を除去し、刻印タイプのリストを返す
func _remove_all_creature_curses() -> Array:
	var curse_types: Array = []
	
	for tile_index in board_system.tile_nodes.keys():
		var creature = creature_manager.get_data_ref(tile_index)
		if creature and creature.has("curse"):
			var curse = creature["curse"]
			var curse_type = curse.get("curse_type", "unknown")
			var curse_name = curse.get("name", "不明")
			
			if curse_type not in curse_types:
				curse_types.append(curse_type)
			
			creature.erase("curse")
			print("[刻印除去] クリーチャー「%s」の刻印「%s」を消した" % [creature.get("name", "?"), curse_name])
	
	return curse_types

## 全プレイヤーの刻印を除去し、刻印タイプのリストを返す
func _remove_all_player_curses() -> Array:
	var curse_types: Array = []
	
	for i in range(player_system.players.size()):
		var player = player_system.players[i]
		if not player.curse.is_empty():
			var curse_type = player.curse.get("curse_type", "unknown")
			var curse_name = player.curse.get("name", "不明")
			
			if curse_type not in curse_types:
				curse_types.append(curse_type)
			
			player.curse = {}
			print("[刻印除去] プレイヤー%dの刻印「%s」を消した" % [i, curse_name])
	
	return curse_types

## 世界刻印を除去し、刻印タイプを返す（空文字列なら刻印なし）
func _remove_world_curse_internal() -> String:
	if not game_stats.has("world_curse"):
		return ""
	
	var curse = game_stats["world_curse"]
	var curse_type = curse.get("curse_type", "unknown")
	var curse_name = curse.get("name", "不明")
	
	game_stats.erase("world_curse")
	print("[刻印除去] 世界刻印「%s」を消した" % curse_name)
	
	return curse_type

# ========================================
# アルカナアーツ9024: 対象ドミニオの刻印を消す（ギアリオン）
# ========================================

## 対象ドミニオのクリーチャー刻印を除去
## @param tile_index: 対象タイルインデックス
## @return bool: 刻印を除去できたかどうか
func remove_creature_curse(tile_index: int) -> bool:
	var creature = creature_manager.get_data_ref(tile_index)
	if not creature:
		print("[SpellPurify] エラー: タイル%dにクリーチャーが存在しません" % tile_index)
		return false
	
	if not creature.has("curse"):
		print("[SpellPurify] タイル%dのクリーチャーには刻印がありません" % tile_index)
		return false
	
	var curse_name = creature["curse"].get("name", "不明")
	creature.erase("curse")
	print("[アルカナアーツ:刻印除去] クリーチャー「%s」の刻印「%s」を消した" % [creature.get("name", "?"), curse_name])
	return true

# ========================================
# アルカナアーツ9025: 世界刻印を消す（ウリエル）
# ========================================

## 世界刻印を除去
## @return bool: 刻印を除去できたかどうか
func remove_world_curse() -> bool:
	if not game_stats.has("world_curse"):
		print("[SpellPurify] 世界刻印がありません")
		return false
	
	var curse_name = game_stats["world_curse"].get("name", "不明")
	game_stats.erase("world_curse")
	print("[アルカナアーツ:世界刻印除去] 世界刻印「%s」を消した" % curse_name)
	return true

# ========================================
# アルカナアーツ9026: 全セプターの刻印を消す（シャラザード）
# ========================================

## 全プレイヤーの刻印を除去
## @return int: 除去した刻印の数
func remove_all_player_curses() -> int:
	var removed_count = 0
	
	for i in range(player_system.players.size()):
		var player = player_system.players[i]
		if not player.curse.is_empty():
			var curse_name = player.curse.get("name", "不明")
			player.curse = {}
			removed_count += 1
			print("[アルカナアーツ:プレイヤー刻印除去] プレイヤー%dの刻印「%s」を消した" % [i, curse_name])
	
	print("[アルカナアーツ:プレイヤー刻印除去] 合計%d人の刻印を消した" % removed_count)
	return removed_count
