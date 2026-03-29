extends Node3D
class_name CreatureCard3DQuad
## Quad Mesh方式の3Dカード表示（CardTextureCache使用）

# ============================================
# 👇 3Dカード表示設定（ここだけ調整すればOK）👇
# ============================================
const CARD_3D_WIDTH = 2.4         # 3D空間でのカード幅（メートル）
const CARD_3D_HEIGHT = 3.6        # 3D空間でのカード高さ（メートル）
const CARD_3D_Y_POSITION = 3.0    # タイルからの高さ（メートル）

# Card.tscnの実サイズ（CardFrame.tscn）
const CARDFRAME_WIDTH = 220
const CARDFRAME_HEIGHT = 293

# 3D表示用のViewportサイズ（CardFrameと同じ）
const VIEWPORT_WIDTH = CARDFRAME_WIDTH   # 220
const VIEWPORT_HEIGHT = CARDFRAME_HEIGHT  # 293
# ============================================

var mesh_instance: MeshInstance3D = null
var material: StandardMaterial3D = null

func _ready():
	_setup_card()

func _setup_card():
	# QuadMeshを作成
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(CARD_3D_WIDTH, CARD_3D_HEIGHT)
	quad_mesh.center_offset = Vector3.ZERO

	# MeshInstanceを作成
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = quad_mesh
	mesh_instance.position = Vector3(0, CARD_3D_Y_POSITION, 0)

	# マテリアルを作成
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	# Placeholder texture will be set when set_creature_data is called
	mesh_instance.material_override = material

	add_child(mesh_instance)
	


func set_creature_data(data: Dictionary):
	var creature_id = data.get("id", -1)
	if creature_id <= 0:
		return

	# Get or render card texture from cache
	var cache = _get_card_texture_cache_instance()
	if not cache:
		push_error("[CreatureCard3DQuad] Failed to get CardTextureCache instance")
		return

	var texture = cache.get_card_texture_sync(creature_id)
	if not texture:
		# Not cached yet - render asynchronously
		texture = await cache.prerender_card_async(creature_id)

	if texture and material:
		material.albedo_texture = texture

# クリーチャーデータを更新（バトル中の変更を反映）
# Note: Dynamic updates are reflected in the cached texture if needed
# For now, we just use the existing cached texture
func update_creature_data(data: Dictionary):
	if data.is_empty():
		return

	# The cached texture is already updated by CardTextureCache if needed
	# If you need to invalidate and re-render for dynamic changes, uncomment:
	# var creature_id = data.get("id", -1)
	# if creature_id > 0:
	#     var cache = _get_card_texture_cache_instance()
	#     cache.invalidate(creature_id)
	#     var texture = await cache.prerender_card_async(creature_id)
	#     if texture and material:
	#         material.albedo_texture = texture

## Internal: Get the global CardTextureCache instance (create if needed)
var _cache_instance = null
func _get_card_texture_cache_instance():
	if _cache_instance and is_instance_valid(_cache_instance):
		return _cache_instance

	# Try to find existing instance in scene tree
	var scene_root = get_tree().root
	for child in scene_root.get_children():
		if child is CardTextureCache:
			_cache_instance = child
			return _cache_instance

	# Create new instance if not found
	_cache_instance = CardTextureCache.new()
	_cache_instance.name = "CardTextureCache"
	scene_root.add_child(_cache_instance)
	return _cache_instance

func set_height(height: float):
	if mesh_instance:
		mesh_instance.position.y = height


## 半透明化（ターゲット選択時に他タイルのカードを薄くする）
func set_transparency(alpha: float) -> void:
	if not mesh_instance:
		return
	var mat = mesh_instance.material_override as StandardMaterial3D
	if not mat:
		return
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, alpha)
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color = Color(1, 1, 1, 1)
