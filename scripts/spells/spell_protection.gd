# SpellProtection - 防魔システム
# スペル/秘術の対象選択時に防魔判定を行う
class_name SpellProtection

# ============================================
# 防魔判定メソッド
# ============================================

## クリーチャーがスペル/秘術から保護されているか判定
## 
## creature_data: クリーチャーデータ（ability_parsed, curseを含む）
## context: 追加コンテキスト（world_curse等のチェック用）
## 戻り値: true = 防魔状態（対象に選べない）
static func is_creature_protected(creature_data: Dictionary, context: Dictionary = {}) -> bool:
	if creature_data.is_empty():
		return false
	
	var creature_name = creature_data.get("name", "?")
	
	# 1. パッシブスキル「防魔」チェック
	# ability_parsed.keywordsをチェック
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if "防魔" in keywords:
		print("[SpellProtection] %s は防魔キーワードを持つため対象外" % creature_name)
		return true
	
	# abilityフィールドからも「防魔」を検出（データが不完全な場合の対応）
	var ability = creature_data.get("ability", "")
	if "防魔" in ability:
		print("[SpellProtection] %s は防魔abilityを持つため対象外" % creature_name)
		return true
	
	# 2. クリーチャー呪い「防魔」チェック
	var curse = creature_data.get("curse", {})
	var curse_type = curse.get("curse_type", "")
	if curse_type in ["spell_protection", "protection_wall"]:
		print("[SpellProtection] %s は防魔呪いを持つため対象外" % creature_name)
		return true
	
	# 3. 世界呪い「呪い防魔化」チェック（呪い付きクリーチャーのみ）
	var world_curse = context.get("world_curse", {})
	if world_curse.get("curse_type") == "cursed_protection":
		# 何らかの呪いがかかっているクリーチャーは防魔
		if not curse.is_empty():
			print("[SpellProtection] %s は呪い防魔化により対象外" % creature_name)
			return true
	
	return false


## プレイヤーがスペル/秘術から保護されているか判定
## 
## player: PlayerDataオブジェクト（curseプロパティを持つ）
## context: 追加コンテキスト（world_curse等のチェック用）
## 戻り値: true = 防魔状態（対象に選べない）
static func is_player_protected(player, context: Dictionary = {}) -> bool:
	if player == null:
		return false
	
	var player_name = player.name if "name" in player else "?"
	
	# 1. プレイヤー呪い「防魔」チェック
	var curse = player.curse if "curse" in player else {}
	if curse is Dictionary and not curse.is_empty():
		if curse.get("curse_type") == "spell_protection":
			print("[SpellProtection] プレイヤー %s は防魔呪いを持つため対象外" % player_name)
			return true
	
	# 2. 世界呪い「防魔」チェック（全セプター対象）
	var world_curse = context.get("world_curse", {})
	if world_curse.get("curse_type") == "world_spell_protection":
		print("[SpellProtection] プレイヤー %s は世界呪い防魔により対象外" % player_name)
		return true
	
	return false


## 対象データから防魔判定を行う（統合メソッド）
## 
## target_data: ターゲット情報（type, tile_index, player_id等）
## handler: board_system, player_system, game_flow_manager を持つオブジェクト
## 戻り値: true = 防魔状態（対象に選べない）
static func is_target_protected(target_data: Dictionary, handler) -> bool:
	var target_type = target_data.get("type", "")
	
	# コンテキストを構築（世界呪いチェック用）
	var context = _build_context(handler)
	
	match target_type:
		"creature":
			# クリーチャーターゲットの防魔チェック
			var creature = target_data.get("creature", {})
			if creature.is_empty():
				return false
			return is_creature_protected(creature, context)
		
		"land":
			# 土地ターゲットの場合、クリーチャーがいればそのクリーチャーの防魔チェック
			var tile_index = target_data.get("tile_index", -1)
			if tile_index < 0 or not handler.board_system:
				return false
			
			var tile = handler.board_system.tile_nodes.get(tile_index)
			if not tile or tile.creature_data.is_empty():
				# クリーチャーがいない土地は防魔対象外
				return false
			
			return is_creature_protected(tile.creature_data, context)
		
		"player":
			# プレイヤーの防魔チェック
			var player_id = target_data.get("player_id", -1)
			if player_id < 0 or not handler.player_system:
				return false
			if player_id >= handler.player_system.players.size():
				return false
			
			var player = handler.player_system.players[player_id]
			return is_player_protected(player, context)
	
	return false


## コンテキストを構築（世界呪い等）
static func _build_context(handler) -> Dictionary:
	var context = {}
	
	# 世界呪いを取得
	# handlerはNode（SpellPhaseHandler等）なのでプロパティに直接アクセス
	if handler == null:
		return context
	
	# game_flow_managerプロパティが存在するか確認
	if "game_flow_manager" in handler and handler.game_flow_manager:
		var gfm = handler.game_flow_manager
		# game_statsプロパティが存在するか確認
		if "game_stats" in gfm and gfm.game_stats is Dictionary:
			context["world_curse"] = gfm.game_stats.get("world_curse", {})
	
	return context


# ============================================
# ターゲットリストフィルタリング
# ============================================

## ターゲットリストから防魔対象を除外
## 
## targets: ターゲット情報の配列
## handler: board_system, player_system, game_flow_manager を持つオブジェクト
## 戻り値: 防魔対象を除外したターゲットリスト
static func filter_protected_targets(targets: Array, handler) -> Array:
	var filtered = []
	
	for target in targets:
		if not is_target_protected(target, handler):
			filtered.append(target)
	
	return filtered


## ターゲット名を取得（ログ用）
static func _get_target_name(target_data: Dictionary) -> String:
	var target_type = target_data.get("type", "")
	match target_type:
		"creature":
			return target_data.get("creature", {}).get("name", "不明なクリーチャー")
		"land":
			var tile_index = target_data.get("tile_index", -1)
			return "タイル%d" % tile_index
		"player":
			var player_id = target_data.get("player_id", -1)
			return "プレイヤー%d" % (player_id + 1)
	return "不明"


# ============================================
# 呪い拡散スキル判定
# ============================================

## クリーチャーが呪い拡散スキルを持っているかチェック
static func has_curse_spread_skill(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "呪い拡散" in keywords


## 呪い拡散スキルの適用
## spell_curse: SpellCurseインスタンス
static func apply_curse_spread(spell_curse, creature_data: Dictionary, tile_index: int, curse_type: String, duration: int, params: Dictionary):
	# 呪い拡散スキルチェック
	if not has_curse_spread_skill(creature_data):
		return
	
	var board_system = spell_curse.board_system
	var creature_manager = spell_curse.creature_manager
	var player_system = spell_curse.player_system
	var game_flow_manager = spell_curse.game_flow_manager
	
	# 現在のプレイヤー（スペル使用者）を取得
	var caster_id = player_system.current_player_index
	
	# 使用者の全領地から拡散対象を取得
	var context = {}
	if game_flow_manager:
		context["world_curse"] = game_flow_manager.game_stats.get("world_curse", {})
	
	for target_tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[target_tile_index]
		
		# 使用者の領地かチェック
		if tile.owner_id != caster_id:
			continue
		
		# 自分自身のタイルはスキップ（既に呪いがついている）
		if target_tile_index == tile_index:
			continue
		
		# クリーチャーがいるかチェック
		var target_creature = creature_manager.get_data_ref(target_tile_index)
		if not target_creature:
			continue
		
		# 防魔チェック
		if is_creature_protected(target_creature, context):
			continue
		
		# 呪いを付与（is_spread = true で再帰防止）
		spell_curse.curse_creature(target_tile_index, curse_type, duration, params, true)
	
	# 呪い拡散クリーチャーをダウン
	if board_system.tile_nodes.has(tile_index):
		var tile = board_system.tile_nodes[tile_index]
		if tile.has_method("set_down_state"):
			tile.set_down_state(true)


# ============================================
# スペル使用不可判定
# ============================================

## プレイヤーがスペル使用不可状態か判定
## 
## player: PlayerDataオブジェクト（curseプロパティを持つ）
## context: 追加コンテキスト（world_curse等のチェック用）
## 戻り値: true = スペル使用不可（秘術は使用可能）
static func is_player_spell_disabled(player, context: Dictionary = {}) -> bool:
	if player == null:
		return false
	
	# 1. プレイヤー呪い「spell_disable」チェック
	var curse = player.curse if "curse" in player else {}
	if curse is Dictionary and not curse.is_empty():
		if curse.get("curse_type") == "spell_disable":
			return true
	
	# 2. 世界呪い「spell_disable」チェック（全セプター対象）
	var world_curse = context.get("world_curse", {})
	if world_curse.get("curse_type") == "world_spell_disable":
		return true
	
	return false


## 全プレイヤーにスペル不可呪いを付与
## 
## player_system: PlayerSystemの参照
## duration: 呪いの持続ターン数
## curse_name: 呪いの表示名
static func apply_spell_disable_to_all_players(player_system, duration: int = 1, curse_name: String = "スペル不可"):
	if player_system == null:
		return
	
	for player in player_system.players:
		# 既存の呪いがあっても上書き
		player.curse = {
			"curse_type": "spell_disable",
			"name": curse_name,
			"duration": duration
		}
		print("[呪い付与] %s → %s (duration=%d)" % [curse_name, player.name, duration])
