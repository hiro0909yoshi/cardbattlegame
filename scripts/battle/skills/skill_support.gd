## 応援スキル (Support Skill)
##
## 盤面に配置されているクリーチャーが、バトル参加者（侵略側・防御側）に対してバフを与えるパッシブスキル
##
## 【主な機能】
## - 属性条件による応援（火属性クリーチャーに+10など）
## - バトルロール条件（攻撃側/防御側のみ）
## - 種族条件（ゴブリン種族のみなど）
## - 所有者一致条件（自分のクリーチャーのみ）
## - 動的ボーナス（隣接自領地数に応じて変動）
##
## 【実装済みクリーチャー】
## - Boges (ID: 401) - 火属性クリーチャーにST+10
## - Grimalkin (ID: 404) - 風属性クリーチャーにST+10
## - Salamander (ID: 421) - 攻撃側にST+10
## - Naiad (ID: 424) - 防御側にHP+10
## - Phantom Warrior (ID: 431) - 地属性クリーチャーにST+10
## - Banshee (ID: 441) - 水属性クリーチャーにST+10
## - Mad Harlequin (ID: 444) - 自領地（動的、ST +N×10）
## - Red Cap (ID: 445) - ゴブリン種族にST+10、HP+10
##
## @version 1.0
## @date 2025-10-31

class_name SkillSupport

const ParticipantClass = preload("res://scripts/battle/battle_participant.gd")

## 応援スキルを全体に適用
##
## 盤面上の全ての応援持ちクリーチャーを取得し、
## バトル参加者（侵略側・防御側）に対して応援効果を適用する
##
## @param participants: バトル参加者の辞書 {"attacker": BattleParticipant, "defender": BattleParticipant}
## @param battle_tile_index: バトルが発生するタイルのインデックス
## @param board_system: BoardSystemへの参照
static func apply_to_all(participants: Dictionary, battle_tile_index: int, board_system) -> void:
	if board_system == null:
		return
	
	# 応援持ちクリーチャーを取得（Dictionaryから値の配列を取得）
	var support_dict = board_system.get_support_creatures()
	var support_creatures = support_dict.values()
	
	if support_creatures.is_empty():
		return
	
	print("【応援スキルチェック】応援持ちクリーチャー数: ", support_creatures.size())
	
	# バトル参加者（侵略側・防御側）に応援効果を適用
	var battle_participants = [participants["attacker"], participants["defender"]]
	
	for supporter_data in support_creatures:
		var supporter_creature = supporter_data["creature_data"]
		var supporter_player_id = supporter_data["player_id"]
		var ability_parsed = supporter_creature.get("ability_parsed", {})
		var effects = ability_parsed.get("effects", [])
		
		for effect in effects:
			if effect.get("effect_type") != "support":
				continue
			
			# 対象範囲とボーナスを取得
			var target = effect.get("target", {})
			var bonus = effect.get("bonus", {})
			
			# 各バトル参加者に対して応援効果をチェック
			for participant in battle_participants:
				if _check_support_target(participant, target, supporter_player_id):
					_apply_support_bonus(participant, bonus, supporter_creature.get("name", "?"), 
										battle_tile_index, participant.player_id, board_system)

## 応援対象判定
##
## バトル参加者が応援スキルの対象になるかを判定する
##
## @param participant: バトル参加者
## @param target: 対象条件の辞書
## @param supporter_player_id: 応援者のプレイヤーID
## @return bool: 対象になる場合はtrue
static func _check_support_target(participant: BattleParticipant, target: Dictionary, supporter_player_id: int) -> bool:
	var scope = target.get("scope", "")
	var conditions = target.get("conditions", [])
	
	# scope="all_creatures"なら全クリーチャーが対象
	if scope != "all_creatures":
		return false
	
	# 条件チェック
	for condition in conditions:
		var condition_type = condition.get("condition_type", "")
		
		# 属性条件
		if condition_type == "element":
			var required_elements = condition.get("elements", [])
			var creature_element = participant.creature_data.get("element", "")
			
			if not creature_element in required_elements:
				return false
		
		# バトル役割条件（侵略側/防御側）
		elif condition_type == "battle_role":
			var required_role = condition.get("role", "")
			
			# 侵略側判定
			if required_role == "attacker" and not participant.is_attacker:
				return false
			
			# 防御側判定
			elif required_role == "defender" and participant.is_attacker:
				return false
		
		# 名前条件（部分一致）
		elif condition_type == "name_contains":
			var name_pattern = condition.get("name_pattern", "")
			var creature_name = participant.creature_data.get("name", "")
			
			if not name_pattern in creature_name:
				return false
		
		# 種族条件
		elif condition_type == "race":
			var required_race = condition.get("race", "")
			var creature_race = participant.creature_data.get("race", "")
			
			if creature_race != required_race:
				return false
		
		# 所有者一致条件（自クリーチャー）
		elif condition_type == "owner_match":
			# 応援者と対象が同じプレイヤーIDか判定
			if participant.player_id != supporter_player_id:
				return false
	
	return true

## 応援ボーナス適用
##
## 対象のバトル参加者にAPとHPのボーナスを適用する
## 動的ボーナス（隣接自領地数に応じた加算）にも対応
##
## @param participant: バトル参加者
## @param bonus: ボーナス内容の辞書
## @param supporter_name: 応援者の名前（ログ用）
## @param battle_tile_index: バトルタイルのインデックス
## @param target_player_id: 対象プレイヤーのID
## @param board_system: BoardSystemへの参照
static func _apply_support_bonus(participant: BattleParticipant, bonus: Dictionary, supporter_name: String, 
								 battle_tile_index: int, target_player_id: int, board_system) -> void:
	var hp_bonus = bonus.get("hp", 0)
	var ap_bonus = bonus.get("ap", 0)
	
	# 隣接自領地数による動的ボーナス
	var ap_per_adjacent = bonus.get("ap_per_adjacent_land", 0)
	var hp_per_adjacent = bonus.get("hp_per_adjacent_land", 0)
	
	if ap_per_adjacent > 0 or hp_per_adjacent > 0:
		# 戦闘タイルの隣接自領地数を取得
		var adjacent_ally_count = _count_adjacent_ally_lands(battle_tile_index, target_player_id, board_system)
		ap_bonus += ap_per_adjacent * adjacent_ally_count
		hp_bonus += hp_per_adjacent * adjacent_ally_count
		print("  → 戦闘タイル", battle_tile_index, "の隣接自領地数: ", adjacent_ally_count)
	
	if hp_bonus == 0 and ap_bonus == 0:
		return
	
	print("【応援効果】", supporter_name, " → ", participant.creature_data.get("name", "?"))
	
	# HPボーナス適用
	if hp_bonus > 0:
		participant.temporary_bonus_hp += hp_bonus
		print("  HP+", hp_bonus, " → temporary_bonus_hp:", participant.temporary_bonus_hp)
	
	# APボーナス適用
	if ap_bonus > 0:
		var old_ap = participant.current_ap
		participant.current_ap += ap_bonus
		print("  AP: ", old_ap, " → ", participant.current_ap, " (+", ap_bonus, ")")

## 隣接自領地数を数える
##
## バトルタイルに隣接する自分の領地の数をカウントする
## Mad Harlequinなどの動的ボーナス計算に使用
##
## @param tile_index: 対象タイルのインデックス
## @param player_id: プレイヤーID
## @param board_system: BoardSystemへの参照
## @return int: 隣接する自領地の数
static func _count_adjacent_ally_lands(tile_index: int, player_id: int, board_system) -> int:
	if board_system == null or tile_index < 0:
		return 0
	
	var neighbors = board_system.tile_neighbor_system.get_spatial_neighbors(tile_index)
	var ally_count = 0
	
	for neighbor_index in neighbors:
		# TileDataManagerから正しくタイル情報を取得
		var tile_info = board_system.tile_data_manager.get_tile_info(neighbor_index)
		if tile_info and tile_info.get("owner", -1) == player_id:
			ally_count += 1
	
	return ally_count
