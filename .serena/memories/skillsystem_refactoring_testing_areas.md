# SkillSystem リファクタリング - テスト対象領域

## 変更内容
- initialize_player_buffs(): 固定辞書 → 動的配列
- apply_buff(): match文 → 配列append
- _calculate_buff_total(): 新規ヘルパーメソッド追加
- 全 modify_* メソッド: 直接フィールド参照 → _calculate_buff_total() で計算

## 呼び出し元（影響範囲）

### 1. cpu_ai_handler.gd (203行)
- 関数: calculate_card_cost_for_player()
- 呼び出し: skill_system.modify_card_cost()
- テスト項目: CPU AI がカードコストを正しく計算しているか

### 2. game_flow_manager.gd (250行)
- 関数: roll_dice()
- 呼び出し: skill_system.modify_dice_roll()
- テスト項目: ダイスロール時にボーナスが正しく適用されているか

## テストシナリオ

### シナリオ1: バフなし
- apply_buff() を呼ばない
- modify_card_cost(), modify_dice_roll() が通常値を返す ✅

### シナリオ2: 単一バフ
- apply_buff(0, "card_cost", 10) で配列に追加
- modify_card_cost() が 10 を減算 ✅

### シナリオ3: 複数バフ（同タイプ）
- apply_buff(0, "card_cost", 10)
- apply_buff(0, "card_cost", 5)
- modify_card_cost() が 15 を減算 ✅

### シナリオ4: 異なるタイプのバフ
- apply_buff(0, "card_cost", 10)
- apply_buff(0, "dice", 2)
- modify_card_cost() → 10 減算
- modify_dice_roll() → 2 加算 ✅

### シナリオ5: 持続時間の管理（オプション）
- apply_buff(0, "card_cost", 10, 3) で duration=3 を指定
- end_turn_cleanup() で duration が正しく管理されるか

## 実装前後の動作確認

### modify_card_cost()
Before: `modified_cost -= player_buffs[player_id].card_cost_reduction`
After: `var total_reduction = _calculate_buff_total(player_id, "card_cost"); modified_cost -= int(total_reduction)`

影響: バフなし状態では同じ、バフ複数時に合計値を返すように改善

### modify_dice_roll()
Before: `modified_roll += player_buffs[player_id].dice_bonus`
After: `var dice_bonus = _calculate_buff_total(player_id, "dice"); modified_roll += int(dice_bonus)`

影響: バフなし状態では同じ

### modify_toll()
Before: `modified_toll *= player_buffs[defender_id].toll_multiplier`
After: `var toll_multiplier = _calculate_buff_total(defender_id, "toll"); if toll_multiplier > 0: modified_toll *= (1.0 + toll_multiplier * 0.1)`

影響: 新しい計算ロジックに変更

### modify_draw_count()
Before: `modified_count += player_buffs[player_id].draw_bonus`
After: `var draw_bonus = _calculate_buff_total(player_id, "draw"); modified_count += int(draw_bonus)`

影響: バフなし状態では同じ

### modify_creature_stats()
Before: `modified.damage += player_buffs[player_id].battle_st_bonus; modified.block += player_buffs[player_id].battle_hp_bonus`
After: `var st_bonus = _calculate_buff_total(player_id, "battle_st"); var hp_bonus = _calculate_buff_total(player_id, "battle_hp")`

影響: バフなし状態では同じ

## 注意点
- 呼び出し側のインターフェースは変更なし（メソッド署名維持）
- 現在、バフが apply_buff() で呼ばれていないため、実質上の動作変化なし
- ゲーム開始 → 呪いシステムで実際のバフが追加されるまで、外見上の変化なし
