extends Node
class_name BattleExecution

# バトル実行フェーズ処理
# 攻撃順決定、攻撃シーケンス、結果判定を担当

## 攻撃順を決定（先制・後手判定）
func determine_attack_order(attacker: BattleParticipant, defender: BattleParticipant) -> Array:
	# 優先順位: アイテム先制 > 後手 > 通常先制 > デフォルト
	
	# 1. アイテムで先制付与されている場合（最優先）
	if attacker.has_item_first_strike and not defender.has_item_first_strike:
		print("【攻撃順】侵略側（アイテム先制） → 防御側")
		return [attacker, defender]
	elif defender.has_item_first_strike and not attacker.has_item_first_strike:
		print("【攻撃順】防御側（アイテム先制） → 侵略側")
		return [defender, attacker]
	elif attacker.has_item_first_strike and defender.has_item_first_strike:
		print("【攻撃順】両者アイテム先制 → 侵略側優先")
		return [attacker, defender]
	
	# 2. 後手判定（先制より優先）
	if attacker.has_last_strike and not defender.has_last_strike:
		print("【攻撃順】防御側 → 侵略側（後手）")
		return [defender, attacker]
	elif defender.has_last_strike and not attacker.has_last_strike:
		print("【攻撃順】侵略側 → 防御側（後手）")
		return [attacker, defender]
	elif attacker.has_last_strike and defender.has_last_strike:
		print("【攻撃順】両者後手 → 侵略側優先")
		return [attacker, defender]
	
	# 3. 通常の先制判定
	if attacker.has_first_strike and not defender.has_first_strike:
		print("【攻撃順】侵略側（先制） → 防御側")
		return [attacker, defender]
	elif defender.has_first_strike and not attacker.has_first_strike:
		print("【攻撃順】防御側（先制） → 侵略側")
		return [defender, attacker]
	elif attacker.has_first_strike and defender.has_first_strike:
		print("【攻撃順】両者先制 → 侵略側優先")
		return [attacker, defender]
	
	# 4. デフォルト（侵略側先攻）
	print("【攻撃順】侵略側 → 防御側")
	return [attacker, defender]

## バトル結果を判定
func resolve_battle_result(attacker: BattleParticipant, defender: BattleParticipant) -> int:
	# BattleSystem.BattleResultのenum値を返す
	const ATTACKER_WIN = 0
	const DEFENDER_WIN = 1
	const ATTACKER_SURVIVED = 2
	
	if not defender.is_alive():
		return ATTACKER_WIN
	elif not attacker.is_alive():
		return DEFENDER_WIN
	else:
		return ATTACKER_SURVIVED

## 攻撃シーケンス実行
func execute_attack_sequence(attack_order: Array, tile_info: Dictionary, special_effects, skill_processor) -> void:
	for i in range(attack_order.size()):
		var attacker_p = attack_order[i]
		var defender_p = attack_order[(i + 1) % 2]
		
		# HPが0以下なら攻撃できない
		if not attacker_p.is_alive():
			continue
		
		# 攻撃回数分ループ
		for attack_num in range(attacker_p.attack_count):
			# 既に倒されていたら攻撃しない
			if not defender_p.is_alive():
				break
			
			# 攻撃実行
			var attacker_name = attacker_p.creature_data.get("name", "?")
			var defender_name = defender_p.creature_data.get("name", "?")
			
			# 攻撃ヘッダー
			if attacker_p.attack_count > 1:
				print("\n【第", i + 1, "攻撃 - ", attack_num + 1, "回目】", "侵略側" if attacker_p.is_attacker else "防御側", "の攻撃")
			else:
				print("\n【第", i + 1, "攻撃】", "侵略側" if attacker_p.is_attacker else "防御側", "の攻撃")
			
			print("  ", attacker_name, " AP:", attacker_p.current_ap, " → ", defender_name)
			
			# 防御側の貫通スキルは効果なし
			if not attacker_p.is_attacker:
				var defender_keywords = attacker_p.creature_data.get("ability_parsed", {}).get("keywords", [])
				if "貫通" in defender_keywords:
					print("  【貫通】防御側のため効果なし")
			
			# 無効化判定のためのコンテキスト構築
			var nullify_context = {
				"current_land_level": tile_info.get("level", 1)
			}
			var nullify_result = special_effects.check_nullify(attacker_p, defender_p, nullify_context)
			
			if nullify_result["is_nullified"]:
				var reduction_rate = nullify_result["reduction_rate"]
				
				if reduction_rate == 0.0:
					# 完全無効化
					print("  【無効化】", defender_p.creature_data.get("name", "?"), " が攻撃を完全無効化")
					continue  # ダメージ処理と即死判定をスキップ
				else:
					# 軽減
					var original_damage = attacker_p.current_ap
					var reduced_damage = int(original_damage * reduction_rate)
					print("  【軽減】", defender_p.creature_data.get("name", "?"), 
						  " がダメージを軽減 ", original_damage, " → ", reduced_damage)
					
					# 反射スキルチェック（軽減後のダメージで）
					var attack_type_reduced = "scroll" if attacker_p.is_using_scroll else "normal"
					var reflect_result_reduced = skill_processor.check_reflect_damage(attacker_p, defender_p, reduced_damage, attack_type_reduced)
					
					# 反射がある場合、ダメージをさらに調整
					var actual_damage_reduced = reflect_result_reduced["self_damage"] if reflect_result_reduced["has_reflect"] else reduced_damage
					
					# 軽減ダメージ適用
					var damage_breakdown_reduced = defender_p.take_damage(actual_damage_reduced)
					
					print("  ダメージ処理:")
					if damage_breakdown_reduced["resonance_bonus_consumed"] > 0:
						print("    - 感応ボーナス: ", damage_breakdown_reduced["resonance_bonus_consumed"], " 消費")
					if damage_breakdown_reduced["land_bonus_consumed"] > 0:
						print("    - 土地ボーナス: ", damage_breakdown_reduced["land_bonus_consumed"], " 消費")
					if damage_breakdown_reduced["base_hp_consumed"] > 0:
						print("    - 基本HP: ", damage_breakdown_reduced["base_hp_consumed"], " 消費")
					print("  → 残HP: ", defender_p.current_hp, " (基本HP:", defender_p.base_hp, ")")
					
					# 反射ダメージを攻撃側に適用
					if reflect_result_reduced["has_reflect"] and reflect_result_reduced["reflect_damage"] > 0:
						print("
  【反射ダメージ適用】")
						var reflect_damage_breakdown_reduced = attacker_p.take_damage(reflect_result_reduced["reflect_damage"])
						print("    - 攻撃側が受けた反射ダメージ: ", reflect_result_reduced["reflect_damage"])
						print("    → 攻撃側残HP: ", attacker_p.current_hp, " (基本HP:", attacker_p.base_hp, ")")
					
					# 軽減の場合は即死判定を行う
					if defender_p.is_alive():
						special_effects.check_instant_death(attacker_p, defender_p)
					
					# 倒されたらバトル終了
					if not defender_p.is_alive():
						print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
						break
					
					# 攻撃側が反射で倒された場合もバトル終了
					if not attacker_p.is_alive():
						print("  → ", attacker_p.creature_data.get("name", "?"), " 反射ダメージで撃破！")
						break
					
					continue  # 次の攻撃へ（通常のダメージ処理はスキップ）
			
			# 反射スキルチェック
			var attack_type = "scroll" if attacker_p.is_using_scroll else "normal"
			var reflect_result = skill_processor.check_reflect_damage(attacker_p, defender_p, attacker_p.current_ap, attack_type)
			
			# 反射がある場合、ダメージを調整
			var actual_damage = reflect_result["self_damage"] if reflect_result["has_reflect"] else attacker_p.current_ap
			
			# ダメージ適用
			var damage_breakdown = defender_p.take_damage(actual_damage)
			
			print("  ダメージ処理:")
			if damage_breakdown["resonance_bonus_consumed"] > 0:
				print("    - 感応ボーナス: ", damage_breakdown["resonance_bonus_consumed"], " 消費")
			if damage_breakdown["land_bonus_consumed"] > 0:
				print("    - 土地ボーナス: ", damage_breakdown["land_bonus_consumed"], " 消費")
			if damage_breakdown["base_hp_consumed"] > 0:
				print("    - 基本HP: ", damage_breakdown["base_hp_consumed"], " 消費")
			print("  → 残HP: ", defender_p.current_hp, " (基本HP:", defender_p.base_hp, ")")
			
			# 反射ダメージを攻撃側に適用
			if reflect_result["has_reflect"] and reflect_result["reflect_damage"] > 0:
				print("
  【反射ダメージ適用】")
				var reflect_damage_breakdown = attacker_p.take_damage(reflect_result["reflect_damage"])
				print("    - 攻撃側が受けた反射ダメージ: ", reflect_result["reflect_damage"])
				print("    → 攻撃側残HP: ", attacker_p.current_hp, " (基本HP:", attacker_p.base_hp, ")")
			
			# 即死判定（攻撃が通った後）
			if defender_p.is_alive():
				special_effects.check_instant_death(attacker_p, defender_p)
			
			# 倒されたらバトル終了
			if not defender_p.is_alive():
				print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
				break
			
			# 攻撃側が反射で倒された場合もバトル終了
			if not attacker_p.is_alive():
				print("  → ", attacker_p.creature_data.get("name", "?"), " 反射ダメージで撃破！")
				break
