extends Node
class_name BattleSpecialEffects

# バトル特殊効果処理
# 即死、無効化、再生、死亡時能力などの特殊スキル処理を担当

# スキルモジュール
var _skill_legacy = preload("res://scripts/battle/skills/skill_legacy.gd")

var board_system_ref = null
var spell_draw_ref: SpellDraw = null
var spell_magic_ref: SpellMagic = null

func setup_systems(board_system, spell_draw = null, spell_magic = null):
	board_system_ref = board_system
	spell_draw_ref = spell_draw
	spell_magic_ref = spell_magic

## 無効化判定を行う
func check_nullify(attacker: BattleParticipant, defender: BattleParticipant, context: Dictionary) -> Dictionary:
	"""
	無効化判定を行う
	
	Returns:
		{
			"is_nullified": bool,  # 無効化されたか
			"reduction_rate": float  # 軽減率（0.0=完全無効化、0.5=50%軽減、1.0=無効化なし）
		}
	"""
	var ability_parsed = defender.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "無効化" in keywords:
		return {"is_nullified": false, "reduction_rate": 1.0}
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var nullify_conditions = keyword_conditions.get("無効化", [])
	
	# 無効化条件が配列でない場合（旧形式）は配列に変換
	if not nullify_conditions is Array:
		nullify_conditions = [nullify_conditions] if not nullify_conditions.is_empty() else []
	
	if nullify_conditions.is_empty():
		return {"is_nullified": false, "reduction_rate": 1.0}
	
	# 複数の無効化条件をチェック（いずれか1つでも該当すれば無効化）
	for nullify_condition in nullify_conditions:
		# 条件付き無効化の場合、先に条件をチェック
		var conditions = nullify_condition.get("conditions", [])
		if conditions.size() > 0:
			print("  【無効化条件チェック】条件数: ", conditions.size())
			var condition_checker = load("res://scripts/skills/condition_checker.gd").new()
			var all_conditions_met = true
			for condition in conditions:
				var condition_type = condition.get("condition_type", "")
				print("    条件タイプ: ", condition_type)
				if condition_type == "land_level_check":
					print("    土地レベル: ", context.get("tile_level", 1), 
						  " ", condition.get("operator", ">="), " ", condition.get("value", 1))
				if not condition_checker._evaluate_single_condition(condition, context):
					all_conditions_met = false
					break
			
			if not all_conditions_met:
				print("    → 条件不成立、この無効化はスキップ")
				continue  # 次の無効化条件へ
			print("    → 全条件成立")
		
		# 無効化タイプ別の判定
		var nullify_type = nullify_condition.get("nullify_type", "")
		var is_nullified = false
		
		match nullify_type:
			"element":
				is_nullified = _check_nullify_element(nullify_condition, attacker)
			"mhp_above":
				is_nullified = _check_nullify_mhp_above(nullify_condition, attacker)
			"mhp_below":
				is_nullified = _check_nullify_mhp_below(nullify_condition, attacker)
			"ap_below":
				is_nullified = _check_nullify_ap_below(nullify_condition, attacker)
			"ap_above":
				is_nullified = _check_nullify_ap_above(nullify_condition, attacker)
			"attacker_ap_above":
				is_nullified = _check_nullify_attacker_ap_above(nullify_condition, attacker, defender)
			"all_attacks":
				is_nullified = true  # 無条件で適用
			"has_ability":
				is_nullified = _check_nullify_has_ability(nullify_condition, attacker)
			"scroll_attack":
				is_nullified = attacker.is_using_scroll
			"normal_attack":
				is_nullified = not attacker.is_using_scroll
			_:
				print("【無効化】未知のタイプ: ", nullify_type)
				continue  # 次の無効化条件へ
		
		# いずれか1つでも無効化条件を満たせば無効化成立
		if is_nullified:
			var reduction_rate = nullify_condition.get("reduction_rate", 0.0)
			print("  【無効化成立】タイプ: ", nullify_type)
			return {"is_nullified": true, "reduction_rate": reduction_rate}
	
	# どの無効化条件も満たさなかった
	return {"is_nullified": false, "reduction_rate": 1.0}

## 属性無効化判定
func _check_nullify_element(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var attacker_element = attacker.creature_data.get("element", "")
	
	# 単一属性
	if condition.has("element"):
		var target_element = condition.get("element")
		return attacker_element == target_element
	
	# 複数属性
	if condition.has("elements"):
		var elements = condition.get("elements", [])
		return attacker_element in elements
	
	return false

## MHP以上無効化判定
func _check_nullify_mhp_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# BattleParticipantのget_max_hp()を使用
	return attacker.get_max_hp() >= threshold

## MHP以下無効化判定
func _check_nullify_mhp_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# BattleParticipantのget_max_hp()を使用
	return attacker.get_max_hp() <= threshold

## AP以下無効化判定
func _check_nullify_ap_below(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# 基礎AP = base_ap + base_up_ap
	var base_ap = attacker.creature_data.get("ap", 0)
	var base_up_ap = attacker.creature_data.get("base_up_ap", 0)
	var attacker_base_ap = base_ap + base_up_ap
	return attacker_base_ap <= threshold

## AP以上無効化判定
func _check_nullify_ap_above(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var threshold = condition.get("value", 0)
	# 基礎AP = base_ap + base_up_ap
	var base_ap = attacker.creature_data.get("ap", 0)
	var base_up_ap = attacker.creature_data.get("base_up_ap", 0)
	var attacker_base_ap = base_ap + base_up_ap
	return attacker_base_ap >= threshold

## 能力持ち無効化判定
func _check_nullify_has_ability(condition: Dictionary, attacker: BattleParticipant) -> bool:
	var ability = condition.get("ability", "")
	var attacker_keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
	return ability in attacker_keywords

## 攻撃者APが装備者より大きい場合の無効化判定（ラグドール用）
func _check_nullify_attacker_ap_above(_condition: Dictionary, attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	# 攻撃者の基礎AP
	var attacker_base_ap = attacker.creature_data.get("ap", 0)
	var attacker_base_up_ap = attacker.creature_data.get("base_up_ap", 0)
	var attacker_total_ap = attacker_base_ap + attacker_base_up_ap
	
	# 防御側（装備者）の基礎AP
	var defender_base_ap = defender.creature_data.get("ap", 0)
	var defender_base_up_ap = defender.creature_data.get("base_up_ap", 0)
	var defender_total_ap = defender_base_ap + defender_base_up_ap
	
	print("  [ラグドール判定] 攻撃者AP:", attacker_total_ap, " vs 装備者AP:", defender_total_ap)
	
	# 攻撃者のAPが装備者より大きい場合に無効化
	return attacker_total_ap > defender_total_ap

## 即死判定を行う
func check_instant_death(attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	# スクイドマントルチェック：防御側がスクイドマントルを持つ場合は即死無効化
	if defender.has_squid_mantle:
		print("【スクイドマントル】", attacker.creature_data.get("name", "?"), "の即死を無効化")
		return false
	
	# 即死スキルを持つかチェック
	var ability_parsed = attacker.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "即死" in keywords:
		return false
	
	print("【即死判定開始】", attacker.creature_data.get("name", "?"), " → ", defender.creature_data.get("name", "?"))
	
	# 即死条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	if instant_death_condition.is_empty():
		return false
	
	# 条件チェック
	if not _check_instant_death_condition(instant_death_condition, attacker, defender):
		return false
	
	# 確率判定
	var probability = instant_death_condition.get("probability", 0)
	var random_value = randf() * 100.0
	
	if random_value <= probability:
		print("【即死発動】", attacker.creature_data.get("name", "?"), " → ", defender.creature_data.get("name", "?"), " (", probability, "% 判定成功)")
		defender.instant_death_flag = true
		defender.base_hp = 0
		# update_current_hp() は呼ばない（current_hp が状態値になったため）
		return true
	else:
		print("【即死失敗】確率:", probability, "% 判定値:", int(random_value), "%")
		return false

## 即死条件をチェック
func _check_instant_death_condition(condition: Dictionary, attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"none":
			# 無条件
			return true
		
		"enemy_is_element", "enemy_element":
			# 敵が特定属性（複数対応）
			var defender_element = defender.creature_data.get("element", "")
			
			# 単一属性の場合（後方互換性）
			if condition.has("element"):
				var required_element = condition.get("element", "")
				if required_element == "全":
					return true
				if defender_element == required_element:
					print("【即死条件】敵が", required_element, "属性 → 条件満たす")
					return true
				else:
					print("【即死条件】敵が", defender_element, "属性（要求:", required_element, "）→ 条件不成立")
					return false
			
			# 複数属性の場合
			var required_elements = condition.get("elements", [])
			if typeof(required_elements) == TYPE_STRING:
				# 文字列の場合は配列に変換（後方互換性）
				if required_elements == "全":
					return true
				required_elements = [required_elements]
			
			if defender_element in required_elements:
				print("【即死条件】敵が", defender_element, "属性（要求:", required_elements, "）→ 条件満たす")
				return true
			else:
				print("【即死条件】敵が", defender_element, "属性（要求:", required_elements, "）→ 条件不成立")
				return false
		
		"enemy_type":
			# 敵が特定タイプ
			var required_type = condition.get("type", "")
			var defender_type = defender.creature_data.get("creature_type", "")
			
			if defender_type == required_type:
				print("【即死条件】敵が", required_type, "型 → 条件満たす")
				return true
			else:
				print("【即死条件】敵が", defender_type, "型（要求:", required_type, "）→ 条件不成立")
				return false
		
		"defender_ap_check":
			# 防御側のAPが一定以上（基本APで判定）
			var operator = condition.get("operator", ">=")
			var value = condition.get("value", 0)
			var defender_base_ap = defender.creature_data.get("ap", 0)  # 基本APで判定
			
			var meets_condition = false
			match operator:
				">=": meets_condition = defender_base_ap >= value
				">": meets_condition = defender_base_ap > value
				"==": meets_condition = defender_base_ap == value
			
			if meets_condition:
				print("【即死条件】防御側AP ", defender_base_ap, " ", operator, " ", value, " → 条件満たす")
				return true
			else:
				print("【即死条件】防御側AP ", defender_base_ap, " ", operator, " ", value, " → 条件不成立")
				return false
		
		"defender_role":
			# 使用者が防御側の場合のみ発動（キロネックス用）
			if not attacker.is_attacker:
				print("【即死条件】使用者が防御側 → 条件満たす")
				return true
			else:
				print("【即死条件】使用者が侵略側 → 条件不成立")
				return false
		
		"後手":
			# 後手条件（先制の逆）
			# この条件は先制判定で既に処理されているため、ここでは常にtrueを返す
			return true
		
		_:
			print("【即死条件】未知の条件タイプ:", condition_type)
			return false

## 再生スキル処理
func apply_regeneration(participant: BattleParticipant) -> void:
	# 生き残っていない場合は発動しない
	if not participant.is_alive():
		return
	
	# 再生キーワードチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "再生" in keywords:
		# 基本HPの最大値を取得（初期値）
		var max_base_hp = participant.creature_data.get("hp", 0)
		# 永続HP上昇の最大値を取得
		var max_base_up_hp = participant.creature_data.get("base_up_hp", 0)
		
		var healed = 0
		
		# base_hpを回復
		if participant.base_hp < max_base_hp:
			healed += max_base_hp - participant.base_hp
			participant.base_hp = max_base_hp
		
		# base_up_hpを回復
		if participant.base_up_hp < max_base_up_hp:
			healed += max_base_up_hp - participant.base_up_hp
			participant.base_up_hp = max_base_up_hp
		
		if healed > 0:
			# update_current_hp() は呼ばない（current_hp が状態値になったため）
			print("【再生発動】", participant.creature_data.get("name", "?"), 
				  " HP回復: +", healed, " → ", participant.current_hp)

## 防御側クリーチャーのHPを更新
func update_defender_hp(tile_info: Dictionary, defender: BattleParticipant) -> void:
	var tile_index = tile_info["index"]
	var creature_data = tile_info.get("creature", {}).duplicate()
	
	# 元のHPは触らない（不変）
	# creature_data["hp"] = そのまま
	
	# BattleParticipantのプロパティから永続バフを反映
	print("[update_defender_hp] 防御側の永続バフを反映:")
	print("  元のbase_up_hp: ", tile_info.get("creature", {}).get("base_up_hp", 0), " → ", defender.base_up_hp)
	print("  元のbase_up_ap: ", tile_info.get("creature", {}).get("base_up_ap", 0), " → ", defender.base_up_ap)
	creature_data["base_up_hp"] = defender.base_up_hp
	creature_data["base_up_ap"] = defender.base_up_ap
	
	# 現在HPを保存（新方式：状態値）
	creature_data["current_hp"] = defender.current_hp
	
	# タイルのクリーチャーデータを更新
	board_system_ref.tile_data_manager.tile_nodes[tile_index].creature_data = creature_data

## 死亡時効果のチェック（道連れ、雪辱など）
func check_on_death_effects(defeated: BattleParticipant, opponent: BattleParticipant) -> Dictionary:
	"""
	撃破された側の死亡時効果をチェックして発動
	
	Args:
		defeated: 撃破されたクリーチャー（死亡した側）
		opponent: 相手クリーチャー（生き残った側）
	
	Returns:
		Dictionary: {
			"death_revenge_activated": bool,  # 道連れが発動したか
			"revenge_mhp_activated": bool     # 雪辱が発動したか
		}
	"""
	var result = {
		"death_revenge_activated": false,
		"revenge_mhp_activated": false
	}
	
	# 撃破されたクリーチャーのアイテムをチェック
	var items = defeated.creature_data.get("items", [])
	
	# on_death効果があるかチェック（早期リターン用）
	var has_on_death_effect = false
	
	# アイテムのon_death効果チェック
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		for effect in effects:
			if effect.get("trigger", "") == "on_death":
				has_on_death_effect = true
				break
		if has_on_death_effect:
			break
	
	# クリーチャースキルの遺産効果チェック
	if not has_on_death_effect:
		var ability_parsed = defeated.creature_data.get("ability_parsed", {})
		var skill_effects = ability_parsed.get("effects", [])
		for effect in skill_effects:
			if effect.get("trigger", "") == "on_death":
				has_on_death_effect = true
				break
	
	# on_death効果がない場合は早期リターン
	if not has_on_death_effect:
		return result
	
	print("【死亡時効果チェック】", defeated.creature_data.get("name", "?"))
	
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			var effect_type = effect.get("effect_type", "")
			var trigger = effect.get("trigger", "")
			
			# on_death トリガーの効果のみ処理
			if trigger != "on_death":
				continue
			
			match effect_type:
				"instant_death":  # 道連れ
					var target = effect.get("target", "")
					if target == "attacker":
						var probability = effect.get("probability", 100)
						var random_value = randf() * 100.0
						
						if random_value <= probability:
							print("【道連れ発動】", defeated.creature_data.get("name", "?"), " → ", 
								  opponent.creature_data.get("name", "?"), " (", probability, "% 判定成功)")
							
							# 相手を即死させる
							opponent.instant_death_flag = true
							opponent.base_hp = 0
						# update_current_hp() は呼ばない（current_hp が状態値になったため）
							result["death_revenge_activated"] = true
						else:
							print("【道連れ失敗】確率:", probability, "% 判定値:", int(random_value), "%")
				
				"draw_cards_on_death":  # トゥームストーン（手札補充）
					if spell_draw_ref:
						var target_hand_size = effect.get("target_hand_size", 6)
						var player_id = defeated.player_id
						print("【トゥームストーン発動】", defeated.creature_data.get("name", "?"), 
							  " → プレイヤー", player_id + 1, "が手札", target_hand_size, "枚まで補充")
						var drawn_cards = spell_draw_ref.draw_until(player_id, target_hand_size)
						if not result.has("draw_cards_activated"):
							result["draw_cards_activated"] = false
						result["draw_cards_activated"] = drawn_cards.size() > 0
					else:
						push_error("SpellDrawの参照が設定されていません")
				
				"legacy_magic":  # ゴールドグース（遺産）
					if spell_magic_ref:
						var multiplier = effect.get("multiplier", 7)
						var player_id = defeated.player_id
						
						# 死亡後はget_max_hp()がマイナスになる可能性があるため、
						# 元のカードデータからMHPを計算
						var base_hp = defeated.creature_data.get("hp", 0)
						var base_up_hp = defeated.creature_data.get("base_up_hp", 0)
						var mhp = base_hp + base_up_hp
						
						var amount = mhp * multiplier
						print("【遺産発動】", defeated.creature_data.get("name", "?"), "の", item.get("name", "?"), 
							  " → プレイヤー", player_id + 1, "が", amount, "G獲得（MHP", mhp, "×", multiplier, "）")
						spell_magic_ref.add_magic(player_id, amount)
						if not result.has("legacy_magic_activated"):
							result["legacy_magic_activated"] = false
						result["legacy_magic_activated"] = true
					else:
						push_error("SpellMagicの参照が設定されていません")
				
				"revenge_mhp_damage":  # 雪辱
					# 相手が生存している場合のみ発動
					if opponent.is_alive():
						var damage = effect.get("damage", 40)
						print("【雪辱発動】", defeated.creature_data.get("name", "?"), "の", item.get("name", "?"), " → ", opponent.creature_data.get("name", "?"))
						opponent.take_mhp_damage(damage)
						result["revenge_mhp_activated"] = true
	
	# 💰 クリーチャースキル: 遺産・道産（フェイト、コーンフォーク、クリーピングコインなど）
	_skill_legacy.apply_on_death(defeated, spell_draw_ref, spell_magic_ref)
	
	return result

## 道連れ効果のチェック（後方互換性のため残す）
func check_death_revenge(defeated: BattleParticipant, attacker: BattleParticipant) -> bool:
	"""
	撃破された側の道連れ効果をチェックして発動（後方互換性用）
	
	Args:
		defeated: 撃破されたクリーチャー
		attacker: 撃破したクリーチャー
	
	Returns:
		bool: 道連れが発動したかどうか
	"""
	var result = check_on_death_effects(defeated, attacker)
	return result["death_revenge_activated"]

## バトル後の魔力獲得効果をチェック
func check_post_battle_magic_effects(winner: BattleParticipant, loser: BattleParticipant, 
									  damage_taken_by_winner: int) -> Dictionary:
	"""
	バトル後の魔力獲得効果をチェックして発動
	
	Args:
		winner: 勝利したクリーチャー
		loser: 敗北したクリーチャー
		damage_taken_by_winner: 勝者が受けたダメージ
	
	Returns:
		Dictionary: {
			"magic_gained": int  # 獲得した魔力の合計
		}
	"""
	var result = {
		"magic_gained": 0
	}
	
	if not spell_magic_ref:
		return result
	
	var items = winner.creature_data.get("items", [])
	
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var effects = effect_parsed.get("effects", [])
		
		for effect in effects:
			var effect_type = effect.get("effect_type", "")
			var trigger = effect.get("trigger", "")
			
			# after_battleトリガーの効果のみ処理
			if trigger != "after_battle":
				continue
			
			match effect_type:
				"magic_on_enemy_survive":  # ゴールドハンマー
					# 条件: 攻撃側が勝利 & 敵が生存
					var condition = effect.get("condition", "")
					if condition == "attacker_win_enemy_alive":
						if winner.stance == "attacker" and loser.is_alive():
							var amount = effect.get("amount", 200)
							print("【ゴールドハンマー発動】", winner.creature_data.get("name", "?"), 
								  " → プレイヤー", winner.player_id + 1, "が", amount, "G獲得")
							spell_magic_ref.add_magic(winner.player_id, amount)
							result["magic_gained"] += amount
				
				"magic_from_damage":  # ゼラチンアーマー
					# 受けたダメージ × 倍率
					if damage_taken_by_winner > 0:
						var multiplier = effect.get("multiplier", 5)
						var amount = damage_taken_by_winner * multiplier
						print("【ゼラチンアーマー発動】", winner.creature_data.get("name", "?"), 
							  " → プレイヤー", winner.player_id + 1, "が", amount, "G獲得（ダメージ", 
							  damage_taken_by_winner, "×", multiplier, "）")
						spell_magic_ref.add_magic(winner.player_id, amount)
						result["magic_gained"] += amount
	
	return result
