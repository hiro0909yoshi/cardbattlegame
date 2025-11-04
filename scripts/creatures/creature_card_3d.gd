extends Node3D
class_name CreatureCard3D
## タイル上に配置される3Dクリーチャーカード表示
##
## 既存の2D Card.tscnをSubViewportで描画し、
## Sprite3Dで3D空間に表示する

## 参照
var card_ui: Control = null  # 2Dカード本体
var viewport: SubViewport = null
var sprite_3d: Sprite3D = null

## クリーチャーデータ
var creature_data: Dictionary = {}

## カードシーンのパス
const CARD_SCENE_PATH = "res://scenes/Card.tscn"

func _ready():
	_setup_3d_card()

## 3Dカード表示のセットアップ
func _setup_3d_card():
	print("[CreatureCard3D] _setup_3d_card 開始")
	
	# SubViewportを作成
	viewport = SubViewport.new()
	viewport.size = Vector2i(240, 320)  # カードサイズ（2倍解像度）
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	print("[CreatureCard3D] SubViewport作成完了")
	
	# 2Dカードシーンをロード
	var card_scene = load(CARD_SCENE_PATH)
	if not card_scene:
		push_error("Card.tscn が見つかりません")
		return
	print("[CreatureCard3D] Card.tscnロード完了")
	
	card_ui = card_scene.instantiate()
	viewport.add_child(card_ui)
	print("[CreatureCard3D] Card UI instantiate完了")
	
	# カードのサイズを調整
	if card_ui:
		card_ui.size = Vector2(240, 320)
		card_ui.position = Vector2.ZERO
		print("[CreatureCard3D] Card UIサイズ設定完了: ", card_ui.size)
	
	# Sprite3Dを作成
	sprite_3d = Sprite3D.new()
	sprite_3d.texture = viewport.get_texture()
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # カメラに向く
	sprite_3d.pixel_size = 0.005  # サイズ調整
	sprite_3d.position = Vector3(0, 0.8, 0)  # タイルの上に浮かせる
	add_child(sprite_3d)
	
	# 透明度対応
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # ライティング影響なし
	sprite_3d.material_override = material

## クリーチャーデータを設定
func set_creature_data(data: Dictionary):
	creature_data = data.duplicate()
	_update_card_display()

## カード表示を更新
func _update_card_display():
	print("[CreatureCard3D] _update_card_display 開始")
	print("  card_ui: ", card_ui)
	print("  creature_data: ", creature_data)
	
	if not card_ui or creature_data.is_empty():
		print("[CreatureCard3D] card_uiがないか、creature_dataが空")
		return
	
	var creature_id = creature_data.get("id", -1)
	print("[CreatureCard3D] creature_id: ", creature_id)
	
	if creature_id > 0:
		# 既存のload_card_data関数を使用
		if card_ui.has_method("load_card_data"):
			print("[CreatureCard3D] load_card_dataを呼び出します")
			card_ui.load_card_data(creature_id)
			print("[CreatureCard3D] load_card_data完了")
		else:
			print("[CreatureCard3D] エラー: load_card_dataメソッドがありません")
		
		# ドラッグ・選択機能を無効化（マップ上では不要）
		card_ui.is_selectable = false
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

## カードの高さを設定
func set_height(height: float):
	if sprite_3d:
		sprite_3d.position.y = height

## カードのスケールを設定
func set_card_scale(scale_factor: float):
	if sprite_3d:
		sprite_3d.pixel_size = 0.005 * scale_factor

## クリーンアップ
func _exit_tree():
	if viewport:
		viewport.queue_free()
