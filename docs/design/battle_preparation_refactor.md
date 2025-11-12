# 🔄 BattlePreparation 分割設計書

**更新**: 2025年11月13日

---

## 📋 目次

1. [分割概要](#分割概要)
2. [各ファイルの役割](#各ファイルの役割)
3. [処理フロー](#処理フロー)
4. [ファイル構成](#ファイル構成)

---

## 分割概要

### 理由

`battle_preparation.gd` は複数の責任を持つため、以下の3つに分割：

| 現状 | 分割後 |
|------|--------|
| `battle_preparation.gd` 1ファイル | `BattleItemApplier.gd` + `BattleCurseApplier.gd` + `BattleSkillGranter.gd` |
| 複数責任 | 単一責任 |
| 可読性低い | 各ファイルが独立 |

### 方針

- フォルダは作らず、`scripts/battle/` に直接配置
- `battle_preparation.gd` は「オーケストレーター」として処理順序を管理
- 詳細処理は各クラスに委譲

---

## 各ファイルの役割

### 1. BattleItemApplier.gd

**責務**: アイテム効果を BattleParticipant に適用

**メインメソッド**: 
- `apply_item_effects(participant, item_data, enemy_participant, battle_tile_index)`

**処理内容**:
- ST加算 / HP加算 / 強打付与 / スキル付与 など20以上の効果タイプ
- 属性別配置数ボーナス計算
- 援護クリーチャー処理（SkillAssist連携）
- 反射系スキルはバトル中に処理（ここではスキップ）

**依存**: CardSystem, BoardSystem, SpellMagic参照

---

### 2. BattleCurseApplier.gd

**責務**: 呪いを temporary_effects に変換して適用

**メインメソッド**:
- `apply_creature_curses(participant, tile_index)`

**処理内容**:
- 呪いデータを読み込み
- `stat_boost` / `stat_reduce` を temporary_effects に追加
- `temporary_bonus_hp/ap` を加算

**依存**: なし（独立）

---

### 3. BattleSkillGranter.gd

**責務**: アイテムからスキル付与条件をチェック＆付与

**メインメソッド**:
- `check_skill_grant_condition(participant, condition, context)`
- `grant_skill_to_participant(participant, skill_name, skill_data)`

**処理内容**:
- スキル付与条件の判定（ConditionChecker連携）
- 各スキルを ability_parsed に追加
- 支援12種類のスキル対応（先制、強打、即死など）

**依存**: ConditionChecker, FirstStrikeSkill, DoubleAttackSkill等

---

## 処理フロー

```
prepare_participants() (battle_preparation.gd)
  │
  ├─ 1. BattleParticipant作成
  │
  ├─ 2. apply_effect_arrays() (battle_preparation.gd)
  │     └─ permanent/temporary_effects を HP/AP に反映
  │
  ├─ 3. BattleCurseApplier.apply_creature_curses()
  │     └─ 呪い → temporary_effects に変換
  │
  ├─ 4. BattleItemApplier.apply_item_effects()
  │     └─ アイテム効果を適用
  │
  ├─ 5. 特殊クリーチャー処理 (battle_preparation.gd)
  │     ├─ リビングアーマー (ST+50)
  │     ├─ ブルガサリ (アイテム使用時 ST+20)
  │     └─ オーガロード (隣接自領地ボーナス)
  │
  └─ 6. 変身スキル処理 (battle_preparation.gd)
		└─ on_battle_start 変身を実行
```

---

## ファイル構成

### 配置

```
scripts/battle/
  ├─ battle_preparation.gd (オーケストレーター)
  ├─ battle_item_applier.gd (新規)
  ├─ battle_curse_applier.gd (新規)
  └─ battle_skill_granter.gd (新規)
```

### 呼び出し関係

```
battle_system.gd
  └─ battle_preparation.prepare_participants()
	   ├─ apply_effect_arrays()
	   ├─ BattleCurseApplier.apply_creature_curses()
	   ├─ BattleItemApplier.apply_item_effects()
	   ├─ [特殊クリーチャー処理]
	   └─ [変身処理]
```

---

## 実装スケジュール

1. **BattleCurseApplier.gd** を作成
   - `_apply_creature_curses()` を抜き出す
   
2. **BattleItemApplier.gd** を作成
   - `apply_item_effects()` をほぼそのまま移行
   
3. **BattleSkillGranter.gd** を作成
   - スキル付与ロジックを抜き出す
   
4. **battle_preparation.gd** を修正
   - 上記3クラスを使用
   - オーケストレーター化

---

**注**: 各ファイルの詳細な実装は、分割時に別途ドキュメント作成
