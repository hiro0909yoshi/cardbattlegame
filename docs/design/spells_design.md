# スペル効果システム設計書

**バージョン**: 1.0  
**最終更新**: 2025年11月3日

---

## 📋 目次

1. [概要](#概要)
2. [システムアーキテクチャ](#システムアーキテクチャ)
3. [実装済みスペル効果](#実装済みスペル効果)
4. [フォルダ構成](#フォルダ構成)
5. [設計思想](#設計思想)
6. [今後の拡張](#今後の拡張)

---

## 概要

バトル外・マップ全体に影響する効果を管理するシステム。

**特徴**:
- バトル中の効果（`scripts/battle/`）とは明確に分離
- マップレベルの効果（ドロー、魔力操作、ダイス操作など）を担当
- 各効果は独立したクラスとして実装

**配置理由**:
- `battle/` = バトル中の効果（ダメージ、スキル等）
- `spells/` = バトル外、マップ全体に影響する効果
- 対称的で理解しやすい構造

---

## システムアーキテクチャ

### 基本構造

```
GameFlowManager
  ├─ spell_draw: SpellDraw          # ドロー処理
  ├─ spell_magic: SpellMagic        # 魔力増減（未実装）
  ├─ spell_dice: SpellDice          # ダイス操作（未実装）
  ├─ spell_hand: SpellHand          # 手札操作（未実装）
  └─ spell_land: SpellLand          # 領地変更（未実装）
```

### 初期化フロー

```gdscript
# GameFlowManager.setup_systems()
func setup_systems(p_system, c_system, ...):
	# ... 他のシステム初期化
	
	# SpellDrawの初期化
	spell_draw = SpellDraw.new()
	spell_draw.setup(card_system)
	
	# 将来的に他のスペル効果も同様に初期化
```

### 使用パターン

```gdscript
# ターン開始時のドロー
var drawn = spell_draw.draw_one(player_id)

# トゥームストーン効果（死亡時）
var drawn_cards = spell_draw.draw_until(player_id, 6)

# 固定枚数ドロースペル
var cards = spell_draw.draw_cards(player_id, 2)
```

---

## フォルダ構成

```
scripts/
├── spells/                    # スペル効果システム
│   ├── spell_draw.gd         # ドロー処理 ✅
│   ├── spell_magic.gd        # 魔力増減（未実装）
│   ├── spell_dice.gd         # ダイス操作（未実装）
│   ├── spell_hand.gd         # 手札操作（破壊、交換）（未実装）
│   └── spell_land.gd         # 領地変更（未実装）

docs/design/
├── design_spell.md           # スペル効果システム設計書（本ファイル）
└── spells/                   # 個別スペル効果のドキュメント
	├── カードドロー.md        # ドロー処理の詳細 ✅
	├── 魔力操作.md           # 魔力増減の詳細（未実装）
	├── ダイス操作.md         # ダイス操作の詳細（未実装）
	├── 手札操作.md           # 手札操作の詳細（未実装）
	└── 領地変更.md           # 領地変更の詳細（未実装）
```

---

## 設計思想

### なぜ spells/ フォルダに分離？

1. **責任の明確化**
   - `battle/`: バトル中の効果
   - `spells/`: バトル外の効果
   - 混在を防ぎ、コードの可読性向上

2. **拡張性**
   - 新しいマップ効果を追加しやすい
   - 各効果が独立したクラスとして管理

3. **再利用性**
   - スペルカード、アイテム効果、特殊タイルなど
   - 様々な場面で同じ効果を再利用可能


## 今後の拡張

### 2. SpellMagic（魔力操作）

**予定メソッド**:
```gdscript
func add_magic(player_id: int, amount: int)      # 魔力増加
func reduce_magic(player_id: int, amount: int)   # 魔力減少
func steal_magic(from_id: int, to_id: int, amount: int)  # 魔力奪取
```

**使用例**:
- 聖杯効果: 踏んだら魔力+100
- 魔力吸収スペル: 相手から魔力を奪う

### 3. SpellDice（ダイス操作）

**予定メソッド**:
```gdscript
func modify_dice(player_id: int, modifier: int)  # ダイス目変更
func reroll_dice(player_id: int)                 # 振り直し
func fix_dice(player_id: int, value: int)        # 固定値に設定
```

**使用例**:
- ダイス+1スペル
- 好きな目を出すスペル

### 4. SpellHand（手札操作）

**予定メソッド**:
```gdscript
func discard_random(player_id: int, count: int)  # ランダム破棄
func discard_by_type(player_id: int, card_type: String)  # タイプ指定破棄
func steal_card(from_id: int, to_id: int)        # 手札を奪う
```

**使用例**:
- 手札破壊スペル
- カード盗みスペル

### 5. SpellLand（領地変更）

**予定メソッド**:
```gdscript
func change_element(tile_index: int, new_element: String)  # 属性変更
func change_level(tile_index: int, delta: int)             # レベル変更
func destroy_creature(tile_index: int)                     # クリーチャー破壊
```

**使用例**:
- 土地変換スペル
- 土地レベルダウンスペル
- クリーチャー破壊スペル

---

## 実装アイテム・効果一覧

### ドロー効果を持つアイテム

| ID | 名前 | 効果 | 実装状況 |
|----|------|------|---------|
| 1038 | トゥームストーン | 自破壊時、手札6枚までカードを引く | ✅ 実装済み |

### 今後実装予定

- 魔力増減アイテム
- ダイス操作スペル
- 手札破壊スペル
- 領地変更スペル

---

## 技術的な注意事項

### 参照の初期化順序

```gdscript
# game_3d.gd または GameFlowManager
# 1. CardSystemを先に初期化
card_system = CardSystem.new()

# 2. SpellDrawを初期化（CardSystemへの参照が必要）
spell_draw = SpellDraw.new()
spell_draw.setup(card_system)
```

### BattleSpecialEffectsへの統合

死亡時効果で使用する場合：

```gdscript
# battle_system.gd
func setup_systems(board_system, card_system, player_system):
	# SpellDrawの参照を取得
	var spell_draw = null
	if game_flow_manager_ref and game_flow_manager_ref.spell_draw:
		spell_draw = game_flow_manager_ref.spell_draw
	
	# BattleSpecialEffectsに渡す
	battle_special_effects.setup_systems(board_system, spell_draw)
```

### エラーハンドリング

```gdscript
# SpellDraw内部
if not card_system_ref:
	push_error("SpellDraw: CardSystemが設定されていません")
	return {}
```

---

## 参照ドキュメント

- **カードシステム**: `scripts/card_system.gd`
- **ゲームフロー**: `scripts/game_flow_manager.gd`
- **バトル特殊効果**: `scripts/battle/battle_special_effects.gd`
- **個別スペル効果**: `docs/design/spells/`

---

**最終更新**: 2025年11月3日（v1.0）
