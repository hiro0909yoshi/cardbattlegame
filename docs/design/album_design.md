# アルバム画面設計書

## 概要

アルバム画面は、プレイヤーが所持するカードの一覧表示、デッキ編集、統計情報を確認できる総合管理画面。メインメニューからアクセスでき、バトルモードフラグによって「ソロバトル用デッキ選択」と「通常アルバム」の2つのモードで動作する。

---

## 画面モード

### 1. 通常モード（is_battle_mode = false）

メインメニューから「アルバム」ボタンで遷移。左パネルに4つのメニュー、右パネルには統計情報またはデッキ選択を表示。

### 2. バトルモード（is_battle_mode = true）

メインメニューから「ソロバトル」ボタンで遷移。初期表示時にブック（デッキ）選択画面を表示。デッキ選択後、バトル画面（Main.tscn）へ遷移。

モード判定方法:
```gdscript
if GameData.has_meta("is_selecting_for_battle"):
    is_battle_mode = GameData.get_meta("is_selecting_for_battle")
else:
    is_battle_mode = false
```

---

## 画面構成とレイアウト

### 全体構成

```
┌─────────────────────────────────────────────────────────────────┐
│                      アルバム                                    │
├──────────────────┬────────────────────────────────────────────┤
│                  │                                            │
│  左パネル        │         右パネル                             │
│  (比率 4:6)      │         (比率 6:6)                          │
│                  │                                            │
│ [デッキ編集]     │  ・統計表示                                 │
│ [所持カード]     │  ・ブック選択                               │
│ [カードリセット] │  ・カード一覧（ページング対応）              │
│ [戻る]           │                                            │
│                  │                                            │
└──────────────────┴────────────────────────────────────────────┘
```

### レイアウト詳細

```
MarginContainer
└── HBoxContainer (alignment = 1)
    ├── LeftPanel (size_flags_horizontal = 3, size_flags_stretch_ratio = 4.0)
    │   └── VBoxContainer (separation = 29)
    │       ├── TitleLabel ("アルバム")
    │       ├── HSeparator
    │       ├── DeckEditButton (800×400)
    │       ├── CardListButton (800×400)
    │       ├── ResetCardsButton (800×200, 赤色)
    │       └── BackButton (800×400)
    │
    └── RightPanel (size_flags_horizontal = 3, size_flags_stretch_ratio = 6.0)
        └── ScrollContainer
            └── GridContainer (columns = 2, h_separation = 100, v_separation = 20)
                ├── (ブック選択ボタン×6 または 統計パネル)
                └── (カード一覧の場合: 10列グリッド)
```

---

## トップ画面

### 左パネル（メニュー）

固定4つのボタンを垂直配置。背景色は暗めグレー（Color(0.15, 0.15, 0.15, 0.9)）。

| ボタン | サイズ | 説明 |
|--------|--------|------|
| デッキ編集 | 800×400 | ブック選択画面を表示 → デッキ編集画面へ遷移 |
| 所持カード一覧 | 800×400 | カード統計画面を表示 |
| カードリセット | 800×200 | 所持カードを全てリセット（デバッグ用） |
| 戻る | 800×400 | メインメニューへ戻る |

**ボタンカラー設定**:
- 通常: Color(1, 1, 1, 1)
- リセットボタン: Color(1, 0.3, 0.3, 1) （警告色・赤）

### 右パネル（初期状態）

通常モードでは初期表示として左パネルメニュー説明を表示する、またはブックアイコン画像を配置。バトルモードでは即座にブック選択を表示。

---

## ブック選択画面

### 概要

6つのデッキスロットを2×3グリッド状に表示。各ボタンにはデッキ名とカード種類数を表示。

### 表示仕様

- **GridContainer**: columns = 2, h_separation = 100, v_separation = 20
- **各ボタン**: custom_minimum_size = Vector2(1000, 400)
- **フォントサイズ**: 48

### ボタンテンプレート

```
┌─────────────────────┐
│  ブック1            │
│  (37種類)          │
│                     │
└─────────────────────┘
```

データ取得:
```gdscript
var deck_name = GameData.player_data.decks[i].get("name", "ブック" + str(i + 1))
var card_count = GameData.player_data.decks[i].get("cards", {}).size()
book_button.text = deck_name + "\n(" + str(card_count) + "種類)"
```

### 遷移処理

ブックボタン押下時:

```gdscript
func _on_book_selected(book_index: int):
    GameData.selected_deck_index = book_index

    if is_battle_mode:
        # バトルモード: フラグをクリアしてバトル画面へ
        GameData.remove_meta("is_selecting_for_battle")
        get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")
    else:
        # 通常モード: デッキ編集画面へ
        get_tree().call_deferred("change_scene_to_file", "res://scenes/DeckEditor.tscn")
```

---

## 所持カード統計画面

### 概要

属性別（火・水・地・風・無）、カードタイプ別（アイテム・スペル）の所持状況を統計表示。各カテゴリをクリックすると詳細なカード一覧へ遷移。

### 統計パネル表示

**GridContainer**: columns = 2, h_separation = 100, v_separation = 20

各パネルサイズ: custom_minimum_size = Vector2(900, 400)

### パネルテンプレート

```
┌────────────────────────────────────┐
│  火属性                            │
│  合計: 32 / 64 (50.0%)            │
│  [C] 8 / 16 (50.0%)               │
│  [N] 12 / 16 (75.0%)              │
│  [S] 10 / 16 (62.5%)              │
│  [R] 2 / 16 (12.5%)               │
└────────────────────────────────────┘
```

### パネルスタイル

属性色のグラデーション背景:

```gdscript
var element_color = _get_element_color_for_category(category)
var style = StyleBoxFlat.new()
style.bg_color = Color(element_color.r * 0.5, element_color.g * 0.5, element_color.b * 0.5, 0.9)
style.border_color = Color(element_color.r * 0.8, element_color.g * 0.8, element_color.b * 0.8, 0.7)
style.set_border_width_all(2)
style.set_corner_radius_all(10)
```

ホバー時: bg_color × 0.6（明るく）
押下時: bg_color × 0.7（最も明るく）

### 統計データ計算

レアリティ別の所有数と総数:

```gdscript
func _calculate_collection_stats() -> Dictionary:
    var stats = {}
    for category in ["fire", "water", "earth", "wind", "neutral", "item", "spell"]:
        stats[category] = {
            "total_owned": 0,
            "total_cards": 0,
            "C": {"owned": 0, "total": 0},
            "N": {"owned": 0, "total": 0},
            "S": {"owned": 0, "total": 0},
            "R": {"owned": 0, "total": 0}
        }

    for card in CardLoader.all_cards:
        # カテゴリ判定と統計更新
        ...

    return stats
```

### 属性色定義

| カテゴリ | 色(RGB) | 説明 |
|---------|---------|------|
| fire（火） | (0.9, 0.3, 0.1) | 赤 |
| water（水） | (0.1, 0.4, 0.9) | 青 |
| earth（地） | (0.5, 0.35, 0.1) | 茶 |
| wind（風） | (0.1, 0.7, 0.3) | 緑 |
| neutral（無） | (0.6, 0.6, 0.6) | グレー |
| item（アイテム） | (0.7, 0.6, 0.2) | 黄 |
| spell（スペル） | (0.5, 0.2, 0.7) | 紫 |

---

## カード一覧画面

### 概要

選択されたカテゴリのカードを10列グリッドで表示。40枚/ページのページング機能付き。左パネルを非表示にしてフル幅表示。

### グリッド仕様

```gdscript
grid_container.columns = 10
grid_container.add_theme_constant_override("h_separation", 40)
grid_container.add_theme_constant_override("v_separation", 20)
grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

1ページ = 10列 × 4行 = 40枚（スクロール可能）

### ヘッダー行

ページングコントロール:

```
[← 戻る] [スペース] [◀ 前] [火属性 (64種)] [1 / 3] [次 ▶] [スペース]
```

**各要素**:
- 戻るボタン: custom_minimum_size = Vector2(200, 80), font_size = 36
- 前・次ボタン: custom_minimum_size = Vector2(160, 80), font_size = 36
- タイトル（属性名 + 種類数）: font_size = 48, color = Color.WHITE
- ページ番号: font_size = 42, color = Color.WHITE

### カードサムネイル

各カードは300×380サイズの PanelContainer で表示。

```
┌─────────────────────────┐
│                         │
│  [カード画像]           │
│  (280×280)             │
│                         │
├─────────────────────────┤
│ カード名               │
│ [レアリティ] 枚数       │
└─────────────────────────┘
```

**内部構成**:
- PanelContainer (custom_minimum_size = Vector2(300, 380))
  - VBoxContainer (separation = 4)
    - TextureRect (custom_minimum_size = Vector2(280, 280))
    - Label（カード名, font_size = 26）
    - Label（レアリティ + 所持数, font_size = 24）

### パネルスタイル

属性色のグラデーション背応:

```gdscript
var element_color = _get_element_color(element, card_type)
var style = StyleBoxFlat.new()
style.bg_color = Color(element_color.r, element_color.g, element_color.b, 0.35)
style.border_color = Color(element_color.r, element_color.g, element_color.b, 0.5)
style.set_border_width_all(2)
style.set_corner_radius_all(8)
```

**未所持時**: panel.modulate = Color(0.4, 0.4, 0.4, 0.8)（暗くグレイアウト）

### レアリティ色定義

| レアリティ | 色 |
|-----------|-----|
| R | Color(1.0, 0.85, 0.3) （金） |
| S | Color(0.85, 0.7, 1.0) （紫） |
| N | Color.WHITE （白） |
| C | Color.WHITE （白） |
| 未所持 | Color(0.4, 0.4, 0.4) （グレー） |

---

## デッキ編集画面

デッキ編集画面は別シーン（DeckEditor.tscn）で実装。Album.tscnからの遷移、および戻り遷移で管理。

### 画面遷移

```
Album.tscn (ブック選択)
    → DeckEditor.tscn (デッキ編集)
    → [保存] → Album.tscn (統計画面)
    → [戻る] → Album.tscn (統計画面)
```

### DeckEditor概要

- **左パネル**: 属性別フィルター、カード一覧（画像300×300付き）、宇宙風背景（属性色変化）
- **インフォパネル**: LeftPanel内にアンカー固定配置（anchor_left=0.55, anchor_top=0.075）
- **枚数選択UI**: InfoPanelContainer内にVBoxContainerで配置（Popup不使用、スクロールブロック防止）
- **枚数上限**: 各カード最大4枚、デッキ合計50枚

### フィルターボタン

8個のボタン（HBoxContainer）:

1. Deck（デッキ内カードのみ表示）
2. 無属性 → "neutral"
3. 火属性 → "fire"
4. 水属性 → "water"
5. 地属性 → "earth"
6. 風属性 → "wind"
7. Item → "item"
8. Spell → "spell"

### カードボタン仕様

- **サイズ**: custom_minimum_size = Vector2(420, 700)
- **内容**: 画像（300×300）+ テキスト情報
- **テキスト表示**:
  ```
  [カード名]
  [開発名（あれば）]
  [レアリティ] [属性]
  所持: X枚
  デッキ: Y枚（デッキに入っている場合のみ表示）
  AP:00 / HP:00 (クリーチャー型のみ)
  ```

### インフォパネル

カードタップでInfoPanelContainer内に表示。シーン（creature_info_panel.tscn等）をインスタンス化。

- Creature: creature_info_panel.tscn
- Item: item_info_panel.tscn
- Spell: spell_info_panel.tscn

**InfoPanelContainer配置**（LeftPanel直下、アンカー固定）:
```
anchor_left = 0.55, anchor_top = 0.075
anchor_right = 1.0, anchor_bottom = 1.0
offset_left = 300, offset_right = -25
clip_contents = true
```

**MainContainer位置調整**（コード内）:
```gdscript
main_container.position = Vector2(-120, -140)
```

### 枚数選択UI

InfoPanelContainer内にVBoxContainerとして配置（Popup不使用）。
Popupを使うとスクロールがブロックされるため、通常のControlノードを使用。

```
所持: 5枚 / デッキ内: 2枚

[0枚] [1枚] [2枚] [3枚] [4枚]

         [閉じる]
```

**ボタン仕様**:
- custom_minimum_size = Vector2(140, 120)
- font_size = 40
- 所持数を超える枚数は disabled = true（グレイアウト）
- コンテナ下部に配置（position.y = container_h - dialog_h - 10）

### デッキカウント表示

右パネルに属性別・タイプ別の集計表示:

```
🔥 15
💧 12
🪨 10
🌪️ 8
⚪ 3
▲ 1 (アイテム)
◆ 1 (スペル)

現在: 50/50
```

---

## 背景エフェクト（星）

### 星エフェクトの仕様

各カテゴリ表示時に、属性色ベースの星をランダム配置。キラキラアニメーション付き。

```gdscript
func _setup_category_background(element_color: Color):
    var bg_container = Control.new()
    bg_container.name = "CategoryBG"
    bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)

    # グラデーション背景
    var gradient = Gradient.new()
    gradient.set_color(0, Color(element_color.r * 0.12, element_color.g * 0.12, element_color.b * 0.12, 0.95))
    gradient.set_color(1, Color(0.02, 0.02, 0.05, 0.98))

    var grad_tex = GradientTexture2D.new()
    grad_tex.gradient = gradient
    grad_tex.fill_from = Vector2(0, 0)
    grad_tex.fill_to = Vector2(0, 1)

    # 星の配置（60個）
    var viewport_size = get_viewport().get_visible_rect().size
    var rng = RandomNumberGenerator.new()
    rng.seed = _current_category.hash()  # カテゴリごとに同じ配置

    for i in range(60):
        var star = PanelContainer.new()
        var star_size = rng.randf_range(2.0, 6.0)
        star.custom_minimum_size = Vector2(star_size, star_size)
        star.position = Vector2(rng.randf_range(0, viewport_size.x), rng.randf_range(0, viewport_size.y))

        # 属性色を30%混ぜた星色
        var star_color: Color
        if rng.randf() < 0.3:
            star_color = Color(
                lerpf(1.0, element_color.r, 0.5) * brightness,
                lerpf(1.0, element_color.g, 0.5) * brightness,
                lerpf(1.0, element_color.b, 0.5) * brightness,
                brightness
            )
        else:
            star_color = Color(brightness, brightness, brightness * 1.1, brightness)

        # キラキラアニメーション（40%の星）
        if rng.randf() < 0.4:
            var tween = create_tween()
            tween.set_loops()
            var delay = rng.randf_range(0.0, 3.0)
            var duration = rng.randf_range(1.5, 3.5)
            tween.tween_interval(delay)
            tween.tween_property(star, "modulate:a", rng.randf_range(0.2, 0.5), duration)
            tween.tween_property(star, "modulate:a", 1.0, duration)
```

**仕様**:
- 星個数: 60個
- サイズ: 2～6px（ランダム）
- 属性色ブレンド: 30%の星に属性色を混ぜ
- キラキラアニメーション: 40%の星に実装
- アニメーション周期: 1.5～3.5秒（ランダム）

---

## カード画像パス

### クリーチャー

```
res://assets/images/creatures/{element}/{id}.png

例:
- res://assets/images/creatures/fire/1.png
- res://assets/images/creatures/water/2.png
```

**要素**: fire, water, earth, wind, neutral

### スペル

```
res://assets/images/spells/{id}.png

例:
- res://assets/images/spells/1.png
```

### アイテム

```
res://assets/images/items/{id}.png

例:
- res://assets/images/items/1.png
```

### パス取得ロジック

```gdscript
func _get_card_image_path(card_id: int, card_type: String, element: String) -> String:
    if card_type == "creature":
        return "res://assets/images/creatures/%s/%d.png" % [element, card_id]
    elif card_type == "spell":
        return "res://assets/images/spells/%d.png" % card_id
    elif card_type == "item":
        return "res://assets/images/items/%d.png" % card_id
    return ""

# 使用時
if image_path != "" and ResourceLoader.exists(image_path):
    tex_rect.texture = load(image_path)
```

---

## 画面遷移

### 遷移図

```
MainMenu.tscn
    ├─ [アルバム] → Album.tscn (通常モード)
    │               ├─ [デッキ編集] → ブック選択 → [選択] → DeckEditor.tscn
    │               │                             ↓
    │               │                        (保存/戻る) → Album.tscn
    │               └─ [所持カード] → 統計表示
    │                                └─ [カテゴリ選択] → カード一覧（10列グリッド）
    │                                                   └─ [戻る] → 統計表示
    │
    └─ [ソロバトル] → Album.tscn (バトルモード)
                    └─ ブック選択
                       └─ [選択] → Main.tscn (バトル開始)
                       └─ [戻る] → MainMenu.tscn
```

### メインメニュー → アルバム（通常）

```gdscript
# main_menu.gd
func _on_album_pressed():
    get_tree().change_scene_to_file("res://scenes/Album.tscn")
```

Album.gd側:

```gdscript
func _ready():
    if GameData.has_meta("is_selecting_for_battle"):
        is_battle_mode = GameData.get_meta("is_selecting_for_battle")
    else:
        is_battle_mode = false

    if is_battle_mode:
        scroll_container.visible = true
        _show_book_selection()
    else:
        scroll_container.visible = false
```

### メインメニュー → アルバム（バトル）

```gdscript
# main_menu.gd
func _on_solo_battle_pressed():
    GameData.set_meta("is_selecting_for_battle", true)
    get_tree().change_scene_to_file("res://scenes/Album.tscn")
```

### アルバム → デッキ編集

```gdscript
# album.gd
func _on_deck_edit_pressed():
    GameData.selected_deck_index = book_index  # グローバルで保存
    get_tree().change_deferred("change_scene_to_file", "res://scenes/DeckEditor.tscn")

# deck_editor.gd 読み込み
func _ready():
    current_deck = GameData.get_current_deck()["cards"].duplicate()
```

### デッキ編集 → アルバム

```gdscript
# deck_editor.gd
func _on_back_pressed():
    get_tree().change_scene_to_file("res://scenes/Album.tscn")
```

### アルバム（バトルモード） → メインメニュー

```gdscript
# album.gd
func _on_back_pressed():
    if is_battle_mode:
        GameData.remove_meta("is_selecting_for_battle")

    get_tree().call_deferred("change_scene_to_file", "res://scenes/MainMenu.tscn")
```

---

## UIコンポーネント一覧

### シーンファイル

| ファイル | 用途 |
|--------|------|
| Album.tscn | アルバム画面メイン |
| DeckEditor.tscn | デッキ編集画面 |
| scenes/ui/creature_info_panel.tscn | クリーチャー情報パネル |
| scenes/ui/item_info_panel.tscn | アイテム情報パネル |
| scenes/ui/spell_info_panel.tscn | スペル情報パネル |

### スクリプトファイル

| ファイル | 用途 |
|--------|------|
| scripts/album.gd | アルバム画面ロジック |
| scripts/deck_editor.gd | デッキ編集画面ロジック |

### 自動読み込み（Autoload）

| 名前 | ファイル | 用途 |
|------|---------|------|
| GameData | scripts/autoload/game_data.gd | ゲーム全体のデータ管理 |
| UserCardDB | scripts/autoload/user_card_db.gd | ユーザー所持カード管理 |
| CardLoader | scripts/autoload/card_loader.gd | カード定義データ読み込み |

---

## データ構造

### GameData.player_data.decks

```gdscript
{
    "decks": [
        {
            "name": "ブック1",
            "cards": {
                1: 2,      # カードID: 枚数
                3: 1,
                5: 3,
                ...
            }
        },
        ...
    ]
}
```

### CardLoader.all_cards

```gdscript
[
    {
        "id": 1,
        "name": "ファイアドレイク",
        "dev_name": "火のドラゴン",
        "type": "creature",
        "element": "fire",
        "rarity": "R",
        "ap": 7,
        "hp": 6,
        "ability_parsed": [...],
        ...
    },
    ...
]
```

### UserCardDB（所持カード）

```gdscript
# 呼び出し方
var owned_count = UserCardDB.get_card_count(card_id)  # 整数

# リセット
UserCardDB.reset_database()
UserCardDB.flush()
```

---

## 関連ドキュメント

- `docs/design/main_menu_design.md` - メインメニュー遷移関連
- `docs/design/design.md` - 全体設計
- `docs/implementation/implementation_patterns.md` - 実装パターン
- `docs/development/coding_standards.md` - GDScript規約

---

## 実装上の注意点

### シグナル接続

ボタン接続時は常に `is_connected()` チェック後に接続:

```gdscript
# OK
if not button.pressed.is_connected(_on_button_pressed):
    button.pressed.connect(_on_button_pressed)

# 簡潔版（Album.gdで使用）
button.pressed.connect(_on_button_pressed)
```

### null参照チェック

```gdscript
# OK
var panel = get_node_or_null("SomePath")
if panel and is_instance_valid(panel):
    panel.queue_free()

# また
if current_info_panel and is_instance_valid(current_info_panel):
    current_info_panel.queue_free()
    current_info_panel = null
```

### テクスチャ読み込み

```gdscript
if ResourceLoader.exists(image_path):
    tex_rect.texture = load(image_path)
```

### プライベート変数

クラス内部変数は `_` プレフィックス:

```gdscript
var _current_category: String = ""
var _current_page: int = 0
var _filtered_cards: Array[Dictionary] = []
var _category_names = { ... }
```

---

最終更新: 2026-03-17
