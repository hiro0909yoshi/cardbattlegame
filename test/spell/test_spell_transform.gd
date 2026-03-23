extends GutTest

## クリーチャー変身系テスト
## SpellTransform の transform / discord_transform + JSON定義確認
## MockBoard + CardSystem使用

const Helper = preload("res://test/spell/spell_test_helper.gd")
const MockBoard = preload("res://test/spell/spell_test_board.gd")

var _board: BoardSystem3D
var _card_system: CardSystem
var _player_system: PlayerSystem
var _spell_transform: SpellTransform


func before_each():
	_board = MockBoard.new()
	_board.name = "MockBoard_Transform"
	add_child(_board)
	_board.tile_nodes = Helper.create_tile_nodes()

	_card_system = CardSystem.new()
	_card_system.name = "CardSystem_Transform"
	add_child(_card_system)
	for pid in range(2):
		_card_system.player_decks[pid] = []
		_card_system.player_discards[pid] = []
		_card_system.player_hands[pid] = {"data": []}

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_Transform"
	add_child(_player_system)
	var p0 = PlayerSystem.PlayerData.new()
	p0.id = 0
	p0.name = "プレイヤー1"
	p0.magic_power = 500
	var p1 = PlayerSystem.PlayerData.new()
	p1.id = 1
	p1.name = "プレイヤー2"
	p1.magic_power = 500
	_player_system.players = [p0, p1]

	_spell_transform = SpellTransform.new(_board, _player_system, _card_system)


func after_each():
	if is_instance_valid(_board):
		_board.free()
	if is_instance_valid(_card_system):
		_card_system.free()
	if is_instance_valid(_player_system):
		_player_system.free()


## クリーチャー配置（IDも設定）
func _place_creature_with_id(tile_index: int, creature_id: int, owner_id: int = 0,
		creature_name: String = "テストクリーチャー", hp: int = 40, ap: int = 30,
		element: String = "fire") -> void:
	var creature = Helper.make_creature(creature_name, hp, ap, element)
	creature["id"] = creature_id
	var tile = _board.tile_nodes[tile_index]
	tile.creature_data = creature.duplicate(true)
	tile.owner_id = owner_id


## JSON定義からeffect_typesを取得
func _get_effect_types(spell_id: int) -> Array[String]:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	return types


# ========================================
# JSON定義確認: アルカナアーツ変身系（固定ID）
# ========================================

## バーニングウォーデン変身(9020): transform, transform_to=5
func test_burning_warden_json():
	var types = _get_effect_types(9020)
	assert_true(types.has("transform"), "バーニングウォーデン: transform持ち")
	var card = CardLoader.get_card_by_id(9020)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 5, "transform_to=5")


## ファラオズギフト変身(9046): transform_to=239
func test_pharaoh_json():
	var card = CardLoader.get_card_by_id(9046)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 239, "transform_to=239")


## タイダルウォーデン変身(9047): transform_to=121
func test_tidal_warden_json():
	var card = CardLoader.get_card_by_id(9047)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 121, "transform_to=121")


## ミストシフター変身(9048): transform_to=104
func test_mist_shifter_json():
	var card = CardLoader.get_card_by_id(9048)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 104, "transform_to=104")


## トランスフェザー変身(9049): transform_to=142
func test_transfeather_json():
	var card = CardLoader.get_card_by_id(9049)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 142, "transform_to=142")


## ガルーダ変身(9050): transform_to=307
func test_garuda_json():
	var card = CardLoader.get_card_by_id(9050)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 307, "transform_to=307")


## ヴァルキリー変身(9051): transform_to=300
func test_valkyrie_json():
	var card = CardLoader.get_card_by_id(9051)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 300, "transform_to=300")


## リビングソイル変身(9052): transform_to=238
func test_living_soil_json():
	var card = CardLoader.get_card_by_id(9052)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(int(e.get("transform_to", 0)), 238, "transform_to=238")


# ========================================
# JSON定義確認: スペル変身系
# ========================================

## ガード(2049): transform + same_element_defensive
func test_guard_json():
	var types = _get_effect_types(2049)
	assert_true(types.has("transform"), "ガード: transform持ち")
	var card = CardLoader.get_card_by_id(2049)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(e.get("transform_type", ""), "same_element_defensive", "ガード: same_element_defensive")
			assert_eq(e.get("target", ""), "target", "ガード: target=target")


## モーフ(2056): discord_transform
func test_morph_json():
	var types = _get_effect_types(2056)
	assert_true(types.has("discord_transform"), "モーフ: discord_transform持ち")


## 変身(9057): transform + copy_target
func test_shapeshifter_json():
	var types = _get_effect_types(9057)
	assert_true(types.has("transform"), "変身: transform持ち")
	var card = CardLoader.get_card_by_id(9057)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "transform":
			assert_eq(e.get("transform_type", ""), "copy_target", "変身: copy_target")
			assert_eq(e.get("target", ""), "self", "変身: target=self")


# ========================================
# apply_effect: 固定ID変身（アルカナアーツ）
# ========================================

## 固定ID変身: クリーチャーが別のクリーチャーに変わる
func test_transform_fixed_id():
	_place_creature_with_id(3, 1, 0, "フレイムパラディン", 40, 30, "fire")
	var effect = {"effect_type": "transform", "transform_to": 5}
	var target_data = {"caster_tile_index": 3}
	var result = _spell_transform.apply_effect(effect, target_data, 0)

	assert_true(result.get("success", false), "変身成功")
	assert_eq(result.get("old_creature", ""), "フレイムパラディン", "旧クリーチャー名")
	assert_eq(result.get("new_creature_id", 0), 5, "新クリーチャーID=5")
	# タイル上のクリーチャーが変わっている
	var new_creature = _board.tile_nodes[3].creature_data
	assert_false(new_creature.is_empty(), "クリーチャーが存在")
	assert_eq(new_creature.get("id", 0), 5, "タイル上ID=5")


## 変身後ダウン状態になる
func test_transform_sets_down():
	_place_creature_with_id(3, 1, 0, "テスト", 40, 30)
	var effect = {"effect_type": "transform", "transform_to": 5}
	var target_data = {"caster_tile_index": 3}
	_spell_transform.apply_effect(effect, target_data, 0)

	assert_true(_board.tile_nodes[3].is_down(), "変身後ダウン状態")


## 変身でアイテムが引き継がれる
func test_transform_preserves_items():
	_place_creature_with_id(3, 1, 0, "テスト", 40, 30)
	var items: Array = [{"name": "テストアイテム", "ap_bonus": 10}]
	_board.tile_nodes[3].creature_data["items"] = items

	var effect = {"effect_type": "transform", "transform_to": 5}
	var target_data = {"caster_tile_index": 3}
	_spell_transform.apply_effect(effect, target_data, 0)

	var new_creature = _board.tile_nodes[3].creature_data
	assert_eq(new_creature.get("items", []).size(), 1, "アイテム1個引き継ぎ")


## 変身で永続ボーナスが引き継がれる
func test_transform_preserves_base_up():
	_place_creature_with_id(3, 1, 0, "テスト", 40, 30)
	_board.tile_nodes[3].creature_data["base_up_hp"] = 15
	_board.tile_nodes[3].creature_data["base_up_ap"] = 10

	var effect = {"effect_type": "transform", "transform_to": 5}
	var target_data = {"caster_tile_index": 3}
	_spell_transform.apply_effect(effect, target_data, 0)

	var new_creature = _board.tile_nodes[3].creature_data
	assert_eq(new_creature.get("base_up_hp", 0), 15, "base_up_hp引き継ぎ")
	assert_eq(new_creature.get("base_up_ap", 0), 10, "base_up_ap引き継ぎ")


## 変身でHPが新クリーチャー基準+永続ボーナスになる
func test_transform_hp_calculation():
	_place_creature_with_id(3, 1, 0, "テスト", 40, 30)
	_board.tile_nodes[3].creature_data["base_up_hp"] = 10

	var effect = {"effect_type": "transform", "transform_to": 5}
	var target_data = {"caster_tile_index": 3}
	_spell_transform.apply_effect(effect, target_data, 0)

	var new_creature = _board.tile_nodes[3].creature_data
	var new_base_hp = CardLoader.get_card_by_id(5).get("hp", 0)
	assert_eq(new_creature.get("current_hp", 0), new_base_hp + 10, "HP = 新基礎HP + base_up_hp")


## クリーチャーなしタイル → 失敗
func test_transform_no_creature():
	var effect = {"effect_type": "transform", "transform_to": 5}
	var target_data = {"caster_tile_index": 3}
	var result = _spell_transform.apply_effect(effect, target_data, 0)
	assert_false(result.get("success", true), "クリーチャーなし: 失敗")


## 無効なtile_index → 失敗
func test_transform_invalid_tile():
	var effect = {"effect_type": "transform", "transform_to": 5}
	var target_data = {"caster_tile_index": -1}
	var result = _spell_transform.apply_effect(effect, target_data, 0)
	assert_false(result.get("success", true), "無効タイル: 失敗")


# ========================================
# apply_effect: same_element_defensive（ガード）
# ========================================

## fire属性クリーチャー → ID=10に変身
func test_transform_defensive_fire():
	_place_creature_with_id(3, 1, 0, "テスト", 40, 30, "fire")
	var effect = {"effect_type": "transform", "target": "target", "transform_type": "same_element_defensive"}
	var target_data = {"tile_index": 3}
	var result = _spell_transform.apply_effect(effect, target_data, 0)

	assert_true(result.get("success", false), "fire堅守変身成功")
	assert_eq(result.get("new_creature_id", 0), 10, "fire → ID=10")


## water属性クリーチャー → ID=102に変身
func test_transform_defensive_water():
	_place_creature_with_id(3, 100, 0, "テスト", 40, 30, "water")
	var effect = {"effect_type": "transform", "target": "target", "transform_type": "same_element_defensive"}
	var target_data = {"tile_index": 3}
	var result = _spell_transform.apply_effect(effect, target_data, 0)

	assert_true(result.get("success", false), "water堅守変身成功")
	assert_eq(result.get("new_creature_id", 0), 102, "water → ID=102")


## earth属性 → ID=222
func test_transform_defensive_earth():
	_place_creature_with_id(3, 200, 0, "テスト", 40, 30, "earth")
	var effect = {"effect_type": "transform", "target": "target", "transform_type": "same_element_defensive"}
	var target_data = {"tile_index": 3}
	var result = _spell_transform.apply_effect(effect, target_data, 0)
	assert_eq(result.get("new_creature_id", 0), 222, "earth → ID=222")


## wind属性 → ID=330
func test_transform_defensive_wind():
	_place_creature_with_id(3, 300, 0, "テスト", 40, 30, "wind")
	var effect = {"effect_type": "transform", "target": "target", "transform_type": "same_element_defensive"}
	var target_data = {"tile_index": 3}
	var result = _spell_transform.apply_effect(effect, target_data, 0)
	assert_eq(result.get("new_creature_id", 0), 330, "wind → ID=330")


## neutral属性 → ID=421
func test_transform_defensive_neutral():
	_place_creature_with_id(3, 400, 0, "テスト", 40, 30, "neutral")
	var effect = {"effect_type": "transform", "target": "target", "transform_type": "same_element_defensive"}
	var target_data = {"tile_index": 3}
	var result = _spell_transform.apply_effect(effect, target_data, 0)
	assert_eq(result.get("new_creature_id", 0), 421, "neutral → ID=421")


# ========================================
# apply_effect: copy_target（変身/シェイプシフター）
# ========================================

## 対象クリーチャーをコピーして変身
func test_transform_copy_target():
	# 変身元（caster）
	_place_creature_with_id(3, 1, 0, "シェイプシフター", 30, 20, "fire")
	# コピー対象
	_place_creature_with_id(7, 100, 1, "コピー対象", 50, 40, "water")

	var effect = {"effect_type": "transform", "target": "self", "transform_type": "copy_target"}
	var target_data = {"caster_tile_index": 3, "tile_index": 7}
	var result = _spell_transform.apply_effect(effect, target_data, 0)

	assert_true(result.get("success", false), "コピー変身成功")
	assert_eq(result.get("new_creature_id", 0), 100, "コピー対象のID=100")
	# 変身元のタイルにコピー先データが配置される
	var new_creature = _board.tile_nodes[3].creature_data
	assert_eq(new_creature.get("id", 0), 100, "タイル3にID=100")


## コピー対象がいない → 失敗
func test_transform_copy_no_target():
	_place_creature_with_id(3, 1, 0, "シェイプシフター", 30, 20)
	var effect = {"effect_type": "transform", "target": "self", "transform_type": "copy_target"}
	var target_data = {"caster_tile_index": 3, "tile_index": 7}  # タイル7は空
	var result = _spell_transform.apply_effect(effect, target_data, 0)
	assert_false(result.get("success", true), "コピー対象なし: 失敗")


# ========================================
# apply_discord_transform（モーフ/ディスコード）
# ========================================

## 最多配置クリーチャーがゴブリンに変身
func test_discord_transform():
	# 同じクリーチャーを3体配置
	_place_creature_with_id(1, 1, 0, "フレイムパラディン", 40, 30, "fire")
	_place_creature_with_id(2, 1, 0, "フレイムパラディン", 40, 30, "fire")
	_place_creature_with_id(3, 1, 0, "フレイムパラディン", 40, 30, "fire")
	# 別のクリーチャー1体
	_place_creature_with_id(7, 100, 1, "ウォーターシールド", 50, 20, "water")

	var result = _spell_transform.apply_discord_transform(1)

	assert_true(result.get("success", false), "ディスコード成功")
	assert_eq(result.get("transformed_count", 0), 3, "3体変身")
	# 全てゴブリン(ID=414)になっている
	for idx in [1, 2, 3]:
		var creature = _board.tile_nodes[idx].creature_data
		assert_eq(creature.get("id", 0), 414, "タイル%d: ゴブリンに変身" % idx)
	# 別クリーチャーは変化なし
	assert_eq(_board.tile_nodes[7].creature_data.get("id", 0), 100, "タイル7: 変化なし")


## ゴブリンは対象外
func test_discord_excludes_goblins():
	# ゴブリン3体
	_place_creature_with_id(1, 414, 0, "ゴブリン", 20, 20)
	_place_creature_with_id(2, 414, 0, "ゴブリン", 20, 20)
	_place_creature_with_id(3, 414, 0, "ゴブリン", 20, 20)
	# 別クリーチャー1体
	_place_creature_with_id(7, 100, 1, "ウォーター", 50, 20)

	var result = _spell_transform.apply_discord_transform(0)

	assert_true(result.get("success", false), "ディスコード成功")
	# ゴブリンは対象外なので、ID=100の1体が変身
	assert_eq(result.get("transformed_count", 0), 1, "1体変身（ゴブリン除外）")


## クリーチャーなし → 失敗
func test_discord_no_creatures():
	var result = _spell_transform.apply_discord_transform(0)
	assert_false(result.get("success", true), "クリーチャーなし: 失敗")


## 全部ゴブリン → 失敗
func test_discord_all_goblins():
	_place_creature_with_id(1, 414, 0, "ゴブリン", 20, 20)
	_place_creature_with_id(2, 414, 0, "ゴブリン", 20, 20)
	var result = _spell_transform.apply_discord_transform(0)
	assert_false(result.get("success", true), "全ゴブリン: 失敗")
