class_name SkillTransform

## 変身スキル処理モジュール
##
## クリーチャーの変身（ランダム変身、強制変身）の処理を行う
## 
## 注: 蘇生はbattle_special_effects.gdのcheck_on_death_effects()に移動済み
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
## @param board_system: BoardSystem3Dの参照（土地ボーナス再計算用、省略可）
## @param battle_tile_index: 戦闘タイルのインデックス（土地ボーナス再計算用、省略可）
## @return Dictionary {
##   "attacker_transformed": bool,
##   "defender_transformed": bool,
##   "attacker_original": Dictionary (元のcreature_data、戻す必要がある場合のみ),
##   "defender_original": Dictionary
## }
static func process_transform_effects(attacker: BattleParticipant, defender: BattleParticipant, card_loader, trigger: String, board_system = null, battle_tile_index: int = -1) -> Dictionary:
	var result = {
		"attacker_transformed": false,
		"defender_transformed": false,
		"attacker_original": {},
		"defender_original": {},
		"needs_attacker_skill_recalc": false  # ツインスパイク用: 侵略側のスキル再計算が必要
	}
	
	# 攻撃側の変身効果チェック
	var attacker_transform = _check_transform(attacker, trigger)
	if attacker_transform:
		var target = attacker_transform.get("target", "self")
		var transform_type = attacker_transform.get("transform_type", "")
		if target == "self":
			# 自分自身が変身
			_apply_transform(attacker, attacker_transform, card_loader, result, true, defender, board_system, battle_tile_index)
		elif target == "opponent":
			# 相手を変身させる
			_apply_transform(defender, attacker_transform, card_loader, result, false, attacker, board_system, battle_tile_index)
			# ツインスパイク：相手を自分のコピーに変身させた場合
			# 変身した防御側のスキルを再計算する必要がある
			if transform_type == "forced_copy_attacker" and result.get("defender_transformed", false):
				result["needs_attacker_skill_recalc"] = true
				print("[ツインスパイク] 侵略側のスキル再計算が必要")
	
	# 防御側の変身効果チェック
	# ただし「on_attack_success」トリガーの場合、defenderは攻撃していないのでスキップ
	if trigger != "on_attack_success":
		var defender_transform = _check_transform(defender, trigger)
		if defender_transform:
			var target = defender_transform.get("target", "self")
			if target == "self":
				# 自分自身が変身
				_apply_transform(defender, defender_transform, card_loader, result, false, attacker, board_system, battle_tile_index)
			elif target == "opponent":
				# 相手を変身させる
				_apply_transform(attacker, defender_transform, card_loader, result, true, defender, board_system, battle_tile_index)
	
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
	
	# base_hpを元のクリーチャーの値に戻す
	participant.base_hp = original_data.get("hp", 0)
	
	# 元のクリーチャーのmax_hpを計算（base_hp + base_up_hp）
	var original_base_up_hp = original_data.get("base_up_hp", 0)
	var original_max_hp = participant.base_hp + original_base_up_hp
	
	# current_hpが元のmax_hpを超えていたら制限
	if participant.current_hp > original_max_hp:
		print("  current_hp制限: ", participant.current_hp, " → ", original_max_hp)
		participant.current_hp = original_max_hp

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
static func _apply_transform(participant: BattleParticipant, transform_effect: Dictionary, card_loader, result: Dictionary, is_attacker: bool, opponent: BattleParticipant = null, board_system = null, battle_tile_index: int = -1) -> void:
	var transform_type = transform_effect.get("transform_type", "")
	var revert_after_battle = transform_effect.get("revert_after_battle", false)
	
	# 元のデータを保存（戦闘後に戻す必要がある場合）
	var original_data = {}
	if revert_after_battle:
		original_data = participant.creature_data.duplicate(true)
	else:
		# revert_after_battle: false の変身（変質、ツインスパイク等）が起きた場合、
		# 以前のランダム変身で設定されたoriginal_dataをクリア（元に戻らないように）
		var key = "attacker_original" if is_attacker else "defender_original"
		if result.has(key) and not result[key].is_empty():
			result[key] = {}
	
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
			_transform_creature(participant, new_creature, is_attacker, result, original_data, board_system, battle_tile_index)

## 実際にクリーチャーを変身させる
static func _transform_creature(participant: BattleParticipant, new_creature: Dictionary, is_attacker: bool, result: Dictionary, original_data: Dictionary, board_system = null, battle_tile_index: int = -1) -> void:
	var old_name = participant.creature_data.get("name", "?")
	var new_name = new_creature.get("name", "?")
	
	print("【変身実行】", old_name, " → ", new_name)
	
	# 現在のバフ（アイテム効果など）と永続ボーナスを記録
	var current_item_bonus_hp = participant.item_bonus_hp
	var current_items = participant.creature_data.get("items", [])
	var current_base_up_hp = participant.base_up_hp
	
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
	
	# 土地ボーナスを再計算（防御側のみ、攻撃側は土地ボーナスなし）
	if not participant.is_attacker and board_system and battle_tile_index >= 0:
		_recalculate_land_bonus(participant, board_system, battle_tile_index)
	
	# HPを設定（current_hpはボーナスを含まない基礎HP）
	# 表示時にボーナスが足される
	participant.current_hp = participant.base_hp + participant.base_up_hp
	
	# 結果を記録
	if is_attacker:
		result["attacker_transformed"] = true
		if not original_data.is_empty():
			result["attacker_original"] = original_data
	else:
		result["defender_transformed"] = true
		if not original_data.is_empty():
			result["defender_original"] = original_data


## 土地ボーナスを再計算（変身後用）
static func _recalculate_land_bonus(participant: BattleParticipant, board_system, battle_tile_index: int) -> void:
	var tile = board_system.get_tile_info(battle_tile_index)
	if tile.is_empty():
		return
	
	var creature_element = participant.creature_data.get("element", "")
	var tile_element = tile.get("element", "neutral")
	var tile_level = tile.get("level", 1)
	var new_land_bonus = 0
	
	# 属性一致チェック（neutral属性は全ての属性と一致）
	if tile_element == "neutral" or creature_element == tile_element:
		new_land_bonus = tile_level * 10
	
	participant.land_bonus_hp = new_land_bonus

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
	
	return selected_creature.get("id", -1)
