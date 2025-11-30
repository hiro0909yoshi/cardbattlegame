extends Node
class_name BattleExecution

# バトル実行フェーズ処理
# 攻撃順決定、攻撃シーケンス、結果判定を担当

# 変身・死者復活スキルをpreload
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")

# スキルモジュール
const ReflectSkill = preload("res://scripts/battle/skills/skill_reflect.gd")
const PenetrationSkill = preload("res://scripts/battle/skills/skill_penetration.gd")

# システム参照
var card_system_ref = null

func setup_systems(card_system):
	card_system_ref = card_system

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
	const BOTH_DEFEATED = 3
	
	# 両方死亡 → 相打ち（土地は無所有になる）
	if not attacker.is_alive() and not defender.is_alive():
		return BOTH_DEFEATED
	elif not defender.is_alive():
		return ATTACKER_WIN
	elif not attacker.is_alive():
		return DEFENDER_WIN
	else:
		return ATTACKER_SURVIVED

## 攻撃シーケンス実行
## 
## Returns:
##   戦闘結果情報を含むDictionary:
##   {
##     "attacker_revived": bool,
##     "defender_revived": bool,
##     "attacker_transformed": bool,
##     "defender_transformed": bool,
##     "attacker_original": Dictionary,
##     "defender_original": Dictionary
##   }
func execute_attack_sequence(attack_order: Array, tile_info: Dictionary, special_effects, _skill_processor) -> Dictionary:
	# spell_magic_refを取得
	var spell_magic_ref = special_effects.spell_magic_ref
	
	# 参加者の参照を保持
	var attacker_p = attack_order[0]
	var defender_p = attack_order[1]
	
	# 戦闘結果情報を記録
	var battle_result = {
		"attacker_revived": false,
		"defender_revived": false,
		"attacker_transformed": false,
		"defender_transformed": false,
		"attacker_original": {},
		"defender_original": {}
	}
	
	# 戦闘終了フラグ（復活時に使用）
	var battle_ended = false
	
	for i in range(attack_order.size()):
		# 戦闘終了フラグチェック（復活時に設定）
		if battle_ended:
			break
		
	
		# 現在の攻撃者と防御者を更新
		attacker_p = attack_order[i]
		defender_p = attack_order[(i + 1) % 2]
		
		# HPが0以下なら攻撃できない
		if not attacker_p.is_alive():
			continue
		
		# 戦闘行動不可呪いチェック
		if SpellCurseBattle.has_battle_disable(attacker_p.creature_data):
			print("【戦闘行動不可】", attacker_p.creature_data.get("name", "?"), " は攻撃できない")
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
			
			# 貫通スキルチェック（防御側の貫通は無効）
			PenetrationSkill.check_and_notify(attacker_p)
			
			# 無効化判定のためのコンテキスト構築
			var nullify_context = {
				"tile_level": tile_info.get("level", 1)
			}
			var nullify_result = special_effects.check_nullify(attacker_p, defender_p, nullify_context)
			
			if nullify_result["is_nullified"]:
				var reduction_rate = nullify_result["reduction_rate"]
				
				if reduction_rate == 0.0:
					# 完全無効化
					print("  【無効化】", defender_p.creature_data.get("name", "?"), " が攻撃を完全無効化")
					
					# magic_barrier呪いによるG100移動チェック
					_apply_gold_transfer_on_nullify(attacker_p, defender_p)
					
					continue  # ダメージ処理と即死判定をスキップ
				else:
					# 軽減
					var original_damage = attacker_p.current_ap
					var reduced_damage = int(original_damage * reduction_rate)
					print("  【軽減】", defender_p.creature_data.get("name", "?"), 
						  " がダメージを軽減 ", original_damage, " → ", reduced_damage)
					
					# 反射スキルチェック（軽減後のダメージで）
					var attack_type_reduced = "scroll" if attacker_p.is_using_scroll else "normal"
					var reflect_result_reduced = ReflectSkill.check_damage(attacker_p, defender_p, reduced_damage, attack_type_reduced)
					
					# 反射がある場合、ダメージをさらに調整
					var actual_damage_reduced = reflect_result_reduced["self_damage"] if reflect_result_reduced["has_reflect"] else reduced_damage
					
					# 軽減ダメージ適用
					var damage_breakdown_reduced = defender_p.take_damage(actual_damage_reduced)
					
				
					# 💰 ダメージ時の魔力獲得・奪取スキル
					var actual_damage_dealt_reduced = (
					damage_breakdown_reduced.get("resonance_bonus_consumed", 0) +
					damage_breakdown_reduced.get("land_bonus_consumed", 0) +
					damage_breakdown_reduced.get("temporary_bonus_consumed", 0) +
					damage_breakdown_reduced.get("item_bonus_consumed", 0) +
					damage_breakdown_reduced.get("spell_bonus_consumed", 0) +
					damage_breakdown_reduced.get("base_hp_consumed", 0)
				)
					if spell_magic_ref:
						# 魔力奪取（攻撃側）: 与えたダメージベース
						apply_damage_based_magic_steal(attacker_p, defender_p, actual_damage_dealt_reduced, spell_magic_ref)
						# 魔力獲得（防御側）: 受けたダメージベース
						SkillMagicGain.apply_damage_magic_gain(defender_p, actual_damage_dealt_reduced, spell_magic_ref)

					print("  ダメージ処理:")
					if damage_breakdown_reduced["resonance_bonus_consumed"] > 0:
						print("    - 感応ボーナス: ", damage_breakdown_reduced["resonance_bonus_consumed"], " 消費")
					if damage_breakdown_reduced["land_bonus_consumed"] > 0:
						print("    - 土地ボーナス: ", damage_breakdown_reduced["land_bonus_consumed"], " 消費")
					if damage_breakdown_reduced["base_hp_consumed"] > 0:
						print("    - 現在HP: ", damage_breakdown_reduced["base_hp_consumed"], " 消費")
					print("  → 残HP: ", defender_p.current_hp, " (現在HP:", defender_p.current_hp, ")")
					
					# 反射ダメージを攻撃側に適用
					if reflect_result_reduced["has_reflect"] and reflect_result_reduced["reflect_damage"] > 0:
						print("
  【反射ダメージ適用】")
						attacker_p.take_damage(reflect_result_reduced["reflect_damage"])
						print("    - 攻撃側が受けた反射ダメージ: ", reflect_result_reduced["reflect_damage"])
						print("    → 攻撃側残HP: ", attacker_p.current_hp, " (現在HP:", attacker_p.current_hp, ")")
					
					# 軽減の場合は即死判定を行う
					if defender_p.is_alive():
						special_effects.check_instant_death(attacker_p, defender_p)
					
					# 防御側撃破チェック（即死後）
					if not defender_p.is_alive():
						print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
						
						# 💀 死亡時効果チェック（道連れ、雪辱など）
						var death_effects = special_effects.check_on_death_effects(defender_p, attacker_p)
						if death_effects["death_revenge_activated"]:
							print("  → ", attacker_p.creature_data.get("name", "?"), " 道連れで撃破！")
						
						# 🔄 死者復活チェック
						if card_system_ref:
							var revive_result = TransformSkill.check_and_apply_revive(
								defender_p,
								attacker_p,
								CardLoader
							)
							
							if revive_result["revived"]:
								print("  【死者復活成功】", revive_result["new_creature_name"], "として復活！")
								# 復活情報を記録
								if defender_p.is_attacker:
									battle_result["attacker_revived"] = true
								else:
									battle_result["defender_revived"] = true
								# 復活したが攻撃はせずに戦闘終了
								print("  → 復活したため、攻撃せずに戦闘終了")
								battle_ended = true
								break
							else:
								# 復活しなかったので撃破確定
								break
						else:
							break
					
					# 攻撃側が反射で倒された場合（即死後）
					if not attacker_p.is_alive():
						print("  → ", attacker_p.creature_data.get("name", "?"), " 反射ダメージで撃破！")
						
						# 💀 死亡時効果チェック（道連れ、雪辱など）
						var death_effects_attacker = special_effects.check_on_death_effects(attacker_p, defender_p)
						if death_effects_attacker["death_revenge_activated"]:
							print("  → ", defender_p.creature_data.get("name", "?"), " 道連れで撃破！")
						
						# 🔄 死者復活チェック
						if card_system_ref:
							var revive_result = TransformSkill.check_and_apply_revive(
								attacker_p,
								defender_p,
								CardLoader
							)
							
							if revive_result["revived"]:
								print("  【死者復活成功】", revive_result["new_creature_name"], "として復活！")
								# 復活情報を記録
								if attacker_p.is_attacker:
									battle_result["attacker_revived"] = true
								else:
									battle_result["defender_revived"] = true
								# 復活したが攻撃はせずに戦闘終了
								print("  → 復活したため、攻撃せずに戦闘終了")
								battle_ended = true
								break
							else:
								# 復活しなかったので撃破確定
								break
						else:
							break
					
					# 🔒 攻撃成功時の呪い付与処理（軽減パス用）
					if defender_p.is_alive() and attacker_p.current_ap > 0:
						_check_and_apply_on_attack_success_curse(attacker_p, defender_p)
					
					continue  # 次の攻撃へ（通常のダメージ処理はスキップ）
			
			# 反射スキルチェック
			var attack_type = "scroll" if attacker_p.is_using_scroll else "normal"
			var reflect_result = ReflectSkill.check_damage(attacker_p, defender_p, attacker_p.current_ap, attack_type)
			
			# 反射がある場合、ダメージを調整
			var actual_damage = reflect_result["self_damage"] if reflect_result["has_reflect"] else attacker_p.current_ap
			
			# ダメージ適用
			var damage_breakdown = defender_p.take_damage(actual_damage)
			
			# 💰 ダメージ時の魔力獲得・奪取スキル
			var actual_damage_dealt = (
			damage_breakdown.get("resonance_bonus_consumed", 0) +
			damage_breakdown.get("land_bonus_consumed", 0) +
			damage_breakdown.get("temporary_bonus_consumed", 0) +
			damage_breakdown.get("item_bonus_consumed", 0) +
			damage_breakdown.get("spell_bonus_consumed", 0) +
			damage_breakdown.get("current_hp_consumed", 0)
		)
			if spell_magic_ref:
				# 魔力奪取（攻撃側）: 与えたダメージベース
				apply_damage_based_magic_steal(attacker_p, defender_p, actual_damage_dealt, spell_magic_ref)
				# 魔力獲得（防御側）: 受けたダメージベース
				SkillMagicGain.apply_damage_magic_gain(defender_p, actual_damage_dealt, spell_magic_ref)

			
			print("  ダメージ処理:")
			if damage_breakdown["resonance_bonus_consumed"] > 0:
				print("    - 感応ボーナス: ", damage_breakdown["resonance_bonus_consumed"], " 消費")
			if damage_breakdown["land_bonus_consumed"] > 0:
				print("    - 土地ボーナス: ", damage_breakdown["land_bonus_consumed"], " 消費")
			if damage_breakdown["current_hp_consumed"] > 0:
				print("    - 現在HP: ", damage_breakdown["current_hp_consumed"], " 消費")
			print("  → 残HP: ", defender_p.current_hp, " (現在HP:", defender_p.current_hp, ")")
			
			# 反射ダメージを攻撃側に適用
			if reflect_result["has_reflect"] and reflect_result["reflect_damage"] > 0:
				print("
  【反射ダメージ適用】")
				attacker_p.take_damage(reflect_result["reflect_damage"])
				print("    - 攻撃側が受けた反射ダメージ: ", reflect_result["reflect_damage"])
				print("    → 攻撃側残HP: ", attacker_p.current_hp, " (現在HP:", attacker_p.current_hp, ")")
			
			# 即死判定（攻撃が通った後）
			if defender_p.is_alive():
				special_effects.check_instant_death(attacker_p, defender_p)
			
			# 🔄 攻撃成功時の変身処理（コカトリス用）
			# 条件: 相手が生存 かつ 実際にダメージを与えた（AP > 0）
			if defender_p.is_alive() and card_system_ref and attacker_p.current_ap > 0:
				var transform_result = TransformSkill.process_transform_effects(
					attacker_p,
					defender_p,
					CardLoader,
					"on_attack_success"
				)
				
				# 変身結果を戦闘結果にマージ
				if transform_result.get("attacker_transformed", false):
					battle_result["attacker_transformed"] = true
					if transform_result.has("attacker_original"):
						battle_result["attacker_original"] = transform_result["attacker_original"]
				if transform_result.get("defender_transformed", false):
					battle_result["defender_transformed"] = true
					if transform_result.has("defender_original"):
						battle_result["defender_original"] = transform_result["defender_original"]
					print("  【変身発動】防御側が変身しました")
			
			# 🔒 攻撃成功時の呪い付与処理（ナイキー、バインドウィップ用）
			# 条件: 相手が生存 かつ 実際にダメージを与えた（AP > 0）
			if defender_p.is_alive() and attacker_p.current_ap > 0:
				_check_and_apply_on_attack_success_curse(attacker_p, defender_p)
			
			# 防御側撃破チェック
			if not defender_p.is_alive():
				print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
				
				# 💀 死亡時効果チェック（道連れ、雪辱など）
				var death_effects = special_effects.check_on_death_effects(defender_p, attacker_p)
				if death_effects["death_revenge_activated"]:
					print("  → ", attacker_p.creature_data.get("name", "?"), " 道連れで撃破！")
				
				# 🔄 死者復活チェック
				if card_system_ref:
					var revive_result = TransformSkill.check_and_apply_revive(
						defender_p,
						attacker_p,
						CardLoader
					)
					
					if revive_result["revived"]:
						print("  【死者復活成功】", revive_result["new_creature_name"], "として復活！")
						# 復活情報を記録
						if defender_p.is_attacker:
							battle_result["attacker_revived"] = true
						else:
							battle_result["defender_revived"] = true
						# 復活したが攻撃はせずに戦闘終了
						print("  → 復活したため、攻撃せずに戦闘終了")
						battle_ended = true
						break
					else:
						# 復活しなかったので撃破確定
						break
				else:
					break
			
			# 攻撃側が反射で倒された場合
			if not attacker_p.is_alive():
				print("  → ", attacker_p.creature_data.get("name", "?"), " 反射ダメージで撃破！")
				
				# 💀 死亡時効果チェック（道連れ、雪辱など）
				var death_effects_attacker = special_effects.check_on_death_effects(attacker_p, defender_p)
				if death_effects_attacker["death_revenge_activated"]:
					print("  → ", defender_p.creature_data.get("name", "?"), " 道連れで撃破！")
				
				# 🔄 死者復活チェック
				if card_system_ref:
					var revive_result = TransformSkill.check_and_apply_revive(
						attacker_p,
						defender_p,
						CardLoader
					)
					
					if revive_result["revived"]:
						print("  【死者復活成功】", revive_result["new_creature_name"], "として復活！")
						# 復活情報を記録
						if attacker_p.is_attacker:
							battle_result["attacker_revived"] = true
						else:
							battle_result["defender_revived"] = true
						# 復活したが攻撃はせずに戦闘終了
						print("  → 復活したため、攻撃せずに戦闘終了")
						battle_ended = true
						break
					else:
						# 復活しなかったので撃破確定
						break
				else:
					break
	
	# 戦闘結果情報を返す
	# 💰 アイテム不使用時の魔力奪取スキル（アマゾン）
	if spell_magic_ref:
		var winner = attacker_p if attacker_p.is_alive() else defender_p
		var loser = defender_p if attacker_p.is_alive() else attacker_p
		var winner_has_item = winner.creature_data.get("items", []).size() > 0
		var turn_count = 1  # TODO: 実際の周回数を取得する必要がある
		SkillMagicSteal.apply_no_item_steal(winner, winner_has_item, turn_count, spell_magic_ref, loser)
	
	# 🃏 生き残り時効果（カード獲得スキル）
	if attacker_p.is_alive():
		special_effects.check_on_survive_effects(attacker_p)
	if defender_p.is_alive():
		special_effects.check_on_survive_effects(defender_p)
	
	# 💀 戦闘後破壊呪いチェック（生き残った側に呪いがあれば破壊）
	_check_destroy_after_battle(attacker_p, defender_p)
	
	# 🔮 戦闘後破壊付与スキル（オトヒメ等：両者生存時に敵へ呪い付与）
	_check_apply_destroy_after_battle_skill(attacker_p, defender_p)
	
	return battle_result

## 💰 魔力奪取スキルを適用（ダメージベース）
func apply_damage_based_magic_steal(attacker: BattleParticipant, defender: BattleParticipant, damage: int, spell_magic) -> void:
	"""
	与えたダメージに応じて魔力を奪う
	- バンディット: 敵に与えたダメージ×G2
	"""
	if not spell_magic:
		return
	
	if damage <= 0:
		return
	
	SkillMagicSteal.apply_damage_based_steal(attacker, defender, damage, spell_magic)

## 🔒 攻撃成功時の呪い付与チェック（ナイキー、バインドウィップ用）
func _check_and_apply_on_attack_success_curse(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	SpellCurseBattle.check_and_apply_on_attack_success(attacker.creature_data, defender.creature_data)


## 💰 攻撃無効化時のG移動（magic_barrier呪い用）
func _apply_gold_transfer_on_nullify(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	# defender（無効化した側）のtemporary_effectsをチェック
	for effect in defender.temporary_effects:
		if effect.get("type") == "gold_transfer_on_nullify":
			var gold_amount = effect.get("value", 100)
			
			# プレイヤーIDを取得
			var attacker_player_id = attacker.player_id
			var defender_player_id = defender.player_id
			
			# 防御側から攻撃側へG移動（steal_magicを使用）
			var spell_magic = defender.spell_magic_ref
			if spell_magic:
				spell_magic.steal_magic(defender_player_id, attacker_player_id, gold_amount)
				print("【マジックバリア】攻撃無効化！ G", gold_amount, " を攻撃側へ移動")
			return


## 💀 戦闘後破壊呪いチェック（生き残っていて呪いがあれば破壊フラグを立てる）
func _check_destroy_after_battle(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	# 攻撃側チェック
	if attacker.is_alive() and SpellCurseBattle.has_destroy_after_battle(attacker.creature_data):
		print("【戦闘後破壊】", attacker.creature_data.get("name", "?"), " は呪いにより破壊される")
		attacker.current_hp = 0
		# 呪いを消費
		attacker.creature_data.erase("curse")
	
	# 防御側チェック
	if defender.is_alive() and SpellCurseBattle.has_destroy_after_battle(defender.creature_data):
		print("【戦闘後破壊】", defender.creature_data.get("name", "?"), " は呪いにより破壊される")
		defender.current_hp = 0
		# 呪いを消費
		defender.creature_data.erase("curse")


## 🔮 戦闘後破壊付与スキル（オトヒメ等：自分が生存 AND 敵も生存の場合に敵へ呪い付与）
func _check_apply_destroy_after_battle_skill(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	# 両者生存時のみ
	if not attacker.is_alive() or not defender.is_alive():
		return
	
	# 攻撃側がスキルを持っているかチェック
	var attacker_keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
	if "戦闘後破壊" in attacker_keywords:
		SpellCurseBattle.apply_destroy_after_battle(defender.creature_data)
		print("【戦闘後破壊付与】", attacker.creature_data.get("name", "?"), " が ", defender.creature_data.get("name", "?"), " に呪いを付与")
	if "通行料無効付与" in attacker_keywords:
		SpellCurseBattle.apply_creature_toll_disable(defender.creature_data)
		print("【通行料無効付与】", attacker.creature_data.get("name", "?"), " が ", defender.creature_data.get("name", "?"), " に呪いを付与")
	
	# 防御側がスキルを持っているかチェック
	var defender_keywords = defender.creature_data.get("ability_parsed", {}).get("keywords", [])
	if "戦闘後破壊" in defender_keywords:
		SpellCurseBattle.apply_destroy_after_battle(attacker.creature_data)
		print("【戦闘後破壊付与】", defender.creature_data.get("name", "?"), " が ", attacker.creature_data.get("name", "?"), " に呪いを付与")
	if "通行料無効付与" in defender_keywords:
		SpellCurseBattle.apply_creature_toll_disable(attacker.creature_data)
		print("【通行料無効付与】", defender.creature_data.get("name", "?"), " が ", attacker.creature_data.get("name", "?"), " に呪いを付与")
