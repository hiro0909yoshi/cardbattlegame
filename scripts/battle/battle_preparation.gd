extends Node
class_name BattlePreparation

# バトル準備フェーズ処理（オーケストレーター）
# BattleParticipantの作成と各処理の委譲を担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")
const PenetrationSkill = preload("res://scripts/battle/skills/skill_penetration.gd")
const SkillSpecialCreatureScript = preload("res://scripts/battle/skills/skill_special_creature.gd")
const BattleCurseApplierScript = preload("res://scripts/battle/battle_curse_applier.gd")
const BattleItemApplierScript = preload("res://scripts/battle/battle_item_applier.gd")
const BattleSkillGranterScript = preload("res://scripts/battle/battle_skill_granter.gd")

# サブシステム（分割後）
var curse_applier = BattleCurseApplierScript.new()
var item_applier = BattleItemApplierScript.new()
var skill_granter = BattleSkillGranterScript.new()

# システム参照
var board_system_ref = null
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var spell_magic_ref = null  # SpellMagicの参照（EP獲得系アイテム用）

func setup_systems(board_system, card_system: CardSystem, player_system: PlayerSystem, spell_magic = null):
	board_system_ref = board_system
	card_system_ref = card_system
	player_system_ref = player_system
	spell_magic_ref = spell_magic
	
	# サブシステムにsystem参照を設定
	item_applier.setup_systems(board_system, card_system, spell_magic)

## 両者のBattleParticipantを準備
func prepare_participants(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}, _battle_tile_index: int = -1) -> Dictionary:
	# 侵略側の準備（土地ボーナスなし）
	var attacker_base_hp = card_data.get("hp", 0)
	var attacker_land_bonus = 0  # 侵略側は土地ボーナスなし
	var attacker_ap = card_data.get("ap", 0)
	
	var attacker = BattleParticipant.new(
		card_data,
		attacker_base_hp,
		attacker_land_bonus,
		attacker_ap,
		true,  # is_attacker
		attacker_index
	)
	
	# SpellMagic参照を設定
	attacker.spell_magic_ref = spell_magic_ref
	
	# base_up_hpを設定（手札から出す場合はないはずだが、移動侵略の場合はある）
	attacker.base_up_hp = card_data.get("base_up_hp", 0)
	attacker.base_up_ap = card_data.get("base_up_ap", 0)
	print("[battle_preparation] 攻撃側の初期永続バフ:")
	print("  base_up_hp: ", attacker.base_up_hp)
	print("  base_up_ap: ", attacker.base_up_ap)
	
	# 現在HPから復元（手札から出す場合は満タン、移動侵略の場合はダメージ後の値）
	var attacker_max_hp = card_data.get("hp", 0) + attacker.base_up_hp
	var attacker_current_hp = card_data.get("current_hp", attacker_max_hp)
	
	# current_hp を直接設定
	attacker.current_hp = attacker_current_hp
	# base_hp と base_up_hp はコンストラクタで既に設定済み
	
	# 防御側の準備（土地ボーナスあり）
	var defender_creature = tile_info.get("creature", {})
	print("\n【防御側クリーチャーデータ】", defender_creature)
	var defender_base_hp = defender_creature.get("hp", 0)
	var defender_land_bonus = calculate_land_bonus(defender_creature, tile_info)  # 防御側のみボーナス
	
	# 貫通スキルチェックはapply_pre_battle_skills()で実行（クリック後）
	
	var defender_ap = defender_creature.get("ap", 0)
	var defender_owner = tile_info.get("owner", -1)
	
	var defender = BattleParticipant.new(
		defender_creature,
		defender_base_hp,
		defender_land_bonus,
		defender_ap,
		false,  # is_attacker
		defender_owner
	)
	
	# SpellMagic参照を設定
	defender.spell_magic_ref = spell_magic_ref
	
	# base_up_hpとbase_up_apを設定
	defender.base_up_hp = defender_creature.get("base_up_hp", 0)
	defender.base_up_ap = defender_creature.get("base_up_ap", 0)
	print("[battle_preparation] 防御側の初期永続バフ:")
	print("  base_up_hp: ", defender.base_up_hp)
	print("  base_up_ap: ", defender.base_up_ap)
	
	# 現在HPから復元（ない場合は満タン）
	# current_hp は土地ボーナスを含まない値として保存
	var defender_base_only_hp = defender_creature.get("hp", 0)  # 基本HPのみ
	var defender_max_hp = defender_base_only_hp + defender.base_up_hp  # MHP計算（土地ボーナス含まず）
	var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)
	
	# current_hp を直接設定（土地ボーナスは別途 land_bonus_hp として管理）
	defender.current_hp = defender_current_hp
	# base_hp と base_up_hp はコンストラクタで既に設定済み
	
	# 効果配列を適用
	apply_effect_arrays(attacker, card_data)
	apply_effect_arrays(defender, defender_creature)
	
	# 呪い適用はapply_pre_battle_skills()で実行（バトル画面セットアップ後）
	
	# アイテムをitemsに追加（効果適用はアイテム破壊判定後に行う）
	# 注意: 前回のバトルのアイテムが残っている可能性があるため、まずクリア
	attacker.creature_data["items"] = []
	defender.creature_data["items"] = []
	
	if not attacker_item.is_empty():
		attacker.creature_data["items"].append(attacker_item)
	
	if not defender_item.is_empty():
		defender.creature_data["items"].append(defender_item)
	
	# 以下の処理はapply_pre_battle_skills()で実行（クリック後）:
	# - クリーチャー能力のAPドレイン
	# - ブルガサリボーナス
	# - ランダムステータス（スペクター）
	# - 変身効果
	# - 戦闘開始時条件
	
	return {
		"attacker": attacker,
		"defender": defender,
		"attacker_used_item": not attacker_item.is_empty(),
		"defender_used_item": not defender_item.is_empty()
	}

## 効果配列（permanent_effects, temporary_effects）を適用
func apply_effect_arrays(participant: BattleParticipant, creature_data: Dictionary) -> void:
	# base_up_hp/apの設定は削除（既にprepare_participantsで設定済み）
	# 防御側：94-99行目で設定
	# 攻撃側：51-56行目で設定
	
	# 効果配列を保持（打ち消し効果判定用）
	participant.permanent_effects = creature_data.get("permanent_effects", [])
	participant.temporary_effects = creature_data.get("temporary_effects", [])
	
	# permanent_effectsから効果を計算
	for effect in participant.permanent_effects:
		if effect.get("type") == "stat_bonus":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			if stat == "hp":
				participant.temporary_bonus_hp += value
			elif stat == "ap":
				participant.temporary_bonus_ap += value
	
	# temporary_effectsから効果を計算
	for effect in participant.temporary_effects:
		if effect.get("type") == "stat_bonus":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			if stat == "hp":
				participant.temporary_bonus_hp += value
			elif stat == "ap":
				participant.temporary_bonus_ap += value
	
	# base_up_apをcurrent_apに反映
	participant.current_ap += participant.base_up_ap + participant.temporary_bonus_ap
	
	# HPを更新（新方式：ボーナス合計を current_hp に直接反映）
	# base_hp + base_up_hp は MHP計算用の定数
	# ボーナスは各フィールドに既に記録されているため、current_hp は自動的に正しい値になる
	# update_current_hp() は呼ばない（current_hp が状態値になったため）
	
	if participant.base_up_hp > 0 or participant.base_up_ap > 0:
		print("[効果] ", creature_data.get("name", "?"), 
			  " base_up_hp:", participant.base_up_hp, 
			  " base_up_ap:", participant.base_up_ap)
	if participant.temporary_bonus_hp > 0 or participant.temporary_bonus_ap > 0:
		print("[効果] ", creature_data.get("name", "?"), 
			  " temporary_bonus_hp:", participant.temporary_bonus_hp, 
			  " temporary_bonus_ap:", participant.temporary_bonus_ap)


## 土地ボーナスを計算
func calculate_land_bonus(creature_data: Dictionary, tile_info: Dictionary) -> int:
	var creature_element = creature_data.get("element", "")
	# tile_info では "element" キーに属性文字列が格納されている
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	print("【土地ボーナス計算】クリーチャー:", creature_data.get("name", "?"), " 属性:", creature_element)
	print("  タイル属性:", tile_element, " レベル:", tile_level)
	
	# SpellCurseBattleの統合判定を使用（通常属性一致 + 追加属性 + 呪い効果）
	if SpellCurseBattle.can_get_land_bonus(creature_data, tile_element):
		var bonus = tile_level * 10
		print("  → 地形効果発動！ボーナス:", bonus)
		return bonus
	
	print("  → 地形効果なし")
	return 0

## 変身効果を持っているかチェック
func _has_transform_effect(participant: BattleParticipant, trigger: String) -> bool:
	if not participant or not participant.creature_data:
		return false
	
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "transform" and effect.get("trigger") == trigger:
			return true
	
	return false


## 戦闘開始時条件をチェック・適用
func _apply_battle_start_conditions(attacker: BattleParticipant, defender: BattleParticipant) -> Dictionary:
	var result = {
		"attacker": {},
		"defender": {}
	}
	
	# 攻撃側の戦闘開始時条件
	var attacker_context = {
		"creature_data": attacker.creature_data
	}
	result["attacker"] = SkillBattleStartConditions.apply(attacker, attacker_context)
	
	# 防御側の戦闘開始時条件
	var defender_context = {
		"creature_data": defender.creature_data
	}
	result["defender"] = SkillBattleStartConditions.apply(defender, defender_context)
	
	return result

# APドレイン（クリーチャー能力）は攻撃成功時効果のためbattle_execution.gdで処理


## アイテム効果を適用（アイテム破壊・盗み後に呼び出す）
## @param attacker 攻撃側
## @param defender 防御側
## @param battle_tile_index 戦闘タイルインデックス
## @param stat_bonus_only trueの場合、ステータスボーナスのみ適用
## @param skip_stat_bonus trueの場合、ステータスボーナスをスキップ（スキル効果のみ適用）
func apply_remaining_item_effects(attacker: BattleParticipant, defender: BattleParticipant, battle_tile_index: int, stat_bonus_only: bool = false, skip_stat_bonus: bool = false) -> void:
	# 攻撃側のアイテム効果を適用
	var attacker_items = attacker.creature_data.get("items", [])
	if not attacker_items.is_empty():
		var item = attacker_items[0]
		var mode_str = ""
		if stat_bonus_only:
			mode_str = "（ステータスのみ）"
		elif skip_stat_bonus:
			mode_str = "（スキルのみ）"
		else:
			mode_str = "（破壊後）"
		print("[アイテム効果適用%s] " % mode_str, attacker.creature_data.get("name", "?"), " → ", item.get("name", "?"))
		item_applier.apply_item_effects(attacker, item, defender, battle_tile_index, stat_bonus_only, skip_stat_bonus)
	
	# 防御側のアイテム効果を適用
	var defender_items = defender.creature_data.get("items", [])
	if not defender_items.is_empty():
		var item = defender_items[0]
		var mode_str = ""
		if stat_bonus_only:
			mode_str = "（ステータスのみ）"
		elif skip_stat_bonus:
			mode_str = "（スキルのみ）"
		else:
			mode_str = "（破壊後）"
		print("[アイテム効果適用%s] " % mode_str, defender.creature_data.get("name", "?"), " → ", item.get("name", "?"))
		item_applier.apply_item_effects(defender, item, attacker, battle_tile_index, stat_bonus_only, skip_stat_bonus)
