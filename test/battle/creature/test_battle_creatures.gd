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


# ========================================
# 2回攻撃スキル
# ========================================

## 攻撃側2回攻撃: 2回攻撃で防御側HPを削る
## マンティコア(風,AP20/HP30,2回攻撃) vs レッドオーガ(火,AP40/HP50)
## 火タイルLv1→防御側ランドボーナスHP+10
## 攻撃側先攻: 1回目AP20→land10消費+HP50から10消費=40、2回目AP20→HP40-20=20
## 反撃AP40→攻HP30-40=-10 撃破
func test_double_attack_attacker():
	var config = _create_config(326, 48, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, -10, "反撃AP40で攻HP30→-10撃破")
	assert_eq(r.defender_final_hp, 20, "2回攻撃AP20×2→land10+HP50から計40消費→HP20")
	assert_eq(r.winner, "defender", "防御側勝利")


## 防御側2回攻撃: 防具で耐えて2回反撃
## レッドオーガ(火,AP40/HP50) vs マンティコア(風,AP20/HP30,2回攻撃)
## 風タイルLv1→防御側ランドボーナスHP+10（風on風一致）
## 防御側にフルプレート(1058,HP+50)→itemHP50
## 攻撃側先攻: AP40→land10消費+itemHP50から30消費→itemHP20残、HP30維持
## 反撃2回: 1回目AP20→攻HP50-20=30、2回目AP20→攻HP30-20=10
func test_double_attack_defender():
	var config = _create_config(48, 326, "wind")
	config.defender_items = [1058]  # フルプレート(HP+50)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 10, "反撃AP20×2で攻HP50→10")
	assert_eq(r.defender_final_hp, 30, "攻AP40→land10+itemHP50消費→HP30維持")
	assert_eq(r.winner, "attacker_survived", "両者生存→攻撃側生存")


## 攻撃側2回攻撃 + タイダルスピア: 1回目で撃破時に2回目を実行しないか
## マンティコア(風,AP20/HP30,2回攻撃) + タイダルスピア(1022,AP+20,水風強化)
## → AP20+20=40 × 1.5(風=強化発動) = 60
## 火タイルLv1→防御側ランドボーナスHP+10
## 1回目AP60→land10消費+HP50-50=0 撃破、2回目なし、反撃なし
func test_double_attack_overkill_no_second_hit():
	var config = _create_config(326, 48, "fire")
	config.attacker_items = [1022]  # タイダルスピア
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "AP20+20=40×1.5=60")
	assert_eq(r.attacker_final_hp, 30, "反撃なし: HP30維持")
	assert_eq(r.defender_final_hp, 0, "1回目AP60で撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ========================================
# 共鳴スキル
# ========================================

## 攻撃側共鳴発動: 火土地を所有→AP+20,HP+20
## オルトロス(地,AP50/HP40,共鳴[火→AP+20,HP+20]) vs レッドオーガ(火,AP40/HP50)
## 火タイルLv1→防御側ランドボーナスHP+10
## 攻撃側が火タイル1つ所有→共鳴発動→AP70,HP40(+共鳴HP20)
## 攻AP70→land10消費+HP50-60=-10 撃破、反撃なし
func test_resonance_attacker_fire_land():
	var config = _create_config(213, 48, "fire")
	# 攻撃側に火タイルを1つ所有させる（共鳴条件）
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 213})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 70, "共鳴でAP50+20=70")
	assert_eq(r.attacker_final_hp, 40, "反撃なし: HP40維持")
	assert_true(r.defender_final_hp <= 0, "AP70で撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 攻撃側共鳴不発: 風土地を所有していない
## ミズチ(水,AP50/HP50,共鳴[風→AP+20,HP+10]) vs レッドオーガ(火,AP40/HP50)
## 火タイルLv1→防御側ランドボーナスHP+10
## 攻撃側は風タイルなし→共鳴不発→AP50,HP50
## 攻AP50→land10消費+HP50-40=10、反撃AP40→攻HP50-40=10
func test_resonance_not_triggered_no_wind_land():
	var config = _create_config(115, 48, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 50, "共鳴不発: AP50のまま")
	assert_eq(r.attacker_final_hp, 10, "反撃AP40で攻HP50→10")
	assert_eq(r.defender_final_hp, 10, "攻AP50→land10+HP50-40=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 防御側共鳴発動: 火土地を所有→AP+20,HP+20
## レッドオーガ(火,AP40/HP50) vs オルトロス(地,AP50/HP40,共鳴[火→AP+20,HP+20])
## 火タイルLv1→防御側ランドボーナスなし（地on火=属性不一致）
## 防御側が火タイル1つ所有→共鳴発動→AP70,HP40(+共鳴HP20)
## 攻AP40→共鳴HP20消費+HP40から20消費=20、反撃AP70→攻HP50-70=-20 撃破
func test_resonance_defender_fire_land():
	var config = _create_config(48, 213, "fire")
	# 防御側に火タイルを1つ所有させる（共鳴条件）
	config.board_layout.append({"tile_index": 2, "owner_id": 1, "creature_id": 213})
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 70, "共鳴でAP50+20=70")
	assert_eq(r.defender_final_hp, 20, "攻AP40→共鳴HP20+HP40から消費→HP20")
	assert_eq(r.attacker_final_hp, -20, "反撃AP70で攻HP50→-20撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


## 防御側共鳴不発: 風土地を所有していない
## レッドオーガ(火,AP40/HP50) vs ミズチ(水,AP50/HP50,共鳴[風→AP+20,HP+10])
## 水タイルLv1→防御側ランドボーナスHP+10（水on水一致）
## 防御側は風タイルなし→共鳴不発→AP50,HP50
## 攻AP40→land10消費+HP50-30=20、反撃AP50→攻HP50-50=0
func test_resonance_defender_not_triggered():
	var config = _create_config(48, 115, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 50, "共鳴不発: AP50のまま")
	assert_eq(r.defender_final_hp, 20, "攻AP40→land10+HP50-30=20")
	assert_eq(r.attacker_final_hp, 0, "反撃AP50で攻HP50→0")
	assert_eq(r.winner, "defender", "防御側勝利")


## 共鳴2重適用なし: 火タイル2つ所有でもボーナスは1回分
## オルトロス(地,AP50/HP40,共鳴[火→AP+20,HP+20]) vs レッドオーガ(火,AP40/HP50)
## 火タイルLv1→防御側ランドボーナスHP+10
## 攻撃側が火タイル2つ所有→共鳴は1回だけ→AP70（AP90にならない）
func test_resonance_no_double_apply():
	var config = _create_config(213, 48, "fire")
	# 攻撃側に火タイルを2つ所有させる
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 213})
	config.board_layout.append({"tile_index": 3, "owner_id": 0, "creature_id": 213})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 70, "火タイル2つでも共鳴は1回: AP50+20=70（90ではない）")
	assert_eq(r.attacker_final_hp, 40, "反撃なし: HP40維持")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 共鳴 + 強化アイテム: 基礎AP上昇後に×1.5が掛かる
## イフリート(火,AP30/HP30,共鳴[地→AP+20,HP+20]) + ジャイアントキラー(1060,AP+30,強化[MHP≥40])
## vs レッドオーガ(火,AP40/HP50) 火タイルLv1→land10
## 攻撃側が地タイル所有→共鳴発動
## 処理順: itemAP+30=60 → 共鳴AP+20=80 → 強化×1.5=120
func test_resonance_with_power_strike_item():
	var config = _create_config(2, 48, "fire")
	config.attacker_items = [1060]  # ジャイアントキラー(AP+30,強化[MHP≥40])
	# 攻撃側に地タイルを所有させる（共鳴条件）
	config.board_layout.append({"tile_index": 16, "owner_id": 0, "creature_id": 2})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 120, "AP30+30(item)+20(共鳴)=80→×1.5(強化)=120")
	assert_eq(r.attacker_final_hp, 30, "反撃なし: HP30維持")
	assert_true(r.defender_final_hp <= 0, "AP120で撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 共鳴 + 巻物アイテム: 巻物APは固定で共鳴AP+20の影響を受けない
## イフリート(火,AP30/HP30,共鳴[地→AP+20,HP+20]) + ライトニングオーブ(1024,術攻撃[AP40])
## vs レッドオーガ(火,AP40/HP50) 火タイルLv1
## 攻撃側が地タイル所有→共鳴発動（HP+20は有効、APは巻物の固定40にリセット）
## 術攻撃AP40→ランドボーナス貫通→HP50-40=10
## 反撃AP40→共鳴HP20消費+HP30から20消費→HP10
func test_resonance_with_scroll_item():
	var config = _create_config(2, 48, "fire")
	config.attacker_items = [1024]  # ライトニングオーブ(術攻撃[AP40])
	# 攻撃側に地タイルを所有させる（共鳴条件）
	config.board_layout.append({"tile_index": 16, "owner_id": 0, "creature_id": 2})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "巻物AP40: 共鳴AP+20は巻物に影響しない")
	assert_eq(r.attacker_final_hp, 10, "反撃AP40→共鳴HP20消費+HP30-20=10")
	assert_eq(r.defender_final_hp, 10, "術攻撃AP40→land貫通→HP50-40=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# ========================================
# 即死スキル
# ========================================

## 攻撃側即死発動: 100%即死で相手を撃破
## パラディン(無,AP30/HP30,即死[無・100%]) vs ゴブリン(無,AP20/HP30)
## 中立タイルLv1→防御側ランドボーナスなし（無on中立=不一致）
## 攻AP30→防HP30-30=0 で通常撃破してしまうので、ランドボーナスで耐えさせる
## 無タイル(中立)ではランドボーナスつかないので、防御側HPを高くするためフルプレート使用
## → 防御側にフルプレート(1058,HP+50)→itemHP50で耐える
## 攻AP30→itemHP50から30消費→防HP30維持（生存）→即死100%発動→HP=0
func test_instant_death_attacker_kills():
	var config = _create_config(424, 414, "neutral")
	config.defender_items = [1058]  # フルプレート(HP+50)で耐えさせる
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "即死100%で撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 防御側即死発動: 反撃時に100%即死
## ゴブリン(無,AP20/HP30) vs パラディン(無,AP30/HP30,即死[無・100%])
## 中立タイルLv1→ランドボーナスなし
## 攻AP20→防HP30-20=10（生存）、反撃AP30→攻HP30-30=0（通常撃破）
## → 攻撃側をフルプレート(1058,HP+50)で耐えさせて即死を確認
func test_instant_death_defender_kills():
	var config = _create_config(414, 424, "neutral")
	config.attacker_items = [1058]  # フルプレート(HP+50)で耐えさせる
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "即死100%で撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


## 即死条件不成立: 相手が無属性でなければ即死しない
## パラディン(無,AP30/HP30,即死[無・100%]) vs レッドオーガ(火,AP40/HP50)
## 火タイルLv1→防御側ランドボーナスHP+10
## 相手が火属性→即死条件不成立→通常攻撃のみ
## 攻AP30→land10消費+HP50-20=30、反撃AP40→攻HP30-40=-10 撃破
func test_instant_death_wrong_element():
	var config = _create_config(424, 48, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 30, "即死不発: 通常攻撃のみ→HP30")
	assert_eq(r.attacker_final_hp, -10, "反撃AP40で撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


## 無効化で即死スキップ: 攻撃が無効化されると即死判定も行われない
## ゴブリン(無,AP20/HP30) vs パラディン(無,AP30/HP30,無効化[無])
## 中立タイルLv1→ランドボーナスなし
## ゴブリンは無属性→パラディンの無効化[無]で攻撃完全無効→即死判定なし
## パラディン反撃AP30→ゴブリンHP30-30=0（通常撃破）
## → ゴブリンにフルプレートで耐えさせても、無効化で攻撃自体が通らない
func test_instant_death_blocked_by_nullify():
	var config = _create_config(414, 424, "neutral")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "反撃AP30で攻HP30→0")
	assert_eq(r.defender_final_hp, 30, "無効化で攻撃無効→HP30維持")
	assert_eq(r.winner, "defender", "防御側勝利")


# ========================================
# 無効化スキル
# ========================================

## AP閾値無効化: AP40以上の攻撃を完全無効化
## レッドオーガ(火,AP40/HP50) vs カーバンクル(火,AP20/HP30,無効化[AP40以上])
## 火タイルLv1→防御側ランドボーナスHP+10（火on火一致）
## 攻AP40→AP40以上で完全無効→ダメージなし
## 反撃AP20→攻HP50-20=30
func test_nullify_ap_threshold_blocked():
	var config = _create_config(48, 11, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 30, "反撃AP20で攻HP50→30")
	assert_eq(r.defender_final_hp, 30, "AP40以上で完全無効→HP30維持")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 1/2軽減: 全攻撃ダメージ半減
## レッドオーガ(火,AP40/HP50) vs ジャックオランタン(火,AP30/HP30,無効化[1/2])
## 火タイルLv1→防御側ランドボーナスHP+10（火on火一致）
## 攻AP40→1/2軽減→20ダメージ→land10消費+HP30-10=20
## 反撃AP30→攻HP50-30=20
func test_nullify_half_reduction():
	var config = _create_config(48, 6, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 20, "反撃AP30で攻HP50→20")
	assert_eq(r.defender_final_hp, 20, "AP40→1/2=20→land10+HP30-10=20")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## AP閾値無効化 条件不成立: AP40未満→無効化されない
## ゴブリン(無,AP20/HP30) vs カーバンクル(火,AP20/HP30,無効化[AP40以上])
## 火タイルLv1→防御側ランドボーナスHP+10（火on火一致）
## 攻AP20→AP40未満→無効化不発→通常ダメージ
## AP20→land10消費+HP30-10=20、反撃AP20→攻HP30-20=10
func test_nullify_ap_threshold_not_met():
	var config = _create_config(414, 11, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 10, "反撃AP20で攻HP30→10")
	assert_eq(r.defender_final_hp, 20, "AP20→無効化不発→land10+HP30-10=20")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# =============================================================================
# 再生スキル
# =============================================================================

## 再生発動（防御側）: ダメージ後にHP全回復
func test_regeneration_defender_healed():
	var config = _create_config(414, 420)  # ゴブリン(AP20) vs スケルトン(AP30/HP40/再生)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "反撃AP30で攻HP30→0")
	assert_eq(r.defender_final_hp, 40, "再生でHP40に全回復")
	assert_eq(r.winner, "defender", "防御側勝利")

## 再生不発（撃破時）: 死亡したら再生しない
func test_regeneration_not_triggered_when_killed():
	var config = _create_config(213, 420)  # オルトロス(AP50) vs スケルトン(AP30/HP40+land10/再生)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "AP50でHP50→撃破→再生不発")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## 再生発動（攻撃側）: 反撃でダメージ後にHP全回復
func test_regeneration_attacker_healed():
	var config = _create_config(420, 414)  # スケルトン(AP30/HP40/再生) vs ゴブリン(AP20/HP30)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 40, "反撃AP20でland10+HP10消費→HP30→再生で40に全回復")
	assert_eq(r.defender_final_hp, 10, "AP30でHP40→10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# =============================================================================
# 蘇生スキル
# =============================================================================

## 蘇生発動（強制・防御側）: 撃破後に別クリーチャーとして復活
func test_revive_forced_defender():
	var config = _create_config(48, 139)  # レッドオーガ(AP40) vs コクーンラーヴァ(AP30/HP30/蘇生[コアトル])
	var r = await _execute_battle(config)
	assert_eq(r.defender_name, "コアトル", "蘇生でコアトルに変化")
	assert_eq(r.defender_final_hp, 30, "蘇生後MHP30で復活")
	assert_eq(r.winner, "attacker_survived", "蘇生で復活→両者生存扱い")

## 蘇生不発（条件不成立）: 敵武器使用時は蘇生しない
func test_revive_conditional_failed():
	var config = _create_config(48, 439)  # レッドオーガ(AP40)+ツヴァイハンダー vs レリックアムル(AP20/HP10/蘇生[条件付])
	config.attacker_items = [1009]  # ツヴァイハンダー(武器, AP+30)
	var r = await _execute_battle(config)
	assert_eq(r.defender_name, "レリックアムル", "蘇生不発→名前変化なし")
	assert_lt(r.defender_final_hp, 1, "撃破されたまま（HP0以下）")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## 蘇生発動（条件付き・成功）: 敵武器不使用時に蘇生
func test_revive_conditional_success():
	var config = _create_config(48, 439)  # レッドオーガ(AP40) vs レリックアムル(AP20/HP10/蘇生[条件付])
	var r = await _execute_battle(config)
	assert_eq(r.defender_name, "レリックアムル", "自身に蘇生→名前同じ")
	assert_eq(r.defender_final_hp, 10, "蘇生後MHP10で復活")
	assert_eq(r.winner, "attacker_survived", "蘇生で復活→両者生存扱い")

## 蘇生（アイテム使用時）: レリックアムルをアイテムとして使用→蘇生が継承される
func test_revive_as_item_inherited():
	var config = _create_config(213, 414)  # オルトロス(AP50) vs ゴブリン(AP20/HP30)+レリックアムル
	config.defender_items = [439]  # レリックアムル(AP+20/HP+10/蘇生[条件付])
	var r = await _execute_battle(config)
	assert_eq(r.defender_name, "レリックアムル", "蘇生継承→レリックアムルとして復活")
	assert_eq(r.defender_final_hp, 10, "蘇生後MHP10で復活")
	assert_eq(r.winner, "attacker_survived", "蘇生で復活→両者生存扱い")

## 蘇生不発（アイテム使用時・敵武器あり）: 蘇生継承されるが条件不成立
func test_revive_as_item_enemy_weapon():
	var config = _create_config(213, 414)  # オルトロス(AP50)+ツヴァイハンダー vs ゴブリン(AP20/HP30)+レリックアムル
	config.attacker_items = [1009]  # ツヴァイハンダー(武器, AP+30)
	config.defender_items = [439]  # レリックアムル
	var r = await _execute_battle(config)
	assert_eq(r.defender_name, "ゴブリン", "敵武器使用→蘇生不発→名前変化なし")
	assert_lt(r.defender_final_hp, 1, "撃破されたまま（HP0以下）")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## 蘇生発動（攻撃側・アイテム使用・敵武器なし）: 反撃で撃破→蘇生成功
func test_revive_as_item_attacker_success():
	var config = _create_config(414, 48)  # ゴブリン(AP20/HP30)+レリックアムル vs レッドオーガ(AP40/HP50)
	config.attacker_items = [439]  # レリックアムル(AP+20/HP+10)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_name, "レリックアムル", "反撃で撃破→蘇生継承→レリックアムルに復活")
	assert_eq(r.attacker_final_hp, 10, "蘇生後MHP10で復活")
	assert_eq(r.winner, "attacker_survived", "蘇生で復活→両者生存扱い")

## 蘇生不発（攻撃側・アイテム使用・敵武器あり）: 反撃で撃破→蘇生条件不成立
func test_revive_as_item_attacker_enemy_weapon():
	var config = _create_config(414, 48)  # ゴブリン(AP20/HP30)+レリックアムル vs レッドオーガ(AP40/HP50)+ツヴァイハンダー
	config.attacker_items = [439]  # レリックアムル
	config.defender_items = [1009]  # ツヴァイハンダー(武器, AP+30)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_name, "ゴブリン", "敵武器使用→蘇生不発→名前変化なし")
	assert_lt(r.attacker_final_hp, 1, "撃破されたまま（HP0以下）")
	assert_eq(r.winner, "defender", "防御側勝利")


# =============================================================================
# 相討スキル（HP閾値型 + アイテム型）
# =============================================================================

## HP閾値型相討（ボム）: HP20以下で自爆+相討→両者死亡
func test_death_revenge_hp_threshold_triggered():
	var config = _create_config(414, 442)  # ゴブリン(AP20) vs ボム(AP10/HP30/相討[HP20以下])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "相討で攻撃側も死亡")
	assert_eq(r.defender_final_hp, 0, "相討で防御側も死亡")
	assert_eq(r.winner, "both_defeated", "両者死亡")

## HP閾値型相討（ボム）不発: 一撃撃破でHP閾値に入らない
func test_death_revenge_hp_threshold_not_triggered():
	var config = _create_config(48, 442)  # レッドオーガ(AP40) vs ボム(AP10/HP30+land10)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "一撃撃破→相討不発")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## HP閾値型相討（ボム攻撃側）: 反撃でHP20以下→自爆+相討
func test_death_revenge_hp_threshold_attacker():
	var config = _create_config(442, 414)  # ボム(AP10/HP30/相討[HP20以下]) vs ゴブリン(AP20/HP30)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "相討で攻撃側も死亡")
	assert_eq(r.defender_final_hp, 0, "相討で防御側も死亡")
	assert_eq(r.winner, "both_defeated", "両者死亡")

## HP閾値型相討 vs 即死: 相討がprocess_damage_aftermathで先に発動→即死チェック不要
func test_death_revenge_vs_instant_death():
	var config = _create_config(424, 442)  # パラディン(AP30/即死[無]) vs ボム(AP10/HP30/相討[HP20以下])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "相討で攻撃側も死亡")
	assert_eq(r.defender_final_hp, 0, "ダメージ後HP10→相討発動で死亡")
	assert_eq(r.winner, "both_defeated", "相討が即死より先→両者死亡")


# =============================================================================
# 反射スキル
# =============================================================================

## 反射100%（ミラー）防御側: 通常攻撃を完全反射、自分はノーダメージ
## ゴブリン(AP20/HP30) vs ミラー(AP0/HP10+land10,反射100%)
## 攻撃AP20→反射: self=0,reflect=20→ゴブリンHP30-20=10 / 反撃AP0→0
func test_reflect_full_defender():
	var config = _create_config(414, 426)  # ゴブリン vs ミラー
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 10, "反射20ダメージでHP30→10")
	assert_eq(r.defender_final_hp, 10, "反射100%で自傷0→current_hp10維持")
	assert_eq(r.winner, "attacker_survived", "両者生存")

## 反射100%で攻撃側撃破: 高APが反射で自滅
## ゴブリン(AP20+ツヴァイハンダーAP30=50/HP30) vs ミラー(AP0/HP10+land10,反射100%)
## 攻撃AP50→反射: self=0,reflect=50→ゴブリンHP30-50=-20→撃破
func test_reflect_full_kills_attacker():
	var config = _create_config(414, 426)  # ゴブリン+ツヴァイハンダー vs ミラー
	config.attacker_items = [1009]  # ツヴァイハンダー(武器, AP+30)
	var r = await _execute_battle(config)
	assert_lt(r.attacker_final_hp, 1, "反射50で自滅（HP30-50=-20）")
	assert_eq(r.defender_final_hp, 10, "反射100%で自傷0→current_hp10維持")
	assert_eq(r.winner, "defender", "反射で攻撃側撃破→防御側勝利")

## 反射50%（ワンダリングナイト）防御側: ダメージ半減+半分反射
## ゴブリン(AP20/HP40) vs ワンダリングナイト(火,AP40/HP30+land10=40,反射50%)
## 攻撃AP20→反射50%: self=10,reflect=10→ワンダリングHP30,ゴブリンHP30
## 反撃AP40→ゴブリンHP30-40=-10→撃破
func test_reflect_half_defender():
	var config = _create_config(414, 25, "fire")  # ゴブリン vs ワンダリングナイト(火)
	var r = await _execute_battle(config)
	assert_lt(r.attacker_final_hp, 1, "反射10+反撃40で撃破")
	assert_eq(r.defender_final_hp, 30, "反射50%で自傷10→HP40-10=30")
	assert_eq(r.winner, "defender", "防御側勝利")

## 反射100%（ミラー）攻撃側: 反撃を反射して反射ダメージ返却
## ミラー(AP0/HP10,攻撃側) vs ゴブリン(AP20/HP30+land10,防御側)
## 攻撃AP0→0 / 反撃AP20→反射100%: self=0,reflect=20→ゴブリンland10消費+current10消費=HP20
func test_reflect_full_attacker():
	var config = _create_config(426, 414)  # ミラー vs ゴブリン
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 10, "反射100%で自傷0→current_hp10維持")
	assert_eq(r.defender_final_hp, 20, "反射20:land10消費+current10消費→HP20")
	assert_eq(r.winner, "attacker_survived", "両者生存")

## 反射50%攻撃側: 反撃を反射→反射ダメージで防御側撃破
## ワンダリングナイト(火,AP40/HP30,攻撃側) vs レッドオーガ(AP40/HP50+land10,防御側)
## 攻撃AP40→レッドオーガ:land10消費+current30消費→current_hp20
## 反撃AP40→反射50%: self=20→current_hp10, reflect=20→レッドオーガcurrent_hp0→撃破
func test_reflect_half_attacker_kills():
	var config = _create_config(25, 48, "fire")  # ワンダリングナイト vs レッドオーガ
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 10, "反射50%で自傷20→HP30-20=10")
	assert_eq(r.defender_final_hp, 0, "攻撃40+反射20でcurrent_hp0→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## 術攻撃vs反射100%: 術攻撃(scroll)はミラーの反射対象外→通常ダメージ
## ウィスプ(火,AP30/HP50,術攻撃[AP30]) vs ミラー(AP0/HP10+land10,反射[通常のみ])
## 術攻撃はscroll→反射不発→ミラーHP20-30=-10→撃破
func test_reflect_not_triggered_by_scroll_attack():
	var config = _create_config(34, 426)  # ウィスプ vs ミラー
	var r = await _execute_battle(config)
	assert_lt(r.defender_final_hp, 1, "術攻撃はscroll→反射不発→撃破")
	assert_eq(r.attacker_final_hp, 50, "反射不発→攻撃側ノーダメージ")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## マサムネ(反射無効)vs反射100%: 反射無効で反射スキルを貫通
## ゴブリン(AP20+マサムネAP20=40/HP30) vs ミラー(AP0/HP10+land10,反射100%)
## マサムネnullify_reflect→反射無効→AP40でミラー撃破
func test_reflect_nullified_by_masamune():
	var config = _create_config(414, 426)  # ゴブリン+マサムネ vs ミラー
	config.attacker_items = [1068]  # マサムネ(武器, AP+20, 反射無効)
	var r = await _execute_battle(config)
	assert_lt(r.defender_final_hp, 1, "反射無効→通常ダメージ→撃破")
	assert_eq(r.attacker_final_hp, 30, "反射無効→反射ダメージなし")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# =============================================================================
# 強化スキル
# =============================================================================

## 強化発動（条件成立）: 敵が属性条件に合致→AP×1.5
## バルログ(火,AP40/HP40,強化[火水地風]) vs タイダルオーガ(水,AP40/HP50+land10)
## 水∈[火水地風]→強化発動→AP40×1.5=60→防HP60-60=0→撃破
func test_power_strike_triggered():
	var config = _create_config(9, 138, "water")  # バルログ vs タイダルオーガ
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "強化発動→AP40×1.5=60")
	assert_eq(r.defender_final_hp, 0, "AP60で防HP60→0→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## 強化不発（条件不成立）: 敵が中立→属性条件に含まれない→AP変化なし
## バルログ(火,AP40/HP40,強化[火水地風]) vs ゴブリン(無,AP20/HP30+land10)
## 中立∉[火水地風]→強化不発→AP40
func test_power_strike_not_triggered():
	var config = _create_config(9, 414)  # バルログ vs ゴブリン(中立)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "強化不発→AP40のまま")

## 強化スキル+強化アイテム: 2重適用されず×1.5は1回のみ
## バルログ(AP40+ジャイアントキラーAP30=70,強化[火水地風]) + ジャイアントキラー(強化[MHP40+])
## vs タイダルオーガ(水,HP50+land10=60)
## 強化は1回のみ→AP70×1.5=105（×2.25=157にならない）
func test_power_strike_not_doubled_with_item():
	var config = _create_config(9, 138, "water")  # バルログ+ジャイアントキラー vs タイダルオーガ
	config.attacker_items = [1060]  # ジャイアントキラー(武器, AP+30, 強化[MHP40+])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 105, "強化1回のみ→AP70×1.5=105")
	assert_lt(r.defender_final_hp, 1, "AP105で防HP60→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## 強化持ち+巻物: 巻物APは強化の影響を受けない（step8でリセット）
## スルト(火,AP60,先制・強化[水,風]) + ライトニングオーブ(巻物,術AP40)
## vs タイダルオーガ(水,AP40/HP50) ※術攻撃でland_bonus無効化
## 処理順: 強化→AP90 → 巻物AP固定→AP40（リセット）
func test_power_strike_with_scroll_not_boosted():
	var config = _create_config(19, 138, "water")  # スルト vs タイダルオーガ
	config.attacker_items = [1024]  # ライトニングオーブ(巻物, 術AP40)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "巻物AP40は強化の影響を受けない")

## 強化+鼓舞（トリックスター隣接）: 鼓舞→強化の順で適用
## バルログ(火,AP40,強化[火水地風]) vs タイダルオーガ(水,HP50+land10) バトルタイル6
## タイル5にトリックスター(342,鼓舞[自・AP&HP+隣接ドミニオ数×20]) owner_id=0
## 隣接ドミニオ数=1(タイル5) → 鼓舞AP+20 → AP60 → 強化×1.5 → AP90
func test_power_strike_with_support_trickster():
	var config = _create_config(9, 138, "water")  # バルログ vs タイダルオーガ
	config.board_layout.append({"tile_index": 5, "owner_id": 0, "creature_id": 342})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 90, "鼓舞AP+20→60、強化×1.5→AP90")

## 強化+鼓舞2体（トリックスター+カラミティバイロン）: 隣接ドミニオ2で鼓舞増大
## バルログ(火,AP40,強化[火水地風]) vs タイダルオーガ(水) バトルタイル6
## タイル5:トリックスター(342,owner=0) タイル7:カラミティバイロン(43,owner=0)
## トリックスター:隣接ドミニオ=2→AP+40 / カラミティバイロン:火地AP+10
## AP40+40+10=90 → 強化×1.5 → AP135
func test_power_strike_with_double_support():
	var config = _create_config(9, 138, "water")  # バルログ vs タイダルオーガ
	config.board_layout.append({"tile_index": 5, "owner_id": 0, "creature_id": 342})
	config.board_layout.append({"tile_index": 7, "owner_id": 0, "creature_id": 43})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 135, "鼓舞2体:AP40+40+10=90→強化×1.5→AP135")

## 同ID鼓舞の重複防止: カラミティバイロン2体配置でもAP+10は1回のみ
## タイル5:トリックスター(342) タイル7:カラミティバイロン(43) タイル8:カラミティバイロン(43)
## 同IDの鼓舞は重複防止→カラミティバイロンAP+10は1回のみ→AP135変わらず
func test_power_strike_support_no_duplicate_same_id():
	var config = _create_config(9, 138, "water")  # バルログ vs タイダルオーガ
	config.board_layout.append({"tile_index": 5, "owner_id": 0, "creature_id": 342})
	config.board_layout.append({"tile_index": 7, "owner_id": 0, "creature_id": 43})
	config.board_layout.append({"tile_index": 8, "owner_id": 0, "creature_id": 43})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 135, "同ID鼓舞は重複防止→AP135のまま")

## トリックスター2体(同owner): プレイヤーごとに1回の重複防止
## タイル5:トリックスター(342,owner=0) タイル1:トリックスター(342,owner=0)
## タイル7:カラミティバイロン(43,owner=0) タイル8:カラミティバイロン(43,owner=0)
## トリックスター(ID:342)はプレイヤーごとに1回→2体目は無効→AP135変わらず
func test_power_strike_support_trickster_no_duplicate_per_player():
	var config = _create_config(9, 138, "water")  # バルログ vs タイダルオーガ
	config.board_layout.append({"tile_index": 5, "owner_id": 0, "creature_id": 342})
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 342})
	config.board_layout.append({"tile_index": 7, "owner_id": 0, "creature_id": 43})
	config.board_layout.append({"tile_index": 8, "owner_id": 0, "creature_id": 43})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 135, "トリックスター2体同owner→1回のみ→AP135")

## 強化+鼓舞+巻物: 鼓舞・強化すべて巻物AP固定でリセット
## スルト(火,AP60,先制・強化[水,風]) + ライトニングオーブ(巻物,術AP40) vs タイダルオーガ(水)
## タイル5:トリックスター タイル1:トリックスター タイル7:カラミティバイロン タイル8:カラミティバイロン
## 処理: scroll→AP40 → 鼓舞→AP90 → 強化→AP135 → 巻物AP固定→AP40
func test_power_strike_support_with_scroll_all_reset():
	var config = _create_config(19, 138, "water")  # スルト vs タイダルオーガ
	config.attacker_items = [1024]  # ライトニングオーブ(巻物, 術AP40)
	config.board_layout.append({"tile_index": 5, "owner_id": 0, "creature_id": 342})
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 342})
	config.board_layout.append({"tile_index": 7, "owner_id": 0, "creature_id": 43})
	config.board_layout.append({"tile_index": 8, "owner_id": 0, "creature_id": 43})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "鼓舞+強化すべて巻物AP固定でリセット→AP40")


# ========================================
# 刺突スキル
# ========================================

## 無条件刺突（攻撃側）: 防御側ランドボーナス無効化
## ナイトメア(風,AP30,HP30,刺突) vs タイダルオーガ(水,AP40,HP50) on water
## 刺突→land_bonus=0→Defender HP50
## AP30→50-30=20生存 / AP40→30-40=-10死亡 → defender勝利
func test_penetration_unconditional_attacker():
	var config = _create_config(334, 138, "water")  # ナイトメア vs タイダルオーガ
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 20, "刺突でland_bonus無効→HP50-30=20")
	assert_eq(r.attacker_final_hp, -10, "反撃AP40→HP30-40=-10")
	assert_eq(r.winner, "defender", "攻撃側死亡→防御側勝利")


## 条件付き刺突発動（敵AP≧40）+ 侵略時蓄魔
## レイドワイバーン(火,AP40,HP50,刺突[敵AP≧40],蓄魔[EP100]) vs タイダルオーガ(水,AP40,HP50)
## 敵AP40≧40→刺突発動→land_bonus=0→HP50
## AP40→50-40=10 / AP40→50-40=10 → 両者生存
## 蓄魔: 侵略時EP+100
func test_penetration_conditional_activate_with_magic_gain():
	var config = _create_config(36, 138, "water")  # レイドワイバーン vs タイダルオーガ
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 10, "刺突発動→HP50-40=10")
	assert_eq(r.attacker_final_hp, 10, "反撃AP40→HP50-40=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_has(r.attacker_battle_effects, "蓄魔[100EP]", "侵略時蓄魔EP+100")


## 条件付き刺突不発（敵AP30＜40）+ 蓄魔は独立して発動
## レイドワイバーン(火,AP40,HP50) vs ナイトメア(風,AP30,HP30) on wind
## 敵AP30<40→刺突不発→land_bonus=10→HP40
## AP40→land10吸収+current30-30=0死亡 → attacker勝利
## 蓄魔は刺突と無関係に発動
func test_penetration_conditional_not_activate():
	var config = _create_config(36, 334, "wind")  # レイドワイバーン vs ナイトメア
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "刺突不発→land10+HP30=40-40=0")
	assert_eq(r.attacker_final_hp, 50, "一撃撃破で反撃なし")
	assert_eq(r.winner, "attacker", "防御側撃破")
	assert_has(r.attacker_battle_effects, "蓄魔[100EP]", "蓄魔は刺突と独立して発動")


## 防御側の刺突は無効（ランドボーナス維持）
## レッドオーガ(火,AP40,HP50) attacks ナイトメア(風,AP30,HP30,刺突) on wind
## 防御側刺突→無効→land_bonus=10維持→HP40
## AP40→land10+HP30=40-40=0死亡
## defender_final_hp=0（-10ではない=land_bonus有効の証拠）
func test_penetration_defender_ignored():
	var config = _create_config(48, 334, "wind")  # レッドオーガ vs ナイトメア
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "防御側刺突無効→land10有効→HP40-40=0")
	assert_eq(r.attacker_final_hp, 50, "一撃撃破で反撃なし")
	assert_eq(r.winner, "attacker", "防御側撃破")


## 属性条件刺突発動: インフェルノイーグル vs 水属性
## インフェルノイーグル(火,AP50,HP40,先制・刺突[水風]・強化[水風]) vs タイダルオーガ(水,AP40,HP50)
## 敵=水→刺突発動+強化発動→AP75 / land_bonus=0→HP50
## 先制: AP75→50-75=-25死亡→反撃なし
func test_penetration_element_condition_activate():
	var config = _create_config(38, 138, "water")  # インフェルノイーグル vs タイダルオーガ
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 75, "強化[水風]→AP50×1.5=75")
	assert_eq(r.defender_final_hp, -25, "先制+刺突→HP50-75=-25")
	assert_eq(r.attacker_final_hp, 40, "先制一撃撃破→反撃なし")
	assert_eq(r.winner, "attacker", "先制一撃撃破")


## 属性条件刺突不発: インフェルノイーグル vs 火属性
## インフェルノイーグル(火,AP50,HP40,先制・刺突[水風]・強化[水風]) vs レッドオーガ(火,AP40,HP50)
## 敵=火→刺突不発+強化不発→AP50 / land_bonus=10→HP60
## 先制: AP50→land10吸収+HP50-40=10生存→反撃AP40→HP40-40=0
func test_penetration_element_condition_not_activate():
	var config = _create_config(38, 48, "fire")  # インフェルノイーグル vs レッドオーガ
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 50, "強化不発→AP50のまま")
	assert_eq(r.defender_final_hp, 10, "刺突不発→land10有効→HP60-50→current10")
	assert_eq(r.attacker_final_hp, 0, "反撃AP40→HP40-40=0")
	assert_eq(r.winner, "defender", "攻撃側死亡")


## 蓄魔は侵略側のみ: レイドワイバーンが防御側→蓄魔なし
## タイダルオーガ(水,AP40,HP50) attacks レイドワイバーン(火,AP40,HP50) on fire
## レイドワイバーンは防御側→侵略時蓄魔不発
## land_bonus=10→HP60 / AP40→60-40=20生存 / AP40→50-40=10
func test_magic_gain_invasion_only_attacker():
	var config = _create_config(138, 36, "fire")  # タイダルオーガ vs レイドワイバーン
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 20, "land10+HP50=60-40=20")
	assert_eq(r.attacker_final_hp, 10, "反撃AP40→HP50-40=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_does_not_have(r.defender_battle_effects, "蓄魔[100EP]", "防御側蓄魔なし")


## 鼓舞でcurrent_ap上昇しても刺突条件はベースAPで判定
## レイドワイバーン(火,AP40,刺突[敵AP≧40]) vs ナイトメア(風,AP30,HP30) on wind tile11
## タイル12にトリックスター(342,owner=1)配置→隣接自ドミニオ1→AP+20,HP+20
## 防御側current_ap=50だが刺突チェックはcreature_data["ap"]=30→30<40→刺突不発
## HP30+land10+鼓舞HP20=60 / AP40→60-40=20生存 / 反撃AP50→HP50-50=0
func test_penetration_not_triggered_by_support_boosted_ap():
	var config = _create_config(36, 334, "wind")  # レイドワイバーン vs ナイトメア
	config.board_layout.append({"tile_index": 12, "owner_id": 1, "creature_id": 342})
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 50, "鼓舞AP+20→AP30+20=50")
	assert_eq(r.defender_final_hp, 20, "刺突不発→land10+鼓舞HP20+HP30=60-40=20")
	assert_eq(r.attacker_final_hp, 0, "反撃AP50→HP50-50=0")
	assert_eq(r.winner, "defender", "鼓舞で防御側生存→攻撃側死亡")


# =============================================================================
# 復活スキル（手札復活）
# =============================================================================

## フェニックス防御側撃破 → 手札復活発動
## オルトロス(火,AP50/HP40) vs フェニックス(火,AP40/HP30,復活)
## 火タイルLv1→防御側ランドボーナスHP+10→HP40
## 攻撃AP50→防HP40-50=-10→撃破→手札復活発動
func test_revive_to_hand_phoenix_defender_killed():
	var config = _create_config(213, 40, "fire")  # オルトロス vs フェニックス
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, -10, "AP50で撃破（HP40-50=-10）")
	assert_eq(r.winner, "attacker", "防御側撃破")
	assert_true(r.defender_revive_to_hand, "手札復活発動")
	assert_false(r.attacker_revive_to_hand, "攻撃側は復活なし")


## フェニックス防御側生存 → 手札復活なし
## ゴブリン(無,AP20/HP30) vs フェニックス(火,AP40/HP30,復活)
## 火タイルLv1→防御側ランドボーナスHP+10→HP40
## 攻撃AP20→防HP40-20=20 / 反撃AP40→攻HP30-40=-10→攻撃側撃破
func test_revive_to_hand_phoenix_defender_survives():
	var config = _create_config(414, 40, "fire")  # ゴブリン vs フェニックス
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 20, "HP40-20=20で生存")
	assert_eq(r.winner, "defender", "攻撃側撃破→防御側勝利")
	assert_false(r.defender_revive_to_hand, "生存→手札復活なし")


## イモータルランド防御側撃破 → 手札復活発動（JSON修正後の動作確認）
## オルトロス(火,AP50/HP40) vs イモータルランド(地,AP30/HP40,復活+領土守護)
## 地タイルLv1→防御側ランドボーナスHP+10→HP50
## 攻撃AP50→防HP50-50=0→撃破→手札復活発動
func test_revive_to_hand_immortal_land_defender_killed():
	var config = _create_config(213, 232, "earth")  # オルトロス vs イモータルランド
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "AP50でHP50→0撃破")
	assert_eq(r.winner, "attacker", "防御側撃破")
	assert_true(r.defender_revive_to_hand, "手札復活発動")


## フェニックス攻撃側が先制で撃破 → 手札復活発動
## フェニックス(火,AP40/HP30,復活) vs ケルベロス(火,AP50/HP50,先制)
## 火タイルLv1→防御側ランドボーナスHP+10→HP60
## ケルベロス先制AP50→フェニックスHP30-50=-20→撃破→手札復活発動
func test_revive_to_hand_phoenix_attacker_killed():
	var config = _create_config(40, 27, "fire")  # フェニックス vs ケルベロス
	var r = await _execute_battle(config)
	assert_true(r.first_strike_occurred, "先制発動")
	assert_eq(r.attacker_final_hp, -20, "先制AP50で撃破（HP30-50=-20）")
	assert_eq(r.winner, "defender", "攻撃側撃破→防御側勝利")
	assert_true(r.attacker_revive_to_hand, "攻撃側手札復活発動")
	assert_false(r.defender_revive_to_hand, "防御側は復活なし")


# =============================================================================
# 形見スキル[EP]
# =============================================================================

## コーンフォーク防御側撃破 → 形見[EP200]発動
## タイダルオーガ(水,AP40/HP50) vs コーンフォーク(風,AP30/HP40,形見[200EP])
## 風タイルLv1→防御側ランドボーナスHP+10→HP50
## 攻AP40→防HP50-40=10(land10消費)→current_hp40 / 反撃AP30→攻HP50-30=20
## → 両者生存 → 形見不発。AP50必要 → ツヴァイハンダー(AP+50)使用
## タイダルオーガ+ツヴァイハンダー(AP90) vs コーンフォーク(風,HP40+land10)
## 攻AP90→防HP50-90=-40→撃破→形見EP200 / 先に攻撃なので反撃なし
func test_legacy_ep_cornfolk_defender_killed():
	var config = _create_config(138, 315, "wind")  # タイダルオーガ vs コーンフォーク(風)
	config.attacker_items = [1009]  # ツヴァイハンダー(AP+50)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, -40, "AP90でHP50→-40撃破")
	assert_eq(r.winner, "attacker", "防御側撃破")
	assert_true(r.defender_battle_effects.has("蓄魔[200EP]"), "形見[EP200]発動")


## コーンフォーク防御側生存 → 形見不発
## ゴブリン(無,AP20/HP30) vs コーンフォーク(風,AP30/HP40,形見[200EP])
## 風タイルLv1→防御側ランドボーナスHP+10→total50
## 攻AP20→land10消費+current_hp10消費→current_hp30 / 反撃AP30→攻HP30-30=0→攻撃側撃破
func test_legacy_ep_cornfolk_defender_survives():
	var config = _create_config(414, 315, "wind")  # ゴブリン vs コーンフォーク(風)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 30, "land10+current10消費→current_hp30")
	assert_eq(r.winner, "defender", "攻撃側撃破")
	assert_false(r.defender_battle_effects.has("蓄魔[200EP]"), "生存→形見不発")


## ミミック防御側撃破 → 蓄魔[100]+形見[100]=EP200
## タイダルオーガ(水,AP40/HP50) vs ミミック(無,AP10/HP30,蓄魔[100]+形見[100EP])
## 中立タイルLv1→ランドボーナスHP+10→total40
## 蓄魔100(バトル開始時) + 攻AP40→land10+current30消費→current_hp0→撃破→形見EP100
## 撃破されたので反撃なし→攻HP50維持
func test_legacy_ep_mimic_defender_killed():
	var config = _create_config(138, 410)  # タイダルオーガ vs ミミック(中立)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "AP40でtotal40→0撃破")
	assert_eq(r.attacker_final_hp, 50, "撃破→反撃なし→HP50維持")
	assert_eq(r.winner, "attacker", "防御側撃破")
	assert_true(r.defender_battle_effects.has("蓄魔[200EP]"), "蓄魔100+形見100=EP200")


# =============================================================================
# 形見スキル[カード]
# =============================================================================

## フェイト防御側撃破 → 形見[カード1枚]発動
## レッドオーガ(火,AP40/HP50)+ツヴァイハンダー(AP+50)=AP90 vs フェイト(水,AP10/HP40,形見[カード1枚])
## 水タイルLv1→防御側ランドボーナスHP+10→total50
## 攻AP90→total50-90=-40→撃破→形見カード1枚ドロー
## 手札: 初期5枚→ドロー1枚→6枚
func test_legacy_card_fate_defender_killed():
	var config = _create_config(48, 136, "water")  # レッドオーガ vs フェイト(水)
	config.attacker_items = [1009]  # ツヴァイハンダー(AP+50)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, -40, "AP90でtotal50→-40撃破")
	assert_eq(r.winner, "attacker", "防御側撃破")
	assert_eq(r.defender_hand_count, 6, "形見[カード]発動→初期5枚+1枚=6枚")


## フェイト防御側生存 → 形見不発
## ゴブリン(無,AP20/HP30) vs フェイト(水,AP10/HP40,形見[カード1枚])
## 水タイルLv1→防御側ランドボーナスHP+10→total50
## 攻AP20→land10+current10消費→current_hp30 / 反撃AP10→攻HP30-10=20
func test_legacy_card_fate_defender_survives():
	var config = _create_config(414, 136, "water")  # ゴブリン vs フェイト(水)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 30, "land10+current10消費→current_hp30")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_eq(r.defender_hand_count, 5, "生存→形見不発→初期5枚のまま")


# =============================================================================
# 復帰スキル（帰還[ブック]）- クリーチャースキル由来
# =============================================================================

## ケンタウロス攻撃側+武器 → アイテムがブックに復帰
## ケンタウロス(風,AP30/HP40,先制+帰還[ブック]) + ツヴァイハンダー(AP+50) = AP80
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10→total40
## 先制AP80→HP40-80=-40→撃破→反撃なし → 帰還:ツヴァイハンダーがブックへ
func test_item_return_centaur_attacker_with_weapon():
	var config = _create_config(314, 414)  # ケンタウロス+ツヴァイハンダー vs ゴブリン
	config.attacker_items = [1009]  # ツヴァイハンダー(武器, AP+50)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 80, "AP30+50=80")
	assert_eq(r.defender_final_hp, -40, "先制AP80→HP40-80=-40撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	assert_true(r.attacker_item_returned, "帰還スキルでアイテムがブックに復帰")
	assert_eq(r.attacker_item_return_type, "deck", "ブック復帰")


## ケンタウロス攻撃側アイテムなし → 復帰なし
## ケンタウロス(風,AP30/HP40,先制) vs ゴブリン(無,AP20/HP30) on neutral
## land_bonus=10→total40 / 先制AP30→HP40-30=10生存 / 反撃AP20→HP40-20=20
func test_item_return_centaur_no_item():
	var config = _create_config(314, 414)  # ケンタウロス vs ゴブリン
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 10, "先制AP30→HP40-30=10(land10消費)")
	assert_eq(r.attacker_final_hp, 20, "反撃AP20→HP40-20=20")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_false(r.attacker_item_returned, "アイテムなし→復帰なし")


## ケンタウロス防御側+武器 → 防御側アイテムがブック復帰
## レッドオーガ(火,AP40/HP50) vs ケンタウロス(風,AP30/HP40,先制+帰還) + ツヴァイハンダー(AP+50)
## 風タイルLv1→land_bonus=10→total HP50+10=60(wind+ツヴァイハンダーHP0)
## ケンタウロス先制: AP30+50=80 → レッドオーガHP50-80=-30→撃破→反撃なし
## 帰還: ツヴァイハンダーがブックへ
func test_item_return_centaur_defender_with_weapon():
	var config = _create_config(48, 314, "wind")  # レッドオーガ vs ケンタウロス
	config.defender_items = [1009]  # ツヴァイハンダー(武器, AP+50)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 80, "AP30+50=80")
	assert_eq(r.attacker_final_hp, -30, "先制AP80→HP50-80=-30撃破")
	assert_eq(r.winner, "defender", "防御側勝利")
	assert_true(r.defender_item_returned, "防御側帰還スキルでブック復帰")
	assert_eq(r.defender_item_return_type, "deck", "ブック復帰")


## アグニ攻撃側+武器 → 強化発動+帰還
## アグニ(火,AP50/HP50,先制+強化[武器]+帰還[ブック]) + ツヴァイハンダー(AP+50) = AP100
## 武器使用→強化発動→AP100×1.5=150
## vs タイダルオーガ(水,AP40/HP50) on water, land_bonus=10→total60
## 先制AP150→HP60-150=-90→撃破→反撃なし → 帰還:ツヴァイハンダーがブックへ
func test_item_return_agni_attacker_power_strike_and_return():
	var config = _create_config(41, 138, "water")  # アグニ+ツヴァイハンダー vs タイダルオーガ
	config.attacker_items = [1009]  # ツヴァイハンダー(武器, AP+50)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 150, "武器使用→強化AP100×1.5=150")
	assert_eq(r.defender_final_hp, -90, "先制AP150→HP60-150=-90撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	assert_true(r.attacker_item_returned, "帰還スキルでアイテムがブック復帰")
	assert_eq(r.attacker_item_return_type, "deck", "ブック復帰")


## アグニ攻撃側アイテムなし → 強化不発+復帰なし
## アグニ(火,AP50/HP50,先制) vs ゴブリン(無,AP20/HP30) on neutral
## 武器なし→強化不発→AP50 / land_bonus=10→total40
## 先制AP50→HP40-50=-10→撃破
func test_item_return_agni_no_item_no_power_strike():
	var config = _create_config(41, 414)  # アグニ vs ゴブリン
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 50, "武器なし→強化不発→AP50のまま")
	assert_eq(r.defender_final_hp, -10, "先制AP50→HP40-50=-10撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	assert_false(r.attacker_item_returned, "アイテムなし→復帰なし")


