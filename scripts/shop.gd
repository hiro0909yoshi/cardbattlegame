## ショップ画面
extends Control

# 売却価格
const SELL_PRICES = {
	"C": 5,
	"N": 10,
	"S": 50,
	"R": 100
}

# ガチャタイプ名
const GACHA_NAMES = {
	0: "ノーマルガチャ",  # GachaType.NORMAL
	1: "Sガチャ",         # GachaType.S_GACHA
	2: "Rガチャ"          # GachaType.R_GACHA
}

# アイテムショップ価格（課金石）
const ITEM_SHOP_PRICES: Array[Dictionary] = [
	{"item_id": 1, "name": "スタミナ回復薬（小）", "stone_cost": 10, "description": "スタミナを20回復"},
	{"item_id": 2, "name": "スタミナ回復薬（大）", "stone_cost": 50, "description": "スタミナを最大値分回復"},
]

@onready var gold_label = $VBoxContainer/Header/GoldLabel
@onready var stone_label = $VBoxContainer/Header/StoneLabel
@onready var purchase_button = $VBoxContainer/ModeButtons/PurchaseButton
@onready var item_shop_button = $VBoxContainer/ModeButtons/ItemShopButton
@onready var stone_purchase_button = $VBoxContainer/ModeButtons/StonePurchaseButton
@onready var sell_button = $VBoxContainer/ModeButtons/SellButton

# ガチャセクション
@onready var gacha_section = $VBoxContainer/ContentPanel/GachaSection
@onready var gacha_type_container = $VBoxContainer/ContentPanel/GachaSection/GachaTypeContainer
@onready var single_button = $VBoxContainer/ContentPanel/GachaSection/ButtonsHBox/SingleGachaButton
@onready var multi_button = $VBoxContainer/ContentPanel/GachaSection/ButtonsHBox/MultiGachaButton
@onready var result_label = $VBoxContainer/ContentPanel/GachaSection/ResultSection/ResultLabel
@onready var result_grid = $VBoxContainer/ContentPanel/GachaSection/ResultSection/ScrollContainer/ResultGrid

# 課金石購入セクション
@onready var stone_purchase_section = $VBoxContainer/ContentPanel/StonePurchaseSection
@onready var stone_purchase_grid = $VBoxContainer/ContentPanel/StonePurchaseSection/StonePurchaseScroll/StonePurchaseGrid
@onready var stone_purchase_result_label = $VBoxContainer/ContentPanel/StonePurchaseSection/StonePurchaseResultLabel

# アイテムショップセクション
@onready var item_shop_section = $VBoxContainer/ContentPanel/ItemShopSection
@onready var item_shop_grid = $VBoxContainer/ContentPanel/ItemShopSection/ItemShopGrid
@onready var item_shop_result_label = $VBoxContainer/ContentPanel/ItemShopSection/ItemShopResultLabel

# 売却セクション
@onready var sell_section = $VBoxContainer/ContentPanel/SellSection
@onready var manual_sell_button = $VBoxContainer/ContentPanel/SellSection/SellButtonsHBox/ManualSellButton
@onready var auto_sell_button = $VBoxContainer/ContentPanel/SellSection/SellButtonsHBox/AutoSellButton
@onready var sell_result_label = $VBoxContainer/ContentPanel/SellSection/SellResultLabel
@onready var manual_sell_panel = $VBoxContainer/ContentPanel/SellSection/ManualSellPanel
@onready var card_grid = $VBoxContainer/ContentPanel/SellSection/ManualSellPanel/CardScrollContainer/CardGrid

@onready var back_button = $VBoxContainer/Footer/BackButton

var gacha_system: Node
var gacha_type_buttons: Array = []
var _purchase_manager: PurchaseManager = null

func _ready():
	# システム初期化
	gacha_system = preload("res://scripts/gacha_system.gd").new()
	add_child(gacha_system)
	_purchase_manager = PurchaseManager.new()

	# モードボタン接続
	purchase_button.pressed.connect(_on_purchase_mode)
	item_shop_button.pressed.connect(_on_item_shop_mode)
	stone_purchase_button.pressed.connect(_on_stone_purchase_mode)
	sell_button.pressed.connect(_on_sell_mode)
	
	# ガチャボタン接続
	single_button.pressed.connect(_on_single_gacha)
	multi_button.pressed.connect(_on_multi_gacha)
	
	# 売却ボタン接続
	manual_sell_button.pressed.connect(_on_manual_sell)
	auto_sell_button.pressed.connect(_on_auto_sell)
	
	back_button.pressed.connect(_on_back)
	
	# ガチャタイプボタンを生成
	_create_gacha_type_buttons()
	
	# 課金石非公開時はアイテムショップタブ・課金石購入タブ・課金石表示を隠す
	if not DebugSettings.show_premium_stone:
		item_shop_button.visible = false
		stone_purchase_button.visible = false
		stone_label.visible = false

	# 初期状態：購入モード
	_on_purchase_mode()
	_update_gold_display()

## ガチャタイプ選択ボタンを生成
func _create_gacha_type_buttons():
	# 既存のボタンをクリア
	for child in gacha_type_container.get_children():
		child.queue_free()
	gacha_type_buttons.clear()
	
	# 各ガチャタイプのボタンを作成
	for type_id in range(3):  # NORMAL, S_GACHA, R_GACHA
		var button = Button.new()
		button.custom_minimum_size = Vector2(300, 80)
		button.add_theme_font_size_override("font_size", 24)
		
		var is_unlocked = gacha_system.is_gacha_unlocked(type_id)
		var single_cost = gacha_system.get_single_cost(type_id)
		var multi_cost = gacha_system.get_multi_10_cost(type_id)
		
		if is_unlocked:
			button.text = "%s\n1回: %dG / 10連: %dG" % [GACHA_NAMES[type_id], single_cost, multi_cost]
			button.pressed.connect(_on_gacha_type_selected.bind(type_id))
		else:
			var unlock_stage = ""
			if type_id == 1:
				unlock_stage = "1-8"
			elif type_id == 2:
				unlock_stage = "2-8"
			button.text = "%s\n🔒 %sクリアで解禁" % [GACHA_NAMES[type_id], unlock_stage]
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5)
		
		gacha_type_container.add_child(button)
		gacha_type_buttons.append(button)
	
	# 最初のガチャタイプを選択
	_on_gacha_type_selected(0)

## ガチャタイプが選択された
func _on_gacha_type_selected(type_id: int):
	gacha_system.set_gacha_type(type_id)
	
	# ボタンの見た目を更新
	for i in range(gacha_type_buttons.size()):
		var btn = gacha_type_buttons[i]
		if not btn.disabled:
			if i == type_id:
				btn.modulate = Color(1.0, 1.0, 0.7)  # 選択中
			else:
				btn.modulate = Color(1.0, 1.0, 1.0)  # 非選択
	
	# ガチャボタンのテキストを更新
	var single_cost = gacha_system.get_single_cost(type_id)
	var multi_cost = gacha_system.get_multi_10_cost(type_id)
	single_button.text = "1回引く\n%dG" % single_cost
	multi_button.text = "10連\n%dG" % multi_cost
	
	result_label.text = "%s を選択中" % GACHA_NAMES[type_id]

func _update_gold_display():
	gold_label.text = "💰 " + str(GameData.player_data.profile.gold) + " G"
	stone_label.text = "💎 " + str(GameData.get_stone())

# ==================== モード切替 ====================

func _hide_all_sections():
	gacha_section.visible = false
	item_shop_section.visible = false
	stone_purchase_section.visible = false
	sell_section.visible = false
	purchase_button.disabled = false
	item_shop_button.disabled = false
	stone_purchase_button.disabled = false
	sell_button.disabled = false

func _on_purchase_mode():
	_hide_all_sections()
	gacha_section.visible = true
	purchase_button.disabled = true

func _on_item_shop_mode():
	_hide_all_sections()
	item_shop_section.visible = true
	item_shop_button.disabled = true
	_display_item_shop()

func _on_stone_purchase_mode():
	_hide_all_sections()
	stone_purchase_section.visible = true
	stone_purchase_button.disabled = true
	_display_stone_packages()

func _on_sell_mode():
	_hide_all_sections()
	sell_section.visible = true
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

# ==================== 課金石購入 ====================

func _display_stone_packages():
	for child in stone_purchase_grid.get_children():
		child.queue_free()

	var packages = _purchase_manager.get_all_packages()
	for pkg in packages:
		var panel = _create_stone_package_panel(pkg)
		stone_purchase_grid.add_child(panel)

	stone_purchase_result_label.text = ""


func _create_stone_package_panel(pkg: Dictionary) -> PanelContainer:
	var pkg_id = pkg.get("id", "")
	var pkg_name = pkg.get("name", "???")
	var stone_amount = int(pkg.get("stone_amount", 0))
	var bonus = int(pkg.get("bonus_amount", 0))
	var price_label_text = pkg.get("price_label", "")
	var description = pkg.get("description", "")
	var badge = pkg.get("badge", "")
	var icon_path = pkg.get("icon", "")

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 350)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.7)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# バッジ（お得、人気など）
	if not badge.is_empty():
		var badge_label = Label.new()
		badge_label.text = badge
		badge_label.add_theme_font_size_override("font_size", 22)
		badge_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge_label)

	# アイコン（画像がある場合）
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.custom_minimum_size = Vector2(80, 80)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon_rect)

	# パック名
	var name_label = Label.new()
	name_label.text = pkg_name
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 課金石数
	var amount_label = Label.new()
	if bonus > 0:
		amount_label.text = "💎 %d + %d" % [stone_amount, bonus]
	else:
		amount_label.text = "💎 %d" % stone_amount
	amount_label.add_theme_font_size_override("font_size", 36)
	amount_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(amount_label)

	# 説明
	if not description.is_empty():
		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 22)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(desc_label)

	# 購入ボタン
	var buy_button = Button.new()
	buy_button.text = price_label_text
	buy_button.custom_minimum_size = Vector2(200, 70)
	buy_button.add_theme_font_size_override("font_size", 30)
	buy_button.pressed.connect(_on_stone_purchase.bind(pkg_id))

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.4, 0.15, 0.9)
	btn_style.set_corner_radius_all(10)
	buy_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.5, 0.2, 0.95)
	buy_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.25, 0.6, 0.25, 1.0)
	buy_button.add_theme_stylebox_override("pressed", btn_pressed)

	vbox.add_child(buy_button)
	panel.add_child(vbox)
	return panel


func _on_stone_purchase(package_id: String):
	var result = _purchase_manager.purchase(package_id)
	if result.get("success", false):
		var total = int(result.get("total", 0))
		var bonus = int(result.get("bonus_amount", 0))
		if bonus > 0:
			stone_purchase_result_label.text = "💎 %d個（+ボーナス%d個）を獲得しました！" % [total - bonus, bonus]
		else:
			stone_purchase_result_label.text = "💎 %d個を獲得しました！" % total
		_update_gold_display()
	else:
		stone_purchase_result_label.text = result.get("error", "購入に失敗しました")


# ==================== アイテムショップ ====================

func _display_item_shop():
	for child in item_shop_grid.get_children():
		child.queue_free()

	for shop_item in ITEM_SHOP_PRICES:
		var panel = _create_item_shop_panel(shop_item)
		item_shop_grid.add_child(panel)

	item_shop_result_label.text = ""


func _create_item_shop_panel(shop_item: Dictionary) -> PanelContainer:
	var item_id = int(shop_item.get("item_id", 0))
	var item_name = shop_item.get("name", "???")
	var stone_cost = int(shop_item.get("stone_cost", 0))
	var description = shop_item.get("description", "")
	var owned = GameData.get_inventory_item_count(item_id)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 250)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.border_color = Color(0.4, 0.5, 0.7)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var name_label = Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 24)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)

	var owned_label = Label.new()
	owned_label.text = "所持数: %d" % owned
	owned_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(owned_label)

	var buy_button = Button.new()
	buy_button.text = "💎 %d で購入" % stone_cost
	buy_button.custom_minimum_size = Vector2(200, 70)
	buy_button.add_theme_font_size_override("font_size", 28)
	buy_button.pressed.connect(_on_buy_item.bind(item_id, item_name, stone_cost))

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.3, 0.5, 0.9)
	btn_style.set_corner_radius_all(8)
	buy_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.35, 0.6, 0.95)
	buy_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.3, 0.4, 0.7, 1.0)
	buy_button.add_theme_stylebox_override("pressed", btn_pressed)

	vbox.add_child(buy_button)
	panel.add_child(vbox)
	return panel


func _on_buy_item(item_id: int, item_name: String, stone_cost: int):
	if not GameData.spend_stone(stone_cost):
		item_shop_result_label.text = "課金石が不足しています"
		return

	GameData.add_inventory_item(item_id, 1)
	item_shop_result_label.text = "%s を購入しました！" % item_name
	_update_gold_display()
	_display_item_shop()


func _on_back():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
