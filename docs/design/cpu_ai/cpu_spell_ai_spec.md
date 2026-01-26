# CPU スペル AI 仕様書

## 概要

CPUのスペルフェーズでのスペル/アルカナアーツ使用判断。

### アーキテクチャ

```
┌────────────────────────────────────────────────────────┐
│ SpellPhaseHandler (spell_phase_handler.gd)             │
│   - スペルフェーズ状態管理                              │
│   - UI制御                                             │
│   - プレイヤー/CPU共通の効果実行                        │
└─────────────────────┬──────────────────────────────────┘
                      │ CPUの場合
                      ▼
┌────────────────────────────────────────────────────────┐
│ CPUSpellPhaseHandler (cpu_spell_phase_handler.gd)      │
│   - decide_action(): スペル/ミスティック判断呼び出し   │
│   - prepare_spell_execution(): 実行準備（犠牲、合成）  │
│   - prepare_mystic_execution(): アルカナアーツ実行準備           │
│   - build_target_data(): ターゲットデータ構築          │
│   - select_best_target(): 最適ターゲット選択           │
└─────────────────────┬──────────────────────────────────┘
                      │ 判断委譲
                      ▼
┌────────────────────────────────────────────────────────┐
│ CPUSpellAI (cpu_spell_ai.gd)                           │
│   - decide_spell(): どのスペルをどのターゲットに       │
│   - _evaluate_xxx(): 各パターンの評価                  │
│   - 内部コンポーネント:                                 │
│     - CPUSpellConditionChecker: 使用条件判定           │
│     - CPUSpellTargetSelector: ターゲット選択           │
│     - CPUSpellUtils: 距離・利益計算                    │
│     - CPUSacrificeSelector: カード犠牲選択             │
└────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────┐
│ CPUMysticArtsAI (cpu_mystic_arts_ai.gd)                │
│   - decide_mystic_arts(): アルカナアーツ判断                     │
│   - 配置クリーチャーのアルカナアーツをスコアリング               │
└────────────────────────────────────────────────────────┘
```

### 役割分担

| クラス | 責務 |
|--------|------|
| `CPUSpellAI` | **判断**: どのスペルを使うか、ターゲットは誰か |
| `CPUMysticArtsAI` | **判断**: どのアルカナアーツを使うか |
| `CPUSpellPhaseHandler` | **処理**: 判断結果を受けて実行準備、データ構築 |
| `SpellPhaseHandler` | **実行**: 効果の実際の実行、UI表示 |

---

## 主要ファイル

| ファイル | 役割 |
|---------|------|
| `cpu_spell_ai.gd` | スペル使用判断 |
| `cpu_spell_phase_handler.gd` | CPUスペルフェーズ処理（実行準備） |
| `cpu_mystic_arts_ai.gd` | アルカナアーツ判断 |
| `cpu_spell_target_selector.gd` | ターゲット選択 |
| `cpu_spell_condition_checker.gd` | 使用条件判定 |
| `cpu_spell_utils.gd` | 距離・利益計算 |
| `cpu_sacrifice_selector.gd` | カード犠牲選択 |

---

## 判断フロー

```
1. CPUSpellPhaseHandler.decide_action()
   │
   ├─ CPUSpellAI.decide_spell()
   │   └─ 手札のスペルを評価、最高スコアを返す
   │
   ├─ CPUMysticArtsAI.decide_mystic_arts()
   │   └─ 配置クリーチャーのアルカナアーツを評価
   │
   └─ スコア比較
       ├─ spell_score >= mystic_score → "spell"
       ├─ mystic_score > spell_score → "mystic"
       └─ どちらも使わない → "pass"

2. SpellPhaseHandler側
   │
   ├─ "spell" → prepare_spell_execution() → execute_spell_effect()
   ├─ "mystic" → prepare_mystic_execution() → execute_mystic_art()
   └─ "pass" → pass_spell()
```

### スペル vs アルカナアーツの優先判断

```gdscript
# 手札が多いならスペル消費優先
if hand_size >= 6:
    spell_score += 0.5

# 手札が少ないならアルカナアーツ優先（カード温存）
if hand_size <= 3:
    mystic_score += 0.5
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

### EP系

| effect_type | 損益分岐点 |
|-------------|-----------|
| `gain_magic` | コスト < 獲得量 |
| `drain_magic` | コスト < 敵EP×% |

### ダイス操作系

| effect_type | 判断基準 |
|-------------|----------|
| `dice_fixed` | 特定マスに止まりたい（ホーリーワード） |

---

## ホーリーワード判断

`_evaluate_holy_word_spell()` で処理。

### 攻撃的使用

敵を自分のLv3+ドミニオに止まらせる。

### 防御的使用

自分が敵のLv3+ドミニオを回避する。

詳細は [cpu_movement_ai_spec.md](cpu_movement_ai_spec.md) 参照。

---

## アルカナアーツ判断

配置済みクリーチャーのアルカナアーツを評価。

```
1. 各クリーチャーのアルカナアーツを取得
2. アルカナアーツのcpu_ruleでスコア計算
3. スペルとスコア比較
4. 高い方を使用
```

---

## 初期化

### CPUSpellAI

```gdscript
# _init()で内部コンポーネントを生成
func _init() -> void:
    condition_checker = CPUSpellConditionChecker.new()
    target_selector = CPUSpellTargetSelector.new()
    spell_utils = CPUSpellUtils.new()
    sacrifice_selector = CPUSacrificeSelector.new()

# initialize()で外部システム参照を設定
func initialize(context) -> void:
    if context:
        board_system = context.board_system
        player_system = context.player_system
        # ... 他の参照
    
    # 内部コンポーネントも初期化
    if condition_checker:
        condition_checker.initialize(context)
    # ...
```

### CPUSpellPhaseHandler

```gdscript
# initialize()で親ハンドラー参照を設定
func initialize(handler) -> void:
    spell_phase_handler = handler
    _sync_references()  # 親から参照を同期
```

---

## 変更履歴

| 日付 | 変更内容 |
|------|---------|
| 2026/01/16 | アーキテクチャ図追加、CPUSpellPhaseHandlerとの役割分担を明記 |
