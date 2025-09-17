# ポリゴン背景作成関数（game.gdに追加）
func create_polygon_background():
	# 既存の背景を削除
	if current_background and is_instance_valid(current_background):
		current_background.queue_free()
	
	# 背景コンテナ
	var bg_container = Node2D.new()
	bg_container.name = "PolygonBackground"
	bg_container.z_index = -10
	$BoardMap.add_child(bg_container)
	current_background = bg_container
	
	# ========== 宇宙背景（最背面） ==========
	var space_bg = Polygon2D.new()
	space_bg.name = "SpaceBackground"
	space_bg.z_index = -3
	
	# 画面全体をカバーする四角形
	var space_points = PackedVector2Array([
		Vector2(-500, -400),
		Vector2(1300, -400),
		Vector2(1300, 1000),
		Vector2(-500, 1000)
	])
	space_bg.polygon = space_points
	
	# 宇宙のグラデーション（濃い紫から黒）
	space_bg.color = Color(0.05, 0.02, 0.1)  # ほぼ黒の紫
	
	# 頂点カラーでグラデーション効果
	var space_colors = PackedColorArray([
		Color(0.1, 0.05, 0.2),   # 左上: 少し明るい紫
		Color(0.02, 0.01, 0.05), # 右上: ほぼ黒
		Color(0.05, 0.02, 0.1),  # 右下: 暗い紫
		Color(0.08, 0.04, 0.15)  # 左下: やや明るい紫
	])
	space_bg.vertex_colors = space_colors
	
	bg_container.add_child(space_bg)
	
	# ========== 星雲効果 ==========
	create_nebula_effect(bg_container)
	
	# ========== 浮遊する島（メイン） ==========
	var island = Polygon2D.new()
	island.name = "FloatingIsland"
	island.z_index = -1
	
	# アイソメトリック風の島の形状
	var island_points = PackedVector2Array([
		# 上部の平面（ボードが乗る部分）
		Vector2(100, 150),   # 左上
		Vector2(250, 80),    # 上左
		Vector2(550, 80),    # 上右
		Vector2(700, 150),   # 右上
		Vector2(700, 450),   # 右下
		Vector2(550, 520),   # 下右
		Vector2(250, 520),   # 下左
		Vector2(100, 450),   # 左下
	])
	island.polygon = island_points
	
	# 島のグラデーション（茶色系の石）
	var island_colors = PackedColorArray([
		Color(0.4, 0.35, 0.3),  # 明るい石色
		Color(0.35, 0.3, 0.25),
		Color(0.3, 0.25, 0.2),
		Color(0.35, 0.3, 0.25),
		Color(0.25, 0.2, 0.15),  # 影の部分
		Color(0.2, 0.15, 0.1),
		Color(0.25, 0.2, 0.15),
		Color(0.3, 0.25, 0.2)
	])
	island.vertex_colors = island_colors
	
	bg_container.add_child(island)
	
	# ========== 島の側面（立体感） ==========
	var island_side = Polygon2D.new()
	island_side.name = "IslandSide"
	island_side.z_index = -2
	
	# 島の下部（影の部分）
	var side_points = PackedVector2Array([
		Vector2(100, 450),   # 左上（島の左下）
		Vector2(250, 520),   # 上左（島の下左）
		Vector2(550, 520),   # 上右（島の下右）
		Vector2(700, 450),   # 右上（島の右下）
		Vector2(650, 550),   # 右下（深い部分）
		Vector2(400, 620),   # 下（最深部）
		Vector2(150, 550),   # 左下（深い部分）
	])
	island_side.polygon = side_points
	
	# 側面は暗い色
	island_side.color = Color(0.15, 0.12, 0.1)
	
	bg_container.add_child(island_side)
	
	# ========== 光るエッジ効果 ==========
	create_glow_edge(bg_container, island_points)
	
	# ========== 星の追加 ==========
	create_stars(bg_container)
	
	print("ポリゴン背景を作成しました")

# 星雲効果を作成
func create_nebula_effect(parent: Node2D):
	var nebula = Polygon2D.new()
	nebula.name = "Nebula"
	nebula.z_index = -2
	nebula.modulate = Color(1, 1, 1, 0.3)  # 半透明
	
	# 不規則な形状の星雲
	var nebula_points = PackedVector2Array([
		Vector2(600, 50),
		Vector2(750, 100),
		Vector2(800, 250),
		Vector2(700, 350),
		Vector2(550, 300),
		Vector2(500, 150)
	])
	nebula.polygon = nebula_points
	
	# 星雲のグラデーション（紫とピンク）
	var nebula_colors = PackedColorArray([
		Color(0.6, 0.3, 0.8, 0.3),
		Color(0.8, 0.4, 0.6, 0.2),
		Color(0.5, 0.3, 0.7, 0.1),
		Color(0.7, 0.4, 0.8, 0.2),
		Color(0.6, 0.3, 0.6, 0.3),
		Color(0.8, 0.5, 0.7, 0.2)
	])
	nebula.vertex_colors = nebula_colors
	
	parent.add_child(nebula)

# 光るエッジ効果
func create_glow_edge(parent: Node2D, island_points: PackedVector2Array):
	var glow = Line2D.new()
	glow.name = "GlowEdge"
	glow.z_index = 0
	glow.width = 3.0
	glow.default_color = Color(0.5, 0.7, 1.0, 0.5)  # 薄い青の光
	
	# 島の輪郭をなぞる
	for point in island_points:
		glow.add_point(point)
	glow.add_point(island_points[0])  # 閉じる
	
	# グラデーション効果
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.3, 0.5, 0.8, 0.3))
	gradient.set_color(1, Color(0.6, 0.8, 1.0, 0.6))
	glow.gradient = gradient
	
	parent.add_child(glow)

# 星を散りばめる
func create_stars(parent: Node2D):
	var star_container = Node2D.new()
	star_container.name = "Stars"
	star_container.z_index = -2
	
	# ランダムに星を配置
	for i in range(30):
		var star = Polygon2D.new()
		
		# 小さい四角形または六角形の星
		var star_size = randf_range(2, 5)
		var star_points = PackedVector2Array([
			Vector2(-star_size, 0),
			Vector2(0, -star_size),
			Vector2(star_size, 0),
			Vector2(0, star_size)
		])
		star.polygon = star_points
		
		# ランダムな位置
		star.position = Vector2(
			randf_range(-400, 1200),
			randf_range(-300, 900)
		)
		
		# 明るさをランダムに
		var brightness = randf_range(0.5, 1.0)
		star.color = Color(brightness, brightness, brightness * 0.9)
		
		# 少し回転
		star.rotation = randf_range(0, PI/4)
		
		star_container.add_child(star)
	
	parent.add_child(star_container)

# 背景を切り替える関数も追加
func switch_to_polygon_background():
	create_polygon_background()
	print("ポリゴン背景に切り替えました")
