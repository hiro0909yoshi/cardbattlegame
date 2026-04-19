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

# アイテムショップ価格（ジェム）
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
@onready var multi_100_button = $VBoxContainer/ContentPanel/GachaSection/ButtonsHBox/Multi100GachaButton
@onready var result_label = $VBoxContainer/ContentPanel/GachaSection/ResultSection/ResultLabel
@onready var result_grid = $VBoxContainer/ContentPanel/GachaSection/ResultSection/ScrollContainer/ResultGrid

# ジェム購入セクション
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

# 課金ガチャ用
var _premium_gacha_button: Button = null
var _premium_gacha_section: VBoxContainer = null
var _premium_type_container: HBoxContainer = null
var _premium_single_button: Button = null
var _premium_multi_button: Button = null
var _premium_result_label: Label = null
var _premium_result_grid: GridContainer = null
var _selected_premium_type: int = 0  # PremiumGachaType

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
	multi_100_button.pressed.connect(_on_multi_100_gacha)

	# 提供割合ボタン（通常ガチャ）
	var rates_btn: Button = Button.new()
	rates_btn.text = "提供割合"
	rates_btn.custom_minimum_size = Vector2(160, 80)
	rates_btn.add_theme_font_size_override("font_size", 22)
	rates_btn.pressed.connect(_on_show_gacha_rates)
	$VBoxContainer/ContentPanel/GachaSection/ButtonsHBox.add_child(rates_btn)
	
	# 売却ボタン接続
	manual_sell_button.pressed.connect(_on_manual_sell)
	auto_sell_button.pressed.connect(_on_auto_sell)
	
	back_button.pressed.connect(_on_back)
	# ヘッダーにも戻るボタン（モバイルでFooterが画面外になる対策）
	var header_back: Button = $VBoxContainer/Header/HeaderBackButton
	if header_back:
		header_back.pressed.connect(_on_back)
	
	# ガチャタイプボタンを生成
	_create_gacha_type_buttons()
	
	# 課金ガチャセクションを動的生成
	_create_premium_gacha_ui()

	# ジェム非公開時はアイテムショップタブ・ジェム購入タブ・ジェム表示・課金ガチャを隠す
	if not DebugSettings.show_premium_stone:
		item_shop_button.visible = false
		stone_purchase_button.visible = false
		stone_label.visible = false
		if _premium_gacha_button:
			_premium_gacha_button.visible = false

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
	var gacha_keys = ["gacha.normal", "gacha.s_gacha", "gacha.r_gacha"]
	for type_id in range(3):  # NORMAL, S_GACHA, R_GACHA
		var button = Button.new()
		button.custom_minimum_size = Vector2(300, 80)
		button.add_theme_font_size_override("font_size", 24)

		var is_unlocked = UnlockManager.is_unlocked(gacha_keys[type_id])
		var single_cost = gacha_system.get_single_cost(type_id)
		var multi_cost = gacha_system.get_multi_10_cost(type_id)

		if is_unlocked:
			button.text = "%s\n1回: %dG / 10連: %dG" % [GACHA_NAMES[type_id], single_cost, multi_cost]
			button.pressed.connect(_on_gacha_type_selected.bind(type_id))
		else:
			var condition = UnlockManager.get_condition_for_key(gacha_keys[type_id])
			var lock_text = condition.get("lock_description", "") if condition else ""
			button.text = "%s\n🔒 %s" % [GACHA_NAMES[type_id], lock_text]
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
	var multi_100_cost = gacha_system.get_multi_100_cost(type_id)
	single_button.text = "1回引く\n%dG" % single_cost
	multi_button.text = "10連\n%dG" % multi_cost
	multi_100_button.text = "100連\n%dG" % multi_100_cost
	
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
	if _premium_gacha_section:
		_premium_gacha_section.visible = false
	purchase_button.disabled = false
	item_shop_button.disabled = false
	stone_purchase_button.disabled = false
	sell_button.disabled = false
	if _premium_gacha_button:
		_premium_gacha_button.disabled = false

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
	var before: Dictionary = _snapshot_owned_ids()
	var before_complete: Dictionary = _snapshot_complete_state()
	var result = gacha_system.pull_single()
	if result.success:
		_mark_new_cards(result.cards, before)
		await _play_gacha_animation(result.cards)
		_show_gacha_result(result.cards)
		await _check_collection_complete(before_complete)
	else:
		result_label.text = result.error
	_update_gold_display()

func _on_multi_gacha():
	var before: Dictionary = _snapshot_owned_ids()
	var before_complete: Dictionary = _snapshot_complete_state()
	var result = gacha_system.pull_multi_10()
	if result.success:
		_mark_new_cards(result.cards, before)
		await _play_gacha_animation(result.cards)
		_show_gacha_result(result.cards)
		await _check_collection_complete(before_complete)
	else:
		result_label.text = result.error
	_update_gold_display()

func _on_multi_100_gacha():
	var before: Dictionary = _snapshot_owned_ids()
	var before_complete: Dictionary = _snapshot_complete_state()
	var result = gacha_system.pull_multi_100()
	if result.success:
		_mark_new_cards(result.cards, before)
		await _play_gacha_animation(result.cards)
		_show_gacha_result(result.cards)
		await _check_collection_complete(before_complete)
	else:
		result_label.text = result.error
	_update_gold_display()


func _snapshot_owned_ids() -> Dictionary:
	var ids: Dictionary = {}
	for card in CardLoader.all_cards:
		var id: int = int(card.get("id", 0))
		if id > 0 and UserCardDB.get_card_count(id) > 0:
			ids[id] = true
	return ids


func _mark_new_cards(cards: Array, before_ids: Dictionary) -> void:
	var seen: Dictionary = {}
	for card in cards:
		var id: int = int(card.get("id", 0))
		if id > 0 and not before_ids.has(id) and not seen.has(id):
			card["_is_new"] = true
			seen[id] = true


func _play_gacha_animation(cards: Array) -> void:
	if DebugSettings.skip_gacha_animation:
		return
	var batches: Array = []
	var i: int = 0
	while i < cards.size():
		var end: int = min(i + 10, cards.size())
		batches.append(cards.slice(i, end))
		i = end
	for batch in batches:
		var anim: CanvasLayer = preload("res://scenes/ui/gacha_animation.tscn").instantiate()
		add_child(anim)
		anim.play(batch)
		await anim.animation_finished
		anim.queue_free()

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

# ==================== ジェム購入 ====================

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

	# ジェム数
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
		item_shop_result_label.text = "ジェムが不足しています"
		return

	GameData.add_inventory_item(item_id, 1)
	item_shop_result_label.text = "%s を購入しました！" % item_name
	_update_gold_display()
	_display_item_shop()


func _on_back():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# ==================== 課金ガチャ ====================

const _PREMIUM_ELEMENT_COLORS: Dictionary = {
	0: Color(1.0, 0.4, 0.3),   # 火
	1: Color(0.3, 0.5, 1.0),   # 水
	2: Color(0.2, 0.7, 0.3),   # 地
	3: Color(0.9, 0.8, 0.2),   # 風
	4: Color(0.6, 0.6, 0.6),   # 無
	5: Color(0.7, 0.4, 1.0),   # スペル
	6: Color(0.3, 0.8, 0.6),   # アイテム
}

## 課金ガチャUI動的生成
func _create_premium_gacha_ui():
	# モードボタン追加
	_premium_gacha_button = Button.new()
	_premium_gacha_button.text = "課金ガチャ"
	_premium_gacha_button.custom_minimum_size = Vector2(200, 60)
	_premium_gacha_button.add_theme_font_size_override("font_size", 24)
	_premium_gacha_button.pressed.connect(_on_premium_gacha_mode)
	var mode_buttons = $VBoxContainer/ModeButtons
	mode_buttons.add_child(_premium_gacha_button)

	# セクション
	_premium_gacha_section = VBoxContainer.new()
	_premium_gacha_section.name = "PremiumGachaSection"
	_premium_gacha_section.visible = false
	_premium_gacha_section.add_theme_constant_override("separation", 12)
	var content_panel = $VBoxContainer/ContentPanel
	content_panel.add_child(_premium_gacha_section)

	# タイトル
	var title = Label.new()
	title.text = "課金ガチャ（S:70% / R:30%）"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_premium_gacha_section.add_child(title)

	# タイプ選択ボタン（スクロール対応）
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_premium_gacha_section.add_child(scroll)

	_premium_type_container = HBoxContainer.new()
	_premium_type_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_premium_type_container)

	for type_id in range(7):
		var btn = Button.new()
		var type_name: String = gacha_system.PREMIUM_GACHA_NAMES[type_id]
		btn.text = type_name
		btn.custom_minimum_size = Vector2(180, 90)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_premium_type_selected.bind(type_id))
		_premium_type_container.add_child(btn)

	# プルボタン
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_hbox.add_theme_constant_override("separation", 20)
	_premium_gacha_section.add_child(buttons_hbox)

	var single_cost: int = gacha_system.get_premium_single_cost()
	var multi_cost: int = gacha_system.get_premium_multi_10_cost()

	_premium_single_button = Button.new()
	_premium_single_button.text = "1回引く\n💎%d" % single_cost
	_premium_single_button.custom_minimum_size = Vector2(200, 80)
	_premium_single_button.add_theme_font_size_override("font_size", 24)
	_premium_single_button.pressed.connect(_on_premium_single_gacha)
	buttons_hbox.add_child(_premium_single_button)

	_premium_multi_button = Button.new()
	_premium_multi_button.text = "10連\n💎%d" % multi_cost
	_premium_multi_button.custom_minimum_size = Vector2(200, 80)
	_premium_multi_button.add_theme_font_size_override("font_size", 24)
	_premium_multi_button.pressed.connect(_on_premium_multi_gacha)
	buttons_hbox.add_child(_premium_multi_button)

	# 提供割合ボタン（課金ガチャ）
	var premium_rates_btn: Button = Button.new()
	premium_rates_btn.text = "提供割合"
	premium_rates_btn.custom_minimum_size = Vector2(160, 80)
	premium_rates_btn.add_theme_font_size_override("font_size", 22)
	premium_rates_btn.pressed.connect(_on_show_premium_gacha_rates)
	buttons_hbox.add_child(premium_rates_btn)

	# 結果表示
	_premium_result_label = Label.new()
	_premium_result_label.add_theme_font_size_override("font_size", 22)
	_premium_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_premium_gacha_section.add_child(_premium_result_label)

	var result_scroll = ScrollContainer.new()
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_premium_gacha_section.add_child(result_scroll)

	_premium_result_grid = GridContainer.new()
	_premium_result_grid.columns = 5
	_premium_result_grid.add_theme_constant_override("h_separation", 8)
	_premium_result_grid.add_theme_constant_override("v_separation", 8)
	result_scroll.add_child(_premium_result_grid)

	# 初期選択
	_on_premium_type_selected(0)


## 課金ガチャモード
func _on_premium_gacha_mode():
	_hide_all_sections()
	_premium_gacha_section.visible = true
	_premium_gacha_button.disabled = true


## 課金ガチャタイプ選択
func _on_premium_type_selected(type_id: int):
	_selected_premium_type = type_id

	# ボタンの見た目更新
	for i in range(_premium_type_container.get_child_count()):
		var btn: Button = _premium_type_container.get_child(i)
		if i == type_id:
			btn.modulate = _PREMIUM_ELEMENT_COLORS.get(i, Color.WHITE)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)

	var type_name: String = gacha_system.PREMIUM_GACHA_NAMES[type_id]
	_premium_result_label.text = "%s を選択中" % type_name


## 課金ガチャ単発
func _on_premium_single_gacha():
	var before: Dictionary = _snapshot_owned_ids()
	var before_complete: Dictionary = _snapshot_complete_state()
	var result = gacha_system.pull_premium_single(_selected_premium_type)
	if result.success:
		_mark_new_cards(result.cards, before)
		await _play_gacha_animation(result.cards)
		_show_premium_gacha_result(result.cards)
		await _check_collection_complete(before_complete)
	else:
		_premium_result_label.text = result.error
	_update_gold_display()


## 課金ガチャ10連
func _on_premium_multi_gacha():
	var before: Dictionary = _snapshot_owned_ids()
	var before_complete: Dictionary = _snapshot_complete_state()
	var result = gacha_system.pull_premium_multi_10(_selected_premium_type)
	if result.success:
		_mark_new_cards(result.cards, before)
		await _play_gacha_animation(result.cards)
		_show_premium_gacha_result(result.cards)
		await _check_collection_complete(before_complete)
	else:
		_premium_result_label.text = result.error
	_update_gold_display()


## 課金ガチャ結果表示
func _show_premium_gacha_result(cards: Array):
	for child in _premium_result_grid.get_children():
		child.queue_free()

	var rarity_count = {"S": 0, "R": 0}
	for card in cards:
		var card_panel = _create_card_display(card)
		_premium_result_grid.add_child(card_panel)
		var rarity = card.get("rarity", "S")
		if rarity_count.has(rarity):
			rarity_count[rarity] += 1

	_premium_result_label.text = "結果: S×%d  R×%d" % [rarity_count["S"], rarity_count["R"]]


# ==================== コレクションコンプリート ====================

const _COLLECTION_CATEGORIES: Dictionary = {
	"fire": { "card_type": "creature", "element": "fire", "label": "火属性クリーチャー" },
	"water": { "card_type": "creature", "element": "water", "label": "水属性クリーチャー" },
	"earth": { "card_type": "creature", "element": "earth", "label": "地属性クリーチャー" },
	"wind": { "card_type": "creature", "element": "wind", "label": "風属性クリーチャー" },
	"neutral": { "card_type": "creature", "element": "neutral", "label": "無属性クリーチャー" },
	"spell": { "card_type": "spell", "element": "", "label": "スペル" },
	"item": { "card_type": "item", "element": "", "label": "アイテム" },
}


## ガチャ前のコンプリート状態をスナップショット（セーブ済みフラグを返すだけ）
func _snapshot_complete_state() -> Dictionary:
	var cc: Dictionary = GameData.player_data.stats.collection_complete
	return cc.duplicate()


## ガチャ後にコレクションコンプリートをチェック（初回達成時のみポップアップ＋セーブ）
func _check_collection_complete(before_complete: Dictionary) -> void:
	# 各カテゴリのコンプリート判定（1枚/4枚）— 達成済みはスキップ
	for cat_key in _COLLECTION_CATEGORIES.keys():
		var label: String = _COLLECTION_CATEGORIES[cat_key]["label"]
		var key_4: String = cat_key + "_4"
		var key_1: String = cat_key + "_1"
		if before_complete.get(key_4, false):
			continue  # 4枚達成済み → 1枚も当然達成済み
		if _is_category_complete(cat_key, 4):
			GameData.set_collection_complete(key_4)
			await _show_complete_popup(label, 4)
		elif not before_complete.get(key_1, false) and _is_category_complete(cat_key, 1):
			GameData.set_collection_complete(key_1)
			await _show_complete_popup(label, 1)

	# 全属性コンプリート判定 — 達成済みはスキップ
	if not before_complete.get("all_4", false):
		if _is_all_complete(4):
			GameData.set_collection_complete("all_4")
			await _show_complete_popup("全カード", 4)
		elif not before_complete.get("all_1", false) and _is_all_complete(1):
			GameData.set_collection_complete("all_1")
			await _show_complete_popup("全カード", 1)


## カードが属するカテゴリキーを返す
func _get_card_category(card: Dictionary) -> String:
	var card_type: String = String(card.get("type", "creature"))
	if card_type.is_empty():
		card_type = "creature"
	match card_type:
		"spell":
			return "spell"
		"item":
			return "item"
		_:
			var element: String = String(card.get("element", ""))
			if _COLLECTION_CATEGORIES.has(element):
				return element
	return ""


## 指定カテゴリが全カード所持済みか（min_count枚以上）
func _is_category_complete(cat_key: String, min_count: int = 1) -> bool:
	var cat: Dictionary = _COLLECTION_CATEGORIES.get(cat_key, {})
	if cat.is_empty():
		return false
	var target_type: String = cat["card_type"]
	var target_element: String = cat["element"]

	for card in CardLoader.all_cards:
		var card_id: int = int(card.get("id", 0))
		if card_id <= 0 or card_id in gacha_system.EXCLUDED_CARD_IDS:
			continue
		var card_type: String = String(card.get("type", "creature"))
		if card_type.is_empty():
			card_type = "creature"
		if card_type != target_type:
			continue
		if not target_element.is_empty() and String(card.get("element", "")) != target_element:
			continue
		if UserCardDB.get_card_count(card_id) < min_count:
			return false
	return true


## 全カテゴリコンプリート判定
func _is_all_complete(min_count: int = 1) -> bool:
	for cat_key in _COLLECTION_CATEGORIES.keys():
		if not _is_category_complete(cat_key, min_count):
			return false
	return true


## コンプリートポップアップ表示
func _show_complete_popup(category_label: String, min_count: int = 1) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(500, 280)
	panel.position = -panel.size * 0.5

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.15, 0.95)
	style.border_color = Color(1.0, 0.85, 0.2, 0.9)
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var is_all: bool = category_label == "全カード"
	var is_max: bool = min_count >= 4

	# タイトル
	var title_label: Label = Label.new()
	if is_all and is_max:
		title_label.text = "PERFECT COMPLETE!!"
	elif is_all:
		title_label.text = "ALL COMPLETE!"
	elif is_max:
		title_label.text = "MAX COMPLETE!"
	else:
		title_label.text = "COMPLETE!"
	title_label.add_theme_font_size_override("font_size", 42)

	# 全属性コンプは金色、属性コンプは銀色
	if is_all:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		style.border_color = Color(1.0, 0.85, 0.2, 0.9)
	else:
		title_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		style.border_color = Color(0.7, 0.75, 0.85, 0.9)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# 説明
	var desc_label: Label = Label.new()
	if is_max:
		desc_label.text = "%s を全て4枚以上コンプリートしました！" % category_label
	else:
		desc_label.text = "%s を全てコンプリートしました！" % category_label
	desc_label.add_theme_font_size_override("font_size", 26)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	var close_label: Label = Label.new()
	close_label.text = "タップで閉じる"
	close_label.add_theme_font_size_override("font_size", 20)
	close_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(close_label)

	# フェードイン
	overlay.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.3)
	await tw.finished

	# タップで閉じる（入力待ち）
	var btn: Button = Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.modulate.a = 0.0
	overlay.add_child(btn)
	btn.move_to_front()
	await btn.pressed
	overlay.queue_free()


# ==================== 提供割合表示 ====================

## 通常ガチャの提供割合を表示
func _on_show_gacha_rates() -> void:
	var lines: Array[String] = []
	var type_names: Dictionary = {0: "ノーマルガチャ", 1: "Sガチャ", 2: "Rガチャ"}
	for type_id in range(3):
		var rates: Dictionary = gacha_system.RARITY_RATES[type_id]
		var single_cost: int = gacha_system.get_single_cost(type_id)
		var multi_cost: int = gacha_system.get_multi_10_cost(type_id)
		var multi_100_cost: int = gacha_system.get_multi_100_cost(type_id)
		lines.append("━━ %s ━━" % type_names[type_id])
		lines.append("1回: %dG / 10連: %dG / 100連: %dG" % [single_cost, multi_cost, multi_100_cost])
		for rarity in rates.keys():
			lines.append("  %s: %.1f%%" % [rarity, rates[rarity]])
		lines.append("")
	lines.append("※ 排出対象外: 合成・変身専用カード（%d種）" % gacha_system.EXCLUDED_CARD_IDS.size())
	lines.append("※ 確率はレアリティ毎の合算値です")
	lines.append("※ 同一レアリティ内の各カードは均等確率です")
	await _show_rates_popup("ゴールドガチャ 提供割合", "\n".join(lines))


## 課金ガチャの提供割合を表示
func _on_show_premium_gacha_rates() -> void:
	var lines: Array[String] = []
	var single_cost: int = gacha_system.get_premium_single_cost()
	var multi_cost: int = gacha_system.get_premium_multi_10_cost()
	lines.append("━━ 排出確率（全タイプ共通）━━")
	lines.append("1回: 💎%d / 10連: 💎%d" % [single_cost, multi_cost])
	for rarity in gacha_system.PREMIUM_RARITY_RATES.keys():
		lines.append("  %s: %.1f%%" % [rarity, gacha_system.PREMIUM_RARITY_RATES[rarity]])
	lines.append("")
	lines.append("━━ ガチャタイプ ━━")
	for type_id in range(7):
		var type_name: String = gacha_system.PREMIUM_GACHA_NAMES[type_id]
		var filter: Dictionary = gacha_system.PREMIUM_GACHA_FILTERS[type_id]
		var desc: String = filter["card_type"]
		if not filter["element"].is_empty():
			desc += "（%s属性）" % filter["element"]
		lines.append("  %s: %s のみ排出" % [type_name, desc])
	lines.append("")
	lines.append("※ 排出対象外: 合成・変身専用カード（%d種）" % gacha_system.EXCLUDED_CARD_IDS.size())
	lines.append("※ 同一レアリティ内の各カードは均等確率です")
	await _show_rates_popup("課金ガチャ 提供割合", "\n".join(lines))


## 提供割合ポップアップ共通
func _show_rates_popup(title_text: String, body_text: String) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 画面の90%を使うパネル
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = 40.0
	var panel_size: Vector2 = Vector2(vp_size.x - margin * 2, vp_size.y - margin * 2)

	var panel: MarginContainer = MarginContainer.new()
	panel.position = Vector2(margin, margin)
	panel.size = panel_size

	var bg: PanelContainer = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.97)
	style.border_color = Color(0.5, 0.4, 0.8, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	bg.add_theme_stylebox_override("panel", style)
	panel.add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	bg.add_child(vbox)

	# タイトル
	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# 区切り線
	var separator: HSeparator = HSeparator.new()
	vbox.add_child(separator)

	# 本文（スクロール可能）
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var body_label: Label = Label.new()
	body_label.text = body_text
	body_label.add_theme_font_size_override("font_size", 24)
	body_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.custom_minimum_size.x = panel_size.x - 80
	scroll.add_child(body_label)

	# 閉じるラベル
	var close_label: Label = Label.new()
	close_label.text = "タップで閉じる"
	close_label.add_theme_font_size_override("font_size", 20)
	close_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(close_label)

	overlay.add_child(panel)

	# フェードイン
	overlay.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
	await tw.finished

	# タップで閉じる
	var close_btn: Button = Button.new()
	close_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	close_btn.modulate.a = 0.0
	overlay.add_child(close_btn)
	close_btn.move_to_front()
	await close_btn.pressed
	overlay.queue_free()
