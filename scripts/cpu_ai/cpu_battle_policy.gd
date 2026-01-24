# CPUバトルポリシークラス
# キャラクターの性格に基づいてバトル判断の重み付けを管理

extends RefCounted
class_name CPUBattlePolicy

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
	NO_ITEM_DEFEND,   # アイテムなしで生き残れるなら使わない
	WITH_ITEM_DEFEND, # アイテムを使って確実に生き残る
	SURRENDER         # 防衛しない（領地を明け渡す）
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
	DefenseAction.NO_ITEM_DEFEND: 1.0,
	DefenseAction.WITH_ITEM_DEFEND: 1.0,
	DefenseAction.SURRENDER: 0.0
}

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
			defense_weights[DefenseAction.NO_ITEM_DEFEND] = float(defense_data["no_item"])
		if defense_data.has("with_item"):
			defense_weights[DefenseAction.WITH_ITEM_DEFEND] = float(defense_data["with_item"])
		if defense_data.has("surrender"):
			defense_weights[DefenseAction.SURRENDER] = float(defense_data["surrender"])

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

## 防衛時の行動を抽選で決定
## evaluation_result: 防衛評価結果（can_survive_without_item, can_survive_with_itemなど）
func decide_defense_action(evaluation_result: Dictionary) -> DefenseAction:
	var available_weights: Dictionary = {}
	
	# NO_ITEM_DEFEND: アイテムなしで生き残れる場合のみ
	if evaluation_result.get("can_survive_without_item", false):
		if defense_weights[DefenseAction.NO_ITEM_DEFEND] > 0:
			available_weights[DefenseAction.NO_ITEM_DEFEND] = defense_weights[DefenseAction.NO_ITEM_DEFEND]
	
	# WITH_ITEM_DEFEND: アイテムありで生き残れる場合のみ
	if evaluation_result.get("can_survive_with_item", false):
		if defense_weights[DefenseAction.WITH_ITEM_DEFEND] > 0:
			available_weights[DefenseAction.WITH_ITEM_DEFEND] = defense_weights[DefenseAction.WITH_ITEM_DEFEND]
	
	# SURRENDER: 常に選択可能
	if defense_weights[DefenseAction.SURRENDER] > 0:
		available_weights[DefenseAction.SURRENDER] = defense_weights[DefenseAction.SURRENDER]
	
	# 選択可能な行動がない場合はSURRENDER
	if available_weights.is_empty():
		return DefenseAction.SURRENDER
	
	return _weighted_random_select(available_weights) as DefenseAction

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

## チュートリアル用（常に戦闘）
static func create_tutorial_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 1.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.0,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 0.0,
		AttackAction.NEVER_BATTLE: 0.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM_DEFEND: 1.0,
		DefenseAction.WITH_ITEM_DEFEND: 0.0,
		DefenseAction.SURRENDER: 0.0
	}
	return policy

## 従来ロジック（ワーストケースで勝てるなら戦闘）
static func create_standard_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 0.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.0,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 1.0,
		AttackAction.NEVER_BATTLE: 0.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM_DEFEND: 1.0,
		DefenseAction.WITH_ITEM_DEFEND: 1.0,
		DefenseAction.SURRENDER: 0.0
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
		DefenseAction.NO_ITEM_DEFEND: 1.0,
		DefenseAction.WITH_ITEM_DEFEND: 0.5,
		DefenseAction.SURRENDER: 0.0
	}
	return policy

## 消極的（戦闘しない）
static func create_passive_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 0.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.0,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 0.0,
		AttackAction.NEVER_BATTLE: 1.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM_DEFEND: 0.0,
		DefenseAction.WITH_ITEM_DEFEND: 0.0,
		DefenseAction.SURRENDER: 1.0
	}
	return policy

## バランス型（従来ワーストケース + 少し楽観的）
static func create_balanced_policy() -> CPUBattlePolicy:
	var policy = CPUBattlePolicy.new()
	policy.attack_weights = {
		AttackAction.ALWAYS_BATTLE: 0.0,
		AttackAction.BATTLE_IF_BOTH_NO_ITEM: 0.3,
		AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM: 1.0,
		AttackAction.NEVER_BATTLE: 0.0
	}
	policy.defense_weights = {
		DefenseAction.NO_ITEM_DEFEND: 1.0,
		DefenseAction.WITH_ITEM_DEFEND: 1.0,
		DefenseAction.SURRENDER: 0.0
	}
	return policy

# =============================================================================
# デバッグ
# =============================================================================

func print_weights() -> void:
	print("[CPUBattlePolicy] 侵略時の重み:")
	print("  ALWAYS_BATTLE: %.1f" % attack_weights[AttackAction.ALWAYS_BATTLE])
	print("  BATTLE_IF_BOTH_NO_ITEM: %.1f" % attack_weights[AttackAction.BATTLE_IF_BOTH_NO_ITEM])
	print("  BATTLE_IF_WIN_VS_ENEMY_ITEM: %.1f" % attack_weights[AttackAction.BATTLE_IF_WIN_VS_ENEMY_ITEM])
	print("  NEVER_BATTLE: %.1f" % attack_weights[AttackAction.NEVER_BATTLE])
	print("[CPUBattlePolicy] 防衛時の重み:")
	print("  NO_ITEM_DEFEND: %.1f" % defense_weights[DefenseAction.NO_ITEM_DEFEND])
	print("  WITH_ITEM_DEFEND: %.1f" % defense_weights[DefenseAction.WITH_ITEM_DEFEND])
	print("  SURRENDER: %.1f" % defense_weights[DefenseAction.SURRENDER])
