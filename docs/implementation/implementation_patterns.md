# 🛠️ 実装パターン集

**目的**: よく使う実装パターンをテンプレート化し、効率的な開発をサポート

**最終更新**: 2025年10月23日

---

## 📑 目次

1. [クリーチャー実装パターン](#クリーチャー実装パターン)
2. [スキル実装パターン](#スキル実装パターン)
3. [JSONデータ追加パターン](#jsonデータ追加パターン)
4. [バグ修正パターン](#バグ修正パターン)
5. [ドキュメント更新パターン](#ドキュメント更新パターン)

---

## クリーチャー実装パターン

### パターン1: 基本クリーチャー（スキルなし）

**使用場面**: シンプルなステータスのみのクリーチャー

**手順**:
1. 該当する属性のJSONファイルを開く
2. 以下のテンプレートを追加

```json
{
  "id": [次のID],
  "name": "[クリーチャー名]",
  "rarity": "N|R|S|E",
  "type": "creature",
  "element": "fire|water|earth|wind|neutral",
  "cost": {
	"mp": [コスト],
	"lands_required": ["[属性]"]
  },
  "ap": [攻撃力],
  "hp": [体力],
  "ability": "",
  "ability_detail": ""
}
```

**例**: シンプルなクリーチャー
```json
{
  "id": 100,
  "name": "ファイアードラゴン",
  "rarity": "R",
  "type": "creature",
  "element": "fire",
  "cost": {
	"mp": 100,
	"lands_required": ["fire"]
  },
  "ap": 40,
  "hp": 40,
  "ability": "",
  "ability_detail": ""
}
```

---

### パターン2: 感応スキル持ちクリーチャー

**使用場面**: 特定属性の土地を持っているとボーナスを得る

**手順**:
1. 基本テンプレートに`ability_parsed`を追加

```json
{
  "id": [ID],
  "name": "[名前]",
  "rarity": "N|R|S|E",
  "type": "creature",
  "element": "fire|water|earth|wind|neutral",
  "cost": {
	"mp": [コスト],
	"lands_required": ["[属性]"]
  },
  "ap": [攻撃力],
  "hp": [体力],
  "ability": "感応",
  "ability_detail": "感応[[属性]・AP+[値]、HP+[値]]",
  "ability_parsed": {
	"keywords": ["感応"],
	"keyword_conditions": {
	  "感応": {
		"element": "[属性]",
		"stat_bonus": {
		  "ap": [APボーナス],
		  "hp": [HPボーナス]
		}
	  }
	}
  }
}
```

**例**: 火地の感応（AP&HP+20）
```json
{
  "id": 15,
  "name": "アモン",
  "rarity": "R",
  "type": "creature",
  "element": "fire",
  "cost": {
	"mp": 80,
	"lands_required": ["fire"]
  },
  "ap": 30,
  "hp": 30,
  "ability": "感応",
  "ability_detail": "感応[地・AP&HP+20]",
  "ability_parsed": {
	"keywords": ["感応"],
	"keyword_conditions": {
	  "感応": {
		"element": "earth",
		"stat_bonus": {
		  "ap": 20,
		  "hp": 20
		}
	  }
	}
  }
}
```

---

### パターン3: 防御型クリーチャー

**使用場面**: 移動・侵略不可だが高HPのクリーチャー

**手順**:
1. 基本テンプレートに`creature_type`を追加

```json
{
  "id": [ID],
  "name": "[名前]",
  "rarity": "N|R|S|E",
  "type": "creature",
  "element": "fire|water|earth|wind|neutral",
  "cost": {
	"mp": [コスト],
	"lands_required": ["[属性]"]
  },
  "creature_type": "defensive",
  "ap": [攻撃力],
  "hp": [体力],
  "ability": "防御型",
  "ability_detail": "防御型"
}
```

**例**: 防御型クリーチャー
```json
{
  "id": 102,
  "name": "アイスウォール",
  "rarity": "N",
  "type": "creature",
  "element": "water",
  "cost": {
	"mp": 50,
	"lands_required": ["water"]
  },
  "creature_type": "defensive",
  "ap": 0,
  "hp": 40,
  "ability": "防御型",
  "ability_detail": "防御型"
}
```

---

### パターン4: 複合スキル持ちクリーチャー

**使用場面**: 先制+強打など、複数のスキルを持つ

**手順**:
1. `keywords`配列に複数のスキルを列挙
2. 各スキルの条件を`keyword_conditions`または`effects`に定義

```json
{
  "id": [ID],
  "name": "[名前]",
  "rarity": "N|R|S|E",
  "type": "creature",
  "element": "fire|water|earth|wind|neutral",
  "cost": {
	"mp": [コスト],
	"lands_required": ["[属性]"]
  },
  "ap": [攻撃力],
  "hp": [体力],
  "ability": "先制・強打",
  "ability_detail": "先制；強打",
  "ability_parsed": {
	"keywords": ["先制", "強打"],
	"effects": [
	  {
		"effect_type": "power_strike",
		"multiplier": 1.5,
		"conditions": []
	  }
	]
  }
}
```

---

## スキル実装パターン

### パターン1: 新しいキーワードスキル追加

**使用場面**: 「先制」「感応」のようなキーワードベースのスキル

**手順**:

#### 1. JSONデータ定義
```json
{
  "ability": "[スキル名]",
  "ability_detail": "[詳細説明]",
  "ability_parsed": {
	"keywords": ["[スキル名]"],
	"keyword_conditions": {
	  "[スキル名]": {
		// スキル固有のパラメータ
	  }
	}
  }
}
```

#### 2. BattleSkillProcessorに処理追加

**ファイル**: `scripts/battle/battle_skill_processor.gd`

```gdscript
# スキル適用関数に追加
func apply_[スキル名]_skill(participant: BattleParticipant, context: Dictionary) -> void:
	var ability_parsed = participant.creature_data.get("ability_parsed", {})
	var keywords = ability_parsed.get("keywords", [])
	
	if not "[スキル名]" in keywords:
		return
	
	var keyword_conditions = ability_parsed.get("keyword_conditions", {})
	var skill_condition = keyword_conditions.get("[スキル名]", {})
	
	# スキル固有の処理
	# ...
```

#### 3. apply_pre_battle_skills()から呼び出し
```gdscript
func apply_pre_battle_skills(attacker: BattleParticipant, defender: BattleParticipant, context: Dictionary) -> void:
	# 既存のスキル適用
	apply_resonance_skill(attacker, context)
	apply_resonance_skill(defender, context)
	
	# 新しいスキルを追加
	apply_[スキル名]_skill(attacker, context)
	apply_[スキル名]_skill(defender, context)
```

---

### パターン2: 条件付きスキル追加

**使用場面**: 「強打」のように、特定条件下で発動するスキル

**手順**:

#### 1. JSONデータ定義
```json
{
  "ability_parsed": {
	"keywords": ["[スキル名]"],
	"effects": [
	  {
		"effect_type": "[effect_type]",
		"multiplier": 1.5,
		"conditions": [
		  {
			"condition_type": "[条件タイプ]",
			"value": [閾値]
		  }
		]
	  }
	]
  }
}
```

#### 2. ConditionCheckerに条件タイプ追加

**ファイル**: `scripts/battle/condition_checker.gd`

```gdscript
func _check_[条件タイプ]_condition(condition: Dictionary, context: Dictionary) -> bool:
	var value = condition.get("value", 0)
	# 条件判定ロジック
	return [判定結果]
```

#### 3. evaluate_conditions()に追加
```gdscript
func evaluate_conditions(conditions: Array, context: Dictionary) -> bool:
	for condition in conditions:
		var condition_type = condition.get("condition_type", "")
		
		match condition_type:
			"[条件タイプ]":
				if not _check_[条件タイプ]_condition(condition, context):
					return false
```

---

### パターン3: 応援スキル追加

**使用場面**: 盤面のクリーチャーにバフを与えるスキル

**手順**:

#### 1. JSONデータ定義
```json
{
  "ability": "応援",
  "ability_detail": "応援[[条件]・[効果]]",
  "ability_parsed": {
	"keywords": ["応援"],
	"effects": [
	  {
		"effect_type": "support",
		"target": {
		  "scope": "all_creatures",
		  "conditions": [
			{
			  "condition_type": "[条件タイプ]",
			  "[パラメータ]": "[値]"
			}
		  ]
		},
		"bonus": {
		  "ap": [APボーナス],
		  "hp": [HPボーナス]
		}
	  }
	]
  }
}
```

#### 2. 新しい条件タイプが必要な場合

**ファイル**: `scripts/battle/battle_skill_processor.gd`

```gdscript
# _check_support_condition()に条件タイプを追加
func _check_support_condition(
	participant: BattleParticipant,
	condition: Dictionary,
	context: Dictionary
) -> bool:
	var condition_type = condition.get("condition_type", "")
	
	match condition_type:
		"[条件タイプ]":
			# 条件判定ロジック
			return [判定結果]
```

**例**: 名前部分一致の条件
```gdscript
"name_contains":
	var name_pattern = condition.get("name_pattern", "")
	var creature_name = participant.creature_data.get("name", "")
	return creature_name.contains(name_pattern)
```

---

## JSONデータ追加パターン

### パターン1: 新しいクリーチャーをJSONに追加

**チェックリスト**:
1. ✅ 属性に合ったファイルを選択
   - 火: `fire_1.json` or `fire_2.json`
   - 水: `water_1.json` or `water_2.json`
   - 地: `earth_1.json` or `earth_2.json`
   - 風: `wind_1.json` or `wind_2.json`
   - 無: `neutral_1.json` or `neutral_2.json`

2. ✅ 既存の最大IDを確認
   ```python
   # 確認コマンド
   python3 << 'EOF'
   import json
   with open('data/fire_1.json', 'r', encoding='utf-8') as f:
	   data = json.load(f)
   cards = data.get("cards", [])
   max_id = max(c.get("id", 0) for c in cards)
   print(f"最大ID: {max_id}")
   EOF
   ```

3. ✅ 新しいカードを追加（最後のカードの後にカンマ追加を忘れずに！）

4. ✅ JSON文法チェック
   ```python
   # 検証コマンド
   python3 << 'EOF'
   import json
   with open('data/fire_1.json', 'r', encoding='utf-8') as f:
	   data = json.load(f)
   print("✅ JSONは正常です")
   EOF
   ```

---

### パターン2: 既存クリーチャーにフィールド追加

**使用場面**: `creature_type`や`race`など、新しい分類フィールドを追加

**手順**:

#### 1. serena:replace_regexを使用
```gdscript
serena:replace_regex(
  regex: '"id": [ID],\n\t  "name": "[名前]",.*?"ability_detail": ".*?"',
  repl: '元の内容 + 新しいフィールド',
  relative_path: 'data/[ファイル名].json'
)
```

**例**: creature_typeを追加
```python
# 変更前
{
  "id": 5,
  "name": "オールドウィロウ",
  "rarity": "R",
  "type": "creature",
  "element": "fire",
  "cost": {...},
  "ap": 20,
  "hp": 40
}

# 変更後
{
  "id": 5,
  "name": "オールドウィロウ",
  "rarity": "R",
  "type": "creature",
  "element": "fire",
  "cost": {...},
  "creature_type": "defensive",  # 追加
  "ap": 20,
  "hp": 40
}
```

---

## バグ修正パターン

### パターン1: メソッド名エラー

**症状**: `Invalid call. Nonexistent function 'get_tile_data' in base 'BoardSystem3D'.`

**原因**: メソッド名が間違っている

**修正手順**:
1. 正しいメソッド名を確認
   ```gdscript
   # docs/配下のドキュメントを確認
   # または、該当クラスのコードを直接確認
   ```

2. serena:replace_regexで一括置換
   ```gdscript
   serena:replace_regex(
	 regex: 'get_tile_data',
	 repl: 'get_tile_info',
	 relative_path: 'scripts/...',
	 allow_multiple_occurrences: true
   )
   ```

---

### パターン2: null参照エラー

**症状**: `Attempt to call function 'XXX' in base 'null instance' on a null instance.`

**原因**: オブジェクトがnullまたは存在しない

**修正手順**:
1. null チェックを追加
   ```gdscript
   # 修正前
   var result = object.method()
   
   # 修正後
   if object and is_instance_valid(object):
	   var result = object.method()
   else:
	   print("[ERROR] object is null")
	   return
   ```

---

### パターン3: 配列範囲外エラー

**症状**: `Index [X] is out of bounds (array size is [Y]).`

**原因**: 配列の要素数より大きいインデックスにアクセス

**修正手順**:
1. 範囲チェックを追加
   ```gdscript
   # 修正前
   var item = array[index]
   
   # 修正後
   if index >= 0 and index < array.size():
	   var item = array[index]
   else:
	   print("[ERROR] Index out of bounds: ", index, " (size: ", array.size(), ")")
	   return
   ```

---

## ドキュメント更新パターン

### パターン1: 実装完了時のドキュメント更新

**更新すべきファイル**:
1. `docs/progress/daily_log.md` - 日次ログに追加
2. `docs/README.md` - 現在の開発状況を更新
3. 該当する設計ドキュメント（必要に応じて）

**手順**:

#### 1. daily_log.mdに追加
```markdown
## YYYY年MM月DD日

### 完了した作業
- ✅ **[機能名]実装完了**
  - [詳細1]
  - [詳細2]
  - 詳細: `[ドキュメントパス]`

### 次のステップ
- 📋 **[次の作業]**
```

#### 2. docs/README.mdの進捗更新
```markdown
現在の開発状況：
- ✅ [完了した機能]: 完了 ✨NEW
  - [詳細]
```

#### 3. 設計ドキュメントの更新（必要な場合）
- 「未実装」セクションを「実装済み」に移動
- 実装内容の詳細を追記
- 変更履歴に記録

---

### パターン2: バグ修正時のドキュメント更新

**更新すべきファイル**:
1. `docs/issues/issues.md` - ステータスを「解決済み」に変更
2. `docs/progress/daily_log.md` - 修正内容を記録

**手順**:

#### 1. issues.mdのステータス更新
```markdown
### BUG-XXX: [バグ内容]
- **ステータス**: ~~調査中~~ → **解決済み**
- **修正日**: YYYY年MM月DD日
- **修正内容**: [修正の詳細]
```

#### 2. daily_log.mdに記録
```markdown
### 完了した作業
- ✅ **BUG-XXX修正**
  - 原因: [原因]
  - 対応: [対応内容]
```

---

## 🎯 パターン使用のコツ

### 1. 適切なパターンを選ぶ
- 実装内容に最も近いパターンを選択
- 複数のパターンを組み合わせてもOK

### 2. テンプレートをコピー
- まずテンプレートをコピー
- 項目を埋めていく
- 最後に文法チェック

### 3. ドキュメントを確認
- パターンだけでなく、該当する設計書も確認
- 既存の実装例を参考にする

### 4. 段階的に実装
1. JSONデータ定義
2. コード実装
3. テスト
4. ドキュメント更新

---

## アイテムスキル実装パターン

### パターン: バトル中に発動するアイテムスキル（反射、無効化など）

**使用場面**: アイテムに戦闘中発動スキルを追加する時（初実装: 反射スキル）

**重要**: アイテムは`effect_parsed`を使用（クリーチャーの`ability_parsed`とは別）

**手順**:

#### 1. item.jsonにeffect_parsedを追加

```json
{
  "id": 1025,
  "name": "スパイクシールド",
  "rarity": "S",
  "type": "item",
  "item_type": "防具",
  "cost": {
	"mp": 40
  },
  "effect": "反射[1/2]",
  "effect_parsed": {
	"keywords": ["反射[1/2]"],
	"stat_bonus": {
	  "st": 0,
	  "hp": 0
	},
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

#### 2. BattlePreparationでアイテムをitemsに追加

`scripts/battle/battle_preparation.gd`の`create_participants()`内:

```gdscript
# アイテム効果を適用
if not attacker_item.is_empty():
	# アイテムデータをクリーチャーのitemsに追加（反射チェックで使用）
	if not attacker.creature_data.has("items"):
		attacker.creature_data["items"] = []
	attacker.creature_data["items"].append(attacker_item)
	apply_item_effects(attacker, attacker_item)
```

#### 3. BattleSkillProcessorでアイテムのeffect_parsedを読み取る

```gdscript
func _get_reflect_effect(defender_p: BattleParticipant, attack_type: String):
	# クリーチャー自身のスキルをチェック
	var ability_parsed = defender_p.creature_data.get("ability_parsed", {})
	# ... クリーチャースキルをチェック ...
	
	# アイテムをチェック
	var items = defender_p.creature_data.get("items", [])
	for item in items:
		var effect_parsed = item.get("effect_parsed", {})  # ← effect_parsed!
		var item_effects = effect_parsed.get("effects", [])
		for effect in item_effects:
			if effect.get("effect_type") == "reflect_damage":
				var attack_types = effect.get("attack_types", [])
				if attack_type in attack_types:
					return effect
	
	return null
```

#### 4. apply_item_effectsでstat_bonusとeffectsを処理

`scripts/battle/battle_preparation.gd`:

```gdscript
func apply_item_effects(participant: BattleParticipant, item_data: Dictionary) -> void:
	var effect_parsed = item_data.get("effect_parsed", {})
	
	# stat_bonusを先に適用（AP+20、HP+20など）
	var stat_bonus = effect_parsed.get("stat_bonus", {})
	if not stat_bonus.is_empty():
		var ap = stat_bonus.get("ap", 0)
		var hp = stat_bonus.get("hp", 0)
		
		if ap > 0:
			participant.current_ap += ap
		if hp > 0:
			participant.item_bonus_hp += hp
			participant.update_current_hp()
	
	# effectsを処理
	var effects = effect_parsed.get("effects", [])
	for effect in effects:
		var effect_type = effect.get("effect_type", "")
		
		match effect_type:
			"reflect_damage", "nullify_reflect":
				# バトル中スキルはBattleExecutionで処理するためスキップ
				pass
			
			"buff_ap":
				participant.current_ap += effect.get("value", 0)
			
			# ... 他のeffect_type ...
```

**重要ポイント**:

1. **アイテムはeffect_parsed、クリーチャーはability_parsed**
2. **二段階処理**:
   - `stat_bonus`: バトル準備時（BattlePreparation）
   - `effects`: バトル中（BattleExecution）
3. **items配列への追加が必須**（スキルチェック時に参照）

**実装例**: 反射スキル（2025年10月23日実装）

---

---

## シグナルとフェーズ管理パターン

### パターン1: CONNECT_ONE_SHOTシグナルの再接続

**使用場面**: `CONNECT_ONE_SHOT`で接続したシグナルをコールバック内で再度接続する必要がある場合

**問題**: `CONNECT_ONE_SHOT`はコールバック**完了後**に切断されるため、コールバック実行中に`is_connected()`チェックすると`true`を返し、再接続できない

**悪い例**:
```gdscript
func _on_item_phase_completed():
	# ❌ is_connected()はコールバック実行中にtrueを返すため、再接続されない
	if not item_handler.item_phase_completed.is_connected(_on_item_phase_completed):
		item_handler.item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
```

**良い例**:
```gdscript
func _on_item_phase_completed():
	# ✅ 常に再接続（ONE_SHOTはコールバック完了後に切断されるため安全）
	item_handler.item_phase_completed.connect(_on_item_phase_completed, CONNECT_ONE_SHOT)
```

**実装例**: `spell_creature_move.gd`, `cpu_turn_processor.gd`（2025年1月実装）

---

### パターン2: 複数フェーズが同時アクティブになる場合の優先順位

**使用場面**: スペル効果中にアイテムフェーズが開始される場合など

**問題**: スペル移動（チャリオット/アウトレイジ）による侵略時、スペルフェーズがアクティブなままアイテムフェーズが開始され、カード選択が正しく処理されない

**原因**: `on_card_selected`でスペルフェーズのチェックがアイテムフェーズより先に来ていた

**悪い例**:
```gdscript
func on_card_selected(card_index: int):
	# ❌ スペルフェーズが先にチェックされる
	if spell_phase_handler.is_spell_phase_active():
		if card_type == "spell":
			spell_phase_handler.use_spell(card)
			return
		else:
			return  # アイテムフェーズがアクティブでもここでreturn!
	
	if item_phase_handler.is_item_phase_active():
		# ここに到達しない
```

**良い例**:
```gdscript
func on_card_selected(card_index: int):
	# ✅ アイテムフェーズを優先（スペル効果中のバトルで使用されるため）
	if item_phase_handler and item_phase_handler.is_item_phase_active():
		if card_type == "item":
			item_phase_handler.use_item(card)
			return
		# ... 援護クリーチャー等の処理
	
	# スペルフェーズは後でチェック
	if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
		if card_type == "spell":
			spell_phase_handler.use_spell(card)
			return
```

**理由**: アイテムフェーズはバトル直前の短い期間のみアクティブになり、その間はアイテム選択が最優先されるべき

**実装例**: `game_flow_manager.gd`の`on_card_selected()`（2025年1月修正）

---

**このパターン集は継続的に更新されます。新しいパターンが見つかったら追加してください！**

**最終更新**: 2025年1月6日（シグナルとフェーズ管理パターン追加）
