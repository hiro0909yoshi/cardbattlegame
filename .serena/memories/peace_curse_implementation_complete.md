# peace呪い（ID 2072）実装完了

## 実装状況

✅ **通行料0計算** - 実装済み
- SpellCurseToll.calculate_final_toll() で実装

✅ **敵移動除外** - 実装完了
- ファイル: `scripts/game_flow/movement_helper.gd`
- メソッド: `_filter_invalid_destinations()`
- 実装内容:
  - SpellCurseToll参照を board_system.get_meta("spell_curse_toll") から取得
  - 敵領地への移動時に has_peace_curse() でチェック
  - peace呪いがあれば該当タイルを移動候補から除外

✅ **戦闘不可** - 実装完了
- ファイル: `scripts/game_flow/land_action_helper.gd`
- メソッド: `confirm_move()`
- 実装内容:
  - 敵地への移動確定時に peace呪いをチェック
  - peace呪いがあれば:
    - UI に「peace呪い: このタイルへは侵略できません」を表示
    - クリーチャーを移動元に戻す
    - 移動・戦闘を中止

## 実装の流れ

### 移動時の処理
1. 領地コマンドで移動を選択
2. `MovementHelper.get_move_destinations()` で移動先を取得
3. `_filter_invalid_destinations()` で無効な移動先をフィルタリング
   - **peace呪いチェック**: 敵領地に peace呪いがあれば除外
4. UI に移動可能なタイルのみ表示

### 敵地侵略時の処理
1. `LandActionHelper.confirm_move()` で移動先を確定
2. 敵地の場合、peace呪いをチェック
   - **peace呪いがある場合**:
     - エラーメッセージ表示
     - クリーチャーを移動元に戻す
     - 領地コマンド閉じる
   - **peace呪いがない場合**:
     - 通常通りバトル発生

## 重要な参照方法

SpellCurseToll への参照:
```gdscript
var spell_curse_toll = null
if board_system.has_meta("spell_curse_toll"):
    spell_curse_toll = board_system.get_meta("spell_curse_toll")
```

メソッド:
- `has_peace_curse(tile_index)` - タイルに peace呪いがあるかチェック

## 実装完了日
2025/11/24

## テスト予定
- [ ] peace呪いが付与された敵領地への移動を試みる
- [ ] 移動候補から除外されているか確認
- [ ] 敵領地侵略でエラーメッセージが表示されるか確認
- [ ] 通行料0が計算されるか確認
