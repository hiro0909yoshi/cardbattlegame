extends GutTest

## SpellCurseStat / EffectManager ステータス増減テスト
## permanent_hp_change, permanent_ap_change, conditional_ap_change のコアロジック検証
## ボードシステム非依存のcreature_data直接操作テスト


# ========================================
# EffectManager.apply_max_hp_effect テスト
# ========================================

## 基本MHP増加
func test_permanent_hp_increase():
	var creature = _create_creature(20, 20)
	EffectManager.apply_max_hp_effect(creature, 10)
	var new_mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
	assert_eq(new_mhp, 30, "MHP: 20+10=30")
	assert_eq(creature["current_hp"], 30, "current_hp も30に増加")


## MHP減少（HP残る）
func test_permanent_hp_decrease():
	var creature = _create_creature(40, 20)
	EffectManager.apply_max_hp_effect(creature, -10)
	var new_mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
	assert_eq(new_mhp, 30, "MHP: 40-10=30")
	assert_eq(creature["current_hp"], 30, "current_hp も30に減少")


## MHP減少でHP0以下
func test_permanent_hp_decrease_to_zero():
	var creature = _create_creature(20, 20)
	EffectManager.apply_max_hp_effect(creature, -30)
	var new_mhp = creature.get("hp", 0) + creature.get("base_up_hp", 0)
	assert_eq(new_mhp, -10, "MHP: 20-30=-10")
	assert_eq(creature["current_hp"], 0, "current_hp は0で下限クランプ")


## ダメージ受けた後にMHP増加
func test_permanent_hp_increase_after_damage():
	var creature = _create_creature(40, 20)
	creature["current_hp"] = 10  # ダメージ済み
	EffectManager.apply_max_hp_effect(creature, 20)
	# MHP: 40+20=60, current_hp: 10+20=30
	assert_eq(creature["current_hp"], 30, "current_hp: 10+20=30（MHP差分だけ加算）")


## ダメージ受けた後にMHP減少（current_hpがMHP超過しないようクランプ）
func test_permanent_hp_decrease_after_damage():
	var creature = _create_creature(40, 20)
	creature["current_hp"] = 30  # ダメージ済み
	EffectManager.apply_max_hp_effect(creature, -20)
	# MHP: 40-20=20, current_hp: 30-20=10（MHP20以内なのでOK）
	assert_eq(creature["current_hp"], 10, "current_hp: 30-20=10")


## MHP増加でcurrent_hpがMHP超過しない
func test_permanent_hp_no_overheal():
	var creature = _create_creature(40, 20)
	creature["current_hp"] = 40  # 満タン
	EffectManager.apply_max_hp_effect(creature, 10)
	# MHP: 40+10=50, current_hp: 40+10=50
	assert_eq(creature["current_hp"], 50, "満タンならMHPまで回復")


## base_up_hp既存の場合
func test_permanent_hp_with_existing_base_up():
	var creature = _create_creature(20, 20)
	creature["base_up_hp"] = 10  # 既にbase_up_hp=10（MHP=30）
	creature["current_hp"] = 30
	EffectManager.apply_max_hp_effect(creature, 10)
	# base_up_hp: 10+10=20, MHP: 20+20=40, current_hp: 30+10=40
	assert_eq(creature["base_up_hp"], 20, "base_up_hp: 10+10=20")
	assert_eq(creature["current_hp"], 40, "current_hp: 30+10=40")


# ========================================
# permanent_ap_change テスト (base_up_ap直接操作)
# ========================================

## 基本AP増加
func test_permanent_ap_increase():
	var creature = _create_creature(20, 20)
	_apply_ap_change(creature, 10)
	var total_ap = creature.get("ap", 0) + creature.get("base_up_ap", 0)
	assert_eq(total_ap, 30, "AP: 20+10=30")


## AP減少
func test_permanent_ap_decrease():
	var creature = _create_creature(20, 40)
	_apply_ap_change(creature, -10)
	var total_ap = creature.get("ap", 0) + creature.get("base_up_ap", 0)
	assert_eq(total_ap, 30, "AP: 40-10=30")


## AP減少で0以下にならない（クランプ）
func test_permanent_ap_decrease_clamp():
	var creature = _create_creature(20, 20)
	_apply_ap_change(creature, -30)
	var total_ap = creature.get("ap", 0) + creature.get("base_up_ap", 0)
	assert_eq(total_ap, 0, "AP: 0下限クランプ")


## base_up_ap既存の場合
func test_permanent_ap_with_existing_base_up():
	var creature = _create_creature(20, 20)
	creature["base_up_ap"] = 10
	_apply_ap_change(creature, 15)
	assert_eq(creature["base_up_ap"], 25, "base_up_ap: 10+15=25")
	var total_ap = creature.get("ap", 0) + creature.get("base_up_ap", 0)
	assert_eq(total_ap, 45, "AP: 20+25=45")


# ========================================
# conditional_ap_change テスト (条件付きAP変更ロジック)
# ========================================

## AP30以下 → AP+20
func test_conditional_ap_low_boost():
	var creature = _create_creature(20, 20)  # AP=20（30以下）
	var conditions: Array[Dictionary] = [
		{"check": "ap_lte", "threshold": 30, "value": 20},
		{"check": "ap_gte", "threshold": 50, "value": -20}
	]
	var applied = _apply_conditional_ap(creature, conditions)
	assert_true(applied, "条件一致: AP20<=30")
	var total_ap = creature.get("ap", 0) + creature.get("base_up_ap", 0)
	assert_eq(total_ap, 40, "AP: 20+20=40")


## AP50以上 → AP-20
func test_conditional_ap_high_reduce():
	var creature = _create_creature(20, 60)  # AP=60（50以上）
	var conditions: Array[Dictionary] = [
		{"check": "ap_lte", "threshold": 30, "value": 20},
		{"check": "ap_gte", "threshold": 50, "value": -20}
	]
	var applied = _apply_conditional_ap(creature, conditions)
	assert_true(applied, "条件一致: AP60>=50")
	var total_ap = creature.get("ap", 0) + creature.get("base_up_ap", 0)
	assert_eq(total_ap, 40, "AP: 60-20=40")


## AP31〜49 → 条件不一致（変化なし）
func test_conditional_ap_no_match():
	var creature = _create_creature(20, 40)  # AP=40（31〜49、どちらにも不一致）
	var conditions: Array[Dictionary] = [
		{"check": "ap_lte", "threshold": 30, "value": 20},
		{"check": "ap_gte", "threshold": 50, "value": -20}
	]
	var applied = _apply_conditional_ap(creature, conditions)
	assert_false(applied, "条件不一致: AP40は31〜49")
	var total_ap = creature.get("ap", 0) + creature.get("base_up_ap", 0)
	assert_eq(total_ap, 40, "AP変化なし")


# ========================================
# ヘルパー
# ========================================

func _create_creature(hp: int, ap: int) -> Dictionary:
	return {
		"name": "テストクリーチャー",
		"hp": hp,
		"ap": ap,
		"base_up_hp": 0,
		"base_up_ap": 0,
		"current_hp": hp,
	}


## permanent_ap_change のコアロジック再現（SpellCurseStat._apply_permanent_ap_change相当）
func _apply_ap_change(creature: Dictionary, value: int) -> void:
	if not creature.has("base_up_ap"):
		creature["base_up_ap"] = 0
	var base_ap = int(creature.get("ap", 0))
	var old_base_up_ap = int(creature.get("base_up_ap", 0))
	var new_base_up_ap = old_base_up_ap + int(value)
	var new_total_ap = base_ap + new_base_up_ap
	if new_total_ap < 0:
		new_base_up_ap = -base_ap
	creature["base_up_ap"] = new_base_up_ap


## conditional_ap_change のコアロジック再現（SpellCurseStat._apply_conditional_ap_change相当）
## @return 条件に一致してAPが変更されたか
func _apply_conditional_ap(creature: Dictionary, conditions: Array[Dictionary]) -> bool:
	var base_ap = creature.get("ap", 0)
	var base_up_ap = creature.get("base_up_ap", 0)
	var current_ap = base_ap + base_up_ap

	for cond in conditions:
		var check = cond.get("check", "")
		var threshold = cond.get("threshold", 0)
		var value = cond.get("value", 0)
		var matched = false
		match check:
			"ap_lte":
				matched = current_ap <= threshold
			"ap_gte":
				matched = current_ap >= threshold
		if matched:
			if not creature.has("base_up_ap"):
				creature["base_up_ap"] = 0
			var new_base_up_ap = base_up_ap + value
			var new_total_ap = base_ap + new_base_up_ap
			if new_total_ap < 0:
				new_base_up_ap = -base_ap
			creature["base_up_ap"] = new_base_up_ap
			return true
	return false
