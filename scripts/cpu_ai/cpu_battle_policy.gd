# CPUバトルポリシークラス
# キャラクターの性格に基づいてバトル判断の重み付けを管理

extends RefCounted
class_name CPUBattlePolicy

const GameConstantsScript = preload("res://scripts/game_constants.gd")

# =============================================================================
# 侵略時の行動タイプ
# =============================================================================
enum AttackAction {
	ALWAYS_BATTLE,         # 必ずバトルを仕掛ける（勝敗関係なく）
	BATTLE_IF_BOTH_NO_ITEM,# 両方アイテムなしで勝てるなら戦闘
	BATTLE_IF_WIN_VS_ENEMY_ITEM, # CPUアイテムなし、防衛側アイテム使用でも勝てるなら戦闘（従来ワーストケース）
	NEVER_BATTLE           # 必ずバトルを仕掛けない
}

# =============================================================================
# 防衛時の行動タイプ
# =============================================================================
enum DefenseAction {
	NO_ITEM,       # アイテムを使用しない
	ALWAYS_PROTECT # 従来ロジック（勝てるようにアイテム使用）
}

# =============================================================================
# 重み設定
# =============================================================================

# 侵略時の重み（デフォルト値）
var attack_weights: Dictionary = {
	AttackAction.ALWAYS_BATTLE: 0.0,
	AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.0,
	AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 1.0,  # 従来ロジック
	AttackAction.NEVER_BATTLE: 0.0
}

# 防衛時の重み（デフォルト値）
var defense_weights: Dictionary = {
	DefenseAction.NO_ITEM: 0.0,
	DefenseAction.ALWAYS_PROTECT: 1.0
}

# 防衛時の優先保護設定
var protect_mystic_arts: bool = false      # アルカナアーツ持ちを優先保護
var protect_element_match: bool = false    # 属性一致を優先保護
var protect_by_value_enabled: bool = false # 土地価値による判断を有効化
var protect_by_value_threshold: int = 200  # この通行料以上なら優先保護
var protect_by_value_min_items: int = 2    # 低価値ドミニオはこの枚数以上ある場合のみアイテム使用

# 召喚確率
var summon_rate: float = -1.0  # 旧版（互換性のため残す）、-1.0ならGameConstants.CPU_SUMMON_RATEを使用
var summon_rate_match: float = -1.0  # 属性一致時の召喚確率（-1.0なら1.0を使用）
var summon_rate_mismatch: float = -1.0  # 属性不一致時の召喚確率（-1.0ならGameConstants.CPU_SUMMON_RATEを使用）

# スペル/ミスティックアーツ使用確率（1.0 = 必ず使う、0.0 = 使わない）
var spell_use_rate: float = 1.0

# ドミニオコマンド使用確率（1.0 = 必ず使う、0.0 = 使わない）
var dominio_use_rate: float = 1.0

# =============================================================================
# 初期化
# =============================================================================

## JSONデータから重みを設定
func load_from_json(policy_data: Dictionary) -> void:
	if policy_data.is_empty():
		return
	
	# 侵略時の重み
	if policy_data.has("attack"):
		var attack_data = policy_data["attack"]
		if attack_data.has("always_battle"):
			attack_weights[AttackAction.ALWAYS_BATTLE] = float(attack_data["always_battle"])
		if attack_data.has("both_no_item"):
			attack_weights[AttackAction.BATTLE_IF_BOTH_NO_ITEM] = float(attack_data["both_no_item"])
		if attack_data.has("vs_enemy_item"):
			attack_weights[AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM] = float(attack_data["vs_enemy_item"])
		if attack_data.has("never_battle"):
			attack_weights[AttackAction.NEVER_BATTLE] = float(attack_data["never_battle"])
	
	# 防衛時の重み
	if policy_data.has("defense"):
		var defense_data = policy_data["defense"]
		if defense_data.has("no_item"):
			defense_weights[DefenseAction.NO_ITEM] = float(defense_data["no_item"])
		if defense_data.has("always_protect"):
			defense_weights[DefenseAction.ALWAYS_PROTECT] = float(defense_data["always_protect"])
		
		# 優先保護設定
		if defense_data.has("protect_mystic_arts"):
			protect_mystic_arts = bool(defense_data["protect_mystic_arts"])
		if defense_data.has("protect_element_match"):
			protect_element_match = bool(defense_data["protect_element_match"])
		if defense_data.has("protect_by_value"):
			var pbv = defense_data["protect_by_value"]
			if typeof(pbv) == TYPE_DICTIONARY:
				protect_by_value_enabled = pbv.get("enabled", false)
				protect_by_value_threshold = int(pbv.get("threshold", 200))
				protect_by_value_min_items = int(pbv.get("min_defense_items", 2))
	
	# 召喚確率（旧版との互換性）
	if policy_data.has("summon_rate"):
		summon_rate = float(policy_data["summon_rate"])
	
	# 召喚確率（属性一致時）
	if policy_data.has("summon_rate_match"):
		summon_rate_match = float(policy_data["summon_rate_match"])
	
	# 召喚確率（属性不一致時）
	if policy_data.has("summon_rate_mismatch"):
		summon_rate_mismatch = float(policy_data["summon_rate_mismatch"])
	
	# スペル使用確率
	if policy_data.has("spell_use_rate"):
		spell_use_rate = float(policy_data["spell_use_rate"])
	
	# ドミニオコマンド使用確率
	if policy_data.has("dominio_use_rate"):
		dominio_use_rate = float(policy_data["dominio_use_rate"])

# =============================================================================
# 抽選ロジック
# =============================================================================

## 侵略時の行動を抽選で決定
## evaluation_result: バトル評価結果
##   - can_win_both_no_item: 両方アイテムなしで勝てるか
##   - can_win_vs_enemy_item: 防衛側アイテム使用でも勝てるか（ワーストケース）
func decide_attack_action(evaluation_result: Dictionary) -> AttackAction:
	var available_weights: Dictionary = {}
	
	# ALWAYS_BATTLE: 常に選択可能
	if attack_weights[AttackAction.ALWAYS_BATTLE] > 0:
		available_weights[AttackAction.ALWAYS_BATTLE] = attack_weights[AttackAction.ALWAYS_BATTLE]
	
	# BATTLE_IF_BOTH_NO_ITEM: 両方アイテムなしで勝てる場合のみ
	if evaluation_result.get("can_win_both_no_item", false):
		if attack_weights[AttackAction.BATTLE_IF_BOTH_NO_ITEM] > 0:
			available_weights[AttackAction.BATTLE_IF_BOTH_NO_ITEM] = attack_weights[AttackAction.BATTLE_IF_BOTH_NO_ITEM]
	
	# BATTLE_IF_WIN_VS_ENEMY_ITEM: 防衛側アイテム使用でも勝てる場合のみ（ワーストケース）
	if evaluation_result.get("can_win_vs_enemy_item", false):
		if attack_weights[AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM] > 0:
			available_weights[AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM] = attack_weights[AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM]
	
	# NEVER_BATTLE: 常に選択可能
	if attack_weights[AttackAction.NEVER_BATTLE] > 0:
		available_weights[AttackAction.NEVER_BATTLE] = attack_weights[AttackAction.NEVER_BATTLE]
	
	print("[CPUBattlePolicy] 選択可能な行動: %s" % available_weights)
	
	# 選択可能な行動がない場合はNEVER_BATTLE
	if available_weights.is_empty():
		print("[CPUBattlePolicy] 選択可能な行動なし → NEVER_BATTLE")
		return AttackAction.NEVER_BATTLE
	
	var selected = _weighted_random_select(available_weights)
	print("[CPUBattlePolicy] 抽選結果: %s" % AttackAction.keys()[selected])
	return selected as AttackAction

## 防衛時の行動を決定
## defense_context: 防衛評価コンテキスト
##   - defender: 防御側クリーチャー
##   - tile_info: タイル情報
##   - toll: 通行料
##   - defense_item_count: 手札の防御アイテム数
func decide_defense_action(defense_context: Dictionary) -> DefenseAction:
	var defender = defense_context.get("defender", {})
	var tile_info = defense_context.get("tile_info", {})
	var toll = defense_context.get("toll", 0)
	var defense_item_count = defense_context.get("defense_item_count", 0)
	
	# 1. 優先保護対象かどうかを判定
	var is_priority_target = false
	
	# アルカナアーツ持ちを優先保護
	if protect_mystic_arts:
		if _has_mystic_arts(defender):
			is_priority_target = true
			print("[CPUBattlePolicy] アルカナアーツ持ちクリーチャー → 優先保護対象")
	
	# 属性一致を優先保護
	if protect_element_match:
		var tile_element = tile_info.get("element", "")
		var creature_element = defender.get("element", "")
		if tile_element != "" and tile_element == creature_element:
			is_priority_target = true
			print("[CPUBattlePolicy] 属性一致（%s） → 優先保護対象" % tile_element)
	
	# 土地価値による判断
	if protect_by_value_enabled:
		if toll >= protect_by_value_threshold:
			is_priority_target = true
			print("[CPUBattlePolicy] 高価値ドミニオ（通行料%d >= %d） → 優先保護対象" % [toll, protect_by_value_threshold])
		elif defense_item_count >= protect_by_value_min_items:
			is_priority_target = true
			print("[CPUBattlePolicy] 防御アイテム十分（%d >= %d） → 保護可能" % [defense_item_count, protect_by_value_min_items])
	
	# 2. 優先保護対象の場合は強制的にALWAYS_PROTECT
	if is_priority_target:
		print("[CPUBattlePolicy] 防衛判断: ALWAYS_PROTECT（優先保護対象）")
		return DefenseAction.ALWAYS_PROTECT
	
	# 3. 優先保護対象でない場合は重み付き抽選
	print("[CPUBattlePolicy] defense_weights: NO_ITEM=%.1f, ALWAYS_PROTECT=%.1f" % [
		defense_weights[DefenseAction.NO_ITEM],
		defense_weights[DefenseAction.ALWAYS_PROTECT]
	])
	var available_weights: Dictionary = {}
	
	if defense_weights[DefenseAction.NO_ITEM] > 0:
		available_weights[DefenseAction.NO_ITEM] = defense_weights[DefenseAction.NO_ITEM]
	
	if defense_weights[DefenseAction.ALWAYS_PROTECT] > 0:
		available_weights[DefenseAction.ALWAYS_PROTECT] = defense_weights[DefenseAction.ALWAYS_PROTECT]
	
	# 選択可能な行動がない場合はNO_ITEM
	if available_weights.is_empty():
		print("[CPUBattlePolicy] 防衛判断: NO_ITEM（デフォルト）")
		return DefenseAction.NO_ITEM
	
	var selected = _weighted_random_select(available_weights)
	print("[CPUBattlePolicy] 防衛判断: %s（抽選）" % DefenseAction.keys()[selected])
	return selected as DefenseAction

## アルカナアーツ持ちかどうかを判定
func _has_mystic_arts(creature: Dictionary) -> bool:
	var ability_parsed = creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "アルカナアーツ" in keywords

## 重み付き抽選
func _weighted_random_select(weights: Dictionary) -> int:
	# 合計を計算
	var total: float = 0.0
	for action in weights:
		total += weights[action]
	
	if total <= 0:
		return weights.keys()[0]
	
	# 乱数で抽選
	var rand = randf() * total
	var cumulative: float = 0.0
	
	for action in weights:
		cumulative += weights[action]
		if rand <= cumulative:
			return action
	
	# フォールバック
	return weights.keys().back()

# =============================================================================
# プリセット
# =============================================================================

## チュートリアル用（常に戦闘、アイテム使用しない）
static func create_tutorial_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 1.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.0,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 0.0,
		AttackAction.NEVER_BATTLE: 0.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM: 1.0,
		DefenseAction.ALWAYS_PROTECT: 0.0
	}
	policy.summon_rate = 1.0  # チュートリアルでは必ず召喚
	return policy

## 従来ロジック（ワーストケースで勝てるなら戦闘、アイテム使用）
static func create_standard_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 0.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.0,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 1.0,
		AttackAction.NEVER_BATTLE: 0.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM: 0.0,
		DefenseAction.ALWAYS_PROTECT: 1.0
	}
	return policy

## 楽観的（両方アイテムなしで勝てるなら戦闘）
static func create_optimistic_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 0.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 1.0,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 0.0,
		AttackAction.NEVER_BATTLE: 0.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM: 0.5,
		DefenseAction.ALWAYS_PROTECT: 0.5
	}
	return policy

## 消極的（戦闘しない、アイテム使用しない）
static func create_passive_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 0.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.0,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 0.0,
		AttackAction.NEVER_BATTLE: 1.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM: 1.0,
		DefenseAction.ALWAYS_PROTECT: 0.0
	}
	return policy

## バランス型（従来ワーストケース + 少し楽観的、アイテム使用）
static func create_balanced_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 0.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.3,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 1.0,
		AttackAction.NEVER_BATTLE: 0.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM: 0.0,
		DefenseAction.ALWAYS_PROTECT: 1.0
	}
	return policy

# =============================================================================
# デバッグ
# =============================================================================

func print_weights() -> void:
	print("[CPUBattlePolicy] ポリシー読み込み完了")

## 召喚確率を取得（旧版、互換性のため残す）
func get_summon_rate() -> float:
	if summon_rate >= 0:
		return summon_rate
	return GameConstantsScript.CPU_SUMMON_RATE

## 属性一致時の召喚確率を取得
func get_summon_rate_match() -> float:
	if summon_rate_match >= 0:
		return summon_rate_match
	# 旧版summon_rateが設定されていればそれを使用（互換性）
	if summon_rate >= 0:
		return summon_rate
	return 1.0  # デフォルトは必ず召喚

## 属性不一致時の召喚確率を取得
func get_summon_rate_mismatch() -> float:
	if summon_rate_mismatch >= 0:
		return summon_rate_mismatch
	# 旧版summon_rateが設定されていればそれを使用（互換性）
	if summon_rate >= 0:
		return summon_rate
	return GameConstantsScript.CPU_SUMMON_RATE

## 召喚するか確率判定（属性一致/不一致を考慮）
func should_summon(is_element_match: bool) -> bool:
	var rate = get_summon_rate_match() if is_element_match else get_summon_rate_mismatch()
	return randf() < rate

## スペル使用確率を取得
func get_spell_use_rate() -> float:
	return spell_use_rate

## スペルを使用するか確率判定
func should_use_spell() -> bool:
	return randf() < spell_use_rate

## ドミニオコマンド使用確率を取得
func get_dominio_use_rate() -> float:
	return dominio_use_rate

## ドミニオコマンドを使用するか確率判定
func should_use_dominio() -> bool:
	return randf() < dominio_use_rate
