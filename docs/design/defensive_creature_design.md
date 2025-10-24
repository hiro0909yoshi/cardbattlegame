# 防御型クリーチャー設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.1  
**最終更新**: 2025年10月25日

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

---

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
  "ability": "防御型"
}
```

### フィールド説明

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `creature_type` | String | `"defensive"` で防御型を指定 |
| | | `"normal"` (デフォルト) で通常クリーチャー |

---

## 実装概要

### 1. 召喚制限

**実装ファイル**: `scripts/tile_action_processor.gd` → `execute_summon()`

**制約内容**:
- `tile_info["owner"] == -1` (完全な空き地) のみ召喚可能
- 自分の土地や敵の土地には召喚不可
- 違反時はメッセージ表示: 「防御型は空き地にのみ召喚可能です」

**実装ポイント**:
```gdscript
var creature_type = card_data.get("creature_type", "normal")
if creature_type == "defensive":
    if tile_info["owner"] != -1:
        # 召喚不可
```

### 2. 移動制限

**実装ファイル**: `scripts/ui_components/land_command_ui.gd` → `show_action_menu()`

**UI表示**:
- 移動ボタンがグレーアウト（disabled）
- ボタンテキスト: "🚶 [M] 移動 (防御型)"

**実装ポイント**:
```gdscript
var creature_type = creature.get("creature_type", "normal")
if creature_type == "defensive":
    action_menu_buttons["move"].disabled = true
```

### 3. 侵略制限（バトル使用不可）

**実装ファイル**: 
- `scripts/ui_components/hand_display.gd` → `create_card_node()`
- `scripts/ui_components/card_selection_ui.gd` → `enable_card_selection()`

**UI表示**:
- バトル時、防御型カードがグレーアウト表示
- カード選択不可（`is_selectable = false`）

**実装ポイント**:
```gdscript
# hand_display.gd
if filter_mode == "battle":
    var creature_type = card_data.get("creature_type", "normal")
    if creature_type == "defensive":
        card.modulate = Color(0.5, 0.5, 0.5, 1.0)

# card_selection_ui.gd
if filter_mode == "battle":
    var creature_type = card_data.get("creature_type", "normal")
    is_selectable = card_type == "creature" and creature_type != "defensive"
```

---

## 防御型クリーチャー一覧

**実装済み（全21体）**

| ID | 名前 | 属性 |
|----|------|------|
| 5 | オールドウィロウ | 🔥 火 |
| 10 | クリーピングフレイム | 🔥 火 |
| 29 | バーナックル | 🔥 火 |
| 102 | アイスウォール | 💧 水 |
| 123 | シーボンズ | 💧 水 |
| 126 | スワンプスボーン | 💧 水 |
| 127 | ゼラチンウォール | 💧 水 |
| 141 | マカラ | 💧 水 |
| 205 | カクタスウォール | 🌍 地 |
| 221 | スクリーマー | 🌍 地 |
| 223 | ストーンウォール | 🌍 地 |
| 240 | マミー | 🌍 地 |
| 244 | ランドアーチン | 🌍 地 |
| 246 | レーシィ | 🌍 地 |
| 330 | トルネード | 💨 風 |
| 411 | グレートフォシル | ⬜ 無 |
| 413 | ゴールドトーテム | ⬜ 無 |
| 421 | スタチュー | ⬜ 無 |
| 423 | ストーンジゾウ | ⬜ 無 |
| 444 | レジェンドファロス | ⬜ 無 |
| 447 | ワンダーウォール | ⬜ 無 |

---

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

---

## 交換コマンド

### 使用可能なパターン

1. **防御型 → 通常クリーチャー**: ✅ 可能
2. **通常クリーチャー → 防御型**: ✅ 可能
3. **防御型 → 防御型**: ✅ 可能

---

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

---

## 関連ファイル

### 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/tile_action_processor.gd` | 召喚制限 |
| `scripts/ui_components/land_command_ui.gd` | 移動制限UI |
| `scripts/ui_components/hand_display.gd` | 侵略制限UI（グレーアウト） |
| `scripts/ui_components/card_selection_ui.gd` | 侵略制限（選択不可） |

### データファイル

- `data/water_1.json` - アイスウォール (ID:102)
- `data/earth_1.json` - カクタスウォール (ID:205)
- その他各属性のJSONファイル

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025-10-23 | 1.0 | 全21体の防御型クリーチャーに`creature_type: "defensive"`を実装完了 |
| 2025-10-25 | 1.1 | ドキュメント簡略化：テスト方法削除、将来拡張案削除、クリーチャー一覧簡略化 |

---

**最終更新**: 2025年10月25日（v1.1）
