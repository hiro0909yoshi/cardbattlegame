class_name Dice3D
extends Node3D

## 3Dサイコロ（1個分）
## 6枚のSprite3Dで構成（BoxMesh不使用 → Z-fighting回避）

signal roll_finished

# ダイスの種類ごとの面の値
const DICE_FACES := {
	1: [0, 1, 2, 3, 4, 5],      # ダイス1: ★,1,2,3,4,5
	2: [0, 2, 3, 4, 5, 6],      # ダイス2: ★,2,3,4,5,6
	3: [1, 2, 3, 4, 5, 6],      # ダイス3: 1,2,3,4,5,6（通常）
}

# Sprite3Dのデフォルト向き = +Z方向
# 各面の外側を向くように回転
const FACE_POSITIONS := [
	{pos = Vector3(0, 0.5, 0), rot = Vector3(-90, 0, 0)},      # top (+Y)
	{pos = Vector3(0, -0.5, 0), rot = Vector3(90, 0, 0)},      # bottom (-Y)
	{pos = Vector3(0, 0, 0.5), rot = Vector3(0, 0, 0)},        # front (+Z)
	{pos = Vector3(0, 0, -0.5), rot = Vector3(0, 180, 0)},     # back (-Z)
	{pos = Vector3(0.5, 0, 0), rot = Vector3(0, 90, 0)},       # right (+X)
	{pos = Vector3(-0.5, 0, 0), rot = Vector3(0, -90, 0)},     # left (-X)
]

# 面インデックス: 各物理面にどのfaces[]インデックスを割り当てるか
# top=0, bottom=5, front=1, back=4, right=2, left=3
const FACE_INDEX_MAP := [0, 5, 1, 4, 2, 3]

var _dice_type: int = 1
var _faces: Array[int] = []


func setup(dice_type: int) -> void:
	_dice_type = dice_type
	_faces.assign(DICE_FACES.get(dice_type, DICE_FACES[3]))
	_build_mesh()


func _build_mesh() -> void:
	for i in range(FACE_POSITIONS.size()):
		var face_value: int = _faces[FACE_INDEX_MAP[i]]
		var fp: Dictionary = FACE_POSITIONS[i]
		var sprite := Sprite3D.new()
		sprite.texture = DiceTextureGenerator.create_face_texture(face_value)
		sprite.pixel_size = 1.0 / 128.0
		sprite.position = fp.pos
		sprite.rotation_degrees = fp.rot
		sprite.double_sided = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.shaded = true
		add_child(sprite)


func roll_to(value: int, delay: float = 0.0) -> void:
	var face_index: int = _faces.find(value)
	if face_index == -1:
		face_index = 0

	var target_rot: Vector3 = _get_rotation_for_face_index(face_index)

	var spin_x := randi_range(2, 3) * 360.0
	var spin_y := randi_range(1, 2) * 360.0
	var final_rot := target_rot + Vector3(spin_x, spin_y, 0)

	rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))

	var base_y := position.y

	var tween := create_tween()
	if delay > 0:
		tween.tween_interval(delay)
	var mid_rot := rotation_degrees.lerp(final_rot, 0.7)
	tween.tween_property(self, "rotation_degrees", mid_rot, 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "rotation_degrees", final_rot, 0.6)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_callback(roll_finished.emit)

	var bounce := create_tween()
	if delay > 0:
		bounce.tween_interval(delay)
	bounce.tween_property(self, "position:y", base_y + 0.8, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	bounce.tween_property(self, "position:y", base_y, 0.3)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	bounce.tween_property(self, "position:y", base_y + 0.2, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	bounce.tween_property(self, "position:y", base_y, 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _get_rotation_for_face_index(face_index: int) -> Vector3:
	# カメラの子なので、+Z方向（画面手前）に出目を向ける
	match face_index:
		0: return Vector3(90, 0, 0)       # top(+Y) → 手前(+Z)
		1: return Vector3(0, 0, 0)        # front(+Z) → そのまま
		2: return Vector3(0, -90, 0)      # right(+X) → 手前(+Z)
		3: return Vector3(0, 90, 0)       # left(-X) → 手前(+Z)
		4: return Vector3(0, 180, 0)      # back(-Z) → 手前(+Z)
		5: return Vector3(-90, 0, 0)      # bottom(-Y) → 手前(+Z)
		_: return Vector3.ZERO
