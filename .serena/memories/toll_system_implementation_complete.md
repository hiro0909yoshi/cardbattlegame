# 通行料システム実装完了（2025/11/23）

## 実装内容

### 1. GameConstants.gd - 通行料係数追加
- `TOLL_ELEMENT_MULTIPLIER`: 要素係数（fire/water/wind/earth=1.0, none=0.8）
- `TOLL_LEVEL_MULTIPLIER`: レベル係数（Lv1-5: 1.0, 1.2, 1.5, 2.0, 2.5）
- `TOLL_MAP_MULTIPLIER`: マップ係数（デフォルト map_1=1.0）
- `floor_toll(amount)`: 10の位で切り捨てユーティリティ関数

### 2. tile_data_manager.gd - 修正・追加
- `calculate_chain_bonus()`: 日本語→英語（"火水風土" → "fire/water/wind/earth"）修正
- `calculate_level_up_cost(tile_index, target_level, map_id)`: 新規追加
  - 通行料計算式を使用した動的計算
  - 連鎖ボーナスは固定値1.5（連鎖2個相当）
  - 10の位で切り捨て

### 3. game_flow_manager.gd - 敵地支払い一本化
- `end_turn()` 内に敵地判定・支払い処理を追加
- 手札調整後、敵地判定前のタイミングで実行
- `check_and_pay_toll_on_enemy_land()`: 新規追加
  - タイル所有者が現在プレイヤーではない場合に支払い実行
  - スタートタイル（無所有）・自領地では支払いなし

### 4. tile_action_processor.gd - パス処理の支払い削除
- `on_action_pass()`: 支払い処理を削除
- コメント追加：「支払いはend_turn()で一本化」

### 5. battle_system.gd - pay_toll_3d()削除
- 関数呼び出し（3箇所）を `emit_signal("invasion_completed", false, ...)` に置き換え
- `pay_toll_3d()` 関数定義を完全削除

## 設計の意図

**統一原則**: プレイヤーが敵地に「留まる」状態 → 通行料支払い義務

**支払いシーン**:
1. パスボタン → on_action_pass() → end_turn() → check_and_pay_toll_on_enemy_land()
2. 戦闘敗北（DEFENDER_WIN） → _on_battle_completed() → end_turn() → check_and_pay_toll_on_enemy_land()
3. 敵地に生き残り（ATTACKER_SURVIVED） → end_turn() → check_and_pay_toll_on_enemy_land()

**支払いが発生しないシーン**:
- 戦闘勝利時（土地を奪取 → 自領地に変更）
- 相打ち（土地が無所有に）

## 確認・チェック

- [ ] GameConstants の TOLL_* が他の処理で使用されているか確認
- [ ] land_command_ui.gd でレベルアップコスト計算をGETするか確認（現在はハードコード）
- [ ] マップ係数（TOLL_MAP_MULTIPLIER）の値を確認（現在は map_1=1.0 のみ）
- [ ] board_system_3d.calculate_toll() が使用されているか確認（board_system_3d.gd L283）

## 次のステップ

1. land_command_ui.gd でレベルアップコスト計算を動的に変更
2. マップごとの係数を設定
3. テスト実行
