class_name BattleCreatureDisplay
extends Control

## バトル画面のクリーチャー表示コンポーネント
## カード、HP/APバー、スキルラベル、ダメージポップアップを統合

signal attack_animation_completed
signal damage_animation_completed

const CARD_SIZE = Vector2(180, 250)
const ATTACK_MOVE_DISTANCE = 80.0
const SHAKE_AMOUNT = 10.0

var creature_data: Dictionary = {}
var is_attacker: bool = true

# 子ノード
var _card_display: Control
var _hp_ap_bar: HpApBar
var _skill_label: SkillLabel
var _card_texture: TextureRect
var _original_position: Vector2


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# カード表示エリア
	_card_display = Control.new()
	_card_display.custom_minimum_size = CARD_SIZE
	add_child(_card_display)
	
	# カード画像
	_card_texture = TextureRect.new()
	_card_texture.custom_minimum_size = CARD_SIZE
	_card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_display.add_child(_card_texture)
	
	# スキルラベル（カード上部）
	_skill_label = SkillLabel.new()
	_skill_label.position = Vector2((CARD_SIZE.x - 180) / 2, -40)
	add_child(_skill_label)
	
	# HP/APバー（カード下部）
	_hp_ap_bar = HpApBar.new()
	_hp_ap_bar.position = Vector2((CARD_SIZE.x - 200) / 2, CARD_SIZE.y + 10)
	add_child(_hp_ap_bar)
	
	custom_minimum_size = Vector2(CARD_SIZE.x, CARD_SIZE.y + 60)


## クリーチャーデータを設定
func setup(data: Dictionary, attacker: bool = true) -> void:
	creature_data = data
	is_attacker = attacker
	
	# カード画像を読み込み
	_load_card_image(data)
	
	# HP/APバーを初期化
	_update_hp_bar()
	_hp_ap_bar.set_ap(data.get("current_ap", data.get("ap", 0)))
	
	_original_position = position


## カード画像を読み込み
func _load_card_image(data: Dictionary) -> void:
	var card_id = data.get("id", 0)
	var image_path = "res://assets/cards/creatures/%d.png" % card_id
	
	if ResourceLoader.exists(image_path):
		_card_texture.texture = load(image_path)
	else:
		# デフォルト画像またはプレースホルダー
		_card_texture.texture = null
		# 背景色で代替
		var bg = ColorRect.new()
		bg.color = Color(0.3, 0.3, 0.3)
		bg.custom_minimum_size = CARD_SIZE
		_card_display.add_child(bg)
		bg.move_to_front()
		_card_texture.move_to_front()


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
	var original_x = _card_display.position.x
	
	# 揺れアニメーション
	for i in range(3):
		tween.tween_property(_card_display, "position:x", original_x + SHAKE_AMOUNT, 0.03)
		tween.tween_property(_card_display, "position:x", original_x - SHAKE_AMOUNT, 0.03)
	tween.tween_property(_card_display, "position:x", original_x, 0.03)
	
	await tween.finished
	damage_animation_completed.emit()


## ダメージポップアップを表示
func show_damage_popup(amount: int) -> void:
	var popup = DamagePopup.new()
	popup.position = Vector2(CARD_SIZE.x / 2, CARD_SIZE.y / 2)
	add_child(popup)
	popup.show_damage(amount)


## 回復ポップアップを表示
func show_heal_popup(amount: int) -> void:
	var popup = DamagePopup.new()
	popup.position = Vector2(CARD_SIZE.x / 2, CARD_SIZE.y / 2)
	add_child(popup)
	popup.show_heal(amount)


## バフポップアップを表示
func show_buff_popup(text: String) -> void:
	var popup = DamagePopup.new()
	popup.position = Vector2(CARD_SIZE.x / 2, CARD_SIZE.y / 2)
	add_child(popup)
	popup.show_buff(text)


## スライドイン
func slide_in(from_left: bool = true):
	var start_x = -CARD_SIZE.x if from_left else get_viewport_rect().size.x + CARD_SIZE.x
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
