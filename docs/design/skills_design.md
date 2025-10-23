# 🎮 スキルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.5  
**最終更新**: 2025年10月23日

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

---

## スキル詳細仕様

### 0. 応援スキル ✨NEW

#### 概要
盤面に配置されているクリーチャーが、**バトル参加者（侵略側・防御側）**に対してバフを与えるパッシブスキル。

**詳細仕様**: 無効化スキルの詳細は別ドキュメントを参照してください。
- **仕様書**: `docs/design/nullify_skill_design.md`

---

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

### 6. 不屈スキル

#### 概要
アクション（召喚、レベルアップ、移動、交換）実行後もダウン状態にならないパッシブスキル。何度でも領地コマンドを実行可能。

#### 発動条件
- 無条件発動（不屈持ちクリーチャーがいる土地は常にダウンしない）

#### 効果
- **召喚後**: 通常はダウンするが、不屈持ちはダウンしない
- **レベルアップ後**: 通常はダウンするが、不屈持ちはダウンしない
- **移動後**: 移動先の土地が通常はダウンするが、不屈持ちはダウンしない
- **交換後**: 通常はダウンするが、不屈持ちはダウンしない

#### 戦略的価値
- **連続行動**: 同一ターンに複数回領地コマンドを実行可能
- **防衛拠点**: 何度攻撃されても領地コマンドで強化・補強できる
- **レベル上げ**: 魔力さえあれば即座にLv.5まで上げられる

#### 実装クリーチャー（16体）

| ID | 名前 | 属性 | AP | HP |
|----|------|------|----|----|
| 14 | シールドメイデン | 火 | 20 | 50 |
| 18 | ショッカー | 火 | 20 | 30 |
| 28 | バードメイデン | 火 | 10 | 40 |
| 113 | エキノダーム | 水 | 20 | 40 |
| 117 | カワヒメ | 水 | 20 | 40 |
| 141 | マカラ | 水 | 30 | 40 |
| 207 | キャプテンコック | 地 | 30 | 40 |
| 234 | ヒーラー | 地 | 10 | 40 |
| 235 | ピクシー | 地 | 30 | 30 |
| 249 | ワーベア | 地 | 30 | 50 |
| 312 | グレートニンバス | 風 | 30 | 30 |
| 331 | トレジャーレイダー | 風 | 30 | 30 |
| 341 | マーシャルモンク | 風 | 30 | 40 |
| 342 | マッドハーレクイン | 風 | 20 | 40 |
| 403 | アーキビショップ | 無 | 20 | 40 |
| 418 | シャドウガイスト | 無 | 30 | 30 |

#### データ構造

```json
{
  "ability_detail": "不屈",
  "ability_parsed": {
	"keywords": ["不屈"]
  }
}
```

#### 実装コード

**SkillSystem.gd**:
```gdscript
## 不屈スキルを持っているかチェック
static func has_unyielding(creature_data: Dictionary) -> bool:
	if creature_data.is_empty():
		return false
	
	var ability_detail = creature_data.get("ability_detail", "")
	return "不屈" in ability_detail
```

**TileActionProcessor.gd（召喚時）**:
```gdscript
# Phase 1-A: 召喚後にダウン状態を設定（不屈チェック）
if board_system.tile_nodes.has(current_tile):
	var tile = board_system.tile_nodes[current_tile]
	if tile and tile.has_method("set_down_state"):
		# 不屈持ちでなければダウン状態にする
		if not SkillSystem.has_unyielding(card_data):
			tile.set_down_state(true)
		else:
			print("不屈により召喚後もダウンしません")
```

**LandCommandHandler.gd（レベルアップ時）**:
```gdscript
# ダウン状態設定（不屈チェック）
if tile.has_method("set_down_state"):
	var creature = tile.creature_data if tile.has("creature_data") else {}
	if not SkillSystem.has_unyielding(creature):
		tile.set_down_state(true)
	else:
		print("不屈によりレベルアップ後もダウンしません")
```

#### 使用例

**シナリオ1: 連続レベルアップ**
```
1. ターン開始時、シールドメイデン配置のLv.1土地を所有（魔力: 1200G）
2. 領地コマンド → レベルアップ → Lv.2（80G消費）
3. 不屈により土地はダウンしない
4. 再度領地コマンド → レベルアップ → Lv.3（160G消費）
5. さらに領地コマンド → レベルアップ → Lv.5（580G消費）
6. 合計820G消費で、1ターンでLv.5達成！
```

**シナリオ2: 防衛拠点**
```
1. 重要な場所にワーベア（不屈）配置
2. 敵に攻撃される → バトル勝利
3. 通常ならダウンするが、不屈により領地コマンド可能
4. 即座にレベルアップして防御力強化
5. 次の敵にも備えられる
```

#### 設計思想

- **リソース管理**: 魔力さえあれば強力だが、魔力切れに注意
- **戦略性**: 不屈持ちクリーチャーの配置場所が重要
- **バランス**: ダウンシステムの制約を回避できる唯一のスキル

---

### 7. 2回攻撃スキル

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

### 7. 土地数比例効果 ✨NEW

#### 概要
指定された属性の土地配置数に応じて、AP/HPが上昇するパッシブスキル。

#### 発動条件
- バトル発生時に自動判定
- 所有している指定属性の土地数を合計
- 土地数 × 倍率 = ボーナス値

#### 効果パターン

**パターン1: 単一属性**
```json
{
  "effects": [
	{
	  "effect_type": "land_count_multiplier",
	  "stat": "ap",
	  "elements": ["fire"],
	  "multiplier": 20
	}
  ]
}
```
- 火土地3つ所有 → AP+60

**パターン2: 複数属性の合計**
```json
{
  "effects": [
	{
	  "effect_type": "land_count_multiplier",
	  "stat": "ap",
	  "elements": ["fire", "earth"],
	  "multiplier": 10
	}
  ]
}
```
- 火土地2つ + 土土地3つ = 5つ所有 → AP+50

**パターン3: HP上昇版**
```json
{
  "effects": [
	{
	  "effect_type": "land_count_multiplier",
	  "stat": "hp",
	  "elements": ["water"],
	  "multiplier": 15
	}
  ]
}
```
- 水土地4つ所有 → HP+60

#### 実装クラス
`scripts/battle/battle_skill_processor.gd`の`apply_land_count_effects()`

#### 実装例

**アームドパラディン** (ID: 1)
```json
{
  "ap": 0,
  "hp": 50,
  "ability_detail": "ST=火地,配置数×10；無効化[巻物]",
  "ability_parsed": {
	"keywords": ["無効化"],
	"effects": [
	  {
		"effect_type": "land_count_multiplier",
		"stat": "ap",
		"elements": ["fire", "earth"],
		"multiplier": 10,
		"description": "火と土の土地配置数×10をSTに加算"
	  }
	]
  }
}
```

#### 実行ログ例
```
【土地数比例】アームドパラディン
  対象属性: ["fire", "earth"] 合計土地数: 5
  AP: 0 → 50 (+50)
```

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
- **設計書**: `docs/design/nullify_skill_design.md`

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

### 12. 反射スキル

#### 概要
攻撃を受けた時、ダメージを攻撃者に返すリアクティブスキル。反射率によって自分が受けるダメージと返すダメージの割合が変わる。

#### 実装状況
⚙️ **実装中**（2025年10月23日）

#### スキルパターン

| パターン | 自分ダメージ | 返すダメージ | 対象攻撃 |
|---------|------------|------------|---------|
| **反射100%** | 0% | 100% | 通常攻撃 or 巻物攻撃 |
| **反射50%** | 50% | 50% | 通常攻撃 |

#### 発動タイミング
```
1. 攻撃側の攻撃（先制含む）
2. ダメージ計算
3. 反射判定 ← ここで発動
4. ダメージ適用
   - 防御側：元ダメージ × (1 - 反射率)
   - 攻撃側：元ダメージ × 反射率
5. 勝敗判定
```

#### 反射の種類

##### 1. 反射[通常攻撃] / 反射（100%）
- **効果**: 通常攻撃を100%反射（自分はダメージ0）
- **対象**: デコイ(426)

**ability_parsed**:
```json
{
  "keywords": ["反射"],
  "effects": [{
	"effect_type": "reflect_damage",
	"reflect_ratio": 1.0,
	"attack_types": ["normal"]
  }]
}
```

**例**:
```
攻撃者AP: 100
防御側: デコイ（反射100%）

結果:
- デコイが受けるダメージ: 0
- 攻撃者が受けるダメージ: 100
```

##### 2. 反射[1/2]（50%）
- **効果**: 通常攻撃を50%反射（自分は50%ダメージ）
- **対象**: ナイトエラント(25), スパイクシールド(1025)

**ability_parsed**:
```json
{
  "keywords": ["反射[1/2]"],
  "effects": [{
	"effect_type": "reflect_damage",
	"reflect_ratio": 0.5,
	"attack_types": ["normal"]
  }]
}
```

**例**:
```
攻撃者AP: 100
防御側: ナイトエラント（反射50%）

結果:
- ナイトエラントが受けるダメージ: 50
- 攻撃者が受けるダメージ: 50
```

##### 3. 反射[巻物]（100%）
- **効果**: 巻物攻撃を100%反射（自分はダメージ0）
- **対象**: メイガスミラー(1069)

**ability_parsed**:
```json
{
  "keywords": ["反射[巻物]"],
  "effects": [{
	"effect_type": "reflect_damage",
	"reflect_ratio": 1.0,
	"attack_types": ["scroll"]
  }]
}
```

##### 4. 反射[全]（100%）
- **効果**: 通常攻撃・巻物攻撃を100%反射（自分はダメージ0）
- **対象**: ミラーホブロン(1066)
- **条件**: 敵アイテム未使用時のみ

**ability_parsed**:
```json
{
  "keywords": ["反射[全]"],
  "effects": [{
	"effect_type": "reflect_damage",
	"reflect_ratio": 1.0,
	"attack_types": ["normal", "scroll"],
	"conditions": [{
	  "condition_type": "enemy_no_item"
	}]
  }]
}
```

#### 反射無効スキル

##### 概要
攻撃側が持つと、相手の反射を無効化するパッシブスキル。

##### 対象
- ムラサメ(1068)

**ability_parsed**:
```json
{
  "keywords": ["反射無効"],
  "effects": [{
	"effect_type": "nullify_reflect"
  }]
}
```

**効果**:
```
攻撃側: ムラサメ装備（反射無効）
防御側: デコイ（反射100%）

結果:
- デコイの反射は発動しない
- デコイが100%ダメージを受ける
```

#### 先制攻撃との関係

反射は先制攻撃でも発動する。

**例**:
```
攻撃側: AP 60（先制あり）
防御側: HP 50、ST 70（反射100%あり）

1. 先制攻撃: AP 60
2. 反射発動: 60ダメージ返す
3. 結果:
   - 防御側: ダメージ0（生存）
   - 攻撃側: 60ダメージ受ける
```

#### 勝敗判定

反射ダメージによる勝敗判定は通常と同じ。

**例1: 防御側勝利**
```
攻撃側: AP 100、HP 40
防御側: HP 80、ST 50（反射50%）

1. 攻撃: 100ダメージ
2. 反射: 50ダメージ返す
3. 結果:
   - 防御側: HP 80 - 50 = 30（生存）
   - 攻撃側: HP 40 - 50 = -10（死亡）
   → 防御側の勝利
```

**例2: 攻撃側勝利**
```
攻撃側: AP 200、HP 100
防御側: HP 80、ST 50（反射50%）

1. 攻撃: 200ダメージ
2. 反射: 100ダメージ返す
3. 結果:
   - 防御側: HP 80 - 100 = -20（死亡）
   - 攻撃側: HP 100 - 100 = 0（死亡）
   → 攻撃側の勝利（先に攻撃したため）
```

#### 実装クリーチャー・アイテム

| ID | 名前 | タイプ | スキル | 反射率 | 対象 |
|----|------|--------|--------|--------|------|
| 426 | デコイ | クリーチャー | 反射 | 100% | 通常攻撃 |
| 25 | ナイトエラント | クリーチャー | 反射[1/2] | 50% | 通常攻撃 |
| 1025 | スパイクシールド | アイテム（防具） | 反射[1/2] | 50% | 通常攻撃 |
| 1066 | ミラーホブロン | アイテム（防具） | 反射[全] | 100% | 全攻撃（条件付き） |
| 1068 | ムラサメ | アイテム（武器） | 反射無効 | - | - |
| 1069 | メイガスミラー | アイテム（アクセサリ） | 反射[巻物] | 100% | 巻物攻撃 |

#### 注意事項

1. **合成スキルとの関係**
   - ナイトエラントが合成で変身した後、反射スキルは消える

2. **HPを超えるダメージ**
   - 防御側のHPを超えるダメージでも、元のダメージを基準に反射
   ```
   攻撃AP: 300
   防御HP: 50（反射50%）
   
   結果:
   - 防御側: 150ダメージ受けて死亡
   - 攻撃側: 150ダメージ返す
   ```

3. **反射の連鎖なし**
   - 反射ダメージはさらに反射されない

---

## 7. 反射スキル

#### 概要
攻撃を受けた時、ダメージの一部または全部を攻撃者に返すスキル。反射には50%反射と100%反射の2種類があり、通常攻撃のみ、巻物攻撃のみ、または両方を対象とする。

#### 発動条件
- 攻撃を受けた時（通常攻撃または巻物攻撃）
- 攻撃側が「反射無効」を持っていない場合

#### 反射の種類

##### パターン1: 反射50%
```
受けるダメージ: 元のダメージ × 50%
返すダメージ: 元のダメージ × 50%

例: AP 100の攻撃を受けた場合
- 防御側が受けるダメージ: 50
- 攻撃者に返すダメージ: 50
```

##### パターン2: 反射100%
```
受けるダメージ: 0
返すダメージ: 元のダメージ × 100%

例: AP 200の攻撃を受けた場合
- 防御側が受けるダメージ: 0
- 攻撃者に返すダメージ: 200
```

#### 攻撃タイプ別の反射

| 表記 | 対象攻撃 | 効果 |
|------|---------|------|
| 反射[通常攻撃] | 通常攻撃のみ | 100%反射 |
| 反射[1/2] | 通常攻撃のみ | 50%反射 |
| 反射[巻物] | 巻物攻撃のみ | 100%反射 |
| 反射[全] | 通常攻撃+巻物攻撃 | 100%反射 |

#### 反射無効

攻撃側が「反射無効」を持つと、防御側の反射スキルが発動しない。

```
攻撃側: ムラサメ装備（反射無効）
防御側: デコイ（反射100%）

結果: デコイの反射は発動せず、通常通りダメージを受ける
```

#### 先制攻撃との関係

先制攻撃でも反射は発動する。

```
攻撃側: AP 60（先制）
防御側: HP 50（反射100%）

1. 先制攻撃: 60ダメージ
2. 反射発動: 攻撃側に60ダメージ返す
3. 防御側はダメージ0（反射100%のため）
4. 攻撃側HP: -60（死亡）
→ 防御側の勝利
```

#### 勝敗判定

反射ダメージで攻撃側が死亡した場合、通常の勝敗基準と同じ。

```
攻撃側: AP 100、HP 40
防御側: HP 80（反射50%）

1. 攻撃: 100ダメージ
2. 反射: 50ダメージ返す
3. 防御側HP: 80 - 50 = 30（生存）
4. 攻撃側HP: 40 - 50 = -10（死亡）

→ 防御側の勝利
```

#### 実装クリーチャー（2体）

| ID | 名前 | 属性 | AP | HP | スキル | 効果 |
|----|------|------|----|----|--------|------|
| 426 | デコイ | 無 | 0 | 10 | 反射[通常攻撃] | 通常攻撃100%反射 |
| 25 | ナイトエラント | 火 | 40 | 30 | 合成・反射[1/2] | 通常攻撃50%反射 |

**注意**: ナイトエラントは合成後に変身するため、変身後は反射スキルを失う。

#### 実装アイテム（4個）

| ID | 名前 | タイプ | 効果 | 詳細 |
|----|------|--------|------|------|
| 1025 | スパイクシールド | 防具 | 反射[1/2] | 通常攻撃50%反射 |
| 1066 | ミラーホブロン | 防具 | 敵アイテム未使用時、反射[全] | 条件付き：通常・巻物100%反射 |
| 1068 | ムラサメ | 武器 | ST+20；反射無効 | 相手の反射を無効化 |
| 1069 | メイガスミラー | アクセサリ | HP+20；反射[巻物] | 巻物攻撃100%反射 |

#### ability_parsed定義

##### 反射100%（通常攻撃）- デコイ
```json
{
  "ability": "反射",
  "ability_detail": "反射[通常攻撃]",
  "ability_parsed": {
	"keywords": ["反射"],
	"effects": [
	  {
		"effect_type": "reflect_damage",
		"reflect_ratio": 1.0,
		"self_damage_ratio": 0.0,
		"attack_types": ["normal"],
		"triggers": ["on_damaged"]
	  }
	]
  }
}
```

##### 反射50%（通常攻撃）- ナイトエラント、スパイクシールド
```json
{
  "ability": "反射",
  "ability_detail": "反射[1/2]",
  "ability_parsed": {
	"keywords": ["反射"],
	"effects": [
	  {
		"effect_type": "reflect_damage",
		"reflect_ratio": 0.5,
		"self_damage_ratio": 0.5,
		"attack_types": ["normal"],
		"triggers": ["on_damaged"]
	  }
	]
  }
}
```

##### 反射100%（巻物攻撃）- メイガスミラー
```json
{
  "ability": "反射[巻物]",
  "ability_detail": "反射[巻物]",
  "ability_parsed": {
	"keywords": ["反射[巻物]"],
	"effects": [
	  {
		"effect_type": "reflect_damage",
		"reflect_ratio": 1.0,
		"self_damage_ratio": 0.0,
		"attack_types": ["scroll"],
		"triggers": ["on_damaged"]
	  }
	]
  }
}
```

##### 反射100%（全攻撃）- ミラーホブロン
```json
{
  "ability": "反射[全]",
  "ability_detail": "敵アイテム未使用時、反射[全]",
  "ability_parsed": {
	"keywords": ["反射[全]"],
	"effects": [
	  {
		"effect_type": "reflect_damage",
		"reflect_ratio": 1.0,
		"self_damage_ratio": 0.0,
		"attack_types": ["normal", "scroll"],
		"triggers": ["on_damaged"],
		"conditions": [
		  {
			"condition_type": "enemy_no_item"
		  }
		]
	  }
	]
  }
}
```

##### 反射無効 - ムラサメ
```json
{
  "ability": "反射無効",
  "ability_detail": "ST+20；反射無効",
  "ability_parsed": {
	"keywords": ["反射無効"],
	"effects": [
	  {
		"effect_type": "nullify_reflect",
		"triggers": ["before_attack"]
	  }
	]
  }
}
```

#### 処理フロー

```
1. 攻撃判定
2. 攻撃側の「反射無効」チェック
   - あり → 反射スキップ、通常ダメージ
   - なし → 3へ
3. 防御側の反射スキルチェック
   - なし → 通常ダメージ
   - あり → 4へ
4. 攻撃タイプと反射タイプの一致確認
   - 不一致 → 通常ダメージ
   - 一致 → 5へ
5. 反射条件チェック（条件付き反射の場合）
   - 条件不成立 → 通常ダメージ
   - 条件成立 → 6へ
6. 反射ダメージ計算
   - 防御側が受けるダメージ = 元ダメージ × self_damage_ratio
   - 攻撃側が受けるダメージ = 元ダメージ × reflect_ratio
7. 勝敗判定
```

#### 戦略的価値

- **低HP防御**: デコイ（HP10）でも大型クリーチャーを倒せる
- **先制対策**: 先制攻撃を反射で返せる
- **巻物対策**: メイガスミラーで巻物攻撃を防げる
- **反射メタ**: ムラサメで反射戦略を封じられる

---

### 実装完了（2025年10月23日）

#### 実装内容

**コード実装:**
1. `BattleSkillProcessor.gd`: 反射判定関数5個追加
   - `check_reflect_damage()`: メイン反射処理
   - `_has_nullify_reflect()`: 反射無効チェック
   - `_get_reflect_effect()`: 反射スキル取得
   - `_check_reflect_conditions()`: 条件判定
   - `_build_reflect_context()`: コンテキスト構築

2. `BattleExecution.gd`: ダメージ処理に反射統合
   - 通常ダメージ処理に反射適用
   - 軽減ダメージ処理に反射適用
   - 反射ダメージで攻撃側撃破判定追加

3. `BattlePreparation.gd`: **アイテムスキルシステム実装（初実装）**
   - アイテムデータを`creature_data["items"]`配列に追加
   - `effect_parsed`の`stat_bonus`と`effects`両方を処理
   - 反射・反射無効は`BattleExecution`で処理するためスキップ

**データ追加:**
- `neutral_1.json`: デコイに`ability_parsed`追加
- `fire_1.json`: ナイトエラントに`ability_parsed`更新
- `item.json`: 4アイテムに`effect_parsed`更新

#### テスト結果

✅ **スパイクシールド（反射50%）**: 動作確認完了
```
攻撃側: AP 100
防御側: スパイクシールド装備

結果:
- 防御側が受けるダメージ: 50
- 攻撃側が受ける反射ダメージ: 50
→ 正常動作
```

#### 重要な実装ポイント

1. **アイテムスキルの初実装**
   - これまでアイテムはステータスボーナス（ST+20、HP+20）のみ
   - 今回初めて戦闘中に発動するスキル（反射）を実装
   - `BattlePreparation`でアイテムを`items`配列に追加
   - `BattleSkillProcessor`でアイテムの`effect_parsed`を読み取り

2. **effect_parsedの二段階処理**
   - `stat_bonus`: バトル準備時に適用（ST+20、HP+20）
   - `effects`: バトル中に処理（reflect_damage、nullify_reflect）

3. **型宣言の修正**
   - GDScriptでは`-> Dictionary`宣言時に`null`を返せないため型宣言を削除

---

## 8. アイテム破壊・盗みスキル

#### 概要
戦闘開始前に相手のアイテムを破壊または奪うスキル。アイテムに依存する戦略を無効化できる強力な妨害スキル。

#### 発動タイミング
**戦闘開始前** - ダメージ計算の前
- 先制攻撃の順序判定に従って発動順を決定
- 両者がアイテム破壊/盗みを持つ場合、先に動く側が優先

#### アイテム破壊

##### 概要
相手のアイテムを破壊（消滅）させる。相手は今回の戦闘でアイテムなしで戦う。

##### 破壊対象の種類

| 表記 | 破壊対象 |
|------|---------|
| アイテム破壊[道具] | 道具タイプのアイテムのみ |
| アイテム破壊[道具か巻物か援護クリーチャー] | 道具、巻物、援護クリーチャーのいずれか |

**注意**: 援護クリーチャーは援護スキルで装備されたクリーチャー

##### 実装クリーチャー（3体）

| ID | 名前 | 属性 | AP/HP | スキル | 破壊対象 |
|----|------|------|-------|--------|---------|
| 313 | グレムリン | 風 | 20/30 | アイテム破壊[道具] | 道具のみ |
| 116 | カイザーペンギン | 水 | 30/50 | アイテム破壊[道具か巻物か援護クリーチャー] | 道具・巻物・援護 |
| 220 | シルバンダッチェス | 地 | 50/50 | 援護[地]；アイテム破壊[道具か巻物か援護クリーチャー]；再生 | 道具・巻物・援護 |

##### ability_parsed定義

**アイテム破壊[道具]**
```json
{
  "ability": "アイテム破壊",
  "ability_detail": "アイテム破壊[道具]",
  "ability_parsed": {
	"keywords": ["アイテム破壊"],
	"effects": [
	  {
		"effect_type": "destroy_item",
		"target_types": ["道具"],
		"triggers": ["before_battle"]
	  }
	]
  }
}
```

**アイテム破壊[道具か巻物か援護クリーチャー]**
```json
{
  "ability": "アイテム破壊",
  "ability_detail": "アイテム破壊[道具か巻物か援護クリーチャー]",
  "ability_parsed": {
	"keywords": ["アイテム破壊"],
	"effects": [
	  {
		"effect_type": "destroy_item",
		"target_types": ["道具", "巻物", "援護クリーチャー"],
		"triggers": ["before_battle"]
	  }
	]
  }
}
```

#### アイテム盗み

##### 概要
相手のアイテムを奪って自分が使用する。**自分がアイテムを使用していない場合のみ発動可能**。

##### 発動条件
1. 自分がアイテムを使用していない
2. 相手がアイテムを使用している

##### 効果
- 相手のアイテムを奪う
- 奪ったアイテムの効果を自分が得る（ST/HPボーナス、スキルなど）
- 相手はアイテムなしで戦う

##### 実装クリーチャー（1体）

| ID | 名前 | 属性 | AP/HP | スキル |
|----|------|------|-------|--------|
| 416 | シーフ | 無 | 20/40 | アイテム盗み |

##### ability_parsed定義

```json
{
  "ability": "アイテム盗み",
  "ability_detail": "アイテム盗み",
  "ability_parsed": {
	"keywords": ["アイテム盗み"],
	"effects": [
	  {
		"effect_type": "steal_item",
		"triggers": ["before_battle"],
		"conditions": [
		  {
			"condition_type": "self_no_item"
		  }
		]
	  }
	]
  }
}
```

#### アイテム破壊・盗み無効

##### 概要
相手のアイテム破壊・盗みスキルを無効化する。

##### 実装クリーチャー（1体）

| ID | 名前 | 属性 | AP/HP | スキル |
|----|------|------|-------|--------|
| 226 | セージ | 地 | 20/30 | 援護；アイテム破壊・盗み無効；巻物強打 |

##### ability_parsed定義

```json
{
  "ability": "アイテム破壊・盗み無効",
  "ability_detail": "援護；アイテム破壊・盗み無効；巻物強打",
  "ability_parsed": {
	"keywords": ["援護", "巻物強打"],
	"effects": [
	  {
		"effect_type": "nullify_item_manipulation",
		"triggers": ["before_battle"]
	  }
	],
	"keyword_conditions": {
	  "巻物強打": {
		"scroll_type": "base_st"
	  }
	}
  }
}
```

#### 処理フロー

```
1. 戦闘開始前処理
2. 先制攻撃の順序で行動順を決定
3. 先に動く側のアイテム破壊・盗みチェック
   ├─ 相手が「アイテム破壊・盗み無効」を持つ → スキップ
   ├─ アイテム破壊の場合 → 4-Aへ
   └─ アイテム盗みの場合 → 4-Bへ
4-A. アイテム破壊処理
   ├─ 相手のアイテムタイプをチェック
   ├─ 破壊対象に一致するか確認
   ├─ 一致する場合、相手のアイテムを破壊（消滅）
   └─ 相手のアイテム効果を無効化
4-B. アイテム盗み処理
   ├─ 自分がアイテムを使用していないか確認
   │  └─ 使用している → スキップ
   ├─ 相手のアイテムを奪う
   ├─ 奪ったアイテムの効果を自分に適用
   └─ 相手のアイテム効果を無効化
5. 後に動く側のアイテム破壊・盗みチェック（同様）
6. ダメージ計算開始
```

#### 戦略的価値

- **アイテム依存戦略の破壊**: スパイクシールド、メイガスミラーなどの強力アイテムを無効化
- **コスト効率**: 低コストクリーチャー（グレムリン20/30、シーフ20/40）で高価なアイテムを無効化できる
- **盗みの二重効果**: 相手のアイテムを奪って自分が使うため、戦力差が大きく開く
- **メタ対策**: セージで破壊・盗み戦略を封じられる

#### 実装時の注意点

1. **援護クリーチャーの扱い**: 援護スキル実装後に対応
2. **複数アイテムの扱い**: 現状は1個のみだが、将来の拡張に備えた設計
3. **盗んだアイテムの管理**: BattleParticipantのitem配列の操作
4. **無効化の優先順位**: 反射無効と同様、before_battleで処理

---

## 将来実装予定のスキル

### 1. 反撃スキル

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

### 2. 回復スキル

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

### 3. スペル反射スキル

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

---

**最終更新**: 2025年10月24日（v1.6）
