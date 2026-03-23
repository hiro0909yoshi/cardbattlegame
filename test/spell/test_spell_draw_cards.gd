extends GutTest

## ドロー系テスト
## SpellDraw の各ドロー操作 + JSON定義確認
## CardSystemを直接使用（デッキを手動設定）

var _card_system: CardSystem
var _player_system: PlayerSystem
var _spell_draw: SpellDraw

## 既知のカードID（テスト用）
const CREATURE_IDS: Array[int] = [1001, 1002, 1003, 1004, 1005]
const SPELL_IDS: Array[int] = [2016, 2023, 2031, 2033, 2037]
const ITEM_IDS: Array[int] = [3001, 3002, 3003]


func before_each():
	# CardSystem初期化
	_card_system = CardSystem.new()
	_card_system.name = "CardSystem_DrawTest"
	add_child(_card_system)
	# 手動でプレイヤーデータ構造を初期化（initialize_decksはGameData依存なので使わない）
	for pid in range(2):
		_card_system.player_decks[pid] = []
		_card_system.player_discards[pid] = []
		_card_system.player_hands[pid] = {"data": []}

	# PlayerSystem
	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_DrawTest"
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

	# SpellDraw
	_spell_draw = SpellDraw.new()
	_spell_draw.setup(_card_system, _player_system)


func after_each():
	if _card_system and is_instance_valid(_card_system):
		_card_system.free()
	if _player_system and is_instance_valid(_player_system):
		_player_system.free()


## デッキにカードIDを設定
func _set_deck(player_id: int, card_ids: Array[int]) -> void:
	_card_system.player_decks[player_id] = card_ids.duplicate()


## 手札にカードを追加
func _add_to_hand(player_id: int, card_id: int) -> void:
	var card_data = CardLoader.get_card_by_id(card_id).duplicate(true)
	if not card_data.is_empty():
		_card_system.player_hands[player_id]["data"].append(card_data)


## JSON定義からeffect_typesを取得
func _get_effect_types(spell_id: int) -> Array[String]:
	var card = CardLoader.get_card_by_id(spell_id)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var types: Array[String] = []
	for e in effects:
		types.append(e.get("effect_type", ""))
	return types


# ========================================
# JSON定義確認
# ========================================

## プライス(2024): draw + toll_multiplier
func test_price_json():
	var types = _get_effect_types(2024)
	assert_true(types.has("draw"), "プライス: draw持ち")
	assert_true(types.has("toll_multiplier"), "プライス: toll_multiplier持ち")

## カース(2054): draw + stat_reduce
func test_curse_json():
	var types = _get_effect_types(2054)
	assert_true(types.has("draw"), "カース: draw持ち")
	assert_true(types.has("stat_reduce"), "カース: stat_reduce持ち")

## ウィークネス(2058): draw + ap_nullify
func test_weakness_json():
	var types = _get_effect_types(2058)
	assert_true(types.has("draw"), "ウィークネス: draw持ち")

## エンハンス(2066): draw + stat_boost
func test_enhance_draw_json():
	var types = _get_effect_types(2066)
	assert_true(types.has("draw"), "エンハンス: draw持ち")
	assert_true(types.has("stat_boost"), "エンハンス: stat_boost持ち")

## ヌル(2094): draw + skill_nullify
func test_null_json():
	var types = _get_effect_types(2094)
	assert_true(types.has("draw"), "ヌル: draw持ち")

## フラックス(2120): draw + random_stat_curse
func test_flux_json():
	var types = _get_effect_types(2120)
	assert_true(types.has("draw"), "フラックス: draw持ち")

## ラッキー(2020): draw_by_rank + gain_magic_by_rank
func test_lucky_json():
	var card = CardLoader.get_card_by_id(2020)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	var has_draw_by_rank = false
	for e in effects:
		if e.get("effect_type", "") == "draw_by_rank":
			has_draw_by_rank = true
	assert_true(has_draw_by_rank, "ラッキー: draw_by_rank持ち")

## チョイス(2090): draw_by_type
func test_choice_json():
	assert_true(_get_effect_types(2090).has("draw_by_type"), "チョイス: draw_by_type")

## ラック(2095): draw_cards
func test_luck_json():
	var card = CardLoader.get_card_by_id(2095)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "draw_cards":
			assert_eq(int(e.get("count", 0)), 2, "ラック: count=2")

## オラクル(2078): draw_from_deck_selection
func test_oracle_json():
	assert_true(_get_effect_types(2078).has("draw_from_deck_selection"), "オラクル: draw_from_deck_selection")

## ディスカバー(2132): draw_and_place
func test_discover_json():
	assert_true(_get_effect_types(2132).has("draw_and_place"), "ディスカバー: draw_and_place")

## カード獲得(9002): draw_until
func test_card_acquire_json():
	var card = CardLoader.get_card_by_id(9002)
	var effects: Array = card.get("effect_parsed", {}).get("effects", [])
	for e in effects:
		if e.get("effect_type", "") == "draw_until":
			assert_eq(int(e.get("target_hand_size", 0)), 5, "カード獲得: target_hand_size=5")

## アイテムリプレニッシュ(9003): draw_by_type
func test_item_replenish_json():
	assert_true(_get_effect_types(9003).has("draw_by_type"), "アイテムリプレニッシュ: draw_by_type")

## アイテムドロー(9043): draw_by_type
func test_item_draw_json():
	assert_true(_get_effect_types(9043).has("draw_by_type"), "アイテムドロー: draw_by_type")

## カードドロー(9042): draw_cards
func test_card_draw_json():
	assert_true(_get_effect_types(9042).has("draw_cards"), "カードドロー: draw_cards")


# ========================================
# draw_one: 1枚ドロー
# ========================================

## 基本ドロー: デッキから1枚引く
func test_draw_one():
	_set_deck(0, [2016, 2023, 2031])
	var result = _spell_draw.draw_one(0)
	assert_false(result.is_empty(), "カードが引けた")
	assert_eq(result.get("id", 0), 2016, "先頭カードが引かれた")
	assert_eq(_card_system.get_hand(0).size(), 1, "手札1枚")
	assert_eq(_card_system.player_decks[0].size(), 2, "デッキ残り2枚")


## デッキ空 → 空辞書
func test_draw_one_empty_deck():
	var result = _spell_draw.draw_one(0)
	assert_true(result.is_empty(), "デッキ空: 空辞書")


# ========================================
# draw_cards: 複数枚ドロー
# ========================================

## 2枚ドロー
func test_draw_cards_two():
	_set_deck(0, [2016, 2023, 2031, 2033])
	var result = _spell_draw.draw_cards(0, 2)
	assert_eq(result.size(), 2, "2枚引けた")
	assert_eq(_card_system.get_hand(0).size(), 2, "手札2枚")
	assert_eq(_card_system.player_decks[0].size(), 2, "デッキ残り2枚")


## デッキ枚数以上ドロー → デッキ分だけ引く
func test_draw_cards_over_deck():
	_set_deck(0, [2016])
	var result = _spell_draw.draw_cards(0, 3)
	assert_eq(result.size(), 1, "デッキ1枚: 1枚だけ引けた")


# ========================================
# draw_until: 手札が指定枚数になるまでドロー
# ========================================

## 手札2枚 → 5枚まで = 3枚ドロー
func test_draw_until():
	_add_to_hand(0, 2016)
	_add_to_hand(0, 2023)
	_set_deck(0, [2031, 2033, 2037, 2041, 2053])
	var result = _spell_draw.draw_until(0, 5)
	assert_eq(result.size(), 3, "3枚追加ドロー")
	assert_eq(_card_system.get_hand(0).size(), 5, "手札5枚")


## 手札が既に足りている → 0枚ドロー
func test_draw_until_already_enough():
	for id in [2016, 2023, 2031, 2033, 2037]:
		_add_to_hand(0, id)
	_set_deck(0, [2041])
	var result = _spell_draw.draw_until(0, 5)
	assert_eq(result.size(), 0, "既に5枚: ドロー0枚")
	assert_eq(_card_system.get_hand(0).size(), 5, "手札5枚のまま")


# ========================================
# draw_by_rank: ランク別ドロー
# ========================================

## 3位 → 3枚ドロー
func test_draw_by_rank():
	_set_deck(0, [2016, 2023, 2031, 2033, 2037])
	var result = _spell_draw.draw_by_rank(0, 3)
	assert_eq(result.size(), 3, "3位: 3枚ドロー")
	assert_eq(_card_system.get_hand(0).size(), 3, "手札3枚")


## 1位 → 1枚ドロー
func test_draw_by_rank_first():
	_set_deck(0, [2016, 2023])
	var result = _spell_draw.draw_by_rank(0, 1)
	assert_eq(result.size(), 1, "1位: 1枚ドロー")


# ========================================
# draw_card_by_type: タイプ指定ドロー
# ========================================

## スペルタイプを指定してドロー
func test_draw_card_by_type_spell():
	_set_deck(0, [1001, 2016, 1002, 2023])
	var result = _spell_draw.draw_card_by_type(0, "spell")
	assert_true(result.get("drawn", false), "スペルが引けた")
	assert_eq(result.get("card_data", {}).get("type", ""), "spell", "type=spell")


## 該当タイプなし → drawn=false
func test_draw_card_by_type_none():
	_set_deck(0, [1001, 1002, 1003])
	var result = _spell_draw.draw_card_by_type(0, "spell")
	assert_false(result.get("drawn", true), "スペルなし: drawn=false")


# ========================================
# discard_and_draw_plus: 全捨て+1枚多くドロー
# ========================================

## 手札3枚 → 全捨て → 同数(3枚)ドロー
func test_discard_and_draw_plus():
	_add_to_hand(0, 2016)
	_add_to_hand(0, 2023)
	_add_to_hand(0, 2031)
	_set_deck(0, [2033, 2037, 2041, 2053, 2065])
	var old_hand_size = _card_system.get_hand(0).size()
	assert_eq(old_hand_size, 3, "初期手札3枚")

	var result = _spell_draw.discard_and_draw_plus(0)
	assert_eq(result.size(), old_hand_size, "旧手札と同数ドロー")
	assert_eq(_card_system.get_hand(0).size(), old_hand_size, "手札3枚")


## 手札0枚 → 0枚ドロー
func test_discard_and_draw_plus_empty():
	_set_deck(0, [2016, 2023])
	var result = _spell_draw.discard_and_draw_plus(0)
	assert_eq(result.size(), 0, "手札0: ドロー0枚")


# ========================================
# add_specific_card_to_hand: 特定カードを手札に追加
# ========================================

## 特定カードIDを手札に追加
func test_add_specific_card():
	var result = _spell_draw.add_specific_card_to_hand(0, 2016)
	assert_true(result.get("success", false), "追加成功")
	assert_eq(_card_system.get_hand(0).size(), 1, "手札1枚")
	assert_eq(_card_system.get_hand(0)[0].get("id", 0), 2016, "id=2016")
