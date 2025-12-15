# 破壊数カウンター実装場所の修正

## 変更理由

ユーザー確認により、破壊数カウンターは**1ゲーム内のみ有効**で、**スペルでリセット可能**であることが判明。

- ❌ GameData（グローバル永続データ）に保存するのは誤り
- ✅ LapSystem（周回管理システム）に保存するのが正しい

## 正しい設計

| データ | 保存場所 | 理由 |
|--------|---------|------|
| ターン数 | GameFlowManager | 1ゲーム内のみ有効 |
| 周回数 | LapSystem | 1ゲーム内のみ有効 |
| 破壊数 | LapSystem | 1ゲーム内のみ有効、スペルでリセット可能 |

## 実装コード

```gdscript
# scripts/game_flow/lap_system.gd
class_name LapSystem

## 周回状態
var player_lap_state: Dictionary = {}  # {player_id: {N: bool, S: bool, lap_count: int}}

## 破壊カウンター
var destroy_count: int = 0

## 周回状態を初期化
func initialize_lap_state(player_count: int):
	player_lap_state.clear()
	destroy_count = 0
	
	for i in range(player_count):
		player_lap_state[i] = {
			"N": false,
			"S": false,
			"lap_count": 1
		}

func on_creature_destroyed():
	"""クリーチャー破壊時にカウント増加"""
	destroy_count += 1
	print("[破壊カウント] 累計: ", destroy_count)

func get_destroy_count() -> int:
	return destroy_count

func reset_destroy_count():
	"""スペルで破壊数をリセット"""
	destroy_count = 0
	print("[破壊カウント] リセット")
```

## 使用方法

### BattleSystem から呼び出し
```gdscript
# scripts/battle_system.gd
# 侵略成功時・防御成功時などでカウント増加
if game_flow_manager_ref:
	game_flow_manager_ref.lap_system.on_creature_destroyed()
```

### BattleSkillProcessor で取得
```gdscript
# scripts/battle/battle_skill_processor.gd
func apply_destroy_count_effects(participant: BattleParticipant):
	var destroy_count = game_flow_manager_ref.lap_system.get_destroy_count()
	participant.temporary_bonus_ap += destroy_count * 5
```

### スペルでリセット
```gdscript
# スペル「リセット破壊数」などで
game_flow_manager_ref.lap_system.reset_destroy_count()
```

---

**最終更新**: 2025年12月16日
