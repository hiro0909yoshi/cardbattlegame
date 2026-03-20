extends GutTest

## バトルシステム基本テスト - アイテム効果検証
## 攻撃側: タイダルオーガ（ID:138, 水, AP40/HP50, スキルなし）
## 防御側: レッドオーガ（ID:48, 火, AP40/HP50, スキルなし）
## 条件: 両者 火×2 + 水×2 土地保有、火タイル Lv1 で戦闘
## 防御側は火タイルで火属性 → ランドボーナス HP+10

var _executor: BattleTestExecutor

const ATTACKER_ID = 138  # タイダルオーガ（水, AP40/HP50）
const DEFENDER_ID = 48   # レッドオーガ（火, AP40/HP50）


func before_all():
	_executor = BattleTestExecutor.new()
	_executor.scene_tree_parent = self


func _create_config() -> BattleTestConfig:
	var config = BattleTestConfig.new()
	config.attacker_creatures = [ATTACKER_ID]
	config.defender_creatures = [DEFENDER_ID]
	# ボード再現型配置: ダイアモンドボード20タイル上に配置
	# 攻撃側(pid=0): 火タイル×2 + 水タイル×2（クリーチャー: 火2水2）
	# 防御側(pid=1): 火タイル×2 + 水タイル×2（クリーチャー: 火2水2）+ バトルタイル火×1
	# ※旧テスト「両者火2水2」条件を再現（防御側バトルタイル含め火計3）
	config.board_layout = [
		# 攻撃側の土地
		{"tile_index": 1, "owner_id": 0, "creature_id": 48},    # 火タイルにレッドオーガ
		{"tile_index": 2, "owner_id": 0, "creature_id": 48},    # 火タイルにレッドオーガ
		{"tile_index": 6, "owner_id": 0, "creature_id": 138},   # 水タイルにタイダルオーガ
		{"tile_index": 7, "owner_id": 0, "creature_id": 138},   # 水タイルにタイダルオーガ
		# 防御側の土地（火タイル3,4 + 水タイル8,9）
		{"tile_index": 3, "owner_id": 1, "creature_id": 48},    # 火タイル（バトルタイル隣）
		{"tile_index": 4, "owner_id": 1, "creature_id": 48},    # 火タイル（バトルタイル）
		{"tile_index": 8, "owner_id": 1, "creature_id": 138},   # 水タイル
		{"tile_index": 9, "owner_id": 1, "creature_id": 138},   # 水タイル
	]
	config.battle_tile_index = 4  # タイル4（火）で戦闘
	config.attacker_battle_land = "fire"
	config.defender_battle_land = "fire"
	config.attacker_battle_land_level = 1
	config.defender_battle_land_level = 1
	return config


## 単一アイテムでバトル実行（攻撃側装備）
func _battle_attacker_item(item_id: int) -> BattleTestResult:
	var config = _create_config()
	config.attacker_items = [item_id]
	var results = await _executor.execute_all_battles(config)
	return results[0]


## 単一アイテムでバトル実行（防御側装備）
func _battle_defender_item(item_id: int) -> BattleTestResult:
	var config = _create_config()
	config.defender_items = [item_id]
	var results = await _executor.execute_all_battles(config)
	return results[0]


## バトル結果をassert（攻撃側装備）
func _assert_attacker_item(item_id: int, item_name: String,
		exp_att_ap: int, exp_att_hp: int,
		exp_def_ap: int, exp_def_hp: int, exp_winner: String,
		exp_granted: Array = []) -> void:
	var r = await _battle_attacker_item(item_id)
	assert_eq(r.attacker_final_ap, exp_att_ap, "%s(攻): 攻AP" % item_name)
	assert_eq(r.attacker_final_hp, exp_att_hp, "%s(攻): 攻HP" % item_name)
	assert_eq(r.defender_final_ap, exp_def_ap, "%s(攻): 防AP" % item_name)
	assert_eq(r.defender_final_hp, exp_def_hp, "%s(攻): 防HP" % item_name)
	assert_eq(r.winner, exp_winner, "%s(攻): 勝者" % item_name)
	assert_eq(r.attacker_granted_skills, exp_granted, "%s(攻): 付与スキル" % item_name)


## バトル結果をassert（防御側装備）
func _assert_defender_item(item_id: int, item_name: String,
		exp_att_ap: int, exp_att_hp: int,
		exp_def_ap: int, exp_def_hp: int, exp_winner: String,
		exp_granted: Array = []) -> void:
	var r = await _battle_defender_item(item_id)
	assert_eq(r.attacker_final_ap, exp_att_ap, "%s(防): 攻AP" % item_name)
	assert_eq(r.attacker_final_hp, exp_att_hp, "%s(防): 攻HP" % item_name)
	assert_eq(r.defender_final_ap, exp_def_ap, "%s(防): 防AP" % item_name)
	assert_eq(r.defender_final_hp, exp_def_hp, "%s(防): 防HP" % item_name)
	assert_eq(r.winner, exp_winner, "%s(防): 勝者" % item_name)
	assert_eq(r.defender_granted_skills, exp_granted, "%s(防): 付与スキル" % item_name)


# ========================================
# 純ステータスボーナス系（付与スキルなし）
# ========================================

func test_1009_zweihander_attacker():
	await _assert_attacker_item(1009, "ツヴァイハンダー", 90, 50, 40, -30, "attacker", [])

func test_1009_zweihander_defender():
	await _assert_defender_item(1009, "ツヴァイハンダー", 40, -40, 90, 20, "defender", [])

func test_1053_broad_axe_attacker():
	await _assert_attacker_item(1053, "ブロードアックス", 80, 50, 40, -20, "attacker", [])

func test_1053_broad_axe_defender():
	await _assert_defender_item(1053, "ブロードアックス", 40, -30, 80, 20, "defender", [])

func test_1073_war_hammer_attacker():
	await _assert_attacker_item(1073, "ウォーハンマー", 70, 50, 40, -10, "attacker", [])

func test_1073_war_hammer_defender():
	await _assert_defender_item(1073, "ウォーハンマー", 40, -20, 70, 20, "defender", [])

func test_1070_claw_attacker():
	await _assert_attacker_item(1070, "クロー", 60, 50, 40, 0, "attacker", [])

func test_1070_claw_defender():
	await _assert_defender_item(1070, "クロー", 40, -10, 60, 20, "defender", [])

func test_1058_full_plate_attacker():
	await _assert_attacker_item(1058, "フルプレート", 40, 50, 40, 20, "attacker_survived", [])

func test_1058_full_plate_defender():
	await _assert_defender_item(1058, "フルプレート", 40, 10, 40, 50, "attacker_survived", [])

func test_1018_brigandine_attacker():
	await _assert_attacker_item(1018, "ブリガンダイン", 40, 50, 40, 20, "attacker_survived", [])

func test_1018_brigandine_defender():
	await _assert_defender_item(1018, "ブリガンダイン", 40, 10, 40, 50, "attacker_survived", [])

func test_1033_half_plate_attacker():
	await _assert_attacker_item(1033, "ハーフプレート", 40, 40, 40, 20, "attacker_survived", [])

func test_1033_half_plate_defender():
	await _assert_defender_item(1033, "ハーフプレート", 40, 10, 40, 50, "attacker_survived", [])

func test_1001_great_helm_attacker():
	await _assert_attacker_item(1001, "グレートヘルム", 30, 50, 40, 30, "attacker_survived", [])

func test_1001_great_helm_defender():
	await _assert_defender_item(1001, "グレートヘルム", 40, 20, 30, 50, "attacker_survived", [])

func test_1008_guardian_blade_attacker():
	await _assert_attacker_item(1008, "ガーディアンブレイド", 70, 50, 40, -10, "attacker", [])

func test_1008_guardian_blade_defender():
	await _assert_defender_item(1008, "ガーディアンブレイド", 40, -20, 70, 50, "defender", [])

func test_1040_trident_attacker():
	await _assert_attacker_item(1040, "トライデント", 80, 50, 40, -20, "attacker", [])

func test_1040_trident_defender():
	await _assert_defender_item(1040, "トライデント", 40, -30, 80, 40, "defender", [])

func test_1020_colossal_sword_attacker():
	await _assert_attacker_item(1020, "コロッサルソード", 100, 50, 40, -40, "attacker", [])

func test_1020_colossal_sword_defender():
	await _assert_defender_item(1020, "コロッサルソード", 40, -50, 100, 20, "defender", [])


# ========================================
# ステータス + 非戦闘効果（復帰・形見・蓄魔等）
# ========================================

func test_1005_phoenix_mail_attacker():
	var r = await _battle_attacker_item(1005)
	assert_eq(r.attacker_final_ap, 40, "フェニックスメイル(攻): 攻AP")
	assert_eq(r.attacker_final_hp, 50, "フェニックスメイル(攻): 攻HP")
	assert_eq(r.defender_final_hp, 20, "フェニックスメイル(攻): 防HP")
	assert_eq(r.winner, "attacker_survived", "フェニックスメイル(攻): 勝者")
	assert_true(r.attacker_item_returned, "フェニックスメイル(攻): 復帰発動")
	assert_eq(r.attacker_item_return_type, "deck", "フェニックスメイル(攻): ブック復帰")

func test_1005_phoenix_mail_defender():
	var r = await _battle_defender_item(1005)
	assert_eq(r.defender_final_hp, 50, "フェニックスメイル(防): 防HP")
	assert_eq(r.winner, "attacker_survived", "フェニックスメイル(防): 勝者")
	assert_true(r.defender_item_returned, "フェニックスメイル(防): 復帰発動")
	assert_eq(r.defender_item_return_type, "deck", "フェニックスメイル(防): ブック復帰")

func test_1011_legacy_orb_attacker():
	await _assert_attacker_item(1011, "レガシーオーブ", 40, 10, 40, 20, "attacker_survived", [])

func test_1011_legacy_orb_defender():
	await _assert_defender_item(1011, "レガシーオーブ", 40, 10, 40, 20, "attacker_survived", [])

func test_1016_dominion_ring_attacker():
	await _assert_attacker_item(1016, "ドミニオンリング", 50, 30, 40, 10, "attacker_survived", [])

func test_1016_dominion_ring_defender():
	await _assert_defender_item(1016, "ドミニオンリング", 40, 0, 50, 40, "defender", [])

func test_1029_drain_mail_attacker():
	await _assert_attacker_item(1029, "ドレインメイル", 40, 50, 40, 20, "attacker_survived", [])

func test_1029_drain_mail_defender():
	await _assert_defender_item(1029, "ドレインメイル", 40, 10, 40, 50, "attacker_survived", [])

func test_1054_chakram_attacker():
	var r = await _battle_attacker_item(1054)
	assert_eq(r.attacker_final_ap, 60, "チャクラム(攻): 攻AP")
	assert_eq(r.attacker_final_hp, 50, "チャクラム(攻): 攻HP")
	assert_eq(r.defender_final_hp, 0, "チャクラム(攻): 防HP")
	assert_eq(r.winner, "attacker", "チャクラム(攻): 勝者")
	assert_true(r.attacker_item_returned, "チャクラム(攻): 復帰発動")
	assert_eq(r.attacker_item_return_type, "hand", "チャクラム(攻): 手札復帰")

func test_1054_chakram_defender():
	var r = await _battle_defender_item(1054)
	assert_eq(r.defender_final_ap, 60, "チャクラム(防): 防AP")
	assert_eq(r.attacker_final_hp, -10, "チャクラム(防): 攻HP")
	assert_eq(r.defender_final_hp, 30, "チャクラム(防): 防HP")
	assert_eq(r.winner, "defender", "チャクラム(防): 勝者")
	assert_true(r.defender_item_returned, "チャクラム(防): 復帰発動")
	assert_eq(r.defender_item_return_type, "hand", "チャクラム(防): 手札復帰")


# ========================================
# 戦闘スキル系（反射・刺突・2回攻撃・無効化）
# ========================================

func test_1002_demon_mask_attacker():
	await _assert_attacker_item(1002, "デモンマスク", 40, 40, 40, -20, "attacker", [])

func test_1002_demon_mask_defender():
	await _assert_defender_item(1002, "デモンマスク", 40, -30, 40, 50, "defender", [])

func test_1025_thorn_shield_attacker():
	await _assert_attacker_item(1025, "ソーンシールド", 40, 30, 40, 0, "attacker", [])

func test_1025_thorn_shield_defender():
	await _assert_defender_item(1025, "ソーンシールド", 40, -10, 40, 40, "defender", [])

func test_1066_reflect_guard_attacker():
	await _assert_attacker_item(1066, "リフレクトガード", 40, 50, 40, -20, "attacker", [])

func test_1066_reflect_guard_defender():
	await _assert_defender_item(1066, "リフレクトガード", 40, -30, 40, 50, "defender", [])

func test_1042_pile_bunker_attacker():
	await _assert_attacker_item(1042, "パイルバンカー", 60, 50, 40, -10, "attacker", ["刺突"])

func test_1042_pile_bunker_defender():
	await _assert_defender_item(1042, "パイルバンカー", 40, -10, 60, 20, "defender", ["刺突"])

func test_1043_double_dagger_attacker():
	await _assert_attacker_item(1043, "ダブルダガー", 40, 50, 40, -20, "attacker", [])

func test_1043_double_dagger_defender():
	await _assert_defender_item(1043, "ダブルダガー", 40, -30, 40, 20, "defender", [])

func test_1026_aegis_shield_attacker():
	await _assert_attacker_item(1026, "イージスシールド", 0, 50, 40, 50, "attacker_survived", ["無効化"])

func test_1026_aegis_shield_defender():
	await _assert_defender_item(1026, "イージスシールド", 40, 50, 0, 50, "attacker_survived", ["無効化"])

func test_1074_miracle_seal_attacker():
	await _assert_attacker_item(1074, "ミラクルシール", 40, 42, 40, 20, "attacker_survived", ["無効化"])

func test_1074_miracle_seal_defender():
	await _assert_defender_item(1074, "ミラクルシール", 40, 10, 40, 50, "attacker_survived", ["無効化"])


# ========================================
# 巻物系（術攻撃）
# ========================================

func test_1007_force_strike_attacker():
	await _assert_attacker_item(1007, "フォースストライク", 40, 10, 40, 10, "attacker_survived", ["術攻撃"])

func test_1007_force_strike_defender():
	await _assert_defender_item(1007, "フォースストライク", 40, 10, 40, 20, "attacker_survived", ["術攻撃"])

func test_1024_lightning_orb_attacker():
	await _assert_attacker_item(1024, "ライトニングオーブ", 40, 10, 40, 10, "attacker_survived", ["術攻撃"])

func test_1024_lightning_orb_defender():
	await _assert_defender_item(1024, "ライトニングオーブ", 40, 10, 40, 20, "attacker_survived", ["術攻撃"])

func test_1030_return_ray_attacker():
	var r = await _battle_attacker_item(1030)
	assert_eq(r.attacker_final_ap, 30, "リターンレイ(攻): 攻AP")
	assert_eq(r.attacker_final_hp, 10, "リターンレイ(攻): 攻HP")
	assert_eq(r.defender_final_hp, 20, "リターンレイ(攻): 防HP")
	assert_eq(r.winner, "attacker_survived", "リターンレイ(攻): 勝者")
	assert_true(r.attacker_item_returned, "リターンレイ(攻): 復帰発動")
	assert_eq(r.attacker_item_return_type, "hand", "リターンレイ(攻): 手札復帰")

func test_1030_return_ray_defender():
	var r = await _battle_defender_item(1030)
	assert_eq(r.defender_final_ap, 30, "リターンレイ(防): 防AP")
	assert_eq(r.attacker_final_hp, 20, "リターンレイ(防): 攻HP")
	assert_eq(r.defender_final_hp, 20, "リターンレイ(防): 防HP")
	assert_eq(r.winner, "attacker_survived", "リターンレイ(防): 勝者")
	assert_true(r.defender_item_returned, "リターンレイ(防): 復帰発動")
	assert_eq(r.defender_item_return_type, "hand", "リターンレイ(防): 手札復帰")

func test_1037_divine_halo_attacker():
	await _assert_attacker_item(1037, "ディバインハロー", 45, 10, 40, 5, "attacker_survived", ["術攻撃", "強化術"])

func test_1037_divine_halo_defender():
	await _assert_defender_item(1037, "ディバインハロー", 40, 5, 45, 20, "attacker_survived", ["術攻撃", "強化術"])


# ========================================
# 条件付き強化系
# ========================================

func test_1060_giant_killer_attacker():
	await _assert_attacker_item(1060, "ジャイアントキラー", 105, 50, 40, -45, "attacker", ["強化"])

func test_1060_giant_killer_defender():
	await _assert_defender_item(1060, "ジャイアントキラー", 40, -55, 105, 20, "defender", ["強化"])

func test_1062_gaia_shield_attacker():
	## 攻撃側=水 → 火地条件不成立 → 無効化なし
	await _assert_attacker_item(1062, "ガイアシールド", 40, 10, 40, 20, "attacker_survived", [])

func test_1062_gaia_shield_defender():
	## 防御側=火 → 火地条件成立 → 無効化[通常攻撃]
	await _assert_defender_item(1062, "ガイアシールド", 40, 10, 40, 50, "attacker_survived", ["無効化"])

func test_1063_gaia_hammer_attacker():
	## 攻撃側=水 → 火条件不成立 → 強化なし
	await _assert_attacker_item(1063, "ガイアハンマー", 60, 50, 40, 0, "attacker", [])

func test_1063_gaia_hammer_defender():
	## 防御側=火 → 火条件成立 → 強化
	await _assert_defender_item(1063, "ガイアハンマー", 40, -40, 90, 20, "defender", ["強化"])

# ========================================
# 自ドミニオ数依存（owned_land_count_bonus）
# ========================================

func test_1019_tidal_armor_attacker():
	## 水+風ドミニオ数×20 → 水2+風0=2 → HP+40(item_bonus)
	await _assert_attacker_item(1019, "タイダルアーマー", 40, 50, 40, 20, "attacker_survived", [])

func test_1019_tidal_armor_defender():
	await _assert_defender_item(1019, "タイダルアーマー", 40, 10, 40, 50, "attacker_survived", [])

func test_1061_gaia_armor_attacker():
	## 火+地ドミニオ数×20 → 火2+地0=2 → HP+40(item_bonus)
	await _assert_attacker_item(1061, "ガイアアーマー", 40, 50, 40, 20, "attacker_survived", [])

func test_1061_gaia_armor_defender():
	await _assert_defender_item(1061, "ガイアアーマー", 40, 10, 40, 50, "attacker_survived", [])

# ========================================
# 配置クリーチャー数依存（element_count / same_element）
# ========================================

func test_1014_shade_edge_attacker():
	## 敵=火, 自ボード上の火クリ数=2 → AP+20
	await _assert_attacker_item(1014, "シェイドエッジ", 60, 50, 40, 0, "attacker", [])

func test_1014_shade_edge_defender():
	## 敵=水, 自ボード上の水クリ数=2 → AP+20
	await _assert_defender_item(1014, "シェイドエッジ", 40, -10, 60, 20, "defender", [])

func test_1023_tidal_halberd_attacker():
	## 水+風配置数×5=10 → AP50, 敵=火→強化成立 → AP75
	await _assert_attacker_item(1023, "タイダルハルバード", 75, 50, 40, -15, "attacker", ["強化"])

func test_1023_tidal_halberd_defender():
	## 水+風配置数×5=10 → AP50, 強化キーワード付与(条件判定はmock環境で常にtrue)、効果は未発動
	await _assert_defender_item(1023, "タイダルハルバード", 40, 0, 50, 20, "defender", ["強化"])

func test_1064_gaia_flail_attacker():
	## 火+地配置数×5=10 → AP50, 強化キーワード付与(条件判定はmock環境で常にtrue)、効果は未発動
	await _assert_attacker_item(1064, "ガイアフレイル", 50, 10, 40, 10, "attacker_survived", ["強化"])

func test_1064_gaia_flail_defender():
	## 火+地配置数×5=10 → AP50, 敵=水→強化成立 → AP75
	await _assert_defender_item(1064, "ガイアフレイル", 40, -25, 75, 20, "defender", ["強化"])

# ========================================
# 連鎖数依存（chain_count）
# ========================================

func test_1034_link_sword_attacker():
	## 戦闘地(タイル4=火)の連鎖数: pid=0の火タイル=2(タイル1,2) → AP+40
	await _assert_attacker_item(1034, "リンクソード", 80, 50, 40, -20, "attacker", [])

func test_1034_link_sword_defender():
	## 戦闘地(タイル4=火)の連鎖数: pid=1の火タイル=2(タイル3,4) → AP+40
	await _assert_defender_item(1034, "リンクソード", 40, -30, 80, 20, "defender", [])

# ========================================
# 巻物系（scroll land_count）
# ========================================

func test_1035_blizzard_rod_attacker():
	## 術攻撃: 水+風配置数×10=20, 敵=火→強化術成立→AP30, land_count巻物は反撃を受ける
	await _assert_attacker_item(1035, "ブリザードロッド", 30, 10, 40, 20, "attacker_survived", ["術攻撃", "強化術"])

func test_1035_blizzard_rod_defender():
	## 術攻撃: player_id=0の水+風配置数×10=20, 強化術キーワード付与(mock環境)、land_count巻物は反撃を受ける
	await _assert_defender_item(1035, "ブリザードロッド", 40, 30, 20, 20, "attacker_survived", ["術攻撃", "強化術"])

func test_1049_volcano_rod_attacker():
	## 術攻撃: 火+地配置数×10=20, 強化術キーワード付与(mock環境)、land_count巻物は反撃を受ける
	await _assert_attacker_item(1049, "ヴォルケーノロッド", 20, 10, 40, 30, "attacker_survived", ["術攻撃", "強化術"])

func test_1049_volcano_rod_defender():
	## 術攻撃: player_id=0の火+地配置数×10=20, 敵=水→強化術成立→AP30, land_count巻物は反撃を受ける
	await _assert_defender_item(1049, "ヴォルケーノロッド", 40, 20, 30, 20, "attacker_survived", ["術攻撃", "強化術"])


# ========================================
# 先制付与系
# ========================================

func test_1000_quick_charm_attacker():
	## AP+10, 先制 → 攻AP50先制→防HP60-50=10, 防→攻HP50-40=10
	await _assert_attacker_item(1000, "クイックチャーム", 50, 10, 40, 10, "attacker_survived", ["先制攻撃"])

func test_1000_quick_charm_defender():
	## 防AP50先制→攻HP50-50=0 撃破、反撃なし
	await _assert_defender_item(1000, "クイックチャーム", 40, 0, 50, 50, "defender", ["先制攻撃"])

func test_1003_wind_edge_attacker():
	## AP+30, 先制 → 攻AP70先制→防HP60-70=-10 撃破
	await _assert_attacker_item(1003, "ウィンドエッジ", 70, 50, 40, -10, "attacker", ["先制攻撃"])

func test_1003_wind_edge_defender():
	## 防AP70先制→攻HP50-70=-20 撃破、反撃なし
	await _assert_defender_item(1003, "ウィンドエッジ", 40, -20, 70, 50, "defender", ["先制攻撃"])

func test_1013_vampire_ring_attacker():
	## APドレイン(on_attack_success)+先制 → 攻AP40先制→防HP60-40=20, 防AP→0(ドレイン)→攻HP50
	await _assert_attacker_item(1013, "ヴァンパイアリング", 40, 50, 0, 20, "attacker_survived", ["先制攻撃"])

func test_1013_vampire_ring_defender():
	## 防AP40先制→攻HP50-40=10, 攻AP→0(ドレイン)→防HP50
	await _assert_defender_item(1013, "ヴァンパイアリング", 0, 10, 40, 50, "attacker_survived", ["先制攻撃"])

func test_1028_hand_crossbow_attacker():
	## AP+10, HP+10, 先制 → 攻AP50先制→防HP60-50=10, 防→攻item10消費,HP50-30=20
	await _assert_attacker_item(1028, "ハンドクロスボウ", 50, 20, 40, 10, "attacker_survived", ["先制攻撃"])

func test_1028_hand_crossbow_defender():
	## 防AP50先制→攻HP50-50=0 撃破、反撃なし
	await _assert_defender_item(1028, "ハンドクロスボウ", 40, 0, 50, 50, "defender", ["先制攻撃"])


# ========================================
# 手札数依存
# ========================================

func test_1055_knowledge_ring_attacker():
	## HP+手札5枚×10=50 → item_bonus_hp=50, 防AP40→item50消費, HP50残
	await _assert_attacker_item(1055, "ナレッジリング", 40, 50, 40, 20, "attacker_survived", [])

func test_1055_knowledge_ring_defender():
	## HP+手札5枚×10=50 → item_bonus_hp=50, 攻AP40→land10+item30消費, HP50残
	await _assert_defender_item(1055, "ナレッジリング", 40, 10, 40, 50, "attacker_survived", [])

# ========================================
# 条件付きスキル付与（条件判定検証済み）
# ========================================

func test_1022_tidal_spear_attacker():
	## AP+20, 水風使用時強化 → 攻=水→条件成立 → (40+20)×1.5=90
	await _assert_attacker_item(1022, "タイダルスピア", 90, 50, 40, -30, "attacker", ["強化"])

func test_1022_tidal_spear_defender():
	## 防=火→条件不成立 → AP=40+20=60（強化キーワードは付くが効果未発動）
	await _assert_defender_item(1022, "タイダルスピア", 40, -10, 60, 20, "defender", ["強化"])

func test_1015_phantom_blaze_attacker():
	## 術攻撃AP40, 同クリーチャー2体以上で強化術 → タイダルオーガ2体(タイル6,7)→成立 → 40×1.5=60
	await _assert_attacker_item(1015, "ファントムブレイズ", 60, 50, 40, -10, "attacker", ["術攻撃", "強化術"])

func test_1015_phantom_blaze_defender():
	## レッドオーガ2体(タイル3,4)→成立 → 40×1.5=60
	await _assert_defender_item(1015, "ファントムブレイズ", 40, -10, 60, 20, "defender", ["術攻撃", "強化術"])

# ========================================
# 変身アイテム
# ========================================

func test_1047_ghoul_blast_attacker():
	## グールブラスト: 術攻撃AP50+スケルトン変身 → 変身後も巻物AP50維持
	## スケルトンAP50(術攻撃)→土地ボーナス無効化 vs 防HP50=0、攻撃側勝利
	var r = await _battle_attacker_item(1047)
	assert_eq(r.attacker_name, "スケルトン", "グールブラスト(攻): 変身確認")
	assert_eq(r.attacker_final_ap, 50, "グールブラスト(攻): 攻AP")
	assert_eq(r.attacker_final_hp, 40, "グールブラスト(攻): 攻HP")
	assert_eq(r.defender_final_hp, 0, "グールブラスト(攻): 防HP")
	assert_eq(r.winner, "attacker", "グールブラスト(攻): 勝者")

func test_1047_ghoul_blast_defender():
	## 防御側スケルトン変身: AP50(術攻撃) → 攻AP40 vs 防スケルトンHP40=0、攻撃側先攻で勝利
	var r = await _battle_defender_item(1047)
	assert_eq(r.defender_name, "スケルトン", "グールブラスト(防): 変身確認")
	assert_eq(r.defender_final_ap, 50, "グールブラスト(防): 防AP")
	assert_eq(r.defender_final_hp, 0, "グールブラスト(防): 防HP")
	assert_eq(r.attacker_final_hp, 50, "グールブラスト(防): 攻HP")
	assert_eq(r.winner, "attacker", "グールブラスト(防): 勝者")

func test_1041_dragon_soul_both():
	## ドラゴンソウル: 両者装備 → 両方ランダムドラゴンに変身することを確認
	var config = _create_config()
	config.attacker_items = [1041]
	config.defender_items = [1041]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_ne(r.attacker_name, "タイダルオーガ", "ドラゴンソウル: 攻撃側変身確認")
	assert_ne(r.defender_name, "レッドオーガ", "ドラゴンソウル: 防御側変身確認")

# ========================================
# ランダムステータスアイテム
# ========================================

func test_1027_grow_mail_both():
	## グロウメイル: AP+HP+10~70ランダム → 両者装備で範囲内か確認
	## 攻撃側: base AP40 + 10~70 = 50~110
	## 防御側: base AP40 + 10~70 = 50~110
	var config = _create_config()
	config.attacker_items = [1027]
	config.defender_items = [1027]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# APが範囲内か（ランダムボーナス10~70がbase AP40に加算）
	assert_gte(r.attacker_final_ap, 50, "グロウメイル: 攻AP下限(40+10)")
	assert_lte(r.attacker_final_ap, 110, "グロウメイル: 攻AP上限(40+70)")
	assert_gte(r.defender_final_ap, 50, "グロウメイル: 防AP下限(40+10)")
	assert_lte(r.defender_final_ap, 110, "グロウメイル: 防AP上限(40+70)")

# ========================================
# 固定ステータス系
# ========================================

func test_1059_petrifact_attacker():
	## ペトリファクト: AP=0, HP=80(固定) → AP0攻撃、防AP40でitem40消費→攻HP40残
	await _assert_attacker_item(1059, "ペトリファクト", 0, 40, 40, 50, "attacker_survived", [])

func test_1059_petrifact_defender():
	## 防: AP=0, HP=80(固定) → 攻AP40でitem40消費→防HP50残
	await _assert_defender_item(1059, "ペトリファクト", 40, 50, 0, 50, "attacker_survived", [])

func test_1032_adamantite_attacker():
	## アダマンタイト: AP-30=10, HP+60 → 後手なので防AP40先攻、攻item60消費→攻HP50残、攻AP10→防HP50残
	await _assert_attacker_item(1032, "アダマンタイト", 10, 50, 40, 50, "attacker_survived", ["後手"])

func test_1032_adamantite_defender():
	## 防: AP-30=10, HP+60, 後手 → 攻AP40先攻→land10+item50消費→防HP50残、防AP10→攻HP40残
	await _assert_defender_item(1032, "アダマンタイト", 40, 40, 10, 50, "attacker_survived", ["後手"])

# ========================================
# 属性条件・レアリティ条件
# ========================================

func test_1057_spectral_wand_attacker():
	## スペクトルワンド: 敵と属性違い→AP&HP+40 → 水≠火→AP80, HP90→防HP-20
	await _assert_attacker_item(1057, "スペクトルワンド", 80, 50, 40, -20, "attacker", [])

func test_1057_spectral_wand_defender():
	## 防: 火≠水→AP80, HP90→攻HP-30
	await _assert_defender_item(1057, "スペクトルワンド", 40, -30, 80, 50, "defender", [])

func test_1056_commons_blade_attacker():
	## コモンズブレイド: AP+40, N使用時強化 → タイダルオーガ=N→(40+40)×1.5=120
	await _assert_attacker_item(1056, "コモンズブレイド", 120, 50, 40, -60, "attacker", ["強化"])

func test_1056_commons_blade_defender():
	## 防: レッドオーガ=N→(40+40)×1.5=120
	await _assert_defender_item(1056, "コモンズブレイド", 40, -70, 120, 20, "defender", ["強化"])

# ========================================
# 属性変化
# ========================================

func test_1045_chameleon_cloak_attacker():
	## カメレオンクローク: HP+40, 属性→無 → 攻HP50+item40=90、防AP40でitem40消費→攻HP50残
	await _assert_attacker_item(1045, "カメレオンクローク", 40, 50, 40, 20, "attacker_survived", [])

func test_1045_chameleon_cloak_defender():
	## 防: HP+40, 属性→無 → neutral属性は全属性一致→ランドボーナスHP+10維持
	## 防HP50+land10+item40=100→攻AP40でland10+item30消費→防HP50残
	await _assert_defender_item(1045, "カメレオンクローク", 40, 10, 40, 50, "attacker_survived", [])

# ========================================
# 相討
# ========================================

func test_1048_desperado_attacker():
	## デスペラード: AP&HP+20, 相討 → AP60→防HP0、相討は防死亡時に攻撃側を道連れ
	## ※現状: 攻撃側勝利（相討がbattle_resultに反映されていない可能性）
	await _assert_attacker_item(1048, "デスペラード", 60, 50, 40, 0, "attacker", [])

func test_1048_desperado_defender():
	## 防: AP60→攻HP-10、防御側勝利
	await _assert_defender_item(1048, "デスペラード", 40, -10, 60, 40, "defender", [])

# ========================================
# 条件不成立テスト（否定テスト）
# ========================================

func test_1048_desperado_on_death():
	## デスペラード相討テスト: 防御側装備者が倒された → on_death相討 → 攻撃側も死亡
	## 攻撃側: タイダルオーガAP40 + ツヴァイハンダーAP+50 = AP90 → 防HP60を超えて撃破
	## 防御側: レッドオーガ + デスペラード(AP+20,HP+20) → HP50+land10+item20=80
	## 攻AP90 → 防HP-10(死亡) → on_death相討 → 攻HP=0 → both_defeated
	var config = _create_config()
	config.attacker_items = [1009]  # ツヴァイハンダー(AP+50)で確実に撃破
	config.defender_items = [1048]  # デスペラード(相討)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, -10, "デスペラード相討(防装備): 防HP(死亡)")
	assert_eq(r.attacker_final_hp, 0, "デスペラード相討(防装備): 攻HP(相討で死亡)")
	assert_eq(r.winner, "both_defeated", "デスペラード相討(防装備): 両者死亡")

func test_1048_desperado_on_death_attacker():
	## デスペラード相討テスト: 攻撃側装備者が倒された → on_death相討 → 防御側も死亡
	## 攻撃側: タイダルオーガ + デスペラード(AP+20,HP+20) → AP60, HP70
	## 防御側: レッドオーガ + ガーディアンブレイド(AP+30,HP+30) → AP70, HP90(50+10+30)
	## 攻AP60 → 防HP90-60=30(生存) → 防AP70 → 攻HP70-70=0(死亡)
	## → on_death相討 → 防HP=0 → both_defeated
	var config = _create_config()
	config.attacker_items = [1048]  # デスペラード(相討)
	config.defender_items = [1008]  # ガーディアンブレイド(AP+30,HP+30)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 0, "デスペラード相討(攻装備): 攻HP(死亡)")
	assert_eq(r.defender_final_hp, 0, "デスペラード相討(攻装備): 防HP(相討で死亡)")
	assert_eq(r.winner, "both_defeated", "デスペラード相討(攻装備): 両者死亡")

func test_1046_resurrect_scarab_defender():
	## リザレクトスカラベ蘇生テスト: 防御側装備者が倒された → スケルトン(ID:420)に蘇生
	## 攻撃側: タイダルオーガAP40 + ツヴァイハンダーAP+50 = AP90 → 防HP60を超えて撃破
	## 防御側: レッドオーガ + リザレクトスカラベ → 撃破後スケルトンとして蘇生
	## 蘇生後: スケルトン(AP30, HP40) → defender_name変更、alive
	var config = _create_config()
	config.attacker_items = [1009]  # ツヴァイハンダー(AP+50)で確実に撃破
	config.defender_items = [1046]  # リザレクトスカラベ(蘇生[スケルトン])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_name, "スケルトン", "リザレクトスカラベ(防): 蘇生後の名前")
	assert_eq(r.winner, "attacker_survived", "リザレクトスカラベ(防): 蘇生→戦闘終了(survived)")

func test_1046_resurrect_scarab_attacker():
	## リザレクトスカラベ蘇生テスト: 攻撃側装備者が倒された → スケルトンに蘇生
	## 攻撃側: タイダルオーガ + リザレクトスカラベ → 防御側に倒される
	## 防御側: レッドオーガ + ツヴァイハンダーAP+50 = AP90 → 攻HP50を超えて撃破
	## 攻撃側死亡 → on_death蘇生 → attacker_name=スケルトン
	var config = _create_config()
	config.attacker_items = [1046]  # リザレクトスカラベ(蘇生[スケルトン])
	config.defender_items = [1009]  # ツヴァイハンダー(AP+50)で確実に撃破
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_name, "スケルトン", "リザレクトスカラベ(攻): 蘇生後の名前")

# ========================================
# 術攻撃無効化 (ルーンシールド 1065)
# ========================================

func test_1065_rune_shield_vs_item_scroll():
	## ルーンシールド vs ライトニングオーブ(術攻撃AP40)
	## 防: レッドオーガ + ルーンシールド(HP+30) → 術攻撃無効 → ダメージ0
	## 防HP: 50+10(land)+30(item)=90 → 攻ダメージ0 → current_hp=50
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_items = [1024]  # ライトニングオーブ(術攻撃AP40)
	config.defender_items = [1065]  # ルーンシールド(HP+30, 無効化[巻物])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 40, "ルーンシールドvsアイテム巻物: 攻AP")
	assert_eq(r.attacker_final_hp, 10, "ルーンシールドvsアイテム巻物: 攻HP")
	assert_eq(r.defender_final_hp, 50, "ルーンシールドvsアイテム巻物: 防HP(術攻撃無効)")
	assert_eq(r.winner, "attacker_survived", "ルーンシールドvsアイテム巻物: 勝者")

func test_1065_rune_shield_vs_creature_scroll():
	## ルーンシールド vs パイロコーラー(ID:12, 強化術, base_ap→AP20×1.5=30)
	## 防: レッドオーガ + ルーンシールド(HP+30) → 術攻撃無効 → ダメージ0
	## 防HP current_hp=50のまま
	## 防AP40 → 攻HP30-40=-10 → 攻死亡
	var config = _create_config()
	config.attacker_creatures = [12]  # パイロコーラー(火, AP20/HP30, 強化術)
	config.defender_items = [1065]  # ルーンシールド
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 30, "ルーンシールドvsクリ術攻撃: 攻AP(強化術20×1.5)")
	assert_eq(r.attacker_final_hp, -10, "ルーンシールドvsクリ術攻撃: 攻HP")
	assert_eq(r.defender_final_hp, 50, "ルーンシールドvsクリ術攻撃: 防HP(術攻撃無効)")
	assert_eq(r.winner, "defender", "ルーンシールドvsクリ術攻撃: 勝者")

func test_1065_rune_shield_vs_creature_scroll_attack():
	## ルーンシールド vs ウィスプ(ID:34, 火, AP30/HP50, 術攻撃[AP30])
	## 防: ルーンシールド → 術攻撃無効 → ダメージ0
	## 防HP current_hp=50のまま
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_creatures = [34]  # ウィスプ(火, AP30/HP50, 術攻撃[AP30])
	config.defender_items = [1065]  # ルーンシールド
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 30, "ルーンシールドvsクリ術攻撃: 攻AP")
	assert_eq(r.attacker_final_hp, 10, "ルーンシールドvsクリ術攻撃: 攻HP")
	assert_eq(r.defender_final_hp, 50, "ルーンシールドvsクリ術攻撃: 防HP(術攻撃無効)")
	assert_eq(r.winner, "attacker_survived", "ルーンシールドvsクリ術攻撃: 勝者")

# ========================================
# 術攻撃反射 (ミラーシールド 1069)
# ========================================

func test_1069_mirror_shield_vs_item_scroll():
	## ミラーシールド vs ライトニングオーブ(術攻撃AP40)
	## 防: レッドオーガ + ミラーシールド(HP+20) → 術攻撃反射(100%, self_damage=0)
	## 防HP: current_hp=50(self_damage=0でダメージなし)
	## 反射ダメージ40 → 攻HP50-40=10、さらに防AP40 → 攻HP10-40=-30
	var config = _create_config()
	config.attacker_items = [1024]  # ライトニングオーブ(術攻撃AP40)
	config.defender_items = [1069]  # ミラーシールド(HP+20, 反射[巻物])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 40, "ミラーシールドvsアイテム巻物: 攻AP")
	assert_eq(r.attacker_final_hp, -30, "ミラーシールドvsアイテム巻物: 攻HP(反射+カウンター)")
	assert_eq(r.defender_final_hp, 50, "ミラーシールドvsアイテム巻物: 防HP(self_damage=0)")
	assert_eq(r.winner, "defender", "ミラーシールドvsアイテム巻物: 勝者")

func test_1069_mirror_shield_vs_creature_scroll():
	## ミラーシールド vs パイロコーラー(強化術AP30)
	## 反射ダメージ30 → 攻HP30-30=0 → 攻死亡（カウンター不要）
	var config = _create_config()
	config.attacker_creatures = [12]  # パイロコーラー(火, AP20/HP30, 強化術)
	config.defender_items = [1069]  # ミラーシールド
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 30, "ミラーシールドvsクリ術攻撃: 攻AP(強化術)")
	assert_eq(r.attacker_final_hp, 0, "ミラーシールドvsクリ術攻撃: 攻HP(反射で死亡)")
	assert_eq(r.defender_final_hp, 50, "ミラーシールドvsクリ術攻撃: 防HP(self_damage=0)")
	assert_eq(r.winner, "defender", "ミラーシールドvsクリ術攻撃: 勝者")

func test_1069_mirror_shield_vs_creature_scroll_attack():
	## ミラーシールド vs ウィスプ(ID:34, 火, AP30/HP50, 術攻撃[AP30])
	## 反射ダメージ30 → 攻HP50-30=20、防AP40 → 攻HP20-40=-20
	var config = _create_config()
	config.attacker_creatures = [34]  # ウィスプ(火, AP30/HP50, 術攻撃[AP30])
	config.defender_items = [1069]  # ミラーシールド
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 30, "ミラーシールドvsクリ術攻撃: 攻AP")
	assert_eq(r.attacker_final_hp, -20, "ミラーシールドvsクリ術攻撃: 攻HP(反射+カウンター)")
	assert_eq(r.defender_final_hp, 50, "ミラーシールドvsクリ術攻撃: 防HP(self_damage=0)")
	assert_eq(r.winner, "defender", "ミラーシールドvsクリ術攻撃: 勝者")

func test_1065_rune_shield_vs_normal_attack():
	## ルーンシールド vs 通常攻撃（ツヴァイハンダーAP+50）
	## 通常攻撃は無効化されない → 防御側にダメージが入る
	## 攻AP90 → 防HP50+10(land)+30(item)=90 → 90-90=0 → 防死亡、カウンターなし
	var config = _create_config()
	config.attacker_items = [1009]  # ツヴァイハンダー(AP+50、通常攻撃)
	config.defender_items = [1065]  # ルーンシールド(HP+30, 無効化[巻物])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 50, "ルーンシールドvs通常攻撃: 攻HP(カウンターなし)")
	assert_eq(r.defender_final_hp, 0, "ルーンシールドvs通常攻撃: 防HP(通常攻撃は無効化されない)")
	assert_eq(r.winner, "attacker", "ルーンシールドvs通常攻撃: 勝者")

func test_1069_mirror_shield_vs_normal_attack():
	## ミラーシールド vs 通常攻撃（ツヴァイハンダーAP+50）
	## 通常攻撃は反射されない → 通常通りダメージ処理
	## 攻AP90 → 防HP50+10(land)+20(item)=80 → 80-90=-10 → 防死亡、カウンターなし
	var config = _create_config()
	config.attacker_items = [1009]  # ツヴァイハンダー(AP+50、通常攻撃)
	config.defender_items = [1069]  # ミラーシールド(HP+20, 反射[巻物])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 50, "ミラーシールドvs通常攻撃: 攻HP(反射なし)")
	assert_eq(r.defender_final_hp, -10, "ミラーシールドvs通常攻撃: 防HP(通常ダメージ)")
	assert_eq(r.winner, "attacker", "ミラーシールドvs通常攻撃: 勝者")

# ========================================
# アイテム破壊 (イビルアイ 1010, ブレイクアーマー 1072)
# ========================================

func test_1010_evil_eye_destroy_r_weapon():
	## イビルアイ → 敵のコロッサルソード(R武器, AP+60,HP-30)を破壊
	## 攻: タイダルオーガ + イビルアイ(ステータスなし) → AP40
	## 防: レッドオーガ + コロッサルソード(R) → 破壊される → AP40に戻る
	## 攻AP40 → 防HP60(50+10) → 防HP20残
	## 防AP40 → 攻HP50 → 攻HP10残
	var config = _create_config()
	config.attacker_items = [1010]  # イビルアイ(アイテム破壊[N以外])
	config.defender_items = [1020]  # コロッサルソード(R, AP+60,HP-30)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 40, "イビルアイvsR武器: 防AP(破壊されて素AP)")
	assert_eq(r.winner, "attacker_survived", "イビルアイvsR武器: 勝者(互いに生存)")

func test_1010_evil_eye_no_destroy_n_weapon():
	## イビルアイ → 敵のガーディアンブレイド(N武器, AP+30,HP+30)は破壊されない
	## 防: レッドオーガ + ガーディアンブレイド(N) → 破壊されず → AP70維持
	var config = _create_config()
	config.attacker_items = [1010]  # イビルアイ
	config.defender_items = [1008]  # ガーディアンブレイド(N, AP+30,HP+30)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 70, "イビルアイvsN武器: 防AP(Nは破壊されない)")
	assert_eq(r.winner, "defender", "イビルアイvsN武器: 勝者")

func test_1072_break_armor_destroy_weapon():
	## ブレイクアーマー → 敵のツヴァイハンダー(武器, AP+50)を破壊
	## 攻: タイダルオーガ → AP40
	## 防: レッドオーガ + ブレイクアーマー(HP+30) → 敵の武器破壊
	## 攻の武器は持っていない、防に武器破壊を持たせて攻に武器を持たせる
	## → 逆: 攻にツヴァイハンダー、防にブレイクアーマー
	## 防がブレイクアーマーで攻の武器を破壊 → 攻AP40に戻る
	var config = _create_config()
	config.attacker_items = [1009]  # ツヴァイハンダー(N, 武器, AP+50)
	config.defender_items = [1072]  # ブレイクアーマー(HP+30, 武器破壊)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 40, "ブレイクアーマーvs武器: 攻AP(武器破壊された)")
	assert_eq(r.winner, "attacker_survived", "ブレイクアーマーvs武器: 勝者")

func test_1072_break_armor_no_destroy_armor():
	## ブレイクアーマー → 敵のブリガンダイン(防具, HP+40)は破壊されない
	## 防がブレイクアーマーで攻の防具を破壊しようとするが、防具は対象外
	var config = _create_config()
	config.attacker_items = [1018]  # ブリガンダイン(N, 防具, HP+40)
	config.defender_items = [1072]  # ブレイクアーマー(HP+30, 武器破壊)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 50, "ブレイクアーマーvs防具: 攻HP(防具は破壊されない)")
	assert_eq(r.winner, "attacker_survived", "ブレイクアーマーvs防具: 勝者")

func test_1010_evil_eye_vs_sacred_cape():
	## イビルアイ → セイクリッドケープ(S防具, HP+40, 破壊無効)は破壊されない
	## 防: セイクリッドケープ → nullify_item_manipulationで破壊無効
	var config = _create_config()
	config.attacker_items = [1010]  # イビルアイ(アイテム破壊[N以外])
	config.defender_items = [1006]  # セイクリッドケープ(S, HP+40, 破壊無効)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 50, "イビルアイvs破壊無効: 防HP(HP+40が維持)")
	assert_eq(r.winner, "attacker_survived", "イビルアイvs破壊無効: 勝者")

func test_thief_steal_success():
	## シーフ(ID:416)のアイテム盗み → ツヴァイハンダー(S武器)を盗む
	## 攻: シーフ(AP20/HP40) → 盗み成功で防のAP+50消失
	## 防: レッドオーガ + ツヴァイハンダー(S) → 盗まれてAP40に戻る
	var config = _create_config()
	config.attacker_creatures = [416]  # シーフ(無, AP20/HP40, アイテム盗み)
	config.defender_items = [1009]  # ツヴァイハンダー(S, AP+50)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 40, "シーフ盗み成功: 防AP(盗まれて素AP)")

func test_thief_steal_vs_gravestone():
	## シーフのアイテム盗み → グレイブストーン(破壊・盗み無効)で盗めない
	## 防: レッドオーガ + グレイブストーン → nullify_item_manipulationで盗み無効
	## グレイブストーンにステータスボーナスなし → 基準値と同一だが盗まれていない
	## 対比: 上のtest_thief_steal_successで盗み自体は機能することを確認済み
	var config = _create_config()
	config.attacker_creatures = [416]  # シーフ(無, AP20/HP40, アイテム盗み)
	config.defender_items = [1038]  # グレイブストーン(N, 破壊・盗み無効)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 40, "シーフvsグレイブストーン: 防AP(盗めない)")
	assert_eq(r.winner, "defender", "シーフvsグレイブストーン: 勝者")

func test_1056_commons_blade_non_n_rarity():
	## コモンズブレイド: N使用時のみ強化 → Sレアリティでは強化なし、AP+40のみ
	## エターナガード(ID:14, 火, S, AP40/HP40) vs レッドオーガ(ID:48, 火, N, AP40/HP50)
	## 攻: AP40+40=80, HP40 → 防AP40ダメージ → 攻HP0
	## 防: AP40, HP50+land10=60 → 攻AP80ダメージ → 防HP-20
	## 攻は先に殴る → 防HP-20 → 防死亡、攻はHP40-40=0 → 相打ち→攻撃者勝利
	var config = _create_config()
	config.attacker_creatures = [14]  # エターナガード（火, S, AP40/HP40）
	config.attacker_items = [1056]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 80, "コモンズブレイド(S): 攻AP(強化なし)")
	assert_eq(r.attacker_granted_skills, [], "コモンズブレイド(S): 強化未付与")

# ========================================
# マサムネ (1068) vs 反射・無効化アイテム
# ========================================

func test_1068_masamune_vs_thorn_shield():
	## マサムネ vs ソーンシールド(反射[1/2]) → 反射が無効化される（肯定テスト）
	## 攻: タイダルオーガ + マサムネ(AP+20) → AP60
	## 防: レッドオーガ + ソーンシールド(反射[1/2]) → AP40, HP60(50+land10)
	## マサムネのnullify_reflect → 反射無効 → 防は全ダメージ60受ける → HP0死亡
	var config = _create_config()
	config.attacker_items = [1068]  # マサムネ(AP+20, 反射・無効化無効)
	config.defender_items = [1025]  # ソーンシールド(反射[1/2])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 60, "マサムネvsソーンシールド: 攻AP(AP+20)")
	assert_eq(r.attacker_final_hp, 50, "マサムネvsソーンシールド: 攻HP(反射無効→カウンターなし)")
	assert_eq(r.defender_final_hp, 0, "マサムネvsソーンシールド: 防HP(全ダメージ受けて死亡)")
	assert_eq(r.winner, "attacker", "マサムネvsソーンシールド: 勝者")

func test_no_masamune_vs_thorn_shield():
	## ソーンシールド反射発動確認（否定テスト：マサムネなし）
	## 攻: タイダルオーガ(素) → AP40
	## 防: レッドオーガ + ソーンシールド → AP40, HP60
	## 反射[1/2]: 攻ダメージ40 → 防self_damage=20, 攻reflect_damage=20
	## 防HP: 60-20=40(land10吸収→current_hp=40)
	## 攻HP: 50-20(反射)-40(カウンター)=-10 → 死亡
	var config = _create_config()
	config.defender_items = [1025]  # ソーンシールド(反射[1/2])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, -10, "ソーンシールド反射発動: 攻HP(反射20+カウンター40)")
	assert_eq(r.defender_final_hp, 40, "ソーンシールド反射発動: 防HP(half damage)")
	assert_eq(r.winner, "defender", "ソーンシールド反射発動: 勝者")

func test_1068_masamune_vs_gaia_shield():
	## マサムネ vs ガイアシールド(火地使用時 無効化[通常攻撃]) → 無効化が無効化される（肯定テスト）
	## 攻: タイダルオーガ + マサムネ(AP+20) → AP60
	## 防: レッドオーガ(火) + ガイアシールド → 火属性なので無効化条件成立
	## マサムネのnullify_triggers["nullify"] → 無効化を無効化 → 通常ダメージ
	## AP60 → 防HP60(50+land10)-60=0 → 死亡
	var config = _create_config()
	config.attacker_items = [1068]  # マサムネ
	config.defender_items = [1062]  # ガイアシールド(火地使用時 無効化[通常攻撃])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 60, "マサムネvsガイアシールド: 攻AP")
	assert_eq(r.attacker_final_hp, 50, "マサムネvsガイアシールド: 攻HP(カウンターなし)")
	assert_eq(r.defender_final_hp, 0, "マサムネvsガイアシールド: 防HP(無効化が無効化)")
	assert_eq(r.winner, "attacker", "マサムネvsガイアシールド: 勝者")

func test_no_masamune_vs_gaia_shield():
	## ガイアシールド無効化発動確認（否定テスト：マサムネなし）
	## 攻: タイダルオーガ(素) → AP40
	## 防: レッドオーガ(火) + ガイアシールド → 火属性で無効化[通常攻撃]発動
	## 攻のダメージ0 → 防HP無傷(current_hp=50)
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.defender_items = [1062]  # ガイアシールド
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "ガイアシールド無効化発動: 攻HP(カウンターのみ)")
	assert_eq(r.defender_final_hp, 50, "ガイアシールド無効化発動: 防HP(通常攻撃無効)")
	assert_eq(r.winner, "attacker_survived", "ガイアシールド無効化発動: 勝者")

func test_1068_masamune_vs_mirror_shield():
	## マサムネ vs ミラーシールド(反射[巻物]) → 通常攻撃なので元々反射しない確認（肯定テスト）
	## 攻: タイダルオーガ + マサムネ(AP+20) → AP60
	## 防: レッドオーガ + ミラーシールド(HP+20) → AP40, HP80(50+land10+item20)
	## マサムネがreflect無効化するが、巻物反射は通常攻撃に関係なし
	## AP60 → 防HP80-60=20(land10+item20吸収→current_hp=20)
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_items = [1068]  # マサムネ
	config.defender_items = [1069]  # ミラーシールド(HP+20, 反射[巻物])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "マサムネvsミラーシールド: 攻HP(カウンターのみ)")
	assert_eq(r.defender_final_hp, 20, "マサムネvsミラーシールド: 防HP(通常ダメージ)")
	assert_eq(r.winner, "attacker_survived", "マサムネvsミラーシールド: 勝者")

func test_no_masamune_vs_mirror_shield():
	## ミラーシールド vs 通常攻撃（否定テスト：マサムネなし、通常攻撃は反射されない）
	## 攻: タイダルオーガ(素) → AP40
	## 防: レッドオーガ + ミラーシールド(HP+20) → AP40, HP80
	## 巻物反射は通常攻撃に発動しない → 通常ダメージ処理
	## AP40 → 防HP80-40=40(land10吸収→current_hp=40)
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.defender_items = [1069]  # ミラーシールド
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "ミラーシールドvs通常攻撃(否定): 攻HP")
	assert_eq(r.defender_final_hp, 40, "ミラーシールドvs通常攻撃(否定): 防HP(反射なし)")
	assert_eq(r.winner, "attacker_survived", "ミラーシールドvs通常攻撃(否定): 勝者")

# ========================================
# タイダルシールド (1021) - 水風使用時 無効化[通常攻撃]
# ========================================

func test_1021_tidal_shield_attacker():
	## タイダルシールド: 攻撃側(水)装備 → 水条件成立 → 無効化発動（肯定テスト）
	## 攻: タイダルオーガ(水) + タイダルシールド → 無効化[通常攻撃] → 防カウンター無効
	## 攻AP40 → 防HP60-40=20(current_hp=40)
	## 防AP40 → 無効化 → 攻HP50のまま
	var config = _create_config()
	config.attacker_items = [1021]  # タイダルシールド(水風使用時 無効化[通常攻撃])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 50, "タイダルシールド(攻/水): 攻HP(カウンター無効化)")
	assert_eq(r.defender_final_hp, 20, "タイダルシールド(攻/水): 防HP(通常ダメージ)")
	assert_eq(r.attacker_granted_skills, ["無効化"], "タイダルシールド(攻/水): 無効化付与")
	assert_eq(r.winner, "attacker_survived", "タイダルシールド(攻/水): 勝者")

func test_1021_tidal_shield_defender():
	## タイダルシールド: 防御側(火)装備 → 水風条件不成立 → 無効化なし（否定テスト）
	## レッドオーガは火属性 → 水風に該当しない → 通常戦闘
	var config = _create_config()
	config.defender_items = [1021]  # タイダルシールド
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "タイダルシールド(防/火): 攻HP(通常戦闘)")
	assert_eq(r.defender_final_hp, 20, "タイダルシールド(防/火): 防HP(通常戦闘)")
	assert_eq(r.defender_granted_skills, [], "タイダルシールド(防/火): 無効化なし")
	assert_eq(r.winner, "attacker_survived", "タイダルシールド(防/火): 勝者")

# ========================================
# パリィシールド (1052) - 無効化[AP30以下]
# ========================================

func test_1052_parry_shield_ap_below():
	## パリィシールド: 防装備 vs ゴブリン(AP20) → AP20≤30で無効化発動（肯定テスト）
	## 攻: ゴブリン(ID:414, 無, AP20/HP30) → base AP20 ≤ 30 → 無効化
	## 攻ダメージ0 → 防HP50(current_hp)
	## 防AP40 → 攻HP30-40=-10 → 攻死亡
	var config = _create_config()
	config.attacker_creatures = [414]  # ゴブリン(無, AP20/HP30)
	config.defender_items = [1052]  # パリィシールド(無効化[AP30以下])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 50, "パリィシールドvsAP20: 防HP(無効化)")
	assert_eq(r.attacker_final_hp, -10, "パリィシールドvsAP20: 攻HP(カウンターで死亡)")
	assert_eq(r.winner, "defender", "パリィシールドvsAP20: 勝者")

func test_1052_parry_shield_ap_above():
	## パリィシールド: 防装備 vs タイダルオーガ(AP40) → AP40>30で無効化なし（否定テスト）
	## 通常戦闘: 攻AP40→防HP20(current_hp), 防AP40→攻HP10
	var config = _create_config()
	config.defender_items = [1052]  # パリィシールド(無効化[AP30以下])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "パリィシールドvsAP40: 攻HP(無効化なし)")
	assert_eq(r.defender_final_hp, 20, "パリィシールドvsAP40: 防HP(通常ダメージ)")
	assert_eq(r.winner, "attacker_survived", "パリィシールドvsAP40: 勝者")

# ========================================
# ヘクスシール (1071) - 無効化[巻物] + 無効化[自分よりAP大]
# ========================================

func test_1071_hex_seal_vs_scroll():
	## ヘクスシール: 防装備 vs 巻物攻撃 → 巻物無効化発動（肯定テスト1）
	## 攻: タイダルオーガ + ライトニングオーブ(術攻撃AP40) → scroll_attack → 無効化
	## 攻ダメージ0 → 防HP50(current_hp)
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_items = [1024]  # ライトニングオーブ(術攻撃AP40)
	config.defender_items = [1071]  # ヘクスシール
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 50, "ヘクスシールvs巻物: 防HP(無効化)")
	assert_eq(r.attacker_final_hp, 10, "ヘクスシールvs巻物: 攻HP(カウンター)")
	assert_eq(r.winner, "attacker_survived", "ヘクスシールvs巻物: 勝者")

func test_1071_hex_seal_vs_high_ap():
	## ヘクスシール: 防装備 vs ヘルハウンド(AP60) → AP60>40で無効化発動（肯定テスト2）
	## 攻: ヘルハウンド(ID:8, 火, AP60/HP50) → base AP60 > 防base AP40 → 無効化
	## 攻ダメージ0 → 防HP50(current_hp)
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_creatures = [8]  # ヘルハウンド(火, AP60/HP50)
	config.defender_items = [1071]  # ヘクスシール
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 50, "ヘクスシールvsAP60: 防HP(無効化)")
	assert_eq(r.attacker_final_hp, 10, "ヘクスシールvsAP60: 攻HP(カウンター)")
	assert_eq(r.winner, "attacker_survived", "ヘクスシールvsAP60: 勝者")

func test_1071_hex_seal_vs_normal():
	## ヘクスシール: 防装備 vs 通常攻撃(AP40=AP40) → 両条件不成立で無効化なし（否定テスト）
	## 攻: タイダルオーガ(AP40, 通常攻撃) → not scroll, AP40 not > AP40 → 無効化なし
	## 通常戦闘: 攻AP40→防HP20, 防AP40→攻HP10
	var config = _create_config()
	config.defender_items = [1071]  # ヘクスシール
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "ヘクスシールvs通常: 攻HP(無効化なし)")
	assert_eq(r.defender_final_hp, 20, "ヘクスシールvs通常: 防HP(通常ダメージ)")
	assert_eq(r.winner, "attacker_survived", "ヘクスシールvs通常: 勝者")

# ========================================
# フロストクレスト (1031) - 即死[水地60%] + 無効化[水地]
# ========================================

func test_1031_frost_crest_vs_water():
	## フロストクレスト: 防装備 vs 水属性 → 即死付与+無効化発動（肯定テスト）
	## 攻: タイダルオーガ(水) → 水 in [水,地] → 無効化発動(確定), 即死判定(60%・非決定)
	## 無効化 → 攻ダメージ0 → 防HP50(current_hp) は確定
	## 即死は確率のためattacker_hp/winnerは非決定的→assertしない
	var config = _create_config()
	config.defender_items = [1031]  # フロストクレスト(即死[水地60%]+無効化[水地])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_true("即死" in r.defender_granted_skills, "フロストクレストvs水: 即死スキル付与")
	assert_true("無効化" in r.defender_granted_skills, "フロストクレストvs水: 無効化スキル付与")
	assert_eq(r.defender_final_hp, 50, "フロストクレストvs水: 防HP(無効化で無傷)")

func test_1031_frost_crest_vs_fire():
	## フロストクレスト: 防装備 vs 火属性 → 条件不成立で通常戦闘（否定テスト）
	## 攻: レッドオーガ(火) → 火 not in [水,地] → 即死/無効化とも発動せず
	## 通常戦闘: 攻AP40→防HP20, 防AP40→攻HP10
	var config = _create_config()
	config.attacker_creatures = [48]  # レッドオーガ(火, AP40/HP50)
	config.defender_items = [1031]  # フロストクレスト
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "フロストクレストvs火: 攻HP(通常戦闘)")
	assert_eq(r.defender_final_hp, 20, "フロストクレストvs火: 防HP(通常ダメージ)")
	assert_eq(r.winner, "attacker_survived", "フロストクレストvs火: 勝者")

# ========================================
# フレイムクレスト (1039) - 即死[火風60%] + 無効化[火風]
# ========================================

func test_1039_flame_crest_vs_fire():
	## フレイムクレスト: 防装備 vs 火属性 → 即死付与+無効化発動（肯定テスト）
	## 攻: レッドオーガ(火) → 火 in [火,風] → 無効化発動(確定), 即死判定(60%・非決定)
	## 無効化 → 攻ダメージ0 → 防HP50(current_hp) は確定
	var config = _create_config()
	config.attacker_creatures = [48]  # レッドオーガ(火, AP40/HP50)
	config.defender_items = [1039]  # フレイムクレスト(即死[火風60%]+無効化[火風])
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_true("即死" in r.defender_granted_skills, "フレイムクレストvs火: 即死スキル付与")
	assert_true("無効化" in r.defender_granted_skills, "フレイムクレストvs火: 無効化スキル付与")
	assert_eq(r.defender_final_hp, 50, "フレイムクレストvs火: 防HP(無効化で無傷)")

func test_1039_flame_crest_vs_water():
	## フレイムクレスト: 防装備 vs 水属性 → 条件不成立で通常戦闘（否定テスト）
	## 攻: タイダルオーガ(水) → 水 not in [火,風] → 即死/無効化とも発動せず
	## 通常戦闘: 攻AP40→防HP20, 防AP40→攻HP10
	var config = _create_config()
	config.defender_items = [1039]  # フレイムクレスト
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "フレイムクレストvs水: 攻HP(通常戦闘)")
	assert_eq(r.defender_final_hp, 20, "フレイムクレストvs水: 防HP(通常ダメージ)")
	assert_eq(r.winner, "attacker_survived", "フレイムクレストvs水: 勝者")

# ========================================
# サイレントローブ (1017) - HP+40, 敵の攻撃成功時能力無効
# ========================================

func test_1017_silent_robe_vs_vampire_ring():
	## サイレントローブ vs ヴァンパイアリング(APドレイン) → APドレイン無効化
	## 攻: タイダルオーガ + ヴァンパイアリング(先制, APドレイン[on_attack_success])
	## 防: レッドオーガ + サイレントローブ(HP+40) → nullify on_attack_success
	## 先制 → 攻AP40 → 防HP100(50+10land+40item) → land10+item30吸収 → current_hp=50
	## APドレイン無効化 → 防AP40のまま
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_items = [1013]  # ヴァンパイアリング(先制+APドレイン)
	config.defender_items = [1017]  # サイレントローブ(HP+40, on_attack_success無効)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 40, "サイレントローブvsAPドレイン: 防AP(ドレイン無効化)")
	assert_eq(r.defender_final_hp, 50, "サイレントローブvsAPドレイン: 防HP(current_hp)")
	assert_eq(r.attacker_final_hp, 10, "サイレントローブvsAPドレイン: 攻HP(カウンター)")
	assert_eq(r.winner, "attacker_survived", "サイレントローブvsAPドレイン: 勝者")

func test_1017_silent_robe_vs_copy_spike():
	## サイレントローブ vs コピースパイク(変質[on_attack_success]) → 変質無効化
	## 攻: タイダルオーガ + コピースパイク(AP+20) → AP60
	## 防: レッドオーガ + サイレントローブ(HP+40) → nullify on_attack_success
	## 攻AP60 → 防HP100 → land10+item40吸収 → current_hp=40
	## 変質無効化 → 防はレッドオーガのまま
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_items = [1036]  # コピースパイク(AP+20, 変質)
	config.defender_items = [1017]  # サイレントローブ(HP+40, on_attack_success無効)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_name, "レッドオーガ", "サイレントローブvs変質: 防名前(変質されない)")
	assert_eq(r.defender_final_hp, 40, "サイレントローブvs変質: 防HP")
	assert_eq(r.attacker_final_hp, 10, "サイレントローブvs変質: 攻HP")
	assert_eq(r.winner, "attacker_survived", "サイレントローブvs変質: 勝者")

func test_1017_silent_robe_vs_curse_whip():
	## サイレントローブ vs カースウィップ(刻印[消沈]) → 消沈無効化で反撃可能
	## 攻: タイダルオーガ + カースウィップ(AP+30) → AP70 → 先制なし
	## 防: レッドオーガ + サイレントローブ(HP+40) → nullify on_attack_success
	## 攻AP70 → 防HP100(50+10land+40item) → land10+item40吸収 → current_hp=30
	## 消沈無効化 → 防は反撃可能 → 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_items = [1050]  # カースウィップ(AP+30, 刻印[消沈])
	config.defender_items = [1017]  # サイレントローブ(HP+40, on_attack_success無効)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 10, "サイレントローブvs消沈: 攻HP(反撃を受ける)")
	assert_eq(r.defender_final_hp, 30, "サイレントローブvs消沈: 防HP")
	assert_eq(r.winner, "attacker_survived", "サイレントローブvs消沈: 勝者")

func test_1050_curse_whip_no_silent_robe():
	## カースウィップ消沈発動確認（サイレントローブなし）→ 防御側反撃不可
	## 攻: タイダルオーガ + カースウィップ(AP+30) → AP70
	## 防: レッドオーガ(アイテムなし) → HP60(50+10land)
	## 攻AP70 → 防HP60-70=-10 → 防死亡 → 反撃なし（そもそも死亡）
	## ※ 防が生存するシナリオでないと消沈は発動しない
	## → 防にブリガンダイン(HP+40)を持たせる: HP100 → 攻AP70で HP30生存 → 消沈発動 → 反撃不可
	var config = _create_config()
	config.attacker_items = [1050]  # カースウィップ(AP+30, 刻印[消沈])
	config.defender_items = [1018]  # ブリガンダイン(HP+40)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 50, "カースウィップ消沈発動: 攻HP(反撃不可→無傷)")
	assert_eq(r.defender_final_hp, 30, "カースウィップ消沈発動: 防HP")
	assert_eq(r.winner, "attacker_survived", "カースウィップ消沈発動: 勝者")

func test_1067_curse_saber_applies_curse():
	## カースセイバー: 攻撃成功時 刻印[免罪] が付与される
	## 攻: タイダルオーガ + カースセイバー(AP+30) → AP70
	## 防: レッドオーガ(アイテムなし) → 攻AP70で死亡するため防にHP+40持たせる
	## 防にブリガンダイン(HP+40): HP100 → 攻AP70 → HP30生存 → 刻印[免罪]付与
	var config = _create_config()
	config.attacker_items = [1067]  # カースセイバー(AP+30, 刻印[免罪])
	config.defender_items = [1018]  # ブリガンダイン(HP+40) ※生存させるため
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_curse.get("curse_type", ""), "creature_toll_disable", "カースセイバー: 刻印タイプ")
	assert_eq(r.defender_curse.get("name", ""), "免罪", "カースセイバー: 刻印名")

func test_1017_silent_robe_vs_curse_saber():
	## サイレントローブ vs カースセイバー(刻印[免罪]) → 刻印無効化
	## 攻: タイダルオーガ + カースセイバー(AP+30) → AP70
	## 防: レッドオーガ + サイレントローブ(HP+40) → nullify on_attack_success
	## 攻AP70 → 防HP100 → 生存 → 刻印無効化 → curse空
	var config = _create_config()
	config.attacker_items = [1067]  # カースセイバー(AP+30, 刻印[免罪])
	config.defender_items = [1017]  # サイレントローブ(HP+40, on_attack_success無効)
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_curse, {}, "サイレントローブvs免罪: 刻印なし(無効化)")

func test_1050_curse_whip_overwrites_existing_curse():
	## カースウィップ: 既存の刻印[免罪]を刻印[消沈]に上書き
	## 防: レッドオーガ + ブリガンダイン(HP+40) + 事前刻印[免罪]
	## 攻: タイダルオーガ + カースウィップ(AP+30, 刻印[消沈])
	## 攻AP70 → 防HP100 → 生存 → 消沈で上書き → 反撃不可
	var config = _create_config()
	config.attacker_items = [1050]  # カースウィップ(AP+30, 刻印[消沈])
	config.defender_items = [1018]  # ブリガンダイン(HP+40) ※生存させるため
	config.defender_pre_curse = {
		"curse_type": "creature_toll_disable",
		"name": "免罪",
		"duration": -1,
		"params": {}
	}
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_curse.get("curse_type", ""), "battle_disable", "刻印上書き: 消沈に上書き")
	assert_eq(r.defender_curse.get("name", ""), "消沈", "刻印上書き: 刻印名")
	assert_eq(r.attacker_final_hp, 50, "刻印上書き: 攻HP(消沈で反撃不可→無傷)")

func test_1050_curse_whip_blocked_by_nullify():
	## カースウィップ vs ガイアシールド(無効化[通常攻撃]) + 既存刻印[免罪]
	## 攻撃が無効化された → on_attack_success発動しない → 刻印上書きされない
	## 攻: タイダルオーガ + カースウィップ(AP+30) → AP70
	## 防: レッドオーガ(火) + ガイアシールド(火地→無効化) + 事前刻印[免罪]
	## 攻ダメージ無効化 → 防HP50(current_hp) → 免罪のまま
	## 防AP40 → 攻HP50-40=10
	var config = _create_config()
	config.attacker_items = [1050]  # カースウィップ(AP+30, 刻印[消沈])
	config.defender_items = [1062]  # ガイアシールド(火地使用時 無効化[通常攻撃])
	config.defender_pre_curse = {
		"curse_type": "creature_toll_disable",
		"name": "免罪",
		"duration": -1,
		"params": {}
	}
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_curse.get("curse_type", ""), "creature_toll_disable", "無効化時刻印維持: 免罪のまま")
	assert_eq(r.defender_curse.get("name", ""), "免罪", "無効化時刻印維持: 刻印名")
	assert_eq(r.defender_final_hp, 50, "無効化時刻印維持: 防HP(攻撃無効)")
	assert_eq(r.attacker_final_hp, 10, "無効化時刻印維持: 攻HP(カウンター)")

func test_124_toll_curser_on_battle_end_curse_not_blocked_by_silent_robe():
	## トールカーサーのon_battle_end免罪刻印はサイレントローブ(nullify on_attack_success)で防げない
	var config = _create_config()
	config.attacker_creatures = [124]  # トールカーサー(水, AP30/HP40, on_battle_end免罪刻印)
	config.attacker_items = [1017]     # サイレントローブ(HP+40)
	config.defender_creatures = [48]   # レッドオーガ(火, AP40/HP50)
	config.defender_items = [1017]     # サイレントローブ(HP+40, nullify on_attack_success)
	config.board_layout = [
		{"tile_index": 6, "owner_id": 0, "creature_id": 124},
		{"tile_index": 7, "owner_id": 0, "creature_id": 124},
		{"tile_index": 2, "owner_id": 1, "creature_id": 48},
		{"tile_index": 3, "owner_id": 1, "creature_id": 48},
	]
	config.battle_tile_index = 3
	config.defender_battle_land = "fire"
	config.defender_battle_land_level = 1
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# トールカーサーAP30 vs レッドオーガHP90(50+40): HP60残
	# レッドオーガAP40 vs トールカーサーHP80(40+40): HP40残 → 攻撃側生存
	assert_eq(r.attacker_final_ap, 30, "トールカーサーAP30")
	assert_eq(r.attacker_final_hp, 40, "トールカーサーHP40残")
	assert_eq(r.defender_final_hp, 50, "レッドオーガHP50残")
	assert_eq(r.winner, "attacker_survived", "攻撃側生存")
	# on_battle_endはサイレントローブで防げない → 免罪刻印が付く
	assert_eq(r.defender_curse.get("curse_type", ""), "creature_toll_disable", "防御側に免罪刻印付与")
	assert_eq(r.attacker_curse.size(), 0, "攻撃側に刻印なし")

# ========== コピースパイク (1036) ==========

func test_1036_copy_spike_attacker():
	## コピースパイク攻撃側: AP+20, 敵破壊時は変質不発動
	## 攻: タイダルオーガ(AP40)+コピースパイク(AP+20)=AP60 vs レッドオーガHP60(50+10土地) → 破壊
	var config = _create_config()
	config.attacker_items = [1036]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 60, "コピースパイク攻: AP60")
	assert_eq(r.attacker_final_hp, 50, "コピースパイク攻: HP50(反撃なし)")
	assert_eq(r.defender_final_hp, 0, "コピースパイク攻: 防HP0")
	assert_eq(r.winner, "attacker", "コピースパイク攻: 攻撃側勝利")
	# 敵破壊時は on_attack_success 条件(defender_alive)を満たさないため変質不発動
	assert_false(r.attacker_battle_effects.has("変質"), "コピースパイク攻: 敵破壊で変質不発動")

func test_1036_copy_spike_transform():
	## コピースパイク攻撃側: 敵非破壊時に変質発動
	## 攻: ゴブリン(AP20)+コピースパイク(AP+20)=AP40 vs レッドオーガHP60(50+10土地) → 非破壊
	var config = _create_config()
	config.attacker_creatures = [414]  # ゴブリン(AP20/HP30)
	config.attacker_items = [1036]     # コピースパイク(AP+20, 変質)
	config.board_layout = [
		{"tile_index": 2, "owner_id": 0, "creature_id": 414},
		{"tile_index": 3, "owner_id": 0, "creature_id": 414},
		{"tile_index": 1, "owner_id": 1, "creature_id": 48},
		{"tile_index": 4, "owner_id": 1, "creature_id": 48},
	]
	config.battle_tile_index = 4
	config.defender_battle_land = "fire"
	config.defender_battle_land_level = 1
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# ゴブリンAP40 vs レッドオーガHP60: HP20残 → 非破壊 → 変質発動
	# レッドオーガ→ゴブリンにコピー（HP30にリセット、AP20に変化）
	# ゴブリン(防)AP20 → ゴブリン(攻)HP30: 30-20=HP10
	assert_eq(r.attacker_final_ap, 40, "コピースパイク変質: AP40")
	assert_eq(r.attacker_final_hp, 10, "コピースパイク変質: 攻HP10(変質後反撃)")
	assert_eq(r.defender_final_hp, 30, "コピースパイク変質: 防HP30(変質でリセット)")
	assert_eq(r.winner, "attacker_survived", "コピースパイク変質: 攻撃側生存")
	assert_true(r.attacker_battle_effects.has("変質"), "コピースパイク変質: 変質発動")
	assert_eq(r.defender_name, "ゴブリン", "コピースパイク変質: 防御側がゴブリンに変質")

func test_1036_copy_spike_defender():
	## コピースパイク防御側: AP+20, 敵撃破時は変質不発動
	## 防: レッドオーガ(AP40)+コピースパイク(AP+20)=AP60 vs タイダルオーガHP50 → 撃破
	var config = _create_config()
	config.defender_items = [1036]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 60, "コピースパイク防: AP60")
	assert_eq(r.defender_final_hp, 20, "コピースパイク防: HP20")
	assert_eq(r.winner, "defender", "コピースパイク防: 防御側勝利")
	# 反撃で攻撃側撃破 → is_alive条件未達で変質不発動
	assert_false(r.defender_battle_effects.has("変質"), "コピースパイク防: 敵撃破で変質不発動")

# ========== グランドハンマー (1012) ==========

func test_1012_grand_hammer_attacker():
	## グランドハンマー攻撃側: AP+40, 敵破壊 → 蓄魔なし
	## 攻: タイダルオーガ(AP40)+グランドハンマー(AP+40)=AP80 vs レッドオーガHP60(50+10) → 破壊
	var config = _create_config()
	config.attacker_items = [1012]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 80, "グランドハンマー攻: AP80")
	assert_eq(r.attacker_final_hp, 50, "グランドハンマー攻: HP50(反撃なし)")
	assert_eq(r.winner, "attacker", "グランドハンマー攻: 攻撃側勝利")

func test_1012_grand_hammer_survive():
	## グランドハンマー攻撃側: AP+40, 敵非破壊 → 蓄魔EP200
	## 攻: ゴブリン(AP20)+グランドハンマー(AP+40)=AP60 vs レッドオーガHP70(50+20火土地Lv2) → 非破壊
	var config = _create_config()
	config.attacker_creatures = [414]  # ゴブリン(AP20/HP30)
	config.attacker_items = [1012]     # グランドハンマー(AP+40)
	config.board_layout = [
		{"tile_index": 2, "owner_id": 0, "creature_id": 414},
		{"tile_index": 3, "owner_id": 0, "creature_id": 414},
		{"tile_index": 1, "owner_id": 1, "creature_id": 48},
		{"tile_index": 4, "owner_id": 1, "creature_id": 48, "level": 2},
	]
	config.battle_tile_index = 4
	config.defender_battle_land = "fire"
	config.defender_battle_land_level = 2
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# ゴブリンAP60 vs レッドオーガHP70(50+20): HP10残 → 非破壊
	# レッドオーガAP40 vs ゴブリンHP30: 撃破
	assert_eq(r.attacker_final_ap, 60, "グランドハンマー非破壊: AP60")
	assert_eq(r.defender_final_hp, 10, "グランドハンマー非破壊: 防HP10残")
	assert_eq(r.winner, "defender", "グランドハンマー非破壊: 防御側勝利")
	assert_true(r.attacker_battle_effects.has("蓄魔[200EP]"), "グランドハンマー非破壊: 蓄魔200EP発動")

# ========== デスペラード (1048) ==========

func test_1048_desperado_draw():
	## デスペラード肯定テスト: 防御側撃破時に相討発動(100%) → 両方撃破
	## 攻: ヘルハウンド(AP60/HP50) vs 防: ゴブリン+デスペラード(AP40/HP50)
	var config = _create_config()
	config.attacker_creatures = [8]    # ヘルハウンド(火, AP60/HP50)
	config.defender_creatures = [414]  # ゴブリン(中立, AP20/HP30)
	config.defender_items = [1048]     # デスペラード(AP+20, HP+20, 相討100%)
	config.board_layout = [
		{"tile_index": 2, "owner_id": 0, "creature_id": 8},
		{"tile_index": 3, "owner_id": 0, "creature_id": 8},
		{"tile_index": 6, "owner_id": 1, "creature_id": 414},
		{"tile_index": 7, "owner_id": 1, "creature_id": 414},
	]
	config.battle_tile_index = 7
	config.defender_battle_land = "water"
	config.defender_battle_land_level = 1
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# ヘルハウンドAP60 vs ゴブリンHP50(30+20): 撃破
	# → 相討発動 → ヘルハウンドHP=0
	assert_eq(r.attacker_final_hp, 0, "デスペラード相討: 攻HP0(相討)")
	assert_eq(r.winner, "both_defeated", "デスペラード相討: 両方撃破")

func test_1048_desperado_no_death():
	## デスペラード否定テスト: 防御側が生き残れば相討不発動
	## 攻: ゴブリン(AP20/HP30) vs 防: レッドオーガ+デスペラード(AP60/HP70)
	var config = _create_config()
	config.attacker_creatures = [414]  # ゴブリン(中立, AP20/HP30)
	config.defender_creatures = [48]   # レッドオーガ(火, AP40/HP50)
	config.defender_items = [1048]     # デスペラード(AP+20, HP+20, 相討100%)
	config.board_layout = [
		{"tile_index": 2, "owner_id": 0, "creature_id": 414},
		{"tile_index": 3, "owner_id": 0, "creature_id": 414},
		{"tile_index": 1, "owner_id": 1, "creature_id": 48},
		{"tile_index": 4, "owner_id": 1, "creature_id": 48},
	]
	config.battle_tile_index = 4
	config.defender_battle_land = "fire"
	config.defender_battle_land_level = 1
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# ゴブリンAP20 vs レッドオーガHP80(50+20item+10土地): HP60残 → 非破壊
	# レッドオーガAP60(40+20) vs ゴブリンHP30: 撃破
	# デスペラードは防御側が死んでいないので相討不発動
	assert_eq(r.winner, "defender", "デスペラード不発動: 防御側勝利")
	assert_true(r.attacker_final_hp <= 0, "デスペラード不発動: 攻撃側撃破")
	assert_true(r.defender_final_hp > 0, "デスペラード不発動: 防御側生存")

# ========== バーニングコア (1044) ==========

func test_1044_burning_core_revenge():
	## バーニングコア肯定テスト: 防御側撃破時に報復MHP-40 → 攻撃側HP減少
	## 攻: ヘルハウンド(AP60/HP50) vs 防: ゴブリン+バーニングコア(AP50/HP50)
	var config = _create_config()
	config.attacker_creatures = [8]    # ヘルハウンド(火, AP60/HP50)
	config.defender_creatures = [414]  # ゴブリン(中立, AP20/HP30)
	config.defender_items = [1044]     # バーニングコア(AP+30, HP+20, 報復MHP-40)
	config.board_layout = [
		{"tile_index": 2, "owner_id": 0, "creature_id": 8},
		{"tile_index": 3, "owner_id": 0, "creature_id": 8},
		{"tile_index": 6, "owner_id": 1, "creature_id": 414},
		{"tile_index": 7, "owner_id": 1, "creature_id": 414},
	]
	config.battle_tile_index = 7
	config.defender_battle_land = "water"
	config.defender_battle_land_level = 1
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# ヘルハウンドAP60 vs ゴブリンHP50(30+20): 撃破
	# → 報復MHP-40 → ヘルハウンドHP50-40=10
	assert_eq(r.attacker_final_hp, 10, "バーニングコア報復: 攻HP10(MHP-40)")
	assert_eq(r.winner, "attacker", "バーニングコア報復: 攻撃側勝利")

func test_1044_burning_core_no_death():
	## バーニングコア否定テスト: 防御側が生き残れば報復不発動
	## 攻: ゴブリン(AP20/HP30) vs 防: レッドオーガ+バーニングコア(AP70/HP80)
	var config = _create_config()
	config.attacker_creatures = [414]  # ゴブリン(中立, AP20/HP30)
	config.defender_creatures = [48]   # レッドオーガ(火, AP40/HP50)
	config.defender_items = [1044]     # バーニングコア(AP+30, HP+20, 報復MHP-40)
	config.board_layout = [
		{"tile_index": 2, "owner_id": 0, "creature_id": 414},
		{"tile_index": 3, "owner_id": 0, "creature_id": 414},
		{"tile_index": 1, "owner_id": 1, "creature_id": 48},
		{"tile_index": 4, "owner_id": 1, "creature_id": 48},
	]
	config.battle_tile_index = 4
	config.defender_battle_land = "fire"
	config.defender_battle_land_level = 1
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# ゴブリンAP20 vs レッドオーガHP90(50+20item+10土地+10?): 非破壊
	# レッドオーガAP70(40+30) vs ゴブリンHP30: 撃破
	# バーニングコアは防御側が死んでいないので報復不発動
	assert_eq(r.winner, "defender", "バーニングコア不発動: 防御側勝利")
	assert_true(r.defender_final_hp > 0, "バーニングコア不発動: 防御側生存")

# ========== フォートレスブレイカー (1051) ==========

func test_1051_fortress_breaker_vs_defensive():
	## 肯定テスト: フォートレスブレイカー vs 堅守クリーチャー → 即死発動
	## 攻: タイダルオーガ+フォートレスブレイカー(AP70) vs 防: メガリスガード(地,AP0/HP60,堅守)
	## メガリスガードHP70(60+10土地) > AP70だが即死で撃破
	var config = _create_config()
	config.attacker_items = [1051]     # フォートレスブレイカー(AP+30, 即死[堅守])
	config.defender_creatures = [222]  # メガリスガード(地, AP0/HP60, 堅守, creature_type=defensive)
	config.board_layout = [
		{"tile_index": 6, "owner_id": 0, "creature_id": 138},
		{"tile_index": 7, "owner_id": 0, "creature_id": 138},
		{"tile_index": 16, "owner_id": 1, "creature_id": 222},
		{"tile_index": 17, "owner_id": 1, "creature_id": 222},
	]
	config.battle_tile_index = 17
	config.defender_battle_land = "earth"
	config.defender_battle_land_level = 1
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 70, "フォートレスブレイカーvs堅守: AP70")
	assert_eq(r.attacker_final_hp, 50, "フォートレスブレイカーvs堅守: 攻HP50(反撃なし)")
	assert_eq(r.defender_final_hp, 0, "フォートレスブレイカーvs堅守: 防HP0(即死)")
	assert_eq(r.winner, "attacker", "フォートレスブレイカーvs堅守: 攻撃側勝利")
	assert_true(r.attacker_granted_skills.has("即死"), "フォートレスブレイカーvs堅守: 即死スキル付与")

func test_1051_fortress_breaker_vs_cursed_defensive():
	## 肯定テスト: フォートレスブレイカー vs 重結界(defensive_form)刻印付きクリーチャー → 即死発動
	## 攻: タイダルオーガ+フォートレスブレイカー(AP70) vs 防: レッドオーガ+刻印[重結界](HP100=50+Lv5土地50)
	## 通常ダメージ70ではHP100を倒せない → 即死[堅守]条件成立 → 即死で撃破
	var config = _create_config()
	config.attacker_items = [1051]  # フォートレスブレイカー(AP+30, 即死[堅守])
	config.defender_battle_land_level = 5  # 土地Lv5 → ボーナスHP50 → 合計HP100
	config.defender_pre_curse = {
		"curse_type": "protection_wall",
		"name": "重結界",
		"params": {"defensive_form": true, "spell_protection": true, "name": "重結界"}
	}
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# レッドオーガHP100(50+50土地)だが即死で撃破
	assert_eq(r.defender_final_hp, 0, "フォートレスブレイカーvs重結界: 防HP0(即死)")
	assert_eq(r.winner, "attacker", "フォートレスブレイカーvs重結界: 攻撃側勝利")
	assert_eq(r.attacker_final_hp, 50, "フォートレスブレイカーvs重結界: 攻HP50(反撃なし)")

func test_1051_fortress_breaker_vs_normal():
	## 否定テスト: フォートレスブレイカー vs 非堅守クリーチャー → 即死不発動（通常ダメージ）
	## 攻: タイダルオーガ+フォートレスブレイカー(AP70) vs 防: レッドオーガ(AP40/HP60)
	## 即死条件不成立 → 通常ダメージ70 vs HP60 → 撃破（即死ではなくダメージ超過）
	var config = _create_config()
	config.attacker_items = [1051]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 70, "フォートレスブレイカーvs通常: AP70")
	assert_eq(r.attacker_final_hp, 50, "フォートレスブレイカーvs通常: 攻HP50(反撃なし)")
	assert_eq(r.winner, "attacker", "フォートレスブレイカーvs通常: 攻撃側勝利")
	assert_true(r.attacker_granted_skills.has("即死"), "フォートレスブレイカーvs通常: 即死スキル付与(条件不成立でも付与はされる)")


# ========== ディスペルオーブ (1004) テスト ==========
# 沈黙（戦闘中能力無効）: 両者のスキル・変身・鼓舞をスキップして基礎ステータスでバトル
# 全スキル持ちクリーチャーに対して、スキルが発動しないことを検証

## --- Group A: 防御側スキル持ち、攻撃側ディスペルオーブ ---

func test_1004_dispel_vs_first_strike():
	## フレイムキメラ(7, fire, AP30/HP50, 先制) → 先制無効化
	## 火Lv1→HP60. 先制nullified → 攻(侵略側)が先に攻撃
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [7]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_false(r.first_strike_occurred, "ディスペルvs先制: 先制不発動")
	assert_eq(r.defender_final_hp, 20, "ディスペルvs先制: 防HP20(60-40)")
	assert_eq(r.attacker_final_hp, 20, "ディスペルvs先制: 攻HP20(50-30)")

func test_1004_dispel_vs_resonance():
	## イフリート(2, fire, AP30/HP30, 共鳴[地]) → 共鳴無効化
	## 地タイル2枚追加(共鳴対象)。Dispel → 共鳴なし → AP30/HP40(30+land10)
	## 攻AP40 vs HP40 → 撃破
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [2]
	# 防御側に地タイル2枚追加（共鳴[地]の対象）
	config.board_layout.append({"tile_index": 16, "owner_id": 1, "creature_id": 222})
	config.board_layout.append({"tile_index": 17, "owner_id": 1, "creature_id": 222})
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 30, "ディスペルvs共鳴: AP30(共鳴ボーナスなし)")
	assert_eq(r.defender_final_hp, 0, "ディスペルvs共鳴: 撃破(HP40にAP40)")
	assert_eq(r.winner, "attacker", "ディスペルvs共鳴: 攻撃側勝利")

func test_1004_dispel_vs_double_attack():
	## マンティコア(326, wind, AP20/HP30, 2回攻撃) → 2回攻撃無効化
	## 風Lv3→HP60で生存させる. Dispel → 1回攻撃のみ → 攻HP30(50-20)
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [326]
	config.defender_battle_land = "wind"
	config.defender_battle_land_level = 3
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 30, "ディスペルvs2回攻撃: 攻HP30(1回のみ被弾)")
	assert_eq(r.defender_final_hp, 20, "ディスペルvs2回攻撃: 防HP20(60-40)")

func test_1004_dispel_vs_regeneration():
	## エターナルウニ(113, water, AP20/HP40, 再生) → 再生無効化
	## 水Lv1→HP50. Dispel → 再生なし → 防HP10(50-40)のまま
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [113]
	config.defender_battle_land = "water"
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 10, "ディスペルvs再生: 防HP10(再生なし)")

func test_1004_dispel_vs_reflect():
	## ミラー(426, neutral, AP0/HP10, 反射) → 反射無効化
	## neutral→火landボーナスなし→HP10. Dispel → 反射なし → 攻HP50のまま
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [426]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 50, "ディスペルvs反射: 反射ダメージなし")
	assert_true(r.defender_final_hp <= 0, "ディスペルvs反射: ミラー撃破")

func test_1004_dispel_vs_reflect_half():
	## ワンダリングナイト(25, fire, AP40/HP30, 反射[1/2]) → 反射[1/2]無効化
	## 火Lv1→HP40. 攻AP40→撃破. Dispel → 反射なし → 攻HP50
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [25]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 50, "ディスペルvs反射半減: 反射ダメージなし")
	assert_eq(r.winner, "attacker", "ディスペルvs反射半減: 攻撃側勝利")

func test_1004_dispel_vs_self_destruct():
	## ボム(442, neutral, AP10/HP30, 相討) → 相討無効化
	## neutral→火landボーナスなし→HP30. 攻AP40→撃破. Dispel → 相討なし → 攻撃側生存
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [442]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.winner, "attacker", "ディスペルvs相討: 攻撃側勝利(相討なし)")
	assert_true(r.attacker_final_hp > 0, "ディスペルvs相討: 攻撃側生存")

func test_1004_dispel_vs_transform():
	## カメレオン(432, neutral, AP0/HP30, 変身) → 変身無効化
	## neutral→火landボーナスなし→HP30. Dispel → 変身なし → AP0のまま → 反撃なし
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [432]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 0, "ディスペルvs変身: AP0(変身なし)")
	assert_eq(r.attacker_final_hp, 50, "ディスペルvs変身: 攻HP50(反撃なし)")
	assert_eq(r.winner, "attacker", "ディスペルvs変身: 攻撃側勝利")

func test_1004_dispel_vs_item_destroy():
	## ストリップペンギン(116, water, AP30/HP50, アイテム破壊) → アイテム破壊無効化
	## 沈黙(Phase0-N)がアイテム破壊(Phase0-D)より先に発動 → 破壊されない
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [116]
	config.defender_battle_land = "water"
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvsアイテム破壊: スキル不発動")

func test_1004_dispel_vs_item_steal():
	## シーフ(416, neutral, AP20/HP40, アイテム盗み) → アイテム盗み無効化
	## neutral→火landボーナスなし→HP40. 攻AP40→撃破.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [416]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.winner, "attacker", "ディスペルvsアイテム盗み: 攻撃側勝利")
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvsアイテム盗み: スキル不発動")

func test_1004_dispel_vs_magic_steal():
	## ゴールドレイダー(107, water, AP40/HP40, 吸魔) → 吸魔無効化
	## 水Lv1→HP50. 攻AP40→防HP10. 防AP40→攻HP10. 吸魔なし.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [107]
	config.defender_battle_land = "water"
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 10, "ディスペルvs吸魔: 防HP10")
	assert_eq(r.attacker_final_hp, 10, "ディスペルvs吸魔: 攻HP10")
	assert_true(r.defender_battle_effects.is_empty(), "ディスペルvs吸魔: 吸魔不発動")

func test_1004_dispel_vs_magic_gain():
	## ミミック(410, neutral, AP10/HP30, 蓄魔+形見) → 蓄魔無効化
	## neutral→火landボーナスなし→HP30. 攻AP40→撃破. 蓄魔なし.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [410]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.winner, "attacker", "ディスペルvs蓄魔: 攻撃側勝利")
	assert_true(r.defender_battle_effects.is_empty(), "ディスペルvs蓄魔: 蓄魔不発動")

func test_1004_dispel_vs_instant_death():
	## ニーベルングブレイド(16, fire, AP40/HP40, 即死+無効化) → 即死無効化
	## 火Lv1→HP50. 攻AP40→防HP10. 防AP40→攻HP10. 即死能力クリアで不発動.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [16]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_true(r.attacker_final_hp > 0, "ディスペルvs即死: 攻撃側生存")
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvs即死: スキル不発動")

func test_1004_dispel_vs_piercing():
	## レイドワイバーン(36, fire, AP40/HP50, 刺突) → 刺突無効化
	## 火Lv1→HP60. 攻AP40→防HP20. 防AP40→攻HP10. 刺突なし→通常ダメージ.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [36]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 20, "ディスペルvs刺突: 防HP20")
	assert_eq(r.attacker_final_hp, 10, "ディスペルvs刺突: 攻HP10")
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvs刺突: スキル不発動")

func test_1004_dispel_vs_magic_attack():
	## ウィスプ(34, fire, AP30/HP50, 術攻撃) → 術攻撃無効化
	## 火Lv1→HP60. 攻AP40→防HP20. 防AP30→攻HP20. 術攻撃なし→通常ダメージ.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [34]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_hp, 20, "ディスペルvs術攻撃: 防HP20")
	assert_eq(r.attacker_final_hp, 20, "ディスペルvs術攻撃: 攻HP20")
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvs術攻撃: スキル不発動")

func test_1004_dispel_vs_reinforcement():
	## フレイムセイント(17, fire, AP20/HP30, 加勢[火/地]) → 加勢無効化
	## 火Lv1→HP40. 攻AP40→撃破. 隣接味方がいても加勢なし.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [17]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.winner, "attacker", "ディスペルvs加勢: 攻撃側勝利")
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvs加勢: 加勢不発動")

func test_1004_dispel_vs_buff_spell():
	## パイロコーラー(12, fire, AP20/HP30, 強化術) → 強化術無効化
	## 火Lv1→HP40. 攻AP40→撃破.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [12]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.winner, "attacker", "ディスペルvs強化術: 攻撃側勝利")
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvs強化術: 強化術不発動")

func test_1004_dispel_vs_power_strike():
	## ウリエル(4, fire, AP40/HP40, 強化[刻印時×1.5]) → 強化無効化
	## 火Lv1→HP50. 沈黙で全能力クリア → AP40のまま(条件チェック前にクリア)
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [4]
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.defender_final_ap, 40, "ディスペルvs強化: AP40(強化なし)")
	assert_true(r.attacker_final_hp > 0, "ディスペルvs強化: 攻撃側生存(AP80にならず)")

func test_1004_dispel_vs_legacy():
	## ドゥームリーパー(136, water, AP10/HP40, 形見) → 形見無効化
	## 水Lv1→HP50. 攻AP40→防HP10. 形見on_deathは沈黙でクリア.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [136]
	config.defender_battle_land = "water"
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvs形見: スキル不発動")

func test_1004_dispel_vs_revive():
	## コクーンラーヴァ(139, water, AP30/HP30, 蘇生) → 蘇生無効化
	## 水Lv1→HP40. 攻AP40→撃破. 蘇生on_deathが沈黙でクリアされ不発動.
	var config = _create_config()
	config.attacker_items = [1004]
	config.defender_creatures = [139]
	config.defender_battle_land = "water"
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.winner, "attacker", "ディスペルvs蘇生: 攻撃側勝利")
	assert_true(r.defender_skills_triggered.is_empty(), "ディスペルvs蘇生: 蘇生不発動")

## --- Group B: 攻撃側スキル持ち、防御側ディスペルオーブ ---

func test_1004_dispel_vs_last_strike():
	## ヘヴィクラウン(119, water, AP50/HP60, 後手) → 後手無効化
	## 攻撃側にヘヴィクラウン、防御側にレッドオーガ+ディスペルオーブ
	## 水landで火クリーチャー→landボーナスなし→防HP50
	## 後手nullified → 攻(侵略側)が先に攻撃 → AP50でHP50撃破 → 反撃なし → 攻HP60
	var config = _create_config()
	config.attacker_creatures = [119]
	config.attacker_items = []
	config.defender_items = [1004]
	config.defender_battle_land = "water"
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_hp, 60, "ディスペルvs後手: 攻HP60(先に攻撃→反撃なし)")
	assert_eq(r.winner, "attacker", "ディスペルvs後手: 攻撃側勝利")

func test_1004_dispel_vs_support():
	## 鼓舞無効化: ボード上のアークデーモン(22, 鼓舞[攻撃時AP+10])から戦闘クリーチャーへのボーナスを阻止
	## 攻撃側ボードにアークデーモン配置、レッドオーガ(48)で侵略
	## 防御側にディスペルオーブ → 沈黙 → 鼓舞フェーズスキップ → AP40のまま
	var config = _create_config()
	config.attacker_creatures = [48]  # レッドオーガ(fire, AP40)で戦闘
	config.attacker_items = []
	config.defender_items = [1004]
	# ボード上にアークデーモン(22, fire, 鼓舞)を攻撃側味方として配置
	config.board_layout[0]["creature_id"] = 22  # tile1: レッドオーガ→アークデーモン
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	assert_eq(r.attacker_final_ap, 40, "ディスペルvs鼓舞: AP40(鼓舞ボーナスなし)")

## --- Group C: 沈黙の相互作用テスト ---

func test_1004_dispel_vs_curse_whip():
	## 防御側ディスペルオーブ vs 攻撃側カースウィップ(1050)
	## 沈黙は両者の能力をクリア → 攻撃側のカースウィップの刻印効果もクリアされるか検証
	## カースウィップ: AP+30 + on_attack_success刻印[消沈]
	## 沈黙でeffects部クリア → stat_bonus(AP+30)のみ残る → 刻印付与されない
	var config = _create_config()
	config.attacker_items = [1050]  # カースウィップ(AP+30, 刻印[消沈])
	config.defender_items = [1004]  # ディスペルオーブ
	var results = await _executor.execute_all_battles(config)
	var r = results[0]
	# AP+30のstat_bonusは沈黙後も適用される
	assert_eq(r.attacker_final_ap, 70, "ディスペルvsカースウィップ: AP70(stat_bonus残る)")
	# 刻印[消沈]は沈黙でクリアされ付与されない
	assert_true(r.defender_curse.is_empty(), "ディスペルvsカースウィップ: 刻印付与なし")
	assert_true(r.attacker_battle_effects.is_empty(), "ディスペルvsカースウィップ: 刻印効果不発動")
