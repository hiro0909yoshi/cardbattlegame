extends Node

# 3Dゲームメイン管理スクリプト
# GameSystemManager への委譲により大幅に簡潔化

# システム参照
var system_manager: GameSystemManager

# 設定
var player_count = 2
var player_is_cpu = [false, true]  # Player1=人間, Player2=CPU

# 🔧 デバッグ設定: trueにするとCPUも手動操作できる
var debug_manual_control_all = true  # デバッグモード有効化

func _ready():
	# GameSystemManager を作成・初期化
	system_manager = GameSystemManager.new()
	add_child(system_manager)
	
	# 全フェーズを実行（Phase 1-6）
	system_manager.initialize_all(
		self,
		player_count,
		player_is_cpu,
		debug_manual_control_all
	)
	
	# ゲーム開始待機
	await get_tree().create_timer(0.5).timeout
	
	# ゲーム開始
	system_manager.start_game()

# デバッグ入力はDebugControllerに統合されました
