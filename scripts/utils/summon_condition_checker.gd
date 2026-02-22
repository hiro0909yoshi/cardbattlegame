class_name SummonConditionChecker
extends RefCounted
## 召喚条件チェックユーティリティ
##
## プレイヤー/CPU共通の召喚条件チェックを提供
## - 土地条件（lands_required）
## - 配置制限（cannot_summon）
## - カード犠牲要否（cards_sacrifice）


# ============================================================
# カード犠牲判定
# ============================================================

## カード犠牲が必要か判定
static func requires_card_sacrifice(card_data: Dictionary) -> bool:
	# 正規化されたフィールドをチェック
	if card_data.get("cost_cards_sacrifice", 0) > 0:
		return true
	# 正規化されていない場合、元のcostフィールドもチェック
	var cost = card_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		return cost.get("cards_sacrifice", 0) > 0
	return false


# ============================================================
# 土地条件チェック
# ============================================================

## 土地条件チェック（属性ごとにカウント）
## @param card_data カードデータ
## @param player_id プレイヤーID
## @param board_system BoardSystem3D参照
## @return {passed: bool, message: String}
static func check_lands_required(card_data: Dictionary, player_id: int, board_system) -> Dictionary:
	var lands_required = _get_lands_required_array(card_data)
	if lands_required.is_empty():
		return {"passed": true, "message": ""}
	
	if not board_system:
		return {"passed": false, "message": "board_systemが未設定"}
	
	# プレイヤーの所有土地の属性をカウント
	var owned_elements = {}  # {"fire": 2, "water": 1, ...}
	var player_tiles = board_system.get_player_tiles(player_id)
	for tile in player_tiles:
		var element = tile.tile_type if tile else ""
		if element != "" and element != "neutral":
			owned_elements[element] = owned_elements.get(element, 0) + 1
	
	# 必要な属性をカウント
	var required_elements = {}  # {"fire": 2, ...}
	for element in lands_required:
		required_elements[element] = required_elements.get(element, 0) + 1
	
	# 各属性の条件を満たしているかチェック
	for element in required_elements.keys():
		var required_count = required_elements[element]
		var owned_count = owned_elements.get(element, 0)
		if owned_count < required_count:
			var element_name = get_element_display_name(element)
			return {
				"passed": false,
				"message": "%s属性の土地が%d個必要です（所有: %d）" % [element_name, required_count, owned_count]
			}
	
	return {"passed": true, "message": ""}


## 土地条件の配列を取得
static func _get_lands_required_array(card_data: Dictionary) -> Array:
	# 正規化されたフィールドをチェック
	if card_data.has("cost_lands_required"):
		var lands = card_data.get("cost_lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
		return []
	# 正規化されていない場合、元のcostフィールドもチェック
	var cost = card_data.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		var lands = cost.get("lands_required", [])
		if typeof(lands) == TYPE_ARRAY:
			return lands
	return []


# ============================================================
# 配置制限チェック
# ============================================================

## 配置制限チェック（cannot_summon）
## @param card_data カードデータ
## @param tile_element タイルの属性
## @return {passed: bool, message: String}
static func check_cannot_summon(card_data: Dictionary, tile_element: String) -> Dictionary:
	var restrictions = card_data.get("restrictions", {})
	var cannot_summon = restrictions.get("cannot_summon", [])
	
	if cannot_summon.is_empty():
		return {"passed": true, "message": ""}
	
	# タイル属性が配置不可リストに含まれているかチェック
	if tile_element in cannot_summon:
		var element_name = get_element_display_name(tile_element)
		return {
			"passed": false,
			"message": "このクリーチャーは%s属性の土地には配置できません" % element_name
		}
	
	return {"passed": true, "message": ""}


# ============================================================
# 愚者チェック
# ============================================================

## 召喚条件が解除されているか（フールズフリーダム/リリース呪い）
## @param player_id プレイヤーID
## @param game_flow_manager GameFlowManager参照
## @param board_system BoardSystem3D参照（player_id未指定時のフォールバック）
## @param player_system PlayerSystem参照（オプション、直接参照優先）
## @param stats 直接参照（GFM経由を避けるため）
## @return 召喚条件が解除されているか
static func is_summon_condition_ignored(player_id: int, game_flow_manager, board_system = null, player_system = null, stats = null) -> bool:
	if not game_flow_manager:
		return false

	# フールズフリーダム（世界呪い）チェック - 直接参照を優先
	var gs = stats if stats else game_flow_manager.game_stats
	if SpellWorldCurse.is_summon_condition_ignored(gs):
		return true

	# リリース呪い（プレイヤー呪い）チェック
	var check_player_id = player_id
	if check_player_id < 0 and board_system:
		check_player_id = board_system.current_player_index

	# player_systemを取得（直接参照優先）
	var ps = player_system if player_system else (game_flow_manager.player_system if game_flow_manager else null)
	if not ps:
		return false
	if check_player_id < 0 or check_player_id >= ps.players.size():
		return false

	var player = ps.players[check_player_id]
	var player_dict = {"curse": player.curse}
	return SpellRestriction.is_summon_condition_released(player_dict)


# ============================================================
# ヘルパー
# ============================================================

## 属性の表示名を取得
static func get_element_display_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		_: return element
