# バフスキル実装に必要な新機能一覧

**作成日**: 2025年10月26日  
**目的**: 条件付きバフスキル実装に必要な、現在未実装の機能を整理

---

## 🔴 最優先で実装が必要な機能

### 1. ターン数カウンター

**必要なクリーチャー**:
- ID 47: ラーバキン - ST=現R数、HP+現R数

**実装場所**: `scripts/game_flow_manager.gd`

**実装内容**:
```gdscript
class_name GameFlowManager

# 追加
var current_turn: int = 0  # ゲーム開始からの経過ターン数

func start_turn():
	current_turn += 1
	var current_player = player_system.get_current_player()
	emit_signal("turn_started", current_player.id)
	print("=== ターン ", current_turn, " 開始（プレイヤー ", current_player.id, "）===")
	# ... 既存処理
```

**取得方法**:
```gdscript
# BattleSkillProcessor から取得
var current_turn = game_flow_manager.current_turn
participant.base_ap = current_turn
participant.temporary_bonus_hp += current_turn
```

---

### 2. 周回完了シグナル

**必要なクリーチャー**:
- ID 7: キメラ - 周回ごとにST+10
- ID 240: モスタイタン - 周回ごとにMHP+10（80で30にリセット）

**実装場所**: `scripts/game_flow_manager.gd`

**実装内容**:
```gdscript
class_name GameFlowManager

# 追加
signal lap_completed(player_id: int)

# ダイス後の移動処理で周回判定
func on_player_moved(player_id: int, old_tile: int, new_tile: int):
	# ゴール（タイル0）を通過したかチェック
	if old_tile > new_tile or (old_tile < 40 and new_tile == 0):
		print("プレイヤー ", player_id, " が1周完了！")
		_on_lap_completed(player_id)

func _on_lap_completed(player_id: int):
	# 全自クリーチャーに周回ボーナスを適用
	if board_system_3d:
		var player_tiles = board_system_3d.get_player_tiles(player_id)
		for tile in player_tiles:
			if tile.creature_data:
				_apply_lap_bonus(tile.creature_data)
	
	lap_completed.emit(player_id)

func _apply_lap_bonus(creature_data: Dictionary):
	var effects = creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "per_lap_permanent_bonus":
			var stat = effect.get("stat", "ap")
			var value = effect.get("value", 10)
			
			# 周回カウント増加
			creature_data["map_lap_count"] = creature_data.get("map_lap_count", 0) + 1
			
			if stat == "ap":
				creature_data["base_up_ap"] = creature_data.get("base_up_ap", 0) + value
			elif stat == "max_hp":
				creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + value
				
				# モスタイタンのリセットチェック
				if effect.has("reset_condition"):
					var total_mhp = creature_data["hp"] + creature_data["base_up_hp"]
					var reset_cond = effect["reset_condition"]["max_hp_check"]
					
					if total_mhp >= reset_cond["value"]:
						creature_data["base_up_hp"] = 0
						print("モスタイタンのMHPをリセット: ", creature_data["name"])
```

**必要な周回判定ロジック**:
- ゴール（タイル0）を通過した時に発火
- 移動前後のタイル位置で判定

---

### 3. 土地レベルアップ/地形変化イベント

**必要なクリーチャー**:
- ID 200: アースズピリット - レベルアップ/地形変化時MHP+10
- ID 328: デュータイタン - レベルアップ/地形変化時MHP-10

**実装場所**: `scripts/board_system_3d.gd`

**実装内容**:
```gdscript
class_name BoardSystem3D

# 追加
signal land_level_changed(tile_index: int, old_level: int, new_level: int)
signal land_element_changed(tile_index: int, old_element: String, new_element: String)

# レベルアップ処理
func level_up_land(tile_index: int):
	var tile = tiles[tile_index]
	var old_level = tile.level
	
	if tile.level < 5:
		tile.level += 1
		print("土地レベルアップ: ", tile_index, " Lv", old_level, " → Lv", tile.level)
		
		# イベント発火
		land_level_changed.emit(tile_index, old_level, tile.level)
		
		# 配置クリーチャーに効果適用
		_apply_land_change_effects(tile_index, "level_up")

# 地形変化処理（スペル、クリーチャー配置など）
func change_land_element(tile_index: int, new_element: String):
	var tile = tiles[tile_index]
	var old_element = tile.element
	
	if old_element != new_element:
		tile.element = new_element
		print("地形変化: ", tile_index, " ", old_element, " → ", new_element)
		
		# イベント発火
		land_element_changed.emit(tile_index, old_element, new_element)
		
		# 配置クリーチャーに効果適用
		_apply_land_change_effects(tile_index, "terrain_change")

func _apply_land_change_effects(tile_index: int, trigger_type: String):
	var tile = tiles[tile_index]
	
	if not tile.creature_data:
		return
	
	var effects = tile.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "on_land_change":
			var trigger = effect.get("trigger", "")
			
			# トリガーが一致するかチェック
			if trigger == trigger_type or trigger == "any":
				var stat_change = effect.get("stat_change", {})
				
				for stat in stat_change:
					var value = stat_change[stat]
					if stat == "max_hp":
						tile.creature_data["base_up_hp"] = tile.creature_data.get("base_up_hp", 0) + value
						print("土地変化効果: ", tile.creature_data["name"], " MHP", 
							  ("+" if value > 0 else ""), value)
```

**呼び出しタイミング**:
- 領地コマンドの「レベルアップ」選択時
- スペルでの属性変化時
- クリーチャー配置時の属性変化

---

### 4. クリーチャー破壊カウンター（グローバル）

**必要なクリーチャー**:
- ID 323: ソウルコレクター - ST+クリーチャー破壊数×5
- ID 35: バルキリー - 敵破壊時ST+10（永続）
- ID 227: ダスクドウェラー - 敵破壊時ST&MHP+10（永続）
- ID 34: バイロマンサー - 敵攻撃成功後（永続、1回のみ）

**実装場所**: `scripts/game_data.gd` (グローバルシングルトン)

**実装内容**:
```gdscript
# scripts/game_data.gd の player_data.stats に追加
"stats": {
	"total_battles": 0,
	"wins": 0,
	"losses": 0,
	"play_time_seconds": 0,
	"story_cleared": 0,
	"gacha_count": 0,
	"cards_obtained": 0,
	"total_creatures_destroyed": 0  # 追加！
}

# メソッド追加
func increment_destroy_count():
	player_data.stats.total_creatures_destroyed += 1
	print("クリーチャー破壊数: ", player_data.stats.total_creatures_destroyed)

func get_destroy_count() -> int:
	return player_data.stats.total_creatures_destroyed

# ゲーム開始時にリセット（1ゲームごとの累計）
func reset_destroy_count_for_game():
	player_data.stats.total_creatures_destroyed = 0
```

**重要**: GameDataシングルトンは既にプロジェクトで使用されているグローバルデータ管理システムです。


**BattleSystem での実装**:
```gdscript
# scripts/battle/battle_system.gd

signal creature_destroyed(attacker_player_id: int, defender_tile_index: int)

func on_battle_complete(result: Dictionary):
	# ... 既存処理 ...
	
	if result.winner == "attacker":
		# 破壊カウント増加（GameDataシングルトンを使用）
		GameData.increment_destroy_count()
		
		# 永続バフ適用
		var attacker_tile = board_system.tiles[attacker_tile_index]
		_apply_on_destroy_permanent_effects(attacker_tile)
		
		# シグナル発火
		creature_destroyed.emit(attacker.player_id, defender_tile_index)
	
	# バイロマンサーの処理
	if result.winner == "defender":
		var defender_tile = board_system.tiles[defender_tile_index]
		_apply_on_enemy_attack_success(defender_tile)

func _apply_on_destroy_permanent_effects(attacker_tile):
	if not attacker_tile.creature_data:
		return
	
	var effects = attacker_tile.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "on_enemy_destroy_permanent":
			var stat_changes = effect.get("stat_changes", {})
			
			for stat in stat_changes:
				var value = stat_changes[stat]
				if stat == "ap":
					attacker_tile.creature_data["base_up_ap"] = \
						attacker_tile.creature_data.get("base_up_ap", 0) + value
				elif stat == "max_hp":
					attacker_tile.creature_data["base_up_hp"] = \
						attacker_tile.creature_data.get("base_up_hp", 0) + value
			
			print("敵破壊時永続バフ: ", attacker_tile.creature_data["name"], " ", stat_changes)

func _apply_on_enemy_attack_success(defender_tile):
	if not defender_tile.creature_data:
		return
	
	# バイロマンサー専用（1回のみ）
	if defender_tile.creature_data.get("bairomancer_triggered", false):
		return
	
	var effects = defender_tile.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "after_battle_change":
			var trigger = effect.get("trigger", "any")
			
			if trigger == "enemy_attack_success":
				defender_tile.creature_data["base_ap"] = effect.get("stat_changes", {}).get("ap", 20)
				defender_tile.creature_data["base_up_hp"] = \
					defender_tile.creature_data.get("base_up_hp", 0) + \
					effect.get("stat_changes", {}).get("max_hp", -30)
				
				defender_tile.creature_data["bairomancer_triggered"] = true
				print("バイロマンサー効果発動: ST=20, MHP-30")
```

**BattleSkillProcessor での使用**:
```gdscript
# scripts/battle/battle_skill_processor.gd

func apply_destroy_count_effects(participant: BattleParticipant, context: Dictionary):
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "destroy_count_multiplier":
			var stat = effect.get("stat", "ap")
			var multiplier = effect.get("multiplier", 5)
			var destroy_count = GameData.get_destroy_count()
			
			if stat == "ap":
				participant.temporary_bonus_ap += destroy_count * multiplier
				print("破壊数カウント効果: +", destroy_count * multiplier, " ST")
```

---

## ✅ 実装済み・実装可能な機能

### 5. 手札数取得（リリス用）

**実装場所**: `scripts/battle/battle_skill_processor.gd`

**実装内容**:
```gdscript
func apply_hand_count_effects(participant: BattleParticipant, player_id: int):
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "hand_count_multiplier":
			var stat = effect.get("stat", "ap")
			var multiplier = effect.get("multiplier", 10)
			var operation = effect.get("operation", "set")
			
			# CardSystemから手札数を取得
			var hand_count = 0
			if card_system and card_system.player_hands.has(player_id):
				hand_count = card_system.player_hands[player_id]["data"].size()
			
			var value = hand_count * multiplier
			
			if operation == "set":
				if stat == "ap":
					participant.base_ap = value
			elif operation == "add":
				if stat == "ap":
					participant.temporary_bonus_ap += value
			
			print("手札数効果: 手札", hand_count, "枚 → ST ", 
				  ("=" if operation == "set" else "+"), value)
```

---

### 6. デッキ枚数比較（コアトリクエ用）

**実装場所**: `scripts/battle/battle_skill_processor.gd`

**実装内容**:
```gdscript
func apply_deck_comparison_effects(participant: BattleParticipant, player_id: int, enemy_id: int):
	var effects = participant.creature_data.get("ability_parsed", {}).get("effects", [])
	
	for effect in effects:
		if effect.get("effect_type") == "deck_comparison_bonus":
			var comparison = effect.get("comparison", "greater_than_opponent")
			var stat_changes = effect.get("stat_changes", {})
			
			# CardSystemからデッキ枚数を取得
			var player_deck_count = card_system.deck.size() if card_system else 0
			# TODO: 敵プレイヤーのデッキ枚数取得方法を確認
			# 現状はプレイヤー全員が同じデッキを共有しているため未対応
			
			var condition_met = false
			if comparison == "greater_than_opponent":
				# TODO: 実装（敵のデッキ枚数と比較）
				pass
			
			if condition_met:
				for stat in stat_changes:
					var value = stat_changes[stat]
					if stat == "ap":
						participant.temporary_bonus_ap += value
					elif stat == "hp":
						participant.temporary_bonus_hp += value
				
				print("デッキ比較効果: ", stat_changes)
```

**注意**: 現在のCardSystemは全プレイヤーが同じデッキを共有しているため、プレイヤーごとのデッキ管理が必要

---

## 🟢 実装不要な機能

### 7. オーガ配置判定（オーガロード用）

**対象**: ID 407 オーガロード

**理由**: ユーザーから「オーガはいらんけど」との指示あり

---

## 🟡 後回し機能

### 8. 秘術システム

**対象**:
- ID 23: ドゥームデボラー - 秘術使用後ST&MHP-10
- その他多数の秘術持ちクリーチャー

**理由**: 秘術システム全体の設計・実装が必要（大規模）

---

## 実装優先順位

1. **ターン数カウンター**（必須、簡単）
2. **手札数取得**（必須、実装済みCardSystemを使うだけ）
3. **クリーチャー破壊カウンター**（必須、中程度）
4. **周回完了シグナル**（必須、やや複雑）
5. **土地レベルアップ/地形変化イベント**（必須、やや複雑）
6. **デッキ枚数比較**（低優先度、CardSystem改修必要）

---

**最終更新**: 2025年10月26日
