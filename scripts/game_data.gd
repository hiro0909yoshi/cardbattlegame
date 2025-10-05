extends Node

# グローバルデータ管理

# 選択中のブック番号（0〜5）
var selected_deck_index = 0

# プレイヤーデータ
var player_data = {
	"collection": {},  # 所持カード {card_id: count}
	"decks": []        # 6個のブック
}

func _ready():
	# 初期化：6個の空ブックを作成
	for i in range(6):
		player_data.decks.append({
			"name": "ブック" + str(i + 1),
			"cards": {}
		})
	
	# テスト用：いくつかカードを追加
	player_data.collection[1] = 4
	player_data.collection[2] = 3
	player_data.collection[5] = 2

func get_current_deck() -> Dictionary:
	return player_data.decks[selected_deck_index]

func save_deck(deck_index: int, cards: Dictionary):
	player_data.decks[deck_index]["cards"] = cards
	print("ブック", deck_index + 1, "を保存しました")
