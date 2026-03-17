# インベントリ（倉庫）システム設計書

**最終更新**: 2026-03-18

---

## 概要

プレイヤーが所持する消費アイテムを管理するシステム。
メイン画面の「倉庫」ボタンからアクセスし、アイテムの確認・使用ができる。

バトル用アイテム（`data/item.json`）とは別システム。

---

## データ構造

### アイテム定義

**ファイル**: `data/inventory_items.json`

```json
[
  {
    "id": 1,
    "name": "スタミナ回復薬（小）",
    "description": "スタミナを20回復する",
    "effect_type": "stamina_recover",
    "value": 20,
    "rarity": "N",
    "max_stack": 99
  },
  {
    "id": 2,
    "name": "スタミナ回復薬（大）",
    "description": "スタミナを全回復する",
    "effect_type": "stamina_recover_full",
    "value": 0,
    "rarity": "S",
    "max_stack": 99
  }
]
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | int | アイテムID（一意） |
| name | String | 表示名 |
| description | String | 説明文 |
| effect_type | String | 効果種別（後述） |
| value | int | 効果の数値（種別による） |
| rarity | String | レアリティ（N/S/R） |
| max_stack | int | 最大所持数 |

### 所持データ

**保存先**: `GameData.player_data.inventory`

```gdscript
"inventory": {
    "1": 5,   # アイテムID "1" を5個所持
    "2": 3    # アイテムID "2" を3個所持
}
```

キーは文字列（JSON互換）、値は整数。

---

## 効果種別（effect_type）

| effect_type | 効果 | value の意味 |
|-------------|------|-------------|
| `stamina_recover` | スタミナを指定値回復（最大値を超えてOK） | 回復量 |
| `stamina_recover_full` | スタミナを最大値まで全回復 | 未使用 |

### 将来の拡張候補

| effect_type | 効果 |
|-------------|------|
| `gold_boost` | 一定時間ゴールド獲得量UP |
| `exp_boost` | 一定時間経験値UP |
| `card_pack` | カードパック開封 |

新しい効果を追加する場合:
1. `data/inventory_items.json` にアイテム定義を追加
2. `game_data.gd` の `use_inventory_item()` 内の match 分岐に追加

---

## スタミナシステム

### 基本仕様

| 項目 | 値 |
|------|-----|
| 最大スタミナ | 50（将来レベルで増加可能） |
| 回復速度 | 5分に1回復（300秒） |
| 完全回復 | 約4時間10分 |
| クエスト消費 | 10 |
| ソロバトル消費 | なし |
| ネット対戦・大会消費 | 10（将来別リソースに変更の可能性あり） |

### 回復ルール

- **時間回復**: 最大値未満の場合のみ動作。最大値を超えない
- **回復薬**: 最大値を超えてOK（例: 40+20=60/50）
- **時間回復の停止**: 現在値が最大値以上の間は時間回復しない
- **時間回復の再開**: 消費して最大値以下に戻ると再開

### 回復手段

| 手段 | 最大値超え | 備考 |
|------|:--------:|------|
| 時間経過 | 不可 | 5分に1回復 |
| 回復薬（小） | 可 | +20 |
| 回復薬（大） | 不可 | 最大値まで |
| 課金石 | 不可 | 全回復（将来実装） |
| レベルアップ | 不可 | 全回復（将来実装） |

---

## API（GameData メソッド）

### スタミナ

| メソッド | 説明 |
|---------|------|
| `get_stamina() -> int` | 現在のスタミナ（時間回復適用済み） |
| `get_stamina_max() -> int` | 最大スタミナ |
| `consume_stamina(amount) -> bool` | スタミナ消費（不足時false） |
| `recover_stamina(amount)` | スタミナ回復（最大値超えOK） |
| `recover_stamina_full()` | スタミナ全回復（最大値まで） |
| `get_stamina_recovery_remaining_seconds() -> int` | 次の回復までの秒数 |
| `update_stamina_by_time()` | 時間経過回復を計算・適用 |

### インベントリ

| メソッド | 説明 |
|---------|------|
| `add_inventory_item(item_id, count)` | アイテム追加（max_stack上限あり） |
| `get_inventory_item_count(item_id) -> int` | 所持数取得 |
| `use_inventory_item(item_id) -> bool` | アイテム使用（効果適用+消費） |
| `get_inventory_item_def(item_id) -> Dictionary` | アイテム定義取得 |
| `get_all_inventory_item_defs() -> Array[Dictionary]` | 全アイテム定義取得 |

---

## 画面構成

### 倉庫画面（Storage）

**シーン**: `scenes/Storage.tscn`
**スクリプト**: `scripts/storage.gd`
**遷移元**: メイン画面「倉庫」ボタン

```
Storage (Control)
├── BG (Control)                    -- グラデーション背景
├── MarginContainer
│   └── VBoxContainer
│       ├── Header (HBoxContainer)
│       │   ├── TitleLabel          -- "倉庫"
│       │   ├── Spacer
│       │   └── StaminaLabel        -- "⚡ 50/50"（1秒更新）
│       ├── ContentArea (HBoxContainer)
│       │   └── ScrollContainer
│       │       └── GridContainer   -- アイテムパネル（3列）
│       └── Footer (HBoxContainer)
│           └── BackButton          -- メイン画面へ戻る
```

### アイテムパネル

各アイテムは600×250のパネルで表示:

```
┌─────────────────────────────────────────┐
│ スタミナ回復薬（小）         [使う]     │
│ スタミナを20回復する                    │
│ 所持数: 5                               │
└─────────────────────────────────────────┘
```

- レアリティでボーダー色を変更（N:青白、S:紫、R:金）
- 所持数0のアイテムは非表示

### メイン画面スタミナ＋ボタン

上部バーのスタミナ横「＋」ボタン:
- 回復薬（大）所持時: 「使いますか？ 所持数: X」確認ダイアログ
- 未所持時: 「所持していません」ダイアログ

---

## アイテム入手経路

| 経路 | 備考 |
|------|------|
| デイリークエスト報酬 | 将来実装 |
| クエストクリア報酬 | 将来実装 |
| ショップ購入（ゴールド） | 将来実装 |
| イベント報酬 | 将来実装 |
| メール添付 | 将来実装 |

現在はデバッグ用に倉庫画面初回アクセス時に各5個付与。

---

## ファイル一覧

| ファイル | 役割 |
|---------|------|
| `data/inventory_items.json` | アイテム定義 |
| `scripts/game_data.gd` | スタミナ・インベントリ管理 |
| `scenes/Storage.tscn` | 倉庫画面シーン |
| `scripts/storage.gd` | 倉庫画面ロジック |
| `scripts/main_menu.gd` | スタミナ表示・＋ボタン処理 |
| `scripts/quest/world_stage_select.gd` | クエスト開始時スタミナ消費 |

---

## 関連ドキュメント

- `docs/design/main_menu_design.md` — スタミナ・倉庫の設計仕様
- `docs/design/gacha_system.md` — ショップ・課金石
- `docs/design/quest_system_design.md` — クエストシステム
