# 🎮 スキルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.3  
**最終更新**: 2025年1月13日

---

## 📋 目次

1. [スキルシステム概要](#スキルシステム概要)
2. [実装済みスキル一覧](#実装済みスキル一覧)
3. [スキル詳細仕様](#スキル詳細仕様)
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
| 貫通 | パッシブ | 防御側の土地ボーナス無効化 | ✅ 完全実装 |
| 強打 | パッシブ | 条件下でAP増幅 | ✅ 完全実装 |
| 先制 | パッシブ | 先攻権獲得 | ✅ 完全実装 |
| 後手 | パッシブ | 相手が先攻 | ✅ 完全実装 |
| 再生 | パッシブ | バトル後にHP全回復 | ✅ 完全実装 |
| 2回攻撃 | パッシブ | 1回のバトルで2回攻撃 | ✅ 完全実装 |
| 即死 | アクティブ | 確率で相手を即死 | ✅ 完全実装 |
| 防魔 | パッシブ | スペル無効化 | 🔶 部分実装 |
| ST変動 | パッシブ | 土地数でAP変動 | ✅ 完全実装 |
| HP変動 | パッシブ | 土地数でHP変動 | 🔶 部分実装 |
| 連撃 | パッシブ | 複数回攻撃 | ❌ 未実装 |
| 巻物攻撃 | パッシブ | 土地ボーナス無視 | ❌ 未実装 |

---

## スキル詳細仕様

### 1. 感応スキル

#### 概要
特定属性の土地を1つでも所有していれば、APやHPが上昇するパッシブスキル。

#### 発動条件
- 指定された属性の土地を **1つ以上所有**
- 土地のレベルや数は不問（無条件発動）
- バトル発生時に自動判定

#### 効果パターン

**パターン1: ST&HP+X** - APとHPが同時上昇
```json
{
  "感応": {
	"element": "fire",
	"stat_bonus": {
	  "ap": 20,
	  "hp": 20
	}
  }
}
```

**パターン2: ST+X、HP+Y** - APとHPが個別上昇
```json
{
  "感応": {
	"element": "water",
	"stat_bonus": {
	  "ap": 10,
	  "hp": 20
	}
  }
}
```

#### 実装クリーチャー（9体）

| クリーチャー名 | 属性 | 必要土地 | 効果 |
|--------------|------|---------|------|
| アモン | 火 | [地] | ST&HP+20 |
| ムシュフシュ | 火 | [地] | ST+20、HP+10 |
| オドントティラヌス | 水 | [風] | ST+20、HP+10 |
| ゴーストシップ | 水 | [風] | HP+30 |
| キリン | 風 | [水] | ST&HP+20 |
| クー・シー | 風 | [水] | ST+10、HP+20 |
| クフ | 風 | [水] | ST+30 |
| グロウホーン | 地 | [火] | ST&HP+20 |
| モルモ | 地 | [火] | ST+30 |

#### HPの扱い

**格納場所**: `BattleParticipant.resonance_bonus_hp`

```gdscript
# 感応ボーナス適用
participant.resonance_bonus_hp += 30
participant.update_current_hp()

# 表示HP = 基本HP + 感応HP + 土地HP + ...
# 例: 30 + 30 + 20 = 80
```

**ダメージ消費順序**: 最優先で消費（詳細は[HP管理](#battleparticipantとhp管理)参照）

#### 強打との相乗効果

感応でAPが上昇した後、強打スキルが適用されるため、相乗効果が得られる。

```
基本AP: 20
  ↓ 感応[火]+30
AP: 50
  ↓ 強打×1.5
AP: 75
```

#### 適用タイミング
- **関数**: `BattleSystem._apply_resonance_skill()`
- **タイミング**: バトル準備段階（`_apply_pre_battle_skills()`内）
- **判定**: プレイヤーの土地所有状況を`board_system.get_player_lands_by_element()`で取得

#### 実装コード例

```gdscript
func _apply_resonance_skill(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "感応" in keywords:
		return
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var resonance_condition = keyword_conditions.get("感応", {})
	
	var required_element = resonance_condition.get("element", "")
	var player_lands = context.get("player_lands", {})
	var owned_count = player_lands.get(required_element, 0)
	
	if owned_count > 0:
		var stat_bonus = resonance_condition.get("stat_bonus", {})
		var ap_bonus = stat_bonus.get("ap", 0)
		var hp_bonus = stat_bonus.get("hp", 0)
		
		if ap_bonus > 0:
			participant.current_ap += ap_bonus
		
		if hp_bonus > 0:
			participant.resonance_bonus_hp += hp_bonus
			participant.update_current_hp()
```

---

### 2. 貫通スキル

#### 概要
防御側の土地ボーナスを無効化する侵略専用スキル。

#### 発動条件
- **侵略側（攻撃側）のみ有効**
- 防御側が持っていても効果なし

#### 無効化対象

| 対象 | 無効化 |
|------|--------|
| ✅ 土地ボーナスHP (`land_bonus_hp`) | する |
| ❌ クリーチャー基本HP (`hp`) | しない |
| ❌ 感応ボーナスHP (`resonance_bonus_hp`) | しない |
| ❌ アイテムボーナスHP（将来実装） | しない |
| ❌ スペルボーナスHP（将来実装） | しない |

#### 条件タイプ

##### 1. 無条件貫通

```json
{
  "ability_parsed": {
	"keywords": ["貫通"]
  }
}
```

**実装例**:
- ナイトメア (ID: 180)
- トロージャンホース (ID: 220)

##### 2. 敵属性条件

```json
{
  "ability_parsed": {
	"keywords": ["貫通"],
	"keyword_conditions": {
	  "貫通": {
		"condition_type": "enemy_is_element",
		"elements": "water"
	  }
	}
  }
}
```

**実装例**:
- ファイアービーク (ID: 38) - 敵が水属性の場合のみ貫通

##### 3. 攻撃力条件

```json
{
  "ability_parsed": {
	"keywords": ["貫通"],
	"keyword_conditions": {
	  "貫通": {
		"condition_type": "attacker_st_check",
		"operator": ">=",
		"value": 40
	  }
	}
  }
}
```

**実装例**:
- ピュトン (ID: 36) - ST40以上で貫通

#### 適用タイミング
- **関数**: `BattleSystem._check_penetration_skill()`
- **タイミング**: BattleParticipant作成時（`_prepare_participants()`内）
- **効果**: 防御側の`land_bonus_hp`を0に設定

#### 実装コード例

```gdscript
func _check_penetration_skill(attacker_data: Dictionary, defender_data: Dictionary, tile_info: Dictionary) -> bool:
	var ability_parsed = attacker_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "貫通" in keywords:
		return false
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var penetrate_condition = keyword_conditions.get("貫通", {})
	
	# 無条件の場合
	if penetrate_condition.is_empty():
		return true
	
	# 条件付きの場合
	var condition_type = penetrate_condition.get("condition_type", "")
	
	match condition_type:
		"enemy_is_element":
			var required = penetrate_condition.get("elements", "")
			return defender_data.get("element", "") == required
		
		"attacker_st_check":
			var operator = penetrate_condition.get("operator", ">=")
			var value = penetrate_condition.get("value", 0)
			var attacker_st = attacker_data.get("ap", 0)
			
			match operator:
				">=": return attacker_st >= value
				">": return attacker_st > value
				"==": return attacker_st == value
	
	return false
```

#### 将来実装
- **巻物攻撃**: 貫通と同様に土地ボーナスを無効化するスキル

---

### 3. 強打スキル

#### 概要
特定条件下でAPを増幅するパッシブスキル。

#### 効果
APに乗数をかけて増幅（例: ×1.5、×2.0）

#### 主な条件タイプ

##### 1. 隣接自領地条件 (adjacent_ally_land)

バトル発生タイルの隣接に自分の土地がある場合に発動。

```json
{
  "effects": [{
	"effect_type": "power_strike",
	"multiplier": 1.5,
	"conditions": [
	  {"condition_type": "adjacent_ally_land"}
	]
  }]
}
```

**実装例**:
- ローンビースト (ID: 49) - 隣接自領地で強打×1.5

##### 2. 土地属性条件 (on_element_land)

特定属性の土地でバトルする場合に発動。

```json
{
  "effects": [{
	"effect_type": "power_strike",
	"multiplier": 2.0,
	"conditions": [
	  {
		"condition_type": "on_element_land",
		"element": "fire"
	  }
	]
  }]
}
```

##### 3. 土地レベル条件 (land_level_check)

土地レベルが特定値以上/以下で発動。

```json
{
  "effects": [{
	"effect_type": "power_strike",
	"multiplier": 1.5,
	"conditions": [
	  {
		"condition_type": "land_level_check",
		"operator": ">=",
		"value": 3
	  }
	]
  }]
}
```

#### 適用タイミング
- **関数**: `EffectCombat.apply_power_strike()`
- **タイミング**: 感応スキル適用後（`_apply_skills()`内）
- **重要**: 感応で上昇したAPを基準に計算される

#### 感応との相乗効果

```gdscript
# 元のAP
var base_ap = 20

# 1. 感応適用
base_ap += 30  # → 50

# 2. 強打適用（感応後のAPが基準）
base_ap *= 1.5  # → 75
```

#### 🆕 アイテムによる強打付与（Phase 1-A）

アイテムカードで強打スキルを一時的に付与できる。

**付与条件と発動条件の違い**:
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

- **付与条件** (`condition`): 火属性クリーチャーが使用した場合のみスキル付与
- **発動条件**: 付与された強打は**無条件で発動**（バトル時の条件チェックなし）

**実装例: マグマハンマー (ID: 1062)**
```json
{
  "id": 1062,
  "name": "マグマハンマー",
  "type": "item",
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

**処理フロー**:
```
1. アイテムフェーズでマグマハンマー選択
   ↓
2. 条件チェック（user_element: fire）
   ├─ 火属性クリーチャー → 付与
   └─ その他属性 → スキップ
   ↓
3. スキル付与
   ├─ keywords配列に「強打」追加
   └─ effects配列に強打効果追加
	   {
		 "effect_type": "power_strike",
		 "multiplier": 1.5,
		 "conditions": []  // 無条件で発動
	   }
   ↓
4. バトル時に強打発動
   AP × 1.5
```

**実装クラス**:
- `BattleSystem._apply_item_effects()` - アイテム効果適用
- `BattleSystem._grant_skill_to_participant()` - スキル付与
- `BattleSystem._check_skill_grant_condition()` - 付与条件チェック

---

### 4. 先制スキル

#### 概要
バトルで先に攻撃できるパッシブスキル。

#### 発動条件
- `keywords`配列に「先制」が含まれる
- 無条件発動

#### 効果
- 攻撃順で優先される
- 両者が先制を持つ場合、侵略側が優先

#### 判定ロジック

```gdscript
func _determine_attack_order(attacker: BattleParticipant, defender: BattleParticipant) -> Array:
	if attacker.has_first_strike and defender.has_first_strike:
		return [attacker, defender]  # 両者先制 → 侵略側優先
	elif defender.has_first_strike:
		return [defender, attacker]  # 防御側のみ先制
	else:
		return [attacker, defender]  # デフォルト（侵略側先攻）
```

#### 実装例
```json
{
  "ability_parsed": {
	"keywords": ["先制"]
  }
}
```

---

### 5. 再生スキル

#### 概要
バトル終了後に基本HPを全回復するパッシブスキル。

#### 発動条件
- **生き残った場合のみ**発動（`current_hp > 0`）
- HP0以下（倒された）の場合は発動しない
- 無条件発動（生存していれば必ず発動）

#### 効果
- バトル終了後、`base_hp`を元の最大値まで回復
- 土地ボーナスや感応ボーナスは含まない（戦闘ごとにリセット）

#### 回復範囲

| 対象 | 回復 |
|------|------|
| ✅ 基本HP (`base_hp`) | する |
| ❌ 土地ボーナス (`land_bonus_hp`) | しない |
| ❌ 感応ボーナス (`resonance_bonus_hp`) | しない |
| ❌ アイテムボーナス (`item_bonus_hp`) | しない |
| ❌ スペルボーナス (`spell_bonus_hp`) | しない |

#### 適用タイミング
- **関数**: `BattleSystem._apply_regeneration()`
- **タイミング**: `_apply_post_battle_effects()`内（バトル結果判定後）
- **対象**: 侵略側・防御側の両方

#### 実装クリーチャー（11体）

| ID | 名前 | 属性 | 備考 |
|----|------|------|------|
| 113 | エキノダーム | 水 | 再生・不屈 |
| 125 | スラッジタイタン | 水 | 戦闘開始時HP減少・再生 |
| 129 | テンタクルズ | 水 | 再生 |
| 133 | バハムート | 水 | 先制・土地変性・再生 |
| 140 | マイコロン | 水 | 敵攻撃成功の戦闘後・再生 |
| 205 | カクタスウォール | 地 | 防御型・再生 |
| 219 | シルバンダッチェス | 地 | 援護・アイテム破壊・再生 |
| 233 | ヒーラー | 地 | 再生・秘術・不屈 |
| 242 | ヨルムンガンド | 地 | 先制・土地変性・再生 |
| 247 | ロックトロル | 地 | 再生 |
| 418 | スケルトン | 無 | 再生 |

#### データ構造

```json
{
  "ability_parsed": {
	"keywords": ["再生"]
  }
}
```

#### 実装コード

```gdscript
func _apply_regeneration(participant: BattleParticipant) -> void:
	# 1. 生存チェック（HP > 0）
	if not participant.is_alive():
		return
	
	# 2. 再生キーワードチェック
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "再生" in keywords:
		# 3. base_hpを元の最大HPまで回復
		var max_base_hp = participant.creature_data.get("hp", 0)
		
		if participant.base_hp < max_base_hp:
			var healed = max_base_hp - participant.base_hp
			participant.base_hp = max_base_hp
			participant.update_current_hp()
			print("【再生発動】", participant.creature_data.get("name", "?"), 
				  " HP回復: +", healed, " → ", participant.current_hp)
```

#### 使用例

**バトルフロー**:
```
1. バトル開始
   侵略側: ロックトロル HP:50/50
   防御側: フェニックス HP:30/30

2. 戦闘実行
   フェニックスの攻撃 → ロックトロルに30ダメージ
   ロックトロル HP:50 → 20

3. バトル終了後
   【再生発動】ロックトロル HP回復: +30 → 50
   → 次のバトルでは満タンの状態！
```

#### 設計思想

- **永続的な回復**: 配置クリーチャーとして残る限り、何度でも再生
- **土地防衛に有利**: 防御側として配置されたクリーチャーが長期間生き残る
- **基本HPのみ回復**: 土地ボーナス等は戦闘ごとにリセットされる仕様と整合

---

### 6. 2回攻撃スキル

#### 概要
1回のバトルで2回連続攻撃を行うパッシブスキル。

#### 発動条件
- 無条件発動（生き残っていれば2回攻撃）
- 各攻撃後に相手の生存確認（倒されていたら次の攻撃はなし）

#### 効果
- 同じ相手に対して2回連続攻撃
- 各攻撃で最終計算後のAPを使用（感応・強打・アイテム・スペル等すべて適用後）
- 相手の反撃は2回攻撃が完了してから

#### 攻撃順序

**通常の場合**:
```
1. 攻撃側の1回目の攻撃
2. 攻撃側の2回目の攻撃（相手が生存していれば）
3. 防御側の反撃
```

**先制+2回攻撃の場合**:
```
1. 先制攻撃側の1回目の攻撃
2. 先制攻撃側の2回目の攻撃
3. 相手の反撃
```

#### 実装クリーチャー（1体）

| ID | 名前 | 属性 | AP | HP |
|----|------|------|----|----|
| 325 | テトラーム | 風 | 20 | 30 |

#### データ構造

```json
{
  "ability_parsed": {
	"keywords": ["2回攻撃"]
  }
}
```

#### 実装詳細

**BattleParticipantクラス**:
```gdscript
var attack_count: int = 1  # デフォルト1回、2回攻撃なら2
```

**スキル判定**:
```gdscript
func _check_double_attack(participant: BattleParticipant) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if "2回攻撃" in keywords:
		participant.attack_count = 2
		print("【2回攻撃】", participant.creature_data.get("name", "?"), " 攻撃回数: 2回")
```

**攻撃シーケンス**:
```gdscript
func _execute_attack_sequence(attack_order: Array) -> void:
	for i in range(attack_order.size()):
		var attacker_p = attack_order[i]
		var defender_p = attack_order[(i + 1) % 2]
		
		if not attacker_p.is_alive():
			continue
		
		# 攻撃回数分ループ
		for attack_num in range(attacker_p.attack_count):
			# 既に倒されていたら攻撃しない
			if not defender_p.is_alive():
				break
			
			# ダメージ処理
			defender_p.take_damage(attacker_p.current_ap)
```

#### 使用例

**バトルフロー**:
```
侵略側: テトラーム AP:20 HP:30 (2回攻撃)
防御側: フェニックス AP:40 HP:30

【第1攻撃 - 1回目】侵略側の攻撃
  テトラーム AP:20 → フェニックス
  ダメージ処理:
	- 基本HP: 20 消費
  → 残HP: 10 (基本HP:10)

【第1攻撃 - 2回目】侵略側の攻撃
  テトラーム AP:20 → フェニックス
  ダメージ処理:
	- 基本HP: 10 消費
  → 残HP: 0 (基本HP:0)
  → フェニックス 撃破！

【結果】侵略成功（フェニックスは反撃できず）
```

#### 設計思想

- **拡張性**: `attack_count`を使用することで、将来的に3回攻撃以上も対応可能
- **アイテム/スペル対応**: アイテムやスペルで`attack_count`を増やす実装が容易
- **効率的な実装**: ループ構造により、攻撃回数に関わらず同じコードで対応
- **早期終了**: 相手が倒されたら即座に攻撃を中止し、無駄な処理を省く

#### 相乗効果

**感応+2回攻撃**:
```
基本AP: 20
  ↓ 感応[火]+30
AP: 50
  ↓ 2回攻撃
合計ダメージ: 50 × 2 = 100
```

**感応+強打+2回攻撃**:
```
基本AP: 20
  ↓ 感応[火]+30
AP: 50
  ↓ 強打×1.5
AP: 75
  ↓ 2回攻撃
合計ダメージ: 75 × 2 = 150
```

---

### 7. 即死スキル

#### 概要
攻撃後、一定確率で相手を即死させるアクティブスキル。

#### 発動タイミング
- **攻撃後、ダメージ適用後**に即死判定
- 攻撃が無効化された場合は発動しない
- 各攻撃ごとに判定（2回攻撃なら2回判定）

#### 発動条件
- 即死スキル保持
- 条件を満たす（属性、ST、立場など）
- 確率判定成功

#### 効果
- 即死成功時、相手の`instant_death_flag = true`
- 相手のHPを0にする
- **再生・復活・変身スキルは発動不可**

#### 条件タイプ

##### 1. 無条件即死

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "none",
		"probability": 70
	  }
	}
  }
}
```

**実装例**:
- アネイマブル (ID: 201) - 後手；即死[70%]

##### 2. 敵属性条件

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "enemy_is_element",
		"elements": "fire",
		"probability": 60
	  }
	}
  }
}
```

**実装例**:
- イエティ (ID: 111) - 即死[火・60%]
- ダンピール (ID: 325) - 即死[地・60%]
- セイント (ID: 424) - 即死[無・100%]

**特殊ケース**:
- `elements: "全"` - すべての属性に有効
- キロネックス (ID: 118) - 防御側なら即死[全・80%]

##### 3. 防御側ST条件

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "defender_st_check",
		"operator": ">=",
		"value": 50,
		"probability": 60
	  }
	}
  }
}
```

**実装例**:
- シグルド (ID: 16) - 即死[ST50以上・60%]

**説明**: 相手（防御側）の基本STが50以上の場合に即死判定

##### 4. 使用者が防御側条件

```json
{
  "ability_parsed": {
	"keywords": ["即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "defender_role",
		"elements": "全",
		"probability": 80
	  }
	}
  }
}
```

**実装例**:
- キロネックス (ID: 118) - 防御側なら即死[全・80%]

**説明**: キロネックスが防御側の時のみ、反撃時に即死判定

#### 実装クリーチャー（6体）

| ID | 名前 | 属性 | 条件 | 確率 |
|----|------|------|------|-----|
| 16 | シグルド | 火 | 防御側ST≥50 | 60% |
| 111 | イエティ | 水 | 敵が火属性 | 60% |
| 118 | キロネックス | 水 | 防御側なら | 80% |
| 201 | アネイマブル | 地 | 無条件（後手） | 70% |
| 325 | ダンピール | 風 | 敵が地属性 | 60% |
| 424 | セイント | 無 | 敵が無属性 | 100% |

#### 適用タイミング
- **関数**: `BattleSystem._check_instant_death()`
- **タイミング**: 攻撃後、ダメージ適用後、死亡チェック前
- **判定**: 基本STで条件判定（計算後のSTではない）

#### 他スキルとの相互作用

| スキル | 関係 |
|--------|------|
| 無効化 | 即死を無効化できる（将来実装） |
| 再生 | 即死されたら再生不可 |
| 復活 | 即死されたら復活不可（将来実装） |
| 変身 | 即死されたら変身不可（将来実装） |
| 先制 | 先制持ちが即死を持つ場合、先制攻撃時に即死判定 |
| 2回攻撃 | 各攻撃ごとに即死判定 |

#### 実装コード

```gdscript
func _check_instant_death(attacker: BattleParticipant, defender: BattleParticipant) -> bool:
	# 即死スキルを持つかチェック
	var ability_parsed = attacker.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "即死" in keywords:
		return false
	
	# 即死条件を取得
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var instant_death_condition = keyword_conditions.get("即死", {})
	
	# 条件チェック
	if not _check_instant_death_condition(instant_death_condition, attacker, defender):
		return false
	
	# 確率判定
	var probability = instant_death_condition.get("probability", 0)
	var random_value = randf() * 100.0
	
	if random_value <= probability:
		print("【即死発動】", attacker.creature_data.get("name", "?"), 
			  " → ", defender.creature_data.get("name", "?"), 
			  " (", probability, "% 判定成功)")
		defender.instant_death_flag = true
		defender.base_hp = 0
		defender.update_current_hp()
		return true
	else:
		print("【即死失敗】確率:", probability, "% 判定値:", int(random_value), "%")
		return false
```

#### 使用例

**バトルフロー（イエティ vs ファイアードレイク）**:
```
侵略側: イエティ AP:40 HP:40 (即死[火・60%])
防御側: ファイアードレイク AP:30 HP:50 (火属性)

【第1攻撃】侵略側の攻撃
  イエティ AP:40 → ファイアードレイク
  ダメージ処理:
	- 土地ボーナス: 10 消費
	- 基本HP: 30 消費
  → 残HP: 10 (基本HP:10)

【即死判定開始】イエティ → ファイアードレイク
【即死条件】敵がfire属性 → 条件満たす
【即死発動】イエティ → ファイアードレイク (60% 判定成功)
  → ファイアードレイク 撃破！

【結果】侵略成功（ファイアードレイクは反撃できず）
```

#### 設計思想

- **ハイリスク・ハイリターン**: 確率発動だが、成功すれば一撃必殺
- **条件付き発動**: 無条件即死は少なく、ほとんどが条件付き
- **将来の拡張性**: `instant_death_flag`により、即死回避スキル実装が容易
- **バランス調整**: 確率と条件により、強力すぎないように調整

---

### 8. 後手スキル

#### 概要
先制の逆で、相手が先に攻撃する順序変更スキル。

#### 発動条件
- `keywords`配列に「後手」が含まれる
- 無条件発動

#### 効果
- **相手が先攻**になる（侵略側でも後手になる）
- 先制スキルを上書き（後手持ちは先制を持てない）
- アイテムなどで先制を付与すると後手が上書きされる（後手が消える）

#### 判定ロジック

```gdscript
# BattleParticipant._check_first_strike()
func _check_first_strike() -> bool:
	var keywords = creature_data.get("ability_parsed", {}).get("keywords", [])
	
	# 後手スキルを持つ場合、先制を無効化
	if "後手" in keywords:
		return false
	
	return "先制" in keywords

# BattleSystem._determine_attack_order()
func _determine_attack_order(attacker: BattleParticipant, defender: BattleParticipant) -> Array:
	var attacker_keywords = attacker.creature_data.get("ability_parsed", {}).get("keywords", [])
	var defender_keywords = defender.creature_data.get("ability_parsed", {}).get("keywords", [])
	var attacker_has_last_strike = "後手" in attacker_keywords
	var defender_has_last_strike = "後手" in defender_keywords
	
	# 後手持ちは相手が先攻
	if attacker_has_last_strike and not defender_has_last_strike:
		return [defender, attacker]  # 侵略側が後手 → 防御側が先攻
	elif defender_has_last_strike and not attacker_has_last_strike:
		return [attacker, defender]  # 防御側が後手 → 侵略側が先攻
	elif attacker_has_last_strike and defender_has_last_strike:
		return [attacker, defender]  # 両者後手 → 侵略側優先
	
	# 通常の先制判定
	# ...
```

#### 実装クリーチャー（1体）

| ID | 名前 | 属性 | AP | HP | その他スキル |
|----|------|------|----|----|-------------|
| 201 | アネイマブル | 地 | 50 | 10 | 後手；即死[70%] |

#### データ構造

```json
{
  "ability_parsed": {
	"keywords": ["後手", "即死"],
	"keyword_conditions": {
	  "即死": {
		"condition_type": "none",
		"probability": 70
	  }
	}
  }
}
```

#### 使用例

**バトルフロー（アネイマブル vs 通常クリーチャー）**:
```
侵略側: アネイマブル AP:50 HP:10 (後手；即死[70%])
防御側: キングバラン AP:60 HP:50

【攻撃順】防御側 → 侵略側（後手により順序変更）

【第1攻撃】防御側の攻撃
  キングバラン AP:60 → アネイマブル
  ダメージ処理:
	- 基本HP: 10 消費
  → 残HP: 0
  → アネイマブル 撃破！

【結果】防御成功（アネイマブルは攻撃できず）
```

**即死が成功する場合**:
```
侵略側: アネイマブル AP:50 HP:10 (後手；即死[70%])
防御側: ゴブリン AP:20 HP:30

【攻撃順】防御側 → 侵略側

【第1攻撃】防御側の攻撃
  ゴブリン AP:20 → アネイマブル
  ダメージ処理:
	- 基本HP: 10 消費
  → 残HP: 0（致死ダメージだが、まだ攻撃可能）

【第2攻撃】侵略側の攻撃
  アネイマブル AP:50 → ゴブリン
  ダメージ処理:
	- 基本HP: 30 消費
  → 残HP: 0
  
【即死判定開始】アネイマブル → ゴブリン
【即死発動】アネイマブル → ゴブリン (70% 判定成功)
  → ゴブリン 撃破！

【結果】両者撃破 → 侵略失敗
```

#### 設計思想

- **ハイリスク・ハイリターン**: HP10と低いが、ST50と即死[70%]を持つ
- **戦術的要素**: 相手の攻撃を受けてから反撃する特殊な戦い方
- **即死との相性**: 後手で耐えて即死を狙う戦術

---

### 9. 防魔スキル

#### 概要
スペルカードの効果を無効化するパッシブスキル。

#### 実装状況
- **keywords判定**: 実装済み
- **スペル無効化**: 部分実装（スペルシステムが未完成）

#### 将来実装
```gdscript
func can_spell_affect(target_creature: Dictionary, spell: Dictionary) -> bool:
	var keywords = target_creature.get("ability_parsed", {}).get("keywords", [])
	return not "防魔" in keywords
```

---

### 8. ST変動スキル

#### 概要
所有土地数に応じてAPが変動するパッシブスキル。

#### 効果式
```
AP = 基本AP + (土地数 × 係数)
```

#### 実装例（アームドパラディン）

```json
{
  "ability_parsed": {
	"effects": [{
	  "effect_type": "modify_stats",
	  "target": "self",
	  "stat": "AP",
	  "operation": "multiply",
	  "formula": "fire_lands * 10"
	}]
  }
}
```

```
所有火土地: 3個
AP = 0 + (3 × 10) = 30
```

---

## スキル適用順序

バトル前のスキル適用は以下の順序で実行される:

```
1. 感応スキル (_apply_resonance_skill)
   ├─ プレイヤーの土地所有状況を確認
   ├─ 条件を満たせばAPとHPを上昇
   └─ resonance_bonus_hpフィールドに加算
   
2. 強打スキル (apply_power_strike)
   ├─ 感応適用後のAPを基準に計算
   ├─ 条件を満たせばAPを増幅
   └─ 例: 基本20 → 感応+30=50 → 強打×1.5=75
   
3. 2回攻撃判定 (_check_double_attack)
   ├─ 2回攻撃スキル保持チェック
   └─ attack_count = 2 に設定
   
4. 攻撃シーケンス (_execute_attack_sequence)
   ├─ 攻撃順決定（先制・後手判定）
   ├─ 各攻撃ごとにダメージ適用
   └─ **攻撃後に即死判定** (_check_instant_death)
	  ├─ 即死スキル保持チェック
	  ├─ 条件判定（属性、ST、立場など）
	  ├─ 確率判定
	  └─ 成功時: instant_death_flag = true, HP = 0
   
5. バトル結果判定 (_resolve_battle_result)
   ├─ HPチェック
   └─ 勝敗決定
   
6. バトル後処理 (_apply_post_battle_effects)
   ├─ 再生スキル適用（生存者のみ）
   │  └─ HP > 0 の場合のみ発動
   ├─ 土地奪取 or カード破壊 or 手札復帰
   └─ クリーチャーHP更新
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

## 将来実装予定のスキル

### 1. 連撃スキル

#### 概要
1ターンに複数回攻撃できるスキル。

#### 設計案
```json
{
  "ability_parsed": {
	"keywords": ["連撃"],
	"keyword_conditions": {
	  "連撃": {
		"attack_count": 2
	  }
	}
  }
}
```

#### 実装イメージ
```gdscript
func _execute_attack_sequence(attack_order: Array) -> void:
	for attacker in attack_order:
		var attack_count = get_attack_count(attacker)  # 連撃判定
		
		for i in range(attack_count):
			if not attacker.is_alive() or not defender.is_alive():
				break
			
			defender.take_damage(attacker.current_ap)
```

### 2. 巻物攻撃スキル

#### 概要
貫通と同様に土地ボーナスを無視する攻撃。

#### 設計案
```json
{
  "ability_parsed": {
	"keywords": ["巻物攻撃"]
  }
}
```

#### 実装方針
- 貫通スキルと同じ処理を使用
- `_check_penetration_skill()`に「巻物攻撃」も追加

### 3. 反撃スキル

#### 概要
攻撃を受けた時、即座に反撃ダメージを与える。

#### 設計案
```json
{
  "ability_parsed": {
	"effects": [{
	  "effect_type": "counter_attack",
	  "damage_ratio": 0.5
	}]
  }
}
```

### 4. 回復スキル

#### 概要
ターン開始時やバトル後にHPを回復。

#### 設計案
```json
{
  "ability_parsed": {
	"effects": [{
	  "effect_type": "heal",
	  "timing": "turn_start",
	  "amount": 10
	}]
  }
}
```

### 5. スペル反射スキル

#### 概要
防魔の上位版。スペルを無効化し、発動者に跳ね返す。

#### 設計案
```json
{
  "ability_parsed": {
	"keywords": ["スペル反射"]
  }
}
```

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/01/12 | 1.0 | 初版作成 - design.mdから分離 |
| 2025/01/12 | 1.1 | 🆕 再生スキル追加（11体実装） |
| 2025/01/12 | 1.2 | 🆕 2回攻撃スキル追加（1体実装、拡張性考慮） |
| 2025/01/13 | 1.3 | 🆕 即死スキル追加（6体実装）、後手スキル追加（1体実装） |

---

**最終更新**: 2025年1月13日（v1.3）
