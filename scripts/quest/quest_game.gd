extends Node
class_name QuestGame

# クエストモード用ゲーム管理スクリプト
# StageLoaderからデータを読み込み、動的にゲームを構築

# システム参照
var system_manager: GameSystemManager
var stage_loader: StageLoader

# ステージID（GameDataから取得、またはデフォルト）
var stage_id: String = "stage_1_1"

# 設定（StageLoaderから取得）
var player_count: int = 2
var player_is_cpu: Array = [false, true]

# クエストモードでは常にCPUはAI任せ
var debug_manual_control_all: bool = false

func _ready():
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
	
	print("[QuestGame] 3Dシーン事前構築完了")

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
	var enemies = stage_loader.get_enemies()
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
	# ステージデータをGameFlowManagerに渡す（リザルト処理用）
	if system_manager.game_flow_manager:
		var stage_data = stage_loader.get_stage_data()
		system_manager.game_flow_manager.set_stage_data(stage_data)
		
		# リザルト画面を作成・設定
		var result_screen = ResultScreen.new()
		result_screen.name = "ResultScreen"
		add_child(result_screen)
		system_manager.game_flow_manager.set_result_screen(result_screen)
	
	# ワープペアを登録
	if system_manager.special_tile_system:
		stage_loader.register_warp_pairs_to_system(system_manager.special_tile_system)
	
	# 周回システム設定を適用
	if system_manager.game_flow_manager and system_manager.game_flow_manager.lap_system:
		var map_data = stage_loader.get_map_data()
		if not map_data.is_empty():
			system_manager.game_flow_manager.lap_system.apply_map_settings(map_data)
			print("[QuestGame] 周回システム設定適用完了")
	
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
		
		print("[QuestGame] 初期EP設定完了")
	
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
	print("[QuestGame] calling _setup_all_decks...")
	_setup_all_decks()

## 全プレイヤーのデッキを設定（プレイヤー0 + CPU）
func _setup_all_decks():
	print("[QuestGame] _setup_all_decks called")
	if not system_manager.card_system:
		print("[QuestGame] card_system is null, returning")
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
	print("[QuestGame] _setup_player_deck called")
	print("[QuestGame] selected_deck_index: %d" % GameData.selected_deck_index)
	
	var deck_info = GameData.get_current_deck()
	print("[QuestGame] deck_info: %s" % str(deck_info))
	
	var cards_dict = deck_info.get("cards", {})
	print("[QuestGame] cards_dict size: %d" % cards_dict.size())
	
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
	print("[QuestGame] Player 0: ブック%d 設定完了 (%d種類)" % [GameData.selected_deck_index + 1, cards_dict.size()])

## CPUのバトルポリシーを設定
func _setup_cpu_battle_policies():
	print("[QuestGame] _setup_cpu_battle_policies 開始")
	
	if not system_manager or not system_manager.board_system_3d:
		print("[QuestGame] system_manager または board_system_3d が null")
		return
	
	# board_system_3d.cpu_ai_handler を直接参照（確実に存在する）
	var cpu_ai_handler = system_manager.board_system_3d.cpu_ai_handler
	if not cpu_ai_handler:
		print("[QuestGame] board_system_3d.cpu_ai_handler が見つかりません")
		return
	
	# CPU敵のポリシーを設定
	var enemies = stage_loader.get_enemies()
	print("[QuestGame] 敵の数: %d" % enemies.size())
	if enemies.is_empty():
		return
	
	# 最初の敵のポリシーを取得して設定
	var policy_data = stage_loader.get_enemy_battle_policy(0)
	print("[QuestGame] policy_data: %s" % policy_data)
	
	if policy_data.is_empty():
		# デフォルトポリシーを設定
		cpu_ai_handler.set_battle_policy_preset("balanced")
		print("[QuestGame] CPUバトルポリシー: デフォルト (balanced)")
	else:
		cpu_ai_handler.load_battle_policy_from_json(policy_data)
		print("[QuestGame] CPUバトルポリシー: JSONから読み込み完了")
	
	# CPUMovementEvaluatorにもcpu_ai_handlerを設定（移動シミュレーション用）
	if system_manager.game_flow_manager and system_manager.board_system_3d.movement_controller:
		var cpu_movement_evaluator = system_manager.board_system_3d.movement_controller.cpu_movement_evaluator
		if cpu_movement_evaluator:
			cpu_movement_evaluator.set_cpu_ai_handler(cpu_ai_handler)
		else:
			print("[QuestGame] cpu_movement_evaluator が見つかりません")
