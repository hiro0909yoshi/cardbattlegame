extends Node3D
class_name CreatureCard3DSimple
## シンプルな3Dカード表示（Control3D方式）

var card_control: Control = null
var card_instance = null

const CARD_SCENE = preload("res://scenes/Card.tscn")

func _ready():
	_setup_card()

func _setup_card():
	print("[CreatureCard3DSimple] セットアップ開始")
	
	# SubViewportを作成（Containerは不要）
	var viewport = SubViewport.new()
	viewport.size = Vector2i(300, 400)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true  # 2D専用に設定
	add_child(viewport)
	
	# Cardをインスタンス化
	card_instance = CARD_SCENE.instantiate()
	card_instance.size = Vector2(300, 400)
	card_instance.position = Vector2.ZERO
	viewport.add_child(card_instance)
	
	# 次のフレームを待ってからSprite3Dにテクスチャを設定
	await get_tree().process_frame
	await get_tree().process_frame  # 2フレーム待つ
	
	# Sprite3Dを作成
	var sprite_3d = Sprite3D.new()
	sprite_3d.texture = viewport.get_texture()
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.pixel_size = 0.004
	sprite_3d.position = Vector3(0, 1.0, 0)
	
	# マテリアル設定
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # 両面表示
	sprite_3d.material_override = material
	
	add_child(sprite_3d)
	
	# 参照を保存
	card_control = card_instance
	
	print("[CreatureCard3DSimple] Sprite3D追加完了")
	print("[CreatureCard3DSimple] Texture: ", sprite_3d.texture)
	print("[CreatureCard3DSimple] Viewport size: ", viewport.size)

func set_creature_data(data: Dictionary):
	print("[CreatureCard3DSimple] set_creature_data: ", data)
	
	if not card_instance:
		print("[CreatureCard3DSimple] エラー: card_instanceがnull")
		return
	
	var creature_id = data.get("id", -1)
	if creature_id <= 0:
		print("[CreatureCard3DSimple] エラー: 無効なID")
		return
	
	# 次のフレームで読み込む
	await get_tree().process_frame
	
	if card_instance and card_instance.has_method("load_card_data"):
		print("[CreatureCard3DSimple] load_card_data呼び出し: ", creature_id)
		card_instance.load_card_data(creature_id)
	else:
		print("[CreatureCard3DSimple] エラー: load_card_dataメソッドなし")

func set_height(height: float):
	var sprite = get_child(0) if get_child_count() > 0 else null
	if sprite and sprite is Sprite3D:
		sprite.position.y = height
