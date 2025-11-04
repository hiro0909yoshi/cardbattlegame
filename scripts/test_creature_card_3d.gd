extends Node3D
## クリーチャーカード3D表示のテストシーン

@onready var camera = $Camera3D
@onready var test_tile = $TestTile

func _ready():
	print("=== CreatureCard3D Test Scene ===")
	
	# カメラ位置調整
	camera.position = Vector3(0, 5, 8)
	camera.look_at(Vector3.ZERO)
	
	# テスト用クリーチャーデータ
	var test_creature = {
		"id": 1,
		"name": "テストクリーチャー",
		"element": "火",
		"ap": 50,
		"hp": 50,
		"rarity": "rare"
	}
	
	# 2秒後にクリーチャーを配置
	await get_tree().create_timer(2.0).timeout
	print("クリーチャーを配置します...")
	test_tile.place_creature(test_creature)
	
	# 削除は無効化（コメントアウト）
	# await get_tree().create_timer(5.0).timeout
	# print("クリーチャーを削除します...")
	# test_tile.remove_creature()

func _input(event):
	# ESCキーでシーンを閉じる
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			get_tree().quit()

func _process(_delta):
	# カメラ操作
	var move_speed = 0.1
	var rotate_speed = 0.02
	
	# WASD で移動
	if Input.is_key_pressed(KEY_W):
		camera.position.z -= move_speed
	if Input.is_key_pressed(KEY_S):
		camera.position.z += move_speed
	if Input.is_key_pressed(KEY_A):
		camera.position.x -= move_speed
	if Input.is_key_pressed(KEY_D):
		camera.position.x += move_speed
	
	# QE で上下移動
	if Input.is_key_pressed(KEY_Q):
		camera.position.y += move_speed
	if Input.is_key_pressed(KEY_E):
		camera.position.y -= move_speed
	
	# 矢印キーで回転
	if Input.is_key_pressed(KEY_UP):
		camera.rotation.x += rotate_speed
	if Input.is_key_pressed(KEY_DOWN):
		camera.rotation.x -= rotate_speed
	if Input.is_key_pressed(KEY_LEFT):
		camera.rotation.y += rotate_speed
	if Input.is_key_pressed(KEY_RIGHT):
		camera.rotation.y -= rotate_speed
	
	# スペースキーでカメラをリセット
	if Input.is_key_pressed(KEY_SPACE):
		camera.position = Vector3(0, 5, 8)
		camera.look_at(Vector3.ZERO)
