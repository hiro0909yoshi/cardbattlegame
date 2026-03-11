class_name EnergyOrb
extends Control

## エネルギー光球（_draw()ベースのなめらかグラデーション）
## 同心円を多数描画して、外側（薄い青）→内側（白）のグラデーションを実現

const RING_COUNT = 32  # 同心円の数（多いほどなめらか）
const GLOW_EXTRA_RATIO = 1.4  # グロー範囲（本体の1.4倍まで発光）


func _ready() -> void:
	# 加算ブレンドで発光表現
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _draw() -> void:
	var center = size / 2
	var max_radius = min(size.x, size.y) / 2

	if max_radius < 1.0:
		return

	# グローハロー（本体の外側ににじみ出る発光）
	var glow_rings = 12
	for i in range(glow_rings):
		var t = float(i) / float(glow_rings)  # 0.0(最外周) → 1.0(本体端)
		var radius = max_radius * GLOW_EXTRA_RATIO * (1.0 - t * 0.3)
		var alpha = lerpf(0.0, 0.06, t)
		draw_circle(center, radius, Color(0.3, 0.55, 1.0, alpha))

	# 本体: 外側から内側に向かって同心円を描画
	for i in range(RING_COUNT):
		var t = float(i) / float(RING_COUNT - 1)  # 0.0(外側) → 1.0(コア)
		var radius = max_radius * (1.0 - t)

		if radius < 0.5:
			break

		# 色: 外側は青みのある水色、内側は白青の光
		var color = Color(
			lerpf(0.2, 0.92, t * t),        # R: 外側を少し抑えて青みを出す
			lerpf(0.4, 0.95, t * t),        # G: 外側で青緑っぽさを出す
			lerpf(0.9, 1.0, sqrt(t)),        # B: 全体的に青を強めに維持
			lerpf(0.1, 0.9, sqrt(t))         # A: 外側はふんわり薄く
		)

		draw_circle(center, radius, color)
