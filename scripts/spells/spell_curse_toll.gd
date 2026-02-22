extends Node
class_name SpellCurseToll

# 通行料刻印システム
# セプター刻印: toll_share, toll_disable, toll_fixed
# ドミニオ刻印: toll_multiplier, peace
# ドキュメント: docs/design/spells/通行料刻印_final.md

# 参照
var spell_curse: SpellCurse
var skill_toll_change: SkillTollChange = null
var creature_manager = null

# 初期化
func setup(curse_system: SpellCurse, toll_skill: SkillTollChange = null, creature_mgr = null):
	spell_curse = curse_system
	skill_toll_change = toll_skill
	creature_manager = creature_mgr

# ========================================
# セプター刻印付与
# ========================================

## toll_share: 他プレイヤーの通行料50%を獲得
func apply_toll_share(player_id: int, duration: int = 5, caster_id: int = -1):
	spell_curse.curse_player(player_id, "toll_share", duration, {
		"name": "徴収",
		"ratio": 0.5
	}, caster_id)

## toll_disable: 通行料を支払わない
func apply_toll_disable(player_id: int, duration: int = 2):
	spell_curse.curse_player(player_id, "toll_disable", duration, {
		"name": "免罪"
	})

## toll_fixed: 通行料を固定値に設定
func apply_toll_fixed(player_id: int, value: int = 200, duration: int = 3):
	spell_curse.curse_player(player_id, "toll_fixed", duration, {
		"name": "通行料" + str(value),
		"value": value
	})

## invasion_disable: 侵略できない（トゥルース用）
func apply_invasion_disable(player_id: int, duration: int = 2):
	spell_curse.curse_player(player_id, "invasion_disable", duration, {
		"name": "休戦"
	})

# ========================================
# ドミニオ刻印付与
# ========================================

## toll_multiplier: 通行料を倍率で増加
func apply_toll_multiplier(tile_index: int, multiplier: float = 1.5):
	spell_curse.curse_creature(tile_index, "toll_multiplier", -1, {
		"name": "通行料" + str(int(multiplier * 100)) + "%",
		"multiplier": multiplier
	})

## toll_half_curse: 通行料半減（アルカナアーツ専用）
func apply_toll_half_curse(tile_index: int, duration: int = 3):
	spell_curse.curse_creature(tile_index, "toll_multiplier", duration, {
		"name": "通行料半減",
		"multiplier": 0.5
	})

## peace: 敵移動除外＋戦闘不可＋通行料0
func apply_peace(tile_index: int):
	spell_curse.curse_creature(tile_index, "peace", -1, {
		"name": "安寧",
		"invasion_disable": true,
		"toll_zero": true
	})

## creature_toll_disable: クリーチャー単体の免罪（スキュラ等）
func apply_creature_toll_disable(tile_index: int, duration: int = -1):
	spell_curse.curse_creature(tile_index, "creature_toll_disable", duration, {
		"name": "免罪"
	})

# ========================================
# 汎用刻印適用（アルカナアーツ用）
# ========================================

## スペル効果から通行料刻印を適用
func apply_curse_from_effect(effect: Dictionary, tile_index: int, player_id: int = -1, caster_id: int = -1):
	var effect_type = effect.get("effect_type", "")
	var duration = effect.get("duration", -1)
	
	match effect_type:
		"curse_toll_half":
			apply_toll_half_curse(tile_index, duration)
		
		"toll_multiplier", "curse_toll_multiplier":
			var multiplier = effect.get("multiplier", 1.5)
			apply_toll_multiplier(tile_index, multiplier)
		
		"toll_disable", "curse_toll_disable":
			apply_toll_disable(player_id, duration)
		
		"toll_fixed", "curse_toll_fixed":
			var value = effect.get("value", 200)
			apply_toll_fixed(player_id, value, duration)
		
		"toll_share", "curse_toll_share":
			apply_toll_share(player_id, duration, caster_id)
		
		"peace", "curse_peace":
			apply_peace(tile_index)
		
		_:
			print("[SpellCurseToll] 未対応の効果タイプ: ", effect_type)

# ========================================
# 通行料計算（統合版）
# ========================================

## 最終通行料を計算（Dictionary 形式で戻る）
## ドミニオ刻印（peace, toll_multiplier）とセプター刻印（toll_disable, toll_fixed, toll_share）を適用
func calculate_final_toll(tile_index: int, payer_id: int, receiver_id: int, base_toll: int) -> Dictionary:
	var final_toll = base_toll
	var bonus_toll = 0
	var bonus_receiver_id = -1
	
	# ========================================
	# ドミニオ刻印判定（peace, toll_multiplier）
	# ========================================
	var land_curse = spell_curse.get_creature_curse(tile_index)
	var land_curse_type = land_curse.get("curse_type", "")
	
	# peace: 通行料0（最優先）
	if land_curse_type == "peace":
		print("[通行料刻印] peace により通行料 = 0")
		return {
			"main_toll": 0,
			"bonus_toll": 0,
			"bonus_receiver_id": -1
		}
	
	# creature_toll_disable: クリーチャー単体の免罪（スキュラ等）
	if land_curse_type == "creature_toll_disable":
		print("[通行料刻印] creature_toll_disable により通行料 = 0")
		return {
			"main_toll": 0,
			"bonus_toll": 0,
			"bonus_receiver_id": -1
		}
	
	# toll_multiplier: 倍率適用
	if land_curse_type == "toll_multiplier":
		var multiplier = land_curse.get("params", {}).get("multiplier", 1.0)
		final_toll = int(final_toll * multiplier)
		print("[通行料刻印] ", land_curse.get("name"), " により通行料 = ", final_toll)
		return {
			"main_toll": final_toll,
			"bonus_toll": 0,
			"bonus_receiver_id": -1
		}
	
	# ========================================
	# セプター刻印判定（支払い側）
	# ========================================
	var payer_curse = spell_curse.get_player_curse(payer_id)
	var payer_curse_type = payer_curse.get("curse_type", "")
	
	# toll_disable: 支払わない（最優先）
	if payer_curse_type == "toll_disable":
		print("[通行料刻印] ", payer_curse.get("name"), " により支払い0")
		return {
			"main_toll": 0,
			"bonus_toll": 0,
			"bonus_receiver_id": -1
		}
	
	# ========================================
	# セプター刻印判定（受取側）
	# ========================================
	var receiver_curse = spell_curse.get_player_curse(receiver_id)
	var receiver_curse_type = receiver_curse.get("curse_type", "")
	
	# toll_fixed: 固定値に変更
	if receiver_curse_type == "toll_fixed":
		var fixed_value = receiver_curse.get("params", {}).get("value", final_toll)
		final_toll = fixed_value
		print("[通行料刻印] ", receiver_curse.get("name"), " により支払い = ", final_toll)
		return {
			"main_toll": final_toll,
			"bonus_toll": 0,
			"bonus_receiver_id": -1
		}
	
	# toll_share: 副収入化（ドリームトレイン）
	if receiver_curse_type == "toll_share":
		# SpellCurse から刻印の付与者を取得（刻印情報に付与者IDが保存されている）
		var curse_caster = receiver_curse.get("caster_id", receiver_id)
		var ratio = receiver_curse.get("params", {}).get("ratio", 0.5)
		bonus_toll = int(final_toll * ratio)
		bonus_receiver_id = curse_caster  # 刻印の付与者（ドリームトレインを使ったプレイヤー）が副収入を得る
		print("[通行料刻印] ", receiver_curse.get("name"), " により副収入 ", bonus_toll, "EP (受取: プレイヤー", bonus_receiver_id + 1, ")")
		return {
			"main_toll": final_toll,
			"bonus_toll": bonus_toll,
			"bonus_receiver_id": bonus_receiver_id
		}
	
	# ========================================
	# クリーチャースキル判定（toll_change）
	# ========================================
	if skill_toll_change and creature_manager:
		var creature = creature_manager.get_data_ref(tile_index)
		if creature and not creature.is_empty():
			var ability_parsed = creature.get("ability_parsed", {})
			var toll_effect = skill_toll_change.get_toll_change_effect(ability_parsed)
			
			if not toll_effect.is_empty():
				var creature_name = creature.get("name", "Unknown")
				var final_toll_with_skill = skill_toll_change.calculate_final_toll(final_toll, toll_effect)
				print("[通行料スキル] ", creature_name, " により通行料 ", final_toll, "EP → ", final_toll_with_skill, "EP")
				return {
					"main_toll": final_toll_with_skill,
					"bonus_toll": 0,
					"bonus_receiver_id": -1
				}
	
	return {
		"main_toll": final_toll,
		"bonus_toll": 0,
		"bonus_receiver_id": -1
	}

## タイル刻印による通行料補正を適用（表示用・player_id不要）
## peace, creature_toll_disable → 0、toll_multiplier → 倍率適用
func apply_tile_curse_to_toll(tile_index: int, base_toll: int) -> int:
	if not spell_curse:
		return base_toll
	var land_curse = spell_curse.get_creature_curse(tile_index)
	var curse_type = land_curse.get("curse_type", "")
	if curse_type == "peace" or curse_type == "creature_toll_disable":
		return 0
	if curse_type == "toll_multiplier":
		var multiplier = land_curse.get("params", {}).get("multiplier", 1.0)
		return int(base_toll * multiplier)
	return base_toll

## peace 刻印の有無を確認（移動除外判定用）
func has_peace_curse(tile_index: int) -> bool:
	var curse = spell_curse.get_creature_curse(tile_index)
	return curse.get("curse_type") == "peace"

## peace 刻印の有無を確認（戦闘UI表示判定用）
func is_invasion_disabled(tile_index: int) -> bool:
	var curse = spell_curse.get_creature_curse(tile_index)
	if curse.get("curse_type") == "peace":
		return curse.get("params", {}).get("invasion_disable", false)
	return false

## プレイヤーが休戦刻印を持っているか（トゥルース用）
func is_player_invasion_disabled(player_id: int) -> bool:
	var curse = spell_curse.get_player_curse(player_id)
	return curse.get("curse_type") == "invasion_disable"

## クリーチャーが鉄壁を持つかチェック（グルイースラッグ、ランドアーチン等）
func is_creature_invasion_immune(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	var ability_parsed = creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	return "鉄壁" in keywords

## peace 刻印がドミニオのクリーチャーにあるか確認（通行料判定用）
func has_peace_curse_on_land(tile_index: int) -> bool:
	var curse = spell_curse.get_creature_curse(tile_index)
	if curse.get("curse_type") == "peace":
		return curse.get("params", {}).get("toll_zero", false)
	return false

## 敵プレイヤーが peace 刻印ドミニオへの移動可能かチェック
## 枷な場合は false を返す
func can_move_to_land(tile_index: int, moving_player_id: int, land_owner_id: int) -> bool:
	# peace 刻印がある場合、敵プレイヤーは枷
	if has_peace_curse(tile_index):
		# ドミニオ所有者は移動可能、他のプレイヤーは不可
		if moving_player_id != land_owner_id:
			return false
	return true
