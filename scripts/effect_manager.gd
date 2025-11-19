extends Node
class_name EffectManager

# 効果管理ユーティリティクラス
# スペル効果の追加・削除、マスグロースなどの効果適用を担当

## ユニークな効果IDを生成
static func generate_effect_id() -> String:
	var timestamp = Time.get_ticks_msec()
	var random_val = randi() % 10000
	return "effect_%d_%d" % [timestamp, random_val]

## スペル効果を追加（上書き処理あり）
static func add_spell_effect_to_creature(creature_data: Dictionary, effect: Dictionary) -> void:
	if creature_data.is_empty():
		print("[効果追加エラー] creature_dataが空です")
		return
	
	# 一時効果 or 永続効果を判定
	var effects_key = "temporary_effects" if effect.get("lost_on_move", true) else "permanent_effects"
	
	# 既存配列を取得（なければ初期化）
	if not creature_data.has(effects_key):
		creature_data[effects_key] = []
	
	# 同名効果を削除（上書き）
	var new_effects = []
	var source_name = effect.get("source_name", "")
	for existing_effect in creature_data.get(effects_key, []):
		if existing_effect.get("source_name") != source_name:
			new_effects.append(existing_effect)
		else:
			print("[効果上書き] ", source_name, " を削除")
	
	# 新しい効果を追加
	effect["id"] = generate_effect_id()
	new_effects.append(effect)
	creature_data[effects_key] = new_effects
	
	print("[効果追加] ", source_name, " → ", creature_data.get("name", "?"), 
		  " (", effects_key, ": +", effect.get("value", 0), " ", effect.get("stat", ""), ")")

## クリーチャーの一時効果をクリア（移動時に使用）
static func clear_temporary_effects(creature_data: Dictionary) -> void:
	if creature_data.is_empty():
		return
	
	var cleared_count = creature_data.get("temporary_effects", []).size()
	creature_data["temporary_effects"] = []
	
	if cleared_count > 0:
		print("[効果クリア] ", creature_data.get("name", "?"), " の一時効果を", cleared_count, "個削除")

## マスグロース効果を適用（全クリーチャーのMHP+5）
static func apply_mass_growth(tile_nodes: Dictionary, player_id: int, hp_bonus: int = 5) -> void:
	var affected_count = 0
	
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and not tile.creature_data.is_empty():
			# base_up_hpを直接増やす（打ち消し不可）
			tile.creature_data["base_up_hp"] = tile.creature_data.get("base_up_hp", 0) + hp_bonus
			affected_count += 1
			print("  ", tile.creature_data.get("name", "?"), " MHP +", hp_bonus)
	
	print("[マスグロース] プレイヤー", player_id + 1, " の", affected_count, "体のクリーチャーのMHP+", hp_bonus)

## ドミナントグロース効果を適用（特定属性のクリーチャーのMHP上昇）
static func apply_dominant_growth(tile_nodes: Dictionary, player_id: int, target_element: String, hp_bonus: int = 10) -> void:
	var affected_count = 0
	
	for tile_index in tile_nodes.keys():
		var tile = tile_nodes[tile_index]
		if tile.owner_id == player_id and not tile.creature_data.is_empty():
			var creature_element = tile.creature_data.get("element", "")
			if creature_element == target_element:
				tile.creature_data["base_up_hp"] = tile.creature_data.get("base_up_hp", 0) + hp_bonus
				affected_count += 1
				print("  ", tile.creature_data.get("name", "?"), " MHP +", hp_bonus)
	
	print("[ドミナントグロース] ", target_element, "属性の", affected_count, "体のクリーチャーのMHP+", hp_bonus)

## 合成効果を適用
static func apply_synthesis_effect(creature_data: Dictionary, hp_bonus: int = 0, ap_bonus: int = 0) -> void:
	if creature_data.is_empty():
		return
	
	creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + hp_bonus
	creature_data["base_up_ap"] = creature_data.get("base_up_ap", 0) + ap_bonus
	
	print("[合成] ", creature_data.get("name", "?"), 
		  " HP+", hp_bonus, " AP+", ap_bonus, 
		  " (打ち消し不可)")

## base_up_hp を増やし、current_hp も同時に更新（マップ上のクリーチャー用）
static func apply_max_hp_effect(creature_data: Dictionary, hp_increase: int) -> void:
	if creature_data.is_empty():
		return
	
	# 1. 古いMHPを保存
	var old_mhp = creature_data.get("hp", 0) + creature_data.get("base_up_hp", 0)
	
	# 2. base_up_hp を増加
	creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + hp_increase
	
	# 3. 新しいMHPを計算
	var new_mhp = creature_data.get("hp", 0) + creature_data["base_up_hp"]
	
	# 4. current_hp も更新（新方式：状態値）
	if creature_data.has("current_hp"):
		var hp_diff = new_mhp - old_mhp
		creature_data["current_hp"] = creature_data.get("current_hp", 0) + hp_diff
		# MHP上限を超えないようにクランプ
		creature_data["current_hp"] = min(creature_data["current_hp"], new_mhp)
		# HP下限の確認（0未満にならないように）
		creature_data["current_hp"] = max(creature_data["current_hp"], 0)
		
		print("【MHP変更】", creature_data.get("name", "?"), " MHP: ", old_mhp, " → ", new_mhp, 
			  " (current_hp: ", creature_data.get("current_hp", 0), ")")
	else:
		# current_hp がない場合は追加
		creature_data["current_hp"] = new_mhp
		print("【MHP変更】", creature_data.get("name", "?"), " MHP: ", old_mhp, " → ", new_mhp,
			  " (current_hp初期化: ", new_mhp, ")")

## デバッグ: クリーチャーの全効果を表示
static func print_all_effects(creature_data: Dictionary) -> void:
	if creature_data.is_empty():
		return
	
	print("\n[効果一覧] ", creature_data.get("name", "?"))
	print("  base_up_hp: ", creature_data.get("base_up_hp", 0))
	print("  base_up_ap: ", creature_data.get("base_up_ap", 0))
	
	print("  permanent_effects:")
	for effect in creature_data.get("permanent_effects", []):
		print("    - ", effect.get("source_name", "?"), ": ", 
			  effect.get("stat", "?"), "+", effect.get("value", 0))
	
	print("  temporary_effects:")
	for effect in creature_data.get("temporary_effects", []):
		print("    - ", effect.get("source_name", "?"), ": ", 
			  effect.get("stat", "?"), "+", effect.get("value", 0))
