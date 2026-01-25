extends Node
class_name BattleExecution

# バトル実行フェーズ処理
# 攻撃順決定、攻撃シーケンス、結果判定を担当

# 変身スキルをpreload（死者復活はbattle_special_effectsに移動済み）
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")

# スキルモジュール
const ReflectSkill = preload("res://scripts/battle/skills/skill_reflect.gd")
const PenetrationSkill = preload("res://scripts/battle/skills/skill_penetration.gd")

# システム参照
var card_system_ref = null
var battle_screen_manager = null

func setup_systems(card_system, screen_manager = null):
	card_system_ref = card_system
	battle_screen_manager = screen_manager

## BattleParticipantから表示用データを作成（変身時のカード更新用）
func _create_display_data(participant: BattleParticipant) -> Dictionary:
	var data = participant.creature_data.duplicate(true)
	# creature_dataに既にボーナスが含まれている場合があるので、一旦クリアしてから設定
	print("[_create_display_data] creature_data内のボーナス（設定前）:")
	print("  item_bonus_hp in creature_data:", participant.creature_data.get("item_bonus_hp", "なし"))
	print("  land_bonus_hp in creature_data:", participant.creature_data.get("land_bonus_hp", "なし"))
	
	data["base_up_hp"] = participant.base_up_hp
	data["item_bonus_hp"] = participant.item_bonus_hp
	data["resonance_bonus_hp"] = participant.resonance_bonus_hp
	data["temporary_bonus_hp"] = participant.temporary_bonus_hp
	data["spell_bonus_hp"] = participant.spell_bonus_hp
	data["land_bonus_hp"] = participant.land_bonus_hp
	data["current_hp"] = participant.current_hp
	data["current_ap"] = participant.current_ap
	print("[_create_display_data] ", participant.creature_data.get("name", "?"))
	print("  hp(from data):", data.get("hp", 0), " current_hp:", data["current_hp"])
	print("  land_bonus_hp:", data["land_bonus_hp"], " item_bonus_hp:", data["item_bonus_hp"])
	return data

## 攻撃後のHPバー更新
func _update_hp_bar_after_damage(participant: BattleParticipant) -> void:
	if not battle_screen_manager:
		return
	
	var side = "attacker" if participant.is_attacker else "defender"
	var hp_data = {
		"base_hp": participant.base_hp,
		"base_up_hp": participant.base_up_hp,
		"item_bonus_hp": participant.item_bonus_hp,
		"resonance_bonus_hp": participant.resonance_bonus_hp,
		"temporary_bonus_hp": participant.temporary_bonus_hp,
		"spell_bonus_hp": participant.spell_bonus_hp,
		"land_bonus_hp": participant.land_bonus_hp,
		"current_hp": participant.current_hp,
		"display_max": participant.base_hp + participant.base_up_hp + \
					   participant.item_bonus_hp + participant.resonance_bonus_hp + \
					   participant.temporary_bonus_hp + participant.spell_bonus_hp + \
					   participant.land_bonus_hp
	}
	await battle_screen_manager.update_hp(side, hp_data)


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

## ダメージ後の共通処理（HP閾値スキルなど）
## Returns: 両者死亡などでバトルを終了すべき場合はtrue
func process_damage_aftermath(damaged: BattleParticipant, opponent: BattleParticipant, _special_effects) -> bool:
	if not damaged.is_alive():
		return false  # 既に死亡している場合はスキップ
	
	# HP閾値での自爆＋道連れチェック（リビングボム等）
	if SkillItemCreature.check_hp_threshold_self_destruct(damaged, opponent):
		return true  # 両者死亡の可能性があるため終了
	
	return false


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
func execute_attack_sequence(attack_order: Array, tile_info: Dictionary, special_effects, skill_processor) -> Dictionary:
	# spell_magic_refを取得
	var spell_magic_ref = special_effects.spell_magic_ref
	
	# 参加者の参照を保持（本来の侵略側/防御側）
	var original_attacker = attack_order[0]
	var original_defender = attack_order[1]
	
	# ループ用（攻撃順で入れ替わる）
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
	# 手札復活はcheck_on_death_effects内で即座に処理される
	
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
			var curse = attacker_p.creature_data.get("curse", {})
			var curse_name = curse.get("name", "戦闘行動不可")
			print("【戦闘行動不可】", attacker_p.creature_data.get("name", "?"), " は攻撃できない")
			# 🎬 呪い発動表示
			if battle_screen_manager:
				var attacker_side = "attacker" if attacker_p.is_attacker else "defender"
				await battle_screen_manager.show_skill_activation(attacker_side, "呪い[%s]" % curse_name, {})
			continue
		
		# 攻撃回数分ループ
		for attack_num in range(attacker_p.attack_count):
			# 既に倒されていたら攻撃しない
			if not defender_p.is_alive():
				break
			
			# 攻撃実行
			var attacker_name = attacker_p.creature_data.get("name", "?")
			var defender_name = defender_p.creature_data.get("name", "?")
			
			# 🎬 攻撃アニメーション
			if battle_screen_manager:
				var attacker_side = "attacker" if attacker_p.is_attacker else "defender"
				await battle_screen_manager.show_attack(attacker_side, attacker_p.current_ap)
			
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
					
					# 🎬 呪いによる無効化の場合、呪い名を表示
					if not attacker_p.is_using_scroll:  # 通常攻撃の無効化
						var curse_nullify_info = _get_curse_nullify_info(defender_p)
						if curse_nullify_info and battle_screen_manager:
							var defender_side = "attacker" if defender_p.is_attacker else "defender"
							await battle_screen_manager.show_skill_activation(defender_side, "呪い[%s]" % curse_nullify_info["name"], {})
					
					# magic_barrier呪いによる100EP移動チェック
					_apply_ep_transfer_on_nullify(attacker_p, defender_p)
					
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
					
					# 🎬 ダメージポップアップ（軽減後）
					if battle_screen_manager and actual_damage_reduced > 0:
						var defender_side = "defender" if defender_p.is_attacker == false else "attacker"
						battle_screen_manager.show_damage(defender_side, actual_damage_reduced)
						# 🎬 HPバー更新
						await _update_hp_bar_after_damage(defender_p)
				
					# 💰 ダメージ時のEP獲得・奪取スキル
					var actual_damage_dealt_reduced = (
					damage_breakdown_reduced.get("resonance_bonus_consumed", 0) +
					damage_breakdown_reduced.get("land_bonus_consumed", 0) +
					damage_breakdown_reduced.get("temporary_bonus_consumed", 0) +
					damage_breakdown_reduced.get("item_bonus_consumed", 0) +
					damage_breakdown_reduced.get("spell_bonus_consumed", 0) +
					damage_breakdown_reduced.get("base_hp_consumed", 0)
				)
					if spell_magic_ref:
						# EP奪取（攻撃側）: 与えたダメージベース
						apply_damage_based_magic_steal(attacker_p, defender_p, actual_damage_dealt_reduced, spell_magic_ref)
						# EP獲得（防御側）: 受けたダメージベース
						SkillMagicGain.apply_damage_magic_gain(defender_p, actual_damage_dealt_reduced, spell_magic_ref)

					print("  ダメージ処理:")
					if damage_breakdown_reduced["resonance_bonus_consumed"] > 0:
						print("    - 感応ボーナス: ", damage_breakdown_reduced["resonance_bonus_consumed"], " 消費")
					if damage_breakdown_reduced["land_bonus_consumed"] > 0:
						print("    - 土地ボーナス: ", damage_breakdown_reduced["land_bonus_consumed"], " 消費")
					if damage_breakdown_reduced["base_hp_consumed"] > 0:
						print("    - 現在HP: ", damage_breakdown_reduced["base_hp_consumed"], " 消費")
					print("  → 残HP: ", defender_p.current_hp, " (現在HP:", defender_p.current_hp, ")")
					
					# ダメージ後の共通処理（HP閾値スキルなど）
					if process_damage_aftermath(defender_p, attacker_p, special_effects):
						break
					
					# 反射ダメージを攻撃側に適用
					if reflect_result_reduced["has_reflect"] and reflect_result_reduced["reflect_damage"] > 0:
						print("
  【反射ダメージ適用】")
						attacker_p.take_damage(reflect_result_reduced["reflect_damage"])
						print("    - 攻撃側が受けた反射ダメージ: ", reflect_result_reduced["reflect_damage"])
						print("    → 攻撃側残HP: ", attacker_p.current_hp, " (現在HP:", attacker_p.current_hp, ")")
						
						# 🎬 反射ダメージ後のHPバー更新
						await _update_hp_bar_after_damage(attacker_p)
						
						# 反射ダメージ後の共通処理
						if process_damage_aftermath(attacker_p, defender_p, special_effects):
							break
					
					# 軽減の場合は即死判定を行う
					if defender_p.is_alive():
						var instant_death_activated = special_effects.check_instant_death(attacker_p, defender_p)
						if instant_death_activated and battle_screen_manager:
							var skill_name = SkillDisplayConfig.get_skill_name("instant_death")
							await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
							# 🎬 即死でHPが0になった側のHPバーを更新
							await _update_hp_bar_after_damage(defender_p)
					
					# 防御側撃破チェック（即死後）
					if not defender_p.is_alive():
						print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
						
						# 💀 死亡時効果チェック（道連れ、雪辱、死者復活など）
						var death_effects = special_effects.check_on_death_effects(defender_p, attacker_p, CardLoader)
						await _show_death_effects(death_effects, defender_p)
						if death_effects["death_revenge_activated"]:
							print("  → ", attacker_p.creature_data.get("name", "?"), " 道連れで撃破！")
							# 🎬 道連れでHPが0になった側のHPバーを更新
							await _update_hp_bar_after_damage(attacker_p)
						
						# 🔄 死者復活チェック（タイル復活）
						if death_effects["revived"]:
							print("  【死者復活成功】", death_effects["new_creature_name"], "として復活！")
							# 復活情報を記録
							var revived_side = "attacker" if defender_p.is_attacker else "defender"
							if defender_p.is_attacker:
								battle_result["attacker_revived"] = true
							else:
								battle_result["defender_revived"] = true
							# 🎬 カード表示を更新（復活後のクリーチャーを表示）
							if battle_screen_manager:
								var display_data = _create_display_data(defender_p)
								await battle_screen_manager.update_creature(revived_side, display_data)
							# 復活したが攻撃はせずに戦闘終了
							print("  → 復活したため、攻撃せずに戦闘終了")
							battle_ended = true
							break
						# 🔄 手札復活チェック（check_on_death_effects内で処理済み）
						elif death_effects["revive_to_hand"]:
							break
						else:
							# 復活しなかったので撃破確定
							break
					
					# 攻撃側が反射で倒された場合（即死後）
					if not attacker_p.is_alive():
						print("  → ", attacker_p.creature_data.get("name", "?"), " 反射ダメージで撃破！")
						
						# 💀 死亡時効果チェック（道連れ、雪辱、死者復活など）
						var death_effects_attacker = special_effects.check_on_death_effects(attacker_p, defender_p, CardLoader)
						await _show_death_effects(death_effects_attacker, attacker_p)
						if death_effects_attacker["death_revenge_activated"]:
							print("  → ", defender_p.creature_data.get("name", "?"), " 道連れで撃破！")
							# 🎬 道連れでHPが0になった側のHPバーを更新
							await _update_hp_bar_after_damage(defender_p)
						
						# 🔄 死者復活チェック（タイル復活）
						if death_effects_attacker["revived"]:
							print("  【死者復活成功】", death_effects_attacker["new_creature_name"], "として復活！")
							# 復活情報を記録
							var revived_side = "attacker" if attacker_p.is_attacker else "defender"
							if attacker_p.is_attacker:
								battle_result["attacker_revived"] = true
							else:
								battle_result["defender_revived"] = true
							# 🎬 カード表示を更新（復活後のクリーチャーを表示）
							if battle_screen_manager:
								var display_data = _create_display_data(attacker_p)
								await battle_screen_manager.update_creature(revived_side, display_data)
							# 復活したが攻撃はせずに戦闘終了
							print("  → 復活したため、攻撃せずに戦闘終了")
							battle_ended = true
							break
						# 🔄 手札復活チェック（check_on_death_effects内で処理済み）
						elif death_effects_attacker["revive_to_hand"]:
							break
						else:
							# 復活しなかったので撃破確定
							break
					
					# 🔒 攻撃成功時効果（軽減パス用）
					# ブラックナイト等の無効化チェック
					if defender_p.is_alive() and attacker_p.current_ap > 0:
						if not SkillSpecialCreature.is_trigger_nullified(defender_p.creature_data, "on_attack_success"):
							var curse_result = _check_and_apply_on_attack_success_curse(attacker_p, defender_p)
							# 呪い付与スキル表示
							if curse_result.get("applied", false) and battle_screen_manager:
								var skill_name = SkillDisplayConfig.get_skill_name("apply_curse")
								var curse_name = curse_result.get("curse_name", "")
								if curse_name:
									skill_name = "%s[%s]" % [skill_name, curse_name]
								var attacker_side = "attacker" if attacker_p.is_attacker else "defender"
								await battle_screen_manager.show_skill_activation(attacker_side, skill_name, {})
							# ダウン付与（ショッカー等）
							var battle_tile_index = tile_info.get("index", -1)
							if battle_tile_index >= 0 and special_effects.board_system_ref:
								var tile = special_effects.board_system_ref.tile_nodes.get(battle_tile_index)
								SkillLandEffects.check_and_apply_on_attack_success_down(attacker_p.creature_data, tile)
							# 攻撃成功時効果（APドレイン、EP獲得等）
							var success_effects = _apply_on_attack_success_effects(attacker_p, defender_p, spell_magic_ref)
							if success_effects.get("ap_drained", false) and battle_screen_manager:
								var skill_owner_side = "attacker" if attacker_p.is_attacker else "defender"
								var ap_drain_name = SkillDisplayConfig.get_skill_name("ap_drain")
								await battle_screen_manager.show_skill_activation(skill_owner_side, ap_drain_name, {})
								var drained_side = "attacker" if defender_p.is_attacker else "defender"
								await battle_screen_manager.update_ap(drained_side, defender_p.current_ap)
					
					continue  # 次の攻撃へ（通常のダメージ処理はスキップ）
			
			# 反射スキルチェック
			var attack_type = "scroll" if attacker_p.is_using_scroll else "normal"
			var reflect_result = ReflectSkill.check_damage(attacker_p, defender_p, attacker_p.current_ap, attack_type)
			
			# 反射がある場合、ダメージを調整
			var actual_damage = reflect_result["self_damage"] if reflect_result["has_reflect"] else attacker_p.current_ap
			
			# ダメージ適用
			var damage_breakdown = defender_p.take_damage(actual_damage)
			
			# 🎬 ダメージポップアップ
			if battle_screen_manager and actual_damage > 0:
				var defender_side = "defender" if defender_p.is_attacker == false else "attacker"
				battle_screen_manager.show_damage(defender_side, actual_damage)
				# 🎬 HPバー更新
				await _update_hp_bar_after_damage(defender_p)
			
			# 💰 ダメージ時のEP獲得・奪取スキル
			var actual_damage_dealt = (
			damage_breakdown.get("resonance_bonus_consumed", 0) +
			damage_breakdown.get("land_bonus_consumed", 0) +
			damage_breakdown.get("temporary_bonus_consumed", 0) +
			damage_breakdown.get("item_bonus_consumed", 0) +
			damage_breakdown.get("spell_bonus_consumed", 0) +
			damage_breakdown.get("current_hp_consumed", 0)
		)
			if spell_magic_ref:
				# EP奪取（攻撃側）: 与えたダメージベース
				apply_damage_based_magic_steal(attacker_p, defender_p, actual_damage_dealt, spell_magic_ref)
				# EP獲得（防御側）: 受けたダメージベース
				SkillMagicGain.apply_damage_magic_gain(defender_p, actual_damage_dealt, spell_magic_ref)

			
			print("  ダメージ処理:")
			if damage_breakdown["resonance_bonus_consumed"] > 0:
				print("    - 感応ボーナス: ", damage_breakdown["resonance_bonus_consumed"], " 消費")
			if damage_breakdown["land_bonus_consumed"] > 0:
				print("    - 土地ボーナス: ", damage_breakdown["land_bonus_consumed"], " 消費")
			if damage_breakdown["current_hp_consumed"] > 0:
				print("    - 現在HP: ", damage_breakdown["current_hp_consumed"], " 消費")
			print("  → 残HP: ", defender_p.current_hp, " (現在HP:", defender_p.current_hp, ")")
			
			# ダメージ後の共通処理（HP閾値スキルなど）
			if process_damage_aftermath(defender_p, attacker_p, special_effects):
				break
			
			# 反射ダメージを攻撃側に適用
			if reflect_result["has_reflect"] and reflect_result["reflect_damage"] > 0:
				# 🎬 反射スキル表示
				if battle_screen_manager:
					var skill_name = SkillDisplayConfig.get_skill_name("reflect_damage")
					await battle_screen_manager.show_skill_activation("defender", skill_name, {})
				print("
  【反射ダメージ適用】")
				attacker_p.take_damage(reflect_result["reflect_damage"])
				print("    - 攻撃側が受けた反射ダメージ: ", reflect_result["reflect_damage"])
				print("    → 攻撃側残HP: ", attacker_p.current_hp, " (現在HP:", attacker_p.current_hp, ")")
				
				# 🎬 反射ダメージ後のHPバー更新
				await _update_hp_bar_after_damage(attacker_p)
				
				# 反射ダメージ後の共通処理
				if process_damage_aftermath(attacker_p, defender_p, special_effects):
					break
			
			# 即死判定（攻撃が通った後）
			if defender_p.is_alive():
				var instant_death_activated = special_effects.check_instant_death(attacker_p, defender_p)
				if instant_death_activated and battle_screen_manager:
					var skill_name = SkillDisplayConfig.get_skill_name("instant_death")
					await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
					# 🎬 即死でHPが0になった側のHPバーを更新
					await _update_hp_bar_after_damage(defender_p)
			
			# 🔄 攻撃成功時の変身処理（コカトリス用）
			# 条件: 相手が生存 かつ 実際にダメージを与えた（AP > 0）
			# ブラックナイト等の無効化チェック
			if defender_p.is_alive() and card_system_ref and attacker_p.current_ap > 0:
				if not SkillSpecialCreature.is_trigger_nullified(defender_p.creature_data, "on_attack_success"):
					var battle_tile_index = tile_info.get("index", -1)
					var board_system = special_effects.board_system_ref if special_effects else null
					var transform_result = TransformSkill.process_transform_effects(
						attacker_p,
						defender_p,
						CardLoader,
						"on_attack_success",
						board_system,
						battle_tile_index
					)
					
					# 変身結果を戦闘結果にマージ
					if transform_result.get("attacker_transformed", false):
						battle_result["attacker_transformed"] = true
						# 強制変化（revert_after_battle: false）の場合、以前のoriginal_dataをクリア
						battle_result["attacker_original"] = transform_result.get("attacker_original", {})
						# 🎬 変身スキル表示（攻撃側が変身）
						if battle_screen_manager:
							var skill_name = SkillDisplayConfig.get_skill_name("transform")
							await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
							# 🎬 カード表示を更新
							var display_data = _create_display_data(attacker_p)
							await battle_screen_manager.update_creature("attacker", display_data)
					if transform_result.get("defender_transformed", false):
						battle_result["defender_transformed"] = true
						# 強制変化（revert_after_battle: false）の場合、以前のoriginal_dataをクリア
						# 空のoriginal_dataが返された場合も、以前の値を上書きする
						battle_result["defender_original"] = transform_result.get("defender_original", {})
						print("  【変身発動】防御側が変身しました")
						# 🎬 変身スキル表示（防御側が変身させられた）
						if battle_screen_manager:
							var skill_name = SkillDisplayConfig.get_skill_name("transform")
							await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
							# 🎬 カード表示を更新
							var display_data = _create_display_data(defender_p)
							await battle_screen_manager.update_creature("defender", display_data)
					
					# 🔄 ツインスパイク：侵略側が変身した場合、スキル再計算
					if transform_result.get("needs_attacker_skill_recalc", false):
						print("  【ツインスパイク】侵略側のスキルを再計算")
						# defender_pは現在の防御者（変身した側）
						# contextを作成（強打等の条件チェックに必要な情報を含む）
						var recalc_context = {
							"player_id": defender_p.player_id,
							"player_lands": special_effects.board_system_ref.get_player_lands_by_element(defender_p.player_id) if special_effects and special_effects.board_system_ref else {},
							"battle_tile_index": tile_info.get("index", -1),
							"battle_tile_element": tile_info.get("element", "neutral"),
							"battle_land_element": tile_info.get("element", "neutral"),
							"creature_element": defender_p.creature_data.get("element", ""),
							"creature_mhp": defender_p.get_max_hp(),
							"enemy_element": attacker_p.creature_data.get("element", ""),
							"opponent": attacker_p,
							"is_attacker": defender_p.is_attacker
						}
						await skill_processor.recalculate_skills_after_transform(defender_p, recalc_context)
						# 🎬 カード表示を再更新（スキル適用後）
						if battle_screen_manager:
							var display_data = _create_display_data(defender_p)
							await battle_screen_manager.update_creature("defender", display_data)
			
			# 🔒 攻撃成功時効果（呪い付与、ダウン付与、APドレイン等）
			# 条件: 相手が生存 かつ 実際にダメージを与えた（AP > 0）
			# ブラックナイト等の無効化チェック
			if defender_p.is_alive() and attacker_p.current_ap > 0:
				if SkillSpecialCreature.is_trigger_nullified(defender_p.creature_data, "on_attack_success"):
					print("【能力無効化】", defender_p.creature_data.get("name", "?"), " により攻撃成功時能力が無効化")
				else:
					# 呪い付与（ナイキー、バインドウィップ等）
					var curse_result = _check_and_apply_on_attack_success_curse(attacker_p, defender_p)
					# 呪い付与スキル表示
					if curse_result.get("applied", false) and battle_screen_manager:
						var skill_name = SkillDisplayConfig.get_skill_name("apply_curse")
						var curse_name = curse_result.get("curse_name", "")
						if curse_name:
							skill_name = "%s[%s]" % [skill_name, curse_name]
						var attacker_side = "attacker" if attacker_p.is_attacker else "defender"
						await battle_screen_manager.show_skill_activation(attacker_side, skill_name, {})
					# ダウン付与（ショッカー等）
					var battle_tile_index = tile_info.get("index", -1)
					if battle_tile_index >= 0 and special_effects.board_system_ref:
						var tile = special_effects.board_system_ref.tile_nodes.get(battle_tile_index)
						SkillLandEffects.check_and_apply_on_attack_success_down(attacker_p.creature_data, tile)
					# 攻撃成功時効果（APドレイン、EP獲得等）
					var success_effects = _apply_on_attack_success_effects(attacker_p, defender_p, spell_magic_ref)
					if success_effects.get("ap_drained", false) and battle_screen_manager:
						# スキル所持者側にスキル名表示
						var skill_owner_side = "attacker" if attacker_p.is_attacker else "defender"
						var ap_drain_name = SkillDisplayConfig.get_skill_name("ap_drain")
						await battle_screen_manager.show_skill_activation(skill_owner_side, ap_drain_name, {})
						# defender_pのAPが0になったので、defender_p側のAPバーを更新
						var drained_side = "attacker" if defender_p.is_attacker else "defender"
						await battle_screen_manager.update_ap(drained_side, defender_p.current_ap)
			
			# 防御側撃破チェック
			if not defender_p.is_alive():
				print("  → ", defender_p.creature_data.get("name", "?"), " 撃破！")
				
				# 💀 死亡時効果チェック（道連れ、雪辱、死者復活など）
				var death_effects = special_effects.check_on_death_effects(defender_p, attacker_p, CardLoader)
				await _show_death_effects(death_effects, defender_p)
				if death_effects["death_revenge_activated"]:
					print("  → ", attacker_p.creature_data.get("name", "?"), " 道連れで撃破！")
					# 🎬 道連れでHPが0になった側のHPバーを更新
					await _update_hp_bar_after_damage(attacker_p)
				
				# 🔄 死者復活チェック（タイル復活）
				if death_effects["revived"]:
					print("  【死者復活成功】", death_effects["new_creature_name"], "として復活！")
					# 復活情報を記録
					var revived_side = "attacker" if defender_p.is_attacker else "defender"
					if defender_p.is_attacker:
						battle_result["attacker_revived"] = true
					else:
						battle_result["defender_revived"] = true
					# 🎬 カード表示を更新（復活後のクリーチャーを表示）
					if battle_screen_manager:
						var display_data = _create_display_data(defender_p)
						await battle_screen_manager.update_creature(revived_side, display_data)
					# 復活したが攻撃はせずに戦闘終了
					print("  → 復活したため、攻撃せずに戦闘終了")
					battle_ended = true
					break
				# 🔄 手札復活チェック（check_on_death_effects内で処理済み）
				elif death_effects["revive_to_hand"]:
					break
				else:
					# 復活しなかったので撃破確定
					break
			
			# 攻撃側が反射で倒された場合
			if not attacker_p.is_alive():
				print("  → ", attacker_p.creature_data.get("name", "?"), " 反射ダメージで撃破！")
				
				# 💀 死亡時効果チェック（道連れ、雪辱、死者復活など）
				var death_effects_attacker = special_effects.check_on_death_effects(attacker_p, defender_p, CardLoader)
				await _show_death_effects(death_effects_attacker, attacker_p)
				if death_effects_attacker["death_revenge_activated"]:
					print("  → ", defender_p.creature_data.get("name", "?"), " 道連れで撃破！")
					# 🎬 道連れでHPが0になった側のHPバーを更新
					await _update_hp_bar_after_damage(defender_p)
				
				# 🔄 死者復活チェック（タイル復活）
				if death_effects_attacker["revived"]:
					print("  【死者復活成功】", death_effects_attacker["new_creature_name"], "として復活！")
					# 復活情報を記録
					var revived_side = "attacker" if attacker_p.is_attacker else "defender"
					if attacker_p.is_attacker:
						battle_result["attacker_revived"] = true
					else:
						battle_result["defender_revived"] = true
					# 🎬 カード表示を更新（復活後のクリーチャーを表示）
					if battle_screen_manager:
						var display_data = _create_display_data(attacker_p)
						await battle_screen_manager.update_creature(revived_side, display_data)
					# 復活したが攻撃はせずに戦闘終了
					print("  → 復活したため、攻撃せずに戦闘終了")
					battle_ended = true
					break
				# 🔄 手札復活チェック（check_on_death_effects内で処理済み）
				elif death_effects_attacker["revive_to_hand"]:
					break
				else:
					# 復活しなかったので撃破確定
					break
	
	# 戦闘結果情報を返す
	# 💰 アイテム不使用時のEP奪取スキル（アマゾン）
	# 勝敗に関係なく、生存している参加者それぞれをチェック
	if spell_magic_ref:
		var turn_count = 1  # TODO: 実際の周回数を取得する必要がある
		
		# 攻撃側のスキルチェック（生存している場合）
		if attacker_p.is_alive():
			var attacker_has_item = attacker_p.creature_data.get("items", []).size() > 0
			SkillMagicSteal.apply_no_item_steal(attacker_p, attacker_has_item, turn_count, spell_magic_ref, defender_p)
		
		# 防御側のスキルチェック（生存している場合）
		if defender_p.is_alive():
			var defender_has_item = defender_p.creature_data.get("items", []).size() > 0
			SkillMagicSteal.apply_no_item_steal(defender_p, defender_has_item, turn_count, spell_magic_ref, attacker_p)
	
	# 🃏 生き残り時効果（カード獲得スキル）
	if original_attacker.is_alive():
		special_effects.check_on_survive_effects(original_attacker)
	if original_defender.is_alive():
		special_effects.check_on_survive_effects(original_defender)
	
	# 🔄 戦闘終了時効果（ルナティックヘア、スキュラ、マイコロン等）
	var battle_end_context = _build_battle_end_context(special_effects, tile_info)
	battle_end_context["was_attacked"] = true  # 防御側は攻撃を受けた
	var battle_end_result = SkillBattleEndEffects.process_all(original_attacker, original_defender, battle_end_context)
	
	# 戦闘終了時スキルの表示
	var activated_skills = battle_end_result.get("activated_skills", [])
	for skill_info in activated_skills:
		var actor = skill_info.get("actor")
		var skill_type = skill_info.get("skill_type", "")
		if actor and skill_type and battle_screen_manager:
			var side = "attacker" if actor.is_attacker else "defender"
			var skill_name = SkillDisplayConfig.get_skill_name(skill_type)
			# 呪い付与の場合は呪い名も表示
			if skill_type == "apply_curse":
				var curse_name = skill_info.get("curse_name", "")
				if curse_name:
					skill_name = "%s[%s]" % [skill_name, curse_name]
			# 衰弱ダメージの場合は特別表示
			elif skill_type == "plague_damage":
				var damage = skill_info.get("damage", 0)
				skill_name = "衰弱[-%d]" % damage
				await battle_screen_manager.show_skill_activation(side, skill_name, {})
				# HPバーを更新
				await _update_hp_bar_after_damage(actor)
				continue
			await battle_screen_manager.show_skill_activation(side, skill_name, {})
	
	# 戦闘終了時効果による死亡を反映
	if battle_end_result.get("attacker_died", false):
		battle_result["attacker_died_by_battle_end"] = true
	if battle_end_result.get("defender_died", false):
		battle_result["defender_died_by_battle_end"] = true
	
	# マイコロン等のspawn処理
	var spawn_info = battle_end_result.get("spawn_info", {})
	if spawn_info.get("spawned", false):
		var spawn_tile = spawn_info.get("spawn_tile_index", -1)
		var spawn_creature = spawn_info.get("creature_data", {})
		if spawn_tile >= 0 and not spawn_creature.is_empty():
			SkillCreatureSpawn.spawn_mycolon_copy(
				special_effects.board_system_ref,
				spawn_tile,
				spawn_creature,
				original_defender.player_id
			)
			battle_result["creature_spawned"] = true
			battle_result["spawn_tile_index"] = spawn_tile
	
	# 💀 戦闘後破壊呪いチェック（生き残った側に呪いがあれば破壊）
	await _check_destroy_after_battle(attacker_p, defender_p)
	
	# 🔮 戦闘後破壊付与スキル（オトヒメ等：両者生存時に敵へ呪い付与）
	_check_apply_destroy_after_battle_skill(attacker_p, defender_p)
	
	return battle_result

## 💰 EP奪取スキルを適用（ダメージベース）
func apply_damage_based_magic_steal(attacker: BattleParticipant, defender: BattleParticipant, damage: int, spell_magic) -> void:
	"""
	与えたダメージに応じてEPを奪う
	- バンディット: 敵に与えたダメージ×2EP
	"""
	if not spell_magic:
		return
	
	if damage <= 0:
		return
	
	SkillMagicSteal.apply_damage_based_steal(attacker, defender, damage, spell_magic)

## 🔒 攻撃成功時の呪い付与チェック（ナイキー、バインドウィップ用）
## 攻撃成功時の呪い付与
## @return Dictionary { "applied": bool, "curse_name": String }
func _check_and_apply_on_attack_success_curse(attacker: BattleParticipant, defender: BattleParticipant) -> Dictionary:
	return SpellCurseBattle.check_and_apply_on_attack_success(attacker.creature_data, defender.creature_data)


## 🔮 呪いによる通常攻撃無効化の情報を取得
## @return Dictionary { "name": String, "curse_type": String } または null
func _get_curse_nullify_info(defender: BattleParticipant) -> Variant:
	for effect in defender.temporary_effects:
		if effect.get("type") == "nullify_normal_attack" and effect.get("source") == "curse":
			return {
				"name": effect.get("source_name", ""),
				"curse_type": effect.get("curse_type", "")
			}
	return null


## 💰 攻撃無効化時のEP移動（magic_barrier呪い用）
func _apply_ep_transfer_on_nullify(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	# defender（無効化した側）のtemporary_effectsをチェック
	for effect in defender.temporary_effects:
		if effect.get("type") == "ep_transfer_on_nullify":
			var ep_amount = effect.get("value", 100)
			
			# プレイヤーIDを取得
			var attacker_player_id = attacker.player_id
			var defender_player_id = defender.player_id
			
			# 防御側から攻撃側へEP移動（steal_magicを使用）
			var spell_magic = defender.spell_magic_ref
			if spell_magic:
				spell_magic.steal_magic(defender_player_id, attacker_player_id, ep_amount)
				print("【マジックバリア】攻撃無効化！ ", ep_amount, "EP を攻撃側へ移動")
			return


## 💀 戦闘後破壊呪いチェック（生き残っていて呪いがあれば破壊フラグを立てる）
func _check_destroy_after_battle(attacker: BattleParticipant, defender: BattleParticipant) -> void:
	# 攻撃側チェック
	if attacker.is_alive() and SpellCurseBattle.has_destroy_after_battle(attacker.creature_data):
		print("【戦闘後破壊】", attacker.creature_data.get("name", "?"), " は呪いにより破壊される")
		# スキル表示
		if battle_screen_manager:
			var skill_name = SkillDisplayConfig.get_skill_name("self_destruct")
			await battle_screen_manager.show_skill_activation("attacker", skill_name, {})
		attacker.current_hp = 0
		# 呪いを消費
		attacker.creature_data.erase("curse")
	
	# 防御側チェック
	if defender.is_alive() and SpellCurseBattle.has_destroy_after_battle(defender.creature_data):
		print("【戦闘後破壊】", defender.creature_data.get("name", "?"), " は呪いにより破壊される")
		# スキル表示
		if battle_screen_manager:
			var skill_name = SkillDisplayConfig.get_skill_name("self_destruct")
			await battle_screen_manager.show_skill_activation("defender", skill_name, {})
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


## 🔄 戦闘終了時効果用のコンテキストを構築
func _build_battle_end_context(special_effects, tile_info: Dictionary) -> Dictionary:
	var context = {
		"tile_info": tile_info,
		"board_system": null,
		"game_stats": {}
	}
	
	# board_systemを取得
	if special_effects and special_effects.board_system_ref:
		context["board_system"] = special_effects.board_system_ref
		
		# game_flow_managerからgame_statsを取得
		var gfm = special_effects.board_system_ref.game_flow_manager
		if gfm and gfm.game_stats:
			context["game_stats"] = gfm.game_stats
	
	return context


## 💀 死亡時効果の表示
func _show_death_effects(death_effects: Dictionary, defeated: BattleParticipant) -> void:
	if not battle_screen_manager:
		return
	
	var side = "attacker" if defeated.is_attacker else "defender"
	
	# 道連れ
	if death_effects.get("death_revenge_activated", false):
		var skill_name = SkillDisplayConfig.get_skill_name("death_revenge")
		await battle_screen_manager.show_skill_activation(side, skill_name, {})
	
	# 雪辱
	if death_effects.get("revenge_mhp_activated", false):
		var skill_name = SkillDisplayConfig.get_skill_name("revenge_mhp_damage")
		await battle_screen_manager.show_skill_activation(side, skill_name, {})
	
	# 死者復活（タイル復活）
	if death_effects.get("revived", false):
		var skill_name = SkillDisplayConfig.get_skill_name("revive")
		await battle_screen_manager.show_skill_activation(side, skill_name, {})
	
	# 手札復活
	if death_effects.get("revive_to_hand", false):
		var skill_name = SkillDisplayConfig.get_skill_name("revive_to_hand")
		await battle_screen_manager.show_skill_activation(side, skill_name, {})


## 攻撃成功時効果を適用（APドレイン、EP獲得等）
func _apply_on_attack_success_effects(attacker: BattleParticipant, defender: BattleParticipant, spell_magic_ref = null) -> Dictionary:
	var result = {"ap_drained": false, "magic_gained": 0}
	
	# クリーチャーeffectsを取得
	var ability_parsed = attacker.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", []).duplicate()
	
	# アイテムeffectsを追加
	var items = attacker.creature_data.get("items", [])
	for item in items:
		var item_effects = item.get("effect_parsed", {}).get("effects", [])
		for item_effect in item_effects:
			var effect_copy = item_effect.duplicate()
			effect_copy["_item_name"] = item.get("name", "")
			effects.append(effect_copy)
	
	for effect in effects:
		var trigger = effect.get("trigger", "")
		if trigger != "on_attack_success":
			continue
		
		var effect_type = effect.get("effect_type", "")
		var item_name = effect.get("_item_name", "")
		
		match effect_type:
			"ap_drain":
				var defender_name = defender.creature_data.get("name", "?")
				var original_ap = defender.current_ap
				
				# 戦闘中のAPを0に
				defender.current_ap = 0
				
				# 永続的にAPを0にする
				defender.creature_data["ap"] = 0
				defender.creature_data["base_up_ap"] = 0
				defender.base_up_ap = 0
				
				var source_name = item_name if item_name else attacker.creature_data.get("name", "?")
				print("  [APドレイン] %s が %s のAPを永続的に0に (元AP: %d)" % [source_name, defender_name, original_ap])
				result["ap_drained"] = true
			
			"magic_on_enemy_survive":
				# ゴールドハンマー: 敵が生き残っていたらEP獲得
				var condition = effect.get("condition", "")
				if condition == "enemy_alive" and defender.is_alive():
					var amount = effect.get("amount", 200)
					if spell_magic_ref:
						spell_magic_ref.add_magic(attacker.player_id, amount)
						var source_name = item_name if item_name else attacker.creature_data.get("name", "?")
						print("  [EP獲得] %s: 敵非破壊で%dEP獲得" % [source_name, amount])
						result["magic_gained"] = amount
	
	return result


## APドレイン効果を適用（攻撃成功時）- 後方互換用
func _apply_ap_drain_on_attack_success(attacker: BattleParticipant, defender: BattleParticipant, spell_magic = null) -> bool:
	var result = _apply_on_attack_success_effects(attacker, defender, spell_magic)
	return result.get("ap_drained", false)
