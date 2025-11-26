extends Node
class_name SpellMagic

## 魔力操作の汎用化モジュール
## バトル外・バトル中のマップ効果として使用する

var player_system_ref: PlayerSystem = null

func setup(player_system: PlayerSystem):
	player_system_ref = player_system
	print("SpellMagic: セットアップ完了")

## 統合エントリポイント - effect辞書から適切な処理を実行
func apply_effect(effect: Dictionary, player_id: int, context: Dictionary = {}) -> void:
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"gain_magic":
			var amount = effect.get("amount", 0)
			add_magic(player_id, amount)
		
		"gain_magic_by_rank":
			var rank = context.get("rank", 1)
			var multiplier = effect.get("multiplier", 50)
			var amount = rank * multiplier
			add_magic(player_id, amount)
			print("[魔力効果] 順位魔力: %d位 × %dG = %dG" % [rank, multiplier, amount])
		
		"drain_magic":
			var from_id = context.get("from_player_id", -1)
			if from_id >= 0:
				drain_magic_from_effect(effect, from_id, player_id)
		
		_:
			print("[SpellMagic] 未対応の効果タイプ: ", effect_type)

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
