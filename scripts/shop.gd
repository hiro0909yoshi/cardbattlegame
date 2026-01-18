## ショップ画面
extends Control

# 売却価格
const SELL_PRICES = {
	"C": 5,
	"N": 10,
	"S": 50,
	"R": 100
}

@onready var gold_label = $VBoxContainer/Header/GoldLabel
@onready var purchase_button = $VBoxContainer/ModeButtons/PurchaseButton
@onready var sell_button = $VBoxContainer/ModeButtons/SellButton

# ガチャセクション
@onready var gacha_section = $VBoxContainer/ContentPanel/GachaSection
@onready var single_button = $VBoxContainer/ContentPanel/GachaSection/ButtonsHBox/SingleGachaButton
@onready var multi_button = $VBoxContainer/ContentPanel/GachaSection/ButtonsHBox/MultiGachaButton
@onready var multi_100_button = $VBoxContainer/ContentPanel/GachaSection/ButtonsHBox/Multi100GachaButton
@onready var result_label = $VBoxContainer/ContentPanel/GachaSection/ResultSection/ResultLabel
@onready var result_grid = $VBoxContainer/ContentPanel/GachaSection/ResultSection/ScrollContainer/ResultGrid

# 売却セクション
@onready var sell_section = $VBoxContainer/ContentPanel/SellSection
@onready var manual_sell_button = $VBoxContainer/ContentPanel/SellSection/SellButtonsHBox/ManualSellButton
@onready var auto_sell_button = $VBoxContainer/ContentPanel/SellSection/SellButtonsHBox/AutoSellButton
@onready var sell_result_label = $VBoxContainer/ContentPanel/SellSection/SellResultLabel
@onready var manual_sell_panel = $VBoxContainer/ContentPanel/SellSection/ManualSellPanel
@onready var card_grid = $VBoxContainer/ContentPanel/SellSection/ManualSellPanel/CardScrollContainer/CardGrid

@onready var back_button = $VBoxContainer/Footer/BackButton

var gacha_system: Node

func _ready():
	# ガチャシステムを初期化
	gacha_system = preload("res://scripts/gacha_system.gd").new()
	add_child(gacha_system)
	
	# モードボタン接続
	purchase_button.pressed.connect(_on_purchase_mode)
	sell_button.pressed.connect(_on_sell_mode)
	
	# ガチャボタン接続
	single_button.pressed.connect(_on_single_gacha)
	multi_button.pressed.connect(_on_multi_gacha)
	multi_100_button.pressed.connect(_on_multi_100_gacha)
	
	# 売却ボタン接続
	manual_sell_button.pressed.connect(_on_manual_sell)
	auto_sell_button.pressed.connect(_on_auto_sell)
	
	back_button.pressed.connect(_on_back)
	
	# 初期状態：購入モード
	_on_purchase_mode()
	_update_gold_display()

func _update_gold_display():
	gold_label.text = "💰 " + str(GameData.player_data.profile.gold) + " G"

# ==================== モード切替 ====================

func _on_purchase_mode():
	gacha_section.visible = true
	sell_section.visible = false
	purchase_button.disabled = true
	sell_button.disabled = false

func _on_sell_mode():
	gacha_section.visible = false
	sell_section.visible = true
	purchase_button.disabled = false
	sell_button.disabled = true
	manual_sell_panel.visible = false
	sell_result_label.text = ""

# ==================== ガチャ ====================

func _on_single_gacha():
	var result = gacha_system.pull_single()
	if result.success:
		_show_gacha_result(result.cards)
	else:
		result_label.text = result.error
	_update_gold_display()

func _on_multi_gacha():
	var result = gacha_system.pull_multi_10()
	if result.success:
		_show_gacha_result(result.cards)
	else:
		result_label.text = result.error
	_update_gold_display()

func _on_multi_100_gacha():
	var result = gacha_system.pull_multi_100()
	if result.success:
		_show_gacha_result(result.cards)
	else:
		result_label.text = result.error
	_update_gold_display()

func _show_gacha_result(cards: Array):
	# 前回の結果をクリア
	for child in result_grid.get_children():
		child.queue_free()
	
	# レアリティ別にカウント
	var rarity_count = {"C": 0, "N": 0, "S": 0, "R": 0}
	
	# カード表示
	for card in cards:
		var card_panel = _create_card_display(card)
		result_grid.add_child(card_panel)
		
		var rarity = card.get("rarity", "N")
		if rarity_count.has(rarity):
			rarity_count[rarity] += 1
	
	result_label.text = "結果: C×%d  N×%d  S×%d  R×%d" % [rarity_count["C"], rarity_count["N"], rarity_count["S"], rarity_count["R"]]

func _create_card_display(card: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 80)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = card.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	var rarity_label = Label.new()
	var rarity = card.get("rarity", "N")
	rarity_label.text = "[" + rarity + "]"
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# レアリティで色分け（C < N < S < R）
	match rarity:
		"R":
			rarity_label.modulate = Color(1.0, 0.8, 0.0)  # 金色（最高）
		"S":
			rarity_label.modulate = Color(0.6, 0.3, 1.0)  # 紫色
		"N":
			rarity_label.modulate = Color(0.3, 0.6, 1.0)  # 青色
		"C":
			rarity_label.modulate = Color(0.7, 0.7, 0.7)  # 灰色（最低）
	
	vbox.add_child(rarity_label)
	
	return panel

# ==================== 売却 ====================

func _on_manual_sell():
	manual_sell_panel.visible = true
	_populate_sellable_cards()

func _populate_sellable_cards():
	# カードグリッドをクリア
	for child in card_grid.get_children():
		child.queue_free()
	
	# 所持カードを表示
	for card in CardLoader.all_cards:
		var card_id = card.get("id", 0)
		var count = UserCardDB.get_card_count(card_id)
		
		if count > 0:
			var card_button = _create_sell_card_button(card, count)
			card_grid.add_child(card_button)

func _create_sell_card_button(card: Dictionary, count: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(180, 120)
	
	var card_id = card.get("id", 0)
	var card_name = card.get("name", "???")
	var rarity = card.get("rarity", "N")
	var price = SELL_PRICES.get(rarity, 10)
	
	# デッキ使用枚数を取得
	var deck_usage = GameData.get_card_usage_in_decks(card_id)
	var sellable = count - deck_usage
	
	button.text = "%s\n[%s] %d枚" % [card_name, rarity, count]
	if deck_usage > 0:
		button.text += " (デッキ:%d)" % deck_usage
	button.text += "\n売値: %dG" % price
	
	button.add_theme_font_size_override("font_size", 14)
	
	# 色分け（C < N < S < R）
	if sellable <= 0:
		# 売却不可（デッキ使用中）
		button.modulate = Color(0.5, 0.5, 0.5)
		button.disabled = true
	else:
		match rarity:
			"R":
				button.modulate = Color(1.0, 0.9, 0.7)  # 金色
			"S":
				button.modulate = Color(0.9, 0.8, 1.0)  # 紫色
			"N":
				button.modulate = Color(0.8, 0.9, 1.0)  # 青色
			"C":
				button.modulate = Color(0.9, 0.9, 0.9)  # 灰色
	
	button.pressed.connect(_on_sell_card.bind(card_id, card_name, rarity, price))
	
	return button

func _on_sell_card(card_id: int, card_name: String, rarity: String, price: int):
	var count = UserCardDB.get_card_count(card_id)
	if count <= 0:
		sell_result_label.text = "このカードは所持していません"
		return
	
	# デッキ使用枚数を確認
	var deck_usage = GameData.get_card_usage_in_decks(card_id)
	var sellable = count - deck_usage
	
	if sellable <= 0:
		sell_result_label.text = "⚠️ %s はデッキに%d枚使用中のため売却できません" % [card_name, deck_usage]
		return
	
	# 1枚売却
	UserCardDB.remove_card(card_id, 1)
	GameData.player_data.profile.gold += price
	GameData.save_to_file()
	UserCardDB.flush()
	
	sell_result_label.text = "%s を1枚売却しました (+%dG)" % [card_name, price]
	_update_gold_display()
	_populate_sellable_cards()

func _on_auto_sell():
	var total_sold = 0
	var total_gold = 0
	
	for card in CardLoader.all_cards:
		var card_id = card.get("id", 0)
		var count = UserCardDB.get_card_count(card_id)
		
		# デッキ使用枚数を取得
		var deck_usage = GameData.get_card_usage_in_decks(card_id)
		
		# 売却可能枚数 = 所持数 - デッキ使用数
		var sellable = count - deck_usage
		
		# 4枚を超えた分を売却（ただしデッキ使用分は除外）
		if sellable > 4:
			var sell_count = sellable - 4
			var rarity = card.get("rarity", "N")
			var price = SELL_PRICES.get(rarity, 10)
			var gold_earned = price * sell_count
			
			UserCardDB.remove_card(card_id, sell_count)
			total_sold += sell_count
			total_gold += gold_earned
	
	if total_sold > 0:
		GameData.player_data.profile.gold += total_gold
		GameData.save_to_file()
		UserCardDB.flush()
		sell_result_label.text = "自動売却完了: %d枚売却 (+%dG)" % [total_sold, total_gold]
	else:
		sell_result_label.text = "売却対象のカードがありません（デッキ使用分+4枚以下）"
	
	_update_gold_display()

func _on_back():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
