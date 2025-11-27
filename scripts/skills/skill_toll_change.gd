extends Node
class_name SkillTollChange

# 通行料変化スキルシステム
# クリーチャーが持つ固有スキルとして実装
# スペルの呪いと異なり、クリーチャー配置時に効果を決定し、永続的に適用される
# ドキュメント: docs/design/skills/通行料操作.md

# ========================================
# 通行料変化効果の種類
# ========================================

## 倍率型: 通行料を倍率で変更
## 例: 1.5倍、0.5倍など
func calculate_toll_with_multiplier(base_toll: int, multiplier: float) -> int:
	var final_toll = int(base_toll * multiplier)
	return max(0, final_toll)

## 固定値型: 通行料を固定値に設定
## 例: 0G、200Gなど
func calculate_toll_with_fixed_value(_base_toll: int, fixed_value: int) -> int:
	return max(0, fixed_value)

## 可変倍率型: ランダムな倍率を適用（ヨーウィ用）
## 毎回移動時にランダムに倍率を決定
func calculate_toll_with_variable_multiplier(base_toll: int, min_multiplier: float, max_multiplier: float) -> int:
	var random_multiplier = randf_range(min_multiplier, max_multiplier)
	var final_toll = int(base_toll * random_multiplier)
	return max(0, final_toll)

# ========================================
# ability_parsed から toll_change を取得
# ========================================

## クリーチャーの ability_parsed から toll_change effect を取得
func get_toll_change_effect(ability_parsed: Dictionary) -> Dictionary:
	if ability_parsed.is_empty():
		return {}
	
	var effects = ability_parsed.get("effects", [])
	for effect in effects:
		if effect.get("effect_type") == "toll_change":
			return effect
	
	return {}

# ========================================
# 通行料を計算
# ========================================

## 通行料を計算（スキル効果を適用）
## 戻り値: 最終通行料（int）
func calculate_final_toll(base_toll: int, toll_effect: Dictionary) -> int:
	if toll_effect.is_empty():
		return base_toll
	
	# 倍率型スキル
	if toll_effect.has("multiplier"):
		var multiplier = toll_effect.get("multiplier", 1.0)
		return calculate_toll_with_multiplier(base_toll, multiplier)
	
	# 可変倍率型スキル（ヨーウィ）
	if toll_effect.get("multiplier_type") == "variable":
		var min_mult = toll_effect.get("min_multiplier", 1.0)
		var max_mult = toll_effect.get("max_multiplier", 1.0)
		return calculate_toll_with_variable_multiplier(base_toll, min_mult, max_mult)
	
	# 固定値型スキル
	if toll_effect.has("value"):
		var fixed_value = toll_effect.get("value", base_toll)
		return calculate_toll_with_fixed_value(base_toll, fixed_value)
	
	return base_toll

# ========================================
# デバッグ出力
# ========================================

## 通行料計算のデバッグログを出力
func log_toll_calculation(creature_name: String, base_toll: int, final_toll: int, effect_type: String):
	var multiplier_str = ""
	if effect_type == "multiplier":
		var multiplier = float(final_toll) / float(base_toll) if base_toll > 0 else 1.0
		multiplier_str = " (%.2f倍)" % multiplier
	
	print("[通行料スキル] %s: %dG → %dG%s" % [creature_name, base_toll, final_toll, multiplier_str])

# ========================================
# 対象クリーチャー一覧
# ========================================

## ID 230（ドワーフマイナー）- 1.5倍
## ID 343（ヨーウィ）- 1/2～2.5倍（可変）
## ID 411（グレートフォシル）- G0（固定値）
## ID 422（スチームギア）- 1/2（倍率）
