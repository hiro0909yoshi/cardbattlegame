# クリーチャー情報パネル設計書

# クリーチャー情報パネル設計書

## 概要

マップ上に配置されたクリーチャーをタップ/クリックすると、そのクリーチャーの詳細情報をパネルで表示する機能。

---

## 要件

### 機能要件

| 項目 | 内容 |
|------|------|
| 表示トリガー | 3Dクリーチャーカードをタップ/クリック |
| 非表示トリガー | 閉じるボタン or パネル外タップ |
| 対応プラットフォーム | PC（クリック）、スマホ（タップ） |

### 表示タイミング

以下のタイミングでクリーチャー情報パネルを表示可能：

- カード選択中（召喚/バトル/アイテム等）
- カメラ自動移動中（プレイヤー移動時）
- 自由カメラモード時

※ 将来的に常時表示可能に拡張予定

---

## パネル表示内容

### 左パネル（カードUI）

Card.tscnをそのまま表示。クリーチャーの見た目を確認できる。

### 右パネル（詳細情報）

| 項目 | データソース | 説明 | 条件 |
|------|-------------|------|------|
| HP | `current_hp` / (`hp` + `base_up_hp`) | 現在HP / 最大HP | 常時 |
| AP | `ap` + `base_up_ap` | 攻撃力 | 常時 |
| 呪い | `curse_effects`（タイル or クリーチャー） | 適用中の呪い | 常時 |
| スキル | `ability_parsed.keywords`, `ability_parsed.abilities` | スキル説明 | あれば |
| 秘術 | `ability_parsed.mystic_art` | 秘術説明 | あれば |

### 中央パネル（選択モードのみ）

確認ダイアログ。Yes/Noボタンで選択を確定またはキャンセル。

---

## UI設計

### 2つの表示モード

| モード | 用途 | 中央パネル |
|--------|------|-----------|
| 閲覧モード | タイル配置クリーチャーを見る | なし |
| 選択モード | 召喚/バトル時のカード選択 | Yes/No確認パネル |

### 閲覧モード（タイル配置クリーチャー）

```
┌────────┐                    ┌──────────────────────┐
│        │                    │ HP: 30 / 40         │
│ カード │                    │ AP: 20              │
│  UI    │                    │                     │
│        │                    │ 【呪い】            │
│        │                    │ なし                │
│        │                    │                     │
│        │                    │ 【スキル】          │
│        │                    │ 地形効果[火]：...   │
│        │                    │                     │
│        │                    │ 【秘術】            │
│        │                    │ 火炎放射：...       │
└────────┘                    └──────────────────────┘
   左側                               右側
```

### 選択モード（召喚/バトル時）

```
┌────────┐  ┌──────────────┐  ┌──────────────────────┐
│        │  │              │  │ HP: 30 / 40         │
│ カード │  │ 召喚しますか？│  │ AP: 20              │
│  UI    │  │              │  │                     │
│        │  │  [Yes] [No]  │  │ 【呪い】            │
│        │  │              │  │ なし                │
│        │  └──────────────┘  │                     │
│        │                    │ 【スキル】          │
│        │                    │ 地形効果[火]：...   │
│        │                    │                     │
│        │                    │ 【秘術】            │
│        │                    │ 火炎放射：...       │
└────────┘                    └──────────────────────┘
   左側         中央                   右側
```

### パネル構成

| パネル | 内容 | 常時表示 |
|--------|------|----------|
| 左パネル | カードUI（Card.tscn） | ✅ |
| 中央パネル | Yes/No確認 | 選択モードのみ |
| 右パネル | 詳細情報 | ✅ |

### 右パネル（詳細情報）の内容

**表示順序（上から下）：**

| 順序 | 項目 | 表示形式 | 条件付き |
|------|------|----------|----------|
| 1 | HP | `HP: 現在HP / MaxHP` | 常時表示 |
| 2 | AP | `AP: 値` | 常時表示 |
| 3 | 呪い | `【呪い】説明文` | 常時表示（なければ「なし」） |
| 4 | スキル | `【スキル】説明文` | あれば表示 |
| 5 | 秘術 | `【秘術】説明文` | あれば表示 |

**表示例：**

```
HP: 30 / 40
AP: 20

【呪い】
なし

【スキル】
地形効果[火]：火タイルでHP+10

【秘術】
火炎放射：敵全体に10ダメージ
```

**スキル/秘術がない場合：**

```
HP: 30 / 40
AP: 20

【呪い】
なし
```

※ スキル・秘術セクションは該当データがなければ非表示

### 中央パネル（Yes/No確認）

| 状況 | 確認テキスト |
|------|-------------|
| 召喚時 | 「召喚しますか？」 |
| バトル時 | 「このクリーチャーで戦いますか？」 |
| 侵略時 | 「侵略しますか？」 |

### 閉じる操作

| モード | 閉じ方 |
|--------|--------|
| 閲覧モード | パネル外タップ or 閉じるボタン |
| 選択モード | Yes/Noボタン押下 |

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

# UI要素
var panel: Panel
var close_button: Button
var name_label: Label
var stats_label: Label
var ability_label: RichTextLabel
var status_label: RichTextLabel
var location_label: Label

# 状態
var is_visible: bool = false
var current_creature_data: Dictionary = {}
var current_tile_index: int = -1

# 公開メソッド
func show_creature_info(creature_data: Dictionary, tile_info: Dictionary)
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
        │ パネル表示指示
        ▼
[CreatureInfoPanelUI]
        │
        │ show_creature_info()
        ▼
[パネル表示]
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

## パネル外タップで閉じる

### 実装方法

1. パネル表示中、背景に透明なControlを配置
2. 背景Controlのクリックでパネルを閉じる
3. パネル自体のクリックは伝播させない

```gdscript
# 背景オーバーレイ
var background_overlay: Control

func show_creature_info(...):
	# 背景を表示
	background_overlay.visible = true
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# パネル表示
	panel.visible = true

func _on_background_clicked():
	hide_panel()
```

---

## 今後の拡張

### Phase 1（現在）
- 基本的なパネル表示
- タップで表示、閉じるボタンで非表示

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
