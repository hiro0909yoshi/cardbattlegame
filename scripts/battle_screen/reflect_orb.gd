class_name ReflectOrb
extends Control

## 反射エネルギー光球（赤系グラデーション）
## EnergyOrbの赤バージョン。反射攻撃で使用。

const RING_COUNT = 32
const GLOW_EXTRA_RATIO = 1.4


func _ready() -> void:
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _draw() -> void:
	var center = size / 2
	var max_radius = min(size.x, size.y) / 2

	if max_radius < 1.0:
		return

	# グローハロー（赤系の発光にじみ）
	var glow_rings = 12
	for i in range(glow_rings):
		var t = float(i) / float(glow_rings)
		var radius = max_radius * GLOW_EXTRA_RATIO * (1.0 - t * 0.3)
		var alpha = lerpf(0.0, 0.06, t)
		draw_circle(center, radius, Color(1.0, 0.3, 0.2, alpha))

	# 本体: 外側（赤）→内側（白黄）
	for i in range(RING_COUNT):
		var t = float(i) / float(RING_COUNT - 1)
		var radius = max_radius * (1.0 - t)

		if radius < 0.5:
			break

		var color = Color(
			lerpf(0.9, 1.0, sqrt(t)),           # R: 全体的に赤を強め
			lerpf(0.15, 0.85, t * t),            # G: 外側で赤、内側で黄白
			lerpf(0.1, 0.6, t * t),              # B: 外側で暗赤、内側でやや明るく
			lerpf(0.1, 0.9, sqrt(t))             # A: 外側はふんわり
		)

		draw_circle(center, radius, color)
