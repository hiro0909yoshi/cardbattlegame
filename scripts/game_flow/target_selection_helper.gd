# TargetSelectionHelper - 対象選択の汎用ヘルパー
# 土地、クリーチャー、プレイヤーなど、あらゆる対象の選択に使用可能
class_name TargetSelectionHelper

# ============================================
# 選択マーカーシステム
# ============================================

## 選択マーカーを作成
## 
## handler: 選択マーカーを保持するオブジェクト（LandCommandHandler、SpellPhaseHandlerなど）
##          handler.selection_marker プロパティが必要
static func create_selection_marker(handler):
	if handler.selection_marker:
		return  # 既に存在する場合は何もしない
	
	# シンプルなリング形状のマーカーを作成
	handler.selection_marker = MeshInstance3D.new()
	
	# トーラス（ドーナツ型）メッシュを作成
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 16
	
	handler.selection_marker.mesh = torus
	
	# マテリアル設定（黄色で発光）
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 0.0, 1.0)  # 黄色
	material.emission_enabled = true
	material.emission = Color(1.0, 1.0, 0.0)
	material.emission_energy_multiplier = 2.0
	handler.selection_marker.material_override = material

## 選択マーカーを表示
## 
## handler: 選択マーカーを保持するオブジェクト
##          handler.selection_marker と handler.board_system が必要
## tile_index: マーカーを表示する土地のインデックス
static func show_selection_marker(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	
	# マーカーが未作成なら作成
	if not handler.selection_marker:
		create_selection_marker(handler)
	
	# マーカーを土地の子として追加
	if handler.selection_marker.get_parent():
		handler.selection_marker.get_parent().remove_child(handler.selection_marker)
	
	tile.add_child(handler.selection_marker)
	
	# 位置を土地の少し上に設定
	handler.selection_marker.position = Vector3(0, 0.5, 0)
	
	# 回転アニメーションを追加
	if not handler.selection_marker.has_meta("rotating"):
		handler.selection_marker.set_meta("rotating", true)

## 選択マーカーを非表示
## 
## handler: 選択マーカーを保持するオブジェクト
static func hide_selection_marker(handler):
	if handler.selection_marker and handler.selection_marker.get_parent():
		handler.selection_marker.get_parent().remove_child(handler.selection_marker)

## 選択マーカーを回転（_process内で呼ぶ）
## 
## handler: 選択マーカーを保持するオブジェクト
## delta: フレーム間の経過時間
static func rotate_selection_marker(handler, delta: float):
	if handler.selection_marker and handler.selection_marker.has_meta("rotating"):
		handler.selection_marker.rotate_y(delta * 2.0)  # 1秒で約114度回転

# ============================================
# カメラ制御
# ============================================

## カメラを土地にフォーカス
## 
## handler: board_system を持つオブジェクト
## tile_index: フォーカスする土地のインデックス
static func focus_camera_on_tile(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	var camera = handler.board_system.camera
	
	if not camera:
		return
	
	# カメラを土地の上方に移動
	var tile_pos = tile.global_position
	var camera_offset = Vector3(12, 15, 12)
	camera.position = tile_pos + camera_offset
	
	# カメラを土地に向ける
	camera.look_at(tile_pos, Vector3.UP)

## カメラをプレイヤーにフォーカス
## 
## handler: board_system を持つオブジェクト
## player_id: フォーカスするプレイヤーのID
static func focus_camera_on_player(handler, player_id: int):
	if not handler.board_system or not handler.board_system.movement_controller:
		return
	
	# プレイヤーの位置（タイル）を取得
	var player_tile = handler.board_system.movement_controller.get_player_tile(player_id)
	
	if player_tile >= 0:
		# プレイヤーがいる土地にカメラをフォーカス
		focus_camera_on_tile(handler, player_tile)

# ============================================
# ハイライト制御
# ============================================

## 土地をハイライト
## 
## handler: board_system を持つオブジェクト
## tile_index: ハイライトする土地のインデックス
static func highlight_tile(handler, tile_index: int):
	if not handler.board_system or not handler.board_system.tile_nodes.has(tile_index):
		return
	
	var tile = handler.board_system.tile_nodes[tile_index]
	if tile.has_method("set_highlight"):
		tile.set_highlight(true)

## すべてのハイライトをクリア
## 
## handler: board_system を持つオブジェクト
static func clear_all_highlights(handler):
	if not handler.board_system:
		return
	
	for tile_idx in handler.board_system.tile_nodes.keys():
		var tile = handler.board_system.tile_nodes[tile_idx]
		if tile.has_method("set_highlight"):
			tile.set_highlight(false)

# ============================================
# 対象タイプ別の処理
# ============================================

## 対象データから土地インデックスを取得
## 
## target_data: 対象データ（type, tile_index, player_idなどを含む）
## board_system: BoardSystem3Dの参照（プレイヤー位置取得に必要）
## 戻り値: 土地インデックス、取得できない場合は-1
static func get_tile_index_from_target(target_data: Dictionary, board_system) -> int:
	var target_type = target_data.get("type", "")
	
	match target_type:
		"land", "creature":
			# 土地またはクリーチャーの場合、tile_indexを直接使用
			return target_data.get("tile_index", -1)
		
		"player":
			# プレイヤーの場合、プレイヤーの位置を取得
			var player_id = target_data.get("player_id", -1)
			if player_id >= 0 and board_system and board_system.movement_controller:
				return board_system.movement_controller.get_player_tile(player_id)
			return -1
		
		_:
			return -1

## 対象を視覚的に選択（マーカー、カメラ、ハイライト）
## 
## handler: board_system と selection_marker を持つオブジェクト
## target_data: 対象データ
static func select_target_visually(handler, target_data: Dictionary):
	# 前のハイライトをクリア
	clear_all_highlights(handler)
	
	# 対象の土地インデックスを取得
	var tile_index = get_tile_index_from_target(target_data, handler.board_system)
	
	if tile_index >= 0:
		# マーカーを表示
		show_selection_marker(handler, tile_index)
		
		# カメラをフォーカス
		focus_camera_on_tile(handler, tile_index)
		
		# ハイライトを表示
		highlight_tile(handler, tile_index)

## 対象選択を完全にクリア（マーカー、ハイライト）
## 
## handler: board_system と selection_marker を持つオブジェクト
static func clear_selection(handler):
	# ハイライトをクリア
	clear_all_highlights(handler)
	
	# マーカーを非表示
	hide_selection_marker(handler)

# ============================================
# 入力ヘルパー
# ============================================

## 数字キーかどうか
static func is_number_key(keycode: int) -> bool:
	return keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

## キーコードから数字を取得（0-9）
static func get_number_from_key(keycode: int) -> int:
	var key_to_index = {
		KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4,
		KEY_6: 5, KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9
	}
	return key_to_index.get(keycode, -1)

# ============================================
# ターゲット検索システム
# ============================================

## 有効なターゲットを取得
## 
## handler: board_system, player_system, current_player_id を持つオブジェクト
## target_type: "land", "creature", "player" など
## target_info: フィルター条件（owner_filter, max_level, required_elements など）
## 戻り値: ターゲット情報の配列
static func get_valid_targets(handler, target_type: String, target_info: Dictionary) -> Array:
	var targets = []
	
	match target_type:
		"creature":
			# 敵クリーチャーを探す
			if handler.board_system:
				for tile_index in handler.board_system.tile_nodes.keys():
					var tile_info = handler.board_system.get_tile_info(tile_index)
					var creature = tile_info.get("creature", {})
					if not creature.is_empty():
						var tile_owner = tile_info.get("owner", -1)
						if tile_owner != handler.current_player_id and tile_owner >= 0:
							targets.append({
								"type": "creature",
								"tile_index": tile_index,
								"creature": creature,
								"owner": tile_owner
							})
		
		"player":
			# プレイヤーを対象とする
			if handler.player_system:
				var target_filter = target_info.get("target_filter", "any")  # "own", "enemy", "any"
				
				for player in handler.player_system.players:
					var is_current = (player.id == handler.current_player_id)
					
					# フィルター判定
					var matches = false
					if target_filter == "own":
						matches = is_current
					elif target_filter == "enemy":
						matches = not is_current
					elif target_filter == "any":
						matches = true
					
					if matches:
						targets.append({
							"type": "player",
							"player_id": player.id,
							"player": {
								"name": player.name,
								"magic_power": player.magic_power,
								"id": player.id
							}
						})
		
		"land", "own_land", "enemy_land":
			# 土地を対象とする
			if handler.board_system:
				var owner_filter = target_info.get("owner_filter", "any")  # "own", "enemy", "any"
				
				for tile_index in handler.board_system.tile_nodes.keys():
					var tile_info = handler.board_system.get_tile_info(tile_index)
					var tile_owner = tile_info.get("owner", -1)
					
					# 所有者フィルター
					var matches_owner = false
					if owner_filter == "own":
						matches_owner = (tile_owner == handler.current_player_id)
					elif owner_filter == "enemy":
						matches_owner = (tile_owner >= 0 and tile_owner != handler.current_player_id)
					else:  # "any"
						matches_owner = (tile_owner >= 0)
					
					if matches_owner:
						var tile_level = tile_info.get("level", 1)
						var tile_element = tile_info.get("element", "")
						
						# レベル制限チェック
						var max_level = target_info.get("max_level", 999)
						var min_level = target_info.get("min_level", 1)
						var required_level = target_info.get("required_level", -1)
						
						# required_levelが指定されている場合は、そのレベルのみ対象
						if required_level > 0:
							if tile_level != required_level:
								continue
						elif tile_level < min_level or tile_level > max_level:
							continue
						
						# 属性制限チェック
						var required_elements = target_info.get("required_elements", [])
						if not required_elements.is_empty():
							if tile_element not in required_elements:
								continue
						
						# クリーチャー存在チェック（target_filter: "creature"）
						var target_filter = target_info.get("target_filter", "")
						if target_filter == "creature":
							var creature = tile_info.get("creature", {})
							if creature.is_empty():
								continue
						
						# 条件を満たす土地を追加
						var land_target = {
							"type": "land",
							"tile_index": tile_index,
							"element": tile_element,
							"level": tile_level,
							"owner": tile_owner
						}
						targets.append(land_target)
	
	return targets

## ターゲットインデックスを次へ移動
## 
## handler: available_targets, current_target_index を持つオブジェクト
## 戻り値: インデックスが変更されたか
static func move_target_next(handler) -> bool:
	if handler.current_target_index < handler.available_targets.size() - 1:
		handler.current_target_index += 1
		return true
	return false

## ターゲットインデックスを前へ移動
## 
## handler: available_targets, current_target_index を持つオブジェクト
## 戻り値: インデックスが変更されたか
static func move_target_previous(handler) -> bool:
	if handler.current_target_index > 0:
		handler.current_target_index -= 1
		return true
	return false

## ターゲットを数字で直接選択
## 
## handler: available_targets, current_target_index を持つオブジェクト
## index: 選択するインデックス
## 戻り値: 選択が成功したか
static func select_target_by_index(handler, index: int) -> bool:
	if index < handler.available_targets.size():
		handler.current_target_index = index
		return true
	return false

# ============================================
# UI表示ヘルパー
# ============================================

## ターゲット情報を日本語テキストに変換
## 
## target_data: ターゲット情報
## current_index: 現在のインデックス（1始まり）
## total_count: 総ターゲット数
## 戻り値: 表示用テキスト
static func format_target_info(target_data: Dictionary, current_index: int, total_count: int) -> String:
	var text = "対象を選択: [↑↓で切替]
"
	text += "対象 %d/%d: " % [current_index, total_count]
	
	# ターゲット情報表示
	match target_data.get("type", ""):
		"land":
			var tile_idx = target_data.get("tile_index", -1)
			var element = target_data.get("element", "neutral")
			var level = target_data.get("level", 1)
			var owner_id = target_data.get("owner", -1)
			
			# 属性名を日本語に変換
			var element_name = element
			match element:
				"fire": element_name = "火"
				"water": element_name = "水"
				"earth": element_name = "地"
				"wind": element_name = "風"
				"neutral": element_name = "無"
			
			var owner_id_text = ""
			if owner_id >= 0:
				owner_id_text = " (P%d)" % (owner_id + 1)
			
			text += "タイル%d %s Lv%d%s" % [tile_idx, element_name, level, owner_id_text]
		
		"creature":
			var tile_idx = target_data.get("tile_index", -1)
			var creature_name = target_data.get("creature", {}).get("name", "???")
			text += "タイル%d %s" % [tile_idx, creature_name]
		
		"player":
			var player_id = target_data.get("player_id", -1)
			text += "プレイヤー%d" % (player_id + 1)
	
	text += "
[Enter: 次へ] [C: 閉じる]"
	return text
