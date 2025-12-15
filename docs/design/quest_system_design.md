# クエストシステム設計書

**バージョン**: 1.0  
**作成日**: 2025年12月15日  
**ステータス**: 設計完了、実装待ち

---

## 📋 目次

1. [概要](#概要)
2. [システム構成](#システム構成)
3. [ディレクトリ構造](#ディレクトリ構造)
4. [JSONスキーマ設計](#jsonスキーマ設計)
5. [CPU AI設計](#cpu-ai設計)
6. [実装ロードマップ](#実装ロードマップ)
7. [将来のサーバー移行](#将来のサーバー移行)

---

## 概要

### 目的

ソロプレイ用のクエストモードを実装する。プレイヤーはワールドを進行し、各ステージでCPU敵と対戦する。

### 基本仕様

| 項目 | 内容 |
|------|------|
| ステージ数 | 20以上 |
| マップ種類 | 10種類（使い回し） |
| 敵キャラ | 10種類（使い回し） |
| プレイヤー構成 | 1人 vs CPU 1〜3体 |
| 進行方式 | ワールド制（1-1 → 1-2 → 1-3、並行して2-1 → 2-2等） |

### 既存システムとの関係

```
MainMenu
├── ソロバトル → Main.tscn（既存のテスト環境、変更なし）
└── クエスト → StageSelect.tscn（新規）
			  └── Quest.tscn（動的にマップ生成）
```

---

## システム構成

### データの分類

| 種類 | 説明 | ファイル数 | 再利用 |
|------|------|-----------|--------|
| ワールド定義 | ワールド一覧・解放条件 | 1 | - |
| ステージ定義 | マップID + 敵構成 + 勝利条件 | ステージ数分 | - |
| マップ定義 | タイル配置・接続・座標 | 10程度 | ✓ |
| キャラクター定義 | 名前・3Dモデルパス | 1 | ✓ |
| デッキ定義 | カードIDリスト | 10〜20程度 | ✓ |
| AIプロファイル | 戦略パラメータ | 5〜10程度 | ✓ |

### 参照方式

ステージ定義はIDで他のデータを参照する：

```
stage_1_1.json
	├── map_id: "map_diamond_20" → maps/map_diamond_20.json
	└── enemies[0]
			├── character_id: "goblin" → characters.json
			├── deck_id: "deck_fire_basic" → decks/deck_fire_basic.json
			└── ai_profile_id: "aggressive" → ai_profiles/aggressive.json
```

**メリット**: 1ステージ追加 = stage_X_X.json 1ファイル追加のみ

---

## ディレクトリ構造

```
data/
├── master/                          # マスターデータ（将来サーバー移行）
│   ├── worlds/
│   │   └── world_list.json          # ワールド一覧・解放条件
│   ├── stages/
│   │   ├── stage_1_1.json           # ステージ定義
│   │   ├── stage_1_2.json
│   │   ├── stage_1_3.json
│   │   └── stage_2_1.json
│   ├── maps/
│   │   ├── map_diamond_20.json      # 現在のMain.tscnベース
│   │   └── map_square_24.json
│   ├── characters/
│   │   └── characters.json          # 全CPUキャラ定義
│   ├── decks/
│   │   ├── deck_fire_basic.json
│   │   ├── deck_water_control.json
│   │   └── deck_balanced.json
│   └── ai_profiles/
│       ├── aggressive.json
│       ├── defensive.json
│       └── balanced.json
│
└── local/                           # ユーザーデータ（将来サーバー移行）
	└── user_save.json               # 進行状況、所持カード等
```

---

## JSONスキーマ設計

### 1. world_list.json（ワールド一覧）

```json
{
  "worlds": [
	{
	  "id": "world_1",
	  "name": "草原の国",
	  "stages": ["stage_1_1", "stage_1_2", "stage_1_3"],
	  "unlock_condition": null
	},
	{
	  "id": "world_2",
	  "name": "炎の国",
	  "stages": ["stage_2_1", "stage_2_2", "stage_2_3"],
	  "unlock_condition": {"type": "stage_clear", "stage_id": "stage_1_1"}
	}
  ]
}
```

### 2. stage_X_X.json（ステージ定義）

```json
{
  "id": "stage_1_1",
  "name": "はじまりの草原",
  "description": "最初の試練。基本を学ぼう。",
  "map_id": "map_diamond_20",
  "player_start_tile": 0,
  "player_start_magic": 1000,
  "enemies": [
	{
	  "player_id": 1,
	  "character_id": "goblin",
	  "deck_id": "deck_fire_basic",
	  "ai_profile_id": "aggressive",
	  "start_tile": 10,
	  "start_magic": 800
	}
  ],
  "win_condition": {
	"type": "magic",
	"target": 8000
  },
  "lose_condition": {
	"type": "bankrupt"
  },
  "rewards": {
	"first_clear": {"type": "card", "card_id": 101},
	"repeat": {"type": "gold", "amount": 500}
  }
}
```

### 3. map_*.json（マップ定義）

```json
{
  "id": "map_diamond_20",
  "name": "ダイヤモンド型",
  "tile_count": 20,
  "tiles": [
	{"index": 0, "type": "Checkpoint", "x": 0, "z": 0, "checkpoint_type": "N"},
	{"index": 1, "type": "Neutral", "x": 4, "z": 0},
	{"index": 2, "type": "Neutral", "x": 8, "z": 0},
	{"index": 3, "type": "Neutral", "x": 12, "z": 0},
	{"index": 4, "type": "Neutral", "x": 16, "z": 0},
	{"index": 5, "type": "Warp", "x": 20, "z": 0, "warp_pair": 15},
	{"index": 6, "type": "Fire", "x": 20, "z": 4},
	{"index": 7, "type": "Fire", "x": 20, "z": 8},
	{"index": 8, "type": "Fire", "x": 20, "z": 12},
	{"index": 9, "type": "Water", "x": 20, "z": 16},
	{"index": 10, "type": "Checkpoint", "x": 20, "z": 20, "checkpoint_type": "S"},
	{"index": 11, "type": "Water", "x": 16, "z": 20},
	{"index": 12, "type": "Water", "x": 12, "z": 20},
	{"index": 13, "type": "Wind", "x": 8, "z": 20},
	{"index": 14, "type": "Wind", "x": 4, "z": 20},
	{"index": 15, "type": "Warp", "x": 0, "z": 20, "warp_pair": 5},
	{"index": 16, "type": "Wind", "x": 0, "z": 16},
	{"index": 17, "type": "Earth", "x": 0, "z": 12},
	{"index": 18, "type": "Earth", "x": 0, "z": 8},
	{"index": 19, "type": "Earth", "x": 0, "z": 4}
  ],
  "connections": {
	"0": [1, 19, 20]
  },
  "special_tiles": {
	"20": {"type": "Branch", "connections": [0, 21]},
	"21": {"type": "Treasure", "connections": [20]}
  }
}
```

### 4. characters.json（キャラクター定義）

```json
{
  "characters": {
	"goblin": {
	  "name": "ゴブリン",
	  "model_path": "res://scenes/Characters/Goblin.tscn",
	  "portrait_path": "res://assets/portraits/goblin.png",
	  "description": "小さいが凶暴な魔物"
	},
	"knight": {
	  "name": "騎士",
	  "model_path": "res://scenes/Characters/Knight.tscn",
	  "portrait_path": "res://assets/portraits/knight.png",
	  "description": "正義を信じる戦士"
	},
	"witch": {
	  "name": "魔女",
	  "model_path": "res://scenes/Characters/Witch.tscn",
	  "portrait_path": "res://assets/portraits/witch.png",
	  "description": "スペルの達人"
	}
  }
}
```

### 5. deck_*.json（デッキ定義）

```json
{
  "id": "deck_fire_basic",
  "name": "炎の基本デッキ",
  "description": "火属性中心の攻撃的デッキ",
  "cards": [
	{"card_id": 1, "count": 3},
	{"card_id": 5, "count": 2},
	{"card_id": 12, "count": 4},
	{"card_id": 101, "count": 2}
  ],
  "total_cards": 50
}
```

### 6. ai_profiles/*.json（AIプロファイル）

```json
{
  "id": "aggressive",
  "name": "攻撃的",
  "description": "積極的に侵略を仕掛ける",
  "difficulty_level": 5,
  "parameters": {
	"aggression": 0.8,
	"resource_management": 0.3,
	"risk_tolerance": 0.7,
	"combo_seeking": 0.4
  },
  "behavior": {
	"summon_rate": 0.8,
	"invasion_rate": 0.7,
	"battle_rate": 0.6,
	"levelup_rate": 0.4
  },
  "features": {
	"basic_evaluation": true,
	"tempo_evaluation": true,
	"synergy_evaluation": true,
	"lookahead": 1
  }
}
```

### 7. user_save.json（ユーザーデータ）

```json
{
  "user_id": "local_user",
  "cleared_stages": ["stage_1_1", "stage_1_2"],
  "unlocked_worlds": ["world_1", "world_2"],
  "owned_cards": [
	{"card_id": 1, "count": 3},
	{"card_id": 5, "count": 1}
  ],
  "gold": 5000,
  "player_decks": [
	{
	  "name": "メインデッキ",
	  "cards": [1, 1, 5, 12, 12]
	}
  ],
  "last_played": "2025-12-15T10:30:00Z"
}
```

---

## CPU AI設計

### 既存実装

| クラス | 役割 | 状態 |
|--------|------|------|
| `CPUAIHandler` | 判断ロジック | ✓ 実装済み |
| `CPUTurnProcessor` | ターン実行 | ✓ 実装済み |

### 動作切り替え

```gdscript
# ソロバトル（テスト用）
player_is_cpu = [false, true]
debug_manual_control_all = true  # CPUも手動操作

# クエストモード
player_is_cpu = [false, true, true, true]
debug_manual_control_all = false  # CPUはAI任せ
```

### AIプロファイル適用

```gdscript
# StageLoaderで設定
func setup_cpu_players(stage_data: Dictionary):
	for enemy in stage_data.enemies:
		var profile = load_ai_profile(enemy.ai_profile_id)
		cpu_ai_handler.set_profile(enemy.player_id, profile)
```

### CPUAIHandlerへの追加（将来実装）

```gdscript
# AI プロファイルを保持
var ai_profiles: Dictionary = {}

func set_profile(player_id: int, profile: Dictionary):
	ai_profiles[player_id] = profile

func get_summon_rate(player_id: int) -> float:
	var profile = ai_profiles.get(player_id, {})
	return profile.get("behavior", {}).get("summon_rate", 0.5)
```

### 難易度レベルと機能

| Level | 基本評価 | テンポ評価 | シナジー | 先読み | ランダム要素 |
|-------|---------|-----------|---------|--------|-------------|
| 1-3 | ✓ | - | - | 0 | 30% |
| 4-6 | ✓ | ✓ | ✓ | 1 | 10% |
| 7-10 | ✓ | ✓ | ✓ | 2 | 0% |

---

## 実装ロードマップ

### Phase 1: 基盤構築（推定: 3-4時間）

1. ディレクトリ構造作成
2. JSONスキーマ確定
3. 既存Main.tscnを`map_diamond_20.json`に変換
4. `stage_1_1.json`作成（テスト用）

**成果物:**
- `data/master/` ディレクトリ
- 初期JSONファイル群

### Phase 2: ローダー実装（推定: 4-5時間）

1. `StageLoader.gd` - JSON読み込み・マップ動的生成
2. `QuestManager.gd` - 進行管理
3. `Quest.tscn` - クエスト用メインシーン

**成果物:**
```gdscript
# scripts/quest/stage_loader.gd
class_name StageLoader
func load_stage(stage_id: String) -> void
func generate_map(map_data: Dictionary) -> void
func setup_enemies(enemies: Array) -> void
```

### Phase 3: UI実装（推定: 3-4時間）

1. `StageSelect.tscn` - ステージ選択画面
2. `WorldSelect.tscn` - ワールド選択画面
3. MainMenuへの導線追加

**成果物:**
- ステージ選択UI
- ワールドマップ風UI（オプション）

### Phase 4: CPU AI強化（推定: 5-8時間）

1. AIプロファイル読み込み
2. 難易度別の評価関数
3. 先読み機能（Level 7+）

**成果物:**
- `CPUAIHandler`の拡張
- AIプロファイルJSON

### Phase 5: テスト・調整（推定: 3-5時間）

1. ステージ1-1〜1-3をプレイテスト
2. AI難易度調整
3. バグ修正

---

## 将来のサーバー移行

### 現在の設計思想

```
data/
├── master/   ← 将来サーバーへ（構造変更なし）
└── local/    ← 将来サーバーDBへ
```

### 移行時の変更点

| 項目 | 現在 | 移行後 |
|------|------|--------|
| マスターデータ読み込み | `FileAccess.open()` | `HTTPRequest` |
| ユーザーデータ保存 | `user_save.json` | サーバーAPI |
| 認証 | なし | OAuth等 |

### ローダーの抽象化

```gdscript
# 今
class DataLoader:
	func load_stage(stage_id: String) -> Dictionary:
		var file = FileAccess.open("res://data/master/stages/%s.json" % stage_id, FileAccess.READ)
		return JSON.parse_string(file.get_as_text())

# 将来（差し替えるだけ）
class DataLoader:
	func load_stage(stage_id: String) -> Dictionary:
		var response = await http.request("https://api.example.com/stages/%s" % stage_id)
		return JSON.parse_string(response.body)
```

**JSONの構造は変わらない。読み込み方法だけ変更。**

### 課金ガチャ対応

サーバー移行時に追加するテーブル：

```sql
-- ユーザーテーブル
CREATE TABLE users (
	user_id TEXT PRIMARY KEY,
	name TEXT,
	gold INTEGER,
	created_at TIMESTAMP
);

-- 所持カードテーブル
CREATE TABLE user_cards (
	user_id TEXT,
	card_id INTEGER,
	count INTEGER,
	PRIMARY KEY (user_id, card_id)
);

-- ガチャ履歴
CREATE TABLE gacha_history (
	id INTEGER PRIMARY KEY,
	user_id TEXT,
	gacha_type TEXT,
	card_id INTEGER,
	timestamp TIMESTAMP
);
```

---

## 関連ドキュメント

- [マップシステム仕様](map_system.md)
- [CPU AI 実装設計書](cpu_ai_design.md)
- [CPUデッキシステム](cpu_deck_system.md)

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2025/12/15 | 初版作成 |

---
