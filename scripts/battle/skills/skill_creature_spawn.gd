class_name SkillCreatureSpawn
extends RefCounted

## クリーチャー分裂・複製スキル
##
## 対象クリーチャー:
## - 140: マイコロン - 敵攻撃で生き残った戦闘後、ランダム空地にコピー配置
## - 335: バウダーイーター - 領地コマンド移動時、元の領地に自分を残す

const MYCOLON_ID = 140
const BOULDER_EATER_ID = 335


# ============================================================
# 判定関数
# ============================================================

## マイコロンかどうか判定
static func is_mycolon(creature_data: Dictionary) -> bool:
	return creature_data.get("id", 0) == MYCOLON_ID


## バウダーイーターかどうか判定
static func is_boulder_eater(creature_data: Dictionary) -> bool:
	return creature_data.get("id", 0) == BOULDER_EATER_ID


## 分裂スキルを持つかどうか判定
static func has_spawn_skill(creature_data: Dictionary) -> bool:
	var ability_parsed = creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		if effect_type in ["spawn_copy_on_defend_survive", "split_on_move"]:
			return true
	
	return false


# ============================================================
# マイコロン: 戦闘後コピー配置
# ============================================================

## マイコロンの戦闘後コピー配置チェック
## 敵から攻撃を受けて生き残った場合に発動
static func check_mycolon_spawn(defender_data: Dictionary, _defender_tile_index: int, 
								was_attacked: bool, board_system, _player_id: int) -> Dictionary:
	var result = {
		"spawned": false,
		"spawn_tile_index": -1,
		"creature_data": {}
	}
	
	# マイコロンでなければスキップ
	if not is_mycolon(defender_data):
		return result
	
	# 攻撃を受けていなければスキップ
	if not was_attacked:
		return result
	
	print("【マイコロン】戦闘後コピー配置チェック")
	
	# ランダムな空地を検索
	var empty_tile = _find_random_empty_tile(board_system)
	if empty_tile < 0:
		print("  空地なし - 発動しない")
		return result
	
	# コピーを生成
	var copy_data = create_creature_copy(defender_data, true)  # 呪い除去
	
	result["spawned"] = true
	result["spawn_tile_index"] = empty_tile
	result["creature_data"] = copy_data
	
	print("  コピー配置先: タイル", empty_tile)
	
	return result


## マイコロンのコピーを実際に配置
static func spawn_mycolon_copy(board_system, tile_index: int, creature_data: Dictionary, player_id: int) -> bool:
	if not board_system:
		return false
	
	# タイルにクリーチャーを配置
	var tile = board_system.tile_data_manager.tile_nodes.get(tile_index)
	if tile:
		# 所有者を設定してからplace_creature()で3Dカードも含めて配置
		tile.owner_id = player_id
		tile.place_creature(creature_data)
		
		# ダウン状態にする（不屈チェック）
		if tile.has_method("set_down_state"):
			if not PlayerBuffSystem.has_unyielding(creature_data):
				tile.set_down_state(true)
		
		print("【マイコロン】コピー配置完了: タイル", tile_index)
		return true
	
	return false


# ============================================================
# バウダーイーター: 移動時分裂
# ============================================================

## バウダーイーターの分裂移動チェック
## 領地コマンド移動時に呼び出す
static func check_boulder_eater_split(creature_data: Dictionary) -> bool:
	return is_boulder_eater(creature_data)


## バウダーイーターの分裂処理
## 元の領地に残すクリーチャーデータを生成（呪い維持）
## 移動先用のコピーデータを生成（呪い除去）
static func process_boulder_eater_split(creature_data: Dictionary) -> Dictionary:
	var result = {
		"original": {},  # 元の領地に残る（呪い維持）
		"copy": {}       # 移動先に配置（呪い除去）
	}
	
	# 元の領地用（呪い維持）
	result["original"] = create_creature_copy(creature_data, false)
	
	# 移動先用（呪い除去）
	result["copy"] = create_creature_copy(creature_data, true)
	
	print("【バウダーイーター】分裂処理")
	print("  元の領地: 呪い維持")
	print("  移動先: 呪い除去")
	
	return result


# ============================================================
# 共通処理
# ============================================================

## クリーチャーデータのコピーを生成
## @param creature_data 元のクリーチャーデータ
## @param remove_curse 呪いを除去するか
## @return コピーされたクリーチャーデータ
static func create_creature_copy(creature_data: Dictionary, remove_curse: bool) -> Dictionary:
	var copy = creature_data.duplicate(true)
	
	# 呪いを除去する場合
	if remove_curse:
		if copy.has("curse"):
			copy.erase("curse")
		if copy.has("curses"):
			copy.erase("curses")
		if copy.has("curse_effects"):
			copy.erase("curse_effects")
		print("  [コピー生成] 呪い除去")
	else:
		print("  [コピー生成] 呪い維持")
	
	# ステータス引き継ぎ（base_up_ap/hp, current_hp）はduplicate(true)で自動的にコピーされる
	print("  [コピー生成] base_up_ap:", copy.get("base_up_ap", 0), 
		  " base_up_hp:", copy.get("base_up_hp", 0),
		  " current_hp:", copy.get("current_hp", copy.get("hp", 0)))
	
	return copy


## ランダムな空地を検索（クリーチャー配置可能なタイルのみ）
static func _find_random_empty_tile(board_system) -> int:
	if not board_system or not board_system.tile_data_manager:
		return -1
	
	var empty_tiles = []
	
	for tile_index in board_system.tile_data_manager.tile_nodes:
		var tile = board_system.tile_data_manager.tile_nodes[tile_index]
		
		# TileHelperで空き地判定（配置可能 + 所有者なし + クリーチャーなし）
		if TileHelper.is_empty_land(tile):
			empty_tiles.append(tile_index)
	
	if empty_tiles.is_empty():
		print("  空地が見つかりません")
		return -1
	
	# ランダムに選択
	var selected = empty_tiles[randi() % empty_tiles.size()]
	print("  空地候補:", empty_tiles.size(), "件 → 選択:", selected)
	return selected
