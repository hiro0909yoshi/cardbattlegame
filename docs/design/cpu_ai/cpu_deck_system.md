# CPUデッキ管理システム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**作成日**: 2025年11月10日  
**ステータス**: 構想のみ（実装は将来）

---

## 📋 目次

1. [概要](#概要)
2. [データ構造](#データ構造)
3. [デッキ管理](#デッキ管理)
4. [マップ連携](#マップ連携)
5. [実装イメージ](#実装イメージ)
6. [将来の拡張](#将来の拡張)

---

## 概要

### 目的
CPUプレイヤーが複数のデッキを所持し、マップごとに適切なデッキを使用できるシステムを構築する。

### 要件
- 各CPUは最大6個のデッキを所持
- デッキはCPU ID と デッキ番号で識別
- マップデータで使用するデッキを指定
- 運営側（開発者）が全てのデッキを管理

### 対象外（今回は実装しない）
- プレイヤーによるCPUデッキの編集
- ゲーム内でのデッキアンロック
- CPUデッキのランダム生成

---

## データ構造

### CPUデッキファイル構造

#### ファイル配置
```
data/
├── cpu_decks.json          # CPUデッキ定義
└── maps/
	├── map_001.json        # マップデータ（CPU割り当て含む）
	└── ...
```

#### cpu_decks.json の構造

```json
{
  "version": "1.0",
  "last_updated": "2025-11-10",
  "cpu_decks": {
	"cpu_1": {
	  "name": "テストCPU",
	  "description": "デバッグ・テスト用のCPU",
	  "decks": [
		{
		  "deck_id": 0,
		  "name": "バランス型",
		  "description": "バランスの取れた基本デッキ",
		  "difficulty": "easy",
		  "cards": {
			"1": 3,   // ゴブリン x3
			"2": 3,   // コボルト x3
			"100": 2, // ファイアボール x2
			"200": 1  // ヒールx1
			// ... 合計50枚
		  }
		},
		{
		  "deck_id": 1,
		  "name": "炎属性速攻",
		  "description": "低コストクリーチャー中心の速攻デッキ",
		  "difficulty": "normal",
		  "cards": {
			"1": 4,   // ゴブリン x4
			"41": 2,  // フレイムデューク x2
			// ...
		  }
		},
		{
		  "deck_id": 2,
		  "name": "防御重視",
		  "description": "高HPクリーチャーと防具中心",
		  "difficulty": "normal",
		  "cards": {
			// ...
		  }
		},
		{
		  "deck_id": 3,
		  "name": "コンボ型",
		  "description": "特定の組み合わせを狙うデッキ",
		  "difficulty": "hard",
		  "cards": {
			// ...
		  }
		},
		{
		  "deck_id": 4,
		  "name": "未使用",
		  "description": "",
		  "difficulty": "",
		  "cards": {}
		},
		{
		  "deck_id": 5,
		  "name": "未使用",
		  "description": "",
		  "difficulty": "",
		  "cards": {}
		}
	  ]
	},
	"cpu_2": {
	  "name": "初心者CPU",
	  "description": "チュートリアル用の弱いCPU",
	  "decks": [
		// ... 最大6個
	  ]
	},
	"cpu_3": {
	  "name": "上級CPU",
	  "description": "高難易度用の強いCPU",
	  "decks": [
		// ... 最大6個
	  ]
	}
  }
}
```

### CPUプロファイル（拡張用）

将来的にAI実装時に使用：

```json
{
  "cpu_decks": {
	"cpu_1": {
	  "name": "テストCPU",
	  "ai_profile": {
		"difficulty_level": 3,
		"aggression": 0.6,
		"resource_management": 0.5,
		"combo_seeking": 0.3
	  },
	  "decks": [...]
	}
  }
}
```

---

## デッキ管理

### デッキの識別

#### CPU ID
- `cpu_1`, `cpu_2`, `cpu_3` など
- 各CPUは独立したエンティティ
- 6個のデッキスロットを持つ

#### デッキ ID
- 0-5 の整数（最大6個）
- CPU内で一意
- 空きスロットも定義可能

#### 完全修飾名
```
cpu_1.deck_0  // CPU 1 のデッキ0
cpu_2.deck_3  // CPU 2 のデッキ3
```

### デッキのバリデーション

ロード時にチェック：
- カード枚数：50枚（固定）
- カードID：有効なIDのみ
- 同一カード上限：制限なし（原作カルドセプトと同じ）

```gdscript
func validate_cpu_deck(deck_data: Dictionary) -> bool:
	var total_cards = 0
	for card_id in deck_data.cards.keys():
		var count = deck_data.cards[card_id]
		total_cards += count
		
		# カードIDの存在確認
		if not CardLoader.has_card(card_id):
			push_error("Invalid card ID: ", card_id)
			return false
	
	if total_cards != 50:
		push_error("Deck must have exactly 50 cards, got: ", total_cards)
		return false
	
	return true
```

---

## マップ連携

### マップデータへのCPU割り当て

#### maps/map_001.json の例

```json
{
  "map_id": 1,
  "map_name": "初心者の森",
  "description": "チュートリアル用マップ",
  "player_count": 2,
  "cpu_assignments": [
	{
	  "player_slot": 1,
	  "cpu_id": "cpu_1",
	  "deck_id": 0,
	  "deck_name": "バランス型"
	}
  ],
  "tiles": [
	// ... タイル定義
  ]
}
```

#### 4人対戦マップの例

```json
{
  "map_id": 5,
  "map_name": "四大元素の戦い",
  "player_count": 4,
  "cpu_assignments": [
	{
	  "player_slot": 1,
	  "cpu_id": "cpu_1",
	  "deck_id": 1,
	  "deck_name": "炎属性速攻"
	},
	{
	  "player_slot": 2,
	  "cpu_id": "cpu_2",
	  "deck_id": 2,
	  "deck_name": "水属性防御"
	},
	{
	  "player_slot": 3,
	  "cpu_id": "cpu_3",
	  "deck_id": 4,
	  "deck_name": "風属性コンボ"
	}
  ]
}
```

### ゲーム開始時の処理フロー

```
1. マップ選択
   ↓
2. マップデータ読み込み
   ↓
3. cpu_assignments を解析
   ↓
4. 各CPUのデッキを cpu_decks.json から読み込み
   ↓
5. CardSystem に各プレイヤーのデッキを設定
   ↓
6. ゲーム開始
```

---

## 実装イメージ

### CPUDeckLoader クラス（新規）

```gdscript
# scripts/cpu_deck_loader.gd
class_name CPUDeckLoader

const CPU_DECKS_PATH = "res://data/cpu_decks.json"

static var cpu_decks_data: Dictionary = {}

## CPUデッキファイルをロード
static func load_cpu_decks() -> bool:
	if not FileAccess.file_exists(CPU_DECKS_PATH):
		push_error("CPU decks file not found: ", CPU_DECKS_PATH)
		return false
	
	var file = FileAccess.open(CPU_DECKS_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open CPU decks file")
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("Failed to parse CPU decks JSON: ", json.get_error_message())
		return false
	
	cpu_decks_data = json.get_data()
	print("✅ CPUデッキファイル読み込み完了")
	return true

## 特定のCPUデッキを取得
static func get_cpu_deck(cpu_id: String, deck_id: int) -> Dictionary:
	if not cpu_decks_data.has("cpu_decks"):
		push_error("cpu_decks not found in data")
		return {}
	
	var cpu_data = cpu_decks_data.cpu_decks.get(cpu_id, {})
	if cpu_data.is_empty():
		push_error("CPU not found: ", cpu_id)
		return {}
	
	var decks = cpu_data.get("decks", [])
	if deck_id < 0 or deck_id >= decks.size():
		push_error("Invalid deck_id: ", deck_id, " for CPU: ", cpu_id)
		return {}
	
	var deck = decks[deck_id]
	if deck.get("cards", {}).is_empty():
		push_warning("Deck is empty: ", cpu_id, ".deck_", deck_id)
	
	return deck

## デッキをCardSystem用の形式に変換
static func convert_to_card_ids(deck_data: Dictionary) -> Array:
	var card_ids = []
	var cards_dict = deck_data.get("cards", {})
	
	for card_id_str in cards_dict.keys():
		var card_id = int(card_id_str)
		var count = cards_dict[card_id_str]
		
		for i in range(count):
			card_ids.append(card_id)
	
	return card_ids
```

### CardSystem への統合

```gdscript
# scripts/card_system.gd に追加

func _load_cpu_deck(player_id: int, cpu_id: String, deck_id: int):
	var deck_data = CPUDeckLoader.get_cpu_deck(cpu_id, deck_id)
	
	if deck_data.is_empty():
		push_error("Failed to load CPU deck: ", cpu_id, ".deck_", deck_id)
		_load_default_deck(player_id)
		return
	
	var card_ids = CPUDeckLoader.convert_to_card_ids(deck_data)
	player_decks[player_id] = card_ids
	player_decks[player_id].shuffle()
	
	print("✅ Player ", player_id, ": ", deck_data.get("name", "?"), 
		  " 読み込み (", card_ids.size(), "枚)")
```

### ゲーム開始時の初期化

```gdscript
# scripts/game_flow_manager.gd

func initialize_game(map_data: Dictionary):
	# CPUデッキファイルをロード（初回のみ）
	if not CPUDeckLoader.cpu_decks_data.is_empty():
		CPUDeckLoader.load_cpu_decks()
	
	# マップのCPU割り当てを取得
	var cpu_assignments = map_data.get("cpu_assignments", [])
	
	# CardSystemに各プレイヤーのデッキソースを設定
	for assignment in cpu_assignments:
		var player_slot = assignment.player_slot
		var cpu_id = assignment.cpu_id
		var deck_id = assignment.deck_id
		
		card_system.set_deck_source(player_slot, {
			"type": "cpu",
			"cpu_id": cpu_id,
			"deck_id": deck_id
		})
	
	# デッキ初期化
	card_system.initialize_all_decks(map_data.player_count)
```

---

## 将来の拡張

### Phase 1: 基本実装（構想のみ）
- cpu_decks.json ファイル作成
- CPUDeckLoader クラス実装
- マップデータとの連携

### Phase 2: デッキエディタ
- 開発者向けのCPUデッキエディタUI
- デッキのバリデーション機能
- デッキのインポート/エクスポート

### Phase 3: 動的デッキ選択
- マップの難易度に応じて自動的にデッキを選択
- プレイヤーの進行状況に応じたデッキ変更

### Phase 4: AI統合
- デッキごとの戦術プロファイル
- AI思考レベルとデッキの紐付け
- 詳細は `docs/design/cpu_ai_design.md` を参照

---

## 実装スケジュール（将来）

| フェーズ | 作業内容 | 推定時間 |
|---------|---------|---------|
| データ設計 | cpu_decks.json 構造確定 | 1時間 |
| CPUDeckLoader | ローダークラス実装 | 2時間 |
| CardSystem統合 | デッキソース管理 | 1.5時間 |
| マップ連携 | ゲーム開始時の初期化 | 1.5時間 |
| テスト | 動作確認 | 2時間 |
| **合計** | | **8時間** |

---

## 注意事項

### デッキ設計のガイドライン

#### バランス型デッキ
- 低コスト：15-20枚
- 中コスト：20-25枚
- 高コスト：5-10枚
- スペル：3-5枚
- アイテム：3-5枚

#### 速攻型デッキ
- 低コスト：25-30枚
- 中コスト：15-20枚
- 高コスト：0-5枚
- 武器多め

#### 堅守デッキ
- 低コスト：10-15枚
- 中コスト：15-20枚
- 高コスト：15-20枚
- 防具多め

### デッキ命名規則
- 簡潔で分かりやすい名前
- 戦術を表す名前推奨
- 例: 「炎速攻」「水防御」「風コンボ」「土バランス」

### メンテナンス
- 新カード追加時はCPUデッキも更新
- バランス調整後はデッキの見直し
- 定期的にデッキの勝率を記録

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2025/11/10 | 初版作成：CPUデッキ管理システム構想 |

---
