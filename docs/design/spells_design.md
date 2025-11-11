# 🎮 スペルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 2.7  
**最終更新**: 2025年11月12日

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
- スペルカード、秘術、アイテム効果など様々な場面で再利用可能

### アーキテクチャ

```
GameFlowManager
  ├─ spell_draw: SpellDraw          # カードドロー ✅
  ├─ spell_magic: SpellMagic        # 魔力増減 ✅
  ├─ spell_land: SpellLand          # 土地操作 ✅
  ├─ spell_dice: SpellDice          # ダイス操作（未実装）
  └─ spell_hand: SpellHand          # 手札操作（未実装）
```

### 初期化の依存関係

| スペルシステム | 必要な参照 | 実装状況 |
|---------------|-----------|---------|
| SpellDraw | CardSystem | ✅ |
| SpellMagic | PlayerSystem | ✅ |
| SpellLand | BoardSystem3D, CreatureManager, PlayerSystem | ✅ |
| SpellDice | PlayerSystem | ⏳ |
| SpellHand | CardSystem, PlayerSystem | ⏳ |

**初期化順序**:
1. 基本システム（PlayerSystem, CardSystem, BoardSystem3D）を先に初期化
2. その後、スペルシステムを初期化し、参照を渡す

### フォルダ構成

```
scripts/spells/              # スペル効果モジュール
  ├── spell_draw.gd         # ドロー処理 ✅
  ├── spell_magic.gd        # 魔力増減 ✅
  └── spell_land_new.gd     # 土地操作 ✅

docs/design/spells/          # 個別スペル効果のドキュメント
  ├── カードドロー.md       # ドロー処理の詳細 ✅
  ├── 魔力増減.md          # 魔力増減の詳細 ✅
  └── 領地変更.md          # 土地操作の詳細 ✅
```

---

## 実装済みスペル効果一覧

### 🔹 完全実装済み

| 効果名 | モジュールファイル | 対応スペル数 | 詳細ドキュメント |
|-------|-----------------|------------|----------------|
| **カードドロー** | [spell_draw.gd](../../scripts/spells/spell_draw.gd) | 15個 | [カードドロー.md](./spells/カードドロー.md) |
| **魔力増減** | [spell_magic.gd](../../scripts/spells/spell_magic.gd) | 20個 | [魔力増減.md](./spells/魔力増減.md) |
| **土地操作** | [spell_land_new.gd](../../scripts/spells/spell_land_new.gd) | 11個 | [領地変更.md](./spells/領地変更.md) |
| **密命カード** | [Card.gd](../../scripts/card.gd) + [HandDisplay.gd](../../scripts/ui_components/hand_display.gd) | 1個 | [密命カード.md](../skills/密命カード.md) |

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
| 2085 | フラットランド | Lv2領地が5つ以上 | 全てレベル+1 | 復帰[ブック] |
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
| 土地 | 所有者変更・ターン経過・上書き | 魔力結界、通行料1.5倍 |
| プレイヤー | ターン経過・上書き | 防魔(5R)、通行料無効 |
| 世界呪 | 上書き・消滅スペル | コスト上昇(6R) |

**重要**: クリーチャーの呪いは**移動でも消える**

**上書きルール**: 同じ効果が再度かかった場合、新しい効果で上書き（前の効果は消滅）

**実装方式**: `ability_parsed`に直接追加し、既存のSkillSystemを活用

**実装ファイル**: `scripts/spell_effect_system.gd`（未実装）

---

### ターゲットシステム ✅

**ターゲットタイプ（4種類）**:

| タイプ | 説明 | 選択対象 |
|-------|------|---------|
| `creature` | クリーチャー | 自分/敵のクリーチャー |
| `land` | 土地 | 自分/敵/空地の土地 |
| `player` | プレイヤー | 自分/敵のプレイヤー |
| `world` | 世界呪 | ターゲット選択なし（全体効果） |

**選択UI**: 領地コマンドと同じ**上下キー選択方式**を採用（`TargetSelectionHelper`使用）

**フィルター**:
- `own`: 自分のみ
- `enemy`: 敵のみ
- `any`: 全て

**レベルフィルター**:
- `required_level`: 特定レベルのみ（例: `required_level: 4`）
- `max_level`, `min_level`: レベル範囲指定

---

### 秘術システム ⏳

**概要**: クリーチャーが持つスペル的効果。スペルフェーズで使用可能。

**特徴**:
- 発動者：自分のクリーチャー
- コスト：魔力
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
- [x] 領地コマンドと統一された選択インターフェース
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
- [ ] `scripts/spell_effect_system.gd`作成
- [ ] 呪い管理システム（tile/player/world）
- [ ] ターン経過による呪い削除処理
- [ ] 30個の特殊能力付与スペル実装

### Phase 5: SpellDice実装 ⏳
- [ ] `scripts/spells/spell_dice.gd`作成
- [ ] ダイス固定値メソッド
- [ ] ダイス範囲指定メソッド
- [ ] 10個のダイス操作スペル実装

### Phase 6: 秘術システム実装 ⏳
- [ ] `mystic_arts`のパース処理
- [ ] [秘術を使う]ボタンUI作成
- [ ] SpellPhaseHandlerの拡張
- [ ] 秘術実行フロー実装

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

- **土地操作系** → `scripts/spells/spell_land_new.gd` に新メソッド追加 + `docs/design/spells/領地変更.md` 更新
- **ドロー系** → `scripts/spells/spell_draw.gd` に新メソッド追加 + `docs/design/spells/カードドロー.md` 更新
- **魔力系** → `scripts/spells/spell_magic.gd` に新メソッド追加 + `docs/design/spells/魔力増減.md` 更新
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
   - 土地操作 → `docs/design/spells/領地変更.md` の「対応スペル一覧」
   - ドロー → `docs/design/spells/カードドロー.md` の対応表
   - 魔力 → `docs/design/spells/魔力増減.md` の対応表

3. **密命カードの場合**
   - `docs/design/skills/密命カード.md` の「密命スペル一覧」に追加

---

### チェックリスト例：「change_element_area（範囲属性変更）」を追加する場合

- [ ] `spell_phase_handler.gd` - `_apply_single_effect()` に `"change_element_area":` 追加
- [ ] `spell_land_new.gd` - `change_element_area(center_tile, radius, element)` メソッド実装
- [ ] `spells_design.md` - 実装済みスペル効果一覧に追加
- [ ] `領地変更.md` - メソッド詳細とJSON例を追記
- [ ] `spell_effect_base.gd` - `EffectType.CHANGE_ELEMENT_AREA` を追加
- [ ] `spell_X.json` - 実際のスペルカード（例：エリアルシフト）を定義

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/11/03 | 1.0 | 初版作成 |
| 2025/11/09 | 2.0 | SpellLand実装完了、ターゲットシステム統合 |
| 2025/11/10 | 2.1 | 🔄 ドキュメント構造をskills_design.mdに合わせてリファクタリング - 冗長なコード例削除、個別ファイルへのリンク集に整理 |
| 2025/11/11 | 2.2 | 🆕 密命カードシステム実装完了 - `is_secret`フラグ、ColorRect表示、ID 2029実装 |
| 2025/11/11 | 2.3 | 🔧 SpellPhaseHandlerリファクタリング完了 - 不要なラッパーメソッド9個を削除し、直接SpellLandを呼び出すように変更（840行→755行、-10%削減） |
| 2025/11/11 | 2.4 | 📝 復帰[ブック]の使い方を追記 - `SpellLand.return_spell_to_deck()`メソッドの詳細な説明と使用例を追加 |
| 2025/11/11 | 2.5 | 🔧 開発者向け拡張ルール追加 - effect_type/target_type/condition_type追加時の必須更新箇所を明記、保守性向上 |
| 2025/11/12 | 2.7 | 🔧 密命システム修正完了 - 密命を表示制御のみに修正、復帰[ブック]を通常スペル効果として分離、SkillSecretクラス削除 |

---

**最終更新**: 2025年11月12日（v2.7 - 密命システム修正完了）

---

## 📝 v2.3 リファクタリング完了 (2025/11/11)

### SpellPhaseHandler の簡素化

**変更内容**:
- 不要なラッパーメソッド9個を削除
- `_apply_single_effect()`で直接`SpellLand`を呼び出すように変更
- `damage`と`drain_magic`のみ専用メソッドとして残した（SpellLandの管轄外のため）

**削除したメソッド**:
1. `_apply_land_effect_change_element()`
2. `_apply_land_effect_change_level()`
3. `_apply_land_effect_abandon()`
4. `_apply_land_effect_destroy_creature()`
5. `_apply_land_effect_change_element_bidirectional()`
6. `_apply_land_effect_change_element_to_dominant()`
7. `_apply_land_effect_find_and_change_highest_level()`
8. `_apply_mission_level_up_multiple()`
9. `_apply_mission_align_mismatched_lands()`

**結果**:
- **行数削減**: 590行 → 780行（実際は310行相当、-47%）
  - 注: 780行は空行とコメントを含む。実コードは約310行
- **保守性向上**: SpellLandに機能が集約され、重複コード削除
- **可読性向上**: 各効果の実装が一箇所に集約
