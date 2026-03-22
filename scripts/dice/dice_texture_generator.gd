class_name DiceTextureGenerator
extends RefCounted

## 木目風サイコロの面テクスチャを動的生成する（キャッシュ付き）

# テクスチャキャッシュ（一度生成したら再利用）
static var _cache: Dictionary = {}


## 指定した目のテクスチャを生成（キャッシュ済みならそれを返す）
static func create_face_texture(value: int, size: int = 128) -> ImageTexture:
	var key := "%d_%d" % [value, size]
	if _cache.has(key):
		return _cache[key]
	var img := _create_wood_background(size)
	if value == 0:
		_draw_star(img, size)
	else:
		_draw_dots(img, value, size)
	_draw_edge_shadow(img, size)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 木目背景を生成
static func _create_wood_background(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var base_r := 0.58
			var base_g := 0.36
			var base_b := 0.18
			# 木目模様（横方向のうねり）
			var grain := sin(float(y) * 0.5 + sin(float(x) * 0.1) * 4.0) * 0.05
			var grain2 := sin(float(y) * 1.5 + sin(float(x) * 0.2) * 2.0) * 0.025
			var r := clampf(base_r + grain + grain2, 0.0, 1.0)
			var g := clampf(base_g + grain * 0.7 + grain2 * 0.7, 0.0, 1.0)
			var b := clampf(base_b + grain * 0.4 + grain2 * 0.4, 0.0, 1.0)
			img.set_pixel(x, y, Color(r, g, b))
	return img


## ドット（目）を描画
static func _draw_dots(img: Image, value: int, size: int) -> void:
	var positions := _get_dot_positions(value, size)
	var radius := int(size * 0.1)
	for pos in positions:
		_draw_filled_circle(img, pos, radius, Color(0.95, 0.93, 0.88))


## ★マーク描画（特殊ダイス目=0用）
static func _draw_star(img: Image, size: int) -> void:
	var center := Vector2(size * 0.5, size * 0.5)
	var outer_r := size * 0.3
	var inner_r := size * 0.12
	var points := 5
	var gold := Color(1.0, 0.85, 0.3)

	for angle_step in range(points * 2):
		var angle := float(angle_step) * PI / float(points) - PI / 2.0
		var r := outer_r if angle_step % 2 == 0 else inner_r
		var next_angle := float(angle_step + 1) * PI / float(points) - PI / 2.0
		var next_r := outer_r if (angle_step + 1) % 2 == 0 else inner_r

		var p1 := center + Vector2(cos(angle) * r, sin(angle) * r)
		var p2 := center + Vector2(cos(next_angle) * next_r, sin(next_angle) * next_r)
		_fill_triangle(img, center, p1, p2, gold)


## 三角形を塗りつぶす
static func _fill_triangle(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, color: Color) -> void:
	var min_x := int(minf(minf(p0.x, p1.x), p2.x))
	var max_x := int(maxf(maxf(p0.x, p1.x), p2.x))
	var min_y := int(minf(minf(p0.y, p1.y), p2.y))
	var max_y := int(maxf(maxf(p0.y, p1.y), p2.y))

	for y in range(maxi(min_y, 0), mini(max_y + 1, img.get_height())):
		for x in range(maxi(min_x, 0), mini(max_x + 1, img.get_width())):
			if _point_in_triangle(Vector2(x, y), p0, p1, p2):
				img.set_pixel(x, y, color)


## 点が三角形内にあるか判定
static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign_2d(p, a, b)
	var d2 := _sign_2d(p, b, c)
	var d3 := _sign_2d(p, c, a)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)


static func _sign_2d(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)


## ドット位置を取得
static func _get_dot_positions(value: int, size: int) -> Array[Vector2i]:
	var m := int(size * 0.27)
	var c := int(size * 0.5)
	var e := size - m
	var tl := Vector2i(m, m)
	var top_r := Vector2i(e, m)
	var ml := Vector2i(m, c)
	var mc := Vector2i(c, c)
	var mr := Vector2i(e, c)
	var bl := Vector2i(m, e)
	var br := Vector2i(e, e)
	match value:
		1: return [mc]
		2: return [top_r, bl]
		3: return [top_r, mc, bl]
		4: return [tl, top_r, bl, br]
		5: return [tl, top_r, mc, bl, br]
		6: return [tl, top_r, ml, mr, bl, br]
		_: return [mc]


## アンチエイリアス付き塗りつぶし円
static func _draw_filled_circle(img: Image, center: Vector2i, radius: int, color: Color) -> void:
	var r_plus := radius + 1
	for y in range(maxi(center.y - r_plus, 0), mini(center.y + r_plus + 1, img.get_height())):
		for x in range(maxi(center.x - r_plus, 0), mini(center.x + r_plus + 1, img.get_width())):
			var dist := Vector2(x - center.x, y - center.y).length()
			if dist <= float(radius) + 0.5:
				var alpha := clampf(float(radius) + 0.5 - dist, 0.0, 1.0)
				var existing := img.get_pixel(x, y)
				img.set_pixel(x, y, existing.lerp(color, alpha))


## 縁に影をつける（立体感演出）
static func _draw_edge_shadow(img: Image, size: int) -> void:
	var border := 3
	var shadow_color := Color(0.3, 0.2, 0.1)
	for y in range(size):
		for x in range(size):
			var dist_to_edge := mini(mini(x, size - 1 - x), mini(y, size - 1 - y))
			if dist_to_edge < border:
				var t := float(border - dist_to_edge) / float(border) * 0.5
				var existing := img.get_pixel(x, y)
				img.set_pixel(x, y, existing.lerp(shadow_color, t))
