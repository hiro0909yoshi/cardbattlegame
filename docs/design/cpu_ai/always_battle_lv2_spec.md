# ALWAYS_BATTLE_LV2 ポリシー仕様

## 1. 概要

`ALWAYS_BATTLE_LV2` は、既存の `ALWAYS_BATTLE` を「**1段階上の思考回路**」にアップグレードしたポリシー。

- **Lv1 (ALWAYS_BATTLE)**: 勝敗・効果を問わず戦闘を仕掛ける脳筋ポリシー。低レベルCPUの"馬鹿さ加減"を表現
- **Lv2 (ALWAYS_BATTLE_LV2)**: 揺さぶり戦術の思想は継承しつつ、「**完全に無意味な戦闘**」だけは回避する賢さを持つ
- **Lv3 (予定)**: Lv2 に加えてアイテム使用も行う、より積極的な揺さぶりポリシー

本ドキュメントでは **Lv2** の仕様を定義する。

## 2. 設計思想

### 2.1 継承する思想（Lv1 と同じ）
- 敵にアイテムを吐かせるための**揺さぶり戦術**として、積極的に戦闘を仕掛ける
- アイテムは**一切使用しない**（相手にアイテムを使わせることが目的であり、自分が使うのは矛盾）

### 2.2 Lv1 から変化する点
- **完全に無意味な戦闘は行わない**
  - AP 0 クリーチャーでの攻撃
  - 無効化スキル対象のクリーチャーでの攻撃
  - ランドボーナスすら削れない攻撃
- **勝てる戦闘は見逃さない**
  - 無装備で勝てるなら勝ちに行く
  - アイテムを仮想的に使えば勝てる状況も攻撃機会として認識
- **本体HPに到達できる攻撃を優先**
  - ランドボーナスを抜いて敵の"本体HP (base_hp)"にダメージを通せるかを基準に判定

### 2.3 キーコンセプト：「本体HPに到達するダメージ」

カルドセプト系HP構造：
```
total_hp = base_hp + base_up_hp + land_bonus_hp + (その他一時ボーナス)
          └─────┬─────┘  └──────┬──────┘
          "クリーチャー本体"    "土地の防御壁"
```

`land_bonus_hp = land_level × 10`

**本体HPに到達する** = ダメージが `land_bonus_hp` を超えて `base_hp` に1以上届くこと。
ランドボーナスだけ削っても、土地壁を叩いただけで実質無意味と判断する。

## 3. クリーチャー選択フロー

戦闘候補のクリーチャーを以下の優先順で選定する。

### Step 1: 両方アイテムなしで勝てる → 戦闘
- 自分もアイテムなし、敵もアイテムなしで勝利可能な組み合わせを探索
- 該当あり → そのクリーチャーで戦闘（**アイテム使用せず**）
- 複数いれば、既存の `_select_optimal_combination` と同様の優先順位（コスト最小 → オーバーキル最小）
- **実装**: 既存の `can_win_both_no_item` / `best_both_no_item_creature_index` を流用

### Step 2: アイテムを仮想使用すれば勝てる → 戦闘（アイテムは使わない）
- 「もし自分がアイテムを使ったら勝てる」クリーチャーを探索
- 該当あり → そのクリーチャーで戦闘（**item_index = -1 を強制**）
- 狙い: この強力なクリーチャーを敵に見せつけることで、防御アイテムを誘発させる
- **実装**: 既存の `find_item_to_beat_worst_case` 系の結果を流用、ただし戻り値の `item_index` は無視

### Step 3: 本体HPを削れる → 戦闘
絶対条件：
- ✅ ランドボーナスを抜けて本体HPに1以上のダメージを通せる
- ✅ 敵の無効化スキル対象外である

その中から以下の優先順位で選定：

#### Step 3-a: 敵の反撃で倒されない、かつ本体HPを削れる
- 判定: 敵がアイテム**不使用**で反撃した場合、自分のクリーチャーが生存するか
  - 生存定義: `attacker_survives == true`（ドロー・引き分けも生存扱い）
- 複数該当時の選定:
  1. 本体HPへの削りダメージが大きい順
  2. 同点ならクリーチャーコストが小さい順
- **実装**: `simulate_battle` を通常攻守で実行し、`attacker_survives` と「本体HPへの実効ダメージ」を確認

#### Step 3-b: 敵に倒されるが本体HPを大きく削れる（捨て身特攻）
3-a に該当なしの場合のみ検討。条件（**全て AND**）:
- ✅ 本体HPへの削りダメージ ≥ 10
- ✅ 攻撃後の敵残HP ≤ 40
- ✅ 自クリーチャーのCPUレート（`CardRateEvaluator.get_rate`） ≤ 80

条件を満たす候補から以下の優先順位で選定：
1. 本体HPへの削りダメージが大きい順
2. 同点ならクリーチャーコストが小さい順
3. 同点ならCPUレートが低い順（より「使い捨て」可能なクリーチャー）

**設計意図**:
- ダメージ 10 以上 かつ 残HP 40 以下 → 「弱りかけの敵にトドメを狙う」状況
- CPUレート 80 以下 → 高価値クリーチャーを捨て駒にしない
- 大型クリーチャー（HP 60+）には Step 3-b は基本的に機能しない（意図通り）

### Step 4: 上記すべて該当なし → 戦闘しない
- 通行料を支払う
- **Lv1 との違い**: Lv1 はここでも無理やり攻撃するが、Lv2 は無駄戦闘を避けて通行料を選ぶ

## 4. 絶対ルール（全Stepで適用）

| ルール | 説明 |
|--------|------|
| アイテム使用禁止 | 実行時、アイテムを一切消費しない（Step 2 のアイテムも仮想判定のみ） |
| 無効化対象除外 | 敵が `nullify` スキル持ち等で無効化する対象のクリーチャーは選ばない |
| 壁抜け必須 | ランドボーナスを抜けない（本体HPに届かない）クリーチャーは Step 3 で選ばない |

## 5. 既存フローとの統合

`cpu_battle_ai.gd::evaluate_all_combinations_for_battle()` の既存フローは以下：

```
0. 合体評価（merge_evaluator）          ← 最優先、継続
0.5 敵が無効化アイテム所持 → 即死優先    ← 継続
1. 通常の勝てる組み合わせ評価            ← Lv2 の Step 1/2 で流用
2. 勝てる組み合わせなし → 即死スキル賭け ← Lv2 では Step 4 の前に維持
3. 戦闘しない                            ← Lv2 では Step 4
```

Lv2 の新ロジックは **Step 3（本体HP削り判定）を既存フローの 1 と 2 の間に差し込む** 形で実装する。

```
Lv2 フロー:
  0. 合体評価
  0.5 無効化+即死優先
  1. Step 1/2: 勝てる組み合わせ検索（既存流用）
  2. （新規）Step 3-a: 生存かつ本体削れるクリーチャー
  3. （新規）Step 3-b: 捨て身で本体削れるクリーチャー
  4. 即死スキル賭け（既存）
  5. Step 4: 戦闘しない
```

## 6. データフロー

### 6.1 `battle_simulator.gd` への拡張

現在の `simulate_battle()` 戻り値に以下のフィールドを追加：

| フィールド | 型 | 説明 |
|-----------|---|------|
| `damage_to_defender_base_hp` | int | 防御側の本体HP(`base_hp + base_up_hp`)に実際に入ったダメージ量。0 なら本体未到達 |
| `defender_land_bonus_hp` | int | 防御側のランドボーナスHP値（判定の補助情報） |

これにより、呼び出し側は `damage_to_defender_base_hp > 0` で「本体HPに届いたか」を確実に判定できる。

### 6.2 `cpu_battle_ai.gd` への拡張

`evaluate_all_combinations_for_battle()` の戻り値に以下を追加：

| フィールド | 型 | 説明 |
|-----------|---|------|
| `lv2_step3a_creature_index` | int | Step 3-a の最適クリーチャーindex、該当なしなら -1 |
| `lv2_step3b_creature_index` | int | Step 3-b の最適クリーチャーindex、該当なしなら -1 |

各クリーチャー評価ループ内で上記を同時計算する。

### 6.3 `cpu_ai_handler.gd` への分岐追加

`match action` に新ケース追加：

```gdscript
CPUBattlePolicyScript.AttackAction.ALWAYS_BATTLE_LV2:
    # Step 1: 両方アイテムなしで勝てる
    if eval_result.get("can_win_both_no_item", false):
        creature_index = eval_result.get("best_both_no_item_creature_index", -1)
        item_index = -1
    # Step 2: アイテム使えば勝てる（仮想）
    elif eval_result.get("can_win_vs_enemy_item", false):
        creature_index = eval_result.creature_index
        item_index = -1  # アイテム使用を強制的に無効化
    # Step 3-a: 生存 & 本体削り
    elif eval_result.get("lv2_step3a_creature_index", -1) >= 0:
        creature_index = eval_result.get("lv2_step3a_creature_index")
        item_index = -1
    # Step 3-b: 捨て身特攻
    elif eval_result.get("lv2_step3b_creature_index", -1) >= 0:
        creature_index = eval_result.get("lv2_step3b_creature_index")
        item_index = -1
    # Step 4: 戦闘しない
    else:
        creature_index = -1
        item_index = -1
```

## 7. ポリシー選択条件

`decide_attack_action()` の選択可能条件:

- `ALWAYS_BATTLE_LV2` は**常に選択可能**
- ただし、Step 1〜3 のどれにも該当しない場合は実質「攻撃しない」に落ちる
- 他ポリシーと重み付き混合可能

### 7.1 JSON 設定例

```json
{
  "enemy_stage3_boss": {
    "battle_policy": {
      "attack": {
        "always_battle": 0.0,
        "always_battle_lv2": 0.8,
        "vs_enemy_item": 0.2,
        "never_battle": 0.0
      }
    }
  }
}
```

## 8. 移動AI（`cpu_movement_evaluator.gd`）との整合

`get_policy_based_battle_result()` にも新ポリシーの分岐追加が必要：

```gdscript
CPUBattlePolicyScript.AttackAction.ALWAYS_BATTLE_LV2:
    # 勝てる場合は勝ち扱い、それ以外は負け前提だが戦闘する扱い
    if eval_result.get("can_win_both_no_item", false) or eval_result.get("can_win_vs_enemy_item", false):
        return {"will_battle": true, "will_win": true}
    elif eval_result.get("lv2_step3a_creature_index", -1) >= 0 \
         or eval_result.get("lv2_step3b_creature_index", -1) >= 0:
        return {"will_battle": true, "will_win": false}
    else:
        return {"will_battle": false, "will_win": false}
```

これを入れないと、移動方向選択時に ALWAYS_BATTLE_LV2 キャラが判断を誤る。

## 9. 影響範囲・リスク

### 9.1 変更対象ファイル

| ファイル | 変更内容 | リスク |
|---------|---------|--------|
| `scripts/cpu_ai/cpu_battle_policy.gd` | enum 追加、load_from_json 対応、選択条件追加 | 低 |
| `scripts/cpu_ai/cpu_battle_ai.gd` | Step 3-a / 3-b の評価ロジック追加、戻り値拡張 | 中 |
| `scripts/cpu_ai/cpu_ai_handler.gd` | decide_battle / get_policy_based_battle_result に分岐追加 | 低 |
| `scripts/cpu_ai/battle_simulator.gd` | 戻り値に本体ダメージ情報を追加 | **中（スペルAI等が使っている可能性あり）** |
| `data/master/characters/characters.json` | テスト用キャラに新ポリシー割り当て | 低 |

### 9.2 既存機能への影響懸念点

1. **battle_simulator.gd の戻り値拡張**
   - 既存の呼び出し元（スペルAI、防御評価器など）は新フィールドを参照しないので破壊はしないが、念のため全呼び出し元の事前確認を推奨
   - 確認対象: `scripts/cpu_ai/` 配下および `scripts/spells/` 配下で `simulate_battle` を呼ぶ箇所

2. **ターン内キャッシュ**
   - `_turn_attack_action_cache` に新ポリシーもキャッシュされるか確認
   - 基本的には int 値なので問題ないはずだが、移動シミュレーションでの事前抽選と実戦闘時の結果が一致するか要テスト

3. **合体（merge）・無効化+即死優先ロジックとの順序**
   - これらは `evaluate_all_combinations_for_battle` の冒頭で動く
   - 新ポリシーでもこれらを先に通す設計とする（仕様5の統合フロー参照）

4. **敵AI（防御側）の反応**
   - Step 2 の「仮想アイテム使用で勝てるクリーチャー」を敵AIがどう認識するかは `cpu_defense_ai.gd` の挙動次第
   - 敵が実際のAPを見て判断している場合、Step 2 の揺さぶり効果は限定的
   - **事前確認項目**: `cpu_defense_ai.gd` が防御アイテム使用を決定する際の判断基準

5. **移動AI の判断**
   - 上記 8 節の対応を忘れるとバグる

## 10. 確認すべき事前調査項目（実装前チェックリスト）

実装着手前に以下を確認する：

- [ ] `battle_simulator.simulate_battle()` の呼び出し元をすべて洗い出し（grep）
- [ ] 呼び出し元で戻り値の dictionary にキー追加しても壊れないことを確認
- [ ] `cpu_defense_ai.gd` の防御アイテム使用判断ロジックを把握（Step 2 の揺さぶり効果予測のため）
- [ ] `_turn_attack_action_cache` の動作を確認（新ポリシーが正しくキャッシュされるか）
- [ ] `cpu_movement_evaluator.gd` 内で `get_policy_based_battle_result` を呼んでいる箇所を確認
- [ ] `merge_evaluator` / `_check_instant_death_gamble` / `_check_nullify_instant_death_priority` の優先順位との競合確認

## 11. 実装後の検証項目（テストチェックリスト）

### 11.1 単体確認

- [ ] JSON からポリシー読み込み成功（`always_battle_lv2: 1.0`）
- [ ] Step 1: 両方なしで勝てる → 該当クリーチャー選択（アイテムなし）
- [ ] Step 2: 仮想アイテム使用で勝てる → 該当クリーチャー選択、実際アイテム消費なし
- [ ] Step 3-a: 生存＆本体削り → 正しく選択
- [ ] Step 3-b: 捨て身特攻（全条件合致） → 正しく選択
- [ ] Step 3-b: ダメージ < 10 → 除外
- [ ] Step 3-b: 残HP > 40 → 除外
- [ ] Step 3-b: CPUレート > 80 → 除外
- [ ] 無効化対象クリーチャー → 選ばれない
- [ ] ランドボーナスを抜けないクリーチャー → 選ばれない
- [ ] Step 4: どれも該当しない → 通行料支払い

### 11.2 エッジケース

- [ ] 手札クリーチャー 0 体 → 通行料
- [ ] 手札に使い捨て可能なクリーチャーしかない → Step 3-b で正しく選ばれる
- [ ] 敵が無効化アイテム所持 → 既存の即死優先が先に動く
- [ ] 合体可能 → 合体優先
- [ ] 即死スキル持ち → Step 4 の前に即死賭けが動く

### 11.3 リグレッション

- [ ] 既存の `ALWAYS_BATTLE` キャラの挙動が変化しないこと
- [ ] `BATTLE_IF_BOTH_NO_ITEM` キャラの挙動が変化しないこと
- [ ] `BATTLE_IF_WIN_VS_ENEMY_ITEM` キャラの挙動が変化しないこと
- [ ] チュートリアルステージの挙動が変化しないこと
- [ ] ステージ1/2 の CPU 挙動が変化しないこと

### 11.4 移動AI

- [ ] ALWAYS_BATTLE_LV2 キャラが、勝てる方向と勝てない方向を正しく評価できる
- [ ] 移動シミュレーション時の予測と実戦闘時の判断が一致する（ターンキャッシュの動作確認）

## 12. 将来拡張：ALWAYS_BATTLE_LV3（参考）

Lv2 が安定稼働した後、以下の要素を追加した Lv3 を検討：

- アイテム使用を許可する（Step 2 で実際にアイテムを使う）
- 「勝てる組み合わせ」の探索で自分のアイテム使用を前提に含める
- その他 Lv2 と同じ制約（無効化回避、壁抜け必須、Step 3-b の使い捨て判定）は継承

Lv2 との違い:
- Lv2: 揺さぶり特化（アイテム温存）
- Lv3: 積極的勝利狙い（アイテム使用もいとわない）

## 13. 未解決の論点（実装着手前に確認）

- [ ] ポリシー名 `ALWAYS_BATTLE_LV2` の enum 値 / JSON キー表記の最終確定
  - enum: `ALWAYS_BATTLE_LV2`
  - JSON キー: `always_battle_lv2`（スネークケース）
- [ ] `battle_simulator` 戻り値拡張の実装方針（内部計算からの取り出し方）
- [ ] Step 2 の敵AI反応について、実装前に `cpu_defense_ai.gd` を確認するか、実装後に挙動で判断するか

---

**Last Updated**: 2026-04-12  
**Status**: 設計フェーズ（実装未着手）
