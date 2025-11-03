# 破壊数カウンター実装場所の修正

## 変更理由

ユーザー確認により、破壊数カウンターは**1ゲーム内のみ有効**で、**スペルでリセット可能**であることが判明。

- ❌ GameData（グローバル永続データ）に保存するのは誤り
- ✅ GameFlowManager（ゲーム進行管理）に保存するのが正しい

## 正しい設計

| データ | 保存場所 | 理由 |
|--------|---------|------|
| ターン数 | GameFlowManager | 1ゲーム内のみ有効 |
| 周回数 | GameFlowManager | 1ゲーム内のみ有効 |
| 破壊数 | GameFlowManager | 1ゲーム内のみ有効、スペルでリセット可能 |

## 実装コード

```gdscript
# scripts/game_flow_manager.gd
class_name GameFlowManager

# 追加
var current_turn: int = 0                    # 現在のターン数
var player_laps: Dictionary = {}             # 各プレイヤーの周回数 {player_id: lap_count}
var creatures_destroyed_this_game: int = 0   # このゲームでの破壊数

func start_game():
	current_turn = 0
	player_laps = {0: 0, 1: 0, 2: 0, 3: 0}
	creatures_destroyed_this_game = 0
	# ... 既存処理

func start_turn():
	current_turn += 1
	# ... 既存処理

func on_creature_destroyed():
	"""クリーチャー破壊時にカウント増加"""
	creatures_destroyed_this_game += 1
	print("このゲームの破壊数: ", creatures_destroyed_this_game)

func reset_destroy_count():
	"""スペルで破壊数をリセット"""
	creatures_destroyed_this_game = 0
	print("破壊数リセット")

func get_destroy_count() -> int:
	return creatures_destroyed_this_game

func on_lap_completed(player_id: int):
	"""周回完了時"""
	player_laps[player_id] = player_laps.get(player_id, 0) + 1
	# クリーチャーへのバフ適用処理...
```

## 使用方法

### BattleSystem から呼び出し
```gdscript
# scripts/battle/battle_system.gd
func on_battle_complete(result: Dictionary):
	if result.winner == "attacker":
		game_flow_manager.on_creature_destroyed()  # カウント増加
		# 永続バフ適用処理...
```

### BattleSkillProcessor で取得
```gdscript
# scripts/battle/battle_skill_processor.gd
func apply_destroy_count_effects(participant: BattleParticipant):
	var destroy_count = game_flow_manager.get_destroy_count()
	participant.temporary_bonus_ap += destroy_count * 5
```

### スペルでリセット
```gdscript
# スペル「リセット破壊数」などで
game_flow_manager.reset_destroy_count()
```

---

**最終更新**: 2025年10月26日
