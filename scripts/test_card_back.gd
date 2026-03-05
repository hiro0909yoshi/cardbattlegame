extends Node3D

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var viewport = $SubViewport
	var card_mesh = $CardMesh
	
	# SubViewportのテクスチャをQuadMeshに重ねる
	var overlay_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.4, 3.6)
	overlay_mesh.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = viewport.get_texture()
	overlay_mesh.material_override = mat
	overlay_mesh.position = Vector3(0, 0, 0.01)  # 少し手前に
	add_child(overlay_mesh)
