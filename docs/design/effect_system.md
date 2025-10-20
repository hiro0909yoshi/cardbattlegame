# 効果システム実装仕様書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 3.0  
**作成日**: 2025年10月21日  
**更新日**: 2025年10月21日  
**ステータス**: Phase 1-2完了、Phase 3部分完了

---

## 📋 目次

1. [概要](#概要)
2. [効果の種類と持続期間](#効果の種類と持続期間)
3. [データ構造設計](#データ構造設計)
4. [HP/AP管理構造](#hpap管理構造)
5. [効果の適用順序](#効果の適用順序)
6. [実装方針](#実装方針)
7. [実装フェーズ](#実装フェーズ)

---

## 概要

### 目的
アイテム、スペル、クリーチャースキルによる様々な効果を統一的に管理するシステムを実装する。

### 設計方針
- **効果の分離管理**: バトル中の一時効果と永続効果を分けて管理
- **動的計算**: バトル時に毎回効果を計算（既存方式を踏襲）
- **効果の保持**: 打ち消し効果に対応するため、効果配列を保持
- **拡張性の確保**: 将来的な新効果の追加が容易

### 重要な仕様決定
- **移動で消える効果**: 領地コマンドでクリーチャーが移動したときに消える
- **合成効果**: `base_up_hp/ap`で特別扱い（打ち消し不可）
- **スペル効果の重複**: 基本的に上書き（以前の同名効果は削除）
- **効果ID管理**: `source_name`で同一スペルを判定

---

## 効果の種類と持続期間

### 1. バトル中のみの効果
**例**: アイテム「ロングソード」使用でAP+30

- **持続期間**: バトル開始〜バトル終了
- **管理場所**: `BattleParticipant.item_bonus_ap`
- **削除タイミング**: バトル終了時に自動削除
- **実装**: バトル準備フェーズで選択、効果を適用

---

### 2. スペルによる一時的な効果（移動で消える）
**例**: スペル「ブレッシング」でHP+10

- **持続期間**: 効果付与〜クリーチャー移動まで
- **管理場所**: `creature_data["temporary_effects"]`
- **削除タイミング**: 領地コマンドでのクリーチャー移動時、交換時
- **上書き仕様**: 同じスペルを再使用すると前の効果を削除

```gdscript
creature_data["temporary_effects"] = [
    {
        "id": "blessing_002",
        "type": "stat_bonus",
        "stat": "hp",
        "value": 10,
        "source": "spell",
        "source_name": "ブレッシング",
        "removable": true,
        "lost_on_move": true
    }
]
```

---

### 3. 条件付き効果（バトル時に動的計算）

#### 3-1. 土地保有数による効果
**例**: 「火土地を3つ以上保有している場合、AP+30」

- **管理場所**: `ability_parsed` の conditions
- **適用タイミング**: バトル開始時に毎回チェック
- **実装**: 既存のConditionCheckerシステムを使用

#### 3-2. 土地の保有数比例効果
**例**: 「火土地1つごとにAP+10」

- **計算方法**: 毎バトル時に動的計算
- **実装**: 感応スキルと同様の処理

#### 3-3. 隣接条件効果
**例**: 「隣接に自領地がある場合、AP+20、HP+20」

- **実装**: 既存の強打スキルシステムと同様
- **適用タイミング**: バトル開始時に条件チェック

---

### 4. マップ周回で上昇する効果
**例**: キメラ「マップを1周したらAP+10」

- **カウント管理**: `creature_data["map_lap_count"]`
- **適用方法**: permanent_effectsに追加
- **永続性**: 移動しても維持、交換で消える

```gdscript
creature_data["map_lap_count"] = 2  # 周回数カウント
creature_data["permanent_effects"].append({
    "id": "lap_bonus_003",
    "type": "stat_bonus",
    "stat": "ap",
    "value": 10,
    "source": "map_lap",
    "removable": false,
    "lost_on_move": false
})
```

---

### 5. スキル「合成」による永続的な効果
**例**: 合成[地]を持つカードを生贄にして召喚

- **適用タイミング**: 召喚時
- **永続性**: 交換で消える、打ち消し不可
- **実装方法**: `base_up_hp/ap`に直接加算（特別扱い）

```gdscript
# 合成効果はbase_up_hp/apで管理（打ち消し不可）
creature_data["base_up_hp"] = 10  # 合成によるHP上昇
creature_data["base_up_ap"] = 20  # 合成によるAP上昇
```

---

### 6. スペルによる永続的な効果

#### 6-1. マスグロース、ドミナントグロース
**例**: スペル「マスグロース」全クリーチャーのMHP+5

- **管理場所**: `base_up_hp`に加算（合成と同じ扱い）
- **削除タイミング**: 打ち消し効果でも消えない
- **適用対象**: 全自クリーチャー

```gdscript
# マスグロース効果はbase_up_hpで管理
for tile in board_system.get_player_tiles(player_id):
    if tile.creature_data:
        tile.creature_data["base_up_hp"] = tile.creature_data.get("base_up_hp", 0) + 5
```

#### 6-2. その他の永続スペル効果
**例**: 永続的な能力付与など

- **管理場所**: `creature_data["permanent_effects"]`
- **削除タイミング**: 打ち消し効果、交換時

---

## データ構造設計

### creature_dataの拡張構造

```gdscript
{
    "id": 1,
    "name": "アモン",
    "hp": 30,           # 元の基礎HP
    "ap": 20,           # 元の基礎AP
    "element": "fire",
    "ability_parsed": {...},  # スキル定義（既存）
    
    # 合成・マスグロース用（打ち消し不可）
    "base_up_hp": 0,    # 永続的な基礎HP上昇
    "base_up_ap": 0,    # 永続的な基礎AP上昇
    
    # 永続的な効果（移動で消えない、交換で消える）
    "permanent_effects": [
        {
            "id": "effect_001",
            "type": "stat_bonus",
            "stat": "hp",
            "value": 20,
            "source": "spell",
            "source_name": "強化呪文",
            "removable": true,        # 打ち消し効果で消せるか
            "lost_on_move": false     # 移動で消えるか
        }
    ],
    
    # 一時的な効果（移動で消える）
    "temporary_effects": [
        {
            "id": "blessing_003",
            "type": "stat_bonus",
            "stat": "hp",
            "value": 10,
            "source": "spell",
            "source_name": "ブレッシング",
            "removable": true,
            "lost_on_move": true
        }
    ],
    
    # マップ周回カウント（キメラ等）
    "map_lap_count": 0
}
```

### effectオブジェクトの構造

```gdscript
{
    "id": "unique_id_string",         # 一意のID
    "type": "stat_bonus",              # 効果タイプ
    "stat": "hp",                      # 対象ステータス（hp/ap）
    "value": 10,                       # 効果値
    "source": "spell",                 # 発生源（spell/item/skill/synthesis）
    "source_name": "ブレッシング",      # 効果名（UI表示用、重複判定用）
    "removable": true,                 # 打ち消し効果で消せるか
    "lost_on_move": false              # 移動で消えるか
}
```

---

## HP/AP管理構造

### BattleParticipantの拡張構造

```gdscript
class BattleParticipant:
    # 基礎値（既存）
    var base_hp: int              # 元のHP（カードデータの値）
    var base_ap: int              # 元のAP
    
    # 永続的な基礎上昇（新規追加）
    var base_up_hp: int = 0       # 合成・マスグロース等（打ち消し不可）
    var base_up_ap: int = 0       
    
    # バトル中の一時ボーナス（一部既存、一部新規）
    var temporary_bonus_hp: int = 0   # 一時的なHPボーナス（新規）
    var temporary_bonus_ap: int = 0   # 一時的なAPボーナス（新規）
    var resonance_bonus_hp: int = 0   # 感応ボーナス（既存）
    var land_bonus_hp: int = 0        # 土地ボーナス（既存）
    var item_bonus_hp: int = 0        # アイテムボーナス（既存）
    var item_bonus_ap: int = 0        # アイテムボーナス（既存）
    var spell_bonus_hp: int = 0       # スペルボーナス（既存）
    
    # 効果配列の参照（新規追加）
    var permanent_effects: Array = []  # バトル中も保持
    var temporary_effects: Array = []  # バトル中も保持
    
    # 計算後の値
    var current_hp: int
    var current_ap: int
```

### HP/APの計算式

```gdscript
# HP計算
current_hp = base_hp + 
             base_up_hp +           # 合成・マスグロース
             temporary_bonus_hp +   # 一時効果の合計
             land_bonus_hp + 
             resonance_bonus_hp + 
             item_bonus_hp +
             spell_bonus_hp

# AP計算
current_ap = base_ap + 
             base_up_ap +           # 合成・マスグロース
             temporary_bonus_ap +   # 一時効果の合計
             item_bonus_ap + 
             (感応AP) + 
             (条件効果AP)
# その後、強打で乗算
```

### ダメージ消費順序（既存仕様）

```
1. resonance_bonus_hp（感応ボーナス）
2. land_bonus_hp（土地ボーナス）
3. temporary_bonus_hp（一時ボーナス）
4. item_bonus_hp（アイテムボーナス）
5. spell_bonus_hp（スペルボーナス）
6. base_up_hp（永続的な基礎HP上昇）
7. base_hp（元のHP）
```

---

## 効果の適用順序

### バトル時の計算順序

```gdscript
# バトル準備時の処理
func prepare_battle_participant(creature_data, tile_data):
    # 1. 基礎値を設定
    participant.base_hp = creature_data["hp"]
    participant.base_ap = creature_data["ap"]
    
    # 2. base_up_hp/apを適用（合成・マスグロース）
    participant.base_up_hp = creature_data.get("base_up_hp", 0)
    participant.base_up_ap = creature_data.get("base_up_ap", 0)
    
    # 3. 効果配列を保持（打ち消し効果判定用）
    participant.permanent_effects = creature_data.get("permanent_effects", [])
    participant.temporary_effects = creature_data.get("temporary_effects", [])
    
    # 4. permanent_effectsから効果を計算
    for effect in participant.permanent_effects:
        if effect["stat"] == "hp":
            participant.temporary_bonus_hp += effect["value"]
        elif effect["stat"] == "ap":
            participant.temporary_bonus_ap += effect["value"]
    
    # 5. temporary_effectsから効果を計算
    for effect in participant.temporary_effects:
        if effect["stat"] == "hp":
            participant.temporary_bonus_hp += effect["value"]
        elif effect["stat"] == "ap":
            participant.temporary_bonus_ap += effect["value"]
    
    # 6. 土地ボーナス（既存処理）
    participant.land_bonus_hp = tile.level * 10
    
    # 7. アイテム効果（バトル準備フェーズで選択）
    if selected_item:
        participant.item_bonus_ap = selected_item.ap_bonus
        participant.item_bonus_hp = selected_item.hp_bonus
    
    # 8. 感応効果（既存処理）
    apply_resonance_skill(participant, context)
    
    # 9. その他の条件効果
    # （土地保有数、隣接条件など）
    
    # 10. 強打を適用（最後）
    if has_power_strike:
        participant.current_ap *= 1.5
```

---

## 実装方針

### 基本方針

1. **既存構造の活用**
   - BattleParticipantの拡張（EffectManagerは作らない）
   - creature_dataに効果配列を追加
   - バトル時の動的計算を維持

2. **効果の管理**
   - 各タイルのcreature_dataで効果を管理
   - バトル時に効果配列を保持（打ち消し判定用）
   - 効果IDは`source_name`で重複判定

3. **段階的実装**
   - 簡単な効果から順次実装
   - 既存システムとの統合を重視

### 効果の追加処理

```gdscript
# スペル効果の追加（上書き処理あり）
func add_spell_effect(creature_data: Dictionary, effect: Dictionary):
    var effects_array = "temporary_effects" if effect.get("lost_on_move", true) else "permanent_effects"
    
    # 同名効果を削除（上書き）
    var new_effects = []
    for existing_effect in creature_data.get(effects_array, []):
        if existing_effect.get("source_name") != effect.get("source_name"):
            new_effects.append(existing_effect)
    
    # 新しい効果を追加
    effect["id"] = generate_unique_id()
    new_effects.append(effect)
    creature_data[effects_array] = new_effects
```

### クリーチャー移動時の処理

```gdscript
# 領地コマンドでのクリーチャー移動時
func on_creature_move(tile_index: int):
    var creature_data = tile.creature_data
    if creature_data:
        # temporary_effectsをクリア（移動で消える効果）
        creature_data["temporary_effects"] = []
        # permanent_effectsは維持
```

---

## 実装フェーズ

### Phase 1: 基盤構築（最優先）

1. **creature_dataの拡張**
   - base_up_hp/apフィールド追加
   - permanent_effects配列追加
   - temporary_effects配列追加
   - map_lap_countフィールド追加

2. **BattleParticipantの改修**
   - base_up_hp/apフィールド追加
   - temporary_bonus_hp/apフィールド追加
   - 効果配列の参照を保持
   - 効果計算ロジックの実装

3. **基本的な効果追加・削除処理**
   - スペル効果の追加（上書き処理付き）
   - 移動時の効果削除処理

### Phase 2: 基本効果の実装

1. **アイテム効果**
   - バトル準備フェーズとの統合
   - ロングソード等のAP+効果実装

2. **スペル効果（一時的）**
   - ブレッシング（HP+10、移動で消える）
   - 効果の上書き処理

3. **スペル効果（永続的）**
   - マスグロース（base_up_hp使用）
   - ドミナントグロース

### Phase 3: 条件付き効果

1. **土地保有数効果**
   - 動的計算の実装
   - ConditionCheckerとの統合

2. **隣接条件効果**
   - 既存システムの活用

### Phase 4: 高度な効果（後回し）

1. **マップ周回効果**（キメラ等）
2. **合成効果**
3. **打ち消し効果**
4. **世界呪**

---

## テスト計画

### Phase 1テスト
- creature_dataへの効果配列追加確認
- BattleParticipantでの効果計算確認

### Phase 2テスト
- アイテム「ロングソード」でAP+30確認
- スペル「ブレッシング」でHP+10確認
- 同じスペルの上書き確認
- クリーチャー移動時の効果削除確認

### Phase 3テスト
- マスグロース効果の永続性確認
- 条件付き効果の動的計算確認

---

## 実装完了状況

### ✅ Phase 1: 基盤構築（完了）

1. **creature_dataの拡張** - `base_tiles.gd`
   - `base_up_hp/ap`フィールド ✅
   - `permanent_effects`配列 ✅
   - `temporary_effects`配列 ✅
   - `map_lap_count`フィールド ✅

2. **BattleParticipantの改修** - `battle_participant.gd`
   - 新フィールドの追加 ✅
   - HP/AP計算式の更新 ✅
   - ダメージ消費順序の調整 ✅

3. **バトル準備時の効果計算** - `battle_preparation.gd`
   - `apply_effect_arrays()`メソッド ✅
   - 効果配列からのボーナス計算 ✅

### ✅ Phase 2: 基本効果の実装（完了）

4. **効果管理メソッド** - `battle_system.gd`
   - `add_spell_effect_to_creature()` ✅
   - `apply_mass_growth()` ✅
   - `apply_dominant_growth()` ✅
   - `clear_temporary_effects_on_move()` ✅
   - `remove_effects_from_creature()` ✅

5. **バトルテストツールの対応** - `battle_test_executor.gd`
   - `_get_effect_info()`メソッド ✅
   - 効果情報の記録 ✅

### ✅ Phase 3: 条件付き効果（部分完了）

6. **土地数比例効果** - `battle_skill_processor.gd`
   - `apply_land_count_effects()` ✅
   - 複数属性の土地数合計に対応 ✅
   - HP/AP両方に対応 ✅

**実装例**: アームドパラディン
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

### 🚧 Phase 3: 未完了

- 隣接条件効果（実装準備中）
- マップ周回効果（実装準備中）

### 🚧 Phase 4: 高度な効果（未実装）

- 合成効果
- 世界呪
- より複雑な条件判定

---

## 実装されたカード例

### クリーチャー

**アームドパラディン** (`data/fire_1.json`)
```json
{
  "id": 1,
  "name": "アームドパラディン",
  "ap": 0,
  "hp": 50,
  "ability_detail": "ST=火地,配置数×10；無効化[巻物]",
  "ability_parsed": {
    "keywords": ["無効化"],
    "keyword_conditions": {
      "無効化": {
        "nullify_type": "scroll_attack"
      }
    },
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

**動作例**:
- 火土地2つ + 土土地3つ = 5つ所有
- ST = 0 + (5 × 10) = **50**

### アイテム

**アーメット** (`data/item.json`)
```json
{
  "id": 1001,
  "name": "アーメット",
  "effect": "ST-10；HP+40",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "debuff_ap",
        "value": 10
      },
      {
        "effect_type": "buff_hp",
        "value": 40
      }
    ]
  }
}
```

**動作例**:
- アモン（ST=30, HP=30）が装備
- ST: 30 - 10 = **20**
- HP: 30 + 40 = **70**

---

## 使用方法

### スペル効果の追加

```gdscript
# ブレッシング（HP+10、移動で消える）
battle_system.add_spell_effect_to_creature(tile_index, {
    "type": "stat_bonus",
    "stat": "hp",
    "value": 10,
    "source": "spell",
    "source_name": "ブレッシング",
    "removable": true,
    "lost_on_move": true
})
```

### マスグロース

```gdscript
# プレイヤー0の全クリーチャーのMHP+5
var affected = battle_system.apply_mass_growth(0, 5)
print("影響を受けたクリーチャー: ", affected, "体")
```

### ドミナントグロース

```gdscript
# プレイヤー1の火属性クリーチャーのみMHP+10
var affected = battle_system.apply_dominant_growth(1, "fire", 10)
```

### 移動時の効果削除

```gdscript
# クリーチャー移動時に一時効果をクリア
battle_system.clear_temporary_effects_on_move(tile_index)
```

### 打ち消し効果

```gdscript
# removable=trueの効果をすべて削除
var removed = battle_system.remove_effects_from_creature(tile_index, true)
```

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/21 | 1.0 | 初版作成 - effect_system_design.mdから作成 |
| 2025/10/21 | 2.0 | 実装仕様確定 - 質疑応答を反映、実装準備完了 |
| 2025/10/21 | 3.0 | Phase 1-2完了、Phase 3部分完了を記録 ||## 実装完了状況

### ✅ Phase 1: 基盤構築（完了）

1. **creature_dataの拡張** - `base_tiles.gd`
   - `base_up_hp/ap`フィールド ✅
   - `permanent_effects`配列 ✅
   - `temporary_effects`配列 ✅
   - `map_lap_count`フィールド ✅

2. **BattleParticipantの改修** - `battle_participant.gd`
   - 新フィールドの追加 ✅
   - HP/AP計算式の更新 ✅
   - ダメージ消費順序の調整 ✅

3. **バトル準備時の効果計算** - `battle_preparation.gd`
   - `apply_effect_arrays()`メソッド ✅
   - 効果配列からのボーナス計算 ✅

### ✅ Phase 2: 基本効果の実装（完了）

4. **効果管理メソッド** - `battle_system.gd`
   - `add_spell_effect_to_creature()` ✅
   - `apply_mass_growth()` ✅
   - `apply_dominant_growth()` ✅
   - `clear_temporary_effects_on_move()` ✅
   - `remove_effects_from_creature()` ✅

5. **バトルテストツールの対応** - `battle_test_executor.gd`
   - `_get_effect_info()`メソッド ✅
   - 効果情報の記録 ✅

### ✅ Phase 3: 条件付き効果（部分完了）

6. **土地数比例効果** - `battle_skill_processor.gd`
   - `apply_land_count_effects()` ✅
   - 複数属性の土地数合計に対応 ✅
   - HP/AP両方に対応 ✅

**実装例**: アームドパラディン
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

### 🚧 Phase 3: 未完了

- 隣接条件効果（実装準備中）
- マップ周回効果（実装準備中）

### 🚧 Phase 4: 高度な効果（未実装）

- 合成効果
- 世界呪
- より複雑な条件判定

---

## 実装されたカード例

### クリーチャー

**アームドパラディン** (`data/fire_1.json`)
```json
{
  "id": 1,
  "name": "アームドパラディン",
  "ap": 0,
  "hp": 50,
  "ability_detail": "ST=火地,配置数×10；無効化[巻物]",
  "ability_parsed": {
    "keywords": ["無効化"],
    "keyword_conditions": {
      "無効化": {
        "nullify_type": "scroll_attack"
      }
    },
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

**動作例**:
- 火土地2つ + 土土地3つ = 5つ所有
- ST = 0 + (5 × 10) = **50**

### アイテム

**アーメット** (`data/item.json`)
```json
{
  "id": 1001,
  "name": "アーメット",
  "effect": "ST-10；HP+40",
  "ability_parsed": {
    "effects": [
      {
        "effect_type": "debuff_ap",
        "value": 10
      },
      {
        "effect_type": "buff_hp",
        "value": 40
      }
    ]
  }
}
```

**動作例**:
- アモン（ST=30, HP=30）が装備
- ST: 30 - 10 = **20**
- HP: 30 + 40 = **70**

---

## 使用方法

### スペル効果の追加

```gdscript
# ブレッシング（HP+10、移動で消える）
battle_system.add_spell_effect_to_creature(tile_index, {
    "type": "stat_bonus",
    "stat": "hp",
    "value": 10,
    "source": "spell",
    "source_name": "ブレッシング",
    "removable": true,
    "lost_on_move": true
})
```

### マスグロース

```gdscript
# プレイヤー0の全クリーチャーのMHP+5
var affected = battle_system.apply_mass_growth(0, 5)
print("影響を受けたクリーチャー: ", affected, "体")
```

### ドミナントグロース

```gdscript
# プレイヤー1の火属性クリーチャーのみMHP+10
var affected = battle_system.apply_dominant_growth(1, "fire", 10)
```

### 移動時の効果削除

```gdscript
# クリーチャー移動時に一時効果をクリア
battle_system.clear_temporary_effects_on_move(tile_index)
```

### 打ち消し効果

```gdscript
# removable=trueの効果をすべて削除
var removed = battle_system.remove_effects_from_creature(tile_index, true)
```

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/21 | 1.0 | 初版作成 - effect_system_design.mdから作成 |
| 2025/10/21 | 2.0 | 実装仕様確定 - 質疑応答を反映、実装準備完了 |
| 2025/10/21 | 3.0 | Phase 1-2完了、Phase 3部分完了を記録 ||---------|
| 2025/10/21 | 1.0 | 初版作成 - effect_system_design.mdから作成 |
| 2025/10/21 | 2.0 | 実装仕様確定 - 質疑応答を反映、実装準備完了 |

---

**最終更新**: 2025年10月21日（v2.0）
