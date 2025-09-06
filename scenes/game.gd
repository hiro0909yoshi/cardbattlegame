extends Node2D

var card_scene = preload("res://scenes/Card.tscn")
var hand_cards = []

func _ready():
	print("ゲーム開始")
	create_hand()

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
