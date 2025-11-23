# 通行料呪い実装進捗（2025/11/23）

## 実装完了

### 1. spell_curse_toll.gd 作成 ✅
- SpellCurseToll クラス新規作成
- セプター呪い付与: apply_toll_share, apply_toll_disable, apply_toll_fixed
- 領地呪い付与: apply_toll_multiplier, apply_peace
- セプター呪い判定: get_payer_toll, get_receiver_toll
- 領地呪い判定: get_land_toll_modifier, has_peace_curse, is_invasion_disabled

### 2. game_flow_manager.gd 統合 ✅
- spell_curse_toll 参照追加
- SpellCurseToll 初期化（_setup_spell_systems内）
- check_and_pay_toll_on_enemy_land() にセプター呪い判定追加
  - toll_disable → 支払い=0G
  - toll_fixed → 固定値に変更
  - TODO: toll_share の複数プレイヤー競合時の処理

### 3. tile_data_manager.gd 統合 ✅
- calculate_toll() の末尾に領地呪い判定追加
- spell_curse_toll.get_land_toll_modifier() で処理
- toll_multiplier → 倍率適用
- peace → 支払い=0G

### 4. spell_phase_handler.gd 統合 ✅
- _apply_single_effect() に5つの呪い処理追加
- toll_share, toll_disable, toll_fixed（セプター呪い）
- toll_multiplier, peace（領地呪い）
- target_type/target_filter により自動的にターゲット判定

## 未実装（後で対応）

### 1. peace呪い - 移動候補除外 ⏸️
- movement_controller または board_system_3d の移動候補制御関数に peace判定追加
- spell_curse_toll.has_peace_curse() で確認
- 移動候補から除外（表示しない）

### 2. peace呪い - 戦闘UI制御 ⏸️
- board_system_3d の _try_invade() に peace判定追加
- spell_curse_toll.is_invasion_disabled() で確認
- 戦闘UI表示をブロック

### 3. toll_share の複数競合処理 ⏸️
- check_and_pay_toll_on_enemy_land() で複数プレイヤー該当時の処理
- 現在は TODO コメント状態

## テスト項目

- [ ] ドリームトレイン (toll_share) - スペル使用 → プレイヤー呪い付与
- [ ] ブラックアウト (toll_disable) - スペル使用 → 通行料0確認
- [ ] ユニフォーミティ (toll_fixed) - スペル使用 → 固定値確認
- [ ] グリード (toll_multiplier) - スペル使用 → 通行料1.5倍確認
- [ ] ピース (peace) - スペル使用 → 敵移動除外・戦闘UI非表示・通行料0確認

## 次のステップ

1. JSON データファイルにスペル追加
2. peace呪い - 移動候補制御の実装
3. peace呪い - 戦闘UI制御の実装
4. テスト実行
