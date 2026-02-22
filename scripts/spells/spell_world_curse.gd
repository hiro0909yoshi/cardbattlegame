extends Node
class_name SpellWorldCurse

# 世界刻印システム
# ゲーム全体に影響を与える刻印効果を管理
# ドキュメント: docs/design/spells/世界刻印.md

# ========================================
# 参照
# ========================================
var spell_curse: SpellCurse
var game_flow_manager: GameFlowManager

# === 直接参照（GFM経由を廃止） ===
var spell_cast_notification_ui = null  # SpellCastNotificationUI: 通知表示
var _player_info_service = null  # PlayerInfoService: プレイヤー情報UI更新
var game_stats  # GameFlowManager.game_stats への直接参照

# ========================================
# 初期化
# ========================================

func setup(curse: SpellCurse, gfm: GameFlowManager):
	spell_curse = curse
	game_flow_manager = gfm

## 直接参照を設定（GFM経由を廃止）
func set_notification_ui(ui) -> void:
	spell_cast_notification_ui = ui

## game_statsを設定（GFM経由を廃止）
func set_game_stats(p_game_stats) -> void:
	game_stats = p_game_stats

# ========================================
# ポップアップ通知
# ========================================

## 世界刻印ブロック時のポップアップ表示
func show_blocked_notification(message: String) -> void:
	if spell_cast_notification_ui and spell_cast_notification_ui.has_method("show_notification_and_wait"):
		spell_cast_notification_ui.show_notification_and_wait(message)

	print("[世界刻印] %s" % message)

# ========================================
# インスタンスメソッド（game_flow_manager参照を使用）
# ========================================

## game_statsを取得
func _get_game_stats() -> Dictionary:
	if not game_flow_manager:
		return {}
	return game_stats

## インペリアルガード: 属性変化がブロックされるか（ポップアップ付き）
func check_land_change_blocked(show_popup: bool = true) -> bool:
	var stats = _get_game_stats()
	if is_land_change_blocked(stats):
		if show_popup:
			show_blocked_notification("不変: インペリアルガード発動中")
		return true
	return false

## テンパランスロウ: 侵略がブロックされるか（ポップアップ付き）
func check_invasion_blocked(attacker_id: int, defender_id: int, show_popup: bool = true) -> bool:
	if defender_id < 0:
		return false

	var stats = _get_game_stats()
	var world_curse = stats.get("world_curse", {})
	if world_curse.get("curse_type") != "invasion_restrict":
		return false

	# 順位を取得（PlayerSystem経由）
	if not game_flow_manager or not game_flow_manager.player_system:
		return false

	var attacker_rank = game_flow_manager.player_system.get_player_ranking(attacker_id)
	var defender_rank = game_flow_manager.player_system.get_player_ranking(defender_id)

	# 攻撃者が上位（順位数値が小さい）なら下位への侵略は制限
	if attacker_rank < defender_rank:
		if show_popup:
			show_blocked_notification("節制: テンパランスロウ発動中")
		return true
	return false

## ハーミットズパラドックス: 同名クリーチャーのバトル時相殺チェック
## ハーミットズパラドックスが有効かどうかをチェック
func is_mirror_world_active() -> bool:
	var stats = _get_game_stats()
	return is_same_creature_destroy_active(stats)

## プレイヤーのフィールドに同名クリーチャーがいるかチェック
## board_system: ボードシステムの参照
## player_id: チェック対象のプレイヤーID
## creature_name: チェック対象のクリーチャー名
## exclude_tile_index: 除外するタイルインデックス（防御側自身のタイルを除外する場合）
## 戻り値: 同名クリーチャーが存在するか
func check_has_same_name_creature(board_system, player_id: int, creature_name: String, exclude_tile_index: int = -1) -> bool:
	if not board_system:
		return false
	
	# プレイヤーが所有するタイルを取得
	var owned_tiles = board_system.get_player_owned_tiles(player_id)
	
	for tile_index in owned_tiles:
		# 除外タイルはスキップ
		if tile_index == exclude_tile_index:
			continue
		
		var tile_info = board_system.get_tile_info(tile_index)
		var creature = tile_info.get("creature", {})
		if creature.is_empty():
			continue
		
		if creature.get("name", "") == creature_name:
			return true
	
	return false

## ライズオブサン: コスト倍率を取得
func get_cost_multiplier_for_card(card: Dictionary) -> float:
	var stats = _get_game_stats()
	return get_cost_multiplier(card, stats)

# ========================================
# 刻印付与（エントリポイント）
# ========================================

## effect辞書から世界刻印を適用
func apply(effect: Dictionary) -> void:
	var curse_type = effect.get("curse_type", "")
	var curse_name = effect.get("name", "")
	var duration = effect.get("duration", 6)
	var params = effect.get("params", {})
	params["name"] = curse_name
	
	spell_curse.curse_world(curse_type, duration, params)
	print("[世界刻印] %s を発動（%dR間）" % [curse_name, duration])
	
	# UIを更新（世界刻印表示）
	_update_ui()

# ========================================
# 判定メソッド（static）
# ========================================

## ハイプリーステス: 刻印付きクリーチャーが結界を得るか
static func is_cursed_creature_protected(stats: Dictionary) -> bool:
	var world_curse = stats.get("world_curse", {})
	return world_curse.get("curse_type") == "cursed_protection"

## エンプレスドメイン: 全セプターがスペル対象不可か
static func is_all_players_spell_immune(stats: Dictionary) -> bool:
	var world_curse = stats.get("world_curse", {})
	return world_curse.get("curse_type") == "world_spell_protection"

## インペリアルガード: 属性変化が無効か
static func is_land_change_blocked(stats: Dictionary) -> bool:
	var world_curse = stats.get("world_curse", {})
	return world_curse.get("curse_type") == "land_protect"

## テンパランスロウ: 下位侵略が制限されているか
## attacker_rank: 攻撃者の順位（1が1位）
## defender_rank: 防御者の順位
static func is_invasion_restricted(attacker_rank: int, defender_rank: int, stats: Dictionary) -> bool:
	var world_curse = stats.get("world_curse", {})
	if world_curse.get("curse_type") != "invasion_restrict":
		return false
	# 攻撃者が上位（数値が小さい）なら下位への侵略は制限
	return attacker_rank < defender_rank

## ライズオブサン: コスト倍率を取得
## card: カードデータ（rarityを含む）
## レアリティによる倍率:
##   R = crown_bag_multiplier (2.0)
##   S = bag_multiplier (1.5)
##   N, C = 1.0（倍率なし）
static func get_cost_multiplier(card: Dictionary, stats: Dictionary) -> float:
	var world_curse = stats.get("world_curse", {})
	if world_curse.get("curse_type") != "cost_increase":
		return 1.0
	var params = world_curse.get("params", {})
	var rarity = card.get("rarity", "N")

	if rarity == "R":
		return params.get("crown_bag_multiplier", 2.0)
	elif rarity == "S":
		return params.get("bag_multiplier", 1.5)

	# N, C は倍率なし
	return 1.0

## フールズフリーダム: 召喚条件が無視されるか
static func is_summon_condition_ignored(stats: Dictionary) -> bool:
	var world_curse = stats.get("world_curse", {})
	return world_curse.get("curse_type") == "summon_cost_free"

## ハングドマンズシール: 特定トリガーが無効か
## trigger_type: "mystic_arts", "on_self_destroy", "on_battle_end"
static func is_trigger_disabled(trigger_type: String, stats: Dictionary) -> bool:
	var world_curse = stats.get("world_curse", {})
	if world_curse.get("curse_type") != "skill_disable":
		return false
	var params = world_curse.get("params", {})
	var disabled = params.get("disabled_triggers", [])
	return trigger_type in disabled

## ボンドオブラバーズ: 連鎖ペアを取得
## 戻り値: [["fire", "earth"], ["water", "wind"]] 形式
static func get_chain_pairs(stats: Dictionary) -> Array:
	var world_curse = stats.get("world_curse", {})
	if world_curse.get("curse_type") != "element_chain":
		return []
	var params = world_curse.get("params", {})
	return params.get("chain_pairs", [])

## ボンドオブラバーズ: 2つの属性が同じ連鎖グループか判定
## 通常: 同属性のみ連鎖
## ボンドオブラバーズ発動中: 火⇔地、水⇔風 も連鎖
static func is_same_chain_group(elem1: String, elem2: String, stats: Dictionary) -> bool:
	# 同属性なら常にtrue
	if elem1 == elem2:
		return true

	# ボンドオブラバーズ発動中のペアチェック
	var pairs = get_chain_pairs(stats)
	for pair in pairs:
		if elem1 in pair and elem2 in pair:
			return true

	return false

## ハーミットズパラドックス: 隠者が有効か
static func is_same_creature_destroy_active(stats: Dictionary) -> bool:
	var world_curse = stats.get("world_curse", {})
	return world_curse.get("curse_type") == "same_creature_destroy"

# ========================================
# ラウンド経過処理
# ========================================

## ラウンド開始時に世界刻印のdurationを更新
## GameFlowManagerから呼び出す（current_player_index == 0 のタイミング）
func on_round_start():
	if not game_flow_manager:
		return
	
	var world_curse = game_stats.get("world_curse", {})
	if world_curse.is_empty():
		return
	
	var duration = world_curse.get("duration", -1)
	if duration > 0:
		world_curse["duration"] = duration - 1
		var curse_name = world_curse.get("name", "不明")
		print("[世界刻印] %s 残り%dR" % [curse_name, duration - 1])
		
		if world_curse["duration"] == 0:
			var expired_name = world_curse.get("name", "不明")
			game_stats.erase("world_curse")
			print("[世界刻印消滅] %s" % expired_name)
		
		# UIを更新
		_update_ui()

# ========================================
# UI更新
# ========================================

## プレイヤー情報パネルを更新（世界刻印表示用）
func _update_ui():
	if not _player_info_service:
		return

	_player_info_service.update_panels()
