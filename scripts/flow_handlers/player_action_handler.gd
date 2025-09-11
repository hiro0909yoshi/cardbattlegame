extends Node
class_name PlayerActionHandler

# プレイヤーアクション処理クラス
# プレイヤーの選択UI表示と入力待ち処理

signal action_selected(action: String, params: Dictionary)
signal summon_selected(card_index: int)
signal battle_selected(card_index: int)
signal level_up_selected(target_level: int, cost: int)
signal pass_selected()

# システム参照
var ui_manager: UIManager
var card_system: CardSystem

# 待機状態
var waiting_for_choice = false
var current_choice_type = ""
var player_choice = ""

func _ready():
	pass

# システム参照を設定
func setup_systems(ui_system: UIManager, c_system: CardSystem):
	ui_manager = ui_system
	card_system = c_system

# 召喚選択を表示
func show_summon_choice(current_player) -> void:
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size == 0:
		print("手札がありません")
		emit_signal("pass_selected")
		return
	
	print("召喚するクリーチャーを選択してください")
	ui_manager.show_card_selection_ui(current_player)
	
	# 選択待ち状態を設定
	start_waiting_for_choice("summon")

# バトル選択を表示
func show_battle_choice(current_player, tile_info: Dictionary, mode: String = "battle") -> void:
	var hand_size = card_system.get_hand_size_for_player(current_player.id)
	if hand_size == 0:
		print("手札がありません")
		emit_signal("pass_selected")
		return
	
	# UIマネージャーのフェーズラベルを設定
	match mode:
		"battle":
			ui_manager.phase_label.text = "バトルするクリーチャーを選択（またはパスで通行料）"
		"invasion":
			ui_manager.phase_label.text = "無防備な土地！侵略するクリーチャーを選択（またはパスで通行料）"
	
	ui_manager.show_card_selection_ui(current_player)
	
	# 選択待ち状態を設定
	start_waiting_for_choice(mode)

# レベルアップ選択を表示
func show_level_up_choice(tile_info: Dictionary, current_player) -> void:
	print("土地レベルアップを選択してください")
	ui_manager.show_level_up_ui(tile_info, current_player.magic_power)
	
	# 選択待ち状態を設定
	start_waiting_for_choice("level_up")

# 選択待ち開始
func start_waiting_for_choice(choice_type: String):
	waiting_for_choice = true
	current_choice_type = choice_type
	player_choice = ""

# 選択待ち状態をチェック
func is_waiting() -> bool:
	return waiting_for_choice

# 選択待ちループ（awaitで呼ばれる）
func wait_for_player_choice():
	while waiting_for_choice:
		await get_tree().process_frame
	
	return player_choice

# カードが選択された（UI経由）
func on_card_selected(card_index: int):
	if not waiting_for_choice:
		return
	
	player_choice = str(card_index)
	waiting_for_choice = false
	
	match current_choice_type:
		"summon":
			emit_signal("summon_selected", card_index)
		"battle", "invasion":
			emit_signal("battle_selected", card_index)
	
	ui_manager.hide_card_selection_ui()
	emit_signal("action_selected", current_choice_type, {"card_index": card_index})

# レベルアップが選択された（UI経由）
func on_level_up_selected(target_level: int, cost: int):
	if not waiting_for_choice or current_choice_type != "level_up":
		return
	
	player_choice = str(target_level) if target_level > 0 else "pass"
	waiting_for_choice = false
	
	emit_signal("level_up_selected", target_level, cost)
	emit_signal("action_selected", "level_up", {"target_level": target_level, "cost": cost})

# パスが選択された（UI経由）
func on_pass_button_pressed():
	if not waiting_for_choice:
		return
	
	player_choice = "pass"
	waiting_for_choice = false
	
	ui_manager.hide_card_selection_ui()
	emit_signal("pass_selected")
	emit_signal("action_selected", "pass", {})

# 選択をキャンセル
func cancel_selection():
	if waiting_for_choice:
		waiting_for_choice = false
		current_choice_type = ""
		player_choice = "cancelled"
		ui_manager.hide_card_selection_ui()

# 現在の選択タイプを取得
func get_current_choice_type() -> String:
	return current_choice_type

# クリーンアップ
func cleanup():
	waiting_for_choice = false
	current_choice_type = ""
	player_choice = ""
