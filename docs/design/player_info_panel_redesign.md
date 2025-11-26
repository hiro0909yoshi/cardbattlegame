# プレイヤー情報パネル UI 実装仕様書

**作成日**: 2025-11-26  
**最終更新**: 2025-11-26  
**ステータス**: ✅ 実装完了  
**対象ファイル**: 
- `scripts/ui_components/player_info_panel.gd`
- `scripts/ui_components/player_status_dialog.gd`
- `scripts/ui_manager.gd`

---

## 概要

画面左上に縦積みで配置された小型プレイヤーパネル。各プレイヤーの基本情報（名前、魔力、総魔力）と呪い状態を表示。パネルをクリックするとステータスダイアログが表示され、詳細情報（保有土地、クリーチャー）が確認できる。

---

## パネル表示（PlayerInfoPanel）

### パネル配置

| 項目 | 値 |
|------|-----|
| **位置** | 画面左上 (20px, 20px～) |
| **配列方向** | 縦積み（上から順に） |
| **パネル間隔** | 10px |
| **パネル幅** | 160px |
| **パネル高さ** | 105px |

```
画面左上
│
├─ [Panel 1] (y=20)
│   Player 1 情報
│
├─ [Panel 2] (y=135)
│   Player 2 情報
│
└─ ...
```

### パネルデザイン

| 要素 | 値 |
|------|-----|
| **フォントサイズ** | 15px |
| **背景色** | 黒 (透明度 0.7) |
| **枠線色** | `GameConstants.PLAYER_COLORS[player_id]` |
| **枠線幅** | 2px |

### 表示内容

#### 標準表示

```
1 プレイヤー1
  魔力: 1200G
  総魔力: 3000G
```

#### ターン中（ハイライト表示）

```
1 ● プレイヤー1
  魔力: 1200G
  総魔力: 3000G
```

※ 先頭の数字は順位（総魔力降順、同率は同順位）

#### 呪いがある場合

```
プレイヤー1
魔力: 1200G
総魔力: 3000G
[呪: ダイス6]
```

### データ仕様

| フィールド | 計算方法 | 出典 |
|----------|---------|------|
| **プレイヤー名** | `player.name` | PlayerData |
| **魔力** | `player.magic_power` | PlayerData |
| **総魔力** | `calculate_total_assets(player_id)` | 魔力 + 土地価値 |
| **呪い名** | `player.curse["name"]` | PlayerData |

### マウスインタラクション

- **マウスフィルター**: 
  - Panel: `MOUSE_FILTER_STOP` (クリック検出)
  - RichTextLabel: `MOUSE_FILTER_IGNORE` (透過)
- **クリック動作**: パネルをクリック → `player_panel_clicked(player_id)` シグナル発火
- **ダイアログ表示**: UIManager が受け取って `show_for_player()` を呼び出し

---

## ステータスダイアログ（PlayerStatusDialog）

### ダイアログ配置

| 項目 | 値 |
|------|-----|
| **サイズ** | 800×800px |
| **位置** | 画面中央（上寄り） |
| **オフセット** | offset_left: -400, offset_top: -580 |
| **背景** | 黒 (透明度 0.5) モーダル |

### ダイアログデザイン

| 要素 | 値 |
|------|-----|
| **タイトルフォント** | 24px |
| **本文フォント** | 16px |
| **テキストエリア** | 750×700px (スクロール対応) |

### 表示内容

#### 1. 基本情報セクション

```
[基本情報]
プレイヤー1 [呪: ダイス6]
魔力: 1200G
総魔力: 3000G
```

**仕様**:
- プレイヤー名
- 呪い名（呪いがあれば）
- 魔力（現在値）
- 総魔力（土地価値 + 魔力）

#### 2. 保有土地セクション

```
[保有土地]
火: 3個
水: 2個
風: 1個
土: 0個
無: 0個
```

**仕様**:
- 属性ごとの土地数を表示
- 無属性（neutral/checkpoint）も「無」として計上

#### 3. 保有クリーチャーセクション

```
[保有クリーチャー]
ハイド [バイタリティ]  HP: 30 / 30  AP: 30
アモン  HP: 25 / 50  AP: 45
```

**仕様**:
- 1行形式で表示（改行しない）
- クリーチャー名 [呪い名]  HP: 現在 / 最大  AP: 最大値
- 呪いがなければ括弧を表示しない

### データ計算仕様

#### HP/AP値の取得

| フィールド | 値 | 備考 |
|----------|-----|------|
| **current_hp** | `creature_data["current_hp"]` | バトル後の残りHP |
| **max_hp** | `creature_data["hp"] + creature_data.get("base_up_hp", 0)` | 詳細は hp_structure.md 参照 |
| **current_ap** | `creature_data.get("ap", 0) + creature_data.get("base_up_ap", 0)` | max_ap と同値（current_ap フィールドなし） |

#### 土地データの取得

```gdscript
# 英語から日本語へのマッピング
ELEMENT_MAP = {
	"fire": "火",
	"water": "水",
	"wind": "風",
	"earth": "土",
	"neutral": "無",
	"checkpoint": "無"
}

# 属性別の土地数を集計
for tile in board_system_ref.tile_nodes.values():
	if tile.owner_id == player_id:
		var jp_element = ELEMENT_MAP.get(tile.tile_type, "無")
		element_counts[jp_element] += 1
```

#### クリーチャーデータの取得

```gdscript
# プレイヤーが保有する土地上のクリーチャーを抽出
for tile in board_system_ref.tile_nodes.values():
	if tile.owner_id == player_id and not tile.creature_data.is_empty():
		creatures.append(tile.creature_data)
```

### 呪い表示ロジック

#### クリーチャー呪い

```gdscript
if creature.has("curse") and not creature.get("curse", {}).is_empty():
	var curse = creature.get("curse", {})
	var curse_name = str(curse.get("name", "呪い"))
	display_name += " [" + curse_name + "]"
```

#### プレイヤー呪い

```gdscript
if player.curse and not player.curse.is_empty():
	var curse_name = player.curse.get("name", "呪い")
	text += " [呪: " + curse_name + "]"
```

### UIイベント

- **ESCキー**: ダイアログを閉じる
- **背景クリック**: ダイアログを閉じる
- **複数ダイアログ**: 同時に1つのみ表示（新規表示時に前のダイアログは自動的に閉じる）

---

## UIManager 統合

### 初期化フロー

```
UIManager._ready()
	↓
player_info_panel を create_ui() で生成
player_status_dialog を create_ui() で生成
	↓
connect_ui_signals() で接続
player_info_panel.player_panel_clicked.connect(_on_player_panel_clicked)
```

### イベント処理

```gdscript
# パネルクリック時
func _on_player_panel_clicked(player_id: int):
	if player_status_dialog and player_status_dialog.has_method("show_for_player"):
		player_status_dialog.show_for_player(player_id)
```

---

## 実装仕様詳細

### PlayerInfoPanel.gd

**主要メソッド**:

- `build_player_info_text(player, player_id: int) -> String`
  - プレイヤー情報テキストを構築
  - ターン中は黄色●マーク付与
  - 呪いがあれば下部に赤色で表示

- `get_lands_by_element(player_id: int) -> Dictionary`
  - tile_nodes から属性別に土地数を集計
  - 戻り値: `{"火": n, "水": m, ...}`

- `get_creatures_on_lands(player_id: int) -> Array`
  - tile_nodes からクリーチャーデータを抽出
  - 戻り値: creature_data の配列

**順位関連メソッド**:

- `get_player_ranking(player_id: int) -> int`
  - 指定プレイヤーの順位を取得（1位=1, 2位=2...）
  - 総魔力降順、同率は同順位

- `calculate_all_rankings() -> Array`
  - 全プレイヤーの順位を計算
  - 戻り値: player_id をインデックスとした順位配列

**シグナル**:

- `player_panel_clicked(player_id: int)` - パネルクリック時に発火

### PlayerStatusDialog.gd

**主要メソッド**:

- `show_for_player(player_id: int)` - ダイアログを表示
- `build_status_text(player_id: int) -> String` - ステータステキストを構築
- `_on_background_clicked()` - 背景クリック時に閉じる
- `_process(delta)` - ESCキー検出

**UI構成**:

```
ColorRect (背景, モーダル)
├── PanelContainer (ダイアログ)
│   └── VBoxContainer
│       ├── Label (タイトル 24px)
│       ├── RichTextLabel (ステータス 16px)
│       └── Button (閉じるボタン)
```

---

## 実装チェックリスト

### パネル表示
- [x] パネルが縦に並ぶ（左上から順に）
- [x] パネルサイズが160×105px
- [x] フォントサイズが15px
- [x] 表示項目が「プレイヤー名」「魔力」「総魔力」のみ
- [x] ターン中は黄色●マーク + テキストハイライト
- [x] パネル枠線が GameConstants.PLAYER_COLORS 準拠
- [x] クリックでダイアログ表示

### ステータスダイアログ
- [x] サイズ 800×800px
- [x] フォント 1.5倍 (16px)
- [x] 基本情報セクション表示
- [x] 保有土地セクション表示（属性別5種類）
- [x] 保有クリーチャーセクション表示（1行形式）
- [x] クリーチャー呪い表示
- [x] プレイヤー呪い表示
- [x] ESCキーで閉じられる
- [x] 背景クリックで閉じられる
- [x] 複数ダイアログは同時に1つのみ表示

---

## 関連ドキュメント

- `docs/design/hp_structure.md` - HP/AP 計算仕様
- `docs/design/spells/呪い効果.md` - 呪いシステム
- `docs/design/game_constants.md` - PLAYER_COLORS, LEVEL_VALUES

---

**最終確認日**: 2025-11-26  
**実装者**: Hand  
**ステータス**: 本番稼働中

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2025/11/26 | 初版作成 |
| 2025/11/26 | 順位表示機能追加（`get_player_ranking`, `calculate_all_rankings`） |
