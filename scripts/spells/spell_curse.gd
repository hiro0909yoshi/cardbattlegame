extends Node
class_name SpellCurse

# 呪い効果システム
# 複数ターンにわたって効果が持続する呪いを管理
# ドキュメント: docs/design/spells/呪い効果.md

# 参照
var board_system: BoardSystem3D
var creature_manager: CreatureManager
var player_system: PlayerSystem
var game_flow_manager: GameFlowManager

# 初期化
func setup(board: BoardSystem3D, creature: CreatureManager, player: PlayerSystem, flow: GameFlowManager):
	board_system = board
	creature_manager = creature
	player_system = player
	game_flow_manager = flow
	
	print("[SpellCurse] 初期化完了")

# ========================================
# 統合エントリポイント
# ========================================

## effect辞書から適切な呪いを適用
func apply_effect(effect: Dictionary, tile_index: int) -> void:
	var effect_type = effect.get("effect_type", "")
	var duration = effect.get("duration", -1)
	
	match effect_type:
		"skill_nullify":
			var params = {"name": effect.get("name", "戦闘能力不可")}
			curse_creature(tile_index, "skill_nullify", duration, params)
		
		"battle_disable":
			var params = {"name": effect.get("name", "戦闘行動不可")}
			curse_creature(tile_index, "battle_disable", duration, params)
		
		_:
			print("[SpellCurse] 未対応の効果タイプ: ", effect_type)

# ========================================
# クリーチャー呪い
# ========================================

# クリーチャーに呪いを付与
func curse_creature(tile_index: int, curse_type: String, duration: int = -1, params: Dictionary = {}):
	var creature = creature_manager.get_data_ref(tile_index)
	if not creature:
		print("[SpellCurse] エラー: タイル ", tile_index, " にクリーチャーが存在しません")
		return
	
	# 既存の呪いがあれば上書き通知
	if creature.has("curse"):
		var old_curse = creature["curse"]
		print("[呪い上書き] ", old_curse.get("name", "不明"), " → ", params.get("name", "不明"))
	
	# 新しい呪いを付与（上書き）
	var curse_name = str(params.get("name", ""))  # StringName対応: 文字列に変換
	creature["curse"] = {
		"curse_type": curse_type,
		"name": curse_name,
		"duration": duration,
		"params": params
	}
	
	print("[呪い付与] ", curse_name, " → ", creature.get("name", "不明"), 
		  " (duration=", duration, ")")

# クリーチャーの呪いを取得
func get_creature_curse(tile_index: int) -> Dictionary:
	var creature = creature_manager.get_data_ref(tile_index)
	if creature:
		return creature.get("curse", {})
	return {}

# クリーチャーから呪いを削除
func remove_curse_from_creature(tile_index: int):
	var creature = creature_manager.get_data_ref(tile_index)
	if creature and creature.has("curse"):
		var curse_name = creature["curse"].get("name", "不明")
		creature.erase("curse")
		print("[呪い消滅] ", curse_name, " (移動)")

# ========================================
# プレイヤー呪い
# ========================================

# プレイヤーに呪いを付与
func curse_player(player_id: int, curse_type: String, duration: int = -1, params: Dictionary = {}, caster_id: int = -1):
	if player_id < 0 or player_id >= player_system.players.size():
		print("[SpellCurse] エラー: 不正なプレイヤーID ", player_id)
		return
	
	var player = player_system.players[player_id]
	
	# 既存の呪いがあれば上書き通知
	if not player.curse.is_empty():
		var old_curse = player.curse
		print("[呪い上書き] ", old_curse.get("name", "不明"), " → ", params.get("name", "不明"))
	
	# 新しい呪いを付与（上書き）
	player.curse = {
		"curse_type": curse_type,
		"name": params.get("name", ""),
		"duration": duration,
		"params": params,
		"caster_id": caster_id  # 呪いを付与したプレイヤーID（toll_shareの副収入判定用）
	}
	
	print("[呪い付与] ", params.get("name", curse_type), " → プレイヤー", player_id, 
		  " (duration=", duration, ")")

# プレイヤーの呪いを取得
func get_player_curse(player_id: int) -> Dictionary:
	if player_id < 0 or player_id >= player_system.players.size():
		return {}
	
	return player_system.players[player_id].curse

# プレイヤーから呪いを削除
func remove_curse_from_player(player_id: int):
	if player_id < 0 or player_id >= player_system.players.size():
		return
	
	var player = player_system.players[player_id]
	if not player.curse.is_empty():
		var curse_name = player.curse.get("name", "不明")
		player.curse = {}
		print("[呪い消滅] ", curse_name, " (削除)")

# ========================================
# 世界呪
# ========================================

# 世界呪を付与
func curse_world(curse_type: String, duration: int = 6, params: Dictionary = {}):
	# 既存の世界呪があれば上書き通知
	if game_flow_manager.game_stats.has("world_curse"):
		var old_curse = game_flow_manager.game_stats["world_curse"]
		print("[呪い上書き] ", old_curse.get("name", "不明"), " → ", params.get("name", "不明"))
	
	# 新しい世界呪を付与（上書き）
	game_flow_manager.game_stats["world_curse"] = {
		"curse_type": curse_type,
		"name": params.get("name", ""),
		"duration": duration,
		"params": params
	}
	
	print("[呪い付与] ", params.get("name", curse_type), " → 世界", 
		  " (duration=", duration, ")")

# 世界呪を取得
func get_world_curse() -> Dictionary:
	return game_flow_manager.game_stats.get("world_curse", {})

# 世界呪を削除
func remove_world_curse():
	if game_flow_manager.game_stats.has("world_curse"):
		var curse_name = game_flow_manager.game_stats["world_curse"].get("name", "不明")
		game_flow_manager.game_stats.erase("world_curse")
		print("[呪い消滅] ", curse_name, " (削除)")

# ========================================
# ターン経過処理
# ========================================

# 特定のプレイヤーの呪いのみ更新（ターン終了時用）
func update_player_curse(player_id: int):
	if player_id < 0 or player_id >= player_system.players.size():
		return
	
	var player = player_system.players[player_id]
	if not player.curse.is_empty():
		var curse = player.curse
		var duration = curse.get("duration", -1)
		
		# duration > 0 の場合のみカウントダウン
		if duration > 0:
			curse["duration"] = duration - 1
			print("[呪いカウントダウン] ", curse.get("name", ""), " duration: ", duration, " → ", duration - 1)
			
			# duration が 0 になったら削除
			if curse["duration"] == 0:
				var curse_name = curse.get("name", "不明")
				player.curse = {}
				print("[呪い消滅] ", curse_name, " (duration=0)")

# 全ての呪いのdurationを更新（デバッグ用）
func update_all_curses():
	# クリーチャー呪い
	_update_creature_curses()
	
	# プレイヤー呪い
	_update_player_curses()
	
	# 世界呪
	_update_world_curse()

# クリーチャー呪いのduration更新
func _update_creature_curses():
	for tile_index in range(20):  # 0-19の全タイル
		var creature = creature_manager.get_data_ref(tile_index)
		if creature and creature.has("curse"):
			var curse = creature["curse"]
			var duration = curse.get("duration", -1)
			
			# duration > 0 の場合のみカウントダウン
			if duration > 0:
				curse["duration"] = duration - 1
				
				# duration が 0 になったら削除
				if curse["duration"] == 0:
					var curse_name = curse.get("name", "不明")
					creature.erase("curse")
					print("[呪い消滅] ", curse_name, " (duration=0)")

# プレイヤー呪いのduration更新
func _update_player_curses():
	for player in player_system.players:
		if not player.curse.is_empty():
			var curse = player.curse
			var duration = curse.get("duration", -1)
			
			# duration > 0 の場合のみカウントダウン
			if duration > 0:
				curse["duration"] = duration - 1
				
				# duration が 0 になったら削除
				if curse["duration"] == 0:
					var curse_name = curse.get("name", "不明")
					player.curse = {}
					print("[呪い消滅] ", curse_name, " (duration=0)")

# 世界呪のduration更新
func _update_world_curse():
	if game_flow_manager.game_stats.has("world_curse"):
		var curse = game_flow_manager.game_stats["world_curse"]
		var duration = curse.get("duration", -1)
		
		# duration > 0 の場合のみカウントダウン
		if duration > 0:
			curse["duration"] = duration - 1
			
			# duration が 0 になったら削除
			if curse["duration"] == 0:
				var curse_name = curse.get("name", "不明")
				game_flow_manager.game_stats.erase("world_curse")
				print("[呪い消滅] ", curse_name, " (duration=0)")
