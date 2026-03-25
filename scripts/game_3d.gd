extends Node

# ソロバトル用ゲーム管理スクリプト
# StageLoaderからデータを読み込み、動的にゲームを構築

# システム参照
var system_manager: GameSystemManager
var stage_loader: StageLoader

# ソロバトルはデフォルトでstage_test_4pを使用（4人対戦テスト）
# GameData.set_meta("stage_id", "xxx") で外部から指定可能
var stage_id: String = "stage_test_4p"

# チュートリアルモードフラグ
var is_tutorial_mode: bool = false

# チュートリアルマネージャー
var tutorial_manager = null

# 設定（StageLoaderから取得）
var player_count: int = 2
var player_is_cpu: Array = [false, true]

func _ready():
	# 🔧 デバッグ設定: trueにするとCPUも手動操作できる
	DebugSettings.manual_control_all = true

	# 外部から指定されたステージIDがあれば使用
	if GameData.has_meta("stage_id"):
		stage_id = GameData.get_meta("stage_id")
		GameData.remove_meta("stage_id")

	# チュートリアルモード確認
	if GameData.has_meta("is_tutorial_mode"):
		is_tutorial_mode = GameData.get_meta("is_tutorial_mode")
		GameData.remove_meta("is_tutorial_mode")

		# チュートリアルモードではCPUを自動操作にする
		if is_tutorial_mode:
			DebugSettings.manual_control_all = false
			print("[Game3D] チュートリアルモード: CPUは自動操作")
	
	# StageLoaderを作成
	stage_loader = StageLoader.new()
	stage_loader.name = "StageLoader"
	add_child(stage_loader)

	# ソロバトル準備画面からの設定があればそちらを使用
	var stage_data: Dictionary = {}
	var is_solo_battle = GameData.has_meta("solo_battle_config")
	if is_solo_battle:
		var config = GameData.get_meta("solo_battle_config")
		GameData.remove_meta("solo_battle_config")
		var built_stage = _build_stage_from_config(config)
		stage_data = stage_loader.load_stage_from_data(built_stage)
		print("[Game3D] ソロバトル準備画面からの設定を使用")
	else:
		stage_data = stage_loader.load_stage(stage_id)

	if stage_data.is_empty():
		GameLogger.error("Quest", "ステージ読み込み失敗: %s（_ready）" % stage_id)
		return
	
	# 設定を取得
	player_count = stage_loader.get_player_count()
	player_is_cpu = stage_loader.get_player_is_cpu()

	# CPU切り替えテスト: プレイヤー2をローカル人間として開始
	if DebugSettings.test_cpu_takeover and player_is_cpu.size() > 1:
		player_is_cpu[1] = false
		print("[Game3D] test_cpu_takeover: P2をローカル操作で開始")

	print("[Game3D] ステージ: %s, プレイヤー数: %d" % [stage_id, player_count])
	
	# 3Dシーンを事前に構築（GameSystemManager が収集できるように）
	_setup_3d_scene_before_init()
	
	# GameSystemManagerを作成・初期化
	system_manager = GameSystemManager.new()
	add_child(system_manager)
	
	system_manager.initialize_all(
		self,
		player_count,
		player_is_cpu,
		DebugSettings.manual_control_all
	)
	
	# ソロバトル（対戦モード）: 全通知を3秒自動進行に設定
	if is_solo_battle:
		var ui_mgr = system_manager.ui_manager if system_manager else null
		if ui_mgr and ui_mgr.global_comment_ui:
			ui_mgr.global_comment_ui.battle_auto_advance = true
		var sph = system_manager.game_flow_manager.spell_phase_handler if system_manager and system_manager.game_flow_manager else null
		if sph and sph.spell_cast_notification_ui:
			sph.spell_cast_notification_ui.battle_auto_advance = true

	# ステージ固有の設定を適用
	_apply_stage_settings()

	# ステージデータをGameResultHandlerに渡す（勝敗後の遷移先判定用）
	system_manager.set_stage_data(stage_data)

	# チュートリアルモード初期化
	if is_tutorial_mode:
		_setup_tutorial()
	
	# ゲーム開始待機
	await get_tree().create_timer(0.5).timeout
	
	# ゲーム開始
	system_manager.start_game()
	
	# チュートリアル開始
	if is_tutorial_mode and tutorial_manager:
		tutorial_manager.start_tutorial()


## チュートリアル終了時
func _on_tutorial_ended():
	print("[Game3D] チュートリアル終了")
	# チュートリアルはリザルト画面をスキップしてメインメニューへ直接遷移
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


## チュートリアルセットアップ
func _setup_tutorial():
	print("[Game3D] チュートリアルモード初期化")
	
	# チュートリアルID取得（デフォルトはstage1）
	var tutorial_id = "stage1"
	if GameData.has_meta("tutorial_id"):
		tutorial_id = GameData.get_meta("tutorial_id")
		GameData.remove_meta("tutorial_id")
	
	# TutorialManager
	var TutorialManagerClass = load("res://scripts/tutorial/tutorial_manager.gd")
	if TutorialManagerClass:
		tutorial_manager = TutorialManagerClass.new()
		tutorial_manager.name = "TutorialManager"
		add_child(tutorial_manager)
		
		# チュートリアルデータパスを設定
		var tutorial_path = "res://data/tutorial/tutorial_%s.json" % tutorial_id
		tutorial_manager.set_tutorial_path(tutorial_path)
		print("[Game3D] チュートリアルデータ: %s" % tutorial_path)
		
		# system_managerを渡して初期化（シグナル接続もTutorialManager内で行う）
		tutorial_manager.initialize_with_systems(system_manager)
		
		# チュートリアル終了シグナルを接続
		tutorial_manager.tutorial_ended.connect(_on_tutorial_ended)

## 3Dシーンを事前構築（タイル・プレイヤー・カメラ）
func _setup_3d_scene_before_init():
	# 既存のカメラ・ライト・コンテナを使用（Main.tscnに配置済み）
	var tiles_container = get_node_or_null("Tiles")
	if not tiles_container:
		tiles_container = Node3D.new()
		tiles_container.name = "Tiles"
		add_child(tiles_container)
	
	# 既存のタイルをクリア
	for child in tiles_container.get_children():
		child.queue_free()
	
	# StageLoaderでマップ生成
	stage_loader.set_tiles_container(tiles_container)
	stage_loader.generate_map()

	# 既存のGridMap背景を削除してCastleEnvironmentに置き換え
	var old_bg = get_node_or_null("Background")
	if old_bg:
		old_bg.queue_free()

	# WorldEnvironment（空と環境光）
	var existing_world_env = get_node_or_null("WorldEnvironment")
	if not existing_world_env:
		var world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		var env = Environment.new()
		var sky = Sky.new()
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.30, 0.55, 0.80)
		sky_mat.sky_horizon_color = Color(0.55, 0.68, 0.80)
		sky_mat.ground_bottom_color = Color(0.45, 0.58, 0.72)
		sky_mat.ground_horizon_color = Color(0.55, 0.68, 0.80)
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.4
		world_env.environment = env
		add_child(world_env)

	# 城壁・地面を作成（タイル範囲から動的にサイズ決定、45度回転）
	var castle_env = CastleEnvironment.new()
	castle_env.name = "CastleEnvironment"
	castle_env.rotation.y = deg_to_rad(45)
	add_child(castle_env)
	castle_env.setup_from_tiles(tiles_container)

	# プレイヤーコンテナを確認・作成
	var players_container = get_node_or_null("Players")
	if not players_container:
		players_container = Node3D.new()
		players_container.name = "Players"
		add_child(players_container)
	
	# 既存のプレイヤーをクリア
	for child in players_container.get_children():
		child.queue_free()
	
	# プレイヤーキャラクター作成
	_create_player_characters(players_container)

	print("[Game3D] 3Dシーン事前構築完了")

## プレイヤーキャラクター作成
func _create_player_characters(container: Node3D):
	# プレイヤー1（Mario）
	var mario_scene = load("res://scenes/Characters/Hero.tscn")
	if mario_scene:
		var mario = mario_scene.instantiate()
		mario.name = "Player"
		var movement_script = load("res://scripts/player_movement.gd")
		if movement_script:
			mario.set_script(movement_script)
		container.add_child(mario)
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
		print("[Game3D] walkアニメーション統合完了: ", idle_model.name)


## FBX内の不要なCamera/Lightノードを削除する
func _hide_fbx_extras(model: Node) -> void:
	for child in model.get_children():
		_hide_fbx_extras(child)
		if child is Camera3D or child is Light3D:
			child.queue_free()


## 外部PNGテクスチャを両モデルに適用する
func _share_material(idle_model: Node, walk_model: Node) -> void:
	var texture_path := _find_texture_path(idle_model)
	if texture_path.is_empty():
		print("[Game3D] テクスチャPNGが見つかりません")
		return
	var texture := load(texture_path) as Texture2D
	if not texture:
		print("[Game3D] テクスチャ読み込み失敗: ", texture_path)
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	for model in [idle_model, walk_model]:
		if not model:
			continue
		var meshes := _find_all_mesh_instances(model)
		for mesh in meshes:
			for i in range(mesh.get_surface_override_material_count()):
				mesh.set_surface_override_material(i, mat)
	print("[Game3D] テクスチャ適用完了: ", texture_path)


## モデルのFBXパスからテクスチャPNGを探す
## ※エクスポート版ではDirAccessでres://をスキャンできないため、
##   ResourceLoader.exists()で既知の命名パターンを直接チェックする
func _find_texture_path(model: Node) -> String:
	if not model:
		return ""
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
		
		print("[Game3D] 初期EP設定完了")

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

		print("[Game3D] プレイヤー名設定完了")

	# 勝利条件を設定
	var win_condition = stage_loader.get_win_condition()
	var target = 0
	# 新形式: conditions配列から target を取得
	if win_condition.has("conditions"):
		for condition in win_condition.get("conditions", []):
			if condition.has("target"):
				target = condition.get("target", 8000)
				break
	# 旧形式: トップレベルの target
	elif win_condition.has("target"):
		target = win_condition.get("target", 8000)
	# target_magicを全プレイヤーに設定
	if target > 0 and system_manager.player_system:
		for player in system_manager.player_system.players:
			player.target_magic = target
		print("[Game3D] 勝利条件: TEP %dEP以上" % target)
	
	# 全プレイヤーのデッキを設定
	print("[Game3D] calling _setup_all_decks...")
	_setup_all_decks()
	
	# CPUのバトルポリシーを設定
	_setup_cpu_battle_policies()

## ソロバトル準備画面の設定からステージデータを構築
func _build_stage_from_config(config: Dictionary) -> Dictionary:
	var rule_preset = config.get("rule_preset", "standard")
	var win_conditions = GameConstants.get_win_conditions(rule_preset).duplicate(true)

	# target_magic のオーバーライド
	var target_magic = config.get("target_magic", 0)
	if target_magic > 0 and win_conditions.has("conditions"):
		for condition in win_conditions.get("conditions", []):
			if condition.has("target"):
				condition["target"] = target_magic

	return {
		"id": "solo_battle_custom",
		"name": "ソロバトル",
		"map_id": config.get("map_id", "map_diamond_20"),
		"rule_preset": rule_preset,
		"max_turns": config.get("max_turns", 0),
		"rule_overrides": {
			"initial_magic": {
				"player": config.get("initial_magic_player", 1000),
				"cpu": config.get("initial_magic_cpu", 1000)
			},
			"win_conditions": win_conditions
		},
		"quest": {
			"enemies": config.get("enemies", [])
		}
	}


## 全プレイヤーのデッキを設定
func _setup_all_decks():
	print("[Game3D] _setup_all_decks called")
	if not system_manager.card_system:
		print("[Game3D] card_system is null, returning")
		return

	# プレイヤー0: GameDataの選択デッキを使用
	var deck_info = GameData.get_current_deck()
	var cards_dict = deck_info.get("cards", {})

	if not cards_dict.is_empty():
		var player_deck_data: Dictionary = {"cards": []}
		for card_id in cards_dict.keys():
			var count = cards_dict[card_id]
			player_deck_data["cards"].append({"id": card_id, "count": count})
		system_manager.card_system.set_deck_for_player(0, player_deck_data)
		system_manager.card_system.deal_initial_hand_for_player(0)
		print("[Game3D] Player 0: ブック%d 設定完了 (%d種類)" % [GameData.selected_deck_index + 1, cards_dict.size()])
	else:
		print("[Game3D] プレイヤーデッキが空のためランダム使用")
		system_manager.card_system.deal_initial_hand_for_player(0)

	# CPU敵: 各自のdeck_idを使用
	var enemies = stage_loader.get_enemies()
	for i in range(enemies.size()):
		var deck_id = stage_loader.get_enemy_deck_id(i)
		if deck_id and deck_id != "random":
			var cpu_deck_data = stage_loader.load_deck(deck_id)
			if not cpu_deck_data.is_empty():
				system_manager.card_system.set_deck_for_player(i + 1, cpu_deck_data)
				print("[Game3D] CPU %d: デッキ %s 設定完了" % [i + 1, deck_id])
			else:
				print("[Game3D] CPU %d: デッキ %s が空のためランダム使用" % [i + 1, deck_id])
		else:
			print("[Game3D] CPU %d: ランダムデッキ使用" % [i + 1])
		system_manager.card_system.deal_initial_hand_for_player(i + 1)

## CPUのバトルポリシーを設定
func _setup_cpu_battle_policies():
	print("[Game3D] _setup_cpu_battle_policies 開始")
	
	if not system_manager:
		print("[Game3D] system_manager が null")
		return
	if not system_manager.board_system_3d:
		print("[Game3D] board_system_3d が null")
		return
	
	# board_system_3d.cpu_ai_handler を直接参照
	var cpu_ai_handler = system_manager.board_system_3d.cpu_ai_handler
	if not cpu_ai_handler:
		print("[Game3D] cpu_ai_handler が見つかりません")
		return
	
	# CPU敵の数だけポリシーを設定（現在は1体のみ対応）
	var enemies = stage_loader.get_enemies()
	print("[Game3D] 敵の数: %d" % enemies.size())
	if enemies.is_empty():
		print("[Game3D] 敵がいないためポリシー設定スキップ")
		return
	
	# 最初の敵のポリシーを取得して設定
	var policy_data = stage_loader.get_enemy_battle_policy(0)
	print("[Game3D] policy_data: %s" % policy_data)
	
	if policy_data.is_empty():
		# ポリシー指定がなければデフォルト（balanced）を使用
		cpu_ai_handler.set_battle_policy_preset("balanced")
		print("[Game3D] CPUバトルポリシー: デフォルト (balanced)")
	else:
		cpu_ai_handler.load_battle_policy_from_json(policy_data)
		print("[Game3D] CPUバトルポリシー: JSONから読み込み")
