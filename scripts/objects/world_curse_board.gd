extends StaticBody3D

# 世界刻印ボード — 現在有効な世界呪いのカードを3D表示
# クリックするとカード詳細情報を表示するシグナルを発火

signal clicked

const CARD_WIDTH: float = 0.9
const CARD_HEIGHT: float = 1.2
const CARD_Y_OFFSET: float = 1.7

@onready var info_label: Label3D = $InfoLabel

var _card_mesh: MeshInstance3D = null
var _card_material: StandardMaterial3D = null
var _current_card_id: int = 0


func _ready() -> void:
	input_event.connect(_on_input_event)
	if info_label:
		info_label.visible = false
	_setup_card_mesh()


func _setup_card_mesh() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	_card_mesh = MeshInstance3D.new()
	_card_mesh.mesh = quad
	_card_mesh.position = Vector3(0, CARD_Y_OFFSET, 0)
	_card_mesh.visible = false

	_card_material = StandardMaterial3D.new()
	_card_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_card_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_card_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_card_mesh.material_override = _card_material

	add_child(_card_mesh)


func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
	elif event is InputEventScreenTouch and event.pressed:
		clicked.emit()


## 表示更新: world_curse データを受け取り、カードを3D表示
## world_curse: {"curse_type": String, "name": String, "duration": int, "params": {"card_id": int, ...}}
func update_display(world_curse: Dictionary) -> void:
	if world_curse.is_empty():
		if _card_mesh:
			_card_mesh.visible = false
		_current_card_id = 0
		return

	var params: Dictionary = world_curse.get("params", {})
	var card_id: int = int(params.get("card_id", 0))
	if card_id <= 0:
		if _card_mesh:
			_card_mesh.visible = false
		return

	if card_id == _current_card_id and _card_mesh and _card_mesh.visible:
		return

	_current_card_id = card_id
	_load_card_texture(card_id)


func _load_card_texture(card_id: int) -> void:
	var cache: CardTextureCache = _get_card_texture_cache()
	if not cache:
		return

	var texture: ImageTexture = cache.get_card_texture_sync(card_id)
	if texture:
		_apply_texture(texture)
		return

	# 非同期レンダリング
	texture = await cache.prerender_card_async(card_id)
	if texture and card_id == _current_card_id:
		_apply_texture(texture)


func _apply_texture(texture: ImageTexture) -> void:
	if not _card_material or not _card_mesh:
		return
	_card_material.albedo_texture = texture
	_card_mesh.visible = true


func _get_card_texture_cache() -> CardTextureCache:
	var scene_root: Node = get_tree().root
	for child in scene_root.get_children():
		if child is CardTextureCache:
			return child
	var instance: CardTextureCache = CardTextureCache.new()
	instance.name = "CardTextureCache"
	scene_root.add_child(instance)
	return instance
