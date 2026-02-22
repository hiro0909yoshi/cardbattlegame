class_name SkillSpecialCreature

## 特殊クリーチャースキル
##
## バトル準備フェーズで特定のクリーチャーに対する特殊処理を担当
##
## 【担当クリーチャー】
## - オーガロード (ID: 407): オーガ配置時能力値上昇
## - スペクター (ID: 323): ランダム能力値設定
##
## 【担当アイテム】
## - ウォーロックディスク (ID: 1004): 敵の全沈黙
##
## @version 1.0
## @date 2025-11-03

## オーガロード（ID: 407）: オーガ配置時能力値上昇
##
## 同じプレイヤーのオーガの配置状況に応じてボーナスを付与
## - 火風オーガ: AP+20
## - 水地オーガ: HP+20
##
## @param participant バトル参加者
## @param player_index プレイヤーインデックス
## @param board_system_ref ボードシステムの参照
static func apply_ogre_lord_bonus(participant: BattleParticipant, player_index: int, board_system_ref) -> void:
	if not board_system_ref:
		return
	
	# 全タイルをチェックして、配置されているオーガの数と属性をカウント
	var fire_wind_ogre_count = 0  # 火風オーガの数
	var water_earth_ogre_count = 0  # 水地オーガの数
	
	# tile_data_managerからタイルノードを取得
	var tile_data_manager = board_system_ref.tile_data_manager
	if not tile_data_manager:
		return
	
	for tile_index in tile_data_manager.tile_nodes:
		var tile = tile_data_manager.tile_nodes[tile_index]
		
		# このタイルにクリーチャーが配置されているか?
		if tile.creature_data.is_empty():
			continue
		
		var creature_data = tile.creature_data
		
		# このクリーチャーの所有者がオーガロードと同じプレイヤーか?
		var creature_owner = tile.owner_id
		if creature_owner != player_index:
			continue
		
		# このクリーチャーがオーガか？
		var race = creature_data.get("race", "")
		if race != "オーガ":
			continue
		
		# オーガロード自身は除外
		if creature_data.get("id", -1) == 407:
			continue
		
		# オーガの属性を取得
		var element = creature_data.get("element", "")
		
		if element == "fire" or element == "wind":
			fire_wind_ogre_count += 1
		elif element == "water" or element == "earth":
			water_earth_ogre_count += 1
	
	# バフを適用
	var bonus_applied = false
	
	if fire_wind_ogre_count > 0:
		participant.temporary_bonus_ap += 20
		participant.update_current_ap()
		bonus_applied = true
		print("[オーガロード] 火風オーガ配置(", fire_wind_ogre_count, "体) AP+20")
	
	if water_earth_ogre_count > 0:
		participant.temporary_bonus_hp += 20
		bonus_applied = true
		print("[オーガロード] 水地オーガ配置(", water_earth_ogre_count, "体) HP+20")
	
	# バフが適用された場合はフラグを設定
	if bonus_applied:
		participant.has_ogre_bonus = true

## ランダムステータス効果を適用（スペクター用）
##
## スペクター (ID: 323) のランダム能力値設定
## 指定範囲内でSTやHPをランダムに決定
##
## @param participant バトル参加者
static func apply_random_stat_effects(participant: BattleParticipant) -> void:
	if not participant or not participant.creature_data:
		return
	
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "random_stat":
			var stat = effect.get("stat", "both")
			var min_value = int(effect.get("min", 10))
			var max_value = int(effect.get("max", 70))
			
			randomize()
			
			# STをランダムに設定
			if stat == "ap" or stat == "both":
				var random_ap = randi() % (max_value - min_value + 1) + min_value
				var base_ap = participant.creature_data.get("ap", 0)
				var base_up_ap = participant.creature_data.get("base_up_ap", 0)
				participant.temporary_bonus_ap = random_ap - (base_ap + base_up_ap)
				participant.update_current_ap()
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " ST=", participant.current_ap, " (", min_value, "~", max_value, ")")
			
			# HPをランダムに設定
			if stat == "hp" or stat == "both":
				var random_hp = randi() % (max_value - min_value + 1) + min_value
				# current_hpにランダム値を設定（temporary_bonus_hpは0のまま）
				# これにより二重計算を防ぐ。呪い等の後続効果はtemporary_bonus_hpに加算される
				participant.current_hp = random_hp
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " HP=", random_hp, " (", min_value, "~", max_value, ")")
			
			return

## ウォーロックディスク: 敵の全能力を無効化
##
## アイテム「ウォーロックディスク」(ID: 1004) の効果
## 装備者の敵のすべてのスキル・能力を無効化し、基礎ステータスのみで戦闘させる
##
## @param self_participant 装備者（攻撃側 or 防御側）
## @param enemy_participant 敵（無効化対象）
static func apply_nullify_enemy_abilities(self_participant: BattleParticipant, enemy_participant: BattleParticipant) -> void:
	var has_nullify_ability = false
	var nullify_source = ""
	
	# 1. クリーチャー自身のability_parsedをチェック（シーボンズなど）
	var self_ability_parsed = self_participant.creature_data.get("ability_parsed", {})
	var self_effects = self_ability_parsed.get("effects", [])
	for effect in self_effects:
		if effect.get("effect_type") == "nullify_all_enemy_abilities":
			has_nullify_ability = true
			nullify_source = "creature"
			break
	
	# 2. アイテム（ウォーロックディスク）をチェック
	if not has_nullify_ability:
		var items = self_participant.creature_data.get("items", [])
		for item in items:
			var effect_parsed = item.get("effect_parsed", {})
			var effects = effect_parsed.get("effects", [])
			for effect in effects:
				if effect.get("effect_type") == "nullify_all_enemy_abilities":
					has_nullify_ability = true
					nullify_source = "item"
					break
			if has_nullify_ability:
				break
	
	# 3. 敵に skill_nullify 呪いがついているかチェック
	var enemy_curse = enemy_participant.creature_data.get("curse", {})
	var enemy_has_skill_nullify = enemy_curse.get("curse_type") == "skill_nullify"
	
	# どちらも該当しなければ何もしない
	if not has_nullify_ability and not enemy_has_skill_nullify:
		return
	
	# ログ出力（発動元を区別）
	if has_nullify_ability:
		if nullify_source == "creature":
			print("【戦闘中能力無効発動】", self_participant.creature_data.get("name", "?"), 
			  " → ", enemy_participant.creature_data.get("name", "?"), "の全能力を無効化")
		else:
			print("【ウォーロックディスク発動】", self_participant.creature_data.get("name", "?"), 
			  " → ", enemy_participant.creature_data.get("name", "?"), "の全能力を無効化")
	elif enemy_has_skill_nullify:
		var curse_name = enemy_curse.get("name", "錯乱")
		print("【呪い発動: ", curse_name, "】", enemy_participant.creature_data.get("name", "?"), "の全能力を無効化")
	
	# 敵のクリーチャー固有スキルを無効化
	if enemy_participant.creature_data.has("ability_parsed"):
		var ability_parsed = enemy_participant.creature_data.get("ability_parsed", {})
		
		# keywordsを空にする
		if ability_parsed.has("keywords"):
			var keywords = ability_parsed.get("keywords", [])
			if keywords.size() > 0:
				print("  無効化されたスキル: ", keywords)
				ability_parsed["keywords"] = []
		
		# effectsを空にする（特殊効果）
		if ability_parsed.has("effects"):
			var effects = ability_parsed.get("effects", [])
			if effects.size() > 0:
				var effect_types = []
				for eff in effects:
					effect_types.append(eff.get("effect_type", "?"))
				print("  無効化されたクリーチャー効果: ", effect_types)
				ability_parsed["effects"] = []
	
	# 敵のアイテムで付与されたスキルを無効化
	var enemy_items = enemy_participant.creature_data.get("items", [])
	for enemy_item in enemy_items:
		if enemy_item.has("effect_parsed"):
			var effect_parsed = enemy_item.get("effect_parsed", {})
			
			# keywordsを空にする
			if effect_parsed.has("keywords"):
				var keywords = effect_parsed.get("keywords", [])
				if keywords.size() > 0:
					print("  無効化されたアイテムキーワード: ", keywords)
					effect_parsed["keywords"] = []
			
			# effectsを空にする（反射、無効化などの特殊効果）
			if effect_parsed.has("effects"):
				var effects = effect_parsed.get("effects", [])
				if effects.size() > 0:
					var effect_types = []
					for eff in effects:
						effect_types.append(eff.get("effect_type", "?"))
					print("  無効化されたアイテム効果: ", effect_types)
					effect_parsed["effects"] = []
			
			# grant_skillsを削除
			if effect_parsed.has("grant_skills"):
				var grant_skills = effect_parsed.get("grant_skills", [])
				if grant_skills.size() > 0:
					print("  無効化されたアイテムスキル: ", grant_skills)
					effect_parsed.erase("grant_skills")
	
	# 敵のスキルフラグを全て無効化
	enemy_participant.has_first_strike = false
	enemy_participant.has_last_strike = false
	enemy_participant.has_item_first_strike = false
	enemy_participant.attack_count = 1  # 通常攻撃に戻す（2回攻撃無効化）
	
	print("  → 敵は基礎ステータスのみで戦闘")


# =============================================================================
# トリガー無効化（ブラックナイト等）
# =============================================================================

## 特定トリガーの能力を無効化するかチェック
## ブラックナイト: 敵の攻撃成功時能力を無効化
## スクイドマントル: 敵の攻撃成功時能力を無効化（アイテム）
##
## @param defender_data 防御側のcreature_data（無効化能力を持つ側）
## @param trigger チェックするトリガー（"on_attack_success"等）
## @return 該当トリガーが無効化されるならtrue
static func is_trigger_nullified(defender_data: Dictionary, trigger: String) -> bool:
	# クリーチャー能力からチェック
	var ability_parsed = defender_data.get("ability_parsed", {})
	var nullify_triggers = ability_parsed.get("nullify_triggers", [])
	if trigger in nullify_triggers:
		return true
	
	# アイテムからチェック（スクイドマントル等）
	var items = defender_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})
		var item_nullify_triggers = effect_parsed.get("nullify_triggers", [])
		if trigger in item_nullify_triggers:
			return true
	
	return false
