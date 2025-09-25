extends BaseTile

func _ready():
	tile_type = "fire"
	base_color = Color(1.0, 0.4, 0.4)  # 赤系
	super._ready()

# 火属性の特別な演出（オプション）
func _on_area_entered(body):
	super._on_area_entered(body)
	# 必要なら火属性固有の演出を追加
