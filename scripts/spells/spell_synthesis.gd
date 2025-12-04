# SpellSynthesis - スペル合成システム
# スペル使用時のカード犠牲による効果強化を管理
class_name SpellSynthesis


# ============ 合成タイプ定数 ============

const SYNTHESIS_TYPE_SAME_CARD = "same_card"           # 同名カード
const SYNTHESIS_TYPE_ANY_SPELL = "any_spell"           # 任意スペル
const SYNTHESIS_TYPE_SINGLE_TARGET_SPELL = "single_target_spell"  # 単体対象スペル
const SYNTHESIS_TYPE_CREATURE = "creature"             # クリーチャー
const SYNTHESIS_TYPE_ITEM = "item"                     # アイテム


# ============ 参照 ============

var card_sacrifice_helper: CardSacrificeHelper


# ============ 初期化 ============

func _init(sacrifice_helper: CardSacrificeHelper = null) -> void:
	card_sacrifice_helper = sacrifice_helper


func set_sacrifice_helper(helper: CardSacrificeHelper) -> void:
	card_sacrifice_helper = helper


# ============ 判定 ============

## このスペルがカード犠牲を必要とするか
func requires_sacrifice(spell_data: Dictionary) -> bool:
	# CardSystemで正規化された後は cost_cards_sacrifice に保存される
	if spell_data.get("cost_cards_sacrifice", 0) > 0:
		return true
	
	# 元のJSON構造がそのまま残っている場合
	var cost = spell_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		if cost.get("cards_sacrifice", 0) > 0:
			return true
	
	return false


## このスペルが合成効果を持つか
func has_synthesis(spell_data: Dictionary) -> bool:
	return spell_data.has("synthesis")


## 合成条件を満たすか判定
func check_condition(spell_data: Dictionary, sacrifice_card: Dictionary) -> bool:
	if not has_synthesis(spell_data):
		return false
	
	if sacrifice_card.is_empty():
		return false
	
	var synthesis = spell_data.get("synthesis", {})
	var synthesis_type = synthesis.get("type", "")
	
	match synthesis_type:
		SYNTHESIS_TYPE_SAME_CARD:
			# 同名カード判定
			return sacrifice_card.get("id") == spell_data.get("id")
		
		SYNTHESIS_TYPE_ANY_SPELL:
			# 任意スペル判定
			return sacrifice_card.get("type") == "spell"
		
		SYNTHESIS_TYPE_SINGLE_TARGET_SPELL:
			# 単体対象スペル判定
			return sacrifice_card.get("type") == "spell" \
				and sacrifice_card.get("spell_type") == "単体対象"
		
		SYNTHESIS_TYPE_CREATURE:
			# クリーチャー判定
			return sacrifice_card.get("type") == "creature"
		
		SYNTHESIS_TYPE_ITEM:
			# アイテム判定
			return sacrifice_card.get("type") == "item"
	
	return false


# ============ override適用 ============

## 合成時のoverride適用
## is_synthesized: 合成が成立したかどうか
## 戻り値: 適用後のeffect_parsed（合成成立時はoverride済み）
func apply_overrides(spell_data: Dictionary, is_synthesized: bool) -> Dictionary:
	var effect_parsed = spell_data.get("effect_parsed", {})
	
	if not is_synthesized:
		return effect_parsed.duplicate(true)
	
	var synthesis = spell_data.get("synthesis", {})
	var result = effect_parsed.duplicate(true)
	
	# 数値変更 (value_override)
	if synthesis.has("value_override"):
		if result.has("effects") and result["effects"].size() > 0:
			result["effects"][0]["value"] = synthesis["value_override"]
	
	# 対象範囲変更 (target_override)
	if synthesis.has("target_override"):
		var target_override = synthesis["target_override"]
		for key in target_override.keys():
			if key == "target_info":
				# target_infoはマージ
				if not result.has("target_info"):
					result["target_info"] = {}
				for sub_key in target_override["target_info"].keys():
					result["target_info"][sub_key] = target_override["target_info"][sub_key]
			else:
				result[key] = target_override[key]
		
		# target_type: all_players の場合、effectsにall_players: trueを追加
		if target_override.get("target_type") == "all_players":
			if result.has("effects"):
				for effect in result["effects"]:
					effect["all_players"] = true
					# owner_filterもeffectsにコピー（サブサイド等で使用）
					var owner_filter = target_override.get("target_info", {}).get("owner_filter", "")
					if not owner_filter.is_empty():
						effect["owner_filter"] = owner_filter
	
	# 効果追加 (effects_add)
	if synthesis.has("effects_add"):
		if not result.has("effects"):
			result["effects"] = []
		for effect in synthesis["effects_add"]:
			result["effects"].append(effect.duplicate(true))
	
	# 効果置換 (effect_override)
	if synthesis.has("effect_override"):
		if result.has("effects") and result["effects"].size() > 0:
			var override = synthesis["effect_override"]
			for key in override.keys():
				result["effects"][0][key] = override[key]
	
	return result


# ============ 合成タイプ情報取得 ============

## 合成タイプを取得
func get_synthesis_type(spell_data: Dictionary) -> String:
	var synthesis = spell_data.get("synthesis", {})
	return synthesis.get("type", "")


## 合成タイプの説明を取得
func get_synthesis_type_description(synthesis_type: String) -> String:
	match synthesis_type:
		SYNTHESIS_TYPE_SAME_CARD:
			return "同名カード"
		SYNTHESIS_TYPE_ANY_SPELL:
			return "任意のスペル"
		SYNTHESIS_TYPE_SINGLE_TARGET_SPELL:
			return "単体対象スペル"
		SYNTHESIS_TYPE_CREATURE:
			return "クリーチャー"
		SYNTHESIS_TYPE_ITEM:
			return "アイテム"
	return "不明"
