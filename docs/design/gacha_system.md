# ガチャシステム設計

## 概要

ショップ画面でカードを入手するためのガチャシステム。
プレイヤーの進行状況に応じて上位ガチャが解禁される。

## ガチャの種類

| ガチャ | 排出レアリティ | 1回 | 10連 | 解禁条件 |
|--------|--------------|-----|------|----------|
| ノーマル | C + N | 50G | 500G | 最初から |
| Sガチャ | C + N + S | 80G | 800G | 1-8クリア |
| Rガチャ | C + N + S + R | 100G | 1000G | 2-8クリア |

## 排出確率

### ノーマルガチャ
- C: 60%
- N: 40%

### Sガチャ
- C: 50%
- N: 35%
- S: 15%

### Rガチャ
- C: 50%
- N: 35%
- S: 12%
- R: 3%

## 解禁条件

- ノーマルガチャ: 最初から解禁
- Sガチャ: ステージ1-8（stage_id: 18）クリアで解禁
- Rガチャ: ステージ2-8（stage_id: 28）クリアで解禁

## ファイル構成

| ファイル | 説明 |
|----------|------|
| `scripts/gacha_system.gd` | ガチャロジック（抽選、価格、解禁判定） |
| `scripts/shop.gd` | ショップ画面UI |
| `scenes/Shop.tscn` | ショップ画面シーン |

## 主要API

### GachaSystem

```gdscript
# ガチャタイプ
enum GachaType { NORMAL, S_GACHA, R_GACHA }

# ガチャタイプを設定
func set_gacha_type(type: GachaType) -> void

# ガチャが解禁されているか確認
func is_gacha_unlocked(type: GachaType) -> bool

# 単発ガチャを引く
func pull_single() -> Dictionary
func pull_single_typed(type: GachaType) -> Dictionary

# 10連ガチャを引く
func pull_multi_10() -> Dictionary
func pull_multi_10_typed(type: GachaType) -> Dictionary

# 価格取得
func get_single_cost(type: GachaType) -> int
func get_multi_10_cost(type: GachaType) -> int
```

### 戻り値形式

```gdscript
# 成功時
{"success": true, "cards": [カードデータの配列]}

# 失敗時
{"success": false, "error": "エラーメッセージ"}
```

## 売却システム

ショップ画面には売却機能もある。

### 売却価格

| レアリティ | 価格 |
|------------|------|
| C | 5G |
| N | 10G |
| S | 50G |
| R | 100G |

### 売却方法

- **手動売却**: カードを1枚ずつ選んで売却
- **自動売却**: 4枚を超えた分を一括売却（デッキ使用分は除外）

## 今後の拡張予定

- [ ] ピックアップガチャ
- [ ] 天井システム
- [ ] 確定枠（10連でS以上確定など）
