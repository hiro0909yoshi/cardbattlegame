extends SubViewportContainer

## キャラクター3Dモデルをプレビュー表示するコンポーネント
## SubViewport + Camera3D で3Dモデルを撮影し、2DのUIに表示する

var _sub_viewport: SubViewport = null
var _camera: Camera3D = null
var _light: DirectionalLight3D = null
var _model_root: Node3D = null
var _current_model: Node = null


func _ready():
	_setup_viewport()


func _setup_viewport():
	# SubViewport
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(800, 900)
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sub_viewport)

	# 環境光
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.4)

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_sub_viewport.add_child(world_env)

	# カメラ
	_camera = Camera3D.new()
	_camera.transform.origin = Vector3(0, 2.0, 10.0)
	_camera.fov = 23
	_sub_viewport.add_child(_camera)
	_camera.look_at(Vector3(0, 1.8, 0))

	# ライト
	_light = DirectionalLight3D.new()
	_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-30)) * Basis(Vector3(0, 1, 0), deg_to_rad(30))
	_light.light_energy = 1.2
	_sub_viewport.add_child(_light)

	# モデルルート
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	_sub_viewport.add_child(_model_root)

	# stretch設定
	stretch = true


## モデルパスからキャラクターを表示
func set_character_model(model_path: String) -> void:
	# 既存モデルを削除
	if _current_model:
		_current_model.queue_free()
		_current_model = null

	if model_path == "":
		return

	var scene = load(model_path)
	if not scene:
		return

	_current_model = scene.instantiate()
	_model_root.add_child(_current_model)

	# FBX内のCamera/Lightを非表示
	_hide_fbx_extras(_current_model)

	# IdleModelを表示、WalkModelを非表示
	var idle_model = _current_model.find_child("IdleModel", false, false)
	var walk_model = _current_model.find_child("WalkModel", false, false)
	if idle_model:
		idle_model.visible = true
		# Idleアニメーションを再生してポーズを適用
		var anim_player = idle_model.find_child("AnimationPlayer", true, false)
		if anim_player:
			for anim_name in anim_player.get_animation_list():
				if anim_name != "RESET":
					anim_player.play(anim_name)
					anim_player.seek(0.0, true)
					break
	if walk_model:
		walk_model.visible = false

	# アニメーション適用後にキャプチャ（数フレーム待つ）
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# アニメーション停止して静止画化
	if idle_model:
		var anim_player = idle_model.find_child("AnimationPlayer", true, false)
		if anim_player:
			anim_player.pause()
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


## 選択中キャラクターを表示（GameDataから取得）
func set_selected_character() -> void:
	var model_path = GameData.get_selected_character_model_path()
	set_character_model(model_path)


## FBX内の不要なCamera/Lightを非表示
func _hide_fbx_extras(node: Node) -> void:
	for child in node.get_children():
		if child is Camera3D or child is Light3D:
			child.visible = false
		if child.get_child_count() > 0:
			_hide_fbx_extras(child)
