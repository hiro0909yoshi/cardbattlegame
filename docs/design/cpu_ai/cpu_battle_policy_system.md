# CPUバトルポリシー（性格）システム

## 概要

CPUの戦闘行動を「性格」として表現し、キャラクターごとに異なる戦闘スタイルを実現するシステム。
侵略時と防衛時それぞれに複数のポリシーを設定し、重み付き抽選で行動を決定する。

## 設計思想

### 基本方針
- **CPUはアイテムを使わない前提で戦闘判断**を行う
- 防衛側のアイテム使用想定のみを変えることで「楽観的」「慎重」の性格を表現
- ただし、アイテムなしでは勝てない場合に限り、CPUもアイテムを使用して逆転を試みる

### ターン内一貫性
- 同一ターン内でポリシー抽選は**1回のみ**
- 移動シミュレーション時に抽選した結果をキャッシュし、実際の停止時も同じポリシーを使用
- これにより「移動判断と実際の行動の一貫性」を保つ

## ポリシー種別

### 侵略時ポリシー（AttackAction）

| ポリシー | JSON キー | 説明 | シミュレーション条件 |
|---------|-----------|------|---------------------|
| ALWAYS_BATTLE | `always_battle` | 必ず戦闘 | 勝敗関係なく戦闘する |
| BATTLE_IF_BOTH_NO_ITEM | `both_no_item` | 両方アイテムなしで勝てるなら戦闘 | CPU: なし、防衛側: なし |
| BATTLE_IF_WIN_VS_ENEMY_ITEM | `vs_enemy_item` | 防衛側がアイテム使用でも勝てるなら戦闘 | CPU: なし、防衛側: あり（ワーストケース） |
| NEVER_BATTLE | `never_battle` | 戦闘しない | 常に通行料を支払う |

#### ポリシー選択ロジック

1. 各ポリシーの「選択可能条件」をチェック
2. 条件を満たすポリシーのみ抽選対象
3. 重み付き抽選で行動を決定

**選択可能条件**：
- `ALWAYS_BATTLE`: 常に選択可能
- `BATTLE_IF_BOTH_NO_ITEM`: `can_win_both_no_item == true` の場合のみ
- `BATTLE_IF_WIN_VS_ENEMY_ITEM`: `can_win_vs_enemy_item == true` の場合のみ
- `NEVER_BATTLE`: 常に選択可能

### 防衛時ポリシー（DefenseAction）

| ポリシー | JSON キー | 説明 |
|---------|-----------|------|
| NO_ITEM_DEFEND | `no_item` | アイテムなしで防衛 |
| WITH_ITEM_DEFEND | `with_item` | アイテムを使用して防衛 |
| SURRENDER | `surrender` | 降参（戦闘放棄） |

**注意**: 防衛時はターン内キャッシュを使用せず、毎回抽選する（敵ターン中のため独立した判断）

## JSON設定形式

### キャラクター設定（characters.json）

```json
{
  "enemy_id": {
    "name": "キャラクター名",
    "battle_policy": {
      "attack": {
        "always_battle": 0.0,
        "both_no_item": 0.3,
        "vs_enemy_item": 1.0,
        "never_battle": 0.0
      },
      "defense": {
        "no_item": 1.0,
        "with_item": 1.0,
        "surrender": 0.0
      }
    }
  }
}
```

### ステージ設定（stages.json）

```json
{
  "stages": [
    {
      "id": "stage_01",
      "enemies": [
        {
          "character_id": "bowser",
          "battle_policy": {
            "attack": {
              "always_battle": 0.0,
              "both_no_item": 1.0,
              "vs_enemy_item": 0.0,
              "never_battle": 0.0
            }
          }
        }
      ]
    }
  ]
}
```

### 重み付き抽選の例

```
attack: {
  "always_battle": 1.0,
  "both_no_item": 1.0,
  "vs_enemy_item": 1.0,
  "never_battle": 1.0
}
```

この設定で全て選択可能な場合：
- 各ポリシー = 1.0 / 4.0 = **25%**

「両方アイテムなしで勝てない」状況では `both_no_item` が除外され：
- 残り3つで各 **33.3%**

## 実装ファイル

### コアファイル

| ファイル | 役割 |
|---------|------|
| `cpu_battle_policy.gd` | ポリシー定義、重み付き抽選ロジック |
| `cpu_battle_ai.gd` | バトル評価（`can_win_both_no_item`, `can_win_vs_enemy_item`の判定） |
| `cpu_ai_handler.gd` | ポリシー判断、ターン内キャッシュ管理 |
| `cpu_movement_evaluator.gd` | 移動シミュレーションへの性格反映 |
| `cpu_turn_processor.gd` | ターン開始時のキャッシュリセット |

### 設定読み込み

| ファイル | 役割 |
|---------|------|
| `quest_game.gd` | クエストモードでのポリシー読み込み |
| `game_3d.gd` | 通常モードでのポリシー読み込み |
| `stage_loader.gd` | ステージJSONからのポリシー取得 |

## 主要メソッド

### cpu_battle_policy.gd

```gdscript
# 侵略時の行動を決定（重み付き抽選）
func decide_attack_action(eval_result: Dictionary) -> int

# 防衛時の行動を決定（重み付き抽選）
func decide_defense_action(eval_result: Dictionary) -> int

# JSONからポリシーを読み込み
func load_from_json(data: Dictionary) -> void

# プリセットポリシー生成
static func create_tutorial_policy() -> CPUBattlePolicy
static func create_standard_policy() -> CPUBattlePolicy
static func create_optimistic_policy() -> CPUBattlePolicy
static func create_passive_policy() -> CPUBattlePolicy
static func create_balanced_policy() -> CPUBattlePolicy
```

### cpu_ai_handler.gd

```gdscript
# ターン開始時にキャッシュをリセット
func reset_turn_cache() -> void

# 性格を反映したバトル結果を取得（移動シミュレーション用）
func get_policy_based_battle_result(eval_result: Dictionary) -> Dictionary
# 戻り値: { "will_battle": bool, "will_win": bool }

# JSONからポリシーを読み込んで設定
func load_battle_policy_from_json(policy_data: Dictionary) -> void
```

### cpu_battle_ai.gd

```gdscript
# バトル評価結果のフィールド
{
  "can_win_both_no_item": false,      # 両方アイテムなしで勝てるか
  "can_win_vs_enemy_item": false,     # ワーストケースで勝てるか
  "best_both_no_item_creature_index": -1,   # 両方アイテムなしで最善のクリーチャー
  "best_both_no_item_overkill": -999,       # オーバーキル値
  "best_no_item_creature_index": -1,  # ワーストケースで最善のクリーチャー
  "best_no_item_overkill": -999,      # オーバーキル値
}
```

## 移動シミュレーションへの反映

### スコア計算

| ポリシー結果 | will_battle | will_win | スコア |
|-------------|-------------|----------|--------|
| 戦闘して勝つ | true | true | `toll * CAN_WIN_MULTIPLIER` (正) |
| 戦闘して負ける | true | false | `toll * CAN_WIN_MULTIPLIER` (正)* |
| 戦闘しない | false | false | `toll * CANT_WIN_MULTIPLIER` (負) |

*注: `ALWAYS_BATTLE`で負ける場合も正のスコア（リスク計算は現在含まない）

### 実装箇所

`cpu_movement_evaluator.gd` の `_can_invade_and_win()`:

```gdscript
func _can_invade_and_win(tile_index: int, attacker_id: int) -> bool:
    # cpu_ai_handlerがあれば性格を反映したバトル結果を取得
    if cpu_ai_handler and battle_ai:
        var eval_result = battle_ai.evaluate_all_combinations_for_battle(...)
        var policy_result = cpu_ai_handler.get_policy_based_battle_result(eval_result)
        
        # 戦闘して勝てる場合のみtrue
        return policy_result.will_battle and policy_result.will_win
```

## プリセットポリシー

| プリセット名 | 特徴 | 用途 |
|-------------|------|------|
| tutorial | 常に戦闘 | チュートリアル |
| standard | ワーストケース基準 | 標準的なCPU |
| optimistic | 楽観的（両方アイテムなし） | 攻撃的なCPU |
| passive | 戦闘を避ける | 消極的なCPU |
| balanced | バランス型 | デフォルト |

## デバッグログ

```
[CPU AI] ターンキャッシュをリセット
[CPU AI] ポリシー設定済み
[CPUBattlePolicy] 選択可能な行動: { 1: 1.0, 3: 1.0 }
[CPUBattlePolicy] 抽選結果: BATTLE_IF_BOTH_NO_ITEM
[CPU AI] ポリシー抽選結果をキャッシュ: BATTLE_IF_BOTH_NO_ITEM
[CPU AI] キャッシュされたポリシーを使用: BATTLE_IF_BOTH_NO_ITEM
[MovementEvaluator] _can_invade_and_win: tile=1, will_battle=false, will_win=false
```

## 実装上の注意点

### ポリシー設定のタイミング

初期化順序に注意が必要。以下の順序で処理される：

1. `GameSystemManager.Phase 4-4` で `item_phase_handler._initialize_cpu_context()` が呼ばれる
2. この時点では `cpu_ai_handler.battle_policy` は null
3. `_get_cpu_battle_policy()` でデフォルトポリシーが作成され、`cpu_defense_ai` に設定される
4. **その後** `quest_game._setup_cpu_battle_policies()` でJSONからポリシーを読み込み、`cpu_ai_handler.battle_policy` に設定

この順序により、`cpu_defense_ai` には初期化時のデフォルトポリシーが設定されたままになる問題があった。

### 解決策

`item_phase_handler.gd` の `_preselect_defender_item()` で、防御判断の直前に最新のポリシーを取得して設定する：

```gdscript
# 最新のバトルポリシーを取得して設定（JSONから読み込んだポリシーが反映されるように）
var latest_policy = _get_cpu_battle_policy(game_flow_manager)
if latest_policy and cpu_defense_ai:
    cpu_defense_ai.set_battle_policy(latest_policy)
```

### cpu_ai_handler のインスタンス管理

`board_system_3d.setup_cpu_ai_handler()` が複数回呼ばれても、既存の `cpu_ai_handler` インスタンスを再利用し、`battle_policy` を保持する：

```gdscript
func setup_cpu_ai_handler():
    var existing = get_node_or_null("CPUAIHandler")
    if existing:
        cpu_ai_handler = existing
    elif not cpu_ai_handler:
        # 新規作成
        cpu_ai_handler = CPUAIHandler.new()
        cpu_ai_handler.name = "CPUAIHandler"
        add_child(cpu_ai_handler)
    
    # システム参照は毎回更新（battle_policyは保持される）
    if cpu_ai_handler.has_method("setup_systems"):
        cpu_ai_handler.setup_systems(...)
```

また、`cpu_ai_handler.setup_systems()` 内で `battle_policy` を保持する：

```gdscript
func setup_systems(...):
    # 既存のbattle_policyを保持
    var existing_policy = battle_policy
    
    # コンテキスト初期化...
    
    # 既存のbattle_policyを復元
    if existing_policy:
        battle_policy = existing_policy
```

## 今後の拡張予定

- [ ] 複数CPU対応（現在は最初の敵のみ）
- [x] 防衛時ポリシーの実装（完了）
- [ ] 状況に応じた動的ポリシー変更（残りHP、ドミニオ数など）
