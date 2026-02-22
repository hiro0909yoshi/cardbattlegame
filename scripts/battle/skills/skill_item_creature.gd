class_name SkillItemCreature
extends RefCounted

## レリックスキル処理
##
## 対象クリーチャー:
## - 438: リビングアーマー - クリーチャー時AP+50
## - 439: リビングアムル - 蘇生[リビングアムル]（敵武器不使用時）
## - 440: リビングクローブ - AP&HP=他属性配置数×5
## - 441: リビングヘルム - 基本効果のみ
## - 442: リビングボム - 相討[HP20以下]

const LIVING_ARMOR_ID = 438
const LIVING_AMUL_ID = 439
const LIVING_CLOVE_ID = 440
const LIVING_HELM_ID = 441
const LIVING_BOMB_ID = 442


# ============================================================
# 判定関数
# ============================================================

## レリックかどうか判定
static func is_item_creature(card_data: Dictionary) -> bool:
	var keywords = card_data.get("ability_parsed", {}).get("keywords", [])
	return "レリック" in keywords


# ============================================================
# アイテムとして使用時
# ============================================================

## アイテムとして使用時の効果を適用
static func apply_as_item(participant, item_creature_data: Dictionary, _board_system) -> void:
	var creature_id = item_creature_data.get("id", 0)
	var item_name = item_creature_data.get("name", "???")
	print("[レリック効果] ", item_name, " (ID:", creature_id, ")")
	
	match creature_id:
		LIVING_CLOVE_ID:
			# リビングクローブ: other_element_countスキルを付与
			# 実際の処理はapply_as_creature()で行われる
			_grant_other_element_count_skill(participant)
			print("  [other_element_countスキル付与]")
		
		_:
			# その他: 基礎AP/HPをボーナスとして加算
			var base_ap = item_creature_data.get("ap", 0)
			var base_hp = item_creature_data.get("hp", 0)
			if base_ap > 0:
				participant.item_bonus_ap += base_ap
				participant.update_current_ap()
				print("  AP+", base_ap)
			if base_hp > 0:
				participant.item_bonus_hp += base_hp
				print("  HP+", base_hp)
	
	# スキル継承（相討等）
	_inherit_skills(participant, item_creature_data)


## other_element_countスキルを使用クリーチャーに付与
static func _grant_other_element_count_skill(participant) -> void:
	# ability_parsedがなければ初期化
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("effects"):
		participant.creature_data["ability_parsed"]["effects"] = []
	
	# other_element_count効果を追加
	var effect = {
		"effect_type": "other_element_count",
		"multiplier": 5,
		"exclude_neutral": true,
		"stat_changes": {"ap": true, "hp": true}
	}
	participant.creature_data["ability_parsed"]["effects"].append(effect)
	
	# フラグを立てる（apply_as_creatureで処理するため）
	participant.creature_data["has_living_clove_effect"] = true


# ============================================================
# クリーチャーとして戦闘時
# ============================================================

## クリーチャーとして戦闘時の効果を適用
static func apply_as_creature(participant, board_system) -> void:
	var creature_id = participant.creature_data.get("id", 0)
	
	match creature_id:
		LIVING_ARMOR_ID:
			# リビングアーマー: クリーチャー時AP+50（一時的バフ）
			participant.temporary_bonus_ap += 50
			participant.update_current_ap()
			print("【リビングアーマー】クリーチャー戦闘時 AP+50")
		
		LIVING_CLOVE_ID:
			# リビングクローブ: 基礎AP/HPを無視、計算値で設定
			apply_living_clove_stat(participant, board_system)


# ============================================================
# リビングボム: 相討[HP20以下]
# ============================================================

## HP閾値での自爆＋相討チェック（ダメージ後に呼び出す）
## Returns: 両者死亡などでバトルを終了すべき場合はtrue
static func check_hp_threshold_self_destruct(damaged, opponent) -> bool:
	if not damaged.is_alive():
		return false
	
	var ability_parsed = damaged.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var trigger = effect.get("trigger", "")
		
		if effect_type == "self_destruct_with_revenge" and trigger == "on_hp_threshold":
			var threshold = effect.get("hp_threshold", 0)
			var current_hp = damaged.current_hp
			
			# HP 1〜閾値の範囲に入った場合（0以下は普通に死亡）
			if current_hp > 0 and current_hp <= threshold:
				print("【相討[HP%d以下]発動】%s のHP %d <= %d" % [
					threshold,
					damaged.creature_data.get("name", "?"),
					current_hp,
					threshold
				])
				
				# 自分を即死させる
				damaged.instant_death_flag = true
				damaged.base_hp = 0
				damaged.current_hp = 0
				
				# 相手も相討で即死
				if opponent.is_alive():
					print("  → %s を相討で撃破！" % opponent.creature_data.get("name", "?"))
					opponent.instant_death_flag = true
					opponent.base_hp = 0
					opponent.current_hp = 0
				
				return true
	
	return false


# ============================================================
# リビングアムル: 蘇生[リビングアムル]（敵武器不使用時）
# ============================================================

## 蘇生チェック（死亡時に呼び出す）
## Returns: 復活する場合はクリーチャーID、しない場合は-1
static func check_revive_on_death(defeated, opponent) -> int:
	var ability_parsed = defeated.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		var trigger = effect.get("trigger", "")
		
		if effect_type == "revive" and trigger == "on_death":
			var condition = effect.get("condition", {})
			var creature_id = effect.get("creature_id", -1)
			
			# 条件チェック
			if not condition.is_empty():
				var condition_type = condition.get("type", "")
				if condition_type == "enemy_item_not_used":
					var item_category = condition.get("item_category", "")
					if not _check_enemy_item_not_used(opponent, item_category):
						print("【蘇生条件未達】敵が%sを使用" % item_category)
						continue
			
			print("【蘇生発動】→ クリーチャーID:", creature_id)
			return creature_id
	
	return -1


## 敵が特定カテゴリのアイテムを使用していないかチェック
static func _check_enemy_item_not_used(opponent, item_category: String) -> bool:
	var items = opponent.creature_data.get("items", [])
	
	for item in items:
		var item_type = item.get("item_type", "")
		if item_type == item_category:
			return false  # 使用している
	
	return true  # 使用していない


# ============================================================
# 共通処理
# ============================================================

## 他属性クリーチャー数を計算（盤面全体）
static func _calculate_other_element_count(board_system) -> int:
	if not board_system:
		return 0
	
	var other_count: int = 0
	var all_elements = ["fire", "water", "earth", "wind"]
	
	# リビングクローブはneutralなので、全4属性をカウント
	for element in all_elements:
		other_count += board_system.count_all_creatures_by_element(element)
	
	var multiplier: int = 5
	var result: int = other_count * multiplier
	print("  (他属性:", other_count, " × ", multiplier, " = ", result, ")")
	return result


## リビングクローブのステータス置換処理
## クリーチャー自身 or アイテムとして使用された場合に適用
static func apply_living_clove_stat(participant, board_system) -> void:
	var calculated_value = _calculate_other_element_count(board_system)
	
	# 基礎AP/HPを置換
	# creature_data["hp"]は元の値を維持（戦闘後の復元用）
	participant.base_hp = calculated_value
	participant.current_ap = calculated_value
	participant.current_hp = calculated_value
	
	print("【リビングクローブ効果】ST&HP=", calculated_value)


## スキルを継承（相討、蘇生等）
static func _inherit_skills(participant, item_creature_data: Dictionary) -> void:
	var ability_parsed = item_creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	var keywords = ability_parsed.get("keywords", [])
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	
	# ability_parsedがなければ初期化
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	if not participant.creature_data["ability_parsed"].has("effects"):
		participant.creature_data["ability_parsed"]["effects"] = []
	if not participant.creature_data["ability_parsed"].has("keywords"):
		participant.creature_data["ability_parsed"]["keywords"] = []
	if not participant.creature_data["ability_parsed"].has("keyword_conditions"):
		participant.creature_data["ability_parsed"]["keyword_conditions"] = {}
	
	# effectsをマージ（特殊処理済みのものは除く）
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		if effect_type in ["other_element_count", "as_creature_bonus"]:
			continue
		participant.creature_data["ability_parsed"]["effects"].append(effect.duplicate())
		print("  [効果継承] ", effect_type)
	
	# keywordsをマージ
	for keyword in keywords:
		if keyword == "レリック":
			continue
		if keyword not in participant.creature_data["ability_parsed"]["keywords"]:
			participant.creature_data["ability_parsed"]["keywords"].append(keyword)
			print("  [キーワード継承] ", keyword)
	
	# keyword_conditionsをマージ
	for key in keyword_conditions:
		participant.creature_data["ability_parsed"]["keyword_conditions"][key] = keyword_conditions[key].duplicate()
		print("  [キーワード条件継承] ", key)
