# クリーチャー情報パネルUI（シーン参照版）
# タイル配置クリーチャーの詳細表示と召喚時の確認ダイアログ
extends Control

class_name CreatureInfoPanelUI

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
@onready var element_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/ElementLabel
@onready var cost_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CostLabel
@onready var hp_ap_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/HpApLabel
@onready var restriction_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/RestrictionLabel
@onready var curse_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CurseLabel
@onready var skill_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/SkillContainer
@onready var skill_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/SkillContainer/SkillLabel
@onready var mystic_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/MysticContainer
@onready var mystic_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/MysticContainer/MysticLabel

# UIManager参照（グローバルボタン用）
var ui_manager_ref = null

# カード表示用
var card_display: Control

# 状態
var is_visible_panel: bool = false
var is_selection_mode: bool = false
var current_creature_data: Dictionary = {}
var current_tile_index: int = -1
var current_confirmation_text: String = ""

# 参照
var card_system = null

# カード表示スケール（固定値）
const CARD_SCALE = 1.12  # 0.8 × 1.4 = 1.12


func _ready():
	# 初期状態は非表示
	hide_panel()


func set_card_system(system) -> void:
	card_system = system


# === 公開メソッド ===

## UIManager参照を設定
func set_ui_manager(manager) -> void:
	ui_manager_ref = manager


## 閲覧モードで表示（タイル配置クリーチャー）
func show_view_mode(creature_data: Dictionary, tile_index: int = -1, setup_buttons: bool = true):
	current_creature_data = creature_data
	current_tile_index = tile_index
	is_selection_mode = false
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# グローバルボタン設定（閲覧モード：戻るのみ）
	# setup_buttons=falseの場合はスキップ（呼び出し側でナビゲーション管理）
	if setup_buttons and ui_manager_ref:
		ui_manager_ref.register_back_action(_on_back_action, "閉じる")


## 選択モードで表示（召喚/バトル時）
func show_selection_mode(creature_data: Dictionary, confirmation_text: String = "召喚しますか？"):
	current_creature_data = creature_data
	current_confirmation_text = confirmation_text
	is_selection_mode = true
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# グローバルボタン設定（選択モード：決定と戻る）
	if ui_manager_ref:
		var confirm_btn_text = "召喚"
		if "バトル" in confirmation_text:
			confirm_btn_text = "バトル"
		elif "侵略" in confirmation_text:
			confirm_btn_text = "侵略"
		elif "交換" in confirmation_text:
			confirm_btn_text = "交換"
		ui_manager_ref.register_global_actions(_on_confirm_action, _on_back_action, confirm_btn_text, "戻る")


## パネルを閉じる
func hide_panel(clear_buttons: bool = true):
	visible = false
	is_visible_panel = false
	current_creature_data = {}
	current_tile_index = -1
	
	if clear_buttons and ui_manager_ref:
		ui_manager_ref.clear_global_actions()
	
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
	# 既存のカード表示をクリア（即座に削除）
	if card_display and is_instance_valid(card_display):
		card_display.get_parent().remove_child(card_display)
		card_display.queue_free()
		card_display = null
	
	# 左パネルの他のカード表示も全てクリア
	if left_panel:
		var children_to_remove = []
		for child in left_panel.get_children():
			if child.has_method("load_card_data"):
				children_to_remove.append(child)
		for child in children_to_remove:
			left_panel.remove_child(child)
			child.queue_free()
	
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
	var card_id = current_creature_data.get("id", 0)
	if card_display.has_method("load_card_data"):
		card_display.load_card_data(card_id)


func _update_right_panel():
	var data = current_creature_data
	
	# 名前 + レア度
	if name_label:
		var rarity = data.get("rarity", "")
		name_label.text = "%s [%s]" % [data.get("name", "不明"), rarity]
	
	# 属性
	if element_label:
		var element = data.get("element", "")
		element_label.text = _get_element_display_name(element)
	
	# コスト
	if cost_label:
		var cost_value = data.get("cost", 0)
		var mp_cost = 0
		var lands_required = []
		if typeof(cost_value) == TYPE_DICTIONARY:
			mp_cost = cost_value.get("mp", 0)
			lands_required = cost_value.get("lands_required", [])
		else:
			mp_cost = cost_value if typeof(cost_value) == TYPE_INT else 0
			lands_required = data.get("cost_lands_required", [])
		var cost_text = "コスト: %dG" % mp_cost
		if not lands_required.is_empty():
			var lands_str = ""
			for land in lands_required:
				lands_str += _get_element_short_name(land)
			cost_text += " (%s)" % lands_str
		cost_label.text = cost_text
	
	# HP / AP
	if hp_ap_label:
		var hp = data.get("hp", 0)
		var ap = data.get("ap", 0)
		var current_hp = data.get("current_hp", hp)
		var max_hp = hp + data.get("base_up_hp", 0)
		var total_ap = ap + data.get("base_up_ap", 0)
		hp_ap_label.text = "HP: %d / %d    AP: %d" % [current_hp, max_hp, total_ap]
	
	# 配置制限 / アイテム制限
	if restriction_label:
		var restrictions = data.get("restrictions", {})
		var restriction_parts = []
		
		var cannot_summon = restrictions.get("cannot_summon", [])
		if not cannot_summon.is_empty():
			var summon_str = ""
			for elem in cannot_summon:
				summon_str += _get_element_short_name(elem)
			restriction_parts.append("配置制限: %s不可" % summon_str)
		else:
			restriction_parts.append("配置制限: なし")
		
		var cannot_use = restrictions.get("cannot_use", [])
		if not cannot_use.is_empty():
			restriction_parts.append("アイテム: %s" % ",".join(cannot_use))
		else:
			restriction_parts.append("アイテム: なし")
		
		restriction_label.text = "  ".join(restriction_parts)
	
	# 呪い
	if curse_label:
		var curse = data.get("curse", {})
		if curse.is_empty():
			curse_label.text = "【呪い】なし"
		else:
			var curse_name = curse.get("name", "不明")
			var duration = curse.get("duration", -1)
			if duration > 0:
				curse_label.text = "【呪い】%s（残り%dターン）" % [curse_name, duration]
			else:
				curse_label.text = "【呪い】%s" % curse_name
	
	# スキル
	if skill_container and skill_label:
		var ability_parsed = data.get("ability_parsed", {})
		var keywords = ability_parsed.get("keywords", [])
		if not keywords.is_empty():
			skill_container.visible = true
			var ability_detail = data.get("ability_detail", data.get("ability", ""))
			skill_label.text = ability_detail
		else:
			skill_container.visible = false
	
	# 秘術
	if mystic_container and mystic_label:
		var ability_parsed = data.get("ability_parsed", {})
		var mystic_art = ability_parsed.get("mystic_art", {})
		var mystic_arts = ability_parsed.get("mystic_arts", [])
		if not mystic_art.is_empty() or not mystic_arts.is_empty():
			mystic_container.visible = true
			var mystic_text = ""
			if not mystic_art.is_empty():
				mystic_text = "%s (%dG)" % [mystic_art.get("name", ""), mystic_art.get("cost", 0)]
			elif not mystic_arts.is_empty():
				var parts = []
				for ma in mystic_arts:
					parts.append("%s (%dG)" % [ma.get("name", ""), ma.get("cost", 0)])
				mystic_text = "\n".join(parts)
			mystic_label.text = mystic_text
		else:
			mystic_container.visible = false


func _get_element_display_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		"neutral": return "無"
		_: return element


func _get_element_short_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		_: return element


# === イベントハンドラ ===

func _on_confirm_action():
	if is_selection_mode:
		var data = current_creature_data
		hide_panel()
		selection_confirmed.emit(data)


func _on_back_action():
	if is_selection_mode:
		hide_panel()
		selection_cancelled.emit()
	else:
		hide_panel()
