extends Control

signal closed

var _current_category := "daily"

@onready var _tab_daily: Button = $PanelContainer/VBoxContainer/TabBar/DailyTab
@onready var _tab_weekly: Button = $PanelContainer/VBoxContainer/TabBar/WeeklyTab
@onready var _tab_permanent: Button = $PanelContainer/VBoxContainer/TabBar/PermanentTab
@onready var _mission_list: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/MissionList
@onready var _close_button: Button = $PanelContainer/VBoxContainer/Header/CloseButton
@onready var _title_label: Label = $PanelContainer/VBoxContainer/Header/TitleLabel

func _ready() -> void:
	_tab_daily.pressed.connect(func(): _switch_tab("daily"))
	_tab_weekly.pressed.connect(func(): _switch_tab("weekly"))
	_tab_permanent.pressed.connect(func(): _switch_tab("permanent"))
	_close_button.pressed.connect(_on_close)

	var mm := get_node_or_null("/root/MissionManager")
	if mm:
		if mm.has_signal("mission_completed"):
			mm.mission_completed.connect(_on_mission_completed)
		if mm.has_signal("mission_claimed"):
			mm.mission_claimed.connect(_on_mission_claimed)

	_switch_tab("daily")


func _switch_tab(category: String) -> void:
	_current_category = category
	_tab_daily.disabled = (category == "daily")
	_tab_weekly.disabled = (category == "weekly")
	_tab_permanent.disabled = (category == "permanent")
	_refresh_list()


func _refresh_list() -> void:
	for child in _mission_list.get_children():
		child.queue_free()

	var mm := get_node_or_null("/root/MissionManager")
	if not mm:
		return

	# デイリータブ時にSNSボーナスセクションを表示
	if _current_category == "daily":
		var sns_row := _create_sns_bonus_row()
		_mission_list.add_child(sns_row)

	var missions: Array[Dictionary] = mm.get_missions(_current_category)

	for mission in missions:
		var row := _create_mission_row(mission)
		_mission_list.add_child(row)


func _create_mission_row(mission: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.content_margin_left = 20
	stylebox.content_margin_right = 20
	stylebox.content_margin_top = 16
	stylebox.content_margin_bottom = 16

	if mission.get("claimed", false):
		stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.6)

	panel.add_theme_stylebox_override("panel", stylebox)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)

	# 左側: タイトル + 進捗数（固定幅）
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(300, 0)
	left_vbox.size_flags_horizontal = Control.SIZE_FILL
	left_vbox.size_flags_stretch_ratio = 0

	var title_label := Label.new()
	title_label.text = mission.get("title", "")
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.clip_text = true
	if mission.get("claimed", false):
		title_label.modulate = Color(0.5, 0.5, 0.5)
	left_vbox.add_child(title_label)

	var progress_label := Label.new()
	progress_label.text = "%d / %d" % [mission.get("current", 0), mission.get("target", 1)]
	progress_label.add_theme_font_size_override("font_size", 26)
	progress_label.modulate = Color(0.8, 0.8, 0.8)
	if mission.get("claimed", false):
		progress_label.modulate = Color(0.4, 0.4, 0.4)
	left_vbox.add_child(progress_label)

	hbox.add_child(left_vbox)

	# 中央: 説明文（伸縮）
	var desc_label := Label.new()
	desc_label.text = mission.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 30)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.size_flags_stretch_ratio = 1
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.clip_text = true
	if mission.get("claimed", false):
		desc_label.modulate = Color(0.4, 0.4, 0.4)
	else:
		desc_label.modulate = Color(0.9, 0.9, 0.9)
	hbox.add_child(desc_label)

	# 右側: 報酬 or 受け取るボタン or 完了マーク（固定幅）
	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(250, 0)
	right_vbox.size_flags_horizontal = Control.SIZE_FILL
	right_vbox.size_flags_stretch_ratio = 0
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var mid: String = mission.get("id", "")

	if mission.get("claimed", false):
		var check_label := Label.new()
		check_label.text = "✔"
		check_label.add_theme_font_size_override("font_size", 48)
		check_label.modulate = Color(0.2, 0.9, 0.3)
		check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_vbox.add_child(check_label)
	elif mission.get("completed", false):
		var reward: Dictionary = mission.get("reward", {})
		var reward_text := _format_reward(reward)
		var claim_button := Button.new()
		claim_button.text = "受け取る\n%s" % reward_text
		claim_button.add_theme_font_size_override("font_size", 28)
		claim_button.custom_minimum_size = Vector2(220, 70)
		claim_button.pressed.connect(_on_claim_pressed.bind(mid))
		right_vbox.add_child(claim_button)
	else:
		var reward: Dictionary = mission.get("reward", {})
		var reward_label := Label.new()
		reward_label.text = _format_reward(reward)
		reward_label.add_theme_font_size_override("font_size", 34)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if reward.get("type", "gold") == "gold":
			reward_label.modulate = Color(1.0, 0.85, 0.3)
		else:
			reward_label.modulate = Color(0.3, 0.8, 1.0)
		right_vbox.add_child(reward_label)

	hbox.add_child(right_vbox)
	panel.add_child(hbox)
	return panel


func _format_reward(reward: Dictionary) -> String:
	var amount: int = int(reward.get("amount", 0))
	if reward.get("type", "gold") == "gold":
		return "%d G" % amount
	else:
		return "%d ジェム" % amount


func _on_claim_pressed(mission_id: String) -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("claim_reward"):
		mm.claim_reward(mission_id)
	_refresh_list()


func _on_mission_completed(_mission_id: String) -> void:
	if visible:
		_refresh_list()


func _on_mission_claimed(_mission_id: String) -> void:
	if visible:
		_refresh_list()


func _create_sns_bonus_row() -> PanelContainer:
	var panel := PanelContainer.new()
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.12, 0.25, 0.9)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.content_margin_left = 20
	stylebox.content_margin_right = 20
	stylebox.content_margin_top = 16
	stylebox.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", stylebox)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)

	# 左側: タイトル + 説明
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(300, 0)
	left_vbox.size_flags_horizontal = Control.SIZE_FILL
	left_vbox.size_flags_stretch_ratio = 0

	var title_label := Label.new()
	title_label.text = "SNSボーナス"
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.modulate = Color(0.4, 0.7, 1.0)
	left_vbox.add_child(title_label)

	var sub_label := Label.new()
	sub_label.text = "1日1回"
	sub_label.add_theme_font_size_override("font_size", 26)
	sub_label.modulate = Color(0.8, 0.8, 0.8)
	left_vbox.add_child(sub_label)

	hbox.add_child(left_vbox)

	# 中央: 説明
	var desc_label := Label.new()
	desc_label.text = "公式SNSをフォローしてボーナスGET"
	desc_label.add_theme_font_size_override("font_size", 30)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.size_flags_stretch_ratio = 1
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.modulate = Color(0.9, 0.9, 0.9)
	hbox.add_child(desc_label)

	# 右側: ボタン（サーバー未接続時は準備中表示）
	var right_vbox := VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(250, 0)
	right_vbox.size_flags_horizontal = Control.SIZE_FILL
	right_vbox.size_flags_stretch_ratio = 0
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var status_label := Label.new()
	status_label.text = "準備中"
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate = Color(0.5, 0.5, 0.5)
	right_vbox.add_child(status_label)

	var reward_label := Label.new()
	reward_label.text = "100 ジェム"
	reward_label.add_theme_font_size_override("font_size", 28)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.modulate = Color(0.3, 0.8, 1.0)
	right_vbox.add_child(reward_label)

	hbox.add_child(right_vbox)
	panel.add_child(hbox)
	return panel


func _on_close() -> void:
	closed.emit()
	queue_free()
