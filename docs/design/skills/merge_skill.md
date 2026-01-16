# 合体スキル

**バージョン**: 1.0  
**最終更新**: 2025年12月10日

---

## 📋 目次

1. [概要](#概要)
2. [発動条件](#発動条件)
3. [発動タイミング](#発動タイミング)
4. [効果](#効果)
5. [コスト計算](#コスト計算)
6. [実装済みクリーチャー](#実装済みクリーチャー)
7. [使用例](#使用例)
8. [JSONデータ形式](#jsonデータ形式)
9. [実装メモ](#実装メモ)

---

## 概要

特定のクリーチャー同士を掛け合わせると、**別のクリーチャーに永続的に変化**するスキル。バトル中に自動発動し、変化後のクリーチャーでバトルを行う。

---

## 発動条件

- バトル参加クリーチャーが「合体」スキルを持っている
- 手札に合体相手（partner_id）のクリーチャーがいる
- 合体相手のコスト分の魔力を支払える

---

## 発動タイミング

```
召喚フェーズ → アイテム選択フェーズ（合体相手を選択）→ バトル開始処理
```

- **アイテム選択フェーズ**で合体相手を選択して発動
- 援護スキルと同様の選択式（アイテムの代わりに合体相手を選ぶ）
- 合体相手を選択しなければ合体しない（アイテムを使うか、パスする選択肢もある）

---

## 効果

| 項目 | 内容 |
|------|------|
| クリーチャー変化 | result_idで指定されたクリーチャーに変身 |
| ステータス | 変身先の基本ステータスになる |
| スキル | 変身先のスキルになる |
| 永続性 | **永続変化**（戦闘後も元に戻らない） |
| 合体相手カード | 捨て札へ |

---

## コスト計算

通常のコスト計算と同様：

```
合計コスト = 召喚コスト + アイテムコスト + 合体相手コスト
```

- 合体相手クリーチャーのmp値をそのまま魔力消費

---

## 実装済みクリーチャー

**合計3体**が合体スキルを持っています。

### 合体パターン一覧

| バトル側 | ID | 合体相手 | partner_id | 結果 | result_id |
|----------|-----|----------|------------|------|-----------|
| アンドロギア | 406 | ビーストギア | 434 | ギアリオン | 408 |
| グランギア | 409 | スカイギア | 419 | アンドロギア | 406 |
| スカイギア | 419 | グランギア | 409 | アンドロギア | 406 |

※ グランギア + スカイギア と スカイギア + グランギア は同じ結果（アンドロギア）

---

## 使用例

### シナリオ: グランギアの合体

```
1. グランギア（ID:409、合体スキル持ち）でバトル開始
2. 手札にスカイギア（ID:419）がある
3. アイテム選択フェーズ完了後、合体フェーズに入る
4. 自動的に合体発動
   - スカイギアのコスト分の魔力を消費
   - スカイギアは捨て札へ
5. グランギアがアンドロギア（ID:406）に永続変化
6. アンドロギアのステータス・スキルでバトル開始
7. 戦闘後もアンドロギアのまま（タイルのクリーチャーデータも更新済み）
```

---

## JSONデータ形式

### ability_parsed内の定義

```json
{
  "ability_parsed": {
	"keywords": ["合体"],
	"keyword_conditions": {
	  "合体": {
		"partner_id": 419,
		"result_id": 406
	  }
	}
  }
}
```

### パラメータ

| キー | 型 | 説明 |
|------|-----|------|
| partner_id | int | 合体相手のクリーチャーID |
| result_id | int | 合体結果のクリーチャーID |

---

## 実装メモ

### 実装ファイル

**コアロジック（統一インターフェース）**:
- `scripts/battle/skills/skill_merge.gd` - 合体スキル判定・実行
  - `has_merge_skill()` - 合体スキル所持チェック
  - `get_merge_partner_id()` - 合体相手IDを取得
  - `get_merge_result_id()` - 合体結果IDを取得
  - `find_merge_partner_in_hand()` - 手札に合体相手がいるかチェック
  - **`execute_merge()`** - 合体実行（統一インターフェース）
  - `_create_merged_creature_data()` - 合体後クリーチャーデータ作成

**呼び出し元**:
- `scripts/game_flow/item_phase_handler.gd`
  - `_execute_merge()` → `SkillMerge.execute_merge()` に委譲
  - `_execute_merge_for_cpu()` → `SkillMerge.execute_merge()` に委譲
- `scripts/tile_action_processor.gd`
  - `_check_and_execute_cpu_attacker_merge()` → `SkillMerge.execute_merge()` に委譲

**CPU判断**:
- `scripts/cpu_ai/cpu_merge_evaluator.gd` - 合体オプション評価・シミュレーション

### 援護スキルとの違い

| 項目 | 援護 | 合体 |
|------|------|------|
| 発動タイミング | アイテムフェーズ | アイテムフェーズ |
| 発動方式 | 手動選択 | 手動選択 |
| 効果 | AP/HP加算 | クリーチャー変身 |
| 永続性 | 戦闘中のみ | 永続変化 |
| スキル継承 | なし | 変身先のスキル |
| タイルデータ | 変更なし | バトル勝利時に更新 |

### 処理フロー

```
【プレイヤー】
1. バトル開始 → ItemPhaseHandler.start_item_phase()
2. 合体スキル持ちなら手札に合体相手を選択可能として表示
3. プレイヤーが合体相手を選択 → use_item() → _execute_merge()
4. _execute_merge() → SkillMerge.execute_merge() に委譲
5. 合体後データをmerged_creature_dataに保存
6. creature_mergedシグナル発行
7. バトル開始処理へ

【CPU攻撃側】
1. CPUBattleAI.decide_invasion() で合体判断
2. CPUMergeEvaluator.check_merge_option_for_attack() でシミュレーション
3. 合体選択時 → pending_merge_data に保存
4. TileActionProcessor.execute_battle()
5. _check_and_execute_cpu_attacker_merge() → SkillMerge.execute_merge() に委譲
6. pending_battle_card_data を更新
7. ItemPhaseHandler.start_item_phase() へ

【CPU防御側】
1. ItemPhaseHandler._cpu_decide_item() で合体判断
2. 合体選択時 → _execute_merge_for_cpu()
3. _execute_merge_for_cpu() → SkillMerge.execute_merge() に委譲
```

※ 永続化は侵略成功時にタイルに配置されるため、バトルシステム側で行われる

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/12/10 | 1.0 | 初版作成 |
| 2026/01/16 | 1.1 | SkillMerge.execute_merge()統一インターフェース追加、実装フローを更新 |
