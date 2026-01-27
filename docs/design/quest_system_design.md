# クエストシステム設計書

**バージョン**: 1.4  
**最終更新**: 2026年1月27日  
**ステータス**: 実装中

---

## 📋 目次

1. [概要](#概要)
2. [システム構成](#システム構成)
3. [ディレクトリ構造](#ディレクトリ構造)
4. [JSONスキーマ設計](#jsonスキーマ設計)
5. [4人対戦対応](#4人対戦対応)
6. [CPU AI設計](#cpu-ai設計)
7. [実装状況](#実装状況)
8. [勝敗判定とリザルト](#勝敗判定とリザルト)
9. [将来のサーバー移行](#将来のサーバー移行)

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
| プレイヤー構成 | 1人 vs CPU 1〜3体（最大4人対戦） |
| 進行方式 | ワールド制（1-1 → 1-2 → 1-3、並行して2-1 → 2-2等） |

### 既存システムとの関係

```
MainMenu
├── ソロバトル → Main.tscn（game_3d.gd、テスト環境）
└── クエスト → StageSelect.tscn（quest_select.gd）
			  └── Quest.tscn（quest_game.gd、動的にマップ生成）
```

### 関連ドキュメント

- [オンラインルール設計書](online_rules_design.md) - ルールプリセット、勝利条件、カード制限
- [マップシステム仕様](map_system.md) - マップ構造、周回システム
- [ステージクリアシステム](stage_clear_system.md) - 勝敗判定、リザルト画面、報酬

---

## システム構成

### データの分類

| 種類 | 説明 | ファイル数 | 再利用 |
|------|------|-----------|--------|
| ワールド定義 | ワールド一覧・解放条件 | 1 | - |
| ステージ定義 | マップID + ルール + 敵構成 | ステージ数分 | - |
| マップ定義 | タイル配置・接続・座標 | 10程度 | ✓ |
| キャラクター定義 | 名前・3Dモデルパス | 1 | ✓ |
| デッキ定義 | カードIDリスト | 10〜20程度 | ✓ |
| AIプロファイル | 戦略パラメータ | 5〜10程度 | ✓ |

### 参照方式

```
stage_1_1.json
├── map_id: "map_diamond_20" → maps/map_diamond_20.json
├── rule_preset: "quick" → game_constants.gd RULE_PRESETS
└── quest.enemies[0]
		├── character_id: "goblin" → characters.json
		├── deck_id: "deck_fire_basic" → decks/deck_fire_basic.json
		└── ai_level: 3
```

---

## ディレクトリ構造

```
data/
├── master/                          # マスターデータ
│   ├── worlds/
│   │   └── world_list.json          # ワールド一覧・解放条件
│   ├── stages/
│   │   ├── stage_1_1.json           # ステージ定義
│   │   ├── stage_1_2.json
│   │   ├── stage_test_4p.json       # ソロ4人対戦テスト
│   │   ├── stage_quest_4p.json      # クエスト4人対戦テスト
│   │   └── ...
│   ├── maps/
│   │   ├── map_diamond_20.json
│   │   └── ...
│   ├── characters/
│   │   └── characters.json          # 全CPUキャラ定義
│   ├── decks/
│   │   ├── deck_balance_easy.json
│   │   ├── deck_skills_test.json
│   │   └── ...
│   └── ai_profiles/
│       ├── easy.json
│       └── ...
│
└── local/                           # ユーザーデータ
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

---

### 2. stage_X_X.json（ステージ定義）

**新しい構造**（ルールとクエスト専用データを分離）:

```json
{
  "id": "stage_quest_4p",
  "name": "4人クエストテスト",
  "description": "プレイヤー1名 + CPU3名のクエストテスト",
  "map_id": "map_diamond_20",

  "rule_preset": "standard",
  "rule_overrides": {
	"initial_magic": {"player": 1000, "cpu": 1000}
  },

  "quest": {
	"enemies": [
	  {
		"character_id": "bowser",
		"deck_id": "skills_test",
		"ai_level": 3,
		"start_tile": 0
	  },
	  {
		"character_id": "bowser",
		"deck_id": "balance_easy",
		"ai_level": 3,
		"start_tile": 0
	  },
	  {
		"character_id": "bowser",
		"deck_id": "random",
		"ai_level": 3,
		"start_tile": 0
	  }
	],
	"rewards": {
	  "first_clear": {"type": "gold", "amount": 1000},
	  "repeat": {"type": "gold", "amount": 200}
	}
  }
}
```

#### フィールド説明

| フィールド | 必須 | 説明 |
|-----------|:----:|------|
| `id` | ✓ | ステージ識別子 |
| `name` | | ステージ名（表示用） |
| `description` | | 説明文 |
| `map_id` | ✓ | 使用するマップのID |
| `rule_preset` | | ルールプリセット名（デフォルト: "standard"） |
| `rule_overrides` | | プリセットを上書きするカスタム設定 |
| `quest` | | ソロクエスト専用データ |
| `quest.enemies` | | CPU敵の配列（1〜3体） |

#### 敵（enemies）の設定

| フィールド | 必須 | 説明 |
|-----------|:----:|------|
| `character_id` | ✓ | キャラクターID（characters.jsonから） |
| `deck_id` | | デッキID（"random"でランダムデッキ） |
| `ai_level` | | AIレベル（1-10、デフォルト: 3） |
| `start_tile` | | 開始タイル（デフォルト: 0） |

#### ルール関連

ルールプリセットと勝利条件の詳細は [オンラインルール設計書](online_rules_design.md) を参照。

---

### 3. characters.json（キャラクター定義）

```json
{
  "characters": {
	"bowser": {
	  "name": "クッパ",
	  "model_path": "res://scenes/Characters/Bowser.tscn",
	  "portrait_path": "res://assets/portraits/bowser.png",
	  "description": "強力な敵キャラ"
	},
	"goblin": {
	  "name": "ゴブリン",
	  "model_path": "res://scenes/Characters/Goblin.tscn",
	  "portrait_path": "res://assets/portraits/goblin.png",
	  "description": "小さいが凶暴な魔物"
	}
  }
}
```

---

### 4. deck_*.json（デッキ定義）

```json
{
  "id": "balance_easy",
  "name": "バランスデッキ（初級）",
  "description": "各属性均等・低コストのバランス型デッキ",
  "cards": [
	{"id": 217, "count": 2},
	{"id": 218, "count": 2},
	{"id": 305, "count": 2},
	{"id": 306, "count": 2},
	{"id": 2033, "count": 4}
  ]
}
```

---

### 5. ai_profiles/*.json（AIプロファイル）

```json
{
  "id": "easy",
  "name": "初級",
  "description": "初心者向け",
  "difficulty_level": 3,
  "behavior": {
	"summon_rate": 0.6,
	"invasion_rate": 0.4,
	"battle_rate": 0.5,
	"levelup_rate": 0.3
  }
}
```

---

### 6. user_save.json（ユーザーデータ）

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
  "last_played": "2025-01-19T10:30:00Z"
}
```

---

## 4人対戦対応

### プレイヤー数の決定

プレイヤー数はステージJSONの`quest.enemies`配列のサイズで決まります。

```
プレイヤー数 = 1（人間） + enemies.size()（CPU）
```

| enemies数 | プレイヤー数 | 構成 |
|-----------|------------|------|
| 1 | 2 | 人間1 + CPU1 |
| 2 | 3 | 人間1 + CPU2 |
| 3 | 4 | 人間1 + CPU3 |

### CPUごとのデッキ設定

各CPUに異なるデッキを設定できます。

```json
"enemies": [
  {"character_id": "bowser", "deck_id": "skills_test"},
  {"character_id": "bowser", "deck_id": "balance_easy"},
  {"character_id": "bowser", "deck_id": "random"}
]
```

| deck_id | 動作 |
|---------|------|
| `"random"` | デフォルトデッキ（ID 1-12を各3枚） |
| `"XXX"` | `deck_XXX.json`から読み込み |

### 実装箇所

| ファイル | 役割 |
|---------|------|
| `stage_loader.gd` | プレイヤー数計算、デッキ読み込み |
| `quest_game.gd` | CPUキャラクター作成、デッキ設定 |
| `game_system_manager.gd` | CardSystem/PlayerSystem初期化 |
| `card_system.gd` | プレイヤーごとのデッキ管理 |
| `ui_manager.gd` | プレイヤー情報パネル作成 |

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
debug_manual_control_all = true  # CPUも手動操作可能

# クエストモード
player_is_cpu = [false, true, true, true]  # 4人対戦
debug_manual_control_all = false  # CPUはAI任せ
```

### AIレベルと機能

| Level | 基本評価 | テンポ評価 | シナジー | 先読み | ランダム要素 |
|-------|---------|-----------|---------|--------|-------------|
| 1-3 | ✓ | - | - | 0 | 30% |
| 4-6 | ✓ | ✓ | ✓ | 1 | 10% |
| 7-10 | ✓ | ✓ | ✓ | 2 | 0% |

---

## 実装状況

### ✅ 実装済み

- [x] ディレクトリ構造
- [x] StageLoader（JSON読み込み・マップ生成）
- [x] QuestGame（クエスト用ゲーム管理）
- [x] マップJSON（7種類）
- [x] ステージJSON（8種類 + テスト用2種類）
- [x] キャラクターJSON
- [x] AIプロファイルJSON（easy）
- [x] デッキJSON（2種類）
- [x] **4人対戦対応**
- [x] **CPUごとのデッキ設定**
- [x] **プレイヤー情報パネル動的生成**
- [x] **プリセットベース設定システム**

### 🚧 未実装

- [ ] ワールド選択UI
- [ ] 報酬システム
- [ ] 進行状況保存
- [ ] AIプロファイル適用（難易度調整）

---

## 勝敗判定とリザルト

### 勝利条件

- TEPが目標値以上でチェックポイント通過

### 敗北条件

| 条件 | 説明 |
|------|------|
| 規定ターン終了 | `max_turns`経過時にTEP比較で負け |
| 降参 | プレイヤーがメニューから降参を選択 |
| TEP同値 | プレイヤー敗北扱い |

### ゲーム終了フロー

```
勝利/敗北確定
    ↓
クリア演出（WIN/LOSE表示 + クリック待ち）
    ↓
リザルト画面
  - クリアランク（勝利時のみ）
  - 報酬表示
  - クリック待ち
    ↓
ステージセレクトへ戻る
```

### 報酬

- 勝利時：ステージ報酬 + ランクボーナス（初回のみ）
- 敗北時：0G

詳細は [ステージクリアシステム](stage_clear_system.md) を参照。

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
func load_stage(stage_id: String) -> Dictionary:
	var file = FileAccess.open("res://data/master/stages/%s.json" % stage_id, FileAccess.READ)
	return JSON.parse_string(file.get_as_text())

# 将来（差し替えるだけ）
func load_stage(stage_id: String) -> Dictionary:
	var response = await http.request("https://api.example.com/stages/%s" % stage_id)
	return JSON.parse_string(response.body)
```

**JSONの構造は変わらない。読み込み方法だけ変更。**

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2025/12/15 | 初版作成 |
| 1.1 | 2025/12/16 | マップJSONスキーマにlap_settings追加 |
| 1.2 | 2025/01/19 | ルール関連をonline_rules_design.mdに分離、ステージJSON構造を更新 |
| 1.3 | 2025/01/20 | 4人対戦対応、CPUごとのデッキ設定、実装状況更新 |
| 1.4 | 2026/01/27 | 勝敗判定とリザルトセクション追加、ステージクリアシステムへの参照追加 |
