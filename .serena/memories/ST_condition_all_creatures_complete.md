# 強打・貫通・秘術スキルのST条件チェック完全リスト

**最終更新**: 2025年11月13日

---

## 🎯 ST条件を持つスキル別クリーチャー一覧

### 1. 強打[敵AP条件]

#### ID 235: ブラックナイト（earth_2.json）
**能力**: 強打[AP30以下]；敵の攻撃成功時能力を無効化

**JSON条件**:
```json
"強打": {
  "condition_type": "enemy_st_check",
  "operator": "<=",
  "value": 30
}
```

**修正内容**:
- `"condition_type": "enemy_st_check"` → `"enemy_ap_check"`

**テスト項目**:
- 敵AP30以下の時：×1.5倍で攻撃
- 敵AP31以上の時：通常攻撃（×1倍）

---

### 2. 貫通[敵AP条件]

#### ID 36: ピュトン（fire_2.json）
**能力**: 貫通[敵AP40以上]；侵略時、魔力獲得[G100]

**JSON条件**:
```json
"貫通": {
  "condition_type": "defender_st_check",
  "operator": ">=",
  "value": 40
}
```

**修正内容**:
- `"condition_type": "defender_st_check"` → `"defender_ap_check"`

**テスト項目**:
- 敵AP40以上の時：土地ボーナス無効化
- 敵AP39以下の時：土地ボーナス有効のまま
- 侵略成功時に魔力獲得[G100]

---

### 3. 秘術[敵AP条件]

#### ID 347: ロードオブペイン（wind_2.json）
**能力**: 応援[風水・AP+|AP-|AP=10]；秘術[G60・ST30以下をAP+|AP-|AP=20、ST50以上をAP+|AP-|AP=20]

**JSON条件**:
```json
"秘術": [
  {
    "condition_type": "enemy_st_check",
    "operator": "<=",
    "value": 30,
    "effect": "AP+|AP-|AP=20"
  },
  {
    "condition_type": "enemy_st_check",
    "operator": ">=",
    "value": 50,
    "effect": "AP+|AP-|AP=20"
  }
]
```

**修正内容**:
- 両方の`"condition_type": "enemy_st_check"` → `"enemy_ap_check"`

**テスト項目**:
- 敵AP30以下の時：魔力消費G60で対象敵手札のクリーチャー1枚奪取、AP+20
- 敵AP31〜49の時：秘術不発動
- 敵AP50以上の時：魔力消費G60で対象敵手札のクリーチャー1枚奪取、AP+20

---

## 📊 修正対象まとめ

| condition_type | 変更先 | クリーチャーID | 個数 |
|---|---|---|---|
| enemy_st_check | enemy_ap_check | 235, 347 | 2 |
| defender_st_check | defender_ap_check | 36 | 1 |
| **合計** | - | - | **3** |

---

## ✅ テストチェックリスト

- [ ] ブラックナイト（ID 235）- 強打[AP30以下]
  - [ ] AP30以下で×1.5倍
  - [ ] AP31以上で×1倍（通常）

- [ ] ピュトン（ID 36）- 貫通[AP40以上]
  - [ ] AP40以上で土地ボーナス無効化
  - [ ] AP39以下では土地ボーナス有効
  - [ ] 侵略成功時に魔力獲得[G100]

- [ ] ロードオブペイン（ID 347）- 秘術[AP範囲]
  - [ ] AP30以下で秘術発動、AP+20
  - [ ] AP31〜49では秘術不発動
  - [ ] AP50以上で秘術発動、AP+20
  - [ ] 応援効果（風水属性・AP+10）も正常に機能

---

## 📝 修正ファイル一覧（ST → AP）

### コード実装ファイル
- ✅ `scripts/skills/condition_checker.gd`
  - `enemy_st_check` → `enemy_ap_check`
  - `st_below`, `st_above` → `ap_below`, `ap_above`
  
- ✅ `scripts/battle/battle_special_effects.gd`
  - `defender_st_check` → `defender_ap_check`

### JSON データファイル（修正不要）
- earth_2.json, fire_2.json, wind_2.json
- JSON内のcomment/ability_detailは後で一括修正

