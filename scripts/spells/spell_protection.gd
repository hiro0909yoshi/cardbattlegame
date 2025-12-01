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
	
	# 1. パッシブスキル「防魔」チェック
	# ability_parsed.keywordsをチェック
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if "防魔" in keywords:
		return true
	
	# abilityフィールドからも「防魔」を検出（データが不完全な場合の対応）
	var ability = creature_data.get("ability", "")
	if "防魔" in ability:
		return true
	
	# 2. クリーチャー呪い「防魔」チェック
	var curse = creature_data.get("curse", {})
	var curse_type = curse.get("curse_type", "")
	if curse_type in ["spell_protection", "protection_wall"]:
		return true
	
	# 3. 世界呪い「呪い防魔化」チェック（呪い付きクリーチャーのみ）
	var world_curse = context.get("world_curse", {})
	if world_curse.get("curse_type") == "cursed_protection":
		# 何らかの呪いがかかっているクリーチャーは防魔
		if not curse.is_empty():
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
	
	# 1. プレイヤー呪い「防魔」チェック
	var curse = player.curse if "curse" in player else {}
	if curse is Dictionary and not curse.is_empty():
		if curse.get("curse_type") == "spell_protection":
			return true
	
	# 2. 世界呪い「防魔」チェック（全セプター対象）
	var world_curse = context.get("world_curse", {})
	if world_curse.get("curse_type") == "world_spell_protection":
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
	var protected_count = 0
	
	for target in targets:
		if is_target_protected(target, handler):
			protected_count += 1
			# デバッグログ
			var target_name = _get_target_name(target)
			print("[防魔] %s は防魔状態のため対象から除外" % target_name)
		else:
			filtered.append(target)
	
	if protected_count > 0:
		print("[防魔] %d体の対象が防魔により除外されました" % protected_count)
	
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
