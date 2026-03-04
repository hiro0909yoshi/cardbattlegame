## 3Dタイルメッシュの頂点高さに応じた頂点カラー設定ユーティリティ
extends Node
class_name TileMeshColorizer

## 頂点のY座標（高さ）に基づいてメッシュに頂点カラーを設定する
## high_color: 盛り上がっている部分の色
## low_color: 平面部分の色
## threshold: 高低を分ける閾値（0.0〜1.0、高さ範囲に対する割合）
static func colorize_by_height(mesh_instance: MeshInstance3D, high_color: Color, low_color: Color, threshold: float = 0.3) -> void:
	var mesh: Mesh = mesh_instance.mesh
	if not mesh:
		push_error("[TileMeshColorizer] MeshInstance3Dにメッシュがありません")
		return

	var array_mesh := ArrayMesh.new()

	for surface_idx in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_idx)
		if arrays.is_empty():
			continue

		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var uvs = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()

		# Y座標の最小・最大値を取得
		var y_min := INF
		var y_max := -INF
		for v in vertices:
			y_min = minf(y_min, v.y)
			y_max = maxf(y_max, v.y)

		var y_range := y_max - y_min
		if y_range < 0.001:
			y_range = 1.0

		# 高さに応じて頂点カラーを設定
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for i in range(vertices.size()):
			var normalized_height := (vertices[i].y - y_min) / y_range
			if normalized_height > threshold:
				colors[i] = high_color
			else:
				colors[i] = low_color

		# 新しいsurface配列を構築
		var new_arrays := []
		new_arrays.resize(Mesh.ARRAY_MAX)
		new_arrays[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			new_arrays[Mesh.ARRAY_NORMAL] = normals
		if not uvs.is_empty():
			new_arrays[Mesh.ARRAY_TEX_UV] = uvs
		new_arrays[Mesh.ARRAY_COLOR] = colors

		# インデックスがあればコピー
		if arrays[Mesh.ARRAY_INDEX]:
			new_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]

		var primitive_type: int = mesh.surface_get_primitive_type(surface_idx)
		array_mesh.add_surface_from_arrays(primitive_type, new_arrays)

		# マテリアル設定（金色メタリック）
		var new_mat := StandardMaterial3D.new()
		new_mat.vertex_color_use_as_albedo = true
		new_mat.metallic = 0.8
		new_mat.metallic_specular = 0.9
		new_mat.roughness = 0.25
		array_mesh.surface_set_material(surface_idx, new_mat)

	mesh_instance.mesh = array_mesh
