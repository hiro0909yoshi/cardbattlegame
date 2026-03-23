extends GutTest

## SpellMagic テスト
## EP増加、EP減少、ドレインマジックの効果を検証

var _spell_magic: SpellMagic
var _player_system: PlayerSystem


func before_each():
	_player_system = PlayerSystem.new()
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 500
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 500
	_player_system.players = [p0, p1]

	_spell_magic = SpellMagic.new()
	_spell_magic.setup(_player_system)


# ========================================
# EP増加テスト
# ========================================

## 基本EP増加
func test_add_magic():
	_spell_magic.add_magic(0, 100)
	assert_eq(_player_system.players[0].magic_power, 600, "500+100=600EP")


## 0EP増加
func test_add_magic_zero():
	_spell_magic.add_magic(0, 0)
	assert_eq(_player_system.players[0].magic_power, 500, "変化なし")


## gain_magic効果（apply_effect経由）
func test_apply_effect_gain_magic():
	var effect = {"effect_type": "gain_magic", "amount": 200}
	var result = await _spell_magic.apply_effect(effect, 0)
	assert_true(result["success"], "gain_magic成功")
	assert_eq(result["amount"], 200, "200EP獲得")
	assert_eq(_player_system.players[0].magic_power, 700, "500+200=700EP")


# ========================================
# EP減少テスト
# ========================================

## 基本EP減少
func test_reduce_magic():
	_spell_magic.reduce_magic(0, 100)
	assert_eq(_player_system.players[0].magic_power, 400, "500-100=400EP")


# ========================================
# ドレインマジック（吸魔）テスト
# ========================================

## 基本ドレイン: P1からP0に100EP吸収
func test_apply_effect_drain_magic():
	var effect = {"effect_type": "drain_magic", "value": 100}
	var context = {"from_player_id": 1}
	var result = await _spell_magic.apply_effect(effect, 0, context)
	assert_true(result["success"], "drain成功")
	assert_eq(_player_system.players[0].magic_power, 600, "P0: 500+100=600")
	assert_eq(_player_system.players[1].magic_power, 400, "P1: 500-100=400")


# ========================================
# 複数プレイヤーテスト
# ========================================

## 各プレイヤーに独立してEP操作
func test_independent_player_magic():
	_spell_magic.add_magic(0, 50)
	_spell_magic.add_magic(1, 100)
	assert_eq(_player_system.players[0].magic_power, 550, "P0: 550EP")
	assert_eq(_player_system.players[1].magic_power, 600, "P1: 600EP")


# ========================================
# 土地刻印発動テスト（トラップ）
# ========================================

## 敵停止時にEP減少トラップが発動
func test_land_curse_reduce_magic_on_enemy_stop():
	# クリーチャーに土地刻印を設定
	var creature = {
		"name": "ゴブリン",
		"hp": 40, "ap": 30, "current_hp": 40,
		"curse": {
			"curse_type": "land_trap",
			"name": "ブラストトラップ",
			"duration": -1,
			"params": {
				"name": "ブラストトラップ",
				"trigger": "on_enemy_stop",
				"one_shot": true,
				"curse_effects": [
					{"effect_type": "reduce_magic_percentage", "target": "stopped_player", "percentage": 20}
				],
				"caster_id": 0
			}
		}
	}
	var tile_info = {"creature": creature, "owner": 0}

	# プレイヤー1(敵)がタイルに停止
	_spell_magic._check_and_trigger_land_curse(1, 1, tile_info)

	# EP20%減少: 500 * 20% = 100 → 400EP
	assert_eq(_player_system.players[1].magic_power, 400, "敵EP20%減少: 500→400")
	# one_shotなので刻印が解除される
	assert_false(creature.has("curse"), "one_shot: 刻印解除")


## 自分の土地に自分が停止した場合は発動しない
func test_land_curse_not_trigger_on_own_stop():
	var creature = {
		"name": "ゴブリン",
		"hp": 40, "ap": 30, "current_hp": 40,
		"curse": {
			"curse_type": "land_trap",
			"name": "ブラストトラップ",
			"duration": -1,
			"params": {
				"name": "ブラストトラップ",
				"trigger": "on_enemy_stop",
				"one_shot": true,
				"curse_effects": [
					{"effect_type": "reduce_magic_percentage", "target": "stopped_player", "percentage": 20}
				],
				"caster_id": 0
			}
		}
	}
	var tile_info = {"creature": creature, "owner": 0}

	# プレイヤー0(自分)が自分の土地に停止
	_spell_magic._check_and_trigger_land_curse(1, 0, tile_info)

	# EP変化なし
	assert_eq(_player_system.players[0].magic_power, 500, "自分の土地では発動しない")
	# 刻印も残る
	assert_true(creature.has("curse"), "刻印残存")


## one_shotでない場合は刻印が残る
func test_land_curse_persistent():
	var creature = {
		"name": "ゴブリン",
		"hp": 40, "ap": 30, "current_hp": 40,
		"curse": {
			"curse_type": "land_trap",
			"name": "永続トラップ",
			"duration": -1,
			"params": {
				"name": "永続トラップ",
				"trigger": "on_enemy_stop",
				"one_shot": false,
				"curse_effects": [
					{"effect_type": "reduce_magic_percentage", "target": "stopped_player", "percentage": 10}
				],
				"caster_id": 0
			}
		}
	}
	var tile_info = {"creature": creature, "owner": 0}

	# 1回目: 敵停止
	_spell_magic._check_and_trigger_land_curse(1, 1, tile_info)
	assert_eq(_player_system.players[1].magic_power, 450, "1回目: 500→450")
	assert_true(creature.has("curse"), "one_shot=false: 刻印残存")

	# 2回目: 再度敵停止
	_spell_magic._check_and_trigger_land_curse(1, 1, tile_info)
	assert_eq(_player_system.players[1].magic_power, 405, "2回目: 450→405")


## 刻印なしクリーチャーでは何も起きない
func test_land_curse_no_curse():
	var creature = {"name": "ゴブリン", "hp": 40, "ap": 30, "current_hp": 40}
	var tile_info = {"creature": creature, "owner": 0}

	_spell_magic._check_and_trigger_land_curse(1, 1, tile_info)
	assert_eq(_player_system.players[1].magic_power, 500, "EP変化なし")
