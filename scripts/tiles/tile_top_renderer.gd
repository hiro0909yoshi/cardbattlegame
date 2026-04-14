extends Node3D
class_name TileTopRenderer

# 4属性タイルの上面テクスチャをMultiMeshで一括描画（属性ごとに1 draw call）
# 属性タイルの _ready/_exit_tree から register/unregister される

const PLANE_MESH: PlaneMesh = preload("res://scenes/Tiles/tile_top_plane.tres")
const MATERIALS: Dictionary = {
	"fire": preload("res://scenes/Tiles/fire_tile_mat.tres"),
	"water": preload("res://scenes/Tiles/water_tile_mat.tres"),
	"earth": preload("res://scenes/Tiles/earth_tile_mat.tres"),
	"wind": preload("res://scenes/Tiles/wind_tile_mat.tres"),
	"neutral": preload("res://scenes/Tiles/neutral_tile_mat.tres"),
}
const TOP_Y_OFFSET: float = 0.314

var _mmis: Dictionary = {}  # element -> MultiMeshInstance3D
var _tiles: Dictionary = {}  # element -> Array[Node3D]
var _rebuild_scheduled: bool = false

func _ready():
	for element in MATERIALS.keys():
		var mmi = MultiMeshInstance3D.new()
		mmi.name = "MMI_" + element
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# 属性ごとにマテリアル付きPlaneMeshを複製（MultiMeshはmesh.materialを使用）
		var plane := PLANE_MESH.duplicate() as PlaneMesh
		plane.material = MATERIALS[element]
		mm.mesh = plane
		mmi.multimesh = mm
		# 視錐台カリング回避（全インスタンスが常に描画対象になるよう大きめのAABB）
		mmi.custom_aabb = AABB(Vector3(-1000, -100, -1000), Vector3(2000, 200, 2000))
		add_child(mmi)
		_mmis[element] = mmi
		_tiles[element] = []

## 既存シーンツリー内の属性タイルを一括登録（初期化が遅い場合の救済）
func register_existing_tiles(root: Node) -> void:
	_scan_and_register(root)

func _scan_and_register(node: Node) -> void:
	if node is BaseTile and _tiles.has(node.tile_type):
		register(node, node.tile_type)
	for child in node.get_children():
		_scan_and_register(child)

func register(tile: Node3D, element: String) -> void:
	if not _tiles.has(element):
		return
	var arr: Array = _tiles[element]
	if not arr.has(tile):
		arr.append(tile)
		_schedule_rebuild()

func unregister(tile: Node3D, element: String) -> void:
	if not _tiles.has(element):
		return
	_tiles[element].erase(tile)
	_schedule_rebuild()

func _schedule_rebuild() -> void:
	if _rebuild_scheduled:
		return
	_rebuild_scheduled = true
	call_deferred("_rebuild")

func _rebuild() -> void:
	_rebuild_scheduled = false
	for element in _tiles.keys():
		var arr: Array = _tiles[element]
		var mmi: MultiMeshInstance3D = _mmis[element]
		var mm: MultiMesh = mmi.multimesh
		mm.instance_count = arr.size()
		for i in arr.size():
			var tile: Node3D = arr[i]
			if not is_instance_valid(tile):
				continue
			var t := tile.global_transform
			t.origin.y += TOP_Y_OFFSET
			mm.set_instance_transform(i, t)
