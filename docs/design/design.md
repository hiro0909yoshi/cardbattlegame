# 🎮 カルドセプト風カードバトルゲーム - 設計書

## 📋 目次
1. [システムアーキテクチャ](#システムアーキテクチャ)
2. [コアシステム設計](#コアシステム設計)
3. [データ構造](#データ構造)
4. [ゲームフロー](#ゲームフロー)
5. [UI/UX設計](#uiux設計)
6. [技術仕様](#技術仕様)
7. [デバッグ機能](#デバッグ機能)
8. [システム初期化](#システム初期化)

---

## システムアーキテクチャ

### 全体構成図
```
┌─────────────────────────────────────────┐
│         Godot Engine 4.4.1              │
├─────────────────────────────────────────┤
│  Main.tscn (3Dゲームシーン)              │
│  ├── BoardSystem3D                      │
│  │   ├── TileNeighborSystem (NEW)      │
│  │   ├── MovementController3D          │
│  │   ├── TileDataManager                │
│  │   └── SpecialTileSystem              │
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
	│   ├── TileNeighborSystem (NEW)
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
- **タイル隣接関係の管理** (NEW)

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

# 隣接判定 (NEW)
func get_spatial_neighbors(tile_index: int) -> Array
func has_adjacent_ally_land(tile_index: int, player_id: int) -> bool

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

#### 🆕 土地ボーナスシステム

**概要**: クリーチャーと土地の属性が一致すると、土地レベルに応じたHPボーナスが得られる。

**計算式**:
```
土地ボーナスHP = 土地レベル × 10

例:
- レベル1の火属性土地 + 火属性クリーチャー → +10HP
- レベル3の水属性土地 + 水属性クリーチャー → +30HP
- レベル5の風属性土地 + 風属性クリーチャー → +50HP (最大)
```

**実装場所**:
- 召喚時: `BaseTile.place_creature()` → `_apply_land_bonus()`
- バトル時: `BattleSystem._apply_attacker_land_bonus()`

**データ構造**:
```gdscript
creature_data = {
	"name": "フェニックス",
	"element": "火",
	"hp": 30,              # 基本HP
	"land_bonus_hp": 20,   # 土地ボーナス（別管理）
	# 表示HP = 30 + 20 = 50
}
```

**特徴**:
- `hp`とは別フィールドで管理
- 「貫通」「巻物」スキルで無視される（将来実装）
- 常時適用（召喚時・バトル時）

#### 🆕 隣接土地判定システム

**概要**: タイルの物理的な隣接関係を座標ベースで判定するシステム。

**判定方法**:
```gdscript
# XZ平面での距離計算
const TILE_SIZE = 4.0
const NEIGHBOR_THRESHOLD = 4.5  # タイルサイズより10%大きい

var dx = abs(my_pos.x - other_pos.x)
var dz = abs(my_pos.z - other_pos.z)
var distance_xz = sqrt(dx * dx + dz * dz)

if distance_xz < NEIGHBOR_THRESHOLD:
	# 隣接と判定
```

**使用例**:
```gdscript
# スキル条件: 「隣接した自領地なら強打」
var neighbors = board_system.tile_neighbor_system.get_spatial_neighbors(tile_index)
# → [5, 7]  # タイル6の隣接タイル

var has_ally = board_system.tile_neighbor_system.has_adjacent_ally_land(
	tile_index, player_id, board_system
)
# → true/false
```

**キャッシュ機構**:
- 初回起動時に全タイルの隣接関係を計算
- 結果をキャッシュして高速化（O(1)で取得）
- マップ変更時は再計算可能

**拡張性**:
- 十字路・T字路: 4方向以上の隣接にも対応
- 立体交差: Y軸も考慮可能（将来）

### 1.1 TileNeighborSystem (NEW)

**責務**: タイルの物理的な隣接関係を管理

**主要メソッド**:
```gdscript
# 初期化
func setup(tiles: Dictionary)

# 隣接取得
func get_spatial_neighbors(tile_index: int) -> Array
func get_sequential_neighbors(tile_index: int) -> Array

# 条件判定
func has_adjacent_ally_land(tile_index: int, player_id: int, board_system) -> bool
```

**アルゴリズム**:
1. 全タイルペアの距離を計算（XZ平面）
2. 閾値4.5以内を隣接と判定
3. 結果を`spatial_neighbors_cache`にキャッシュ

**パフォーマンス**:
- 初回構築: O(N²) - 20タイルで400回計算、<10ms
- 実行時取得: O(1) - キャッシュから即座に取得

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
- **土地ボーナスの適用** (NEW)
- スキル効果の適用
- バトル結果の演出制御

**注意**: 属性相性システムは将来的に削除予定

#### バトルフロー
```
1. 攻撃側の土地ボーナス適用 (NEW)
   └─ クリーチャー属性 = タイル属性?
	  └─ HP + (レベル × 10)

2. 攻撃側の先制攻撃
   ├─ AP ≥ 防御側HP? → 攻撃側勝利
   └─ 防御側生存 → 次へ

3. 防御側の反撃
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

# 🆕 土地ボーナス（HP）- メインシステム
クリーチャー属性 = タイル属性
→ HP + (レベル × 10)
→ land_bonus_hpフィールドに格納

例:
- 基本HP: 30
- レベル3の火土地 + 火クリーチャー
- land_bonus_hp: 30
- 合計HP: 60
```

#### スキルシステム統合

**詳細は [skills_design.md](skills_design.md) を参照**

```gdscript
# スキル適用フロー
1. ability_parsed を解析
2. ConditionChecker で条件判定
3. EffectCombat で効果適用
4. 修正後の AP/HP でバトル実行
```

**実装済み主要スキル**:
- 感応: 特定属性の土地所有でAP/HP上昇
- 貫通: 防御側の土地ボーナス無効化
- 強打: 条件下でAP増幅
- 先制: 先攻権獲得
- 後手: 相手が先攻
- 再生: バトル後にHP全回復
- 2回攻撃: 1回のバトルで2回攻撃
- 即死: 攻撃後に確率で即死判定

**スキル適用順序**: 感応 → 強打 → 2回攻撃判定 → 攻撃実行 → **即死判定** → バトル結果 → 再生

詳細な仕様、実装例、データ構造については `skills_design.md` を参照してください。

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

**詳細は [skills_design.md](skills_design.md) を参照**

#### アーキテクチャ
```
SkillSystem (マネージャー)
  ├── ConditionChecker (条件判定)
  └── EffectCombat (効果適用)
```

#### 実装済みスキル一覧
- **感応**: 特定属性の土地所有でAP/HP上昇（9体実装）
- **貫通**: 防御側の土地ボーナス無効化
- **強打**: 条件下でAP増幅
- **先制**: 先攻権獲得
- **防魔**: スペル無効化（部分実装）

#### スキル適用順序
1. 感応スキル → 2. 強打スキル → 3. その他スキル

スキルの詳細仕様、条件システム、BattleParticipantとHP管理、将来実装予定のスキルについては `skills_design.md` を参照してください。

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

### 🆕 クリーチャーデータ（配置後）
```gdscript
{
  "id": 49,
  "name": "ローンビースト",
  "element": "火",
  "ap": 20,
  "hp": 40,               # 基本HP
  "land_bonus_hp": 30,    # 🆕 土地ボーナス（レベル3×10）
  "ability_parsed": {...}
}
```

**表示HP計算**:
```gdscript
var total_hp = creature.hp + creature.get("land_bonus_hp", 0)
# 基本HP(40) + 土地ボーナス(30) = 70
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
│  │      └─ 🆕 土地ボーナス適用 │
│  ├─ 敵の土地           │
│  │   ├─ 通行料支払い    │
│  │   └─ バトル選択可能  │
│  │      └─ 🆕 隣接自領地判定 │
│  ├─ スタート通過       │
│  │   └─ 200G獲得       │
│  └─ カードマス         │
│      └─ カード入手      │
│  ↓                      │
│ 🆕 召喚フェーズ         │
│  ├─ カード召喚          │
│  └─ 領地コマンド        │
│      ├─ レベルアップ    │
│      ├─ クリーチャー移動 │
│      └─ クリーチャー交換 │
│  ↓                      │
│ カードドロー（1枚）      │
│  ↓                      │
│ 勝利条件判定            │
│  ├─ Yes → ゲーム終了   │
│  └─ No → 次プレイヤー─┘
```

### 🆕 レベルアップフロー（Phase 1-A）
```
移動完了
  ↓
領地コマンドボタン表示（人間プレイヤーのみ）
  ↓
土地選択（数字キー1-0）
  ├─ ダウン状態の土地は選択不可
  └─ 所有している土地のみ選択可能
  ↓
アクションメニュー表示（右側中央パネル）
  ├─ [L] レベルアップ
  ├─ [M] 移動（未実装）
  ├─ [S] 交換（未実装）
  └─ [C] 戻る（土地選択に戻る）
  ↓
レベルアップ選択（Lキー）
  ↓
レベル選択画面表示
  ├─ 現在レベル表示
  ├─ Lv2-5選択ボタン
  │   ├─ 累計コスト表示
  │   │   Lv1→2: 80G
  │   │   Lv1→3: 240G
  │   │   Lv1→4: 620G
  │   │   Lv1→5: 1200G
  │   └─ 魔力不足のボタンは無効化
  └─ [C] 戻る（アクションメニューに戻る）
  ↓
レベル選択（Lv2-5いずれか）
  ↓
レベルアップ実行
  ├─ 魔力消費（累計コスト）
  ├─ 土地レベル更新
  ├─ ダウン状態設定
  └─ UI更新
  ↓
ターン終了
```

**レベルコスト（累計方式）**:
```gdscript
const LEVEL_COSTS = {
    0: 0,
    1: 0,
    2: 80,      // Lv1→2: 80G
    3: 240,     // Lv1→3: 240G (80 + 160)
    4: 620,     // Lv1→4: 620G (80 + 160 + 380)
    5: 1200     // Lv1→5: 1200G (80 + 160 + 380 + 580)
}

// コスト計算
var cost = LEVEL_COSTS[target_level] - LEVEL_COSTS[current_level]
```

**実装クラス**:
- `LandCommandHandler`: 領地コマンドのロジック
- `UIManager`: アクションメニュー・レベル選択パネルのUI
- `GameFlowManager`: ターン終了処理

---

### バトルフロー詳細
```
バトル開始
  ↓
カード選択（手札から）
  ↓
コスト支払い（mp × 10G）
  ↓
🆕 攻撃側カードに土地ボーナス適用
  ├─ カード属性 = タイル属性?
  └─ Yes → HP + (レベル × 10)
  ↓
🆕 隣接自領地判定
  ├─ TileNeighborSystemで隣接タイル取得
  ├─ 隣接に自領地あり?
  └─ Yes → 強打条件満たす
  ↓
スキル条件判定
  ├─ プレイヤー土地取得
  ├─ バトルコンテキスト構築
  │   ├─ battle_tile_index
  │   ├─ player_id
  │   └─ board_system
  └─ 強打等の効果判定
  ↓
ボーナス計算
  ├─ 属性相性（ST）- 削除予定
  └─ 地形・連鎖（HP）
  ↓
先制攻撃判定
  ├─ 攻撃側 AP vs 防御側 HP
  │   └─ 防御側HP = 基本HP + land_bonus_hp
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

### UI配置の基本方針

#### 全画面対応
**すべてのUI要素は、画面解像度に依存しない相対的な配置を使用する。**

- ✅ **推奨**: `viewport_size`を使用した相対配置
  ```gdscript
  var viewport_size = get_viewport().get_visible_rect().size
  var panel_x = viewport_size.x - panel_width - 20  # 右端から20px
  var panel_y = (viewport_size.y - panel_height) / 2  # 画面中央
  ```

- ❌ **非推奨**: 絶対座標指定
  ```gdscript
  panel.position = Vector2(1200, 100)  # 画面サイズが変わると破綻
  ```

#### 配置ガイドライン
1. **水平方向**
   - 左寄せ: `margin`
   - 中央揃え: `(viewport_size.x - width) / 2`
   - 右寄せ: `viewport_size.x - width - margin`

2. **垂直方向**
   - 上寄せ: `margin`
   - 中央揃え: `(viewport_size.y - height) / 2`
   - 下寄せ: `viewport_size.y - height - margin`

3. **マージン**
   - 画面端からの余白: 10-20px推奨
   - UI要素間の余白: 5-10px推奨

---

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

#### 5. ActionMenuPanel（Phase 1-A）
- **位置**: 画面右側中央（全画面対応）
  ```gdscript
  var panel_x = viewport_size.x - panel_width - 20
  var panel_y = (viewport_size.y - panel_height) / 2
  ```
- **サイズ**: 200x320px
- **表示内容**:
  - 選択中の土地番号
  - [L] レベルアップ
  - [M] 移動
  - [S] 交換
  - [C] 戻る
- **表示タイミング**: 土地選択後

#### 6. LevelSelectionPanel（Phase 1-A）
- **位置**: ActionMenuPanelと同じ（右側中央）
- **サイズ**: 250x400px
- **表示内容**:
  - 現在レベル表示
  - Lv2-5選択ボタン
  - 各レベルのコスト表示（累計方式）
  - 魔力による有効/無効判定
  - [C] 前の画面に戻る
- **表示タイミング**: レベルアップ選択後

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
│  HP: 30 (+20)│ ← 🆕 土地ボーナス表示
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
│   ├── tile_neighbor_system.gd  # 🆕 隣接判定
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
- **🆕 隣接判定キャッシュ**: O(N²)計算を初回のみ実行、以降O(1)

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

### ⚠️ 重要: アクション処理フラグの管理

**問題**: アクション処理中を示すフラグが2箇所に存在

#### 現状の二重管理

1. **BoardSystem3D.is_waiting_for_action**
   - 場所: `scripts/board_system_3d.gd` Line 27
   - 役割: タイルアクションの処理中フラグ
   - 設定: `process_tile_landing()` で `true`
   - 解除: `_on_action_completed()` で `false`

2. **TileActionProcessor.is_action_processing**
   - 場所: `scripts/tile_action_processor.gd` Line 23
   - 役割: アクション処理中フラグ（重複）
   - 設定: `process_tile_landing()` で `true`
   - 解除: `_complete_action()` で `false`

#### 問題点

```
【バグの発生例】
LandCommandHandler → board_system._on_action_completed()
  ↓
is_waiting_for_action = false  ← リセット成功
  ↓
tile_action_completed シグナル発行
  ↓
しかし...
  ↓
is_action_processing = true のまま！ ← リセット失敗
  ↓
次のプレイヤー: カード選択
  ↓
"Already processing tile action" エラー ← バグ発生
```

#### 暫定対応（現在の実装）

```gdscript
# land_command_handler.gd
# 両方のフラグをリセットするため、TileActionProcessor経由で通知
if board_system and board_system.tile_action_processor:
    board_system.tile_action_processor._complete_action()
    # これにより:
    # 1. is_action_processing = false
    # 2. action_completed シグナル発行
    # 3. BoardSystem3D._on_action_completed()
    # 4. is_waiting_for_action = false
    # 5. tile_action_completed シグナル発行
```

#### ✅ 恒久対応完了（2025/10/16 - TECH-002）

**採用案**: 案1（TileActionProcessorに統一）

**実装内容**:
1. **BoardSystem3D.is_waiting_for_action を削除**
   - フラグ管理をTileActionProcessorに完全統一
   - `_on_action_completed()`はシグナル転送のみに簡素化

2. **TileActionProcessor.complete_action() 公開メソッド追加**
   - 外部から安全にアクション完了を通知可能に
   - `_complete_action()`は内部用メソッドとして保持

3. **LandCommandHandlerの暫定コードを整理**
   - 3箇所の`_complete_action()`呼び出しを`complete_action()`に変更
   - 長いコメントを簡潔に整理

**修正後のアーキテクチャ**:
```
【修正前】二重管理（不整合のリスク）
BoardSystem3D.is_waiting_for_action ←── ①
TileActionProcessor.is_action_processing ←── ②

【修正後】単一責任
TileActionProcessor.is_action_processing ←── 唯一の真実の源
  ↑
  BoardSystem3D（シグナル転送のみ）
  LandCommandHandler（complete_action()経由）
```

**メリット**:
- 状態管理の責任が明確化
- バグの温床となる二重管理を解消
- 保守性・拡張性の向上

---

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
- **TileNeighborSystem**: 🆕 物理座標ベースの隣接判定
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
5. **🆕 土地ボーナス拡張**
   - 「貫通」「巻物」スキルで無視
   - 属性連鎖とのシナジー強化

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
| 2025/01/11 | 1.2 | 統一捨て札システム追加、2D版削除完了、ターン終了処理解決 |
| 2025/01/11 | 1.3 | 🆕 土地ボーナスシステム追加、隣接土地判定システム追加 |

---

## デバッグ機能

### debug_manual_control_all フラグ

#### 概要
全プレイヤー（CPUを含む）を手動操作可能にするデバッグ用フラグ

#### 仕様
```gdscript
@export var debug_manual_control_all: bool = false
```

**動作**:
- `true`: 全プレイヤーを手動操作（CPUも含む）
- `false`: `player_is_cpu`配列に従って動作

**用途**:
- デバッグ・テスト時に全プレイヤーを操作したい場合
- スキル動作の検証
- バランス調整のための実戦テスト

#### データフロー
```
GameFlowManager.debug_manual_control_all (エクスポート変数)
  ↓ setup_3d_mode()で転送
BoardSystem3D.debug_manual_control_all
  ↓ process_tile_landing()で渡す
TileActionProcessor.process_tile_landing(debug_manual_control_all)
  ↓ CPU判定
is_cpu_turn = player_is_cpu[current_player_index] and not debug_manual_control_all
```

#### 影響範囲
| システム | 動作 |
|---------|------|
| TileActionProcessor | CPU判定に使用 |
| CardSelectionUI | カード選択可否の判定 |
| UIManager | 手札表示制御（現在は全員表示） |

---

## システム初期化

### 初期化順序の重要性

**game_3d.gdの_ready()処理順序**（重要度：高）

正しい順序で初期化しないと、参照が未設定のままになり不具合が発生します。

#### 正しい初期化順序

```gdscript
func _ready():
	# 1. システム作成（省略）
	
	# 2. UIManager設定
	ui_manager.board_system_ref = board_system_3d
	ui_manager.player_system_ref = player_system
	ui_manager.card_system_ref = card_system
	ui_manager.create_ui(self)  # ← CardSelectionUI等を初期化
	
	# 3. 手札UI初期化
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		ui_manager.initialize_hand_container(ui_layer)
		ui_manager.connect_card_system_signals()
	
	# 4. デバッグフラグ設定（重要！setup_systemsより前）
	game_flow_manager.debug_manual_control_all = debug_manual_control_all
	
	# 5. GameFlowManager設定
	game_flow_manager.setup_systems(player_system, card_system, board_system_3d, 
									skill_system, ui_manager, battle_system, special_tile_system)
	game_flow_manager.setup_3d_mode(board_system_3d, player_is_cpu)
	
	# 6. CardSelectionUIへの参照再設定（重要！）
	if ui_manager.card_selection_ui:
		ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager
```

#### なぜ参照再設定が必要か

**問題のタイミング図**:
```
時刻  イベント
T1    ui_manager.create_ui()
	  └─ card_selection_ui.initialize()
		 └─ card_selection_ui.game_flow_manager_ref = game_flow_manager_ref
			(この時点でui_manager.game_flow_manager_refはnull)

T2    game_flow_manager.setup_systems(ui_manager)
	  └─ ui_manager.game_flow_manager_ref = self
		 (ここで初めてui_managerに参照が設定される)

T3    card_selection_ui使用時
	  └─ game_flow_manager_ref.debug_manual_control_all
		 (nullのままなのでエラー)
```

**解決方法**:
- setup_systems()の後に明示的に再設定
- または、debug_manual_control_allを先に設定してからsetup_systems()を呼ぶ

---

## 手札表示システム

### 設計方針

#### 基本仕様
- **常に現在のターンプレイヤーの手札のみを表示**
- ターン切り替え時に全プレイヤーの手札UIを削除してから再生成
- 将来的にPVP対応時も同じロジックで動作可能

#### 手札更新フロー

```gdscript
// CardSystem
emit_signal("hand_updated")  // プレイヤー指定なし
  ↓
// UIManager
func _on_hand_updated():
	var current_player = player_system_ref.get_current_player()
	update_hand_display(current_player.id)  // 現在プレイヤーのIDで更新
  ↓
func update_hand_display(player_id: int):
	// 1. 全プレイヤーの手札を削除（重要！）
	for pid in player_card_nodes.keys():
		for card_node in player_card_nodes[pid]:
			card_node.queue_free()
		player_card_nodes[pid].clear()
	
	// 2. 現在プレイヤーの手札を生成
	var hand_data = card_system_ref.get_all_cards_for_player(player_id)
	for card_data in hand_data:
		var card_node = create_card_node(card_data)
		player_card_nodes[player_id].append(card_node)
	
	// 3. 手札を配置
	rearrange_hand(player_id)
```

#### カード操作の仕様

| 状態 | is_selectable | mouse_filter | ドラッグ | 選択 |
|------|---------------|--------------|---------|------|
| 通常表示 | false | STOP | 無効 | 無効 |
| 選択モード | true | STOP | 無効 | 有効 |

**実装**:
```gdscript
// ui_manager.gd - create_card_node()
card.is_selectable = false  // 初期状態は選択不可

// card_selection_ui.gd - enable_card_selection()
card_node.set_selectable(true, i)  // 選択モード時に有効化
```

**ドラッグ機能**:
- 現在は完全に無効化（コメントアウト）
- 将来的に必要なら再実装

### CardSelectionUIの仕様

#### player_id対応

```gdscript
// 修正前（常にplayer 0固定）
var hand_nodes = ui_manager_ref.player_card_nodes.get(0, [])

// 修正後（current_player.idを使用）
func enable_card_selection(hand_data: Array, available_magic: int, player_id: int = 0):
	var hand_nodes = ui_manager_ref.player_card_nodes.get(player_id, [])
```

#### デバッグモード対応

```gdscript
// show_selection()
var allow_manual = (current_player.id == 0) or 
				   (game_flow_manager_ref and game_flow_manager_ref.debug_manual_control_all)

if allow_manual:
	enable_card_selection(hand_data, current_player.magic_power, current_player.id)
	create_pass_button(hand_data.size())
```

---

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/01/10 | 1.0 | 初版作成 |
| 2025/01/10 | 1.1 | 3D専用設計に修正、分岐路計画追加 |
| 2025/01/11 | 1.2 | 統一捨て札システム追加、2D版削除完了、ターン終了処理解決 |
| 2025/01/11 | 1.3 | 🆕 土地ボーナスシステム追加、隣接土地判定システム追加 |
| 2025/01/12 | 1.4 | 🆕 デバッグ機能追加、システム初期化順序明記、手札表示システム仕様追加 |
| 2025/01/12 | 1.5 | 🆕 貫通スキル実装、土地ボーナス計算の仕様明記 |
| 2025/01/12 | 1.6 | 🆕 感応スキル追加、BattleParticipantクラス説明追加、スキル適用順序明記 |
| 2025/01/12 | 1.7 | 📄 スキル関連を skills_design.md に分離、design.md を簡略化 |

---

**最終更新**: 2025年1月12日（v1.7）  
**関連ドキュメント**: [skills_design.md](skills_design.md) - スキルシステム詳細仕様
