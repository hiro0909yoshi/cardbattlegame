extends Node
class_name SpellWorldCurse

# 世界呪いシステム
# ゲーム全体に影響を与える呪い効果を管理
# ドキュメント: docs/design/spells/世界呪い.md

# ========================================
# 参照
# ========================================
var spell_curse: SpellCurse
var game_flow_manager: GameFlowManager

# ========================================
# 初期化
# ========================================

func setup(curse: SpellCurse, gfm: GameFlowManager):
	spell_curse = curse
	game_flow_manager = gfm
	print("[SpellWorldCurse] 初期化完了")

# ========================================
# 呪い付与（エントリポイント）
# ========================================

## effect辞書から世界呪いを適用
func apply(effect: Dictionary) -> void:
	var curse_type = effect.get("curse_type", "")
	var name = effect.get("name", "")
	var duration = effect.get("duration", 6)
	var params = effect.get("params", {})
	params["name"] = name
	
	spell_curse.curse_world(curse_type, duration, params)
	print("[世界呪い] %s を発動（%dR間）" % [name, duration])
	
	# UIを更新（世界呪い表示）
	_update_ui()

# ========================================
# 判定メソッド（static）
# ========================================

## ダークワールド: 呪い付きクリーチャーが防魔を得るか
static func is_cursed_creature_protected(game_stats: Dictionary) -> bool:
	var world_curse = game_stats.get("world_curse", {})
	return world_curse.get("curse_type") == "cursed_protection"

## ミスティワールド: 全セプターがスペル対象不可か
static func is_all_players_spell_immune(game_stats: Dictionary) -> bool:
	var world_curse = game_stats.get("world_curse", {})
	return world_curse.get("curse_type") == "world_spell_protection"

## ソリッドワールド: 土地変性が無効か
static func is_land_change_blocked(game_stats: Dictionary) -> bool:
	var world_curse = game_stats.get("world_curse", {})
	return world_curse.get("curse_type") == "land_protect"

## マーシフルワールド: 下位侵略が制限されているか
## attacker_rank: 攻撃者の順位（1が1位）
## defender_rank: 防御者の順位
static func is_invasion_restricted(attacker_rank: int, defender_rank: int, game_stats: Dictionary) -> bool:
	var world_curse = game_stats.get("world_curse", {})
	if world_curse.get("curse_type") != "invasion_restrict":
		return false
	# 攻撃者が上位（数値が小さい）なら下位への侵略は制限
	return attacker_rank < defender_rank

## ウェイストワールド: コスト倍率を取得
## card: カードデータ（rarityを含む）
static func get_cost_multiplier(card: Dictionary, game_stats: Dictionary) -> float:
	var world_curse = game_stats.get("world_curse", {})
	if world_curse.get("curse_type") != "cost_increase":
		return 1.0
	var params = world_curse.get("params", {})
	# S/Rレアリティは冠袋扱い
	var rarity = card.get("rarity", "N")
	if rarity in ["S", "R"]:
		return params.get("crown_bag_multiplier", 2.0)
	return params.get("bag_multiplier", 1.5)

## ブライトワールド: 召喚条件が無視されるか
static func is_summon_condition_ignored(game_stats: Dictionary) -> bool:
	var world_curse = game_stats.get("world_curse", {})
	return world_curse.get("curse_type") == "summon_cost_free"

## ナチュラルワールド: 特定トリガーが無効か
## trigger_type: "mystic_arts", "on_self_destroy", "on_battle_end"
static func is_trigger_disabled(trigger_type: String, game_stats: Dictionary) -> bool:
	var world_curse = game_stats.get("world_curse", {})
	if world_curse.get("curse_type") != "skill_disable":
		return false
	var params = world_curse.get("params", {})
	var disabled = params.get("disabled_triggers", [])
	return trigger_type in disabled

## ジョイントワールド: 連鎖ペアを取得
## 戻り値: [["fire", "earth"], ["water", "air"]] 形式
static func get_chain_pairs(game_stats: Dictionary) -> Array:
	var world_curse = game_stats.get("world_curse", {})
	if world_curse.get("curse_type") != "element_chain":
		return []
	var params = world_curse.get("params", {})
	return params.get("chain_pairs", [])

## ミラーワールド: 同種相殺が有効か
static func is_same_creature_destroy_active(game_stats: Dictionary) -> bool:
	var world_curse = game_stats.get("world_curse", {})
	return world_curse.get("curse_type") == "same_creature_destroy"

# ========================================
# ラウンド経過処理
# ========================================

## ラウンド開始時に世界呪いのdurationを更新
## GameFlowManagerから呼び出す（current_player_index == 0 のタイミング）
func on_round_start():
	if not game_flow_manager:
		return
	
	var world_curse = game_flow_manager.game_stats.get("world_curse", {})
	if world_curse.is_empty():
		return
	
	var duration = world_curse.get("duration", -1)
	if duration > 0:
		world_curse["duration"] = duration - 1
		var curse_name = world_curse.get("name", "不明")
		print("[世界呪い] %s 残り%dR" % [curse_name, duration - 1])
		
		if world_curse["duration"] == 0:
			var name = world_curse.get("name", "不明")
			game_flow_manager.game_stats.erase("world_curse")
			print("[世界呪い消滅] %s" % name)
		
		# UIを更新
		_update_ui()

# ========================================
# UI更新
# ========================================

## プレイヤー情報パネルを更新（世界呪い表示用）
func _update_ui():
	if not game_flow_manager:
		return
	
	if game_flow_manager.ui_manager and game_flow_manager.ui_manager.player_info_panel:
		game_flow_manager.ui_manager.player_info_panel.update_all_panels()
