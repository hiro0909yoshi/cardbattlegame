extends Node3D
class_name SimpleCreatureCard3D
## シンプルなテスト用3Dクリーチャーカード
## 真っ白なカードの代わりに、ColorRectで簡単な情報を表示

var viewport: SubViewport = null
var sprite_3d: Sprite3D = null
var creature_data: Dictionary = {}

func _ready():
	_setup_simple_card()

func _setup_simple_card():
	print("[SimpleCreatureCard3D] セットアップ開始")
	
	# SubViewportを作成
	viewport = SubViewport.new()
	viewport.size = Vector2i(240, 320)
	viewport.transparent_bg = false  # 背景を表示
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true  # 2D専用
	add_child(viewport)
	
	print("[SimpleCreatureCard3D] Viewport作成完了")
	
	# シンプルなカードUI（ColorRect + Label）を作成
	var card_bg = ColorRect.new()
	card_bg.size = Vector2(240, 320)
	card_bg.color = Color(0.9, 0.9, 0.85)  # ベージュ背景
	viewport.add_child(card_bg)
	
	# 枠線
	var border = ColorRect.new()
	border.size = Vector2(240, 320)
	border.color = Color.TRANSPARENT
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.2, 0.1)
	viewport.add_child(border)
	
	# 名前ラベル
	var name_label = Label.new()
	name_label.position = Vector2(10, 10)
	name_label.size = Vector2(220, 40)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color.BLACK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = "???"
	name_label.name = "NameLabel"
	viewport.add_child(name_label)
	
	# ステータスラベル（攻撃/防御）
	var stats_label = Label.new()
	stats_label.position = Vector2(10, 240)
	stats_label.size = Vector2(220, 60)
	stats_label.add_theme_font_size_override("font_size", 32)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_label.text = "攻:0 防:0"
	stats_label.name = "StatsLabel"
	viewport.add_child(stats_label)
	
	# 属性ラベル
	var element_label = Label.new()
	element_label.position = Vector2(10, 60)
	element_label.size = Vector2(220, 30)
	element_label.add_theme_font_size_override("font_size", 20)
	element_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	element_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	element_label.text = ""
	element_label.name = "ElementLabel"
	viewport.add_child(element_label)
	
	# Sprite3Dを作成（Viewport作成後すぐ）
	sprite_3d = Sprite3D.new()
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_3d.pixel_size = 0.005
	sprite_3d.position = Vector3(0, 0.8, 0)
	add_child(sprite_3d)
	
	# テクスチャは次のフレームで設定
	await get_tree().process_frame
	sprite_3d.texture = viewport.get_texture()
	print("[SimpleCreatureCard3D] Texture設定完了")
	
	# マテリアル設定
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite_3d.material_override = material

func set_creature_data(data: Dictionary):
	creature_data = data.duplicate()
	# 次のフレームで更新（Viewportの準備を待つ）
	await get_tree().process_frame
	_update_display()

func _update_display():
	print("[SimpleCreatureCard3D] _update_display開始")
	print("  creature_data: ", creature_data)
	
	if creature_data.is_empty():
		print("[SimpleCreatureCard3D] データが空")
		return
	
	# 名前を更新
	var name_label = viewport.get_node_or_null("NameLabel")
	if name_label:
		name_label.text = creature_data.get("name", "???")
	
	# ステータスを更新
	var stats_label = viewport.get_node_or_null("StatsLabel")
	if stats_label:
		var ap = creature_data.get("ap", 0)
		var hp = creature_data.get("hp", 0)
		stats_label.text = "攻:%d 防:%d" % [ap, hp]
	
	# 属性を更新
	var element_label = viewport.get_node_or_null("ElementLabel")
	if element_label:
		var element = creature_data.get("element", "")
		var element_text = ""
		match element:
			"fire": element_text = "🔥 火属性"
			"water": element_text = "💧 水属性"
			"wind": element_text = "💨 風属性"
			"earth": element_text = "🌍 土属性"
			_: element_text = element
		element_label.text = element_text
	
	# 背景色を属性に応じて変更
	var card_bg = viewport.get_child(0) if viewport.get_child_count() > 0 else null
	if card_bg is ColorRect:
		match creature_data.get("element", ""):
			"fire":
				card_bg.color = Color(1.0, 0.8, 0.7)  # 薄い赤
			"water":
				card_bg.color = Color(0.7, 0.85, 1.0)  # 薄い青
			"wind":
				card_bg.color = Color(0.8, 1.0, 0.8)  # 薄い緑
			"earth":
				card_bg.color = Color(0.9, 0.85, 0.7)  # 薄い茶色
			_:
				card_bg.color = Color(0.9, 0.9, 0.85)  # ベージュ

func set_height(height: float):
	if sprite_3d:
		sprite_3d.position.y = height

func set_card_scale(scale_factor: float):
	if sprite_3d:
		sprite_3d.pixel_size = 0.005 * scale_factor

func _exit_tree():
	if viewport:
		viewport.queue_free()
