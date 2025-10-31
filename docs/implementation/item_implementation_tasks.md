# 📋 アイテム実装タスク管理

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 2.1  
**最終更新**: 2025年10月31日

---

## 🎯 実装ルール

### ⚠️ 最優先事項

#### 0. **既存スキルシステムの活用（最重要）**

**CRITICAL**: アイテム実装時、既に実装されているスキルモジュールが存在する場合は、**必ずそれを使用すること**。

**既存スキルモジュールの確認場所**:
- `scripts/battle/skills/` ディレクトリ内の各スキルファイル
- 各スキルには `grant_skill()` メソッドが実装されている

**実装例**:

❌ **悪い例（スキルシステムを使わない）**:
```gdscript
"grant_first_strike":
	participant.has_item_first_strike = true
	print("先制付与（アイテム）")
```

✅ **良い例（既存スキルシステムを活用）**:
```gdscript
"grant_first_strike":
	SkillFirstStrike.grant_skill(participant, "先制")
```

**利用可能なスキルモジュール**:
- `SkillFirstStrike`: 先制・後手付与
- `SkillPowerStrike`: 強打付与
- `SkillPenetration`: 貫通付与
- `SkillTransform`: 変身付与
- `SkillDoubleAttack`: 2回攻撃付与
- その他 `scripts/battle/skills/` 内のすべてのスキル

**重要な理由**:
1. コードの一貫性を保つ
2. 既存のロジックとの整合性
3. デバッグメッセージの統一
4. メンテナンス性の向上

**実装前のチェックリスト**:
- [ ] `scripts/battle/skills/` ディレクトリを確認
- [ ] 該当するスキルモジュールが存在するか確認
- [ ] 存在する場合は `grant_skill()` メソッドを使用
- [ ] 存在しない場合のみ、新規実装を検討

---

### 必須確認事項

#### 1. **アイテム専用バフの使用**
アイテム効果には専用のバフ構造を使用すること：
- `stat_bonus`: ST/HP増減（推奨形式）
- `buff_ap` / `debuff_ap`: AP増減（レガシー）
- `buff_hp` / `debuff_hp`: HP増減（レガシー）
- `grant_skill`: スキル付与
- `grant_first_strike`: 先制付与
- `grant_last_strike`: 後手付与

**stat_bonus形式（推奨）**:
```json
"effect_parsed": {
  "stat_bonus": {
	"st": 30,
	"hp": -10
  }
}
```

**参照**: `docs/design/item_system.md`

#### 2. **既存条件分岐の確認**
新しい条件を追加する前に、必ず既存の条件分岐を確認すること：

**既存条件タイプ一覧**:
- `enemy_max_hp_check`: 敵のMHP条件（operator + value形式）
- `user_element`: 使用者の属性条件
- `on_element_land`: 特定属性の土地
- `land_level_check`: 土地レベル判定
- `adjacent_ally_land`: 隣接自領地判定
- `enemy_is_element`: 敵属性判定

**参照**: 
- `docs/design/condition_patterns_catalog.md` - 条件分岐パターン完全カタログ（全50種類）

#### 3. **条件形式の統一**

**すべての条件で `operator` と `value` を使用**：

✅ **正しい例**:
```json
{
  "condition_type": "enemy_max_hp_check",
  "operator": ">=",
  "value": 40
}
```

❌ **間違った例**:
```json
{
  "condition_type": "enemy_max_hp_check",
  "min_hp": 40  // 独自パラメータ名は禁止
}
```

#### 4. **スキル付与の実装**

**`skill_conditions`はスキルの発動条件**（付与条件ではない）:

```json
{
  "effect_type": "grant_skill",
  "skill": "強打",
  "skill_conditions": [
	{
	  "condition_type": "user_element",
	  "elements": ["fire", "earth"]
	}
  ]
}
```

この場合：
- アイテム使用時、強打スキルは**常に付与**される
- 付与された強打は、**火または地属性の時のみ発動**する

**参照ドキュメント**:
- `docs/design/skills_design.md` - 各スキルの構造
- `docs/design/skills/` - 個別スキル詳細仕様

#### 5. **不明な効果の確認**
以下の場合は**必ずユーザーに確認**すること：
- 効果の動作が不明瞭
- 既存システムでの実装方法が不明
- 新しい効果タイプが必要
- 特殊な条件判定が必要

#### 6. **スキル付与のコーディングパターン**

**重要**: `battle_preparation.gd`の`grant_skill_to_participant`関数でスキルを付与する際は、以下のパターンに従うこと。

**基本パターン（即死スキルを例に）**:

```gdscript
"即死":
	# 1. ability_parsedの準備
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	
	var ability_parsed = participant.creature_data["ability_parsed"]
	if not ability_parsed.has("keywords"):
		ability_parsed["keywords"] = []
	
	# 2. キーワードを追加
	if not "即死" in ability_parsed["keywords"]:
		ability_parsed["keywords"].append("即死")
	
	# 3. keyword_conditionsの準備
	if not ability_parsed.has("keyword_conditions"):
		ability_parsed["keyword_conditions"] = {}
	
	# 4. skill_paramsから必要なパラメータを取得
	var skill_params = _skill_data.get("skill_params", {})
	var probability = skill_params.get("probability", 100)
	var target_elements = skill_params.get("target_elements", [])
	var target_type = skill_params.get("target_type", "")
	
	# 5. スキルデータを構築
	var instant_death_data = {
		"probability": probability
	}
	
	# 6. 条件に応じてデータを追加
	if not target_elements.is_empty():
		instant_death_data["condition_type"] = "enemy_element"
		instant_death_data["elements"] = target_elements
	elif not target_type.is_empty():
		instant_death_data["condition_type"] = "enemy_type"
		instant_death_data["type"] = target_type
	
	# 7. keyword_conditionsに設定
	ability_parsed["keyword_conditions"]["即死"] = instant_death_data
	
	print("  即死スキル付与: 確率=", probability, "% 条件=", instant_death_data.get("condition_type", "無条件"))
```

**無効化スキルの例**:

```gdscript
"無効化":
	# 1-3. 同様の準備処理
	if not participant.creature_data.has("ability_parsed"):
		participant.creature_data["ability_parsed"] = {}
	
	var ability_parsed = participant.creature_data["ability_parsed"]
	if not ability_parsed.has("keywords"):
		ability_parsed["keywords"] = []
	
	if not "無効化" in ability_parsed["keywords"]:
		ability_parsed["keywords"].append("無効化")
	
	if not ability_parsed.has("keyword_conditions"):
		ability_parsed["keyword_conditions"] = {}
	
	# 4. skill_paramsから取得
	var skill_params = _skill_data.get("skill_params", {})
	var nullify_type = skill_params.get("nullify_type", "normal_attack")
	var reduction_rate = skill_params.get("reduction_rate", 0.0)
	
	# 5. スキルデータを構築
	var nullify_data = {
		"nullify_type": nullify_type,
		"reduction_rate": reduction_rate,
		"conditions": []
	}
	
	# 6. タイプに応じて必要なパラメータを追加
	if nullify_type in ["st_below", "st_above", "mhp_below", "mhp_above"]:
		nullify_data["value"] = skill_params.get("value", 0)
	elif nullify_type == "element":
		nullify_data["elements"] = skill_params.get("elements", [])
	
	# 7. keyword_conditionsに設定
	ability_parsed["keyword_conditions"]["無効化"] = nullify_data
	
	print("  無効化スキル付与: ", nullify_type)
```

**重要なポイント**:
1. **その場で取得**: 必要なパラメータは`skill_params.get()`でその場で取得する
2. **条件分岐で追加**: タイプに応じて必要なパラメータだけを追加する
3. **統一形式**: `value`, `elements`, `type`などのパラメータ名を統一する
4. **デバッグログ**: 付与時に必ず確認用のprintを出力する

#### 7. **実装完了後のチェック**
JSONに落とし込んだら、必ず以下を実行：
- [ ] `effect_parsed`構造の確認（アイテムは`effect_parsed`を使用）
- [ ] 効果タイプの確認
- [ ] 条件の確認（該当する場合）
- [ ] **既存スキルシステムを活用しているか確認（最重要）**
- [ ] **条件形式が統一されているか確認（operator + value）**
- [ ] **スキル付与のコーディングパターンに従っているか確認**

---

## 📝 実装パターン分類

### 1. 基本ステータス増減
単純なST/HP増減のみのアイテム。実装が容易。

**例**: ロングソード、クレイモア、チェインメイル

### 2. 先制・後手付与
`SkillFirstStrike.grant_skill()`を使用。

**例**: イーグルレイピア、スリング、ダイヤアーマー

### 3. 条件付きスキル付与
既存のスキルシステムを活用。

**例**: マグマハンマー、ストームスピア、ボーパルソード、ドリルランス

### 4. 動的ステータス計算
土地数や連鎖数に応じて動的にST/HPを計算。

**例**: シェイドクロー、ストームアーマー、マグマアーマー

### 5. 無効化・反射系
一部実装済み。同様のパターンで実装可能。

**例**: スパイクシールド、ミラーホブロン、メイガスミラー

### 6. 巻物攻撃
別途実装方針を決定してから実装。

### 7. 特殊効果
最も複雑。個別に仕様確認が必要。

**例**: 変身、復活、魔力獲得、アイテム破壊など

---

## 🔄 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/31 | 2.1 | 条件形式の統一ルールを追加、stat_bonus形式を推奨 |
| 2025/10/31 | 2.0 | 実際のitem.jsonから情報を再収集し、ドキュメント全面刷新 |

---

**最終更新**: 2025年10月31日（v2.1）
