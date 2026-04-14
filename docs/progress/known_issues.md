# 未解決・要観察リスト

既知の不具合や暫定対策を記録し、再発時の調査を効率化する。

## ステータス定義
- **未解決**: 原因不明または対策未実施
- **要観察**: 対策済みだが再発の可能性あり
- **解決済み**: 対策が確認され再発なし（一定期間後に削除可）

---

## チェックポイントタイル黒表示（2026-04-14）

- **症状**: 5回に1回程度、チェックポイントタイルが全面黒になる（金色模様が消失）
- **原因推定**: GLBモデルの `instantiate()` 直後に `surface_get_arrays()` を呼ぶと空配列が返り、空の `ArrayMesh` に置換されて黒くなる
- **対策**: `checkpoint_tile.gd` の `_load_sp_tile_model()` で `add_child` 後に `await get_tree().process_frame` を追加し、メッシュデータ準備を待ってから着色
- **関連ファイル**: `scripts/tiles/checkpoint_tile.gd`, `scripts/utils/tile_mesh_colorizer.gd`
- **状態**: 要観察

---

## 移動先マーカー非表示・カード使用可否表示の不具合（2026-04-14）

- **症状**: モバイル環境でのみ発生。方向選択時に着地先を示す黄色い点滅マーカーが表示されないことがある。また、マーカー表示時にそのタイルで手札のカードが使用可能かどうかの視覚フィードバックが機能しない場合がある
- **再現条件**: 不安定（できる時とできない時がある）。PC環境では未確認
- **原因特定（一部）**: シンプル方向選択（前進/後退）の `_update_ui()` にマーカー表示の呼び出しがなかった。分岐選択では実装済み
- **対策**:
  - `movement_direction_selector.gd` の `_update_ui()` にマーカー表示（`highlight_destinations`）を追加
  - `movement_destination_predictor.gd` に公開メソッド `highlight_destinations()` を追加
  - 方向選択終了時のマーカークリア（`clear_destination_highlight`）を追加
- **残存リスク・次回調査方針**:
  1. **`card_selection_ui` 参照が null**: `game_flow_manager.gd:153` で初期化時に `ui_manager.card_selection_ui` が未生成だとセットされない。→ `set_card_selection_ui` 呼び出しを遅延実行にする、または `null` 時のフォールバック追加
  2. **フレームスキップによる描画遅延**: `base_tiles.gd:341` で 3フレームに1回の更新。短時間の方向選択で初期フレームがスキップされる可能性。→ `_blink_frame_counter` を `start_destination_highlight()` でリセット
  3. **`frame_mesh_instance` 未初期化**: `start_destination_highlight()` で `frame_mesh_instance` が見つからないとマーカーが出ない（ログ出力あり）。→ 再現時にログ確認
  4. **`DebugSettings.disable_all_process`**: モバイル負荷軽減フラグが立っていると `_process` がスキップされ点滅しない。→ モバイルで当該フラグの状態確認
  5. **`predicted_destination_tiles` の残留**: 前回の方向選択のタイル情報が残っているとカード制限が正しく更新されない。→ セレクタ開始時にクリア
- **関連ファイル**: `scripts/movement_direction_selector.gd`, `scripts/movement_destination_predictor.gd`, `scripts/movement_branch_selector.gd`, `scripts/tiles/base_tiles.gd`, `scripts/ui_components/card_selection_ui.gd`, `scripts/autoload/debug_settings.gd`
- **状態**: 要観察
