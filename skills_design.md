# 🎮 スキルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**最終更新**: 2025年1月12日

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

### 5. 防魔スキル

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

### 6. ST変動スキル

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
   
3. その他スキル（将来実装）
   ├─ 先制判定（既に完了）
   ├─ 防魔判定（スペル時）
   └─ 連撃準備（未実装）
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

---

**最終更新**: 2025年1月12日（v1.0）
