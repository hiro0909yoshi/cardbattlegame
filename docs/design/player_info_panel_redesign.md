# プレイヤー情報パネル UI 再設計書

**作成日**: 2025-11-26  
**対象ファイル**: `scripts/ui_components/player_info_panel.gd`  
**関連ファイル**: `scripts/ui_manager.gd`, `scripts/ui_components/player_status_dialog.gd` (新規作成予定)

---

## 概要

現在のプレイヤー情報パネルをサイズダウンし、表示情報を最小化した上で、クリック機能を追加してステータス詳細表示への導線を整備する。

---

## 現状分析

### 現在のレイアウト
- **配置**: 画面上部に横4分割（プレイヤー数分）
- **パネルサイズ**: 幅 = viewport_width / 4 - 50px、高さ = 240px
- **表示項目**: 
  - プレイヤー名
  - 魔力（現在値）
  - 土地数
  - 総資産
  - 属性連鎖

### 問題点
1. パネルが大きすぎてゲーム画面を圧迫
2. 土地数や総資産などの詳細情報は使用頻度が低い
3. ステータス詳細を見るまでのワークフローが長い

---

## 新設計の仕様

### 1. レイアウト変更

#### パネル配置
- **方向**: 縦積み（上から順番に1, 2, 3, 4...）
- **開始位置**: 画面左上 (20px, 20px)
- **間隔**: 10px

#### パネルサイズ
| 項目 | サイズ |
|------|--------|
| 幅   | 160px  |
| 高さ | 105px  |

#### パネル色
- `GameConstants.PLAYER_COLORS` 配列を使用
- Player 1: 黄色、Player 2: 青色（既存仕様に統一）

### 2. 表示内容

表示項目（優先度順）:
1. **プレイヤー名** （ターン時はハイライト）
2. **魔力** （現在値）
3. **総魔力** （総資産額）

```
┌─────────────────┐
│● プレイヤー1    │
│魔力: 1200G      │
│総魔力: 3000G    │
└─────────────────┘
```

**注記**: 総魔力 = 現在の `calculate_total_assets()` の計算結果（名前のみ変更）

#### テキストフォーマット
- フォントサイズ: 14-15px 固定
- ターン中プレイヤー: 黄色●マーク + テキスト黄色ハイライト
- 非ターン中: 白色テキスト

### 3. インタラクション

#### クリック機能
- **動作**: パネルをクリックするとそのプレイヤーのステータスダイアログを表示
- **ダイアログ内容**: 
  - 詳細なステータス情報（土地数、属性連鎖、持有クリーチャー等）
  - ゲーム進行中でも確認可能
  - ESCキーで閉じる

#### ビジュアルフィードバック
- マウスホバー時: パネル背景色が若干明るくなる（インタラクティブ性を示唆）

---

## 実装計画

### Phase 1: PlayerInfoPanel 修正

**ファイル**: `scripts/ui_components/player_info_panel.gd`

#### 修正項目

1. **`create_single_panel(player_id)`**
   ```gdscript
   # 変更点:
   - panel_width = 160
   - panel_height = 105
   - panel_x = 20
   - panel_y = 20 + (105 + 10) * player_id  # 垂直積み
   - panel_style.border_color は固定値で統一可能
   ```

2. **`build_player_info_text(player, player_id)`**
   ```gdscript
   # 削除:
   - get_land_count() の呼び出し
   - get_chain_info() の呼び出し
   
   # 変更:
   - calculate_total_assets()は既存計算方法のまま使用
   - 表示ラベルのみ「総資産」→「総魔力」に変更
   
   # 表示構造:
   text += "[color=yellow]● [/color]"  # ターン時のみ
   text += player.name + "\n"
   text += "魔力: " + str(player.magic_power) + "G\n"
   text += "総魔力: " + str(calculate_total_assets(player_id)) + "G"
   ```

3. **フォントサイズ調整**
   ```gdscript
   # 固定値に変更（魔力・総魔力用に大きめサイズ）
   info_label.add_theme_font_size_override("normal_font_size", 15)
   ```

4. **クリック検出の追加**
   ```gdscript
   # 各パネルに gui_input シグナルを接続
   panel.gui_input.connect(_on_panel_clicked.bind(player_id))
   ```

#### 新規メソッド
```gdscript
func _on_panel_clicked(event: InputEvent, player_id: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# PlayerStatusDialogを表示する
		emit_signal("player_panel_clicked", player_id)
```

#### 新規シグナル
```gdscript
signal player_panel_clicked(player_id: int)
```

### Phase 2: PlayerStatusDialog 新規作成

**ファイル**: `scripts/ui_components/player_status_dialog.gd` (新規)

#### 機能
- モーダルダイアログとして表示
- プレイヤーIDに基づいて詳細ステータスを表示
- ESCキーで閉じる

#### データ取得方法
- **土地情報**: `board_system_ref.get_tile_data_array()` または `tile_nodes` から属性ごとに集計
- **保有クリーチャー**: `board_system_ref` の creature_system または creature_map から取得
  - 各クリーチャーの `name`, `current_hp`, `max_hp`, `current_ap` を表示

#### 表示内容
```
┌──────────────────────────────────┐
│ プレイヤー1のステータス            │
├──────────────────────────────────┤
│ [土地情報]                        │
│ 火: 3個  水: 2個  風: 1個  土: 0個 │
│                                  │
│ [保有クリーチャー]                 │
│ スライム                          │
│  HP: 150 / 250                   │
│  AP: 35                          │
│                                  │
│ ドラゴン                          │
│  HP: 200 / 300                   │
│  AP: 45                          │
└──────────────────────────────────┘
```

**表示項目**:
- **土地情報**: 属性（火/水/風/土）ごとの土地数
- **保有クリーチャー**: 名前、現在HP/最大HP、現在AP
- ~~属性連鎖~~: 削除（土地属性情報で十分）

### Phase 3: UIManager 統合

**ファイル**: `scripts/ui_manager.gd`

- PlayerInfoPanel の `player_panel_clicked` シグナルを接続
- PlayerStatusDialog の表示/非表示を管理

```gdscript
func _ready():
	# ... 既存コード ...
	if player_info_panel:
		player_info_panel.player_panel_clicked.connect(_on_player_panel_clicked)

func _on_player_panel_clicked(player_id: int):
	if player_status_dialog:
		player_status_dialog.show_for_player(player_id)
```

---

## UI階層構図

```
CanvasLayer (UILayer)
├── PlayerInfoPanel
│   ├── Panel (Player 1)
│   │   └── RichTextLabel
│   ├── Panel (Player 2)
│   │   └── RichTextLabel
│   └── ...
└── PlayerStatusDialog (新規)
	└── PanelContainer
		└── VBoxContainer
			├── Label (タイトル)
			├── RichTextLabel (ステータス情報)
			└── Button (閉じるボタン)
```

---

## 検証チェックリスト

### パネル表示
- [x] パネルが縦に並ぶ（左上から順に）
- [x] パネルサイズが160×105px
- [x] フォントサイズが15px
- [x] 表示項目が「プレイヤー名」「魔力」「総魔力」のみ
- [x] 土地数・属性連鎖が非表示
- [x] ターン中のプレイヤーは黄色●マーク + ハイライト表示
- [x] パネル枠線が GameConstants.PLAYER_COLORS に基づく正しい色

### ステータスダイアログ
- [ ] クリックでダイアログ表示
- [ ] ダイアログに土地情報（属性別の数）が表示
- [ ] ダイアログに保有クリーチャー（名前、HP、AP）が表示
- [ ] ESCキーでダイアログを閉じられる
- [ ] 複数ダイアログを同時に開けない（前のを自動的に閉じる）

---

## 今後の拡張ポイント

1. **パネルのドラッグ移動**: ウィンドウをドラッグで位置変更可能に
2. **ホバー時の情報プレビュー**: マウスホバーで簡易情報をツールチップ表示
3. **カスタマイズUI**: ユーザーが表示項目を選択可能に
