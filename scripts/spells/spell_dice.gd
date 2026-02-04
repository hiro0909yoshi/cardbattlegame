extends Node
class_name SpellDice

# ダイス操作スペル効果
# プレイヤーのダイス結果を固定値や範囲指定に変更する
# ドキュメント: docs/design/spells/呪い効果.md

# 参照
var player_system: PlayerSystem
var spell_curse: SpellCurse

# 初期化
func setup(p_system: PlayerSystem, curse: SpellCurse):
	player_system = p_system
	spell_curse = curse
	
	print("[SpellDice] 初期化完了")

# ========================================
# スペル効果適用（SpellPhaseHandlerから呼ばれる）
# ========================================

# ダイス固定効果を適用
func apply_dice_fixed_effect(effect: Dictionary, target_data: Dictionary, current_player_id: int):
	var target_player_id = _get_target_player_id(target_data, current_player_id)
	if target_player_id < 0:
		return
	
	var value = effect.get("value", 6)
	var duration = effect.get("duration", 1)
	var _name = effect.get("name", "ダイス固定")
	
	spell_curse.curse_player(target_player_id, "dice_fixed", duration, {
		"name": _name,
		"value": value
	})

# ダイス範囲指定効果を適用
func apply_dice_range_effect(effect: Dictionary, target_data: Dictionary, current_player_id: int):
	var target_player_id = _get_target_player_id(target_data, current_player_id)
	if target_player_id < 0:
		return
	
	var min_val = effect.get("min", 1)
	var max_val = effect.get("max", 6)
	var duration = effect.get("duration", 1)
	var _name = effect.get("name", "ダイス範囲指定")
	
	spell_curse.curse_player(target_player_id, "dice_range", duration, {
		"name": _name,
		"min": min_val,
		"max": max_val
	})

# 複数ダイスロール効果を適用
func apply_dice_multi_effect(effect: Dictionary, target_data: Dictionary, current_player_id: int):
	var target_player_id = _get_target_player_id(target_data, current_player_id)
	if target_player_id < 0:
		return
	
	var count = effect.get("count", 2)
	var duration = effect.get("duration", 1)
	var _name = effect.get("name", "複数ダイス")
	
	spell_curse.curse_player(target_player_id, "dice_multi", duration, {
		"name": _name,
		"count": count
	})

# 範囲指定 + EP獲得効果を適用
func apply_dice_range_magic_effect(effect: Dictionary, target_data: Dictionary, current_player_id: int):
	var target_player_id = _get_target_player_id(target_data, current_player_id)
	if target_player_id < 0:
		return
	
	var min_val = effect.get("min", 1)
	var max_val = effect.get("max", 6)
	var magic = effect.get("magic", 0)
	var duration = effect.get("duration", 1)
	var _name = effect.get("name", "蓄魔歩行")
	
	spell_curse.curse_player(target_player_id, "dice_range_magic", duration, {
		"name": _name,
		"min": min_val,
		"max": max_val,
		"magic": magic
	})

# ターゲットプレイヤーIDを取得（内部ヘルパー）
func _get_target_player_id(target_data: Dictionary, current_player_id: int) -> int:
	# target_type が "none" の場合は使用者自身
	if target_data.get("type", "") == "none" or target_data.is_empty():
		return current_player_id
	
	# target_type が "player" の場合はターゲット選択
	if target_data.get("type", "") == "player":
		return target_data.get("player_id", current_player_id)
	
	return current_player_id

# ========================================
# 汎用効果適用（統合版）
# ========================================

## スペル効果から呪いを適用（統合メソッド）
func apply_effect_from_parsed(effect: Dictionary, target_data: Dictionary, current_player_id: int):
	var effect_type = effect.get("effect_type", "")
	
	match effect_type:
		"dice_fixed":
			apply_dice_fixed_effect(effect, target_data, current_player_id)
		
		"dice_range":
			apply_dice_range_effect(effect, target_data, current_player_id)
		
		"dice_multi":
			apply_dice_multi_effect(effect, target_data, current_player_id)
		
		"dice_range_magic":
			apply_dice_range_magic_effect(effect, target_data, current_player_id)
		
		_:
			print("[SpellDice] 未対応の効果タイプ: ", effect_type)

# ========================================
# ダイス固定スペル
# ========================================

# ホーリーワード6: ダイスを6に固定（1ターン）
func holy_word_6(player_id: int):
	spell_curse.curse_player(player_id, "dice_fixed", 1, {
		"name": "ホーリーワード6",
		"value": 6
	})

# ホーリーワード1: ダイスを1に固定（1ターン）
func holy_word_1(player_id: int):
	spell_curse.curse_player(player_id, "dice_fixed", 1, {
		"name": "ホーリーワード1",
		"value": 1
	})

# ========================================
# ダイス範囲指定スペル
# ========================================

# ヘイスト: ダイスを6-8の範囲に指定（1ターン）
func haste(player_id: int):
	spell_curse.curse_player(player_id, "dice_range", 1, {
		"name": "ヘイスト",
		"min": 6,
		"max": 8
	})

# ========================================
# ダイス判定（呪い適用）
# ========================================

# 3個目のダイスが必要か判定（フライ効果）
func needs_third_dice(player_id: int) -> bool:
	var curse = spell_curse.get_player_curse(player_id)
	var curse_type = curse.get("curse_type", "")
	if curse_type == "dice_multi":
		var count = curse.get("params", {}).get("count", 2)
		return count >= 3
	return false

# 複数ダイスロールが必要か判定（旧版 - 互換性のため残す）
func needs_multi_roll(player_id: int) -> bool:
	var curse = spell_curse.get_player_curse(player_id)
	var curse_type = curse.get("curse_type", "")
	return curse_type == "dice_multi"

# 複数ダイスロールの回数を取得（旧版 - 互換性のため残す）
func get_multi_roll_count(player_id: int) -> int:
	var curse = spell_curse.get_player_curse(player_id)
	var curse_type = curse.get("curse_type", "")
	if curse_type == "dice_multi":
		return curse.get("params", {}).get("count", 1)
	return 1

# ダイス範囲呪い（dice_range または dice_range_magic）があるか判定
func has_dice_range_curse(player_id: int) -> bool:
	var curse = spell_curse.get_player_curse(player_id)
	var curse_type = curse.get("curse_type", "")
	return curse_type == "dice_range" or curse_type == "dice_range_magic"

# ダイス範囲呪いの情報を取得（表示用）
func get_dice_range_info(player_id: int) -> Dictionary:
	var curse = spell_curse.get_player_curse(player_id)
	var curse_type = curse.get("curse_type", "")
	if curse_type == "dice_range" or curse_type == "dice_range_magic":
		var params = curse.get("params", {})
		return {
			"name": curse.get("name", ""),
			"min": params.get("min", 1),
			"max": params.get("max", 6)
		}
	return {}

# ダイスロール後にEPを付与するか判定
func should_grant_magic(player_id: int) -> bool:
	var curse = spell_curse.get_player_curse(player_id)
	return curse.get("curse_type", "") == "dice_range_magic"

# 付与するEP量を取得
func get_magic_grant_amount(player_id: int) -> int:
	var curse = spell_curse.get_player_curse(player_id)
	if curse.get("curse_type", "") == "dice_range_magic":
		return curse.get("params", {}).get("magic", 0)
	return 0

# ダイスロール後のEP付与処理（GameFlowManagerから呼ばれる）
func process_magic_grant(player_id: int, ui_manager) -> void:
	if not should_grant_magic(player_id):
		return
	
	var curse = spell_curse.get_player_curse(player_id)
	var curse_name = curse.get("name", "")
	var magic_amount = get_magic_grant_amount(player_id)
	if magic_amount > 0:
		player_system.add_magic(player_id, magic_amount)
		print("[", curse_name, "] EP獲得 +", magic_amount, "EP")
		if ui_manager and ui_manager.global_comment_ui:
			await ui_manager.global_comment_ui.show_and_wait("EP +" + str(magic_amount) + "EP 獲得！", player_id)

# ダイスロール時に呪いを適用
# 通常のダイスシステムから呼ばれる
func get_modified_dice_value(player_id: int, original_value: int) -> int:
	var curse = spell_curse.get_player_curse(player_id)
	
	if curse.is_empty():
		return original_value
	
	var curse_type = curse.get("curse_type", "")
	var params = curse.get("params", {})
	
	match curse_type:
		"dice_fixed":
			# ダイス固定
			var fixed_value = int(params.get("value", 6))
			print("[ダイス呪い] ", curse.get("name", ""), " → ", fixed_value)
			return fixed_value
		
		"dice_range":
			# ダイス範囲指定
			var min_val = int(params.get("min", 1))
			var max_val = int(params.get("max", 6))
			var new_value = randi() % (max_val - min_val + 1) + min_val
			print("[ダイス呪い] ", curse.get("name", ""), " → ", new_value, " (", min_val, "-", max_val, ")")
			return new_value
		
		"dice_multi":
			# 複数ダイス（GameFlowManagerで処理済み）
			return original_value
		
		"dice_range_magic":
			# 範囲指定 + EP獲得（チャージステップ）
			var min_val = int(params.get("min", 1))
			var max_val = int(params.get("max", 6))
			var new_value = randi() % (max_val - min_val + 1) + min_val
			print("[ダイス呪い] ", curse.get("name", ""), " → ", new_value, " (", min_val, "-", max_val, ")")
			return new_value
		
		_:
			return original_value
