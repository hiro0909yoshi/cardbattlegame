## SpellStrategy - 基底インターフェース（全スペル戦略の親クラス）
class_name SpellStrategy
extends RefCounted

## スペル戦略の基本インターフェース
## 各スペル固有の実装は派生クラスで override する

## バリデーション（実行前の条件チェック）
## 戻り値: true = 実行可能、false = 実行不可
func validate(_context: Dictionary) -> bool:
	push_error("[SpellStrategy] validate() を実装してください")
	return false

## 実行（スペル効果の適用）
## 戻り値: effect_message を含む Dictionary
func execute(_context: Dictionary) -> Dictionary:
	push_error("[SpellStrategy] execute() を実装してください")
	return { "effect_message": "" }

## ================================================================================
## ヘルパーメソッド
## ================================================================================

## Level 1: 必須キーの存在確認
## context に指定されたキーが全て存在するか確認
func _validate_context_keys(context: Dictionary, required_keys: Array) -> bool:
	# ★ NEW: null チェック（第0段階）
	if not context:
		_log_error("context が null です")
		return false

	var missing_keys = []
	for key in required_keys:
		if key not in context:
			missing_keys.append(key)

	if missing_keys.size() > 0:
		_log_error("必須キーが見つかりません: %s" % missing_keys)
		return false

	return true

## Level 2: 参照実体のnull確認
## context の指定キーに対応する値が null でないか確認
func _validate_references(context: Dictionary, ref_keys: Array) -> bool:
	# ★ ENHANCED: より詳細なログ
	var null_refs = []
	for key in ref_keys:
		var ref = context.get(key)
		if ref == null:
			null_refs.append(key)

	if null_refs.size() > 0:
		_log_error("null 参照が見つかります: %s" % null_refs)
		# ★ NEW: コンテキスト内容をダンプ
		for key in null_refs:
			print("  - %s: null" % key)
		return false

	return true

## Level 3: スペル固有の条件確認（派生クラスで実装）
## 例: ターゲットの有効性、プレイヤーのリソース（EP等）、タイルの状態
func _validate_spell_conditions(_context: Dictionary) -> bool:
	# 派生クラスで override する
	return true

## ================================================================================
## Logging Helper
## ================================================================================

## デバッグログ出力（ファイル名を自動付与）
func _log(message: String) -> void:
	print("[%s] %s" % [get_class(), message])

## エラーログ出力（ファイル名を自動付与）
func _log_error(message: String) -> void:
	push_error("[%s] %s" % [get_class(), message])
