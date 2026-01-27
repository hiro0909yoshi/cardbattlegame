class_name ResultScreen
extends CanvasLayer

## リザルト画面
## 勝利/敗北時に表示され、ランクと報酬を表示する

signal result_confirmed

# UI要素
var panel: Panel
var title_label: Label
var rank_label: Label
var turn_label: Label
var best_info_label: Label
var reward_container: VBoxContainer
var total_label: Label
var continue_label: Label

# 表示データ
var result_data: Dictionary = {}


func _ready():
	_build_ui()
	hide_screen()


func _build_ui():
	# 背景パネル
	panel = Panel.new()
	panel.name = "ResultPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	# メインコンテナ
	var main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(500, 400)
	main_container.position = Vector2(-250, -200)
	main_container.add_theme_constant_override("separation", 20)
	panel.add_child(main_container)
	
	# タイトル（WIN / LOSE）
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	main_container.add_child(title_label)
	
	# ランク表示
	rank_label = Label.new()
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 48)
	main_container.add_child(rank_label)
	
	# ターン数
	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(turn_label)
	
	# ベスト情報（2回目以降）
	best_info_label = Label.new()
	best_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_info_label.add_theme_font_size_override("font_size", 20)
	best_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_container.add_child(best_info_label)
	
	# 区切り線
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(400, 2)
	main_container.add_child(separator)
	
	# 報酬コンテナ
	reward_container = VBoxContainer.new()
	reward_container.add_theme_constant_override("separation", 8)
	main_container.add_child(reward_container)
	
	# 合計ラベル
	total_label = Label.new()
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 32)
	total_label.add_theme_color_override("font_color", Color.GOLD)
	main_container.add_child(total_label)
	
	# 続けるラベル
	continue_label = Label.new()
	continue_label.text = "[ タップで続ける ]"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.add_theme_font_size_override("font_size", 20)
	continue_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_container.add_child(continue_label)


## 勝利リザルトを表示
func show_victory(data: Dictionary):
	result_data = data
	
	# タイトル
	title_label.text = "STAGE CLEAR!"
	title_label.add_theme_color_override("font_color", Color.GOLD)
	
	# ランク
	var rank = data.get("rank", "C")
	rank_label.text = "クリアランク: " + rank
	rank_label.add_theme_color_override("font_color", _get_rank_color(rank))
	
	# ターン数
	var turn_count = data.get("turn_count", 0)
	turn_label.text = "クリアターン: %d" % turn_count
	
	# ベスト情報
	if not data.get("is_first_clear", true):
		var best_rank = data.get("best_rank", "")
		var best_turn = data.get("best_turn", 0)
		best_info_label.text = "ベストランク: %s (%dターン)" % [best_rank, best_turn]
		best_info_label.visible = true
	else:
		best_info_label.visible = false
	
	# 報酬
	_build_reward_display(data.get("rewards", {}))
	
	_show_with_animation()


## 敗北リザルトを表示
func show_defeat(data: Dictionary):
	result_data = data
	
	# タイトル
	title_label.text = "LOSE..."
	title_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	
	# ランク非表示
	var defeat_reason = data.get("defeat_reason", "")
	if defeat_reason == "surrender":
		rank_label.text = "（降参）"
	elif defeat_reason == "turn_limit":
		rank_label.text = "（規定ターン終了）"
	else:
		rank_label.text = ""
	rank_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	
	# ターン数
	var turn_count = data.get("turn_count", 0)
	if defeat_reason == "turn_limit":
		turn_label.text = "ターン: %d" % turn_count
	else:
		turn_label.text = ""
	
	# ベスト情報非表示
	best_info_label.visible = false
	
	# 報酬（0G）
	_build_reward_display(data.get("rewards", {}))
	
	_show_with_animation()


## 報酬表示を構築
func _build_reward_display(rewards: Dictionary):
	# 既存の報酬行をクリア
	for child in reward_container.get_children():
		child.queue_free()
	
	var is_defeat = rewards.get("is_defeat", false)
	var is_first_clear = rewards.get("is_first_clear", false)
	
	if is_defeat:
		var line = _create_reward_line("報酬", "0G")
		reward_container.add_child(line)
		total_label.text = "合計: 0G"
	else:
		var base_gold = rewards.get("base_gold", 0)
		var rank_bonus = rewards.get("rank_bonus", 0)
		var total = rewards.get("total", 0)
		
		if is_first_clear:
			var base_line = _create_reward_line("初回クリア報酬", "%dG" % base_gold)
			reward_container.add_child(base_line)
			
			if rank_bonus > 0:
				var bonus_line = _create_reward_line("ランクボーナス", "%dG" % rank_bonus)
				reward_container.add_child(bonus_line)
		else:
			var base_line = _create_reward_line("クリア報酬", "%dG" % base_gold)
			reward_container.add_child(base_line)
		
		total_label.text = "合計: %dG" % total


## 報酬行を作成
func _create_reward_line(label_text: String, value_text: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(350, 0)
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 24)
	hbox.add_child(value)
	
	return hbox


## ランク色を取得
func _get_rank_color(rank: String) -> Color:
	match rank:
		"SS":
			return Color(1.0, 0.84, 0.0)  # ゴールド
		"S":
			return Color(0.75, 0.75, 0.75)  # シルバー
		"A":
			return Color(0.8, 0.5, 0.2)  # ブロンズ
		"B":
			return Color(0.4, 0.6, 1.0)  # ブルー
		"C":
			return Color(0.6, 0.6, 0.6)  # グレー
		_:
			return Color.WHITE


## アニメーション付きで表示
func _show_with_animation():
	panel.visible = true
	panel.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


## 画面を非表示
func hide_screen():
	panel.visible = false


## 入力処理
func _input(event):
	if not panel.visible:
		return
	
	if event is InputEventMouseButton and event.pressed:
		_on_continue_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_on_continue_pressed()


## 続けるボタン押下
func _on_continue_pressed():
	print("[ResultScreen] 続ける押下")
	result_confirmed.emit()
	hide_screen()
