extends Control

## インフォパネル説明画面
## 4ページ構成: プレイヤー、クリーチャー、スペル、アイテム

@onready var back_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/BackButton
@onready var prev_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/PrevButton
@onready var next_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/NextButton
@onready var page_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PageLabel
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var left_panel: Control = $MarginContainer/VBoxContainer/ContentHBox/LeftPanel
@onready var right_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentHBox/RightPanel/MarginContainer/VBoxContainer/RightLabel
@onready var right_vbox: VBoxContainer = $MarginContainer/VBoxContainer/ContentHBox/RightPanel/MarginContainer/VBoxContainer
@onready var annotation_labels: VBoxContainer = $MarginContainer/VBoxContainer/ContentHBox/RightPanel/MarginContainer/VBoxContainer/AnnotationLabels

# 注釈オーバーレイ
var annotation_overlay: AnnotationOverlay = null

const PAGE_TITLES = [
	"プレイヤーインフォパネル",
	"クリーチャーインフォパネル",
	"スペルインフォパネル",
	"アイテムインフォパネル"
]

var current_page: int = 0
var total_pages: int = 4

# 各インフォパネルのインスタンス
var player_info_panel_instance = null
var creature_info_panel_instance = null
var spell_info_panel_instance = null
var item_info_panel_instance = null

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	_setup_annotation_overlay()
	_load_info_panels()
	_update_page()

func _setup_annotation_overlay() -> void:
	annotation_overlay = AnnotationOverlay.new()
	annotation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	annotation_overlay.z_index = 100  # 最前面に表示
	# ルートに追加して全体の上に描画
	add_child(annotation_overlay)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Help.tscn")

func _on_prev_pressed():
	current_page = (current_page - 1 + total_pages) % total_pages
	_update_page()

func _on_next_pressed():
	current_page = (current_page + 1) % total_pages
	_update_page()

func _load_info_panels():
	# プレイヤーインフォパネル（シーンがあれば読み込む）
	var player_scene = load("res://scenes/ui/player_status_dialog.tscn")
	if player_scene:
		player_info_panel_instance = player_scene.instantiate()
		player_info_panel_instance.visible = false
		left_panel.add_child(player_info_panel_instance)
	
	# クリーチャーインフォパネル
	var creature_scene = load("res://scenes/ui/creature_info_panel.tscn")
	if creature_scene:
		creature_info_panel_instance = creature_scene.instantiate()
		creature_info_panel_instance.visible = false
		left_panel.add_child(creature_info_panel_instance)
	
	# スペルインフォパネル
	var spell_scene = load("res://scenes/ui/spell_info_panel.tscn")
	if spell_scene:
		spell_info_panel_instance = spell_scene.instantiate()
		spell_info_panel_instance.visible = false
		left_panel.add_child(spell_info_panel_instance)
	
	# アイテムインフォパネル
	var item_scene = load("res://scenes/ui/item_info_panel.tscn")
	if item_scene:
		item_info_panel_instance = item_scene.instantiate()
		item_info_panel_instance.visible = false
		left_panel.add_child(item_info_panel_instance)

func _update_page():
	# タイトル更新
	title_label.text = PAGE_TITLES[current_page]
	page_label.text = str(current_page + 1) + " / " + str(total_pages)
	
	# 全パネル非表示
	if player_info_panel_instance:
		player_info_panel_instance.visible = false
	if creature_info_panel_instance:
		creature_info_panel_instance.visible = false
	if spell_info_panel_instance:
		spell_info_panel_instance.visible = false
	if item_info_panel_instance:
		item_info_panel_instance.visible = false
	
	# 注釈をクリア
	if annotation_overlay:
		annotation_overlay.clear_annotations()
	
	# 注釈ラベルを非表示（各ページで必要に応じて表示）
	if annotation_labels:
		annotation_labels.visible = false
	
	# 現在のページのパネルを表示
	match current_page:
		0:
			_show_player_info_panel()
		1:
			_show_creature_info_panel()
		2:
			_show_spell_info_panel()
		3:
			_show_item_info_panel()

func _show_player_info_panel():
	if player_info_panel_instance:
		player_info_panel_instance.visible = true
		# 位置とサイズ調整
		player_info_panel_instance.position = Vector2.ZERO
		player_info_panel_instance.scale = Vector2(0.5, 0.5)
	
	right_label.text = _get_player_info_description()

func _show_creature_info_panel():
	if creature_info_panel_instance:
		creature_info_panel_instance.visible = true
		creature_info_panel_instance.position = Vector2(50, -100)
		creature_info_panel_instance.scale = Vector2(1.0, 1.0)
		
		# サンプルデータを設定（ID 43）
		var sample_data = _get_sample_creature_data()
		if creature_info_panel_instance.has_method("show_view_mode"):
			creature_info_panel_instance.show_view_mode(sample_data, -1, false)
		
		# 注釈ラベルを表示
		if annotation_labels:
			annotation_labels.visible = true
		
		# 注釈を追加（1フレーム待ってから位置を取得）
		await get_tree().process_frame
		_setup_creature_annotations()
	
	right_label.text = _get_creature_info_description()

func _show_spell_info_panel():
	if spell_info_panel_instance:
		spell_info_panel_instance.visible = true
		spell_info_panel_instance.position = Vector2.ZERO
		spell_info_panel_instance.scale = Vector2(0.8, 0.8)
		
		# サンプルデータを設定
		var sample_data = _get_sample_spell_data()
		if spell_info_panel_instance.has_method("show_spell_info"):
			spell_info_panel_instance.show_spell_info(sample_data, -1)
	
	right_label.text = _get_spell_info_description()

func _show_item_info_panel():
	if item_info_panel_instance:
		item_info_panel_instance.visible = true
		item_info_panel_instance.position = Vector2.ZERO
		item_info_panel_instance.scale = Vector2(0.8, 0.8)
		
		# サンプルデータを設定
		var sample_data = _get_sample_item_data()
		if item_info_panel_instance.has_method("show_item_info"):
			item_info_panel_instance.show_item_info(sample_data, -1)
	
	right_label.text = _get_item_info_description()

func _setup_creature_annotations() -> void:
	if not annotation_overlay or not creature_info_panel_instance:
		return
	
	annotation_overlay.clear_annotations()
	
	# クリーチャーパネル内のノードを取得
	var content_vbox = creature_info_panel_instance.get_node_or_null("MainContainer/RightPanel/ContentMargin/VBoxContainer")
	if not content_vbox:
		return
	
	# 左パネルの各要素を取得
	var name_container = content_vbox.get_node_or_null("NameContainer")
	var name_label = name_container.get_node_or_null("NameLabel") if name_container else null
	var rarity_label = name_container.get_node_or_null("RarityLabel") if name_container else null
	var cost_container = content_vbox.get_node_or_null("CostContainer")
	var cost_label = cost_container.get_node_or_null("CostLabel") if cost_container else null
	var cost_icons = cost_container.get_node_or_null("CostElementIcons") if cost_container else null
	var hp_ap_container = content_vbox.get_node_or_null("HpApContainer")
	var hp_label = hp_ap_container.get_node_or_null("HpLabel") if hp_ap_container else null
	var ap_label = hp_ap_container.get_node_or_null("ApLabel") if hp_ap_container else null
	var restriction_container = content_vbox.get_node_or_null("RestrictionContainer")
	var restriction_label = restriction_container.get_node_or_null("RestrictionTextLabel") if restriction_container else null
	var restriction_icons = restriction_container.get_node_or_null("RestrictionElementIcons") if restriction_container else null
	var item_label = restriction_container.get_node_or_null("ItemLabel") if restriction_container else null
	var curse_label = content_vbox.get_node_or_null("CurseLabel")
	var skill_container = content_vbox.get_node_or_null("SkillContainer")
	
	# 右パネルの注釈ラベルを取得
	var name_annotation = annotation_labels.get_node_or_null("NameAnnotation")
	var rarity_annotation = annotation_labels.get_node_or_null("RarityAnnotation")
	var cost_annotation = annotation_labels.get_node_or_null("CostAnnotation")
	var cost_icon_annotation = annotation_labels.get_node_or_null("CostIconAnnotation")
	var hp_annotation = annotation_labels.get_node_or_null("HpAnnotation")
	var ap_annotation = annotation_labels.get_node_or_null("ApAnnotation")
	var restriction_annotation = annotation_labels.get_node_or_null("RestrictionAnnotation")
	var item_annotation = annotation_labels.get_node_or_null("ItemAnnotation")
	var curse_annotation = annotation_labels.get_node_or_null("CurseAnnotation")
	var skill_annotation = annotation_labels.get_node_or_null("SkillAnnotation")
	
	# 1. 名前（上から線を出す）
	if name_label and name_annotation:
		var source_rect = _get_control_rect_in_overlay(name_label)
		var target_pos = _get_label_left_center(name_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(1.0, 0.8, 0.2), 800.0, "top", 30.0)
	
	# 2. レアリティ
	if rarity_label and rarity_annotation:
		var source_rect = _get_control_rect_in_overlay(rarity_label)
		var target_pos = _get_label_left_center(rarity_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.9, 0.6, 0.2),450)
	
	# 3. コスト（上から線を出す、長め）
	if cost_label and cost_annotation:
		var source_rect = _get_control_rect_in_overlay(cost_label)
		var target_pos = _get_label_left_center(cost_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.2, 0.8, 0.4), 1200.0, "top", 30.0)
	
	# 4. 必要土地/犠牲カードアイコン
	if cost_icons and cost_icon_annotation:
		var source_rect = _get_control_rect_in_overlay(cost_icons)
		var target_pos = _get_label_left_center(cost_icon_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.4, 0.7, 0.3),930)
	
	# 5. HP
	if hp_label and hp_annotation:
		var source_rect = _get_control_rect_in_overlay(hp_label)
		var target_pos = _get_label_left_center(hp_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.2, 0.6, 0.8), 1000.0, "right_top")
	
	# 6. AP
	if ap_label and ap_annotation:
		var source_rect = _get_control_rect_in_overlay(ap_label)
		var target_pos = _get_label_left_center(ap_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.8, 0.5, 0.2),770)
	
	# 7. 配置制限（ラベルとアイコンを合わせて囲む）
	if restriction_label and restriction_annotation:
		var source_rect = _get_combined_rect_in_overlay(restriction_label, restriction_icons)
		var target_pos = _get_label_left_center(restriction_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.8, 0.4, 0.2), 1020.0, "right_top")
	
	# 8. アイテム制限
	if item_label and item_annotation:
		var source_rect = _get_control_rect_in_overlay(item_label)
		var target_pos = _get_label_left_center(item_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.6, 0.4, 0.8),510)
	
	# 9. 呪い（テキストサイズに合わせた矩形）
	if curse_label and curse_annotation:
		var source_rect = _get_text_fitted_rect(curse_label)
		var target_pos = _get_label_left_center(curse_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.8, 0.2, 0.2) ,800)
	
	# 10. スキル
	if skill_container and skill_annotation:
		var source_rect = _get_control_rect_in_overlay(skill_container)
		var target_pos = _get_label_left_center(skill_annotation)
		annotation_overlay.add_annotation(source_rect, target_pos, "", Color(0.4, 0.6, 1.0))

func _get_control_rect_in_overlay(control: Control) -> Rect2:
	## Controlのグローバル矩形をオーバーレイのローカル座標に変換
	var global_rect = control.get_global_rect()
	var local_pos = global_rect.position - annotation_overlay.get_global_position()
	return Rect2(local_pos, global_rect.size)

func _get_combined_rect_in_overlay(control1: Control, control2: Control) -> Rect2:
	## 2つのControlを合わせた矩形を取得（オーバーレイ座標系）
	if control1 == null:
		return Rect2()
	
	var rect1 = control1.get_global_rect()
	
	if control2 == null:
		var local_pos = rect1.position - annotation_overlay.get_global_position()
		return Rect2(local_pos, rect1.size)
	
	var rect2 = control2.get_global_rect()
	var combined = rect1.merge(rect2)
	var local_pos = combined.position - annotation_overlay.get_global_position()
	return Rect2(local_pos, combined.size)

func _get_label_left_center(label: Control) -> Vector2:
	## ラベルの左端中央の位置を取得（オーバーレイ座標系）
	var global_rect = label.get_global_rect()
	var left_center = Vector2(global_rect.position.x, global_rect.get_center().y)
	return left_center - annotation_overlay.get_global_position()

func _get_text_fitted_rect(label: Label) -> Rect2:
	## ラベルの実際のテキストサイズに合わせた矩形を取得（オーバーレイ座標系）
	var font = label.get_theme_font("font")
	var font_size = label.get_theme_font_size("font_size")
	var text = label.text
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	var global_pos = label.global_position - annotation_overlay.get_global_position()
	# パディングを追加（左右は広め、上下は狭め）
	var padding_x = 10
	var padding_y = 0
	return Rect2(
		global_pos - Vector2(padding_x, padding_y),
		text_size + Vector2(padding_x * 2, padding_y * 2)
	)

# サンプルデータ取得
func _get_sample_creature_data() -> Dictionary:
	# ID 43 のクリーチャーを使用
	if CardLoader:
		var data = CardLoader.get_card_by_id(43)
		if not data.is_empty():
			return data
	
	# フォールバック
	return {
		"id": 43,
		"name": "サンプル",
		"type": "creature",
		"element": "fire",
		"ap": 30,
		"hp": 30,
		"cost": {"ep": 50},
		"ability": ""
	}

func _get_sample_spell_data() -> Dictionary:
	# ID 2001 のアースシフト
	if CardLoader:
		var data = CardLoader.get_card_by_id(2001)
		if not data.is_empty():
			return data
	
	return {
		"id": 2001,
		"name": "アースシフト",
		"type": "spell",
		"spell_type": "単体対象",
		"cost": {"ep": 100},
		"effect": "対象自ドミニオを地に変える"
	}

func _get_sample_item_data() -> Dictionary:
	# アイテムデータを取得
	if CardLoader:
		var data = CardLoader.get_card_by_id(3001)
		if not data.is_empty():
			return data
	
	return {
		"id": 3001,
		"name": "サンプルアイテム",
		"type": "item",
		"item_type": "武器",
		"effect": "ST+10"
	}

# 説明テキスト
func _get_player_info_description() -> String:
	var text = "[font_size=36][b]プレイヤーインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "画面左上のプレイヤー情報パネルをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・基本情報（名前、EP、TEP）\n"
	text += "・マップ情報（周回数、ターン数、破壊数）\n"
	text += "・手札一覧\n"
	text += "・保有土地（属性別）\n"
	text += "・保有クリーチャー一覧\n"
	text += "[/font_size]"
	return text

func _get_creature_info_description() -> String:
	var text = "[font_size=36][b]クリーチャーインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "クリーチャーカードをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・カード名と属性\n"
	text += "・コスト（MP、必要ドミニオ）\n"
	text += "・ST（攻撃力）/ HP（体力）\n"
	text += "・能力説明\n"
	text += "・アルカナアーツ情報（ある場合）\n"
	text += "[/font_size]"
	return text

func _get_spell_info_description() -> String:
	var text = "[font_size=36][b]スペルインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "スペルカードをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・カード名\n"
	text += "・スペルタイプ\n"
	text += "・コスト（MP、カード犠牲など）\n"
	text += "・効果説明\n"
	text += "[/font_size]"
	return text

func _get_item_info_description() -> String:
	var text = "[font_size=36][b]アイテムインフォパネル[/b][/font_size]\n\n"
	text += "[font_size=28]"
	text += "アイテムカードをタップすると\n"
	text += "詳細情報が表示されます。\n\n"
	text += "[b]表示内容：[/b]\n"
	text += "・カード名\n"
	text += "・アイテムタイプ（武器/防具/アクセサリ/巻物）\n"
	text += "・コスト\n"
	text += "・効果説明\n"
	text += "・使用条件（ある場合）\n"
	text += "[/font_size]"
	return text
