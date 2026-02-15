# SpellSubsystemContainer - スペルサブシステムの参照を一元管理
class_name SpellSubsystemContainer
extends RefCounted

## スペルサブシステムの参照を集約するコンテナ
##
## 責務:
## - 11個のSpell**** クラスの参照を一元管理
## - SpellPhaseHandler の参照変数を削減（26個 → 5個に集約）
## - GameSystemManager による初期化
##
## 利点:
## - アクセスパターンが明確: spell_systems.spell_damage.xxx() など
## - 初期化ロジックが集約される
## - 新規スペルシステム追加時に集約位置が明確

## 11個のSpell**** クラス参照
var spell_damage: SpellDamage = null  # ダメージ・回復処理
var spell_creature_move: SpellCreatureMove = null  # クリーチャー移動
var spell_creature_swap: SpellCreatureSwap = null  # クリーチャー交換
var spell_creature_return: SpellCreatureReturn = null  # クリーチャー手札戻し
var spell_creature_place: SpellCreaturePlace = null  # クリーチャー配置
var spell_borrow: SpellBorrow = null  # スペル借用
var spell_transform: SpellTransform = null  # クリーチャー変身
var spell_purify: SpellPurify = null  # 呪い除去
var spell_synthesis: SpellSynthesis = null  # スペル合成
var card_sacrifice_helper: CardSacrificeHelper = null  # カード犠牲システム
var cpu_turn_processor = null  # CPU処理（旧・バトル用）

## 初期化検証
func is_fully_initialized() -> bool:
	## 最小限の必須システムが初期化されているか確認
	if not spell_damage:
		return false
	if not spell_creature_move:
		return false
	if not spell_purify:
		return false
	return true

## デバッグ用: 初期化状況を表示
func print_initialization_status() -> void:
	var initialized = []
	var uninitialized = []

	if spell_damage:
		initialized.append("spell_damage")
	else:
		uninitialized.append("spell_damage")

	if spell_creature_move:
		initialized.append("spell_creature_move")
	else:
		uninitialized.append("spell_creature_move")

	if spell_creature_swap:
		initialized.append("spell_creature_swap")
	else:
		uninitialized.append("spell_creature_swap")

	if spell_creature_return:
		initialized.append("spell_creature_return")
	else:
		uninitialized.append("spell_creature_return")

	if spell_creature_place:
		initialized.append("spell_creature_place")
	else:
		uninitialized.append("spell_creature_place")

	if spell_borrow:
		initialized.append("spell_borrow")
	else:
		uninitialized.append("spell_borrow")

	if spell_transform:
		initialized.append("spell_transform")
	else:
		uninitialized.append("spell_transform")

	if spell_purify:
		initialized.append("spell_purify")
	else:
		uninitialized.append("spell_purify")

	if spell_synthesis:
		initialized.append("spell_synthesis")
	else:
		uninitialized.append("spell_synthesis")

	if card_sacrifice_helper:
		initialized.append("card_sacrifice_helper")
	else:
		uninitialized.append("card_sacrifice_helper")

	if cpu_turn_processor:
		initialized.append("cpu_turn_processor")
	else:
		uninitialized.append("cpu_turn_processor")

	print("[SpellSubsystemContainer] 初期化済み: %d個 / %d個" % [initialized.size(), initialized.size() + uninitialized.size()])
	if uninitialized.size() > 0:
		print("  未初期化: %s" % uninitialized)
