# プレイヤー情報パネル UI 実装仕様書

**作成日**: 2025-11-26  
**最終更新**: 2025-01-20  
**ステータス**: ✅ 実装完了  
**対象ファイル**: 
- `scripts/ui_components/player_info_panel.gd`
- `scripts/ui_components/player_status_dialog.gd`
- `scenes/ui/player_status_dialog.tscn`
- `scripts/ui_manager.gd`

---

## 概要

画面左上に縦積みで配置された小型プレイヤーパネル。各プレイヤーの基本情報（名前、EP、TEP）と刻印状態を表示。パネルをクリックするとステータスダイアログが表示され、詳細情報（保有土地、クリーチャー、手札）が確認できる。

---

## パネル表示（PlayerInfoPanel）

### パネル配置

| 項目 | 値 |
|------|-----|
| **位置** | 画面左上 (28px, 28px～) |
| **配列方向** | 縦積み（上から順に） |
| **パネル間隔** | 14px |
| **パネル幅** | 260px |
| **パネル高さ** | 190px |

```
画面左上
│
├─ [Panel 1] (y=28)
│   Player 1 情報
│
├─ [Panel 2] (y=189)
│   Player 2 情報
│
├─ [Panel 3] (y=350)
│   Player 3 情報
│
├─ [Panel 4] (y=511)
│   Player 4 情報
│
└─ [世界刻印ラベル] (パネル下)
```

### パネルデザイン

| 要素 | 値 |
|------|-----|
| **フォントサイズ** | 28px |
| **背景色** | 黒 (透明度 0.7) |
| **枠線色** | `GameConstants.PLAYER_COLORS[player_id]` |
| **枠線幅** | 2px |

### プレイヤーカラー

| プレイヤー | 色 |
|-----------|-----|
| プレイヤー1 | 赤 (#ff0000) |
| プレイヤー2 | 青 (#0000ff) |
| プレイヤー3 | 緑 (#00ff00) |
| プレイヤー4 | 黄 (#ffff00) |

### 表示内容

#### 標準表示

```
1 プレイヤー1
EP: 1200
TEP: 3000
SG: N S E W
```

#### ターン中（ハイライト表示）

```
1 ● プレイヤー1
EP: 1200
TEP: 3000
SG: N S E W
```

※ 先頭の数字は順位（TEP降順、同率は同順位）
※ SG行: 取得済みシグナル=黄色、未取得=グレーで表示

#### 刻印がある場合

```
1 プレイヤー1
EP: 1200
TEP: 3000
SG: N S E W
呪: ダイス6
```

### 世界刻印ラベル

パネル下部に世界刻印情報を表示。

```
世界: カオスパニック (3R)
```

- 世界刻印がない場合は非表示
- フォントサイズ: 22px
- 色: 紫

### マウスインタラクション

- **マウスフィルター**: 
  - Panel: `MOUSE_FILTER_STOP` (クリック検出)
  - RichTextLabel: `MOUSE_FILTER_IGNORE` (透過)
- **クリック動作**: パネルをクリック → `player_panel_clicked(player_id)` シグナル発火
- **ダイアログ表示**: UIManager が受け取って `show_for_player()` を呼び出し

---

## ステータスダイアログ（PlayerStatusDialog）

### シーン構成

**ファイル**: `scenes/ui/player_status_dialog.tscn`

```
PlayerStatusDialog (Control)
├── BackgroundRect (ColorRect) - 半透明黒背景、クリックで閉じる
└── MainPanel (Control)
    ├── ParchmentBg (TextureRect) - 背景画像（インフォ.png）
    └── ContentMargin (MarginContainer)
        └── VBoxContainer
            ├── TitleLabel (Label) - タイトル
            ├── Separator (HSeparator)
            └── StatusLabel (RichTextLabel) - ステータス内容
```

### ダイアログデザイン

| 要素 | 値 |
|------|-----|
| **背景画像** | `res://assets/ui/インフォ.png` |
| **背景オーバーレイ** | 黒 (透明度 0.5) |
| **タイトルフォント** | 60px |
| **本文フォント** | 40px（太字: 44px） |
| **テキスト色** | 茶色 (#4d4026) |
| **マージン** | 左60, 上80, 右60, 下40 |

### 表示内容（5列テーブル構成）

```
┌─────────────────────────────────────────────────────────────────┐
│                    プレイヤー1のステータス                        │
├─────────────────────────────────────────────────────────────────┤
│ 基本情報        │     │ マップ情報      │          │ 手札        │
│ プレイヤー1     │     │ 周回数: 1       │          │ ■ ファイア  │
│ EP: 1200     │     │ ターン数: 5     │          │ ◆ マジック  │
│ TEP: 3000   │     │ 破壊数: 2       │          │ ● 剣        │
├─────────────────────────────────────────────────────────────────┤
│ 保有土地                                                         │
│ 火: 3個  水: 2個  風: 1個  土: 0個  無: 0個                       │
├─────────────────────────────────────────────────────────────────┤
│ 保有クリーチャー                                                  │
│ ハイド [バイタリティ]  HP: 30 / 30  AP: 30                       │
│ アモン  HP: 25 / 50  AP: 45                                      │
└─────────────────────────────────────────────────────────────────┘
```

### 手札アイコン

カード名の左にタイプ別のアイコン（色付き文字）を表示。

#### クリーチャー（■）

| 属性 | 色 |
|------|-----|
| 火 | 赤 (#ff4444) |
| 水 | 青 (#4444ff) |
| 土 | 茶 (#aa8844) |
| 風 | 緑 (#44ff44) |
| 無 | グレー (#888888) |

#### スペル（◆）

| スペルタイプ | 色 |
|-------------|-----|
| 単体対象 | オレンジ (#ffaa00) |
| 複数対象 | ピンク (#ff00aa) |
| 単体特殊能力付与 | 水色 (#00aaff) |
| 複数特殊能力付与 | 紫 (#aa00ff) |
| 世界呪 | 赤 (#ff0000) |

#### アイテム（●）

| アイテムタイプ | 色 |
|---------------|-----|
| 武器 | オレンジ (#ff6600) |
| 防具 | 青 (#0066ff) |
| アクセサリ | 金 (#ffcc00) |
| 巻物 | 緑 (#66ff66) |

### UIイベント

- **ESCキー**: ダイアログを閉じる
- **背景クリック**: ダイアログを閉じる
- **閉じるボタン**: 削除済み（背景クリックで閉じるため不要）

---

## UIManager 統合

### 初期化フロー

```
UIManager._ready()
    ↓
create_ui() で生成:
  - player_info_panel (スクリプトから生成)
  - player_status_dialog (シーンからインスタンス化)
    ↓
connect_ui_signals() で接続:
  - player_info_panel.player_panel_clicked.connect(_on_player_panel_clicked)
    ↓
setup_systems() で初期化:
  - player_info_panel.initialize(ui_layer, player_system_ref, null, player_count)
  - player_status_dialog.initialize(ui_layer, player_system_ref, board_system_ref, 
                                     player_info_panel, game_flow_manager_ref, card_system_ref)
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

| メソッド | 説明 |
|---------|------|
| `initialize(parent, player_system, board_system, count)` | パネル初期化、プレイヤー数を指定 |
| `create_panels()` | プレイヤー数分のパネルを作成 |
| `create_world_curse_label()` | 世界刻印ラベルを作成 |
| `update_all_panels()` | 全パネルを更新 |
| `update_single_panel(player_id)` | 単一パネルを更新 |
| `build_player_info_text(player, player_id)` | 表示テキストを構築 |
| `_build_signal_text(player_id)` | 取得済みシグナルテキストを構築 |
| `set_game_flow_manager(gfm)` | GFM参照設定、ターン・シグナルシグナル接続 |
| `get_player_ranking(player_id)` | 順位を取得 |
| `calculate_all_rankings()` | 全プレイヤーの順位を計算 |
| `get_lands_by_element(player_id)` | 属性別土地数を取得 |
| `get_creatures_on_lands(player_id)` | 保有クリーチャーを取得 |

**シグナル**:

- `player_panel_clicked(player_id: int)` - パネルクリック時に発火

### PlayerStatusDialog.gd

**主要メソッド**:

| メソッド | 説明 |
|---------|------|
| `initialize(parent, player_system, board_system, player_info_panel, game_flow_manager, card_system)` | ダイアログ初期化 |
| `show_for_player(player_id)` | ダイアログを表示 |
| `hide_dialog()` | ダイアログを非表示 |
| `build_status_text(player_id)` | ステータステキストを構築 |
| `build_hand_text(player_id)` | 手札テキストを構築 |
| `_get_card_icon(card)` | カードアイコンを取得 |
| `_get_creature_icon(card)` | クリーチャーアイコンを取得 |
| `_get_spell_icon(card)` | スペルアイコンを取得 |
| `_get_item_icon(card)` | アイテムアイコンを取得 |

**システム参照**:

| 参照 | 用途 |
|------|------|
| `player_system_ref` | プレイヤー情報 |
| `board_system_ref` | 土地・クリーチャー情報 |
| `game_flow_manager_ref` | マップ情報（周回、ターン、世界刻印） |
| `card_system_ref` | 手札情報 |
| `player_info_panel` | 土地・クリーチャー取得メソッド |

---

## 実装チェックリスト

### パネル表示
- [x] パネルが縦に並ぶ（左上から順に）
- [x] パネルサイズが260×190px
- [x] フォントサイズが28px
- [x] 表示項目が「順位」「プレイヤー名」「EP」「TEP」「シグナル取得状況」
- [x] ターン中は黄色●マーク
- [x] パネル枠線が GameConstants.PLAYER_COLORS 準拠
- [x] クリックでダイアログ表示
- [x] 世界刻印ラベル表示
- [x] 4人対戦対応（動的プレイヤー数）

### ステータスダイアログ
- [x] シーンベースで実装（player_status_dialog.tscn）
- [x] 背景画像（インフォ.png）使用
- [x] 基本情報セクション表示
- [x] マップ情報セクション表示（周回、ターン、破壊数）
- [x] 手札セクション表示（アイコン付き）
- [x] 保有土地セクション表示（属性別5種類）
- [x] 保有クリーチャーセクション表示（1行形式）
- [x] クリーチャー刻印表示
- [x] プレイヤー刻印表示
- [x] 世界刻印表示
- [x] ESCキーで閉じられる
- [x] 背景クリックで閉じられる
- [x] 閉じるボタン削除（背景クリックで代替）

---

## 関連ドキュメント

- `docs/design/hp_structure.md` - HP/AP 計算仕様
- `docs/design/spells/刻印効果.md` - 刻印システム
- `docs/design/quest_system_design.md` - 4人対戦対応

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2025/11/26 | 初版作成 |
| 2025/11/26 | 順位表示機能追加 |
| 2025/01/20 | パネルサイズ1.4倍に拡大（224×147px、フォント28px） |
| 2025/01/20 | 4人対戦対応（動的プレイヤー数） |
| 2025/01/20 | ステータスダイアログをシーンベースに変更 |
| 2025/01/20 | ダイアログ背景を画像（インフォ.png）に変更 |
| 2025/01/20 | 手札表示を追加（アイコン付き） |
| 2025/01/20 | マップ情報（周回、ターン、破壊数）を追加 |
| 2025/01/20 | 世界刻印表示を追加 |
| 2025/01/20 | 閉じるボタンを削除 |
| 2026/02/10 | パネルサイズを260×190pxに拡大 |
| 2026/02/10 | 取得済みシグナル表示を追加（SG行、黄色/グレー） |
| 2026/02/10 | GameFlowManager参照設定・シグナル取得時の即座更新を追加 |
