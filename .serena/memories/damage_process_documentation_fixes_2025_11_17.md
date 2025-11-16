# ダメージ処理ドキュメント修正リスト (2025-11-17)

## 概要
base_up_hp が消費可能なHPではなく、永続的なMHPボーナスであることが確認されたため、ダメージ消費順序の定義を修正する必要があります。

## 修正が必要なドキュメント

### 1. **hp_structure.md** ⭐ 最優先
**ファイルパス**: `docs/design/hp_structure.md`

**現在の問題**:
```
### ダメージ消費順序

ダメージを受けた時、以下の順序でHPが消費される：

1. resonance_bonus_hp（感応ボーナス）
2. land_bonus_hp（土地ボーナス）
3. temporary_bonus_hp（一時ボーナス）
4. item_bonus_hp（アイテムボーナス）
5. spell_bonus_hp（スペルボーナス）
6. base_up_hp（永続的な基礎HP上昇）  ← ❌ これが問題
7. base_hp（元のHP、最後）
```

**修正内容**:
- base_up_hp は削除（消費順序から外す）
- 新しいダメージ消費順序：
  1. resonance_bonus_hp（感応ボーナス）
  2. land_bonus_hp（土地ボーナス）
  3. temporary_bonus_hp（一時ボーナス）
  4. item_bonus_hp（アイテムボーナス）
  5. spell_bonus_hp（スペルボーナス）
  6. base_hp（元のHP、最後に消費）

**詳細**:
- base_up_hp は永続的なMHPボーナスで、ダメージでは削られない
- 永続バフは戦闘終了後も維持される
- 削られるのは base_hp のみ

---

### 2. **effect_system_design.md** ⭐ 最優先
**ファイルパス**: `docs/design/effect_system_design.md`

**現在の問題**:
```
### ダメージ消費順序

1. resonance_bonus_hp（感応ボーナス）
2. land_bonus_hp（土地ボーナス）
3. temporary_bonus_hp（一時ボーナス）
4. item_bonus_hp（アイテムボーナス）
5. base_up_hp（永続的な基礎HP上昇）  ← ❌ これが問題
6. base_hp（元のHP）
```

**修正内容**:
- hp_structure.md と同じ修正
- base_up_hp を削除
- 説明を追加：なぜ base_up_hp は削られないのか

---

### 3. **condition_patterns_catalog.md** (条件パターンカタログ)
**ファイルパス**: `docs/design/condition_patterns_catalog.md`

**確認項目**:
- 「雪辱」スキルの処理を確認
- take_mhp_damage 処理の説明が正しいか確認
- 「HP-30」という記述がある場合、修正が必要かチェック

**予想される問題**:
- 雪辱スキルは base_hp を直接削る（base_up_hp は削らない）
- ドキュメントの説明が古い可能性

---

### 4. **skills_design.md** (スキル設計)
**ファイルパス**: `docs/design/skills_design.md`

**確認項目**:
- バイロマンサー（ID: 34）のスキル説明を確認
- 雪辱スキルの説明を確認
- ダメージ消費順序への言及がないか確認

**予想される問題**:
- ダメージ消費順序の説明がある場合は修正

---

### 5. **skills/ 配下のドキュメント** (特に必要なもの)

**a) スキル系ドキュメント確認対象**:
- `on_death_effects.md` - 死亡時効果（雪辱含む）
- `regeneration_skill.md` - 再生スキル
- `transform_skill.md` - 変身スキル（base_up_hp に関係？）
- `instant_death_skill.md` - 即死スキル

**確認項目**:
- base_up_hp のダメージ削減についての記述があるか
- base_hp と base_up_hp の区別が正しいか

---

### 6. **battle_system.md** (バトルシステム)
**ファイルパス**: `docs/design/battle_system.md`

**確認項目**:
- バトル準備時の HP 初期化処理
- バトル終了時の HP 保存処理
- ダメージ処理についての説明

**予想される問題**:
- ダメージ消費順序の説明がある場合

---

### 7. **item_system.md** (アイテムシステム)
**ファイルパス**: `docs/design/item_system.md`

**確認項目**:
- 1059（ペトリフストーン）の説明
- HP固定値設定について
- base_up_hp が復元されることについての説明

**修正内容**:
- 「HP=80を固定設定した場合、base_up_hp は一時的に0になるが、バトル終了後に元に戻る」という説明を追加

---

## 変更概要

### 変更の種類

1. **直接修正が必要** (最優先)
   - hp_structure.md - ダメージ消費順序から base_up_hp 削除
   - effect_system_design.md - ダメージ消費順序から base_up_hp 削除
   - condition_patterns_catalog.md - 雪辱スキルの説明確認・修正
   - item_system.md - 1059の処理説明追加

2. **確認が必要** (中優先)
   - skills_design.md
   - battle_system.md
   - on_death_effects.md

3. **参考確認** (低優先)
   - その他スキル関連ドキュメント

---

## 修正に伴う関連項目

### 重要な認識の統一

1. **base_up_hp について**
   - 永続的なMHPボーナス
   - ダメージでは削られない（get_max_hp() の計算にのみ使用）
   - バトル後も creature_data に保存される

2. **base_hp について**
   - バトル中の「基本HP」（ダメージ後の残りHP）
   - ダメージで削られる
   - 最後に消費される

3. **ダメージ消費順序**
   - 各種ボーナス → base_hp のみ
   - base_up_hp は含まれない

4. **1059（ペトリフストーン）**
   - HP=80を固定設定
   - base_up_hp を一時的に0にして現在HPを再計算
   - バトル後に base_up_hp を復元

---

## テスト関連

**1059テスト**: ユーザー実施中
**34番（バイロマンサー）**: 現状維持（base_hp -= 30 のまま）

