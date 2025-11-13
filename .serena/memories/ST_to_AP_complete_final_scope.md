# ST → AP 修正 完全影響範囲（最終版）

**最終更新**: 2025年11月13日

---

## 🎯 修正対象ファイル一覧（全15ファイル）

### 🔴 Tier 1: コア実装ファイル（最優先・バトル関連）

#### 1. scripts/skills/condition_checker.gd
**修正対象**:
- L179-196: `enemy_st_check` ケース（4箇所）
  - `var enemy_st = context.get("enemy_st", 0)` → `"enemy_ap"`
  - オペレータ比較（<=, >=, <, >, ==）
  
- L179-184: `st_above`, `st_below` ケース（2箇所）
  - `var enemy_st = context.get("enemy_st", ...)` → `"enemy_ap"`

- L397-398: nullify チェック内
  - `var attacker_st = attack_context.get("attacker_st", 0)` → `"attacker_ap"`

**影響クリーチャー**: 235（ブラックナイト）, 347（ロードオブペイン）

---

#### 2. scripts/battle/battle_special_effects.gd
**修正対象**:
- L80-85: `attacker_st_above` ケース
  - コメント「攻撃者ST」→「攻撃者AP」
  - `_check_nullify_attacker_st_above()` メソッド呼び出し

- L135-151: `_check_nullify_st_below()` / `_check_nullify_st_above()` メソッド
  - L141: `var attacker_base_st = base_ap + base_up_ap` （コメント確認）
  - L142, 150-151: `attacker_base_st` 変数名（3箇所）

- L160-174: `_check_nullify_attacker_st_above()` メソッド
  - L164: `var attacker_base_st = attacker_base_ap + attacker_base_up_ap`
  - L169: `var defender_base_st = defender_base_ap + defender_base_up_ap`
  - L171: print「攻撃者ST」→「攻撃者AP」、「装備者ST」→「装備者AP」（3箇所）
  - L174: `attacker_base_st > defender_base_st` 比較（3箇所）

- L269-285: `defender_st_check` ケース
  - L273: `var defender_base_st = defender.creature_data.get("ap", 0)` （コメント「基本ST」→「基本AP」）
  - L277-279: `defender_base_st >= value` 等（3箇所）
  - L282, 285: print「防御側ST」→「防御側AP」（2箇所）

**影響クリーチャー**: ID 122（シーホース）, ID 16（シグルド）, ID 1071（ラグドール）

---

#### 3. scripts/battle/skills/skill_penetration.gd
**修正対象**:
- L16-17: コメント「攻撃側ST」→「攻撃側AP」、「防御側ST」→「防御側AP」（2箇所）

- L73-74: コメント（重複）「攻撃側ST」→「攻撃側AP」、「防御側ST」→「防御側AP」（2箇所）

- L123-139: `attacker_st_check` ケース
  - L127: `var attacker_st = attacker_data.get("ap", 0)`
  - L131-133: オペレータ比較（3箇所）
  - L136, 139: print「ST」→「AP」（2箇所）

- L142-158: `defender_st_check` ケース
  - L146: `var defender_st = defender_data.get("ap", 0)`
  - L150-152: オペレータ比較（3箇所）
  - L155, 158: print「ST」→「AP」（2箇所）

**影響クリーチャー**: ID 36（ピュトン）

---

#### 4. scripts/battle/battle_skill_processor.gd
**修正対象**:
- L476-484: `base_st_to_hp` effect_type
  - L476: `if effect_type == "base_st_to_hp"` → `"base_ap_to_hp"` （検討）
  - L477: `var base_st = participant.creature_data.get("ap", 0)` → コメント「基本ST」→「基本AP」
  - L478: `var base_up_st = participant.creature_data.get("base_up_ap", 0)` → 変数名 `base_up_st` → `base_up_ap`
  - L479: `var total_base_st = base_st + base_up_st` → `total_base_ap = base_ap + base_up_ap`
  - L481-484: 複数箇所の `total_base_st` → `total_base_ap` 、print内のコメント「基礎ST」→「基礎AP」

**影響クリーチャー**: ID 49（ローンビースト）

---

#### 5. scripts/skills/effect_combat.gd
**修正対象**:
- L86: `"attacker_st": attack_data.get("st", 0)` → `"attacker_ap": attack_data.get("ap", 0)`

---

### 🟠 Tier 2: CPU AI・バトル評価

#### 6. scripts/flow_handlers/cpu_ai_handler.gd
**修正対象**:
- L233: `var attacker_st = attacker.get("ap", 0)` （変数名は `attacker_ap` のままで問題ない）
- L235: `var defender_st = defender.get("ap", 0)` （変数名は `defender_ap` のままで問題ない）
- L239, 242, 244: 変数名の統一（`attacker_st`, `defender_st` → `attacker_ap`, `defender_ap`）

---

### 🟡 Tier 3: ドキュメント（前出）

#### 7-24. ドキュメントファイル
（前回リスト参照 - condition_patterns_catalog.md, nullify_skill.md など23ファイル）

---

## 📊 修正統計

| ファイル名 | 言語 | 修正個所 | 優先度 |
|---|---|---|---|
| condition_checker.gd | GDScript | 15+ | 🔴 最高 |
| battle_special_effects.gd | GDScript | 25+ | 🔴 最高 |
| skill_penetration.gd | GDScript | 15+ | 🔴 最高 |
| battle_skill_processor.gd | GDScript | 10+ | 🔴 最高 |
| effect_combat.gd | GDScript | 2 | 🔴 最高 |
| cpu_ai_handler.gd | GDScript | 5+ | 🟠 高 |
| ドキュメント23ファイル | Markdown | 250+ | 🟡 中 |
| **合計** | - | **300+** | - |

---

## 🎯 修正キーワード一覧

### 置換対象
1. `enemy_st_check` → `enemy_ap_check`
2. `defender_st_check` → `defender_ap_check`
3. `attacker_st_check` → `attacker_ap_check`（検討中）
4. `base_st_to_hp` → `base_ap_to_hp`（検討中）
5. `attacker_st` → `attacker_ap`（変数名）
6. `defender_st` → `defender_ap`（変数名）
7. `base_st` → `base_ap`（変数名）
8. `base_up_st` → `base_up_ap`（変数名）
9. `total_base_st` → `total_base_ap`（変数名）
10. `enemy_st` → `enemy_ap`（コンテキスト）

### コメント内の置換
- 「基本ST」→「基本AP」
- 「攻撃側ST」→「攻撃側AP」
- 「防御側ST」→「防御側AP」
- 「基礎ST」→「基礎AP」

---

## ✅ テストクリーチャー完全リスト

| ID | 名前 | スキル | 修正対象ファイル |
|-----|------|--------|-----------------|
| **16** | シグルド | 即死[AP50以上]；無効化[MHP50以上] | battle_special_effects.gd |
| **36** | ピュトン | 貫通[AP40以上]；侵略時、魔力獲得[G100] | skill_penetration.gd |
| **49** | ローンビースト | HP+基礎AP | battle_skill_processor.gd |
| **122** | シーホース | 感応[風]；無効化[AP40以下] | battle_special_effects.gd |
| **235** | ブラックナイト | 強打[AP30以下]；敵の攻撃成功時能力を無効化 | condition_checker.gd |
| **347** | ロードオブペイン | 応援[風水]；秘術[AP範囲] | condition_checker.gd |
| **144** | ラハブ | 無効化[AP50以上]；応援[水風] | battle_special_effects.gd |
| **415** | ワイバーン | 即死[AP40以上] | condition_checker.gd |
| - | ラグドール（アイテム1071） | 無効化[攻撃者AP > 装備者AP] | battle_special_effects.gd |

---

## 🔄 修正実行順序

**Phase 1: コア実装（5ファイル）**
1. condition_checker.gd - `enemy_st_check` → `enemy_ap_check`
2. battle_special_effects.gd - `defender_st_check` 等
3. skill_penetration.gd - `attacker_st_check`, `defender_st_check`
4. battle_skill_processor.gd - `base_st_to_hp` → `base_ap_to_hp`
5. effect_combat.gd - `attacker_st` → `attacker_ap`

**Phase 2: 補助実装（1ファイル）**
6. cpu_ai_handler.gd - 変数名統一

**Phase 3: ドキュメント（23ファイル）**
- condition_patterns_catalog.md
- nullify_skill.md
- その他ドキュメント

---

## ⚠️ 重要な注意点

1. **`attacker_st_check`の扱い**
   - 貫通スキル（skill_penetration.gd）で使用
   - → `attacker_ap_check` への変更検討

2. **`base_st_to_hp`の扱い**
   - effect_typeの変更は**ドキュメント・JSONとの一貫性が必要**
   - → JSONファイルも合わせて修正が必要

3. **テスト実装順序**
   - Phase 1修正後、コンパイルテスト
   - 各クリーチャーの動作確認
   - バトルテストツールでの大規模テスト推奨

