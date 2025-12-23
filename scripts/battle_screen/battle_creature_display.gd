class_name BattleCreatureDisplay
extends Control

## バトル画面のクリーチャー表示コンポーネント
## カード、HP/APバー、スキルラベル、ダメージポップアップを統合

signal attack_animation_completed
signal damage_animation_completed

const CARD_SCENE_PATH = "res://scenes/Card.tscn"
const CARD_DISPLAY_SIZE = Vector2(220, 293)  # Card.tscnの元サイズ
const CARD_SCALE = 3.9  # バトル画面での表示スケール（3.0 * 1.3）
const ATTACK_MOVE_DISTANCE = 80.0
const SHAKE_AMOUNT = 10.0

var creature_data: Dictionary = {}
var is_attacker: bool = true

# 子ノード
var _card_container: Control
var _card_instance: Control  # Card.tscnのインスタンス
var _hp_ap_bar: HpApBar
var _skill_label: SkillLabel
var _original_position: Vector2

# カードシーン（プリロード）
var _card_scene: PackedScene


func _ready() -> void:
	_card_scene = load(CARD_SCENE_PATH)
	_setup_ui()


func _setup_ui() -> void:
	var scaled_size = CARD_DISPLAY_SIZE * CARD_SCALE
	
	# カード表示コンテナ
	_card_container = Control.new()
	_card_container.custom_minimum_size = scaled_size
	add_child(_card_container)
	
	# スキルラベル（カード上部）
	_skill_label = SkillLabel.new()
	_skill_label.position = Vector2((scaled_size.x - 300) / 2, -70)
	add_child(_skill_label)
	
	# HP/APバー（カード下部）- 5.2倍サイズ対応
	_hp_ap_bar = HpApBar.new()
	_hp_ap_bar.position = Vector2((scaled_size.x - 1040) / 2, scaled_size.y + 30)
	add_child(_hp_ap_bar)
	
	custom_minimum_size = Vector2(scaled_size.x, scaled_size.y + 260)


## クリーチャーデータを設定
func setup(data: Dictionary, attacker: bool = true, show_hp_bar: bool = true) -> void:
	creature_data = data
	is_attacker = attacker
	
	# 実際のカードをインスタンス化して表示
	_create_card_instance(data)
	
	# HP/APバーの表示切り替え
	if show_hp_bar:
		_hp_ap_bar.visible = true
		_update_hp_bar()
		_hp_ap_bar.set_ap(data.get("current_ap", data.get("ap", 0)))
	else:
		_hp_ap_bar.visible = false
	
	_original_position = position


## Card.tscnをインスタンス化してデータを設定
func _create_card_instance(data: Dictionary) -> void:
	# 既存のカードインスタンスを削除
	if _card_instance:
		_card_instance.queue_free()
		_card_instance = null
	
	if not _card_scene:
		push_error("BattleCreatureDisplay: Card.tscn が読み込めません")
		return
	
	# カードをインスタンス化
	_card_instance = _card_scene.instantiate()
	_card_container.add_child(_card_instance)
	
	# スケール設定
	_card_instance.scale = Vector2(CARD_SCALE, CARD_SCALE)
	
	# マウスイベントを無効化（バトル画面では選択不要）
	_card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_filter_recursive(_card_instance, Control.MOUSE_FILTER_IGNORE)
	
	# クリーチャーデータを設定
	if _card_instance.has_method("load_dynamic_creature_data"):
		_card_instance.load_dynamic_creature_data(data)
	elif _card_instance.has_method("load_card_data"):
		var card_id = data.get("id", 0)
		_card_instance.load_card_data(card_id)


## 子ノードのマウスフィルターを再帰的に設定
func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


## HPバーを更新
func _update_hp_bar() -> void:
	var hp_data = {
		"base_hp": creature_data.get("hp", 0),
		"base_up_hp": creature_data.get("base_up_hp", 0),
		"item_bonus_hp": creature_data.get("item_bonus_hp", 0),
		"resonance_bonus_hp": creature_data.get("resonance_bonus_hp", 0),
		"temporary_bonus_hp": creature_data.get("temporary_bonus_hp", 0),
		"spell_bonus_hp": creature_data.get("spell_bonus_hp", 0),
		"land_bonus_hp": creature_data.get("land_bonus_hp", 0),
		"current_hp": creature_data.get("current_hp", creature_data.get("hp", 0)),
		"display_max": _calculate_display_max()
	}
	_hp_ap_bar.set_hp_data(hp_data)


func _calculate_display_max() -> int:
	var total = creature_data.get("hp", 0) + \
				creature_data.get("base_up_hp", 0) + \
				creature_data.get("item_bonus_hp", 0) + \
				creature_data.get("resonance_bonus_hp", 0) + \
				creature_data.get("temporary_bonus_hp", 0) + \
				creature_data.get("spell_bonus_hp", 0) + \
				creature_data.get("land_bonus_hp", 0)
	return max(total, 100)


## スキル名を表示
func show_skill(skill_name: String) -> void:
	_skill_label.show_skill(skill_name)


## HPを更新（アニメーション付き）
func update_hp(new_data: Dictionary):
	creature_data.merge(new_data, true)
	var hp_data = {
		"base_hp": creature_data.get("hp", 0),
		"base_up_hp": creature_data.get("base_up_hp", 0),
		"item_bonus_hp": creature_data.get("item_bonus_hp", 0),
		"resonance_bonus_hp": creature_data.get("resonance_bonus_hp", 0),
		"temporary_bonus_hp": creature_data.get("temporary_bonus_hp", 0),
		"spell_bonus_hp": creature_data.get("spell_bonus_hp", 0),
		"land_bonus_hp": creature_data.get("land_bonus_hp", 0),
		"current_hp": new_data.get("current_hp", creature_data.get("current_hp", 0)),
		"display_max": _calculate_display_max()
	}
	await _hp_ap_bar.animate_hp_change(hp_data)


## APを更新
func update_ap(new_ap: int) -> void:
	creature_data["current_ap"] = new_ap
	_hp_ap_bar.animate_ap_change(new_ap)


## クリーチャーを更新（変身時など）
func update_creature(new_data: Dictionary) -> void:
	creature_data = new_data
	# カード表示を再作成
	_create_card_instance(new_data)
	# HP/APバーも更新
	_update_hp_bar()
	_hp_ap_bar.set_ap(new_data.get("current_ap", new_data.get("ap", 0)))


## 攻撃アニメーション
func play_attack_animation():
	var direction = 1.0 if is_attacker else -1.0
	var target_x = _original_position.x + (ATTACK_MOVE_DISTANCE * direction)
	
	var tween = create_tween()
	# 前に移動
	tween.tween_property(self, "position:x", target_x, 0.15).set_ease(Tween.EASE_OUT)
	# 戻る
	tween.tween_property(self, "position:x", _original_position.x, 0.15).set_ease(Tween.EASE_IN)
	
	await tween.finished
	attack_animation_completed.emit()


## 被ダメージアニメーション（揺れ）
func play_damage_animation():
	var tween = create_tween()
	var original_x = _card_container.position.x
	
	# 揺れアニメーション
	for i in range(3):
		tween.tween_property(_card_container, "position:x", original_x + SHAKE_AMOUNT, 0.03)
		tween.tween_property(_card_container, "position:x", original_x - SHAKE_AMOUNT, 0.03)
	tween.tween_property(_card_container, "position:x", original_x, 0.03)
	
	await tween.finished
	damage_animation_completed.emit()


## ダメージポップアップを表示
func show_damage_popup(amount: int) -> void:
	var scaled_size = CARD_DISPLAY_SIZE * CARD_SCALE
	var popup = DamagePopup.new()
	popup.position = Vector2(scaled_size.x / 2, scaled_size.y / 2)
	add_child(popup)
	popup.show_damage(amount)


## 回復ポップアップを表示
func show_heal_popup(amount: int) -> void:
	var scaled_size = CARD_DISPLAY_SIZE * CARD_SCALE
	var popup = DamagePopup.new()
	popup.position = Vector2(scaled_size.x / 2, scaled_size.y / 2)
	add_child(popup)
	popup.show_heal(amount)


## バフポップアップを表示
func show_buff_popup(text: String) -> void:
	var scaled_size = CARD_DISPLAY_SIZE * CARD_SCALE
	var popup = DamagePopup.new()
	popup.position = Vector2(scaled_size.x / 2, scaled_size.y / 2)
	add_child(popup)
	popup.show_buff(text)


## スライドイン
func slide_in(from_left: bool = true):
	var scaled_size = CARD_DISPLAY_SIZE * CARD_SCALE
	var start_x = -scaled_size.x if from_left else get_viewport_rect().size.x + scaled_size.x
	position.x = start_x
	
	var tween = create_tween()
	tween.tween_property(self, "position:x", _original_position.x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished


## 敗北演出（フェードアウト＋落下）
func play_defeat_animation():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(self, "position:y", position.y + 100, 0.5).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", deg_to_rad(-15 if is_attacker else 15), 0.5)
	await tween.finished
