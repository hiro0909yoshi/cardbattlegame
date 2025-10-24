# 🎮 スキルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.8  
**最終更新**: 2025年10月24日

---

## 📋 目次

1. [スキルシステム概要](#スキルシステム概要)
2. [実装済みスキル一覧](#実装済みスキル一覧)
3. [個別スキル仕様書へのリンク](#スキル詳細仕様) ⭐NEW
4. [スキル適用順序](#スキル適用順序)
5. [BattleParticipantとHP管理](#battleparticipantとhp管理)
6. [スキル条件システム](#スキル条件システム)
7. [将来実装予定のスキル](#将来実装予定のスキル)

---

## スキルシステム概要

### アーキテクチャ

```
SkillSystem (マネージャー)
  ├── ConditionChecker (条件判定)
  │   ├── build_battle_context()
  │   ├── evaluate_conditions()
  │   └── 各種条件評価メソッド
  │
  └── EffectCombat (効果適用)
	  ├── apply_power_strike()
	  ├── apply_first_strike()
	  └── その他効果メソッド
```

### スキル定義構造

```json
{
  "ability_parsed": {
	"keywords": ["感応", "先制"],
	"keyword_conditions": {
	  "感応": {
		"element": "fire",
		"stat_bonus": {
		  "ap": 30,
		  "hp": 0
		}
	  }
	},
	"effects": [
	  {
		"effect_type": "power_strike",
		"multiplier": 1.5,
		"conditions": [
		  {"condition_type": "adjacent_ally_land"}
		]
	  }
	]
  }
}
```

### バトルでのスキル適用フロー

```
1. BattleParticipant作成
   ├─ 基本ステータス設定
   └─ 先制判定

2. ability_parsedを解析
   ├─ keywords配列チェック
   └─ keyword_conditions取得

3. ConditionCheckerで条件判定
   ├─ バトルコンテキスト構築
   ├─ プレイヤー土地情報取得
   └─ 各条件を評価

4. EffectCombatで効果適用
   ├─ 感応スキル適用
   ├─ 強打スキル適用
   └─ その他スキル適用

5. 修正後のAP/HPでバトル実行
```

---

## 実装済みスキル一覧

| スキル名 | タイプ | 効果 | 実装状況 |
|---------|--------|------|---------|
| 感応 | パッシブ | 特定属性の土地所有でAP/HP上昇 | ✅ 完全実装 |
| 応援 | パッシブ | 盤面のクリーチャーにバフ付与 | ✅ 完全実装 |
| 貫通 | パッシブ | 防御側の土地ボーナス無効化 | ✅ 完全実装 |
| 強打 | パッシブ | 条件下でAP増幅 | ✅ 完全実装 |
| 先制 | パッシブ | 先攻権獲得 | ✅ 完全実装 |
| 後手 | パッシブ | 相手が先攻 | ✅ 完全実装 |
| 再生 | パッシブ | バトル後にHP全回復 | ✅ 完全実装 |
| 土地数比例 | パッシブ | 土地数×倍率でAP/HP上昇 | ✅ 完全実装 |
| 不屈 | パッシブ | アクション後もダウンしない | ✅ 完全実装 |
| 2回攻撃 | パッシブ | 1回のバトルで2回攻撃 | ✅ 完全実装 |
| 即死 | アクティブ | 確率で相手を即死 | ✅ 完全実装 |
| 防魔 | パッシブ | スペル無効化 | 🔶 部分実装 |
| ST変動 | パッシブ | 土地数でAP変動 | ✅ 完全実装 |
| HP変動 | パッシブ | 土地数でHP変動 | 🔶 部分実装 |
| 無効化 | パッシブ | 特定攻撃/属性の無効化 | ✅ 完全実装 |
| 巻物攻撃 | パッシブ | 巻物使用時の特殊攻撃 | ✅ 完全実装 |
| 反射 | リアクティブ | 受けたダメージを攻撃者に返す | ✅ 完全実装 |
| 反射無効 | パッシブ | 相手の反射を無効化 | ✅ 完全実装 |
| 援護 | アイテムフェーズ | 手札クリーチャーをAP/HP加算に使用 | ✅ 完全実装 |
| 変身 | アクティブ | 自身または相手を別のクリーチャーに変身 | ✅ 完全実装 |
| 死者復活 | リアクティブ | 撃破時に別のクリーチャーとして復活 | ✅ 完全実装 |
| アイテム破壊 | バトル前 | 相手のアイテムを破壊 | ✅ 完全実装 |
| アイテム盗み | バトル前 | 相手のアイテムを奪う | ✅ 完全実装 |

---

## スキル詳細仕様

このセクションでは各スキルの概要のみを記載します。  
**詳細な仕様については、各スキルの個別ドキュメントを参照してください。**

### 個別スキル仕様書へのリンク

#### 実装済みスキル（15ファイル）

1. **[応援スキル](skills/assist_skill.md)** ✅ 完全実装
   - 盤面のクリーチャーがバトル参加者にバフを付与

2. **[感応スキル](skills/resonance_skill.md)** ✅ 完全実装
   - 特定属性の土地所有でAP/HP上昇

3. **[貫通スキル](skills/penetration_skill.md)** ✅ 完全実装
   - 防御側の土地ボーナスHP無効化

4. **[強打スキル](skills/power_strike_skill.md)** ✅ 完全実装
   - 条件下でAP増幅（1.5倍）

5. **[先制スキル](skills/first_strike_skill.md)** ✅ 完全実装
   - 先攻権獲得

6. **[再生スキル](skills/regeneration_skill.md)** ✅ 完全実装
   - バトル後にHP全回復

7. **[不屈スキル](skills/indomitable_skill.md)** ✅ 完全実装
   - アクション後もダウンしない

8. **[2回攻撃スキル](skills/double_attack_skill.md)** ✅ 完全実装
   - 1回のバトルで2回攻撃

9. **[即死スキル](skills/instant_death_skill.md)** ✅ 完全実装
   - 確率で相手を即死

10. **[無効化スキル](skills/nullify_skill.md)** ✅ 完全実装
	- 特定攻撃/属性の無効化

11. **[巻物攻撃スキル](skills/scroll_attack_skill.md)** ✅ 完全実装
	- 巻物使用時の特殊攻撃

12. **[反射スキル](skills/reflect_skill.md)** ✅ 完全実装
	- 受けたダメージを攻撃者に返す

13. **[援護スキル](skills/support_skill.md)** ✅ 完全実装
	- 手札クリーチャーをAP/HP加算に使用

14. **[変身スキル](skills/transform_skill.md)** ✅ 完全実装
	- 特定のタイミングで自身または相手を別のクリーチャーに変身させる

15. **[死者復活スキル](skills/revive_skill.md)** ✅ 完全実装
	- 撃破時に別のクリーチャーとして復活し、タイルを維持

16. **[アイテム破壊・盗みスキル](skills/item_destruction_theft_skill.md)** ✅ 完全実装
	- 戦闘開始前に相手のアイテムを破壊または奪う

#### その他のスキル

以下のスキルは個別ファイルが未作成です（このファイル内に記載）：

- **後手スキル** - 相手が先攻（セクション8）
- **防魔スキル** - スペル無効化（セクション9）
- **ST変動スキル** - 土地数でAP変動（セクション8）
- **土地数比例スキル** - 土地数×倍率でAP/HP上昇（セクション7）
- **HP変動スキル** - 土地数でHP変動（部分実装）

---

## スキル適用順序

バトル前のスキル適用は以下の順序で実行される:

```
1. 応援スキル適用 (apply_support_skills_to_all) ✨NEW
   ├─ 盤面の応援持ちクリーチャーを取得
   ├─ 条件を満たすバトル参加者にバフ付与
   └─ 動的ボーナス（隣接自領地数）を計算
   
2. 巻物攻撃判定 (check_scroll_attack)
3. 感応スキル (apply_resonance_skill)
4. 土地数比例効果 (apply_land_count_effects)
   ├─ プレイヤーの土地所有状況を確認
   ├─ 条件を満たせばAPとHPを上昇
   └─ resonance_bonus_hpフィールドに加算
   
5. 強打スキル (apply_power_strike)
   ├─ 感応適用後のAPを基準に計算
   ├─ 条件を満たせばAPを増幅
   └─ 例: 基本20 → 感応+30=50 → 強打×1.5=75
   
6. 2回攻撃判定 (_check_double_attack)
   ├─ 2回攻撃スキル保持チェック
   └─ attack_count = 2 に設定
   
7. 攻撃シーケンス (_execute_attack_sequence)
   ├─ 攻撃順決定（先制・後手判定）
   ├─ 各攻撃ごとにダメージ適用
   └─ **攻撃後に即死判定** (_check_instant_death)
	  ├─ 即死スキル保持チェック
	  ├─ 条件判定（属性、ST、立場など）
	  ├─ 確率判定
	  └─ 成功時: instant_death_flag = true, HP = 0
   
8. バトル結果判定 (_resolve_battle_result)
   ├─ HPチェック
   └─ 勝敗決定
   
9. バトル後処理 (_apply_post_battle_effects)
   ├─ 再生スキル適用（生存者のみ）
   │  └─ HP > 0 の場合のみ発動
   ├─ 土地奪取 or カード破壊 or 手札復帰
   └─ クリーチャーHP更新

**注**: 不屈スキルはバトル処理とは独立して動作し、アクション後のダウン判定時に適用される。バトルフロー内では関与しない。
```

### 設計思想

この順序により、複数スキルを持つクリーチャーは相乗効果を得られる。

**例: 感応+強打の組み合わせ**
```
モルモ（感応[火]+30、強打×1.5を仮定）

基本AP: 20
  ↓ 感応発動（火土地1個所有）
AP: 50 (+30)
  ↓ 強打発動（隣接自領地あり）
AP: 75 (×1.5)

→ 最終的にAP: 75で攻撃！
```

### 実装コード

```gdscript
func _apply_skills(participant: BattleParticipant, context: Dictionary) -> void:
	var effect_combat = load("res://scripts/skills/effect_combat.gd").new()
	
	# 1. 感応スキル適用
	_apply_resonance_skill(participant, context)
	
	# 2. 強打スキル適用（感応適用後のAPを基準）
	var modified_creature_data = participant.creature_data.duplicate()
	modified_creature_data["ap"] = participant.current_ap  # 感応後のAP
	var modified = effect_combat.apply_power_strike(modified_creature_data, context)
	participant.current_ap = modified.get("ap", participant.current_ap)
	
	# 3. その他スキル（将来実装）
```

---

## BattleParticipantとHP管理

### BattleParticipantクラス

**役割**: バトル参加者のステータスとHP管理を担当

**実装場所**: `scripts/battle_participant.gd`

### HPの階層構造

```gdscript
{
  base_hp: int              # クリーチャーの基本HP（最後に消費）
  resonance_bonus_hp: int   # 感応ボーナス（優先消費）
  land_bonus_hp: int        # 土地ボーナス（2番目に消費）
  item_bonus_hp: int        # アイテムボーナス（将来実装）
  spell_bonus_hp: int       # スペルボーナス（将来実装）
  current_hp: int           # 表示HP（全ての合計）
}
```

### ダメージ消費順序

1. **感応ボーナス** (`resonance_bonus_hp`) - 最優先で消費
2. **土地ボーナス** (`land_bonus_hp`) - 戦闘ごとに復活
3. **アイテムボーナス** (`item_bonus_hp`) - 将来実装
4. **スペルボーナス** (`spell_bonus_hp`) - 将来実装
5. **基本HP** (`base_hp`) - 最後に消費

### 設計思想

- **一時的なボーナスを先に消費**し、クリーチャーの本来のHPを守る
- **感応ボーナス**: 最も一時的（バトル限定）なため、最優先消費
- **土地ボーナス**: 戦闘ごとに復活するため、次に消費
- **基本HP**: 減ると配置クリーチャーの永続的なダメージとなる

### ダメージ処理の実装

```gdscript
func take_damage(damage: int) -> Dictionary:
	var remaining_damage = damage
	var damage_breakdown = {
		"resonance_bonus_consumed": 0,
		"land_bonus_consumed": 0,
		"item_bonus_consumed": 0,
		"spell_bonus_consumed": 0,
		"base_hp_consumed": 0
	}
	
	# 1. 感応ボーナスから消費
	if resonance_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(resonance_bonus_hp, remaining_damage)
		resonance_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["resonance_bonus_consumed"] = consumed
	
	# 2. 土地ボーナスから消費
	if land_bonus_hp > 0 and remaining_damage > 0:
		var consumed = min(land_bonus_hp, remaining_damage)
		land_bonus_hp -= consumed
		remaining_damage -= consumed
		damage_breakdown["land_bonus_consumed"] = consumed
	
	# 3. アイテムボーナス（将来実装）
	# 4. スペルボーナス（将来実装）
	
	# 5. 基本HPから消費
	if remaining_damage > 0:
		base_hp -= remaining_damage
		damage_breakdown["base_hp_consumed"] = remaining_damage
	
	# 現在HPを更新
	update_current_hp()
	
	return damage_breakdown
```

### バトルフロー内での使用

```gdscript
# 1. 参加者作成
var attacker = BattleParticipant.new(
	card_data,      # クリーチャーデータ
	base_hp,        # 基本HP
	land_bonus,     # 土地ボーナスHP
	ap,             # 攻撃力
	true,           # is_attacker
	player_id       # プレイヤーID
)

# 2. スキル適用
attacker.resonance_bonus_hp += 30  # 感応ボーナス追加
attacker.update_current_hp()       # 合計HP再計算

# 3. ダメージ処理
var breakdown = attacker.take_damage(50)
# → 感応(30) → 土地(20) → 基本HP(0) の順で消費

# 4. 結果表示
print("  - 感応ボーナス: ", breakdown["resonance_bonus_consumed"], " 消費")
print("  - 土地ボーナス: ", breakdown["land_bonus_consumed"], " 消費")
print("  - 基本HP: ", breakdown["base_hp_consumed"], " 消費")
print("  → 残HP: ", attacker.current_hp)
```

### 主要メソッド

```gdscript
# 合計HPを再計算
func update_current_hp():
	current_hp = base_hp + resonance_bonus_hp + land_bonus_hp + 
				 item_bonus_hp + spell_bonus_hp

# ダメージ処理（消費順序に従う）
func take_damage(damage: int) -> Dictionary

# 生存判定
func is_alive() -> bool:
	return current_hp > 0

# デバッグ用ステータス表示
func get_status_string() -> String:
	return "%s (HP:%d/%d, AP:%d)" % [
		creature_data.get("name", "不明"),
		current_hp,
		base_hp + land_bonus_hp + item_bonus_hp + spell_bonus_hp,
		current_ap
	]
```

---

## スキル条件システム

### 実装済み条件一覧

| 条件タイプ | 説明 | 使用例 |
|-----------|------|--------|
| `on_element_land` | 特定属性の土地 | 火土地で強打 |
| `has_item_type` | アイテム装備 | 武器装備時強打 |
| `land_level_check` | 土地レベル判定 | レベル3以上で強打 |
| `element_land_count` | 属性土地数 | 火土地3個以上で強打 |
| `adjacent_ally_land` | 隣接自領地判定 | 隣接に自土地あり |
| `enemy_is_element` | 敵属性判定 | 敵が水属性で貫通 |
| `attacker_st_check` | 攻撃力判定 | ST40以上で貫通 |

### adjacent_ally_land条件（詳細）

#### 定義
バトル発生タイルの物理的な隣接タイルに、攻撃プレイヤーの領地が存在するか判定。

#### 評価フロー

```
1. BattleSystem
   ├─ battle_tile_index (バトル発生タイル)
   ├─ player_id (攻撃プレイヤー)
   └─ board_system参照

2. ConditionChecker
   └─ adjacent_ally_land条件を検出

3. TileNeighborSystem
   ├─ get_spatial_neighbors(battle_tile)
   │  └─ 物理座標ベースで隣接タイル取得
   ├─ 各隣接タイルのownerをチェック
   └─ 自領地があれば true

4. 効果発動
   └─ 強打等のスキルが発動
```

#### 実装コード

```gdscript
# ConditionChecker
func evaluate_condition(condition: Dictionary, context: Dictionary) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"adjacent_ally_land":
			var board_system = context.get("board_system")
			var player_id = context.get("player_id", -1)
			var battle_tile = context.get("battle_tile_index", -1)
			
			if not board_system or player_id < 0 or battle_tile < 0:
				return false
			
			return board_system.tile_neighbor_system.has_adjacent_ally_land(
				battle_tile, player_id, board_system
			)
```

#### 使用例（ローンビースト）

```json
{
  "id": 49,
  "name": "ローンビースト",
  "ability_parsed": {
	"effects": [{
	  "effect_type": "power_strike",
	  "multiplier": 1.5,
	  "conditions": [
		{"condition_type": "adjacent_ally_land"}
	  ]
	}]
  }
}
```

**説明**: バトル発生タイルの隣接に自分の土地があれば、AP×1.5で攻撃。

---

## 🆕 アイテムシステム（Phase 1-A）

### 概要

バトル前にアイテムカードを使用して、クリーチャーを強化できるシステム。

### アイテムフェーズのフロー

```
バトルカード選択
  ↓
バトルカード消費（手札から削除）
  ↓
攻撃側アイテムフェーズ
  ├─ 攻撃側の手札を表示
  ├─ アイテムカード以外はグレーアウト
  ├─ アイテム選択 or パス
  └─ 効果を保存
  ↓
防御側アイテムフェーズ
  ├─ 防御側の手札を表示（正しいプレイヤーIDで取得）
  ├─ アイテムカード以外はグレーアウト
  ├─ アイテム選択 or パス
  └─ 効果を保存
  ↓
バトル開始
  ├─ 両者のアイテム効果を適用
  └─ 通常のバトル処理
```

### アイテム効果タイプ

#### 1. buff_ap - AP増加

```json
{
  "effect_type": "buff_ap",
  "value": 30
}
```

**効果**: `participant.current_ap += value`

**例**: ロングソード (ID: 1072) - AP+30

#### 2. buff_hp - HP増加

```json
{
  "effect_type": "buff_hp",
  "value": 20
}
```

**効果**: `participant.item_bonus_hp += value`

**HP消費順序**:
1. 感応ボーナス (`resonance_bonus_hp`)
2. 土地ボーナス (`land_bonus_hp`)
3. **アイテムボーナス** (`item_bonus_hp`)
4. スペルボーナス (`spell_bonus_hp`)
5. 基本HP (`base_hp`)

#### 3. grant_skill - スキル付与

```json
{
  "effect_type": "grant_skill",
  "skill": "強打",
  "condition": {
	"condition_type": "user_element",
	"elements": ["fire"]
  }
}
```

**付与可能スキル**:
- 先制
- 後手
- 強打

**付与条件タイプ**:
- `user_element`: 使用者（クリーチャー）の属性チェック
  - 火属性のクリーチャーが使用した場合のみ付与
  - その他の属性ではスキップ

**発動条件**:
- アイテムで付与されたスキルは**無条件で発動**
- バトル時の条件チェックなし（`conditions: []`）

### 実装クラス

#### ItemPhaseHandler
アイテムフェーズの状態管理とUI制御。

**主要メソッド**:
```gdscript
func start_item_phase(player_id: int)
func use_item(item_card: Dictionary)
func pass_item()
func complete_item_phase()
```

**状態遷移**:
```
INACTIVE
  ↓ start_item_phase()
WAITING_FOR_SELECTION
  ↓ use_item() / pass_item()
ITEM_APPLIED
  ↓ complete_item_phase()
INACTIVE
```

#### BattleSystem アイテム効果適用

**主要メソッド**:
```gdscript
func _apply_item_effects(participant: BattleParticipant, item_data: Dictionary)
func _grant_skill_to_participant(participant: BattleParticipant, skill_name: String, skill_data: Dictionary)
func _check_skill_grant_condition(participant: BattleParticipant, condition: Dictionary) -> bool
```

**適用タイミング**:
```
execute_3d_battle_with_data()
  ↓
_apply_item_effects(attacker, attacker_item)
_apply_item_effects(defender, defender_item)
  ↓
_apply_skills(attacker)
_apply_skills(defender)
  ↓
バトル実行
```

### UI統合

#### CardSelectionUI フィルター機能

**フィルターモード**:
- `"spell"`: スペルカードのみ選択可能
- `"item"`: アイテムカードのみ選択可能
- `"discard"`: すべてのカードタイプ選択可能
- `""`（空文字）: クリーチャーカードのみ選択可能

**グレーアウト処理**:
```gdscript
// HandDisplay.create_card_node()
if filter_mode == "item":
	if not is_item_card:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
```

#### GameFlowManager プレイヤーID参照

**アイテムフェーズ中の特別処理**:
```gdscript
func on_card_selected(card_index: int):
	var target_player_id = player_system.get_current_player().id
	
	// アイテムフェーズ中は ItemPhaseHandler.current_player_id を使用
	if item_phase_handler and item_phase_handler.is_item_phase_active():
		target_player_id = item_phase_handler.current_player_id
	
	var hand = card_system.get_all_cards_for_player(target_player_id)
```

**理由**:
- 防御側のアイテムフェーズでは、防御側の手札を表示する必要がある
- `get_current_player()`は常に攻撃側を返すため、明示的に`current_player_id`を使用

### テストアイテム

#### ロングソード (ID: 1072)
```json
{
  "cost": {"mp": 10},
  "effect": "ST+30",
  "ability_parsed": {
	"effects": [
	  {"effect_type": "buff_ap", "value": 30}
	]
  }
}
```

#### マグマハンマー (ID: 1062)
```json
{
  "cost": {"mp": 20},
  "effect": "ST+20；💧🌱使用時、強打",
  "ability_parsed": {
	"effects": [
	  {"effect_type": "buff_ap", "value": 20},
	  {
		"effect_type": "grant_skill",
		"skill": "強打",
		"condition": {
		  "condition_type": "user_element",
		  "elements": ["fire"]
		}
	  }
	]
  }
}
```

---

### 10. 無効化スキル

#### 概要
特定の攻撃タイプや属性からのダメージを完全に無効化するパッシブスキル。

#### 実装状況
✅ **完全実装**（2025年10月）

#### 詳細仕様
無効化スキルの詳細は別ドキュメントを参照してください。
- **設計書**: [`docs/design/skills/nullify_skill.md`](skills/nullify_skill.md)

#### 主な無効化タイプ
- 属性無効化（火、水、地、風、無属性）
- 通常攻撃無効化
- 巻物攻撃無効化
- 条件付き無効化（ST値、MHP値、装備アイテム、土地レベル）

---

### 11. 巻物攻撃スキル

#### 概要
巻物アイテムを使用した場合に発動する特殊攻撃スキル。

#### 実装状況
✅ **完全実装**（2025年10月）

#### 主な効果
- 巻物攻撃：土地ボーナスHP無視
- 巻物強打：巻物攻撃 + 1.5倍ダメージ + 感応ボーナス適用

#### 詳細仕様
巻物攻撃の詳細は無効化スキル仕様書を参照：
- **仕様書**: `docs/implementation/nullification_system.md`

---

## 8. アイテム破壊・盗みスキル

#### 概要
戦闘開始前に相手のアイテムを破壊または奪うスキル。アイテムに依存する戦略を無効化できる強力な妨害スキル。

#### 実装状況
❌ **未実装**

#### 主なスキル
- **アイテム破壊**: 相手のアイテムを破壊（消滅）
- **アイテム盗み**: 相手のアイテムを奪って自分が使用
- **アイテム破壊・盗み無効**: 相手の破壊・盗みを無効化

#### 詳細仕様
アイテム破壊・盗みの詳細は専用ドキュメントを参照：
- **仕様書**: [`docs/design/skills/item_destruction_theft_skill.md`](skills/item_destruction_theft_skill.md)

---

## 8. 援護スキル ✅ 完全実装

### 概要
アイテムフェーズ時に、**手札のクリーチャーカードをアイテムのように使用**して、バトル参加クリーチャーのAP/HPを加算できるスキル。

### 発動条件
- バトル参加クリーチャーが援護スキルを持っている
- アイテムフェーズ時に手札に対象クリーチャーがある
- 使用クリーチャーのコスト分の魔力を消費

### 効果
1. **AP加算**: 援護クリーチャーのAPをバトル参加クリーチャーに加算
2. **HP加算**: 援護クリーチャーのHPをバトル参加クリーチャーに加算
3. **スキル非継承**: 援護クリーチャーのスキルは継承されない
4. **カード消費**: 使用した援護クリーチャーは捨て札に

### 援護対象属性

援護スキルには対象属性が指定されており、その属性のクリーチャーのみ援護可能：

```json
{
  "援護": {
	"target_elements": ["all"]  // 全属性対応
  }
}
```

または

```json
{
  "援護": {
	"target_elements": ["fire", "earth"]  // 火・地属性のみ
  }
}
```

#### 対象パターン
- **全属性対応** (`["all"]`): どの属性のクリーチャーでも援護可能
- **特定属性のみ**: 指定された属性のクリーチャーのみ援護可能

### UI動作

#### アイテムフェーズ時
1. バトル参加クリーチャーに援護スキルがある場合
2. フェーズラベル: 「アイテムまたは援護クリーチャーを選択」
3. 手札の表示:
   - **アイテムカード**: 選択可能（グレーアウトなし）
   - **援護対象クリーチャー**: 選択可能（グレーアウトなし）
   - **その他のカード**: グレーアウト（選択不可）

### コスト計算

- **援護クリーチャーのコスト**: mp値をそのまま魔力消費（等倍）
- 例: 75MPのクリーチャーを援護に使用 → 75G消費

### 実装済みクリーチャー

**合計18体** が援護スキルを持っています。

#### 属性別分布
- 🔥 火属性: 2体（シャラザード、バルキリー）
- 🌊 水属性: 2体（アクアデューク、ブラッドプリン）
- 💨 風属性: 1体（アームドプリンセス）
- 🌍 地属性: 10体（ウッドフォーク、オドラデク、セージなど）
- ⚪ 無属性: 3体（アンドロギア、グランギア、スカイギア）

#### 援護対象別
- **全属性対応**: 5体（28%）
  - ウッドフォーク (ID:202)
  - オドラデク (ID:203)
  - セージ (ID:225)
  - グランギア (ID:409)
  - スカイギア (ID:419)
- **特定属性のみ**: 13体（72%）

**詳細リスト**: プロジェクトルートの `/docs/reference/assist_creatures_list.md` を参照

### 使用例

**シナリオ1: 基本的な使用**
```
1. バルキリー（AP:30 HP:30、援護[無火地]）でバトル開始
2. アイテムフェーズで手札のピュトン（AP:20 HP:30、火属性）を選択
3. コスト75G消費してピュトンを援護に使用
4. バルキリーのステータスが AP:50 HP:60 に上昇
5. ピュトンは捨て札へ
6. 強化されたバルキリーでバトル実行
```

**シナリオ2: 属性制限**
```
1. シャラザード（援護[火地]）でバトル開始
2. 手札: ピュトン（火）、グランギア（無）、ウッドフォーク（地）
3. UI表示:
   - ピュトン: 選択可能（火属性）
   - ウッドフォーク: 選択可能（地属性）
   - グランギア: グレーアウト（無属性は対象外）
```

### 戦略的価値

#### メリット
1. **瞬間火力**: 手札のクリーチャーを犠牲に即座にパワーアップ
2. **柔軟性**: アイテムがない場合でもクリーチャーで代用可能
3. **リソース活用**: 使わないクリーチャーを有効活用

#### デメリット
1. **カード消費**: 使用したクリーチャーは失われる
2. **コスト**: クリーチャーのコスト分の魔力が必要
3. **スキル非継承**: 強力なスキル持ちでも能力は引き継がれない

### 実装メモ

- **実装ファイル**: 
  - `scripts/game_flow/item_phase_handler.gd` - 援護判定とカード選択
  - `scripts/battle/battle_preparation.gd` - 援護効果の適用
  - `scripts/ui_components/hand_display.gd` - グレーアウト制御
  - `scripts/ui_components/card_selection_ui.gd` - 選択可能判定
  
- **実装日**: 2025年10月24日

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/01/12 | 1.0 | 初版作成 - design.mdから分離 |
| 2025/01/12 | 1.1 | 🆕 再生スキル追加（11体実装） |
| 2025/01/12 | 1.2 | 🆕 2回攻撃スキル追加（1体実装、拡張性考慮） |
| 2025/01/13 | 1.3 | 🆕 即死スキル追加（6体実装）、後手スキル追加（1体実装） |
| 2025/10/23 | 1.4 | 🆕 応援スキル追加（9体実装）、種族システム先行実装、無効化スキルへの参照追加 |
| 2025/10/23 | 1.5 | 🆕 反射スキル追加（6種類実装完了：反射100%、反射50%、反射[巻物]、反射[全]、反射無効） |
| 2025/10/24 | 1.6 | 🆕 援護スキル追加（18体実装完了、全属性対応5体・特定属性13体） |
| 2025/10/25 | 1.7 | 🔄 スキル詳細仕様セクションをリファクタリング - 個別ファイル（14個）へのリンク集に置き換え |
| 2025/10/24 | 1.8 | 🆕 変身スキル追加（2体実装：バルダンダース、コカトリス）|
| 2025/10/24 | 1.9 | 🆕 死者復活スキル追加（4体+1アイテム実装済み）、バグ修正（リビングアムルのcreature_id、アイテムカテゴリチェック）|

---

**最終更新**: 2025年10月24日（v1.9）
