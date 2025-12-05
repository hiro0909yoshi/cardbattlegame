extends Node
class_name SpellMagic

## 魔力操作の汎用化モジュール
## バトル外・バトル中のマップ効果として使用する
## ドキュメント: docs/design/spells/魔力増減.md

var player_system_ref: PlayerSystem = null
var board_system_ref = null  # BoardSystem3D
var game_flow_manager_ref = null  # GameFlowManager
var spell_curse_ref = null  # SpellCurse（呪い連携用）
var spell_cast_notification_ui = null  # 通知UI

func setup(player_system: PlayerSystem, board_system = null, game_flow_manager = null, spell_curse = null):
	player_system_ref = player_system
	board_system_ref = board_system
	game_flow_manager_ref = game_flow_manager
	spell_curse_ref = spell_curse
	print("SpellMagic: セットアップ完了")

## 通知UIを設定
func set_notification_ui(notification_ui) -> void:
	spell_cast_notification_ui = notification_ui

## 統合エントリポイント - effect辞書から適切な処理を実行
func apply_effect(effect: Dictionary, player_id: int, context: Dictionary = {}) -> Dictionary:
	var effect_type = effect.get("effect_type", "")
	var result = {"success": false, "amount": 0}
	var notification_text = ""
	var from_id = context.get("from_player_id", -1)
	
	match effect_type:
		"gain_magic":
			var amount = effect.get("amount", 0)
			add_magic(player_id, amount)
			result = {"success": true, "amount": amount}
			if amount > 0:
				notification_text = _format_gain_notification(player_id, amount)
		
		"gain_magic_by_rank":
			var rank = context.get("rank", 1)
			var multiplier = effect.get("multiplier", 50)
			var amount = rank * multiplier
			add_magic(player_id, amount)
			print("[魔力効果] 順位魔力: %d位 × %dG = %dG" % [rank, multiplier, amount])
			result = {"success": true, "amount": amount}
			if amount > 0:
				notification_text = _format_gain_notification(player_id, amount, "【順位ボーナス】%d位 × %dG" % [rank, multiplier])
		
		"gain_magic_by_lap":
			# マナ: 周回数×G50獲得
			result = gain_magic_by_lap(player_id, effect)
			if result.get("amount", 0) > 0:
				var lap = result.get("lap_count", 0)
				notification_text = _format_gain_notification(player_id, result["amount"], "【マナ】%d周 × %dG" % [lap, effect.get("multiplier", 50)])
		
		"gain_magic_from_destroyed_count":
			# インシネレート: 破壊数×G20
			result = gain_magic_from_destroyed_count(player_id, effect)
			if result.get("amount", 0) > 0:
				var count = result.get("destroy_count", 0)
				notification_text = _format_gain_notification(player_id, result["amount"], "【インシネレート】%d体破壊 × %dG" % [count, effect.get("multiplier", 20)])
		
		"gain_magic_from_spell_cost":
			# クレアボヤンス: 敵スペル魔力合計×50%
			var target_player_id = context.get("from_player_id", -1)
			var card_system = context.get("card_system", null)
			if target_player_id >= 0 and card_system:
				result = gain_magic_from_spell_cost(player_id, effect, target_player_id, card_system)
				if result.get("amount", 0) > 0:
					var total = result.get("spell_cost_total", 0)
					notification_text = _format_gain_notification(player_id, result["amount"], "【クレアボヤンス】敵スペルコスト%dGの%d%%" % [total, effect.get("percentage", 50)])
		
		"drain_magic":
			if from_id >= 0:
				var amount = drain_magic_from_effect(effect, from_id, player_id)
				result = {"success": amount > 0, "amount": amount}
				if amount > 0:
					notification_text = _format_drain_notification(from_id, player_id, amount, "【ドレインマジック】")
		
		"drain_magic_conditional":
			# フラクション: 自分より魔力多い敵から30%奪取
			if from_id >= 0:
				result = drain_magic_conditional(effect, from_id, player_id)
				if result.get("amount", 0) > 0:
					notification_text = _format_drain_notification(from_id, player_id, result["amount"], "【フラクション】%d%%奪取" % effect.get("percentage", 30))
				elif result.get("reason") == "condition_not_met":
					notification_text = "【フラクション】\n条件不成立: 対象の魔力が術者以下"
		
		"drain_magic_by_land_count":
			# ランドドレイン: 敵領地数×G30奪取
			if from_id >= 0:
				result = drain_magic_by_land_count(effect, from_id, player_id)
				if result.get("amount", 0) > 0:
					var lands = result.get("land_count", 0)
					notification_text = _format_drain_notification(from_id, player_id, result["amount"], "【ランドドレイン】%d領地 × %dG" % [lands, effect.get("multiplier", 30)])
		
		"drain_magic_by_lap_diff":
			# スピードペナルティ: 周回数差×G100奪取
			if from_id >= 0:
				result = drain_magic_by_lap_diff(effect, from_id, player_id)
				if result.get("amount", 0) > 0:
					var diff = result.get("diff", 0)
					notification_text = _format_drain_notification(from_id, player_id, result["amount"], "【スピードペナルティ】%d周差 × %dG" % [diff, effect.get("multiplier", 100)])
				elif result.get("diff", 0) <= 0:
					notification_text = "【スピードペナルティ】\n周回数差なし"
		
		"balance_all_magic":
			# レディビジョン: 全プレイヤー魔力平均化
			result = balance_all_magic()
			if result.get("success", false):
				notification_text = "【レディビジョン】\n全プレイヤー魔力を[color=yellow]%dG[/color]に平均化" % result.get("average", 0)
		
		"gain_magic_from_land_chain":
			# ロングライン: 連続領地×G500、未達成ならドロー
			result = gain_magic_from_land_chain(player_id, effect, context)
			var chain = result.get("chain", 0)
			var required = effect.get("required_chain", 4)
			if result.get("condition_met", false):
				notification_text = _format_gain_notification(player_id, result["amount"], "【ロングライン】連続%d領地達成！" % chain)
			else:
				notification_text = "【ロングライン】\n連続%d領地 (必要%d)\n条件未達成 → カードドロー" % [chain, required]
		
		"mhp_to_magic":
			# ドゥームデボラー秘術: MHP×G2を得て、ST&MHP-10
			var tile_index = context.get("tile_index", -1)
			result = mhp_to_magic(player_id, effect, tile_index)
			if result.get("success", false):
				var mhp = result.get("mhp", 0)
				notification_text = _format_gain_notification(player_id, result["amount"], "【ドゥームデボラー】MHP%d × G2\nST&MHP-10" % mhp)
		
		"drain_magic_by_spell_count":
			# ウィッチ秘術: 対象の手札スペル数×G40を奪う
			if from_id >= 0:
				var card_system = context.get("card_system", null)
				result = drain_magic_by_spell_count(effect, from_id, player_id, card_system)
				if result.get("amount", 0) > 0:
					var spell_count = result.get("spell_count", 0)
					notification_text = _format_drain_notification(from_id, player_id, result["amount"], "【ウィッチ】スペル%d枚 × %dG" % [spell_count, effect.get("multiplier", 40)])
				else:
					notification_text = "【ウィッチ】\n対象の手札にスペルがありません"
		
		_:
			print("[SpellMagic] 未対応の効果タイプ: ", effect_type)
	
	# 通知を表示（クリック待ち）
	if notification_text != "":
		await _show_notification_and_wait(notification_text)
	
	return result

## 魔力増加
func add_magic(player_id: int, amount: int) -> void:
	"""
	魔力を増やす
	
	引数:
	  player_id: プレイヤーID（0-3）
	  amount: 増加量
	"""
	if not player_system_ref:
		push_error("SpellMagic: PlayerSystemが設定されていません")
		return
	
	if amount <= 0:
		print("[魔力増加] プレイヤー", player_id + 1, "は0以下の増加量のため何もしません")
		return
	
	if player_id < 0 or player_id >= player_system_ref.players.size():
		push_error("SpellMagic: 無効なプレイヤーID: ", player_id)
		return
	
	var player = player_system_ref.players[player_id]
	if not player:
		push_error("SpellMagic: 無効なプレイヤーID: ", player_id)
		return
	
	player.magic_power += amount
	print("[魔力増加] プレイヤー", player_id + 1, " +", amount, "G → 合計:", player.magic_power, "G")

## 魔力減少
func reduce_magic(player_id: int, amount: int) -> void:
	"""
	魔力を減らす
	
	引数:
	  player_id: プレイヤーID（0-3）
	  amount: 減少量
	"""
	if not player_system_ref:
		push_error("SpellMagic: PlayerSystemが設定されていません")
		return
	
	if amount <= 0:
		print("[魔力減少] プレイヤー", player_id + 1, "は0以下の減少量のため何もしません")
		return
	
	if player_id < 0 or player_id >= player_system_ref.players.size():
		push_error("SpellMagic: 無効なプレイヤーID: ", player_id)
		return
	
	var player = player_system_ref.players[player_id]
	if not player:
		push_error("SpellMagic: 無効なプレイヤーID: ", player_id)
		return
	
	# 0未満にならないようにする
	var actual_reduction = min(amount, player.magic_power)
	player.magic_power -= actual_reduction
	print("[魔力減少] プレイヤー", player_id + 1, " -", actual_reduction, "G → 合計:", player.magic_power, "G")

## 魔力奪取
func steal_magic(from_player_id: int, to_player_id: int, amount: int) -> int:
	"""
	魔力を奪う（相手から自分へ）
	
	引数:
	  from_player_id: 奪われるプレイヤーID
	  to_player_id: 奪うプレイヤーID
	  amount: 奪取量
	
	戻り値:
	  実際に奪った量（相手の魔力が足りない場合は少なくなる）
	"""
	if not player_system_ref:
		push_error("SpellMagic: PlayerSystemが設定されていません")
		return 0
	
	if amount <= 0:
		print("[魔力奪取] 0以下の奪取量のため何もしません")
		return 0
	
	if from_player_id < 0 or from_player_id >= player_system_ref.players.size():
		push_error("SpellMagic: 無効なプレイヤーID: ", from_player_id)
		return 0
	
	if to_player_id < 0 or to_player_id >= player_system_ref.players.size():
		push_error("SpellMagic: 無効なプレイヤーID: ", to_player_id)
		return 0
	
	var from_player = player_system_ref.players[from_player_id]
	var to_player = player_system_ref.players[to_player_id]
	
	# 実際に奪える量を計算
	var actual_amount = min(amount, from_player.magic_power)
	
	from_player.magic_power -= actual_amount
	to_player.magic_power += actual_amount
	
	print("[魔力奪取] プレイヤー", from_player_id + 1, " -", actual_amount, "G → プレイヤー", 
		  to_player_id + 1, " +", actual_amount, "G")
	
	return actual_amount


## 魔力奪取（effect辞書から）
func drain_magic_from_effect(effect: Dictionary, from_player_id: int, to_player_id: int) -> int:
	"""
	effect辞書に基づいて魔力を奪う
	
	引数:
	  effect: 効果辞書 {value, value_type: "fixed"|"percentage"}
	  from_player_id: 奪われるプレイヤーID
	  to_player_id: 奪うプレイヤーID
	
	戻り値:
	  実際に奪った量
	"""
	if not player_system_ref:
		push_error("SpellMagic: PlayerSystemが設定されていません")
		return 0
	
	var value = effect.get("value", 0)
	var value_type = effect.get("value_type", "fixed")
	
	if value <= 0:
		return 0
	
	var current_magic = player_system_ref.get_magic(from_player_id)
	
	var drain_amount = 0
	if value_type == "percentage":
		drain_amount = int(current_magic * value / 100.0)
	else:
		drain_amount = value
	
	# 実際に奪える量（所持魔力以上は奪えない）
	drain_amount = min(drain_amount, current_magic)
	
	if drain_amount <= 0:
		return 0
	
	# 魔力を移動
	player_system_ref.add_magic(from_player_id, -drain_amount)
	player_system_ref.add_magic(to_player_id, drain_amount)
	
	print("[魔力奪取] プレイヤー", from_player_id + 1, " -", drain_amount, "G → プレイヤー", 
		  to_player_id + 1, " +", drain_amount, "G (", value_type, ")")
	
	return drain_amount

# ========================================
# 汎用計算関数
# ========================================

## 計算型魔力獲得（乗算）
func gain_magic_calculated(player_id: int, base_value: int, multiplier: int, description: String = "") -> int:
	var amount = base_value * multiplier
	if amount > 0:
		add_magic(player_id, amount)
		if description != "":
			print("[魔力獲得] ", description, ": ", base_value, " × ", multiplier, "G = ", amount, "G")
	return amount

## 計算型魔力奪取（乗算）
func drain_magic_calculated(from_player_id: int, to_player_id: int, base_value: int, multiplier: int, description: String = "") -> int:
	var amount = base_value * multiplier
	if amount > 0:
		var actual = steal_magic(from_player_id, to_player_id, amount)
		if description != "":
			print("[魔力奪取] ", description, ": ", base_value, " × ", multiplier, "G = ", amount, "G (実際: ", actual, "G)")
		return actual
	return 0

# ========================================
# Phase 1: 基本奪取系
# ========================================

## ランドドレイン: 敵領地数×G30奪取
func drain_magic_by_land_count(effect: Dictionary, from_player_id: int, to_player_id: int) -> Dictionary:
	if not board_system_ref:
		print("[ランドドレイン] BoardSystemが設定されていません")
		return {"success": false, "amount": 0}
	
	var multiplier = effect.get("multiplier", 30)
	var land_count = 0
	
	# 敵の領地数を取得
	if board_system_ref.has_method("get_owner_land_count"):
		land_count = board_system_ref.get_owner_land_count(from_player_id)
	elif "tile_nodes" in board_system_ref:
		for i in board_system_ref.tile_nodes:
			var tile = board_system_ref.tile_nodes[i]
			if tile.owner_id == from_player_id:
				land_count += 1
	
	var actual = drain_magic_calculated(from_player_id, to_player_id, land_count, multiplier, "ランドドレイン")
	return {"success": actual > 0, "amount": actual, "land_count": land_count}

## フラクション: 自分より魔力多い敵から30%奪取（条件付き）
func drain_magic_conditional(effect: Dictionary, from_player_id: int, to_player_id: int) -> Dictionary:
	if not player_system_ref:
		return {"success": false, "amount": 0}
	
	var from_magic = player_system_ref.get_magic(from_player_id)
	var to_magic = player_system_ref.get_magic(to_player_id)
	
	# 条件チェック: 対象が術者より魔力が多いか
	var condition = effect.get("condition", "")
	if condition == "target_has_more_magic":
		if from_magic <= to_magic:
			print("[フラクション] 条件不成立: 対象の魔力(%dG)が術者(%dG)以下" % [from_magic, to_magic])
			return {"success": false, "amount": 0, "reason": "condition_not_met"}
	
	# パーセンテージ奪取
	var percentage = effect.get("percentage", 30)
	var drain_amount = int(from_magic * percentage / 100.0)
	
	if drain_amount <= 0:
		return {"success": false, "amount": 0}
	
	var actual = steal_magic(from_player_id, to_player_id, drain_amount)
	print("[フラクション] 敵魔力%dGの%d%% = %dG奪取" % [from_magic, percentage, actual])
	
	return {"success": actual > 0, "amount": actual}

# ========================================
# Phase 2: 計算・参照型
# ========================================

## マナ: 周回数×G50獲得
func gain_magic_by_lap(player_id: int, effect: Dictionary) -> Dictionary:
	if not game_flow_manager_ref:
		print("[マナ] GameFlowManagerが設定されていません")
		return {"success": false, "amount": 0}
	
	var multiplier = effect.get("multiplier", 50)
	var lap_count = 0
	
	if game_flow_manager_ref.has_method("get_lap_count"):
		lap_count = game_flow_manager_ref.get_lap_count(player_id)
	
	var amount = lap_count * multiplier
	if amount > 0:
		add_magic(player_id, amount)
	
	print("[マナ] 周回数%d × %dG = %dG獲得" % [lap_count, multiplier, amount])
	return {"success": true, "amount": amount, "lap_count": lap_count}

## インシネレート: 破壊数×G20獲得
func gain_magic_from_destroyed_count(player_id: int, effect: Dictionary) -> Dictionary:
	if not game_flow_manager_ref:
		print("[インシネレート] GameFlowManagerが設定されていません")
		return {"success": false, "amount": 0}
	
	var multiplier = effect.get("multiplier", 20)
	var destroy_count = 0
	
	if game_flow_manager_ref.has_method("get_destroy_count"):
		destroy_count = game_flow_manager_ref.get_destroy_count()
	
	var amount = destroy_count * multiplier
	if amount > 0:
		add_magic(player_id, amount)
	
	print("[インシネレート] 破壊数%d × %dG = %dG獲得" % [destroy_count, multiplier, amount])
	
	# reset_count: trueの場合、破壊数を0にリセット
	if effect.get("reset_count", false):
		if game_flow_manager_ref.has_method("reset_destroy_count"):
			game_flow_manager_ref.reset_destroy_count()
			print("[インシネレート] 破壊数をリセット")
	
	return {"success": true, "amount": amount, "destroy_count": destroy_count}

## クレアボヤンス: 敵手札スペルのコスト合計×50%獲得
func gain_magic_from_spell_cost(player_id: int, effect: Dictionary, target_player_id: int, card_system) -> Dictionary:
	if not card_system:
		print("[クレアボヤンス] CardSystemが設定されていません")
		return {"success": false, "amount": 0}
	
	var percentage = effect.get("percentage", 50)
	
	# 敵手札のスペルカードのコスト合計を計算
	var hand = card_system.get_all_cards_for_player(target_player_id)
	var spell_cost_total = 0
	for card in hand:
		if card.get("type", "") == "spell":
			var cost = card.get("cost", {})
			# costが辞書の場合とintの場合に対応
			if cost is Dictionary:
				spell_cost_total += cost.get("mp", 0)
			elif cost is int:
				spell_cost_total += cost
	
	# パーセンテージを適用
	var amount = int(spell_cost_total * percentage / 100.0)
	
	if amount > 0:
		add_magic(player_id, amount)
		print("[クレアボヤンス] 敵手札スペルコスト合計%dGの%d%% = %dG獲得" % [spell_cost_total, percentage, amount])
	else:
		print("[クレアボヤンス] 敵手札にスペルがないか、コスト0")
	
	return {"success": amount > 0, "amount": amount, "spell_cost_total": spell_cost_total}

## スピードペナルティ: 対象の周回数と術者の周回数の差×G100奪取
func drain_magic_by_lap_diff(effect: Dictionary, from_player_id: int, to_player_id: int) -> Dictionary:
	if not game_flow_manager_ref or not player_system_ref:
		print("[スピードペナルティ] システム参照が設定されていません")
		return {"success": false, "amount": 0}
	
	var multiplier = effect.get("multiplier", 100)
	
	# 対象（敵）の周回数と術者の周回数を取得
	var target_lap = game_flow_manager_ref.get_lap_count(from_player_id)  # 対象敵の周回数
	var caster_lap = game_flow_manager_ref.get_lap_count(to_player_id)    # 術者の周回数
	var diff = target_lap - caster_lap
	
	if diff <= 0:
		print("[スピードペナルティ] 周回数差なし（対象:%d周, 術者:%d周）" % [target_lap, caster_lap])
		return {"success": false, "amount": 0, "diff": 0}
	
	var actual = drain_magic_calculated(from_player_id, to_player_id, diff, multiplier, "スピードペナルティ")
	print("[スピードペナルティ] 対象%d周 - 術者%d周 = %d周差 × %dG" % [target_lap, caster_lap, diff, multiplier])
	return {"success": actual > 0, "amount": actual, "diff": diff, "target_lap": target_lap, "caster_lap": caster_lap}

# ========================================
# Phase 4: グローバル効果
# ========================================

## ロングライン: 連続領地4つでG500、未達成ならドロー
func gain_magic_from_land_chain(player_id: int, effect: Dictionary, _context: Dictionary) -> Dictionary:
	if not board_system_ref:
		print("[ロングライン] BoardSystemが設定されていません")
		return {"success": false, "amount": 0}
	
	var required_chain = effect.get("required_chain", 4)
	var amount = effect.get("amount", 500)
	
	# 連続領地数を計算
	var max_chain = _calculate_max_land_chain(player_id)
	
	if max_chain >= required_chain:
		# 条件達成: 魔力獲得
		add_magic(player_id, amount)
		print("[ロングライン] 連続領地%d達成！ %dG獲得" % [max_chain, amount])
		return {"success": true, "amount": amount, "chain": max_chain, "condition_met": true}
	else:
		# 条件未達成: フォールバック効果（ドロー）を返す
		print("[ロングライン] 連続領地%d（必要%d）未達成" % [max_chain, required_chain])
		var fallback = effect.get("fallback_effect", {})
		return {"success": true, "amount": 0, "chain": max_chain, "condition_met": false, "next_effect": fallback}

## 連続領地の最大数を計算
func _calculate_max_land_chain(player_id: int) -> int:
	if not board_system_ref or not "tile_nodes" in board_system_ref:
		return 0
	
	var max_chain = 0
	var current_chain = 0
	var total_tiles = board_system_ref.tile_nodes.size()
	
	# マップを1周して連続領地を数える
	for i in range(total_tiles):
		var tile = board_system_ref.tile_nodes[i]
		if tile.owner_id == player_id:
			current_chain += 1
			if current_chain > max_chain:
				max_chain = current_chain
		else:
			current_chain = 0
	
	# 周回マップの場合、最初と最後が繋がっているかチェック
	if total_tiles > 0:
		var first_tile = board_system_ref.tile_nodes[0]
		var last_tile = board_system_ref.tile_nodes[total_tiles - 1]
		if first_tile.owner_id == player_id and last_tile.owner_id == player_id:
			# 最初から連続している数を数える
			var start_chain = 0
			for i in range(total_tiles):
				var tile = board_system_ref.tile_nodes[i]
				if tile.owner_id == player_id:
					start_chain += 1
				else:
					break
			# 最後から連続している数を数える
			var end_chain = 0
			for i in range(total_tiles - 1, -1, -1):
				var tile = board_system_ref.tile_nodes[i]
				if tile.owner_id == player_id:
					end_chain += 1
				else:
					break
			# 繋がっている場合、合計が最大チェーンを超えるかチェック
			var wrap_chain = start_chain + end_chain
			if wrap_chain > max_chain:
				max_chain = wrap_chain
	
	return max_chain

## レディビジョン: 全プレイヤー魔力平均化
func balance_all_magic() -> Dictionary:
	if not player_system_ref:
		return {"success": false}
	
	var total_magic = 0
	var player_count = player_system_ref.players.size()
	
	# 合計を計算
	for player in player_system_ref.players:
		total_magic += player.magic_power
	
	# 平均を計算（端数切り捨て）
	var average = int(total_magic / player_count)
	
	# 各プレイヤーに平均値を設定
	var changes = []
	for i in range(player_count):
		var old_magic = player_system_ref.players[i].magic_power
		player_system_ref.players[i].magic_power = average
		changes.append({"player_id": i, "old": old_magic, "new": average})
		print("[レディビジョン] プレイヤー%d: %dG → %dG" % [i + 1, old_magic, average])
	
	print("[レディビジョン] 全プレイヤー魔力を%dGに平均化" % average)
	return {"success": true, "average": average, "changes": changes}

# ========================================
# バウンティハント（賞金首）
# ========================================

## バウンティハント報酬を適用（バトル終了時に呼び出す）
## @param loser_creature: 敗者のクリーチャーデータ
## @param winner_creature: 勝者のクリーチャーデータ
## @return Dictionary: {success, reward, caster_id}
func apply_bounty_reward(loser_creature: Dictionary, winner_creature: Dictionary) -> Dictionary:
	var result = {"success": false, "reward": 0, "caster_id": -1}
	
	if loser_creature.is_empty():
		return result
	
	# 敗者の呪いを確認
	var curse = loser_creature.get("curse", {})
	if curse.is_empty():
		return result
	
	if curse.get("curse_type", "") != "bounty":
		return result
	
	var params = curse.get("params", {})
	var reward = params.get("reward", 300)
	var requires_weapon = params.get("requires_weapon", true)
	var caster_id = params.get("caster_id", -1)
	
	if caster_id < 0:
		print("[バウンティハント] 術者IDが不正: ", caster_id)
		return result
	
	result["caster_id"] = caster_id
	result["reward"] = reward
	
	# 武器使用チェック
	if requires_weapon:
		var winner_items = winner_creature.get("items", [])
		var used_weapon = false
		
		for item in winner_items:
			var item_type = item.get("item_type", "")
			if item_type == "武器":
				used_weapon = true
				break
		
		if not used_weapon:
			print("[バウンティハント] 武器未使用のため報酬なし")
			return result
	
	# 報酬付与
	add_magic(caster_id, reward)
	result["success"] = true
	
	var loser_name = loser_creature.get("name", "クリーチャー")
	print("[バウンティハント] 賞金首「%s」撃破！プレイヤー%d が %dG獲得" % [loser_name, caster_id + 1, reward])
	
	return result

## バウンティハント報酬を適用して通知表示（非同期）
func apply_bounty_reward_with_notification(loser_creature: Dictionary, winner_creature: Dictionary) -> Dictionary:
	var result = apply_bounty_reward(loser_creature, winner_creature)
	
	if result["success"]:
		var loser_name = loser_creature.get("name", "クリーチャー")
		var notification_text = "【バウンティハント】\n賞金首「%s」撃破！\n[color=yellow]+%dG[/color] 獲得！" % [loser_name, result["reward"]]
		await _show_notification_and_wait(notification_text)
	
	return result

# ========================================
# 通知システム
# ========================================

## 通知表示＋クリック待ち
func _show_notification_and_wait(text: String) -> void:
	if spell_cast_notification_ui:
		spell_cast_notification_ui.show_notification_and_wait(text)
		await spell_cast_notification_ui.click_confirmed

## 魔力獲得の通知テキスト生成
@warning_ignore("unused_variable")
func _format_gain_notification(player_id: int, amount: int, source: String = "") -> String:
	var _player_name = "プレイヤー%d" % (player_id + 1)
	if player_system_ref and player_id >= 0 and player_id < player_system_ref.players.size():
		_player_name = player_system_ref.players[player_id].name
	
	var text = "[color=yellow]+%dG[/color] 獲得！" % amount
	if source != "":
		text = "%s\n%s" % [source, text]
	return text

## 魔力奪取の通知テキスト生成
@warning_ignore("unused_variable")
func _format_drain_notification(from_id: int, to_id: int, amount: int, source: String = "") -> String:
	var from_name = "プレイヤー%d" % (from_id + 1)
	var _to_name = "プレイヤー%d" % (to_id + 1)
	if player_system_ref:
		if from_id >= 0 and from_id < player_system_ref.players.size():
			from_name = player_system_ref.players[from_id].name
		if to_id >= 0 and to_id < player_system_ref.players.size():
			_to_name = player_system_ref.players[to_id].name
	
	var text = "%sから[color=yellow]%dG[/color]奪取！" % [from_name, amount]
	if source != "":
		text = "%s\n%s" % [source, text]
	return text

# ========================================
# 土地呪い（ブラストトラップ等）
# ========================================

## 土地呪い発動（移動完了時に呼ばれる公開メソッド）
func trigger_land_curse(tile_index: int, stopped_player_id: int) -> void:
	if not board_system_ref:
		return
	
	var tile_info = board_system_ref.get_tile_info(tile_index)
	_check_and_trigger_land_curse(tile_index, stopped_player_id, tile_info)

## 土地呪いチェック＆発動
func _check_and_trigger_land_curse(tile_index: int, stopped_player_id: int, tile_info: Dictionary) -> void:
	var creature = tile_info.get("creature", {})
	if creature.is_empty():
		return
	
	var curse = creature.get("curse", {})
	if curse.is_empty():
		return
	
	var curse_type = curse.get("curse_type", "")
	var params = curse.get("params", {})
	var trigger = params.get("trigger", "")
	
	# on_enemy_stop トリガーのみ処理
	if trigger != "on_enemy_stop":
		return
	
	# 土地の所有者と停止プレイヤーが異なる場合のみ発動
	var owner_id = tile_info.get("owner", -1)
	if owner_id == stopped_player_id:
		return  # 自分の土地には発動しない
	
	print("[土地呪い発動] %s (タイル%d)" % [params.get("name", curse_type), tile_index])
	
	# 呪い効果を実行
	var curse_effects = params.get("curse_effects", [])
	for effect in curse_effects:
		_apply_land_curse_effect(effect, tile_index, stopped_player_id, creature)
	
	# one_shot の場合は呪いを削除
	if params.get("one_shot", false):
		creature.erase("curse")
		print("[土地呪い] 1回発動のため呪いを解除")

## 土地呪い効果を適用
func _apply_land_curse_effect(effect: Dictionary, tile_index: int, stopped_player_id: int, creature: Dictionary) -> void:
	var effect_type = effect.get("effect_type", "")
	var target = effect.get("target", "")
	
	match effect_type:
		"reduce_magic_percentage":
			# 停止プレイヤーの魔力を割合減少
			if target == "stopped_player":
				var percentage = effect.get("percentage", 0)
				var current_magic = player_system_ref.get_magic(stopped_player_id)
				var reduction = int(current_magic * percentage / 100.0)
				if reduction > 0:
					player_system_ref.add_magic(stopped_player_id, -reduction)
					print("[土地呪い効果] プレイヤー%d の魔力 -%dG (%d%%)" % [stopped_player_id + 1, reduction, percentage])
		
		"damage_creature":
			# 土地のクリーチャーにダメージ
			if target == "land_creature":
				var amount = effect.get("amount", 0)
				if amount > 0 and not creature.is_empty():
					# current_hpを減少
					var current_hp = creature.get("current_hp", creature.get("hp", 0))
					var new_hp = max(0, current_hp - amount)
					creature["current_hp"] = new_hp
					print("[土地呪い効果] %s に %dダメージ (HP: %d → %d)" % [creature.get("name", "?"), amount, current_hp, new_hp])
					
					# HP0で破壊（SpellDamage経由で死亡効果を処理）
					if new_hp <= 0:
						var tile = board_system_ref.tile_nodes.get(tile_index)
						if tile and game_flow_manager_ref and game_flow_manager_ref.spell_phase_handler:
							var spell_damage = game_flow_manager_ref.spell_phase_handler.spell_damage
							if spell_damage:
								spell_damage._destroy_creature(tile)
							else:
								# フォールバック
								board_system_ref.remove_creature(tile_index)
								board_system_ref.set_tile_owner(tile_index, -1)
						else:
							board_system_ref.remove_creature(tile_index)
							board_system_ref.set_tile_owner(tile_index, -1)
						print("[土地呪い効果] %s は破壊されました" % creature.get("name", "?"))

# ========================================
# 秘術用効果（ゴールドトーテム等）
# ========================================

## 自壊効果（クリーチャー破壊＋土地無所有）
func apply_self_destroy(tile_index: int, clear_land: bool = true) -> bool:
	if tile_index < 0 or not board_system_ref:
		return false
	
	var tile = board_system_ref.tile_nodes.get(tile_index)
	if not tile:
		return false
	
	var creature_name = tile.creature_data.get("name", "クリーチャー") if tile.creature_data else "クリーチャー"
	
	# クリーチャーを削除
	board_system_ref.remove_creature(tile_index)
	
	# 土地を無所有にする
	if clear_land:
		board_system_ref.set_tile_owner(tile_index, -1)
		print("[秘術効果] %s が自壊、土地は無所有になりました" % creature_name)
	else:
		print("[秘術効果] %s が自壊しました" % creature_name)
	
	return true


# ========================================
# 秘術用魔力獲得効果
# ========================================

## MHP変換（ドゥームデボラー秘術）: MHP×G2を得て、ST&MHP-10
func mhp_to_magic(player_id: int, effect: Dictionary, tile_index: int) -> Dictionary:
	if tile_index < 0 or not board_system_ref or not player_system_ref:
		return {"success": false}
	
	var tile_info = board_system_ref.get_tile_info(tile_index)
	var creature = tile_info.get("creature", {})
	if creature.is_empty():
		return {"success": false}
	
	# MHPを計算
	var base_hp = creature.get("hp", 0)
	var base_up_hp = creature.get("base_up_hp", 0)
	var mhp = base_hp + base_up_hp
	
	# 魔力獲得量を計算
	var multiplier = effect.get("multiplier", 2)
	var amount = mhp * multiplier
	
	# 魔力を獲得
	player_system_ref.add_magic(player_id, amount)
	print("[ドゥームデボラー秘術] MHP%d × G%d = %dG 獲得" % [mhp, multiplier, amount])
	
	# ステータスペナルティを適用
	var stat_penalty = effect.get("stat_penalty", {})
	var ap_change = stat_penalty.get("ap", 0)
	var hp_change = stat_penalty.get("max_hp", 0)
	
	if not creature.has("base_up_ap"):
		creature["base_up_ap"] = 0
	if not creature.has("base_up_hp"):
		creature["base_up_hp"] = 0
	
	creature["base_up_ap"] += ap_change
	creature["base_up_hp"] += hp_change
	
	# current_hpも調整（MHP減少に合わせる）
	var new_mhp = base_hp + creature["base_up_hp"]
	var current_hp = creature.get("current_hp", mhp)
	if current_hp > new_mhp:
		creature["current_hp"] = new_mhp
	
	print("[ドゥームデボラー秘術] ペナルティ適用: AP%+d, MHP%+d" % [ap_change, hp_change])
	
	return {"success": true, "amount": amount, "mhp": mhp}


## スペル数魔力奪取（ウィッチ秘術）: 対象の手札スペル数×G40を奪う
func drain_magic_by_spell_count(effect: Dictionary, from_id: int, to_id: int, card_system) -> Dictionary:
	if not player_system_ref or not card_system:
		return {"success": false, "amount": 0}
	
	# 対象の手札からスペル数をカウント
	var hand = card_system.get_all_cards_for_player(from_id)
	var spell_count = 0
	for card in hand:
		if card.get("type", "") == "spell":
			spell_count += 1
	
	if spell_count == 0:
		print("[ウィッチ秘術] 対象の手札にスペルがありません")
		return {"success": false, "amount": 0, "spell_count": 0}
	
	var multiplier = effect.get("multiplier", 40)
	var amount = spell_count * multiplier
	
	# 奪取（from から減らして to に加える）
	var from_magic = player_system_ref.get_magic(from_id)
	var actual_amount = min(amount, from_magic)  # 持っている分だけ奪う
	
	if actual_amount > 0:
		player_system_ref.add_magic(from_id, -actual_amount)
		player_system_ref.add_magic(to_id, actual_amount)
		print("[ウィッチ秘術] スペル%d枚 × G%d = %dG 奪取" % [spell_count, multiplier, actual_amount])
	
	return {"success": true, "amount": actual_amount, "spell_count": spell_count}
