extends Node

# ソロバトル用ゲーム管理スクリプト
# StageLoaderからデータを読み込み、動的にゲームを構築

# システム参照
var system_manager: GameSystemManager
var stage_loader: StageLoader

# ソロバトルはデフォルトでstage_1_1を使用
var stage_id: String = "stage_1_1"

# 設定（StageLoaderから取得）
var player_count: int = 2
var player_is_cpu: Array = [false, true]

# 🔧 デバッグ設定: trueにするとCPUも手動操作できる
var debug_manual_control_all: bool = true

func _ready():
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
	
	# ゲーム開始待機
	await get_tree().create_timer(0.5).timeout
	
	# ゲーム開始
	system_manager.start_game()

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
	
	# CPU敵
	var enemies = stage_loader.current_stage_data.get("enemies", [])
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
		
		# CPU敵
		var enemies = stage_loader.current_stage_data.get("enemies", [])
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

