class_name SkillTransform

## 変身スキル処理モジュール
##
## クリーチャーの変身（ランダム変身、強制変身）の処理を行う
## 
## 注: 死者復活はbattle_special_effects.gdのcheck_on_death_effects()に移動済み
##
## 使用方法:
## ```gdscript
## # 攻撃成功時の変身
## var result = SkillTransform.process_transform_effects(attacker, defender, card_loader, "on_attack_success")
## 
## # 戦闘後の変身復帰
## SkillTransform.revert_transform(participant, original_data)
## ```

# ========================================
# 変身スキル処理
# ========================================

## 変身効果を処理
##
## @param attacker: 攻撃側参加者
## @param defender: 防御側参加者
## @param card_loader: CardLoaderのインスタンス（クリーチャーデータ取得用）
## @param trigger: 発動タイミング（"on_battle_start", "on_attack_success"など）
## @return Dictionary {
##   "attacker_transformed": bool,
##   "defender_transformed": bool,
##   "attacker_original": Dictionary (元のcreature_data、戻す必要がある場合のみ),
##   "defender_original": Dictionary
## }
static func process_transform_effects(attacker: BattleParticipant, defender: BattleParticipant, card_loader, trigger: String) -> Dictionary:
	var result = {
		"attacker_transformed": false,
		"defender_transformed": false,
		"attacker_original": {},
		"defender_original": {}
	}
	
	# 攻撃側の変身効果チェック
	var attacker_transform = _check_transform(attacker, trigger)
	if attacker_transform:
		var target = attacker_transform.get("target", "self")
		if target == "self":
			# 自分自身が変身
			_apply_transform(attacker, attacker_transform, card_loader, result, true, defender)
		elif target == "opponent":
			# 相手を変身させる
			_apply_transform(defender, attacker_transform, card_loader, result, false, attacker)
	
	# 防御側の変身効果チェック
	var defender_transform = _check_transform(defender, trigger)
	if defender_transform:
		var target = defender_transform.get("target", "self")
		if target == "self":
			# 自分自身が変身
			_apply_transform(defender, defender_transform, card_loader, result, false, attacker)
		elif target == "opponent":
			# 相手を変身させる
			_apply_transform(attacker, defender_transform, card_loader, result, true, defender)
	
	return result

## 変身を元に戻す（ハルゲンダース専用）
##
## @param participant: 参加者
## @param original_data: 元のcreature_data
static func revert_transform(participant: BattleParticipant, original_data: Dictionary) -> void:
	if original_data.is_empty():
		return
	
	print("[変身解除] ", participant.creature_data.get("name", "?"), " → ", original_data.get("name", "?"))
	
	# creature_dataを完全に元に戻す
	participant.creature_data = original_data.duplicate(true)

## 変身効果があるかチェック
##
## @param participant: BattleParticipant
## @param trigger: 発動タイミング
## @return 変身効果のDictionary、なければnull
static func _check_transform(participant: BattleParticipant, trigger: String):
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "transform" and effect.get("trigger") == trigger:
			return effect
	
	return null

## 変身を適用
static func _apply_transform(participant: BattleParticipant, transform_effect: Dictionary, card_loader, result: Dictionary, is_attacker: bool, opponent: BattleParticipant = null) -> void:
	var transform_type = transform_effect.get("transform_type", "")
	var revert_after_battle = transform_effect.get("revert_after_battle", false)
	
	# 元のデータを保存（戦闘後に戻す必要がある場合）
	var original_data = {}
	if revert_after_battle:
		original_data = participant.creature_data.duplicate(true)
	
	# 変身タイプに応じて処理
	var new_creature_id = -1
	
	match transform_type:
		"random":
			new_creature_id = _get_random_creature_id(card_loader)
			print("[ランダム変身] ", participant.creature_data.get("name", "?"), " → ID:", new_creature_id)
		
		"forced":
			new_creature_id = transform_effect.get("creature_id", -1)
			print("[強制変身] ", participant.creature_data.get("name", "?"), " → ID:", new_creature_id)
		
		"specific":
			new_creature_id = transform_effect.get("creature_id", -1)
			print("[特定変身] ", participant.creature_data.get("name", "?"), " → ID:", new_creature_id)
		
		"forced_copy_attacker":
			# ツインスパイク専用：攻撃側のクリーチャーIDをコピー
			if opponent:
				new_creature_id = opponent.creature_data.get("id", -1)
				print("[ツインスパイク] ", participant.creature_data.get("name", "?"), " → ", opponent.creature_data.get("name", "?"), " (ID:", new_creature_id, ")")
		
		"random_by_race":
			# 特定の種族からランダムに選択（ドラゴンオーブ用）
			var race = transform_effect.get("race", "")
			new_creature_id = _get_random_creature_by_race(card_loader, race)
			print("[種族ランダム変身] ", participant.creature_data.get("name", "?"), " → 種族:", race, " ID:", new_creature_id)
		
		"random_by_name_pattern":
			# 名前パターンからランダムに選択（ドラゴンオーブ用）
			var name_pattern = transform_effect.get("name_pattern", "")
			new_creature_id = _get_random_creature_by_name_pattern(card_loader, name_pattern)
			print("[名前パターン変身] ", participant.creature_data.get("name", "?"), " → パターン:", name_pattern, " ID:", new_creature_id)

	
	# 新しいクリーチャーデータを取得
	if new_creature_id > 0:
		var new_creature = card_loader.get_card_by_id(new_creature_id)
		if new_creature:
			_transform_creature(participant, new_creature, is_attacker, result, original_data)

## 実際にクリーチャーを変身させる
static func _transform_creature(participant: BattleParticipant, new_creature: Dictionary, is_attacker: bool, result: Dictionary, original_data: Dictionary) -> void:
	var old_name = participant.creature_data.get("name", "?")
	var new_name = new_creature.get("name", "?")
	
	print("【変身実行】", old_name, " → ", new_name)
	print("  元のAP/HP: ", participant.current_ap, "/", participant.current_hp)
	
	# 重要: 現在のバフ（アイテム効果など）と永続ボーナスを記録
	var current_ap = participant.current_ap
	var current_item_bonus_hp = participant.item_bonus_hp
	var current_items = participant.creature_data.get("items", [])
	var current_base_up_hp = participant.base_up_hp  # 永続ボーナスを保持
	
	# creature_dataを新しいクリーチャーに置き換え
	participant.creature_data = new_creature.duplicate(true)
	
	# アイテム情報を引き継ぐ
	if not current_items.is_empty():
		participant.creature_data["items"] = current_items
	
	# 永続ボーナス（base_up_hp）を引き継ぐ
	participant.creature_data["base_up_hp"] = current_base_up_hp
	participant.base_up_hp = current_base_up_hp
	
	# 基礎ステータスを新しいクリーチャーのものに更新
	participant.base_hp = new_creature.get("hp", 0)
	
	# APは新しいクリーチャーのベース値を使用（バフは考慮しない）
	participant.current_ap = new_creature.get("ap", 0)
	
	# HPバフを再適用
	participant.item_bonus_hp = current_item_bonus_hp
	
	# HPを再計算（土地ボーナスとアイテムボーナスを含む）
	# 変身後のMHP = base_hp + base_up_hp + land_bonus_hp + item_bonus_hp + その他ボーナス
	participant.current_hp = participant.base_hp + participant.base_up_hp + participant.land_bonus_hp + participant.item_bonus_hp + participant.spell_bonus_hp + participant.temporary_bonus_hp + participant.resonance_bonus_hp
	
	print("  変身後AP/HP: ", participant.current_ap, "/", participant.current_hp)
	
	# 結果を記録
	if is_attacker:
		result["attacker_transformed"] = true
		if not original_data.is_empty():
			result["attacker_original"] = original_data
	else:
		result["defender_transformed"] = true
		if not original_data.is_empty():
			result["defender_original"] = original_data

## ランダムなクリーチャーIDを取得
##
## @param card_loader: CardLoaderのインスタンス
## @return ランダムに選ばれたクリーチャーのID
static func _get_random_creature_id(card_loader) -> int:
	# 全クリーチャーを取得
	var all_creatures = card_loader.get_all_creatures()
	
	if all_creatures.is_empty():
		print("[警告] クリーチャーリストが空です")
		return -1
	
	# ランダムに1体選択
	var random_index = randi() % all_creatures.size()
	var selected_creature = all_creatures[random_index]
	
	return selected_creature.get("id", -1)

## 種族でフィルタしてランダムなクリーチャーIDを取得
##
## @param card_loader: CardLoaderのインスタンス
## @param race: 種族名（例: "オーガ", "ゴブリン"）
## @return ランダムに選ばれたクリーチャーのID
static func _get_random_creature_by_race(card_loader, race: String) -> int:
	if card_loader == null:
		print("[警告] card_loaderがnullです")
		return -1
	
	var all_creatures = card_loader.get_all_creatures()
	
	if all_creatures.is_empty():
		print("[警告] クリーチャーリストが空です")
		return -1
	
	# 指定種族のクリーチャーをフィルタ
	var filtered_creatures = []
	for creature in all_creatures:
		if creature.get("race", "") == race:
			filtered_creatures.append(creature)
	
	if filtered_creatures.is_empty():
		print("[警告] 種族「", race, "」のクリーチャーが見つかりません")
		return -1
	
	# ランダムに1体選択
	var random_index = randi() % filtered_creatures.size()
	var selected_creature = filtered_creatures[random_index]
	
	print("  → 種族「", race, "」から", filtered_creatures.size(), "体中、", selected_creature.get("name", "?"), "を選択")
	
	return selected_creature.get("id", -1)

## 名前パターンでフィルタしてランダムなクリーチャーIDを取得
##
## @param card_loader: CardLoaderのインスタンス
## @param name_pattern: 名前に含むべき文字列（例: "ドラゴン"）
## @return ランダムに選ばれたクリーチャーのID
static func _get_random_creature_by_name_pattern(card_loader, name_pattern: String) -> int:
	if card_loader == null:
		print("[警告] card_loaderがnullです")
		return -1
	
	var all_creatures = card_loader.get_all_creatures()
	
	if all_creatures.is_empty():
		print("[警告] クリーチャーリストが空です")
		return -1
	
	# 名前にパターンを含むクリーチャーをフィルタ
	var filtered_creatures = []
	for creature in all_creatures:
		var name = creature.get("name", "")
		if name_pattern in name:
			filtered_creatures.append(creature)
	
	if filtered_creatures.is_empty():
		print("[警告] 名前に「", name_pattern, "」を含むクリーチャーが見つかりません")
		return -1
	
	# ランダムに1体選択
	var random_index = randi() % filtered_creatures.size()
	var selected_creature = filtered_creatures[random_index]
	
	print("  → 名前に「", name_pattern, "」を含む", filtered_creatures.size(), "体中、", selected_creature.get("name", "?"), "を選択")
	
	return selected_creature.get("id", -1)
