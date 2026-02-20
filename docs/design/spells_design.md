# 🎮 スペルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム
**バージョン**: 3.0
**最終更新**: 2026-02-20

---

## 📋 目次

1. [スペルシステム概要](#スペルシステム概要)
2. [実装済みスペル効果一覧](#実装済みスペル効果一覧)
3. [スペルの特殊システム](#スペルの特殊システム)
4. [実装計画](#実装計画)
5. [変更履歴](#変更履歴)

---

## スペルシステム概要

### 基本設計

バトル外・マップ全体に影響する効果を管理するシステム。

**特徴**:
- `battle/`（バトル中の効果）と`spells/`（バトル外の効果）で明確に分離
- 各効果は独立したクラスとして実装
- スペルカード、アルカナアーツ、アイテム効果など様々な場面で再利用可能

### アーキテクチャ

```
GameFlowManager
  └─ spell_container: SpellSystemContainer (RefCounted, Phase 1)
      ├─ spell_draw: SpellDraw          # カードドロー ✅
      ├─ spell_magic: SpellMagic        # EP増減 ✅
      ├─ spell_land: SpellLand          # 土地操作 ✅
      ├─ spell_dice: SpellDice          # ダイス操作 ✅
      ├─ spell_curse: SpellCurse        # 呪い管理 ✅
      ├─ spell_curse_stat: SpellCurseStat (Node)  # ステータス呪い ✅
      ├─ spell_world_curse: SpellWorldCurse (Node) # 世界呪い ✅
      ├─ spell_player_move: SpellPlayerMove  # プレイヤー移動 ✅
      ├─ spell_curse_toll: SpellCurseToll    # 通行料呪い ✅
      └─ spell_cost_modifier: SpellCostModifier  # コスト修正 ✅

SpellPhaseHandler
  ├─ spell_ui_manager: SpellUIManager (Phase 5-1, UI統合)
  ├─ cpu_spell_phase_handler: CPUSpellPhaseHandler (CPU AI)
  ├─ spell_flow: SpellFlowHandler
  ├─ spell_state: SpellStateHandler
  ├─ mystic_arts_handler: MysticArtsHandler
  └─ spell_effect_executor: SpellEffectExecutor
```

### 初期化の依存関係

| スペルシステム | 必要な参照 | 実装状況 |
|---------------|-----------|---------|
| SpellDraw | CardSystem | ✅ |
| SpellMagic | PlayerSystem | ✅ |
| SpellLand | BoardSystem3D, CreatureManager, PlayerSystem | ✅ |
| SpellDice | PlayerSystem, SpellCurse | ✅ |
| SpellCurse | BoardSystem3D, CreatureManager, PlayerSystem, GameFlowManager | ✅ |
| SpellCurseStat | SpellCurse, CreatureManager | ✅ |
| SpellWorldCurse | SpellCurse, GameFlowManager | ✅ |
| SpellPlayerMove | BoardSystem3D, PlayerSystem, GameFlowManager, SpellCurse | ✅ |
| SpellCurseToll | SpellCurse, skill_toll_change, CreatureManager | ✅ |
| SpellCostModifier | SpellCurse, PlayerSystem, GameFlowManager | ✅ |

**初期化順序**:
1. 基本システム（PlayerSystem, CardSystem, BoardSystem3D）を先に初期化
2. その後、スペルシステムを初期化し、参照を渡す

### フォルダ構成

```
scripts/spells/              # スペル効果モジュール
  ├── spell_system_container.gd  # コンテナ（Phase 1） ✅
  ├── spell_draw.gd         # ドロー処理 ✅
  ├── spell_magic.gd        # EP増減 ✅
  ├── spell_land_new.gd     # 土地操作 ✅
  ├── spell_dice.gd         # ダイス操作 ✅
  ├── spell_curse.gd        # 呪い管理 ✅
  ├── spell_curse_stat.gd        # ステータス呪い ✅
  ├── spell_world_curse.gd       # 世界呪い ✅
  ├── spell_player_move.gd       # プレイヤー移動 ✅
  ├── spell_curse_toll.gd        # 通行料呪い ✅
  └── spell_cost_modifier.gd     # コスト修正 ✅

docs/design/spells/          # 個別スペル効果のドキュメント
  ├── カードドロー.md       # ドロー処理の詳細 ✅
  ├── EP増減.md          # EP増減の詳細 ✅
  ├── ドミニオ変更.md          # 土地操作の詳細 ✅
  ├── ダイス操作.md        # ダイス操作の詳細 ✅
  ├── ステータス増減.md    # ステータス増減の詳細 ✅
  └── 呪い効果.md          # 呪いシステム全体の詳細 ✅
```

---

## 実装済みスペル効果一覧

### 🔹 完全実装済み

| 効果名 | モジュールファイル | 対応スペル数 | 詳細ドキュメント |
|-------|-----------------|------------|----------------|
| **カードドロー** | [spell_draw.gd](../../scripts/spells/spell_draw.gd) | 15個 | [カードドロー.md](./spells/カードドロー.md) |
| **EP増減** | [spell_magic.gd](../../scripts/spells/spell_magic.gd) | 20個 | [EP増減.md](./spells/EP増減.md) |
| **土地操作** | [spell_land_new.gd](../../scripts/spells/spell_land_new.gd) | 11個 | [ドミニオ変更.md](./spells/ドミニオ変更.md) |
| **ダイス操作** | [spell_dice.gd](../../scripts/spells/spell_dice.gd) | 7個 | [ダイス操作.md](./spells/ダイス操作.md) |
| **密命カード** | [Card.gd](../../scripts/card.gd) + [HandDisplay.gd](../../scripts/ui_components/hand_display.gd) | 1個 | [密命カード.md](../skills/密命カード.md) |

### 🔹 完全実装済み（続き）

| 効果名 | モジュールファイル | 対応スペル数 | 詳細ドキュメント |
|-------|-----------------|------------|----------------|
| **ステータス増減** | [spell_curse_stat.gd](../../scripts/spells/spell_curse_stat.gd) | 2個 | [ステータス増減.md](./spells/ステータス増減.md) |
| **世界呪い** | [spell_world_curse.gd](../../scripts/spells/spell_world_curse.gd) | 5個 | [呪い効果.md](./spells/呪い効果.md) |
| **プレイヤー移動** | [spell_player_move.gd](../../scripts/spells/spell_player_move.gd) | 3個 | [呪い効果.md](./spells/呪い効果.md) |
| **通行料呪い** | [spell_curse_toll.gd](../../scripts/spells/spell_curse_toll.gd) | 4個 | [呪い効果.md](./spells/呪い効果.md) |
| **コスト修正** | [spell_cost_modifier.gd](../../scripts/spells/spell_cost_modifier.gd) | 3個 | [呪い効果.md](./spells/呪い効果.md) |

---

## スペルの特殊システム

### 密命（Secret）システム ✅

**概要**: 相手プレイヤーから見たときにカード内容が見えない（真っ黒表示）スペル。効果自体は通常スペルと同じ。

**実装場所**: `scripts/card.gd`（表示制御のみ）

**重要**: 密命は単なる表示制御であり、効果の成功/失敗とは無関係。

**アーキテクチャ**:
```
Card.gd (scripts/)
  └─ _update_secret_display() - 表示制御
	  ├─ is_secret フラグで判定
	  ├─ viewing_player_id と owner_player_id を比較
	  └─ 敵プレイヤーには真っ黒表示
```

#### 🎴 密命カード表示（is_secret）

**JSONでの定義**:
```json
{
  "id": 2029,
  "is_secret": true,
  "effect_parsed": {
	"target_type": "land",
	"effects": [...]
  }
}
```

**表示ルール**:
- 所有プレイヤー: 通常表示（内容が見える）
- 敵プレイヤー: **真っ黒で見えない**

**実装**:
- `Card.gd`: `_update_secret_display()`で表示制御
- `ColorRect`で真っ黒表示を実現
- `viewing_player_id`と`owner_player_id`を比較して判定

#### 🔄 復帰[ブック]効果

一部のスペルは条件を満たさない場合、カードがデッキに戻る「復帰[ブック]」効果を持つ。**これは密命とは無関係**。

**対象スペル**:

| ID | 名前 | 条件 | 効果 | 条件不成立時 |
|----|------|------|------|-------------|
| 2085 | フラットランド | Lv2ドミニオが5つ以上 | 全てレベル+1 | 復帰[ブック] |
| 2096 | ホームグラウンド | 属性不一致の土地が4つ以上 | 4つを属性変更 | 復帰[ブック] |
| 2085 | フラットランド | Lv2ドミニオが5つ以上 | 全てレベル+1 | 復帰[ブック] |
| 2096 | ホームグラウンド | 属性不一致の土地が4つ以上 | 4つを属性変更 | 復帰[ブック] |

**実装**: `SpellLand.return_spell_to_deck(player_id, spell_card)`
- 手札から削除 → デッキのランダムな位置に挿入
- `item_return`スキルと同じ方式

**JSON定義**:
```json
{
  "effect_type": "conditional_level_change",
  "return_to_deck_on_fail": true,
  "required_count": 5
}
```

---

### 呪い（継続効果）システム ⏳

**概要**: 複数ターンにわたってプレイヤー/クリーチャー/土地/世界全体にかかる効果。

**呪いの種類**:

| 対象 | 消滅条件 | 例 |
|------|---------|-----|
| クリーチャー | 移動・交換・撃破・ターン経過・上書き | 不屈(5R)、戦闘行動不可 |
| プレイヤー | ターン経過・上書き | 防魔(5R)、通行料無効 |
| 世界呪 | 上書き・消滅スペル | コスト上昇(6R) |

**重要**: クリーチャーの呪いは**移動でも消える**

**上書きルール**: 同じ効果が再度かかった場合、新しい効果で上書き（前の効果は消滅）

**実装方式**: `ability_parsed`に直接追加し、既存のSkillSystemを活用

**実装ファイル**: 各スペルシステム（spell_curse.gd, spell_curse_stat.gd, spell_world_curse.gd 等）で分散実装済み ✅

---

### ターゲットシステム ✅

**ターゲットタイプ（6種類）**:

| タイプ | 説明 | 選択対象 | UI |
|-------|------|---------|-----|
| `creature` | クリーチャー | 自分/敵のクリーチャー | 上下キー選択 |
| `land` | 土地 | 自分/敵/空地の土地 | 上下キー選択 |
| `player` | プレイヤー | 自分/敵のプレイヤー | 上下キー選択 |
| `all_creatures` | 全クリーチャー | 条件に合致する全て | なし（自動適用） |
| `world` | 世界呪 | ターゲット選択なし（全体効果） | なし |
| セルフ（`target_filter: "self"`） | 使用者自身 | ターゲット選択なし（自動的に使用者） | なし |

**選択UI**: ドミニオオーダーと同じ**GlobalActionButtons統合方式**を採用

**ボタン操作**:
- ▲/▼ボタン: 対象切り替え（前/次）
- ✓ボタン: 決定
- ✕ボタン: キャンセル

**実装**: `SpellPhaseHandler._setup_target_selection_navigation()`で`ui_manager.enable_navigation()`を呼び出し

**フィルター**:
- `own`: 自分のみ
- `enemy`: 敵のみ
- `any`: 全て
- `self`: 使用者自身（ターゲット選択UI なし、自動的に効果発動）

**レベルフィルター**:
- `required_level`: 特定レベルのみ（例: `required_level: 4`）
- `max_level`, `min_level`: レベル範囲指定

**全クリーチャーターゲット（`all_creatures`）**:
- 条件に合致する全クリーチャーに自動適用
- `TargetSelectionHelper.get_all_creatures(board_system, condition)` で取得
- 各spellモジュール（SpellCurseBattle等）で効果適用

```gdscript
# 全クリーチャー取得（汎用）
var targets = TargetSelectionHelper.get_all_creatures(board_system, {
	"condition_type": "mhp_check",
	"operator": "<=",
	"value": 30
})
# targets = [{tile_index: int, creature: Dictionary}, ...]
```

**セルフターゲット実装例**（ドリームトレイン）:
```json
{
  "effect_parsed": {
	"target_type": "player",
	"target_filter": "self",
	"effects": [
	  {
		"effect_type": "toll_share",
		"name": "通行料促進",
		"ratio": 0.5,
		"duration": 5
	  }
	]
  }
}
```

**実装**: `SpellPhaseHandler`で`target_filter == "self"`をチェック → UI表示なし → `target_data = {"type": "player", "player_id": current_player_id}`で自動設定 → 即座に効果発動

**全体ターゲット実装例**（ディラニー）:
```json
{
  "effect_parsed": {
	"target_type": "all_creatures",
	"target_info": {
	  "condition": {
		"condition_type": "mhp_check",
		"operator": "<=",
		"value": 30
	  }
	},
	"effects": [
	  {
		"effect_type": "battle_disable",
		"name": "戦闘行動不可",
		"duration": -1
	  }
	]
  }
}
```

**実装**: `SpellPhaseHandler._execute_spell_on_all_creatures()` で処理 → UI表示なし → 全タイルを走査 → 条件に合致するクリーチャーに効果適用

**condition_type一覧**:
| condition_type | 説明 | パラメータ |
|----------------|------|-----------|
| `mhp_check` | 最大HP判定 | `operator`, `value` |

---

### アルカナアーツシステム ⏳

**概要**: クリーチャーが持つスペル的効果。スペルフェーズで使用可能。

**特徴**:
- 発動者：自分のクリーチャー
- コスト：EP
- タイミング：スペルフェーズで1ターン1回
- 制約：**スペルカードと排他的**（同じターンに両方使えない）

**データ構造**:
```json
{
  "ability_parsed": {
	"mystic_arts": [
	  {
		"name": "デッキ破壊",
		"description": "対象ブックの上1枚を破壊",
		"cost": 50,
		"target_type": "player",
		"target_filter": "enemy",
		"effects": [...]
	  }
	]
  }
}
```

**実装時期**: 全スペル実装完了後（現時点では設計のみ）

---

## 実装計画

### Phase 1: ターゲットシステム基盤 ✅
- [x] `target_type`と`target_filter`のパース処理
- [x] ターゲット選択UIの拡張（creature/land/player対応）
- [x] ドミニオオーダーと統一された選択インターフェース
- [x] `required_level`フィルター実装

### Phase 2: SpellLand実装 ✅
- [x] `scripts/spells/spell_land_new.gd`作成
- [x] 基本メソッド10個実装
- [x] GameFlowManager・SpellPhaseHandler統合
- [x] 土地操作スペル11個の基盤実装完了

### Phase 3: 密命カードシステム実装 ✅
- [x] `is_secret`フラグによる表示制御
- [x] `ColorRect`による真っ黒表示
- [x] `viewing_player_id`常に0の実装
- [x] ID 2029「サドンインパクト」実装完了

### Phase 4: SpellEffectSystem実装 ⏳
- [x] `scripts/spell_curse.gd`作成
- [x] 呪い管理システム（tile/player/world）
- [x] ターン経過による呪い削除処理
- [ ] 30個の特殊能力付与スペル実装

### Phase 5: SpellDice実装 ⏳
- [x] `scripts/spells/spell_dice.gd`作成
- [x] ダイス固定値メソッド
- [x] ダイス範囲指定メソッド
- [x] 10個のダイス操作スペル実装

### Phase 6: アルカナアーツシステム実装 ⏳
- [x] `mystic_arts`のパース処理
- [x] [アルカナアーツを使う]ボタンUI作成
- [x] SpellPhaseHandlerの拡張
- [x] アルカナアーツ実行フロー実装

---

## 🔧 開発者向け：拡張時の更新ルール

スペルシステムに新しい機能を追加する際は、以下のチェックリストに従って関連箇所を必ず更新してください。

### 新しい effect_type を追加する場合

#### ✅ 必須更新箇所（優先度：高）

1. **`scripts/game_flow/spell_phase_handler.gd`**
   - `_apply_single_effect()` の `match effect_type:` に新しいケースを追加
   - 対応する処理を実装（または適切なSpellXxxクラスのメソッドを呼び出し）

2. **`docs/design/spells_design.md`** ← このドキュメント
   - 「実装済みスペル効果一覧」セクションに追加
   - 対応するスペルカードのリストを更新

3. **`scripts/spells/spell_effect_base.gd`**
   - `EffectType` enum に新しい効果タイプを追加（参考・補完用）

#### 📝 該当する場合のみ更新

- **土地操作系** → `scripts/spells/spell_land_new.gd` に新メソッド追加 + `docs/design/spells/ドミニオ変更.md` 更新
- **ドロー系** → `scripts/spells/spell_draw.gd` に新メソッド追加 + `docs/design/spells/カードドロー.md` 更新
- **EP系** → `scripts/spells/spell_magic.gd` に新メソッド追加 + `docs/design/spells/EP増減.md` 更新
- **新カテゴリ** → 新しい `SpellXxx.gd` クラスを作成 + 専用ドキュメント作成

---

### 新しい target_type を追加する場合

#### ✅ 必須更新箇所（優先度：高）

1. **`scripts/game_flow/spell_phase_handler.gd`**
   - `_get_valid_targets()` に新しいターゲットタイプの取得ロジックを追加
   - 必要に応じて `_show_target_selection_ui()` を拡張

2. **`docs/design/spells_design.md`** ← このドキュメント
   - 「ターゲットシステム」セクションのターゲットタイプ表を更新

3. **`scripts/spells/spell_effect_base.gd`**
   - `TargetType` enum に新しいターゲットタイプを追加（参考・補完用）

#### 📝 UI関連の更新が必要な場合

- **選択UI** → `scripts/ui_components/target_selection_helper.gd` の拡張が必要な場合あり
- **フィルタリング** → 新しい `owner_filter` や `tile_filter` を追加する場合、条件判定ロジックも更新

---

### 新しい条件タイプ（condition_type）を追加する場合

#### ✅ 必須更新箇所（優先度：高）

1. **`scripts/skills/condition_checker.gd`**
   - `_evaluate_single_condition()` の `match cond_type:` に新しいケースを追加
   - 条件判定ロジックを実装
   - **注**: このクラスはバトルスキルとスペルの**両方**で共用されます

2. **`docs/design/spell_condition_patterns_catalog.txt`** ← スペル用条件パターンカタログ
   - 新しい条件パターンを追加（S-X形式で番号付け）
   - 使用例とコードスニペットを記載
   - **フォーマット**:
	 ```
	 S-X. 条件名
	 gdscript
	 条件判定コード例
	 使用: 使用メソッド名
	 対象スペル: スペル名 (ID)
	 ```

3. **`docs/design/spells_design.md`** ← このドキュメント
   - 該当する特殊システム（密命、呪い等）のセクションに条件を追記
   - 利用可能な条件タイプ表を更新

4. **`scripts/skills/skill_effect_base.gd`**
   - `ConditionType` enum に新しい条件タイプを追加（参考・補完用）
   - **注**: スペル専用条件でもここに追加（バトルとスペルで共通のenum定義）

#### 📝 バトルスキルでも使用する条件の場合

- **`docs/design/condition_patterns_catalog.md`** にもパターンを追記（B-X形式）
- バトル・スペル両方で使える汎用的な条件として文書化

#### 🔍 条件パターンカタログ更新例

**spell_condition_patterns_catalog.txt**:
```
S-6. 手札枚数条件チェック
gdscript
var hand_count = context.get("hand_cards", []).size()
if hand_count >= required_count:
使用: check_hand_count_condition()
対象スペル: シンクタンク (2XXX)
```

---

### 新しいスペルカードを追加する場合

#### ✅ 必須更新箇所

1. **`data/spell_X.json`**
   - カードデータを追加
   - `effect_parsed` を正しく定義（既存の effect_type を使用）

2. **該当する詳細ドキュメント**
   - 土地操作 → `docs/design/spells/ドミニオ変更.md` の「対応スペル一覧」
   - ドロー → `docs/design/spells/カードドロー.md` の対応表
   - EP → `docs/design/spells/EP増減.md` の対応表

3. **密命カードの場合**
   - `docs/design/skills/密命カード.md` の「密命スペル一覧」に追加

---

### チェックリスト例：「change_element_area（範囲属性変更）」を追加する場合

- [ ] `spell_phase_handler.gd` - `_apply_single_effect()` に `"change_element_area":` 追加
- [ ] `spell_land_new.gd` - `change_element_area(center_tile, radius, element)` メソッド実装
- [ ] `spells_design.md` - 実装済みスペル効果一覧に追加
- [ ] `ドミニオ変更.md` - メソッド詳細とJSON例を追記
- [ ] `spell_effect_base.gd` - `EffectType.CHANGE_ELEMENT_AREA` を追加
- [ ] `spell_X.json` - 実際のスペルカード（例：エリアルシフト）を定義

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/11/03 | 1.0 | 初版作成 |
| 2025/11/09 | 2.0 | SpellLand実装完了、ターゲットシステム統合 |
| 2025/11/10 | 2.1 | ドキュメント構造リファクタリング |
| 2025/11/11 | 2.2 | 密命カードシステム実装完了 |
| 2025/11/11 | 2.3 | SpellPhaseHandlerリファクタリング |
| 2025/11/11 | 2.4 | 復帰[ブック]の使い方を追記 |
| 2025/11/11 | 2.5 | 開発者向け拡張ルール追加 |
| 2025/11/12 | 2.7 | 密命システム修正完了 |
| 2025/12/16 | 3.0 | ドキュメント修復、ボタン関連記述更新（GlobalActionButtons統合） |
| 2026/02/20 | 3.1 | アーキテクチャ更新（Phase E 完了）：SpellSystemContainer統合、全10スペルシステム実装完了 |

---

**最終更新**: 2026-02-20（v3.1）
