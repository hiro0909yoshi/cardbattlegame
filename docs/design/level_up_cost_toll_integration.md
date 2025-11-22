# レベルアップコスト・通行料統合設計書

**バージョン**: 2.0  
**作成日**: 2025年11月23日  
**ステータス**: 設計確定

---

## 📋 目次

1. [概要](#概要)
2. [新設計方針](#新設計方針)
3. [計算式の統一](#計算式の統一)
4. [レベルアップコストの計算方法](#レベルアップコストの計算方法)
5. [実装箇所の整理](#実装箇所の整理)
6. [修正計画](#修正計画)
7. [実装タイムライン](#実装タイムライン)

---

## 概要

レベルアップコストを**通行料システムから動的に計算する**ように統合する設計。

**目標**：
```
レベルアップコスト(Lv X) = 通行料計算(連鎖ボーナス=1.5)
                          = 100 × 属性係数 × レベル係数[X] × 1.5 × マップ係数
                          → 10の位で切り捨て
```

**現在の問題**：
- レベルアップコストが ハードコーディング（Lv.2: 80, Lv.3: 240, Lv.4: 620, Lv.5: 1200）
- マップごとの差分が反映されていない
- 通行料システムとの関係が不明確

**新設計のメリット**：
- ✅ 通行料から動的に計算
- ✅ マップごとに自動変更
- ✅ 単一の計算式で管理
- ✅ バランス調整が容易

---

## 新設計方針

### 通行料 × 連鎖2 = レベルアップコスト

```
┌─────────────────────────────────────────────────────┐
│ レベルアップコスト計算                              │
├─────────────────────────────────────────────────────┤
│                                                      │
│ コスト = floor_toll(                               │
│   100 × 属性係数[tile.element]                    │
│       × レベル係数[target_level]                   │
│       × 連鎖ボーナス(2個 = 1.5)  ← 固定値         │
│       × マップ係数[current_map]                    │
│ )                                                   │
│                                                      │
│ ※ 10の位で切り捨て（floor_toll使用）              │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 具体例（基準マップmap_1、火属性タイル）

```
属性係数: 1.0（火）
レベル係数: Lv.3 = 1.5
連鎖ボーナス: 1.5（固定）
マップ係数: 1.0（map_1）

Lv.3へのアップグレード:
100 × 1.0 × 1.5 × 1.5 × 1.0 = 225
→ 切り捨て → 220G

Lv.4へのアップグレード:
100 × 1.0 × 2.0 × 1.5 × 1.0 = 300
→ 切り捨て → 300G

Lv.5へのアップグレード:
100 × 1.0 × 2.5 × 1.5 × 1.0 = 375
→ 切り捨て → 370G
```

**マップ係数の影響**（Map2: 0.8、Map3: 1.2）

```
Map2（20%安）:
Lv.3: 100 × 1.0 × 1.5 × 1.5 × 0.8 = 180 → 180G
Lv.4: 100 × 1.0 × 2.0 × 1.5 × 0.8 = 240 → 240G

Map3（20%高）:
Lv.3: 100 × 1.0 × 1.5 × 1.5 × 1.2 = 270 → 270G
Lv.4: 100 × 1.0 × 2.0 × 1.5 × 1.2 = 360 → 360G
```

---

## 計算式の統一

### 通行料計算（既存）

```gdscript
func calculate_toll(tile_index: int, map_id: String = "") -> int:
	var base = GameConstants.TOLL_BASE_AMOUNT  # 100
	var element_mult = GameConstants.TOLL_ELEMENT_MULTIPLIER.get(tile.tile_type, 1.0)
	var level_mult = GameConstants.TOLL_LEVEL_MULTIPLIER.get(tile.level, 1.0)
	var chain_bonus = calculate_chain_bonus(tile_index, tile.owner_id)
	var map_mult = GameConstants.TOLL_MAP_MULTIPLIER.get(map_id, 1.0)
	
	var raw_toll = base * element_mult * level_mult * chain_bonus * map_mult
	return GameConstants.floor_toll(raw_toll)  # 10の位で切り捨て
```

### レベルアップコスト計算（新規）

```gdscript
func calculate_level_up_cost(tile_index: int, target_level: int, map_id: String = "") -> int:
	var base = GameConstants.TOLL_BASE_AMOUNT  # 100
	var tile = tile_nodes[tile_index]
	var element_mult = GameConstants.TOLL_ELEMENT_MULTIPLIER.get(tile.tile_type, 1.0)
	var level_mult = GameConstants.TOLL_LEVEL_MULTIPLIER.get(target_level, 1.0)
	var chain_bonus = 1.5  # 固定値（連鎖2個）
	var map_mult = GameConstants.TOLL_MAP_MULTIPLIER.get(map_id, 1.0)
	
	var raw_cost = base * element_mult * level_mult * chain_bonus * map_mult
	return GameConstants.floor_toll(raw_cost)  # 10の位で切り捨て
```

**重要な違い**：
- 通行料: 実際のタイルの連鎖ボーナスを使用
- レベルアップコスト: 固定値1.5（連鎖2個相当）を常に使用

---

## レベルアップコストの計算方法

### 現在の実装（ハードコード）

```gdscript
# land_command_ui.gd（183, 238, 315行）
var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}
```

### 新しい実装（動的計算）

**1. TileDataManager に新しいメソッドを追加**

```gdscript
func calculate_level_up_cost(tile_index: int, target_level: int, map_id: String = "") -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	if target_level < 2 or target_level > GameConstants.MAX_LEVEL:
		return 0
	
	var base = GameConstants.TOLL_BASE_AMOUNT
	var tile = tile_nodes[tile_index]
	var element_mult = GameConstants.TOLL_ELEMENT_MULTIPLIER.get(tile.tile_type, 1.0)
	var level_mult = GameConstants.TOLL_LEVEL_MULTIPLIER.get(target_level, 1.0)
	var chain_bonus = 1.5  # 連鎖2個（固定）
	var map_mult = 1.0
	
	if map_id != "" and GameConstants.TOLL_MAP_MULTIPLIER.has(map_id):
		map_mult = GameConstants.TOLL_MAP_MULTIPLIER[map_id]
	
	var raw_cost = base * element_mult * level_mult * chain_bonus * map_mult
	return GameConstants.floor_toll(raw_cost)
```

**2. land_command_ui.gd から呼び出す**

```gdscript
func _calculate_level_up_cost(tile_index: int, from_level: int, to_level: int, map_id: String = "") -> int:
	# TileDataManagerから計算結果を取得
	return board_system_ref.tile_data_manager.calculate_level_up_cost(tile_index, to_level, map_id)
```

---

## 実装箇所の整理

### 現在の散在箇所

```
1️⃣  land_command_ui.gd（3箇所）
    ├─ show_level_selection() - line 183
    │  var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}
    ├─ create_level_selection_panel() - line 238
    │  var level_costs = {2: 80, 3: 240, 4: 620, 5: 1200}
    └─ _calculate_level_up_cost() - line 315
       var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}

2️⃣  GameConstants.gd
    └─ LEVEL_VALUES: 累積値 {1:0, 2:80, 3:340, 4:960, 5:2160}
```

### 修正後の集約

```
1️⃣  TileDataManager.gd（新規）
    └─ calculate_level_up_cost(tile_index, target_level, map_id)
       → 通行料計算式を使用して動的に計算

2️⃣  land_command_ui.gd（修正）
    ├─ show_level_selection()
    │  → board_system_ref.tile_data_manager.calculate_level_up_cost() を呼び出す
    ├─ create_level_selection_panel()
    │  → 同上
    └─ _calculate_level_up_cost()
       → 同上

3️⃣  GameConstants.gd
    ├─ TOLL_BASE_AMOUNT: 100
    ├─ TOLL_ELEMENT_MULTIPLIER: {...}
    ├─ TOLL_LEVEL_MULTIPLIER: {...}
    ├─ TOLL_MAP_MULTIPLIER: {...}
    └─ floor_toll(): 10の位で切り捨て関数
```

---

## 注意事項（通行料支払い一本化による変更）

### 2025/11/23 アップデート

**バトルシステムからの支払い処理削除**:
- `battle_system.gd` の `pay_toll_3d()` を削除予定
- バトル結果（敗北）後の支払いは `tile_action_processor.gd` に一本化
- レベルアップコストの計算ロジックは変更なし

**対象外**:
- このドキュメント（level_up_cost_toll_integration.md）の内容は変更なし
- レベルアップコスト計算は支払い処理とは独立

---

## 修正計画

### Phase 1: GameConstants の拡張（確認・追加）

**既存の定数を確認**
```gdscript
const TOLL_BASE_AMOUNT = 100
const TOLL_ELEMENT_MULTIPLIER = {
	"fire": 1.0,
	"water": 1.0,
	"wind": 1.0,
	"earth": 1.0,
	"none": 0.8
}
const TOLL_LEVEL_MULTIPLIER = {
	1: 1.0,
	2: 1.2,
	3: 1.5,
	4: 2.0,
	5: 2.5
}
const TOLL_MAP_MULTIPLIER = {
	# マップ係数を決定時に追加
}

# ユーティリティ関数
static func floor_toll(amount: float) -> int:
	return int(floor(amount / 10.0) * 10.0)
```

### Phase 2: TileDataManager.gd に calculate_level_up_cost() を追加

```gdscript
func calculate_level_up_cost(tile_index: int, target_level: int, map_id: String = "") -> int:
	if not tile_nodes.has(tile_index):
		return 0
	
	if target_level < 2 or target_level > GameConstants.MAX_LEVEL:
		return 0
	
	var base = GameConstants.TOLL_BASE_AMOUNT
	var tile = tile_nodes[tile_index]
	var element_mult = GameConstants.TOLL_ELEMENT_MULTIPLIER.get(tile.tile_type, 1.0)
	var level_mult = GameConstants.TOLL_LEVEL_MULTIPLIER.get(target_level, 1.0)
	var chain_bonus = 1.5  # 連鎖2個（固定）
	var map_mult = 1.0
	
	if map_id != "" and GameConstants.TOLL_MAP_MULTIPLIER.has(map_id):
		map_mult = GameConstants.TOLL_MAP_MULTIPLIER[map_id]
	
	var raw_cost = base * element_mult * level_mult * chain_bonus * map_mult
	return GameConstants.floor_toll(raw_cost)
```

### Phase 3: land_command_ui.gd を修正

**show_level_selection() - 183行**
```gdscript
func show_level_selection(tile_index: int, current_level: int, player_magic: int):
	selected_tile_for_action = tile_index
	
	if action_menu_panel:
		action_menu_panel.visible = false
	
	if current_level_label:
		current_level_label.text = "現在: Lv.%d" % current_level
	
	for level in [2, 3, 4, 5]:
		if level <= current_level:
			if level_selection_buttons.has(level):
				level_selection_buttons[level].disabled = true
		else:
			# TileDataManager から計算
			var cost = board_system_ref.tile_data_manager.calculate_level_up_cost(tile_index, level)
			var next_cost = board_system_ref.tile_data_manager.calculate_level_up_cost(tile_index, level) if level > current_level else 0
			
			# 現在レベルからの差分を計算
			var current_cost = board_system_ref.tile_data_manager.calculate_level_up_cost(tile_index, current_level) if current_level > 1 else 0
			var diff_cost = next_cost - current_cost
			
			if player_magic >= diff_cost:
				if level_selection_buttons.has(level):
					level_selection_buttons[level].disabled = false
					level_selection_buttons[level].text = "Lv.%d → %dG" % [level, diff_cost]
			else:
				if level_selection_buttons.has(level):
					level_selection_buttons[level].disabled = true
					level_selection_buttons[level].text = "Lv.%d → %dG (不足)" % [level, diff_cost]
```

**create_level_selection_panel() - 238行**
```gdscript
func create_level_selection_panel(parent: Node):
	# ... パネル作成部分は既存のまま ...
	
	for level in [2, 3, 4, 5]:
		var btn = _create_level_button(level, 0, Vector2(10, button_y))
		btn.pressed.connect(_on_level_selected.bind(level))
		level_selection_panel.add_child(btn)
		level_selection_buttons[level] = btn
		button_y += 65 + button_spacing
```

**_calculate_level_up_cost() - 315行**
```gdscript
func _calculate_level_up_cost(tile_index: int, from_level: int, to_level: int) -> int:
	# TileDataManager から計算結果を取得
	if board_system_ref and board_system_ref.tile_data_manager:
		var to_cost = board_system_ref.tile_data_manager.calculate_level_up_cost(tile_index, to_level)
		var from_cost = board_system_ref.tile_data_manager.calculate_level_up_cost(tile_index, from_level) if from_level > 1 else 0
		return to_cost - from_cost
	return 0
```

---

## 実装タイムライン

### Step 1: GameConstants の確認・追加（15分）
- [ ] TOLL_* 定数が既に定義されているか確認
- [ ] floor_toll() 関数が実装されているか確認
- [ ] TOLL_MAP_MULTIPLIER にマップを追加（後で）

### Step 2: TileDataManager.gd に calculate_level_up_cost() を追加（30分）
- [ ] メソッドの実装
- [ ] テスト: 各レベル・各属性・各マップでの計算結果を検証

### Step 3: land_command_ui.gd を修正（1時間）
- [ ] show_level_selection() を修正
- [ ] create_level_selection_panel() を修正
- [ ] _calculate_level_up_cost() を修正
- [ ] テスト: UI表示が正しいか確認

### Step 4: TileActionProcessor.gd の確認（15分）
- [ ] on_level_up_selected() が正しく動作するか確認（修正不要の可能性が高い）

### Step 5: 統合テスト（30分）
- [ ] 各タイルでレベルアップが正しく計算されるか
- [ ] マップごとに コストが異なるか
- [ ] 属性ごとにコストが異なるか
- [ ] 10の位で正しく切り捨てられているか

---

## チェックリスト

### 実装前の確認
- [ ] GameConstants に TOLL_* が定義されているか確認
- [ ] floor_toll() が実装されているか確認
- [ ] 現在のレベルアップが正しく動作しているか確認

### 実装時の確認
- [ ] calculate_level_up_cost() の計算式が正しいか
- [ ] タイルの属性を正しく取得しているか
- [ ] マップ係数を正しく適用しているか
- [ ] 10の位で正しく切り捨てられているか

### 実装後の検証
- [ ] UI表示が変わることを確認（値が動的に計算されている）
- [ ] レベルアップコストが正確に計算されるか
- [ ] マップごとに異なる価格が表示されるか
- [ ] 無属性タイルで20%安い価格になるか

---

## 関連ドキュメント

- `docs/design/toll_system_spec.md` - 通行料システム仕様
- `docs/design/toll_system.md` - 通行料システム設計書
- `docs/refactoring/toll_system_refactoring.md` - 通行料リファクタリング計画
- `docs/design/level_up_cost_implementation_flow.md` - レベルアップコスト実装フロー

---

## 変更履歴（2025/11/23）

### アップデート: 通行料支払い処理の一本化に伴う通知

**このドキュメントへの影響**:
- ❌ レベルアップコスト計算ロジック：変更なし
- ❌ GameConstants の定数：変更なし
- ❌ TileDataManager.calculate_level_up_cost()：変更なし
- ✅ 参照情報更新：通行料支払い処理が別設計に変更されたことを記載

**参照**: 
- [toll_system_spec.md](toll_system_spec.md) v2.2
- [toll_system.md](toll_system.md) v2.2

---

**最終更新**: 2025年11月23日（修正: 支払い処理タイミング）
