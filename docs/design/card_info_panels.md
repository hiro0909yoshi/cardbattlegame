# カード情報パネル設計書

**バージョン**: 2.0  
**最終更新**: 2025年12月16日

## 概要

カード（クリーチャー/スペル/アイテム）の詳細情報をパネルで表示する機能。使用確認ダイアログ、およびマップ上の情報閲覧に使用。

**対象パネル**:
- クリーチャー情報パネル（CreatureInfoPanelUI）
- スペル情報パネル（SpellInfoPanelUI）
- アイテム情報パネル（ItemInfoPanelUI）

**共通設計**: [info_panel.md](info_panel.md) を参照

---

## 目次

1. [クリーチャー情報パネル](#クリーチャー情報パネル)
2. [スペル情報パネル](#スペル情報パネル)
3. [アイテム情報パネル](#アイテム情報パネル)
4. [共通クラス設計](#共通クラス設計)

---

# クリーチャー情報パネル

## 実装状況

| 項目 | 状態 | 備考 |
|------|------|------|
| 基本UI構築 | ✅ 完了 | 2パネル構成（左:カード/右:詳細） |
| 画面サイズ対応 | ✅ 完了 | viewport比率ベース |
| 選択モード | ✅ 完了 | 召喚/交換時の確認ダイアログ |
| ON/OFF切替 | ✅ 完了 | GameSettings.use_creature_info_panel |
| 閲覧モード | ✅ 完了 | ドミニオオーダーのアクションメニュー時 |
| グローバルボタン対応 | ✅ 完了 | 決定/戻るボタンをグローバル化 |
| ダブルクリック召喚 | ✅ 完了 | 同じカード2回タップで即召喚 |
| カードホバー管理 | ✅ 完了 | 戻るボタン時にホバー状態解除 |

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
| 閲覧モード | ドミニオオーダーで選択した土地のクリーチャー表示 | 非表示 | グローバル「戻る」ボタン |
| 選択モード | 召喚/交換時のカード選択確認 | 確認テキスト表示 | グローバル「決定/戻る」ボタン |

### 使用箇所

| 場面 | モード | 確認テキスト |
|------|--------|-------------|
| 召喚フェーズでクリーチャー選択 | 選択モード | 「召喚しますか？」 |
| 交換でクリーチャー選択 | 選択モード | 「このクリーチャーに交換しますか？」 |
| ドミニオオーダーのアクションメニュー | 閲覧モード | - |

---

## UIレイアウト

### 画面サイズ対応設計

viewport比率ベースで動的にサイズ計算：

```gdscript
# 定数（画面比率ベース）
const PANEL_MARGIN_RATIO = 0.02      # 画面幅の2%
const CARD_WIDTH_RATIO = 0.18        # 画面幅の18%（カード幅）
const RIGHT_PANEL_WIDTH_RATIO = 0.25 # 画面幅の25%
const FONT_SIZE_RATIO = 0.018        # 画面高さの1.8%（×1.65倍で使用）
```

### レイアウト図（選択モード）

```
┌─────────────────────────────────────────────────────────────────┐
│                    【半透明オーバーレイ】                        │
│                                                                 │
│  ┌────────┐  ┌─────────────────────────────┐                    │
│  │        │  │ ティアマト [R]              │                    │
│  │ カード │  │ 火                          │                    │
│  │  UI    │  │ コスト: 110G (火火)         │                    │
│  │        │  │ HP: 60 / 60    AP: 60       │                    │
│  │        │  │ 配置制限: なし アイテム: なし │                    │
│  │        │  │                             │                    │
│  │        │  │ 【呪い】なし                │                    │
│  │        │  │ 【スキル】先制; 強化[水]... │                    │
│  └────────┘  └─────────────────────────────┘                    │
│   左パネル              右パネル                                 │
│  (18%幅)              (25%幅、高さ×1.33)                        │
│                                                                 │
│          ※パネル全体を180px上に配置                            │
│          ※カード表示は追加で50px上に配置                        │
└─────────────────────────────────────────────────────────────────┘
```

### パネル配置計算

```gdscript
func _update_sizes():
	var viewport = get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	var screen_width = viewport_size.x
	var screen_height = viewport_size.y
	
	# フォントサイズ計算（全体を1.65倍に拡大）
	var base_font_size = int(screen_height * FONT_SIZE_RATIO * 1.65)
	var title_font_size = int(base_font_size * 1.4)
	var small_font_size = int(base_font_size * 0.85)
	
	# 各パネルサイズ
	var card_width = screen_width * CARD_WIDTH_RATIO
	var card_height = card_width * (293.0 / 220.0)  # カード縦横比維持
	var right_width = screen_width * RIGHT_PANEL_WIDTH_RATIO
	var right_height = card_height * 1.33  # 高さを2/3に縮小
	var panel_separation = int(screen_width * 0.02)
	
	# コンテナ合計サイズ
	var total_width = card_width + panel_separation + right_width
	var total_height = max(card_height, right_height)
	
	# 画面中央に配置 + 180px上に移動
	var center_x = (screen_width - total_width) / 2.0
	var center_y = (screen_height - total_height) / 2.0 - 180
	main_container.position = Vector2(center_x, center_y)

func _update_card_display():
	# カードシーンをロードして表示
	var card_scene = preload("res://scenes/Card.tscn")
	card_display = card_scene.instantiate()
	left_panel.add_child(card_display)
	
	# カード位置を50px上に調整
	card_display.position.y = -50
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
| 7 | 呪い | `curse` | `【呪い】なし` または `【呪い】○○（残りNターン）` |
| 8 | スキル | `ability_parsed.keywords` | 条件付き表示 |
| 9 | アルカナアーツ | `ability_parsed.mystic_art` | 条件付き表示 |

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

### 呪い表示

クリーチャーの呪いは`curse`辞書から取得：

```gdscript
var curse = data.get("curse", {})
if curse.is_empty():
	curse_label.text = "【呪い】なし"
else:
	var curse_name = curse.get("name", "不明")
	var duration = curse.get("duration", -1)
	if duration > 0:
		curse_label.text = "【呪い】%s（残り%dターン）" % [curse_name, duration]
	else:
		curse_label.text = "【呪い】%s" % curse_name
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
		├── 決定ボタン or 同じカード再タップ（ダブルクリック）
		│       │
		│       ▼
		│   selection_confirmed シグナル
		│       │
		│       ▼
		│   card_selected シグナル発火 → 召喚処理
		│
		└── 戻るボタン → selection_cancelled シグナル
				│
				▼
			カードのホバー状態解除 → 選択UIに戻る（再選択可能）
```

### ダブルクリック召喚

同じカードを2回タップすると、情報パネルを経由せず即召喚：

```gdscript
# card_selection_ui.gd
func _show_creature_info_panel(card_index: int, card_data: Dictionary):
	# ダブルクリック検出：同じカードを再度クリックした場合は即確定
	if pending_card_index == card_index and ui_manager_ref.creature_info_panel_ui.is_visible_panel:
		var confirm_data = card_data.duplicate()
		confirm_data["hand_index"] = card_index
		_on_creature_panel_confirmed(confirm_data)
		return
```

### 戻るボタン時のホバー解除

```gdscript
# card_selection_ui.gd
func _on_creature_panel_cancelled():
	pending_card_index = -1
	
	# 選択中のカードのホバー状態を解除
	var card_script = load("res://scripts/card.gd")
	if card_script.currently_selected_card:
		card_script.currently_selected_card.deselect_card()
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
var right_panel: VBoxContainer   # 詳細情報（中央パネルは廃止）

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

### 完了済み

1. ~~**閲覧モード実装**~~ ✅
   - ドミニオオーダーのアクションメニュー時に自動表示

2. ~~**UIの微調整**~~ ✅
   - パネル全体を180px上に配置
   - カード表示を50px上に配置
   - 右パネル高さを2/3に縮小
   - フォントサイズ1.65倍に拡大

3. ~~**ダブルクリック召喚**~~ ✅
   - 同じカード2回タップで即召喚

4. ~~**ホバー状態解除**~~ ✅
   - 戻るボタン押下時にカードのホバー状態を解除

### 優先度中

5. **バトルモード対応**
   - selection_mode == "battle" での確認テキスト変更
   - 侵略モード対応

### 優先度低（将来）

6. **アニメーション追加**
   - フェードイン/アウト
   - スライドイン

7. **ホバープレビュー（PC）**
   - マウスオーバーでプレビュー表示

---

## 関連ドキュメント

| ファイル | 内容 |
|----------|------|
| `docs/design/tile_system.md` | タイルシステム |
| `docs/implementation/creature_3d_display_implementation.md` | 3Dクリーチャー表示 |

---

---

# スペル情報パネル

## 概要

スペルカードの詳細情報を表示し、使用確認を行うパネル。

## ファイル構成

| ファイル | 役割 |
|----------|------|
| `scenes/ui/spell_info_panel.tscn` | シーンファイル |
| `scripts/ui_components/spell_info_panel_ui.gd` | UIスクリプト |

## 表示内容

| 順序 | 項目 | データソース | 表示形式 |
|------|------|-------------|----------|
| 1 | 名前 + レア度 | `name`, `rarity` | `ファイアボール [N]` |
| 2 | コスト | `cost` または `cost.mp` | `コスト: 50G` |
| 3 | スペルタイプ | `spell_type` | `単体クリーチャー` |
| 4 | 効果テキスト | `effect` | 効果説明文 |

## 主要メソッド

```gdscript
## スペル情報パネルを表示（使用確認モード）
func show_spell_info(spell_data: Dictionary, hand_index: int = -1)

## パネルを閉じる
func hide_panel(clear_buttons: bool = true)

## パネル表示中かどうか
func is_panel_visible() -> bool
```

## シグナル

| シグナル | 発火タイミング |
|---------|---------------|
| `selection_confirmed(card_data)` | 決定ボタン押下時 |
| `selection_cancelled` | 戻るボタン押下時 |
| `panel_closed` | パネル閉じた時 |

## 呼び出し元

- `CardSelectionUI._show_spell_info_panel()` - スペルフェーズ時

---

# アイテム情報パネル

## 概要

アイテムカードの詳細情報を表示し、使用確認を行うパネル。

## ファイル構成

| ファイル | 役割 |
|----------|------|
| `scenes/ui/item_info_panel.tscn` | シーンファイル |
| `scripts/ui_components/item_info_panel_ui.gd` | UIスクリプト |

## 表示内容

| 順序 | 項目 | データソース | 表示形式 |
|------|------|-------------|----------|
| 1 | 名前 + レア度 | `name`, `rarity` | `ロングソード [N]` |
| 2 | コスト | `cost` または `cost.mp` | `コスト: 30G` |
| 3 | アイテムタイプ | `item_type` | `武器` / `防具` / `道具` / `巻物` |
| 4 | ステータス変化 | `effect_parsed.stat_bonus` | `AP+20  HP+10` |
| 5 | 効果テキスト | `effect` | 効果説明文 |

## 主要メソッド

```gdscript
## アイテム情報パネルを表示（使用確認モード）
func show_item_info(item_data: Dictionary, hand_index: int = -1)

## パネルを閉じる
func hide_panel(clear_buttons: bool = true)

## パネル表示中かどうか
func is_panel_visible() -> bool
```

## シグナル

| シグナル | 発火タイミング |
|---------|---------------|
| `selection_confirmed(card_data)` | 決定ボタン押下時 |
| `selection_cancelled` | 戻るボタン押下時 |
| `panel_closed` | パネル閉じた時 |

## 呼び出し元

- `CardSelectionUI._show_item_info_panel()` - アイテムフェーズ時

## ステータスボーナス表示

`effect_parsed.stat_bonus` からAP/HPボーナスを整形：

```gdscript
func _format_stat_bonus(data: Dictionary) -> String:
	var effect_parsed = data.get("effect_parsed", {})
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	
	var parts = []
	var ap = stat_bonus.get("ap", 0)
	var hp = stat_bonus.get("hp", 0)
	
	if ap != 0:
		parts.append("AP%s%d" % ["+" if ap > 0 else "", ap])
	if hp != 0:
		parts.append("HP%s%d" % ["+" if hp > 0 else "", hp])
	
	return "  ".join(parts)
```

## アイテムフェーズでのクリーチャー表示

アイテムフェーズでは以下もカード選択可能（**クリーチャー情報パネル**で表示）：
- **レリック**: `SkillItemCreature.is_item_creature(card_data)` で判定
- **加勢クリーチャー**: バトル参加クリーチャーが加勢スキルを持つ場合

---

# 共通クラス設計

## 共通定数

```gdscript
const CARD_SCALE = 1.12  # カード表示スケール
```

## 共通パターン

### グローバルボタン連携

```gdscript
# パネル表示時
if ui_manager_ref:
	ui_manager_ref.enable_navigation(
		func(): _on_confirm_action(),  # 決定
		func(): _on_back_action()      # 戻る
	)

# パネル非表示時
if clear_buttons and ui_manager_ref:
	ui_manager_ref.disable_navigation()
```

### カード表示のクリア

```gdscript
if card_display and is_instance_valid(card_display):
	card_display.queue_free()
	card_display = null
```

### カード読み込み

```gdscript
var card_scene = preload("res://scenes/Card.tscn")
card_display = card_scene.instantiate()
card_display.scale = Vector2(CARD_SCALE, CARD_SCALE)
left_panel.add_child(card_display)

var card_id = current_data.get("id", 0)
if card_display.has_method("load_card_data"):
	card_display.load_card_data(card_id)
```

---

# スペル使用後の手札選択時

## 概要

ポイズンマインド、シャッター、セフト等のスペル使用後に敵手札やデッキからカードを選択する際、選択したカードの詳細をインフォパネルで表示する。

## 対象スペル

| スペル | filter_mode | 選択対象 |
|--------|-------------|---------|
| シャッター | `destroy_item_spell` | 敵手札のアイテム/スペル |
| スクイーズ | `destroy_any` | 敵手札の全カード |
| セフト | `destroy_spell` | 敵手札のスペル |
| ポイズンマインド | - | 敵デッキ上部6枚 |
| フォーサイト | - | 自デッキ上部6枚 |
| メタモルフォシス | `item_or_spell` | 敵手札のアイテム/スペル |

## 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/card.gd` | ワンクリック判定（`_is_handler_card_selection_active()`） |
| `scripts/ui_manager.gd` | カード選択ハンドラー経由のルーティング |
| `scripts/spells/card_selection_handler.gd` | インフォパネル表示・確認処理 |

## フロー

```
[カードクリック]
	  │
	  ▼
[card.gd] _is_handler_card_selection_active() で判定
	  │
	  │ filter が destroy_* or item_or_spell
	  │
	  ▼
[ui_manager.gd] _on_card_button_pressed()
	  │
	  │ handler.is_selecting() == true
	  │
	  ▼
[game_flow_manager.gd] on_card_selected()
	  │
	  ▼
[card_selection_handler.gd] on_enemy_card_selected() 等
	  │
	  ▼
_request_card_confirmation()
	  │
	  ▼
_show_info_panel_for_card() → カードタイプに応じたパネル表示
	  │
	  ├── 確認ボタン → アクション実行
	  │
	  └── キャンセル → 選択画面に戻る（戻るボタン再登録）
```

## CardSelectionHandler の主要メソッド

```gdscript
## カード選択後、インフォパネルで確認を要求
func _request_card_confirmation(card_index: int, card_data: Dictionary, 
								 action_type: String, on_confirmed: Callable, 
								 on_cancelled: Callable)

## カードタイプに応じたインフォパネルを表示
func _show_info_panel_for_card(card_data: Dictionary, confirmation_text: String)

## 全インフォパネルを非表示
func _hide_all_info_panels(clear_buttons: bool = true)
```

## 注意点

### カード切り替え時の処理

異なるカードを選択した場合、既存パネルを閉じてから新しいパネルを表示：

```gdscript
# _request_card_confirmation() 内
if is_panel_visible:
	_hide_all_info_panels(false)  # ボタンはクリアしない
```

### キャンセル時の戻るボタン再登録

キャンセル後に選択画面に戻れるよう、戻るボタンを再登録：

```gdscript
func _on_enemy_selection_cancelled():
	# ... フェーズラベル更新 ...
	
	# 戻るボタンを再登録
	if ui_manager:
		ui_manager.enable_navigation(
			Callable(),  # 決定なし
			func(): _cancel_enemy_card_selection("キャンセルしました")
		)
```

### カード表示の即時削除

`queue_free()` だけでは遅延があるため、`remove_child()` で即座に削除：

```gdscript
if card_display and is_instance_valid(card_display):
	if card_display.get_parent():
		card_display.get_parent().remove_child(card_display)
	card_display.queue_free()
	card_display = null
```

## 関連ドキュメント

- [手札操作スペル](spells/手札操作.md) - スペル側の詳細
- [インフォパネルシステム](info_panel.md) - 全体設計

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025/12/11 | 初版作成（クリーチャー情報パネル） |
| 2025/12/11 | レイアウト更新、半透明オーバーレイ追加 |
| 2025/12/11 | 実装完了部分を反映、画面サイズ対応設計追加、クラス設計詳細化 |
| 2025/12/12 | UI調整（パネル位置180px上、カード位置50px上、右パネル高さ2/3、フォント1.65倍） |
| 2025/12/12 | ダブルクリック召喚、戻るボタン時のホバー解除、呪い表示修正（curse形式対応） |
| 2025/12/16 | ファイル名変更（creature_info_panel.md → card_info_panels.md）、スペル/アイテムパネル追記 |
| 2025/12/17 | スペル使用後の手札選択時のインフォパネル表示を追加 |
