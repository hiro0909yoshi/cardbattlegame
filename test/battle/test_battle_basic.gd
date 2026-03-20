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
	await _assert_attacker_item(1005, "フェニックスメイル", 40, 50, 40, 20, "attacker_survived", [])

func test_1005_phoenix_mail_defender():
	await _assert_defender_item(1005, "フェニックスメイル", 40, 10, 40, 50, "attacker_survived", [])

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
	await _assert_attacker_item(1054, "チャクラム", 60, 50, 40, 0, "attacker", [])

func test_1054_chakram_defender():
	await _assert_defender_item(1054, "チャクラム", 40, -10, 60, 30, "defender", [])


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
	await _assert_attacker_item(1030, "リターンレイ", 30, 10, 40, 20, "attacker_survived", ["術攻撃"])

func test_1030_return_ray_defender():
	await _assert_defender_item(1030, "リターンレイ", 40, 20, 30, 20, "attacker_survived", ["術攻撃"])

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
