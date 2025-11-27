# ダメージ操作システム実装 引き継ぎ

## 概要

ダメージ・回復系スペルと秘術の実装作業進行中。Phase 1-3完了。

## 実装状況

### 完了済み

#### システム実装
- ✅ `scripts/spells/spell_damage.gd` 新規作成
  - `apply_damage(tile_index, value)` - ダメージ適用
  - `apply_heal(tile_index, value)` - HP回復
  - `apply_full_heal(tile_index)` - HP全回復
  - `_destroy_creature(tile)` - クリーチャー破壊（レベル維持、3D表示削除）
  - `format_damage_notification()` / `format_heal_notification()` - 通知テキスト生成

- ✅ `TargetSelectionHelper.get_valid_targets()` 拡張
  - `owner_filter`: "own", "enemy", "any"
  - `creature_elements`: 属性制限
  - `has_curse`: 呪い付きのみ
  - `has_summon_condition`: 召喚条件ありのみ
  - `hp_reduced`: HP減少中のみ
  - `is_down`: ダウン中のみ
  - `mhp_check`: MHP条件
  - `element_mismatch`: 領地属性とクリーチャー属性の不一致
  - `most_common_element`: 最多属性（クラスターバースト用）

- ✅ `spell_phase_handler` 全体ダメージ対応
  - `_execute_spell_on_all_creatures()` - ダメージ/呪い分岐
  - `_apply_damage_to_all_creatures()` - 1体ずつ処理

#### スペル実装（JSON追加済み）

| Phase | ID | 名前 | 効果 | ステータス |
|-------|-----|------|------|----------|
| 1 | 2106 | マジックボルト | 対象敵HP-20 | ✅ |
| 1 | 2033 | シャイニングガイザー | 対象敵HP-30 | ✅ |
| 2 | 2041 | ストーンブラスト | 対象敵地/風HP-30 | ✅ |
| 2 | 2088 | ブレイズスプラッシュ | 対象敵火/水HP-30 | ✅ |
| 2 | 2031 | サンダークラップ | 召喚条件あり対象敵HP-30（密命） | ✅ |
| 3 | 2065 | バーニングベイル | 全水/風HP-20 | ✅ |
| 3 | 2086 | フリーズサイクロン | 全火/地HP-20 | ✅ |
| 3 | 2037 | スウォーム | HP減少中全HP-20 | ✅ |
| 3 | 2016 | エレメンタルラス | 属性不一致全HP-20 | ✅ |
| 3 | 2023 | クラスターバースト | 最多属性全HP-20 | ✅ |
| 3 | 2053 | ディザスター | ダウン中MHP50以上全HP-30 | ✅ |

### 未実装

#### Phase 4: 回復
| ID | 名前 | 効果 |
|----|------|------|
| 2121 | リストア | ダウン解除＋HP全回復 |
| 2116 | ライフストリーム | 全自クリーチャーHP全回復 |

#### Phase 5: 秘術
| ID | クリーチャー | 効果 |
|----|-------------|------|
| 304 | エルフアーチャー | 対象敵HP-10 |
| 231 | ハードロックドラゴン | 対象敵火/風HP-20 |
| 344 | ライトニングドラゴン | 対象敵水/地HP-20 |
| 404 | アーマードラゴン | 対象無HP-30 |
| 428 | ニルーバーナ | 呪い付き全HP-20 |
| 233 | ヒーラー | 対象自HP30回復 |

## 技術詳細

### 全体ダメージ処理フロー
1. `_execute_spell_on_all_creatures()` でダメージ/呪い効果を判定
2. ダメージ効果の場合 `_apply_damage_to_all_creatures()` を呼び出し
3. `TargetSelectionHelper.get_valid_targets()` で条件付き対象取得
4. 1体ずつ: カメラフォーカス → ダメージ → 通知 → クリック待ち

### HP管理
- `creature["current_hp"]` - 現在HP（状態値）
- `creature["hp"]` - ベースHP（不変）
- `creature["base_up_hp"]` - 永続ボーナス（マスグロース等）
- MHP = hp + base_up_hp

## 関連ファイル

- `docs/design/spells/ダメージ操作.md` - 詳細設計
- `scripts/spells/spell_damage.gd` - ダメージ・回復処理
- `scripts/game_flow/target_selection_helper.gd` - ターゲット選択
- `scripts/game_flow/spell_phase_handler.gd` - スペル実行
- `data/spell_1.json`, `data/spell_2.json` - スペルデータ

## 次の作業

Phase 4: 回復スペル実装
- リストア (2121) - ダウン解除＋HP全回復
- ライフストリーム (2116) - 全自クリーチャーHP全回復
