extends GutTest

## 刻印効果バトルテスト
## 刻印付与状態でバトルを行い、効果が正しく適用されるかを検証

var _executor: BattleTestExecutor


func before_all():
	_executor = BattleTestExecutor.new()
	_executor.scene_tree_parent = self


## 汎用config作成
func _create_config(attacker_id: int, defender_id: int, defender_land: String = "neutral") -> BattleTestConfig:
	var config = BattleTestConfig.new()
	config.attacker_creatures = [attacker_id]
	config.defender_creatures = [defender_id]
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
# skill_nullify（錯乱）: スキル無効化
# ========================================

## 錯乱刻印でスキルが発動しない
## ケルベロス(火,AP50/HP50,先制) に錯乱 → 先制が発動しない
## vs レッドコボルト(火,AP20/HP20) 中立地
## 通常: 先制でケルベロスが先攻→AP50でコボルト撃破
## 錯乱時: 先制なし→攻撃側コボルトが先攻AP20→ケルベロスHP30、反撃AP50→コボルト撃破
func test_skill_nullify_blocks_first_strike():
	var config = _create_config(50, 27)  # レッドコボルト vs ケルベロス
	config.defender_pre_curse = {
		"curse_type": "skill_nullify",
		"name": "錯乱",
		"duration": -1,
		"params": {"name": "錯乱"}
	}
	var r = await _execute_battle(config)
	assert_false(r.first_strike_occurred, "錯乱: 先制が発動しない")
	assert_eq(r.winner, "defender", "防御側勝利（先制なしでも素ステで勝つ）")


# ========================================
# battle_disable（消沈）: 攻撃不可
# ========================================

## 消沈刻印で攻撃側が攻撃できない
## レッドコボルト(火,AP20/HP20) に消沈 vs レッドコボルト(火,AP20/HP20) 中立地
## 消沈側は攻撃スキップ → 防御側が反撃でダメージ20 → 攻撃側HP0
func test_battle_disable_attacker_cannot_attack():
	var config = _create_config(50, 50)  # レッドコボルト vs レッドコボルト
	config.attacker_pre_curse = {
		"curse_type": "battle_disable",
		"name": "消沈",
		"duration": -1,
		"params": {}
	}
	var r = await _execute_battle(config)
	assert_eq(r.damage_dealt_by_attacker, 0, "消沈: 攻撃側ダメージ0")
	assert_eq(r.winner, "defender", "防御側勝利（攻撃側は攻撃できない）")


# ========================================
# ap_nullify: 基礎AP=0化
# ========================================

## AP無効刻印で基礎APが0になる
## レッドコボルト(火,AP20/HP20) に AP=0 vs レッドコボルト(火,AP20/HP20) 中立地
## AP=0 → ダメージ0 → 防御側HP変化なし
func test_ap_nullify_zero_damage():
	var config = _create_config(50, 50)  # レッドコボルト vs レッドコボルト
	config.attacker_pre_curse = {
		"curse_type": "ap_nullify",
		"name": "AP=0",
		"duration": -1,
		"params": {"name": "AP=0"}
	}
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 0, "AP無効: 最終AP=0")
	assert_eq(r.damage_dealt_by_attacker, 0, "AP無効: ダメージ0")


# ========================================
# stat_reduce（零落）: ステータス減少
# ========================================

## ステータス減少刻印でHP/AP両方-10
## レッドコボルト(火,AP20/HP20) に零落(-10) vs レッドコボルト(火,AP20/HP20) 中立地Lv0
## 土地レベル0で地形ボーナスなし
## AP20-10=10 → ダメージ10 → 防御HP20-10=10
## 防御側反撃AP20 → 攻撃側HP(20-10=10)-20=-10 → 攻撃側撃破
func test_stat_reduce_both():
	var config = _create_config(50, 50)  # レッドコボルト vs レッドコボルト
	config.attacker_battle_land_level = 0
	config.defender_battle_land_level = 0
	config.attacker_pre_curse = {
		"curse_type": "stat_reduce",
		"name": "零落",
		"duration": -1,
		"params": {"name": "零落", "stat": "both", "value": -10}
	}
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 10, "零落: AP20-10=10")
	assert_eq(r.defender_final_hp, 10, "零落: 防御側HP20-10=10")
	assert_eq(r.winner, "defender", "防御側勝利（攻撃側HP10で反撃20受けて撃破）")


# ========================================
# metal_form（メタルフォーム）: 通常攻撃無効化
# ========================================

## メタルフォーム刻印で通常攻撃が無効
## レッドコボルト(火,AP20/HP20) vs レッドコボルト(火,AP20/HP20) にメタルフォーム 中立地
## 防御側メタル → 攻撃側の通常攻撃無効 → 防御側HP変化なし
func test_metal_form_blocks_normal_attack():
	var config = _create_config(50, 50)  # レッドコボルト vs レッドコボルト
	config.defender_pre_curse = {
		"curse_type": "metal_form",
		"name": "メタルフォーム",
		"duration": -1,
		"params": {}
	}
	var r = await _execute_battle(config)
	assert_eq(r.damage_dealt_by_attacker, 0, "メタルフォーム: 通常攻撃無効")
	assert_eq(r.defender_final_hp, 20, "防御側HP変化なし")


# ========================================
# destroy_after_battle（崩壊）: 戦闘後に破壊
# ========================================

## 崩壊刻印で戦闘に勝っても破壊される
## ケルベロス(火,AP50/HP50,先制) に崩壊 vs レッドコボルト(火,AP20/HP20) 中立地
## 先制AP50→コボルト撃破、ケルベロス生存
## しかし崩壊刻印により戦闘後にHP=0に → 両者撃破扱い
func test_destroy_after_battle():
	var config = _create_config(27, 50)  # ケルベロス vs レッドコボルト
	config.attacker_pre_curse = {
		"curse_type": "destroy_after_battle",
		"name": "崩壊",
		"duration": -1,
		"params": {}
	}
	var r = await _execute_battle(config)
	# 崩壊によりケルベロスもHP=0になる → 両者撃破
	assert_eq(r.winner, "both_defeated", "崩壊: 両者撃破")
	assert_eq(r.attacker_final_hp, 0, "崩壊: ケルベロスHP=0")
	# 崩壊刻印は処理後にeraseされる
	assert_true(r.attacker_curse.is_empty(), "崩壊刻印は処理後に除去される")


# ========================================
# plague（衰弱）: 戦闘終了時HP -= MHP/2
# ========================================

## 衰弱刻印で戦闘終了時にMHP/2のダメージを受ける
## ケルベロス(火,AP50/HP50) に衰弱 vs レッドコボルト(火,AP20/HP20) 中立地Lv0
## 先制AP50→コボルト撃破、ケルベロスHP50（反撃なし）
## 戦闘終了後: 衰弱ダメージ MHP/2 = 50/2 = 25 → HP50-25=25
func test_plague_damage_after_battle():
	var config = _create_config(27, 50)  # ケルベロス vs レッドコボルト
	config.attacker_battle_land_level = 0
	config.defender_battle_land_level = 0
	config.attacker_pre_curse = {
		"curse_type": "plague",
		"name": "衰弱",
		"duration": -1,
		"params": {}
	}
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	# 衰弱ダメージ: MHP=50, damage=50/2=25, HP=50-25=25
	assert_eq(r.attacker_final_hp, 25, "衰弱: HP50-25=25")


# ========================================
# magic_barrier（マジックバリア）: 通常攻撃無効 + EP移動
# ========================================

## マジックバリア刻印で通常攻撃が無効（メタルフォームと同じ無効化）
## レッドコボルト(火,AP20/HP20) vs レッドコボルト(火,AP20/HP20) にマジックバリア 中立地
## 防御側バリア → 攻撃側の通常攻撃無効 → 防御側HP変化なし
func test_magic_barrier_blocks_normal_attack():
	var config = _create_config(50, 50)  # レッドコボルト vs レッドコボルト
	config.defender_pre_curse = {
		"curse_type": "magic_barrier",
		"name": "マジックバリア",
		"duration": -1,
		"params": {"ep_transfer": 100}
	}
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 20, "マジックバリア: 防御側HP変化なし")


# ========================================
# land_effect_disable（暗転）: 地形ボーナス無効
# ========================================

## 暗転刻印で地形ボーナスが無効になる
## レッドコボルト(火,HP20/AP20) on 火タイルLv3 → 通常は地形ボーナス+30
## 暗転あり → 地形ボーナスなし → HP20のまま
## vs レッドコボルト(火,HP20/AP20) 攻撃側
func test_land_effect_disable_removes_land_bonus():
	var config = _create_config(50, 50, "fire")  # レッドコボルト vs レッドコボルト on 火タイル
	config.defender_battle_land_level = 3
	config.defender_pre_curse = {
		"curse_type": "land_effect_disable",
		"name": "暗転",
		"duration": -1,
		"params": {}
	}
	var r = await _execute_battle(config)
	# 暗転なしならHP20+30=50、暗転ありならHP20
	# 攻撃側AP20 vs 防御側HP20 → 防御側HP0
	assert_eq(r.winner, "attacker", "暗転: 地形ボーナスなしで攻撃側勝利")


## 暗転なしの場合は地形ボーナスが付く（対照実験）
## 防御側HP20 + 地形ボーナス30 = 実質50。攻撃AP20 → 土地ボーナスから消費
## defender_final_hpはcurrent_hp（土地ボーナス含まない）なので20のまま
func test_land_effect_disable_control():
	var config = _create_config(50, 50, "fire")  # レッドコボルト vs レッドコボルト on 火タイル
	config.defender_battle_land_level = 3
	# 暗転なし → 地形ボーナスありで防御側生存
	var r = await _execute_battle(config)
	assert_eq(r.winner, "defender", "暗転なし: 地形ボーナスありで防御側勝利")
	# current_hpは20のまま（土地ボーナスから消費）
	assert_eq(r.defender_final_hp, 20, "暗転なし: 基礎HPは無傷")


# ========================================
# land_effect_grant（恩寵）: 他属性で地形ボーナス取得
# ========================================

## 恩寵刻印で属性不一致でも地形ボーナスを得る
## ブルーコボルト(水,HP20/AP20) on 火タイルLv3 → 通常は地形ボーナスなし
## 恩寵あり → 地形ボーナス+30 → 実質HP50
## vs レッドコボルト(火,HP20/AP20) 攻撃側
func test_land_effect_grant_gives_bonus():
	var config = _create_config(50, 150, "fire")  # レッドコボルト vs ブルーコボルト on 火タイル
	config.defender_battle_land_level = 3
	config.defender_pre_curse = {
		"curse_type": "land_effect_grant",
		"name": "恩寵",
		"duration": -1,
		"params": {"grant_elements": []}
	}
	var r = await _execute_battle(config)
	# 恩寵あり → 地形ボーナス+30 → 防御側が生存
	assert_eq(r.winner, "defender", "恩寵: 地形ボーナスで防御側勝利")
	# current_hpは20のまま（土地ボーナスから消費）
	assert_eq(r.defender_final_hp, 20, "恩寵: 基礎HPは無傷")


## 恩寵なしの場合は属性不一致で地形ボーナスなし（対照実験）
func test_land_effect_grant_control():
	var config = _create_config(50, 150, "fire")  # レッドコボルト vs ブルーコボルト on 火タイル
	config.defender_battle_land_level = 3
	# 恩寵なし → 水属性は火タイルで地形ボーナスなし
	var r = await _execute_battle(config)
	# 地形ボーナスなし → 防御側HP20、攻撃側AP20 → HP0
	assert_eq(r.winner, "attacker", "恩寵なし: 地形ボーナスなしで攻撃側勝利")


# ========================================
# random_stat（狂星）: AP/HPランダム化
# ========================================

## 狂星刻印でAP/HPがランダム値に変化する
## レッドコボルト(火,AP20/HP20) に狂星(min=10,max=70)
## AP/HPが10〜70の範囲内に収まることを検証
func test_random_stat_changes_stats():
	var config = _create_config(50, 50)  # レッドコボルト vs レッドコボルト
	config.attacker_battle_land_level = 0
	config.defender_battle_land_level = 0
	config.attacker_pre_curse = {
		"curse_type": "random_stat",
		"name": "狂星",
		"duration": -1,
		"params": {"name": "狂星", "stat": "both", "min": 10, "max": 70}
	}
	var r = await _execute_battle(config)
	# APが10〜70の範囲（元のAP20とは異なる可能性が高い）
	assert_true(r.attacker_final_ap >= 10 and r.attacker_final_ap <= 70,
		"狂星: AP=%d は10-70の範囲内" % r.attacker_final_ap)


# ========================================
# stat_boost（ステ上昇）: HP/AP増加
# ========================================

## ステ上昇刻印でHP/APが増加する
## レッドコボルト(火,AP20/HP20) にstat_boost(+10) vs レッドコボルト(火,AP20/HP20) 中立地Lv0
## AP20+10=30 → ダメージ30 → 防御HP20-30=-10 → 防御側撃破
## 反撃なし（防御側先に撃破）
func test_stat_boost_increases_stats():
	var config = _create_config(50, 50)  # レッドコボルト vs レッドコボルト
	config.attacker_battle_land_level = 0
	config.defender_battle_land_level = 0
	config.attacker_pre_curse = {
		"curse_type": "stat_boost",
		"name": "強化",
		"duration": -1,
		"params": {"name": "強化", "value": 10}
	}
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "ステ上昇: AP20+10=30")
	assert_eq(r.winner, "attacker", "ステ上昇: AP30で防御側HP20を一撃撃破")
