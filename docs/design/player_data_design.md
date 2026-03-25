# プレイヤーデータ設計書

**目的**: CPU引き継ぎ（PvP切断時）とゲーム状態復帰を前提としたプレイヤーデータの定義

---

## PlayerData フィールド定義

### コアステータス（ゲームロジックに直接影響）

| フィールド | 型 | 初期値 | 説明 | シリアライズ |
|-----------|-----|--------|------|:-----------:|
| `id` | int | 0 | プレイヤーID（0-3） | 必須 |
| `name` | String | "" | プレイヤー名 | 必須 |
| `magic_power` | int | GameConstants.DEFAULT_INITIAL_MAGIC | 現在EP | 必須 |
| `target_magic` | int | GameConstants.DEFAULT_TARGET_MAGIC | 目標TEP | 必須 |
| `current_tile` | int | 0 | 現在位置（タイル番号0-19） | 必須 |
| `destroyed_count` | int | 0 | バトルで破壊したクリーチャー数 | 必須 |

### 移動制御（移動フェーズで使用）

| フィールド | 型 | 初期値 | 説明 | シリアライズ |
|-----------|-----|--------|------|:-----------:|
| `current_direction` | int | 1 | 移動方向（1=順, -1=逆） | 必須 |
| `came_from` | int | -1 | 前にいたタイル（分岐判定用） | 必須 |
| `last_choice_tile` | int | -1 | 最後に選択したタイル | 必須 |
| `movement_direction` | String | "" | 移動方向フラグ | 必須 |

### 効果・刻印

| フィールド | 型 | 初期値 | 説明 | シリアライズ |
|-----------|-----|--------|------|:-----------:|
| `curse` | Dictionary | {} | プレイヤー刻印（後述） | 必須 |
| `direction_choice_pending` | bool | false | 方向選択権（次ターン有効） | 必須 |
| `magic_stones` | Dictionary | {fire:0, water:0, earth:0, wind:0} | 魔法石所持数 | 必須 |

### ランタイム専用（シリアライズ不要）

| フィールド | 型 | 初期値 | 説明 | シリアライズ |
|-----------|-----|--------|------|:-----------:|
| `color` | Color | PLAYER_COLORS[id] | UI表示色（idから復元可能） | 不要 |
| `piece_node` | Node | null | 3D駒ノード参照 | 不要 |

### CPU引き継ぎ用（追加予定）

| フィールド | 型 | 初期値 | 説明 | シリアライズ |
|-----------|-----|--------|------|:-----------:|
| `is_cpu` | bool | false | CPU操作フラグ（ランタイム切替可能） | 必須 |

---

## 刻印データ構造

### プレイヤー刻印（`player.curse`）

```gdscript
{
  "curse_type": String,   # "skill_nullify", "plague", "bounty", "stat_reduce" 等
  "name": String,         # 刻印表示名
  "duration": int,        # -1=永続, n=残りターン数
  "params": Dictionary,   # curse_type固有パラメータ
  "caster_id": int        # 付与者ID
}
```

### クリーチャー刻印（`creature_data.curse`）

```gdscript
{
  "curse_type": String,   # "battle_disable", "command_growth", "mystic_grant" 等
  "name": String,
  "duration": int,
  "params": Dictionary
}
```

### 世界刻印（`game_stats.world_curse`）

```gdscript
{
  "curse_type": String,   # "land_change_restrict", "invasion_restrict" 等
  "name": String,
  "duration": int,
  "params": Dictionary
}
```

---

## ゲーム全状態のスナップショット構成

CPU引き継ぎとゲーム復帰の両方で必要な状態を網羅する。

### P0: 必須（なければゲームが再開できない）

| システム | データ | 説明 |
|---------|--------|------|
| PlayerSystem | `players[]` 全フィールド | 全プレイヤーの状態 |
| CardSystem | `player_hands` | 各プレイヤーの手札 |
| CardSystem | `player_decks` | 各プレイヤーのデッキ残り |
| CardSystem | `player_discards` | 各プレイヤーの捨て札 |
| BoardSystem3D | 各タイルの `owner_id`, `creature_data`, `level`, `down_state` | ボード状態 |
| GameFlowManager | `current_turn_number`, `current_player_index` | ターン進行 |
| GameFlowManager | `current_phase` | 現在のフェーズ |
| GameFlowManager | `game_stats` | 世界刻印等 |

### P1: 重要（なければ一部ロジックが狂う）

| システム | データ | 説明 |
|---------|--------|------|
| LapSystem | `player_lap_state` | チェックポイント通過状態・周回数 |
| LapSystem | `destroy_count` | クリーチャー破壊カウンター |
| PlayerBuffSystem | `player_buffs` | バフ配列（コスト軽減、ダイス修正等） |
| SpellStateHandler | `spell_used_this_turn`, `skip_dice_phase` | ターン内フラグ |

### P2: 推奨（なくてもゲーム進行に致命的でない）

| システム | データ | 説明 |
|---------|--------|------|
| 各タイル creature_data | `map_lap_count` | 周回ボーナス適用回数 |
| 各タイル creature_data | `permanent_effects`, `temporary_effects` | クリーチャーの効果 |

### ゲーム設定（固定値、復帰時に再設定）

| データ | 説明 |
|--------|------|
| `map_id` | ステージID |
| `player_count` | プレイヤー数 |
| CPU/プレイヤー割当 | 各プレイヤーが人間かCPUか |
| `lap_bonus_preset` | 周回ボーナス設定 |
| `base_bonus` | 基礎周回ボーナスEP |

---

## CPU引き継ぎの設計

### フロー

```
プレイヤー切断検知
  ↓
現在のフェーズを確認
  ├─ ターン外（他プレイヤーのターン中） → player.is_cpu = true のみ
  └─ 自分のターン中
      ├─ 移動フェーズ → 移動完了まで待機 → is_cpu = true
      ├─ スペル選択中 → スペルキャンセル → is_cpu = true
      ├─ カード犠牲選択中 → 犠牲キャンセル（EP返却） → is_cpu = true
      ├─ アイテム選択中 → CPU自動選択に切替
      └─ バトル中 → バトル完了まで待機 → is_cpu = true
  ↓
次のターンからCPU AIが操作
```

### 再接続フロー

```
プレイヤー再接続
  ↓
player.is_cpu = false
  ↓
次の自分のターン開始時からプレイヤー操作に復帰
```

---

## 既知の問題（要修正）

### ~~destroyed_count の重複管理~~ ✅ 解決済み
- `PlayerData.destroyed_count` は未使用だったため削除
- 破壊カウントは `LapSystem.destroy_count` が唯一の正（全参照箇所がこちらを使用）

### ~~magic_power の初期値不整合~~ ✅ 解決済み
- デフォルト値を `0` に変更（`target_magic` も同様）
- 初期化は必ず `initialize_players()` 経由で `GameConstants` の値が設定される

### ~~buffs フィールドの二重管理~~ ✅ 解決済み
- `PlayerData.buffs` は `direction_choice_pending` フラグ専用だった（`PlayerBuffSystem` のバフシステムとは無関係）
- `buffs: Dictionary` → `direction_choice_pending: bool` に変更し、混同を解消

---

## MatchSnapshotBuilder

**ファイル**: `scripts/system_manager/match_snapshot_builder.gd`

各システムに散らばったプレイヤー・試合状態を「集めるだけ」の集約クラス。
状態の変更は一切行わない。

### API

| メソッド | 戻り値 | 説明 |
|---------|--------|------|
| `get_player_snapshot(player_id)` | Dictionary | プレイヤー1人分の完全状態 |
| `get_match_snapshot()` | Dictionary | 試合全体の完全状態（全プレイヤー + ボード + ターン情報） |

### データソースマッピング

| スナップショットのキー | 取得元 |
|-----------------------|--------|
| id, name, magic_power, current_tile 等 | PlayerSystem.PlayerData |
| lap_state | LapSystem.player_lap_state |
| buffs | PlayerBuffSystem.player_buffs |
| spell_used_this_turn, skip_dice_phase | SpellStateHandler |
| hand, deck_count, discard_count | CardSystem |
| destroy_count | LapSystem（全体共有値、match_snapshot直下） |
| current_turn, current_phase, game_stats | GameFlowManager |
| tiles[] | BoardSystem3D |

### 将来の用途

- セーブ/ロード
- PvP同期（network_design.md の JSON メッセージに変換）
- リプレイ
- デバッグ（状態一発取得）

---

## 実装ファイル一覧

| ファイル | 役割 |
|----------|------|
| scripts/player_system.gd | PlayerData定義・EP操作・TEP計算・順位計算 |
| scripts/player_buff_system.gd | バフ管理（duration付き配列） |
| scripts/game_flow/lap_system.gd | 周回管理・チェックポイント・破壊カウント |
| scripts/game_flow_manager.gd | ターン進行・フェーズ管理・game_stats |
| scripts/card_system.gd | 手札・デッキ・捨て札管理 |
| scripts/board_system_3d.gd | タイル状態管理（所有者・クリーチャー・レベル） |
| scripts/spells/spell_curse.gd | クリーチャー/プレイヤー刻印操作 |
| scripts/spells/spell_world_curse.gd | 世界刻印操作 |
| scripts/tiles/magic_stone_system.gd | 魔法石価値計算 |
| scripts/game_flow/spell_state_handler.gd | スペルフェーズ状態 |
| scripts/system_manager/match_snapshot_builder.gd | 試合状態スナップショット集約 |
