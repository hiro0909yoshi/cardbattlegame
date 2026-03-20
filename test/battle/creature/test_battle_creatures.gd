extends GutTest

## クリーチャースキルテスト
## 各クリーチャー固有スキルの発動と効果を検証

var _executor: BattleTestExecutor


func before_all():
	_executor = BattleTestExecutor.new()
	_executor.scene_tree_parent = self


## 汎用config作成
## defender_land: 防御側の土地属性（ランドボーナス判定用）
func _create_config(attacker_id: int, defender_id: int, defender_land: String = "neutral") -> BattleTestConfig:
	var config = BattleTestConfig.new()
	config.attacker_creatures = [attacker_id]
	config.defender_creatures = [defender_id]
	# battle_tile_indexをdefender_landに合わせ、防御側クリーチャーを配置
	var tile_idx: int
	match defender_land:
		"fire": tile_idx = 4
		"water": tile_idx = 6
		"wind": tile_idx = 11
		"earth": tile_idx = 16
		_: tile_idx = 5  # neutral
	config.battle_tile_index = tile_idx
	config.board_layout = [
		{"tile_index": tile_idx, "owner_id": 1, "creature_id": defender_id},
	]
	config.attacker_battle_land = defender_land
	config.defender_battle_land = defender_land
	config.attacker_battle_land_level = 1
	config.defender_battle_land_level = 1
	return config


## バトル実行ヘルパー
func _execute_battle(config: BattleTestConfig) -> BattleTestResult:
	var results = await _executor.execute_all_battles(config)
	return results[0]


# ========================================
# 先制攻撃スキル
# ========================================

## 防御側先制: 一撃撃破で反撃なし
## ケルベロス(火,AP50/HP50,先制) vs タイダルオーガ(水,AP40/HP50)
## 火タイルLv1→防御側ランドボーナスHP+10（別管理）
## 先制でAP50→攻HP50-50=0 撃破、反撃なし
func test_first_strike_defender_kills():
	var config = _create_config(138, 27, "fire")
	var r = await _execute_battle(config)
	assert_true(r.first_strike_occurred, "先制発動")
	assert_eq(r.attacker_final_hp, 0, "先制AP50で攻HP50→0")
	assert_eq(r.defender_final_hp, 50, "反撃なし: HP50維持")
	assert_eq(r.winner, "defender", "防御側勝利")


## 防御側先制: 倒しきれず両者生存→防御勝利
## マルコシアス(火,AP30/HP40,先制) vs タイダルオーガ(水,AP40/HP50)
## 火タイルLv1→防御HP40+10=50
## 先制AP30→攻HP50-30=20、反撃AP40→防HP50-40=10
func test_first_strike_defender_both_survive():
	var config = _create_config(138, 15, "fire")
	var r = await _execute_battle(config)
	assert_true(r.first_strike_occurred, "先制発動")
	assert_eq(r.attacker_final_hp, 20, "先制AP30で攻HP50→20")
	assert_eq(r.defender_final_hp, 10, "反撃AP40で防HP50→10")
	assert_eq(r.winner, "attacker_survived", "両者生存→攻撃側生存")


## 両者先制: 侵略側優先→一撃撃破
## ケルベロス(火,AP50/HP50,先制) vs コアトル(風,AP40/HP30,先制)
## 風タイルLv1→防御側ランドボーナスHP+10=40
## 両者先制→侵略側優先: AP50→防HP40-50=-10 撃破
func test_first_strike_both_attacker_priority():
	var config = _create_config(27, 316, "wind")
	var r = await _execute_battle(config)
	assert_true(r.first_strike_occurred, "先制発動")
	assert_eq(r.attacker_final_hp, 50, "反撃なし: HP50維持")
	assert_true(r.defender_final_hp <= 0, "侵略側優先で防御撃破")
	assert_eq(r.winner, "attacker", "侵略側勝利")


## 先制なし同士: 通常攻撃順（ベースライン）
## レッドオーガ(火,AP40/HP50) vs タイダルオーガ(水,AP40/HP50)
## 火タイルLv1→防御側ランドボーナスなし(水on火) HP50
## 通常順: 攻AP40→防HP50-40=10、反撃AP40→攻HP50-40=10
func test_no_first_strike_baseline():
	var config = _create_config(48, 138, "fire")
	var r = await _execute_battle(config)
	assert_false(r.first_strike_occurred, "先制なし")
	assert_eq(r.attacker_final_hp, 10, "反撃AP40で攻HP50→10")
	assert_eq(r.defender_final_hp, 10, "攻AP40で防HP50→10")
	assert_eq(r.winner, "attacker_survived", "両者生存→攻撃側生存")


# ========================================
# 後手スキル
# ========================================

## 攻撃側後手: 防御側が先に攻撃
## ヘヴィクラウン(水,AP50/HP60,後手) vs レッドオーガ(火,AP40/HP50)
## 火タイルLv1→攻撃側は水on火でランドボーナスなし
## 防御側先攻: AP40→攻HP60-40=20、反撃AP50→land10消費+HP50-40=10
func test_last_strike_attacker_is_slower():
	var config = _create_config(119, 48, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 20, "防御AP40で攻HP60→20")
	assert_eq(r.defender_final_hp, 10, "攻AP50→land10消費+HP50-40=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 防御側後手: 攻撃側が先に攻撃（通常と同じ順序）
## レッドオーガ(火,AP40/HP50) vs ヘヴィクラウン(水,AP50/HP60,後手)
## 水タイルLv1→防御側ランドボーナスあり（水on水）
## 攻撃側先攻: AP40→land10消費+HP60-30=30、防御側反撃: AP50→攻HP50-50=0
func test_last_strike_defender_is_slower():
	var config = _create_config(48, 119, "water")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "防御AP50で攻HP50→0")
	assert_eq(r.defender_final_hp, 30, "攻AP40→land10消費+HP60-30=30")
	assert_eq(r.winner, "defender", "防御側勝利")


## 両者後手: 侵略側優先
## ヘヴィクラウン(水,AP50/HP60) vs ヘヴィクラウン(水,AP50/HP60)
## 水タイルLv1→防御側ランドボーナスあり
## 両者後手→侵略側優先: AP50→land10消費+HP60-40=20、反撃AP50→攻HP60-50=10
func test_last_strike_both_attacker_priority():
	var config = _create_config(119, 119, "water")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 10, "防御AP50で攻HP60→10")
	assert_eq(r.defender_final_hp, 20, "攻AP50→land10消費+HP60-40=20")
	assert_eq(r.winner, "attacker_survived", "両者生存→攻撃側生存")


## 後手クリーチャー + 先制アイテム: アイテム先制が最優先で後手を上書き
## ヘヴィクラウン(水,AP50/HP60,後手) + クイックチャーム(AP+10,先制)
## → AP60, 後手+アイテム先制 → アイテム先制最優先で攻撃側先攻
## 防御側: レッドオーガ(火,AP40/HP50) 火タイル → land10
## 攻撃側先攻: AP60→land10消費+HP50-50=0 撃破
func test_last_strike_overridden_by_item_first_strike():
	var config = _create_config(119, 48, "fire")
	config.attacker_items = [1000]  # クイックチャーム
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "AP50+10=60")
	assert_eq(r.attacker_final_hp, 60, "反撃なし: HP60維持")
	assert_eq(r.defender_final_hp, 0, "AP60→land10消費+HP50-50=0")
	assert_eq(r.winner, "attacker", "アイテム先制で攻撃側勝利")


## 先制クリーチャー + アダマンタイト(後手): 後手が先制を上書き
## ケルベロス(火,AP50/HP50,先制) + アダマンタイト(AP-30,HP+60,後手)
## → AP20, アイテムHP+60(別管理), 先制+後手 → 後手優先で防御側が先に攻撃
## 防御側: タイダルオーガ(水,AP40/HP50)
## 防御側先攻: AP40→アイテムHP60から消費→攻HP50維持、反撃AP20→防HP50-20=30
func test_first_strike_overridden_by_last_strike():
	var config = _create_config(27, 138, "fire")
	config.attacker_items = [1032]  # アダマンタイト
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 20, "AP50-30=20")
	assert_eq(r.attacker_final_hp, 50, "アイテムHP60がダメージ吸収→素HP50維持")
	assert_eq(r.defender_final_hp, 30, "攻AP20で防HP50→30")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_true("後手" in r.attacker_granted_skills, "後手スキル付与")
