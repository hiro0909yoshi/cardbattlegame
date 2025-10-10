extends Node3D
class_name TileInfoDisplay

# タイル上の情報表示管理システム
# 通行料、HP、STを切り替えて表示

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")

# 表示モード
enum DisplayMode {
	TOLL,      # 通行料
	HP,        # クリーチャーHP
	ST         # クリーチャーST
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
		
		# Label3Dを作成
		var label = Label3D.new()
		label.name = "InfoLabel"
		label.text = ""
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false  # falseにして遠近感を有効に
		label.pixel_size = 0.005  # サイズ調整
		label.position = Vector3(0, 0.5, 1.5)  # タイルの上に配置
		label.modulate = Color.WHITE
		
		# フォント設定
		label.font_size = 70
		label.outline_size = 8
		label.outline_modulate = Color.BLACK
		
		tile.add_child(label)
		tile_labels[index] = label
	
	print("TileInfoDisplay: ", tile_labels.size(), "個のラベルを作成")

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
		DisplayMode.ST:
			show_st(label, tile_info)

# 通行料表示
func show_toll(label: Label3D, tile_info: Dictionary, tile_index: int):
	if tile_info.get("owner", -1) == -1:
		label.visible = false
	else:
		var toll = calculate_display_toll(tile_info, tile_index)
		if toll > 0:
			label.text = str(toll) + "G"
			label.modulate = Color(1.0, 0.9, 0.3)  # 金色
			label.visible = true
		else:
			label.visible = false

# HP表示
func show_hp(label: Label3D, tile_info: Dictionary):
	var creature = tile_info.get("creature", {})
	if creature.is_empty():
		label.visible = false
	else:
		var hp = creature.get("block", 0)
		label.text = "HP:" + str(hp)
		label.modulate = Color(0.3, 1.0, 0.3)  # 緑
		label.visible = true

# ST表示
func show_st(label: Label3D, tile_info: Dictionary):
	var creature = tile_info.get("creature", {})
	if creature.is_empty():
		label.visible = false
	else:
		var st = creature.get("damage", 0)
		label.text = "ST:" + str(st)
		label.modulate = Color(1.0, 0.3, 0.3)  # 赤
		label.visible = true

# 通行料を計算
func calculate_display_toll(tile_info: Dictionary, tile_index: int) -> int:
	if not board_system_ref:
		return 0
	
	# BoardSystem3Dの計算メソッドを使用
	if board_system_ref.has_method("calculate_toll"):
		return board_system_ref.calculate_toll(tile_index)
	
	# フォールバック計算
	var level = tile_info.get("level", 1)
	var base_toll = GameConstants.BASE_TOLL
	return base_toll * level

# 表示モードを切り替え
func switch_mode():
	current_mode = DisplayMode.values()[(current_mode + 1) % 3]
	
	var mode_names = ["通行料", "HP", "ST"]
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
		DisplayMode.ST:
			return "ST"
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
