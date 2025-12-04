class_name CreatureSynthesis
extends RefCounted

## クリーチャー合成システム
## 召喚時にカードを犠牲にして、ステータス上昇または変身を行う

# ============ 定数 ============

## 合成条件タイプ
const CONDITION_ELEMENT = "element"        # 特定属性のカード
const CONDITION_CURSE_SPELL = "curse_spell"  # 呪いスペル
const CONDITION_ITEM = "item"              # アイテムカード
const CONDITION_CREATURE = "creature"      # クリーチャーカード

## 合成効果タイプ
const EFFECT_STAT_BOOST = "stat_boost"     # ステータス上昇
const EFFECT_TRANSFORM = "transform"       # 変身

## 呪いスペルに該当するspell_type
const CURSE_SPELL_TYPES = ["単体特殊能力付与", "複数特殊能力付与"]

# ============ 参照 ============

var card_loader = null  # 変身先カード取得用


# ============ 初期化 ============

func _init(loader = null):
	card_loader = loader


# ============ 判定 ============

## このクリーチャーが合成効果を持つか判定
func has_synthesis(creature_data: Dictionary) -> bool:
	return creature_data.has("synthesis")


## 合成条件を満たすか判定
func check_condition(creature_data: Dictionary, sacrifice_card: Dictionary) -> bool:
	if not has_synthesis(creature_data):
		return false
	
	if sacrifice_card.is_empty():
		return false
	
	var synthesis = creature_data.get("synthesis", {})
	var condition_type = synthesis.get("type", "")
	var condition_value = synthesis.get("condition", "")
	
	match condition_type:
		CONDITION_ELEMENT:
			# 特定属性のカード
			return sacrifice_card.get("element", "") == condition_value
		
		CONDITION_CURSE_SPELL:
			# 呪いスペル（単体特殊能力付与 or 複数特殊能力付与）
			if sacrifice_card.get("type", "") != "spell":
				return false
			var spell_type = sacrifice_card.get("spell_type", "")
			return spell_type in CURSE_SPELL_TYPES
		
		CONDITION_ITEM:
			# アイテムカード
			return sacrifice_card.get("type", "") == "item"
		
		CONDITION_CREATURE:
			# クリーチャーカード
			return sacrifice_card.get("type", "") == "creature"
	
	return false


# ============ 合成適用 ============

## 合成効果を適用
## 戻り値: 適用後のcreature_data（変身の場合は別クリーチャー）
func apply_synthesis(creature_data: Dictionary, sacrifice_card: Dictionary, is_synthesized: bool) -> Dictionary:
	if not is_synthesized:
		return creature_data
	
	var synthesis = creature_data.get("synthesis", {})
	var effect_type = synthesis.get("effect_type", EFFECT_STAT_BOOST)
	
	match effect_type:
		EFFECT_STAT_BOOST:
			return _apply_stat_boost(creature_data, synthesis)
		
		EFFECT_TRANSFORM:
			return _apply_transform(creature_data, sacrifice_card, synthesis)
	
	return creature_data


## ステータス上昇を適用
func _apply_stat_boost(creature_data: Dictionary, synthesis: Dictionary) -> Dictionary:
	var result = creature_data.duplicate(true)
	var effect = synthesis.get("effect", {})
	
	# AP上昇（base_apを使用）
	if effect.has("ap"):
		var bonus_ap = effect["ap"]
		var current_base_ap = result.get("base_ap", result.get("ap", 0))
		result["base_ap"] = current_base_ap + bonus_ap
		result["ap"] = result.get("ap", 0) + bonus_ap
		print("[CreatureSynthesis] base_ap+%d → %d" % [bonus_ap, result["base_ap"]])
	
	# MHP上昇（base_hpを使用）
	if effect.has("mhp"):
		var bonus_mhp = effect["mhp"]
		var current_base_hp = result.get("base_hp", result.get("hp", 0))
		result["base_hp"] = current_base_hp + bonus_mhp
		result["hp"] = result.get("hp", 0) + bonus_mhp
		print("[CreatureSynthesis] base_hp%+d → %d" % [bonus_mhp, result["base_hp"]])
	
	# 合成済みフラグと元カードID（手札に戻す時に使用）
	result["is_synthesized"] = true
	result["synthesis_type"] = "stat_boost"
	result["original_card_id"] = creature_data.get("id", -1)
	
	return result


## 変身を適用
func _apply_transform(creature_data: Dictionary, sacrifice_card: Dictionary, synthesis: Dictionary) -> Dictionary:
	var transform_target = synthesis.get("transform_to", "")
	
	# "sacrifice" の場合は犠牲カードに変身
	if transform_target == "sacrifice":
		if sacrifice_card.get("type", "") == "creature":
			var result = sacrifice_card.duplicate(true)
			result["is_synthesized"] = true
			result["synthesis_type"] = "transform"
			result["transformed_from"] = creature_data.get("name", "")
			print("[CreatureSynthesis] %s → %s に変身（犠牲クリーチャー）" % [
				creature_data.get("name", "?"),
				result.get("name", "?")
			])
			return result
		else:
			push_error("[CreatureSynthesis] 犠牲カードがクリーチャーではありません")
			return creature_data
	
	# 特定のクリーチャーIDに変身
	if card_loader and transform_target is int:
		var target_card = card_loader.get_card_by_id(transform_target)
		if not target_card.is_empty():
			var result = target_card.duplicate(true)
			result["is_synthesized"] = true
			result["synthesis_type"] = "transform"
			result["transformed_from"] = creature_data.get("name", "")
			print("[CreatureSynthesis] %s → %s に変身（ID: %d）" % [
				creature_data.get("name", "?"),
				result.get("name", "?"),
				transform_target
			])
			return result
		else:
			push_error("[CreatureSynthesis] 変身先クリーチャーID %d が見つかりません" % transform_target)
	
	# 変身先名で検索
	if card_loader and transform_target is String and not transform_target.is_empty():
		var target_card = _find_card_by_name(transform_target)
		if not target_card.is_empty():
			var result = target_card.duplicate(true)
			result["is_synthesized"] = true
			result["synthesis_type"] = "transform"
			result["transformed_from"] = creature_data.get("name", "")
			print("[CreatureSynthesis] %s → %s に変身" % [
				creature_data.get("name", "?"),
				result.get("name", "?")
			])
			return result
		else:
			push_error("[CreatureSynthesis] 変身先クリーチャー '%s' が見つかりません" % transform_target)
	
	return creature_data


## カード名で検索
func _find_card_by_name(card_name: String) -> Dictionary:
	if not card_loader:
		return {}
	
	for card in card_loader.all_cards:
		if card.get("name", "") == card_name:
			return card
	
	return {}
