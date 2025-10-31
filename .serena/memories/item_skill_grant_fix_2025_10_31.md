# アイテムスキル付与の条件形式修正

## 日付
2025年10月31日

## 問題
ボーパルソード(ID:1060)の強打スキルが、条件に関わらず常に発動していた。

## 原因
1. **JSON条件の形式ミス**: `min_hp: 40`という独自パラメータを使用
2. **MHP取得ミス**: `enemy_mhp`に`defender.creature_data["mhp"]`を設定（未計算の基本値）

## 修正内容

### 1. JSON条件形式の統一 (data/item.json)
```json
// 修正前
{
  "condition_type": "enemy_max_hp_check",
  "min_hp": 40  // ← 独自形式
}

// 修正後
{
  "condition_type": "enemy_max_hp_check",
  "operator": ">=",
  "value": 40
}
```

### 2. MHP取得の修正 (scripts/battle/battle_skill_processor.gd)
```gdscript
// 修正前
var attacker_context = ConditionChecker.build_battle_context(
  attacker.creature_data,
  defender.creature_data,  // ← mhpは基本値のみ
  ...
)

// 修正後
var attacker_context = ConditionChecker.build_battle_context(
  attacker.creature_data,
  defender.creature_data,
  tile_info,
  {
    ...
    "enemy_mhp_override": defender.get_max_hp()  // 計算済みMHP
  }
)
```

### 3. build_battle_contextの修正 (scripts/skills/condition_checker.gd)
```gdscript
"enemy_mhp": game_state.get("enemy_mhp_override", defender_data.get("mhp", 0))
```

### 4. デバッグ出力の追加
- `_evaluate_power_strike_conditions`に条件評価ログ
- `enemy_max_hp_check`に詳細なチェックログ

## 重要な教訓

### 条件形式の統一
- すべての条件タイプで`operator`と`value`を使用
- 独自パラメータ名（`min_hp`, `max_hp`等）は禁止
- `condition_checker.gd`は統一的な形式で条件評価

### MHP取得方法
- `BattleParticipant.get_max_hp()`: 真のMHP（base_hp + base_up_hp）
- `creature_data["mhp"]`: 基本値のみ、ボーナス未計算
- 戦闘ボーナス（土地、アイテム等）は`current_hp`に含まれるが、MHPには含まれない

## 更新ドキュメント
- docs/design/item_system.md
- docs/design/condition_patterns_catalog.md
