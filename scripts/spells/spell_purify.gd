extends Node
class_name SpellPurify

# 呪い除去システム
# 2073: ピュアリファイ - 全呪いを消し、種類×G50を得る
# 秘術9024: 対象領地の呪いを消す（ギアリオン）
# 秘術9025: 世界呪いを消す（ウリエル）
# 秘術9026: 全セプターの呪いを消す（シャラザード）

# 参照
var board_system: BoardSystem3D
var player_system: PlayerSystem
var game_flow_manager: GameFlowManager
var creature_manager: CreatureManager

# 初期化
func _init(board: BoardSystem3D, creature: CreatureManager, player: PlayerSystem, flow: GameFlowManager):
	board_system = board
	creature_manager = creature
	player_system = player
	game_flow_manager = flow
	print("[SpellPurify] 初期化完了")

# ========================================
# 2073: ピュアリファイ
# ========================================

## 全呪いを消し、消した呪いの種類×G50を得る
## @param caster_id: 術者のプレイヤーID
## @return Dictionary: {removed_types: Array, gold_gained: int}
func purify_all(caster_id: int) -> Dictionary:
	var removed_curse_types: Array = []
	
	# 1. クリーチャー呪いを収集・除去
	var creature_types = _remove_all_creature_curses()
	for curse_type in creature_types:
		if curse_type not in removed_curse_types:
			removed_curse_types.append(curse_type)
	
	# 2. プレイヤー呪いを収集・除去
	var player_types = _remove_all_player_curses()
	for curse_type in player_types:
		if curse_type not in removed_curse_types:
			removed_curse_types.append(curse_type)
	
	# 3. 世界呪いを収集・除去
	var world_type = _remove_world_curse_internal()
	if world_type != "" and world_type not in removed_curse_types:
		removed_curse_types.append(world_type)
	
	# 4. 魔力獲得（種類×G50）
	var gold_gained = removed_curse_types.size() * 50
	if gold_gained > 0 and caster_id >= 0 and caster_id < player_system.players.size():
		player_system.players[caster_id].magic_power += gold_gained
		print("[ピュアリファイ] プレイヤー%d: %d種類の呪いを消し、G%dを得た" % [caster_id, removed_curse_types.size(), gold_gained])
	
	return {
		"removed_types": removed_curse_types,
		"gold_gained": gold_gained
	}

## 全クリーチャーの呪いを除去し、呪いタイプのリストを返す
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
			print("[呪い除去] クリーチャー「%s」の呪い「%s」を消した" % [creature.get("name", "?"), curse_name])
	
	return curse_types

## 全プレイヤーの呪いを除去し、呪いタイプのリストを返す
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
			print("[呪い除去] プレイヤー%dの呪い「%s」を消した" % [i, curse_name])
	
	return curse_types

## 世界呪いを除去し、呪いタイプを返す（空文字列なら呪いなし）
func _remove_world_curse_internal() -> String:
	if not game_flow_manager.game_stats.has("world_curse"):
		return ""
	
	var curse = game_flow_manager.game_stats["world_curse"]
	var curse_type = curse.get("curse_type", "unknown")
	var curse_name = curse.get("name", "不明")
	
	game_flow_manager.game_stats.erase("world_curse")
	print("[呪い除去] 世界呪い「%s」を消した" % curse_name)
	
	return curse_type

# ========================================
# 秘術9024: 対象領地の呪いを消す（ギアリオン）
# ========================================

## 対象領地のクリーチャー呪いを除去
## @param tile_index: 対象タイルインデックス
## @return bool: 呪いを除去できたかどうか
func remove_creature_curse(tile_index: int) -> bool:
	var creature = creature_manager.get_data_ref(tile_index)
	if not creature:
		print("[SpellPurify] エラー: タイル%dにクリーチャーが存在しません" % tile_index)
		return false
	
	if not creature.has("curse"):
		print("[SpellPurify] タイル%dのクリーチャーには呪いがありません" % tile_index)
		return false
	
	var curse_name = creature["curse"].get("name", "不明")
	creature.erase("curse")
	print("[秘術:呪い除去] クリーチャー「%s」の呪い「%s」を消した" % [creature.get("name", "?"), curse_name])
	return true

# ========================================
# 秘術9025: 世界呪いを消す（ウリエル）
# ========================================

## 世界呪いを除去
## @return bool: 呪いを除去できたかどうか
func remove_world_curse() -> bool:
	if not game_flow_manager.game_stats.has("world_curse"):
		print("[SpellPurify] 世界呪いがありません")
		return false
	
	var curse_name = game_flow_manager.game_stats["world_curse"].get("name", "不明")
	game_flow_manager.game_stats.erase("world_curse")
	print("[秘術:世界呪い除去] 世界呪い「%s」を消した" % curse_name)
	return true

# ========================================
# 秘術9026: 全セプターの呪いを消す（シャラザード）
# ========================================

## 全プレイヤーの呪いを除去
## @return int: 除去した呪いの数
func remove_all_player_curses() -> int:
	var removed_count = 0
	
	for i in range(player_system.players.size()):
		var player = player_system.players[i]
		if not player.curse.is_empty():
			var curse_name = player.curse.get("name", "不明")
			player.curse = {}
			removed_count += 1
			print("[秘術:プレイヤー呪い除去] プレイヤー%dの呪い「%s」を消した" % [i, curse_name])
	
	print("[秘術:プレイヤー呪い除去] 合計%d人の呪いを消した" % removed_count)
	return removed_count
