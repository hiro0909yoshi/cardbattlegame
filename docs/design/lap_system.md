# 周回システム実装仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月27日  
**最終更新**: 2025年12月16日（通知ポップアップUI追加）  
**ステータス**: ✅ 実装完了

---

## 📋 概要

プレイヤーがマップを1周するごとに発生するシステム。

### シグナル入手時
- 基礎ボーナス付与（マップ設定による）
- 通知ポップアップ表示（シグナル名 + 魔力ボーナス）

### 周回完了時（全シグナル揃った時）
- 追加ボーナス付与（クリーチャー数・周回数に応じて）
- 全クリーチャーのダウン解除
- 全クリーチャーのHP回復(+10)
- 特定クリーチャーへの周回ボーナス
- 4段階の通知ポップアップ表示

---

## 🎁 周回ボーナス計算

### ボーナス構成

| タイミング | ボーナス |
|-----------|---------|
| シグナル入手時（N, S等） | 基礎ボーナス |
| 周回完了時 | 追加ボーナス |

### 追加ボーナス計算式

```
追加ボーナス = 基礎ボーナス × (クリーチャー数 × 0.4 + (周回数 - 1) × 0.4)
```

### 計算例（基礎ボーナス = 120G）

| 周回 | クリーチャー数 | シグナル | 追加ボーナス | 合計 |
|------|--------------|---------|-------------|------|
| 1周目 | 0体 | N取得 | - | 120G |
| 1周目 | 0体 | S取得（周回完了） | 0G | 120G |
| 1周目 | 3体 | N取得 | - | 120G |
| 1周目 | 3体 | S取得（周回完了） | 120×(3×0.4+0×0.4)=144G | 264G |
| 2周目 | 3体 | N取得 | - | 120G |
| 2周目 | 3体 | S取得（周回完了） | 120×(3×0.4+1×0.4)=192G | 312G |
| 3周目 | 5体 | N取得 | - | 120G |
| 3周目 | 5体 | S取得（周回完了） | 120×(5×0.4+2×0.4)=336G | 456G |

---

## ⚙️ マップ設定

### GameConstants プリセット

**場所**: `scripts/game_constants.gd`

```gdscript
# 基礎ボーナスプリセット
const LAP_BONUS_PRESETS = {
	"low": 100,
	"standard": 120,
	"high": 150,
	"very_high": 200
}

# 必要シグナルプリセット
const CHECKPOINT_PRESETS = {
	"standard": ["N", "S"],
	"three_way": ["N", "S", "W"],
	"four_way": ["N", "S", "W", "E"]
}

# 周回ボーナス係数
const LAP_BONUS_CREATURE_RATE = 0.4   # 配置クリーチャー1体あたり40%
const LAP_BONUS_LAP_RATE = 0.4        # 1周あたり追加40%
```

### マップJSON設定例

```json
{
	"map_id": 1,
	"name": "初心者の草原",
	"lap_settings": {
		"bonus_preset": "standard",
		"checkpoint_preset": "standard"
	}
}
```

| プリセット | 設定内容 |
|-----------|---------|
| `bonus_preset` | "low"(100), "standard"(120), "high"(150), "very_high"(200) |
| `checkpoint_preset` | "standard"(N,S), "three_way"(N,S,W), "four_way"(N,S,W,E) |

---

## 🖥️ UI表示（通知ポップアップ）

### シグナル入手時

シグナル（N, S等）を入手した際、以下が表示される：

1. **画面中央**: シグナル名を大きく表示（フェードアウト）
2. **通知ポップアップ**: クリック待ち
   ```
   シグナル N 取得！
   魔力 +120 G
   ```

### 周回完了時

全シグナルが揃い周回完了した際、4段階の通知ポップアップが順次表示される：

| 順番 | 内容 | 色 |
|------|------|-----|
| 1 | 「O周完了」 | 黄色 |
| 2 | 「周回ボーナス OOO G（基礎 XXX G + 追加 YYY G）」 | シアン |
| 3 | 「ダウン解除」 | ライム |
| 4 | 「HP回復 +10」 | ライム |

各ポップアップはクリックで次へ進む。

### GlobalCommentUI

**場所**: `scripts/ui_components/global_comment_ui.gd`

グローバルな通知ポップアップUI。UIManagerに登録され、各システムから呼び出し可能。

```gdscript
# クリック待ちモード（スペル効果、周回完了等）
await ui_manager.global_comment_ui.show_and_wait("メッセージ")
await ui_manager.global_comment_ui.click_confirmed

# 自動フェードモード（即時通知等）
ui_manager.global_comment_ui.show_auto_fade("メッセージ", 2.0, "bottom")
```

| メソッド | 用途 |
|---------|------|
| `show_and_wait(message)` | クリック待ち表示 |
| `show_auto_fade(message, duration, position)` | 自動フェード表示 |
| `show_auto_fade_delayed(message, delay, duration, position)` | 遅延後に自動フェード |

---

## 🏗️ アーキテクチャ

### クラス構成

```
GameFlowManager
  └── LapSystem (子ノード)
		├── 周回状態管理 (player_lap_state)
		├── マップ設定 (base_bonus, required_checkpoints)
		├── 破壊カウンター (destroy_count)
		└── 周回ボーナス適用
```

**設計方針**: ファサード方式（プロジェクト標準に統一）
- 外部から`game_flow_manager.lap_system.get_lap_count()`で直接アクセス
- GameFlowManagerはラッパーメソッドを持たない

---

## 🎯 実装内容

### 1. LapSystem クラス

**場所**: `scripts/game_flow/lap_system.gd`

```gdscript
class_name LapSystem
extends Node

# シグナル
signal lap_completed(player_id: int)
signal checkpoint_signal_obtained(player_id: int, checkpoint_type: String)

# 周回状態
var player_lap_state: Dictionary = {}
var destroy_count: int = 0

# マップ設定
var base_bonus: int = 120
var required_checkpoints: Array = ["N", "S"]

# 外部参照
var player_system = null
var board_system_3d = null
var ui_manager = null

# UI要素
var signal_display_label: Label = null  # シグナル/周回数の大きな表示

# 主要メソッド
func setup(p_system, b_system, p_ui_manager)
func initialize_lap_state(player_count: int)
func apply_map_settings(map_data: Dictionary)
func connect_checkpoint_signals()
func complete_lap(player_id: int)
func get_lap_count(player_id: int) -> int

# ボーナス計算
func _calculate_additional_bonus(player_id: int, lap_count: int) -> int
func _get_player_creature_count(player_id: int) -> int

# UI表示
func _setup_ui()
func _show_signal_display(signal_type: String)
func _show_comment_and_wait(message: String)

# 破壊カウンター
func on_creature_destroyed()
func get_destroy_count() -> int
func reset_destroy_count()
```

### 2. チェックポイント通過処理

```gdscript
func _on_checkpoint_passed(player_id: int, checkpoint_type: String):
	# 必要なシグナルかチェック
	if not checkpoint_type in required_checkpoints:
		return
	
	# 既に取得済みならスキップ
	if player_lap_state[player_id].get(checkpoint_type, false):
		return
	
	# シグナル取得 - 基礎ボーナス付与
	player_lap_state[player_id][checkpoint_type] = true
	player_system.add_magic(player_id, base_bonus)
	
	# 全シグナル揃ったか確認
	if _check_lap_complete(player_id):
		complete_lap(player_id)
```

### 3. 周回完了処理

```gdscript
func complete_lap(player_id: int):
	var current_lap = player_lap_state[player_id]["lap_count"]
	
	# 画面中央に「O周」を大きく表示
	_show_signal_display("%d周" % current_lap)
	
	# 周回数をインクリメント
	player_lap_state[player_id]["lap_count"] += 1
	
	# フラグをリセット
	for checkpoint in required_checkpoints:
		player_lap_state[player_id][checkpoint] = false
	
	# ボーナス計算
	var additional_bonus = _calculate_additional_bonus(player_id, current_lap)
	var lap_total_bonus = base_bonus + additional_bonus  # 周回完了時のボーナス合計
	
	# 追加ボーナスを付与（基礎ボーナスはシグナル入手時に付与済み）
	if additional_bonus > 0:
		player_system.add_magic(player_id, additional_bonus)
	
	# ダウン解除
	board_system_3d.movement_controller.clear_all_down_states_for_player(player_id)
	
	# HP回復+10
	board_system_3d.movement_controller.heal_all_creatures_for_player(player_id, 10)
	
	# 4段階の通知ポップアップ表示
	await _show_comment_and_wait("[color=yellow]%d周完了[/color]" % current_lap)
	await _show_comment_and_wait("[color=cyan]周回ボーナス %d G[/color]\n（基礎 %d G + 追加 %d G）" % [lap_total_bonus, base_bonus, additional_bonus])
	await _show_comment_and_wait("[color=lime]ダウン解除[/color]")
	await _show_comment_and_wait("[color=lime]HP回復 +10[/color]")
	
	# クリーチャー固有の周回ボーナス
	_apply_lap_bonus_to_all_creatures(player_id)
	
	lap_completed.emit(player_id)
```

---

## 📊 データ構造

### player_lap_state

```gdscript
{
	0: {"N": false, "S": true, "lap_count": 2},
	1: {"N": true, "S": false, "lap_count": 1}
}
```

### 周回ボーナス対象クリーチャー

| ID | 名前 | 効果 |
|----|------|------|
| 7 | キメラ | 周回ごとにAP+10（上限なし） |
| 240 | モスタイタン | 周回ごとにMHP+10（MHP≧80でMHP=30にリセット） |

---

## 🔧 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/game_flow/lap_system.gd` | **周回管理クラス（メイン）** |
| `scripts/game_flow_manager.gd` | ラッパー（外部互換用） |
| `scripts/game_constants.gd` | プリセット定義 |
| `scripts/tiles/checkpoint_tile.gd` | チェックポイントタイル |
| `scripts/board_system_3d.gd` | `get_player_tiles()`提供 |
| `scripts/movement_controller.gd` | チェックポイント通過検出 |
| `scripts/ui_components/global_comment_ui.gd` | 通知ポップアップUI |
| `scripts/ui_manager.gd` | GlobalCommentUI管理 |

---

## 🔗 外部参照箇所

LapSystemの機能を利用している箇所:

| メソッド | 参照元ファイル |
|---------|---------------|
| `get_lap_count()` | spell_magic.gd, player_status_dialog.gd |
| `get_destroy_count()` | battle_skill_processor.gd, debug_panel.gd, spell_magic.gd |
| `on_creature_destroyed()` | battle_system.gd |
| `player_lap_state` | battle_special_effects.gd, skill_legacy.gd, spell_player_move.gd |
| `apply_map_settings()` | マップ読み込み時（GameFlowManager） |

---

## ✅ テスト確認項目

- [x] N→S通過で周回完了
- [x] S→N通過でも周回完了
- [x] シグナル入手時の基礎ボーナス
- [x] 周回完了時の追加ボーナス
- [x] 周回完了時のダウン解除
- [x] 周回完了時のHP回復
- [x] キメラのST上昇（周回ごとに+10）
- [x] モスタイタンのMHP上昇とリセット
- [x] 複数プレイヤーの周回状態が独立
- [x] 破壊カウンターの正常動作
- [x] シグナル入手時の通知ポップアップ表示
- [x] 周回完了時の4段階通知ポップアップ表示
- [ ] マップ設定の読み込み
- [ ] 3方向/4方向シグナルの動作

---

## 📝 変更履歴

| 日付 | 内容 |
|------|------|
| 2025/10/27 | 初版作成 |
| 2025/12/11 | LapSystemクラス分離 |
| 2025/12/16 | 周回ボーナス計算式リニューアル（シグナル入手時基礎ボーナス + 周回完了時追加ボーナス）、マップ設定対応、必要シグナル拡張対応 |
| 2025/12/16 | 通知ポップアップUI追加（GlobalCommentUI）、シグナル入手時・周回完了時の4段階表示実装 |
| 2025/12/16 | 周回ボーナス表示を「基礎(base_bonus) + 追加」形式に修正 |
