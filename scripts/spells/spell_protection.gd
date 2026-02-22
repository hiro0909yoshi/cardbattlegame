# SpellProtection - 結界システム
# スペル/アルカナアーツの対象選択時に結界判定を行う
class_name SpellProtection

# ============================================
# 結界判定メソッド
# ============================================

## クリーチャーがスペル/アルカナアーツから保護されているか判定
## 
## creature_data: クリーチャーデータ（ability_parsed, curseを含む）
## context: 追加コンテキスト（world_curse等のチェック用）
## 戻り値: true = 結界状態（対象に選べない）
static func is_creature_protected(creature_data: Dictionary, context: Dictionary = {}) -> bool:
	if creature_data.is_empty():
		return false
	
	var creature_name = creature_data.get("name", "?")
	
	# 1. パッシブスキル「結界」チェック
	# ability_parsed.keywordsをチェック
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if "結界" in keywords:
		print("[SpellProtection] %s は結界キーワードを持つため対象外" % creature_name)
		return true
	
	# abilityフィールドからも「結界」を検出（データが不完全な場合の対応）
	var ability = creature_data.get("ability", "")
	if "結界" in ability:
		print("[SpellProtection] %s は結界abilityを持つため対象外" % creature_name)
		return true
	
	# 2. クリーチャー呪い「結界」チェック
	var curse = creature_data.get("curse", {})
	var curse_type = curse.get("curse_type", "")
	if curse_type in ["spell_protection", "protection_wall"]:
		print("[SpellProtection] %s は結界呪いを持つため対象外" % creature_name)
		return true
	
	# 3. 世界呪い「女教皇」チェック（呪い付きクリーチャーのみ）
	var world_curse = context.get("world_curse", {})
	if world_curse.get("curse_type") == "cursed_protection":
		# 何らかの呪いがかかっているクリーチャーは結界
		if not curse.is_empty():
			print("[SpellProtection] %s は女教皇により対象外" % creature_name)
			return true
	
	return false


## プレイヤーがスペル/アルカナアーツから保護されているか判定
## 
## player: PlayerDataオブジェクト（curseプロパティを持つ）
## context: 追加コンテキスト（world_curse等のチェック用）
## 戻り値: true = 結界状態（対象に選べない）
static func is_player_protected(player, context: Dictionary = {}) -> bool:
	if player == null:
		return false
	
	var player_name = player.name if "name" in player else "?"
	
	# 1. プレイヤー呪い「結界」チェック
	var curse = player.curse if "curse" in player else {}
	if curse is Dictionary and not curse.is_empty():
		if curse.get("curse_type") == "spell_protection":
			print("[SpellProtection] プレイヤー %s は結界呪いを持つため対象外" % player_name)
			return true
	
	# 2. 世界呪い「結界」チェック（全セプター対象）
	var world_curse = context.get("world_curse", {})
	if world_curse.get("curse_type") == "world_spell_protection":
		print("[SpellProtection] プレイヤー %s は世界呪い結界により対象外" % player_name)
		return true
	
	return false


## 対象データから結界判定を行う（統合メソッド）
## 
## target_data: ターゲット情報（type, tile_index, player_id等）
## handler: board_system, player_system, game_flow_manager を持つオブジェクト
## 戻り値: true = 結界状態（対象に選べない）
static func is_target_protected(target_data: Dictionary, handler) -> bool:
	var target_type = target_data.get("type", "")
	
	# コンテキストを構築（世界呪いチェック用）
	var context = _build_context(handler)
	
	match target_type:
		"creature":
			# クリーチャーターゲットの結界チェック
			var creature = target_data.get("creature", {})
			if creature.is_empty():
				return false
			return is_creature_protected(creature, context)
		
		"land":
			# 土地ターゲットの場合、クリーチャーがいればそのクリーチャーの結界チェック
			var tile_index = target_data.get("tile_index", -1)
			if tile_index < 0 or not handler.board_system:
				return false
			
			var tile = handler.board_system.tile_nodes.get(tile_index)
			if not tile or tile.creature_data.is_empty():
				# クリーチャーがいない土地は結界対象外
				return false
			
			return is_creature_protected(tile.creature_data, context)
		
		"player":
			# プレイヤーの結界チェック
			var player_id = target_data.get("player_id", -1)
			if player_id < 0 or not handler.player_system:
				return false
			if player_id >= handler.player_system.players.size():
				return false
			
			var player = handler.player_system.players[player_id]
			return is_player_protected(player, context)
	
	return false


## コンテキストを構築（世界呪い等）
## 直接参照を優先し、フォールバックで game_flow_manager を使用
static func _build_context(handler) -> Dictionary:
	var context = {}

	# 世界呪いを取得
	# handlerはNode（SpellPhaseHandler等）なのでプロパティに直接アクセス
	if handler == null:
		return context

	# 直接参照 game_stats を優先
	if "game_stats" in handler and handler.game_stats is Dictionary:
		context["world_curse"] = handler.game_stats.get("world_curse", {})
		return context

	# フォールバック: game_flow_manager 経由
	if "game_flow_manager" in handler and handler.game_flow_manager:
		var gfm = handler.game_flow_manager
		# game_statsプロパティが存在するか確認
		if "game_stats" in gfm and gfm.game_stats is Dictionary:
			context["world_curse"] = gfm.game_stats.get("world_curse", {})

	return context


# ============================================
# ターゲットリストフィルタリング
# ============================================

## ターゲットリストから結界対象を除外
## 
## targets: ターゲット情報の配列
## handler: board_system, player_system, game_flow_manager を持つオブジェクト
## 戻り値: 結界対象を除外したターゲットリスト
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
# 伝染スキル判定
# ============================================

## クリーチャーが伝染スキルを持っているかチェック
static func has_curse_spread_skill(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "伝染" in keywords


## 伝染スキルの適用
## spell_curse: SpellCurseインスタンス
static func apply_curse_spread(spell_curse, creature_data: Dictionary, tile_index: int, curse_type: String, duration: int, params: Dictionary):
	# 伝染スキルチェック
	if not has_curse_spread_skill(creature_data):
		return
	
	var board_system = spell_curse.board_system
	var creature_manager = spell_curse.creature_manager
	var player_system = spell_curse.player_system
	var game_flow_manager = spell_curse.game_flow_manager
	
	# 現在のプレイヤー（スペル使用者）を取得
	var caster_id = player_system.current_player_index
	
	# 使用者の全ドミニオから拡散対象を取得
	var context = {}
	if game_flow_manager:
		context["world_curse"] = game_flow_manager.game_stats.get("world_curse", {})
	
	for target_tile_index in board_system.tile_nodes.keys():
		var tile = board_system.tile_nodes[target_tile_index]
		
		# 使用者のドミニオかチェック
		if tile.owner_id != caster_id:
			continue
		
		# 自分自身のタイルはスキップ（既に呪いがついている）
		if target_tile_index == tile_index:
			continue
		
		# クリーチャーがいるかチェック
		var target_creature = creature_manager.get_data_ref(target_tile_index)
		if not target_creature:
			continue
		
		# 結界チェック
		if is_creature_protected(target_creature, context):
			continue
		
		# 呪いを付与（is_spread = true で再帰防止）
		spell_curse.curse_creature(target_tile_index, curse_type, duration, params, true)
	
	# 伝染クリーチャーをダウン
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
## 戻り値: true = スペル使用不可（アルカナアーツは使用可能）
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


## 全プレイヤーに禁呪呪いを付与
##
## player_system: PlayerSystemの参照
## duration: 呪いの持続ターン数
## curse_name: 呪いの表示名
static func apply_spell_disable_to_all_players(player_system, duration: int = 1, curse_name: String = "禁呪"):
	if player_system == null:
		return

	for player in player_system.players:
		# 既存の呪いがあっても上書き
		player.curse = {
			"curse_type": "spell_disable",
			"name": curse_name,
			"duration": duration
		}
		print("[刻印付与] %s → %s (duration=%d)" % [curse_name, player.name, duration])


# ============================================
# 堅牢判定（旧SpellHpImmune統合）
# ============================================

## クリーチャーが堅牢を持っているか判定
static func has_hp_effect_immune(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false

	var creature_name = creature_data.get("name", "?")

	# 1. クリーチャー固有能力チェック（keywords）
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	if "堅牢" in keywords:
		print("[SpellProtection] %s は堅牢キーワードを持つため対象外" % creature_name)
		return true

	# 2. 呪いチェック（グラナイト等で付与）
	var curse = creature_data.get("curse", {})
	if curse.get("curse_type") == "hp_effect_immune":
		print("[SpellProtection] %s は堅牢呪いを持つため対象外" % creature_name)
		return true

	return false


## スペル/アルカナアーツがHP変更効果を持つか判定
static func affects_hp(effect_parsed: Dictionary) -> bool:
	return effect_parsed.get("affects_hp", false)


## 堅牢によりスキップすべきか判定（全体スペル用）
static func should_skip_hp_effect(creature_data: Dictionary, effect_parsed: Dictionary) -> bool:
	if not affects_hp(effect_parsed):
		return false

	if has_hp_effect_immune(creature_data):
		print("[堅牢] %s はHP変更効果を無効化" % creature_data.get("name", "?"))
		return true

	return false


## ターゲット選択時に堅牢を持つクリーチャーを除外するフィルタ
static func filter_hp_immune_targets(creatures: Array, effect_parsed: Dictionary) -> Array:
	if not affects_hp(effect_parsed):
		return creatures

	var filtered = []
	for creature in creatures:
		if not has_hp_effect_immune(creature):
			filtered.append(creature)
		else:
			print("[堅牢] %s は対象から除外" % creature.get("name", "?"))

	return filtered
