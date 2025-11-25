# 秘術システム完成図書

**ステータス**: ✅ 実装完了（Phase 1-3）+ 秘術専用スペル方式確定  
**最終更新**: 2025年11月25日（9000番台方式採用）

---

## 概要

秘術（Mystic Arts）は、クリーチャーが持つ特殊な魔法効果。スペルフェーズで発動でき、コストとして魔力を消費する。

### 基本仕様

| 項目 | 内容 |
|------|------|
| 発動者 | 自分のクリーチャーのみ |
| コスト | 魔力（プレイヤーの共通資源） |
| タイミング | スペルフェーズ内（ターン1回） |
| 排他性 | スペルカード使用時は秘術は使えない（逆も同様） |
| 発動後 | クリーチャーはダウン状態（不屈で回避可） |

---

## 実装方式：spell_id参照（正式採用）

既存スペルの効果を秘術として使用する方式。秘術専用の効果は**9000番台のIDを使用**。

### データ構造

**クリーチャーJSON（既存スペル参照の例）**:
```json
{
  "id": 2,
  "name": "アモン",
  "ability_parsed": {
	"keywords": ["感応", "防魔", "秘術"],
	"mystic_arts": [
	  {
		"id": "amon_mystic_001",
		"name": "バイタリティ",
		"description": "対象領地に呪い\"能力値+20\"；カードを1枚引く",
		"spell_id": 2066,
		"cost": 50
	  }
	]
  }
}
```

**クリーチャーJSON（秘術専用スペル参照の例）**:
```json
{
  "id": 29,
  "name": "バーナックル",
  "ability_parsed": {
	"keywords": ["防御型", "秘術"],
	"mystic_arts": [
	  {
		"id": "barnacle_mystic_001",
		"name": "通行料半減",
		"description": "対象敵領地に通行料半減の呪いをかける（3ターン）",
		"spell_id": 9001,
		"cost": 50
	  }
	]
  }
}
```

**秘術専用スペル（data/spell_mystic.json）**:
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

### フィールド説明

| フィールド | 説明 |
|-----------|------|
| `id` | 秘術の一意ID（クリーチャー内でユニーク） |
| `name` | 秘術名（UI表示用） |
| `description` | 説明テキスト |
| `spell_id` | 参照するスペルのID（9000番台：秘術専用、2000番台：既存スペル） |
| `cost` | 魔力コスト（スペル本来のコストとは独立） |

### 秘術専用スペルID範囲

**ID 9000-9999: 秘術専用スペル**
- 通常のスペルカードとしては使用されない
- 秘術からのみ参照される
- `data/spell_mystic.json` に定義
- 例：通行料半減（9001）

**ID 2000-2999: 既存スペル**
- 通常のスペルカードとして使用可能
- 秘術からも参照可能
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
  ├─ [秘術を使う] 選択
  │   ├─ 発動可能クリーチャーを列挙
  │   ├─ クリーチャー選択UI表示
  │   ├─ 秘術選択UI表示
  │   ├─ ターゲット選択（セルフターゲット時は自動）
  │   ├─ 秘術発動・効果適用
  │   ├─ 魔力消費
  │   ├─ クリーチャーをダウン状態に設定
  │   └─ スペルUIを非表示（排他制御）
  │
  ├─ [スペルカード使用] → 秘術UIを非表示
  └─ [スペルをしない] → スペルフェーズ終了
```

---

## 関連ファイル

```
scripts/spells/spell_mystic_arts.gd      # 秘術実行エンジン
scripts/game_flow/spell_phase_handler.gd # 秘術発動フロー
scripts/ui_components/spell_and_mystic_ui.gd  # 秘術選択UI
scripts/spells/spell_curse_toll.gd       # 通行料呪いシステム（秘術から使用）
scripts/card_loader.gd                   # スペルデータ読み込み
data/fire_1.json                         # アモン（既存スペル参照例）
data/fire_2.json                         # バーナックル（秘術専用スペル参照例）
data/spell_2.json                        # バイタリティ（既存スペル）
data/spell_mystic.json                   # 秘術専用スペル（9000番台）
```

---

## SpellMysticArts 主要メソッド

| メソッド | 説明 |
|---------|------|
| `get_available_creatures(player_id)` | 秘術発動可能なクリーチャー一覧を取得 |
| `get_mystic_arts_for_creature(creature_data)` | クリーチャーの秘術一覧を取得 |
| `can_cast_mystic_art(mystic_art, context)` | 発動可否判定（魔力・ダウン状態・ターゲット有無） |
| `apply_spell_effect(mystic_art, target_data, context)` | spell_id参照で効果適用 |
| `_set_down_state(tile_index)` | 発動後のダウン状態設定 |

---

## ダウン状態と不屈

秘術発動後、クリーチャーはダウン状態になる（領地コマンドと同様）。

- ダウン状態のクリーチャーは次ターンまで秘術使用不可
- ダウン状態はスタート通過時に全土地で一括解除
- **不屈スキル**を持つクリーチャーはダウン状態にならない

---

## UI仕様

### ボタン配置

```
画面レイアウト

  [秘術を使う]                    [スペルをしない]
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
| 秘術を使う | 紫 (#663399) | 秘術選択 |
| スペルをしない | グレー (#808080) | スキップ |

---

## 動作確認済み効果

| effect_type | 説明 | 確認状況 |
|-------------|------|---------|
| `stat_boost` | 能力値増加 | ✅ バイタリティで確認 |
| `draw` | カードドロー | ✅ バイタリティで確認 |
| `damage` | ダメージ適用 | ✅ 実装済み |
| `curse_toll_half` | 通行料半減 | ✅ バーナックルで確認 |
| `toll_multiplier` | 通行料倍率 | ✅ 統合処理で対応 |
| `toll_share`, `toll_disable`, `toll_fixed`, `peace` | その他通行料呪い | ✅ 統合処理で対応 |

---

## パラメータカスタマイズ方式（確定）

秘術専用の効果やパラメータが必要な場合は **9000番台のIDで秘術専用スペルを作成** する方式を採用。

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

## 秘術を追加する手順

### パターンA：既存スペルを使用する場合

1. **スペル定義確認**: 使用したいスペルが`data/spell_*.json`に存在するか確認
2. **クリーチャーJSONに追加**:
   ```json
   "ability_parsed": {
	 "keywords": ["秘術"],
	 "mystic_arts": [{
	   "id": "unique_id",
	   "name": "秘術名",
	   "description": "説明",
	   "spell_id": 既存スペルID,
	   "cost": コスト
	 }]
   }
   ```
3. **動作確認**: ゲーム内で秘術が発動できることを確認

### パターンB：秘術専用スペルを作成する場合

1. **data/spell_mystic.jsonに定義追加**:
   ```json
   {
	 "id": 9001,
	 "name": "秘術専用スペル名",
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
	 "keywords": ["秘術"],
	 "mystic_arts": [{
	   "id": "unique_id",
	   "name": "秘術名",
	   "description": "説明",
	   "spell_id": 9001,
	   "cost": コスト
	 }]
   }
   ```

3. **動作確認**: ゲーム内で秘術が発動できることを確認

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2025/11/24 | 初版作成、基盤実装 |
| 2025/11/25 | spell_id参照方式実装完了、バイタリティ動作確認、秘術専用スペル9000番台方式確定、バーナックル（通行料半減）実装完了 |
