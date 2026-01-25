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

# 🔧 デバッグ設定: trueにするとCPUも手動操作できる
var debug_manual_control_all: bool = true

func _ready():
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
			debug_manual_control_all = false
			print("[Game3D] チュートリアルモード: CPUは自動操作")
	
	# StageLoaderを作成
	stage_loader = StageLoader.new()
	stage_loader.name = "StageLoader"
	add_child(stage_loader)
	
	# ステージを読み込み
	var stage_data = stage_loader.load_stage(stage_id)
	if stage_data.is_empty():
		push_error("[Game3D] ステージ読み込み失敗: " + stage_id)
		return
	
	# 設定を取得
	player_count = stage_loader.get_player_count()
	player_is_cpu = stage_loader.get_player_is_cpu()
	
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
		debug_manual_control_all
	)
	
	# ステージ固有の設定を適用
	_apply_stage_settings()
	
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

## チュートリアルセットアップ
func _setup_tutorial():
	print("[Game3D] チュートリアルモード初期化")
	
	# 新チュートリアルシステムを使用（テスト中）
	var use_new_system = true
	
	if use_new_system:
		# 新システム: TutorialController
		var TutorialControllerClass = load("res://scripts/tutorial/tutorial_controller.gd")
		if TutorialControllerClass:
			tutorial_manager = TutorialControllerClass.new()
			tutorial_manager.name = "TutorialManager"
			add_child(tutorial_manager)
			tutorial_manager.setup_systems(system_manager)
			
			# ステージ1をロード
			if tutorial_manager.load_stage("res://data/tutorial/tutorial_stage1.json"):
				print("[Game3D] 新チュートリアルシステム初期化完了")
			else:
				push_error("[Game3D] チュートリアルステージ読み込み失敗")
	else:
		# 旧システム: TutorialManager
		var TutorialManagerClass = load("res://scripts/tutorial/tutorial_manager.gd")
		if TutorialManagerClass:
			tutorial_manager = TutorialManagerClass.new()
			tutorial_manager.name = "TutorialManager"
			add_child(tutorial_manager)
			tutorial_manager.initialize_with_systems(system_manager)

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
	var mario_scene = load("res://scenes/Characters/Mario.tscn")
	if mario_scene:
		var mario = mario_scene.instantiate()
		mario.name = "Player"
		var movement_script = load("res://scripts/player_movement.gd")
		if movement_script:
			mario.set_script(movement_script)
		container.add_child(mario)
	
	# CPU敵（新旧形式両対応）
	var enemies = stage_loader._get_enemies()
	for i in range(enemies.size()):
		var char_data = stage_loader.get_enemy_character(i)
		var model_path = char_data.get("model_path", "res://scenes/Characters/Bowser.tscn")
		var enemy_scene = load(model_path)
		if enemy_scene:
			var enemy = enemy_scene.instantiate()
			enemy.name = "Player%d" % (i + 2)
			container.add_child(enemy)

## ステージ固有の設定を適用
func _apply_stage_settings():
	# ワープペアを登録
	if system_manager.special_tile_system:
		stage_loader.register_warp_pairs_to_system(system_manager.special_tile_system)
	
	# 周回システム設定を適用
	if system_manager.game_flow_manager and system_manager.game_flow_manager.lap_system:
		var map_data = stage_loader.get_map_data()
		if not map_data.is_empty():
			system_manager.game_flow_manager.lap_system.apply_map_settings(map_data)
			print("[Game3D] 周回システム設定適用完了")
	
	# 初期魔力を設定
	if system_manager.player_system:
		# プレイヤー1
		var player_magic = stage_loader.get_player_start_magic()
		system_manager.player_system.set_magic(0, player_magic)
		
		# CPU敵（新旧形式両対応）
		var enemies = stage_loader._get_enemies()
		for i in range(enemies.size()):
			var enemy_magic = stage_loader.get_enemy_start_magic(i)
			system_manager.player_system.set_magic(i + 1, enemy_magic)
		
		print("[Game3D] 初期魔力設定完了")
	
	# 勝利条件を設定
	var win_condition = stage_loader.get_win_condition()
	if win_condition.has("target") and system_manager.player_system:
		var target = win_condition.get("target", 8000)
		for player in system_manager.player_system.players:
			player.target_magic = target
		print("[Game3D] 勝利条件: 総魔力 %dG以上" % target)
	
	# 全プレイヤーのデッキを設定
	print("[Game3D] calling _setup_all_decks...")
	_setup_all_decks()
	
	# CPUのバトルポリシーを設定
	_setup_cpu_battle_policies()

## 全プレイヤーのデッキを設定（ソロバトル: 全員同じデッキ）
func _setup_all_decks():
	print("[Game3D] _setup_all_decks called")
	if not system_manager.card_system:
		print("[Game3D] card_system is null, returning")
		return
	
	# ソロバトルモード: 全プレイヤーがGameDataの選択デッキを使用
	var deck_info = GameData.get_current_deck()
	var cards_dict = deck_info.get("cards", {})
	
	if cards_dict.is_empty():
		print("[Game3D] デッキが空のため全員ランダム使用")
		return
	
	# GameDataの形式 {card_id: count} を set_deck_for_player 形式に変換
	var deck_data = {"cards": []}
	for card_id in cards_dict.keys():
		var count = cards_dict[card_id]
		deck_data["cards"].append({"id": card_id, "count": count})
	
	# 全プレイヤーに同じデッキを設定
	for player_id in range(player_count):
		system_manager.card_system.set_deck_for_player(player_id, deck_data)
		system_manager.card_system.deal_initial_hand_for_player(player_id)
		print("[Game3D] Player %d: ブック%d 設定完了 (%d種類)" % [player_id, GameData.selected_deck_index + 1, cards_dict.size()])

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
	var enemies = stage_loader._get_enemies()
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
