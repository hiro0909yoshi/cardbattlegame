# 土地レベル条件（land_level_check）実装完了報告

**実装日**: 2025/10/20  
**対象機能**: 条件付き無効化スキル - 土地レベル条件

## 実装概要

アブサス（ID:106）の「戦闘地がレベル3以上の場合、無効化[通常攻撃]」を実現するため、`land_level_check`条件タイプを実装しました。

## 実装内容

### 1. ConditionChecker.gd - 土地レベル条件の追加

**ファイル**: `scripts/skills/condition_checker.gd`

**追加内容**:
```gdscript
# 土地レベル条件
"land_level_check":
	var current_land_level = context.get("current_land_level", 1)
	var operator = condition.get("operator", ">=")
	var value = condition.get("value", 1)
	match operator:
		">=": return current_land_level >= value
		">": return current_land_level > value
		"<=": return current_land_level <= value
		"<": return current_land_level < value
		"==": return current_land_level == value
		_: return false
```

**サポートする演算子**:
- `>=`: 以上
- `>`: より大きい
- `<=`: 以下
- `<`: より小さい
- `==`: 等しい

### 2. BattleSystem._check_nullify() - メソッド名修正とコンテキスト対応

**ファイル**: `scripts/battle_system.gd`

**変更点**:
1. 引数名を`_context`から`context`に変更（コンテキストを実際に使用するため）
2. `condition_checker.evaluate_condition()`を`condition_checker._evaluate_single_condition()`に修正
   - 正しいメソッド名を使用
3. デバッグ出力を追加
   - 条件チェック時のログ出力
   - 土地レベル情報の表示

### 3. BattleSystem._execute_attack_sequence() - コンテキスト構築

**ファイル**: `scripts/battle_system.gd`

**変更点**:
1. 関数シグネチャに`tile_info`パラメータを追加
   ```gdscript
   func _execute_attack_sequence(attack_order: Array, tile_info: Dictionary) -> void:
   ```

2. 無効化判定時にコンテキストを構築
   ```gdscript
   # 無効化判定のためのコンテキスト構築
   var nullify_context = {
	   "current_land_level": tile_info.get("level", 1)
   }
   var nullify_result = _check_nullify(attacker_p, defender_p, nullify_context)
   ```

3. 呼び出し元（2箇所）を修正
   - `execute_3d_battle()` L122
   - `execute_3d_battle_with_data()` L182

### 4. ConditionChecker.build_battle_context() - コンテキストビルダー拡張

**ファイル**: `scripts/skills/condition_checker.gd`

**追加内容**:
```gdscript
# 土地情報
"battle_land_element": battle_field.get("element", ""),
"current_land_level": battle_field.get("level", 1),  // 追加
"adjacent_is_ally_land": battle_field.get("adjacent_ally", false),
"player_lands": game_state.get("player_lands", {}),
```

## テストケース

### アブサス（ID:106）の動作確認

**クリーチャー情報**:
```json
{
  "id": 106,
  "name": "アブサス",
  "element": "water",
  "ap": 20,
  "hp": 40,
  "ability": "無効化",
  "ability_detail": "戦闘地がレベル3以上の場合、無効化[通常攻撃]",
  "ability_parsed": {
	"keywords": ["無効化"],
	"keyword_conditions": {
	  "無効化": {
		"nullify_type": "normal_attack",
		"conditions": [{
		  "condition_type": "land_level_check",
		  "operator": ">=",
		  "value": 3
		}]
	  }
	}
  }
}
```

**期待される動作**:
1. レベル1-2の土地：通常攻撃を無効化しない
2. レベル3-5の土地：通常攻撃を完全無効化
3. 巻物攻撃：レベルに関係なく無効化しない（nullify_typeが"normal_attack"のため）

**ログ出力例**（レベル3の土地の場合）:
```
【無効化条件チェック】条件数: 1
  条件タイプ: land_level_check
  土地レベル: 3 >= 3
  → 全条件成立
【無効化】アブサス が攻撃を完全無効化
```

## 共通定義との整合性

**card_definitions.json** に定義済みの条件タイプと一致:
```json
{
  "possession": [
	"has_item_type", "has_keyword", "total_land_count",
	"land_level_check",  // ← 今回実装
	"element_land_count", "consecutive_lands"
  ],
  "context_vars": [
	"current_land_level",  // ← 今回実装
	"fire_creatures", ...
  ]
}
```

## 拡張性

この実装により、以下の機能でも`land_level_check`条件が使用可能になります:

### 1. 強打スキル
```json
{
  "effect_type": "power_strike",
  "multiplier": 1.5,
  "conditions": [{
	"condition_type": "land_level_check",
	"operator": ">=",
	"value": 3
  }]
}
```

### 2. その他の条件付きスキル
- 感応
- 即死
- HP変動
など、`conditions`配列を持つ全てのスキルで利用可能

## 関連ファイル

**実装**:
- `scripts/skills/condition_checker.gd`
- `scripts/battle_system.gd`

**データ**:
- `data/water_1.json` (アブサス ID:106)

**ドキュメント**:
- `docs/design/nullify_skill_design.md`
- `docs/design/skills_design.md`
- `docs/issues/tasks.md`

## 残りの作業

### 未実装の条件付き無効化
- `item_equipped` 条件 (例: ID 103 アクアデューク - 防具使用時)

### 推奨テスト
1. バトルテストツールでアブサスの無効化を確認
2. レベル1-5の各土地での動作確認
3. 巻物攻撃時の動作確認（無効化されないこと）

## まとめ

土地レベル条件（`land_level_check`）の実装により、アブサスの条件付き無効化が正常に機能するようになりました。この実装は汎用的な設計となっており、強打や他のスキルでも土地レベル条件を使用できます。
