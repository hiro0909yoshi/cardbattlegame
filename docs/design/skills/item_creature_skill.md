# レリック (Item Creature)

クリーチャーとしてもアイテムとしても使用できる特殊なクリーチャー。

## 基本仕様

### 使用方法
1. **クリーチャーとして配置** - 通常のクリーチャーと同様に盤面に配置
2. **アイテムとして使用** - 戦闘時に加勢アイテムとして使用

### アイテムとして使用時の効果
- 基礎AP/HPがボーナスとして加算される
- 追加スキル（相討、蘇生等）も適用される
- スキルによるステータス変動（例: 440の他属性配置数×5）も適用

---

## 実装クリーチャー一覧

| ID | 名前 | 基礎AP | 基礎HP | 追加スキル |
|----|------|--------|--------|------------|
| 438 | リビングアーマー | 0 | 40 | クリーチャーとして戦闘中AP+50 |
| 439 | リビングアムル | 20 | 10 | 敵武器不使用時、蘇生[リビングアムル] |
| 440 | リビングクローブ | 0 | 30 | AP&HP=他属性の配置数×5 |
| 441 | リビングヘルム | 20 | 30 | なし（基本効果のみ） |
| 442 | リビングボム | 10 | 30 | 相討[HP20以下] |

---

## 実装状況

### 実装済み（クリーチャーとして使用時）
- [x] クリーチャーとして配置
- [x] リビングアーマー: クリーチャーとして戦闘中AP+50
- [x] リビングクローブ: AP&HP=他属性配置数×5（`other_element_count`効果）

### 実装済み（アイテムとして使用時）
- [x] アイテム選択UIで「レリック」を選択可能に
- [x] 基礎AP/HPを使用者に加算
- [x] ability_parsed.effectsを使用者にマージ
- [x] ability_parsed.keywordsを使用者にマージ
- [x] ability_parsed.keyword_conditionsを使用者にマージ
- [x] リビングクローブ: AP/HP置換処理（特殊）
- [x] リビングアムル: 蘇生[リビングアムル]（敵武器不使用時）
- [x] リビングボム: 相討[HP20以下]（自分のHP20以下で自爆＋相討）

---

## 処理フロー

### アイテムとして使用する場合
```
カード選択UI（アイテム選択時）
  ↓ type == "creature" でも「レリック」キーワードがあれば選択可能
  ↓
battle_item_applier.gd
  ↓ レリック判定（type == "creature"）
  ↓ 基礎AP/HPをitem_bonus_ap/hpとして加算
  ↓ ability_parsed.effectsを戦闘クリーチャーにマージ（スキル継承）
  ↓ keywordsもマージ（相討等のキーワードスキル用）
```

### クリーチャーとして使用する場合
```
通常のクリーチャー配置フロー
  ↓
battle_skill_processor.gd
  ↓ スキル効果（other_element_count等）を適用
```

---

## レリックのスキル継承

アイテムとして使用時、レリックのスキルは戦闘クリーチャーに継承される。

### 継承されるもの
| 項目 | 継承元 | 継承先 | 備考 |
|------|--------|--------|------|
| AP | `item_data.ap` | `participant.item_bonus_ap` | 加算 |
| HP | `item_data.hp` | `participant.item_bonus_hp` | 加算 |
| effects | `item_data.ability_parsed.effects` | `participant.creature_data.ability_parsed.effects` | マージ |
| keywords | `item_data.ability_parsed.keywords` | `participant.creature_data.ability_parsed.keywords` | マージ |

### 特殊ケース
| ID | 名前 | 特殊処理 |
|----|------|----------|
| 438 | リビングアーマー | クリーチャー時のみAP+50（アイテム時は基礎AP/HPのみ） |
| 440 | リビングクローブ | AP/HPは加算ではなく**置換**（使用者のAP/HP = 計算値） |

### 継承例：リビングボム（相討）
```
戦闘クリーチャー: ファイター（AP30/HP40）
アイテム: リビングボム（AP10/HP30、相討[HP20以下]）

結果:
- ファイターのAP: 30 + 10 = 40
- ファイターのHP: 40 + 30 = 70
- ファイターに「相討[HP20以下]」スキル付与
```

### 継承例：リビングクローブ（ステータス置換 - 特殊）
```
戦闘クリーチャー: ファイター（AP30/HP40）
アイテム: リビングクローブ（他属性配置数×5）
状況: 他属性クリーチャー4体配置中

結果:
- 計算値 = 4 × 5 = 20
- ファイターのAP: 30 → 20 に置換
- ファイターのHP: 40 → 20 に置換

※リビングクローブは加算ではなく「置換」。使用者のAP/HPがそのまま計算値になる。
```

---

## UI変更（アイテム選択時のフィルタリング）

### 現状
```gdscript
# クリーチャーは全てグレーアウト
if card.type == "creature":
	# グレーアウト
```

### 変更後
```gdscript
# レリック以外のクリーチャーをグレーアウト
if card.type == "creature":
	var keywords = card.get("ability_parsed", {}).get("keywords", [])
	if "レリック" not in keywords:
		# グレーアウト
```

### 対象ファイル
- `scripts/ui_components/card_selection_ui.gd`
- `scripts/ui_components/hand_display.gd`

---

## JSON定義例

### リビングヘルム（基本効果のみ）
```json
{
  "id": 441,
  "name": "リビングヘルム",
  "type": "creature",
  "ap": 20,
  "hp": 30,
  "ability_detail": "レリック",
  "ability_parsed": {
	"keywords": ["レリック"]
  }
}
```

### リビングクローブ（ステータス計算あり）
```json
{
  "id": 440,
  "name": "リビングクローブ",
  "type": "creature",
  "ap": 0,
  "hp": 30,
  "ability_detail": "レリック；AP&HP=他属性の配置数×5",
  "ability_parsed": {
	"keywords": ["レリック"],
	"effects": [
	  {
		"effect_type": "other_element_count",
		"multiplier": 5,
		"exclude_neutral": true,
		"stat_changes": {"ap": true, "hp": true}
	  }
	]
  }
}
```

---

## 関連ファイル

- `scripts/battle/skills/skill_item_creature.gd` - レリックスキル処理（リビングアーマーAP+50）
- `scripts/battle/battle_item_applier.gd` - アイテム効果適用
- `scripts/battle/battle_skill_processor.gd` - スキル効果処理（other_element_count等）
- `scripts/ui_components/card_selection_ui.gd` - カード選択UI
