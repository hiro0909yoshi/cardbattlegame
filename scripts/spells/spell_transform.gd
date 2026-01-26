class_name SpellTransform

## クリーチャー変身処理モジュール
##
## スペル・アルカナアーツによる変身効果を処理する
##
## 使用方法:
## ```gdscript
## var spell_transform = SpellTransform.new(board_system, player_system, card_system)
## var result = await spell_transform.apply_effect(effect, target_data, caster_player_id)
## ```
##
## 対応するeffect_type:
## - transform: クリーチャーを別のクリーチャーに変身させる
##
## 変身タイプ:
## - transform_to (固定ID変身): ability_parsed.transform_to にIDを指定
## - copy_target (対象コピー): 選択した対象と同じクリーチャーに変身
## - same_element_defensive: 同属性の防御型クリーチャーに変身
## - to_goblin: ゴブリンに変身


# ============ 参照 ============

var board_system_ref: Object
var player_system_ref: Object
var card_system_ref: Object
var spell_phase_handler_ref: Object

# ゴブリンのID（固定）
const GOBLIN_ID = 414


# ============ 初期化 ============

func _init(board_sys: Object, player_sys: Object, card_sys: Object, spell_phase_handler: Object = null) -> void:
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler


# ============ メイン効果適用 ============

## 効果を適用（effect_typeに応じて分岐）
func apply_effect(effect: Dictionary, target_data: Dictionary, caster_player_id: int) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"transform":
			return _apply_transform(effect, target_data, caster_player_id)
		_:
			push_error("[SpellTransform] 未対応のeffect_type: %s" % effect_type)
			return {"success": false, "reason": "unknown_effect_type"}


# ============ 変身効果実装 ============

## 変身効果を適用
func _apply_transform(effect: Dictionary, target_data: Dictionary, _caster_player_id: int) -> Dictionary:
	var target = effect.get("target", "self")  # self: アルカナアーツ使用者, target: 選択対象
	var transform_to = effect.get("transform_to", -1)  # 固定ID変身
	var transform_type = effect.get("transform_type", "")  # 変身タイプ
	
	# アルカナアーツ使用者のタイルを取得
	var caster_tile_index = target_data.get("caster_tile_index", -1)
	
	# 変身対象のタイルを決定
	var transform_tile_index = -1
	if target == "self":
		# 自分自身を変身（アルカナアーツ使用者のタイル）
		transform_tile_index = caster_tile_index
	else:
		# 選択した対象を変身
		transform_tile_index = target_data.get("tile_index", -1)
	
	if transform_tile_index == -1:
		return {"success": false, "reason": "invalid_tile"}
	
	var tile = board_system_ref.tile_nodes.get(transform_tile_index)
	if not tile or tile.creature_data.is_empty():
		return {"success": false, "reason": "no_creature"}
	
	var old_creature = tile.creature_data
	var old_name = old_creature.get("name", "不明")
	
	# 変身先のクリーチャーIDを決定
	var new_creature_id = -1
	
	if transform_to > 0:
		# 固定ID変身
		new_creature_id = transform_to
	elif transform_type != "":
		# 変身タイプに応じて決定
		match transform_type:
			"copy_target":
				# 対象コピー変身（シェイプシフター）
				var copy_tile_index = target_data.get("tile_index", -1)
				new_creature_id = _get_copy_target_id(copy_tile_index)
			"same_element_defensive":
				# 同属性の防御型クリーチャーに変身（ターンウォール）
				var element = old_creature.get("element", "neutral")
				new_creature_id = _get_same_element_defensive_id(element)
			"to_goblin":
				# ゴブリンに変身（ディスコード）
				new_creature_id = GOBLIN_ID
			_:
				push_error("[SpellTransform] 未対応のtransform_type: %s" % transform_type)
				return {"success": false, "reason": "unknown_transform_type"}
	else:
		return {"success": false, "reason": "no_transform_target_specified"}
	
	if new_creature_id <= 0:
		return {"success": false, "reason": "invalid_new_creature_id"}
	
	# 変身先のクリーチャーデータを取得
	var new_creature = CardLoader.get_card_by_id(new_creature_id)
	if not new_creature:
		push_error("[SpellTransform] クリーチャーが見つかりません: ID %d" % new_creature_id)
		return {"success": false, "reason": "creature_not_found"}
	
	var new_name = new_creature.get("name", "不明")
	
	# 変身を実行
	_execute_transform(tile, old_creature, new_creature)
	
	print("[SpellTransform] %s → %s に変身 (タイル%d)" % [old_name, new_name, transform_tile_index])
	
	return {
		"success": true,
		"tile_index": transform_tile_index,
		"old_creature": old_name,
		"new_creature": new_name,
		"new_creature_id": new_creature_id
	}


## 変身を実行（タイル上のクリーチャーを置き換え）
func _execute_transform(tile: Object, old_creature: Dictionary, new_creature: Dictionary) -> void:
	# 引き継ぐ情報を保存
	var current_items = old_creature.get("items", [])
	var base_up_hp = old_creature.get("base_up_hp", 0)
	var base_up_ap = old_creature.get("base_up_ap", 0)
	var tile_owner_id = tile.owner_id
	
	# 新しいクリーチャーデータを作成
	# 注意: 呪い(curses)は引き継がない（変身で消える）
	var transformed_creature = new_creature.duplicate(true)
	
	# アイテムを引き継ぐ
	if not current_items.is_empty():
		transformed_creature["items"] = current_items
	
	# 永続ボーナスを引き継ぐ
	transformed_creature["base_up_hp"] = base_up_hp
	transformed_creature["base_up_ap"] = base_up_ap
	
	# HPを計算（基礎HP + 永続ボーナス）
	var base_hp = new_creature.get("hp", 0)
	transformed_creature["current_hp"] = base_hp + base_up_hp
	
	# 既存クリーチャーを削除してから新しいクリーチャーを配置
	var tile_index = _get_tile_index(tile)
	if tile_index >= 0:
		board_system_ref.remove_creature(tile_index)
		board_system_ref.place_creature(tile_index, transformed_creature, tile_owner_id)
	
	# ダウン状態にする（アルカナアーツ使用後）
	if tile.has_method("set_down_state"):
		tile.set_down_state(true)


## タイルからインデックスを取得
func _get_tile_index(tile: Object) -> int:
	for index in board_system_ref.tile_nodes:
		if board_system_ref.tile_nodes[index] == tile:
			return index
	return -1


# ============ 変身先ID取得 ============

## 対象コピー変身のID取得（シェイプシフター用）
func _get_copy_target_id(target_tile_index: int) -> int:
	if target_tile_index == -1:
		return -1
	
	var target_tile = board_system_ref.tile_nodes.get(target_tile_index)
	if not target_tile or target_tile.creature_data.is_empty():
		return -1
	
	return target_tile.creature_data.get("id", -1)


## 同属性の防御型クリーチャーIDを取得（ターンウォール用）
func _get_same_element_defensive_id(element: String) -> int:
	# 属性ごとに固定の防御型クリーチャーを返す
	const DEFENSIVE_CREATURES = {
		"fire": 5,       # オールドウィロウ
		"water": 102,    # アイスウォール
		"earth": 222,    # ストーンウォール
		"wind": 330,     # トルネード
		"neutral": 421   # スタチュー
	}
	
	if DEFENSIVE_CREATURES.has(element):
		return DEFENSIVE_CREATURES[element]
	
	push_warning("[SpellTransform] 属性 %s の防御型クリーチャーが定義されていません" % element)
	return -1


# ============ 複数対象変身（ディスコード用） ============

## 最多配置クリーチャー種を全てゴブリンに変身
func apply_discord_transform(_caster_player_id: int) -> Dictionary:
	# 全クリーチャーをカウント
	var creature_counts = {}  # {creature_id: {count, name, tiles}}
	
	for tile_index in board_system_ref.tile_nodes:
		var tile = board_system_ref.tile_nodes[tile_index]
		if tile.creature_data.is_empty():
			continue
		
		var creature_id = tile.creature_data.get("id", -1)
		var creature_name = tile.creature_data.get("name", "不明")
		
		if creature_id == GOBLIN_ID:
			continue  # ゴブリンは対象外
		
		if not creature_counts.has(creature_id):
			creature_counts[creature_id] = {"count": 0, "name": creature_name, "tiles": []}
		
		creature_counts[creature_id]["count"] += 1
		creature_counts[creature_id]["tiles"].append(tile_index)
	
	if creature_counts.is_empty():
		return {"success": false, "reason": "no_valid_creatures"}
	
	# 最多配置数を見つける
	var max_count = 0
	for id in creature_counts:
		if creature_counts[id]["count"] > max_count:
			max_count = creature_counts[id]["count"]
	
	# 最多配置クリーチャー種を抽出（複数ある場合も含む）
	var max_creatures = []
	for id in creature_counts:
		if creature_counts[id]["count"] == max_count:
			max_creatures.append({"id": id, "data": creature_counts[id]})
	
	if max_creatures.is_empty():
		return {"success": false, "reason": "no_max_creatures"}
	
	# 最多配置クリーチャーが複数種類ある場合はランダムに1種類選択
	var random_index = randi() % max_creatures.size()
	var selected = max_creatures[random_index]
	var target_creature_name = selected["data"]["name"]
	var target_tiles = selected["data"]["tiles"]
	
	# ゴブリンのデータを取得
	var goblin_data = CardLoader.get_card_by_id(GOBLIN_ID)
	if not goblin_data:
		return {"success": false, "reason": "goblin_data_not_found"}
	
	# 全対象を変身
	var transformed_count = 0
	for tile_index in target_tiles:
		var tile = board_system_ref.tile_nodes.get(tile_index)
		if tile and not tile.creature_data.is_empty():
			_execute_transform(tile, tile.creature_data, goblin_data)
			transformed_count += 1
	
	print("[SpellTransform] ディスコード: %s を %d体ゴブリンに変身" % [target_creature_name, transformed_count])
	
	return {
		"success": true,
		"target_creature": target_creature_name,
		"transformed_count": transformed_count
	}
