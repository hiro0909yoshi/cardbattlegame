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
@onready var right_panel: Control = $MainContainer/RightPanel

# 右パネルのラベル（シーンから取得）
@onready var name_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/NameContainer/NameLabel
@onready var rarity_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/NameContainer/RarityLabel
@onready var cost_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CostContainer/CostLabel
@onready var cost_element_icons: HBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CostContainer/CostElementIcons
@onready var hp_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/HpApContainer/HpLabel
@onready var ap_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/HpApContainer/ApLabel
@onready var restriction_text_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/RestrictionContainer/RestrictionTextLabel
@onready var restriction_element_icons: HBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/RestrictionContainer/RestrictionElementIcons
@onready var item_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/RestrictionContainer/ItemLabel
@onready var curse_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/CurseLabel
@onready var skill_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/SkillContainer
@onready var skill_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/SkillContainer/SkillLabel
@onready var mystic_container: VBoxContainer = $MainContainer/RightPanel/ContentMargin/VBoxContainer/MysticContainer
@onready var mystic_label: Label = $MainContainer/RightPanel/ContentMargin/VBoxContainer/MysticContainer/MysticLabel

# UIManager参照（グローバルボタン用）
var ui_manager_ref = null

# 状態
var is_visible_panel: bool = false
var is_selection_mode: bool = false
var is_info_only_mode: bool = false  # 閲覧専用モード（キャンセルシグナル発行しない）
var current_creature_data: Dictionary = {}
var current_tile_index: int = -1
var current_hand_index: int = -1
var current_confirmation_text: String = ""

# 参照
var card_system = null


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
	is_info_only_mode = false
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# グローバルボタン設定（閲覧モード：戻るのみ）
	# setup_buttons=falseの場合はスキップ（呼び出し側でナビゲーション管理）
	if setup_buttons and ui_manager_ref:
		ui_manager_ref.register_back_action(_on_back_action, "閉じる")


## 選択モードで表示（召喚/バトル時）
## restriction_reason: ""=制限なし, "ep"=EP不足/土地条件, "restriction"=配置制限等
func show_selection_mode(creature_data: Dictionary, confirmation_text: String = "召喚しますか？", restriction_reason: String = ""):
	current_creature_data = creature_data
	current_confirmation_text = confirmation_text
	is_selection_mode = true
	is_info_only_mode = false
	
	_update_display()
	
	visible = true
	is_visible_panel = true
	
	# 制限理由に応じてコメントとボタンを変更
	var creature_name = creature_data.get("name", "クリーチャー")
	
	if restriction_reason == "ep":
		# EP不足/土地条件
		if ui_manager_ref and ui_manager_ref.phase_display:
			ui_manager_ref.phase_display.show_action_prompt("%s：EP不足または土地条件未達" % creature_name, "right")
		# 戻るボタンのみ
		if ui_manager_ref:
			ui_manager_ref.register_back_action(_on_back_action, "戻る")
	elif restriction_reason == "restriction":
		# 配置制限等
		if ui_manager_ref and ui_manager_ref.phase_display:
			ui_manager_ref.phase_display.show_action_prompt("%s：使用できません" % creature_name, "right")
		# 戻るボタンのみ
		if ui_manager_ref:
			ui_manager_ref.register_back_action(_on_back_action, "戻る")
	else:
		# 制限なし - 通常の確認
		if ui_manager_ref and ui_manager_ref.phase_display:
			ui_manager_ref.phase_display.show_action_prompt("%sを%s" % [creature_name, confirmation_text], "right")
		
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
	is_info_only_mode = false  # フラグをリセット
	current_creature_data = {}
	current_tile_index = -1
	
	# 選択モードの場合はアクション指示を消す
	if is_selection_mode and ui_manager_ref and ui_manager_ref.phase_display:
		ui_manager_ref.phase_display.hide_action_prompt()
	
	if clear_buttons and ui_manager_ref:
		ui_manager_ref.clear_global_actions()
	
	panel_closed.emit()


## パネル表示中かどうか
func is_panel_visible() -> bool:
	return is_visible_panel


# === 内部メソッド ===

func _update_display():
	_update_right_panel()


func _update_right_panel():
	var data = current_creature_data
	
	# 名前
	if name_label:
		name_label.text = data.get("name", "不明")
	
	# レア度
	if rarity_label:
		var rarity = data.get("rarity", "")
		rarity_label.text = "[%s]" % rarity if rarity else ""
	
	# コスト
	if cost_label:
		var cost_value = data.get("cost", 0)
		var ep_cost = 0
		var lands_required = []
		var cards_sacrifice = 0
		
		# 元のカードデータからコスト情報を取得
		var card_id = data.get("id", 0)
		var original_data = CardLoader.get_card_by_id(card_id) if card_id > 0 else {}
		var original_cost = original_data.get("cost", {})
		
		if typeof(original_cost) == TYPE_DICTIONARY:
			ep_cost = original_cost.get("ep", 0)
			lands_required = original_cost.get("lands_required", [])
			cards_sacrifice = original_cost.get("cards_sacrifice", 0)
		else:
			ep_cost = cost_value if typeof(cost_value) == TYPE_INT else 0
			lands_required = data.get("cost_lands_required", [])
		
		cost_label.text = "コスト: %dEP" % ep_cost
		_add_cost_icons(cost_element_icons, lands_required, cards_sacrifice)
	
	# HP / AP
	var hp = data.get("hp", 0)
	var ap = data.get("ap", 0)
	var current_hp = data.get("current_hp", hp)
	var max_hp = hp + data.get("base_up_hp", 0)
	var total_ap = ap + data.get("base_up_ap", 0)
	
	if hp_label:
		hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
	if ap_label:
		ap_label.text = "AP: %d" % total_ap
	
	# 配置制限 / アイテム制限
	var restrictions = data.get("restrictions", {})
	var cannot_summon = restrictions.get("cannot_summon", [])
	
	if restriction_text_label:
		if cannot_summon.is_empty():
			restriction_text_label.text = "配置不可: なし"
		else:
			restriction_text_label.text = "配置不可:"
	
	_add_element_icons(restriction_element_icons, cannot_summon)
	
	if item_label:
		var cannot_use = restrictions.get("cannot_use", [])
		if not cannot_use.is_empty():
			item_label.text = "アイテム制限: %s" % ",".join(cannot_use)
		else:
			item_label.text = "アイテム制限: なし"
	
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
	
	# アルカナアーツ
	if mystic_container and mystic_label:
		var ability_parsed = data.get("ability_parsed", {})
		var mystic_art = ability_parsed.get("mystic_art", {})
		var mystic_arts = ability_parsed.get("mystic_arts", [])
		if not mystic_art.is_empty() or not mystic_arts.is_empty():
			mystic_container.visible = true
			var mystic_text = ""
			if not mystic_art.is_empty():
				mystic_text = "%s (%dEP)" % [mystic_art.get("name", ""), mystic_art.get("cost", 0)]
			elif not mystic_arts.is_empty():
				var parts = []
				for ma in mystic_arts:
					parts.append("%s (%dEP)" % [ma.get("name", ""), ma.get("cost", 0)])
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


# === 属性アイコン ===

var _element_textures: Dictionary = {}

func _get_element_texture(element: String) -> Texture2D:
	if element not in _element_textures:
		var path = "res://assets/ui/element_%s.png" % element
		if ResourceLoader.exists(path):
			_element_textures[element] = load(path)
		else:
			_element_textures[element] = null
	return _element_textures[element]

func _add_element_icons(container: HBoxContainer, elements: Array) -> void:
	if not container:
		return
	
	# 既存のアイコンをクリア
	for child in container.get_children():
		child.queue_free()
	
	# 属性アイコンを追加
	for element in elements:
		var texture = _get_element_texture(element)
		if texture:
			var icon = TextureRect.new()
			icon.texture = texture
			icon.custom_minimum_size = Vector2(40, 40)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			container.add_child(icon)


func _add_cost_icons(container: HBoxContainer, elements: Array, cards_sacrifice: int) -> void:
	if not container:
		return
	
	# 既存のアイコンをクリア
	for child in container.get_children():
		child.queue_free()
	
	# 属性アイコンを追加
	for element in elements:
		var texture = _get_element_texture(element)
		if texture:
			var icon = TextureRect.new()
			icon.texture = texture
			icon.custom_minimum_size = Vector2(40, 40)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			container.add_child(icon)
	
	# カード犠牲アイコンを追加
	if cards_sacrifice > 0:
		var sacrifice_texture = load("res://assets/ui/sacrifice_card.png")
		if sacrifice_texture:
			for i in range(cards_sacrifice):
				var icon = TextureRect.new()
				icon.texture = sacrifice_texture
				icon.custom_minimum_size = Vector2(40, 40)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				container.add_child(icon)


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
