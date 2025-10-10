# 🎮 カルドセプト風カードバトルゲーム - 設計書

## 📋 目次
1. [システムアーキテクチャ](#システムアーキテクチャ)
2. [コアシステム設計](#コアシステム設計)
3. [データ構造](#データ構造)
4. [ゲームフロー](#ゲームフロー)
5. [UI/UX設計](#uiux設計)
6. [技術仕様](#技術仕様)

---

## システムアーキテクチャ

### 全体構成図
```
┌─────────────────────────────────────────┐
│         Godot Engine 4.4.1              │
├─────────────────────────────────────────┤
│  Main.tscn (3Dゲームシーン)              │
│  ├── BoardSystem3D                      │
│  ├── CardSystem                         │
│  ├── BattleSystem                       │
│  ├── PlayerSystem                       │
│  ├── SkillSystem                        │
│  ├── GameFlowManager                    │
│  └── UIManager                          │
├─────────────────────────────────────────┤
│  Autoload Singletons                    │
│  ├── CardLoader                         │
│  └── GameData                           │
├─────────────────────────────────────────┤
│  Data Layer (JSON)                      │
│  ├── card_definitions.json              │
│  ├── fire/water/wind/earth.json         │
│  └── spell_*.json                       │
└─────────────────────────────────────────┘
```

### 主要クラス関係図
```
GameFlowManager
    ├── BoardSystem3D
    │   ├── MovementController3D
    │   ├── TileDataManager
    │   └── SpecialTileSystem
    ├── CardSystem
    │   └── CardLoader (Autoload)
    ├── BattleSystem
    │   ├── EffectCombat
    │   └── ConditionChecker
    ├── PlayerSystem
    └── UIManager
        ├── PlayerInfoPanel
        ├── CardSelectionUI
        ├── LevelUpUI
        └── DebugPanel
```

---

## コアシステム設計

### 1. ボードシステム (BoardSystem3D)

#### 責務
- 3Dマップの生成と管理
- タイルの所有権管理
- クリーチャー配置管理（3D空間）
- 属性連鎖の計算
- 通行料の計算
- プレイヤー移動制御

#### 主要メソッド
```gdscript
# タイル管理
func get_tile_info(tile_index: int) -> Dictionary
func set_tile_owner(tile_index: int, player_id: int)
func place_creature(tile_index: int, creature: Dictionary)

# 連鎖・ボーナス計算
func get_element_chain_count(tile_index: int, player_id: int) -> int
func calculate_toll(tile_index: int) -> int
func get_player_lands_by_element(player_id: int) -> Dictionary

# マップレイアウト
func create_tiles_diamond_layout() -> Array
```

#### マップレイアウト仕様
- **現行**: 1辺5マスの菱形（外周20マス）
- **将来計画**: 自由な分岐マップ設計
  - 十字路・T字路対応
  - 非ループ構造のマップ
  - カスタムマップエディター予定
- **特殊マス**:
  - スタート地点
  - チェックポイント
  - ワープゲート
  - カードマス
  - イベントマス（拡張予定）

#### 属性連鎖システム
```
連鎖数    通行料倍率    HPボーナス
  1個        1.0倍        +10
  2個        1.5倍        +20
  3個        2.5倍        +30
  4個以上    4.0倍        +40 (上限)
```

### 2. カードシステム (CardSystem)

#### 責務
- デッキ管理（最大50枚）
- 手札管理（最大6枚）
- カードドロー処理
- 捨て札管理とシャッフル

#### カードライフサイクル
```
デッキ → 手札 → 使用 → 捨て札
         ↑              ↓
         └── シャッフル ←┘
```

#### 主要メソッド
```gdscript
# 初期化
func _initialize_deck()  # GameDataから選択デッキ読み込み
func deal_initial_hands_all_players(player_count: int)

# ドロー処理
func draw_card_for_player(player_id: int) -> Dictionary
func draw_cards_for_player(player_id: int, count: int) -> Array

# カード使用
func use_card_for_player(player_id: int, card_index: int) -> Dictionary

# 検索
func find_cards_by_element_for_player(player_id: int, element: String) -> Array
func find_affordable_cards_for_player(player_id: int, magic: int) -> Array
```

### 3. バトルシステム (BattleSystem)

#### 責務
- 戦闘判定（先制攻撃対応）
- 地形・連鎖ボーナス適用
- スキル効果の適用
- バトル結果の演出制御

**注意**: 属性相性システムは将来的に削除予定

#### バトルフロー
```
1. 攻撃側の先制攻撃
   ├─ AP ≥ 防御側HP? → 攻撃側勝利
   └─ 防御側生存 → 次へ

2. 防御側の反撃
   ├─ ST ≥ 攻撃側HP? → 防御側勝利
   ├─ 攻撃側生存 → 攻撃側勝利
   └─ 両者AP=0 → 引き分け（膠着）
```

#### ボーナス計算
```gdscript
# 属性相性（削除予定）
# 現在実装されているが、将来的に削除される
# 火 → 風 → 土 → 水 → 火
# 相性有利: ST+20

# 地形効果（HP）- メインシステム
クリーチャー属性 = タイル属性
→ HP + 連鎖ボーナス(10/20/30/40)
```

#### スキルシステム統合
```gdscript
# スキル適用フロー
1. ability_parsed を解析
2. ConditionChecker で条件判定
3. EffectCombat で効果適用
4. 修正後の AP/HP でバトル実行
```

### 4. プレイヤーシステム (PlayerSystem)

#### 責務
- プレイヤー情報管理（魔力、土地数、位置）
- ターン管理
- 魔力の増減処理
- 勝利条件判定

#### プレイヤーデータ構造
```gdscript
{
  "id": int,
  "name": String,
  "magic_power": int,      # 初期3000G
  "position": int,         # ボード上の位置
  "owned_lands": Array,    # 所有土地のインデックス
  "is_cpu": bool,
  "color": Color
}
```

### 5. スキルシステム (SkillSystem)

#### アーキテクチャ
```
SkillSystem (マネージャー)
  ├── ConditionChecker (条件判定)
  │   └── build_battle_context()
  └── EffectCombat (効果適用)
      └── apply_power_strike()
```

#### スキル定義構造
```json
{
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "modify_stats",
        "target": "self",
        "stat": "AP",
        "operation": "multiply",
        "formula": "fire_lands * 10",
        "conditions": [
          {
            "condition_type": "on_element_land",
            "element": "火"
          }
        ]
      }
    ]
  }
}
```

#### 実装済みエフェクト
- **modify_stats**: ステータス変更
- **add_keyword**: キーワード能力付与
- **damage**: ダメージ
- **heal**: 回復

#### 実装済み条件
- **on_element_land**: 特定属性の土地
- **has_item_type**: アイテム装備
- **land_level_check**: 土地レベル
- **element_land_count**: 属性土地数

---

## データ構造

### カードデータ
```json
{
  "id": 1,
  "name": "アームドパラディン",
  "rarity": "E",
  "type": "creature",
  "element": "火",
  "cost": {
    "mp": 200,
    "lands_required": ["火", "火"]
  },
  "ap": 0,
  "hp": 50,
  "ability": "ST変動",
  "ability_detail": "ST=火配置数×10；無効化[巻物]",
  "ability_parsed": {
    "effects": [...]
  }
}
```

### タイルデータ
```gdscript
{
  "index": int,           # タイルインデックス
  "element": String,      # "火", "水", "風", "土", ""
  "owner": int,           # -1=空き地, 0-3=プレイヤーID
  "level": int,           # 1-5
  "creature": Dictionary, # 配置クリーチャー
  "position": Vector3,    # 3D座標
  "tile_type": String,    # "START", "CHECKPOINT", "WARP", etc.
  "connections": Array    # 接続タイル（分岐路用）
}
```

### デッキデータ (GameData)

**注意**: 現在デッキシステムは別の方式で管理されています。
card_definitions.jsonから直接カードデータを読み込む実装に変更予定。

以下は旧データ構造（使用していません）：
```gdscript
# 削除予定の古い構造
{
  "book_1": {
    "name": "炎の書",
    "cards": {
      1: 3,  # card_id: count
      2: 2
    }
  }
}
```

現行の実装では、CardLoaderがfire.json/water.json等から
カードデータを直接ロードしています。

---

## ゲームフロー

### メインゲームループ
```
ゲーム開始
  ↓
プレイヤー初期化（魔力3000G）
  ↓
初期手札配布（5枚）
  ↓
┌─ ターン開始 ←─────────┐
│  ↓                      │
│ サイコロ振る（1-6）     │
│  ↓                      │
│ 移動                    │
│  ↓                      │
│ マスイベント判定        │
│  ├─ 空き地             │
│  │   └─ カード召喚可能  │
│  ├─ 敵の土地           │
│  │   ├─ 通行料支払い    │
│  │   └─ バトル選択可能  │
│  ├─ スタート通過       │
│  │   └─ 200G獲得       │
│  └─ カードマス         │
│      └─ カード入手      │
│  ↓                      │
│ 土地レベルアップ        │
│  ↓                      │
│ カードドロー（1枚）      │
│  ↓                      │
│ 勝利条件判定            │
│  ├─ Yes → ゲーム終了   │
│  └─ No → 次プレイヤー─┘
```

### バトルフロー詳細
```
バトル開始
  ↓
カード選択（手札から）
  ↓
コスト支払い（mp × 10G）
  ↓
スキル条件判定
  ├─ プレイヤー土地取得
  ├─ バトルコンテキスト構築
  └─ 強打等の効果判定
  ↓
ボーナス計算
  ├─ 属性相性（ST）
  └─ 地形・連鎖（HP）
  ↓
先制攻撃判定
  ├─ 攻撃側 AP vs 防御側 HP
  └─ 防御側倒れる? → 勝利
  ↓
反撃判定（防御側生存時）
  ├─ 防御側 ST vs 攻撃側 HP
  └─ 結果確定
  ↓
土地所有権変更
  ↓
UI更新
```

---

## UI/UX設計

### 画面レイアウト
```
┌────────────────────────────────────────────┐
│ [魔力: 3450G] [土地: 5/20] [P1ターン]      │ ← PlayerInfoPanel
├────────────────────────────────────────────┤
│                                             │
│          [ボードビュー]                      │
│         ◇ ◇ ◇ ◇ ◇                          │
│        ◇       ◇                           │
│       ◇         ◇                          │
│        ◇       ◇                           │
│         ◇ ◇ ◇ ◇ ◇                          │
│                                             │
├────────────────────────────────────────────┤
│ [カード1] [カード2] [カード3] [カード4]     │ ← Hand (手札)
└────────────────────────────────────────────┘
```

### UIコンポーネント

#### 1. PlayerInfoPanel
- **位置**: 画面上部
- **表示内容**:
  - 現在のプレイヤー名
  - 魔力（Gold）
  - 所有土地数
  - デッキ/捨て札枚数
- **サイズ**: 調整可能（71行目で設定）

#### 2. CardSelectionUI
- **用途**: カード選択・バトル決定
- **表示要素**:
  - カード一覧（スクロール可能）
  - カードステータス表示
  - 決定/キャンセルボタン
- **モーダル**: 選択中は他操作無効

#### 3. LevelUpUI
- **用途**: 土地レベルアップ
- **表示要素**:
  - 現在レベル / 次レベル
  - 必要コスト
  - 実行/スキップボタン

#### 4. DebugPanel
- **位置**: 画面右下
- **機能**:
  - プレイヤー情報表示
  - デバッグコマンド
  - CPU手札表示

### カード表示仕様
```
サイズ: 240x350px
間隔: 20px
配置: 画面下部中央揃え

カード構成:
┌──────────────┐
│  [コスト]     │ ← 右上
│              │
│  [名前]      │ ← 中央
│  [属性]      │
│              │
│  AP: 40      │ ← 下部
│  HP: 30      │
└──────────────┘
```

---

## 技術仕様

### 開発環境
- **エンジン**: Godot Engine 4.4.1
- **言語**: GDScript
- **レンダリング**: 3D専用（Forward+）
- **対象OS**: macOS (M4 MacBook Air)
- **解像度**: 3704x1712px（ウィンドウモード）
- **カメラ**: 3Dパースペクティブカメラ

### ファイル構成
```
cardbattlegame/
├── scenes/
│   ├── game.tscn          # 【削除予定】2D版（使用していない）
│   ├── Main.tscn          # メインの3Dゲームシーン
│   ├── MainMenu.tscn      # メインメニュー
│   ├── DeckEditor.tscn    # デッキ編集
│   ├── Card.tscn          # カードシーン
│   ├── Tiles/             # タイルシーン
│   └── Characters/        # キャラクター
│
├── scripts/
│   ├── game_constants.gd  # 定数定義
│   ├── card_system.gd
│   ├── battle_system.gd
│   ├── player_system.gd
│   ├── board_system_3d.gd  # メイン（3D専用）
│   ├── movement_controller.gd
│   ├── game_flow_manager.gd
│   ├── skill_system.gd
│   ├── ui_components/
│   ├── flow_handlers/
│   ├── tiles/
│   └── skills/
│
├── data/
│   ├── card_definitions.json
│   ├── fire.json
│   ├── water.json
│   ├── wind.json
│   ├── earth.json
│   └── spell_*.json
│
├── assets/
│   └── images/
│       ├── tiles/         # 64x64px PNG
│       └── map/
│
└── models/                # 3Dモデル (GLB)
```

### パフォーマンス考慮事項
- **z-index**: 奥行き表現（重なり順制御）
- **テクスチャサイズ**: 128x128px推奨（表示50x50）
- **ノード数**: 最小限に抑える
- **シグナル**: 疎結合のためシグナル活用

### 制約事項
1. **予約語回避**:
   - `owner` → `tile_owner`
   - `is_processing()` → `is_battle_active()`
2. **TextureRect制約**:
   - `color`プロパティ使用不可
   - `modulate`で色調整
3. **画像形式**:
   - 透過: PNG必須
   - JPEG: 透過不可

### ⚠️ 重要: ターン終了処理の管理

**責任クラス**: `GameFlowManager` (scripts/game_flow_manager.gd)

#### end_turn()の呼び出し経路（完全版）

```
【正常な呼び出しチェーン】
1. TileActionProcessor (_complete_action)
   └─ emit_signal("action_completed")
      │
      ↓
2. BoardSystem3D (_on_action_completed)
   └─ emit_signal("tile_action_completed")
      │
      ↓
3. GameFlowManager (_on_tile_action_completed_3d)
   └─ end_turn()
      └─ emit_signal("turn_ended")
```

#### tile_action_completed発火箇所（全リスト）

**A. BoardSystem3D経由（正常系）**:
```gdscript
# board_system_3d.gd Line 221
func _on_action_completed():
    if not is_waiting_for_action:
        return
    is_waiting_for_action = false
    emit_signal("tile_action_completed")
```

**B. GameFlowManager内での直接発火（問題系）**:
```gdscript
# game_flow_manager.gd
Line 151: _on_cpu_summon_decided() 内
Line 188: _on_cpu_level_up_decided() 内
Line 210, 219: on_level_up_selected() 内

# ⚠️ これらは削除予定（2D版の残存コード）
```

**C. TileActionProcessor経由（正常系）**:
```gdscript
# tile_action_processor.gd
- execute_summon() → _complete_action()
- on_action_pass() → _complete_action()
- on_card_selected() → _complete_action()
- on_level_up_selected() → _complete_action()
```

#### 重複実行防止機構（3段階）

```gdscript
# 【第1段階】BoardSystem3D (board_system_3d.gd Line 219-223)
func _on_action_completed():
    if not is_waiting_for_action:  # 重複チェック
        return
    is_waiting_for_action = false
    emit_signal("tile_action_completed")

# 【第2段階】GameFlowManager (game_flow_manager.gd Line 134-138)
func _on_tile_action_completed_3d():
    if current_phase == GamePhase.END_TURN or current_phase == GamePhase.SETUP:
        print("Warning: tile_action_completed ignored (phase:", current_phase, ")")
        return
    end_turn()

# 【第3段階】GameFlowManager (game_flow_manager.gd Line 230-233)
func end_turn():
    if current_phase == GamePhase.END_TURN:
        print("Warning: Already ending turn")
        return
    # ... 処理 ...
```

#### 既知の問題（BUG-000）

**症状**:
- ターンが飛ばされる（プレイヤー1→プレイヤー3）
- `end_turn()`の複数回呼び出し
- フェーズチェックが非同期処理に対応できない

**根本原因**:
1. **シグナル経路の二重化**: GameFlowManagerが直接emit_signalしている
2. **非同期競合**: awaitタイミングでフェーズチェックが無効化
3. **2D版残存**: 削除予定のCPUハンドラーコードが混在

**影響箇所**:
```
scripts/game_flow_manager.gd
  - Line 151: _on_cpu_summon_decided()
  - Line 188: _on_cpu_level_up_decided()
  - Line 210-219: on_level_up_selected()
```

**修正計画**: 
- issues.md BUG-000 参照
- TECH-001（古い2Dコード削除）と連動
- シグナル経路を完全一本化（推奨）

---

## 3D実装の特徴

### 現行の3Dシステム
- **BoardSystem3D**: 3D空間でのタイル配置
- **MovementController3D**: プレイヤーの3D移動制御
- **カメラシステム**: プレイヤー追従・フォーカス機能
- **3Dモデル**: GLB形式のタイル・キャラクター

### マップ設計の進化
```
現在（菱形1周）        将来（自由分岐）
     ◇                      ◇
    ◇ ◇                    ╱ ╲
   ◇   ◇                  ◇   ◇
  ◇     ◇      →         │   │
   ◇   ◇                  ◇═══◇
    ◇ ◇                    ╲ ╱
     ◇                      ◇
```

### 分岐路システム設計案
```gdscript
# タイルの接続情報
{
  "index": 5,
  "connections": [4, 6, 12],  # 3方向に分岐
  "junction_type": "T-junction"  # 十字路・T字路
}
```

---

## 拡張性考慮

### 今後追加予定の機能
1. **スペルカード**
   - 効果: 全体/単体
   - タイミング: 即時/永続
2. **アイテムシステム**
   - 装備効果
   - 使い捨てアイテム
3. **マルチプレイヤー**
   - オンライン対戦
   - ロビーシステム
4. **キャンペーンモード**
   - ストーリー進行
   - ボス戦

### プラグイン設計
```gdscript
# 拡張可能なイベントシステム
signal tile_event_triggered(tile_index: int, event_type: String)

func register_tile_event(tile_index: int, event: Callable):
    # イベントハンドラー登録
```

---

## 削除予定・変更予定項目

### 🗑️ 削除予定
1. **game.tscn** - 2D版シーン（使用していない）
2. **board_system.gd** - 2D版ボードシステム（存在する場合）
3. **属性相性システム** - バトルシステムから削除予定

### 🔄 変更予定
1. **マップシステム** - 菱形から分岐路対応へ
2. **デッキ管理** - 新しいデータ構造へ移行
3. **タイル接続** - connections配列追加

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/01/10 | 1.0 | 初版作成 |
| 2025/01/10 | 1.1 | 3D専用設計に修正、分岐路計画追加 |

---

**最終更新**: 2025年1月10日（v1.1）
