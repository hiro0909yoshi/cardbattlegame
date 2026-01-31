extends Control
class_name AnnotationOverlay

## 注釈オーバーレイ
## インフォパネルの各部分を四角で囲み、説明へ線を引く

# 注釈データの構造:
# {
#   "target_rect": Rect2,      # 囲む対象の矩形（ローカル座標）
#   "label_pos": Vector2,      # 説明ラベルの位置
#   "label_text": String,      # 説明テキスト
#   "color": Color             # 線と枠の色（オプション）
# }

var annotations: Array[Dictionary] = []

# 描画設定
var line_color: Color = Color(1.0, 0.8, 0.2, 1.0)  # 黄色系
var line_width: float = 5.0
var rect_corner_radius: float = 4.0
var font_size: int = 28
var label_padding: Vector2 = Vector2(10, 5)

func _ready() -> void:
	# 背景は透明
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	for annotation in annotations:
		_draw_annotation(annotation)

func _draw_annotation(data: Dictionary) -> void:
	var target_rect: Rect2 = data.get("target_rect", Rect2())
	var label_pos: Vector2 = data.get("label_pos", Vector2.ZERO)
	var label_text: String = data.get("label_text", "")
	var color: Color = data.get("color", line_color)
	var bend_offset: float = data.get("bend_offset", 100.0)  # 折れ曲がり位置（枠からの距離）
	var line_direction: String = data.get("line_direction", "right")  # "right" or "top"
	var vertical_offset: float = data.get("vertical_offset", 0.0)  # 上方向へのオフセット（topの場合）
	
	if target_rect.size == Vector2.ZERO:
		return
	
	# 1. 対象を四角で囲む
	draw_rect(target_rect, color, false, line_width)
	
	# 2. 折れ線を描画
	var line_start: Vector2
	var mid_point1: Vector2
	var mid_point2: Vector2
	var line_end = label_pos
	
	if line_direction == "top":
		# 上から出るパターン: 上端中央 → 上へ → 右へ水平 → 斜めにラベルへ
		line_start = Vector2(target_rect.get_center().x, target_rect.position.y)
		mid_point1 = Vector2(line_start.x, line_start.y - vertical_offset)  # 上へ
		mid_point2 = Vector2(line_start.x + bend_offset, mid_point1.y)  # 右へ水平
		
		draw_line(line_start, mid_point1, color, line_width)
		draw_line(mid_point1, mid_point2, color, line_width)
		draw_line(mid_point2, line_end, color, line_width)
	elif line_direction == "right_top":
		# 右辺の上端から出るパターン: 右辺上端 → 右へ水平 → 斜めにラベルへ
		line_start = Vector2(target_rect.position.x + target_rect.size.x, target_rect.position.y)
		mid_point1 = Vector2(line_start.x + bend_offset, line_start.y)
		
		draw_line(line_start, mid_point1, color, line_width)
		draw_line(mid_point1, line_end, color, line_width)
	elif line_direction == "bottom_left":
		# 下辺の左端から出るパターン: 下辺左端 → 下へ → 右へ水平 → 斜めにラベルへ
		line_start = Vector2(target_rect.position.x, target_rect.position.y + target_rect.size.y)
		mid_point1 = Vector2(line_start.x, line_start.y + vertical_offset)  # 下へ
		mid_point2 = Vector2(mid_point1.x + bend_offset, mid_point1.y)  # 右へ水平
		
		draw_line(line_start, mid_point1, color, line_width)
		draw_line(mid_point1, mid_point2, color, line_width)
		draw_line(mid_point2, line_end, color, line_width)
	elif line_direction == "bottom":
		# 下辺の中央から出るパターン: 下辺中央 → 下へ → 右へ水平 → 斜めにラベルへ
		line_start = Vector2(target_rect.get_center().x, target_rect.position.y + target_rect.size.y)
		mid_point1 = Vector2(line_start.x, line_start.y + vertical_offset)  # 下へ
		mid_point2 = Vector2(mid_point1.x + bend_offset, mid_point1.y)  # 右へ水平
		
		draw_line(line_start, mid_point1, color, line_width)
		draw_line(mid_point1, mid_point2, color, line_width)
		draw_line(mid_point2, line_end, color, line_width)
	else:
		# 右から出るパターン（デフォルト）: 右端中央 → 右へ水平 → 斜めにラベルへ
		line_start = Vector2(target_rect.position.x + target_rect.size.x, target_rect.get_center().y)
		mid_point1 = Vector2(line_start.x + bend_offset, line_start.y)
		
		draw_line(line_start, mid_point1, color, line_width)
		draw_line(mid_point1, line_end, color, line_width)
	
	# 3. 説明テキストを描画（テキストがあれば）
	if label_text != "":
		_draw_label(label_pos, label_text, color)

func _get_rect_edge_point(rect: Rect2, target: Vector2) -> Vector2:
	## 矩形の端から目標点への最適な接続点を計算
	var center = rect.get_center()
	var direction = (target - center).normalized()
	
	# 矩形の各辺との交点を計算して最も近いものを返す
	var half_size = rect.size / 2.0
	
	# 右辺
	if direction.x > 0:
		var t = half_size.x / direction.x
		var y = direction.y * t
		if abs(y) <= half_size.y:
			return center + Vector2(half_size.x, y)
	
	# 左辺
	if direction.x < 0:
		var t = -half_size.x / direction.x
		var y = direction.y * t
		if abs(y) <= half_size.y:
			return center + Vector2(-half_size.x, y)
	
	# 下辺
	if direction.y > 0:
		var t = half_size.y / direction.y
		var x = direction.x * t
		if abs(x) <= half_size.x:
			return center + Vector2(x, half_size.y)
	
	# 上辺
	if direction.y < 0:
		var t = -half_size.y / direction.y
		var x = direction.x * t
		if abs(x) <= half_size.x:
			return center + Vector2(x, -half_size.y)
	
	return center

func _draw_label(pos: Vector2, text: String, color: Color) -> void:
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# 背景ボックス
	var bg_rect = Rect2(
		pos - label_padding,
		text_size + label_padding * 2
	)
	draw_rect(bg_rect, Color(0.1, 0.1, 0.15, 0.9), true)
	draw_rect(bg_rect, color, false, 2.0)
	
	# テキスト
	draw_string(font, pos + Vector2(0, text_size.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## 注釈を追加
## bend_offset: 枠から水平に伸ばす距離（その後斜めにラベルへ向かう）
## line_direction: "right"（右から出る）or "top"（上から出る）
## vertical_offset: 上方向へのオフセット（line_direction="top"の場合のみ有効）
func add_annotation(target_rect: Rect2, label_pos: Vector2, label_text: String, color: Color = Color.TRANSPARENT, bend_offset: float = 100.0, line_direction: String = "right", vertical_offset: float = 20.0) -> void:
	var annotation = {
		"target_rect": target_rect,
		"label_pos": label_pos,
		"label_text": label_text,
		"bend_offset": bend_offset,
		"line_direction": line_direction,
		"vertical_offset": vertical_offset
	}
	if color != Color.TRANSPARENT:
		annotation["color"] = color
	annotations.append(annotation)
	queue_redraw()

## Controlノードから矩形を取得して注釈を追加
func add_annotation_for_control(control: Control, label_pos: Vector2, label_text: String, color: Color = Color.TRANSPARENT) -> void:
	if control == null:
		return
	# Controlのグローバル位置をこのノードのローカル座標に変換
	var global_rect = control.get_global_rect()
	var local_pos = global_rect.position - get_global_position()
	var local_rect = Rect2(local_pos, global_rect.size)
	add_annotation(local_rect, label_pos, label_text, color)

## 全注釈をクリア
func clear_annotations() -> void:
	annotations.clear()
	queue_redraw()
