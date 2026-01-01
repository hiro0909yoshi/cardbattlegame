# CPU AI 実装設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**作成日**: 2025年11月10日  
**ステータス**: 部分実装済み（バトルAI・スペルAI実装完了）

> **注**: 実装済みの詳細仕様は以下を参照:
> - `docs/specs/cpu_battle_ai_spec.md` - バトル判断
> - `docs/specs/cpu_spell_ai_spec.md` - スペル/秘術判断

---

## 📋 目次

1. [概要](#概要)
2. [設計思想](#設計思想)
3. [評価関数ベースAI](#評価関数ベースai)
4. [シナジー評価](#シナジー評価)
5. [先読み機能](#先読み機能)
6. [難易度設定](#難易度設定)
7. [実装ロードマップ](#実装ロードマップ)

---

## 概要

### 目的
プレイヤーに適度な挑戦を提供し、楽しめるCPU AIを実装する。

### 設計方針
- **評価関数ベース**: ルールベースよりも柔軟で拡張性が高い
- **段階的実装**: Level 1 → 10 まで段階的に賢くする
- **データ駆動**: デッキごとに戦術プロファイルを持つ
- **デバッグしやすさ**: スコアをログ出力して調整可能

### 非目標（実装しない）
- 完全な最適解の計算（計算量が膨大）
- プレイヤーの手札を完全に推測（カルドセプトの性質上困難）
- 学習型AI（データ収集とモデル学習が必要）

---

## 設計思想

### 一般的なゲームAIの実装例

#### ポケモン（ターンベースRPG）
```
弱いトレーナー: ランダム技選択
普通のトレーナー: タイプ相性を見る
強いトレーナー: 効果的な技 + HP管理 + 交代読み
```

#### 遊戯王デュエルリンクス
```
Level 10: ランダムプレイ
Level 30: 基本コンボ理解
Level 60: デッキの勝ち筋を理解
```

#### ハースストーン
```
各ターンの選択肢をスコアリング:
- 盤面制圧: 0.7
- 顔面ダメージ: 0.3
- 資源温存: 0.2
デッキタイプで重みを調整
```

### 本プロジェクトのアプローチ

**評価関数 + デッキプロファイル + 難易度レベル**

```
選択肢をスコアリング
  ↓
最高スコアの行動を選択（確率的）
  ↓
難易度に応じて評価の深さを変える
```

---

## 評価関数ベースAI

### 基本構造

```gdscript
# scripts/ai/cpu_thinking.gd
class_name CPUThinking

var deck_profile: Dictionary  # デッキの戦術プロファイル
var difficulty_level: int  # 1-10

## 行動を評価してスコアを返す
func evaluate_action(action: Dictionary, game_state: Dictionary) -> float:
	var score = 0.0
	
	# Level 1: 基本評価（全CPUが使用）
	score += evaluate_basic_value(action)
	
	# Level 3+: テンポ評価（効率性）
	if difficulty_level >= 3:
		score += evaluate_tempo(action, game_state)
	
	# Level 5+: シナジー評価
	if difficulty_level >= 5:
		score += evaluate_synergy(action, game_state)
	
	# Level 7+: 先読み評価
	if difficulty_level >= 7:
		score += evaluate_future_turns(action, game_state)
	
	# デッキプロファイルによる補正
	score *= get_archetype_multiplier(action)
	
	# ランダム要素（低難易度ほど大きい）
	var random_factor = (10 - difficulty_level) * 0.05
	score += randf_range(-random_factor, random_factor) * score
	
	return score

## 最良の行動を選択
func choose_best_action(actions: Array, game_state: Dictionary) -> Dictionary:
	var best_action = null
	var best_score = -INF
	
	for action in actions:
		var score = evaluate_action(action, game_state)
		
		# デバッグログ
		if OS.is_debug_build():
			print("[AI] ", action.type, ": score=", score)
		
		if score > best_score:
			best_score = score
			best_action = action
	
	return best_action
```

### Level 1: 基本評価

```gdscript
func evaluate_basic_value(action: Dictionary) -> float:
	var score = 0.0
	
	match action.type:
		"summon":
			var creature = action.creature
			var cost = action.cost
			
			# クリーチャーの基本価値
			score += creature.ap * 1.0
			score += creature.hp * 0.5
			
			# コストはマイナス要素
			score -= cost * 0.3
			
		"invade":
			var my_creature = action.my_creature
			var enemy_creature = action.enemy_creature
			
			# 勝てるなら高評価
			if my_creature.ap > enemy_creature.hp:
				score += 50.0
				
				# 生き残れるならさらに高評価
				if my_creature.hp > enemy_creature.ap:
					score += 30.0
			else:
				score -= 100.0  # 負けるなら低評価
		
		"level_up":
			# 土地レベル上昇の価値
			score += action.current_level * 10.0
		
		"use_spell":
			# スペルの基本価値
			score += 30.0  # 仮の値
	
	return score
```

### Level 3: テンポ評価

```gdscript
func evaluate_tempo(action: Dictionary, game_state: Dictionary) -> float:
	var score = 0.0
	
	match action.type:
		"summon":
			var cost = action.cost
			var my_magic = game_state.my_magic
			
			# 魔力効率
			var efficiency = action.creature.ap / max(cost, 1)
			score += efficiency * 10.0
			
			# 魔力を使い切らない方が良い
			if my_magic - cost > 30:
				score += 10.0
		
		"invade":
			# 土地を奪えるなら高評価
			if action.tile_owner != game_state.my_id:
				score += 40.0
	
	return score
```

---

## シナジー評価

### 最小限のシナジー定義

#### デッキプロファイルの例

```json
{
  "deck_id": 1,
  "name": "炎速攻",
  "archetype": "aggro",
  "profile": {
	"aggression": 0.8,
	"resource_management": 0.3,
	"combo_seeking": 0.4
  },
  "synergy_rules": [
	{
	  "name": "武器+先制",
	  "item_type": "weapon",
	  "creature_keywords": ["先制"],
	  "bonus": 30.0,
	  "reason": "先制で確実にダメージ"
	},
	{
	  "name": "防具+低HP",
	  "item_type": "armor",
	  "creature_condition": "hp < 30",
	  "bonus": 25.0
	}
  ],
  "special_items": [
	{
	  "item_id": 1030,
	  "name": "ソウルレイ",
	  "bonus_multiplier": 1.3,
	  "reason": "手札に戻るので積極的に使う"
	}
  ]
}
```

#### シナジー評価の実装

```gdscript
func evaluate_synergy(action: Dictionary, game_state: Dictionary) -> float:
	var score = 0.0
	
	if action.type != "use_item":
		return 0.0
	
	var item = action.item
	var creature = action.creature
	
	# カテゴリルールチェック
	for rule in deck_profile.synergy_rules:
		if matches_synergy_rule(item, creature, rule):
			score += rule.bonus
			if OS.is_debug_build():
				print("[シナジー] ", rule.name, " +", rule.bonus)
	
	# 特殊アイテムチェック
	for special in deck_profile.special_items:
		if item.id == special.item_id:
			score *= special.bonus_multiplier
			if OS.is_debug_build():
				print("[特殊] ", special.name, " x", special.bonus_multiplier)
	
	return score

func matches_synergy_rule(item: Dictionary, creature: Dictionary, rule: Dictionary) -> bool:
	# アイテムタイプチェック
	if rule.has("item_type"):
		if item.type != rule.item_type:
			return false
	
	# クリーチャーキーワードチェック
	if rule.has("creature_keywords"):
		var keywords = creature.get("ability_parsed", {}).get("keywords", [])
		var has_keyword = false
		for kw in rule.creature_keywords:
			if kw in keywords:
				has_keyword = true
				break
		if not has_keyword:
			return false
	
	# 条件チェック
	if rule.has("creature_condition"):
		if not evaluate_simple_condition(rule.creature_condition, creature):
			return false
	
	return true

func evaluate_simple_condition(condition: String, creature: Dictionary) -> bool:
	# 簡易的な条件評価
	# 例: "hp < 30" → creature.hp < 30
	if condition.contains("<"):
		var parts = condition.split("<")
		var stat = parts[0].strip_edges()
		var value = int(parts[1].strip_edges())
		return creature.get(stat, 0) < value
	
	return true
```

### 自然に評価されるシナジー（90%のケース）

```gdscript
func evaluate_item_on_creature(item: Dictionary, creature: Dictionary, battle: Dictionary) -> float:
	var score = 0.0
	
	# 戦闘シミュレーション
	var my_ap = creature.ap + item.get("ap_bonus", 0)
	var my_hp = creature.hp + item.get("hp_bonus", 0)
	var enemy_ap = battle.enemy.ap
	var enemy_hp = battle.enemy.hp
	
	# 勝てるようになる？（最重要）
	var can_win_without = creature.ap > enemy_hp
	var can_win_with = my_ap > enemy_hp
	
	if can_win_with and not can_win_without:
		score += 100.0  # 勝てるようになるなら超重要
	
	# 生き残れるようになる？
	var survives_without = creature.hp > enemy_ap
	var survives_with = my_hp > enemy_ap
	
	if survives_with and not survives_without:
		score += 80.0  # 生き残れるなら重要
	
	# すでに勝てる場合は無駄遣い
	if can_win_without and survives_without:
		score -= 30.0
	
	return score
```

**このシンプルな評価だけで90%のケースは正しく判断できる**

---

## 先読み機能

### Level 1: 先読みなし（現在の状態だけ）

```gdscript
func should_invade_level1(my_creature: Dictionary, enemy_creature: Dictionary) -> bool:
	# 今の戦闘だけ見る
	return my_creature.ap > enemy_creature.hp
```

### Level 2: 1ターン先読み（相手の反撃を考える）

```gdscript
func should_invade_level2(my_creature: Dictionary, enemy_creature: Dictionary) -> bool:
	# 勝てるか？
	if my_creature.ap <= enemy_creature.hp:
		return false
	
	# 相手の反撃で生き残れるか？
	var my_hp_after = my_creature.hp - enemy_creature.ap
	if my_hp_after <= 0:
		return false  # 相打ちは避ける
	
	return true
```

### Level 3: 2ターン先読み（簡易版）

```gdscript
func evaluate_invasion_with_lookahead(my_creature: Dictionary, tile_index: int, game_state: Dictionary) -> float:
	var score = 0.0
	
	# 1. この戦闘に勝てるか？
	var battle_result = simulate_battle(my_creature, game_state.enemy_creature)
	if not battle_result.i_win:
		return -100.0  # 負けるなら大幅マイナス
	
	# 2. 勝った後、次のターン敵が侵略してきたら？
	if battle_result.i_survive:
		var my_hp_after = battle_result.my_remaining_hp
		
		# 敵の手札から最強クリーチャーを推測
		var estimated_enemy_best = estimate_enemy_strength(game_state)
		
		# そのクリーチャーで攻められたら耐えられる？
		if my_hp_after > estimated_enemy_best.ap:
			score += 30.0  # 耐えられるなら高評価
		else:
			score -= 20.0  # すぐやられるなら低評価
	
	return score

func estimate_enemy_strength(game_state: Dictionary) -> Dictionary:
	# 簡易版：敵の魔力から推測
	var enemy_magic = game_state.enemy_magic
	
	if enemy_magic >= 50:
		return {"ap": 40, "hp": 40}  # 強いの出せる
	elif enemy_magic >= 30:
		return {"ap": 30, "hp": 30}  # 中程度
	else:
		return {"ap": 20, "hp": 20}  # 弱い

func simulate_battle(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var attacker_hp = attacker.hp
	var defender_hp = defender.hp
	
	# 先制攻撃
	if has_first_strike(attacker):
		defender_hp -= attacker.ap
		if defender_hp <= 0:
			return {"i_win": true, "i_survive": true, "my_remaining_hp": attacker_hp}
	
	# 攻撃
	defender_hp -= attacker.ap
	attacker_hp -= defender.ap
	
	return {
		"i_win": defender_hp <= 0,
		"i_survive": attacker_hp > 0,
		"my_remaining_hp": attacker_hp
	}
```

---

## 難易度設定

### Level 1-3（初心者）

```json
{
  "difficulty": 1,
  "name": "とても簡単",
  "profile": {
	"aggression": 0.5,
	"resource_management": 0.3,
	"random_factor": 0.3
  },
  "features": {
	"basic_evaluation": true,
	"tempo_evaluation": false,
	"synergy_evaluation": false,
	"lookahead": 0
  }
}
```

**挙動**:
- コスパの良いクリーチャーを召喚
- 勝てそうなら侵略
- 30%の確率でランダムな選択

### Level 4-6（中級）

```json
{
  "difficulty": 5,
  "name": "普通",
  "profile": {
	"aggression": 0.7,
	"resource_management": 0.5,
	"random_factor": 0.1
  },
  "features": {
	"basic_evaluation": true,
	"tempo_evaluation": true,
	"synergy_evaluation": true,
	"lookahead": 1
  },
  "synergy_rules": [
	{"item_type": "weapon", "creature_keywords": ["先制"], "bonus": 30}
  ]
}
```

**挙動**:
- 魔力効率を考える
- 武器+先制などの基本コンボを理解
- 相手の反撃を1ターン先読み
- 10%の確率でランダムな選択

### Level 7-10（上級）

```json
{
  "difficulty": 8,
  "name": "難しい",
  "profile": {
	"aggression": 0.8,
	"resource_management": 0.7,
	"random_factor": 0.0
  },
  "features": {
	"basic_evaluation": true,
	"tempo_evaluation": true,
	"synergy_evaluation": true,
	"lookahead": 2,
	"predict_opponent": true
  },
  "synergy_rules": [
	{"item_type": "weapon", "creature_keywords": ["先制"], "bonus": 30},
	{"item_type": "armor", "creature_condition": "hp < 30", "bonus": 25},
	{"item_id": 1030, "bonus_multiplier": 1.3}
  ]
}
```

**挙動**:
- 魔力を温存しつつ効率的にプレイ
- 全てのシナジーを理解
- 2ターン先まで読む
- 相手の手札・魔力から戦略を推測
- ほぼランダム要素なし

---

## 実装ロードマップ

### Phase 1: 基礎AI（Level 1-3）

**推定時間**: 3-4時間

**実装内容**:
1. CPUThinking クラス作成
2. 基本評価関数実装
3. 行動選択ロジック
4. ランダム要素追加

**成果物**:
```gdscript
# scripts/ai/cpu_thinking_v1.gd
- evaluate_basic_value()
- choose_best_action()
- 簡単な判断（勝てる？コスパは？）
```

### Phase 2: シナジー評価（Level 4-6）

**推定時間**: 4-5時間

**実装内容**:
1. デッキプロファイル構造定義
2. シナジールール実装
3. カテゴリマッチング
4. 特殊アイテム処理

**成果物**:
```gdscript
- evaluate_synergy()
- matches_synergy_rule()
- 5-10個のシナジールール定義
```

### Phase 3: 先読み機能（Level 7-10）

**推定時間**: 5-8時間

**実装内容**:
1. 戦闘シミュレーション
2. 敵の強さ推測
3. リスク評価
4. 2ターン先読み

**成果物**:
```gdscript
- evaluate_future_turns()
- simulate_battle()
- estimate_enemy_strength()
```

### Phase 4: 調整・バランシング

**推定時間**: 3-5時間

**実装内容**:
1. 実際のプレイテスト
2. スコアの重み調整
3. 難易度バランス
4. バグ修正

---

## デバッグ・調整方法

### スコアのログ出力

```gdscript
func choose_best_action(actions: Array, game_state: Dictionary) -> Dictionary:
	print("\n=== AI思考開始 ===")
	print("難易度: Level ", difficulty_level)
	print("選択肢: ", actions.size(), "個")
	
	for action in actions:
		var score = evaluate_action(action, game_state)
		print("  - ", action.type, " (", action.get("name", ""), "): ", score)
	
	# ...
```

### 調整用パラメータファイル

```json
// data/ai_tuning.json
{
  "weights": {
	"creature_ap": 1.0,
	"creature_hp": 0.5,
	"cost_penalty": 0.3,
	"win_bonus": 100.0,
	"survive_bonus": 80.0,
	"synergy_bonus": 30.0
  }
}
```

実行時に読み込んで調整可能にする。

---

## 注意事項

### 完璧を目指さない
- 人間のような判断ミスも面白さの一部
- 100%最適解は不要（計算量も膨大）
- 適度な強さを目指す

### データ駆動にする
- ハードコードを避ける
- JSONで調整可能に
- デバッグログを充実させる

### 段階的に実装
- いきなり高度なAIは作らない
- Phase 1 → 2 → 3 と確実に
- 各Phaseでテストプレイ

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2025/11/10 | 初版作成：CPU AI実装設計 |

---
