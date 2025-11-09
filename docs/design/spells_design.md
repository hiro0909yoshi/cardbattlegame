# スペル効果システム設計書

**バージョン**: 2.0  
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
  ├─ spell_draw: SpellDraw          # ドロー処理 ✅
  ├─ spell_magic: SpellMagic        # 魔力増減 ✅
  ├─ spell_land: SpellLand          # 土地操作 ✅
  ├─ spell_dice: SpellDice          # ダイス操作（未実装）
  └─ spell_hand: SpellHand          # 手札操作（未実装）
```

### 初期化フロー

```gdscript
# GameFlowManager.gd
class_name GameFlowManager

# スペル効果システム
var spell_draw: SpellDraw
var spell_magic: SpellMagic
var spell_land: SpellLand

func setup_systems(p_system, c_system, board_system, creature_manager, ...):
	# ... 他のシステム初期化
	
	# SpellDrawの初期化
	spell_draw = SpellDraw.new()
	spell_draw.setup(card_system)
	
	# SpellMagicの初期化
	spell_magic = SpellMagic.new()
	spell_magic.setup(player_system)
	
	# SpellLandの初期化
	spell_land = SpellLand.new()
	spell_land.setup(board_system, creature_manager, player_system)
	
	# 将来的に他のスペル効果も同様に初期化
```

### 初期化の依存関係

| スペルシステム | 必要な参照 |
|---------------|-----------|
| SpellDraw | CardSystem |
| SpellMagic | PlayerSystem |
| SpellLand | BoardSystem3D, CreatureManager, PlayerSystem |
| SpellDice | （未実装） |
| SpellHand | CardSystem, PlayerSystem |

**初期化順序**:
1. 基本システム（PlayerSystem, CardSystem等）を先に初期化
2. その後、スペルシステムを初期化し、参照を渡す
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

### スクリプトファイル

```
scripts/
├── spells/                          # スペル効果モジュール（必須配置）
│   ├── spell_draw.gd               # ドロー処理 ✅
│   ├── spell_magic.gd              # 魔力増減 ✅
│   ├── spell_land.gd               # 土地操作 ✅
│   ├── spell_dice.gd               # ダイス操作（未実装）
│   └── spell_hand.gd               # 手札操作（未実装）
│
├── spell_effect_system.gd          # 💬（継続効果）管理システム
│
└── game_flow/
	└── spell_phase_handler.gd      # スペルフェーズ制御 ✅
```

### ドキュメントファイル

```
docs/design/
├── spells_design.md                # スペル効果システム設計書（本ファイル）
│
└── spells/                         # 個別スペル効果のドキュメント
	├── カードドロー.md              # ドロー処理の詳細 ✅
	├── 魔力増減.md                 # 魔力増減の詳細 ✅
	├── ダイス操作.md               # ダイス操作の詳細（未実装）
	├── 手札操作.md                 # 手札操作の詳細（未実装）
	└── 領地変更.md                 # 領地変更の詳細 ✅
```

### ファイル配置ルール

**`scripts/spells/`内に必須**:
- スペル効果の実行モジュール（spell_*.gd）
- 各モジュールは特定のスペル効果カテゴリーを担当

**`scripts/`直下または適切な場所**:
- システム全体を管理するクラス（SpellEffectSystem等）
- 既存のゲームフロー制御（SpellPhaseHandler等）

**`docs/design/spells/`内**:
- 個別スペル効果の詳細ドキュメント
- 実装例、使用例、仕様詳細

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

---

## スペルの特殊システム

### 密命（Mission）システム

**概要**:
密命は、スペルカードに付与される特殊な条件効果。クリーチャーのスキルに相当するもの。

**特徴**:
- 条件を満たせば強力な効果を発動
- 条件を満たさない場合は代替効果（カードをブックに戻す、カードを引く等）
- **敵プレイヤーにカード内容が分からない**という戦略的効果

**密命の動作**:

```
スペル使用
  ↓
条件チェック
  ↓
成功 → メイン効果発動
失敗 → 代替効果発動（カードをブックに戻す等）
```

### 復帰[ブック]について

密命の失敗効果などで「復帰[ブック]」が使われる場合、**既存のアイテム復帰スキルシステム**を活用できます。

**実装場所**: `scripts/battle/skills/skill_item_return.gd`

**使用方法**:
```gdscript
# CardSystemを使ってデッキに戻す
card_system.return_card_to_deck(card_id, player_id)  # デッキの一番上に戻る
```

**注意点**:
- 「復帰[ブック]」= デッキの一番上に戻す
- 「復帰[手札]」= 手札に戻す（手札上限を超えても追加）
- 既存のアイテム復帰システムと同じ仕組みを使う

---

**密命スペルの例**:

| ID | 名前 | 条件 | 成功効果 | 失敗効果 |
|----|------|------|---------|---------|
| 2004 | アセンブルカード | 手札に火水風地がある | G500獲得 | カードを2枚引く |
| 2029 | サドンインパクト | 対象がレベル4領地 | レベルを1下げる | （失敗なし） |
| 2085 | フラットランド | レベル2領地を5つ持つ | それらを1上げる | 復帰[ブック] |
| 2096 | ホームグラウンド | 属性違いの領地を4つ持つ | 合う属性に変化 | 復帰[ブック] |

**実装方針**:

密命は個別のスペル実装で条件チェックを行う。密命専用のシステムは不要。

```gdscript
# SpellPhaseHandler内での処理例
func _execute_flatten_land_spell(player_id: int):
	# 条件チェック: レベル2領地を5つ持つか
	var level2_lands = []
	for tile_index in range(20):
		var tile = board_system.tiles[tile_index]
		if tile.tile_owner == player_id and tile.land_level == 2:
			level2_lands.append(tile_index)
	
	if level2_lands.size() >= 5:
		# 成功: レベルを1上げる
		for tile_index in level2_lands:
			spell_land.change_level(tile_index, 1)
	else:
		# 失敗: カードをブックに戻す
		card_system.return_card_to_deck(card_id)
```

**注意点**:
- 「復帰[ブック]」= カードをデッキの一番上に戻す
- 「復帰[手札]」= カードを手札に戻す
- 密命の失敗は戦略的な要素であり、ペナルティではない

---

## 実装済みスペル効果

### 1. SpellDraw（カードドロー）✅

**実装ファイル**: `scripts/spells/spell_draw.gd`

**メソッド**:
```gdscript
func draw_one(player_id: int) -> Dictionary          # ターン開始時の1枚ドロー
func draw_cards(player_id: int, count: int) -> Array # 固定枚数ドロー
func draw_until(player_id: int, target: int) -> Array # 指定枚数まで補充
func exchange_all_hand(player_id: int) -> Array      # 手札全交換
```

**詳細**: [カードドロー.md](./spells/カードドロー.md)

---

### 2. SpellMagic（魔力増減）✅

**実装ファイル**: `scripts/spells/spell_magic.gd`

**メソッド**:
```gdscript
func add_magic(player_id: int, amount: int)                        # 魔力増加
func reduce_magic(player_id: int, amount: int)                     # 魔力減少
func steal_magic(from_id: int, to_id: int, amount: int) -> int    # 魔力奪取
```

**実装アイテム**:
- ゼラチンアーマー（ID: 1029）: ダメージ受け取り時に魔力獲得
- ゴールドハンマー（ID: 1012）: 敵非破壊時に魔力獲得
- ゴールドグース（ID: 1011）: 死亡時に魔力獲得

**詳細**: [魔力増減.md](./spells/魔力増減.md)

---

### 3. SpellLand（土地操作）✅

**実装ファイル**: `scripts/spells/spell_land.gd`

**メソッド**:
```gdscript
func change_element(tile_index: int, new_element: String) -> bool     # 属性変更
func change_level(tile_index: int, delta: int) -> bool                # レベル増減
func set_level(tile_index: int, level: int) -> bool                   # レベル固定
func destroy_creature(tile_index: int) -> bool                        # クリーチャー破壊
func abandon_land(tile_index: int, player_id: int) -> int             # 土地放棄
func change_element_with_condition(...) -> bool                       # 条件付き属性変更
func get_player_dominant_element(player_id: int) -> String            # 最多属性取得
func change_level_multiple_with_condition(...) -> int                 # 一括レベル変更
```

**対応スペル**:
- アースシフト（ID: 2001）: 属性を地に変更
- アステロイド（ID: 2003）: レベルを1下げる
- ランドトランス（ID: 2118）: 土地放棄で魔力獲得

**詳細**: [領地変更.md](./spells/領地変更.md)

---

## 💬（継続効果）システム設計

### 概要

複数ターンにわたってプレイヤー/クリーチャー/土地/世界全体にかかる効果を管理するシステム。

**特徴**:
- 即時効果（ダメージ等）と継続効果（💬）を明確に分離
- ターン経過による自動消滅
- イベント（移動、交換、撃破等）による消滅
- 上書きルール（同じ効果は上書きされる）

---

### 💬の種類と消滅条件

| 対象 | 消滅条件 | 例 |
|------|---------|-----|
| **クリーチャーの💬** | ①移動 ②交換 ③撃破 ④ターン経過 ⑤上書き ⑥消滅スペル | 不屈(5R)、戦闘行動不可 |
| **土地の💬** | ①所有者変更（要調査） ②ターン経過 ③上書き ④消滅スペル | 魔力結界、通行料1.5倍 |
| **プレイヤーの💬** | ①ターン経過 ②上書き ③消滅スペル | 防魔(5R)、通行料無効 |
| **世界呪** | ①上書き ②消滅スペル | コスト上昇(6R)、召喚条件解除(6R) |

**重要**: クリーチャーの💬は**移動でも消える**

---

### 💬の重複ルール

**上書き方式**を採用：
- 同じ効果が再度かかった場合、**新しい効果で上書き**
- 前の効果は完全に消滅
- 異なる効果は同時に有効（スタック可能）

**例**:
```
状態1: 防魔(5R)
　↓
状態2: 防魔(3R)をかける
　↓
結果: 防魔(3R)（5Rの方は消滅）
```

**世界呪の特殊ルール**:
- 世界呪は**1つだけ有効**
- 新しい世界呪をかけると、前の世界呪は消滅

---

### 💬の持続期間

**ターン指定あり**:
- `"duration": 5` → 5ラウンド後に自動消滅
- ターン終了時にカウントダウン

**ターン指定なし（永続）**:
- `"duration": 0` または記載なし → 永続効果
- 消滅条件：上書き、消滅スペル、イベント（移動等）

---

### 実装方式：ability_parsedへの統合

**設計方針**:
- 💬で付与されたスキルは`ability_parsed`に直接追加
- `source`フィールドで元々のスキルと区別
- 既存のSkillSystemをそのまま活用

**データ構造**:

```json
{
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "indomitable",
		"source": "original"
	  },
	  {
		"effect_type": "stat_buff",
		"stat": "AP",
		"value": 20,
		"source": "spell",
		"duration": 5,
		"ability_id": "ability_earth_shift_001",
		"applied_turn": 10
	  }
	],
	"keywords": ["不屈", "先制"]
  }
}
```

**フィールド説明**:

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|-----|
| `effect_type` | String | 効果タイプ | ✅ |
| `source` | String | 付与元（"original" / "spell" / "item"） | ✅ |
| `duration` | int | 残りターン数（0=永続） | ✅（spellの場合） |
| `ability_id` | String | 💬の識別子（削除用） | ✅（spellの場合） |
| `applied_turn` | int | 付与されたターン番号 | ❌ |

---

### SpellEffectSystemの役割

**主な責務**:
1. 💬の付与・削除
2. ターン経過によるduration減算
3. イベントによる💬削除（移動、交換等）
4. 💬の上書き処理

**実装ファイル**: `scripts/spell_effect_system.gd`

```gdscript
class_name SpellEffectSystem

# 💬管理用の参照
var creature_manager_ref: CreatureManager
var player_system_ref: PlayerSystem
var board_system_ref: BoardSystem3D

# 世界呪の管理（1つだけ有効）
var world_ability: Dictionary = {}

# 💬の付与（クリーチャー）
func apply_ability_to_creature(tile_index: int, ability_data: Dictionary) -> void:
	var creature_data = creature_manager_ref.get_data_ref(tile_index)
	
	# ability_parsedの初期化
	if not creature_data.has("ability_parsed"):
		creature_data["ability_parsed"] = {"effects": [], "keywords": []}
	
	# 既存の同種💬を削除（上書き）
	_remove_same_type_ability(creature_data, ability_data)
	
	# 新しい💬を追加
	for effect in ability_data.get("effects", []):
		var new_effect = effect.duplicate()
		new_effect["source"] = "spell"
		new_effect["duration"] = ability_data.get("duration", 0)
		new_effect["ability_id"] = ability_data.get("ability_id", "")
		new_effect["applied_turn"] = current_turn
		
		creature_data["ability_parsed"]["effects"].append(new_effect)

# 💬の削除（クリーチャー）
func remove_all_spell_abilities_from_creature(tile_index: int) -> void:
	var creature_data = creature_manager_ref.get_data_ref(tile_index)
	
	var effects = creature_data.get("ability_parsed", {}).get("effects", [])
	for i in range(effects.size() - 1, -1, -1):
		if effects[i].get("source") == "spell":
			effects.remove_at(i)

# ターン経過処理
func on_turn_end(player_id: int) -> void:
	_decrement_durations()
	_remove_expired_abilities()

# duration減算
func _decrement_durations() -> void:
	# 全クリーチャーのdurationを減算
	for tile_index in range(20):
		if creature_manager_ref.has_creature(tile_index):
			var creature_data = creature_manager_ref.get_data_ref(tile_index)
			var effects = creature_data.get("ability_parsed", {}).get("effects", [])
			
			for effect in effects:
				if effect.get("source") == "spell" and effect.get("duration", 0) > 0:
					effect["duration"] -= 1
	
	# プレイヤーのdurationを減算
	# ... (同様の処理)
	
	# 世界呪のdurationを減算
	if world_ability.get("duration", 0) > 0:
		world_ability["duration"] -= 1

# 期限切れ💬の削除
func _remove_expired_abilities() -> void:
	# duration=0になった💬を削除
	pass
```

---

### イベントフック

**クリーチャー移動時**:
```gdscript
# MovementController または該当箇所
func on_creature_moved(from_tile: int, to_tile: int):
	spell_effect_system.remove_all_spell_abilities_from_creature(from_tile)
```

**クリーチャー交換時**:
```gdscript
func on_creature_exchanged(tile_index: int):
	spell_effect_system.remove_all_spell_abilities_from_creature(tile_index)
```

**クリーチャー撃破時**:
```gdscript
func on_creature_defeated(tile_index: int):
	spell_effect_system.remove_all_spell_abilities_from_creature(tile_index)
```

**土地所有者変更時**（要調査）:
```gdscript
func on_land_owner_changed(tile_index: int):
	# 土地の💬を削除するか？（仕様確認後実装）
	pass
```

---

### 💬のUI表示

**表示場所**（未実装）:
- プレイヤーステータス画面に現在の💬を一覧表示
- 各💬の残りターン数を表示
- アイコンで効果を視覚的に表現

**実装予定**:
- `ui_components/player_status_ui.gd`（新規作成）
- 💬アイコンのリソース作成

---

### 💬の発動タイミング

💬の効果は様々なタイミングで発動する：

| タイミング | 例 |
|-----------|-----|
| **戦闘準備時** | 能力値+20、能力値-20 |
| **戦闘中** | 無効化[通常攻撃]、防魔 |
| **移動時** | 強制停止、移動不可 |
| **通行料発生時** | 通行料1.5倍、通行料無効 |
| **常時** | 不屈、制限解除 |

**実装パターン**:
- 各システムが必要なタイミングでAbilitySystemにクエリ
- 例：`spell_effect_system.get_stat_modifiers(tile_index)` → 能力値補正を取得

---

### 消滅スペル

💬を消すスペルの実装：

**例**: ピュアリファイ（ID: 2073）- 全💬を消す

```gdscript
# SpellEffectExecutor
func execute_purify_spell():
	var removed_count = spell_effect_system.remove_all_abilities()
	var gold_reward = removed_count * 50
	spell_magic.add_magic(current_player_id, gold_reward)
```

---

## ターゲットシステム設計

### ターゲットタイプ（4種類）

スペルおよび秘術は以下の4種類のターゲットを持つ：

| ターゲットタイプ | 説明 | 選択対象 | 例 |
|----------------|------|---------|-----|
| `creature` | クリーチャー | 自分/同盟/敵のクリーチャー | マジックボルト、シャイニングガイザー |
| `land` | 土地 | 自分/同盟/敵/空地の土地 | アースシフト、サブサイド |
| `player` | プレイヤー | 自分/敵のプレイヤー | ドレインマジック、バリアー |
| `world` | 世界呪 | ターゲット選択なし（全体効果） | ウェイストワールド、ソリッドワールド |

### ターゲット選択UI

**設計方針**:
- 領地コマンドと同じ**上下キー選択方式**を採用
- 土地とクリーチャーで統一されたインターフェース
- CreatureManagerによる分離を活用

**選択フロー**:
```
ターゲット選択開始
  ↓
対象リスト表示（↑↓で選択）
  ├─ creature → クリーチャー一覧
  ├─ land → 土地一覧
  └─ player → プレイヤー一覧
  ↓
Enterで確定 / Escでキャンセル
  ↓
効果実行
```

### ターゲットフィルター

各ターゲットタイプに追加のフィルターを指定可能：

```json
{
  "target_type": "creature",
  "target_filter": "enemy",           // 敵のみ
  "target_conditions": {
	"max_hp": 50,                     // MHP50以下
	"element": ["fire", "water"]      // 特定属性
  }
}
```

**フィルター値**:
- `self`: 自分のみ
- `ally`: 自分と同盟
- `enemy`: 敵のみ
- `all`: 全て

---

## 秘術システム設計

### 概要

**秘術**は、クリーチャーが持つスペル的効果。スペルフェーズで使用可能。

**特徴**:
- 発動者：**自分のクリーチャー**（将来的に同盟クリーチャーも想定）
- コスト：秘術ごとに異なる魔力コスト
- タイミング：スペルフェーズで1ターン1回（スペルカードとは**排他的**）
- 制約：スペルカードと秘術は同じターンに両方使えない

### スペルフェーズのフロー

```
スペルフェーズ開始
├─ A) スペルカード使用
│   └─ 手札のスペルをダブルクリック
│       → ターゲット選択（必要な場合）
│       → 魔力コスト支払い
│       → 効果実行
│       → カードを捨て札へ
│
├─ B) 秘術使用
│   └─ [秘術を使う]ボタンをクリック
│       → 自分のクリーチャー一覧表示（↑↓で選択）
│       → クリーチャー選択（Enterで確定）
│       → 秘術が確定（そのクリーチャーの秘術）
│       → ターゲット選択（必要な場合）
│       → 魔力コスト支払い
│       → 効果実行
│
└─ C) パス
	└─ [ダイスを振る]ボタンをクリック
		→ スペルフェーズ終了
		→ ダイスフェーズへ
```

### 秘術のデータ構造

**JSONファイル内**:

```json
{
  "id": 214,
  "name": "コアトリクエ",
  "ability": "秘術",
  "ability_detail": "ブックが相手より多い場合、ST&HP+20；秘術[G50・対象ブックの上1枚を破壊]",
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "conditional_stat_buff",
		"condition": {
		  "condition_type": "deck_count_advantage",
		  "comparison": "greater"
		},
		"stat_changes": {"ap": 20, "hp": 20}
	  }
	],
	"mystic_arts": [
	  {
		"name": "デッキ破壊",
		"description": "対象ブックの上1枚を破壊",
		"cost": 50,
		"target_type": "player",
		"target_filter": "enemy",
		"effects": [
		  {
			"effect_type": "destroy_deck_top",
			"count": 1
		  }
		]
	  }
	]
  }
}
```

**秘術の定義フィールド**:

| フィールド | 型 | 説明 | 必須 |
|-----------|-----|------|-----|
| `name` | String | 秘術の名前 | ✅ |
| `description` | String | 秘術の説明文 | ❌ |
| `cost` | int | 魔力コスト | ✅ |
| `target_type` | String | ターゲットタイプ（creature/land/player/world） | ✅ |
| `target_filter` | String | ターゲットフィルター（self/ally/enemy/all） | ❌ |
| `target_conditions` | Dictionary | 追加の選択条件 | ❌ |
| `effects` | Array | 効果の配列 | ✅ |

### 秘術の実装時期

**注意**: 秘術システムは**全てのスペル実装完了後**に取り組む予定。
現時点では設計のみを記載し、実装は保留。

---

## システム統合ガイド

### GameFlowManagerへの統合

**ファイル**: `scripts/game_flow_manager.gd`

```gdscript
class_name GameFlowManager

# スペル効果システム
var spell_draw: SpellDraw
var spell_magic: SpellMagic
var spell_land: SpellLand
# var spell_dice: SpellDice    # 未実装
# var spell_hand: SpellHand    # 未実装

func setup_systems(p_system: PlayerSystem, c_system: CardSystem, 
				   board_system: BoardSystem3D, creature_manager: CreatureManager, ...):
	# 基本システムの初期化
	player_system = p_system
	card_system = c_system
	# ... 他のシステム
	
	# スペル効果システムの初期化
	_setup_spell_systems(board_system, creature_manager)

func _setup_spell_systems(board_system: BoardSystem3D, creature_manager: CreatureManager):
	# SpellDraw
	spell_draw = SpellDraw.new()
	spell_draw.setup(card_system)
	print("[SpellDraw] 初期化完了")
	
	# SpellMagic
	spell_magic = SpellMagic.new()
	spell_magic.setup(player_system)
	print("[SpellMagic] 初期化完了")
	
	# SpellLand
	spell_land = SpellLand.new()
	spell_land.setup(board_system, creature_manager, player_system)
	print("[SpellLand] 初期化完了")
	
	# 将来的な拡張
	# spell_dice = SpellDice.new()
	# spell_dice.setup(player_system)
	# 
	# spell_hand = SpellHand.new()
	# spell_hand.setup(card_system, player_system)
```

### BattleSystemへの参照渡し

死亡時効果などでSpellDrawやSpellMagicを使用する場合：

**ファイル**: `scripts/battle_system.gd`

```gdscript
class_name BattleSystem

var spell_draw: SpellDraw
var spell_magic: SpellMagic

func setup_systems(board_system, card_system, player_system, 
				   game_flow_manager_ref):
	# SpellDrawの参照を取得
	if game_flow_manager_ref and game_flow_manager_ref.spell_draw:
		spell_draw = game_flow_manager_ref.spell_draw
	
	# SpellMagicの参照を取得
	if game_flow_manager_ref and game_flow_manager_ref.spell_magic:
		spell_magic = game_flow_manager_ref.spell_magic
	
	# BattleSpecialEffectsに渡す
	battle_special_effects.setup_systems(board_system, spell_draw, spell_magic)
```

### SpellPhaseHandlerでの使用

**ファイル**: `scripts/game_flow/spell_phase_handler.gd`

```gdscript
class_name SpellPhaseHandler

var game_flow_manager_ref: GameFlowManager

func _execute_spell_effect(spell_data: Dictionary, target_index: int):
	var effect_type = spell_data.get("effect_type", "")
	
	match effect_type:
		# カードドロー系
		"draw_cards":
			var count = spell_data.get("count", 2)
			game_flow_manager_ref.spell_draw.draw_cards(current_player_id, count)
		
		# 魔力操作系
		"drain_magic":
			var percentage = spell_data.get("percentage", 30)
			var target_player = spell_data.get("target_player_id")
			var amount = _calculate_magic_drain(target_player, percentage)
			game_flow_manager_ref.spell_magic.steal_magic(
				target_player, current_player_id, amount
			)
		
		# 土地操作系
		"change_element":
			var new_element = spell_data.get("element", "earth")
			game_flow_manager_ref.spell_land.change_element(target_index, new_element)
		
		"change_level":
			var delta = spell_data.get("delta", -1)
			game_flow_manager_ref.spell_land.change_level(target_index, delta)
		
		"destroy_creature":
			game_flow_manager_ref.spell_land.destroy_creature(target_index)
		
		"abandon_land":
			var value = game_flow_manager_ref.spell_land.abandon_land(
				target_index, current_player_id
			)
			var magic_gain = int(value * spell_data.get("conversion_rate", 0.7))
			game_flow_manager_ref.spell_magic.add_magic(current_player_id, magic_gain)
```

### 初期化時のエラーチェック

```gdscript
# game_flow_manager.gd
func _setup_spell_systems(board_system, creature_manager):
	# 必要な参照の確認
	if not card_system:
		push_error("GameFlowManager: CardSystemが初期化されていません")
		return
	
	if not player_system:
		push_error("GameFlowManager: PlayerSystemが初期化されていません")
		return
	
	if not board_system:
		push_error("GameFlowManager: BoardSystem3Dが初期化されていません")
		return
	
	if not creature_manager:
		push_error("GameFlowManager: CreatureManagerが初期化されていません")
		return
	
	# スペルシステムの初期化
	spell_draw = SpellDraw.new()
	spell_draw.setup(card_system)
	
	spell_magic = SpellMagic.new()
	spell_magic.setup(player_system)
	
	spell_land = SpellLand.new()
	spell_land.setup(board_system, creature_manager, player_system)
```

---

## 実装計画

### Phase 1: ターゲットシステム基盤（優先度：高）
- [ ] `target_type`と`target_filter`のパース処理
- [ ] ターゲット選択UIの拡張（creature/land/player対応）
- [ ] 上下キー選択の統一インターフェース実装

### Phase 2: SpellLand実装（優先度：高）✅
- [x] `scripts/spells/spell_land.gd`作成
- [x] 土地属性変更メソッド
- [x] 土地レベル変更メソッド
- [x] クリーチャー破壊メソッド
- [ ] 20個の土地操作スペル実装（個別スペルカードのJSONとeffect実行）

### Phase 3: SpellEffectSystem実装（優先度：高）
- [ ] `scripts/spell_effect_system.gd`作成
- [ ] 💬管理システム（tile/player/world）
- [ ] ターン経過による💬削除処理
- [ ] 30個の特殊能力付与スペル実装

### Phase 4: SpellDice実装（優先度：中）
- [ ] `scripts/spells/spell_dice.gd`作成
- [ ] ダイス固定値メソッド
- [ ] ダイス範囲指定メソッド
- [ ] 10個のダイス操作スペル実装

### Phase 5: 秘術システム実装（優先度：低 - 全スペル完了後）
- [ ] `mystic_arts`のパース処理（ability_parsed内）
- [ ] [秘術を使う]ボタンUI作成
- [ ] クリーチャー選択UI実装
- [ ] SpellPhaseHandlerの拡張（秘術対応）
- [ ] 秘術実行フロー実装

---

**最終更新**: 2025年11月9日（v2.0）
