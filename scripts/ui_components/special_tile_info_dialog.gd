class_name SpecialTileInfoDialog
extends Window

## 特殊タイル説明ダイアログ
## 各特殊タイルの名前・色・簡易説明を一覧表示

const SPECIAL_TILES_INFO = [
	{
		"name": "チェックポイント",
		"type": "Checkpoint",
		"color": Color(1.0, 0.9, 0.3),
		"description": "通過するとEPボーナスを獲得。全チェックポイントを通過すると周回完了となり、大きなボーナスが得られる。停止時に自分の全クリーチャーのダウン状態を解除する。"
	},
	{
		"name": "ワープ（通過型）",
		"type": "Warp",
		"color": Color(1.0, 0.5, 0.0),
		"description": "停止せずに通過するワープゲート。対になるワープタイルへ即座に移動する。"
	},
	{
		"name": "ワープ（停止型）",
		"type": "WarpStop",
		"color": Color(0.8, 0.3, 0.8),
		"description": "停止してからワープするタイル。対になるワープタイルへ移動した後、移動先のタイルアクションが発生する。"
	},
	{
		"name": "カード購入",
		"type": "CardBuy",
		"color": Color(0.3, 0.8, 0.8),
		"description": "EPを支払ってカードを購入できるタイル。ランダムに提示されるカードから選んで手札に加える。"
	},
	{
		"name": "カード配布",
		"type": "CardGive",
		"color": Color(0.3, 0.8, 0.8),
		"description": "無料でカードを1枚もらえるタイル。ランダムなカードが手札に追加される。"
	},
	{
		"name": "魔法陣",
		"type": "Magic",
		"color": Color(0.9, 0.3, 0.9),
		"description": "マップ上の好きなタイルへワープできる魔法陣。プレイヤーが移動先を選択する。"
	},
	{
		"name": "魔法石",
		"type": "MagicStone",
		"color": Color(0.7, 0.5, 0.9),
		"description": "魔法石を獲得できるタイル。魔法石は特殊な効果を持つアイテムとして使用できる。"
	},
	{
		"name": "分岐",
		"type": "Branch",
		"color": Color(1.0, 0.7, 0.3),
		"description": "進行方向を選択できる分岐タイル。複数の経路から好きな方向を選んで進む。"
	},
	{
		"name": "拠点",
		"type": "Base",
		"color": Color(0.5, 0.9, 0.5),
		"description": "空いている土地を選んでクリーチャーを遠隔召喚できるタイル。手札からクリーチャーを選び、離れた場所に配置する。"
	},
]

func _init():
	title = "特殊タイル一覧"
	size = Vector2i(800, 750)
	unresizable = false
	close_requested.connect(_on_close)

func _ready():
	_build_ui()

func _build_ui():
	var margin = MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# 説明ヘッダー
	var header = Label.new()
	header.text = "特殊な機能を持つタイルの説明"
	header.add_theme_font_size_override("font_size", 28)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 各タイル情報
	for tile_info in SPECIAL_TILES_INFO:
		_add_tile_entry(vbox, tile_info)

func _add_tile_entry(parent: VBoxContainer, tile_info: Dictionary):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.25, 1.0)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# タイル色サンプル
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(40, 40)
	color_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	color_rect.color = tile_info.get("color", Color.WHITE)
	hbox.add_child(color_rect)

	# テキスト部分
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(text_vbox)

	var name_label = Label.new()
	name_label.text = tile_info.get("name", "")
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", tile_info.get("color", Color.WHITE))
	text_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = tile_info.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(desc_label)

func _on_close():
	queue_free()
