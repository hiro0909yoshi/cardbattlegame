# スペルカードの詳細表示と使用確認ダイアログ
extends Control

class_name SpellInfoPanelUI

# シグナル
signal selection_confirmed(card_data: Dictionary)
signal selection_cancelled
signal panel_closed

# UI要素（シーンから取得）
@onready var main_container: HBoxContainer = $MainContainer
@onready var left_panel: Control = $MainContainer/LeftPanel
@onready var right_panel: Control = $MainContainer/RightPanel

# 右パネルのラベル（シーンから取得）
@onready var name_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/NameLabel
@onready var cost_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CostLabel
@onready var spell_type_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/SpellTypeLabel
@onready var effect_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/EffectContainer
@onready var effect_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/EffectContainer/EffectLabel

# UIManager参照（グローバルボタン用）
var ui_manager_ref = null

# カード表示用
var card_display: Control

# 状態
var is_visible_panel: bool = false
var current_spell_data: Dictionary = {}
var current_hand_index: int = -1

# カード表示スケール（固定値）
const CARD_SCALE = 1.12


func _ready():
	# 初期状態は非表示
	hide_panel()


# === 公開メソッド ===

## UIManager参照を設定
func set_ui_manager(manager) -> void:
	ui_manager_ref = manager


## スペル情報パネルを表示（使用確認モード）
func show_spell_info(spell_data: Dictionary, hand_index: int = -1):
	current_spell_data = spell_data
	current_hand_index = hand_index
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# グローバルボタン設定（決定と戻る）
	if ui_manager_ref:
		ui_manager_ref.enable_navigation(
			func(): _on_confirm_action(),  # 決定: 使用
			func(): _on_back_action()      # 戻る: キャンセル
		)


## パネルを閉じる
func hide_panel(clear_buttons: bool = true):
	visible = false
	is_visible_panel = false
	current_spell_data = {}
	current_hand_index = -1
	
	if clear_buttons and ui_manager_ref:
		ui_manager_ref.disable_navigation()
	
	# カード表示をクリア
	if card_display and is_instance_valid(card_display):
		card_display.queue_free()
		card_display = null
	
	panel_closed.emit()


## パネル表示中かどうか
func is_panel_visible() -> bool:
	return is_visible_panel


# === 内部メソッド ===

func _update_display():
	_update_card_display()
	_update_right_panel()


func _update_card_display():
	# 既存のカード表示をクリア
	if card_display and is_instance_valid(card_display):
		card_display.queue_free()
		card_display = null
	
	if not left_panel:
		return
	
	# カードシーンをロードして表示
	var card_scene = preload("res://scenes/Card.tscn")
	card_display = card_scene.instantiate()
	
	# 固定スケール
	card_display.scale = Vector2(CARD_SCALE, CARD_SCALE)
	
	left_panel.add_child(card_display)
	
	# カード位置（左パネル内で中央寄せ）
	card_display.position = Vector2(0, 0)
	
	# カードデータを設定
	var card_id = current_spell_data.get("id", 0)
	if card_display.has_method("load_card_data"):
		card_display.load_card_data(card_id)


func _update_right_panel():
	var data = current_spell_data
	
	# 名前 + レア度
	if name_label:
		var rarity = data.get("rarity", "")
		name_label.text = "%s [%s]" % [data.get("name", "不明"), rarity]
	
	# コスト
	if cost_label:
		var cost_value = data.get("cost", {})
		var mp_cost = 0
		if typeof(cost_value) == TYPE_DICTIONARY:
			mp_cost = cost_value.get("mp", 0)
		else:
			mp_cost = cost_value if typeof(cost_value) == TYPE_INT else 0
		cost_label.text = "コスト: %dG" % mp_cost
	
	# スペルタイプ（対象タイプ）
	if spell_type_label:
		var spell_type = data.get("spell_type", "")
		spell_type_label.text = spell_type if not spell_type.is_empty() else "その他"
	
	# 効果テキスト
	if effect_label:
		var effect_text = data.get("effect", "")
		effect_label.text = effect_text if not effect_text.is_empty() else "効果なし"


# === イベントハンドラ ===

func _on_confirm_action():
	"""決定ボタン押下時"""
	var confirm_data = current_spell_data.duplicate()
	confirm_data["hand_index"] = current_hand_index
	
	hide_panel()
	selection_confirmed.emit(confirm_data)


func _on_back_action():
	"""戻るボタン押下時"""
	# キャンセル時はナビゲーションをクリアしない（呼び出し元で再設定される）
	hide_panel(false)
	selection_cancelled.emit()
