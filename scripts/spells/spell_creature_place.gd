extends Node
class_name SpellCreaturePlace

# クリーチャー配置システム
# スペル・秘術でのクリーチャー配置を統一管理

# ===== ユーティリティメソッド =====

## 配置可能な空き地を取得
func get_empty_tiles(board_system: BoardSystem3D) -> Array:
	"""盤面上の全空き地を取得（特殊タイルを除外、タイル番号順）"""
	var empty_tiles = []
	
	# タイル番号順にソート
	var tile_indices = board_system.tile_nodes.keys()
	tile_indices.sort()
	
	for tile_index in tile_indices:
		var tile = board_system.tile_nodes[tile_index]
		# 配置不可タイルは除外
		if not TileHelper.is_placeable_tile(tile):
			continue
		# クリーチャーがいない土地のみ
		if tile.creature_data.is_empty():
			empty_tiles.append(tile_index)
	
	if empty_tiles.is_empty():
		print("[SpellCreaturePlace] 配置可能なタイルがありません")
	
	return empty_tiles

## 配置前の検証
func validate_placement(board_system: BoardSystem3D, tile_index: int, _creature_id: int) -> bool:
	"""タイルへのクリーチャー配置が有効か確認"""
	
	# タイルの存在確認
	if not board_system.tile_nodes.has(tile_index):
		print("[警告] タイルが見つかりません: ", tile_index)
		return false
	
	var tile = board_system.tile_nodes[tile_index]
	
	# 空き地確認
	if not tile.creature_data.is_empty():
		print("[警告] タイル%dには既にクリーチャーが配置されています" % tile_index)
		return false
	
	return true

## クリーチャーをタイルに配置（共通処理）
func _place_creature_direct(
	board_system: BoardSystem3D,
	tile_index: int,
	creature_id: int,
	player_id: int,
	card_loader: CardLoader
) -> bool:
	"""実際にクリーチャーをタイルに配置する"""
	
	# クリーチャーデータを取得
	var creature_data = card_loader.get_card_by_id(creature_id)
	if creature_data.is_empty():
		print("[エラー] クリーチャーが見つかりません: ", creature_id)
		return false
	
	# 検証
	if not validate_placement(board_system, tile_index, creature_id):
		return false
	
	# 配置実行
	board_system.place_creature(tile_index, creature_data, player_id)
	print("[配置完了] タイル%d に %s (ID:%d) を配置 (プレイヤー%d)" % 
		  [tile_index, creature_data.get("name", "?"), creature_id, player_id])
	
	return true

## クリーチャーをダウン状態に設定
func _set_creature_down(board_system: BoardSystem3D, tile_index: int) -> void:
	"""配置したクリーチャーをダウン状態に設定"""
	
	if not board_system.tile_nodes.has(tile_index):
		return
	
	var tile = board_system.tile_nodes[tile_index]
	
	# BaseTile.set_down_state() メソッドが存在する場合
	if tile.has_method("set_down_state"):
		tile.set_down_state(true)
	
	# クリーチャーデータにダウンフラグを設定
	if not tile.creature_data.is_empty():
		tile.creature_data["is_down"] = true
	
	print("[ダウン設定] タイル%d のクリーチャーをダウン状態に" % tile_index)

# ===== 配置モード別メソッド =====

## 1. ランダム配置（random）- ゲームが自動選択
func place_creature_random(
	board_system: BoardSystem3D,
	player_id: int,
	creature_id: int,
	card_loader: CardLoader,
	set_down: bool = false
) -> bool:
	"""ランダム配置（スパルトイ用）"""
	
	# 空き地取得
	var empty_tiles = get_empty_tiles(board_system)
	if empty_tiles.is_empty():
		return false
	
	# ランダムに1つ選択
	var selected_tile = empty_tiles[randi() % empty_tiles.size()]
	
	# 配置実行
	var success = _place_creature_direct(board_system, selected_tile, creature_id, player_id, card_loader)
	
	if success and set_down:
		_set_creature_down(board_system, selected_tile)
	
	return success

## 3. 条件付き配置（conditional）- 条件を満たした場合に配置
func place_creature_conditional(
	board_system: BoardSystem3D,
	player_system: PlayerSystem,
	player_id: int,
	creature_id: int,
	card_loader: CardLoader,
	set_down: bool = false
) -> bool:
	"""条件付き配置（ゴブリンズレア用）
	
	条件: プレイヤーが「空地」（所有者がいない通常タイル）に止まっている
	"""
	
	# 1. プレイヤーの現在位置を取得（board_system経由で正確な位置を取得）
	var current_tile = -1
	if board_system.movement_controller:
		current_tile = board_system.movement_controller.get_player_tile(player_id)
	
	# フォールバック: PlayerSystemから取得
	if current_tile < 0:
		current_tile = player_system.get_player_position(player_id)
	
	if current_tile < 0:
		print("[警告] プレイヤー位置が取得できません")
		return false
	
	print("[条件付き配置] プレイヤー%d の現在位置: タイル%d" % [player_id, current_tile])
	
	# 2. 現在地が空地（所有者なし）か確認
	var tile = board_system.tile_nodes.get(current_tile)
	if not tile:
		print("[警告] タイルが見つかりません: ", current_tile)
		return false
	
	# 配置不可タイルチェック
	if not TileHelper.is_placeable_tile(tile):
		print("[条件判定] 失敗 - タイル%dは配置不可タイルです" % current_tile)
		return false
	
	# 所有者がいる土地は配置不可
	if tile.owner_id != -1:
		print("[条件判定] 失敗 - タイル%dは既に所有されています（所有者: %d）" % [current_tile, tile.owner_id])
		return false
	
	# 3. クリーチャー配置（条件成立）
	print("[条件判定] 成功 - タイル%dは空地です" % current_tile)
	var success = _place_creature_direct(board_system, current_tile, creature_id, player_id, card_loader)
	
	if success and set_down:
		_set_creature_down(board_system, current_tile)
	
	return success

## 4. 隣接空地配置（adjacent）- 選択タイルの隣接空き地に配置
func place_creature_adjacent(
	board_system: BoardSystem3D,
	player_id: int,
	creature_id: int,
	target_tile: int,
	card_loader: CardLoader,
	set_down: bool = false
) -> Array:
	"""隣接空地配置（レジェンドファロス秘術用）
	
	Args:
		target_tile: 中心となるタイル（自クリーチャーがいるタイル）
	
	Returns:
		配置成功したタイルのインデックス配列
	"""
	
	var placed_tiles = []
	
	# 隣接タイル取得
	var adjacent_tiles = []
	if board_system.tile_neighbor_system:
		adjacent_tiles = board_system.tile_neighbor_system.get_spatial_neighbors(target_tile)
	
	if adjacent_tiles.is_empty():
		print("[配置] 隣接タイルがありません")
		return placed_tiles
	
	# 隣接タイル中、空き地のみを抽出（特殊タイルを除外）
	var available_adjacent = []
	for adj_tile in adjacent_tiles:
		var tile = board_system.tile_nodes.get(adj_tile)
		if not tile:
			continue
		# 配置不可タイルは除外
		if not TileHelper.is_placeable_tile(tile):
			continue
		# クリーチャーがいない土地のみ
		if tile.creature_data.is_empty():
			available_adjacent.append(adj_tile)
	
	if available_adjacent.is_empty():
		print("[配置] 配置可能な隣接空き地がありません")
		return placed_tiles
	
	# 各隣接空き地に配置
	for adj_tile in available_adjacent:
		var success = _place_creature_direct(board_system, adj_tile, creature_id, player_id, card_loader)
		
		if success:
			placed_tiles.append(adj_tile)
			if set_down:
				_set_creature_down(board_system, adj_tile)
	
	print("[隣接配置] %d個のタイルに配置完了" % placed_tiles.size())
	return placed_tiles

# ===== 復帰処理 =====

## 復帰[手札] - スペルカードを手札に戻す
func return_to_hand(
	spell_card: Dictionary,
	player_id: int,
	card_system: CardSystem
) -> void:
	"""スペルカードを手札に戻す（復帰[手札]）
	
	対象: ゴブリンズレア（ID: 2028）
	"""
	
	if card_system.hand[player_id] == null:
		card_system.hand[player_id] = []
	
	# 手札に追加
	card_system.hand[player_id].append(spell_card)
	
	print("[復帰[手札]] %s をプレイヤー%d の手札に戻しました" % 
		  [spell_card.get("name", "?"), player_id])

# ===== 汎用配置メソッド（SpellPhaseHandler/SpellMysticArts連携用） =====

## ターゲット選択済みの配置を実行（秘術・スペル共通）
func place_creature_at_target(
	board_system: BoardSystem3D,
	player_id: int,
	creature_id: int,
	target_data: Dictionary,
	set_down: bool = false
) -> bool:
	"""target_dataで指定されたタイルにクリーチャーを配置
	
	Args:
		board_system: ボードシステム参照
		player_id: 配置するプレイヤーID
		creature_id: 配置するクリーチャーID
		target_data: ターゲット情報（tile_indexを含む）
		set_down: 配置後ダウン状態にするか
	
	Returns:
		配置成功: true, 失敗: false
	"""
	var tile_index = target_data.get("tile_index", -1)
	if tile_index < 0:
		print("[SpellCreaturePlace] 無効なtile_index: ", tile_index)
		return false
	
	# 配置実行
	var success = _place_creature_direct(board_system, tile_index, creature_id, player_id, CardLoader)
	
	if success and set_down:
		_set_creature_down(board_system, tile_index)
	
	return success


## placement_modeに基づいて配置を実行（effect辞書から呼び出し）
func apply_place_effect(
	effect: Dictionary,
	target_data: Dictionary,
	player_id: int,
	board_system: BoardSystem3D,
	player_system: PlayerSystem = null
) -> Dictionary:
	"""place_creature効果を適用
	
	Args:
		effect: 効果辞書（creature_id, placement_mode等を含む）
		target_data: ターゲット情報
		player_id: 配置するプレイヤーID
		board_system: ボードシステム参照
		player_system: プレイヤーシステム参照（conditional用）
	
	Returns:
		結果辞書 { "success": bool, "placed_tiles": Array }
	"""
	var creature_id = effect.get("creature_id", -1)
	var placement_mode = effect.get("placement_mode", "select")
	var set_down = effect.get("set_down", false)
	
	if creature_id <= 0:
		print("[SpellCreaturePlace] 無効なcreature_id: ", creature_id)
		return { "success": false, "placed_tiles": [] }
	
	var result = { "success": false, "placed_tiles": [] }
	
	match placement_mode:
		"select":
			# 指定配置 - target_dataのtile_indexを使用
			var success = place_creature_at_target(board_system, player_id, creature_id, target_data, set_down)
			result["success"] = success
			if success:
				result["placed_tiles"] = [target_data.get("tile_index", -1)]
		
		"random":
			# ランダム配置
			var success = place_creature_random(board_system, player_id, creature_id, CardLoader, set_down)
			result["success"] = success
		
		"conditional":
			# 条件付き配置（空地にいる場合のみ）
			if player_system:
				var success = place_creature_conditional(board_system, player_system, player_id, creature_id, CardLoader, set_down)
				result["success"] = success
			else:
				print("[SpellCreaturePlace] conditional配置にはplayer_systemが必要です")
		
		"adjacent":
			# 隣接空地配置
			var target_tile = target_data.get("tile_index", -1)
			var placed_tiles = place_creature_adjacent(board_system, player_id, creature_id, target_tile, CardLoader, set_down)
			result["success"] = placed_tiles.size() > 0
			result["placed_tiles"] = placed_tiles
		
		_:
			print("[SpellCreaturePlace] 未対応のplacement_mode: ", placement_mode)
	
	return result


# ===== デバッグ・テスト用 =====

func debug_list_empty_tiles(board_system: BoardSystem3D) -> void:
	"""デバッグ用：空き地一覧を表示"""
	var empty_tiles = get_empty_tiles(board_system)
	print("[デバッグ] 空き地一覧（計%d個）: %s" % [empty_tiles.size(), empty_tiles])
