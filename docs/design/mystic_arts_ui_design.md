# ミステリックアーツ UI設計書（全画面対応版）

**バージョン**: 2.0  
**最終更新**: 2025年11月24日  
**対応**: 全画面解像度（1280×720〜2560×1440以上）

---

## 目次

1. [ボタン配置戦略](#ボタン配置戦略)
2. [実装方式](#実装方式)
3. [CardUIHelper連携](#carduihelper連携)
4. [スタイル定義](#スタイル定義)
5. [実装コード例](#実装コード例)

---

## ボタン配置戦略

### 基本原則

秘術ボタンは **スペルをしないボタンと完全に同じ方式** で配置します。

```
画面レイアウト（俯瞰図）

┌─────────────────────────────────────────────────────┐
│                                                     │
│  [秘術を使う]                    [スペルをしない]  │
│  ← 手札左側                      手札右側 →       │
│                                                     │
│          ┌─ 手札コンテナ ─┐                        │
│          │ [🃏][🃏][🃏]... │                        │
│          └────────────────┘                        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 配置計算ロジック

**スペルをしないボタン**の実装（`card_selection_ui.gd`から）:

```gdscript
var layout = CardUIHelper.calculate_card_layout(viewport_size, hand_count)

# 最後のカードの右側に配置
var last_card_x = layout.start_x + hand_count * layout.card_width 
                + (hand_count - 1) * layout.spacing + layout.spacing
pass_button.position = Vector2(last_card_x, layout.card_y)
```

**秘術ボタン**も同じ方式で配置:

```gdscript
var layout = CardUIHelper.calculate_card_layout(viewport_size, hand_count)

# 最初のカードの左側に配置（手札の反対側）
var mystic_button_x = layout.start_x - 320  # ボタン幅300 + マージン20
mystic_button.position = Vector2(mystic_button_x, layout.card_y)
```

---

## 実装方式

### クラス構成

```
SpellPhaseUIManager (新規作成)
├── 秘術ボタン管理
├── スペルをしないボタン管理  
└── 排他制御
```

### SpellPhaseUIManager の実装

```gdscript
class_name SpellPhaseUIManager
extends Control

# ボタン参照
var mystic_button: Button = null
var spell_skip_button: Button = null

# UI参照
var card_ui_helper: Object = null  # CardUIHelper
var hand_display: Object = null    # HandDisplay

# 定数
const BUTTON_WIDTH = 300
const BUTTON_HEIGHT = 70
const BUTTON_MARGIN = 20

func _ready():
	# CardUIHelper と HandDisplay への参照を設定（外部から）
	pass

# === ボタン作成 ===

func create_mystic_button(parent: Node) -> Button:
	"""秘術ボタンを作成（全画面対応）"""
	if mystic_button:
		return mystic_button
	
	mystic_button = Button.new()
	mystic_button.name = "MysticButton"
	mystic_button.text = "秘術を使う"
	mystic_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	
	# 位置計算（CardUIHelper を使用）
	_update_button_positions()
	
	# スタイル設定
	_apply_mystic_button_style(mystic_button)
	
	# Z-index
	mystic_button.z_index = 100
	
	parent.add_child(mystic_button)
	mystic_button.visible = false  # 初期状態は非表示
	
	return mystic_button

func create_spell_skip_button(parent: Node) -> Button:
	"""スペルをしないボタンを作成（既存、参考用）"""
	if spell_skip_button:
		return spell_skip_button
	
	spell_skip_button = Button.new()
	spell_skip_button.name = "SpellSkipButton"
	spell_skip_button.text = "スペルをしない"
	spell_skip_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	
	_update_button_positions()
	_apply_spell_skip_button_style(spell_skip_button)
	
	spell_skip_button.z_index = 100
	parent.add_child(spell_skip_button)
	spell_skip_button.visible = false
	
	return spell_skip_button

# === 位置更新 ===

func _update_button_positions():
	"""画面解像度変更時にボタン位置を再計算"""
	var viewport_size = get_viewport().get_visible_rect().size
	var hand_count = 6  # 最大手札数（調整可能）
	
	# CardUIHelper でレイアウト計算
	if not card_ui_helper:
		card_ui_helper = CardUIHelper
	
	var layout = card_ui_helper.calculate_card_layout(viewport_size, hand_count)
	
	# 秘術ボタン：手札左側
	if mystic_button:
		var mystic_x = layout.start_x - BUTTON_WIDTH - BUTTON_MARGIN
		mystic_button.position = Vector2(mystic_x, layout.card_y)
	
	# スペルをしないボタン：手札右側
	if spell_skip_button:
		var last_card_x = layout.start_x + hand_count * layout.card_width \
		                 + (hand_count - 1) * layout.spacing + layout.spacing
		spell_skip_button.position = Vector2(last_card_x, layout.card_y)

# === スタイル適用 ===

func _apply_mystic_button_style(button: Button):
	"""秘術ボタンのスタイル設定"""
	# Normal状態
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.4, 0.2, 0.6, 1.0)  # 紫系
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1, 1, 1, 1)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover状態
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.6, 0.3, 0.8, 1.0)  # 明るい紫
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed状態
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.3, 0.1, 0.5, 1.0)  # 暗い紫
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# フォント設定
	button.add_theme_font_size_override("font_size", 24)

func _apply_spell_skip_button_style(button: Button):
	"""スペルをしないボタンのスタイル設定"""
	# Normal状態
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.5, 0.5, 0.5, 1.0)  # グレー
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1, 1, 1, 1)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", normal_style)
	
	# Hover状態
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.7, 0.7, 0.7, 1.0)  # ライトグレー
	button.add_theme_stylebox_override("hover", hover_style)
	
	# Pressed状態
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.3, 0.3, 0.3, 1.0)  # ダークグレー
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# フォント設定
	button.add_theme_font_size_override("font_size", 24)

# === 表示制御 ===

func show_mystic_button():
	"""秘術ボタン表示"""
	if mystic_button:
		mystic_button.visible = true

func hide_mystic_button():
	"""秘術ボタン非表示"""
	if mystic_button:
		mystic_button.visible = false

func show_spell_skip_button():
	"""スペルをしないボタン表示"""
	if spell_skip_button:
		spell_skip_button.visible = true

func hide_spell_skip_button():
	"""スペルをしないボタン非表示"""
	if spell_skip_button:
		spell_skip_button.visible = false

# === 排他制御 ===

func on_spell_used():
	"""スペル使用時：秘術ボタンを非表示"""
	hide_mystic_button()

func on_mystic_art_used():
	"""秘術使用時：スペルをしないボタンを非表示"""
	hide_spell_skip_button()

func reset_buttons():
	"""両ボタンをリセット"""
	show_mystic_button()
	show_spell_skip_button()
```

---

## CardUIHelper 連携

### 必須メソッド

```gdscript
# CardUIHelper.calculate_card_layout() の戻り値
{
	"start_x": float,          # 手札開始X座標
	"card_y": float,           # 手札Y座標（ボタンもこれに合わせる）
	"card_width": float,       # カード幅（220）
	"card_height": float,      # カード高さ（293）
	"spacing": float,          # カード間隔
	"total_width": float       # 総手札幅
}
```

### 使用例

```gdscript
var layout = CardUIHelper.calculate_card_layout(Vector2(1920, 1080), 6)

# 秘術ボタンX座標
var mystic_x = layout.start_x - 320

# Y座標（カードと同じ高さに揃える）
var button_y = layout.card_y

# スペルをしないボタンX座標
var last_card_x = layout.start_x + 6 * layout.card_width + 5 * layout.spacing + layout.spacing
```

---

## スタイル定義

### 秘術ボタン

| 状態 | RGB | 16進数 | 用途 |
|------|-----|--------|------|
| Normal | (0.4, 0.2, 0.6) | #663399 | 基本紫色 |
| Hover | (0.6, 0.3, 0.8) | #9966CC | ホバー時 |
| Pressed | (0.3, 0.1, 0.5) | #552288 | 押下時 |

### スペルをしないボタン

| 状態 | RGB | 16進数 | 用途 |
|------|-----|--------|------|
| Normal | (0.5, 0.5, 0.5) | #808080 | グレー基本 |
| Hover | (0.7, 0.7, 0.7) | #B3B3B3 | ホバー時 |
| Pressed | (0.3, 0.3, 0.3) | #4D4D4D | 押下時 |

### 共通スタイル

```
枠線: 2px（白色 #FFFFFF）
角丸: 5px（全角）
フォントサイズ: 24px
フォント色: 白色（カテゴリー内）
```

---

## 実装コード例

### SpellPhaseHandler での使用

```gdscript
class_name SpellPhaseHandler
extends Node

var spell_phase_ui_manager: SpellPhaseUIManager = null

func _ready():
	# SpellPhaseUIManager を作成
	spell_phase_ui_manager = SpellPhaseUIManager.new()
	add_child(spell_phase_ui_manager)
	spell_phase_ui_manager.card_ui_helper = CardUIHelper
	spell_phase_ui_manager.hand_display = hand_display

func start_spell_phase():
	"""スペルフェーズ開始"""
	# ボタンをUIレイヤーに追加
	var ui_layer = ui_manager.get_node("UILayer")
	spell_phase_ui_manager.create_mystic_button(ui_layer)
	spell_phase_ui_manager.create_spell_skip_button(ui_layer)
	
	spell_phase_ui_manager.show_mystic_button()
	spell_phase_ui_manager.show_spell_skip_button()

func on_spell_used():
	"""スペル使用時"""
	spell_phase_ui_manager.on_spell_used()
	# 秘術ボタンは非表示

func on_mystic_art_used():
	"""秘術使用時"""
	spell_phase_ui_manager.on_mystic_art_used()
	# スペルをしないボタンは非表示

func end_spell_phase():
	"""スペルフェーズ終了"""
	spell_phase_ui_manager.reset_buttons()
```

---

## 対応解像度表

| 解像度 | 秘術X | スペルX | 備考 |
|--------|-------|---------|------|
| 1280×720 | 計算値 | 計算値 | 最小対応 |
| 1920×1080 | 計算値 | 計算値 | 標準 |
| 2560×1440 | 計算値 | 計算値 | 4K対応 |
| その他 | 計算値 | 計算値 | 自動対応 |

**全て CardUIHelper により自動計算**

---

**最終更新**: 2025年11月24日（v2.0 - 全画面対応版完成）
