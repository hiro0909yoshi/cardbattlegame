extends Node3D
class_name CreatureCard3DQuad
## Quad Mesh方式の3Dカード表示

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

var viewport: SubViewport = null
var card_instance = null
var mesh_instance: MeshInstance3D = null

const CARD_SCENE = preload("res://scenes/Card.tscn")

func _ready():
	_setup_card()

func _setup_card():
	
	# SubViewport作成（CardFrameと同じサイズ）
	viewport = SubViewport.new()
	viewport.size = Vector2i(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)  # 220x293
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)
	
	# Cardをインスタンス化してリサイズ
	card_instance = CARD_SCENE.instantiate()
	viewport.add_child(card_instance)
	
	# サイズを設定（CardFrame 220x293と同じ）
	card_instance.position = Vector2.ZERO
	card_instance.size = Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	card_instance.custom_minimum_size = Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	
	# 子要素のレイアウトを新しいサイズに合わせる
	if card_instance.has_method("_adjust_children_size"):
		card_instance.adjust_children_size()
	
	# QuadMeshを作成
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(CARD_3D_WIDTH, CARD_3D_HEIGHT)
	quad_mesh.center_offset = Vector3.ZERO
	
	# MeshInstanceを作成
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = quad_mesh
	mesh_instance.position = Vector3(0, CARD_3D_Y_POSITION, 0)
	

	
	# マテリアルを作成
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	# テクスチャを設定（次のフレームで）
	await get_tree().process_frame
	await get_tree().process_frame

	var texture = viewport.get_texture()
	material.albedo_texture = texture
	mesh_instance.material_override = material

	add_child(mesh_instance)
	


func set_creature_data(data: Dictionary):
	if not card_instance:
		return
	
	var creature_id = data.get("id", -1)
	if creature_id <= 0:
		return
	
	# 次のフレームで読み込む
	await get_tree().process_frame
	
	if card_instance and card_instance.has_method("load_card_data"):
		card_instance.load_card_data(creature_id)
		
		# テクスチャ更新
		await get_tree().process_frame
		if mesh_instance and viewport:
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_texture = viewport.get_texture()

# クリーチャーデータを更新（バトル中の変更を反映）
func update_creature_data(data: Dictionary):
	if not card_instance:
		return
	
	if data.is_empty():
		return
	
	# 動的データを反映
	if card_instance.has_method("load_dynamic_creature_data"):
		card_instance.load_dynamic_creature_data(data)
		
		# テクスチャ更新
		await get_tree().process_frame
		if mesh_instance and viewport:
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_texture = viewport.get_texture()

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
