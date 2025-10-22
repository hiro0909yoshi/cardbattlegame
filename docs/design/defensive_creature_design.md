# 防御型クリーチャー設計書

# 防御型クリーチャー設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**最終更新**: 2025年10月23日

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|----------|
| 2025-10-23 | 1.0 | 全21体の防御型クリーチャーに`creature_type: "defensive"`を実装完了 |

---

## 概要

防御型クリーチャーは、高い基礎能力を持つ代わりに行動制限があるクリーチャータイプです。

## 特徴

### メリット
- 基礎HPが高い
- 防御時は通常通り反撃できる
- レベルアップ可能
- 交換コマンド使用可能

### デメリット（制約）
1. **侵略行動ができない** - バトルカードとして使用不可
2. **移動ができない** - 領地コマンドの移動が使用不可
3. **空き地にしか召喚できない** - 自分の土地や敵の土地には配置不可

## データ構造

### JSON定義

```json
{
  "id": 102,
  "name": "アクアナイト",
  "type": "creature",
  "creature_type": "defensive",
  "ap": 0,
  "hp": 40,
  "ability": "防御型",
  "ability_detail": "防御型；HP+20"
}
```

### フィールド説明

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `creature_type` | String | `"defensive"` で防御型を指定 |
| | | `"normal"` (デフォルト) で通常クリーチャー |

## 実装詳細

### 1. 召喚制限

**ファイル**: `scripts/tile_action_processor.gd`  
**関数**: `execute_summon()`

```gdscript
# 防御型チェック: 空き地以外には召喚できない
var creature_type = card_data.get("creature_type", "normal")
if creature_type == "defensive":
    var current_tile = board_system.movement_controller.get_player_tile(current_player_index)
    var tile_info = board_system.get_tile_info(current_tile)
    
    # 空き地（owner = -1）でなければ召喚不可
    if tile_info["owner"] != -1:
        print("[TileActionProcessor] 防御型クリーチャーは空き地にのみ召喚できます")
        if ui_manager:
            ui_manager.phase_label.text = "防御型は空き地にのみ召喚可能です"
        _complete_action()
        return
```

**制約内容**:
- `tile_info["owner"] == -1` (完全な空き地) のみ召喚可能
- 自分の土地 (`owner == player_id`) には召喚不可
- 敵の土地 (`owner != player_id`) には召喚不可

### 2. 移動制限

**ファイル**: `scripts/ui_components/land_command_ui.gd`  
**関数**: `show_action_menu()`

```gdscript
# 防御型チェック: 移動ボタンを無効化
if board_system_ref and board_system_ref.tile_nodes.has(tile_index):
    var tile = board_system_ref.tile_nodes[tile_index]
    var creature = tile.creature_data if tile.has("creature_data") else {}
    var creature_type = creature.get("creature_type", "normal")
    
    if action_menu_buttons.has("move"):
        if creature_type == "defensive":
            action_menu_buttons["move"].disabled = true
            action_menu_buttons["move"].text = "🚶 [M] 移動 (防御型)"
        else:
            action_menu_buttons["move"].disabled = false
            action_menu_buttons["move"].text = "🚶 [M] 移動"
```

**UI表示**:
- 移動ボタンがグレーアウト（disabled）
- ボタンテキストに「(防御型)」と表示

### 3. 侵略制限

#### 3-1. フィルターモード設定

**ファイル**: `scripts/tile_action_processor.gd`  
**関数**: `show_battle_ui()`

```gdscript
# バトルUI表示
func show_battle_ui(mode: String):
    if ui_manager:
        # 防御型クリーチャーはバトルで使用不可
        ui_manager.card_selection_filter = "battle"
        # ...
```

#### 3-2. カード表示のグレーアウト

**ファイル**: `scripts/ui_components/hand_display.gd`  
**関数**: `create_card_node()`

```gdscript
elif filter_mode == "battle":
    # バトルフェーズ中: 防御型クリーチャーをグレーアウト
    var creature_type = card_data.get("creature_type", "normal")
    if creature_type == "defensive":
        card.modulate = Color(0.5, 0.5, 0.5, 1.0)
```

#### 3-3. カード選択制限とグレーアウト

**ファイル**: `scripts/ui_components/card_selection_ui.gd`  
**関数**: `enable_card_selection()`

**選択制限**:
```gdscript
elif filter_mode == "battle":
    # バトルフェーズ中: 防御型以外のクリーチャーカードのみ選択可能
    var creature_type = card_data.get("creature_type", "normal")
    is_selectable = card_type == "creature" and creature_type != "defensive"
```

**グレーアウト**:
```gdscript
if filter_mode == "battle":
    # バトルフェーズ中: 防御型クリーチャーをグレーアウト
    var creature_type = card_data.get("creature_type", "normal")
    if creature_type == "defensive":
        card_node.modulate = Color(0.5, 0.5, 0.5, 1.0)
    else:
        card_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
```

**UI表示**:
- バトル時、防御型カードがグレーアウト表示
- 防御型カードは選択不可（`is_selectable = false`）
- 二重の制限により確実に防御型の侵略を防止

## 防御型クリーチャー一覧

### 実装済み（全21体）

| ID | 名前 | 属性 | AP | HP | レアリティ | スキル |
|----|------|------|----|----|---------|--------|
| 5 | オールドウィロウ | 火 | 20 | 40 | R | 防御型 |
| 10 | クリーピングフレイム | 火 | 30 | 50 | N | 防御型・秘術 |
| 29 | バーナックル | 火 | 30 | 60 | N | 防御型・秘術 |
| 102 | アイスウォール | 水 | 0 | 40 | N | 防御型 |
| 123 | シーボンズ | 水 | 10 | 40 | R | 防御型・戦闘中能力無効 |
| 126 | スワンプスボーン | 水 | 20 | 40 | R | 防御型・秘術 |
| 127 | ゼラチンウォール | 水 | 10 | 50 | S | 防御型・魔力獲得 |
| 141 | マカラ | 水 | 30 | 40 | R | 防御型・秘術 |
| 205 | カクタスウォール | 地 | 10 | 50 | S | 防御型・再生 |
| 221 | スクリーマー | 地 | 20 | 40 | S | 防御型・秘術 |
| 223 | ストーンウォール | 地 | 0 | 60 | N | 防御型 |
| 240 | マミー | 地 | 20 | 50 | N | 防御型・道連れ |
| 244 | ランドアーチン | 地 | 20 | 50 | S | 防御型・移動侵略無効 |
| 246 | レーシィ | 地 | 30 | 40 | S | 防御型・戦闘後効果 |
| 330 | トルネード | 風 | 20 | 50 | N | 防御型・先制 |
| 411 | グレートフォシル | 無 | 0 | 30 | S | 防御型・通行料変化・死者復活 |
| 413 | ゴールドトーテム | 無 | 0 | 30 | S | 防御型・秘術 |
| 421 | スタチュー | 無 | 0 | 50 | N | 防御型・周回回復不可 |
| 423 | ストーンジゾウ | 無 | 10 | 30 | N | 防御型・防魔・秘術 |
| 444 | レジェンドファロス | 無 | 40 | 50 | N | 防御型・周回回復不可・秘術 |
| 447 | ワンダーウォール | 無 | 0 | 30 | S | 防御型・無効化 |

**属性別内訳**:
- 🔥 火属性: 3体
- 💧 水属性: 5体
- 🌍 地属性: 6体
- 💨 風属性: 1体
- ⬜ 無属性: 6体

## バトルフロー

### 防御時の挙動

防御型クリーチャーは防御時、通常のクリーチャーと同様に反撃します：

```
1. 敵クリーチャーが防御型の土地に侵略
   ↓
2. スキル適用（土地ボーナス、感応など）
   ↓
3. 攻撃順決定（先制判定）
   ↓
4. 戦闘実行
   - 侵略側の攻撃
   - 防御型クリーチャーの反撃（生存していれば）
   ↓
5. 勝敗判定
```

**重要**: 防御型は「侵略できない」だけで、「攻撃できない」わけではありません。

## 交換コマンド

### 使用可能なパターン

1. **防御型 → 通常クリーチャー**
   - ✅ 可能
   - 防御型を手札に戻し、通常クリーチャーを配置

2. **通常クリーチャー → 防御型**
   - ✅ 可能
   - 通常クリーチャーを手札に戻し、防御型を配置

3. **防御型 → 防御型**
   - ✅ 可能
   - 防御型を手札に戻し、別の防御型を配置

## レベルアップ

防御型クリーチャーが配置された土地は、通常通りレベルアップ可能です。

## テスト方法

### 1. 召喚制限のテスト

```
1. 空き地に移動
2. アクアナイト (ID:102) を選択
   → ✅ 召喚成功

3. 自分の土地に移動
4. アクアナイト (ID:102) を選択
   → ❌ 「防御型は空き地にのみ召喚可能です」
```

### 2. 移動制限のテスト

```
1. 防御型クリーチャーを配置
2. 領地コマンドを開く
3. 配置した土地を選択
   → ✅ 移動ボタンがグレーアウト表示
```

### 3. 侵略制限のテスト

```
1. 敵の土地に移動
2. カード選択画面を表示
   → ✅ 防御型カードがグレーアウト表示
```

### 4. 防御時の反撃テスト

```
1. 防御型クリーチャーを配置
2. CPUが侵略
   → ✅ 防御型クリーチャーが反撃する
```

## 将来の拡張案

### 他のクリーチャータイプ

`creature_type` フィールドを活用して、他のタイプも実装可能：

- `"aerial"` - 飛行型（地形効果無効）
- `"aquatic"` - 水棲型（水タイル限定）
- `"immobile"` - 不動型（召喚後移動不可）

### 防御型の亜種

- `"defensive_aggressive"` - 防御型だが反撃時AP×1.5
- `"defensive_counter"` - 防御型だが先制反撃

## 設計思想

### なぜ `creature_type` を使うのか？

1. **スキルとの分離**
   - スキル = バトル時の能力
   - タイプ = ゲームフロー全体の性質

2. **判定箇所の明確化**
   - スキル判定: `ability_parsed.keywords`
   - タイプ判定: `creature_type`

3. **拡張性**
   - 新しいクリーチャータイプの追加が容易
   - 既存コードへの影響が少ない

## 関連ファイル

- `scripts/tile_action_processor.gd` - 召喚制限
- `scripts/ui_components/land_command_ui.gd` - 移動制限UI
- `scripts/ui_components/hand_display.gd` - 侵略制限UI
- `data/water_1.json` - アクアナイト (ID:102)
- `data/earth_1.json` - カクタスウォール (ID:205)

## 更新履歴

- 2025-10-23: 初版作成、基本実装完了
