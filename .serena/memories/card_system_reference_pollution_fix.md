# CardSystemの参照汚染バグ - 修正方針 (2025-11-16)

## バグの本質

CardLoaderのall_cardsが**ゲーム中に直接修正される**ため、全プレイヤーの同じカードIDが共有される。

## 原因箇所

**scripts/card_system.gd の_load_card_data()関数 (line 154-176)**

```gdscript
func _load_card_data(card_id: int) -> Dictionary:
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		// ここでCardLoader.all_cardsから参照を取得
		
		// costを正規化
		if card_data.has("cost"):
			if typeof(card_data.cost) == TYPE_DICTIONARY:
				if card_data.cost.has("mp"):
					card_data.cost = card_data.cost.mp
				else:
					card_data.cost = 1
		else:
			card_data.cost = 1
		
		return card_data  // ← 参照をそのまま返している
```

## 修正内容

**line 176の前に以下を追加:**

```gdscript
func _load_card_data(card_id: int) -> Dictionary:
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			print("WARNING: カードID ", card_id, " が見つかりません")
			return {}
		
		# ★ ディープコピーを追加 ★
		card_data = card_data.duplicate(true)
		
		# costを正規化
		if card_data.has("cost"):
			if typeof(card_data.cost) == TYPE_DICTIONARY:
				if card_data.cost.has("mp"):
					card_data.cost = card_data.cost.mp
				else:
					card_data.cost = 1
		else:
			card_data.cost = 1
		
		return card_data  // ← コピーを返す
	else:
		print("ERROR: CardLoaderが見つかりません")
		return {}
```

## 効果

- 手札内の各カードは独立したデータを保持する
- バトル中の永続バフ（base_up_hp等）がCardLoaderに影響しない
- プレイヤー間でカードの状態が混在しない

## 検証方法

1. プレイヤー2でダスクドウェラーを複数回使用（+30になる）
2. プレイヤー1でダスクドウェラーを使用
3. base_up_hpが0の状態で出現することを確認
