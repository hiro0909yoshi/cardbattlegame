class_name SkillMerge

## 合体スキル - 特定クリーチャー同士で別のクリーチャーに永続変化
##
## 【主な機能】
## - バトル参加クリーチャーが合体スキルを持ち、手札に合体相手がいる場合に発動
## - 合体結果のクリーチャーに永続的に変身
## - 変身先のステータス・スキルになる
##
## 【発動条件】
## - バトル参加クリーチャーが「合体」キーワードを持つ
## - 手札に合体相手（partner_id）のクリーチャーがいる
## - 合体相手のコスト分の魔力を支払える
##
## 【発動タイミング】
## 召喚フェーズ → アイテム選択フェーズ → 【合体フェーズ】 → バトル開始処理
##
## 【効果】
## - result_idのクリーチャーに変身（永続）
## - 合体相手は捨て札へ
## - タイルのクリーチャーデータも更新
##
## 【実装済みクリーチャー】
## - アンドロギア(406) + ビーストギア(434) → ギアリオン(408)
## - グランギア(409) + スカイギア(419) → アンドロギア(406)
## - スカイギア(419) + グランギア(409) → アンドロギア(406)
##
## @version 1.0
## @date 2025-12-10


## 合体スキルを持っているかチェック
##
## @param creature_data クリーチャーデータ
## @return 合体スキルを持っているか
static func has_merge_skill(creature_data: Dictionary) -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	return "合体" in keywords


## 合体相手のIDを取得
##
## @param creature_data クリーチャーデータ
## @return 合体相手のID（-1 = 合体スキルなし）
static func get_merge_partner_id(creature_data: Dictionary) -> int:
	if not has_merge_skill(creature_data):
		return -1
	
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var merge_condition = keyword_conditions.get("合体", {})
	
	return merge_condition.get("partner_id", -1)


## 合体結果のIDを取得
##
## @param creature_data クリーチャーデータ
## @return 合体結果のID（-1 = 合体スキルなし）
static func get_merge_result_id(creature_data: Dictionary) -> int:
	if not has_merge_skill(creature_data):
		return -1
	
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var merge_condition = keyword_conditions.get("合体", {})
	
	return merge_condition.get("result_id", -1)


## 手札に合体相手がいるかチェック
##
## @param creature_data バトル参加クリーチャーのデータ
## @param hand_cards 手札のカード配列
## @return 合体相手のカードインデックス（-1 = いない）
static func find_merge_partner_in_hand(creature_data: Dictionary, hand_cards: Array) -> int:
	var partner_id = get_merge_partner_id(creature_data)
	if partner_id == -1:
		return -1
	
	for i in range(hand_cards.size()):
		var card = hand_cards[i]
		if card.get("id", -1) == partner_id:
			return i
	
	return -1


## 合体可能かチェック（手札と魔力）
##
## @param creature_data バトル参加クリーチャーのデータ
## @param hand_cards 手札のカード配列
## @param player_magic プレイヤーの現在魔力
## @return 合体可能か
static func can_merge(creature_data: Dictionary, hand_cards: Array, player_magic: int) -> bool:
	# 合体スキルチェック
	if not has_merge_skill(creature_data):
		return false
	
	# 手札に合体相手がいるかチェック
	var partner_index = find_merge_partner_in_hand(creature_data, hand_cards)
	if partner_index == -1:
		return false
	
	# 魔力チェック
	var partner_card = hand_cards[partner_index]
	var partner_cost = partner_card.get("cost", {})
	var mp_cost = partner_cost.get("mp", 0) if partner_cost is Dictionary else partner_cost
	
	return player_magic >= mp_cost


## 合体相手のコストを取得
##
## @param hand_cards 手札のカード配列
## @param partner_index 合体相手のカードインデックス
## @return コスト（魔力消費量）
static func get_merge_cost(hand_cards: Array, partner_index: int) -> int:
	if partner_index < 0 or partner_index >= hand_cards.size():
		return 0
	
	var partner_card = hand_cards[partner_index]
	var cost = partner_card.get("cost", {})
	
	if cost is Dictionary:
		return cost.get("mp", 0)
	return cost


## 合体効果を適用
##
## @param participant バトル参加者
## @param hand_cards 手札のカード配列
## @param player_id プレイヤーID
## @param card_system カードシステム参照
## @param board_system ボードシステム参照
## @param player_system プレイヤーシステム参照
## @return 結果辞書 { "success": bool, "partner_index": int, "cost": int, "result_creature": Dictionary }
static func apply_merge_effect(
	participant: BattleParticipant,
	hand_cards: Array,
	player_id: int,
	card_system,
	board_system,
	player_system
) -> Dictionary:
	var result = {
		"success": false,
		"partner_index": -1,
		"cost": 0,
		"result_creature": {}
	}
	
	var creature_data = participant.creature_data
	
	# 合体スキルチェック
	if not has_merge_skill(creature_data):
		return result
	
	# 手札に合体相手がいるかチェック
	var partner_index = find_merge_partner_in_hand(creature_data, hand_cards)
	if partner_index == -1:
		print("[合体] 手札に合体相手がいません")
		return result
	
	# 魔力チェック
	var player_magic = player_system.get_magic(player_id) if player_system else 0
	var cost = get_merge_cost(hand_cards, partner_index)
	
	if player_magic < cost:
		print("[合体] 魔力不足: 必要%dG, 現在%dG" % [cost, player_magic])
		return result
	
	# 合体結果のクリーチャーデータを取得
	var result_id = get_merge_result_id(creature_data)
	var result_creature = CardLoader.get_card_by_id(result_id)
	
	if result_creature.is_empty():
		print("[合体] 合体結果のクリーチャーが見つかりません: ID=%d" % result_id)
		return result
	
	# 合体相手の情報を取得（ログ用）
	var partner_card = hand_cards[partner_index]
	var partner_name = partner_card.get("name", "?")
	var original_name = creature_data.get("name", "?")
	var result_name = result_creature.get("name", "?")
	
	print("[合体] %s + %s → %s" % [original_name, partner_name, result_name])
	
	# 魔力消費
	if player_system:
		player_system.add_magic(player_id, -cost)
		print("[合体] 魔力消費: %dG" % cost)
	
	# 合体相手を捨て札へ
	if card_system:
		card_system.discard_card(player_id, partner_index, "merge")
		print("[合体] %s を捨て札へ" % partner_name)
	
	# クリーチャーデータを更新（永続化用のフィールドを保持）
	var new_creature_data = result_creature.duplicate(true)
	
	# 永続化フィールドの初期化
	if not new_creature_data.has("base_up_hp"):
		new_creature_data["base_up_hp"] = 0
	if not new_creature_data.has("base_up_ap"):
		new_creature_data["base_up_ap"] = 0
	if not new_creature_data.has("permanent_effects"):
		new_creature_data["permanent_effects"] = []
	if not new_creature_data.has("temporary_effects"):
		new_creature_data["temporary_effects"] = []
	if not new_creature_data.has("map_lap_count"):
		new_creature_data["map_lap_count"] = 0
	
	# current_hpの初期化
	var max_hp = new_creature_data.get("hp", 0) + new_creature_data.get("base_up_hp", 0)
	new_creature_data["current_hp"] = max_hp
	
	# タイルインデックスを保持
	var tile_index = creature_data.get("tile_index", participant.tile_index)
	new_creature_data["tile_index"] = tile_index
	
	# BattleParticipantのcreature_dataを更新
	participant.creature_data = new_creature_data
	participant.base_ap = new_creature_data.get("ap", 0)
	participant.current_ap = participant.base_ap
	participant.base_hp = new_creature_data.get("hp", 0)
	participant.current_hp = max_hp
	
	# タイルのcreature_dataを更新（永続化）
	if board_system and board_system.tile_nodes.has(tile_index):
		var tile = board_system.tile_nodes[tile_index]
		tile.creature_data = new_creature_data
		print("[合体] タイル%d のクリーチャーデータを更新（永続化）" % tile_index)
	
	result["success"] = true
	result["partner_index"] = partner_index
	result["cost"] = cost
	result["result_creature"] = new_creature_data
	
	print("[合体] 完了: %s (HP:%d AP:%d)" % [result_name, max_hp, participant.base_ap])
	
	return result


# ============================================================
# 統一インターフェース（ItemPhaseHandler/TileActionProcessor用）
# ============================================================

## 合体を実行（BattleParticipantなしバージョン）
##
## ItemPhaseHandlerやTileActionProcessorから呼び出す統一インターフェース
## タイル更新は行わない（呼び出し側の責務）
##
## @param creature_data 合体元クリーチャーデータ
## @param partner_index 手札の合体相手インデックス
## @param player_id プレイヤーID
## @param card_system CardSystem参照
## @param player_system PlayerSystem参照
## @param game_flow_manager GameFlowManager参照（コスト修正用、オプション）
## @return Dictionary { success, result_creature, cost, partner_data }
static func execute_merge(
	creature_data: Dictionary,
	partner_index: int,
	player_id: int,
	card_system,
	player_system,
	game_flow_manager = null
) -> Dictionary:
	var result = {
		"success": false,
		"result_creature": {},
		"cost": 0,
		"partner_data": {}
	}
	
	# 合体スキルチェック
	if not has_merge_skill(creature_data):
		print("[SkillMerge] 合体スキルなし")
		return result
	
	# 手札を取得
	if not card_system:
		print("[SkillMerge] card_systemがnull")
		return result
	
	var hand = card_system.get_all_cards_for_player(player_id)
	if partner_index < 0 or partner_index >= hand.size():
		print("[SkillMerge] 無効なパートナーインデックス: %d" % partner_index)
		return result
	
	var partner_data = hand[partner_index]
	var partner_id = partner_data.get("id", -1)
	var expected_partner_id = get_merge_partner_id(creature_data)
	
	# 合体相手のIDを確認
	if partner_id != expected_partner_id:
		print("[SkillMerge] 合体相手が一致しない: expected=%d, actual=%d" % [expected_partner_id, partner_id])
		return result
	
	# コスト計算
	var cost = get_merge_cost(hand, partner_index)
	
	# ライフフォース呪いチェック
	if game_flow_manager and game_flow_manager.spell_cost_modifier:
		cost = game_flow_manager.spell_cost_modifier.get_modified_cost(player_id, partner_data)
	
	# 魔力チェック
	var player_magic = player_system.get_magic(player_id) if player_system else 0
	if player_magic < cost:
		print("[SkillMerge] 魔力不足: 必要%dG, 現在%dG" % [cost, player_magic])
		return result
	
	# 合体結果のクリーチャーを取得
	var result_id = get_merge_result_id(creature_data)
	var result_creature = CardLoader.get_card_by_id(result_id)
	
	if result_creature.is_empty():
		print("[SkillMerge] 合体結果のクリーチャーが見つかりません: ID=%d" % result_id)
		return result
	
	var original_name = creature_data.get("name", "?")
	var partner_name = partner_data.get("name", "?")
	var result_name = result_creature.get("name", "?")
	
	print("[SkillMerge] %s + %s → %s" % [original_name, partner_name, result_name])
	
	# 魔力消費
	if player_system:
		player_system.add_magic(player_id, -cost)
		print("[SkillMerge] 魔力消費: %dG" % cost)
	
	# 合体相手を捨て札へ
	if card_system:
		card_system.discard_card(player_id, partner_index, "merge")
		print("[SkillMerge] %s を捨て札へ" % partner_name)
	
	# 合体後のクリーチャーデータを準備
	var new_creature_data = _create_merged_creature_data(result_creature, creature_data)
	
	result["success"] = true
	result["result_creature"] = new_creature_data
	result["cost"] = cost
	result["partner_data"] = partner_data
	result["result_name"] = result_name
	
	var max_hp = new_creature_data.get("current_hp", 0)
	print("[SkillMerge] 完了: %s (HP:%d AP:%d)" % [result_name, max_hp, new_creature_data.get("ap", 0)])
	
	return result


## 合体後のクリーチャーデータを作成（内部ヘルパー）
static func _create_merged_creature_data(result_creature: Dictionary, original_creature: Dictionary) -> Dictionary:
	var new_creature_data = result_creature.duplicate(true)
	
	# 永続化フィールドの初期化
	if not new_creature_data.has("base_up_hp"):
		new_creature_data["base_up_hp"] = 0
	if not new_creature_data.has("base_up_ap"):
		new_creature_data["base_up_ap"] = 0
	if not new_creature_data.has("permanent_effects"):
		new_creature_data["permanent_effects"] = []
	if not new_creature_data.has("temporary_effects"):
		new_creature_data["temporary_effects"] = []
	if not new_creature_data.has("map_lap_count"):
		new_creature_data["map_lap_count"] = 0
	
	# current_hpの初期化
	var max_hp = new_creature_data.get("hp", 0) + new_creature_data.get("base_up_hp", 0)
	new_creature_data["current_hp"] = max_hp
	
	# タイルインデックスを保持
	var tile_index = original_creature.get("tile_index", -1)
	if tile_index >= 0:
		new_creature_data["tile_index"] = tile_index
	
	# 合体情報を追加（バトル画面表示用）
	new_creature_data["_was_merged"] = true
	new_creature_data["_merged_result_name"] = new_creature_data.get("name", "?")
	
	return new_creature_data
