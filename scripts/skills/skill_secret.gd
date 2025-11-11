extends Node
class_name SkillSecret

## 密命（Secret Mission）スキル処理クラス
## 
## 役割:
## - 密命カードの条件判定
## - 密命の成功/失敗処理
## - 失敗効果の実行（復帰[ブック]等）
##
## 使用方法:
## ```gdscript
## var result = SkillSecret.check_mission(spell_card, context)
## if result.is_mission and not result.success:
##     # 失敗処理
## ```

## 密命判定を実行
## @param spell_card: スペルカードデータ
## @param context: 判定に必要なコンテキスト情報
## @return Dictionary: { "success": bool, "is_mission": bool, "failure_effect": String }
static func check_mission(spell_card: Dictionary, context: Dictionary) -> Dictionary:
	var checker = ConditionChecker.new()
	return checker.check_secret_mission(spell_card, context)

## カードが密命カードかチェック（表示用フラグ）
## @param card_data: カードデータ
## @return bool: is_secretフラグの値
static func is_secret_card(card_data: Dictionary) -> bool:
	return card_data.get("is_secret", false)

## 密命キーワードが定義されているかチェック
## @param card_data: カードデータ
## @return bool: keywords配列に"密命"が含まれているか
static func has_secret_keyword(card_data: Dictionary) -> bool:
	var effect_parsed = card_data.get("effect_parsed", {})
	var keywords = effect_parsed.get("keywords", [])
	return "密命" in keywords

## 密命の成功条件を取得
## @param spell_card: スペルカードデータ
## @return Array: 成功条件の配列
static func get_success_conditions(spell_card: Dictionary) -> Array:
	var effect_parsed = spell_card.get("effect_parsed", {})
	var keyword_conditions = effect_parsed.get("keyword_conditions", {})
	var mission_data = keyword_conditions.get("密命", {})
	return mission_data.get("success_conditions", [])

## 密命の失敗効果を取得
## @param spell_card: スペルカードデータ
## @return String: 失敗効果の種類（"return_to_deck", "none"等）
static func get_failure_effect(spell_card: Dictionary) -> String:
	var effect_parsed = spell_card.get("effect_parsed", {})
	var keyword_conditions = effect_parsed.get("keyword_conditions", {})
	var mission_data = keyword_conditions.get("密命", {})
	return mission_data.get("failure_effect", "return_to_deck")

## 密命コンテキストを構築（SpellPhaseHandlerで使用）
## @param player_id: プレイヤーID
## @param board_system: BoardSystem3D参照
## @param creature_manager: CreatureManager参照
## @param card_system: CardSystem参照
## @param target_data: ターゲット情報
## @return Dictionary: 密命判定用のコンテキスト
static func build_mission_context(
	player_id: int,
	board_system,
	creature_manager,
	card_system,
	target_data: Dictionary
) -> Dictionary:
	return {
		"player_id": player_id,
		"board_system": board_system,
		"creature_manager": creature_manager,
		"hand_cards": card_system.get_all_cards_for_player(player_id) if card_system else [],
		"target_data": target_data
	}

## 密命失敗時のログ出力
## @param player_id: プレイヤーID
## @param spell_card: スペルカードデータ
static func log_mission_failure(player_id: int, spell_card: Dictionary) -> void:
	print("[密命失敗] プレイヤー%d が密命カード「%s」を使用 - 条件未達成" % [
		player_id,
		spell_card.get("name", "???")
	])

## 密命成功時のログ出力
## @param player_id: プレイヤーID
## @param spell_card: スペルカードデータ
static func log_mission_success(player_id: int, spell_card: Dictionary) -> void:
	print("[密命成功] プレイヤー%d が密命カード「%s」を使用 - 条件達成" % [
		player_id,
		spell_card.get("name", "???")
	])
