# ST → AP 修正実行計画書

**作成日**: 2025年11月13日

---

## 🎯 修正戦略

### ✅ 推奨アプローチ：「スキル単位での修正」

スキル関連の修正を **関連ファイル** ごとに一括処理するアプローチ

---

## 📋 修正順序（優先度順）

### Phase 1: 基礎条件判定系（最優先）

#### Step 1: 無効化スキル [AP条件版]
**対象ファイル**:
- `docs/design/skills/nullify_skill.md` - ドキュメント
- `data/water_1.json` - シーホース（ID 122）
- `data/water_2.json` - ラハブ（ID 144）
- `scripts/battle/battle_special_effects.gd` - 無効化判定ロジック

**修正内容**:
- `st_below` → `ap_below`
- `st_above` → `ap_above`
- 無効化判定メソッドのコメント修正

**テスト**: シーホース（AP40以下）、ラハブ（AP50以上）

---

#### Step 2: 即死スキル [AP条件版]
**対象ファイル**:
- `docs/design/skills/instant_death_skill.md` - ドキュメント
- `data/neutral_1.json` - ワイバーン（ID 415）
- `data/fire_1.json` - シグルド（ID 16）
- `scripts/battle/battle_special_effects.gd` - 即死判定ロジック

**修正内容**:
- `defender_st_check` → `defender_ap_check`
- コメント「基本ST」→「基本AP」

**テスト**: ワイバーン（AP40以上）、シグルド（AP50以上）

---

#### Step 3: 強打スキル [AP条件版]
**対象ファイル**:
- `docs/design/skills/power_strike_skill.md` - ドキュメント
- `data/earth_2.json` - ブラックナイト（ID 235）
- `scripts/skills/condition_checker.gd` - `enemy_st_check` ケース

**修正内容**:
- `enemy_st_check` → `enemy_ap_check`
- コメント「敵ST」→「敵AP」

**テスト**: ブラックナイト（AP30以下）

---

#### Step 4: 貫通スキル [AP条件版]
**対象ファイル**:
- `docs/design/skills/penetration_skill.md` - ドキュメント
- `data/fire_2.json` - ピュトン（ID 36）
- `scripts/battle/skills/skill_penetration.gd` - 貫通判定ロジック

**修正内容**:
- `defender_st_check` → `defender_ap_check`
- `attacker_st_check` → `attacker_ap_check`（要確認）
- コメント「ST」→「AP」（複数箇所）

**テスト**: ピュトン（AP40以上で土地ボーナス無効化）

---

### Phase 2: 特殊効果系

#### Step 5: 秘術スキル [AP条件版]
**対象ファイル**:
- `data/wind_2.json` - ロードオブペイン（ID 347）
- `scripts/skills/condition_checker.gd` - `enemy_st_check` ケース（追加）

**修正内容**:
- `enemy_st_check` → `enemy_ap_check`（2箇所）

**テスト**: ロードオブペイン（AP30以下/50以上での秘術発動）

---

#### Step 6: 基礎AP→HP変換系
**対象ファイル**:
- `data/...json` - ローンビースト（ID 49）
- `scripts/battle/battle_skill_processor.gd` - `base_st_to_hp`

**修正内容**:
- `base_st_to_hp` → `base_ap_to_hp`
- `base_st`, `base_up_st` → `base_ap`, `base_up_ap`
- `total_base_st` → `total_base_ap`

**テスト**: ローンビースト（基本AP+HPボーナス）

---

### Phase 3: ドキュメント一括修正

#### Step 7: 条件パターンカタログ
**対象ファイル**:
- `docs/design/condition_patterns_catalog.md`

**修正内容**:
- セクション3-4「敵のSTチェック」→「敵のAPチェック」
- セクション3-5「基礎STの取得」→「基礎APの取得」
- コード例の `base_st` → `base_ap`
- クリーチャー例の「ST」→「AP」

---

#### Step 8: その他ドキュメント（一括）
**対象ファイル**:
- nullify_skill.md, instant_death_skill.md, power_strike_skill.md 他

**修正内容**:
- ability_detail の「ST」→「AP」
- セクション見出しの「ST」→「AP」

---

## 🔄 実行ステップ

### 各Stepの実行フロー

```
Step実行 → ファイル修正 → テスト実行 → 検証 → 次Stepへ
```

### 各Stepでの作業

1. **ドキュメント修正**（3-5分）
   - ability_detail の変更
   - セクション名の変更

2. **JSONファイル修正**（2-3分）
   - `condition_type` の変更
   - コメント・説明の変更

3. **GDScriptファイル修正**（5-10分）
   - `enemy_st_check` → `enemy_ap_check` 等
   - 変数名の統一
   - print文の修正

4. **テスト実行**（5-15分）
   - バトルテストツールで該当クリーチャーテスト
   - 複数回実行で確率判定確認

5. **検証**（2-3分）
   - コンパイルエラーなし確認
   - 他への影響なし確認

---

## 📊 実行スケジュール（推定）

| Phase | Steps | 時間 | 優先度 |
|-------|-------|------|--------|
| Phase 1 | 1-4 | 60-90分 | 🔴 最高 |
| Phase 2 | 5-6 | 30-45分 | 🟠 高 |
| Phase 3 | 7-8 | 45-60分 | 🟡 中 |
| **合計** | - | **135-195分** | - |

---

## 🎯 開始方法

### どのStepから始めるか

**推奨**: **Step 1（無効化スキル）** から開始

理由：
1. 最も修正が少ない（シンプル）
2. テストが分かりやすい
3. 他スキルへの依存が少ない
4. 成功体験が得られる

---

## ✅ 修正時のチェックリスト

各Stepごとに確認すべき項目：

### ドキュメント修正時
- [ ] ability_detail の「ST」→「AP」完全置換
- [ ] セクション名の修正
- [ ] コード例の修正

### JSON修正時
- [ ] `condition_type` の値を正確に変更
- [ ] JSONフォーマット正常（括弧など）
- [ ] コメント内の説明も修正

### GDScript修正時
- [ ] 全`enemy_st_check` を `enemy_ap_check` に
- [ ] 全変数名を統一（`base_st` → `base_ap`等）
- [ ] print文内のコメントも修正
- [ ] コンパイルエラーなし

### テスト実行時
- [ ] 該当クリーチャーのバトルテスト
- [ ] 条件境界値テスト（例：AP30以下 vs 31以上）
- [ ] 複数回実行で確率判定確認（即死等）

---

## 💡 効率化のコツ

1. **一括置換ツール活用**
   - VSCodeの正規表現置換
   - 例：`enemy_st_check` → `enemy_ap_check`

2. **ドキュメント修正は並列化可能**
   - 複数ドキュメントを同時修正

3. **テストは優先度順**
   - Phase 1完了後に一度バトルテストツール実行
   - 全Stepのテストを最後に一括実行

4. **バージョン管理活用**
   - 各Stepごとにコミット
   - 問題発生時に巻き戻し可能

---

## 🚀 第1ステップ実行予定

### Step 1: 無効化スキル [AP条件版]

修正ファイル：
1. ✅ `docs/design/skills/nullify_skill.md`
2. ✅ `data/water_1.json` - シーホース（ID 122）
3. ✅ `data/water_2.json` - ラハブ（ID 144）
4. ✅ `scripts/battle/battle_special_effects.gd` - メソッド修正

修正内容：
- `"st_below"` → `"ap_below"`
- `"st_above"` → `"ap_above"`
- コメント「ST」→「AP」

テスト対象：
- シーホース：敵AP40以下で無効化
- ラハブ：敵AP50以上で無効化

---

**準備完了！** 

次のステップをお知らせください：
1. Step 1 から始める
2. 別のStepから始める
3. 別のアプローチを使用する

