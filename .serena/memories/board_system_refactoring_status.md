# BoardSystem3D リファクタリング現況（2026-02-12 更新）

## 完了済みタスク

### タスク3: board_system_3d 委譲メソッド実装
- ステップ1: get_player_tile委譲（15箇所）
- ステップ2: camera_controller系委譲（18箇所）
- ステップ2b: movement_controller系委譲（24箇所）
→ 全サブシステムへの外部直接参照ゼロ達成

### サブシステム直接参照解消（タスクA〜E）
- A: tile_info_display直接参照 → 委譲メソッド経由に（5箇所、4ファイル）
  - get_tile_label() 新規追加
- B: special_tile_system直接参照 → 委譲メソッド経由に（2箇所）
  - get_warp_pairs(), get_warp_pair() 新規追加
- C: battle_system 3段チェーン → 委譲メソッド経由に（1箇所）
  - get_battle_screen_manager() 新規追加
- D: player_tiles外部参照 → get_player_tile()使用に（2箇所）
- E: tile_data_manager直接参照 → 委譲メソッド経由に（2箇所）
  - calculate_toll_with_curse() 新規追加

### 追加変更（Haiku実施）
- game_system_manager.gd: class_name型注釈→preload定数化（循環参照対策）
- game_flow_manager.gd: 同上 + _update_camera_mode重複削除
- quest_game.gd: preload化 + initialize_all await追加

## 残存する許容済みパターン
- tile_nodes: 200箇所以上。公開プロパティとして維持（委譲メソッド化は非現実的）
- board_system.camera: 10箇所程度。直接参照が多いが実害低
- battle_system初期化キャッシュ: dominio_command_handler, cpu_turn_processorの2箇所
- MC内部ヘルパー（warp_handler, special_handler等）からのcontroller.*参照: 内部分割のため許容

## 今後の残タスク（優先度低）
- UI座標ハードコード（規約6, ~20箇所）— 大工事、後回し
- debug_manual_control_all集約（規約10残り）— 影響範囲大
- signal_flow_mapスキル作成 — 未着手