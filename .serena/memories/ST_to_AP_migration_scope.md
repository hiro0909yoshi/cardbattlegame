# ST → AP 移行影響範囲

## 完了した箇所
- ✅ item.json: stat_bonus の "st" → "ap"
- ✅ battle_item_applier.gd: stat_bonus.get("st", 0) → stat_bonus.get("ap", 0)
- ✅ condition_checker.gd: ST参照をAP参照に変更
- ✅ battle_item_applier.gd: _apply_random_stat_bonus() の st_range → ap_range
- ✅ battle_item_applier.gd: _apply_fixed_stat() の stat == "st" → stat == "ap"
- ✅ data/item.json: st_range → ap_range
- ✅ data/item.json: scroll_type: "fixed_st" → "fixed_ap"
- ✅ scripts/battle/skills/skill_scroll_attack.gd: "fixed_st" → "fixed_ap"

## 次回作業：アイテム巻物の実装

### 作業内容

**Phase 1: `_apply_scroll_attack()` の機能拡張**
- 現在：単に`scroll_config`を設定保存しているだけ
- 修正：実際にAPを動的に計算して`current_ap`に適用

**具体的な修正箇所：**

1. **`_apply_scroll_attack()` 内の処理追加**
   - `scroll_type` に応じて、実際のAPを計算
   - `participant.current_ap` に直接設定（キーワード条件に加えて）
   
   ```gdscript
   match scroll_type:
       "fixed_ap":
           var value = effect.get("value", 0)
           participant.current_ap = value  # ← 追加
       "base_ap":
           var base_ap = participant.creature_data.get("ap", 0)
           participant.current_ap = base_ap  # ← 追加
       "land_count":
           # 土地数を計算してAPを設定  # ← 追加
   ```

2. **`is_using_scroll` フラグの設定**
   - `_apply_scroll_attack()` 内で `participant.is_using_scroll = true` を設定
   - （バフ検知なし）

3. **JSONの表記修正**
   - 巻物アイテムの `effect` フィールド内の "ST" → "AP" 表記修正
   - JSON内の説明文修正

4. **表記統一**
   - `_apply_scroll_attack()` 内のコメントで "固定ST" → "固定AP"

### Phase 2: battle_skill_processor での呼び出し確認
- アイテム巻物が呼ばれた場合、他のスキル（感応等）をスキップする必要があるか確認
- 現在の仕様：アイテムフェーズで既に`is_using_scroll = true`なので、battle_skill_processorで自動的にスキップされるはず

### 作業量
- 中程度（1時間未満）
- メイン：`_apply_scroll_attack()`の拡張（20行程度）
- サブ：JSONの表記修正、コメント修正

