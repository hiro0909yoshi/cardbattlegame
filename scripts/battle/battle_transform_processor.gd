class_name BattleTransformProcessor

# 変身処理を担当するクラス
# 戦闘開始時、攻撃成功時などのタイミングで変身を実行

static func process_transform_effects(attacker: BattleParticipant, defender: BattleParticipant, card_loader, trigger: String) -> Dictionary:
	"""
	変身効果を処理
	
	Args:
		attacker: 攻撃側参加者
		defender: 防御側参加者
		card_loader: CardLoaderのインスタンス（クリーチャーデータ取得用）
		trigger: 発動タイミング（"on_battle_start", "on_attack_success"など）
	
	Returns:
		{
			"attacker_transformed": bool,
			"defender_transformed": bool,
			"attacker_original": Dictionary (元のcreature_data、戻す必要がある場合のみ),
			"defender_original": Dictionary
		}
	"""
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
			_apply_transform(attacker, attacker_transform, card_loader, result, true)
		elif target == "opponent":
			# 相手を変身させる
			_apply_transform(defender, attacker_transform, card_loader, result, false)
	
	# 防御側の変身効果チェック
	var defender_transform = _check_transform(defender, trigger)
	if defender_transform:
		var target = defender_transform.get("target", "self")
		if target == "self":
			# 自分自身が変身
			_apply_transform(defender, defender_transform, card_loader, result, false)
		elif target == "opponent":
			# 相手を変身させる
			_apply_transform(attacker, defender_transform, card_loader, result, true)
	
	return result

static func revert_transform(participant: BattleParticipant, original_data: Dictionary) -> void:
	"""
	変身を元に戻す（ハルゲンダース専用）
	
	Args:
		participant: 参加者
		original_data: 元のcreature_data
	"""
	if original_data.is_empty():
		return
	
	print("[変身解除] ", participant.creature_data.get("name", "?"), " → ", original_data.get("name", "?"))
	
	# creature_dataを完全に元に戻す
	participant.creature_data = original_data.duplicate(true)

static func _check_transform(participant: BattleParticipant, trigger: String):
	"""
	変身効果があるかチェック
	
	Returns:
		変身効果のDictionary、なければnull
	"""
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "transform" and effect.get("trigger") == trigger:
			return effect
	
	return null

static func _apply_transform(participant: BattleParticipant, transform_effect: Dictionary, card_loader, result: Dictionary, is_attacker: bool) -> void:
	"""
	変身を適用
	"""
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
	
	# 新しいクリーチャーデータを取得
	if new_creature_id > 0:
		var new_creature = card_loader.get_card_by_id(new_creature_id)
		if new_creature:
			_transform_creature(participant, new_creature, is_attacker, result, original_data)

static func _transform_creature(participant: BattleParticipant, new_creature: Dictionary, is_attacker: bool, result: Dictionary, original_data: Dictionary) -> void:
	"""
	実際にクリーチャーを変身させる
	"""
	var old_name = participant.creature_data.get("name", "?")
	var new_name = new_creature.get("name", "?")
	
	print("【変身実行】", old_name, " → ", new_name)
	print("  元のAP/HP: ", participant.current_ap, "/", participant.current_hp)
	
	# 重要: 現在のバフ（アイテム効果など）を記録
	var current_ap = participant.current_ap
	var current_item_bonus_hp = participant.item_bonus_hp
	var current_items = participant.creature_data.get("items", [])
	
	# creature_dataを新しいクリーチャーに置き換え
	participant.creature_data = new_creature.duplicate(true)
	
	# アイテム情報を引き継ぐ
	if not current_items.is_empty():
		participant.creature_data["items"] = current_items
	
	# 基礎ステータスを新しいクリーチャーのものに更新
	participant.base_hp = new_creature.get("hp", 0)
	
	# APは新しいクリーチャーのベース値を使用（バフは考慮しない）
	participant.current_ap = new_creature.get("ap", 0)
	
	# HPバフを再適用
	participant.item_bonus_hp = current_item_bonus_hp
	
	# HPを再計算（土地ボーナスとアイテムボーナスを含む）
	participant.update_current_hp()
	
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

static func _get_random_creature_id(card_loader) -> int:
	"""
	ランダムなクリーチャーIDを取得
	
	Args:
		card_loader: CardLoaderのインスタンス
	
	Returns:
		ランダムに選ばれたクリーチャーのID
	"""
	# 全クリーチャーを取得
	var all_creatures = card_loader.get_all_creatures()
	
	if all_creatures.is_empty():
		print("[警告] クリーチャーリストが空です")
		return -1
	
	# ランダムに1体選択
	var random_index = randi() % all_creatures.size()
	var selected_creature = all_creatures[random_index]
	
	return selected_creature.get("id", -1)

# ========================================
# 死者復活スキル処理
# ========================================

static func check_and_apply_revive(participant: BattleParticipant, opponent: BattleParticipant, card_loader) -> Dictionary:
	"""
	死者復活スキルをチェックして適用
	
	Args:
		participant: 撃破されたクリーチャー
		opponent: 攻撃したクリーチャー（条件チェック用）
		card_loader: CardLoaderのインスタンス
	
	Returns:
		{
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
	
	# 死者復活効果をチェック
	var revive_effect = _check_revive(participant)
	if not revive_effect:
		return result
	
	print("[死者復活チェック] ", participant.creature_data.get("name", "?"))
	
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
		_apply_revive(participant, new_creature, result)
	else:
		print("[死者復活] クリーチャーが見つかりません: ID ", new_creature_id)
	
	return result

static func _check_revive(participant: BattleParticipant):
	"""
	死者復活効果があるかチェック
	
	Returns:
		死者復活効果のDictionary、なければnull
	"""
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "revive" and effect.get("trigger") == "on_death":
			return effect
	
	return null

static func _check_revive_condition(revive_effect: Dictionary, opponent: BattleParticipant) -> bool:
	"""
	復活条件をチェック
	
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

static func _opponent_used_item_category(opponent: BattleParticipant, category: String) -> bool:
	"""
	相手が特定カテゴリのアイテムを使用しているかチェック
	
	Args:
		opponent: 相手のクリーチャー
		category: アイテムカテゴリ（"武器"、"防具"など）
	
	Returns:
		使用していればtrue
	"""
	var items = opponent.creature_data.get("items", [])
	for item in items:
		var item_category = item.get("item_type", "")
		if item_category == category:
			return true
	return false

static func _apply_revive(participant: BattleParticipant, new_creature: Dictionary, result: Dictionary) -> void:
	"""
	死者復活を適用（変身処理を流用）
	
	Args:
		participant: 復活するクリーチャー
		new_creature: 復活先のクリーチャーデータ
		result: 結果を格納するDictionary
	"""
	var old_name = participant.creature_data.get("name", "?")
	var new_name = new_creature.get("name", "?")
	
	print("【死者復活】", old_name, " → ", new_name)
	
	# 現在のアイテムボーナスを記録
	var current_item_bonus_hp = participant.item_bonus_hp
	var current_items = participant.creature_data.get("items", [])
	
	# creature_dataを新しいクリーチャーに置き換え
	participant.creature_data = new_creature.duplicate(true)
	
	# アイテム情報を引き継ぐ
	if not current_items.is_empty():
		participant.creature_data["items"] = current_items
	
	# 基礎ステータスを新しいクリーチャーのものに更新
	participant.base_hp = new_creature.get("hp", 0)
	participant.current_ap = new_creature.get("ap", 0)
	
	# HPバフを再適用
	participant.item_bonus_hp = current_item_bonus_hp
	
	# HPを全回復（最大HPで復活）
	participant.update_current_hp()
	
	print("  復活後AP/HP: ", participant.current_ap, "/", participant.current_hp)
	
	# 結果を記録
	result["revived"] = true
	result["new_creature_id"] = new_creature.get("id", -1)
	result["new_creature_name"] = new_name
