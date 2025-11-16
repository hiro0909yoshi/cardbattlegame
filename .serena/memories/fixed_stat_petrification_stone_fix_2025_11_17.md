# 1059（ペトリフストーン）base_up_hp 復元修正 完了 (2025-11-17)

## 修正内容
**ファイル**: scripts/battle/battle_item_applier.gd
**関数**: _apply_fixed_stat (355～372行目)

### 問題
- HP固定値設定アイテム（1059）が適用される際、base_up_hpが0にリセットされたまま復元されない
- HP = 50に固定された場合、元の base_up_hp = 20 が失われていた

### 修正方法（保存・変更・復元の3ステップ）
```gdscript
elif stat == "hp":
    # 保存：元のbase_up_hpを保存
    var saved_base_up_hp = participant.base_up_hp
    
    # 変更：base_up_hpを一時的に0に設定
    participant.base_up_hp = 0
    
    # HP固定値を適用
    participant.creature_data["mhp"] = fixed_value
    participant.creature_data["hp"] = fixed_value
    participant.base_hp = fixed_value
    participant.update_current_hp()
    
    # 復元：元のbase_up_hpを戻す
    participant.base_up_hp = saved_base_up_hp
    participant.update_current_hp()
    
    print("  [固定値] HP=", fixed_value, " (base_up_hp復元: +", saved_base_up_hp, ")")
```

## テスト状況
✅ 修正完了・テスト実施（ユーザー確認済み）

## 注記
- このアイテムID 1059のみが fixed_stat を使用しているため、この処理は1059固有の対応

## バイロマンサー（ID: 34）について
- 敵攻撃受け後に AP=20（上書き）、MHP-30（base_up_hp -= 30）
- 仕様: base_hpを固定値にするより、base_up_hpを-30する現在の方が適切
- 理由: base_hpを固定値にするとbase_up_hpが生きたままになり、結果的に同じだが、current_hpのヘル処理の可能性があるため、現状維持
