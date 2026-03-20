# 🎮 アイテムシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.2  
**最終更新**: 2025年12月23日

---## 📝 実装チェックリスト

### 武器 (26個)

- [+] 1000: アージェントキー - AP+10；先制；攻撃で敵非破壊時、使用クリーチャーはランダムな空地に飛ぶ
- [x] 1003: イーグルレイピア - AP+30；先制
- [x] 1008: カタパルト - AP+30；HP+30
- [x] 1009: クレイモア - AP+50
- [x] 1012: ゴールドハンマー - AP+40；攻撃で敵非破壊時、蓄魔[200EP]
- [x] 1014: シェイドクロー - AP+敵と同属性の配置数×10
- [x] 1020: ストームコーザー - AP+60；HP-30
- [x] 1022: ストームスピア - AP+20；水風使用時、強化
- [x] 1023: ストームハルバード - AP+水風配置数×5；強化[火地]
- [x] 1034: チェーンソー - AP+戦闘地の連鎖数×20
- [x] 1040: ガントレットソード - AP+40；HP+20
- [x] 1042: ドリルランス - AP+20；刺突
- [x] 1043: トンファ - 2回攻撃
- [x] 1044: ナパームアロー - AP+30；HP+20；報復[敵のMHP-40]
- [x] 1050: バインドウィップ - AP+30；攻撃成功時、敵に刻印"消沈"
- [x] 1051: バタリングラム - AP+30；即死[堅守]
- [x] 1053: バトルアックス - AP+40
- [x] 1054: ブーメラン - AP+20；HP+10；復帰[手札]
- [x] 1056: ブラックソード - AP+40；レア度Nが使用時、強化
- [x] 1057: プリズムワンド - 敵と属性が違う場合、AP&HP+40
- [x] 1060: ボーパルソード - AP+30；強化[MHP40以上]
- [x] 1063: マグマハンマー - AP+20；火地使用時、強化
- [x] 1064: マグマフレイル - AP+火地配置数×5；強化[水風]
- [x] 1067: ムーンシミター - AP+30；攻撃成功時、敵に刻印"免罪"
- [x] 1068: ムラサメ - AP+20；敵の攻撃無効化・反射無効
- [x] 1070: メイス - AP+20
- [x] 1073: ロングソード - AP+30

### 防具 (20個)

- [x] 1001: アーメット - AP-|AP&|AP=|AP 10；HP+40
- [x] 1002: アングリーマスク - HP+30；追加ダメージ[自分が受けたダメージ]
- [x] 1005: エターナルメイル - HP+40；復帰[ブック]
- [x] 1006: エンジェルケープ - HP+40；アイテム破壊・盗み無効
- [x] 1017: スクイドマントル - HP+40；敵の攻撃成功時能力無効
- [x] 1018: スケールアーマー - HP+40
- [x] 1019: ストームアーマー - HP+水風自ドミニオ数×20
- [x] 1021: ストームシールド - 水風使用時、無効化[通常攻撃]
- [x] 1025: スパイクシールド - 反射[1/2]
- [x] 1026: スフィアシールド - AP=0；無効化[通常攻撃]
- [x] 1027: スペクターローブ - AP&HP+10~70
- [x] 1029: ゼラチンアーマー - HP+40；蓄魔[受けたダメージ×5EP]
- [x] 1032: ダイヤアーマー - AP-|AP&|AP=|AP 30；HP+60；後手
- [x] 1033: チェインメイル - HP+30
- [x] 1045: ニュートラルクローク - HP+40；属性変化[無]
- [x] 1052: バックラー - 無効化[ST30以下]
- [x] 1058: プレートメイル - HP+50
- [x] 1061: マグマアーマー - HP+火地自ドミニオ数×20
- [x] 1062: マグマシールド - 火地使用時、無効化[通常攻撃]
- [x] 1065: マジックシールド - HP+30；無効化[巻物]
- [x] 1066: ミラーホブロン - 敵アイテム未使用時、反射[全]
- [x] 1072: リアクトアーマー - HP+30；アイテム破壊[武器]

### アクセサリ (20個)

- [x] 1004: ウォーロックディスク - 戦闘中能力無効
- [x] 1010: イビルアイ - アイテム破壊[レア度N以外]
- [x] 1011: ゴールドグース - 形見[MHP×7EP]
- [x] 1013: サキュバスリング - APドレイン；先制
- [x] 1016: シルバープロウ - 土地レベルアップ；AP+10；HP+20
- [x] 1028: スリング - AP&HP+10；先制
- [x] 1031: ターコイズアムル - 即死[水地・60%]；無効化[水地]
- [x] 1036: ツインスパイク - AP+20；変質[使用クリーチャー]
- [x] 1038: トゥームストーン - 自破壊時、手札6枚までカードを引く；アイテム破壊・盗み無効
- [x] 1039: トパーズアムル - 即死[火風・60%]；無効化[火風]
- [x] 1041: ドラゴンオーブ - 変身[いずれかのドラゴン]
- [x] 1046: ネクロスカラベ - 蘇生[スケルトン]
- [x] 1048: バーニングハート - AP&HP+20；
- [x] 1055: フォースアンクレット - HP+自手札数×10
- [x] 1059: ペトリフストーン - AP=0；HP=80
- [x] 1069: メイガスミラー - HP+20；反射[巻物]
- [x] 1071: ラグドール - 無効化[巻物]；無効化[自分よりSTの大きなクリーチャー]
- [x] 1074: ワンダーチャーム - 無効化[通常攻撃の80%]

### 巻物 (9個)

- [x] 1007: オーラストライク - 術攻撃[AP=基本ST]
- [x] 1015: シャドウブレイズ - 術攻撃[ST40]；敵と同じクリーチャー配置時、強化術
- [x] 1024: スパークボール - 術攻撃[ST40]
- [x] 1030: ソウルレイ - 術攻撃[ST30]；復帰[手札]
- [x] 1035: チリングブラスト - 術攻撃[AP=水風自ドミニオ数×10]；強化術[火地]
- [x] 1037: ティアリングハロー - 術攻撃[ST30]；無以外使用時、強化術；アイテム破壊・盗み無効
- [x] 1047: ネクロプラズマ - 術攻撃[ST50]；変身[スケルトン]
- [x] 1049: バーニングロッド - 術攻撃[AP=火地自ドミニオ数×10]；強化術[水風]


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
  └─ アイテムデータを保存（効果はまだ適用しない）
  ↓
防御側アイテムフェーズ
  ├─ 防御側の手札を表示
  ├─ アイテムカード以外はグレーアウト
  ├─ アイテム選択 or パス
  └─ アイテムデータを保存（効果はまだ適用しない）
  ↓
バトル準備（prepare_participants）
  ├─ BattleParticipant作成
  └─ アイテムをitemsに追加（効果はまだ適用しない）
  ↓
バトル前スキル処理開始
  ↓
アイテム破壊・盗み処理
  ├─ 素の先制（クリーチャー能力のみ）で順序決定
  └─ 先に動く側からアイテム破壊・盗みを実行
  ↓
アイテム効果適用（破壊されなかったアイテムのみ）
  ├─ ステータスボーナス（AP/HP）を適用
  ├─ スキル付与（先制など）を適用
  └─ バトル画面にアイテム名表示
  ↓
各種スキル処理
  ├─ ブルガサリ、共鳴、強化など
  └─ 先制判定（アイテムによる先制含む）
  ↓
ダメージ計算・バトル実行
```

### アイテム効果タイプ

#### 1. buff_ap - AP増加

```json
{
  "effect_type": "buff_ap",
  "value": 30
}
```

**効果**: `participant.item_bonus_ap += value`

**AP計算順序**:
バトル中のAP計算式に含まれる（HPと同様に階層管理）

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
1. 土地ボーナス (`land_bonus_hp`) ← 最初に消費
2. 共鳴ボーナス (`resonance_bonus_hp`)
3. 一時ボーナス (`temporary_bonus_hp`)
4. スペルボーナス (`spell_bonus_hp`)
5. **アイテムボーナス** (`item_bonus_hp`)
6. current_hp ← 最後に消費

#### 3. grant_skill - スキル付与

```json
{
  "effect_type": "grant_skill",
  "skill": "強化",
  "skill_conditions": [
	{
	  "condition_type": "enemy_max_hp_check",
	  "operator": ">=",
	  "value": 40
	}
  ]
}
```

**スキル付与の仕組み**:
- `skill`: 付与するスキル名（例: "強化"）
- `skill_conditions`: スキルの**発動条件**（バトル時にチェック）

**重要**: `skill_conditions`はスキルの**発動条件**であり、**付与条件**ではありません。
- アイテムを使用すると、スキルは**常に付与**されます
- 付与されたスキルは、バトル時に`skill_conditions`の条件を満たす場合のみ発動します

**発動条件の例**:
- `enemy_max_hp_check`: 敵の最大HP条件
  - `operator`: 比較演算子（">=", "<=", ">", "<", "=="）
  - `value`: 閾値
- `user_element`: 使用者の属性チェック（付与時の条件として使う場合もあり）
  - `elements`: 対象属性リスト（例: ["fire"]）

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
prepare_participants()
  └─ アイテムをitemsに追加（効果はまだ適用しない）
  ↓
apply_pre_battle_skills()
  ├─ アイテム破壊・盗み処理
  ├─ apply_remaining_item_effects()  ← 破壊後にアイテム効果適用
  ├─ _apply_skills_with_animation()
  └─ 先制判定
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
  "effect": "AP+30",
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
  "effect": "AP+20；💧🌱使用時、強化",
  "ability_parsed": {
	"effects": [
	  {"effect_type": "buff_ap", "value": 20},
	  {
		"effect_type": "grant_skill",
		"skill": "強化",
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

## ⚠️ 実装上の注意事項

### スキル付与条件の正しい記述方法

アイテムでスキルを付与する際、条件の形式に注意が必要です。

#### ❌ 間違った例

```json
{
  "effect_type": "grant_skill",
  "skill": "強化",
  "skill_conditions": [
	{
	  "condition_type": "enemy_max_hp_check",
	  "min_hp": 40  // ← 独自パラメータ名は使用不可
	}
  ]
}
```

**問題点**: `condition_checker.gd`は統一的な`operator`と`value`で条件を評価します。独自のパラメータ名（`min_hp`、`max_hp`など）を使うと、条件が無視されてスキルが常に発動してしまいます。

#### ✅ 正しい例

```json
{
  "effect_type": "grant_skill",
  "skill": "強化",
  "skill_conditions": [
	{
	  "condition_type": "enemy_max_hp_check",
	  "operator": ">=",
	  "value": 40
	}
  ]
}
```

**正しい書き方**: すべての条件タイプで`operator`（比較演算子）と`value`（閾値）を使用します。

### バトルコンテキストへのMHP設定

強化などの条件判定で敵のMHPを参照する場合、`BattleParticipant.get_max_hp()`メソッドを使用してください。

```gdscript
// ✅ 正しい
"enemy_mhp_override": defender.get_max_hp()

// ❌ 間違い
"enemy_mhp_override": defender.max_hp  // プロパティは存在しない
"enemy_mhp": defender.creature_data.get("mhp", 0)  // 基本値のみ、ボーナス未計算
```

**理由**: `get_max_hp()`は`base_hp + base_up_hp`を返し、戦闘ボーナス（土地、アイテム等）を除いた真のMHPを取得できます。

### 参照ファイル

- 条件評価の実装: `scripts/skills/condition_checker.gd`
- スキル適用処理: `scripts/battle/battle_skill_processor.gd`
- バトル参加者管理: `scripts/battle/battle_participant.gd`

---

## 🔧 特殊アイテム処理

### 1059（ペトリフストーン）- HP固定値設定

**効果**: AP=0、HP=80 に固定設定

#### 実装の特殊性

HP固定値設定アイテムでは、以下の特殊な処理が必要です：

**問題状況**:
- クリーチャーが `base_up_hp = 20` を持っている場合
- HP=80 に固定設定されると、最終的なMHPは 80 + 20 = 100 になってしまう

**解決方法 - 保存・変更・復元の3ステップ**:

```gdscript
# _apply_fixed_stat 関数内 (battle_item_applier.gd)

elif stat == "hp":
	# 1. 保存：元のbase_up_hpを保存
	var saved_base_up_hp = participant.base_up_hp
	
	# 2. 変更：base_up_hpを一時的に0に設定
	participant.base_up_hp = 0
	
	# HP固定値を適用
	participant.creature_data["mhp"] = fixed_value
	participant.creature_data["hp"] = fixed_value
	participant.base_hp = fixed_value
	# current_hp は状態値のため、update_current_hp() は呼ばない
	
	# 3. 復元：元のbase_up_hpを戻す
	participant.base_up_hp = saved_base_up_hp
	# current_hp は状態値のため、update_current_hp() は呼ばない
	
	print("  [固定値] HP=", fixed_value, " (base_up_hp復元: +", saved_base_up_hp, ")")
```

#### 処理フロー詳細

| ステップ | base_hp | base_up_hp | current_hp | 説明 |
|---------|---------|-----------|-----------|------|
| **初期** | 50 | 20 | 70 | 元の状態（MHP=70） |
| **1. 保存** | 50 | 20 | 70 | saved_base_up_hp = 20 |
| **2. 変更** | 80 | 0 | 80 | HP固定値を適用 |
| **3. 復元** | 80 | 20 | 100 | base_up_hp を復元 |

**重要なポイント**:
- バトル中は base_hp=80、base_up_hp=20 で保持
- 最終的な MHP = 80 + 20 = 100
- バトル終了後も base_up_hp は保持される（永続バフ）
- ただし base_hp は戦闘で削られる可能性がある

#### 関連ドキュメント

- [HP管理構造](hp_structure.md) - base_hp と base_up_hp の定義
- [効果システム設計](effect_system_design.md) - 固定値設定の実装詳細

---
