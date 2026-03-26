extends CharacterBody3D

## モデルの緑色部分だけを赤に置換する

const SHADER_PATH = "res://scripts/characters/green_to_red.gdshader"

func _ready():
	_apply_color_swap($WalkModel)
	_apply_color_swap($IdleModel)


func _apply_color_swap(model: Node) -> void:
	for child in model.get_children():
		if child is MeshInstance3D:
			_swap_mesh(child)
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D:
				_swap_mesh(grandchild)


func _swap_mesh(mesh_instance: MeshInstance3D) -> void:
	var shader = load(SHADER_PATH) as Shader
	for i in range(mesh_instance.get_surface_override_material_count()):
		var original = mesh_instance.mesh.surface_get_material(i)
		if original is StandardMaterial3D and original.albedo_texture:
			var shader_mat = ShaderMaterial.new()
			shader_mat.shader = shader
			shader_mat.set_shader_parameter("albedo_texture", original.albedo_texture)
			mesh_instance.set_surface_override_material(i, shader_mat)
