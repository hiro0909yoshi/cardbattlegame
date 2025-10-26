# 周回システム実装メモ

**実装日**: 2025年10月27日  
**ステータス**: ✅ 実装完了

---

## 概要

チェックポイント方式の周回システムと周回ボーナス（スタート通過ボーナス）を実装しました。

---

## 実装内容

### 1. チェックポイント方式の周回検出

#### CheckpointTile (scripts/tiles/checkpoint_tile.gd)
- `CheckpointType` enum追加（N / S）
- `@export var checkpoint_type`で各タイルのタイプを設定可能
- `checkpoint_passed(player_id, checkpoint_type)` シグナル追加
- `on_player_passed()` メソッド追加

#### MovementController (scripts/movement_controller.gd)
- `check_and_handle_checkpoint()` 関数追加
  - CheckpointTileの通過を検出
  - タイル0は2回目以降のみ通過扱い（ゲーム開始時は無視）
- `move_along_path()` でチェックポイント通過をチェック

#### GameFlowManager (scripts/game_flow_manager.gd)
- `player_lap_state` 辞書で各プレイヤーの状態管理
  - `game_started`: ゲーム開始フラグ
  - `N`: Nシグナル受信フラグ
  - `S`: Sシグナル受信フラグ
- `lap_completed(player_id)` シグナル追加
- `_initialize_lap_state()`: 周回状態の初期化
- `_connect_checkpoint_signals()`: CheckpointTileのシグナル接続
- `_on_checkpoint_passed()`: チェックポイント通過イベント処理
- `_complete_lap()`: 周回完了処理（N+S揃った時）
- `_apply_lap_bonus_to_all_creatures()`: 全クリーチャーに周回ボーナス適用
- `_apply_lap_bonus_to_creature()`: 個別クリーチャーへの適用
- `_apply_per_lap_bonus()`: 永続バフの適用ロジック

---

### 2. 周回ボーナス（スタート通過ボーナス）

#### MovementController (scripts/movement_controller.gd)
- `handle_start_pass()` に以下を追加：
  - ✅ 魔力ボーナス（既存）
  - ✅ ダウン状態クリア（既存）
  - ✅ **クリーチャーHP回復+10（新規追加）**
- `heal_all_creatures_for_player()` 関数追加
  - プレイヤーの全クリーチャーのHPを指定量回復
  - MHPを超えないよう制限

---

## 周回システムの仕組み

### チェックポイント配置
- **タイル0**: CheckpointTile (type: N)
- **タイル10**: CheckpointTile (type: S)

### 周回完了条件
1. プレイヤーがタイル0（N）を通過 → Nフラグ立つ
2. プレイヤーがタイル10（S）を通過 → Sフラグ立つ
3. **N + S 両方のフラグが立つ** → 周回完了

### 特殊ルール
- **ゲーム開始時のタイル0通過は無視**
  - `game_started` フラグで管理
  - 最初の通過時はフラグを立てるのみ
  - 2回目以降の通過からNシグナルとして扱う

### 周回完了時の処理
1. N, Sフラグをリセット（`game_started`は維持）
2. プレイヤーの全クリーチャーに周回ボーナス適用
3. `lap_completed` シグナル発行

---

## 永続バフの適用

### 対象クリーチャー
- **ID 7: キメラ** - 周回ごとにST+10
- **ID 240: モスタイタン** - 周回ごとにMHP+10（MHP≧80でリセット）

### データ保存
```gdscript
creature_data["map_lap_count"] = 0     # 周回数カウンター
creature_data["base_up_ap"] = 0        # 永続的なAP上昇
creature_data["base_up_hp"] = 0        # 永続的なHP上昇
```

### 適用ロジック
```gdscript
# ability_parsed構造
{
  "effect_type": "per_lap_permanent_bonus",
  "stat": "ap" | "max_hp",
  "value": 10,
  "reset_condition": {  # モスタイタンのみ
    "max_hp_check": {"operator": ">=", "value": 80, "reset_to": 30}
  }
}
```

### モスタイタンのリセット処理
- MHP + 新しいボーナス ≧ 80 の場合
- `base_up_hp` を `reset_to - base_hp` に設定
- 結果的に MHP = 30 にリセット

---

## 周回ボーナスの詳細

### スタート地点（タイル0）通過時
毎回以下の3つの効果が発動：

1. **魔力ボーナス**: `GameConstants.PASS_BONUS`の魔力を獲得
2. **ダウン状態クリア**: プレイヤーの全領地のダウン状態を解除
3. **HP回復+10**: プレイヤーの全クリーチャーのHPを10回復（MHP上限）

### HP回復の計算
```gdscript
max_hp = creature.hp + creature.base_up_hp
current_hp = creature.current_hp
new_hp = min(current_hp + 10, max_hp)
```

---

## テスト項目

### 周回システム
- [ ] タイル0通過でゲーム開始フラグが立つ
- [ ] 2回目のタイル0通過でNシグナル発行
- [ ] タイル10通過でSシグナル発行
- [ ] N+S揃った時に周回完了シグナル発行
- [ ] キメラのSTが周回ごとに+10される
- [ ] モスタイタンのMHPが周回ごとに+10される
- [ ] モスタイタンのMHPが80以上で30にリセット

### 周回ボーナス
- [ ] スタート通過で魔力獲得
- [ ] スタート通過でダウン状態クリア
- [ ] スタート通過でクリーチャーHP+10回復
- [ ] HP回復がMHPを超えない

---

## 今後の拡張

### 未実装の必須機能
1. **ターン数カウンター** - ラーバキン(ID: 47)用
2. **土地イベント** - アースズピリット、デュータイタン用
3. **破壊カウンター** - バルキリー、ソウルコレクター等

### main.tscnの設定
- [ ] タイル0をCheckpointTile (type: N)に変更
- [ ] タイル10をCheckpointTile (type: S)に変更

---

## 変更履歴

| 日付 | 変更内容 |
|------|---------|
| 2025/10/27 | 初版作成 - 周回システムと周回ボーナスを実装 |

---

**最終更新**: 2025年10月27日
