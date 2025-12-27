# 特殊タイル仕様

**バージョン**: 1.0  
**最終更新**: 2025年12月16日

---

## 概要

特殊タイルはクリーチャー配置不可の特別なマス。各タイルに固有の効果がある。

---

## 1. カード購入タイル (card_buy)

### 基本情報
| 項目 | 値 |
|------|-----|
| tile_type | `card_buy` |
| 停止可 | ✅ |
| 発動タイミング | 停止時 |
| 色 | 緑 |

### 効果
1. 停止すると**スペル・アイテム**からランダムで3枚表示
2. プレイヤーは1枚を選択して購入可能（購入しない選択肢あり）
3. 購入価格 = **カードコストの50%（切り上げ）**
4. 購入したカードは**手札**に追加

### 処理フロー
```
停止
  ↓
スペル・アイテムから3枚ランダム選出（CardLoaderから）
  ↓
UI: 3枚表示 + 「買わない」ボタン
  ↓
プレイヤー選択
  ├─ カード選択 → コスト50%（切り上げ）支払い → 手札に追加
  └─ 買わない → 何もしない
  ↓
完了
```

### 計算例
- カードコスト100 → 購入価格50
- カードコスト70 → 購入価格35
- カードコスト15 → 購入価格8（切り上げ）

### 注意
- 手札上限に達していても購入可能
- 魔力不足のカードも表示される（グレーアウトで選択不可）

---

## 2. カード譲渡タイル (card_give)

### 基本情報
| 項目 | 値 |
|------|-----|
| tile_type | `card_give` |
| 停止可 | ✅ |
| 発動タイミング | 停止時 |
| 色 | 黄 |

### 効果
1. 停止すると**クリーチャー/アイテム/スペル**の3種類から選択
2. 選択した種類のカードを**自分の山札**からランダムで1枚取得
3. 取得したカードは**手札**に追加
4. **無料**

### 処理フロー
```
停止
  ↓
UI: 「クリーチャー」「アイテム」「スペル」ボタン表示
  ↓
プレイヤー選択
  ↓
山札から該当種類のカードを検索
  ├─ 見つかった → ランダム1枚を手札に移動
  └─ 見つからない → メッセージ表示（該当カードなし）
  ↓
完了
```

### 注意
- 山札（deck）から取得するため、山札にない種類は取得不可
- 取得したカードは山札から消える
- 山札に該当種類がなければ「該当カードなし」表示で終了（選び直し不可）
- 山札が空の場合は3種類すべて選択不可表示

---

## 3. 魔法石タイル (magic_stone)

### 基本情報
| 項目 | 値 |
|------|-----|
| tile_type | `magic_stone` |
| 停止可 | ✅ |
| 発動タイミング | **通過時・停止時（毎回発動）** |
| 色 | シアン |

### 概念
魔法石は4属性（火・水・土・風）の株式のようなアイテム。価値は全プレイヤーの石所持数により動的に変化する。

### 石の種類
| 石 | 初期価値 |
|----|---------|
| 火の石 | 50G |
| 水の石 | 50G |
| 土の石 | 50G |
| 風の石 | 50G |

### 価値計算

全プレイヤーの石所持数を参照して動的に計算（整数演算のみ）。

#### 計算式
```
石の価値 = 初期値(50) + 同属性ボーナス - 相克属性ペナルティ

同属性ボーナス = 全プレイヤーの同属性石所持数 × 4G
相克属性ペナルティ = 全プレイヤーの相克属性石所持数 × 2G
```

#### 相克関係
| 石 | 同属性（+4G/個） | 相克属性（-2G/個） |
|----|-----------------|-------------------|
| 火の石 | 火 | 水 |
| 水の石 | 水 | 火 |
| 土の石 | 土 | 風 |
| 風の石 | 風 | 土 |

#### 計算例
全プレイヤーの石所持状況:
- 火の石: 5個
- 水の石: 3個

**火の石の価値:**
```
= 50 + (5 × 4) - (3 × 2)
= 50 + 20 - 6
= 64G
```

**水の石の価値:**
```
= 50 + (3 × 4) - (5 × 2)
= 50 + 12 - 10
= 52G
```

### 売買ルール
| 項目 | 仕様 |
|------|------|
| 購入価格 | 現在価値 |
| 売却価格 | 現在価値 |
| 1イベントの取引回数 | **1回まで**（購入または売却後に終了） |
| 取引可能属性 | **1種類のみ**（複数属性の同時取引不可） |
| 数量選択 | 同一属性で複数個まとめて売買可能 |

### 所持上限
なし（無制限に購入可能）

### 最低価値
25G（相克ペナルティで下がっても25未満にはならない）

### 総魔力への影響
所持している石の**現在価値**が総魔力に加算される

```
総魔力 = 所持魔力 + 土地価値 + 石の現在価値合計
```

### 処理フロー
```
通過 or 停止（毎回発動）
  ↓
UI: ショップ画面表示
  ├─ 各石の現在価値表示
  ├─ 所持数表示
  ├─ 購入数/売却数選択（+/-ボタン）
  ├─ 「購入」「売却」「閉じる」ボタン
  ↓
プレイヤー操作
  ├─ 購入 → 個数 × 現在価値を支払い → 石を取得 → **ショップ終了**
  ├─ 売却 → 石を手放す → 個数 × 現在価値を獲得 → **ショップ終了**
  └─ 閉じる → 何もしない → ショップ終了
  ↓
移動継続（通過時）または ターン進行（停止時）
```

### 実装ファイル
- `scripts/tiles/magic_stone_tile.gd` - タイル処理
- `scripts/tiles/magic_stone_system.gd` - 価値計算・売買ロジック
- `scripts/ui_components/magic_stone_ui.gd` - ショップUI
- `scripts/player_system.gd` - 石所持データ（PlayerData.magic_stones）、総魔力計算

---

## 4. 魔法タイル (magic)

### 基本情報
| 項目 | 値 |
|------|-----|
| tile_type | `magic` |
| 停止可 | ✅ |
| 発動タイミング | 停止時 |
| 色 | ピンク |

### 効果
1. 停止すると**全スペル**からランダムで3枚表示
2. プレイヤーは1枚を選択して使用可能（使用しない選択肢あり）
3. 使用時は**カードコストを支払う**
4. 使用後のカードは消滅（手札には入らない）

### 処理フロー
```
停止
  ↓
全スペルから3枚ランダム選出（CardLoaderから）
  ↓
UI: 3枚表示 + 「使わない」ボタン
  ↓
プレイヤー選択
  ├─ スペル選択 → コスト支払い → 通常のスペル使用処理
  │    （ターゲット選択等、通常のスペルUIを使用）
  └─ 使わない → 何もしない
  ↓
完了
```

### 注意
- スペル使用処理は既存のSpellPhaseHandler等を流用
- ターゲット指定が必要なスペルは通常通りUI表示
- 魔力不足のスペルも表示される（グレーアウトで選択不可）
- 対象がないスペルも表示される（使用時に対象選択不可で実質使えない）

---

## 5. ベースタイル (base)

### 基本情報
| 項目 | 値 |
|------|-----|
| tile_type | `base` |
| 停止可 | ✅ |
| 発動タイミング | 停止時 |
| 色 | グレー |

### 効果
1. 停止すると「空き地にクリーチャーを配置しますか？」と確認
2. 「配置する」選択で**空き地選択UI**を表示
3. 空き地を選択後、通常の**召喚フロー**（手札選択→コスト支払い→配置）を実行
4. 配置しない選択肢あり

### 処理フロー
```
停止
  ↓
空き地があるかチェック
  ├─ なし → 何もしない（selected_tile: -1）
  └─ あり → 確認ダイアログ表示
		↓
	「空き地にクリーチャーを配置しますか？」
		├─ 「配置する」→ 空き地選択UI
		│    ↓
		│    TargetSelectionHelper で空き地選択
		│    ↓
		│    選択タイルインデックスを返却
		│    ↓
		│    GameFlowManager が通常召喚フローを実行
		│    （手札選択 → コスト支払い → 配置）
		└─ 「しない」→ 何もしない（selected_tile: -1）
  ↓
完了
```

### 制限チェック（召喚フロー内で実行）
1. **lands_required**: 必要属性土地数を満たしているか
2. **カードコスト**: 魔力が足りているか
3. **手札**: 召喚可能なクリーチャーがあるか

### 注意
- 空き地がない場合は確認ダイアログなしでスキップ
- CPUは自動的に「しない」を選択（スキップ）
- 空き地選択後の召喚フローは通常の召喚処理を再利用
- neutral（無属性）タイルも空き地として配置可能

### 実装ファイル
- `scripts/tiles/special_base_tile.gd` - ベースタイル処理
- `scripts/ui_components/global_comment_ui.gd` - 確認ダイアログ（show_choice_and_wait）

---

## 6. 分岐タイル (branch)

### 基本情報
| 項目 | 値 |
|------|-----|
| tile_type | `branch` |
| 停止可 | ✅ |
| 発動タイミング | 通過時（自動進行）、停止時（方向変更可） |
| 色 | 茶色（RGB: 0.55, 0.35, 0.15） |

### 概念

分岐タイルは**メイン方向**と**2つの分岐方向**を持つ特殊タイル。`branch_direction`で「開いている分岐」が決まり、通過時の進行方向が自動的に制御される。

### connections配列の構造

**重要**: connectionsの順序で役割が決まる。JSONでは`connections`のみ設定し、方向はタイル座標から自動計算される。

```
connections = [main, branch1, branch2]
```

| インデックス | 役割 | 説明 | インジケーター色 |
|-------------|------|------|-----------------|
| [0] | main | メイン方向（**常にアクセス可能**） | 緑 |
| [1] | branch1 | 分岐選択肢1（branch_direction=0で開） | 赤 |
| [2] | branch2 | 分岐選択肢2（branch_direction=1で開） | 赤 |

**ポイント**: 「必ず開通させたい方向」を`connections[0]`に設定する。

### 通過時の動作

進める方向 = **[main, 開いている分岐]** から **came_from を除外**

| 進める方向の数 | 動作 |
|---------------|------|
| 1つ | 自動選択 |
| 2つ以上 | 選択UI表示 |

**例（branch_direction=0の場合、branch1が開）**:
| came_from | 進める方向 | 動作 |
|-----------|-----------|------|
| main | [branch1] | → branch1へ自動 |
| branch1 | [main] | → mainへ自動 |
| branch2 | [main, branch1] | → 選択UI表示 |

### 自動切替

4ターン（ラウンド4, 8, 12...）ごとに全分岐タイルの`branch_direction`が切り替わる。

```gdscript
# GameFlowManager
if current_turn_number % 4 == 0:
    _toggle_all_branch_tiles()
```

### 視覚表示（インジケーター）

インジケーターの方向はconnectionsのタイル座標から自動計算される。

| インジケーター | 表示条件 | 色 | 説明 |
|---------------|---------|-----|------|
| MainIndicator | 常時表示 | **緑** | メイン方向（常に開通） |
| Indicator1 | branch_direction=0 | **赤** | branch1方向（開いている時のみ） |
| Indicator2 | branch_direction=1 | **赤** | branch2方向（開いている時のみ） |

**方向とサイズ**:
```gdscript
const DIRECTION_OFFSET = {
    "left": Vector3(-0.8, 0, 0),
    "right": Vector3(0.8, 0, 0),
    "up": Vector3(0, 0, -0.8),
    "down": Vector3(0, 0, 0.8)
}

const DIRECTION_MESH_SIZE = {
    "left": Vector3(2.5, 0.2, 1.0),   # X方向に長い
    "right": Vector3(2.5, 0.2, 1.0),
    "up": Vector3(1.0, 0.2, 2.5),     # Z方向に長い
    "down": Vector3(1.0, 0.2, 2.5)
}
```

### マップJSON設定

#### タイル定義

**シンプルに定義（方向は自動計算）**:
```json
{
  "index": 5,
  "type": "Branch",
  "x": 40,
  "z": 8
}
```

`main_dir`と`branch_dirs`は**不要**。座標から自動計算される。

#### マップレベルconnections（必須）

```json
"connections": {
  "5": [6, 4, 9]
}
```

| インデックス | タイル | 役割 | 備考 |
|-------------|-------|------|------|
| [0] | 6 | **main（常に開通）** | 必ず開通させたい方向 |
| [1] | 4 | branch1 | branch_direction=0で開 |
| [2] | 9 | branch2 | branch_direction=1で開 |

### 処理フロー

```
通過時:
  ↓
get_next_tile_for_direction(came_from) を呼び出し
  ↓
進める方向 = [main, 開いている分岐] - came_from
  ├─ 1つ → 自動移動（tile返却）
  └─ 2つ以上 → choices返却（UI表示）
  ↓
tileが返却された場合 → 自動移動
choicesが返却された場合 → 選択UI表示（黄色インジケーター）
  ↓
移動実行

停止時:
  ↓
handle_special_action() を呼び出し
  ↓
CPUの場合 → スキップ（変更しない）
  ↓
プレイヤーの場合 → 通知ポップアップ表示
  ├─ ✓決定ボタン → 方向変更（branch_directionを切替）
  └─ ✕戻るボタン → 変更しない
  ↓
完了
```

### 分岐選択時インジケーター（方向選択UI）

通常タイル・分岐タイル問わず、分岐選択時には**黄色**の動的インジケーターが表示される。

**色の区別**:
- **緑**: BranchTileのメイン方向（常に開通）
- **赤**: BranchTileの開いている分岐方向
- **黄色**: 方向選択UI（プレイヤーが選択中の方向）

### 実装ファイル
- `scripts/tiles/branch_tile.gd` - 分岐タイル処理、インジケーター定数定義、方向自動計算
- `scripts/movement_controller.gd` - 移動時の分岐処理（_get_next_tile_with_branch）、動的インジケーター
- `scripts/game_flow_manager.gd` - 4ターン自動切替（_toggle_all_branch_tiles）
- `scripts/quest/stage_loader.gd` - JSON読み込み、BranchTile初期化（setup_with_tile_nodes）
- `scripts/special_tile_system.gd` - 停止時処理の呼び出し（handle_branch_tile）
- `scripts/ui_components/global_comment_ui.gd` - 通知ポップアップ（show_message, hide_message）
- `scenes/Tiles/BranchTile.tscn` - タイルシーン（インジケーター含む）

### 実装状況

| 機能 | 状態 | 備考 |
|------|------|------|
| 通過時自動分岐 | ✅ 完了 | main + 開いている分岐から選択 |
| 分岐選択UI | ✅ 完了 | 進める方向が2つ以上の場合に表示 |
| 4ターン自動切替 | ✅ 完了 | ラウンド4, 8, 12...で切替 |
| 視覚インジケーター（固定） | ✅ 完了 | 緑=main、赤=開いている分岐 |
| 視覚インジケーター（動的） | ✅ 完了 | 黄色、分岐選択時に表示 |
| 停止時方向変更UI | ✅ 完了 | 通知ポップアップ + グローバルボタン |
| 方向自動計算 | ✅ 完了 | connectionsの座標から自動計算 |

---

## CPU対応

- CPUもすべての特殊タイルを使用する
- AIロジックは後回し（初期実装では「スキップ」動作）
- 各タイルにCPU判断ロジックを追加予定

---

## 実装優先度

| 優先度 | タイル | 理由 |
|--------|--------|------|
| 1 | card_give | シンプル（無料、山札から取得のみ） |
| 2 | card_buy | シンプル（コスト計算のみ追加） |
| 3 | magic | 既存スペル処理を流用可能 |
| 4 | base | 既存配置処理を流用可能 |
| 5 | magic_stone | 新規システム（石の管理、価値計算） |

---

## 実装詳細

### アーキテクチャ: タイルへの処理委譲

特殊タイルの処理は各タイルクラスに委譲する方式を採用。

```
special_tile_system.gd
  ↓ handle_xxx_tile(player_id, tile)
タイルクラス (xxx_tile.gd)
  ↓ handle_special_action(player_id, context)
UI表示・処理実行
  ↓
結果を返す
```

#### コンテキスト

タイルに渡されるcontextには以下のシステム参照が含まれる：

```gdscript
func _create_tile_context() -> Dictionary:
	return {
		"player_system": player_system,
		"card_system": card_system,
		"ui_manager": ui_manager,
		"game_flow_manager": game_flow_manager,
		"board_system": board_system
	}
```

#### タイル側の実装パターン

```gdscript
extends BaseTile

var _player_system = null
var _card_system = null
var _ui_manager = null
# ...

func handle_special_action(player_id: int, context: Dictionary) -> Dictionary:
	# コンテキストからシステム参照を取得
	_player_system = context.get("player_system")
	_card_system = context.get("card_system")
	_ui_manager = context.get("ui_manager")
	# ...
	
	# CPUの場合はスキップ
	if _is_cpu_player(player_id):
		return {"success": true, "xxx_done": false}
	
	# プレイヤーの場合はUI表示
	var result = await _show_xxx_selection(player_id)
	return result
```

### 共通UI設定関数

全ての特殊タイルハンドラは、処理の最後に共通関数`_show_special_tile_landing_ui(player_id)`を呼び出す。

```gdscript
## special_tile_system.gd

func _show_special_tile_landing_ui(player_id: int):
	# カードをグレーアウト（召喚不可）
	ui_manager.card_selection_filter = "disabled"
	# 手札UI表示
	ui_manager.show_card_selection_ui(current_player)
	# フェーズ表示
	ui_manager.phase_label.text = "特殊タイル: 召喚不可（パスまたは領地コマンドを使用）"
```

### UI共通仕様

特殊タイルUIは統一されたサイズ・スタイルを使用：

| 項目 | 値 |
|------|-----|
| メインパネル | 1800 x 1050 |
| カードパネル | 500 x 680 |
| パネル間隔 | 80px |
| 位置調整 | 中央から150px上 |
| タイトルフォント | 48〜56 |
| カード名フォント | 44 |
| 説明フォント | 40 |
| ボタン（決定） | 300x90〜350x100 |
| ボタン（キャンセル） | 400x100〜450x110 |

---

## 実装状況

| タイル | 状態 | 備考 |
|--------|------|------|
| magic | ✅ 完了 | タイル委譲、SpellPhaseHandler連携 |
| card_buy | ✅ 完了 | タイル委譲、購入価格50%表示 |
| card_give | ✅ 完了 | タイル委譲、3タイプ選択UI |
| magic_stone | ✅ 完了 | タイル委譲、動的価格、通過時・停止時発動、売買UI |
| base | ✅ 完了 | タイル委譲、遠隔配置+通常召喚フロー |
| checkpoint | ✅ 動作中 | LapSystemで処理 |
| warp_stop | ✅ 動作中 | special_tile_systemで処理 |
| branch | ✅ 完了 | main/branch判定、4ターン自動切替、視覚インジケーター |
| branch | 🔄 基本動作 | 通過時自動進行のみ、停止時選択・自動切替は未実装 |

---

## 関連ファイル

### タイルクラス
- `scripts/tiles/branch_tile.gd` - 分岐タイル処理
- `scripts/tiles/magic_tile.gd` - 魔法タイル処理
- `scripts/tiles/card_buy_tile.gd` - カード購入タイル処理
- `scripts/tiles/card_give_tile.gd` - カード譲渡タイル処理
- `scripts/tiles/special_base_tile.gd` - ベースタイル処理（遠隔配置）
- `scripts/tiles/magic_stone_tile.gd` - 魔法石タイル処理
- `scripts/tiles/magic_stone_system.gd` - 魔法石価値計算・売買処理

### UI
- `scripts/ui_components/magic_tile_ui.gd` - 魔法タイルUI
- `scripts/ui_components/card_buy_ui.gd` - カード購入タイルUI
- `scripts/ui_components/card_give_ui.gd` - カード譲渡タイルUI
- `scripts/ui_components/magic_stone_ui.gd` - 魔法石ショップUI

### システム
- `scripts/special_tile_system.gd` - 特殊タイル処理・委譲・共通UI設定
- `scripts/tile_action_processor.gd` - タイル着地処理
- `scripts/game_flow/spell_phase_handler.gd` - 外部スペル実行（魔法タイル用）

### その他
- `scripts/tile_helper.gd` - タイルタイプ定数
- `scripts/quest/stage_loader.gd` - タイルシーンマッピング
- `data/master/maps/map_diamond_20_v2.json` - 特殊タイル配置マップ

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2025/12/16 | 初版作成 |
| 2025/12/16 | 魔法石の価値計算式追加（相克属性ペナルティ含む） |
| 2025/12/16 | 詳細仕様追加（手札上限、グレーアウト、最低価値25、複数購入、CPU対応など） |
| 2025/12/17 | 実装詳細セクション追加（共通UI設定関数、ハンドラ実装パターン） |
| 2025/12/17 | タイル委譲アーキテクチャに移行（magic, card_buy, card_give完了） |
| 2025/12/17 | UI共通仕様追加、実装状況セクション追加 |
| 2025/12/18 | ベースタイル実装完了（確認ダイアログ+空き地選択+通常召喚フロー） |
| 2025/12/18 | 魔法石タイル基盤実装（動的価格、売買UI）、総魔力計算をPlayerSystemに一元化 |
| 2025/12/18 | 魔法石タイル通過発動追加、価値計算を石所持数ベースに変更（+4G/-2G）、1イベント1回制限 |
| 2025/12/18 | 分岐タイル仕様追加（通過時自動分岐、停止時方向変更、4ターン自動切替） |
| 2025/12/19 | 分岐タイル実装完了（main/branch判定、4ターン切替、視覚インジケーター） |
| 2025/12/19 | 停止時方向変更UI追加、動的インジケーター追加（通常タイル分岐選択時も表示） |
