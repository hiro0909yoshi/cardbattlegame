extends Node3D
class_name TileInfoDisplay

# タイル上の情報表示管理システム
# 通行料、HP、STを切り替えて表示

# 定数をpreload

# 表示モード
enum DisplayMode {
	TOLL,      # 通行料
	HP,        # クリーチャーHP
	AP         # クリーチャーAP（攻撃力）
}

# 現在の表示モード
var current_mode = DisplayMode.TOLL
var tile_labels = {}  # tile_index -> Label3D

# システム参照
var board_system_ref = null

func _ready():
	pass

# ラベルを初期化
func setup_labels(tile_nodes: Dictionary, board_system):
	board_system_ref = board_system
	
	for index in tile_nodes:
		var tile = tile_nodes[index]
		create_label_for_tile(tile, index)


## 単一タイル用のラベルを作成（地形変化時にも使用）
func create_label_for_tile(tile: Node, tile_index: int) -> Label3D:
	# 既存のラベルがあれば削除
	if tile_labels.has(tile_index):
		var old_label = tile_labels[tile_index]
		if is_instance_valid(old_label):
			old_label.queue_free()
		tile_labels.erase(tile_index)
	
	# Label3Dを作成
	var label = Label3D.new()
	label.name = "InfoLabel"
	label.text = ""
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false  # falseにして遠近感を有効に
	label.pixel_size = 0.02  # サイズ調整
	label.position = Vector3(0, -0.7, 0)  # タイルの上に配置
	label.modulate = Color.WHITE
	
	# フォント設定
	label.font_size = 70
	label.outline_size = 20
	label.outline_modulate = Color.BLACK
	
	tile.add_child(label)
	tile_labels[tile_index] = label
	
	return label


# 単一タイルの表示を更新
func update_display(tile_index: int, tile_info: Dictionary):
	if not tile_labels.has(tile_index):
		return
	
	var label = tile_labels[tile_index]
	
	# 特殊マスは表示しない
	if tile_info.get("is_special", false):
		label.visible = false
		return
	
	label.visible = true
	
	match current_mode:
		DisplayMode.TOLL:
			show_toll(label, tile_info, tile_index)
		DisplayMode.HP:
			show_hp(label, tile_info)
		DisplayMode.AP:
			show_ap(label, tile_info)

# 通行料表示
func show_toll(label: Label3D, tile_info: Dictionary, tile_index: int):
	# 所有者がいない、またはクリーチャーがいない場合は非表示
	if tile_info.get("owner", -1) == -1 or not tile_info.get("has_creature", false):
		label.visible = false
	else:
		var toll = calculate_display_toll(tile_info, tile_index)
		if toll > 0:
			label.text = str(toll)
			label.modulate = _get_owner_color(tile_info)
			label.visible = true
		else:
			label.visible = false

# HP表示
func show_hp(label: Label3D, tile_info: Dictionary):
	var creature = tile_info.get("creature", {})
	if creature.is_empty():
		label.visible = false
	else:
		# current_hpがあれば使用、なければ基礎HPを表示
		var hp = creature.get("current_hp", creature.get("hp", 0))
		label.text = "HP:" + str(hp)
		label.modulate = _get_owner_color(tile_info)
		label.visible = true

# AP表示（攻撃力）
func show_ap(label: Label3D, tile_info: Dictionary):
	var creature = tile_info.get("creature", {})
	if creature.is_empty():
		label.visible = false
	else:
		var ap = creature.get("ap", 0)
		label.text = "AP:" + str(ap)
		label.modulate = _get_owner_color(tile_info)
		label.visible = true

# 通行料を計算
func calculate_display_toll(tile_info: Dictionary, tile_index: int) -> int:
	if not board_system_ref:
		return 0
	
	# BoardSystem3Dの計算メソッドを使用
	if board_system_ref.has_method("calculate_toll"):
		return board_system_ref.calculate_toll(tile_index)
	
	# フォールバック計算（土地価値ベース）
	var level = tile_info.get("level", 1)
	var base_value = GameConstants.BASE_LAND_VALUE
	var level_mult = GameConstants.LAND_VALUE_LEVEL_MULTIPLIER.get(level, 1)
	var toll_mult = GameConstants.TOLL_LEVEL_MULTIPLIER.get(level, 0.2)
	return GameConstants.floor_toll(base_value * level_mult * toll_mult)

# タイル所有者のプレイヤーカラーを取得
func _get_owner_color(tile_info: Dictionary) -> Color:
	var owner_id = tile_info.get("owner", -1)
	if owner_id >= 0 and owner_id < GameConstants.PLAYER_COLORS.size():
		return GameConstants.PLAYER_COLORS[owner_id]
	return Color.WHITE

# 表示モードを切り替え
func switch_mode():
	current_mode = DisplayMode.values()[(current_mode + 1) % 3]
	
	var mode_names = ["通行料", "HP", "AP"]
	print("表示モード切替: ", mode_names[current_mode])
	
	# 全タイル更新
	refresh_all_displays()

# 現在のモードを取得
func get_current_mode_name() -> String:
	match current_mode:
		DisplayMode.TOLL:
			return "通行料"
		DisplayMode.HP:
			return "HP"
		DisplayMode.AP:
			return "AP"
		_:
			return "不明"

# 全タイルの表示を更新
func refresh_all_displays():
	if not board_system_ref:
		return
	
	for index in tile_labels:
		var tile_info = board_system_ref.get_tile_info(index)
		update_display(index, tile_info)

# 特定のモードに設定
func set_mode(mode: DisplayMode):
	current_mode = mode
	refresh_all_displays()

# クリーンアップ
func cleanup():
	for label in tile_labels.values():
		if label and is_instance_valid(label):
			label.queue_free()
	tile_labels.clear()
