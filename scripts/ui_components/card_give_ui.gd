extends Control

# カード譲渡タイルUI
# 3種類（クリーチャー/アイテム/スペル）から選択

signal type_selected(card_type: String)
signal cancelled()

var card_system: CardSystem
var player_id: int = 0

@onready var creature_button: Button = $Panel/VBoxContainer/CreatureButton
@onready var item_button: Button = $Panel/VBoxContainer/ItemButton
@onready var spell_button: Button = $Panel/VBoxContainer/SpellButton
@onready var cancel_button: Button = $Panel/VBoxContainer/CancelButton
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel

func _ready():
	creature_button.pressed.connect(_on_creature_pressed)
	item_button.pressed.connect(_on_item_pressed)
	spell_button.pressed.connect(_on_spell_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	visible = false

func setup(p_card_system: CardSystem, p_player_id: int):
	card_system = p_card_system
	player_id = p_player_id

func show_selection():
	if not card_system:
		push_error("[CardGiveUI] CardSystemが設定されていません")
		return
	
	# 各タイプの可用性をチェック
	var has_creature = card_system.has_deck_card_type(player_id, "creature")
	var has_item = card_system.has_deck_card_type(player_id, "item")
	var has_spell = card_system.has_deck_card_type(player_id, "spell")
	
	# ボタンの有効/無効を設定
	creature_button.disabled = not has_creature
	item_button.disabled = not has_item
	spell_button.disabled = not has_spell
	
	# ボタンテキストを更新
	creature_button.text = "クリーチャー" if has_creature else "クリーチャー（なし）"
	item_button.text = "アイテム" if has_item else "アイテム（なし）"
	spell_button.text = "スペル" if has_spell else "スペル（なし）"
	
	# 全てなければキャンセルのみ
	if not has_creature and not has_item and not has_spell:
		title_label.text = "山札にカードがありません"
	else:
		title_label.text = "カードの種類を選択"
	
	visible = true

func hide_selection():
	visible = false

func _on_creature_pressed():
	hide_selection()
	emit_signal("type_selected", "creature")

func _on_item_pressed():
	hide_selection()
	emit_signal("type_selected", "item")

func _on_spell_pressed():
	hide_selection()
	emit_signal("type_selected", "spell")

func _on_cancel_pressed():
	hide_selection()
	emit_signal("cancelled")
