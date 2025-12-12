extends Control
class_name BattleLogUI

# 戦闘ログを視覚的に表示するUI

@onready var log_container: VBoxContainer = $ScrollContainer/VBoxContainer
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var title_label: Label = $TitleLabel

var skill_log_system: SkillLogSystem
var log_entry_scene = preload("res://scenes/ui/LogEntry.tscn")  # 後で作成

# ログエントリーの最大表示数
var max_visible_entries: int = 20
var log_entries: Array = []

# 色設定
var type_colors = {
	SkillLogSystem.LogType.SKILL_ACTIVATED: Color.YELLOW,
	SkillLogSystem.LogType.BATTLE_START: Color.CYAN,
	SkillLogSystem.LogType.BATTLE_DAMAGE: Color(1, 0.3, 0.3),
	SkillLogSystem.LogType.BATTLE_END: Color.GREEN,
	SkillLogSystem.LogType.CONDITION_CHECK: Color(0.7, 0.7, 0.7),
	SkillLogSystem.LogType.EFFECT_APPLIED: Color.ORANGE,
	SkillLogSystem.LogType.KEYWORD_TRIGGERED: Color.MAGENTA
}

func _ready():
	# SkillLogSystemを取得または作成
	skill_log_system = get_node_or_null("/root/SkillLogSystem")
	if not skill_log_system:
		skill_log_system = SkillLogSystem.new()
		skill_log_system.name = "SkillLogSystem"
		get_tree().root.add_child(skill_log_system)
	
	# シグナル接続
	skill_log_system.log_added.connect(_on_log_added)
	skill_log_system.battle_started.connect(_on_battle_started)
	skill_log_system.battle_ended.connect(_on_battle_ended)
	
	# UI初期化
	_setup_ui()

func _setup_ui():
	# スクロールコンテナ設定 ※1.4倍
	scroll_container.custom_minimum_size = Vector2(560, 420)
	
	# タイトル設定 ※1.4倍
	title_label.text = "戦闘・スキルログ"
	title_label.add_theme_font_size_override("font_size", 25)

# ログエントリー追加
func _on_log_added(entry: Dictionary):
	# 簡易版：Labelで表示（後でRichTextLabelに変更可能）
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	
	# 色とアイコンを設定
	var color = type_colors.get(entry.type, Color.WHITE)
	var color_hex = "#" + color.to_html()
	var icon = _get_icon_for_type(entry.type)
	
	# インデント設定
	var indent = ""
	if entry.type in [SkillLogSystem.LogType.CONDITION_CHECK,
					   SkillLogSystem.LogType.EFFECT_APPLIED,
					   SkillLogSystem.LogType.BATTLE_DAMAGE]:
		indent = "    "
	
	# BBCodeフォーマット
	label.text = "[color=%s]%s%s %s[/color]" % [
		color_hex,
		indent,
		icon,
		entry.message
	]
	
	# アニメーション効果（フェードイン）
	label.modulate.a = 0.0
	log_container.add_child(label)
	
	var tween = get_tree().create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	
	# エントリー管理
	log_entries.append(label)
	
	# 最大数を超えたら古いものを削除
	if log_entries.size() > max_visible_entries:
		var old_entry = log_entries.pop_front()
		old_entry.queue_free()
	
	# 自動スクロール
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

# 戦闘開始時の特別表示
func _on_battle_started(attacker: String, defender: String):
	# 区切り線を追加
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 2)
	log_container.add_child(separator)
	log_entries.append(separator)

# 戦闘終了時の特別表示
func _on_battle_ended(result: Dictionary):
	# 区切り線を追加
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 2)
	separator.modulate = Color.GREEN
	log_container.add_child(separator)
	log_entries.append(separator)

# タイプに応じたアイコンを返す
func _get_icon_for_type(type: SkillLogSystem.LogType) -> String:
	match type:
		SkillLogSystem.LogType.SKILL_ACTIVATED:
			return "⚡"
		SkillLogSystem.LogType.BATTLE_START:
			return "⚔️"
		SkillLogSystem.LogType.BATTLE_DAMAGE:
			return "💥"
		SkillLogSystem.LogType.BATTLE_END:
			return "🏁"
		SkillLogSystem.LogType.CONDITION_CHECK:
			return "❓"
		SkillLogSystem.LogType.EFFECT_APPLIED:
			return "✨"
		SkillLogSystem.LogType.KEYWORD_TRIGGERED:
			return "🔮"
		_:
			return "•"

# ログをクリア
func clear_log():
	for entry in log_entries:
		entry.queue_free()
	log_entries.clear()

# ログの表示/非表示を切り替え
func toggle_visibility():
	visible = not visible

# フィルタリング機能
var filter_types: Array = []

func set_filter(types: Array):
	filter_types = types
	_refresh_display()

func _refresh_display():
	# フィルタに基づいて表示を更新
	for i in range(log_entries.size()):
		var entry = log_entries[i]
		if filter_types.is_empty():
			entry.visible = true
		else:
			# フィルタ実装（エントリーにtypeを保存する必要あり）
			pass
