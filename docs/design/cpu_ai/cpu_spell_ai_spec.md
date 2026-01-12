# CPU スペル AI 仕様書

## 概要

CPUのスペルフェーズでのスペル/ミスティックアーツ使用判断。

**主要ファイル**:
- `cpu_spell_ai.gd` - スペル使用判断
- `cpu_mystic_arts_ai.gd` - ミスティックアーツ判断
- `cpu_spell_target_selector.gd` - ターゲット選択
- `cpu_spell_condition_checker.gd` - 使用条件判定

---

## 判断フロー

```
1. スペル/ミスティックアーツの使用可否チェック
2. 両方使用可能な場合:
   - 手札6枚以上 → スペル優先
   - 手札3枚以下 → ミスティックアーツ優先
   - それ以外 → 効果の有用性で比較
3. 使用するスペルを選択
4. ターゲットを選択
5. 実行
```

---

## cpu_ruleフィールド

各スペルJSONに設定：

```json
{
  "cpu_rule": {
	"pattern": "condition",
	"condition": "element_mismatch",
	"priority": "medium"
  }
}
```

### パターン一覧

| pattern | 説明 |
|---------|------|
| `immediate` | 手に入り次第使用（ドロー系） |
| `has_target` | 有効ターゲットがいれば使用 |
| `condition` | 特定条件を満たしたら使用 |
| `profit_calc` | 損益計算して判断 |
| `strategic` | 戦略的判断（ホーリーワード等） |
| `skip` | CPU使用しない |

### 優先度

| priority | スコア |
|----------|--------|
| `high` | 3 |
| `medium_high` | 2.5 |
| `medium` | 2 |
| `low` | 1 |
| `very_low` | 0.5 |

---

## 主要なeffect_type

### ダメージ/回復系

| effect_type | 判断基準 |
|-------------|----------|
| `damage` | 敵を倒せるか |
| `heal` / `full_heal` | 味方がダメージを受けているか |

### ドロー系

| effect_type | 判断基準 |
|-------------|----------|
| `draw` / `draw_cards` | 手札が少ない |
| `draw_by_type` | 欲しいタイプがある |

### 魔力系

| effect_type | 損益分岐点 |
|-------------|-----------|
| `gain_magic` | コスト < 獲得量 |
| `drain_magic` | コスト < 敵魔力×% |

### ダイス操作系

| effect_type | 判断基準 |
|-------------|----------|
| `dice_fixed` | 特定マスに止まりたい（ホーリーワード） |

---

## ホーリーワード判断

`_evaluate_holy_word_spell()` で処理。

### 攻撃的使用

敵を自分のLv3+領地に止まらせる。

### 防御的使用

自分が敵のLv3+領地を回避する。

詳細は [cpu_movement_ai_spec.md](cpu_movement_ai_spec.md) 参照。

---

## ミスティックアーツ判断

配置済みクリーチャーの秘術を評価。

```
1. 各クリーチャーの秘術を取得
2. 秘術のcpu_ruleでスコア計算
3. スペルとスコア比較
4. 高い方を使用
```
