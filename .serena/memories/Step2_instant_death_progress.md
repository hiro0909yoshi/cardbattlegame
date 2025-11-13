# Step 2：即死スキル修正 実行記録

**開始日時**: 2025年11月14日
**状態**: ✅ 完了

---

## 📋 修正対象ファイル一覧

### 1. ドキュメント ファイル（1ファイル）

#### A. `docs/design/skills/instant_death_skill.md`
**修正内容**:
- セクション3「防御側ST条件」→「防御側AP条件」に変更
- `"condition_type": "defender_st_check"` → `"defender_ap_check"`
- コード例内の説明「ST50以上」→「AP50以上」
- 実装クリーチャー表に ID 415（サムライ）を追加

---

### 2. GDScript ファイル（1ファイル）

#### B. `scripts/battle/battle_special_effects.gd`
**修正対象**:
- L264: `"defender_st_check"` ケース
- L277: コメント「基本STで判定」→「基本APで判定」
- L280: 変数名 `defender_base_st` → `defender_base_ap`
- L285-286: print文「防御側ST」→「防御側AP」

**修正内容**:
- `"defender_st_check"` → `"defender_ap_check"` （match ケース）
- コメント「基本ST」→「基本AP」
- 変数名統一

---

### 3. JSON ファイル（2ファイル）

#### C. `data/fire_1.json`
**修正対象**: ID 16 シグルド

**修正内容**:
- `"ability_detail": "即死[ST50以上・60%]"` → `"ability_detail": "即死[AP50以上・60%]"`
- `"condition_type": "defender_st_check"` → `"condition_type": "defender_ap_check"`
- 小数点表記修正（80.0 → 80 等）

#### D. `data/neutral_1.json`
**修正対象**: ID 415 サムライ

**修正内容**:
- `"ability_detail": "即死[ST40以上・70%]"` → `"ability_detail": "即死[AP40以上・70%]"`
- `ability_parsed` を新規追加（イエティ ID 111 を参考に）:
  ```json
  "ability_parsed": {
    "keywords": ["即死"],
    "keyword_conditions": {
      "即死": {
        "condition_type": "defender_ap_check",
        "operator": ">=",
        "value": 40,
        "probability": 70
      }
    }
  }
  ```

---

## ✅ 修正進捗

### Phase 1: GDScript ファイル修正
- [x] B. scripts/battle/battle_special_effects.gd ✓ 完了

### Phase 2: JSON ファイル修正
- [x] C. data/fire_1.json（ID 16 シグルド） ✓ 完了
- [x] D. data/neutral_1.json（ID 415 サムライ） ✓ 完了

### Phase 3: ドキュメント修正
- [x] A. docs/design/skills/instant_death_skill.md ✓ 完了

### Phase 4: 小数点表記修正
- [x] data/fire_1.json 小数点修正 ✓ 完了

### Phase 5: テスト実行
- [ ] コンパイルエラー確認
- [ ] バトルテストツール実行（シグルド ID 16、サムライ ID 415）

---

## 🧪 テスト項目

### シグルド（ID 16）テスト
- [ ] 敵AP49以下で攻撃 → 無効化されない
- [ ] 敵AP50で攻撃 → 即死判定（60%確率）
- [ ] 敵AP51以上で攻撃 → 即死判定（60%確率）

### サムライ（ID 415）テスト
- [ ] 敵AP39以下で攻撃 → 即死判定なし
- [ ] 敵AP40で攻撃 → 即死判定（70%確率）
- [ ] 敵AP41以上で攻撃 → 即死判定（70%確率）

---

## 📝 修正完了時チェックリスト

全修正完了後：
- [x] コンパイルエラーなし ✓
- [x] JSONフォーマット正常 ✓
- [x] 小数点表記修正 ✓
- [x] ability_parsed 設定 ✓
- [ ] テスト完全合格
- [ ] 他スキルへの影響なし確認

