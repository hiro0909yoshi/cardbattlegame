class_name BattleScreenManager
extends Node

## バトル画面マネージャー
## 既存のBattleSystemから呼び出されるインターフェース

signal intro_completed
signal skill_animation_completed
signal attack_animation_completed
@warning_ignore("unused_signal")
signal battle_screen_opened  # 将来使用予定
signal battle_screen_closed

# 参照
var _battle_screen: BattleScreen
var _transition_layer: TransitionLayer
var _is_battle_active := false


func _ready() -> void:
	# トランジションレイヤーを作成
	_transition_layer = TransitionLayer.new()
	add_child(_transition_layer)


## バトルを開始
func start_battle(attacker_data: Dictionary, defender_data: Dictionary, _item_data = null):
	if _is_battle_active:
		push_warning("BattleScreenManager: バトルが既にアクティブです")
		return
	
	_is_battle_active = true
	
	# トランジション（フェードアウト）
	await _transition_layer.fade_out(true)
	
	# バトル画面を作成
	_battle_screen = BattleScreen.new()
	add_child(_battle_screen)
	_battle_screen.initialize(attacker_data, defender_data)
	
	# トランジション（フェードイン）
	await _transition_layer.fade_in()
	
	# イントロ演出
	await _battle_screen.play_intro()
	
	intro_completed.emit()


## スキル発動演出を表示
func show_skill_activation(side: String, skill_name: String, effects: Dictionary = {}):
	if not _battle_screen:
		return
	
	await _battle_screen.show_skill_activation(side, skill_name)
	
	# HP/AP変更があれば適用（同時開始、完了を待つ）
	if effects.has("hp_data") and effects.has("ap"):
		# 両方同時に開始
		_battle_screen.show_hp_change(side, effects["hp_data"])
		_battle_screen.show_ap_change(side, effects["ap"])
		# アニメーション時間分待つ
		await _battle_screen.get_tree().create_timer(1.5).timeout
	elif effects.has("hp_data"):
		await _battle_screen.show_hp_change(side, effects["hp_data"])
	elif effects.has("ap"):
		await _battle_screen.show_ap_change(side, effects["ap"])
	
	# バフ表示
	if effects.has("buff_text"):
		_battle_screen.show_buff_popup(side, effects["buff_text"])
	
	skill_animation_completed.emit()


## 攻撃演出を表示
func show_attack(attacker_side: String, damage: int):
	if not _battle_screen:
		return
	
	await _battle_screen.show_attack(attacker_side, damage)
	attack_animation_completed.emit()


## ダメージ表示
func show_damage(side: String, amount: int) -> void:
	if not _battle_screen:
		return
	
	_battle_screen.show_damage_popup(side, amount)


## HP更新
func update_hp(side: String, hp_data: Dictionary):
	if not _battle_screen:
		return
	
	await _battle_screen.show_hp_change(side, hp_data)


## AP更新
func update_ap(side: String, value: int):
	if not _battle_screen:
		return
	
	await _battle_screen.show_ap_change(side, value)


## バトル結果表示（画面は閉じない）
func show_battle_result(result: int):
	if not _battle_screen:
		return
	
	# 結果演出
	await _battle_screen.show_result(result)


## バトル終了（後方互換性のため残す - 結果表示+画面を閉じる）
func end_battle(result: int):
	await show_battle_result(result)
	await close_battle_screen()


## バトル画面を閉じる
func close_battle_screen():
	if not _battle_screen:
		_is_battle_active = false
		battle_screen_closed.emit()
		return
	
	# トランジション（フェードアウト）
	await _transition_layer.quick_fade_out()
	
	# バトル画面を削除
	_battle_screen.queue_free()
	_battle_screen = null
	
	# トランジション（フェードイン）
	await _transition_layer.quick_fade_in()
	
	_is_battle_active = false
	battle_screen_closed.emit()


## バトルがアクティブかどうか
func is_battle_active() -> bool:
	return _is_battle_active


## 強制終了（エラー時など）
func force_close() -> void:
	if _battle_screen:
		_battle_screen.queue_free()
		_battle_screen = null
	
	_transition_layer.quick_fade_in()
	_is_battle_active = false
	battle_screen_closed.emit()


## BattleParticipantからHP表示用データを作成
static func create_hp_data_from_participant(participant) -> Dictionary:
	return {
		"base_hp": participant.base_hp,
		"base_up_hp": participant.base_up_hp,
		"item_bonus_hp": participant.item_bonus_hp,
		"resonance_bonus_hp": participant.resonance_bonus_hp,
		"temporary_bonus_hp": participant.temporary_bonus_hp,
		"spell_bonus_hp": participant.spell_bonus_hp,
		"land_bonus_hp": participant.land_bonus_hp,
		"current_hp": participant.current_hp,
		"display_max": participant.base_hp + participant.base_up_hp + \
					   participant.item_bonus_hp + participant.resonance_bonus_hp + \
					   participant.temporary_bonus_hp + participant.spell_bonus_hp + \
					   participant.land_bonus_hp
	}
