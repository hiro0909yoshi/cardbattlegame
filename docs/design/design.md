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
9. [関連ドキュメント](#関連ドキュメント) ⭐NEW

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
1. バトルカード選択・消費
   └─ 手札から即座に削除・魔力消費

2. 攻撃側アイテムフェーズ (NEW)
   ├─ 手札からアイテムカード選択
   ├─ 魔力消費
   └─ アイテム効果を保存

3. 防御側アイテムフェーズ (NEW)
   ├─ 手札からアイテムカード選択
   ├─ 魔力消費
   └─ アイテム効果を保存

4. バトル準備
   ├─ 攻撃側の土地ボーナス適用
   │  └─ クリーチャー属性 = タイル属性?
   │     └─ HP + (レベル × 10)
   ├─ 防御側の土地ボーナス適用
   └─ アイテム効果適用 (NEW)
	  ├─ AP/HP強化
	  └─ スキル付与

5. 攻撃側の先制攻撃
   ├─ AP ≥ 防御側HP? → 攻撃側勝利
   └─ 防御側生存 → 次へ

6. 防御側の反撃
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
- 無効化: 攻撃を無効化する（１００％無効化なら即死も無効化）
- 不屈: アクション後もダウン状態にならない（何度でも領地コマンド実行可能）

**スキル適用順序**: 感応 → 強打 → 2回攻撃判定 → 攻撃実行 → **即死判定** → バトル結果 → 再生

詳細な仕様、実装例、データ構造については `skills_design.md` を参照してください。

### 3.5. 効果システム (EffectSystem) ✨NEW

#### 責務
- クリーチャーのステータス変更効果の管理
- スペル・アイテム・スキルによる効果の統一管理
- 一時効果と永続効果の分離管理
- 効果の適用・削除・打ち消し

#### 効果の種類

**1. バトル中のみの効果**
- アイテム効果（AP+30、HP+40など）
- バトル終了時に自動削除

**2. 一時効果（移動で消える）**
- スペル「ブレッシング」（HP+10）
- 領地コマンドでクリーチャー移動時に削除

**3. 永続効果（移動で消えない）**
- マスグロース（全クリーチャーMHP+5）
- ドミナントグロース（特定属性MHP+10）
- 交換時やゲーム終了まで維持

**4. 土地数比例効果**
- アームドパラディン「火と土の土地数×10」
- バトル時に動的計算

#### データ構造

```gdscript
creature_data = {
	"base_up_hp": 0,           # 永続的な基礎HP上昇
	"base_up_ap": 0,           # 永続的な基礎AP上昇
	"permanent_effects": [],   # 永続効果配列
	"temporary_effects": [],   # 一時効果配列
	"map_lap_count": 0         # 周回カウント
}

# 効果オブジェクト
effect = {
	"type": "stat_bonus",
	"stat": "hp",              # または "ap"
	"value": 10,
	"source": "spell",
	"source_name": "ブレッシング",
	"removable": true,         # 打ち消し可能か
	"lost_on_move": true       # 移動で消えるか
}
```

#### 主要メソッド

```gdscript
# スペル効果
func add_spell_effect_to_creature(tile_index: int, effect: Dictionary)
func apply_mass_growth(player_id: int, bonus_hp: int = 5)
func apply_dominant_growth(player_id: int, element: String, bonus_hp: int = 10)

# 効果削除
func clear_temporary_effects_on_move(tile_index: int)
func remove_effects_from_creature(tile_index: int, removable_only: bool = true)
```

#### ability_parsedの拡張

**土地数比例効果の例**:
```json
{
  "effects": [
	{
	  "effect_type": "land_count_multiplier",
	  "stat": "ap",
	  "elements": ["fire", "earth"],
	  "multiplier": 10
	}
  ]
}
```

**アイテム効果の例**:
```json
{
  "effects": [
	{
	  "effect_type": "debuff_ap",
	  "value": 10
	},
	{
	  "effect_type": "buff_hp",
	  "value": 40
	}
  ]
}
```

#### 実装例

**アームドパラディン**（火・土土地数×10）
```json
{
  "id": 1,
  "ap": 0,
  "hp": 50,
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "land_count_multiplier",
		"stat": "ap",
		"elements": ["fire", "earth"],
		"multiplier": 10
	  }
	]
  }
}
```

**アーメット**（ST-10、HP+40）
```json
{
  "id": 1001,
  "ability_parsed": {
	"effects": [
	  {"effect_type": "debuff_ap", "value": 10},
	  {"effect_type": "buff_hp", "value": 40}
	]
  }
}
```

詳細は `docs/design/effect_system.md` を参照。

---

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

### 6. スペルシステム (SpellPhaseHandler)

#### 責務
- スペルフェーズの管理
- スペルカードの使用判定
- 対象選択UIの制御
- スペル効果の実行
- 1ターン1回制限の管理

#### アーキテクチャ
```
SpellPhaseHandler
  ├── TargetSelectionUI (対象選択UI)
  └── SpellEffectSystem (効果適用)
```

#### スペルフェーズの流れ
```
ターン開始
  ↓
スペルフェーズ開始
  ├─ スペルカード以外をグレーアウト
  ├─ 「スペルを選択してください」表示
  └─ 人間プレイヤー: カード選択UI表示
	 CPU: 簡易AI判定（30%確率）
  ↓
スペル使用 or ダイスボタンでスキップ
  ↓
【スペル使用の場合】
  ├─ コスト支払い
  ├─ 対象選択が必要?
  │   ├─ Yes → 対象選択UI表示
  │   │   ├─ クリーチャー: 敵クリーチャー一覧
  │   │   └─ プレイヤー: 敵プレイヤー一覧
  │   └─ No → 即座に効果発動
  ↓
  効果実行
  ├─ damage: クリーチャーにダメージ
  ├─ drain_magic: 魔力吸収
  ├─ heal: HP回復（未実装）
  └─ その他効果...
  ↓
  カードを捨て札に
  ↓
スペルフェーズ完了
  ├─ グレーアウト解除
  └─ 次フェーズへ
```

#### 主要メソッド
```gdscript
# フェーズ管理
func start_spell_phase(player_id: int)
func complete_spell_phase()
func pass_spell()

# スペル使用
func use_spell(spell_card: Dictionary)
func execute_spell_effect(spell_card: Dictionary, target_data: Dictionary)

# 対象選択
func _show_target_selection_ui(target_type: String, target_info: Dictionary)
func _get_valid_targets(target_type: String, target_info: Dictionary) -> Array
func on_target_selected(target_data: Dictionary)

# 効果適用
func _apply_single_effect(effect: Dictionary, target_data: Dictionary)
```

#### 実装済みスペル効果

**1. damage - クリーチャーへのダメージ**
```gdscript
{
	"effect_type": "damage",
	"value": 20  # ダメージ量
}
```
- クリーチャーの基本HPと土地ボーナスHPを削る
- HP≤0でクリーチャー撃破、土地を空き地化
- 例: マジックボルト（コスト50MP、ダメージ20）

**2. drain_magic - 魔力吸収**
```gdscript
{
	"effect_type": "drain_magic",
	"value": 30,
	"value_type": "percentage"  # or "fixed"
}
```
- 対象プレイヤーから魔力を奪う
- percentage: 相手の魔力の%を吸収
- fixed: 固定値を吸収
- 例: ドレインマジック（コスト80MP、30%吸収）

#### スペルカードのデータ構造
```json
{
	"id": 201,
	"name": "マジックボルト",
	"type": "spell",
	"cost": {"mp": 50},
	"ability": "対象の敵クリーチャーに20ダメージ",
	"ability_parsed": {
		"target": {
			"type": "creature",
			"required": true
		},
		"effects": [
			{
				"effect_type": "damage",
				"value": 20
			}
		]
	}
}
```

#### スペルとスキルの違い

| 特徴 | スキル | スペル |
|------|--------|--------|
| 実装場所 | `SkillSystem` | `SpellPhaseHandler` |
| 発動タイミング | バトル中 | スペルフェーズ |
| 対象 | バトル参加者のみ | 任意の対象 |
| 効果範囲 | バトル結果に影響 | 広範囲（ダメージ、魔力操作等） |
| データ管理 | `ability_parsed` | `ability_parsed` |

#### 対象選択UIの仕様

**TargetSelectionUI**:
- 画面中央にパネル表示
- ↑↓キーで対象を切り替え
- Enterで決定、Escでキャンセル
- 選択中の対象にカメラ自動フォーカス

**対象タイプ**:
1. `"creature"`: 敵クリーチャー
2. `"player"`: 敵プレイヤー
3. `"land"`: 土地（未実装）

#### 使用制限
- **1ターン1回**: `spell_used_this_turn`フラグで管理
- **コスト制限**: MPが不足している場合は使用不可
- **フェーズ制限**: スペルフェーズでのみ使用可能
  - 召喚フェーズではスペルカードは選択不可
  - スペルカード以外はスペルフェーズで選択不可

#### カードフィルタリングシステム
```gdscript
# UIManager.card_selection_filter
"spell"  # スペルフェーズ: スペルカードのみ選択可能
""       # 召喚フェーズ: クリーチャーカードのみ選択可能

# HandDisplay: グレーアウト適用
if filter_mode == "spell":
	# スペルカード以外をグレーアウト
	if not is_spell_card:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
elif filter_mode == "":
	# スペルカードをグレーアウト
	if is_spell_card:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
```

#### 新しいスペル効果の追加方法

`_apply_single_effect()`メソッドに新しいケースを追加:
```gdscript
match effect_type:
	"damage":
		# 既存のダメージ処理
	
	"drain_magic":
		# 既存の魔力吸収処理
	
	"heal":  # 新しい効果
		# HP回復処理
		if target_data.get("type", "") == "creature":
			var creature = # ... 対象取得
			creature["hp"] += value
			print("回復: +%d HP" % value)
	
	"buff_st":  # STバフ
		# ST上昇処理
		
	# ... その他の効果
```

#### 注意事項

1. **スキルとスペルは完全に分離**
   - スキル: バトル中の特殊能力（`SkillSystem`）
   - スペル: ターン中の魔法（`SpellPhaseHandler`）
   - データ構造は似ているが、処理系統は別

2. **効果の実装場所**
   - スキル効果: `scripts/skills/effect_combat.gd`
   - スペル効果: `scripts/game_flow/spell_phase_handler.gd`の`_apply_single_effect()`

3. **カード種別の判定**
   - `card.get("type", "")` で判定
   - `"creature"`: クリーチャーカード
   - `"spell"`: スペルカード
   - `"item"`: アイテムカード（未実装）

4. **グレーアウトとis_selectableは別管理**
   - グレーアウト: 視覚的な表現（`modulate`）
   - `is_selectable`: 実際の選択可否
   - CardSelectionUIが適切に制御

#### 実装ファイル

**主要ファイル**:
- `scripts/game_flow/spell_phase_handler.gd` - スペルフェーズ管理
- `scripts/ui_components/target_selection_ui.gd` - 対象選択UI
- `data/spell_test.json` - テスト用スペルデータ

**関連ファイル**:
- `scripts/game_flow_manager.gd` - フェーズ統合
- `scripts/ui_manager.gd` - カードフィルター
- `scripts/ui_components/hand_display.gd` - グレーアウト制御
- `scripts/ui_components/card_selection_ui.gd` - カード選択制御

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
  "race": "ゴブリン",      # 🆕 種族（任意）
  "ability_parsed": {...}
}
```

**表示HP計算**:
```gdscript
var total_hp = creature.hp + creature.get("land_bonus_hp", 0)
# 基本HP(40) + 土地ボーナス(30) = 70
```

### 🆕 種族システム（Phase 1: ゴブリン先行実装）

#### 概要
クリーチャーに種族を設定し、種族ベースでスキル判定や検索を行えるシステム。
応援スキルの実装に合わせて先行実装。

#### データ構造
```json
{
  "id": 414,
  "name": "ゴブリン",
  "element": "neutral",
  "race": "ゴブリン",
  "ap": 20,
  "hp": 20
}
```

#### 実装済み種族

**ゴブリン種族（2体）**:
- ID: 414 - ゴブリン（無属性）
- ID: 445 - レッドキャップ（無属性、応援スキル持ち）

#### 使用例

**応援スキルでの種族条件**:
```json
{
  "effect_type": "support",
  "target": {
	"scope": "all_creatures",
	"conditions": [
	  {
		"condition_type": "race",
		"race": "ゴブリン"
	  }
	]
  },
  "bonus": {
	"ap": 20
  }
}
```

レッドキャップ（ID: 445）は、盤面上のゴブリン種族全てにAP+20を付与する。

#### 種族判定コード
```gdscript
# BattleSkillProcessor.check_support_target()
elif condition_type == "race":
  var required_race = condition.get("race", "")
  var creature_race = participant.creature_data.get("race", "")
  
  if creature_race != required_race:
	return false
```

#### 将来の拡張

**実装予定の種族**:
- ドラゴン種族
- アンデッド種族
- デーモン種族
- エルフ種族
- ドワーフ種族

**種族サーチ機能**:
```gdscript
# 将来実装予定
func search_creatures_by_race(race: String) -> Array
```

**種族シナジースキル**:
- 同種族ボーナス
- 種族専用装備
- 種族変更スペル

#### 設計思想
- **段階的実装**: まずゴブリンで種族システムを確立
- **後方互換性**: `race`フィールドは任意（未設定でも動作）
- **拡張性**: 将来的に多様な種族を追加可能
- **スキル統合**: 既存の条件チェックシステムに統合済み

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
│ 🆕 スペルフェーズ       │
│  ├─ スペルカード使用可能 │
│  ├─ 対象選択UI         │
│  └─ ダイスでスキップ    │
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

### 🆕 ダウン状態システム（Phase 1-A）

#### 概要
土地でアクション（召喚、レベルアップ、移動、交換）を実行すると、その土地は「ダウン状態」になり、次のターンまで再度選択できなくなる。

#### ダウン状態の設定タイミング
- 召喚実行後
- レベルアップ実行後
- クリーチャー移動実行後（移動先の土地）
- クリーチャー交換実行後

**例外: 不屈スキル**
- 不屈スキルを持つクリーチャーがいる土地は、アクション後もダウン状態にならない
- 何度でも領地コマンドを実行可能

#### ダウン状態の解除タイミング
- プレイヤーがスタートマスを通過したとき
- 全プレイヤーの全土地のダウン状態が一括解除される

#### 制約
- **ダウン状態の土地は領地コマンドで選択できない**
  - `get_player_owned_lands()`でダウン状態の土地を除外
  - UI上で選択肢として表示されない
- ダウン状態でもクリーチャーは通常通り機能する
  - バトルの防御側として機能
  - 通行料は発生する

#### 実装
```gdscript
# ダウン状態の設定
tile.set_down(true)

# ダウン状態の確認
if tile.is_down():
	# 選択不可

# ダウン状態の解除（スタート通過時）
movement_controller.clear_all_down_states_for_player(player_id)
```

#### 不屈スキルの実装
```gdscript
# SkillSystem.gd
static func has_unyielding(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	var ability_detail = creature_data.get("ability_detail", "")
	return "不屈" in ability_detail

# ダウン状態設定時の不屈チェック（各アクション処理）
if tile.has_method("set_down_state"):
	var creature = tile.creature_data if tile.has("creature_data") else {}
	if not SkillSystem.has_unyielding(creature):
		tile.set_down_state(true)
	else:
		print("不屈によりダウンしません")
```

**不屈持ちクリーチャー一覧** (16体):
- 火: シールドメイデン(14), ショッカー(18), バードメイデン(28)
- 水: エキノダーム(113), カワヒメ(117), マカラ(141)
- 地: キャプテンコック(207), ヒーラー(234), ピクシー(235), ワーベア(249)
- 風: グレートニンバス(312), トレジャーレイダー(331), マーシャルモンク(341), マッドハーレクイン(342)
- 無: アーキビショップ(403), シャドウガイスト(418)

#### デバッグコマンド
- **Uキー**: 現在プレイヤーの全土地のダウン状態を即座に解除
- テスト用の機能（本番では無効化予定）

---

### 🆕 領地コマンドの制約（Phase 1-A）

#### 基本制約
1. **1ターンに1回のみ実行可能**
   - レベルアップ、移動、交換のいずれか1つのみ
   - 実行後は自動的にターン終了
   
2. **召喚と領地コマンドは排他的**
   - 召喚を実行した場合、領地コマンドは実行できない
   - 領地コマンドを実行した場合、召喚は実行できない
   - どちらか一方のみ選択可能

3. **ダウン状態の土地は選択不可**
   - アクション実行済みの土地は次のターンまで使用不可
   - 選択肢として表示されない
   - **例外**: 不屈スキル持ちのクリーチャーがいる土地はダウンしないため、何度でも使用可能

#### 土地選択の操作方法
- **矢印キー（↑↓←→）**: 土地を切り替え（プレビュー）
- **Enterキー**: 選択を確定してアクションメニューへ
- **数字キー（1-0）**: 該当する土地を即座に確定
- **C/Escapeキー**: キャンセル

#### アクション選択
- **Lキー**: レベルアップ
- **Mキー**: クリーチャー移動
- **Sキー**: クリーチャー交換
- **C/Escapeキー**: 前画面に戻る

---

### 🆕 クリーチャー移動フロー（Phase 1-A）

```
領地コマンド → 移動を選択
  ↓
移動元の土地を選択（ダウン状態除外）
  ↓
隣接する移動先を表示
  ├─ 空き地
  ├─ 自分の土地（移動不可）
  └─ 敵の土地
  ↓
移動先を選択（↑↓キーで切り替え）
  ↓
【空き地への移動】
  - 移動元が空き地になる
  - 移動先に土地獲得
  - クリーチャー配置
  - ダウン状態設定
  - ターン終了
  
【敵地への移動】
  - 移動元が空き地になる
  - バトル実行
  - 勝利: 土地獲得 + ダウン設定
  - 敗北: クリーチャー消滅
  - ターン終了
```

**実装クラス**:
- `LandCommandHandler.execute_move_creature()`
- `LandCommandHandler.confirm_move()`

---

### 🆕 クリーチャー交換フロー（Phase 1-A）

```
領地コマンド → 交換を選択
  ↓
交換対象の土地を選択（ダウン状態除外）
  ↓
手札にクリーチャーカードがあるか確認
  ├─ なし → エラーメッセージ
  └─ あり → 次へ
  ↓
新しいクリーチャーカードを選択
  ↓
元のクリーチャーを手札に戻す
  ↓
新しいクリーチャーを召喚
  - コスト支払い（mp × 10G）
  - 土地ボーナス適用
  - 土地レベル継承
  - ダウン状態設定
  ↓
ターン終了
```

**実装クラス**:
- `LandCommandHandler.execute_swap_creature()`
- `TileActionProcessor.execute_swap()`

---

### バトルフロー詳細
```
バトル開始
  ↓
カード選択（手札から）
  ↓
コスト支払い（mp × 10G）
  ↓
バトルカード消費（手札から削除）
  ↓
🆕 攻撃側アイテムフェーズ
  ├─ アイテムカード選択UI表示
  ├─ アイテムカード以外はグレーアウト
  ├─ アイテム選択 or パス
  ├─ アイテム使用時
  │   ├─ 魔力消費（mp × 10G）
  │   ├─ カードを捨て札に
  │   └─ 効果を保存（バトル時に適用）
  └─ 防御側アイテムフェーズへ
  ↓
🆕 防御側アイテムフェーズ
  ├─ 防御側プレイヤーの手札を表示
  ├─ アイテムカード選択UI表示
  ├─ アイテム選択 or パス
  ├─ アイテム使用時
  │   ├─ 魔力消費（mp × 10G）
  │   ├─ カードを捨て札に
  │   └─ 効果を保存（バトル時に適用）
  └─ バトル開始へ
  ↓
🆕 アイテム効果適用
  ├─ 攻撃側のアイテム効果適用
  │   ├─ buff_ap: AP増加
  │   ├─ buff_hp: HP増加（item_bonus_hp）
  │   └─ grant_skill: スキル付与（強打、先制など）
  └─ 防御側のアイテム効果適用
	  ├─ buff_ap: AP増加
	  ├─ buff_hp: HP増加（item_bonus_hp）
	  └─ grant_skill: スキル付与
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
│   ├── game_flow/
│   │   ├── land_command_handler.gd      # 領地コマンド統合管理
│   │   ├── land_selection_manager.gd    # 土地選択ロジック
│   │   ├── land_action_executor.gd      # アクション実行ロジック
│   │   ├── land_input_handler.gd        # 入力処理
│   │   ├── tile_action_processor.gd     # タイルアクション処理
│   │   ├── tile_summon_handler.gd       # 召喚処理
│   │   ├── tile_leveling_handler.gd     # レベルアップ処理
│   │   ├── spell_phase_handler.gd       # スペルフェーズ管理
│   │   └── item_phase_handler.gd        # アイテムフェーズ管理
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
| 2025/10/25 | 1.5 | 🆕 関連ドキュメント索引追加、スキルシステム個別ファイル（14個）へのリンク追加 |

---

## 関連ドキュメント

このドキュメントはプロジェクト全体のアーキテクチャと概要を示すマスタードキュメントです。
各システムの詳細仕様については、以下の関連ドキュメントを参照してください。

### システム設計ドキュメント

#### スキルシステム
- **[skills_design.md](skills_design.md)** - スキルシステム全体設計
  - 実装済みスキル一覧（18種類）
  - スキル適用順序とアーキテクチャ
  - 将来実装予定のスキル

#### 個別スキル仕様書（14ファイル）

**実装済みスキル:**
1. [assist_skill.md](skills/assist_skill.md) - 応援スキル
2. [double_attack_skill.md](skills/double_attack_skill.md) - 2回攻撃スキル
3. [first_strike_skill.md](skills/first_strike_skill.md) - 先制スキル
4. [indomitable_skill.md](skills/indomitable_skill.md) - 不屈スキル
5. [instant_death_skill.md](skills/instant_death_skill.md) - 即死スキル
6. [nullify_skill.md](skills/nullify_skill.md) - 無効化スキル
7. [penetration_skill.md](skills/penetration_skill.md) - 貫通スキル
8. [power_strike_skill.md](skills/power_strike_skill.md) - 強打スキル
9. [reflect_skill.md](skills/reflect_skill.md) - 反射スキル
10. [regeneration_skill.md](skills/regeneration_skill.md) - 再生スキル
11. [resonance_skill.md](skills/resonance_skill.md) - 感応スキル
12. [scroll_attack_skill.md](skills/scroll_attack_skill.md) - 巻物攻撃スキル
13. [support_skill.md](skills/support_skill.md) - 援護スキル

**未実装スキル:**
14. [item_destruction_theft_skill.md](skills/item_destruction_theft_skill.md) - アイテム破壊・盗みスキル

#### その他のシステム
- **[effect_system.md](effect_system.md)** - エフェクトシステム設計
- **[effect_system_design.md](effect_system_design.md)** - エフェクトシステム詳細設計
- **[battle_test_tool_design.md](battle_test_tool_design.md)** - バトルテストツール設計
- **[turn_end_flow.md](turn_end_flow.md)** - ターン終了フロー
- **[defensive_creature_design.md](defensive_creature_design.md)** - 防御型クリーチャー設計

### 実装・進捗管理ドキュメント

- **[docs/progress/](../progress/)** - 実装進捗と状態管理
- **[docs/implementation/](../implementation/)** - 実装仕様書
- **[docs/issues/](../issues/)** - タスク管理とバグトラッキング
- **[docs/refactoring/](../refactoring/)** - リファクタリング記録
| 2025/01/12 | 1.5 | 🆕 貫通スキル実装、土地ボーナス計算の仕様明記 |
| 2025/01/12 | 1.6 | 🆕 感応スキル追加、BattleParticipantクラス説明追加、スキル適用順序明記 |
| 2025/01/12 | 1.7 | 📄 スキル関連を skills_design.md に分離、design.md を簡略化 |
| 2025/10/17 | 1.8 | 🆕 スペルフェーズシステム追加、スペルとスキルの分離明記 |

---

**最終更新**: 2025年10月17日（v1.8）  
**関連ドキュメント**: [skills_design.md](skills_design.md) - スキルシステム詳細仕様
