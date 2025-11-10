extends Node

## アイテム復帰スキル処理
## 
## 使用したアイテムをブックまたは手札に戻すスキル
## - ブック復帰: デッキの一番上に戻る
## - 手札復帰: 即座に手札に戻る（手札上限を超えても追加）

class_name SkillItemReturn

## CardSystemへの参照
static var card_system_ref: CardSystem = null

## システム参照の設定
static func setup_systems(card_system: CardSystem) -> void:
	card_system_ref = card_system

## アイテム復帰のチェックと実行
## 
## @param participant: BattleParticipant - スキル保有者
## @param used_items: Array[Dictionary] - 使用したアイテムのリスト
## @param player_id: int - プレイヤーID
## @return Dictionary - 復帰結果
static func check_and_apply_item_return(participant: BattleParticipant, used_items: Array, player_id: int) -> Dictionary:
	if used_items.is_empty():
		return {"returned": false, "items": []}
	
	# 復帰効果を収集
	var return_effects = _get_return_effects(participant, used_items)
	
	if return_effects.is_empty():
		return {"returned": false, "items": []}
	
	var returned_items = []
	var returned_item_ids = []  # 重複チェック用
	
	# 各復帰効果に対して処理
	for return_effect in return_effects:
		var return_type = return_effect.get("return_type", "")
		var target = return_effect.get("target", "self")  # "self" or "all_items"
		
		# 復帰対象のアイテムを決定
		var items_to_return = []
		if target == "all_items":
			# ケンタウロスなど：全アイテムを復帰（ただし除外リストを考慮）
			var exclude_ids = return_effect.get("exclude_item_ids", [])
			var all_items = return_effect.get("used_items", used_items)
			
			for item in all_items:
				var item_id = item.get("id", -1)
				# 除外リストに含まれていないアイテムのみ追加
				if not item_id in exclude_ids:
					items_to_return.append(item)
		else:
			# 通常：そのアイテム自身のみ復帰
			items_to_return = [return_effect.get("item_data")]
		
		# 各アイテムを復帰
		for item_data in items_to_return:
			if item_data == null or item_data.is_empty():
				continue
			
			var item_id = item_data.get("id", -1)
			# 既に復帰済みのアイテムはスキップ
			if item_id in returned_item_ids:
				continue
			
			var success = false
			match return_type:
				"return_to_deck":
					# player_idを渡す
					success = _return_to_deck(player_id, item_data)
					if success:
						print("【アイテム復帰→ブック】", item_data.get("name", "?"))
				
				"return_to_hand":
					success = _return_to_hand(player_id, item_data)
					if success:
						print("【アイテム復帰→手札】", item_data.get("name", "?"))
			
			if success:
				returned_items.append(item_data)
				returned_item_ids.append(item_id)
	
	return {
		"returned": not returned_items.is_empty(),
		"items": returned_items,
		"count": returned_items.size()
	}

## 復帰効果の収集
## 
## クリーチャーのability_parsedと使用したアイテムのeffect_parsedから
## item_return効果を収集する
## 
## 優先順位: アイテム自身の復帰効果 > クリーチャーの全アイテム復帰
static func _get_return_effects(participant: BattleParticipant, used_items: Array) -> Array:
	var return_effects = []
	
	# アイテム自身に復帰効果があるかチェック
	var items_with_own_return = []
	
	# 1. 使用したアイテム自身の復帰効果を取得（優先）
	for item_data in used_items:
		var effect_parsed = item_data.get("effect_parsed", {})
		var item_effects = effect_parsed.get("effects", [])
		
		var has_own_return = false
		for effect in item_effects:
			if effect.get("effect_type") == "item_return":
				var trigger = effect.get("trigger", "")
				if trigger == "after_item_use":
					# アイテムデータを効果に追加（復帰処理で使用）
					var effect_with_item = effect.duplicate()
					effect_with_item["item_data"] = item_data
					effect_with_item["target"] = "self"  # アイテム自身
					return_effects.append(effect_with_item)
					has_own_return = true
		
		# アイテム自身に復帰効果がある場合は記録
		if has_own_return:
			items_with_own_return.append(item_data.get("id", -1))
	
	# 2. クリーチャーのスキルから復帰効果を取得（アイテム自身に効果がない場合のみ適用）
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var creature_effects = ability_parsed.get("effects", [])
	
	for effect in creature_effects:
		if effect.get("effect_type") == "item_return":
			var trigger = effect.get("trigger", "")
			if trigger == "after_item_use":
				var target = effect.get("target", "self")
				
				if target == "all_items":
					# 全アイテム復帰の場合、アイテム自身に復帰効果がないものだけを対象に
					var creature_effect = effect.duplicate()
					creature_effect["used_items"] = used_items
					creature_effect["exclude_item_ids"] = items_with_own_return
					return_effects.append(creature_effect)
				else:
					# 通常の復帰効果
					return_effects.append(effect)
	
	return return_effects

## アイテムをデッキのランダムな位置に戻す
## @param player_id: int - プレイヤーID（新システム用）
static func _return_to_deck(player_id: int, item_data: Dictionary) -> bool:
	if not card_system_ref:
		push_error("SkillItemReturn: CardSystemの参照が設定されていません")
		return false
	
	var card_id = item_data.get("id", -1)
	if card_id < 0:
		push_error("SkillItemReturn: 無効なカードID")
		return false
	
	# 新システム: プレイヤーの捨て札から削除
	if card_id in card_system_ref.player_discards[player_id]:
		card_system_ref.player_discards[player_id].erase(card_id)
	
	# 新システム: プレイヤーのデッキのランダムな位置に挿入
	var deck_size = card_system_ref.player_decks[player_id].size()
	if deck_size == 0:
		# デッキが空の場合は単純に追加
		card_system_ref.player_decks[player_id].append(card_id)
	else:
		# ランダムな位置を決定（0〜deck_size の範囲）
		var random_position = randi() % (deck_size + 1)
		card_system_ref.player_decks[player_id].insert(random_position, card_id)
	
	return true

## アイテムを手札に戻す
static func _return_to_hand(player_id: int, item_data: Dictionary) -> bool:
	if not card_system_ref:
		push_error("SkillItemReturn: CardSystemの参照が設定されていません")
		return false
	
	# CardSystemのreturn_card_to_hand()を使用
	# この関数は手札上限を超えても強制的に追加する
	return card_system_ref.return_card_to_hand(player_id, item_data)
