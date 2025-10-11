# 🐛 カルドセプト風カードバトルゲーム - 課題管理

## 目次
1. [解決済みの課題](#解決済みの課題)
2. [既知のバグ](#既知のバグ)
3. [バランス調整項目](#バランス調整項目)
4. [パフォーマンス問題](#パフォーマンス問題)
5. [UI/UX改善](#uiux改善)
6. [技術的負債](#技術的負債)
7. [要望・提案](#要望提案)

---

## 解決済みの課題

### ✅ 解決済み（2025/01/12）

#### ~~BUG-008: デバッグモード時のCPU手動操作不可~~
**解決日**: 2025/01/12  
**解決方法**: システム初期化順序の修正 + 参照設定の追加

**元の問題**: 
- `debug_manual_control_all = true`でもCPUターンが自動処理されていた
- CPUプレイヤーの手札が選択できない
- カード選択UIが表示されない

**根本原因**:
1. **初期化順序の問題**: `ui_manager.create_ui()`が`game_flow_manager.setup_systems()`より先に実行
2. **参照の未設定**: CardSelectionUIに`game_flow_manager_ref`が設定されていなかった
3. **プレイヤーID固定**: CardSelectionUIが常にplayer 0の手札ノードを参照

**影響範囲**: 
- game_3d.gd（初期化順序）
- BoardSystem3D（フラグ転送）
- TileActionProcessor（CPU判定）
- UIManager（手札表示）
- CardSelectionUI（カード選択）

**修正内容**:
```gdscript
// game_3d.gd - 初期化順序を修正
game_flow_manager.debug_manual_control_all = debug_manual_control_all  // 先に設定
game_flow_manager.setup_systems(...)
game_flow_manager.setup_3d_mode(...)

// setup_systems後に参照を再設定
if ui_manager.card_selection_ui:
	ui_manager.card_selection_ui.game_flow_manager_ref = game_flow_manager

// card_selection_ui.gd - player_idパラメータを追加
func enable_card_selection(hand_data: Array, available_magic: int, player_id: int = 0):
	var hand_nodes = ui_manager_ref.player_card_nodes.get(player_id, [])
```

#### ~~BUG-009: 手札表示がプレイヤー1固定~~
**解決日**: 2025/01/12  
**解決方法**: 現在のターンプレイヤーIDで手札を更新

**元の問題**: 
- CPUターンでもプレイヤー1の手札しか表示されない
- ターン切り替え時に手札が切り替わらない

**原因**:
- `_on_hand_updated()`が`update_hand_display(0)`固定で呼んでいた
- `rearrange_hand()`に`player_id != 0`チェックがあり、CPUの手札が配置されなかった

**修正内容**:
```gdscript
// ui_manager.gd
func _on_hand_updated():
	if player_system_ref:
		var current_player = player_system_ref.get_current_player()
		if current_player:
			update_hand_display(current_player.id)  // 現在プレイヤーのIDで更新

func rearrange_hand(player_id: int):
	// player_id != 0 チェックを削除
	var card_nodes = player_card_nodes[player_id]
	// ...
```

#### ~~BUG-010: 手札が切り替わらず重なる~~
**解決日**: 2025/01/12  
**解決方法**: ターン切り替え時に全プレイヤーの手札を削除

**元の問題**: 
- ターン切り替え時に前のプレイヤーの手札が残り、新しい手札と重なって表示される

**原因**:
- `update_hand_display()`で現在プレイヤーの手札のみ削除していた
- 他のプレイヤーの手札ノードが残っていた

**修正内容**:
```gdscript
// ui_manager.gd update_hand_display()
// 全プレイヤーの既存カードノードを削除
for pid in player_card_nodes.keys():
	for card_node in player_card_nodes[pid]:
		if is_instance_valid(card_node):
			card_node.queue_free()
	player_card_nodes[pid].clear()
```

#### ~~BUG-011: カードのドラッグ&ドロップが有効~~
**解決日**: 2025/01/12  
**解決方法**: ドラッグ処理をコメントアウト

**元の問題**: 
- 手札表示用のカードがドラッグできてしまう
- 意図しない操作が可能

**原因**:
- `card.gd`のドラッグ処理が有効だった
- `is_selectable = false`の時もドラッグが動作

**修正内容**:
```gdscript
// card.gd - ドラッグ機能を無効化
// ドラッグ機能は無効化（将来的に必要なら再実装）
// if not is_selectable and mouse_over and event is InputEventMouseButton:
//     if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
//         is_dragging = true
```

#### ~~FEAT-003: 先制スキルの動作確認~~
**解決日**: 2025/01/12  
**確認内容**: デバッグモードで先制スキルの動作を検証

**確認結果**: 
- 先制スキル持ちクリーチャーが正しく先攻を取ることを確認
- バトルシステムでの先制判定が正常に動作
- カードUI上での先制アイコン表示も正常

**テスト方法**:
- デバッグモード（`debug_manual_control_all = true`）を有効化
- 両プレイヤーを手動操作し、先制スキル持ちカードでバトル
- 先攻順序と戦闘結果を確認

**動作確認済みスキル**:
- "first_strike"（先制攻撃）
- 両者が先制を持つ場合の攻撃力判定

### ✅ 解決済み（2025/01/11）

#### ~~BUG-000: ターン終了処理の重複実行~~
**解決日**: 2025/01/11  
**解決方法**: シグナル経路の完全一本化 + 2D版コード削除

**元の問題**: ターンが飛ばされる、`end_turn()`の重複実行  
**影響範囲**: GameFlowManager, BoardSystem3D

#### ~~ISSUE-001: 手札調整システムの未実装~~
**解決日**: 2025/01/11  
**実装内容**: 
- `discard_card()` 統一関数の実装
- ターン終了時の手札調整処理（人間: 手動選択、CPU: 自動）
- 捨て札理由の分類（use/discard/forced/destroy）
- 手札表示の動的スケール（画面80%対応）

#### ~~TECH-001: 古い2Dコードの削除~~
**解決日**: 2025/01/11  
**削除内容**:
- game.tscn（2D版シーン）
- board_system.gd（2D版ボードシステム）
- 2D関連の分岐コード

#### ~~WARN-001～005: Godot警告の整理~~
**解決日**: 2025/01/11  
**対応内容**:
- **シャドウイング**: `is_processing`、`element`、`conditions`変数名を変更
- **未使用のシグナル**: `player_system.gd`から削除
- **未使用のパラメータ**: `_`プレフィックスを追加
- **未使用のローカル変数**: `player_node`を削除
- **型の問題**: Enum型への明示的キャスト追加
- **Integer division**: float除算 + int()キャストに修正

#### ~~FEAT-001: 隣接土地判定システムの実装~~
**解決日**: 2025/01/11  
**実装内容**:
- **TileNeighborSystem**クラスの作成（`scripts/tile_neighbor_system.gd`）
  - 座標ベースで物理的に隣接するタイルを判定（XZ平面距離4.5以内）
  - 初回起動時に隣接関係をキャッシュ（パフォーマンス最適化）
  - `get_spatial_neighbors(tile_index)` - 隣接タイルリストを取得
  - `has_adjacent_ally_land(tile_index, player_id)` - 隣接自領地判定
- **BoardSystem3Dへの統合**
  - `tile_neighbor_system`インスタンスの作成と初期化
  - タイル配置後に自動でキャッシュ構築
- **ConditionCheckerの拡張**
  - `"adjacent_ally_land"`条件の動的判定を実装
  - TileNeighborSystemを使用した実時間判定
  - フォールバック機構（従来の静的値にも対応）
- **BattleSystemのコンテキスト拡張**
  - `battle_tile_index`、`player_id`、`board_system`をコンテキストに追加
  - スキル条件評価時に必要な情報を提供

**動作確認**:
- ローンビースト（ID:49）の「隣接自領地なら強打」が正常動作
- タイル6で攻撃時、隣接タイル5が自領地の場合にAP20→30に上昇

**技術詳細**:
```gdscript
# 隣接判定の仕組み
const TILE_SIZE = 4.0
const NEIGHBOR_THRESHOLD = 4.5

# XZ平面での距離計算
var distance_xz = sqrt(dx * dx + dz * dz)
if distance_xz < NEIGHBOR_THRESHOLD:
	neighbors.append(other_index)
```

#### ~~FEAT-002: 土地ボーナスシステムの実装~~
**解決日**: 2025/01/11  
**実装内容**:
- **召喚時の土地ボーナス適用**（`BaseTile._apply_land_bonus()`）
  - クリーチャー属性と土地属性が一致 → HP + (レベル × 10)
  - `land_bonus_hp`フィールドに格納（基本HPとは別管理）
- **バトル時の土地ボーナス適用**（`BattleSystem._apply_attacker_land_bonus()`）
  - 攻撃側カードにも土地ボーナスを適用
  - 防御側は配置済みクリーチャーの`land_bonus_hp`を使用
- **BoardSystem3Dへの統合**
  - `get_player_lands_by_element(player_id)` メソッド追加
  - プレイヤーの属性別土地数を取得可能に

**動作確認**:
- レベル3の火土地 + 火クリーチャー → +30HP
- バトル時の攻撃側・防御側両方で土地ボーナスが正しく計算される

#### ~~BUG-007: 属性名の英語/日本語混在~~
**解決日**: 2025/01/11  
**解決方法**: すべて英語に統一

**元の問題**: 
- タイル定義: `tile_type = "fire"` (英語)
- チェック処理: `in ["火", "水", "風", "地"]` (日本語)
- 結果: すべての土地が「その他」に分類され、連鎖計算が機能しない

**影響範囲**:
- `tile_data_manager.gd`: `get_owner_element_counts()`
- `battle_system.gd`: プレイヤー土地情報取得
- `base_tiles.gd`: 召喚時の土地ボーナス判定
- `battle_system.gd`: バトル時の土地ボーナス判定

**修正内容**:
```gdscript
# 修正前
if tile.tile_type in ["火", "水", "風", "地"]:

# 修正後
if tile.tile_type in ["fire", "water", "wind", "earth"]:
```

**教訓**: 
- 属性名は英語で統一（"fire", "water", "wind", "earth", "neutral"）
- 今後新しい属性チェックを追加する際は英語を使用すること

**対応内容**:
- **ownerシャドウイング**: `owner` → `tile_owner`に変更（2箇所）
- **未使用シグナル**: 13個のシグナルをコメントアウト + TODOコメント追加
- **未使用パラメータ**: アンダースコア接頭辞を追加（主要3箇所）
- **未使用ローカル変数**: 3個の変数を削除（condition_checker, likely_winner, is_processing）

---

## 既知のバグ

### 🔴 Critical（ゲーム進行に影響）

#### BUG-001: カードドロー時の表示ズレ
**報告日**: 2025/01/09  
**優先度**: 高  
**影響範囲**: CardSystem, UI

**症状**:
- カードを使用後、手札の再配置が正しく行われないことがある
- 特に6枚目のカード使用後に発生しやすい

**再現手順**:
1. 手札が6枚の状態にする
2. 右端のカードを使用
3. 新しくドローしたカードが正しい位置に表示されない

**原因**:
```gdscript
# card_system.gd _rearrange_player_hand()
# hand_size計算時にノード削除が反映されていない可能性
```

**修正案**:
- `_rearrange_player_hand()`内でノード有効性チェック強化
- カード使用後に明示的な`await get_tree().process_frame`追加

**ステータス**: 🚧 調査中

---

#### BUG-002: CPU AIの無限ループ
**報告日**: 2025/01/08  
**優先度**: 高  
**影響範囲**: CPUAIHandler

**症状**:
- 特定条件下でCPUのターンが終わらない
- 魔力が足りないのにカード使用を試み続ける

**再現手順**:
1. CPUの魔力を100G以下にする
2. 手札に高コストカードのみがある状態
3. CPUのターンで停止

**原因**:
```gdscript
# cpu_ai_handler.gd
# カード使用可能判定で無限ループ
while affordable_cards.is_empty():
	# ループ脱出条件がない
```

**修正案**:
- 最大試行回数を設定（例: 10回）
- affordable_cards が空の場合は即座にスキップ

**ステータス**: ⚠️ 要対応

---

### 🟡 Major（機能に影響）

#### BUG-003: 属性連鎖の誤判定
**報告日**: 2025/01/10  
**優先度**: 中  
**影響範囲**: BoardSystem

**症状**:
- 隣接していない土地が連鎖としてカウントされる
- 特に菱形マップの角で発生

**再現手順**:
1. マップの0番（スタート）と5番（チェックポイント）を同属性で取得
2. 連鎖数が2とカウントされる（実際は隣接していない）

**原因**:
```gdscript
# board_system.gd get_adjacent_tiles()
# 菱形配置での隣接判定ロジックが不完全
```

**修正案**:
- 隣接テーブルの見直し
- 菱形配置専用の隣接判定関数作成

**ステータス**: 📋 計画中

---

#### BUG-004: スキル効果の重複適用
**報告日**: 2025/01/10  
**優先度**: 中  
**影響範囲**: SkillSystem, BattleSystem

**症状**:
- 強打スキルが複数回適用される
- バトル結果が正しく計算されない

**再現手順**:
1. 強打持ちクリーチャーで攻撃
2. 条件を満たす
3. APが想定の2倍になる

**原因**:
```gdscript
# effect_combat.gd apply_power_strike()
# 既に修正済みのAPに対して再度倍率適用
```

**修正案**:
- `power_strike_applied`フラグの確認を追加
- 元のAP値を保持して計算

**ステータス**: 🚧 調査中

---

### 🟢 Minor（表示・軽微）

#### BUG-005: デバッグパネルの文字が小さい
**報告日**: 2025/01/09  
**優先度**: 低  
**影響範囲**: DebugPanel UI

**症状**:
- 高解像度ディスプレイでデバッグテキストが読みづらい
- フォントサイズ12pxが小さい

**修正案**:
- フォントサイズを16pxに変更
- または解像度に応じた動的調整

**ステータス**: 📋 計画中

---

#### BUG-006: カードコストの表示が辞書形式
**報告日**: 2025/01/10  
**優先度**: 低  
**影響範囲**: Card UI

**症状**:
- カードコストが`{"mp": 50}`と表示される
- 数値のみ表示すべき

**修正案**:
```gdscript
# card.gd load_card_data()
if typeof(card_data.cost) == TYPE_DICTIONARY:
	cost_label.text = str(card_data.cost.mp)
else:
	cost_label.text = str(card_data.cost)
```

**ステータス**: 📋 計画中

---

## バランス調整項目

### ゲームバランス

#### BALANCE-001: 初期魔力が低すぎる
**報告日**: 2025/01/09  
**優先度**: 中

**現状**:
- 初期魔力: 3000G
- 平均カードコスト: 500-1000G
- 最初の数ターンでカードが使えない

**提案**:
- 初期魔力を4000Gに増加
- または初期手札のコストを下げる

**検証方法**:
- プレイテスト10回実施
- 3ターン目までのカード使用率を測定

---

#### BALANCE-002: 属性連鎖が強すぎる
**報告日**: 2025/01/10  
**優先度**: 中

**現状**:
- 4個連鎖: 通行料4.0倍、HP+40
- 一度連鎖が完成すると逆転困難

**提案**:
- 4個連鎖の倍率を3.5倍に減少
- または連鎖維持にコスト追加

**検証方法**:
- CPU対戦100回実施
- 連鎖達成プレイヤーの勝率測定

---

#### BALANCE-003: 属性相性ボーナスが低い
**報告日**: 2025/01/10  
**優先度**: 低

**現状**:
- 属性相性: ST+20
- 地形ボーナス: HP+40（最大）
- 相性を無視して地形重視の戦略が優勢

**提案**:
- 属性相性を+30に増加
- または地形ボーナスを+30（最大）に減少

---

#### BALANCE-004: レベルアップコストが高い
**報告日**: 2025/01/09  
**優先度**: 低

**現状**:
```gdscript
const LEVEL_VALUES = {
	2: 80,
	3: 340,   # 80 + 260
	4: 960,   # 340 + 620
	5: 2160   # 960 + 1200
}
```

**提案**:
- レベル3以降のコストを30%減少
- または通行料収入を増加

---

### カードバランス

#### BALANCE-005: 一部カードの性能差が大きい
**報告日**: 2025/01/10  
**優先度**: 中

**問題カード**:
- アームドパラディン（ID:1）
  - AP=0, HP=50, コスト200G
  - ST変動スキルで実質AP=50以上
  - コストパフォーマンスが高すぎる

**提案**:
- コストを300Gに増加
- または基礎HPを40に減少

---

## パフォーマンス問題

### PERF-001: ゲーム開始時の読み込み遅延
**報告日**: 2025/01/09  
**優先度**: 中  
**影響**: 初回起動時に3-5秒かかる

**原因**:
- 全カードデータを一度にロード
- JSON解析がメインスレッドで実行

**改善案**:
```gdscript
# card_loader.gd
# 非同期ロードに変更
func load_cards_async():
	for file in card_files:
		await load_json_async(file)
```

**期待効果**: 起動時間を1秒以下に短縮

---

### PERF-002: 手札表示時のフレームドロップ
**報告日**: 2025/01/10  
**優先度**: 低  
**影響**: カード6枚表示時にFPS低下（60→45）

**原因**:
- 毎フレームCardノードの再配置計算
- 不要なテクスチャ再読み込み

**改善案**:
- カード位置をキャッシュ
- 変更時のみ再計算

---

## UI/UX改善

### UI-001: カード選択時のフィードバック不足
**優先度**: 中

**現状**:
- カードをホバーしても視覚的変化なし
- 選択可能なカードが不明瞭

**提案**:
- ホバー時に拡大（scale: 1.1）
- 選択可能カードに光るエフェクト
- 選択不可カードをグレーアウト

**実装例**:
```gdscript
func _on_mouse_entered():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
```

---

### UI-002: バトル結果が分かりにくい
**優先度**: 中

**現状**:
- バトル結果がコンソールのみ
- プレイヤーが結果を把握できない

**提案**:
- バトル結果ポップアップ追加
- 勝敗アニメーション
- ダメージ数値表示

---

### UI-003: 土地情報の表示不足
**優先度**: 中

**現状**:
- タイルをクリックしても詳細が見れない
- 所有者、レベル、クリーチャー情報が不明

**提案**:
- タイル詳細パネル追加
- 右クリックでポップアップ表示

---

### UI-004: ターン終了ボタンがない
**優先度**: 高

**現状**:
- プレイヤーのターンを任意に終了できない
- 全アクション強制実行

**提案**:
- 「ターン終了」ボタン追加
- Escキーでも終了可能

---

## 技術的負債

### TECH-002: game_flow_manager.gdが大きすぎる
**優先度**: 高  
**行数**: 約500行

**問題**:
- 責務が多すぎる
- 保守性が低い
- テストが困難

**リファクタリング案**:
```
game_flow_manager.gd (100行)
  ├── turn_manager.gd (150行)
  ├── event_handler.gd (100行)
  └── action_processor.gd (150行)
```

---

### TECH-003: 予約語回避の命名規則が不統一
**優先度**: 中

**現状**:
- `tile_owner` と `owner_id` が混在
- `is_processing` と `is_active` が混在

**統一案**:
- 所有者: `owner_id` に統一
- 状態: `is_active` に統一

---

### TECH-004: エラーハンドリング不足
**優先度**: 中

**問題箇所**:
```gdscript
# card_system.gd
func use_card_for_player(player_id: int, index: int):
	var card = player_hands[player_id]["data"][index]
	# インデックス範囲外チェックなし
```

**改善案**:
```gdscript
func use_card_for_player(player_id: int, index: int):
	if not player_hands.has(player_id):
		push_error("Invalid player_id")
		return {}
	
	if index < 0 or index >= player_hands[player_id]["data"].size():
		push_error("Invalid card index")
		return {}
```

---

### TECH-005: マジックナンバーが多い
**優先度**: 低

**問題箇所**:
```gdscript
# 多数のファイルで
if magic_power > 500:
if card_count == 6:
if level >= 3:
```

**改善案**:
- game_constants.gdに集約
- または各システムで定数定義

---

### TECH-006: 属性名の統一規則
**優先度**: 高  
**追加日**: 2025/01/11

**ルール**:
すべての属性チェックは**英語**を使用する

**属性名リスト**:
```gdscript
# 正しい属性名（必ず英語）
"fire"     # 火
"water"    # 水
"wind"     # 風
"earth"    # 地
"neutral"  # 無属性
```

**チェック例**:
```gdscript
# ✅ 正しい
if element in ["fire", "water", "wind", "earth"]:

# ❌ 間違い（日本語を使わない）
if element in ["火", "水", "風", "地"]:
```

**適用箇所**:
- 属性連鎖の計算
- 土地ボーナスの判定
- スキル条件の評価
- UI表示は日本語でOK（翻訳処理を挟む）

**理由**:
- タイル定義が英語（`tile_type = "fire"`等）
- カードデータも英語（`"element": "fire"`）
- 内部処理は英語で統一し、表示のみ日本語に変換する設計

**注意事項**:
新しい属性チェックを追加する際は、必ずこのルールに従うこと

---

## 要望・提案

### FEATURE-001: マップ分岐システム
**提案日**: 2025/01/10  
**優先度**: 高  
**難易度**: 高

**内容**:
- 現在の菱形1周から自由分岐マップへ
- 十字路・T字路対応
- 非ループ構造のマップ
- カスタムマップエディター

**実装案**:
```gdscript
# tile_data.connections配列
{
  "index": 5,
  "connections": [4, 6, 12],  # 複数方向
  "junction_type": "cross",   # 十字路
  "requires_choice": true      # プレイヤー選択必要
}
```

---

### FEATURE-002: リプレイ機能
**提案日**: 2025/01/10  
**優先度**: 低  
**難易度**: 高

**内容**:
- ゲーム進行の記録
- リプレイ再生
- 早送り/巻き戻し

**実装案**:
```gdscript
# replay_system.gd
var actions = []

func record_action(action: Dictionary):
	actions.append(action)
	
func replay():
	for action in actions:
		await execute_action(action)
```

---

### FEATURE-003: カードフィルター機能
**提案日**: 2025/01/09  
**優先度**: 中  
**難易度**: 低

**内容**:
- デッキ編集時のカード検索
- 属性・コスト・レアリティフィルター

---

### FEATURE-004: 統計情報
**提案日**: 2025/01/10  
**優先度**: 低  
**難易度**: 中

**内容**:
- 勝率・平均ターン数
- よく使うカード統計
- 属性別勝率

---

### FEATURE-005: BGM・SE追加
**提案日**: 2025/01/09  
**優先度**: 中  
**難易度**: 中

**必要素材**:
- メニューBGM
- バトルBGM
- カード使用SE
- 勝利ファンファーレ

---

## 課題の優先順位付け

### 🚨 緊急対応（即時）
1. 🔴 **BUG-000: ターン終了処理の重複実行** ← **最優先**

### 今週対応（1/11 - 1/17）
1. 🔴 TECH-001: 古い2Dコード削除（BUG-000の根本対策）
2. 🔴 BUG-002: CPU AIの無限ループ
3. 🔴 UI-004: ターン終了ボタン追加
4. 🟡 BUG-003: 属性連鎖の誤判定

### 来週対応（1/18 - 1/24）
1. 🟡 BALANCE-001: 初期魔力調整
2. 🟡 BALANCE-002: 属性連鎖バランス
3. 🟡 UI-001: カード選択フィードバック

### 月末まで（1/25 - 1/31）
1. 🟢 TECH-001: game_flow_managerリファクタ
2. 🟢 PERF-001: 読み込み最適化
3. 🟢 UI-002: バトル結果表示

---

## バグ報告テンプレート

```markdown
### BUG-XXX: [バグタイトル]
**報告日**: YYYY/MM/DD
**優先度**: 高/中/低
**影響範囲**: [システム名]

**症状**:
[バグの説明]

**再現手順**:
1. 
2. 
3. 

**原因**:
[コード箇所や推測される原因]

**修正案**:
[修正方法の提案]

**ステータス**: 🚧 調査中 / ⚠️ 要対応 / 📋 計画中 / ✅ 完了
```

---

## 変更履歴

| 日付 | 変更内容 |
|------|---------|
| 2025/01/10 | 初版作成 |
| 2025/01/10 | BUG-001〜006追加 |
| 2025/01/10 | バランス調整項目追加 |
| 2025/01/11 | FEAT-001: 隣接土地判定システム実装完了 |
| 2025/01/11 | FEAT-002: 土地ボーナスシステム実装完了 |
| 2025/01/11 | BUG-007: 属性名の英語/日本語混在問題を解決 |
| 2025/01/11 | TECH-006: 属性名統一規則を追加 |
| 2025/01/12 | BUG-008〜011: デバッグモード・手札表示・ドラッグ問題を解決 |
| 2025/01/12 | FEAT-003: 先制スキルの動作確認完了 |

---

**最終更新**: 2025年1月12日
