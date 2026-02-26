extends Node
class_name QuestGame

# クエストモード用ゲーム管理スクリプト
# StageLoaderからデータを読み込み、動的にゲームを構築

# システム参照を preload
const GameSystemManagerClass = preload("res://scripts/system_manager/game_system_manager.gd")

var system_manager: GameSystemManager
var stage_loader: StageLoader

# ステージID（GameDataから取得、またはデフォルト）
var stage_id: String = "stage_1_1"

# 設定（StageLoaderから取得）
var player_count: int = 2
var player_is_cpu: Array = [false, true]

func _ready():
	# クエストモードでは常にCPUはAI任せ
	DebugSettings.manual_control_all = false

	# GameDataからステージIDを取得
	if GameData.selected_stage_id != "":
		stage_id = GameData.selected_stage_id

	# StageLoaderを作成
	stage_loader = StageLoader.new()
	stage_loader.name = "StageLoader"
	add_child(stage_loader)

	# ステージを読み込み
	var stage_data = stage_loader.load_stage(stage_id)
	if stage_data.is_empty():
		push_error("[QuestGame] ステージ読み込み失敗: " + stage_id)
		return

	# 設定を取得
	player_count = stage_loader.get_player_count()
	player_is_cpu = stage_loader.get_player_is_cpu()

	print("[QuestGame] ステージ: %s, プレイヤー数: %d" % [stage_id, player_count])

	# 3Dシーンを事前に構築（GameSystemManager が収集できるように）
	_setup_3d_scene_before_init()

	# GameSystemManagerを作成・初期化
	system_manager = GameSystemManagerClass.new()
	add_child(system_manager)

	system_manager.initialize_all(
		self,
		player_count,
		player_is_cpu,
		DebugSettings.manual_control_all
	)
	
	# ステージ固有の設定を適用
	_apply_stage_settings()
	
	# ゲーム開始待機
	await get_tree().create_timer(0.5).timeout
	
	# ゲーム開始
	system_manager.start_game()
	
	# CPUのバトルポリシーを設定（start_game後にCPUTurnProcessorが初期化される）
	_setup_cpu_battle_policies()

## 3Dシーンを事前構築（タイル・プレイヤー・カメラ）
func _setup_3d_scene_before_init():
	# カメラ作成
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.transform = Transform3D(
		Basis(Vector3(1, 0, 0), Vector3(0, 0.707107, 0.707107), Vector3(0, -0.707107, 0.707107)),
		Vector3(0, 10, 10)
	)
	camera.top_level = true
	add_child(camera)
	
	# ライト作成
	var light = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.transform = Transform3D(
		Basis(Vector3(0.707107, 0.5, -0.5), Vector3(0, 0.707107, 0.707107), Vector3(0.707107, -0.5, 0.5)),
		Vector3(-50, 50, 0)
	)
	add_child(light)
	
	# タイルコンテナ作成
	var tiles_container = Node3D.new()
	tiles_container.name = "Tiles"
	add_child(tiles_container)
	
	# StageLoaderでマップ生成
	stage_loader.set_tiles_container(tiles_container)
	stage_loader.generate_map()
	
	# プレイヤーコンテナ作成
	var players_container = Node3D.new()
	players_container.name = "Players"
	add_child(players_container)
	
	# プレイヤーキャラクター作成
	_create_player_characters(players_container)

## プレイヤーキャラクター作成
func _create_player_characters(container: Node3D):
	# プレイヤー1（Mario）
	var mario_scene = load("res://scenes/Characters/Necromancer.tscn")
	if mario_scene:
		var mario = mario_scene.instantiate()
		mario.name = "Player"
		var movement_script = load("res://scripts/player_movement.gd")
		if movement_script:
			mario.set_script(movement_script)
		container.add_child(mario)
		# 初期状態でIdleアニメーション再生
		_setup_initial_animation(mario)
	
	# CPU敵（新旧形式両対応）
	var enemies = stage_loader.get_enemies()
	for i in range(enemies.size()):
		var char_data = stage_loader.get_enemy_character(i)
		var model_path = char_data.get("model_path", "res://scenes/Characters/Necromancer.tscn")
		var enemy_scene = load(model_path)
		if enemy_scene:
			var enemy = enemy_scene.instantiate()
			enemy.name = "Player%d" % (i + 2)
			container.add_child(enemy)
			_setup_initial_animation(enemy)

## 初期アニメーション設定（WalkModelのアニメーションをIdleModelに統合）
func _setup_initial_animation(player_node: Node) -> void:
	var walk_model = player_node.find_child("WalkModel", false, false)
	var idle_model = player_node.find_child("IdleModel", false, false)
	# FBX内のCamera/Lightを非表示にする
	for model in [walk_model, idle_model]:
		if model:
			_hide_fbx_extras(model)
	# WalkModelのアニメーションをIdleModelに統合
	_integrate_walk_animation(walk_model, idle_model)
	# WalkModelは常に非表示（アニメーションソースとしてのみ使用）
	if walk_model:
		walk_model.visible = false
	if idle_model:
		idle_model.visible = true
		var anim = idle_model.find_child("AnimationPlayer", true, false)
		if anim and anim.has_animation("mixamo_com"):
			anim.play("mixamo_com")
	# 外部PNGテクスチャを両モデルに適用
	_share_material(idle_model, walk_model)
	# 正面（45度）を向く
	player_node.rotation = Vector3(0, deg_to_rad(45), 0)


## WalkModelのアニメーションをIdleModelのAnimationPlayerに統合する
func _integrate_walk_animation(walk_model: Node, idle_model: Node) -> void:
	if not walk_model or not idle_model:
		return
	var walk_anim_player = walk_model.find_child("AnimationPlayer", true, false)
	var idle_anim_player = idle_model.find_child("AnimationPlayer", true, false)
	if not walk_anim_player or not idle_anim_player:
		return
	if not walk_anim_player.has_animation("mixamo_com"):
		return
	var walk_anim = walk_anim_player.get_animation("mixamo_com")
	var lib = idle_anim_player.get_animation_library("")
	if lib and not lib.has_animation("walk"):
		lib.add_animation("walk", walk_anim)
		print("[QuestGame] walkアニメーション統合完了: ", idle_model.name)

## 外部PNGテクスチャを両モデルに適用する
## FBX内のCamera/Lightノードを非表示にする
func _hide_fbx_extras(model: Node) -> void:
	for child in model.get_children():
		if child is Camera3D or child is Light3D:
			child.visible = false
		# 再帰的に子も確認
		_hide_fbx_extras(child)

func _share_material(idle_model: Node, walk_model: Node) -> void:
	# キャラクターのテクスチャPNGパスを取得（Idle FBXと同じフォルダ）
	var texture_path := _find_texture_path(idle_model)
	if texture_path.is_empty():
		print("[QuestGame] テクスチャPNGが見つかりません")
		return
	var texture := load(texture_path) as Texture2D
	if not texture:
		print("[QuestGame] テクスチャ読み込み失敗: ", texture_path)
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	# 両モデルに適用
	for model in [idle_model, walk_model]:
		if not model:
			continue
		var meshes := _find_all_mesh_instances(model)
		for mesh in meshes:
			for i in range(mesh.get_surface_override_material_count()):
				mesh.set_surface_override_material(i, mat)
	print("[QuestGame] テクスチャ適用完了: ", texture_path)

## モデルのFBXパスからテクスチャPNGを探す
## ※エクスポート版ではDirAccessでres://をスキャンできないため、
##   ResourceLoader.exists()で既知の命名パターンを直接チェックする
func _find_texture_path(model: Node) -> String:
	if not model:
		return ""
	# モデルのシーンファイルパスからフォルダを特定
	var scene_path: String = model.scene_file_path
	if scene_path.is_empty():
		var packed = model.get_meta("_editor_scene_path_", "") if model.has_meta("_editor_scene_path_") else ""
		if packed is String and not packed.is_empty():
			scene_path = packed
	var folder := "res://assets/models/necromancer/"
	if not scene_path.is_empty():
		folder = scene_path.get_base_dir() + "/"
	# Meshy出力の命名規則: {Name}_0.png（エクスポート版対応）
	var candidates: Array[String] = [
		folder + "Idle_0.png",
		folder + "Walk_0.png",
		folder + "idle_0.png",
		folder + "walk_0.png",
	]
	# FBX名から推測: {FBXベース名}_0.png
	if not scene_path.is_empty():
		var base_name = scene_path.get_file().get_basename()
		candidates.append(folder + base_name + "_0.png")
		candidates.append(folder + base_name + ".png")
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	# フォールバック: エディタではDirAccessでスキャン（開発時のみ有効）
	var dir := DirAccess.open(folder)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				return folder + file_name
			file_name = dir.get_next()
	return ""

## モデル内の全MeshInstance3Dを再帰的に探す
func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result

## ステージ固有の設定を適用
func _apply_stage_settings():
	# ステージデータをGameSystemManagerに委譲（チェーンアクセス解消）
	var stage_data = stage_loader.get_stage_data()
	system_manager.set_stage_data(stage_data)

	# リザルト画面を作成・設定
	var result_screen = ResultScreen.new()
	result_screen.name = "ResultScreen"
	add_child(result_screen)
	system_manager.set_result_screen(result_screen)
	
	# ワープペアを登録
	if system_manager.special_tile_system:
		stage_loader.register_warp_pairs_to_system(system_manager.special_tile_system)
	
	# 周回システム設定を適用（委譲メソッド経由）
	var map_data = stage_loader.get_map_data()
	if not map_data.is_empty():
		system_manager.apply_map_settings_to_lap_system(map_data)
	
	# 初期EPを設定
	if system_manager.player_system:
		# プレイヤー1
		var player_magic = stage_loader.get_player_start_magic()
		system_manager.player_system.set_magic(0, player_magic)
		
		# CPU敵（新旧形式両対応）
		var enemies = stage_loader.get_enemies()
		for i in range(enemies.size()):
			var enemy_magic = stage_loader.get_enemy_start_magic(i)
			system_manager.player_system.set_magic(i + 1, enemy_magic)

		# プレイヤー名を設定
		# プレイヤー0: GameDataの名前を使用
		system_manager.player_system.players[0].name = GameData.player_data.profile.name

		# CPU敵: キャラクター名を使用
		var enemies_for_name = stage_loader.get_enemies()
		for i in range(enemies_for_name.size()):
			var char_data = stage_loader.get_enemy_character(i)
			var cpu_name = char_data.get("name", "CPU " + str(i + 1))
			if i + 1 < system_manager.player_system.players.size():
				system_manager.player_system.players[i + 1].name = cpu_name

	# チーム割り当て
	var teams = stage_loader.get_teams()
	if not teams.is_empty() and system_manager.team_system:
		system_manager.team_system.setup_teams(teams, system_manager.player_system)
		print("[QuestGame] チーム設定完了: %s" % str(teams))

	# 勝利条件を設定
	var win_conditions = stage_loader.get_win_condition()
	var target = 8000  # デフォルト値
	
	# 新形式: conditions配列から取得
	if win_conditions.has("conditions"):
		var conditions = win_conditions.get("conditions", [])
		for condition in conditions:
			if condition.get("type") == "magic":
				target = condition.get("target", 8000)
				break
	# 旧形式: 直接targetを持っている場合
	elif win_conditions.has("target"):
		target = win_conditions.get("target", 8000)
	
	if system_manager.player_system:
		# 全プレイヤーのtarget_magicを設定
		for player in system_manager.player_system.players:
			player.target_magic = target
		print("[QuestGame] 勝利条件: TEP %dEP以上でチェックポイント通過" % target)

	# 全プレイヤーのデッキを設定
	_setup_all_decks()

## 全プレイヤーのデッキを設定（プレイヤー0 + CPU）
func _setup_all_decks():
	if not system_manager.card_system:
		push_error("[QuestGame] card_system is null, returning")
		return
	
	# プレイヤー0: GameDataから選択中のブックを設定
	_setup_player_deck()
	
	# CPU: ステージ設定から読み込み（新旧形式両対応）
	var enemies = stage_loader.get_enemies()
	for i in range(enemies.size()):
		var deck_id = stage_loader.get_enemy_deck_id(i)
		var player_id = i + 1
		
		if deck_id == "random":
			# ランダムデッキは既にdeal_initial_hands_all_playersで配布済み
			print("[QuestGame] CPU %d: ランダムデッキ使用" % player_id)
		else:
			# 指定デッキを読み込んで設定
			var deck_data = stage_loader.load_deck(deck_id)
			if not deck_data.is_empty():
				system_manager.card_system.set_deck_for_player(player_id, deck_data)
				system_manager.card_system.deal_initial_hand_for_player(player_id)
				print("[QuestGame] CPU %d: デッキ %s 設定完了" % [player_id, deck_id])
			else:
				print("[QuestGame] CPU %d: デッキ %s が見つからないためランダム" % [player_id, deck_id])

## プレイヤー0のデッキを設定（GameDataから）
func _setup_player_deck():
	var deck_info = GameData.get_current_deck()
	var cards_dict = deck_info.get("cards", {})

	if cards_dict.is_empty():
		print("[QuestGame] Player 0: デッキが空のためランダム使用")
		return
	
	# GameDataの形式 {card_id: count} を set_deck_for_player 形式に変換
	var deck_data = {"cards": []}
	for card_id in cards_dict.keys():
		var count = cards_dict[card_id]
		deck_data["cards"].append({"id": card_id, "count": count})
	
	system_manager.card_system.set_deck_for_player(0, deck_data)
	system_manager.card_system.deal_initial_hand_for_player(0)

## CPUのバトルポリシーを設定
func _setup_cpu_battle_policies():
	if not system_manager or not system_manager.board_system_3d:
		push_error("[QuestGame] system_manager または board_system_3d が null")
		return

	# board_system_3d.cpu_ai_handler を直接参照（確実に存在する）
	var cpu_ai_handler = system_manager.board_system_3d.cpu_ai_handler
	if not cpu_ai_handler:
		push_error("[QuestGame] board_system_3d.cpu_ai_handler が見つかりません")
		return

	# CPU敵のポリシーを設定
	var enemies = stage_loader.get_enemies()
	if enemies.is_empty():
		return

	# 最初の敵のポリシーを取得して設定
	var policy_data = stage_loader.get_enemy_battle_policy(0)

	if policy_data.is_empty():
		# デフォルトポリシーを設定
		cpu_ai_handler.set_battle_policy_preset("balanced")
	else:
		cpu_ai_handler.load_battle_policy_from_json(policy_data)
	
	# CPUMovementEvaluatorにもcpu_ai_handlerを設定（移動シミュレーション用）
	if system_manager.game_flow_manager and system_manager.board_system_3d:
		var cpu_movement_evaluator = system_manager.board_system_3d.get_cpu_movement_evaluator()
		if cpu_movement_evaluator:
			cpu_movement_evaluator.set_cpu_ai_handler(cpu_ai_handler)
		else:
			print("[QuestGame] cpu_movement_evaluator が見つかりません")
