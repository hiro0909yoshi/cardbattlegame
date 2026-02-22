# ターン数カウンターシステム実装仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年10月27日  
**バージョン**: 1.1  
**ステータス**: ✅ 実装完了

---

## 📋 概要

ゲームのラウンド数（全プレイヤーが1回ずつ行動する単位）をカウントし、ラウンド数に応じてクリーチャーのステータスを変動させるシステム。

---

## 🎯 実装内容

### 1. ラウンド数カウンター

#### GameFlowManager
- **変数**: `current_turn_number`（実際はラウンド数）
- **初期値**: 1（ゲーム開始時）
- **カウント方式**: 全プレイヤーが1回ずつ行動したら+1（ラウンド制）

```gdscript
# ゲーム開始
var current_turn_number = 1  # ラウンド数カウンター（初期値1）

func end_turn():
	# ...
	# プレイヤー切り替え
	var old_player_index = board_system_3d.current_player_index
	board_system_3d.current_player_index = (board_system_3d.current_player_index + 1) % board_system_3d.player_count
	
	# 全プレイヤーが1回ずつ行動したらラウンド数を増やす
	if board_system_3d.current_player_index == 0:
		current_turn_number += 1
		print("=== ラウンド", current_turn_number, "開始 ===")
```

### 2. ラウンド制の仕様

#### 例: 2プレイヤーの場合
| 行動順 | プレイヤー | ラウンド数 |
|--------|-----------|-----------|
| 1 | プレイヤー1 | 1 |
| 2 | プレイヤー2 | 1 |
| 3 | プレイヤー1 | 2 ← ここで+1 |
| 4 | プレイヤー2 | 2 |
| 5 | プレイヤー1 | 3 ← ここで+1 |

**重要**: プレイヤー1のターンが来た時（`current_player_index == 0`）にラウンド数が増加

---

## 🎮 対象クリーチャー

### ラーバキン (ID 47)

#### 能力
- **AP|基本AP**: AP|基本AP(60) - 現ラウンド数
- **HP**: 基本HP(30) + 現ラウンド数

#### ability_parsed
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"effect_type": "turn_number_bonus",
		"ap_mode": "subtract",
		"hp_mode": "add"
	  }
	]
  }
}
```

#### ステータス変化例
| ラウンド | AP|基本AP | HP | 備考 |
|---------|----|----|------|
| 1 | 59 | 31 | ゲーム開始直後 |
| 2 | 58 | 32 | |
| 3 | 57 | 33 | |
| 5 | 55 | 35 | |
| 10 | 50 | 40 | 攻守バランス型 |
| 20 | 40 | 50 | 防御寄り |
| 30 | 30 | 60 | 完全堅守 |

**戦略**: ラウンドが進むほど、攻撃力が下がり耐久力が上がる。序盤は攻撃型、後半は堅守として運用。

---

## 🔧 実装詳細

### BattleSkillProcessor

#### apply_turn_number_bonus
```gdscript
func apply_turn_number_bonus(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var effects = ability_parsed.get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "turn_number_bonus":
			var game_flow_manager = context.get("game_flow_manager")
			if not game_flow_manager:
				return
			
			var current_turn = game_flow_manager.current_turn_number
			var ap_mode = effect.get("ap_mode", "add")
			var hp_mode = effect.get("hp_mode", "add")
			
			# AP処理
			if ap_mode == "subtract":
				participant.current_ap = max(0, participant.current_ap - current_turn)
			elif ap_mode == "add":
				participant.current_ap += current_turn
			elif ap_mode == "override":
				participant.current_ap = current_turn
			
			# HP処理（temporary_bonus_hpを使用）
			if hp_mode == "add":
				participant.temporary_bonus_hp += current_turn
			elif hp_mode == "subtract":
				participant.temporary_bonus_hp -= current_turn
```

**注**: HP処理は`current_hp`ではなく`temporary_bonus_hp`に加算する。これにより戦闘後にボーナスがリセットされ、クリーチャー本体のHPには影響しない。

#### 適用タイミング
- バトル準備時、他のスキルより**最優先**で適用
- 共鳴、強化、術攻撃などの前に実行

### ConditionChecker

#### build_battle_context
`game_flow_manager`をcontextに追加：

```gdscript
static func build_battle_context(...):
	return {
		# ...
		"game_flow_manager": game_state.get("game_flow_manager", null),
		# ...
	}
```

---

## 📊 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/game_flow_manager.gd` | ラウンドカウンター管理 |
| `scripts/battle/battle_skill_processor.gd` | ターン数ボーナス適用 |
| `scripts/skills/condition_checker.gd` | contextにgame_flow_manager追加 |
| `data/fire_2.json` | ラーバキンのability_parsed |

---

## ✅ テスト確認項目

- [x] ラウンド1でラーバキン召喚: AP|基本AP=59, HP=31
- [x] ラウンド3でバトル: AP|基本AP=57, HP=33
- [x] ラウンド5でバトル: AP|基本AP=55, HP=35
- [x] プレイヤー1→2→1と回った時にラウンド2になる
- [x] 2プレイヤーでラウンドカウントが正常

---

## 📝 用語の明確化

### ターン vs ラウンド

| 用語 | 定義 | カウント方法 |
|------|------|-------------|
| **ターン** | 1人のプレイヤーの行動 | プレイヤー切り替え毎に+1 |
| **ラウンド** | 全プレイヤーが1回ずつ行動 | 全員行動後に+1 |

**本システムの実装**: ラウンド制
- 変数名は`current_turn_number`だが、実際は**ラウンド数**を管理
- 全プレイヤーが1回ずつ行動して初めて+1

---

## 🐛 解決した問題

### 問題1: ターン制 vs ラウンド制
**症状**: プレイヤー切り替え毎にカウントが増加  
**原因**: `end_turn()`で常に+1していた  
**解決**: `current_player_index == 0`の時のみ+1

### 問題2: game_flow_managerが見つからない
**症状**: `【ターン数ボーナス】GameFlowManagerが見つかりません`  
**原因**: `ConditionChecker.build_battle_context`にgame_flow_managerが含まれていない  
**解決**: contextに`game_flow_manager`を追加

---

## 📝 今後の拡張

- [ ] 他のラウンド数依存クリーチャーの追加
- [ ] UIにラウンド数表示
- [ ] ラウンド数に応じた特殊イベント

---

**最終更新**: 2025年12月16日（v1.1 - 初期値・HP処理の記述修正）
