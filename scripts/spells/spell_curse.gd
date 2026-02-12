extends Node
class_name SpellCurse

# 呪い効果システム
# 複数ターンにわたって効果が持続する呪いを管理
# ドキュメント: docs/design/spells/呪い効果.md

# ========================================
# インスタンス変数
# ========================================

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

## 全クリーチャーに呪いを適用（ディラニー、プレイグ、イモビライズ等）
func apply_to_all_creatures(effect: Dictionary, target_info: Dictionary) -> int:
	var condition = target_info.get("condition", {})
	var targets = TargetSelectionHelper.get_all_creatures(board_system, condition)
	
	var affected_count = 0
	for target in targets:
		var tile_index = target["tile_index"]
		apply_effect(effect, tile_index)
		affected_count += 1
	
	var effect_type = effect.get("effect_type", "")
	print("[SpellCurse] 全クリーチャー対象 (%s): %d体に呪いを付与" % [effect_type, affected_count])
	return affected_count

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
		
		"ap_nullify":
			var params = {"name": effect.get("name", "AP=0")}
			curse_creature(tile_index, "ap_nullify", duration, params)
		
		"grant_mystic_arts":
			# アルカナアーツ付与呪い（シュリンクシジル、ドレインシジル等）
			# spell_id参照方式と旧mystic_arts配列方式の両方に対応
			var curse_name = effect.get("name", effect.get("curse_name", "アルカナアーツ付与"))
			var spell_id = effect.get("spell_id", 0)
			var cost = effect.get("cost", 0)
			var mystic_arts = effect.get("mystic_arts", [])
			
			var params = {
				"name": curse_name
			}
			
			if spell_id > 0:
				# spell_id参照方式（新方式）
				params["spell_id"] = spell_id
				params["cost"] = cost
			else:
				# mystic_arts配列方式（旧方式）
				params["mystic_arts"] = mystic_arts
			
			curse_creature(tile_index, "mystic_grant", duration, params)
		
		"stat_reduce":
			# ステータス減少呪い（縮小術等）- バトル時にHP/APを減らす
			var stat = effect.get("stat", "both")  # "hp", "ap", "both"
			var value = effect.get("value", -10)
			var params = {
				"name": effect.get("name", "弱体化"),
				"stat": stat,
				"value": value
			}
			curse_creature(tile_index, "stat_reduce", duration, params)
		
		"random_stat_curse":
			# 能力値不定呪い（リキッドフォーム）- バトル時にAP&HPをランダム化
			var params = {
				"name": effect.get("name", "能力値不定"),
				"stat": effect.get("stat", "both"),
				"min": effect.get("min", 10),
				"max": effect.get("max", 70)
			}
			curse_creature(tile_index, "random_stat", duration, params)
		
		"command_growth_curse":
			# コマンド成長呪い（ドミナントグロース）- レベルアップ/地形変化でMHP+20
			var params = {
				"name": effect.get("name", "コマンド成長"),
				"hp_bonus": effect.get("hp_bonus", 20)
			}
			curse_creature(tile_index, "command_growth", duration, params)
		
		"plague_curse":
			# 衰弱呪い（プレイグ）- 戦闘終了時にHP -= MHP/2（切り上げ）
			var params = {
				"name": effect.get("name", "衰弱")
			}
			curse_creature(tile_index, "plague", duration, params)
		
		"bounty_curse":
			# 賞金首呪い（バウンティハント）- 武器で破壊時に術者が300EP獲得
			var caster_id = player_system.current_player_index
			var params = {
				"name": effect.get("name", "賞金首"),
				"reward": effect.get("reward", 300),
				"requires_weapon": effect.get("requires_weapon", true),
				"prevent_move": effect.get("prevent_move", true),
				"prevent_swap": effect.get("prevent_swap", true),
				"caster_id": caster_id
			}
			curse_creature(tile_index, "bounty", duration, params)
		
		"land_curse":
			# 土地呪い（ブラストトラップ等）- 敵停止時に発動
			var caster_id = player_system.current_player_index
			var params = {
				"name": effect.get("curse_name", effect.get("name", "土地呪い")),
				"curse_type": effect.get("curse_type", ""),
				"trigger": effect.get("trigger", "on_enemy_stop"),
				"one_shot": effect.get("one_shot", false),
				"curse_effects": effect.get("curse_effects", []),
				"caster_id": caster_id
			}
			curse_creature(tile_index, effect.get("curse_type", "land_trap"), duration, params)
		
		"creature_curse":
			# クリーチャー呪い（汎用）- マジックシェルター、ジャングラバーの移動不可等
			var curse_type_inner = effect.get("curse_type", "unknown")
			var params = {
				"name": effect.get("name", effect.get("description", "呪い"))
			}
			# 追加パラメータをコピー（spell_protection, defensive_form等）
			for key in ["spell_protection", "defensive_form", "description"]:
				if effect.has(key):
					params[key] = effect.get(key)
			curse_creature(tile_index, curse_type_inner, duration, params)
		
		"forced_stop":
			# 強制停止呪い（クイックサンド）- 移動中のプレイヤーを1度だけ足どめ
			var params = {
				"name": effect.get("name", "強制停止"),
				"uses_remaining": effect.get("uses", 1)
			}
			curse_creature(tile_index, "forced_stop", duration, params)
		
		"indomitable":
			# 不屈呪い（ハイパーアクティブ）- ダウン状態にならない
			var params = {
				"name": effect.get("name", "不屈")
			}
			curse_creature(tile_index, "indomitable", duration, params)
		
		"land_effect_disable":
			# 地形効果無効呪い
			var creature = creature_manager.get_data_ref(tile_index)
			if creature:
				SpellCurseBattle.apply_land_effect_disable(creature, effect.get("name", "地形効果無効"))
		
		"land_effect_grant":
			# 地形効果付与呪い
			var creature = creature_manager.get_data_ref(tile_index)
			if creature:
				var grant_elements = effect.get("grant_elements", [])
				SpellCurseBattle.apply_land_effect_grant(creature, grant_elements, effect.get("name", "地形効果"))
		
		"metal_form":
			# メタルフォーム呪い
			var creature = creature_manager.get_data_ref(tile_index)
			if creature:
				SpellCurseBattle.apply_metal_form(creature, effect.get("name", "メタルフォーム"))
		
		"magic_barrier":
			# マジックバリア呪い
			var creature = creature_manager.get_data_ref(tile_index)
			if creature:
				SpellCurseBattle.apply_magic_barrier(creature, effect.get("name", "マジックバリア"))
		
		"destroy_after_battle":
			# 戦闘後破壊呪い
			var creature = creature_manager.get_data_ref(tile_index)
			if creature:
				SpellCurseBattle.apply_destroy_after_battle(creature, effect.get("name", "戦闘後破壊"))
		
		"apply_curse":
			# 汎用呪い付与（マスファンタズム等）
			var curse_type_inner = effect.get("curse_type", "unknown")
			var params = {
				"name": effect.get("name", "呪い")
			}
			curse_creature(tile_index, curse_type_inner, duration, params)
		
		_:
			print("[SpellCurse] 未対応の効果タイプ: ", effect_type)



# ========================================
# クリーチャー呪い
# ========================================

# クリーチャーに呪いを付与
# is_spread: 拡散処理中かどうか（再帰防止用）
func curse_creature(tile_index: int, curse_type: String, duration: int = -1, params: Dictionary = {}, is_spread: bool = false):
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
	
	# 呪い拡散スキルチェック（再帰防止: is_spread = false の場合のみ）
	if not is_spread:
		SpellProtection.apply_curse_spread(self, creature, tile_index, curse_type, duration, params)

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

## コマンド成長呪いをトリガー（レベルアップ/地形変化時に呼び出す）
## @param tile_index: コマンド実行対象のタイルインデックス
## @return Dictionary: {triggered: bool, creature_name: String, hp_bonus: int, old_mhp: int, new_mhp: int, old_hp: int, new_hp: int}
func trigger_command_growth(tile_index: int) -> Dictionary:
	var result = {"triggered": false}
	
	var curse = get_creature_curse(tile_index)
	if curse.is_empty():
		return result
	
	if curse.get("curse_type") != "command_growth":
		return result
	
	var creature = creature_manager.get_data_ref(tile_index)
	if not creature:
		return result
	
	var params = curse.get("params", {})
	var hp_bonus = params.get("hp_bonus", 20)
	var curse_name = curse.get("name", "コマンド成長")
	
	# 旧値を保存
	var old_mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
	var old_hp = creature.get("current_hp", old_mhp)
	
	# MHP+20を適用（EffectManager使用）
	EffectManager.apply_max_hp_effect(creature, hp_bonus)
	
	# 新値を取得
	var new_mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
	var new_hp = creature.get("current_hp", new_mhp)
	
	print("[コマンド成長] ", creature.get("name", "?"), " MHP+", hp_bonus, " (呪い: ", curse_name, ")")
	
	result = {
		"triggered": true,
		"creature_name": creature.get("name", "クリーチャー"),
		"hp_bonus": hp_bonus,
		"old_mhp": old_mhp,
		"new_mhp": new_mhp,
		"old_hp": old_hp,
		"new_hp": new_hp
	}
	
	return result

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
	
	# マジックタイル経由の場合、付与ターンでのduration減少をスキップするためのフラグを追加
	if _is_magic_tile_mode():
		player.curse["from_magic_tile"] = true
		player.curse["granted_turn"] = _get_current_turn()
		print("[呪い付与] ", params.get("name", curse_type), " → プレイヤー", player_id, 
			  " (duration=", duration, ", magic_tile=true, turn=", _get_current_turn(), ")")
	else:
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
		var curse_type = curse.get("curse_type", "")
		var duration = curse.get("duration", -1)
		
		# マジックタイル経由で付与された呪いは付与ターンではスキップ
		if curse.get("from_magic_tile", false):
			var granted_turn = curse.get("granted_turn", -1)
			var current_turn = _get_current_turn()
			if granted_turn >= 0 and granted_turn == current_turn:
				print("[呪いカウントダウン] ", curse.get("name", ""), " - マジックタイル付与ターンのためスキップ")
				# フラグをクリア（次ターン以降は通常通り減少）
				curse.erase("from_magic_tile")
				curse.erase("granted_turn")
				return
		
		# duration > 0 の場合のみカウントダウン
		if duration > 0:
			curse["duration"] = duration - 1
			print("[呪いカウントダウン] ", curse.get("name", ""), " duration: ", duration, " → ", duration - 1)
			
			# duration が 0 になったら削除
			if curse["duration"] == 0:
				var curse_name = curse.get("name", "不明")
				player.curse = {}
				print("[呪い消滅] ", curse_name, " (duration=0)")
				
				# 歩行逆転呪いの場合、方向を元に戻す
				if curse_type == "movement_reverse":
					_on_movement_reverse_curse_removed(player_id)

## 現在のターン番号を取得
func _get_current_turn() -> int:
	if game_flow_manager:
		return game_flow_manager.current_turn_number
	return -1

## マジックタイルモードかチェック
func _is_magic_tile_mode() -> bool:
	if game_flow_manager and game_flow_manager.spell_phase_handler:
		return game_flow_manager.spell_phase_handler.is_magic_tile_mode
	return false

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
	for tile_index in board_system.tile_nodes.keys():  # 全タイル
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

# 歩行逆転呪い解除時の処理
func _on_movement_reverse_curse_removed(player_id: int):
	if board_system:
		board_system.on_movement_reverse_curse_removed(player_id)
