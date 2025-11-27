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
			participant.temporary_bonus_hp += value
			participant.current_hp += value
			participant.temporary_bonus_ap += value
		
		"stat_reduce":
			var value = params.get("value", -20)
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
			print("[呪い変換] stat_reduce: HP", value, ", AP", value)
			
			# 効果を計算に反映
			participant.temporary_bonus_hp += value
			participant.current_hp += value
			participant.temporary_bonus_ap += value
		
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
	
	# current_hpとcurrent_apを更新
	participant.current_ap += participant.temporary_bonus_ap
	# update_current_hp() は呼ばない（current_hp が状態値になったため）
