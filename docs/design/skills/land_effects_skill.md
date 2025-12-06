# 土地効果スキル (skill_land_effects.gd)

戦闘中の土地効果スキルを統一管理するクラス。

## 担当スキル一覧

### 実装済み

| ID | 名前 | 効果 | トリガー |
|----|------|------|----------|
| 121 | ショッカー | 攻撃成功時、敵をダウン | on_attack_success |

### 実装予定

#### 土地変性（4体）
侵略成功時（土地を奪った時のみ）に配置先の土地属性を変更する。

| ID | 名前 | 変性先 | トリガー |
|----|------|--------|----------|
| 19 | ティアマト | 火 | on_invasion_success |
| 133 | バハムート | 水 | on_invasion_success |
| 242 | ヨルムンガンド | 地 | on_invasion_success |
| 329 | テュポーン | 風 | on_battle_won |

**条件**: 土地を奪った場合のみ発動（バトルに勝利し土地を取得）

#### 土地破壊（1体）
侵略成功時にその土地のレベルを1下げる。

| ID | 名前 | 効果 | トリガー |
|----|------|------|----------|
| 327 | デバステイター | 侵略時、土地レベル-1 | on_invasion_success |

**条件**: レベル1の場合はレベル1で止まる（0にはならない）

#### 土地破壊・変性無効（1体）
スペル/スキルによる土地変性と土地破壊（レベルダウン）を無効化する。

| ID | 名前 | 効果 |
|----|------|------|
| 232 | バロン | 復活；土地破壊・変性無効 |

**無効化対象**:
- スペルによる属性変更（`change_element`）
- スペル/スキルによるレベルダウン（`change_level` delta < 0）
- デバステイターの土地破壊効果

**チェック場所**: `spell_land_new.gd`の各メソッド（ソリッドワールドと同様の実装パターン）

---

## JSON定義例

### 土地変性（ティアマト）
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"trigger": "on_invasion_success",
		"effect_type": "change_tile_element",
		"element": "fire"
	  }
	]
  }
}
```

### 土地破壊（デバステイター）
```json
{
  "ability_parsed": {
	"effects": [
	  {
		"trigger": "on_invasion_success",
		"effect_type": "destroy_source_tile"
	  }
	]
  }
}
```

### 土地破壊・変性無効（バロン）
```json
{
  "ability_parsed": {
	"keywords": ["復活", "土地破壊・変性無効"]
  }
}
```

---

## 処理フロー

### 土地変性
```
battle_system.gd（侵略成功時）
  ↓
SkillLandEffects.check_and_apply_tile_change()
  ↓ change_tile_element効果を持つか？
  ↓ 対象タイルが土地破壊・変性無効を持つか？
  ↓ spell_land.change_element()
```

### 土地破壊
```
battle_system.gd（侵略成功時）
  ↓
SkillLandEffects.check_and_apply_tile_destroy()
  ↓ destroy_source_tile効果を持つか？
  ↓ 元のタイルをリセット（owner_id = -1）
```

---

## 関連ファイル

- `scripts/battle/skills/skill_land_effects.gd` - メイン処理
- `scripts/spells/spell_land_new.gd` - 土地属性変更処理
- `scripts/battle_system.gd` - 侵略成功時の呼び出し元
