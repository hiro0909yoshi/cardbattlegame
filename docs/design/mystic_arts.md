# アルカナアーツシステム完成図書

**ステータス**: ✅ 実装完了（Phase 1-3）+ 3方式対応（既存スペル参照/アルカナアーツ専用スペル/直接effects）  
**最終更新**: 2025年12月16日

---

## 概要

アルカナアーツ（Mystic Arts）は、クリーチャーが持つ特殊な魔法効果。スペルフェーズで発動でき、コストとしてEPを消費する。

### 基本仕様

| 項目 | 内容 |
|------|------|
| 発動者 | 自分のクリーチャーのみ |
| コスト | EP（プレイヤーの共通資源） |
| タイミング | スペルフェーズ内（ターン1回） |
| 排他性 | スペルカード使用時はアルカナアーツは使えない（逆も同様） |
| 発動後 | クリーチャーはダウン状態（不屈で回避可） |

---

## 実装方式

アルカナアーツの効果定義には3つの方式がある。

| 方式 | 用途 | 例 |
|------|------|-----|
| A. 既存スペル参照 | 既存スペルと同じ効果 | アモン（バイタリティ参照） |
| B. アルカナアーツ専用スペル | 既存にない効果（9000番台） | バーナックル（通行料半減） |
| C. 直接effects | シンプルな効果 | フェイト（カードドロー） |

**推奨**: シンプルな効果はC方式、複雑な効果やターゲット設定が必要な場合はB方式を使用。

### データ構造

**方式A：クリーチャーJSON（既存スペル参照の例）**:
```json
{
  "id": 2,
  "name": "アモン",
  "ability_parsed": {
	"keywords": ["感応", "防魔", "アルカナアーツ"],
	"mystic_arts": [
	  {
		"id": "amon_mystic_001",
		"name": "バイタリティ",
		"description": "対象ドミニオに呪い\"能力値+20\"；カードを1枚引く",
		"spell_id": 2066,
		"cost": 50
	  }
	]
  }
}
```

**方式B：クリーチャーJSON（アルカナアーツ専用スペル参照の例）**:
```json
{
  "id": 29,
  "name": "バーナックル",
  "ability_parsed": {
	"keywords": ["防御型", "アルカナアーツ"],
	"mystic_arts": [
	  {
		"id": "barnacle_mystic_001",
		"name": "通行料半減",
		"description": "対象敵ドミニオに通行料半減の呪いをかける（3ターン）",
		"spell_id": 9001,
		"cost": 50
	  }
	]
  }
}
```

**アルカナアーツ専用スペル（data/spell_mystic.json）**:
```json
{
  "cards": [
	{
	  "id": 9001,
	  "name": "通行料半減の呪い",
	  "rarity": "N",
	  "type": "spell",
	  "cost": {
		"mp": 0
	  },
	  "effect_parsed": {
		"target_type": "land",
		"target_info": {
		  "owner_filter": "enemy",
		  "target_filter": "creature"
		},
		"effects": [
		  {
			"effect_type": "curse_toll_half",
			"duration": 3
		  }
		]
	  }
	}
  ]
}
```

**方式C：クリーチャーJSON（直接effects方式の例）**:
```json
{
  "id": 136,
  "name": "フェイト",
  "ability_parsed": {
	"keywords": ["遺産", "アルカナアーツ"],
	"mystic_arts": [
	  {
		"name": "カードドロー",
		"cost": 40,
		"target_type": "self",
		"effects": [{"effect_type": "draw_cards", "count": 1}]
	  }
	]
  }
}
```

**直接effects方式のフィールド**:

| フィールド | 説明 |
|-----------|------|
| `name` | アルカナアーツ名（UI表示用） |
| `cost` | EPコスト |
| `target_type` | ターゲットタイプ（`self`, `player`, `land`等） |
| `target_info` | ターゲット条件（オプション） |
| `effects` | 効果配列（SpellDrawやSpellPhaseHandlerで処理） |

### フィールド説明

| フィールド | 説明 |
|-----------|------|
| `id` | アルカナアーツの一意ID（クリーチャー内でユニーク） |
| `name` | アルカナアーツ名（UI表示用） |
| `description` | 説明テキスト |
| `spell_id` | 参照するスペルのID（9000番台：アルカナアーツ専用、2000番台：既存スペル） |
| `cost` | EPコスト（スペル本来のコストとは独立） |

### アルカナアーツ専用スペルID範囲

**ID 9000-9999: アルカナアーツ専用スペル**
- 通常のスペルカードとしては使用されない
- アルカナアーツからのみ参照される
- `data/spell_mystic.json` に定義
- 例：通行料半減（9001）

**ID 2000-2999: 既存スペル**
- 通常のスペルカードとして使用可能
- アルカナアーツからも参照可能
- 例：バイタリティ（2066）

### 効果適用フロー

```
1. mystic_art["spell_id"] からスペルID取得
2. CardLoader.get_card_by_id(spell_id) でスペルデータ取得
3. spell_card["effect_parsed"] からターゲット情報と効果を取得
4. spell_phase_handler._apply_single_effect() で各効果を適用
```

### target_type 一覧

| target_type | 説明 | 選択UI |
|-------------|------|--------|
| `land` | クリーチャーがいる土地 | 上下キー選択 |
| `player` | プレイヤー | 上下キー選択 or `self` |
| `all_creatures` | 全クリーチャー（条件付き） | なし（自動適用） |

**owner_filter**（土地系）: `own`, `enemy`, `any`  
**target_filter**（土地系）: `creature`（クリーチャー必須）  
**target_filter**（プレイヤー系）: `self`（自分自身のみ）

---

## 実行フロー

```
スペルフェーズ開始
  │
  ├─ [アルカナアーツを使う] 選択
  │   ├─ 発動可能クリーチャーを列挙
  │   ├─ クリーチャー選択UI表示
  │   ├─ アルカナアーツ選択UI表示
  │   ├─ ターゲット選択（セルフターゲット時は自動）
  │   ├─ アルカナアーツ発動・効果適用
  │   ├─ EP消費
  │   ├─ クリーチャーをダウン状態に設定
  │   └─ スペルUIを非表示（排他制御）
  │
  ├─ [スペルカード使用] → アルカナアーツUIを非表示
  └─ [スペルをしない] → スペルフェーズ終了
```

---

## 関連ファイル

```
scripts/spells/spell_mystic_arts.gd      # アルカナアーツ実行エンジン
scripts/spells/spell_draw.gd             # ドロー・手札操作系効果
scripts/spells/card_selection_handler.gd # 敵手札選択UI（destroy_and_draw等）
scripts/game_flow/spell_phase_handler.gd # アルカナアーツ発動フロー、非同期判定
scripts/ui_components/spell_and_mystic_ui.gd  # アルカナアーツ選択UI
scripts/ui_components/card_selection_ui.gd    # カード選択フィルター
scripts/spells/spell_curse_toll.gd       # 通行料呪いシステム（アルカナアーツから使用）
scripts/card_loader.gd                   # スペルデータ読み込み
data/fire_1.json                         # アモン（既存スペル参照例）
data/fire_2.json                         # バーナックル（アルカナアーツ専用スペル参照例）
data/water_2.json                        # フェイト（直接effects方式例）
data/spell_2.json                        # バイタリティ（既存スペル）
data/spell_mystic.json                   # アルカナアーツ専用スペル（9000番台）
```

---

## 主要メソッド

### SpellMysticArts

| メソッド | 説明 |
|---------|------|
| `get_available_creatures(player_id)` | アルカナアーツ発動可能なクリーチャー一覧を取得 |
| `get_mystic_arts_for_creature(creature_data)` | クリーチャーのアルカナアーツ一覧を取得 |
| `can_cast_mystic_art(mystic_art, context)` | 発動可否判定（EP・ダウン状態・ターゲット有無） |
| `apply_mystic_art_effect(mystic_art, target_data, context)` | アルカナアーツ効果を適用（spell_id参照/直接effects両対応） |
| `execute_mystic_art(creature, mystic_art, target_data)` | アルカナアーツ実行（非同期対応） |
| `_is_async_mystic_art(mystic_art)` | 非同期効果を含むアルカナアーツかどうかを判定 |
| `_set_caster_down_state(tile_index, board_system)` | 発動後のダウン状態設定 |

---

## ダウン状態と不屈

アルカナアーツ発動後、クリーチャーはダウン状態になる（ドミニオオーダーと同様）。

- ダウン状態のクリーチャーは次ターンまでアルカナアーツ使用不可
- ダウン状態はスタート通過時に全土地で一括解除
- **不屈スキル**を持つクリーチャーはダウン状態にならない

---

## UI仕様

### ボタン配置

```
画面レイアウト

  [アルカナアーツを使う]                    [スペルをしない]
  ← 手札左側                      手札右側 →

		  ┌─ 手札コンテナ ─┐
		  │ [🃏][🃏][🃏]... │
		  └────────────────┘
```

- CardUIHelper.calculate_card_layout() で位置計算
- 全画面解像度対応（1280×720〜2560×1440）

### スタイル

| ボタン | 色（Normal） | 用途 |
|--------|-------------|------|
| アルカナアーツを使う | 紫 (#663399) | アルカナアーツ選択 |
| スペルをしない | グレー (#808080) | スキップ |

---

## 動作確認済み効果

| effect_type | 説明 | 確認状況 |
|-------------|------|---------|
| `stat_boost` | 能力値増加 | ✅ バイタリティで確認 |
| `draw` | カードドロー | ✅ バイタリティで確認 |
| `draw_cards` | カードドロー（枚数指定） | ✅ フェイトで確認 |
| `draw_by_type` | タイプ指定ドロー | ✅ アイアンモンガーで確認 |
| `add_specific_card` | 特定カード生成 | ✅ ハイプクイーンで確認 |
| `destroy_and_draw` | 敵手札破壊→自分ドロー | ✅ クラウドギズモで確認 |
| `swap_creature` | クリーチャー交換 | ✅ レムレースで確認 |
| `damage` | ダメージ適用 | ✅ 実装済み |
| `curse_toll_half` | 通行料半減 | ✅ バーナックルで確認 |
| `toll_multiplier` | 通行料倍率 | ✅ 統合処理で対応 |
| `toll_share`, `toll_disable`, `toll_fixed`, `peace` | その他通行料呪い | ✅ 統合処理で対応 |

---

## パラメータカスタマイズ方式（確定）

アルカナアーツ専用の効果やパラメータが必要な場合は **9000番台のIDでアルカナアーツ専用スペルを作成** する方式を採用。

### 実装方法

**1. data/spell_mystic.json にスペル定義を追加**:
```json
{
  "cards": [
	{
	  "id": 9001,
	  "name": "通行料半減の呪い",
	  "effect_parsed": {
		"target_type": "land",
		"target_info": {
		  "owner_filter": "enemy",
		  "target_filter": "creature"
		},
		"effects": [
		  {
			"effect_type": "curse_toll_half",
			"duration": 3
		  }
		]
	  }
	}
  ]
}
```

**2. クリーチャーデータから参照**:
```json
"mystic_arts": [{
  "id": "barnacle_mystic_001",
  "name": "通行料半減",
  "spell_id": 9001,
  "cost": 50
}]
```

### メリット

- 既存スペルと同じ構造で管理可能
- ターゲット設定やパラメータを自由にカスタマイズ
- 効果の再利用が容易
- CardLoaderで統一的に読み込み

---

## アルカナアーツを追加する手順

### パターンA：既存スペルを使用する場合

1. **スペル定義確認**: 使用したいスペルが`data/spell_*.json`に存在するか確認
2. **クリーチャーJSONに追加**:
   ```json
   "ability_parsed": {
	 "keywords": ["アルカナアーツ"],
	 "mystic_arts": [{
	   "id": "unique_id",
	   "name": "アルカナアーツ名",
	   "description": "説明",
	   "spell_id": 既存スペルID,
	   "cost": コスト
	 }]
   }
   ```
3. **動作確認**: ゲーム内でアルカナアーツが発動できることを確認

### パターンB：アルカナアーツ専用スペルを作成する場合

1. **data/spell_mystic.jsonに定義追加**:
   ```json
   {
	 "id": 9001,
	 "name": "アルカナアーツ専用スペル名",
	 "type": "spell",
	 "effect_parsed": {
	   "target_type": "land",
	   "target_info": {
		 "owner_filter": "enemy",
		 "target_filter": "creature"
	   },
	   "effects": [{
		 "effect_type": "curse_toll_half",
		 "duration": 3
	   }]
	 }
   }
   ```

2. **クリーチャーJSONに追加**:
   ```json
   "ability_parsed": {
	 "keywords": ["アルカナアーツ"],
	 "mystic_arts": [{
	   "id": "unique_id",
	   "name": "アルカナアーツ名",
	   "description": "説明",
	   "spell_id": 9001,
	   "cost": コスト
	 }]
   }
   ```

3. **動作確認**: ゲーム内でアルカナアーツが発動できることを確認

### パターンC：直接effects方式（推奨）

シンプルな効果で、spell_mystic.jsonへの追加が不要な場合に使用。

1. **クリーチャーJSONに追加**:
   ```json
   "ability_parsed": {
	 "keywords": ["アルカナアーツ"],
	 "mystic_arts": [{
	   "name": "アルカナアーツ名",
	   "cost": コスト,
	   "target_type": "self",
	   "effects": [{"effect_type": "draw_cards", "count": 1}]
	 }]
   }
   ```

2. **動作確認**: ゲーム内でアルカナアーツが発動できることを確認

**使用可能なeffect_type**（SpellDraw対応）:
- `draw_cards`: カードドロー（count指定）
- `draw_by_type`: タイプ指定ドロー（card_type: "item"等）
- `add_specific_card`: 特定カード生成（card_id指定）
- `destroy_and_draw`: 敵手札破壊→自分ドロー（target_type: "player"）
- `swap_creature`: クリーチャー交換（target_type: "player"）

**非同期効果の注意**: `destroy_and_draw`, `swap_creature`等の非同期効果は`_is_async_mystic_art()`で自動判定され、カード選択完了後にスペルフェーズが終了する。

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2025/11/24 | 初版作成、基盤実装 |
| 2025/11/25 | spell_id参照方式実装完了、バイタリティ動作確認、アルカナアーツ専用スペル9000番台方式確定、バーナックル（通行料半減）実装完了 |
| 2025/11/27 | 直接effects方式（パターンC）追加、フェイト・アイアンモンガー・ハイプクイーン・クラウドギズモ・レムレース実装完了、非同期アルカナアーツ対応（_is_async_mystic_art）、creatureフィルター対応 |
| 2025/12/16 | ドキュメント整理 - 主要メソッドの実装場所を修正（SpellPhaseHandler→SpellMysticArts） |
