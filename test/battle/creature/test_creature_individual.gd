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


# ===========================================================================
# シンダーハンター (42): 火, N, AP30/HP30
# 強化[敵MHP40以下]
# ===========================================================================

## 強化発動: 敵MHP30(<=40) → AP30×1.5=45
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP45→land10+cur30消費→def_hp=-5→撃破
func test_cinder_hunter_power_strike_mhp_below():
	var config = _create_config(42, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 45, "敵MHP30<=40→強化発動→AP30×1.5=45")
	assert_eq(r.defender_final_hp, -5, "防HP40(30+land10)-45=-5→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 強化不発: 敵MHP50(>40) → AP30のまま
## vs ドラゴンゾンビ(無,AP50/HP60) on neutral, land_bonus=10
## AP30→land10+cur60消費→def_hp=40(生存)
## 防AP50→att_hp=30-50=-20→撃破
func test_cinder_hunter_no_power_strike_mhp_above():
	var config = _create_config(42, 425)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "敵MHP60>40→強化不発→AP30")
	assert_eq(r.defender_final_hp, 40, "防HP70(60+land10)-30=40")
	assert_eq(r.winner, "defender", "防御側勝利")


## 強化アイテム併用: シンダーハンター+ジャイアントキラー(AP+30,強化[MHP>=40])
## 敵MHP30→シンダーハンター強化発動、ジャイアントキラー強化不発(MHP30<40)
## AP30+30=60→×1.5=90
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
func test_cinder_hunter_with_power_strike_item():
	var config = _create_config(42, 414)
	config.attacker_items = [1060]  # ジャイアントキラー(AP+30,強化[MHP>=40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 90, "AP60→強化×1.5=90")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 巻物アイテム併用: シンダーハンター+ライトニングオーブ(術攻撃[AP40])
## 術攻撃AP40固定（強化のAP上昇は巻物でリセット）
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
func test_cinder_hunter_with_scroll_item():
	var config = _create_config(42, 414)
	config.attacker_items = [1024]  # ライトニングオーブ(術攻撃[AP40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "巻物AP40固定（強化リセット）")
	assert_eq(r.attacker_is_using_scroll, true, "術攻撃フラグON")


# ===========================================================================
# シールブレイカー (235): 地, R, AP40/HP40
# 強化[敵AP<=30]
# ===========================================================================

## 強化発動: 敵AP20(<=30) → AP40×1.5=60
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP60→land10+cur30消費→def_hp=-20→撃破
func test_shield_breaker_power_strike_enemy_low_ap():
	var config = _create_config(235, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "敵AP20<=30→強化発動→AP40×1.5=60")
	assert_eq(r.defender_final_hp, -20, "防HP40(30+land10)-60=-20→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 強化不発: 敵AP50(>30) → AP40のまま
## vs ドラゴンゾンビ(無,AP50/HP60) on neutral, land_bonus=10
## 攻HP40-50=-10→撃破、防HP70(60+land10)-40=30
func test_shield_breaker_no_power_strike_enemy_high_ap():
	var config = _create_config(235, 425)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "敵AP50>30→強化不発→AP40")
	assert_eq(r.defender_final_hp, 30, "防HP70(60+land10)-40=30")
	assert_eq(r.winner, "defender", "防御側勝利")


## 強化アイテム併用: シールブレイカー+ジャイアントキラー(AP+30,強化[MHP>=40])
## 敵ゴブリンMHP30<40→ジャイアントキラー強化不発、シールブレイカー強化発動
## AP40+30=70→×1.5=105
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
func test_shield_breaker_with_power_strike_item():
	var config = _create_config(235, 414)
	config.attacker_items = [1060]  # ジャイアントキラー(AP+30,強化[MHP>=40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 105, "AP70→強化×1.5=105")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 巻物アイテム併用: シールブレイカー+ライトニングオーブ(術攻撃[AP40])
## 術攻撃AP40固定（強化リセット）
func test_shield_breaker_with_scroll_item():
	var config = _create_config(235, 414)
	config.attacker_items = [1024]  # ライトニングオーブ(術攻撃[AP40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "巻物AP40固定（強化リセット）")
	assert_eq(r.attacker_is_using_scroll, true, "術攻撃フラグON")


# ===========================================================================
# ナイト (333): 風, R, AP50/HP40
# 強化[敵MHP>=50]
# ===========================================================================

## 強化発動: 敵MHP50(>=50) → AP50×1.5=75
## vs レッドオーガ(火,AP40/HP50) on fire, land_bonus=10
## AP75→land10+cur50消費→def_hp=-15→撃破
func test_knight_power_strike_enemy_high_mhp():
	var config = _create_config(333, 48, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 75, "敵MHP50>=50→強化発動→AP50×1.5=75")
	assert_eq(r.defender_final_hp, -15, "防HP60(50+land10)-75=-15→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 強化不発: 敵MHP30(<50) → AP50のまま
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP50→land10+cur30消費→def_hp=-10→撃破
func test_knight_no_power_strike_enemy_low_mhp():
	var config = _create_config(333, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 50, "敵MHP30<50→強化不発→AP50")
	assert_eq(r.defender_final_hp, -10, "防HP40(30+land10)-50=-10→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 強化アイテム併用: ナイト+ジャイアントキラー(AP+30,強化[MHP>=40])
## 敵MHP50>=40→両方の強化条件成立だが×1.5は1回のみ
## AP50+30=80→×1.5=120
## vs レッドオーガ(火,AP40/HP50) on fire, land_bonus=10
func test_knight_with_power_strike_item():
	var config = _create_config(333, 48, "fire")
	config.attacker_items = [1060]  # ジャイアントキラー(AP+30,強化[MHP>=40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 120, "AP80→強化×1.5=120（2重にならない）")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 巻物アイテム併用: ナイト+ライトニングオーブ(術攻撃[AP40])
## 術攻撃AP40固定（強化リセット）
func test_knight_with_scroll_item():
	var config = _create_config(333, 48, "fire")
	config.attacker_items = [1024]  # ライトニングオーブ(術攻撃[AP40])
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "巻物AP40固定（強化リセット）")
	assert_eq(r.attacker_is_using_scroll, true, "術攻撃フラグON")


# ===========================================================================
# サラマンダー (46): 火, R, AP40/HP50
# 共鳴[地・AP+20/HP+10] + 強化[敵属性:火,地]
# 巻物使用不可
# ===========================================================================

## 共鳴+強化同時発動: 地土地2つ所有で共鳴、敵が地属性で強化
## 共鳴AP+20 → AP60, 強化×1.5 → AP90
## vs ロックウォッチャー(地,AP30/HP50) on earth, land_bonus=10
## AP90 → 防HP60(50+land10)-90=-30→撃破
func test_salamander_resonance_and_power_strike():
	var config = BattleTestConfig.new()
	config.attacker_creatures = [46]
	config.defender_creatures = [204]
	config.battle_tile_index = 16  # 地タイル
	config.board_layout = [
		{"tile_index": 16, "owner_id": 1, "creature_id": 204},
		{"tile_index": 17, "owner_id": 0, "creature_id": 48},  # 攻撃側地タイル1
		{"tile_index": 18, "owner_id": 0, "creature_id": 48},  # 攻撃側地タイル2
	]
	config.attacker_battle_land = "earth"
	config.defender_battle_land = "earth"
	config.attacker_battle_land_level = 1
	config.defender_battle_land_level = 1
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 90, "共鳴AP+20→60→強化×1.5=90")
	assert_eq(r.defender_final_hp, -30, "防HP60(50+land10)-90=-30→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 共鳴のみ発動: 地土地所有で共鳴、敵が水属性で強化不発
## 共鳴AP+20/HP+10 → AP60/HP60, 強化不発
## vs プレッシャーリング(水,AP20/HP30) on water, land_bonus=10
func test_salamander_resonance_only_no_power_strike():
	var config = BattleTestConfig.new()
	config.attacker_creatures = [46]
	config.defender_creatures = [105]
	config.battle_tile_index = 6  # 水タイル
	config.board_layout = [
		{"tile_index": 6, "owner_id": 1, "creature_id": 105},
		{"tile_index": 16, "owner_id": 0, "creature_id": 48},  # 攻撃側地タイル1
		{"tile_index": 17, "owner_id": 0, "creature_id": 48},  # 攻撃側地タイル2
	]
	config.attacker_battle_land = "water"
	config.defender_battle_land = "water"
	config.attacker_battle_land_level = 1
	config.defender_battle_land_level = 1
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "共鳴AP+20→60、敵水→強化不発")
	assert_eq(r.defender_final_hp, -20, "防HP40(30+land10)-60=-20→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 強化アイテム併用: サラマンダー+ジャイアントキラー(AP+30,強化[MHP>=40])
## 敵MHP50>=40→ジャイアントキラー強化も成立、AP40+20(共鳴)+30=90→×1.5=135
## vs ロックウォッチャー(地,AP30/HP50) on earth, land_bonus=10
func test_salamander_with_power_strike_item():
	var config = BattleTestConfig.new()
	config.attacker_creatures = [46]
	config.defender_creatures = [204]
	config.attacker_items = [1060]  # ジャイアントキラー(AP+30,強化[MHP>=40])
	config.battle_tile_index = 16
	config.board_layout = [
		{"tile_index": 16, "owner_id": 1, "creature_id": 204},
		{"tile_index": 17, "owner_id": 0, "creature_id": 48},
		{"tile_index": 18, "owner_id": 0, "creature_id": 48},
	]
	config.attacker_battle_land = "earth"
	config.defender_battle_land = "earth"
	config.attacker_battle_land_level = 1
	config.defender_battle_land_level = 1
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 135, "AP40+20(共鳴)+30(item)=90→×1.5=135")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ===========================================================================
# ニーベルングブレイド (16): 火, S, AP40/HP40
# 即死[敵AP>=50, 60%] + 無効化[MHP>=50]
# ===========================================================================

## 即死条件不成立: 敵AP20(<50) → 即死判定なし → 通常戦闘
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP40 → 防HP40(30+land10)-40=0→撃破
func test_nibelungblade_no_instant_death_low_ap():
	var config = _create_config(16, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "AP40維持")
	assert_eq(r.defender_final_hp, 0, "防HP40(30+land10)-40=0→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 無効化発動: 敵MHP50(>=50) → 攻撃無効
## レッドオーガ(火,AP40/MHP50) vs ニーベルングブレイド(防御側, fire, land=10)
## MHP50>=50 → 無効化 → ダメージ0
## 反撃AP40 → レッドオーガHP50-40=10
## ※current_hpはland_bonusを含まない
func test_nibelungblade_nullify_high_mhp():
	var config = _create_config(48, 16, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 40, "無効化→防HP40維持(land10は別管理)")
	assert_eq(r.attacker_final_hp, 10, "反撃AP40→攻HP50-40=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 無効化不発: 敵MHP30(<50) → 通常ダメージ
## ゴブリン(無,AP20/MHP30) vs ニーベルングブレイド(防御側, fire, land=10)
## MHP30<50 → 無効化不発 → AP20ダメージ
## HP50-20=30、反撃AP40→ゴブリンHP30-40=-10→撃破
func test_nibelungblade_no_nullify_low_mhp():
	var config = _create_config(414, 16, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 30, "MHP30<50→無効化不発→HP50-20=30")
	assert_eq(r.attacker_final_hp, -10, "反撃AP40→HP30-40=-10→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


# ===========================================================================
# フロストキラー (111): 水, S, AP40/HP40
# 即死[敵属性fire, 60%] + 無効化[属性fire]
# 巻物使用不可
# ===========================================================================

## 即死条件不成立: 敵が非火属性 → 即死判定なし → 通常戦闘
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP40 → 防HP40(30+land10)-40=0→撃破
func test_frost_killer_no_instant_death_non_fire():
	var config = _create_config(111, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "AP40維持")
	assert_eq(r.defender_final_hp, 0, "防HP40-40=0→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 無効化発動: 敵が火属性 → 攻撃無効
## レッドオーガ(火,AP40) vs フロストキラー(防御側, water, land=10)
## 火属性 → 無効化 → ダメージ0
## ※即死[fire,60%]が確率発動するため、攻撃側結果は可変
func test_frost_killer_nullify_fire_element():
	var config = _create_config(48, 111, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 40, "火属性無効化→防HP40維持(land10は別管理)")


## 無効化不発: 敵が非火属性 → 通常ダメージ
## ゴブリン(無,AP20) vs フロストキラー(防御側, water, land=10)
## 無属性 → 無効化不発 → AP20ダメージ
## HP50-20=30、反撃AP40→ゴブリンHP30-40=-10→撃破
func test_frost_killer_no_nullify_non_fire():
	var config = _create_config(414, 111, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 30, "無属性→無効化不発→HP50-20=30")
	assert_eq(r.attacker_final_hp, -10, "反撃AP40→HP30-40=-10→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


# ===========================================================================
# アヌビス (144): 水, R, AP60/HP60
# 無効化[AP>=50]
# アクセサリ使用不可, 地属性召喚不可
# ===========================================================================

## 無効化発動: 敵AP50(>=50) → 攻撃無効
## ドラゴンゾンビ(無,AP50) vs アヌビス(防御側, water, land=10)
## AP50>=50 → 無効化 → ダメージ0
## 反撃AP60 → ドラゴンゾンビHP60-60=0→撃破
## ※鼓舞[水風HP+10]あり、current_hpはland/tempボーナス含まず
func test_anubis_nullify_high_ap():
	var config = _create_config(425, 144, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 60, "無効化→防HP60維持(land10+鼓舞10は別管理)")
	assert_eq(r.attacker_final_hp, 0, "反撃AP60→HP60-60=0→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


## 無効化不発: 敵AP20(<50) → 通常ダメージ
## ゴブリン(無,AP20) vs アヌビス(防御側, water, land=10)
## AP20<50 → 無効化不発 → AP20ダメージ
## land10+鼓舞temp10で吸収→current_hp=60維持、反撃AP60→ゴブリン撃破
func test_anubis_no_nullify_low_ap():
	var config = _create_config(414, 144, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 60, "AP20→land10+鼓舞10で吸収→HP60維持")
	assert_eq(r.attacker_final_hp, -30, "反撃AP60→HP30-60=-30→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


# ===========================================================================
# ウンディーネ (100): 水, S, AP30/HP50
# 無効化[地,風属性]
# 巻物使用不可
# ===========================================================================

## 無効化発動: 敵が地属性 → 攻撃無効
## ロックウォッチャー(地,AP30) vs ウンディーネ(防御側, water, land=10)
## 地属性 → 無効化 → ダメージ0
## 反撃AP30 → ロックウォッチャーHP50-30=20
func test_undine_nullify_earth_element():
	var config = _create_config(204, 100, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 50, "地属性無効化→防HP50維持(land10は別管理)")
	assert_eq(r.attacker_final_hp, 20, "反撃AP30→攻HP50-30=20")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 無効化不発: 敵が火属性 → 通常ダメージ
## レッドオーガ(火,AP40) vs ウンディーネ(防御側, water, land=10)
## 火属性 → 無効化不発 → AP40ダメージ
## HP60-40=20、反撃AP30→レッドオーガHP50-30=20
func test_undine_no_nullify_fire_element():
	var config = _create_config(48, 100, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 20, "火属性→無効化不発→HP60-40=20")
	assert_eq(r.attacker_final_hp, 20, "反撃AP30→HP50-30=20")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# ===========================================================================
# ネプチューンガード (103): 水, R, AP50/HP50
# 無効化[通常攻撃・防具使用時] + 加勢[water] + 堅牢
# ===========================================================================

## 防具使用時、通常攻撃無効化
## ゴブリン(無,AP20) vs ネプチューンガード(防御側, water, land=10) + フルプレート(防具,HP+50)
## 防具使用中 → 通常攻撃無効化 → ダメージ0
## 反撃AP50 → ゴブリンHP30-50=-20→撃破
## ※current_hpはland/itemボーナスを含まない
func test_neptune_guard_nullify_with_armor():
	var config = _create_config(414, 103, "water")
	config.defender_items = [1058]  # フルプレート(HP+50, 防具)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 50, "無効化→防HP50維持(land10+item50は別管理)")
	assert_eq(r.attacker_final_hp, -20, "反撃AP50→HP30-50=-20→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


## 防具なし → 通常ダメージ
## ゴブリン(無,AP20) vs ネプチューンガード(防御側, water, land=10)
## 防具なし → 無効化不発 → AP20ダメージ
## HP60-20=40、反撃AP50→ゴブリンHP30-50=-20→撃破
func test_neptune_guard_no_nullify_without_armor():
	var config = _create_config(414, 103, "water")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 40, "防具なし→無効化不発→HP60-20=40")
	assert_eq(r.attacker_final_hp, -20, "反撃AP50→HP30-50=-20→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


# ===========================================================================
# ドラゴニュート (307): 風, S, AP0/HP40
# AP&HP=[風]配置数×10 (set)
# 地属性召喚不可
# ===========================================================================

## 風3つ配置: AP&HP=30
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP30 → 防HP40(30+land10)-30=10、ゴブリンAP20→HP30-20=10
func test_dragonnewt_wind_count_3():
	var config = _create_config(307, 414)
	config.board_layout.append({"tile_index": 11, "owner_id": 0, "creature_id": 48})  # 風タイル1
	config.board_layout.append({"tile_index": 12, "owner_id": 0, "creature_id": 48})  # 風タイル2
	config.board_layout.append({"tile_index": 13, "owner_id": 0, "creature_id": 48})  # 風タイル3
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "風3×10=AP30(set)")
	assert_eq(r.attacker_final_hp, 10, "HP30(set)-20=10")
	assert_eq(r.defender_final_hp, 10, "防HP40-30=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 風0配置: AP&HP=0 → HP0で戦闘開始前に死亡
## vs ゴブリン(無,AP20/HP30) on neutral
## HP0→is_alive()=false→攻撃不可→ゴブリン無傷
func test_dragonnewt_wind_count_0():
	var config = _create_config(307, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 0, "風0×10=AP0(set)")
	assert_eq(r.attacker_final_hp, 0, "HP0(set)→戦闘開始前に死亡")
	assert_eq(r.defender_final_hp, 30, "防HP30維持(land10は別管理)")
	assert_eq(r.winner, "defender", "防御側勝利")


## 強化アイテム併用: 風3配置(AP30 set) + ガーディアンブレイド(AP+30/HP+30)
## setがアイテム後に適用 → current_ap=30(setで上書き)、item_bonus_hp=30は別プール
## vs ゴブリン(無,AP20/HP30) on neutral
## AP30 → land10+HP20消費→HP10、ゴブリンAP20→HP30-20=10 → 両者生存
func test_dragonnewt_with_boost_item():
	var config = _create_config(307, 414)
	config.attacker_items = [1008]  # ガーディアンブレイド(AP+30/HP+30)
	config.board_layout.append({"tile_index": 11, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 12, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 13, "owner_id": 0, "creature_id": 48})
	var r = await _execute_battle(config)
	# setでAP=30に上書き（アイテムAP+30は上書きされる）
	assert_eq(r.attacker_final_ap, 30, "set後AP=30（アイテムAPはset上書き）")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 巻物アイテム併用: 風3配置 + フォースストライク(巻物,base_ap)
## 巻物AP=base_ap(creature_data['ap']=0) → setが先に30→巻物が最後に0上書き？
## or 巻物が最後に再適用 → AP=0
## vs ゴブリン(無,AP20/HP30) on neutral
func test_dragonnewt_with_scroll_item():
	var config = _create_config(307, 414)
	config.attacker_items = [1007]  # フォースストライク(巻物,base_ap)
	config.board_layout.append({"tile_index": 11, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 12, "owner_id": 0, "creature_id": 48})
	config.board_layout.append({"tile_index": 13, "owner_id": 0, "creature_id": 48})
	var r = await _execute_battle(config)
	# 巻物base_ap → creature_data["ap"]=0 → AP=0
	assert_eq(r.attacker_final_ap, 0, "巻物base_ap=creature_data.ap=0")


# ===========================================================================
# ヒドラ (146): 水, S, AP0/HP30
# AP+手札数×10
# ===========================================================================

## 手札5枚(デフォルト): AP=0+50=50
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP50 → 防HP40-50=-10→撃破
func test_hydra_hand_count_5():
	var config = _create_config(146, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 50, "手札5×10=AP50")
	assert_eq(r.defender_final_hp, -10, "防HP40(30+land10)-50=-10→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 手札3枚: AP=0+30=30
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## AP30 → 防HP40-30=10、ゴブリンAP20→HP30-20=10
func test_hydra_hand_count_3():
	var config = _create_config(146, 414)
	config.attacker_initial_hand_size = 3
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "手札3×10=AP30")
	assert_eq(r.defender_final_hp, 10, "防HP40(30+land10)-30=10")
	assert_eq(r.attacker_final_hp, 10, "攻HP30-20=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# ===========================================================================
# ロックウォッチャー (204): 地, N, AP30/HP50
# 先制 + 防御時AP=50
# ===========================================================================

## 攻撃時: AP30のまま（防御時AP=50は不発）
## vs ゴブリン(無,AP20/HP30) on neutral, land_bonus=10
## 先制AP30 → 防HP40-30=10、反撃AP20→攻HP50-20=30
func test_rock_watcher_attack_normal_ap():
	var config = _create_config(204, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 30, "攻撃時→AP30のまま")
	assert_eq(r.defender_final_hp, 10, "防HP40(30+land10)-30=10")
	assert_eq(r.attacker_final_hp, 30, "攻HP50-20=30")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 防御時: AP=50に変更
## ゴブリン(無,AP20) vs ロックウォッチャー(防御側, earth, land=10)
## 先制あり→ロックウォッチャーが先に攻撃(AP50)→ゴブリンHP30-50=-20→撃破
func test_rock_watcher_defend_fixed_ap():
	var config = _create_config(414, 204, "earth")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 50, "防御時→AP=50")
	assert_eq(r.attacker_final_hp, -20, "先制AP50→ゴブリンHP30-50=-20→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


# ===========================================================================
# ベヒーモス (212): 地, S, AP60/HP50
# 無効化[先制の能力を持つクリーチャー]
# ===========================================================================

## 無効化発動: フレイムキメラ(火,AP30/HP50,先制持ち) vs ベヒーモス(地,earth,land=10)
## 先制持ち→無効化発動→攻撃無効、ベヒーモスAP60→フレイムキメラHP50-60=-10→撃破
func test_behemoth_nullify_first_strike():
	var config = _create_config(7, 212, "earth")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 50, "無効化→防HP50維持(land10は別管理)")
	assert_eq(r.attacker_final_hp, -10, "ベヒーモスAP60→攻HP50-60=-10→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


## 無効化不発: ゴブリン(無,AP20/HP30,先制なし) vs ベヒーモス(地,earth,land=10)
## 先制なし→無効化不発→通常戦闘
## ゴブリンAP20 vs land10→land消費、ベヒーモスAP60→ゴブリンHP30-60=-30→撃破
func test_behemoth_no_nullify_no_first_strike():
	var config = _create_config(414, 212, "earth")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 40, "ゴブリンAP20→land10消費→HP50-10=40")
	assert_eq(r.attacker_final_hp, -30, "ベヒーモスAP60→ゴブリンHP30-60=-30→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


# ===========================================================================
# バジリスク (215): 地, S, AP30/HP40
# 変質[on_attack_success → メガリスガード(222)に変身]
# ===========================================================================

## 攻撃成功→変質発動: バジリスク(AP30) vs ゴブリン(HP30+land10=40) on neutral
## AP30→land10+20消費→HP10→変質→メガリスガード(HP60,AP0)に変身
## メガリスガードAP0→バジリスクHP40維持
func test_basilisk_transform_on_attack_success():
	var config = _create_config(215, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 40, "メガリスガードAP0→ノーダメージ→HP40維持")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_true(r.attacker_battle_effects.has("変質"), "変質効果が発動")


## 攻撃で敵撃破→変質不発(死亡): バジリスク(AP30) vs 弱い敵
## HP20以下の敵を一撃で倒す→変質対象がいない
func test_basilisk_no_transform_on_kill():
	var config = _create_config(215, 414)
	config.defender_buff_config["base_up_hp"] = -20  # ゴブリンHP30→10
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker", "攻撃側勝利（一撃撃破）")
	assert_false(r.attacker_battle_effects.has("変質"), "敵死亡→変質不発")


# ===========================================================================
# セイレーン (332): 風, R, AP30/HP30
# 先制；攻撃成功時、敵に刻印[消沈]
# ===========================================================================

## 先制→攻撃成功→刻印[消沈]付与→反撃無効
## セイレーン(AP30,先制) vs ゴブリン(HP30+land10=40) on neutral
## 先制AP30→land10+20消費→HP30-20=10(生存)→消沈で反撃不可
func test_siren_curse_on_attack_success():
	var config = _create_config(332, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 30, "消沈で反撃不可→HP30維持")
	assert_eq(r.defender_final_hp, 10, "先制AP30→land10+20消費→HP30-20=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_true(r.attacker_battle_effects.has("刻印[消沈]"), "刻印[消沈]が発動")
	assert_eq(r.defender_curse.get("curse_type", ""), "battle_disable", "消沈刻印が付与")


# ===========================================================================
# リンドヴルム (320): 風, N, AP30/HP40
# 攻撃成功時、敵に刻印[衰弱]
# ===========================================================================

## 攻撃成功→刻印[衰弱]付与→衰弱ダメージで敵撃破
## リンドヴルム(AP30) vs ゴブリン(HP30+land10=40) on neutral
## AP30→land10+20消費→HP30-20=10→衰弱ダメージ→HP0→撃破
## ゴブリンAP20→リンドヴルムHP40-20=20
func test_lindwurm_curse_on_attack_success():
	var config = _create_config(320, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 20, "ゴブリンAP20→HP40-20=20")
	assert_eq(r.defender_final_hp, 0, "衰弱ダメージで追加撃破→HP0")
	assert_eq(r.winner, "attacker", "衰弱ダメージで敵撃破→攻撃側勝利")
	assert_true(r.attacker_battle_effects.has("刻印[衰弱]"), "刻印[衰弱]が発動")
	assert_eq(r.defender_curse.get("curse_type", ""), "plague", "衰弱刻印が付与")


# ===========================================================================
# シャドウレイス (418): 無, R, AP40/HP30
# 先制；APドレイン；奮闘
# ===========================================================================

## 先制→APドレイン→敵AP=0で反撃ダメージなし
## シャドウレイス(AP40,先制) vs ドラゴンゾンビ(無,AP50/HP60) on neutral, land10
## 先制AP40→land10+30消費→HP60-30=30(生存)→APドレイン→AP=0
## ドラゴンゾンビAP0→シャドウレイスHP30-0=30(ノーダメージ)
func test_shadow_wraith_ap_drain():
	var config = _create_config(418, 425)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 30, "APドレイン→敵AP0→ノーダメージ")
	assert_eq(r.defender_final_hp, 30, "先制AP40→land10+30消費→HP60-30=30")
	assert_eq(r.defender_final_ap, 0, "APドレイン→AP=0")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_true(r.attacker_battle_effects.has("APドレイン"), "APドレイン効果が発動")


# ===========================================================================
# セクメト (35): 火, N, AP30/HP30
# 加勢[無火地]；先制；敵破壊時、AP+10（永続）
# ===========================================================================

## 先制で敵撃破→AP+10永続バフ
## ゴブリン(AP20) attacks セクメト(防御側,fire,land=10)
## 先制→セクメトAP30→ゴブリンHP30-30=0→撃破→AP+10発動
func test_sekhmet_destroy_bonus():
	var config = _create_config(414, 35, "fire")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, 0, "先制AP30→ゴブリンHP30-30=0→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")
	assert_eq(r.defender_effect_info.get("base_up_ap", 0), 10, "敵破壊→AP+10永続")


# ===========================================================================
# キルフィーダー (227): 地, S, AP40/HP40
# 先制；敵破壊時、AP+10・MHP+10（永続）
# ===========================================================================

## 先制で敵撃破→AP+10・MHP+10永続バフ
## ゴブリン(AP20) attacks キルフィーダー(防御側,earth,land=10)
## 先制→キルフィーダーAP40→ゴブリンHP30-40=-10→撃破→AP+10/MHP+10発動
func test_killfeeder_destroy_bonus():
	var config = _create_config(414, 227, "earth")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, -10, "先制AP40→ゴブリンHP30-40=-10→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")
	assert_eq(r.defender_effect_info.get("base_up_ap", 0), 10, "敵破壊→AP+10永続")
	assert_eq(r.defender_effect_info.get("base_up_hp", 0), 10, "敵破壊→MHP+10永続")


# ===========================================================================
# バフォメット (443): 無, R, AP20/HP30
# 戦闘後、敵のAPとMHPを交換
# ===========================================================================

## 戦闘後→敵のAP⇔MHP交換
## バフォメット(AP20) vs ドラゴンゾンビ(無,AP50/HP60) on neutral, land10
## AP20→land10+10消費→HP60-10=50、ドラゴンゾンビAP50→HP30-50=-20→バフォメット撃破
## 戦闘後：ドラゴンゾンビのAP50⇔MHP60交換→AP=60,MHP=50
## current_hp=min(50,50)=50
func test_baphomet_swap_ap_mhp():
	var config = _create_config(443, 425)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_hp, -20, "ドラゴンゾンビAP50→HP30-50=-20→撃破")
	assert_eq(r.winner, "defender", "防御側勝利")


## バフォメット防御側で生存→敵のAP⇔MHP交換
## ゴブリン(AP20) vs バフォメット(無,HP30) on neutral, land10
## ゴブリンAP20→land10+10消費→HP30-10=20
## バフォメットAP20→ゴブリン HP30+land10: land10消費+10base→HP30-10=20
## 戦闘後：ゴブリンAP20⇔MHP30交換→AP=30,MHP=20
## current_hp=min(20,20)=20
func test_baphomet_defend_swap():
	var config = _create_config(414, 443)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 20, "AP20→land10+10消費→HP30-10=20")
	assert_eq(r.attacker_final_hp, 10, "ゴブリン(攻撃側landなし)HP30-バフォメットAP20=10")
	assert_eq(r.winner, "attacker_survived", "両者生存")


# ===========================================================================
# ヴァンパイア (446): 無, N, AP70/HP70
# 戦闘後、AP&MHP-10（永続）
# ===========================================================================

## 戦闘後→AP&MHP-10永続減少
## ヴァンパイア(AP70) vs ゴブリン(HP30+land10=40) on neutral
## AP70→ゴブリン撃破→戦闘後AP-10/MHP-10
## ※add_base_up_hpでcurrent_hpも-10される→HP70-10=60
func test_vampire_after_battle_penalty():
	var config = _create_config(446, 414)
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker", "攻撃側勝利")
	assert_eq(r.attacker_final_hp, 60, "戦闘後MHP-10→current_hpも-10→70-10=60")
	assert_eq(r.attacker_effect_info.get("base_up_ap", 0), -10, "戦闘後AP-10永続")
	assert_eq(r.attacker_effect_info.get("base_up_hp", 0), -10, "戦闘後MHP-10永続")


## 防御時も戦闘後ペナルティ発動
## ゴブリン(AP20) vs ヴァンパイア(HP70+land10=80) on neutral, land10
## ゴブリンAP20→land10消費+10base→HP70-10=60
## ヴァンパイアAP70→ゴブリンHP30-70=-40→撃破
## 戦闘後MHP-10→current_hpも-10→60-10=50
func test_vampire_defend_penalty():
	var config = _create_config(414, 446)
	var r = await _execute_battle(config)
	assert_eq(r.winner, "defender", "防御側勝利")
	assert_eq(r.defender_final_hp, 50, "HP60(戦闘後)-10(ペナルティ)=50")
	assert_eq(r.defender_effect_info.get("base_up_ap", 0), -10, "戦闘後AP-10永続")
	assert_eq(r.defender_effect_info.get("base_up_hp", 0), -10, "戦闘後MHP-10永続")


# ===========================================================================
# ヌエ (339): 風, S, AP40/HP40
# アイテム使用時AP+20；敵アイテム使用の戦闘後MHP+10
# ===========================================================================

## 自分がアイテム使用→AP+20ボーナス
## ヌエ(AP40) + ガーディアンブレイド(AP+30,HP+30) vs ゴブリン on neutral
## AP40 + item30 + ブルガサリボーナス20 = 90
func test_nue_self_item_ap_bonus():
	var config = _create_config(339, 414)
	config.attacker_items = [1008]  # ガーディアンブレイド(武器,AP+30,HP+30)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 90, "AP40+item30+ヌエボーナス20=90")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 敵がアイテム使用→戦闘後MHP+10
## ゴブリン+ドミニオンリング(AP+10,HP+20) vs ヌエ(防御側,wind,HP40+land10) on wind
## ゴブリンAP30→land10消費+20base→HP40-20=20(ヌエ生存)
## ヌエAP40→ゴブリン: item20消費+20base→HP30-20=10
## 戦闘後：MHP+10 → add_base_up_hpでcurrent_hpも+10 → HP20+10=30
func test_nue_enemy_item_mhp_bonus():
	var config = _create_config(414, 339, "wind")
	config.attacker_items = [1016]  # ドミニオンリング(アクセサリ,AP+10,HP+20)
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 30, "HP20(戦闘後)+10(MHP永続ボーナス)=30")
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_eq(r.defender_effect_info.get("base_up_hp", 0), 10, "敵アイテム使用→MHP+10永続")


# ===========================================================================
# エアエレメンタル (330): 風, N, AP20/HP50
# 先制；常時補正AP+20、HP-10
# ===========================================================================

## 常時補正: AP=20+20=40, HP=50-10(temp)=実質40
## エアエレメンタル(先制AP40) vs ゴブリン(HP30+land10=40) on neutral
## 先制AP40→land10+30消費→HP30-30=0→撃破
func test_air_elemental_constant_bonus():
	var config = _create_config(330, 414)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 40, "AP20+常時補正20=40")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


## 常時補正HP-10: 被ダメージ時にtemp_bonus_hpが先に消費
## ゴブリン(AP20) vs エアエレメンタル(防御側,wind,HP50+land10,temp-10) on wind
## ゴブリンAP20 vs エアエレメンタル: land10消費+temp(-10)は0以下なのでスキップ→base HP50-10=40
## 先制AP40→ゴブリンHP30-40=-10→撃破
func test_air_elemental_defend_hp_penalty():
	var config = _create_config(414, 330, "wind")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_ap, 40, "AP20+常時補正20=40")
	assert_eq(r.winner, "defender", "先制AP40→ゴブリン撃破")


# ===========================================================================
# スパインウォール (205): 地, N, AP10/HP50
# 堅守；敵が水風の場合HP+50；再生
# ===========================================================================

## 敵が水属性→HP+50ボーナス（temp_bonus_hp）
## ヘヴィアンカー(水,AP10) vs スパインウォール(地,earth,HP50+land10+temp50) on earth
## AP10→land10消費→current_hp=50維持
## スパインウォールAP10→ヘヴィアンカーHP70-10=60
func test_spine_wall_water_enemy_hp_bonus():
	var config = _create_config(101, 205, "earth")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 50, "水属性→HP+50、AP10はland10で吸収→HP50維持")
	assert_eq(r.attacker_final_hp, 60, "スパインウォールAP10→HP70-10=60")
	assert_eq(r.winner, "attacker_survived", "両者生存")


## 敵が地属性→HP+50なし、AP60で撃破
## ベヒーモス(地,AP60) vs スパインウォール(地,earth,HP50+land10) on earth
## AP60→land10消費+base50→HP50-50=0→撃破（再生不可）
func test_spine_wall_no_bonus_earth_enemy():
	var config = _create_config(212, 205, "earth")
	var r = await _execute_battle(config)
	assert_eq(r.defender_final_hp, 0, "地属性→ボーナスなし、AP60→land10+HP50=60→HP0→撃破")
	assert_eq(r.winner, "attacker", "攻撃側勝利")


# ==============================================================================
# 個別クリーチャーテスト: ライフリンク(ID:137)
# 水, S, AP20/HP20, 加勢[水地風], MHP+加勢クリーチャーのHP (上限100)
# ==============================================================================

## 基本加勢: 水クリーチャー(プレッシャーリング ID:105 AP20/HP30)を加勢使用
## ライフリンク(AP20,HP20) + 加勢AP20 + 加勢HP30(item_bonus) + MHP永続吸収30
## → current_ap=40, MHP=50(current_hp=50), item_bonus_hp=30
## ゴブリン(414,AP20) → ライフリンク: land10+item10消費 → item残20, HP50
## ライフリンクAP40 → ゴブリンHP30: 撃破 → winner=defender
func test_life_link_basic_assist_water():
	var config = _create_config(414, 137, "neutral")
	config.defender_items = [105]  # プレッシャーリング(水,AP20/HP30)を加勢
	var r = await _execute_battle(config)
	# MHP永続吸収: base20 + absorbed30 = MHP50
	assert_eq(r.defender_effect_info.get("base_up_hp", 0), 30, "MHP永続吸収+30")
	# ゴブリンAP20 → land10+item10消費 → base HP50無傷
	assert_eq(r.defender_final_hp, 50, "AP20→land10+item10消費→HP50維持")
	assert_eq(r.winner, "defender", "ライフリンクAP40でゴブリンHP30撃破")


## 地属性クリーチャー加勢: ヴォイドパペット(ID:203 地 AP20/HP20)
## ライフリンク(AP20,HP20) + 加勢AP20 + 加勢HP20(item_bonus) + MHP永続吸収20
## → current_ap=40, MHP=40(current_hp=40), item_bonus_hp=20
## ゴブリンAP20 → land10+item10 → item残10, HP40
## ライフリンクAP40 → ゴブリンHP30: 撃破
func test_life_link_assist_earth_creature():
	var config = _create_config(414, 137, "neutral")
	config.defender_items = [203]  # ヴォイドパペット(地,AP20/HP20)
	var r = await _execute_battle(config)
	# MHP永続吸収: base20 + absorbed20 = MHP40
	assert_eq(r.defender_effect_info.get("base_up_hp", 0), 20, "地クリーチャー加勢でMHP+20")
	assert_eq(r.winner, "defender", "ライフリンクAP40でゴブリンHP30撃破")


## MHP上限100テスト: ライフリンク(HP20) + base_up_hp50 + 加勢HP40 → 20+50+40=110 → 100に制限
## buff_configでbase_up_hpを事前に50上げ、加勢クリーチャーHP40で上限確認
## ゴブリンAP20 → land10+item10 → item残30, HP100
## ライフリンクAP40 → ゴブリンHP30: 撃破
func test_life_link_mhp_cap_100():
	var config = _create_config(414, 137, "neutral")
	config.defender_buff_config["base_up_hp"] = 50  # 事前にMHP70(20+50)
	config.defender_items = [106]  # アビスキーパー(水,AP20/HP40) → 70+40=110→100制限
	var r = await _execute_battle(config)
	# 上限100なので、吸収量は100-70=30のみ
	assert_eq(r.defender_effect_info.get("base_up_hp", 0), 50 + 30, "MHP上限100: 50+30=80(base_up_hp)")
	# MHP=100, ゴブリンAP20 → land10+item10消費 → item残30 → HP100維持
	assert_eq(r.defender_final_hp, 100, "MHP100でHP100維持")
	assert_eq(r.winner, "defender", "ライフリンクAP40でゴブリンHP30撃破")


## 風クリーチャー加勢: ウィンドオーガ(ID:301 風 AP40/HP50)で加勢
## ライフリンク(AP20,HP20) + 加勢AP40 + 加勢HP50(item_bonus) + MHP永続吸収50
## → current_ap=60, MHP=70(current_hp=70), item_bonus_hp=50
## ゴブリンAP20 → land10+item10 → item残40, HP70
## ライフリンクAP60 → ゴブリンHP30: 撃破
func test_life_link_assist_wind_creature():
	var config = _create_config(414, 137, "neutral")
	config.defender_items = [301]  # ウィンドオーガ(風,AP40/HP50)
	var r = await _execute_battle(config)
	# MHP永続吸収: base20 + absorbed50 = MHP70
	assert_eq(r.defender_effect_info.get("base_up_hp", 0), 50, "風クリーチャー加勢でMHP+50")
	# ライフリンク current_ap = 20(base) + 40(assist) = 60
	assert_eq(r.winner, "defender", "ライフリンクAP60でゴブリンHP30撃破")


# ==============================================================================
# 個別クリーチャーテスト: ストームブリンガー(ID:327)
# 風, S, AP50/HP40, 侵略時土地破壊（on_invasion: 勝敗問わずLv-1）
# ==============================================================================

## 侵略勝利時にタイルレベルが-1される
## ストームブリンガー(327,AP50+buff30=80) vs ゴブリン(414,AP20/HP30) on neutral
## AP80 → land10+HP20消費→HP0→ゴブリン撃破 → on_invasion: Lv-1
func test_storm_bringer_reduce_level_on_win():
	var config = _create_config(327, 414, "neutral")
	config.attacker_buff_config["base_up_ap"] = 30  # AP80で確実撃破
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker", "ストームブリンガーがゴブリン撃破")
	assert_eq(r.land_effect_level_reduced, true, "侵略時にタイルレベル-1")


## 侵略敗北時もタイルレベルが-1される（防御側に領土守護なし）
## ストームブリンガー(327,AP50/HP40) vs ベヒーモス(212,地,AP60/HP60) on earth
## AP50 → land10+HP50消費→HP10, ベヒーモスAP60 → HP40→0→撃破
## 侵略側敗北だがon_invasion発動 → 防御側に領土守護なし → Lv-1
func test_storm_bringer_reduce_level_on_loss():
	var config = _create_config(327, 212, "earth")
	var r = await _execute_battle(config)
	assert_eq(r.winner, "defender", "ベヒーモス防御勝利")
	assert_eq(r.land_effect_level_reduced, true, "侵略敗北でもタイルレベル-1")


## 侵略敗北時、防御側が領土守護持ちで生存 → レベル減少無効
## ストームブリンガー(327,AP50/HP40) vs イモータルランド(232,地,AP30/HP40,領土守護) on earth
## AP50 → land10+HP40消費→HP0→イモータルランド撃破... ではダメ
## → 両者生存にするためAPを下げる: buff で AP-30 → AP20
## AP20 → land10+HP10消費→HP30, イモータルランドAP30 → HP40-30=10 → 両者生存
## 侵略側生存だがon_invasion発動 → 防御側生存+領土守護 → Lv変化なし
func test_storm_bringer_blocked_by_land_protection():
	var config = _create_config(327, 232, "earth")
	config.attacker_buff_config["base_up_ap"] = -30  # AP50-30=20で両者生存
	var r = await _execute_battle(config)
	assert_eq(r.winner, "attacker_survived", "両者生存")
	assert_eq(r.land_effect_level_reduced, false, "領土守護により土地破壊が無効")


## 防御側の場合は侵略ではないので発動しない
## ゴブリン(414,AP20/HP30) vs ストームブリンガー(327,AP50/HP40) on neutral
## ゴブリンAP20 → land10+HP10消費→HP30, ストームブリンガーAP50 → HP30-50→0→撃破
## ストームブリンガーは防御側 → on_invasionは攻撃側のみ → 不発
func test_storm_bringer_no_reduce_as_defender():
	var config = _create_config(414, 327, "neutral")
	var r = await _execute_battle(config)
	assert_eq(r.winner, "defender", "ストームブリンガー防御勝利")
	assert_eq(r.land_effect_level_reduced, false, "防御側ではon_invasion不発")


# ==============================================================================
# 個別クリーチャーテスト: オーガロード(ID:407)
# 無, S, AP40/HP50, 火風オーガ配置でAP+20/水地オーガ配置でHP+20, 強化術
# ==============================================================================

## 火オーガ(レッドオーガ48)配置 → AP+20
## オーガロード(AP40+20=60) vs ゴブリン(414,AP20/HP30) on neutral
## 強化術は巻物使用時のみ発動（ここではアイテムなし）
func test_ogre_lord_fire_ogre_ap_bonus():
	var config = _create_config(407, 414, "neutral")
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 48})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "火オーガ配置→AP40+20=60")
	assert_eq(r.winner, "attacker", "AP60でゴブリン撃破")


## 水地オーガ(アースオーガ210+タイダルオーガ138)配置 → HP+20(temporary_bonus_hp)
## AP変動なし→強化術発動(AP40×1.5=60)、強化術は土地ボーナスも無効化
## current_hpは50のまま（temporary_bonus_hpは別プール）
func test_ogre_lord_water_earth_ogre_hp_bonus():
	var config = _create_config(407, 414, "neutral")
	config.board_layout.append({"tile_index": 6, "owner_id": 0, "creature_id": 138})   # タイダルオーガ(水)
	config.board_layout.append({"tile_index": 16, "owner_id": 0, "creature_id": 210})  # アースオーガ(地)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "水地オーガのみ→APバフなし→強化術発動(40×1.5=60)")
	assert_eq(r.attacker_final_hp, 50, "current_hp=50(temp+20は別プール)、撃破→反撃なし")
	assert_eq(r.winner, "attacker", "AP60でゴブリン撃破")


## 火風+水地オーガ全配置 → AP+20 & HP+20(temporary_bonus_hp)
## AP+20バフ検出→強化術不発→AP60, current_hp=50(temp+20は別プール)
func test_ogre_lord_all_ogres():
	var config = _create_config(407, 414, "neutral")
	config.board_layout.append({"tile_index": 1, "owner_id": 0, "creature_id": 48})    # レッドオーガ(火)
	config.board_layout.append({"tile_index": 11, "owner_id": 0, "creature_id": 301})  # ウィンドオーガ(風)
	config.board_layout.append({"tile_index": 6, "owner_id": 0, "creature_id": 138})   # タイダルオーガ(水)
	config.board_layout.append({"tile_index": 16, "owner_id": 0, "creature_id": 210})  # アースオーガ(地)
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "火風オーガAP+20→バフ検出→強化術不発→AP60")
	assert_eq(r.attacker_final_hp, 50, "current_hp=50(temp+20は別プール)、撃破→反撃なし")
	assert_eq(r.winner, "attacker", "AP60でゴブリン撃破")


## オーガ未配置 → オーガボーナスなし、APバフなし→強化術発動
## オーガロード(AP40×1.5=60,HP50) vs ゴブリン(414,AP20/HP30) on neutral
## 強化術で土地ボーナス無効化、AP60→撃破→反撃なし→HP50維持
func test_ogre_lord_no_ogres():
	var config = _create_config(407, 414, "neutral")
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 60, "オーガ未配置→APバフなし→強化術発動(40×1.5=60)")
	assert_eq(r.attacker_final_hp, 50, "ゴブリン撃破→反撃なし→HP50維持")
	assert_eq(r.winner, "attacker", "AP60でゴブリン撃破")


# ==============================================================================
# 個別クリーチャーテスト: ゴブリンシャーマン(ID:445)
# 無, N, AP30/HP30, AP&HP=ゴブリン配置数×20, 鼓舞[ゴブリン・AP+20]
# ==============================================================================

## ゴブリン1体配置(ボード上) → count=1 → AP&HP=1×20=20
## ※include_selfはtile非配置の攻撃側には効かない（現仕様）
## ゴブリンシャーマン(AP20,HP20) vs レッドオーガ(48,AP40/HP50) on neutral
func test_goblin_shaman_1_goblin_on_board():
	var config = _create_config(445, 48, "neutral")
	# ゴブリン(414)を1体配置
	config.board_layout.append({"tile_index": 15, "owner_id": 0, "creature_id": 414})
	var r = await _execute_battle(config)
	assert_eq(r.attacker_final_ap, 20, "ゴブリン1体×20=AP20")
	assert_eq(r.attacker_final_hp, -20, "HP20-40=-20→撃破")
	assert_eq(r.winner, "defender", "レッドオーガ生存")


## ゴブリン0体(自身のみ、ボード未配置) → AP&HP=1×20=20? or 0?
## include_self=trueなので自身をカウント
## ただしboard上のtile_nodesから数えるので、自身がtileに配置されていなければ0
func test_goblin_shaman_self_only():
	var config = _create_config(445, 414, "neutral")
	# 自身以外ゴブリンなし（自身も攻撃側なのでタイルに配置されない）
	var r = await _execute_battle(config)
	# タイル上にゴブリンがいない → 0体×20 = AP&HP=0
	assert_eq(r.attacker_final_ap, 0, "ゴブリン配置0体→AP=0")
	assert_eq(r.attacker_final_hp, 0, "ゴブリン配置0体→HP=0→死亡")
	assert_eq(r.winner, "defender", "HP0で防御側勝利")


# ==============================================================================
# 個別クリーチャーテスト: 合体スキル
# グランギア(409)+スカイギア(419)→アンドロギア(406)
# アンドロギア(406)+ビーストギア(434)→ギアリオン(408)
# ==============================================================================

## グランギア(409,AP20/HP40)+スカイギア(419)→アンドロギア(406,AP60/HP60)
## 合体後アンドロギア(AP60,HP60) vs ゴブリン(414,AP20/HP30) on neutral
## 先制持ち→AP60→撃破→反撃なし→HP60維持
func test_merge_gran_gear_to_androgia():
	var config = _create_config(409, 414, "neutral")
	config.attacker_merge_partner_id = 419  # スカイギア
	var r = await _execute_battle(config)
	# 合体後はアンドロギア(AP60/HP60)のステータスになる
	assert_eq(r.attacker_final_ap, 60, "合体後アンドロギア AP60")
	assert_eq(r.attacker_final_hp, 60, "合体後アンドロギア HP60、撃破→反撃なし")
	assert_eq(r.winner, "attacker", "AP60でゴブリン撃破")


## アンドロギア(406,AP60/HP60)+ビーストギア(434)→ギアリオン(408,AP80/HP80)
## 合体後ギアリオン(AP80,HP80) vs レッドオーガ(48,AP40/HP50) on neutral
## 先制持ち→AP80→撃破→反撃なし→HP80維持
func test_merge_androgia_to_gearion():
	var config = _create_config(406, 48, "neutral")
	config.attacker_merge_partner_id = 434  # ビーストギア
	var r = await _execute_battle(config)
	# 合体後はギアリオン(AP80/HP80)のステータスになる
	assert_eq(r.attacker_final_ap, 80, "合体後ギアリオン AP80")
	assert_eq(r.attacker_final_hp, 80, "合体後ギアリオン HP80、撃破→反撃なし")
	assert_eq(r.winner, "attacker", "AP80でレッドオーガ撃破")
