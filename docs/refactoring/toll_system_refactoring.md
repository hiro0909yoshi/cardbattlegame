# 通行料システムリファクタリング計画

**バージョン**: 1.0  
**最終更新**: 2025年11月20日  
**ステータス**: 計画中

---

## 概要

現在の通行料システムの実装に基づいて、新しい仕様（土地価値＝通行料、TEPに反映）に対応させるためのリファクタリング計画です。

**参照**: `docs/design/toll_system_spec.md` - 新仕様書

---

## 実装予定機能

### Phase 1: 基盤修正（優先度：高）

#### 0. GameConstants.LEVEL_VALUES の統一化

**問題**: レベルアップコストが複数の場所にハードコーディングされている

**現状**:
- `game_constants.gd` の `LEVEL_VALUES` - 間違った値（検証用に現状のまま）
- `land_command_ui.gd` - 183行目、238行目、315行目にハードコード
  ```gdscript
  var level_costs = {0: 0, 1: 0, 2: 80, 3: 240, 4: 620, 5: 1200}
  ```
- `level_up_ui.gd` - 既に GameConstants.LEVEL_VALUES を参照（正しい）
- `tile_data_manager.gd` - get_upgrade_cost() で GameConstants.LEVEL_VALUES を参照（正しい）

**実装内容**:

1. `game_constants.gd` の LEVEL_VALUES をテスト用の誤った値のまま保持（検証目的）
2. `land_command_ui.gd` の 3箇所すべてで GameConstants.LEVEL_VALUES を参照するように修正
   - 183行目: `show_level_selection()` メソッド内
   - 238行目: `create_level_selection_panel()` メソッド内
   - 315行目: `_calculate_level_up_cost()` メソッド内

**修正後の確認方法**:
- ゲーム実行時に UI に 340, 960, 2160 が表示される → GameConstants が呼び出されている証拠
- UI に 240, 620, 1200 が表示される → GameConstants が呼び出されていない

**影響範囲**:
- レベルアップ実行時のEP消費も同時に修正される（cost パラメータが GameConstants から計算されるため）
- land_action_helper.gd の `execute_level_up_with_level()` は修正不要（cost を受け取るだけ）

---

#### 1. TEPの UI表示

**内容**: プレイヤー情報パネルにTEPを表示

**実装箇所**: `scripts/ui_manager.gd` / UIコンポーネント

**表示内容**:
```
手持ちEP: 2500G
土地価値: 1200G
TEP: 3700G ← 新規追加
```

**計算式**:
```gdscript
var total_magic = player.magic_power + tile_data_manager.calculate_total_land_value(player_id)
```

#### 2. 勝利判定の修正

**現在**: 手持ちEPで判定（不正確）

**変更**: TEPで判定

**実装箇所**: `scripts/player_system.gd` の add_magic()

**修正前**:
```gdscript
if player.magic_power >= player.target_magic:
	emit_signal("player_won", player_id)
```

**修正後**:
```gdscript
var total_magic = player.magic_power + calculate_total_land_value(player_id)
if total_magic >= player.target_magic:
	emit_signal("player_won", player_id)
```

---

### Phase 2: 土地売却機能（優先度：高）

#### 1. 売却処理の実装

**内容**: 手持ちEP不足時に土地を売却

**実装箇所**: `scripts/tile_action_processor.gd`

**売却フロー**:
```
pay_toll()で支払い不可
  ↓
土地一覧を表示
  ↓
ユーザーが売却土地を選択
  ↓
売却額 = その土地の通行料
  ↓
手持ちEP += 売却額
  ↓
土地を失う（所有者 = -1）
  ↓
通行料を支払う
```

**疑似コード**:
```gdscript
func try_pay_toll_with_sale(payer_id, receiver_id, toll_amount):
	if player.magic_power >= toll_amount:
		pay_toll(payer_id, receiver_id, toll_amount)
	else:
		# 足りない分を計算
		var shortage = toll_amount - player.magic_power
		
		# 売却可能な土地を提示
		var sellable_lands = get_sellable_lands(payer_id)
		
		# ユーザーが選択
		var selected_land = show_land_selection_ui(sellable_lands)
		
		# 売却実行
		var sale_value = calculate_toll(selected_land)
		sell_land(payer_id, selected_land, sale_value)
		
		# 改めて通行料を支払う
		pay_toll(payer_id, receiver_id, toll_amount)
```

#### 2. 売却UIの実装

**内容**: 土地選択インターフェース

**実装箇所**: UIManager / 新規Land Selection Dialog

**表示情報**:
```
売却可能な土地:
- タイル3（火属性、Lv2）→ 300G
- タイル7（水属性、Lv1）→ 100G
- タイル12（風属性、Lv3）→ 450G

選択: [Enter決定] [C:キャンセル]
```

---

### Phase 3: 呪いシステムの統合（優先度：中）

#### 1. 呪い判定の追加

**実装箇所**: `scripts/spells/spell_curse_toll.gd` （新規作成予定）

**修正対象**: `tile_data_manager.calculate_toll()`

**呪いの適用タイミング**:
```gdscript
func calculate_toll_with_curse(tile_index, payer_id, receiver_id) -> int:
	var base_toll = calculate_toll(tile_index)
	
	# 支払い側の呪いをチェック
	if spell_curse.get_player_curse(payer_id).curse_type == "toll_disable":
		return 0  # 無効化
	
	# 受け取り側の呪いをチェック
	var receiver_curse = spell_curse.get_creature_curse(tile_index)
	if receiver_curse.curse_type == "toll_multiplier":
		base_toll *= receiver_curse.params.multiplier
	elif receiver_curse.curse_type == "toll_fixed":
		base_toll = receiver_curse.params.value
	
	return base_toll
```

---

### Phase 4: 土地価値の動的更新（優先度：低）

#### 1. UI自動更新

**内容**: 土地レベルアップ時に通行料とTEPを自動更新

**実装箇所**: `scripts/ui_manager.gd`

**更新シーン**:
- 土地レベルアップ時
- クリーチャー召喚時（連鎖ボーナス変化）
- クリーチャー移動時

---

## 実装順序

```
1. TEP UI表示 (1-2時間)
   ↓
2. 勝利判定の修正 (30分)
   ↓
3. 土地売却機能 (3-4時間)
   ↓
4. 呪いシステム統合 (2-3時間)
   ↓
5. UI自動更新 (1時間)
```

---

## テスト項目

### Unit Tests

- [ ] calculate_toll()の計算が正確か
- [ ] calculate_total_land_value()の合計が正しいか
- [ ] pay_toll()でのEP移動が正確か

### Integration Tests

- [ ] 土地売却時にTEPが正しく更新されるか
- [ ] 勝利判定がTEPで行われるか
- [ ] 呪いが通行料に正しく適用されるか

### Manual Tests

- [ ] UI表示が正確か
- [ ] 売却フロー全体が機能するか
- [ ] 呪いの優先順位が正しいか

---

## 注意事項

### 1. TEP計算のパフォーマンス

**現状**: 毎回全タイルをループ

**改善案**: キャッシュの導入（タイル変更時のみ更新）

### 2. 売却判定の制限

売却不可の土地：
- スタート地点
- チェックポイント
- ワープゲート

### 3. 呪いの優先順位

支払い側の呪い > 受け取り側の呪い > 基本通行料

---

## 関連ドキュメント

- [通行料システム仕様書](toll_system_spec.md) - 新仕様確定
- [呪い効果システム](spells/呪い効果.md) - 呪いの基盤
- [通行料呪い仕様](spells/通行料呪い.md) - 通行料関連呪い

---

**最終更新**: 2025年11月20日
