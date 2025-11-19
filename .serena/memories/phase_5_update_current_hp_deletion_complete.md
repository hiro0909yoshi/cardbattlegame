# Phase 5完了：update_current_hp() 呼び出し削除（2025-11-20）

## 実装状況

✅ **全39箇所の修正完了**

### 修正ファイル一覧

| ファイル | 箇所数 | ステータス |
|---------|--------|-----------|
| battle_skill_processor.gd | 16 | ✅ 完了 |
| battle_item_applier.gd | 12 | ✅ 完了 |
| battle_special_effects.gd | 3 | ✅ 完了 |
| battle_curse_applier.gd | 1 | ✅ 完了 |
| skill_resonance.gd | 1 | ✅ 完了 |
| skill_special_creature.gd | 2 | ✅ 完了 |
| skill_transform.gd | 2 | ✅ 完了 |
| skill_assist.gd | 1 | ✅ 完了 |
| skill_item_manipulation.gd | 2 | ✅ 完了 |
| skill_penetration.gd | 1 | ✅ 完了 |
| skill_support.gd | 1 | ✅ 完了 |
| **合計** | **39** | **✅ 完了** |

## 修正内容

### 修正戦略
すべての `update_current_hp()` 呼び出しを以下のコメントに置き換え：
```gdscript
# update_current_hp() は呼ばない（current_hp が状態値になったため）
```

### 削除対象の呼び出しパターン

1. **ボーナスHP変更後**: 
   - `temporary_bonus_hp`, `item_bonus_hp`, `land_bonus_hp` など変更後
   - 新方式では `current_hp` は状態値なので、フィールド変更は無関係

2. **スキル適用後**:
   - ダメージ軽減、無効化スキル等で各種ボーナスを変更後
   - `current_hp` の再計算が不要

3. **条件判定後**:
   - HPに関する条件判定後の HP 再計算
   - 新方式では必要なし

## 次ステップ

### 残りの作業
1. ✅ Phase 1-5: バトル側修正完了
2. ⬜ **update_current_hp() 関数定義の削除**
   - 場所: battle_participant.gd （89-91行目）
   - 呼び出し完全削除後に削除予定

3. ⬜ **Phase 4: place_creature() に current_hp 初期化追加**（未実施）

4. ⬜ **マップ側修正** (separate):
   - base_up_hp 変更時の current_hp 同期
   - 4ファイル、複数箇所

## テスト実施予定

以下の項目でテストを実施予定：
- [ ] バトル開始時のHP初期化が正しいか
- [ ] ボーナスHP変更が current_hp に影響しないか（正常）
- [ ] ダメージがcurrent_hpから直接削られるか
- [ ] スキル効果（無効化、軽減）が正しく機能するか
- [ ] バトル終了時のHP保存が正しいか

## 設計の確認

### current_hp の動作
- **修正前**: 計算値（毎回 update_current_hp() で再計算）
- **修正後**: 状態値（ダメージで直接削られ、スキル等でボーナス変更時は影響なし）

### ボーナスHP フィールドの役割
- これらは表示・計算用の参照値
- `current_hp` には影響しない
- ボーナス合計は表示時に個別に参照
