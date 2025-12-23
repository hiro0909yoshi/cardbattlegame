extends Node
class_name BattleSpecialEffects

# バトル特殊効果処理
# 即死、無効化、再生、死亡時能力などの特殊スキル処理を担当

# スキルモジュール
var _skill_legacy = preload("res://scripts/battle/skills/skill_legacy.gd")
const SkillDisplayConfig = preload("res://scripts/battle_screen/skill_display_config.gd")

var board_system_ref = null
var spell_draw_ref: SpellDraw = null
var spell_magic_ref: SpellMagic = null
var card_system_ref = null
var battle_screen_manager = null

func setup_systems(board_system, spell_draw = null, spell_magic = null, card_system = null, p_battle_screen_manager = null):
	board_system_ref = board_system
	spell_draw_ref = spell_draw
	spell_magic_ref = spell_magic
	card_system_ref = card_system
	battle_screen_manager = p_battle_screen_manager

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
		defender.current_hp = 0
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

## HP閾値での自爆＋道連れチェック（リビングボム等）
## ダメージを受けた後に呼び出す
func check_hp_threshold_self_destruct(damaged: BattleParticipant, opponent: BattleParticipant) -> bool:
	# SkillItemCreatureに委譲
	return SkillItemCreature.check_hp_threshold_self_destruct(damaged, opponent)


## 再生スキル処理
func apply_regeneration(participant: BattleParticipant) -> void:
	# 生き残っていない場合は発動しない
	if not participant.is_alive():
		return
	
	# 再生キーワードチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "再生" in keywords:
		# バトル終了後に current_hp を MHP まで回復
		var current_mhp = participant.get_max_hp()
		var _old_hp = participant.current_hp
		var healed = 0
		
		if participant.current_hp < current_mhp:
			healed = current_mhp - participant.current_hp
			participant.current_hp = current_mhp
		
		if healed > 0:
			print("【再生発動】", participant.creature_data.get("name", "?"), 
				  " HP回復: +", healed, " → ", participant.current_hp, "/", current_mhp)
			# スキル表示
			await _show_regeneration(participant)

## 再生スキル表示
func _show_regeneration(participant: BattleParticipant) -> void:
	if not battle_screen_manager:
		return
	
	var side = "attacker" if participant.is_attacker else "defender"
	var skill_name = SkillDisplayConfig.get_skill_name("regeneration")
	var hp_data = _create_hp_data(participant)
	
	await battle_screen_manager.show_skill_activation(side, skill_name, {
		"hp_data": hp_data,
		"ap": participant.current_ap
	})

## HP表示用データ作成
func _create_hp_data(participant: BattleParticipant) -> Dictionary:
	return {
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

## 死亡時効果のチェック（道連れ、雪辱、死者復活など）
func check_on_death_effects(defeated: BattleParticipant, opponent: BattleParticipant, card_loader = null) -> Dictionary:
	"""
	撃破された側の死亡時効果をチェックして発動
	
	Args:
		defeated: 撃破されたクリーチャー（死亡した側）
		opponent: 相手クリーチャー（生き残った側）
		card_loader: CardLoaderのインスタンス（死者復活用、省略可）
	
	Returns:
		Dictionary: {
			"death_revenge_activated": bool,  # 道連れが発動したか
			"revenge_mhp_activated": bool,    # 雪辱が発動したか
			"revived": bool,                  # 死者復活が発動したか（タイル復活）
			"new_creature_name": String,      # 復活後のクリーチャー名
			"revive_to_hand": bool,           # 手札復活が発動したか
			"revive_to_hand_data": Dictionary # 手札復活するクリーチャーデータ
		}
	"""
	var result = {
		"death_revenge_activated": false,
		"revenge_mhp_activated": false,
		"revived": false,
		"new_creature_name": "",
		"revive_to_hand": false,
		"revive_to_hand_data": {}
	}
	
	# ナチュラルワールドによる死亡時効果無効化チェック
	if _is_on_death_disabled():
		print("【死亡時効果】ナチュラルワールドにより無効化")
		return result
	
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
						# 条件チェック（例：敵HP20以下で道連れ発動）
						var condition = effect.get("condition", {})
						if not condition.is_empty():
							var condition_type = condition.get("condition_type", "")
							if condition_type == "enemy_hp_below":
								var threshold = condition.get("value", 0)
								var enemy_hp = opponent.current_hp
								if enemy_hp > threshold:
									print("【道連れ条件未達】敵HP:", enemy_hp, " > ", threshold)
									continue
								print("【道連れ条件達成】敵HP:", enemy_hp, " <= ", threshold)
						
						var probability = effect.get("probability", 100)
						var random_value = randf() * 100.0
						
						if random_value <= probability:
							print("【道連れ発動】", defeated.creature_data.get("name", "?"), " → ", 
								  opponent.creature_data.get("name", "?"), " (", probability, "% 判定成功)")
							
							# 相手を即死させる
							opponent.instant_death_flag = true
							opponent.current_hp = 0
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
	
	# 🔥 クリーチャースキル: on_death効果（サルファバルーン、マミー等）
	var creature_on_death_result = _process_creature_on_death_effects(defeated, opponent)
	result.merge(creature_on_death_result, true)
	
	# 💰 クリーチャースキル: 遺産（フェイト、コーンフォーク、マミー等）
	var game_flow_manager = _get_game_flow_manager()
	_skill_legacy.apply_on_death(defeated, spell_draw_ref, spell_magic_ref, game_flow_manager)
	
	# 🔄 手札復活チェック（フェニックス等）
	if _check_revive_to_hand(defeated):
		print("【復活発動】", defeated.creature_data.get("name", "?"), " → 手札に復活")
		result["revive_to_hand"] = true
		result["revive_to_hand_data"] = defeated.creature_data.duplicate(true)
		
		# 即座に手札に戻す
		if card_system_ref:
			var return_data = defeated.creature_data.duplicate(true)
			return_data["current_hp"] = return_data.get("hp", 0) + return_data.get("base_up_hp", 0)
			card_system_ref.return_card_to_hand(defeated.player_id, return_data)
		
		return result  # 手札復活の場合はタイル復活はチェックしない
	
	# 🔄 死者復活チェック（タイル復活、最後に処理）
	if card_loader:
		var revive_result = _check_and_apply_revive(defeated, opponent, card_loader)
		if revive_result["revived"]:
			result["revived"] = true
			result["new_creature_name"] = revive_result["new_creature_name"]
	
	return result

## 手札復活効果があるかチェック
func _check_revive_to_hand(participant: BattleParticipant) -> bool:
	"""
	手札復活効果（フェニックスの「復活」）があるかチェック
	
	Returns:
		手札復活効果があればtrue
	"""
	# クリーチャー自身の能力をチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "revive_to_hand" and effect.get("trigger") == "on_death":
			return true
	
	# アイテムからの手札復活効果をチェック
	var items = participant.creature_data.get("items", [])
	for item in items:
		var item_effect_parsed = item.get("effect_parsed", {})
		var item_effects = item_effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "revive_to_hand" and effect.get("trigger") == "on_death":
				return true
	
	return false

## 死者復活をチェックして適用
func _check_and_apply_revive(defeated: BattleParticipant, opponent: BattleParticipant, card_loader) -> Dictionary:
	"""
	死者復活効果をチェックして適用
	
	Args:
		defeated: 撃破されたクリーチャー
		opponent: 攻撃側クリーチャー（条件チェック用）
		card_loader: CardLoaderのインスタンス
	
	Returns:
		Dictionary: {
			"revived": bool,
			"new_creature_id": int,
			"new_creature_name": String
		}
	"""
	var result = {
		"revived": false,
		"new_creature_id": -1,
		"new_creature_name": ""
	}
	
	# 死者復活効果を探す
	var revive_effect = _find_revive_effect(defeated)
	if not revive_effect:
		return result
	
	print("[死者復活チェック] ", defeated.creature_data.get("name", "?"))
	
	# 条件チェック（条件付き復活の場合）
	if not _check_revive_condition(revive_effect, opponent):
		print("[死者復活] 条件未達成のため発動しません")
		return result
	
	# 復活先のクリーチャーIDを決定
	var new_creature_id = revive_effect.get("creature_id", -1)
	if new_creature_id <= 0:
		print("[死者復活] 無効なクリーチャーIDです: ", new_creature_id)
		return result
	
	# 復活実行
	var new_creature = card_loader.get_card_by_id(new_creature_id)
	if new_creature:
		_apply_revive(defeated, new_creature, result)
	else:
		print("[死者復活] クリーチャーが見つかりません: ID ", new_creature_id)
	
	return result

## 死者復活効果を探す
func _find_revive_effect(participant: BattleParticipant):
	"""
	クリーチャーまたはアイテムから死者復活効果を探す
	
	Returns:
		死者復活効果のDictionary、なければnull
	"""
	# クリーチャー自身の能力をチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "revive" and effect.get("trigger") == "on_death":
			return effect
	
	# アイテムからの復活効果をチェック
	var items = participant.creature_data.get("items", [])
	for item in items:
		var item_effect_parsed = item.get("effect_parsed", {})
		var item_effects = item_effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "revive" and effect.get("trigger") == "on_death":
				return effect
	
	return null

## 復活条件をチェック
func _check_revive_condition(revive_effect: Dictionary, opponent: BattleParticipant) -> bool:
	"""
	復活条件を満たすかチェック
	
	Args:
		revive_effect: 死者復活効果の定義
		opponent: 攻撃側のクリーチャー
	
	Returns:
		条件を満たすならtrue
	"""
	var revive_type = revive_effect.get("revive_type", "forced")
	
	# 強制復活は無条件で発動
	if revive_type == "forced":
		return true
	
	# 条件付き復活
	if revive_type == "conditional":
		var condition = revive_effect.get("condition", {})
		var condition_type = condition.get("type", "")
		
		match condition_type:
			"enemy_item_not_used":
				# 相手がアイテムを使用していない
				var item_category = condition.get("item_category", "")
				var opponent_used_item = _opponent_used_item_category(opponent, item_category)
				print("[条件チェック] 敵が", item_category, "を使用: ", opponent_used_item)
				return not opponent_used_item
		
		# 未知の条件タイプ
		print("[警告] 未知の条件タイプ: ", condition_type)
		return false
	
	return false

## 相手が特定カテゴリのアイテムを使用しているかチェック
func _opponent_used_item_category(opponent: BattleParticipant, category: String) -> bool:
	"""
	相手が特定カテゴリのアイテムを使用しているかチェック
	"""
	var items = opponent.creature_data.get("items", [])
	for item in items:
		var item_category = item.get("item_type", "")
		if item_category == category:
			return true
	return false

## 死者復活を適用
func _apply_revive(participant: BattleParticipant, new_creature: Dictionary, result: Dictionary) -> void:
	"""
	死者復活を実行
	"""
	var old_name = participant.creature_data.get("name", "?")
	var new_name = new_creature.get("name", "?")
	
	print("【死者復活】", old_name, " → ", new_name)
	
	# 現在のアイテムと永続ボーナスを記録
	var current_items = participant.creature_data.get("items", [])
	var current_base_up_hp = participant.base_up_hp
	var current_base_up_ap = participant.base_up_ap
	
	# creature_dataを新しいクリーチャーに置き換え
	participant.creature_data = new_creature.duplicate(true)
	
	# アイテム情報を引き継ぐ
	if not current_items.is_empty():
		participant.creature_data["items"] = current_items
	
	# 永続ボーナスを引き継ぐ
	participant.creature_data["base_up_hp"] = current_base_up_hp
	participant.creature_data["base_up_ap"] = current_base_up_ap
	participant.base_up_hp = current_base_up_hp
	participant.base_up_ap = current_base_up_ap
	
	# 基礎ステータスを新しいクリーチャーのものに更新
	participant.base_hp = new_creature.get("hp", 0)
	participant.current_ap = new_creature.get("ap", 0)
	
	# HPを復活後のMHPに設定
	participant.current_hp = participant.base_hp + participant.base_up_hp
	
	print("  復活後: AP=", participant.current_ap, " HP=", participant.current_hp)
	
	# 結果を記録
	result["revived"] = true
	result["new_creature_id"] = new_creature.get("id", -1)
	result["new_creature_name"] = new_name

## 🃏 生き残り時効果チェック（カード獲得スキル用）
func check_on_survive_effects(survivor: BattleParticipant) -> Dictionary:
	"""
	バトル中生き残ったクリーチャーのスキル効果を発動
	
	Args:
		survivor: 生き残ったクリーチャー
	
	Returns:
		{
			"cards_drawn": int,  # 引いたカード枚数
			"skill_activated": bool  # スキルが発動したか
		}
	"""
	var result = {
		"cards_drawn": 0,
		"skill_activated": false
	}
	
	if not survivor or not survivor.is_alive():
		return result
	
	if not spell_draw_ref:
		return result
	
	# クリーチャーのskill_idsをチェック
	var ability_parsed = survivor.creature_data.get("ability_parsed", {})
	var skill_ids = ability_parsed.get("skill_ids", [])
	
	if skill_ids.is_empty():
		return result
	
	# アイテム使用フラグ（アイテムを装備していれば使用したとみなす）
	var used_item = survivor.creature_data.get("items", []).size() > 0
	
	for skill_id in skill_ids:
		# spell_mystic.jsonからスキルデータを取得
		var skill_data = CardLoader.get_card_by_id(skill_id)
		if skill_data.is_empty():
			continue
		
		var effect_parsed = skill_data.get("effect_parsed", {})
		var trigger = effect_parsed.get("trigger", "")
		
		# on_surviveトリガーのみ処理
		if trigger != "on_survive":
			continue
		
		# trigger_conditionチェック
		var trigger_condition = effect_parsed.get("trigger_condition", {})
		if trigger_condition.has("self_used_item"):
			if trigger_condition["self_used_item"] and not used_item:
				print("【カード獲得スキップ】", survivor.creature_data.get("name", "?"), " - アイテム未使用")
				continue
		
		# 効果を発動
		var effects = effect_parsed.get("effects", [])
		for effect in effects:
			var effect_type = effect.get("effect_type", "")
			
			match effect_type:
				"draw_until":
					var target_hand_size = effect.get("target_hand_size", 5)
					var drawn = spell_draw_ref.draw_until(survivor.player_id, target_hand_size)
					result["cards_drawn"] += drawn.size()
					if drawn.size() > 0:
						result["skill_activated"] = true
						print("【カード獲得】", survivor.creature_data.get("name", "?"), 
							  " → プレイヤー", survivor.player_id + 1, "が", drawn.size(), "枚獲得（", target_hand_size, "枚まで）")
				
				"draw_cards":
					var count = effect.get("count", 1)
					var drawn = spell_draw_ref.draw_cards(survivor.player_id, count)
					result["cards_drawn"] += drawn.size()
					if drawn.size() > 0:
						result["skill_activated"] = true
						print("【カード獲得】", survivor.creature_data.get("name", "?"), 
							  " → プレイヤー", survivor.player_id + 1, "が", drawn.size(), "枚獲得")
				
				"draw_by_type":
					var card_type = effect.get("card_type", "item")
					var draw_result = spell_draw_ref.draw_card_by_type(survivor.player_id, card_type)
					if draw_result.get("drawn", false):
						result["cards_drawn"] += 1
						result["skill_activated"] = true
						print("【カード獲得】", survivor.creature_data.get("name", "?"), 
							  " → プレイヤー", survivor.player_id + 1, "が", card_type, "『", draw_result.get("card_name", "?"), "』を獲得")
	
	return result


## ナチュラルワールドで死亡時効果が無効化されているか
func _is_on_death_disabled() -> bool:
	var game_stats = _get_game_stats()
	return SpellWorldCurse.is_trigger_disabled("on_death", game_stats)


## game_statsを取得
func _get_game_stats() -> Dictionary:
	if not board_system_ref:
		return {}
	if not board_system_ref.game_flow_manager:
		return {}
	return board_system_ref.game_flow_manager.game_stats


## クリーチャースキルのon_death効果を処理
func _process_creature_on_death_effects(defeated: BattleParticipant, opponent: BattleParticipant) -> Dictionary:
	var result = {}
	
	var ability_parsed = defeated.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		var trigger = effect.get("trigger", "")
		if trigger != "on_death":
			continue
		
		var effect_type = effect.get("effect_type", "")
		var target = effect.get("target", "enemy")
		
		match effect_type:
			"instant_death":  # 道連れ（アイテムクリーチャーから継承）
				if target == "attacker" and opponent.is_alive():
					# 条件チェック（例：敵HP20以下で道連れ発動）
					var condition = effect.get("condition", {})
					if not condition.is_empty():
						var condition_type = condition.get("condition_type", "")
						if condition_type == "enemy_hp_below":
							var threshold = condition.get("value", 0)
							var enemy_hp = opponent.current_hp
							if enemy_hp > threshold:
								print("【道連れ条件未達】敵HP:", enemy_hp, " > ", threshold)
								continue
							print("【道連れ条件達成】敵HP:", enemy_hp, " <= ", threshold)
					
					var probability = effect.get("probability", 100)
					var random_value = randf() * 100.0
					
					if random_value <= probability:
						print("【道連れ発動】", defeated.creature_data.get("name", "?"), " → ", 
							  opponent.creature_data.get("name", "?"), " (", probability, "% 判定成功)")
						
						# 相手を即死させる
						opponent.instant_death_flag = true
						opponent.current_hp = 0
						result["death_revenge_activated"] = true
					else:
						print("【道連れ失敗】確率:", probability, "% 判定値:", int(random_value), "%")
			
			"damage_enemy":
				# サルファバルーン: 敵にHPダメージ
				if target == "enemy" and opponent.is_alive():
					var damage = effect.get("damage", 0)
					print("【自破壊時効果】%s → %s に %d ダメージ" % [
						defeated.creature_data.get("name", "?"),
						opponent.creature_data.get("name", "?"),
						damage
					])
					opponent.take_damage(damage)
					result["damage_enemy_activated"] = true
					
					if not opponent.is_alive():
						print("【自破壊時効果】%s は死亡" % opponent.creature_data.get("name", "?"))
						result["opponent_killed"] = true
			
			"legacy_gold":
				# マミー等: 遺産（ゴールド獲得）- skill_legacy.gdで処理
				pass
	
	return result


## on_death効果の金額計算
func _calculate_on_death_amount(effect: Dictionary, defeated: BattleParticipant) -> int:
	var formula = effect.get("amount_formula", "")
	
	if formula.is_empty():
		return effect.get("amount", 0)
	
	# "lap_count * 40" のような形式を解析
	if "lap_count" in formula:
		var lap_count = _get_lap_count(defeated.player_id)
		# 式を評価（簡易的に lap_count * N の形式のみ対応）
		var multiplier = 40  # デフォルト
		var regex = RegEx.new()
		regex.compile("lap_count\\s*\\*\\s*(\\d+)")
		var match_result = regex.search(formula)
		if match_result:
			multiplier = int(match_result.get_string(1))
		return lap_count * multiplier
	
	return effect.get("amount", 0)


## プレイヤーの周回数を取得
func _get_lap_count(player_id: int) -> int:
	var game_flow_manager = _get_game_flow_manager()
	if not game_flow_manager or not game_flow_manager.lap_system:
		return 1
	return game_flow_manager.lap_system.get_lap_count(player_id)


## PlayerSystemへの参照を取得
func _get_player_system():
	if not board_system_ref:
		return null
	if not board_system_ref.game_flow_manager:
		return null
	return board_system_ref.game_flow_manager.player_system


## GameFlowManagerへの参照を取得
func _get_game_flow_manager():
	if not board_system_ref:
		return null
	return board_system_ref.game_flow_manager


# =============================================================================
# 抹消効果（アネイマブル）- 敵を倒した時に同名カードを全て削除
# =============================================================================

## 勝者のon_kill効果をチェック・適用
## @param winner 勝者
## @param loser 敗者（倒されたクリーチャー）
## @return 抹消されたカード枚数
func check_and_apply_annihilate(winner: BattleParticipant, loser: BattleParticipant) -> int:
	var ability_parsed = winner.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("trigger") != "on_kill":
			continue
		if effect.get("effect_type") != "annihilate":
			continue
		
		# 確率チェック
		var probability = effect.get("probability", 100)
		var roll = randi() % 100
		if roll >= probability:
			print("【抹消】確率判定失敗 (%d%% >= %d%%)" % [roll, probability])
			return 0
		
		# 倒した敵の名前を取得
		var target_name = loser.creature_data.get("name", "")
		if target_name.is_empty():
			return 0
		
		# 相手プレイヤーのデッキと手札から同名カードを削除
		var deleted_count = _annihilate_cards(loser.player_id, target_name)
		
		print("【抹消】%s が %s を抹消！ → %d枚削除" % [
			winner.creature_data.get("name", "?"),
			target_name,
			deleted_count
		])
		
		return deleted_count
	
	return 0


## 指定プレイヤーの手札とデッキから同名カードを全削除
func _annihilate_cards(player_id: int, card_name: String) -> int:
	if not card_system_ref:
		push_error("BattleSpecialEffects._annihilate_cards: card_system_ref未設定")
		return 0
	
	var deleted_count = 0
	
	# 手札から削除（手札はカードデータの配列）
	var hand = card_system_ref.get_hand(player_id)
	var indices_to_remove = []
	for i in range(hand.size()):
		if hand[i].get("name", "") == card_name:
			indices_to_remove.append(i)
	
	# 後ろから削除（インデックスがずれないように）
	indices_to_remove.reverse()
	for index in indices_to_remove:
		card_system_ref.remove_card_from_hand(player_id, index)
		deleted_count += 1
		print("  [抹消] 手札から『%s』を削除" % card_name)
	
	# デッキから削除（デッキはカードIDの配列）
	var deck = card_system_ref.get_deck(player_id)
	var deck_indices_to_remove = []
	for i in range(deck.size()):
		var card_id = deck[i]
		var card_data = CardLoader.get_card_by_id(card_id) if CardLoader else {}
		if card_data.get("name", "") == card_name:
			deck_indices_to_remove.append(i)
	
	deck_indices_to_remove.reverse()
	for index in deck_indices_to_remove:
		card_system_ref.remove_card_from_deck(player_id, index)
		deleted_count += 1
		print("  [抹消] デッキから『%s』を削除" % card_name)
	
	return deleted_count
