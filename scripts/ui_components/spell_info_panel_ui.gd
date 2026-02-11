# スペルカードの詳細表示と使用確認ダイアログ
extends Control

class_name SpellInfoPanelUI

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
@onready var cost_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CostContainer/CostLabel
@onready var cost_icons: HBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CostContainer/CostIcons
@onready var spell_type_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/SpellTypeContainer/SpellTypeLabel
@onready var spell_type_icon: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/SpellTypeContainer/SpellTypeIcon
@onready var effect_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/EffectContainer
@onready var effect_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/EffectContainer/EffectLabel

# UIManager参照（グローバルボタン用）
var ui_manager_ref = null

# 状態
var is_visible_panel: bool = false
var is_info_only_mode: bool = false  # 閲覧専用モード（キャンセルシグナル発行しない）
var current_spell_data: Dictionary = {}
var current_hand_index: int = -1


func _ready():
	# 初期状態は非表示
	hide_panel()


# === 公開メソッド ===

## UIManager参照を設定
func set_ui_manager(manager) -> void:
	ui_manager_ref = manager


## スペル情報パネルを表示（使用確認モード）
## restriction_reason: ""=制限なし, "ep"=EP不足, "restriction"=呪い等
## current_selection_mode: 選択モード（spell, sacrifice, discard等）
func show_spell_info(spell_data: Dictionary, hand_index: int = -1, restriction_reason: String = "", current_selection_mode: String = "spell", custom_confirmation: String = ""):
	current_spell_data = spell_data
	current_hand_index = hand_index
	is_info_only_mode = false
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	var spell_name = spell_data.get("name", "スペル")
	
	if restriction_reason == "ep":
		# EP不足
		if ui_manager_ref and ui_manager_ref.phase_display:
			ui_manager_ref.phase_display.show_action_prompt("%s：EP不足" % spell_name, "right")
		# 戻るボタンのみ
		if ui_manager_ref:
			ui_manager_ref.register_back_action(func(): _on_back_action(), "戻る")
	elif restriction_reason == "restriction":
		# スペル不可呪い等
		if ui_manager_ref and ui_manager_ref.phase_display:
			ui_manager_ref.phase_display.show_action_prompt("%s：使用できません" % spell_name, "right")
		# 戻るボタンのみ
		if ui_manager_ref:
			ui_manager_ref.register_back_action(func(): _on_back_action(), "戻る")
	else:
		# 制限なし - 通常の確認
		var prompt_message = ""
		var confirm_text = "使用"
		var is_discard_mode = false
		if custom_confirmation != "":
			prompt_message = custom_confirmation
			confirm_text = "決定"
		elif current_selection_mode == "discard":
			prompt_message = "%sを捨てますか？" % spell_name
			confirm_text = "捨てる"
			is_discard_mode = true
		elif current_selection_mode == "sacrifice":
			prompt_message = "%sを犠牲にしますか？" % spell_name
			confirm_text = "犠牲"
		else:
			prompt_message = "%sを使用しますか？" % spell_name
		
		if ui_manager_ref and ui_manager_ref.phase_display:
			ui_manager_ref.phase_display.show_action_prompt(prompt_message, "right")
		
		# グローバルボタン設定
		if ui_manager_ref:
			if is_discard_mode:
				# 捨て札モードは戻るボタンなし（強制）、閉じるのみ
				ui_manager_ref.register_confirm_action(func(): _on_confirm_action(), confirm_text)
				ui_manager_ref.register_back_action(func(): _on_back_action(), "閉じる")
			else:
				ui_manager_ref.enable_navigation(
					func(): _on_confirm_action(),  # 決定: 使用/犠牲
					func(): _on_back_action()      # 戻る: キャンセル
				)


## 閲覧モードで表示
## setup_buttons=trueの場合は×ボタンで「閉じる」を登録
func show_view_mode(spell_data: Dictionary, setup_buttons: bool = false):
	current_spell_data = spell_data
	current_hand_index = -1
	is_info_only_mode = true
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# ボタン登録（オプション）
	if setup_buttons and ui_manager_ref:
		ui_manager_ref.register_back_action(_on_back_action, "閉じる")


## パネルを閉じる
func hide_panel(clear_buttons: bool = true):
	# 使用確認モードの場合はアクション指示を消す
	if not is_info_only_mode and ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.hide_action_prompt()
	
	visible = false
	is_visible_panel = false
	is_info_only_mode = false  # フラグをリセット
	current_spell_data = {}
	current_hand_index = -1
	
	if clear_buttons and ui_manager_ref:
		if ui_manager_ref._nav_state_saved:
			ui_manager_ref.restore_navigation_state()
		else:
			ui_manager_ref.disable_navigation()
	
	panel_closed.emit()


## パネル表示中かどうか
func is_panel_visible() -> bool:
	return is_visible_panel


# === 内部メソッド ===

func _update_display():
	_update_right_panel()


func _update_right_panel():
	var data = current_spell_data
	
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
		var cards_sacrifice = 0
		if typeof(cost_value) == TYPE_DICTIONARY:
			ep_cost = cost_value.get("ep", 0)
			cards_sacrifice = cost_value.get("cards_sacrifice", 0)
		else:
			ep_cost = cost_value if typeof(cost_value) == TYPE_INT else 0
		cost_label.text = "コスト: %dEP" % ep_cost
		
		# 犠牲カードアイコンを追加
		_update_cost_icons(cards_sacrifice)
	
	# スペルタイプ（対象タイプ）
	if spell_type_label:
		var spell_type = data.get("spell_type", "")
		spell_type_label.text = spell_type if not spell_type.is_empty() else "その他"
		
		# スペルタイプアイコンを更新
		_update_spell_type_icon(spell_type)
	
	# 効果テキスト
	if effect_label:
		var effect_text = data.get("effect", "")
		effect_label.text = effect_text if not effect_text.is_empty() else "効果なし"

func _update_cost_icons(cards_sacrifice: int) -> void:
	"""犠牲カードアイコンを更新"""
	if not cost_icons:
		return
	
	# 既存のアイコンをクリア
	for child in cost_icons.get_children():
		child.queue_free()
	
	# 犠牲カードアイコンを追加
	if cards_sacrifice > 0:
		var sacrifice_texture = load("res://assets/ui/sacrifice_card.png")
		if sacrifice_texture:
			for i in range(cards_sacrifice):
				var icon = TextureRect.new()
				icon.texture = sacrifice_texture
				icon.custom_minimum_size = Vector2(32, 32)
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				cost_icons.add_child(icon)

func _update_spell_type_icon(spell_type: String) -> void:
	"""スペルタイプアイコンを更新"""
	if not spell_type_icon:
		return
	
	# スペルタイプに応じた色を設定
	var color = Color.WHITE
	match spell_type:
		"単体対象":
			color = Color("#ff4545")  # 赤
		"単体特殊能力付与":
			color = Color("#45ff87")  # 緑
		"複数対象":
			color = Color("#ffaa45")  # オレンジ
		"複数特殊能力付与":
			color = Color("#45ccff")  # 水色
		"世界呪":
			color = Color("#aa45ff")  # 紫
		_:
			color = Color("#aaaaaa")  # グレー
	
	spell_type_icon.text = "◆"
	spell_type_icon.add_theme_color_override("font_color", color)


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
