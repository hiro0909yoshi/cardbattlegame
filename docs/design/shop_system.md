# ショップシステム設計書

**最終更新**: 2026-03-18

---

## 概要

ショップ画面は4つのモードで構成される：

| モード | 通貨 | 説明 |
|--------|------|------|
| 購入（ガチャ） | ゴールド | カードをガチャで入手 |
| アイテム購入 | 課金石 | 回復薬等のアイテムを購入 |
| 課金石購入 | 現金（将来） | 課金石パッケージを購入 |
| 売却 | → ゴールド | 不要カードを売却してゴールド入手 |

---

## 課金石購入

### パッケージ定義

**ファイル**: `data/stone_packages.json`

```json
[
  {
    "id": "stone_100",
    "name": "お試しパック",
    "stone_amount": 100,
    "price": 120,
    "price_label": "¥120",
    "description": "まずはお試し",
    "icon": "res://assets/images/ui/stone_pack_small.png",
    "badge": "",
    "sort_order": 1
  }
]
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | String | パッケージID（一意） |
| name | String | 表示名 |
| stone_amount | int | 基本課金石数 |
| bonus_amount | int | ボーナス課金石数（任意） |
| price | int | 価格（円） |
| price_label | String | 表示用価格文字列 |
| description | String | 説明文 |
| icon | String | アイコン画像パス |
| badge | String | バッジ文字列（"お得"、"人気"等、空なら非表示） |
| sort_order | int | 表示順 |

### 現在のパッケージ

| パッケージ | 課金石 | ボーナス | 価格 | バッジ |
|-----------|--------|---------|------|--------|
| お試しパック | 100 | - | ¥120 | - |
| お得パック | 600 | +60 | ¥610 | お得 |
| 大量パック | 1,500 | +250 | ¥1,220 | 人気 |
| 超大量パック | 5,000 | +1,500 | ¥3,060 | 最もお得 |

### PurchaseManager

**ファイル**: `scripts/purchase_manager.gd`

課金処理を抽象化するクラス。現在はデバッグモード（即付与）。

```gdscript
var manager = PurchaseManager.new()

# 全パッケージ取得
var packages = manager.get_all_packages()

# 購入実行
var result = manager.purchase("stone_600")
# → {"success": true, "stone_amount": 600, "bonus_amount": 60, "total": 660}
```

### サーバー移行時の対応

1. `PurchaseManager._is_debug_mode` を `false` に変更
2. `_store_purchase()` にApple/Google決済APIを実装
3. レシート検証をサーバー側で実施（`/api/shop/verify_receipt`）
4. サーバーが検証完了後に課金石を付与

---

## アイテム購入（課金石消費）

### 商品定義

`shop.gd` 内の `ITEM_SHOP_PRICES` で定義。

| アイテム | 課金石コスト | 効果 |
|---------|------------|------|
| スタミナ回復薬（小） | 10 | スタミナ+20（最大超えOK） |
| スタミナ回復薬（大） | 50 | スタミナ+最大値分（超過OK） |

### 将来の拡張

新アイテム追加時：
1. `data/inventory_items.json` にアイテム定義を追加
2. `shop.gd` の `ITEM_SHOP_PRICES` に価格を追加
3. `game_data.gd` の `use_inventory_item()` に効果を追加

---

## ガチャ

**詳細**: `docs/design/gacha_system.md` を参照

| ガチャ | 排出レアリティ | 1回 | 10連 | 解禁条件 |
|--------|--------------|-----|------|----------|
| ノーマル | C + N | 50G | 500G | 最初から |
| Sガチャ | C + N + S | 80G | 800G | 1-8クリア |
| Rガチャ | C + N + S + R | 100G | 1000G | 2-8クリア |

---

## 売却

| レアリティ | 売却価格 |
|-----------|---------|
| C | 5G |
| N | 10G |
| S | 50G |
| R | 100G |

- **手動売却**: カードを1枚ずつ選択して売却
- **自動売却**: 4枚を超えた分を一括売却（デッキ使用分は除外）

---

## 課金石の表示制御

`DebugSettings.show_premium_stone` フラグで一括制御。

**false（非公開）時に隠れるもの**:
- メイン画面: 💎アイコン、所持数、+ボタン、リセットボタン
- ショップ: 「アイテム購入」タブ、「課金石購入」タブ、💎所持数
- ログインボーナス: 課金石の報酬表示行

**true（公開）時**: 全て表示

---

## ファイル一覧

| ファイル | 役割 |
|---------|------|
| `data/stone_packages.json` | 課金石パッケージ定義 |
| `scripts/purchase_manager.gd` | 課金処理管理（PurchaseManager） |
| `scripts/shop.gd` | ショップ画面ロジック |
| `scenes/Shop.tscn` | ショップ画面シーン |
| `scripts/gacha_system.gd` | ガチャロジック |
| `data/inventory_items.json` | アイテム定義 |
| `scripts/autoload/debug_settings.gd` | 課金石表示フラグ |

---

## 関連ドキュメント

- `docs/design/gacha_system.md` — ガチャシステム詳細
- `docs/design/inventory_system.md` — インベントリ・スタミナシステム
- `docs/design/backend_design.md` — サーバー側決済API設計
