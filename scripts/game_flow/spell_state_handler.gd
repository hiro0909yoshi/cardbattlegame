# SpellStateHandler - スペルフェーズの状態管理を一元化
extends RefCounted
class_name SpellStateHandler

## ===== State enum =====
enum State {
	INACTIVE,
	WAITING_FOR_INPUT,  # スペル選択またはダイス待ち
	SELECTING_TARGET,    # 対象選択中
	CONFIRMING_EFFECT,   # 効果確認中（全体対象等）
	EXECUTING_EFFECT     # 効果実行中
}

## ===== 状態変数（55個） =====

# フェーズ管理
var current_state: State = State.INACTIVE
var current_player_id: int = -1

# スペル選択
var selected_spell_card: Dictionary = {}
var spell_used_this_turn: bool = false  # 1ターン1回制限

# スペルスキップフラグ
var skip_dice_phase: bool = false  # ワープ系スペル使用時はサイコロフェーズをスキップ

# 確認フェーズ用
var confirmation_target_type: String = ""
var confirmation_target_info: Dictionary = {}
var confirmation_target_data: Dictionary = {}

# カード犠牲の一時保存（ターゲット選択後に消費）
var pending_sacrifice_card: Dictionary = {}

# スペル失敗フラグ
var spell_failed: bool = false  # 復帰[ブック]フラグ（条件不成立でデッキに戻る）

# 外部スペルモード（魔法タイル等で使用）
# trueの場合、手札からの削除・捨て札処理をスキップ
var is_external_spell_mode: bool = false
var is_magic_tile_mode: bool = false  # マジックタイル経由（刻印duration調整用）
var _external_spell_cancelled: bool = false  # キャンセルフラグ
var _external_spell_no_target: bool = false  # 対象不在フラグ

# 借用スペル実行中フラグ
var is_borrow_spell_mode: bool = false

## ===== 初期化 =====
func _init() -> void:
	reset_turn_state()

## ===== 状態遷移 =====

## 状態を遷移する（バリデーション付き）
func transition_to(new_state: State) -> void:
	"""状態遷移（バリデーション付き）"""
	# TODO: 状態遷移のバリデーション（必要に応じて）
	current_state = new_state

## ===== アクセサメソッド =====

## ターン状態をリセット
func reset_turn_state() -> void:
	current_state = State.INACTIVE
	current_player_id = -1
	selected_spell_card = {}
	confirmation_target_type = ""
	confirmation_target_info = {}
	confirmation_target_data = {}
	pending_sacrifice_card = {}
	spell_used_this_turn = false
	skip_dice_phase = false
	spell_failed = false
	is_external_spell_mode = false
	is_magic_tile_mode = false
	_external_spell_cancelled = false
	_external_spell_no_target = false
	is_borrow_spell_mode = false

## 現在の状態を取得
func get_current_state() -> State:
	return current_state

## 状態が指定の状態か確認
func is_state(state: State) -> bool:
	return current_state == state

## 現在のプレイヤーIDを取得
func get_current_player_id() -> int:
	return current_player_id

## 現在のプレイヤーIDを設定
func set_current_player_id(player_id: int) -> void:
	current_player_id = player_id

## スペルカードを設定
func set_spell_card(card: Dictionary) -> void:
	selected_spell_card = card

## スペルカードを取得
func get_spell_card() -> Dictionary:
	return selected_spell_card

## スペルカードをクリア
func clear_spell_card() -> void:
	selected_spell_card = {}

## スペルが使用済みか確認
func is_spell_used_this_turn() -> bool:
	return spell_used_this_turn

## スペル使用済みフラグを設定
func set_spell_used_this_turn(used: bool) -> void:
	spell_used_this_turn = used

## 確認状態を設定
func set_confirmation_state(target_type: String, target_info: Dictionary, target_data: Dictionary) -> void:
	confirmation_target_type = target_type
	confirmation_target_info = target_info
	confirmation_target_data = target_data

## 確認状態を取得
func get_confirmation_state() -> Dictionary:
	return {
		"target_type": confirmation_target_type,
		"target_info": confirmation_target_info,
		"target_data": confirmation_target_data
	}

## 確認状態をクリア
func clear_confirmation_state() -> void:
	confirmation_target_type = ""
	confirmation_target_info = {}
	confirmation_target_data = {}

## 確認状態の対象タイプを取得
func get_confirmation_target_type() -> String:
	return confirmation_target_type

## 確認状態の対象情報を取得
func get_confirmation_target_info() -> Dictionary:
	return confirmation_target_info

## 確認状態の対象データを取得
func get_confirmation_target_data() -> Dictionary:
	return confirmation_target_data

## 犠牲カードを設定
func set_pending_sacrifice_card(card: Dictionary) -> void:
	pending_sacrifice_card = card

## 犠牲カードを取得
func get_pending_sacrifice_card() -> Dictionary:
	return pending_sacrifice_card

## 犠牲カードをクリア
func clear_pending_sacrifice_card() -> void:
	pending_sacrifice_card = {}

## サイコロフェーズをスキップするか確認
func should_skip_dice_phase() -> bool:
	return skip_dice_phase

## サイコロフェーズスキップフラグを設定
func set_skip_dice_phase(skip: bool) -> void:
	skip_dice_phase = skip

## 外部スペルモードを設定
func set_external_spell_mode(enabled: bool, from_magic_tile: bool = false) -> void:
	is_external_spell_mode = enabled
	is_magic_tile_mode = from_magic_tile
	if not enabled:
		_external_spell_cancelled = false
		_external_spell_no_target = false

## 外部スペルモードを取得
func is_in_external_spell_mode() -> bool:
	return is_external_spell_mode

## マジックタイルモードを取得
func is_in_magic_tile_mode() -> bool:
	return is_magic_tile_mode

## 外部スペルがキャンセルされたかを取得
func was_external_spell_cancelled() -> bool:
	return _external_spell_cancelled

## 外部スペルキャンセルフラグを設定
func set_external_spell_cancelled(cancelled: bool) -> void:
	_external_spell_cancelled = cancelled

## 外部スペルに対象がなかったかを取得
func was_external_spell_no_target() -> bool:
	return _external_spell_no_target

## 外部スペル対象不在フラグを設定
func set_external_spell_no_target(no_target: bool) -> void:
	_external_spell_no_target = no_target

## 外部スペル結果を取得
func get_external_spell_result() -> Dictionary:
	return {
		"cancelled": _external_spell_cancelled,
		"no_target": _external_spell_no_target
	}

## 借用スペルモードを設定
func set_borrow_spell_mode(enabled: bool) -> void:
	is_borrow_spell_mode = enabled

## 借用スペルモードを取得
func is_in_borrow_spell_mode() -> bool:
	return is_borrow_spell_mode

## スペル失敗フラグを設定
func set_spell_failed(failed: bool) -> void:
	spell_failed = failed

## スペル失敗フラグを取得
func is_spell_failed() -> bool:
	return spell_failed

## スペル使用可能か確認
func can_use_spell() -> bool:
	return current_state == State.WAITING_FOR_INPUT and not spell_used_this_turn

## スペルフェーズがアクティブか確認
func is_spell_phase_active() -> bool:
	return current_state != State.INACTIVE

## 対象選択中か確認
func is_selecting_target() -> bool:
	return current_state == State.SELECTING_TARGET

## 確認フェーズ中か確認
func is_confirming_effect() -> bool:
	return current_state == State.CONFIRMING_EFFECT

## 効果実行中か確認
func is_executing_effect() -> bool:
	return current_state == State.EXECUTING_EFFECT
