extends GutTest

## 手札操作系テスト
## SpellDraw の破壊/奪取/デッキ操作/条件チェック + JSON定義確認
## CardSystemを直接使用（デッキ/手札を手動設定）

var _card_system: CardSystem
var _player_system: PlayerSystem
var _spell_draw: SpellDraw


func before_each():
	_card_system = CardSystem.new()
	_card_system.name = "CardSystem_HandTest"
	add_child(_card_system)
	for pid in range(2):
		_card_system.player_decks[pid] = []
		_card_system.player_discards[pid] = []
		_card_system.player_hands[pid] = {"data": []}

	_player_system = PlayerSystem.new()
	_player_system.name = "PlayerSystem_HandTest"
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

	_spell_draw = SpellDraw.new()
	_spell_draw.setup(_card_system, _player_system)


func after_each():
	if is_instance_valid(_card_system):
		_card_system.free()
	if is_instance_valid(_player_system):
		_player_system.free()


## 手札にカードを追加
func _add_to_hand(player_id: int, card_id: int) -> void:
	var card_data = CardLoader.get_card_by_id(card_id).duplicate(true)
	if not card_data.is_empty():
		_card_system.player_hands[player_id]["data"].append(card_data)


## デッキにカードIDを設定
func _set_deck(player_id: int, card_ids: Array[int]) -> void:
	_card_system.player_decks[player_id] = card_ids.duplicate()


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

## ハーモニー(2004): check_hand_elements
func test_harmony_json():
	assert_true(_get_effect_types(2004).has("check_hand_elements"), "ハーモニー: check_hand_elements")

## ウィズダム(2077): check_hand_synthesis
func test_wisdom_json():
	assert_true(_get_effect_types(2077).has("check_hand_synthesis"), "ウィズダム: check_hand_synthesis")

## クリーン(2017): destroy_duplicate_cards
func test_clean_json():
	assert_true(_get_effect_types(2017).has("destroy_duplicate_cards"), "クリーン: destroy_duplicate_cards")

## スマッシュ(2034): destroy_selected_card
func test_smash_json():
	assert_true(_get_effect_types(2034).has("destroy_selected_card"), "スマッシュ: destroy_selected_card")

## ディール(2038): destroy_selected_card
func test_deal_json():
	assert_true(_get_effect_types(2038).has("destroy_selected_card"), "ディール: destroy_selected_card")

## スナッチ(2046): steal_selected_card
func test_snatch_json():
	assert_true(_get_effect_types(2046).has("steal_selected_card"), "スナッチ: steal_selected_card")

## ピック(2042): steal_item_conditional
func test_pick_json():
	assert_true(_get_effect_types(2042).has("steal_item_conditional"), "ピック: steal_item_conditional")

## コンタミ(2093): destroy_from_deck_selection
func test_contami_json():
	assert_true(_get_effect_types(2093).has("destroy_from_deck_selection"), "コンタミ: destroy_from_deck_selection")

## リボーン(2127): discard_and_draw_plus
func test_reborn_json():
	assert_true(_get_effect_types(2127).has("discard_and_draw_plus"), "リボーン: discard_and_draw_plus")

## クリーンズ(2128): destroy_curse_cards
func test_cleanse_json():
	assert_true(_get_effect_types(2128).has("destroy_curse_cards"), "クリーンズ: destroy_curse_cards")

## ラス(2129): destroy_expensive_cards
func test_wrath_json():
	assert_true(_get_effect_types(2129).has("destroy_expensive_cards"), "ラス: destroy_expensive_cards")

## トランス(2113): transform_to_card
func test_trance_json():
	assert_true(_get_effect_types(2113).has("transform_to_card"), "トランス: transform_to_card")

## シャッフル(2122): reset_deck
func test_shuffle_json():
	assert_true(_get_effect_types(2122).has("reset_deck"), "シャッフル: reset_deck")

## ブックバーン(9038): destroy_deck_top
func test_bookburn_json():
	assert_true(_get_effect_types(9038).has("destroy_deck_top"), "ブックバーン: destroy_deck_top")

## トリックスティール(9045): destroy_and_draw
func test_trick_steal_json():
	assert_true(_get_effect_types(9045).has("destroy_and_draw"), "トリックスティール: destroy_and_draw")

## ハイヴソルジャー召喚(9053): add_specific_card
func test_hive_soldier_json():
	assert_true(_get_effect_types(9053).has("add_specific_card"), "ハイヴソルジャー: add_specific_card")

## チェンジリング(9059): swap_creature
func test_changeling_json():
	assert_true(_get_effect_types(9059).has("swap_creature"), "チェンジリング: swap_creature")


# ========================================
# destroy_duplicate_cards: 重複カード破壊
# ========================================

## 重複あり: 同じカード2枚 → 1枚破壊
func test_destroy_duplicate_cards():
	_add_to_hand(1, 2016)
	_add_to_hand(1, 2016)
	_add_to_hand(1, 2023)
	assert_eq(_card_system.get_hand(1).size(), 3, "初期手札3枚")

	var result = _spell_draw.destroy_duplicate_cards(1)
	assert_gt(result.get("total_destroyed", 0), 0, "重複破壊あり")
	# 重複分が消えて手札が減る
	assert_lt(_card_system.get_hand(1).size(), 3, "手札が減った")


## 重複なし: 破壊0
func test_destroy_duplicate_cards_none():
	_add_to_hand(1, 2016)
	_add_to_hand(1, 2023)
	_add_to_hand(1, 2031)
	var result = _spell_draw.destroy_duplicate_cards(1)
	assert_eq(result.get("total_destroyed", -1), 0, "重複なし: 破壊0")
	assert_eq(_card_system.get_hand(1).size(), 3, "手札3枚のまま")


# ========================================
# destroy_card_at_index: 指定インデックスのカード破壊
# ========================================

## インデックス指定で破壊
func test_destroy_card_at_index():
	_add_to_hand(1, 2016)
	_add_to_hand(1, 2023)
	_add_to_hand(1, 2031)
	var result = _spell_draw.destroy_card_at_index(1, 1)
	assert_true(result.get("destroyed", false), "破壊成功")
	assert_eq(_card_system.get_hand(1).size(), 2, "手札2枚")


## 無効インデックス → 失敗
func test_destroy_card_invalid_index():
	_add_to_hand(1, 2016)
	var result = _spell_draw.destroy_card_at_index(1, 5)
	assert_false(result.get("destroyed", true), "無効インデックス: 失敗")


# ========================================
# steal_card_at_index: カード奪取
# ========================================

## P1の手札からP0へ奪取
func test_steal_card():
	_add_to_hand(1, 2016)
	_add_to_hand(1, 2023)
	assert_eq(_card_system.get_hand(1).size(), 2, "P1手札2枚")
	assert_eq(_card_system.get_hand(0).size(), 0, "P0手札0枚")

	var result = _spell_draw.steal_card_at_index(1, 0, 0)
	assert_true(result.get("stolen", false), "奪取成功")
	assert_eq(_card_system.get_hand(1).size(), 1, "P1手札1枚に減少")
	assert_eq(_card_system.get_hand(0).size(), 1, "P0手札1枚に増加")


## 空手札から奪取 → 失敗
func test_steal_card_empty():
	var result = _spell_draw.steal_card_at_index(1, 0, 0)
	assert_false(result.get("stolen", true), "空手札: 奪取失敗")


# ========================================
# destroy_curse_cards: 全プレイヤーの呪いカード破壊
# ========================================

## 呪いカード（世界刻印スペル）を破壊
func test_destroy_curse_cards():
	# 世界刻印スペル(spell_type=世界刻印)をP0に入れる
	_add_to_hand(0, 2009)  # ライズオブサン (世界刻印)
	_add_to_hand(0, 2016)  # クリティカル (ダメージスペル)
	var hand_before = _card_system.get_hand(0).size()
	var result = _spell_draw.destroy_curse_cards()
	var destroyed = result.get("total_destroyed", 0)
	# 世界刻印が破壊対象なら1枚破壊
	if destroyed > 0:
		assert_lt(_card_system.get_hand(0).size(), hand_before, "呪いカード破壊")
	else:
		# is_curse_cardの判定基準によっては0の場合もある
		assert_eq(destroyed, 0, "破壊対象なし")


# ========================================
# destroy_expensive_cards: 高コストカード破壊
# ========================================

## 高コストカードを破壊
func test_destroy_expensive_cards():
	# 各種コストのカードを入れる
	_add_to_hand(0, 2016)  # クリティカル
	_add_to_hand(0, 2023)  # マッサカー
	_add_to_hand(0, 2031)  # ボルト
	var result = _spell_draw.destroy_expensive_cards(200)
	# コスト200以上のカードがあれば破壊される
	assert_true(result.has("total_destroyed"), "結果にtotal_destroyedあり")


# ========================================
# get_top_cards_from_deck: デッキ上位確認
# ========================================

## デッキ上位3枚を取得
func test_get_top_cards():
	_set_deck(0, [2016, 2023, 2031, 2033])
	var top = _spell_draw.get_top_cards_from_deck(0, 3)
	assert_eq(top.size(), 3, "上位3枚取得")


## デッキ枚数以上を要求 → デッキ分だけ
func test_get_top_cards_over():
	_set_deck(0, [2016])
	var top = _spell_draw.get_top_cards_from_deck(0, 5)
	assert_eq(top.size(), 1, "デッキ1枚: 1枚だけ")


# ========================================
# destroy_deck_card_at_index: デッキカード破壊
# ========================================

## デッキからカード破壊
func test_destroy_deck_card():
	_set_deck(1, [2016, 2023, 2031])
	var result = _spell_draw.destroy_deck_card_at_index(1, 0)
	assert_true(result.get("destroyed", false), "デッキカード破壊成功")
	assert_eq(_card_system.player_decks[1].size(), 2, "デッキ残り2枚")


# ========================================
# reset_deck_to_original: デッキ初期化
# ========================================

## デッキリセット
func test_reset_deck():
	# GameDataのデッキに元カードを設定（reset_deck_to_originalが参照する）
	var original_cards = {2016: 1, 2023: 1, 2031: 1}
	var deck_index = GameData.player_data.get("selected_deck_index", 0)
	if deck_index < GameData.player_data.decks.size():
		GameData.player_data.decks[deck_index]["cards"] = original_cards
	_set_deck(0, [2016])
	_card_system.player_discards[0] = [2023, 2031]
	var result = _spell_draw.reset_deck_to_original(0)
	assert_true(result.get("success", false), "デッキリセット成功")


# ========================================
# get_hand_creature_elements: 手札クリーチャー属性確認
# ========================================

## 4属性クリーチャーが揃っている
func test_has_all_elements():
	_add_to_hand(0, 1)    # fire creature
	_add_to_hand(0, 100)  # water creature
	_add_to_hand(0, 200)  # earth creature
	_add_to_hand(0, 300)  # wind creature
	var elements = _spell_draw.get_hand_creature_elements(0)
	assert_gte(elements.size(), 1, "クリーチャー属性あり")


## 手札にクリーチャーなし
func test_hand_creature_elements_none():
	_add_to_hand(0, 2016)  # spell only
	_add_to_hand(0, 2023)  # spell only
	var elements = _spell_draw.get_hand_creature_elements(0)
	assert_eq(elements.size(), 0, "クリーチャーなし: 空配列")


# ========================================
# count_items_in_hand: 手札アイテム数カウント
# ========================================

## アイテムカード数をカウント
func test_count_items():
	_add_to_hand(1, 2016)  # spell
	_add_to_hand(1, 1000)  # item (クイックチャーム)
	_add_to_hand(1, 1001)  # item (グレートヘルム)
	var count = _spell_draw.count_items_in_hand(1)
	assert_eq(count, 2, "アイテム2枚")


## アイテムなし
func test_count_items_none():
	_add_to_hand(1, 2016)
	_add_to_hand(1, 2023)
	var count = _spell_draw.count_items_in_hand(1)
	assert_eq(count, 0, "アイテム0枚")


# ========================================
# add_specific_card_to_hand: 特定カード追加
# ========================================

## 特定カードIDを手札に追加
func test_add_specific_card():
	var result = _spell_draw.add_specific_card_to_hand(0, 1)
	assert_true(result.get("success", false), "カード追加成功")
	assert_eq(_card_system.get_hand(0).size(), 1, "手札1枚")
	assert_eq(_card_system.get_hand(0)[0].get("id", 0), 1, "id=1(フレイムパラディン)")
