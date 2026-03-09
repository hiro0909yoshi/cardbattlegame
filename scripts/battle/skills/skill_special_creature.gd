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
				# これにより二重計算を防ぐ。刻印等の後続効果はtemporary_bonus_hpに加算される
				participant.current_hp = random_hp
				print("【ランダム能力値】", participant.creature_data.get("name", "?"), 
					  " HP=", random_hp, " (", min_value, "~", max_value, ")")
			
			return

## 参加者1人分の全スキル・能力を無条件でクリア
##
## 沈黙発動時に呼ばれる。検出は呼び出し側（battle_skill_processor）で行い、
## この関数はチェックなしで無条件にクリアする。
##
## @param participant クリア対象の参加者
static func clear_all_abilities(participant: BattleParticipant) -> void:
	var name = participant.creature_data.get("name", "?")

	# クリーチャー固有スキルを無効化
	var old_ability_parsed = participant.creature_data.get("ability_parsed", {})
	if not old_ability_parsed.is_empty():
		var old_keywords = old_ability_parsed.get("keywords", [])
		if old_keywords.size() > 0:
			print("  [沈黙] ", name, " 無効化されたスキル: ", old_keywords)
		var old_effects = old_ability_parsed.get("effects", [])
		if old_effects.size() > 0:
			var effect_types: Array[String] = []
			for eff in old_effects:
				effect_types.append(eff.get("effect_type", "?"))
			print("  [沈黙] ", name, " 無効化されたクリーチャー効果: ", effect_types)

	# ability_parsed全体を空で置き換え
	participant.creature_data["ability_parsed"] = {
		"keywords": [],
		"effects": [],
		"keyword_conditions": {}
	}

	# ability / ability_detail のテキストもクリア
	participant.creature_data["ability"] = ""
	participant.creature_data["ability_detail"] = ""

	# アイテムのスキル効果を無効化（stat_bonusのみ残す）
	var items = participant.creature_data.get("items", [])
	for item in items:
		if item.has("effect_parsed"):
			var effect_parsed = item.get("effect_parsed", {})
			var stat_bonus = effect_parsed.get("stat_bonus", {})
			# effect_parsed丸ごと差し替え（stat_bonusのみ残す）
			item["effect_parsed"] = {"stat_bonus": stat_bonus}

	# スキルフラグを全て無効化
	participant.has_first_strike = false
	participant.has_last_strike = false
	participant.has_item_first_strike = false
	participant.attack_count = 1

	print("  [沈黙] ", name, " → 基礎ステータスのみで戦闘")


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
