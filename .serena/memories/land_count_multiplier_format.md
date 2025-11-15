# land_count_multiplier 形式確認結果

**確認日**: 2025年11月14日

## 📋 3つのドキュメントでの記載

### 1. effect_system.md (Line 538-540)
```json
{
  "effect_type": "land_count_multiplier",
  "stat": "ap",
  "elements": ["fire", "earth"],  // ← 配列形式
  "multiplier": 10
}
```
✅ `"elements"` を使用

### 2. conditional_stat_buff_system.md
- `land_count_multiplier` が実装effect_typeの一覧に含まれている
- 詳細な形式記載なし（effect_system.mdを参照）

### 3. condition_patterns_catalog.md (Line 221)
```gdscript
var target_elements = effect.get("elements", [])
var total_count = 0
for element in target_elements:
    total_count += player_lands.get(element, 0)
```
✅ `effect.get("elements", [])` で読み込み

---

## 🎯 結論

**正しい形式は `"elements"` (配列) です**

### 現在のサンダースポーン (ID 318) のデータ
```json
{
  "effect_type": "land_count_multiplier",
  "target": "self",
  "stat": "ap",
  "operation": "add",
  "value": 10,
  "land_element": "water"  // ❌ 間違った形式
}
```

### 正しくあるべき形式
```json
{
  "effect_type": "land_count_multiplier",
  "stat": "ap",
  "elements": ["water"],  // ✅ 配列形式
  "multiplier": 10
}
```

---

## 📝 修正が必要な理由

1. 実装 (battle_skill_processor.gd) は `effect.get("elements", [])` で読み込む
2. ドキュメント (effect_system.md, condition_patterns_catalog.md) では配列形式が標準
3. `"land_element"` フィールドは実装では認識されない
4. サンダースポーンのスキルが発動しない理由

---

## 🔧 修正内容

| 項目 | 現在 | 修正後 |
|------|------|--------|
| フィールド名 | `"land_element"` | `"elements"` |
| 値の形式 | `"water"` (文字列) | `["water"]` (配列) |
| マルチプライヤ | `"value": 10` | `"multiplier": 10` |
