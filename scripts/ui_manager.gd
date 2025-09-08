extends Node
class_name UIManager

# UI要素の作成・管理・更新システム

signal dice_button_pressed()
signal summon_button_pressed()
signal pass_button_pressed()

# UI要素
var dice_button: Button
var turn_label: Label
var magic_label: Label
var phase_label: Label
var summon_button: Button
var pass_button: Button

func _ready():
	print("UIManager: 初期化")

# UIを作成
func create_ui(parent: Node):
	# フェーズ表示
	phase_label = Label.new()
	phase_label.text = "セットアップ中..."
	phase_label.position = Vector2(350, 50)
	phase_label.add_theme_font_size_override("font_size", 24)
	parent.add_child(phase_label)
	
	# ターン表示
	turn_label = Label.new()
	turn_label.position = Vector2(50, 30)
	turn_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(turn_label)
	
	# 魔力表示
	magic_label = Label.new()
	magic_label.position = Vector2(50, 60)
	magic_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(magic_label)
	
	# サイコロボタン
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	dice_button.position = Vector2(350, 250)
	dice_button.size = Vector2(120, 40)
	dice_button.pressed.connect(_on_dice_button_pressed)
	dice_button.disabled = true
	parent.add_child(dice_button)
	
	# 召喚ボタン
	summon_button = Button.new()
	summon_button.text = "召喚する"
	summon_button.position = Vector2(300, 400)
	summon_button.size = Vector2(100, 40)
	summon_button.pressed.connect(_on_summon_button_pressed)
	summon_button.visible = false
	parent.add_child(summon_button)
	
	# パスボタン
	pass_button = Button.new()
	pass_button.text = "召喚しない"
	pass_button.position = Vector2(420, 400)
	pass_button.size = Vector2(100, 40)
	pass_button.pressed.connect(_on_pass_button_pressed)
	pass_button.visible = false
	parent.add_child(pass_button)
	
	print("UIManager: UI作成完了")

# UI更新
func update_ui(current_player, current_phase):
	if current_player:
		turn_label.text = current_player.name + "のターン"
		magic_label.text = "魔力: " + str(current_player.magic_power) + " / " + str(current_player.target_magic) + " G"
	
	# フェーズ表示を更新
	update_phase_display(current_phase)

# フェーズ表示を更新
func update_phase_display(phase):
	match phase:
		0: # SETUP
			phase_label.text = "準備中..."
		1: # DICE_ROLL
			phase_label.text = "サイコロを振ってください"
		2: # MOVING
			phase_label.text = "移動中..."
		3: # TILE_ACTION
			phase_label.text = "アクション選択"
		4: # BATTLE
			phase_label.text = "バトル！"
		5: # END_TURN
			phase_label.text = "ターン終了"

# ダイス結果を表示
func show_dice_result(value: int, parent: Node):
	var dice_label = Label.new()
	dice_label.text = "🎲 " + str(value)
	dice_label.add_theme_font_size_override("font_size", 48)
	dice_label.position = Vector2(350, 300)
	parent.add_child(dice_label)
	
	# 1秒後に消す
	await dice_label.get_tree().create_timer(1.0).timeout
	dice_label.queue_free()

# 召喚選択UIを表示
func show_summon_choice(card_data: Dictionary, cost: int):
	phase_label.text = card_data.get("name", "不明") + " (コスト: " + str(cost) + "G)"
	summon_button.visible = true
	pass_button.visible = true

# 召喚選択UIを非表示
func hide_summon_choice():
	summon_button.visible = false
	pass_button.visible = false
	phase_label.text = "アクション選択"

# 魔力不足表示
func show_magic_shortage():
	phase_label.text = "魔力不足 - 召喚不可"

# サイコロボタンの有効/無効
func set_dice_button_enabled(enabled: bool):
	dice_button.disabled = not enabled

# ボタンイベント
func _on_dice_button_pressed():
	emit_signal("dice_button_pressed")

func _on_summon_button_pressed():
	emit_signal("summon_button_pressed")

func _on_pass_button_pressed():
	emit_signal("pass_button_pressed")
