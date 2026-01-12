# CPU バトル判断仕様書

## 概要

CPUのバトル時の判断ロジック。攻撃側と防御側で別ファイルに分離。

**ファイル構成**:
| ファイル | 役割 |
|---------|------|
| `cpu_battle_ai.gd` | 攻撃側判断 |
| `cpu_defense_ai.gd` | 防御側判断（アイテム/援護/合体） |
| `cpu_item_evaluator.gd` | アイテム評価共通ロジック |
| `cpu_merge_evaluator.gd` | 合体シミュレーション |
| `battle_simulator.gd` | バトル結果シミュレーション |

---

## BattleSimulator

### シミュレーション結果

```gdscript
enum BattleResult {
	ATTACKER_WIN,      # 攻撃側勝利
	DEFENDER_WIN,      # 防御側勝利
	ATTACKER_SURVIVED, # 両者生存
	BOTH_DEFEATED      # 相打ち
}
```

### 考慮する要素

- HP/AP（基礎値 + base_up補正）
- 土地ボーナス（防御側のみ）
- スキル効果（先制、2回攻撃、強打、無効化、反射など）
- アイテム効果

---

## 攻撃側判断（cpu_battle_ai.gd）

### 判断フロー

```
1. 敵がアイテム破壊/盗みスキル持ち → アイテム使用不可
2. 合体で勝てる → 合体優先
3. 無効化+即死持ちで敵が無効化アイテム所持 → 無効化+即死を優先
4. 各クリーチャー×アイテムをシミュレーション
5. ATTACKER_WIN のみ攻撃実行
6. 勝てない → 即死スキル持ちで賭ける
7. 即死もない → 攻撃しない
```

### 主要関数

| 関数 | 役割 |
|------|------|
| `evaluate_all_combinations_for_battle()` | クリーチャー×アイテム全組み合わせ評価 |
| `simulate_worst_case()` | 敵の対抗手段を考慮したワーストケース判定 |
| `find_item_to_beat_worst_case()` | ワーストケースに勝つアイテム探索 |

### ワーストケース判定

敵の対抗手段（アイテム・援護）を考慮：

```
1. 両方アイテムなしで勝てない → 攻撃しない
2. 敵の全対抗手段をシミュレーション
3. ワーストケースでも勝てる → 攻撃（アイテム温存）
4. ワーストケースで負けるが自アイテムで勝てる → 攻撃（アイテム使用）
5. 自アイテムでも勝てない → 攻撃しない
```

---

## 防御側判断（cpu_defense_ai.gd）

### メインエントリ

```gdscript
func decide_defense_action(context: Dictionary) -> Dictionary
# 返り値: { action: "item"|"support"|"merge"|"pass", ... }
```

### 判断フロー

```
1. 無効化スキルで勝てる → パス（アイテム温存）
2. 敵がアイテム破壊/盗み持ち → アイテム使用不可（援護のみ）
3. 合体で勝てる → 合体（最優先）
4. アイテムなしで勝利/両者生存 → パス
5. 勝てるアイテム/援護を探す
6. 防具枚数で優先順位決定
   - 2枚以下: 援護優先
   - 3枚以上: アイテム優先
```

### 主要関数

| 関数 | 役割 |
|------|------|
| `_evaluate_nullify_option()` | 無効化スキルで勝てるか判定 |
| `_evaluate_merge_option()` | 合体で勝てるか判定 |
| `_evaluate_item_options()` | 使用可能アイテムの評価 |
| `_evaluate_support_options()` | 援護クリーチャーの評価 |
| `_check_instant_death_threat()` | 敵の即死スキル脅威判定 |

### 温存対象

高レベル土地防衛用に取っておくアイテム/クリーチャー：
- 道連れ（instant_death + on_death）
- 死亡時ダメージ（damage_enemy + on_death）

**Lv2以上の土地でのみ使用**

---

## アイテム評価（cpu_item_evaluator.gd）

### 主要関数

| 関数 | 役割 |
|------|------|
| `evaluate_items_for_attack()` | 攻撃側アイテム評価 |
| `evaluate_items_for_defense()` | 防御側アイテム評価 |
| `is_reserve_item()` | 温存対象判定 |
| `get_item_type_priority()` | アイテム種別優先度 |

### アイテム種別優先度

**攻撃時**: 巻物 > 武器 > アクセサリ > 防具
**防御時**: 防具 > アクセサリ > 武器（巻物は使用しない）

---

## 合体判断（cpu_merge_evaluator.gd）

### 条件

1. 合体スキルを持っている
2. 手札に合体相手（partner_id）がいる
3. 合体相手のコストを支払える
4. 合体後のクリーチャーで勝てる/生き残れる

### 合体パターン例

| バトル側 | 合体相手 | 結果 |
|----------|----------|------|
| アンドロギア | ビーストギア | ギアリオン |
| グランギア | スカイギア | アンドロギア |

---

## 即死スキル判断

### 攻撃側（cpu_battle_ai.gd）

勝てる組み合わせがない場合、即死スキル持ちで賭ける。

```
1. 即死条件（属性、APチェック等）を満たすか確認
2. 確率が高いクリーチャーを優先
3. 敵が無効化アイテム持ち → 無効化+即死クリーチャーを優先
```

### 防御側（cpu_defense_ai.gd）

敵が100%即死スキル持ちの場合：

```
1. 通常攻撃100%無効化アイテムを探す
2. あれば使用
3. なければアイテムを使わない（即死されるため無駄）
```

---

## メインファイルとの連携

### item_phase_handler.gd（変更後）

```gdscript
func _cpu_decide_item():
	var context = _build_defense_context()
	var decision = cpu_defense_ai.decide_defense_action(context)
	
	match decision.action:
		"item": use_item(decision.item)
		"support": use_support(decision.creature)
		"merge": _execute_merge_for_cpu(decision.merge_data)
		"pass": pass_item()
```

### tile_action_processor.gd（変更後）

```gdscript
func _process_cpu_battle(tile_info: Dictionary):
	var decision = cpu_battle_ai.evaluate_all_combinations_for_battle(...)
	if decision.should_attack:
		cpu_action_executor.execute_battle(decision)
```
