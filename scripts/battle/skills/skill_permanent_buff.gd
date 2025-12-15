## 永続バフ・永続変化スキル処理モジュール
##
## 敵破壊時の永続バフ（バルキリー・ダスクドウェラー）と
## バトル後の永続変化（ロックタイタン・バイロマンサー・ブルガサリ・スペクター）を処理
##
## 使用方法:
## ```gdscript
## # 敵破壊時の永続バフ適用
## SkillPermanentBuff.apply_on_destroy_buffs(participant)
##
## # バトル後の永続変化適用
## SkillPermanentBuff.apply_after_battle_changes(participant)
## ```

class_name SkillPermanentBuff

# ========================================
# 敵破壊時の永続バフ
# ========================================

## 敵破壊時の永続バフ適用（バルキリー・ダスクドウェラー）
## @param participant: 敵を破壊した側のBattleParticipant
static func apply_on_destroy_buffs(participant: BattleParticipant) -> void:
	if not participant or not participant.creature_data:
		return
	
	print("[DEBUG_永続バフ] 関数開始: ", participant.creature_data.get("name", "?"), 
		  " ID:", participant.creature_data.get("id", "?"),
		  " 現在のbase_up_hp:", participant.base_up_hp,
		  " 現在のbase_up_ap:", participant.base_up_ap)
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	print("[DEBUG_永続バフ] 破壊時効果数: ", effects.size())
	
	for effect in effects:
		if effect.get("effect_type") == "on_enemy_destroy_permanent":
			print("[DEBUG_永続バフ] on_enemy_destroy_permanent 効果を検出")
			var stat_changes = effect.get("stat_changes", {})
			
			for stat in stat_changes:
				var value = stat_changes[stat]
				if stat == "ap":
					# BattleParticipantのプロパティに保存（参照汚染を防ぐ）
					participant.base_up_ap += value
					print("[永続バフ] ", participant.creature_data.get("name", ""), " AP+", value)
				
				elif stat == "max_hp":
					# BattleParticipantのプロパティに保存（参照汚染を防ぐ）
					var old_base_up_hp = participant.base_up_hp
					participant.base_up_hp += value
					participant.current_hp += value  # MHPが増えたら現在HPも増やす
					print("[永続バフ] ", participant.creature_data.get("name", ""), " MHP+", value)
					print("  base_up_hp: ", old_base_up_hp, " → ", participant.base_up_hp)

# ========================================
# バトル後の永続変化
# ========================================

## バトル後の永続的な変化を適用（勝敗問わず）
## ロックタイタン (ID: 446)、バイロマンサー (ID: 34)、
## ブルガサリ (ID: 339)、スペクター (ID: 321)
## @param participant: BattleParticipant
static func apply_after_battle_changes(participant: BattleParticipant) -> void:
	if not participant or not participant.creature_data:
		return
	
	var creature_id = participant.creature_data.get("id", -1)
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	# バイロマンサー専用処理（敵から攻撃を受けた場合のみ発動）
	_apply_bairomancer_effect(participant, creature_id)
	
	# ブルガサリ専用処理（敵がアイテムを使用した戦闘後、MHP+10）
	_apply_bulgasari_effect(participant, creature_id)
	
	# 汎用永続変化（ロックタイタン等）
	_apply_generic_permanent_changes(participant, effects)
	
	# スペクター専用処理（戦闘後にランダムステータスをリセット）
	_apply_specter_reset(participant, creature_id, effects)

# ========================================
# 個別クリーチャー処理
# ========================================

## バイロマンサー (ID: 34) - 敵から攻撃を受けるとAP=20, MHP-30
static func _apply_bairomancer_effect(participant: BattleParticipant, creature_id: int) -> void:
	if creature_id != 34:
		return
	
	# 敵から攻撃を受けた、かつ生き残っている、かつまだ発動していない
	if participant.was_attacked_by_enemy and participant.is_alive():
		if not participant.creature_data.get("bairomancer_triggered", false):
			# AP=20（完全上書き）、MHP-30
			var old_ap = participant.creature_data.get("ap", 0)
			var old_base_up_ap = participant.creature_data.get("base_up_ap", 0)
			
			participant.creature_data["ap"] = 20  # 基礎APを20に上書き
			participant.base_up_ap = 0  # BattleParticipantのプロパティをリセット
			
			# BattleParticipantのプロパティから30減少
			participant.base_up_hp -= 30
			
			# 発動フラグを設定
			participant.creature_data["bairomancer_triggered"] = true
			
			print("[バイロマンサー発動] 敵の攻撃を受けて変化！")
			print("  AP: ", old_ap + old_base_up_ap, " → 20")
			print("  MHP-30 (合計MHP:", participant.creature_data.get("hp", 0) + participant.base_up_hp, ")")

## ブルガサリ (ID: 339) - 敵がアイテムを使用した戦闘後、MHP+10
static func _apply_bulgasari_effect(participant: BattleParticipant, creature_id: int) -> void:
	if creature_id != 339:
		return
	
	if participant.enemy_used_item and participant.is_alive():
		# BattleParticipantのプロパティに保存
		participant.base_up_hp += 10
		print("[ブルガサリ発動] 敵のアイテム使用後 MHP+10 (合計MHP:", participant.creature_data.get("hp", 0) + participant.base_up_hp, ")")

## 汎用永続変化処理（after_battle_permanent_change効果タイプ）
static func _apply_generic_permanent_changes(participant: BattleParticipant, effects: Array) -> void:
	for effect in effects:
		if effect.get("effect_type") == "after_battle_permanent_change":
			var stat_changes = effect.get("stat_changes", {})
			
			for stat in stat_changes:
				var value = stat_changes[stat]
				if stat == "ap":
					_apply_ap_change(participant, value)
				elif stat == "max_hp":
					_apply_mhp_change(participant, value)

## AP変化を適用（下限0チェック付き）
static func _apply_ap_change(participant: BattleParticipant, value: int) -> void:
	if not participant.creature_data.has("base_up_ap"):
		participant.creature_data["base_up_ap"] = 0
	
	# 下限チェック: AP（base_ap + base_up_ap）が0未満にならないようにする
	var new_base_up_ap = participant.creature_data["base_up_ap"] + value
	var new_total_ap = participant.creature_data.get("ap", 0) + new_base_up_ap
	
	if new_total_ap < 0:
		# 合計APが0になるように調整
		new_base_up_ap = -participant.creature_data.get("ap", 0)
		print("[永続変化] ", participant.creature_data.get("name", ""), " AP", value, " → 下限0に制限")
	
	participant.creature_data["base_up_ap"] = new_base_up_ap
	print("[永続変化] ", participant.creature_data.get("name", ""), " AP", "+" if value >= 0 else "", value, " (合計AP:", participant.creature_data.get("ap", 0) + new_base_up_ap, ")")

## MHP変化を適用（下限0チェック付き）
static func _apply_mhp_change(participant: BattleParticipant, value: int) -> void:
	# 下限チェック: MHP（hp + base_up_hp）が0未満にならないようにする
	var new_base_up_hp = participant.base_up_hp + value
	var new_total_hp = participant.creature_data.get("hp", 0) + new_base_up_hp
	
	if new_total_hp < 0:
		# 合計MHPが0になるように調整
		new_base_up_hp = -participant.creature_data.get("hp", 0)
		print("[永続変化] ", participant.creature_data.get("name", ""), " MHP", value, " → 下限0に制限")
	
	# creature_dataとBattleParticipantの両方に保存（AP処理と統一）
	participant.creature_data["base_up_hp"] = new_base_up_hp
	participant.base_up_hp = new_base_up_hp
	print("[永続変化] ", participant.creature_data.get("name", ""), " MHP", "+" if value >= 0 else "", value, " (合計MHP:", participant.creature_data.get("hp", 0) + new_base_up_hp, ")")

## スペクター (ID: 321) - 戦闘後にランダムステータスをリセット
static func _apply_specter_reset(participant: BattleParticipant, creature_id: int, effects: Array) -> void:
	if creature_id != 321:
		return
	
	# random_statエフェクトを持つ場合、base_hp/base_apを元の値に戻す
	var has_random_stat = false
	for effect in effects:
		if effect.get("effect_type") == "random_stat":
			has_random_stat = true
			break
	
	if has_random_stat and participant.is_alive():
		# 元のカードデータからbase_hp/base_apを取得
		var original_hp = CardLoader.get_card_by_id(321).get("hp", 20)
		var original_ap = CardLoader.get_card_by_id(321).get("ap", 20)
		
		# creature_dataのhp/apを元の値に戻す
		participant.creature_data["hp"] = original_hp
		participant.creature_data["ap"] = original_ap
		
		print("[ランダムステータスリセット] スペクターの能力値を初期値に戻しました (AP:", original_ap, ", HP:", original_hp, ")")
