# 🎮 アイテムシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**最終更新**: 2025年10月25日

---

## 🆕 アイテムシステム（Phase 1-A）

### 概要

バトル前にアイテムカードを使用して、クリーチャーを強化できるシステム。

### 関連スキル・システム

- **[巻物攻撃スキル](skills/scroll_attack_skill.md)** - 巻物アイテムを使用した特殊攻撃
- **[アイテム破壊・盗みスキル](skills/item_destruction_theft_skill.md)** - 相手のアイテムを破壊または奪うスキル

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
