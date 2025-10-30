# HP計算ユーティリティ仕様書

**作成日**: 2025-10-30  
**対象**: `scripts/utils/hp_calculator.gd`

---

## 📋 概要

クリーチャーのMHP（最大HP）と現在HPの計算を一元管理するユーティリティクラスです。

### 🎯 目的

1. **MHP計算の統一化**: `hp + base_up_hp` の計算をコード全体で統一
2. **重複コードの削減**: 同じ計算式が50箇所以上に散らばっている問題を解決
3. **メンテナンス性向上**: 計算ロジックの変更が1箇所で完結
4. **可読性向上**: `HPCalculator.calculate_max_hp(data)` で意図が明確に

---

## 🔧 使用方法

### 基本的な使い方

```gdscript
# MHPを取得
var mhp = HPCalculator.calculate_max_hp(creature_data)

# 現在HPを取得
var current_hp = HPCalculator.calculate_current_hp(creature_data)

# ダメージを負っているかチェック
if HPCalculator.is_damaged(creature_data):
	print("このクリーチャーは負傷しています")
```

### 条件チェック

```gdscript
# MHP40以下かチェック
if HPCalculator.is_mhp_below_or_equal(creature_data, 40):
	print("即死スキル発動")

# MHP50以上かチェック
if HPCalculator.is_mhp_above_or_equal(creature_data, 50):
	print("無効化スキル発動")

# 範囲チェック
if HPCalculator.is_mhp_in_range(creature_data, 30, 60):
	print("中型クリーチャーです")
```

### デバッグ

```gdscript
# デバッグ文字列を取得: "25/40 (30+10)"
var debug_str = HPCalculator.get_hp_debug_string(creature_data)
print("HP状態: ", debug_str)
```

---

## 📊 計算式

### MHP（最大HP）

```gdscript
MHP = base_hp + base_up_hp
```

- `base_hp`: JSONの `"hp"` フィールド（初期HP）
- `base_up_hp`: 永続バフによる最大HP増加量

### 現在HP

```gdscript
現在HP = current_hp (設定されている場合) または MHP (デフォルト)
```

- `current_hp`: ダメージを負った後の現在HP
- 設定されていない場合は満タン（MHP）として扱う

---

## 🔄 置き換え例

### Before（従来のコード）

```gdscript
# ❌ 重複した計算式
var attacker_max_hp = attacker_base_hp + attacker.base_up_hp
var attacker_current_hp = card_data.get("current_hp", attacker_max_hp)

var defender_max_hp = defender_base_hp + defender.base_up_hp
var defender_current_hp = defender_creature.get("current_hp", defender_max_hp)

var creature_mhp = creature_hp + creature_base_up_hp
if creature_mhp >= threshold:
	qualified_count += 1
```

### After（HPCalculator使用）

```gdscript
# ✅ 統一された計算
var attacker_max_hp = HPCalculator.calculate_max_hp(card_data)
var attacker_current_hp = HPCalculator.calculate_current_hp(card_data)

var defender_max_hp = HPCalculator.calculate_max_hp(defender_creature)
var defender_current_hp = HPCalculator.calculate_current_hp(defender_creature)

if HPCalculator.is_mhp_above_or_equal(tile.creature_data, threshold):
	qualified_count += 1
```

---

## 📁 置き換え対象ファイル

以下のファイルで `hp + base_up_hp` パターンを置き換え可能：

### 高優先度（頻繁に使用）
1. **`battle_preparation.gd`** (42行目, 78行目, 243行目等)
2. **`battle_skill_processor.gd`** (232行目, 292行目, 1087行目等)
3. **`condition_checker.gd`** (MHP条件チェック)

### 中優先度
4. **`game_flow_manager.gd`** (665行目)
5. **`land_action_helper.gd`** (407行目)
6. **`board_system_3d.gd`** (MHP計算箇所)

---

## 🎯 使用シーン別ガイド

### シーン1: 戦闘準備でのMHP計算

```gdscript
# battle_preparation.gd
func prepare_battle(...):
	# Before
	var attacker_max_hp = attacker_base_hp + attacker.base_up_hp
	var attacker_current_hp = card_data.get("current_hp", attacker_max_hp)
	
	# After
	var attacker_max_hp = HPCalculator.calculate_max_hp(card_data)
	var attacker_current_hp = HPCalculator.calculate_current_hp(card_data)
```

### シーン2: 条件付き配置数カウント

```gdscript
# battle_skill_processor.gd - apply_phase_3c_effects()
# Before
var creature_hp = tile.creature_data.get("hp", 0)
var creature_base_up_hp = tile.creature_data.get("base_up_hp", 0)
var creature_mhp = creature_hp + creature_base_up_hp
if creature_mhp >= threshold:
	qualified_count += 1

# After
if HPCalculator.is_mhp_above_or_equal(tile.creature_data, threshold):
	qualified_count += 1
```

### シーン3: 無効化スキルのMHPチェック

```gdscript
# condition_checker.gd
# Before
var target_hp = target_data.get("hp", 0)
var target_base_up_hp = target_data.get("base_up_hp", 0)
var target_mhp = target_hp + target_base_up_hp
if target_mhp <= value:
	return true

# After
return HPCalculator.is_mhp_below_or_equal(target_data, value)
```

### シーン4: ブラッドプリンのMHP吸収

```gdscript
# battle_preparation.gd - apply_item_effects()
# Before
var assist_base_hp = item_data.get("hp", 0)
var assist_base_up_hp = item_data.get("base_up_hp", 0)
var assist_mhp = assist_base_hp + assist_base_up_hp

var blood_purin_base_hp = participant.creature_data.get("hp", 0)
var blood_purin_base_up_hp = participant.creature_data.get("base_up_hp", 0)
var current_mhp = blood_purin_base_hp + blood_purin_base_up_hp

# After
var assist_mhp = HPCalculator.calculate_max_hp(item_data)
var current_mhp = HPCalculator.calculate_max_hp(participant.creature_data)
```

---

## ⚠️ 注意事項

### JSONデータ構造

HPCalculatorは以下のフィールドを期待します：

```json
{
  "hp": 30,              // 必須: 基本HP
  "base_up_hp": 0,       // オプション: 永続バフ（デフォルト0）
  "current_hp": 25       // オプション: 現在HP（デフォルトはMHP）
}
```

### 互換性

- **既存コードとの共存**: 段階的な置き換えが可能
- **後方互換性**: `get()` でデフォルト値を使用し、エラーを回避

### パフォーマンス

- **オーバーヘッド**: 関数呼び出しによる微小なオーバーヘッドあり
- **影響**: 戦闘処理は数十回/秒のため、実用上問題なし

---

## 🚀 段階的な導入計画

### Phase 1: 新規コード（完了）
- ✅ HPCalculatorクラスの作成
- ✅ ドキュメント作成

### Phase 2: 高優先度ファイルの置き換え（次のステップ）
- [ ] `battle_preparation.gd`
- [ ] `battle_skill_processor.gd`
- [ ] `condition_checker.gd`

### Phase 3: 中優先度ファイルの置き換え
- [ ] `game_flow_manager.gd`
- [ ] `land_action_helper.gd`
- [ ] その他のファイル

### Phase 4: レビューとテスト
- [ ] 全機能の動作確認
- [ ] パフォーマンステスト
- [ ] エッジケースの検証

---

## 📈 期待効果

### コード削減
- **削減行数**: 約50-70行（重複計算の削減）
- **重複率削減**: 35% → 5%

### メンテナンス性
- **修正箇所**: 50箇所 → 1箇所
- **バグリスク**: 大幅減少

### 可読性
- **意図の明確化**: 計算式よりも関数名で意図が伝わる
- **デバッグ容易性**: `get_hp_debug_string()` で一目瞭然

---

## 🔍 検証方法

### 単体テスト例

```gdscript
func test_hp_calculator():
	var test_data = {
		"hp": 30,
		"base_up_hp": 10,
		"current_hp": 25
	}
	
	assert(HPCalculator.calculate_max_hp(test_data) == 40, "MHP計算")
	assert(HPCalculator.calculate_current_hp(test_data) == 25, "現在HP")
	assert(HPCalculator.is_damaged(test_data), "ダメージチェック")
	assert(HPCalculator.is_mhp_above_or_equal(test_data, 40), "MHP閾値")
	
	print("✅ HPCalculator全テスト通過")
```

---

**最終更新**: 2025-10-30  
**バージョン**: 1.0
