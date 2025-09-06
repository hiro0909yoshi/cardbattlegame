extends Node2D

var card_scene = preload("res://scenes/Card.tscn")
var hand_cards = []

# ボードマップ用の変数を追加
var board_tiles = []  # マスの配列
var total_tiles = 20  # マスの総数
var current_player_pos = 0  # プレイヤーの現在位置

# プレイヤー駒とUI用の変数を追加
var player_piece = null  # プレイヤーの駒
var dice_button = null  # サイコロボタン
var is_moving = false  # 移動中フラグ

func _ready():
	print("ゲーム開始")
	create_hand()
	create_board()
	create_player()  # プレイヤー駒を追加
	create_ui()  # UIを追加

func create_hand():
	for i in range(5):
		var card = card_scene.instantiate()
		$Hand.add_child(card)
		
		# カードを横に並べる
		card.position = Vector2(50 + i * 120, 200)
		
		# ランダムIDで読み込み
		var random_id = randi_range(1, 12)
		
		# has_methodでチェックしてから呼び出し
		if card.has_method("load_card_data"):
			card.load_card_data(random_id)
		
		hand_cards.append(card)

func create_board():
	# BoardMapノードが存在するかチェック
	if not has_node("BoardMap"):
		print("BoardMapノードが見つかりません")
		return
	
	var center = Vector2(400, 400)  # ボードの中心
	var radius = 150  # 円の半径
	
	for i in range(total_tiles):
		# 円形にマスを配置
		var angle = (2 * PI * i) / total_tiles - PI/2
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		
		# マスを表す簡単な四角形を作成
		var tile = ColorRect.new()
		tile.size = Vector2(30, 30)
		tile.position = pos - tile.size / 2  # 中心に配置
		
		# マスの色を設定（仮）
		if i == 0:
			tile.color = Color(1.0, 0.9, 0.3)  # スタート地点は金色
		elif i % 5 == 0:
			tile.color = Color(0.3, 0.8, 0.3)  # 5マスごとに緑
		else:
			# 通常マスはランダムな属性色
			var colors = [
				Color(1.0, 0.4, 0.4),  # 火（赤）
				Color(0.4, 0.6, 1.0),  # 水（青）
				Color(0.4, 1.0, 0.6),  # 風（緑）
				Color(0.8, 0.6, 0.3)   # 土（茶）
			]
			tile.color = colors[randi() % colors.size()]
		
		$BoardMap.add_child(tile)
		board_tiles.append(tile)
	
	print("ボードマップ生成完了: ", total_tiles, "マス")

# プレイヤー駒を作成
func create_player():
	player_piece = ColorRect.new()
	player_piece.size = Vector2(20, 20)
	player_piece.color = Color(1, 1, 1)  # 白色の駒
	player_piece.z_index = 10  # マスより前面に表示
	
	# スタート地点に配置
	if board_tiles.size() > 0:
		var start_tile = board_tiles[0]
		player_piece.position = start_tile.position + start_tile.size/2 - player_piece.size/2
	
	add_child(player_piece)
	print("プレイヤー駒を配置")

# UIを作成
func create_ui():
	# サイコロボタン
	dice_button = Button.new()
	dice_button.text = "サイコロを振る"
	dice_button.position = Vector2(350, 250)
	dice_button.size = Vector2(120, 40)
	dice_button.pressed.connect(_on_dice_pressed)
	add_child(dice_button)

# サイコロボタンが押されたとき
func _on_dice_pressed():
	if is_moving:
		return  # 移動中は無効
	
	# サイコロを振る
	var dice_value = randi_range(1, 6)
	print("サイコロの目: ", dice_value)
	
	# サイコロの目を表示
	show_dice_result(dice_value)
	
	# 移動開始
	move_player(dice_value)

# サイコロの結果を表示
func show_dice_result(value: int):
	var dice_label = Label.new()
	dice_label.text = "🎲 " + str(value)
	dice_label.add_theme_font_size_override("font_size", 48)
	dice_label.position = Vector2(350, 300)
	add_child(dice_label)
	
	# 1秒後に消す
	await get_tree().create_timer(1.0).timeout
	dice_label.queue_free()

# プレイヤーを移動
func move_player(steps: int):
	is_moving = true
	dice_button.disabled = true
	
	# 1マスずつ移動
	for i in range(steps):
		await get_tree().create_timer(0.3).timeout  # 0.3秒待機
		
		# 次のマスへ
		current_player_pos = (current_player_pos + 1) % total_tiles
		var target_tile = board_tiles[current_player_pos]
		
		# 駒を移動
		player_piece.position = target_tile.position + target_tile.size/2 - player_piece.size/2
		
		print("マス ", current_player_pos, " に移動")
	
	# 移動完了
	is_moving = false
	dice_button.disabled = false
	print("移動完了！現在位置: マス", current_player_pos)
