# SkillSystem 拡張性向上 - リファクタリング計画

## 概要
SkillSystem.gd のバフ管理を動的なデータ構造に変更し、新しいバフ種類追加時の保守性を向上させる計画。

---

## 1. 現状の問題点

### 1.1 バフの硬直化
現在のバフ管理は固定フィールド方式：

```gdscript
player_buffs[player_id] = {
	"card_cost_reduction": 0,
	"dice_bonus": 0,
	"toll_multiplier": 1.0,
	"draw_bonus": 0,
	"magic_income_bonus": 0,
	"battle_st_bonus": 0,
	"battle_hp_bonus": 0
}
```

### 1.2 新バフ追加時の修正範囲
新しいバフ種類を追加する場合、複数箇所を修正が必要：

```gdscript
# 1. initialize_player_buffs() に追加
"new_buff_type": 0,

# 2. apply_buff() の match文に追加
"new_buff":
	player_buffs[player_id].new_buff += value

# 3. apply_debuff() で自動的に対応（呼び出し側で調整可能）

# 4. modify_* メソッドで参照
modified_value += player_buffs[player_id].new_buff
```

### 1.3 拡張性の課題
- バフが 8種類でも修正箇所が分散
- 将来的にバフが数十種類に増える可能性
- 新バフ追加時のバグリスク増加

---

## 2. 推奨される解決方針：動的バフ配列方式

### 2.1 新しいバフ構造

```gdscript
# Before: 固定フィールド
player_buffs[player_id] = {
	"card_cost_reduction": 0,
	"dice_bonus": 0,
	...
}

# After: 動的配列
player_buffs[player_id] = [
	{
		"type": "card_cost_reduction",
		"value": 10,
		"duration": -1  # -1 = 無制限
	},
	{
		"type": "dice_bonus",
		"value": 2,
		"duration": 3   # 3ターン
	},
	...
]
```

### 2.2 バフオブジェクトの仕様

```gdscript
# バフ辞書の標準フォーマット
{
	"type": String,           # バフの種類（"card_cost_reduction" など）
	"value": int or float,    # バフの値
	"duration": int           # 持続ターン数（-1 = 無制限）
}
```

### 2.3 バフ種類一覧

| # | type | value型 | 説明 |
|----|------|---------|------|
| 1 | card_cost_reduction | int | カードコスト削減 |
| 2 | dice_bonus | int | ダイス目ボーナス |
| 3 | toll_multiplier | float | 通行料倍率 |
| 4 | draw_bonus | int | ドロー枚数ボーナス |
| 5 | magic_income_bonus | int | 魔力獲得ボーナス |
| 6 | battle_st_bonus | int | バトルAP（攻撃力）ボーナス |
| 7 | battle_hp_bonus | int | バトルHP（防御力）ボーナス |

---

## 3. 実装ステップ

### 3.1 【ステップ1】initialize_player_buffs() を修正

```gdscript
# Before
func initialize_player_buffs():
	for i in range(4):
		player_buffs[i] = {
			"card_cost_reduction": 0,
			"dice_bonus": 0,
			...
		}

# After
func initialize_player_buffs():
	for i in range(4):
		player_buffs[i] = []  # 空の配列で初期化
```

### 3.2 【ステップ2】apply_buff() を修正

```gdscript
# Before
func apply_buff(player_id: int, buff_type: String, value: int, _duration: int = -1):
	if not player_buffs.has(player_id):
		return
	
	match buff_type:
		"card_cost":
			player_buffs[player_id].card_cost_reduction += value
		"dice":
			player_buffs[player_id].dice_bonus += value
		# ... 全てのバフ

# After
func apply_buff(player_id: int, buff_type: String, value: int, duration: int = -1):
	if not player_buffs.has(player_id):
		return
	
	# バフオブジェクトを配列に追加（新規追加）
	var buff = {
		"type": buff_type,
		"value": value,
		"duration": duration
	}
	player_buffs[player_id].append(buff)
	
	emit_signal("buff_applied", str(player_id), buff_type, value)
	print("バフ適用: プレイヤー", player_id + 1, " - ", buff_type, " +", value)
```

### 3.3 【ステップ3】計算メソッドを修正

各 modify_* メソッドで、バフ配列をループして計算：

```gdscript
# Before: 直接フィールド参照
func modify_card_cost(base_cost: int, card_data: Dictionary, player_id: int) -> int:
	var modified_cost = base_cost
	if player_buffs.has(player_id):
		modified_cost -= player_buffs[player_id].card_cost_reduction  # 直接参照
	return max(0, modified_cost)

# After: バフ配列から合計を計算
func modify_card_cost(base_cost: int, card_data: Dictionary, player_id: int) -> int:
	var modified_cost = base_cost
	
	if player_buffs.has(player_id):
		# バフ配列から card_cost_reduction の合計を計算
		var total_reduction = _calculate_buff_total(player_id, "card_cost_reduction")
		modified_cost -= total_reduction
	
	return max(0, modified_cost)

# 新しいヘルパーメソッド
func _calculate_buff_total(player_id: int, buff_type: String) -> float:
	var total = 0.0
	for buff in player_buffs[player_id]:
		if buff["type"] == buff_type:
			total += buff["value"]
	return total
```

### 3.4 【ステップ4】全 modify_* メソッドの更新

以下のメソッド内で `_calculate_buff_total()` を使用：

- `modify_card_cost()` → "card_cost_reduction" を計算
- `modify_dice_roll()` → "dice_bonus" を計算
- `modify_toll()` → "toll_multiplier" を計算
- `modify_draw_count()` → "draw_bonus" を計算
- `modify_creature_stats()` → "battle_st_bonus", "battle_hp_bonus" を計算

### 3.5 【ステップ5】持続時間管理（オプション）

```gdscript
# end_turn_cleanup() を拡張
func end_turn_cleanup():
	for player_id in player_buffs.keys():
		var buffs = player_buffs[player_id]
		var remaining_buffs = []
		
		for buff in buffs:
			# 持続時間を減少
			if buff["duration"] > 0:
				buff["duration"] -= 1
				if buff["duration"] > 0:
					remaining_buffs.append(buff)
				else:
					print("バフ終了: ", buff["type"])
			elif buff["duration"] == -1:
				# 無制限は保持
				remaining_buffs.append(buff)
		
		player_buffs[player_id] = remaining_buffs
```

---

## 4. 影響範囲

### 4.1 修正が必要なファイル

| ファイル | 修正内容 | 修正行数 |
|---------|---------|---------|
| scripts/skill_system.gd | 主要リファクタリング | ~60行 |
| scripts/flow_handlers/cpu_ai_handler.gd | modify_card_cost() の呼び出し確認 | ~0行（変更なし） |
| scripts/game_flow_manager.gd | modify_dice_roll() の呼び出し確認 | ~0行（変更なし） |

### 4.2 呼び出し側への影響

✅ **影響なし** - 外部インターフェース（メソッド署名）は変わらない

```gdscript
# 呼び出し側は変更不要
var modified_cost = skill_system.modify_card_cost(100, card_data, player_id)
var modified_roll = skill_system.modify_dice_roll(6, player_id)
```

### 4.3 注意点

- `apply_buff()` は現在ほぼ呼ばれていないが、署名は維持
- `apply_debuff()` も自動的に対応

---

## 5. 利点と期待効果

### 5.1 拡張性の向上

**新バフ追加時のコスト削減**

Before（現状）:
```
新バフ追加時の修正:
  1. initialize_player_buffs() に1行追加
  2. apply_buff() の match文に3行追加
  3. 呼び出し側で _calculate_buff_total() 追加
  合計: 5-10箇所の修正
```

After（リファクタリング後）:
```
新バフ追加時の修正:
  1. modify_* メソッド内で _calculate_buff_total(player_id, "new_buff_type") を呼び出す
  合計: 1-2箇所の修正
```

### 5.2 動的なバフ管理が可能

```gdscript
# 同じバフタイプの複数効果も管理可能
player_buffs[0] = [
	{"type": "card_cost_reduction", "value": 10, "duration": -1},  # 永続
	{"type": "card_cost_reduction", "value": 5, "duration": 3},    # 3ターン
	# 合計: 15のコスト削減
]
```

### 5.3 バグリスク削減

- match文のケース漏れがない
- 新バフ追加時の誤り削減

---

## 6. テスト計画

### 6.1 単体テスト（推奨）

```gdscript
# 既存機能の動作確認
- modify_card_cost() が正しく計算される
- modify_dice_roll() が正しく計算される
- apply_buff() でバフが配列に追加される
- 複数バフの合計が正しく計算される

# エッジケース
- バフが空の場合の計算
- 負の値を持つバフ
- duration = 0 の場合
```

### 6.2 統合テスト

```gdscript
- ゲーム内でカードコスト削減が機能する
- ダイス目ボーナスが適用される
- ターン終了時にバフが正しく消滅する
```

---

## 7. 実装スケジュール

| 段階 | 内容 | 推定時間 |
|------|------|---------|
| 1 | initialize_player_buffs() 修正 | 5分 |
| 2 | apply_buff() 修正 | 10分 |
| 3 | _calculate_buff_total() 実装 | 10分 |
| 4 | 全 modify_* メソッド更新 | 20分 |
| 5 | テストと動作確認 | 15分 |
| **合計** | | **60分（約1時間）** |

---

## 8. 実装後のコード例

### 修正前後の比較

**Before:**
```gdscript
player_buffs[0] = {
	"card_cost_reduction": 15,
	"dice_bonus": 2,
	...
}
```

**After:**
```gdscript
player_buffs[0] = [
	{"type": "card_cost_reduction", "value": 10, "duration": -1},
	{"type": "card_cost_reduction", "value": 5, "duration": 3},
	{"type": "dice_bonus", "value": 2, "duration": -1},
]
```

計算結果は同じ（合計値で計算）だが、**バフの動的管理が可能**。

---

## 9. 将来への拡張可能性

このリファクタリング後は以下が容易に実装可能：

1. **バフの優先度管理** - 複数バフの相互作用
2. **バフの可視化** - UI で現在のバフ一覧表示
3. **条件付きバフ** - 特定条件下でのみ有効なバフ
4. **バフの複合効果** - 複数バフの組み合わせ効果

---

## 10. 結論

**リファクタリング実施すべき** ✅

理由：
- 修正範囲が小さい（SkillSystem.gd 内のみ）
- 拡張性が大幅に向上
- 将来のメンテナンスコスト削減
- 実装時間が短い（1時間以内）
- リスクが低い（既存呼び出しに影響なし）
