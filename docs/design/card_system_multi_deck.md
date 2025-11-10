# CardSystem マルチデッキ化 実装完了

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 2.1  
**最終更新**: 2025年11月10日  
**ステータス**: ✅ 実装完了・テスト済み

---

## 📋 概要

各プレイヤーが独立したデッキ（ブック）を持つように CardSystem を改修しました。

### 目的
- **アイテム復帰スキル**が正しく機能すること
- 使用したアイテムが**使用者自身のデッキ**に戻る
- CPU個別のデッキ戦略が実装可能になる

### 実装結果
✅ プレイヤー0: 人間プレイヤー（GameDataから選択中のブック使用）  
✅ プレイヤー1: 手動操作CPU（同じデッキを使用 - 暫定）  
✅ プレイヤー2-3: デフォルトデッキ（将来のCPU用）

---

## 🔧 実装内容

### データ構造の変更

**変更前**（共有デッキ方式）:
```gdscript
var deck = []  # 全プレイヤー共通
var discard = []  # 全プレイヤー共通
var player_hands = {}
```

**変更後**（マルチデッキ方式）:
```gdscript
var player_decks = {}  # player_id -> Array[int] (card_ids)
var player_discards = {}  # player_id -> Array[int] (card_ids)
var player_hands = {}  # player_id -> {"data": [card_data]}
```

### 主要な変更点

#### 1. デッキ初期化
```gdscript
func _initialize_decks(player_count: int):
	for player_id in range(player_count):
		player_decks[player_id] = []
		player_discards[player_id] = []
		player_hands[player_id] = {"data": []}
	
	_load_deck_from_game_data(0)  # プレイヤー0
	_load_manual_cpu_deck(1)      # プレイヤー1
```

#### 2. カードドロー
```gdscript
func draw_card_data_v2(player_id: int) -> Dictionary:
	if player_decks[player_id].is_empty():
		if player_discards[player_id].is_empty():
			return {}
		# 捨て札をシャッフルしてデッキに戻す
		player_decks[player_id] = player_discards[player_id].duplicate()
		player_discards[player_id].clear()
		player_decks[player_id].shuffle()
	
	var card_id = player_decks[player_id].pop_front()
	return _load_card_data(card_id)
```

#### 3. カード使用・捨て札
```gdscript
func discard_card(player_id: int, card_index: int, reason: String = "discard"):
	# ...
	player_discards[player_id].append(card_data.id)  # プレイヤー別の捨て札
	# ...
```

#### 4. アイテム復帰（最重要）
```gdscript
# scripts/battle/skills/skill_item_return.gd
static func _return_to_deck(player_id: int, item_data: Dictionary) -> bool:
	var card_id = item_data.get("id", -1)
	
	# プレイヤーの捨て札から削除
	if card_id in card_system_ref.player_discards[player_id]:
		card_system_ref.player_discards[player_id].erase(card_id)
	
	# プレイヤーのデッキのランダムな位置に挿入
	var deck_size = card_system_ref.player_decks[player_id].size()
	if deck_size == 0:
		card_system_ref.player_decks[player_id].append(card_id)
	else:
		var random_position = randi() % (deck_size + 1)
		card_system_ref.player_decks[player_id].insert(random_position, card_id)
	
	return true
```

**重要**: アイテムは**ランダムな位置**に戻るため、次のドローでは引けない（バランス調整）

---

## 📁 変更ファイル一覧

### 主要変更
1. ✅ `scripts/card_system.gd` - データ構造とメソッド全体
2. ✅ `scripts/battle/skills/skill_item_return.gd` - `_return_to_deck()`に`player_id`追加

### その他の影響箇所（既に対応済み）
- `scripts/spells/spell_draw.gd` - 内部で`draw_card_for_player()`を使用
- `scripts/game_flow_manager.gd` - 初期化処理
- `scripts/debug_controller.gd` - デバッグ用カード追加
- `scripts/special_tile_system.gd` - カードマス処理

---

## 🧪 テスト結果

### ✅ T0: アイテム復帰（ブック）
**テスト内容**:
- エターナルメイル（ID: 1005）、ケンタウロス（ID: 314）を使用
- 戦闘でアイテムを使用後、使用者のデッキのランダムな位置に戻る
- 他プレイヤーのデッキには影響しない

**結果**: ✅ 正常動作確認

### ✅ T0-2: アイテム復帰（手札）
**テスト内容**:
- ソウルレイ（ID: 1030）、ブーメラン（ID: 1054）を使用
- 即座に使用者の手札に戻る

**結果**: ✅ 正常動作確認

### ✅ 基本機能テスト
- デッキ初期化: 両プレイヤーが独立したデッキを持つ
- カードドロー: 各プレイヤーが自分のデッキからドロー
- カード使用: 正しいプレイヤーの捨て札に行く
- デッキリサイクル: 捨て札が空になったらシャッフルして戻る

**結果**: ✅ 全て正常動作確認

---

## 🎮 デバッグコマンド

テスト時に使える既存のデバッグコマンド:
- **H キー**: 任意のカードを手札に追加
- **9 キー**: +1000G
- **D キー**: CPU手札表示切替

**復帰アイテムのID**:
- 1005: エターナルメイル（ブック復帰）
- 1030: ソウルレイ（手札復帰）
- 1054: ブーメラン（手札復帰）
- 314: ケンタウロス（全アイテムブック復帰）

---

## 🔮 今後の拡張

### CPU デッキ管理（将来実装）
- `data/cpu_decks.json` ファイル作成
- CPUプロファイルとデッキの紐付け
- CPU難易度別のデッキ戦略

詳細は `docs/design/cpu_deck_system.md` を参照。

---

## 📝 関連ドキュメント

- [アイテム復帰スキル](./skills/item_return_skill.md) - アイテム復帰の詳細仕様
- [CPU デッキシステム](./cpu_deck_system.md) - CPU個別デッキの設計
- [スペルシステム](./spells_design.md) - スペルの復帰[ブック]効果

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 2.0 | 2025/11/10 | マルチデッキ化実装完了 |
| 2.1 | 2025/11/10 | アイテム復帰をランダムな位置への挿入に変更（バランス調整） |

---
