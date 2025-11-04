extends Node3D
class_name CreatureCard3DQuad
## Quad Mesh方式の3Dカード表示

var viewport: SubViewport = null
var card_instance = null
var mesh_instance: MeshInstance3D = null

const CARD_SCENE = preload("res://scenes/Card.tscn")

func _ready():
	_setup_card()

func _setup_card():
	print("[CreatureCard3DQuad] セットアップ開始")
	
	# SubViewportを作成（大きめに）
	viewport = SubViewport.new()
	viewport.size = Vector2i(600, 800)  # より大きく
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)
	print("[CreatureCard3DQuad] Viewport作成完了")
	
	# Cardをインスタンス化してViewportいっぱいに広げる
	card_instance = CARD_SCENE.instantiate()
	card_instance.size = Vector2(600, 800)  # Viewportと同じサイズ
	card_instance.position = Vector2.ZERO
	card_instance.custom_minimum_size = Vector2(600, 800)
	viewport.add_child(card_instance)
	print("[CreatureCard3DQuad] Card追加完了")
	
	# カードのサイズを強制的に調整
	await get_tree().process_frame
	if card_instance:
		card_instance.size = Vector2(600, 800)
	
	# QuadMeshを作成
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(2.4, 3.6)  # カードのサイズ（横2.4m、縦3.6m）
	quad_mesh.center_offset = Vector3.ZERO  # 中心を原点に
	
	# MeshInstanceを作成
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = quad_mesh
	mesh_instance.position = Vector3(0, 3.0, 0)  # X=0, Y=3.0, Z=0（タイル中心の真上）
	# 回転なし = カメラに向く（Y軸に立つ）
	
	print("[CreatureCard3DQuad] Mesh位置: ", mesh_instance.position)
	
	# マテリアルを作成
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # カメラに向く
	
	# テクスチャを設定（次のフレームで）
	await get_tree().process_frame
	await get_tree().process_frame
	
	var texture = viewport.get_texture()
	material.albedo_texture = texture
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	
	print("[CreatureCard3DQuad] セットアップ完了")
	print("[CreatureCard3DQuad] Texture valid: ", texture != null)

func set_creature_data(data: Dictionary):
	print("[CreatureCard3DQuad] set_creature_data: ", data.get("name", "???"))
	
	if not card_instance:
		print("[CreatureCard3DQuad] エラー: card_instanceがnull")
		return
	
	var creature_id = data.get("id", -1)
	if creature_id <= 0:
		print("[CreatureCard3DQuad] エラー: 無効なID")
		return
	
	# 次のフレームで読み込む
	await get_tree().process_frame
	
	if card_instance and card_instance.has_method("load_card_data"):
		print("[CreatureCard3DQuad] load_card_data呼び出し: ", creature_id)
		card_instance.load_card_data(creature_id)
		
		# さらに次のフレームでテクスチャを再設定
		await get_tree().process_frame
		if mesh_instance and viewport:
			var material = mesh_instance.material_override as StandardMaterial3D
			if material:
				material.albedo_texture = viewport.get_texture()
				print("[CreatureCard3DQuad] テクスチャ再設定完了")
	else:
		print("[CreatureCard3DQuad] エラー: load_card_dataメソッドなし")

func set_height(height: float):
	if mesh_instance:
		mesh_instance.position.y = height
