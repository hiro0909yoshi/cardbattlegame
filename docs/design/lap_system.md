# 周回システム実装仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月27日  
**最終更新**: 2025年12月11日（LapSystemクラス分離）  
**ステータス**: ✅ 実装完了

---

## 📋 概要

プレイヤーがマップを1周するごとに発生するシステム。周回完了時に以下の効果が発生:
- 魔力ボーナス付与
- 全クリーチャーのダウン解除
- 全クリーチャーのHP回復(+10)
- 特定クリーチャーへの周回ボーナス

---

## 🏗️ アーキテクチャ

### クラス構成（2025/12/11リファクタリング後）

```
GameFlowManager
  └── LapSystem (子ノード)
        ├── 周回状態管理 (player_lap_state)
        ├── 破壊カウンター (game_stats)
        └── 周回ボーナス適用
```

**設計方針**: ラッパー方式
- 外部からは従来通り`game_flow_manager.get_lap_count()`等で呼び出し可能
- 内部では`LapSystem`に委譲

---

## 🎯 実装内容

### 1. LapSystem クラス

**場所**: `scripts/game_flow/lap_system.gd`

```gdscript
class_name LapSystem
extends Node

signal lap_completed(player_id: int)

var player_lap_state: Dictionary = {}  # {player_id: {N: bool, S: bool, lap_count: int}}
var game_stats: Dictionary = {"total_creatures_destroyed": 0}

func initialize_lap_state(player_count: int)
func connect_checkpoint_signals()
func complete_lap(player_id: int)
func get_lap_count(player_id: int) -> int
func on_creature_destroyed()
func get_destroy_count() -> int
func reset_destroy_count()
```

### 2. GameFlowManager（ラッパー）

**場所**: `scripts/game_flow_manager.gd`

```gdscript
# プロパティ（外部互換用）
var player_lap_state: Dictionary:
    get: return lap_system.player_lap_state if lap_system else {}

var game_stats: Dictionary:
    get: return lap_system.game_stats if lap_system else {}

# メソッド（LapSystemに委譲）
func get_lap_count(player_id: int) -> int
func on_creature_destroyed()
func get_destroy_count() -> int
func reset_destroy_count()
func _complete_lap(player_id: int)
```

### 3. チェックポイントシステム

#### CheckpointTile
- **場所**: `scripts/tiles/checkpoint_tile.gd`
- **タイプ**: N（北）/ S（南）の2種類
- **配置**: マップに2箇所（タイル0とタイル10）

```gdscript
signal checkpoint_passed(player_id: int, checkpoint_type: String)
```

### 4. 周回完了処理

```gdscript
func complete_lap(player_id: int):
    # 周回数をインクリメント
    player_lap_state[player_id]["lap_count"] += 1
    
    # フラグをリセット
    player_lap_state[player_id]["N"] = false
    player_lap_state[player_id]["S"] = false
    
    # 魔力ボーナス付与
    player_system.add_magic(player_id, GameConstants.PASS_BONUS)
    
    # ダウン解除
    board_system_3d.movement_controller.clear_all_down_states_for_player(player_id)
    
    # HP回復+10
    board_system_3d.movement_controller.heal_all_creatures_for_player(player_id, 10)
    
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

### ability_parsed例

#### キメラ (ID 7)
```json
{
  "effects": [
    {
      "effect_type": "per_lap_permanent_bonus",
      "stat": "ap",
      "value": 10
    }
  ]
}
```

#### モスタイタン (ID 240)
```json
{
  "effects": [
    {
      "effect_type": "per_lap_permanent_bonus",
      "stat": "max_hp",
      "value": 10,
      "reset_condition": {
        "max_hp_check": {
          "operator": ">=",
          "value": 80,
          "reset_to": 30
        }
      }
    }
  ]
}
```

---

## 🔧 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/game_flow/lap_system.gd` | **周回管理クラス（メイン）** |
| `scripts/game_flow_manager.gd` | ラッパー（外部互換用） |
| `scripts/tiles/checkpoint_tile.gd` | チェックポイントタイル |
| `scripts/board_system_3d.gd` | `get_player_tiles()`提供 |
| `scripts/movement_controller.gd` | チェックポイント通過検出 |

---

## 🔗 外部参照箇所

LapSystemの機能を利用している箇所:

| メソッド | 参照元ファイル |
|---------|---------------|
| `get_lap_count()` | spell_magic.gd, player_status_dialog.gd |
| `get_destroy_count()` | battle_skill_processor.gd, debug_panel.gd, spell_magic.gd |
| `on_creature_destroyed()` | battle_system.gd |
| `player_lap_state` | battle_special_effects.gd, skill_legacy.gd, spell_player_move.gd |

---

## ✅ テスト確認項目

- [x] N→S通過で周回完了
- [x] S→N通過でも周回完了
- [x] 周回完了時の魔力ボーナス
- [x] 周回完了時のダウン解除
- [x] 周回完了時のHP回復
- [x] キメラのST上昇（周回ごとに+10）
- [x] モスタイタンのMHP上昇とリセット
- [x] 複数プレイヤーの周回状態が独立
- [x] 破壊カウンターの正常動作

---

## 📝 今後の拡張

- [ ] チェックポイント数を可変に（現在は2固定）
- [ ] 周回ボーナス対象クリーチャーを追加
- [ ] 周回数UIの表示
- [ ] 周回数に応じた特殊イベント
- [ ] 直接参照方式への移行（game_flow_manager経由をやめる）