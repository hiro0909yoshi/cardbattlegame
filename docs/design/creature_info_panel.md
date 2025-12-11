# クリーチャー情報パネル設計書

## 概要

クリーチャーの詳細情報をパネルで表示する機能。召喚時の確認ダイアログ、およびマップ上のクリーチャー情報閲覧に使用。

---

## 実装状況

| 項目 | 状態 | 備考 |
|------|------|------|
| 基本UI構築 | ✅ 完了 | 3パネル構成（左/中央/右） |
| 画面サイズ対応 | ✅ 完了 | viewport比率ベース |
| 選択モード | ✅ 完了 | 召喚/交換時の確認ダイアログ |
| ON/OFF切替 | ✅ 完了 | GameSettings.use_creature_info_panel |
| 閲覧モード | ✅ 完了 | 領地コマンドのアクションメニュー時 |
| グローバルボタン対応 | ✅ 完了 | 決定/戻るボタンをグローバル化 |

---

## ファイル構成

### 新規作成ファイル

| ファイル | 役割 |
|----------|------|
| `scripts/game_settings.gd` | 機能ON/OFFフラグ管理 |
| `scripts/ui_components/creature_info_panel_ui.gd` | 情報パネルUI管理 |

### 変更ファイル

| ファイル | 変更内容 |
|----------|----------|
| `scripts/ui_manager.gd` | パネル変数追加、初期化、シグナル接続 |
| `scripts/ui_components/card_selection_ui.gd` | ON/OFF分岐処理追加 |

---

## 機能ON/OFF切替

```gdscript
# scripts/game_settings.gd
class_name GameSettings

static var use_creature_info_panel: bool = true  # true: 新パネル使用
static var debug_mode: bool = false
```

- `true`: 召喚時にクリーチャー選択→情報パネル表示→Yes/No確認
- `false`: 従来動作（カード選択で即召喚）

---

## 2つの表示モード

| モード | 用途 | 中央パネル | 閉じ方 |
|--------|------|-----------|--------|
| 閲覧モード | 領地コマンドで選択した土地のクリーチャー表示 | 非表示 | グローバル「戻る」ボタン |
| 選択モード | 召喚/交換時のカード選択確認 | 確認テキスト表示 | グローバル「決定/戻る」ボタン |

### 使用箇所

| 場面 | モード | 確認テキスト |
|------|--------|-------------|
| 召喚フェーズでクリーチャー選択 | 選択モード | 「召喚しますか？」 |
| 交換でクリーチャー選択 | 選択モード | 「このクリーチャーに交換しますか？」 |
| 領地コマンドのアクションメニュー | 閲覧モード | - |

---

## UIレイアウト

### 画面サイズ対応設計

viewport比率ベースで動的にサイズ計算：

```gdscript
# 定数（画面比率ベース）
const PANEL_MARGIN_RATIO = 0.02      # 画面幅の2%
const CARD_WIDTH_RATIO = 0.18        # 画面幅の18%（カード幅）
const RIGHT_PANEL_WIDTH_RATIO = 0.25 # 画面幅の25%
const CENTER_PANEL_WIDTH_RATIO = 0.12 # 画面幅の12%
const FONT_SIZE_RATIO = 0.018        # 画面高さの1.8%
```

### レイアウト図（選択モード）

```
┌─────────────────────────────────────────────────────────────────┐
│                    【半透明オーバーレイ】                        │
│                                                                 │
│  ┌────────┐  ┌──────────────┐  ┌─────────────────────────────┐  │
│  │        │  │              │  │ ティアマト [R]              │  │
│  │ カード │  │ 召喚しますか？│  │ 火                          │  │
│  │  UI    │  │              │  │ コスト: 110G (火火)         │  │
│  │        │  │  [はい][いいえ]│  │ HP: 60 / 60    AP: 60       │  │
│  │        │  │              │  │ 配置制限: なし アイテム: なし │  │
│  │        │  └──────────────┘  │                             │  │
│  │        │                    │ 【呪い】なし                │  │
│  │        │                    │ 【スキル】先制; 強打[水]... │  │
│  └────────┘                    └─────────────────────────────┘  │
│   左パネル      中央パネル              右パネル                 │
│  (18%幅)       (12%幅)                (25%幅)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### パネル配置計算

```gdscript
func _update_sizes():
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# 各パネルサイズ
	var card_width = screen_width * CARD_WIDTH_RATIO
	var card_height = card_width * (293.0 / 220.0)  # カード縦横比維持
	var center_width = screen_width * CENTER_PANEL_WIDTH_RATIO
	var right_width = screen_width * RIGHT_PANEL_WIDTH_RATIO
	var right_height = card_height  # カードと同じ高さ
	var panel_separation = int(screen_width * 0.02)
	
	# コンテナ合計サイズ
	var total_width = card_width + panel_separation + center_width + panel_separation + right_width
	var total_height = max(card_height, right_height)
	
	# 画面中央に配置
	var center_x = (screen_width - total_width) / 2.0
	var center_y = (screen_height - total_height) / 2.0
	main_container.position = Vector2(center_x, center_y)
```

---

## 右パネル詳細情報

### 表示項目

| 順序 | 項目 | データソース | 表示形式 |
|------|------|-------------|----------|
| 1 | 名前 + レア度 | `name`, `rarity` | `ティアマト [R]` |
| 2 | 属性 | `element` | 色付きテキスト |
| 3 | コスト | `cost` または `cost.mp` | `コスト: 110G (火火)` |
| 4 | HP / AP | `hp`, `ap`, `current_hp` | `HP: 60 / 60  AP: 60` |
| 5 | 配置制限 | `restrictions.cannot_summon` | `配置制限: なし` |
| 6 | アイテム制限 | `restrictions.cannot_use` | `アイテム: なし` |
| 7 | 呪い | `curse_effects` | `【呪い】なし` |
| 8 | スキル | `ability_parsed.keywords` | 条件付き表示 |
| 9 | 秘術 | `ability_parsed.mystic_art` | 条件付き表示 |

### データ形式対応

`cost`フィールドは2つの形式に対応：

```gdscript
# costが辞書の場合
var cost_value = data.get("cost", 0)
var mp_cost = 0
var lands_required = []

if typeof(cost_value) == TYPE_DICTIONARY:
	mp_cost = cost_value.get("mp", 0)
	lands_required = cost_value.get("lands_required", [])
else:
	mp_cost = cost_value if typeof(cost_value) == TYPE_INT else 0
	lands_required = data.get("cost_lands_required", [])  # 正規化フィールド
```

### 属性表示変換

```gdscript
func _get_element_display_name(element: String) -> String:
	match element:
		"fire": return "火"
		"water": return "水"
		"earth": return "地"
		"wind": return "風"
		"neutral": return "無"
		_: return element

func _get_element_color(element: String) -> Color:
	match element:
		"fire": return Color(1.0, 0.3, 0.2)
		"water": return Color(0.2, 0.5, 1.0)
		"earth": return Color(0.6, 0.4, 0.2)
		"wind": return Color(0.2, 0.8, 0.3)
		_: return Color.WHITE
```

---

## シグナルフロー

### 選択モード（召喚時）

```
[手札カードタップ]
		│
		▼
[card_selection_ui.gd] on_card_selected()
		│
		│ GameSettings.use_creature_info_panel == true
		│ && selection_mode == "summon"
		│ && card_type == "creature"
		│
		▼
[creature_info_panel_ui.gd] show_selection_mode()
		│
		├── Yesボタン → selection_confirmed シグナル
		│       │
		│       ▼
		│   [ui_manager.gd] _on_creature_info_panel_confirmed()
		│       │
		│       ▼
		│   card_selected シグナル発火 → 召喚処理
		│
		└── Noボタン → selection_cancelled シグナル
				│
				▼
			選択UIに戻る（再選択可能）
```

---

## クラス設計

### CreatureInfoPanelUI

```gdscript
class_name CreatureInfoPanelUI
extends Control

# シグナル
signal selection_confirmed(card_data: Dictionary)
signal selection_cancelled
signal panel_closed

# UI要素
var background_overlay: ColorRect
var main_container: HBoxContainer
var left_panel: Control       # カードUI
var center_panel: VBoxContainer  # Yes/No確認
var right_panel: VBoxContainer   # 詳細情報

# 右パネルのラベル
var name_label: Label
var element_label: Label
var cost_label: Label
var hp_ap_label: Label
var restriction_label: Label
var curse_label: Label
var skill_container: VBoxContainer
var skill_label: Label
var mystic_container: VBoxContainer
var mystic_label: Label

# 中央パネルの要素
var confirm_label: Label
var yes_button: Button
var no_button: Button

# カード表示用
var card_display: Control

# 状態
var is_visible_panel: bool = false
var is_selection_mode: bool = false
var current_creature_data: Dictionary = {}
var current_tile_index: int = -1
var current_confirmation_text: String = ""

# 参照
var card_system = null

# 公開メソッド
func set_card_system(system) -> void
func show_view_mode(creature_data: Dictionary, tile_index: int = -1)
func show_selection_mode(creature_data: Dictionary, confirmation_text: String)
func hide_panel()

# 内部メソッド
func _setup_ui()
func _update_sizes()
func _update_display()
func _update_card_display()
func _update_right_panel()
```

### GameSettings

```gdscript
class_name GameSettings

static var use_creature_info_panel: bool = true
static var debug_mode: bool = false
```

---

## UIManager統合

### 変数追加

```gdscript
var creature_info_panel_ui: CreatureInfoPanelUI
```

### 初期化

```gdscript
func _ready():
	creature_info_panel_ui = CreatureInfoPanelUI.new()

func create_ui():
	creature_info_panel_ui.set_card_system(card_system_ref)
	ui_layer.add_child(creature_info_panel_ui)
	
	# シグナル接続
	creature_info_panel_ui.selection_confirmed.connect(_on_creature_info_panel_confirmed)
	creature_info_panel_ui.selection_cancelled.connect(_on_creature_info_panel_cancelled)
```

### シグナルハンドラ

```gdscript
func _on_creature_info_panel_confirmed(card_data: Dictionary):
	var card_index = card_data.get("hand_index", -1)
	if card_index >= 0:
		emit_signal("card_selected", card_index)

func _on_creature_info_panel_cancelled():
	emit_signal("pass_button_pressed")
```

---

## CardSelectionUI変更

### 追加変数

```gdscript
var pending_card_index: int = -1
var creature_info_panel_connected: bool = false
```

### on_card_selected変更

```gdscript
func on_card_selected(card_index: int):
	if not is_active:
		return
	
	# クリーチャー情報パネルを使用するか判定
	if GameSettings.use_creature_info_panel and selection_mode == "summon":
		var card_data = _get_card_data_for_index(card_index)
		if card_data and card_data.get("type") == "creature":
			_show_creature_info_panel(card_index, card_data)
			return
	
	# 既存の動作
	hide_selection()
	emit_signal("card_selected", card_index)
```

---

## 残作業

### 優先度高

1. **閲覧モード実装**
   - CreatureCard3DQuadにArea3D追加
   - `creature_tapped`シグナル
   - UIManagerで閲覧モード表示

2. **UIの微調整**
   - 位置の微調整
   - フォントサイズ調整
   - パネル間隔調整

### 優先度中

3. **バトルモード対応**
   - selection_mode == "battle" での確認テキスト変更
   - 侵略モード対応

### 優先度低（将来）

4. **アニメーション追加**
   - フェードイン/アウト
   - スライドイン

5. **ホバープレビュー（PC）**
   - マウスオーバーでプレビュー表示

---

## 関連ドキュメント

| ファイル | 内容 |
|----------|------|
| `docs/design/tile_system.md` | タイルシステム |
| `docs/implementation/creature_3d_display_implementation.md` | 3Dクリーチャー表示 |

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025/12/11 | 初版作成 |
| 2025/12/11 | レイアウト更新、半透明オーバーレイ追加 |
| 2025/12/11 | 実装完了部分を反映、画面サイズ対応設計追加、クラス設計詳細化 |
