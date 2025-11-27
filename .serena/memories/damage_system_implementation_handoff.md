# ダメージ操作システム実装 引き継ぎ

## 概要

ダメージ・回復系スペルと秘術の実装準備が完了。次のチャットで実装作業を開始する。

## 作成済みドキュメント

**`docs/design/spells/ダメージ操作.md`** - 詳細な設計書

## 実装対象

### スペル（13個）

| カテゴリ | ID | 名前 | 効果 |
|---------|-----|------|------|
| 単体ダメージ | 2106 | マジックボルト | 対象敵HP-20 |
| 単体ダメージ | 2033 | シャイニングガイザー | 対象敵HP-30（合成でHP-40） |
| 条件付き単体 | 2031 | サンダークラップ | 召喚条件あり対象敵HP-30 |
| 条件付き単体 | 2041 | ストーンブラスト | 対象地/風HP-30 |
| 条件付き単体 | 2088 | ブレイズスプラッシュ | 対象火/水HP-30 |
| 全体ダメージ | 2016 | エレメンタルラス | 属性不一致全HP-20 |
| 全体ダメージ | 2023 | クラスターバースト | 最多属性全HP-20 |
| 全体ダメージ | 2053 | ディザスター | ダウン中MHP50以上全HP-30 |
| 全体ダメージ | 2037 | スウォーム | HP減少中全HP-20 |
| 全体ダメージ | 2065 | バーニングベイル | 全水/風HP-20 |
| 全体ダメージ | 2086 | フリーズサイクロン | 全火/地HP-20 |
| 回復 | 2121 | リストア | ダウン解除＋HP全回復 |
| 回復 | 2116 | ライフストリーム | 全自クリーチャーHP全回復 |

### 秘術（6体）

| ID | クリーチャー | 効果 |
|----|-------------|------|
| 231 | ハードロックドラゴン | 対象敵火/風HP-20 |
| 304 | エルフアーチャー | 対象敵HP-10 |
| 344 | ライトニングドラゴン | 対象敵水/地HP-20 |
| 404 | アーマードラゴン | 対象無HP-30 |
| 428 | ニルーバーナ | 呪い付き全HP-20 |
| 233 | ヒーラー | 対象自HP30回復 |

## 実装方針

### 1. 新規クラス作成

**`scripts/spells/spell_damage.gd`** を新規作成

主要メソッド:
- `apply_damage(tile, value)` - ダメージ適用
- `apply_heal(tile, value)` - HP回復
- `apply_full_heal(tile)` - HP全回復
- `_destroy_creature(tile)` - クリーチャー破壊（レベル維持）

### 2. HP操作の注意点

- HP取得: `creature.get("current_hp", max_hp)` を使用
- HP保存: `creature["current_hp"] = new_hp`
- **撃破時はレベル維持**（空き地として残る）
- 回復上限: MHP（`hp + base_up_hp`）

### 3. 現状の問題点（要修正）

`spell_phase_handler._apply_damage_effect`:
- `creature.get("hp", 0)` → `current_hp`を使うべき
- `tile.level = 1` → レベル維持すべき

`spell_mystic_arts._apply_damage`:
- `tile.level = 1` → レベル維持すべき

### 4. ターゲット選択

- 既存UI（バイタリティ等と同じ）を使用
- `TargetSelectionHelper.get_valid_targets()` を拡張
- 条件に合わないクリーチャーはスキップ

target_info 拡張フィールド:
- `owner_filter`: "own", "enemy", "any"
- `creature_elements`: ["fire", "water"] 等
- `has_curse`: true/false
- `has_summon_condition`: true/false
- `hp_reduced`: true/false
- `is_down`: true/false
- `mhp_check`: { "operator": ">=", "value": 50 }
- `element_mismatch`: true/false

### 5. 演出フロー

**単体ダメージ**:
1. ターゲット選択UI
2. カメラフォーカス
3. ダメージ通知「○○に20ダメージ！ HP: 30/50 → 10/50」
4. 撃破時「○○は倒された！」→ クリーチャー消去
5. クリック待ち
6. スペルフェーズ終了

**全体ダメージ**:
1. 条件でフィルタリング
2. 1体ずつ: カメラフォーカス → ダメージ通知 → 撃破判定 → クリック待ち
3. 全員終わったらスペルフェーズ終了

### 6. 呼び出し構造

```
spell_phase_handler → spell_damage.apply_damage()
spell_mystic_arts  → spell_damage.apply_damage()
```

秘術からも直接呼び出し（シンプル）

### 7. クラスターバースト（最多属性）

- 敵味方関係なく最多属性の全クリーチャーにダメージ
- 同数の場合はランダム

## 実装予定順序

1. `spell_damage.gd` 新規作成
2. `TargetSelectionHelper` 拡張（creature条件フィルタ）
3. マジックボルト（最もシンプル）で動作確認
4. 属性限定系、全体ダメージ系を順次実装
5. 回復系実装
6. 秘術対応

## 関連ファイル

- `docs/design/spells/ダメージ操作.md` - 詳細設計
- `docs/design/hp_structure.md` - HP管理仕様
- `scripts/game_flow/target_selection_helper.gd` - ターゲット選択
- `scripts/game_flow/spell_phase_handler.gd` - スペル実行
- `scripts/spells/spell_mystic_arts.gd` - 秘術実行
