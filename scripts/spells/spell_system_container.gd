class_name SpellSystemContainer
extends RefCounted
## SpellSystem参照コンテナ
##
## GameFlowManagerが保持する10+2個のspellシステム変数を一元管理するコンテナ。
## CPUAIContextパターンを踏襲し、RefCountedベースで参照を保持する。

# ============================================================
# コアシステム（8個）
# ============================================================

var spell_draw = null
var spell_magic = null
var spell_land = null
var spell_curse = null
var spell_dice = null
var spell_curse_stat = null
var spell_world_curse = null
var spell_player_move = null

# ============================================================
# 派生システム（2個）
# ============================================================

var spell_curse_toll = null
var spell_cost_modifier = null

# ============================================================
# 初期化
# ============================================================

## コアシステムをセットアップ（8個）
func setup(
	p_spell_draw,
	p_spell_magic,
	p_spell_land,
	p_spell_curse,
	p_spell_dice,
	p_spell_curse_stat,
	p_spell_world_curse,
	p_spell_player_move
) -> void:
	spell_draw = p_spell_draw
	spell_magic = p_spell_magic
	spell_land = p_spell_land
	spell_curse = p_spell_curse
	spell_dice = p_spell_dice
	spell_curse_stat = p_spell_curse_stat
	spell_world_curse = p_spell_world_curse
	spell_player_move = p_spell_player_move


## 派生システムを設定: SpellCurseToll
func set_spell_curse_toll(p_spell_curse_toll) -> void:
	spell_curse_toll = p_spell_curse_toll


## 派生システムを設定: SpellCostModifier
func set_spell_cost_modifier(p_spell_cost_modifier) -> void:
	spell_cost_modifier = p_spell_cost_modifier

# ============================================================
# 辞書変換（既存の辞書展開メソッドとの互換性用）
# ============================================================

## 全システムを辞書形式で返す
func to_dictionary() -> Dictionary:
	return {
		"spell_draw": spell_draw,
		"spell_magic": spell_magic,
		"spell_land": spell_land,
		"spell_curse": spell_curse,
		"spell_dice": spell_dice,
		"spell_curse_stat": spell_curse_stat,
		"spell_world_curse": spell_world_curse,
		"spell_player_move": spell_player_move,
		"spell_curse_toll": spell_curse_toll,
		"spell_cost_modifier": spell_cost_modifier
	}

# ============================================================
# バリデーション
# ============================================================

## コアシステム（8個）が全て設定されているかチェック
func is_valid() -> bool:
	return (
		spell_draw != null and
		spell_magic != null and
		spell_land != null and
		spell_curse != null and
		spell_dice != null and
		spell_curse_stat != null and
		spell_world_curse != null and
		spell_player_move != null
	)


## 派生システムを含む全12システムが設定されているかチェック
func is_fully_valid() -> bool:
	return (
		is_valid() and
		spell_curse_toll != null and
		spell_cost_modifier != null
	)


## デバッグ用：設定状況を出力
func debug_print_status() -> void:
	print("[SpellSystemContainer] === 設定状況 ===")
	print("  spell_draw: %s" % ("OK" if spell_draw else "未設定"))
	print("  spell_magic: %s" % ("OK" if spell_magic else "未設定"))
	print("  spell_land: %s" % ("OK" if spell_land else "未設定"))
	print("  spell_curse: %s" % ("OK" if spell_curse else "未設定"))
	print("  spell_dice: %s" % ("OK" if spell_dice else "未設定"))
	print("  spell_curse_stat: %s" % ("OK" if spell_curse_stat else "未設定"))
	print("  spell_world_curse: %s" % ("OK" if spell_world_curse else "未設定"))
	print("  spell_player_move: %s" % ("OK" if spell_player_move else "未設定"))
	print("  spell_curse_toll: %s" % ("OK" if spell_curse_toll else "未設定"))
	print("  spell_cost_modifier: %s" % ("OK" if spell_cost_modifier else "未設定"))
