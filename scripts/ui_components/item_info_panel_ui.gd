# アイテムカードの詳細表示と使用確認ダイアログ
extends Control

class_name ItemInfoPanelUI

# シグナル
signal selection_confirmed(card_data: Dictionary)
signal selection_cancelled
signal panel_closed

# UI要素（シーンから取得）
@onready var main_container: HBoxContainer = $MainContainer
@onready var right_panel: Control = $MainContainer/RightPanel

# 右パネルのラベル（シーンから取得）
@onready var name_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/NameContainer/NameLabel
@onready var rarity_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/NameContainer/RarityLabel
@onready var cost_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CostLabel
@onready var item_type_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/ItemTypeContainer/ItemTypeLabel
@onready var item_type_icon: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/ItemTypeContainer/ItemTypeIcon
@onready var stat_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/StatContainer
@onready var stat_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/StatContainer/StatLabel
@onready var effect_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/EffectContainer
@onready var effect_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/EffectContainer/EffectLabel

# UIManager参照（グローバルボタン用）
var ui_manager_ref = null

# 状態
var is_visible_panel: bool = false
var current_item_data: Dictionary = {}
var current_hand_index: int = -1


func _ready():
	# 初期状態は非表示
	hide_panel()


# === 公開メソッド ===

## UIManager参照を設定
func set_ui_manager(manager) -> void:
	ui_manager_ref = manager


## アイテム情報パネルを表示（使用確認モード）
func show_item_info(item_data: Dictionary, hand_index: int = -1):
	current_item_data = item_data
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
	current_item_data = {}
	current_hand_index = -1
	
	if clear_buttons and ui_manager_ref:
		ui_manager_ref.disable_navigation()
	
	panel_closed.emit()


## パネル表示中かどうか
func is_panel_visible() -> bool:
	return is_visible_panel


# === 内部メソッド ===

func _update_display():
	_update_right_panel()


func _update_right_panel():
	var data = current_item_data
	
	# 名前
	if name_label:
		name_label.text = data.get("name", "不明")
	
	# レア度
	if rarity_label:
		var rarity = data.get("rarity", "")
		rarity_label.text = "[%s]" % rarity if rarity else ""
	
	# コスト
	if cost_label:
		var cost_value = data.get("cost", {})
		var ep_cost = 0
		if typeof(cost_value) == TYPE_DICTIONARY:
			ep_cost = cost_value.get("ep", 0)
		else:
			ep_cost = cost_value if typeof(cost_value) == TYPE_INT else 0
		cost_label.text = "コスト: %dEP" % ep_cost
	
	# アイテムタイプ
	if item_type_label:
		var item_type = data.get("item_type", "")
		item_type_label.text = item_type if not item_type.is_empty() else "アイテム"
		
		# アイテムタイプアイコンを更新
		_update_item_type_icon(item_type)
	
	# ステータス変化
	if stat_label:
		var stat_text = _format_stat_bonus(data)
		if stat_text.is_empty():
			stat_container.visible = false
		else:
			stat_container.visible = true
			stat_label.text = stat_text
	
	# 効果テキスト
	if effect_label:
		var effect_text = data.get("effect", "")
		if effect_text.is_empty():
			effect_container.visible = false
		else:
			effect_container.visible = true
			effect_label.text = effect_text


func _update_item_type_icon(item_type: String) -> void:
	"""アイテムタイプアイコンを更新"""
	if not item_type_icon:
		return
	
	# アイテムタイプに応じた色を設定
	var color = Color.WHITE
	match item_type:
		"武器":
			color = Color("#ff6645")  # 赤オレンジ
		"防具":
			color = Color("#4566ff")  # 青
		"アクセサリ":
			color = Color("#45cc87")  # 緑
		"巻物":
			color = Color("#cc45ff")  # 紫
		_:
			color = Color("#aaaaaa")  # グレー
	
	item_type_icon.text = "▲"
	item_type_icon.add_theme_color_override("font_color", color)

## ステータスボーナスを整形
func _format_stat_bonus(data: Dictionary) -> String:
	var effect_parsed = data.get("effect_parsed", {})
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	
	if stat_bonus.is_empty():
		return ""
	
	var parts = []
	var ap = stat_bonus.get("ap", 0)
	var hp = stat_bonus.get("hp", 0)
	
	if ap != 0:
		var sign_str = "+" if ap > 0 else ""
		parts.append("AP%s%d" % [sign_str, ap])
	
	if hp != 0:
		var hp_sign_str = "+" if hp > 0 else ""
		parts.append("HP%s%d" % [hp_sign_str, hp])
	
	return "  ".join(parts)


# === イベントハンドラ ===

func _on_confirm_action():
	"""決定ボタン押下時"""
	var confirm_data = current_item_data.duplicate()
	confirm_data["hand_index"] = current_hand_index
	
	hide_panel()
	selection_confirmed.emit(confirm_data)


func _on_back_action():
	"""戻るボタン押下時"""
	# キャンセル時はナビゲーションをクリアしない（呼び出し元で再設定される）
	hide_panel(false)
	selection_cancelled.emit()
