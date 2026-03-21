extends GutTest

## 個別クリーチャーテスト
## 各クリーチャー固有の複合スキル・効果を検証

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


# ==============================================================================
# 個別クリーチャーテスト: フレイムパラディン(ID:1)
# 火, S, AP0/HP50, AP変動[火地×10], 無効化[巻物]
# ==============================================================================

## AP変動基本: 火2+地1所有 → AP=(2+1)×10=30
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP30→land10+cur20消費→def_hp=10, AP20→att_hp=30
func test_flame_paladin_land_count_ap():
	var config = _create_config(1, 414)
	# 攻撃側の所有タイル: 火2+地1をboard_layoutに追加
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 48})   # 火タイル1
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 48})   # 火タイル2
	config.board_layout.append({"tile_index": 16, "owner_id": 0, "creature_id": 213}) # 地タイル1
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "火2+地1=3×10=AP30")
	assert_eq(r.defender_final_hp, 10, "防HP40-30=10")
	assert_eq(r.attacker_final_hp, 30, "攻HP50-20=30")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## AP変動ゼロ: 自分タイルなし、敵に火1所有 → 敵のタイルはカウントしない → AP=0
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP0→ダメージ0→def_hp=30, AP20→att_hp=30
func test_flame_paladin_zero_ap_enemy_lands_ignored():
	var config = _create_config(1, 414)
	# 敵(player_id=1)に火タイル1つ → 自分のカウントに入らないことを確認
	config.board_layout.append({"tile_index": 1, "owner_id": 1, "creature_id": 48})  # 敵の火タイル
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 0, "自分タイルなし→AP0、敵の火タイルは不検知")
	assert_eq(r.defender_final_hp, 30, "AP0→ダメージなし→cur_hp=30")
	assert_eq(r.attacker_final_hp, 30, "攻HP50-20=30")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 無効化[巻物]: 攻撃側が巻物使用→防御側フレイムパラディンが無効化
## ウィスプ(風,AP30/HP30,術攻撃[固定AP30]) vs フレイムパラディン(火,AP0/HP50,無効化[巻物])
## ウィスプの術攻撃AP30→フレイムパラディンの無効化[巻物]で完全無効→ダメージ0
## フレイムパラディンAP0(タイルなし)→ダメージ0 → 両者無傷
func test_flame_paladin_nullify_scroll_attack():
	var config = _create_config(34, 1)  # ウィスプ(攻) vs フレイムパラディン(防)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_is_using_scroll, true, "ウィスプは術攻撃")
	assert_eq(r.defender_final_hp, 50, "無効化[巻物]→ダメージ0→HP50無傷")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 強化アイテム併用: AP変動後に強化が乗る
## フレイムパラディン(火2+地1→AP30)+ジャイアントキラー(AP+30,強化[敵MHP≧40])
## vs レッドオーガ(火,AP40/HP50,MHP=50≧40→強化発動)
## AP30+30=60→強化×1.5→AP90 on fire, land_bonus=10
## AP90→land10+cur50→60-90→def_hp=-30→撃破
func test_flame_paladin_with_power_strike_item():
	var config = _create_config(1, 48, "fire")
	# 攻撃側: 火2+地1
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 16, "owner_id": 0, "creature_id": 213})
	config.attacker_items = [1060]  # ジャイアントキラー(武器,AP+30,強化[敵MHP≧40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 90, "AP30+30=60→強化×1.5=90")
	assert_eq(r.defender_final_hp, -30, "防HP60(50+land10)-90=-30→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ============================================================
# ウリエル (ID:4) - 火, R, AP40/HP40
# 強化[刻印付きクリーチャー]；アルカナアーツ[EP50・世界刻印を消す]
# ============================================================

## 強化[has_mark]発動: 敵に刻印あり → AP40×1.5=60
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP60→land10+cur30消費→def_hp=-20, ゴブリン撃破
func test_uriel_power_strike_with_marked_enemy():
	var config = _create_config(4, 414)
	config.defender_pre_curse = {"curse_type": "bounty", "name": "懸賞"}
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "刻印あり→強化発動→AP40×1.5=60")
	assert_eq(r.defender_final_hp, -20, "防HP40(30+land10)-60=-20→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 強化不発: 敵に刻印なし・アイテムなし → AP40のまま
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP40→land10+cur30消費→def_hp=0, ゴブリン撃破
func test_uriel_no_power_strike_without_mark():
	var config = _create_config(4, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "刻印なし→強化不発→AP40")
	assert_eq(r.defender_final_hp, 0, "防HP40(30+land10)-40=0→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## ガイアハンマー併用: 強化が2重にならない
## ウリエル(火,AP40)+ガイアハンマー(AP+20,火地使用時強化) vs 刻印付きゴブリン
## AP40+20=60→強化×1.5=90（×1.5は1回のみ、2.25にはならない）
## on neutral, land_bonus=10 → ゴブリンHP40-90=-50→撃破
func test_uriel_gaia_hammer_no_double_power_strike():
	var config = _create_config(4, 414)
	config.defender_pre_curse = {"curse_type": "bounty", "name": "懸賞"}
	config.attacker_items = [1063]  # ガイアハンマー(武器,AP+20,火地使用時強化)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 90, "AP60→強化×1.5=90（2重にならない）")
	assert_eq(r.defender_final_hp, -50, "防HP40(30+land10)-90=-50→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ============================================================
# ボムスライム (ID:13) - 火, N, AP10/HP40
# 自破壊時、敵のHP-40
# 巻物使用不可
# ============================================================

## 死亡時ダメージ発動: ボムスライム撃破 → 敵にHP-40ダメージ
## vs ドラゴンゾンビ(無,AP50/HP60) on neutral, land_bonus=10
## 攻AP10→land10消費→def_hp=60, 防AP50→att_hp=-10→撃破
## 死亡時: 敵HP-40 → def_hp=60-40=20
func test_bomb_slime_death_damage_activates():
	var config = _create_config(13, 425)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, -10, "攻HP40-50=-10→撃破")
	assert_eq(r.defender_final_hp, 20, "防HP60-40(死亡時ダメージ)=20")
	assert_eq(r.winner, "defender", "防御側勝利")


## 死亡時ダメージで相討ち: ボムスライム撃破 → 敵HP-40 → 敵も死亡
## vs エターナガード(火,AP40/HP40) on neutral, land_bonus=10
## 攻AP10→land10消費→def_hp=40, 防AP40→att_hp=0→撃破
## 死亡時: 敵HP-40 → def_hp=40-40=0→相討ち
func test_bomb_slime_death_damage_mutual_kill():
	var config = _create_config(13, 14)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "攻HP40-40=0→撃破")
	assert_eq(r.defender_final_hp, 0, "防HP40-40(死亡時ダメージ)=0→相討ち")


## 生存時は不発: ボムスライムが生き残る → death効果発動せず
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## 攻AP10→land10消費→def_hp=30, 防AP20→att_hp=20
## 両者生存→死亡時効果発動せず→def_hp=30のまま
func test_bomb_slime_no_death_damage_when_alive():
	var config = _create_config(13, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 20, "攻HP40-20=20→生存")
	assert_eq(r.defender_final_hp, 30, "防HP30→死亡時効果不発→30のまま")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 防御側テスト: ボムスライム防御側で撃破 → 攻撃者にHP-40
## ドラゴンゾンビ(無,AP50/HP60) vs ボムスライム(火,AP10/HP40) on neutral
## neutral→全クリーチャーにland_bonus=10
## 攻AP50→land10+cur40消費→def_hp=0→撃破 → 死亡時: 攻撃者にHP-40 → att_hp=60-40=20
func test_bomb_slime_defender_death_damage():
	var config = _create_config(425, 13)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "防HP50(40+land10)-50=0→撃破")
	assert_eq(r.attacker_final_hp, 20, "攻HP60-40(死亡時ダメージ)=20")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 刻印(stat_reduce)で弱体化後に撃破 → 死亡時効果は発動する
## ドラゴンゾンビ(無,AP50/HP60) vs ボムスライム(火,AP10/HP40,消沈HP-20) on neutral
## ボムスライムHP: 40-刻印20=cur20, land_bonus=10
## 攻AP50→land10+cur20消費→def_hp=-20→撃破
## 死亡時: 攻撃者にHP-40 → att_hp=60-40=20
func test_bomb_slime_cursed_death_damage_still_fires():
	var config = _create_config(425, 13)
	config.defender_pre_curse = {"curse_type": "stat_reduce", "name": "消沈", "params": {"value": -20, "stat": "hp"}}
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, -20, "防HP30(20+land10)-50=-20→撃破")
	assert_eq(r.attacker_final_hp, 20, "攻HP60-40(死亡時ダメージ)=20→刻印があっても発動")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ============================================================
# マルコシアス (ID:15) - 火, S, AP30/HP40
# 先制；AP+MHP50以上配置数×5
# ============================================================

## AP変動: MHP50以上2体+MHP50未満2体配置 → 2×5=AP+10 → AP40
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## 先制: マルコシアスAP40→land10+cur30消費→def_hp=0→撃破
func test_marcosias_conditional_land_count():
	var config = _create_config(15, 414)
	# MHP≧50 → カウント対象
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 48})   # レッドオーガ(HP50) ✓
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 425})  # ドラゴンゾンビ(HP60) ✓
	# MHP<50 → カウント対象外
	config.board_layout.append({"tile_index": 3, "owner_id": 0, "creature_id": 414})  # ゴブリン(HP30) ✗
	config.board_layout.append({"tile_index": 4, "owner_id": 0, "creature_id": 13})   # ボムスライム(HP40) ✗
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "AP30+MHP50以上2体×5=AP40")
	assert_eq(r.defender_final_hp, 0, "防HP40(30+land10)-40=0→撃破")
	assert_eq(r.winner, "attacker", "先制で攻撃側勝利")


# ============================================================
# ショックブリンガー (ID:18) - 火, S, AP10/HP40
# 先制；攻撃成功時、敵をダウン；奮闘
# ============================================================

## 攻撃成功時ダウン: 攻撃が通る → 防御側タイルがダウン
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## 先制AP10→land10消費→def_hp=30(生存) → ダウン付与
## 防AP20→att_hp=20
func test_shock_bringer_down_on_attack_success():
	var config = _create_config(18, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 20, "攻HP40-20=20→生存")
	assert_eq(r.defender_final_hp, 30, "防HP30→生存")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_eq(r.defender_tile_down, true, "攻撃成功→防御側タイルがダウン")


## 奮闘持ち防御側: ダウンしない
## vs エターナガード(火,AP40/HP40) on neutral → ダウン無効（奮闘は別クリーチャーに必要）
## 奮闘持ちを防御側に配置 → ダウン無効を確認
## ※ショックブリンガー自体が奮闘持ちだが、ダウン対象は防御側タイル
func test_shock_bringer_down_blocked_by_indomitable():
	# ショックブリンガー(攻) vs ショックブリンガー(防, 奮闘持ち)
	var config = _create_config(18, 18)
	var r = await _execute_battle(config)
	assert_eq(r.defender_tile_down, false, "防御側が奮闘持ち→ダウンしない")


## サイレントローブ(HP+40,敵の攻撃成功時能力無効)で攻撃成功時ダウンを無効化
## ショックブリンガー(攻,AP10/HP40,先制) vs ゴブリン(防,AP20/HP30)+サイレントローブ(HP+40)
## on neutral, land_bonus=10, item_bonus_hp=40
## 先制AP10→land10から消費→current_hp=30のまま
## サイレントローブがon_attack_success無効化→ダウンしない
## 防AP20→att_hp=20
func test_shock_bringer_down_nullified_by_silent_robe():
	var config = _create_config(18, 414)
	config.defender_items = [1017]  # サイレントローブ(HP+40,on_attack_success無効)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 20, "攻HP40-20=20")
	assert_eq(r.defender_final_hp, 30, "防current_hp=30（land10から消費→current_hp無傷）")
	assert_eq(r.defender_tile_down, false, "サイレントローブでダウン無効化")


# ============================================================
# スルト (ID:19) - 火, R, AP60/HP60
# 先制；強化[水・風]；属性変化[火]（勝利時）
# ============================================================

## 強化[水]発動 + 属性変化: 水属性敵に勝利 → AP×1.5=90, タイルがfireに変化
## vs タイダルオーガ(水,AP40/HP50) on water, land_bonus=10
## 先制AP90→land10+cur50消費→def_hp=-30→撃破
## 勝利→属性変化[火]→タイルwater→fire
func test_surtr_power_strike_water_and_element_change():
	var config = _create_config(19, 138, "water")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 90, "強化[水]発動→AP60×1.5=90")
	assert_eq(r.defender_final_hp, -30, "防HP60(50+land10)-90=-30→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	assert_eq(r.land_effect_changed_element, "fire", "勝利時属性変化→fire")


## 強化不発（火属性敵）: 敵が火 → 強化条件不成立 → AP60のまま
## vs レッドオーガ(火,AP40/HP50) on fire, land_bonus=10
## 先制AP60→land10+cur50消費→def_hp=0→撃破
func test_surtr_no_power_strike_fire_enemy():
	var config = _create_config(19, 48, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "敵が火→強化不発→AP60")
	assert_eq(r.defender_final_hp, 0, "防HP60(50+land10)-60=0→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 敗北時は属性変化しない: スルト(攻撃側)が倒される → on_battle_won不発
## スルト(攻,AP60/HP60,先制) vs ドラゴンゾンビ(防,AP50/HP60) on neutral
## land_bonus=10 → def_hp=70
## 先制AP60→def_hp=70-60=10(生存)
## 防AP50→att_hp=60-50=10(生存) → 両者生存(attacker_survived)→属性変化なし
func test_surtr_no_element_change_when_survived():
	var config = _create_config(19, 425)
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_eq(r.land_effect_changed_element, "", "両者生存→属性変化なし")


# ============================================================
# ラクシャーサ (ID:26) - 火, S, AP50/HP40
# カード獲得[5枚まで]；強化[敵アイテム不使用時]
# ============================================================

## 強化発動（敵アイテムなし）: AP50×1.5=75
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP75→land10+cur30消費→def_hp=-35→撃破
func test_rakshasa_power_strike_enemy_no_item():
	var config = _create_config(26, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 75, "敵アイテムなし→強化発動→AP50×1.5=75")
	assert_eq(r.defender_final_hp, -35, "防HP40(30+land10)-75=-35→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 強化不発（敵アイテムあり）: AP50のまま
## vs ゴブリン(無,AP20/HP30)+ブリガンダイン(HP+40) on neutral, land_bonus=10
## AP50→land10+item40+cur30消費→def_hp=30(生存)
## 防AP20→att_hp=20
func test_rakshasa_no_power_strike_enemy_has_item():
	var config = _create_config(26, 414)
	config.defender_items = [1018]  # ブリガンダイン(HP+40)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 50, "敵アイテムあり→強化不発→AP50")
	assert_eq(r.defender_final_hp, 30, "防current_hp=30（land10+item40から消費→current_hp無傷）")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 強化アイテム併用: ラクシャーサ+ジャイアントキラー(AP+30,強化[敵MHP≧40])
## 敵アイテムなし → 両方の強化条件成立だが×1.5は1回のみ
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP50+30=80→強化×1.5=120
func test_rakshasa_with_power_strike_item_no_double():
	var config = _create_config(26, 414)
	config.attacker_items = [1060]  # ジャイアントキラー(武器,AP+30,強化[敵MHP≧40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 120, "AP80→強化×1.5=120（2重にならない）")
	assert_eq(r.defender_final_hp, -80, "防HP40(30+land10)-120=-80→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## カード獲得: 手札3枚で生存 → draw_until(5) → 手札5枚
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP75(強化)→撃破。生存→カード獲得発動→2枚ドロー
func test_rakshasa_card_draw_on_survive():
	var config = _create_config(26, 414)
	config.attacker_initial_hand_size = 3  # 手札を3枚に制限
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker", "攻撃側勝利→生存")
	assert_eq(r.attacker_hand_count, 5, "カード獲得→手札3→5枚")


# ============================================================
# インフェルノタイタン (ID:30) - 火, S, AP60/HP60
# 自ドミニオ5つ以上でAP&HP-30
# 防具・巻物使用不可
# ============================================================

## 自ドミニオ5つ → AP60-30=30（current_apに直接反映）
## HP-30はtemporary_bonus_hpに-30で記録（current_hpは60のまま、MHP計算に影響）
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP30→land10+cur30消費→def_hp=10(生存)
## 防AP20→att_hp=60-20=40（HP-30はcurrent_hpには直接影響しない）
func test_inferno_titan_debuff_with_5_lands():
	var config = _create_config(30, 414)
	# 攻撃側に5タイル配置（ドミニオ5つ）
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 3, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 4, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 16, "owner_id": 0, "creature_id": 213})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "自ドミニオ5→AP60-30=30")
	assert_eq(r.defender_final_hp, 10, "防HP40(30+land10)-30=10")
	assert_eq(r.attacker_final_hp, 40, "攻current_hp60-AP20=40")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# ============================================================
# ハイヴソルジャー (ID:32) - 火, N, AP20/HP20
# AP&HP+ハイヴソルジャー配置数×10（自身含む）
# ============================================================

## 味方ハイヴソルジャー4体配置（自分含む） → 侵略中なので自分除外=3体分
## AP20+3×10=50, HP temporary_bonus+30
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP50→land10+cur30消費→def_hp=-10→撃破
func test_hive_soldier_specific_creature_count():
	var config = _create_config(32, 414)
	# 自分自身のタイル（侵略元）+ 味方3体 = 計4体配置、自分除外で3体カウント
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 32})  # 自分
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 32})
	config.board_layout.append({"tile_index": 3, "owner_id": 0, "creature_id": 32})
	config.board_layout.append({"tile_index": 4, "owner_id": 0, "creature_id": 32})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 50, "AP20+3体×10=50（自分除外）")
	assert_eq(r.defender_final_hp, -10, "防HP40(30+land10)-50=-10→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ============================================================
# ファフニール (ID:37) - 火, N, AP30/HP40
# AP+火配置数×5
# ============================================================

## 火タイル3つ所有 → AP30+3×5=45
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP45→land10+cur30消費→def_hp=-5→撃破
func test_fafnir_fire_land_count_ap():
	var config = _create_config(37, 414)
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 2, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 3, "owner_id": 0, "creature_id": 48})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 45, "AP30+火3×5=45")
	assert_eq(r.defender_final_hp, -5, "防HP40(30+land10)-45=-5→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ============================================================
# ローンウルフ (ID:49) - 火, S, AP20/HP40
# HP+基本AP；隣が自ドミニオなら強化
# ============================================================

## 隣接自ドミニオあり → 強化発動 AP20×1.5=30 + HP+基礎AP(temporary_bonus_hp+20)
## battle_tile=5(neutral), tile4にowner_id=0を配置 → 隣接判定true
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP30→land10+cur30消費→def_hp=10(生存)
## 防AP20→temporary_bonus_hp(20)で吸収→att_current_hp=40
func test_lone_wolf_power_strike_with_adjacent_ally():
	var config = _create_config(49, 414)
	# 隣接タイル(tile4)に自ドミニオ配置
	config.board_layout.append({"tile_index": 4, "owner_id": 0, "creature_id": 48})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "隣接自ドミニオ→強化発動→AP20×1.5=30")
	assert_eq(r.defender_final_hp, 10, "防HP40(30+land10)-30=10")
	assert_eq(r.attacker_final_hp, 40, "攻HP40→AP20はtemp_bonus_hp(20)で吸収→current_hp無傷")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 隣接自ドミニオなし → 強化不発 AP20のまま
## battle_tile=5, 隣接(4,6)にowner_id=0なし → 不発
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP20→land10+cur30消費→def_hp=20(生存)
func test_lone_wolf_no_power_strike_without_adjacent():
	var config = _create_config(49, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 20, "隣接自ドミニオなし→強化不発→AP20")
	assert_eq(r.defender_final_hp, 20, "防HP40(30+land10)-20=20")


# ============================================================
# アビスキーパー (ID:106) - 水, S, AP20/HP40
# 戦闘地レベル3以上で無効化[通常攻撃]
# 武器・アクセサリ使用不可
# ============================================================

## レベル3以上 → 無効化発動: 敵の通常攻撃ダメージ0
## レッドオーガ(火,AP40/HP50) vs アビスキーパー(防) on water Lv3
## land_bonus=30, 無効化→攻撃ダメージ0
## アビスキーパーAP20→att_hp=50-20=30
func test_abyss_keeper_nullify_at_level3():
	var config = _create_config(48, 106, "water")
	config.defender_battle_land_level = 3
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 40, "無効化[通常攻撃]→ダメージ0→HP40無傷")
	assert_eq(r.attacker_final_hp, 30, "攻HP50-AP20=30")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## レベル2以下 → 無効化不発: 通常通りダメージ
## レッドオーガ(火,AP40/HP50) vs アビスキーパー(防) on water Lv2
## land_bonus=20, 無効化条件不成立
## AP40→land20+cur40消費→def_hp=20(生存)
func test_abyss_keeper_no_nullify_at_level2():
	var config = _create_config(48, 106, "water")
	config.defender_battle_land_level = 2
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 20, "防HP60(40+land20)-40=20→無効化不発")


# ============================================================
# ゴールドレイダー (ID:107) - 水, N, AP40/HP40
# アイテム不使用時、吸魔[周回数×30EP]
# ============================================================

## アイテムなしで生存 → 吸魔発動（周回数1×30=30EP）
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP40→land10+cur30消費→def_hp=0→撃破
## 吸魔30EP発動
func test_gold_raider_magic_steal_no_item():
	var config = _create_config(107, 414)
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	var effects_str = ",".join(r.attacker_battle_effects)
	assert_true("吸魔" in effects_str, "吸魔が発動: effects=%s" % effects_str)


## アイテムありで生存 → 吸魔不発
## vs ゴブリン(無,AP20/HP30)+ブリガンダイン(HP+40) on neutral
## 攻撃側にもアイテムを持たせる
func test_gold_raider_no_steal_with_item():
	var config = _create_config(107, 414)
	config.attacker_items = [1003]  # ウィンドエッジ(AP+20)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 70, "AP40+30=70")
	var effects_str2 = ",".join(r.attacker_battle_effects)
	assert_false("吸魔" in effects_str2, "アイテム使用→吸魔不発: effects=%s" % effects_str2)


# ============================================================
# テリトリースピリット (ID:109) - 水, S, AP30/HP30
# HP=水自ドミニオ数×20；無効化[水]
# ============================================================

## 防御側テリトリースピリット: 水ドミニオ3つ所有 → HP=3×20=60(set)
## 攻撃側タイダルオーガ(138,水,AP40/HP50) → 無効化[水]でダメージ0
## 防御側AP30 → 攻撃側HP50-30=20 → 両者生存(attacker_survived)
func test_territory_spirit_hp_set_and_nullify_water():
	var config = _create_config(138, 109, "water")
	# 防御側が水タイル3つ所有（battle_tile含む）
	config.board_layout = [
		{"tile_index": 6, "owner_id": 1, "creature_id": 109},  # battle_tile
		{"tile_index": 7, "owner_id": 1, "creature_id": 48},
		{"tile_index": 8, "owner_id": 1, "creature_id": 48},
	]
	config.defender_owned_lands = {"fire": 0, "water": 3, "earth": 0, "wind": 0}
	var r = await _execute_battle(config)
	# base_hp=30（元データ維持）, current_hp=60（set操作後）
	assert_eq(r.defender_base_hp, 30, "base_hpは元データ30を維持")
	# 無効化[水]でダメージ0 → current_hp=60維持（land_bonusは別管理）
	assert_eq(r.defender_final_hp, 60, "HP=水3×20=60(set), 無効化でダメージ0")
	assert_eq(r.attacker_final_hp, 20, "攻HP50-30=20")
	assert_eq(r.winner, "attacker_survived", "両者生存→侵略失敗")


## 火属性(レッドオーガ)で攻撃 → 無効化[水]不発、ダメージ貫通
## AP40 → land_bonus10+cur_hp30消費 → def_final_hp=30
## 防御側AP30 → 攻撃側HP40-30=10 → 両者生存
func test_territory_spirit_no_nullify_vs_fire():
	var config = _create_config(48, 109, "water")
	config.board_layout = [
		{"tile_index": 6, "owner_id": 1, "creature_id": 109},
		{"tile_index": 7, "owner_id": 1, "creature_id": 48},
		{"tile_index": 8, "owner_id": 1, "creature_id": 48},
	]
	config.defender_owned_lands = {"fire": 0, "water": 3, "earth": 0, "wind": 0}
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 30, "HP60(set)-land10-cur30=残30, 無効化不発")
	assert_eq(r.attacker_final_hp, 20, "攻HP50-30=20")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# ============================================================
# ウェーブウォーカー (ID:110) - 水, R, AP40/HP30
# 戦闘地が水風の場合、AP+20；堅牢
# ============================================================

## 防御側ウェーブウォーカー on 水タイル → AP+20発動(60)
## vs ゴブリン(414,無,AP20/HP30) → 防御側勝利
func test_wave_walker_ap_bonus_on_water():
	var config = _create_config(414, 110, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 60, "AP40+20=60（水タイルで条件成立）")
	assert_eq(r.attacker_final_hp, -30, "攻HP30-60=-30→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")

## 防御側ウェーブウォーカー on 火タイル → AP+20不発(40)
## vs ゴブリン(414,無,AP20/HP30)
func test_wave_walker_no_bonus_on_fire():
	var config = _create_config(414, 110, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 40, "AP40（火タイルで条件不成立）")
	assert_eq(r.attacker_final_hp, -10, "攻HP30-40=-10→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


# ============================================================
# コーラルプリンセス (ID:114) - 水, S, AP40/HP40
# 鼓舞[防御側・HP+10]；戦闘後、敵に刻印[崩壊]
# ============================================================

## 鼓舞テスト: ボード上のコーラルプリンセスが防御側クリーチャーにHP+10
## 攻撃側ゴブリン(414,AP20/HP30) vs 防御側レッドオーガ(48,AP40/HP50) on neutral
## 鼓舞HP+10 → temporary_bonus=10、ダメージ20でland10+temp10消費→def_hp=50
func test_coral_princess_support_defender_hp():
	var config = _create_config(414, 48)
	# コーラルプリンセスをボード上に配置（防御側プレイヤーのタイル）
	config.board_layout.append({"tile_index": 7, "owner_id": 1, "creature_id": 114})
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 50, "鼓舞HP+10で吸収→HP50維持")
	assert_eq(r.attacker_final_hp, -10, "攻HP30-40=-10→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")

## 崩壊テスト: コーラルプリンセスが防御側で戦闘、両者生存→敵に崩壊刻印
## 攻撃側レッドオーガ(48,AP40/HP50) vs 防御側コーラルプリンセス(114,AP40/HP40)
## land10→AP40でland10+cur30消費→def_hp=10、def_AP40→att_hp=10→両者生存
func test_coral_princess_destroy_curse_on_survive():
	var config = _create_config(48, 114)
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_eq(r.attacker_curse.get("curse_type", ""), "destroy_after_battle", "攻撃側に崩壊刻印付与")

## 世界刻印[吊人]発動中 → 崩壊付与が無効化される
func test_coral_princess_destroy_blocked_by_hanged_man():
	var config = _create_config(48, 114)
	config.world_curse = {
		"curse_type": "skill_disable",
		"name": "吊人",
		"params": {"disabled_triggers": ["mystic_arts", "on_death", "on_battle_end"]}
	}
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_eq(r.attacker_curse.get("curse_type", ""), "", "吊人により崩壊刻印が付与されない")

# ===========================================================================
# デッドリージェル (118): 防御側なら即死[全・80%]；自破壊時、100EPを失う
# ===========================================================================

# ===========================================================================
# タラスク (122): 共鳴[風・HP+30]；無効化[AP40以下]
# ===========================================================================

## 風土地2つ所有で共鳴HP+30（重複しない）、攻撃側AP40以下を無効化して生存
func test_tarasque_resonance_and_nullify():
	# レッドオーガAP40 vs タラスクHP30 on 風土地、防御側が風土地2つ所有
	var config = BattleTestConfig.new()
	config.attacker_creatures = [48]
	config.defender_creatures = [122]
	config.battle_tile_index = 11  # 風タイル
	config.board_layout = [
		{"tile_index": 11, "owner_id": 1, "creature_id": 122},
		{"tile_index": 12, "owner_id": 1, "creature_id": 0, "level": 1},  # 風土地2つ目
	]
	var r = await _execute_battle(config)
	# 無効化でAP40以下ダメージ0 → current_hp=30のまま
	# 共鳴HP+30はresonance_bonus_hpに入る（current_hpには含まれない）
	# 両者生存（タラスクAP40でレッドオーガHP50→残10）
	assert_eq(r.defender_final_hp, 30, "無効化でダメージ0、current_hp=30: defender_hp=%d" % r.defender_final_hp)
	assert_eq(r.winner, "attacker_survived", "両者生存")

# ===========================================================================
# ヴォイドスケルトン (123): 堅守；戦闘中能力無効
# ===========================================================================

## 敵クリーチャーの共鳴スキルを無効化する
func test_void_skeleton_nullify_enemy_resonance():
	# タラスク(共鳴[風・HP+30]) vs ヴォイドスケルトン(沈黙)
	var config = BattleTestConfig.new()
	config.attacker_creatures = [122]  # タラスク AP40/HP30
	config.defender_creatures = [123]  # ヴォイドスケルトン AP10/HP40
	config.battle_tile_index = 11  # 風タイル
	config.board_layout = [
		{"tile_index": 11, "owner_id": 1, "creature_id": 123},
		{"tile_index": 12, "owner_id": 0, "creature_id": 0, "level": 1},  # 攻撃側の風土地
	]
	var r = await _execute_battle(config)
	# 沈黙で共鳴無効 → タラスクAP40/HP30のまま
	# ヴォイドスケルトンHP40+land10 - AP40 = land10消費+current30消費 → current_hp=10
	# タラスクHP30 - AP10 = 20 → 生存
	assert_eq(r.attacker_final_hp, 20, "タラスクHP30-AP10=20: hp=%d" % r.attacker_final_hp)
	assert_eq(r.winner, "attacker_survived", "両者生存（共鳴無効で互いに生存）")

## 敵クリーチャーの強化スキルを無効化する
func test_void_skeleton_nullify_enemy_power_up():
	# ラクシャーサ(強化) vs ヴォイドスケルトン(沈黙)
	var config = _create_config(26, 123)  # ラクシャーサAP50 vs ヴォイドスケルトンHP40+land10
	var r = await _execute_battle(config)
	# 沈黙で強化無効 → ラクシャーサAP50のまま（強化ならAP75）
	# ヴォイドスケルトンHP40+land10 - AP50 = 0 → 撃破
	# 防御側先に撃破 → 反撃なし → ラクシャーサHP40のまま
	assert_eq(r.attacker_final_hp, 40, "反撃なしHP40のまま: hp=%d" % r.attacker_final_hp)
	assert_eq(r.winner, "attacker", "攻撃側勝利（強化無効で防御側撃破）")

## 敵アイテムのスキル効果を無効化する（stat_bonusは残る）
func test_void_skeleton_nullify_enemy_item_skill():
	# レッドオーガ+クイックチャーム(先制+AP10) vs ヴォイドスケルトン
	var config = _create_config(48, 123)  # レッドオーガAP40 vs ヴォイドスケルトンHP40+land10
	config.attacker_items = [1000]  # クイックチャーム: 先制+AP10
	var r = await _execute_battle(config)
	# 沈黙で先制無効化、stat_bonus AP+10は残る → AP50
	# ヴォイドスケルトンHP40+land10 - AP50 = 0 → 撃破
	# 反撃なし → レッドオーガHP50のまま
	assert_eq(r.attacker_final_ap, 50, "stat_bonus AP+10は残る: final_ap=%d" % r.attacker_final_ap)
	assert_eq(r.winner, "attacker", "攻撃側勝利")

## ヴォイドスケルトン自身の能力も無効化される（相互沈黙）
func test_void_skeleton_self_ability_also_cleared():
	# ヴォイドスケルトン vs ヴォイドスケルトン → 両方沈黙
	var config = _create_config(123, 123)
	var r = await _execute_battle(config)
	# 攻撃側AP10 → 防御側HP40+land10: land10消費 → current_hp=40
	# 防御側AP10 → 攻撃側HP40: current_hp=30
	assert_eq(r.attacker_final_hp, 30, "HP40-AP10=30: hp=%d" % r.attacker_final_hp)
	assert_eq(r.defender_final_hp, 40, "land_bonus吸収でcurrent_hp=40: hp=%d" % r.defender_final_hp)
	assert_eq(r.winner, "attacker_survived", "両者生存")

## 敵の即死スキルを無効化する
func test_void_skeleton_nullify_instant_death():
	# デッドリージェル(即死[全・80%]) vs ヴォイドスケルトン(沈黙)
	# ヴォイドスケルトンが防御側 → デッドリージェルの「防御側なら即死」条件は不成立だが
	# ヴォイドスケルトンを攻撃側にしてデッドリージェルを防御側にする
	var config = _create_config(123, 118)  # ヴォイドスケルトンAP10 vs デッドリージェルHP50+land10
	var r = await _execute_battle(config)
	# 沈黙でデッドリージェルの即死無効 → 通常戦闘
	# ヴォイドスケルトンAP10 vs デッドリージェルHP50+land10: land10消費→HP50
	# デッドリージェルAP30 vs ヴォイドスケルトンHP40: HP10
	assert_eq(r.attacker_final_hp, 10, "HP40-AP30=10: hp=%d" % r.attacker_final_hp)
	assert_eq(r.winner, "attacker_survived", "即死無効で両者生存")

## 注: on_death EP損失の沈黙テストは省略
## ヴォイドスケルトンはアイテム全不可でデッドリージェルHP50を倒せないため
## コード上はability_parsed.effectsが空になり発動しないことを確認済み

## 敵アイテムの術攻撃を無効化する
func test_void_skeleton_nullify_scroll_attack():
	# レッドオーガ+フォースストライク(術攻撃[AP=基本AP]) vs ヴォイドスケルトン
	var config = _create_config(48, 123)  # レッドオーガAP40 vs ヴォイドスケルトンHP40+land10
	config.attacker_items = [1007]  # フォースストライク: 術攻撃
	var r = await _execute_battle(config)
	# 沈黙で術攻撃無効 → 通常攻撃AP40: land10+current30消費 → current_hp=10
	# 反撃AP10 → current_hp=40
	assert_eq(r.defender_final_hp, 10, "術攻撃無効、通常AP40: hp=%d" % r.defender_final_hp)
	assert_eq(r.winner, "attacker_survived", "両者生存")

## 敵アイテムの反射を無効化する
func test_void_skeleton_nullify_item_reflect():
	# レッドオーガ+デモンマスク(反射+HP30) vs ヴォイドスケルトン
	var config = _create_config(48, 123)  # レッドオーガAP40 vs ヴォイドスケルトンHP40+land10
	config.attacker_items = [1002]  # デモンマスク: 反射+HP30
	var r = await _execute_battle(config)
	# 沈黙で反射無効、stat_bonus HP+30は残る（item_bonus_hp=30）
	# ヴォイドスケルトンAP10 → item_bonus30から消費 → current_hp=50
	# レッドオーガAP40 → ヴォイドスケルトンHP40+land10: land10+current30消費 → current_hp=10
	assert_eq(r.attacker_final_hp, 50, "反射無効、item_hpから消費: hp=%d" % r.attacker_final_hp)
	assert_eq(r.winner, "attacker_survived", "両者生存")

# ===========================================================================
# カリュブディス (125): 戦闘開始時HP減少中なら自滅；再生
# ===========================================================================

# ===========================================================================
# マナアブソーバー (127): 堅守；蓄魔[受けたダメージ×5EP]
# ===========================================================================

## 倒されずに蓄魔が発動する
func test_mana_absorber_survive_magic_gain():
	# レッドオーガAP40 vs マナアブソーバーHP50+land10
	var config = _create_config(48, 127)
	var r = await _execute_battle(config)
	# AP40ダメージ: land10+current30消費 → current_hp=20 → 生存
	# 蓄魔: 40×5=200EP
	# マナアブソーバーAP10でレッドオーガHP50→40
	assert_eq(r.defender_final_hp, 20, "HP50+land10-AP40=20: hp=%d" % r.defender_final_hp)
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_true(r.defender_battle_effects.has("蓄魔[200EP]"), "蓄魔200EP: %s" % str(r.defender_battle_effects))

## 倒された場合は蓄魔が発動しない
func test_mana_absorber_defeated_no_magic_gain():
	# ラクシャーサAP50(強化75) vs マナアブソーバーHP50+land10
	var config = _create_config(26, 127)
	var r = await _execute_battle(config)
	# AP75で撃破 → 蓄魔は発動しない
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	assert_true(r.defender_battle_effects.is_empty(), "撃破時は蓄魔なし: %s" % str(r.defender_battle_effects))

# ===========================================================================
# シーソルジャー (130): 強化術；アイテム使用の戦闘後カード獲得
# ===========================================================================

## 巻物使用時に強化術（AP=基本AP）で攻撃、土地ボーナス無効化
func test_sea_soldier_scroll_power_strike():
	# シーソルジャーAP30+フォースストライク vs レッドオーガHP50 on neutral土地
	var config = _create_config(130, 48)  # シーソルジャー攻撃側
	config.attacker_items = [1007]  # フォースストライク: 術攻撃→強化術に
	var r = await _execute_battle(config)
	# 強化術でAP=基本AP30、土地ボーナス無効化
	# レッドオーガHP50+land10 → 土地ボーナス無効 → HP50-AP30=20
	# レッドオーガAP40 → シーソルジャーHP40: HP0 → 撃破
	assert_eq(r.attacker_final_ap, 30, "強化術でAP=基本AP30: ap=%d" % r.attacker_final_ap)
	assert_eq(r.winner, "defender", "防御側勝利")

# ===========================================================================
# シーサーペント (131): 水で戦闘中、HP+ドミニオレベル×10
# ===========================================================================

## 水土地レベル3でHP+30ボーナス
func test_sea_serpent_water_land_level_bonus():
	# レッドオーガAP40 vs シーサーペントHP40 on 水土地Lv3
	var config = _create_config(48, 131, "water")
	config.defender_battle_land_level = 3
	var r = await _execute_battle(config)
	# 水土地Lv3: HP+30 → HP40+land30+bonus30=100相当
	# AP40ダメージ: land30消費+bonus10消費 → current_hp=40
	# シーサーペントAP20 → レッドオーガHP50: HP30
	assert_eq(r.defender_final_hp, 40, "水土地Lv3 HP+30でHP維持: hp=%d" % r.defender_final_hp)
	assert_eq(r.winner, "attacker_survived", "両者生存")

## 火土地ではHP+ボーナスなし
func test_sea_serpent_no_bonus_on_fire():
	# レッドオーガAP40 vs シーサーペントHP40 on 火土地
	var config = _create_config(48, 131, "fire")
	var r = await _execute_battle(config)
	# 火土地: レベルボーナスなし + 属性不一致でland_bonus=0 → HP40のみ
	# AP40ダメージ → HP0 → 撃破
	assert_eq(r.defender_final_hp, 0, "火土地でボーナスなし撃破: hp=%d" % r.defender_final_hp)
	assert_eq(r.winner, "attacker", "攻撃側勝利")

# ===========================================================================
# カリュブディス (125): 戦闘開始時HP減少中なら自滅；再生
# ===========================================================================

## HPフルで自滅せず、再生で回復して生存
func test_charybdis_full_hp_no_self_destruct():
	# レッドオーガAP40 vs カリュブディスHP60+land10
	var config = _create_config(48, 125)
	var r = await _execute_battle(config)
	# 自滅なし → 通常戦闘
	# レッドオーガAP40 → カリュブディスHP60+land10: land10+current30消費 → current_hp=30
	# 再生でHP回復 → current_hp=60
	# カリュブディスAP50 → レッドオーガHP50: current_hp=0 → 撃破
	assert_eq(r.winner, "defender", "防御側勝利")

## HP減少中なら戦闘開始時に自滅する
func test_charybdis_damaged_hp_self_destruct():
	# レッドオーガAP40 vs カリュブディスHP60（current_hp=50で減少状態）
	var config = _create_config(48, 125)
	config.defender_buff_config["current_hp"] = 50  # HPが減少している状態
	var r = await _execute_battle(config)
	# 戦闘開始時にHP減少→自滅 → 攻撃側勝利
	assert_eq(r.winner, "attacker", "HP減少中のため自滅→攻撃側勝利")

# ===========================================================================
# デッドリージェル (118): 自破壊時、100EPを失う
# ===========================================================================

## 破壊時に所有者が100EP失う
func test_deadly_jelly_ep_loss_on_death():
	# デッドリージェル(118)を防御側に置き、攻撃側AP50で倒す
	var config = _create_config(26, 118)  # ラクシャーサAP50 vs デッドリージェルHP50
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	assert_true(r.defender_battle_effects.has("EP損失[100EP]"), "防御側100EP損失: %s" % str(r.defender_battle_effects))
