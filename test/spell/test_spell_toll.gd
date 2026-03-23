extends GutTest

## SpellCurseToll 通行料刻印テスト
## calculate_final_toll のコアロジックを検証

var _toll_system: SpellCurseToll
var _spell_curse: SpellCurse
var _player_system: PlayerSystem
var _creature_manager: CreatureManager


func before_each():
	# PlayerSystem セットアップ
	_player_system = PlayerSystem.new()
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 1000
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 1000
	_player_system.players = [p0, p1]

	# CreatureManager セットアップ
	_creature_manager = CreatureManager.new()
	# タイル5にクリーチャーを配置
	_creature_manager.creatures[5] = {
		"name": "テストクリーチャー",
		"hp": 30, "ap": 20,
		"element": "fire",
	}

	# SpellCurse セットアップ
	_spell_curse = SpellCurse.new()
	_spell_curse.creature_manager = _creature_manager
	_spell_curse.player_system = _player_system

	# SpellCurseToll セットアップ
	_toll_system = SpellCurseToll.new()
	_toll_system.setup(_spell_curse)


# ========================================
# 刻印なし（ベースライン）
# ========================================

## 刻印なしの場合は基本通行料がそのまま
func test_no_curse_base_toll():
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 500, "刻印なし: 基本通行料500")
	assert_eq(result["bonus_toll"], 0, "副収入なし")


# ========================================
# ドミニオ刻印（クリーチャーに付与）
# ========================================

## peace: 通行料0
func test_peace_toll_zero():
	_toll_system.apply_peace(5)
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 0, "peace: 通行料0")


## toll_multiplier: 通行料1.5倍
func test_toll_multiplier_150():
	_toll_system.apply_toll_multiplier(5, 1.5)
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 750, "toll_multiplier: 500*1.5=750")


## toll_multiplier: 通行料2倍
func test_toll_multiplier_200():
	_toll_system.apply_toll_multiplier(5, 2.0)
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 1000, "toll_multiplier: 500*2.0=1000")


## toll_half_curse: 通行料半減
func test_toll_half():
	_toll_system.apply_toll_half_curse(5)
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 250, "toll_half: 500*0.5=250")


## creature_toll_disable: クリーチャー単体の免罪
func test_creature_toll_disable():
	_toll_system.apply_creature_toll_disable(5)
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 0, "creature_toll_disable: 通行料0")


# ========================================
# セプター刻印（プレイヤーに付与）
# ========================================

## toll_disable: 支払い側が通行料免除
func test_toll_disable_payer():
	_toll_system.apply_toll_disable(0, 2)  # P0が免罪
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 0, "toll_disable: 支払い0")


## toll_fixed: 通行料を固定値に
func test_toll_fixed():
	_toll_system.apply_toll_fixed(1, 200, 3)  # P1(受取側)に固定200
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 200, "toll_fixed: 通行料200固定")


## toll_share: 副収入（50%を付与者が受け取る）
func test_toll_share():
	_toll_system.apply_toll_share(1, 5, 0)  # P1(受取側)にtoll_share、付与者はP0
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 500, "toll_share: メイン通行料は変わらない")
	assert_eq(result["bonus_toll"], 250, "toll_share: 副収入500*0.5=250")
	assert_eq(result["bonus_receiver_id"], 0, "toll_share: 副収入受取はP0")


# ========================================
# peace ユーティリティ
# ========================================

## has_peace_curse
func test_has_peace_curse():
	assert_false(_toll_system.has_peace_curse(5), "peace刻印なし")
	_toll_system.apply_peace(5)
	assert_true(_toll_system.has_peace_curse(5), "peace刻印あり")


## is_invasion_disabled
func test_is_invasion_disabled():
	assert_false(_toll_system.is_invasion_disabled(5), "侵略可能")
	_toll_system.apply_peace(5)
	assert_true(_toll_system.is_invasion_disabled(5), "peace: 侵略不可")


## apply_tile_curse_to_toll 表示用
func test_apply_tile_curse_to_toll_peace():
	_toll_system.apply_peace(5)
	var toll = _toll_system.apply_tile_curse_to_toll(5, 500)
	assert_eq(toll, 0, "peace: 表示用通行料0")


func test_apply_tile_curse_to_toll_multiplier():
	_toll_system.apply_toll_multiplier(5, 2.0)
	var toll = _toll_system.apply_tile_curse_to_toll(5, 500)
	assert_eq(toll, 1000, "multiplier: 表示用通行料1000")


func test_apply_tile_curse_to_toll_none():
	var toll = _toll_system.apply_tile_curse_to_toll(5, 500)
	assert_eq(toll, 500, "刻印なし: 表示用通行料500")


# ========================================
# 優先度テスト
# ========================================

## peace（ドミニオ刻印）はセプター刻印より優先
func test_peace_overrides_payer_curse():
	_toll_system.apply_peace(5)  # ドミニオにpeace
	_toll_system.apply_toll_fixed(1, 200, 3)  # 受取側にtoll_fixed
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 0, "peace優先: ドミニオpeaceでセプター刻印無視")


## toll_disable（支払い側）はtoll_fixed（受取側）より優先
func test_toll_disable_overrides_fixed():
	_toll_system.apply_toll_disable(0, 2)  # 支払い側P0にtoll_disable
	_toll_system.apply_toll_fixed(1, 200, 3)  # 受取側P1にtoll_fixed
	var result = _toll_system.calculate_final_toll(5, 0, 1, 500)
	assert_eq(result["main_toll"], 0, "toll_disable優先: 支払い免除")
