extends RefCounted
class_name SpellMovement

# 移動関連の呪い・スキル処理
# - 拘束呪い (forced_stop): スペルで付与、誰でも止める、1回で消滅
# - 拘束スキル (trap_stop): クリーチャースキル、所有者以外を止める、永続

# 参照
var creature_manager = null
var board_system = null

func _init():
	pass

# セットアップ
func setup(cm, bs):
	creature_manager = cm
	board_system = bs

# =============================================================================
# 拘束判定（メイン関数）
# =============================================================================

## 拘束判定を行う（tile_nodesを直接渡すバージョン）
## 戻り値: { "stopped": bool, "reason": String, "source_type": String }
## source_type: "curse" = 呪い, "skill" = スキル, "" = 拘束なし
func check_forced_stop_with_tiles(tile_index: int, moving_player_id: int, tile_nodes: Dictionary, consume: bool = true) -> Dictionary:
	var result = {"stopped": false, "reason": "", "source_type": ""}
	
	# タイルにクリーチャーがいるか確認
	if not tile_nodes.has(tile_index):
		return result
	
	var tile = tile_nodes[tile_index]
	if not tile.creature_data:
		return result
	
	var creature = tile.creature_data
	var tile_owner_id = tile.owner_id
	
	# 1. 呪い"停滞"チェック（誰でも止まる）
	if _has_forced_stop_curse(creature):
		result["stopped"] = true
		result["reason"] = "停滞の呪いで拘束された！"
		result["source_type"] = "curse"
		# consume=trueの場合のみ呪いを消費（シミュレーション時はfalse）
		if consume:
			_consume_forced_stop_curse(creature)
		return result
	
	# 2. スキル"拘束"チェック（所有者は止まらない）
	if tile_owner_id != moving_player_id:
		var trap_result = _check_trap_stop_skill(creature, tile)
		if trap_result["active"]:
			result["stopped"] = true
			result["reason"] = creature.get("name", "クリーチャー") + "の拘束！"
			result["source_type"] = "skill"
			return result
	
	return result

## 拘束判定を行う（board_system経由、後方互換）
func check_forced_stop(tile_index: int, moving_player_id: int) -> Dictionary:
	if not board_system or not board_system.tile_nodes:
		return {"stopped": false, "reason": "", "source_type": ""}
	return check_forced_stop_with_tiles(tile_index, moving_player_id, board_system.tile_nodes)

# =============================================================================
# 呪い"停滞" (forced_stop)
# =============================================================================

## 停滞呪いを付与
func apply_forced_stop_curse(tile_index: int, duration: int = 2) -> bool:
	if not creature_manager:
		return false
	
	var creature = creature_manager.get_data_ref(tile_index)
	if creature.is_empty():
		return false
	
	# 既存の呪いを上書き
	creature["curse"] = {
		"curse_type": "forced_stop",
		"name": "停滞",
		"duration": duration,
		"params": {
			"uses_remaining": 1  # 1回で消滅
		}
	}
	
	print("[刻印付与] 停滞 → タイル", tile_index, " (", duration, "R)")
	return true

## 停滞呪いを持っているか
func _has_forced_stop_curse(creature: Dictionary) -> bool:
	if not creature.has("curse"):
		return false
	var curse = creature["curse"]
	return curse.get("curse_type", "") == "forced_stop"

## 停滞呪いを消費（1回使用で消滅）
func _consume_forced_stop_curse(creature: Dictionary) -> void:
	if not creature.has("curse"):
		return
	
	var curse = creature["curse"]
	if curse.get("curse_type", "") != "forced_stop":
		return
	
	# 使用回数を減らす
	var params = curse.get("params", {})
	var uses = params.get("uses_remaining", 1)
	uses -= 1
	
	if uses <= 0:
		# 呪い削除
		creature.erase("curse")
		print("[呪い消滅] 停滞（使用済み）")
	else:
		params["uses_remaining"] = uses

# =============================================================================
# スキル"拘束" (trap_stop)
# =============================================================================

## 拘束スキルが発動するか判定
## 条件: 指定属性のタイルに配置されている必要あり
func _check_trap_stop_skill(creature: Dictionary, tile) -> Dictionary:
	var result = {"active": false, "element": ""}
	
	# ability_parsed から拘束スキルを探す
	var ability_parsed = creature.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	# 拘束キーワードがあるか
	var has_trap = false
	for keyword in keywords:
		if keyword is String and keyword.begins_with("拘束"):
			has_trap = true
			break
	
	if not has_trap:
		# ability_detail からパース（フォールバック）
		var ability_detail = creature.get("ability_detail", "")
		if "拘束" in ability_detail:
			has_trap = true
	
	if not has_trap:
		return result
	
	# 拘束の発動条件: 指定属性のタイルに配置
	var trap_elements = _get_trap_stop_elements(creature)
	var tile_element = _get_tile_element(tile)
	
	if tile_element in trap_elements:
		result["active"] = true
		result["element"] = tile_element
	
	return result

## 拘束スキルの対象属性を取得
func _get_trap_stop_elements(creature: Dictionary) -> Array:
	var elements = []
	
	# ability_parsed から取得
	var ability_parsed = creature.get("ability_parsed", {})
	var trap_info = ability_parsed.get("trap_stop", {})
	if trap_info.has("elements"):
		return trap_info["elements"]
	
	# ability_detail からパース（例: "拘束[火]", "拘束[水]"）
	var ability_detail = creature.get("ability_detail", "")
	var regex = RegEx.new()
	regex.compile("拘束\\[([^\\]]+)\\]")
	var match_result = regex.search(ability_detail)
	
	if match_result:
		var element_str = match_result.get_string(1)
		# 属性名を変換
		match element_str:
			"火":
				elements.append("fire")
			"水":
				elements.append("water")
			"地":
				elements.append("earth")
			"風":
				elements.append("wind")
			_:
				elements.append(element_str)
	
	return elements

## タイルの属性を取得
func _get_tile_element(tile) -> String:
	if tile.has_method("get_tile_type"):
		return tile.get_tile_type()
	if "tile_type" in tile:
		return tile.tile_type
	return ""

# =============================================================================
# 奮闘呪い (indomitable)
# =============================================================================

## 奮闘呪いを付与
func apply_indomitable_curse(tile_index: int, duration: int = 5) -> bool:
	if not creature_manager:
		return false
	
	var creature = creature_manager.get_data_ref(tile_index)
	if creature.is_empty():
		return false
	
	# 既存の呪いを上書き
	creature["curse"] = {
		"curse_type": "indomitable",
		"name": "奮闘",
		"duration": duration,
		"params": {}
	}
	
	print("[刻印付与] 奮闘 → タイル", tile_index, " (", duration, "R)")
	return true

## 奮闘呪いを持っているか（静的メソッド）
static func has_indomitable_curse(creature: Dictionary) -> bool:
	if creature.is_empty():
		return false
	if not creature.has("curse"):
		return false
	var curse = creature["curse"]
	return curse.get("curse_type", "") == "indomitable"

# =============================================================================
# ダウン解除 (down_clear)
# =============================================================================

## 指定プレイヤーの全クリーチャーのダウン状態を解除
func clear_down_state_for_player(player_id: int, tile_nodes: Dictionary) -> int:
	var cleared_count = 0
	
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id != player_id:
			continue
		if not tile.creature_data:
			continue
		
		# ダウン状態を解除
		if tile.has_method("set_down_state") and tile.has_method("is_down"):
			if tile.is_down():  # ダウン中の場合のみ
				tile.set_down_state(false)
				cleared_count += 1
				print("[ダウン解除] タイル", tile_index, " - ", tile.creature_data.get("name", ""))
	
	print("[アラーム] ", cleared_count, "体のダウンを解除")
	return cleared_count

# =============================================================================
# ダウン付与 (set_down)
# =============================================================================

## 指定タイルのクリーチャーをダウン状態にする（アルプアルカナアーツ等）
func set_down_state_for_tile(tile_index: int, tile_nodes: Dictionary) -> bool:
	if not tile_nodes.has(tile_index):
		return false
	
	var tile = tile_nodes[tile_index]
	if not tile.creature_data or tile.creature_data.is_empty():
		return false
	
	var creature_name = tile.creature_data.get("name", "クリーチャー")
	
	# 奮闘チェック（奮闘を持っていたらダウンしない）
	if has_indomitable_curse(tile.creature_data):
		print("[ダウン付与] %s は奮闘を持っているためダウンしません" % creature_name)
		return false
	
	# 既にダウン中かチェック
	if tile.has_method("is_down") and tile.is_down():
		print("[ダウン付与] %s は既にダウン状態です" % creature_name)
		return true  # 成功扱い
	
	# ダウン状態を設定
	if tile.has_method("set_down_state"):
		tile.set_down_state(true)
		print("[ダウン付与] %s をダウン状態にしました" % creature_name)
		return true
	
	return false

# =============================================================================
# SpellPhaseHandler連携用
# =============================================================================

## スペル効果から呪いを付与（SpellCurse経由で呼ばれる想定）
func apply_curse_from_effect(tile_index: int, effect: Dictionary) -> bool:
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"forced_stop":
			var duration = effect.get("duration", 2)
			return apply_forced_stop_curse(tile_index, duration)
		"indomitable":
			var duration = effect.get("duration", 5)
			return apply_indomitable_curse(tile_index, duration)
	
	return false
