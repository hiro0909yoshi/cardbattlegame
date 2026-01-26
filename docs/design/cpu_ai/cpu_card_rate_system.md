# カードレート評価システム

## 概要

カードの価値を数値化して、CPU判断に使用するシステム。

## ファイル

`scripts/cpu_ai/card_rate_evaluator.gd`

## 使用方法

```gdscript
const CardRateEvaluator = preload("res://scripts/cpu_ai/card_rate_evaluator.gd")

# カードのレート取得
var rate = CardRateEvaluator.get_rate(card)

# 最もレートの低いカードを取得
var lowest = CardRateEvaluator.get_lowest_rate_card(cards)

# 最もレートの高いカードを取得
var highest = CardRateEvaluator.get_highest_rate_card(cards)

# レート順にソート（昇順: 低い方が先）
var sorted_asc = CardRateEvaluator.sort_by_rate_asc(cards)

# レート順にソート（降順: 高い方が先）
var sorted_desc = CardRateEvaluator.sort_by_rate_desc(cards)
```

## レート計算

### クリーチャー

```
レート = (HP + AP) / 2 + スキル補正 - コスト補正
```

- ベース: `(HP + AP) / 2`
- スキル補正: `SKILL_RATE_BONUS`から取得
- コスト補正: `コスト / 5`

### スペル

```
レート = 効果補正 + 対象範囲補正 - コスト補正
```

- 効果補正: `SPELL_EFFECT_BONUS`から取得（複数効果は合算）
- 対象範囲補正: `SPELL_TARGET_TYPE_BONUS`から取得
- コスト補正: `コスト / 10`

### アイテム

```
レート = 50 + ステータス修正 + 効果補正 + キーワード補正
```

- 基礎値: `50`（交換対象にならないため優先度を上げる）
- ステータス修正: `AP修正 + HP修正`
- 効果補正: `ITEM_EFFECT_BONUS`から取得
- キーワード補正: `SKILL_RATE_BONUS`から取得

## 組み込み箇所

| 箇所 | 用途 | 状態 |
|------|------|------|
| 手札破棄（上限超過時） | レートの低いものから捨てる | 実装済 |
| クリーチャー配置 | 配置判断に参照 | 実装済 |
| 手札破壊系スペル | 敵の手札でレートの高いものから破壊 | 未実装 |
| 敵クリーチャーへのスペル効果 | 対象選択に参照 | 未実装 |
| 味方クリーチャーへのスペル効果 | 対象選択に参照 | 未実装 |
| 領地コマンドの交換判断 | 交換するか判断 | 未実装 |

## 手札破棄の重複補正

手札破棄時のみ、同一カードの重複に対してペナルティを適用。

| 枚数 | 補正 |
|------|------|
| 1枚目 | 0 |
| 2枚目 | -30 |
| 3枚目以降 | -100 |

**実装箇所:** `cpu_hand_utils.gd` の `_get_rate_for_discard()`

この補正は手札破棄判断時のみ適用され、他の判断（配置、交換など）には影響しない。

## クリーチャー配置のロジック

**実装箇所:** `cpu_hand_utils.gd` の `select_best_summon_card()`

**優先順位：**
1. 属性一致カード → レート最高を選択
2. 属性一致なし＋アルカナアーツ持ち → レート最高を選択
3. どちらもなし → レート最低を選択（弱いカードを処分）

## 補正値の調整

補正値は`card_rate_evaluator.gd`内の定数で定義。各値の横にコメントで対象カード名を記載。

- `SKILL_RATE_BONUS`: クリーチャーのキーワード補正
- `SPELL_EFFECT_BONUS`: スペルの効果タイプ補正
- `SPELL_TARGET_TYPE_BONUS`: スペルの対象範囲補正
- `ITEM_EFFECT_BONUS`: アイテムの効果タイプ補正

## JSONでの個別指定

カードJSONに`"rate"`を直接指定すると、計算式より優先される。

```json
{
  "id": 1,
  "name": "特殊カード",
  "rate": 100,
  ...
}
```
