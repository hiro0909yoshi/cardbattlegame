# クリーチャー情報パネル設計書

## 概要

マップ上に配置されたクリーチャーをタップ/クリックすると、そのクリーチャーの詳細情報をパネルで表示する機能。

---

## 要件

### 機能要件

| 項目 | 内容 |
|------|------|
| 表示トリガー | 3Dクリーチャーカードをタップ/クリック |
| 対応プラットフォーム | PC（クリック）、スマホ（タップ） |
| 半透明オーバーレイ | あり（パネル表示中は背景を暗くする） |

### 表示タイミング

以下のタイミングでクリーチャー情報パネルを表示可能：

- カード選択中（召喚/バトル/アイテム等）
- カメラ自動移動中（プレイヤー移動時）
- 自由カメラモード時

※ 将来的に常時表示可能に拡張予定

---

## 2つの表示モード

| モード | 用途 | 中央パネル | 閉じ方 |
|--------|------|-----------|--------|
| 閲覧モード | タイル配置クリーチャーを見る | なし | どこでもタップ |
| 選択モード | 召喚/バトル時のカード選択 | Yes/No確認 | Yes/Noボタン |

---

## UIレイアウト

### 閲覧モード（タイル配置クリーチャー）

```
┌─────────────────────────────────────────────────────────────────┐
│                    【半透明オーバーレイ】                        │
│                    （どこでもタップで閉じる）                    │
│                                                                 │
│  ┌────────┐                    ┌─────────────────────────────┐  │
│  │        │                    │ アームドパラディン    [E]   │  │
│  │ カード │                    │ 火                          │  │
│  │  UI    │                    │ コスト: 200G (火火)         │  │
│  │        │                    │ HP: 30 / 40    AP: 20       │  │
│  │        │                    │ 配置制限: 地不可  アイテム: 武器│  │
│  │        │                    │                             │  │
│  │        │                    │ 【呪い】なし                │  │
│  │        │                    │ 【スキル】無効化: 巻物...   │  │
│  │        │                    │ 【秘術】火炎放射(50G): ...  │  │
│  └────────┘                    └─────────────────────────────┘  │
│     左側                                   右側                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 選択モード（召喚/バトル時）

```
┌─────────────────────────────────────────────────────────────────┐
│                    【半透明オーバーレイ】                        │
│                                                                 │
│  ┌────────┐  ┌──────────────┐  ┌─────────────────────────────┐  │
│  │        │  │              │  │ アームドパラディン    [E]   │  │
│  │ カード │  │ 召喚しますか？│  │ 火                          │  │
│  │  UI    │  │              │  │ コスト: 200G (火火)         │  │
│  │        │  │  [Yes] [No]  │  │ HP: 30 / 40    AP: 20       │  │
│  │        │  │              │  │ 配置制限: 地不可  アイテム: 武器│  │
│  │        │  └──────────────┘  │                             │  │
│  │        │                    │ 【呪い】なし                │  │
│  │        │                    │ 【スキル】無効化: 巻物...   │  │
│  │        │                    │ 【秘術】火炎放射(50G): ...  │  │
│  └────────┘                    └─────────────────────────────┘  │
│     左側         中央                       右側                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## パネル構成

### 左パネル（カードUI）

Card.tscnをそのまま表示。クリーチャーの見た目を確認できる。

### 右パネル（詳細情報）概要

| 項目 | データソース | 条件 |
|------|-------------|------|
| 名前 + レア度 | `name`, `rarity` | 常時 |
| 属性 | `element` | 常時 |
| コスト + 必要土地 | `cost.mp`, `cost.lands_required` | 常時 |
| HP / AP | `current_hp` / `hp`, `ap` | 常時（横並び） |
| 配置制限 / アイテム制限 | `restrictions.cannot_summon`, `restrictions.item_use` | 常時（横並び） |
| 呪い | `curse_effects` | 常時 |
| スキル | `ability_parsed.keywords` | あれば |
| 秘術 | `ability_parsed.mystic_art(s)` | あれば |

### 中央パネル（選択モードのみ）

確認ダイアログ。Yes/Noボタンで選択を確定またはキャンセル。

| 状況 | 確認テキスト |
|------|-------------|
| 召喚時 | 「召喚しますか？」 |
| バトル時 | 「このクリーチャーで戦いますか？」 |
| 侵略時 | 「侵略しますか？」 |

### 右パネル（詳細情報）

**表示順序（上から下）：**

| 順序 | 項目 | データソース | 表示形式 | 条件 |
|------|------|-------------|----------|------|
| 1 | 名前 | `name` | テキスト | 常時 |
| 2 | レア度 | `rarity` | 名前の右隣に表示 | 常時 |
| 3 | 属性 | `element` | アイコンまたはテキスト | 常時 |
| 4 | コスト | `cost.mp`, `cost.lands_required` | `コスト: 30G (火火)` | 常時 |
| 5 | HP | `current_hp` / (`hp` + `base_up_hp`) | `HP: 30 / 40` | 常時 |
| 6 | AP | `ap` + `base_up_ap` | HPの右隣に表示 | 常時 |
| 7 | 配置制限 | `restrictions.cannot_summon` | `配置制限: 地不可` | 常時 |
| 8 | アイテム制限 | `restrictions.item_use` | 配置制限の右隣に表示 | 常時 |
| 9 | 呪い | `curse_effects` | 適用中の呪い | 常時 |
| 10 | スキル | `ability_parsed.keywords` | スキル名: 説明 | あれば |
| 11 | 秘術 | `ability_parsed.mystic_art(s)` | 秘術名: 説明 | あれば |

**レイアウト詳細：**

```
┌─────────────────────────────────┐
│ アームドパラディン    [E]       │  ← 名前 + レア度
│ 火                              │  ← 属性
│ コスト: 200G (火火)             │  ← コスト + 必要土地
│ HP: 30 / 40    AP: 20           │  ← HP と AP は横並び
│ 配置制限: 地不可  アイテム: 武器 │  ← 横並び
│                                 │
│ 【呪い】                        │
│ なし                            │
│                                 │
│ 【スキル】                      │  ← あれば表示
│ 無効化: 巻物攻撃を無効化        │
│                                 │
│ 【秘術】                        │  ← あれば表示
│ 火炎放射(50G): 敵に30ダメージ   │
└─────────────────────────────────┘
```

**コストの表示例：**
- `mp: 200, lands_required: ["fire", "fire"]` → `コスト: 200G (火火)`
- `mp: 30, lands_required: null` → `コスト: 30G`

**配置制限の表示例：**
- `restrictions.cannot_summon: ["earth"]` → `配置制限: 地不可`
- `restrictions.cannot_summon: ["fire", "water"]` → `配置制限: 火水不可`
- `restrictions.cannot_summon: null` → `配置制限: なし`

**アイテム制限の表示例：**
- `restrictions.item_use: ["武器"]` → `アイテム制限: 武器`
- `restrictions.item_use: ["武器", "防具"]` → `アイテム制限: 武器,防具`
- `restrictions.item_use: null` → `アイテム制限: なし`

**スキル/秘術がない場合は非表示**

---

## 閉じる操作

| モード | 閉じ方 | 結果 |
|--------|--------|------|
| 閲覧モード | どこでもタップ | パネルを閉じる |
| 選択モード | Yesボタン | 選択を確定して閉じる |
| 選択モード | Noボタン | キャンセルして閉じる |

---

## 実装設計

### 新規ファイル

| ファイル | 役割 |
|----------|------|
| `scripts/ui_components/creature_info_panel_ui.gd` | 情報パネルUI管理 |

### 変更ファイル

| ファイル | 変更内容 |
|----------|----------|
| `scripts/creatures/creature_card_3d_quad.gd` | タップ判定追加（Area3D） |
| `scripts/ui_manager.gd` | パネル管理、シグナル接続 |

### クラス設計

#### CreatureInfoPanelUI

```gdscript
class_name CreatureInfoPanelUI
extends Control

signal panel_closed
signal selection_confirmed(creature_data: Dictionary)
signal selection_cancelled

# UI要素
var background_overlay: Control  # 半透明オーバーレイ
var left_panel: Control          # カードUI
var center_panel: Control        # Yes/No確認（選択モードのみ）
var right_panel: Control         # 詳細情報

# 状態
var is_visible: bool = false
var is_selection_mode: bool = false
var current_creature_data: Dictionary = {}
var current_tile_index: int = -1

# 公開メソッド
func show_view_mode(creature_data: Dictionary, tile_index: int)
func show_selection_mode(creature_data: Dictionary, confirmation_text: String)
func hide_panel()
func is_panel_visible() -> bool
```

#### CreatureCard3DQuad（変更）

```gdscript
# 追加
signal creature_tapped(creature_data: Dictionary, tile_index: int)

var collision_area: Area3D
var collision_shape: CollisionShape3D

func _setup_tap_detection()
func _on_input_event(camera, event, position, normal, shape_idx)
```

### シグナルフロー

```
[3Dクリーチャーカード]
        │
        │ タップ検出
        ▼
creature_tapped(creature_data, tile_index)
        │
        ▼
[UIManager]
        │
        │ モード判定
        ▼
[CreatureInfoPanelUI]
        │
        ├── 閲覧モード → show_view_mode()
        │       │
        │       └── どこでもタップ → hide_panel()
        │
        └── 選択モード → show_selection_mode()
                │
                ├── Yes → selection_confirmed シグナル
                └── No  → selection_cancelled シグナル
```

---

## タップ判定実装

### Area3D構成

```
CreatureCard3DQuad (Node3D)
├── SubViewport
├── MeshInstance3D (QuadMesh)
└── Area3D (新規追加)
    └── CollisionShape3D (BoxShape3D)
```

### CollisionShapeサイズ

```gdscript
# カードサイズに合わせる
const CARD_3D_WIDTH = 2.4
const CARD_3D_HEIGHT = 3.6

var box_shape = BoxShape3D.new()
box_shape.size = Vector3(CARD_3D_WIDTH, CARD_3D_HEIGHT, 0.1)
```

### 入力イベント処理

```gdscript
func _on_input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			creature_tapped.emit(creature_data, tile_index)
	elif event is InputEventScreenTouch:
		if event.pressed:
			creature_tapped.emit(creature_data, tile_index)
```

---

## 半透明オーバーレイ

### 実装方法

```gdscript
# 背景オーバーレイ（画面全体を覆う）
var background_overlay: ColorRect

func _setup_overlay():
	background_overlay = ColorRect.new()
	background_overlay.color = Color(0, 0, 0, 0.5)  # 半透明黒
	background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	background_overlay.gui_input.connect(_on_overlay_input)

func _on_overlay_input(event):
	# 閲覧モードの場合、どこでもタップで閉じる
	if not is_selection_mode:
		if event is InputEventMouseButton and event.pressed:
			hide_panel()
		elif event is InputEventScreenTouch and event.pressed:
			hide_panel()
```

---

## 今後の拡張

### Phase 1（現在）
- 基本的なパネル表示
- 閲覧モード、選択モード

### Phase 2（将来）
- 常時表示モード
- PCでのホバープレビュー
- アニメーション（フェードイン/アウト）

### Phase 3（将来）
- 複数クリーチャー比較表示
- バトル時の攻撃/防御側表示
- 効果予測表示

---

## 関連ドキュメント

| ファイル | 内容 |
|----------|------|
| `docs/design/tile_system.md` | タイルシステム（クリーチャー選択含む） |
| `docs/implementation/creature_3d_display_implementation.md` | 3Dクリーチャー表示実装 |

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025/12/11 | 初版作成 |
| 2025/12/11 | レイアウト更新、半透明オーバーレイ追加、閉じる操作の詳細化 |
