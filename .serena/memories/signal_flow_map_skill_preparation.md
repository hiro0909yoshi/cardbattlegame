# signal_flow_map スキル作成準備

## 目的
シグナル接続の流れを可視化・管理するツール/ドキュメント作成

## 現在の状況
- コーディング規約確認完了
- 整理中...

## 主要なシグナルフロー（from signal_cleanup_work.md）

### トップレベル相互参照（2件）
1. **game_flow_manager ↔ board_system**（双方向、深刻度⚠️ 中）
   - gfm→bs: 移動/タイル操作
   - bs→gfm: ターン制御
   
2. **game_flow_manager ↔ ui_manager**（双方向、深刻度⚠️ 中）
   - gfm→ui: 表示更新
   - ui→gfm: 入力伝達

### 親→子→親の逆参照（5件）
1. board_system.tile_action_processor → game_flow_manager
2. board_system.tile_data_manager → game_flow_manager
3. board_system.movement_controller → game_flow_manager
4. board_system.special_tile_system → game_flow_manager
5. board_system.battle_system → game_flow_manager

### UI シグナル接続（306接続、違反0件）
- 全シグナル接続が規約に準拠
- 親→子の逆参照なし

## 今後の作業
1. シグナルフロー図化（TextorMermaid形式）
2. 各コンポーネントの接続点ドキュメント化
3. 密結合パターンの可視化
