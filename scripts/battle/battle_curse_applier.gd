extends Node
class_name BattleCurseApplier

# 呪い効果を temporary_effects に変換して適用

## 呪いをtemporary_effectsに変換して適用
func apply_creature_curses(participant: BattleParticipant, _tile_index: int) -> void:
	# クリーチャーデータから呪いを取得
	var creature_data = participant.creature_data
	
	if not creature_data or creature_data.is_empty() or not creature_data.has("curse"):
		return
	
	var curse = creature_data["curse"]
	var curse_type = curse.get("curse_type", "")
	var params = curse.get("params", {})
	var curse_name = curse.get("name", "")
	
	# 呪いタイプに応じてtemporary_effectsに追加
	match curse_type:
		"stat_boost":
			var value = params.get("value", 20)
			participant.temporary_effects.append({
				"type": "stat_bonus",
				"stat": "hp",
				"value": value,
				"source": "curse",
				"source_name": curse_name,
				"removable": true,
				"lost_on_move": true
			})
			participant.temporary_effects.append({
				"type": "stat_bonus",
				"stat": "ap",
				"value": value,
				"source": "curse",
				"source_name": curse_name,
				"removable": true,
				"lost_on_move": true
			})
			print("[呪い変換] stat_boost: HP+", value, ", AP+", value)
			
			# 効果を計算に反映
			print("[DEBUG呪い] 変換前: temporary_bonus_hp=", participant.temporary_bonus_hp, " current_hp=", participant.current_hp)
			participant.temporary_bonus_hp += value
			participant.current_hp += value
			participant.temporary_bonus_ap += value
			print("[DEBUG呪い] 変換後: temporary_bonus_hp=", participant.temporary_bonus_hp, " current_hp=", participant.current_hp)
		
		"stat_reduce":
			var value = params.get("value", -20)
			var stat = params.get("stat", "both")  # "hp", "ap", "both"
			
			# HP減少
			if stat == "hp" or stat == "both":
				participant.temporary_effects.append({
					"type": "stat_bonus",
					"stat": "hp",
					"value": value,
					"source": "curse",
					"source_name": curse_name,
					"removable": true,
					"lost_on_move": true
				})
				participant.temporary_bonus_hp += value
				participant.current_hp += value
			
			# AP減少
			if stat == "ap" or stat == "both":
				participant.temporary_effects.append({
					"type": "stat_bonus",
					"stat": "ap",
					"value": value,
					"source": "curse",
					"source_name": curse_name,
					"removable": true,
					"lost_on_move": true
				})
				participant.temporary_bonus_ap += value
			
			# ログ出力
			match stat:
				"hp":
					print("[呪い変換] stat_reduce: HP", value)
				"ap":
					print("[呪い変換] stat_reduce: AP", value)
				_:
					print("[呪い変換] stat_reduce: HP", value, ", AP", value)
		
		"ap_nullify":
			# 基礎APを0に固定（バフ・アイテムは加算可能）
			var base_ap = participant.creature_data.get("ap", 0)
			var base_up_ap = participant.base_up_ap
			var nullify_value = -(base_ap + base_up_ap)  # 基礎APを打ち消す値
			
			participant.temporary_effects.append({
				"type": "ap_nullify",
				"value": nullify_value,
				"source": "curse",
				"source_name": curse_name,
				"removable": true,
				"lost_on_move": true
			})
			print("[呪い変換] ap_nullify: 基礎AP=0 (", base_ap, "+", base_up_ap, " → 0)")
			
			# 効果を計算に反映（基礎APを打ち消す）
			participant.temporary_bonus_ap += nullify_value
		
		"random_stat":
			# 能力値不定（リキッドフォーム）- AP&HPをランダム値に設定
			# SkillSpecialCreatureScript.apply_random_stat_effects()と同じ処理
			var stat = params.get("stat", "both")
			var min_value = int(params.get("min", 10))
			var max_value = int(params.get("max", 70))
			
			# STをランダムに設定
			if stat == "ap" or stat == "both":
				var random_ap = randi() % (max_value - min_value + 1) + min_value
				var base_ap = participant.creature_data.get("ap", 0)
				var base_up_ap = participant.creature_data.get("base_up_ap", 0)
				participant.temporary_bonus_ap = random_ap - (base_ap + base_up_ap)
				participant.current_ap = random_ap
				print("[呪い変換] random_stat: AP=", random_ap, " (", min_value, "~", max_value, ")")
			
			# HPをランダムに設定
			if stat == "hp" or stat == "both":
				var random_hp = randi() % (max_value - min_value + 1) + min_value
				var base_hp = participant.creature_data.get("hp", 0)
				var base_up_hp = participant.creature_data.get("base_up_hp", 0)
				participant.temporary_bonus_hp = random_hp - (base_hp + base_up_hp)
				participant.current_hp = random_hp
				print("[呪い変換] random_stat: HP=", random_hp, " (", min_value, "~", max_value, ")")
			
			# temporary_effectsに記録（表示用）
			participant.temporary_effects.append({
				"type": "random_stat",
				"source": "curse",
				"source_name": curse_name,
				"removable": true,
				"lost_on_move": true
			})
			
			# random_statは既にcurrent_ap/hpを直接設定済みなので、ここでreturn
			return
		
		"metal_form", "magic_barrier":
			# 無効化[通常攻撃]を付与（呪いによる無効化スキル）
			# ability_parsedにkeyword_conditionsとして追加
			var ability_parsed = participant.creature_data.get("ability_parsed", {})
			if not ability_parsed.has("keywords"):
				ability_parsed["keywords"] = []
			if not ability_parsed.has("keyword_conditions"):
				ability_parsed["keyword_conditions"] = {}
			if not ability_parsed["keyword_conditions"].has("無効化"):
				ability_parsed["keyword_conditions"]["無効化"] = []
			
			# 既にkeywordsに無効化がなければ追加
			if not "無効化" in ability_parsed["keywords"]:
				ability_parsed["keywords"].append("無効化")
			
			# normal_attack無効化条件を追加
			ability_parsed["keyword_conditions"]["無効化"].append({
				"nullify_type": "normal_attack",
				"reduction_rate": 0.0
			})
			
			# ability_parsedをcreature_dataに反映
			participant.creature_data["ability_parsed"] = ability_parsed
			
			# temporary_effectsに記録（表示用）
			participant.temporary_effects.append({
				"type": "nullify_normal_attack",
				"source": "curse",
				"source_name": curse_name,
				"curse_type": curse_type,
				"removable": true,
				"lost_on_move": true
			})
			print("[呪い変換] ", curse_type, ": 無効化[通常攻撃]を付与")
			
			# magic_barrierの場合、G100移動パラメータを記録
			if curse_type == "magic_barrier":
				var gold_transfer = params.get("gold_transfer", 100)
				participant.temporary_effects.append({
					"type": "gold_transfer_on_nullify",
					"value": gold_transfer,
					"source": "curse",
					"source_name": curse_name
				})
				print("[呪い変換] magic_barrier: 攻撃無効化時にG", gold_transfer, "移動")
	
	# current_hpとcurrent_apを更新
	participant.current_ap += participant.temporary_bonus_ap
	# update_current_hp() は呼ばない（current_hp が状態値になったため）
