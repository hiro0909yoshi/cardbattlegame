extends Node
class_name BattlePreparation

# バトル準備フェーズ処理（オーケストレーター）
# BattleParticipantの作成と各処理の委譲を担当

# 定数をpreload
const GameConstants = preload("res://scripts/game_constants.gd")
const TransformSkill = preload("res://scripts/battle/skills/skill_transform.gd")
const PenetrationSkill = preload("res://scripts/battle/skills/skill_penetration.gd")
const SkillSpecialCreatureScript = preload("res://scripts/battle/skills/skill_special_creature.gd")
const BattleCurseApplier = preload("res://scripts/battle/battle_curse_applier.gd")
const BattleItemApplier = preload("res://scripts/battle/battle_item_applier.gd")
const BattleSkillGranter = preload("res://scripts/battle/battle_skill_granter.gd")

# サブシステム（分割後）
var curse_applier = BattleCurseApplier.new()
var item_applier = BattleItemApplier.new()
var skill_granter = BattleSkillGranter.new()

# システム参照
var board_system_ref = null
var card_system_ref: CardSystem = null
var player_system_ref: PlayerSystem = null
var spell_magic_ref = null  # SpellMagicの参照（魔力獲得系アイテム用）

func setup_systems(board_system, card_system: CardSystem, player_system: PlayerSystem, spell_magic = null):
	board_system_ref = board_system
	card_system_ref = card_system
	player_system_ref = player_system
	spell_magic_ref = spell_magic
	
	# サブシステムにsystem参照を設定
	item_applier.setup_systems(board_system, card_system, spell_magic)

## 両者のBattleParticipantを準備
func prepare_participants(attacker_index: int, card_data: Dictionary, tile_info: Dictionary, attacker_item: Dictionary = {}, defender_item: Dictionary = {}, battle_tile_index: int = -1) -> Dictionary:
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
	
	# 貫通スキルチェック：攻撃側が貫通を持つ場合、防御側の土地ボーナスを無効化
	if PenetrationSkill.check_penetration_condition(card_data, defender_creature):
		print("【貫通発動】防御側の土地ボーナス ", defender_land_bonus, " を無効化")
		defender_land_bonus = 0
	
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
	# 現在HPから復元（ない場合は満タン）
	var defender_base_only_hp = defender_creature.get("hp", 0)  # 基本HPのみ
	var defender_max_hp = defender_base_only_hp + defender.base_up_hp  # MHP計算
	var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)
	
	# current_hp を直接設定（新方式）
	defender.current_hp = defender_current_hp
	# base_hp と base_up_hp はコンストラクタで既に設定済み
	
	# 効果配列を適用
	apply_effect_arrays(attacker, card_data)
	apply_effect_arrays(defender, defender_creature)
	
	# 呪いをtemporary_effectsに変換して適用
	# battle_tile_indexは防御側のクリーチャーがいるタイル
	# attacker（侵略側）の呪いは card_data に含まれているはず
	# 手札から出すクリーチャーなので、移動侵略でない限り呪いはない
	curse_applier.apply_creature_curses(defender, battle_tile_index)
	
	# アイテム効果を適用
	if not attacker_item.is_empty():
		# アイテムデータをクリーチャーのitemsに追加（反射チェックで使用）
		if not attacker.creature_data.has("items"):
			attacker.creature_data["items"] = []
		attacker.creature_data["items"].append(attacker_item)
		item_applier.apply_item_effects(attacker, attacker_item, defender, battle_tile_index)
	
	if not defender_item.is_empty():
		# アイテムデータをクリーチャーのitemsに追加（反射チェックで使用）
		if not defender.creature_data.has("items"):
			defender.creature_data["items"] = []
		defender.creature_data["items"].append(defender_item)
		item_applier.apply_item_effects(defender, defender_item, attacker, battle_tile_index)
	
	# アイテムクリーチャー・バフ処理
	# リビングアーマー（ID: 438）: クリーチャーとして戦闘時AP+50
	var attacker_id = attacker.creature_data.get("id", -1)
	var defender_id = defender.creature_data.get("id", -1)
	
	if attacker_id == 438:
		attacker.temporary_bonus_ap += 50
		print("[リビングアーマー] クリーチャーとして戦闘 AP+50")
	
	if defender_id == 438:
		defender.temporary_bonus_ap += 50
		print("[リビングアーマー] クリーチャーとして戦闘 AP+50")
	
	# ブルガサリ（ID: 339）: アイテム使用時AP+20
	if attacker_id == 339:
		if not attacker_item.is_empty():
			attacker.temporary_bonus_ap += 20
			print("[ブルガサリ] 自分がアイテム使用 AP+20")
		if not defender_item.is_empty():
			# 敵がアイテムを使用したフラグを設定（永続バフは後で）
			attacker.enemy_used_item = true
	
	if defender_id == 339:
		if not defender_item.is_empty():
			defender.temporary_bonus_ap += 20
			print("[ブルガサリ] 自分がアイテム使用 AP+20")
		if not attacker_item.is_empty():
			# 敵がアイテムを使用したフラグを設定（永続バフは後で）
			defender.enemy_used_item = true
	
	# オーガロード（ID: 407）: オーガ配置時能力値上昇
	if attacker_id == 407:
		SkillSpecialCreatureScript.apply_ogre_lord_bonus(attacker, attacker_index, board_system_ref)
	
	if defender_id == 407:
		SkillSpecialCreatureScript.apply_ogre_lord_bonus(defender, defender_owner, board_system_ref)
	
	# アイテムクリーチャー効果適用後、current_apを再計算
	if attacker_id == 438 or attacker_id == 339 or attacker_id == 407:
		attacker.current_ap = attacker.creature_data.get("ap", 0) + attacker.base_up_ap + attacker.temporary_bonus_ap + attacker.item_bonus_ap
	if defender_id == 438 or defender_id == 339 or defender_id == 407:
		defender.current_ap = defender.creature_data.get("ap", 0) + defender.base_up_ap + defender.temporary_bonus_ap + defender.item_bonus_ap
	
	# ランダムステータス効果を適用（スペクター用）
	SkillSpecialCreatureScript.apply_random_stat_effects(attacker)
	SkillSpecialCreatureScript.apply_random_stat_effects(defender)
	
	# 🔄 戦闘開始時の変身処理（アイテム効果適用後）
	var transform_result = {}
	
	# 変身効果があるかチェック
	var has_transform_effect = _has_transform_effect(attacker, "on_battle_start") or _has_transform_effect(defender, "on_battle_start")
	
	if has_transform_effect and card_system_ref:
		# CardLoaderのグローバル参照を取得
		# @GlobalScope.CardLoader は Autoload として自動的に利用可能
		var card_loader_instance = CardLoader if typeof(CardLoader) != TYPE_NIL else null
		
		if card_loader_instance != null and card_loader_instance.has_method("get_all_creatures"):
			print("【変身】CardLoader取得成功、全カード数: ", card_loader_instance.all_cards.size())
			transform_result = TransformSkill.process_transform_effects(
				attacker, 
				defender, 
				card_loader_instance, 
				"on_battle_start"
			)
		else:
			print("【警告】CardLoaderが利用できません - 変身処理をスキップ")
	
	# 🚫 ウォーロックディスク: apply_pre_battle_skills()の最初で処理するため、ここでは削除
	
	return {
		"attacker": attacker,
		"defender": defender,
		"transform_result": transform_result
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
	var tile_element = tile_info.get("element", "")
	var tile_level = tile_info.get("level", 1)
	
	print("【土地ボーナス計算】クリーチャー:", creature_data.get("name", "?"), " 属性:", creature_element)
	print("  タイル属性:", tile_element, " レベル:", tile_level)
	
	if creature_element == tile_element and creature_element in ["fire", "water", "wind", "earth"]:
		var bonus = tile_level * 10
		print("  → 属性一致！ボーナス:", bonus)
		return bonus
	
	print("  → 属性不一致、ボーナスなし")
	return 0

# バトル準備の完了を通知
func battle_preparation_completed():
	pass  # 必要に応じて処理を追加

# バトル終了後の処理
func process_battle_end(_attacker: BattleParticipant, _defender: BattleParticipant) -> void:
	pass  # 必要に応じて処理を追加

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
