# 🐛 カルドセプト風カードバトルゲーム - 課題管理

## 目次
1. [既知のバグ](#既知のバグ)
2. [バランス調整項目](#バランス調整項目)
3. [パフォーマンス問題](#パフォーマンス問題)
4. [UI/UX改善](#uiux改善)
5. [技術的負債](#技術的負債)
6. [要望・提案](#要望提案)

---

## 既知のバグ

### 🔴 Critical（ゲーム進行に影響）

#### BUG-000: ターン終了処理の重複実行
**報告日**: 2025/01/10  
**優先度**: 最高  
**最終更新**: 2025/01/10  
**優先度**: 最高  
**影響範囲**: GameFlowManager, BoardSystem3D, TileActionProcessor

**症状**:
- ターンが飛ばされる（プレイヤー1→プレイヤー3など）
- `end_turn()`が複数回呼ばれる
- フェーズ管理の不整合
- 頻繁に発生し、ゲーム進行を妨げる

**ターン終了処理の責任所在**:
```
【完全な呼び出しチェーン】

1. TileActionProcessor (tile_action_processor.gd)
   └─ _complete_action() 
	  └─ emit_signal("action_completed")
		 │
		 ↓
2. BoardSystem3D (board_system_3d.gd)
   └─ _on_action_completed()  [Line 219]
	  ├─ if is_waiting_for_action: (重複チェック)
	  └─ emit_signal("tile_action_completed")
		 │
		 ↓
3. GameFlowManager (game_flow_manager.gd)
   └─ _on_tile_action_completed_3d()  [Line 134]
	  ├─ if current_phase == END_TURN/SETUP: return (重複チェック)
	  └─ end_turn()  [Line 140]
		 └─ emit_signal("turn_ended", player_id)
```

**tile_action_completedが発火される全箇所**:

**A. BoardSystem3D経由（正常系）**:
```gdscript
# board_system_3d.gd
Line 221: _on_action_completed()
  ← tile_action_processor.action_completed
  ← cpu_turn_processor.cpu_action_completed
```

**B. GameFlowManager内での直接発火（問題系）**:
```gdscript
# game_flow_manager.gd
Line 151: _on_cpu_summon_decided()
  └─ board_system_3d.emit_signal("tile_action_completed")

Line 188: _on_cpu_level_up_decided()
  └─ board_system_3d.emit_signal("tile_action_completed")

Line 210-219: on_level_up_selected()
  └─ board_system_3d.emit_signal("tile_action_completed")
```

**C. 他のシグナル経由**:
```gdscript
# battle_system → board_system_3d._on_invasion_completed()
# special_tile_system → tile_action_processor._on_special_action_completed()
```

**根本原因**:
1. **シグナル経路の二重化**
   - 正常: TileActionProcessor → BoardSystem3D → GameFlowManager
   - 異常: GameFlowManagerが直接BoardSystem3Dのシグナルを発火
   
2. **非同期処理の競合**
   - バトル完了とアクション完了が同時発火
   - `await`中にフェーズが変わりチェックが無効化

3. **2D版と3D版の混在**
   - CPU関連の古いコード（Line 151, 188, 210-219）が残存
   - これらは削除予定だが放置されている

**重複防止機構（現状）**:
```gdscript
# game_flow_manager.gd Line 134-138
func _on_tile_action_completed_3d():
	if current_phase == GamePhase.END_TURN or current_phase == GamePhase.SETUP:
		print("Warning: tile_action_completed ignored (phase:", current_phase, ")")
		return
	end_turn()

# game_flow_manager.gd Line 230-233
func end_turn():
	if current_phase == GamePhase.END_TURN:
		print("Warning: Already ending turn")
		return
	# ...処理...

# board_system_3d.gd Line 219-223
func _on_action_completed():
	if not is_waiting_for_action:
		return
	is_waiting_for_action = false
	emit_signal("tile_action_completed")
```

**問題点**:
1. フェーズチェックだけでは非同期処理に対応できない
2. 複数箇所から同じシグナルを発火している
3. `is_waiting_for_action`と`current_phase`の二重管理で混乱

**修正案（推奨）**:

**Option 1: シグナル経路の完全一本化** ⭐推奨
```gdscript
# game_flow_manager.gd
# ❌ 削除: 直接のemit_signal呼び出しを全削除
func _on_cpu_summon_decided(card_index: int):
	# board_system_3d.emit_signal("tile_action_completed")  # 削除

# ✅ 修正: board_system_3dに処理を委譲
func _on_cpu_summon_decided(card_index: int):
	if board_system_3d:
		board_system_3d.tile_action_processor.execute_summon(card_index)
	# action_completed → tile_action_completed が自動発火
```

**Option 2: フラグによる排他制御強化**
```gdscript
# game_flow_manager.gd
var is_ending_turn = false
var turn_end_lock = false

func end_turn():
	if turn_end_lock:
		print("Warning: Turn end locked")
		return
		
	turn_end_lock = true
	is_ending_turn = true
	
	# ... 処理 ...
	
	await get_tree().create_timer(GameConstants.TURN_END_DELAY).timeout
	
	is_ending_turn = false
	turn_end_lock = false
```

**Option 3: CallableのONE_SHOT接続** 
```gdscript
# 全てのtile_action_completedシグナル接続をONE_SHOTに
board_system_3d.tile_action_completed.connect(
	_on_tile_action_completed_3d, 
	CONNECT_ONE_SHOT  # 1回だけ実行
)
```

**即時対応が必要な修正**:
```gdscript
# game_flow_manager.gd Line 151を削除
# func _on_cpu_summon_decided(card_index: int):
#     else:
#         board_system_3d.emit_signal("tile_action_completed")  # ← 削除

# game_flow_manager.gd Line 188を削除  
# func _on_cpu_level_up_decided(do_upgrade: bool):
#     board_system_3d.emit_signal("tile_action_completed")  # ← 削除

# game_flow_manager.gd Line 210, 219を削除
# func on_level_up_selected(target_level: int, cost: int):
#     board_system_3d.emit_signal("tile_action_completed")  # ← 全て削除
```

**関連するTECH負債**:
- TECH-001: 古い2Dコードの削除（これらのCPU処理コードを含む）
- TECH-002: game_flow_manager.gdのリファクタリング

**検証方法**:
1. デバッグモードで`end_turn()`呼び出しをカウント
2. 10ターン実行して全て1回ずつか確認
3. CPU vs CPUで100ターン自動実行テスト

**ステータス**: ⚠️ 最優先対応（即時修正必要）

---

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

### TECH-001: 古い2Dコードの削除
**優先度**: 高  
**影響範囲**: プロジェクト全体

**問題**:
- game.tscn（2D版）が残存
- board_system.gd（2D版）使用されていない
- 2D/3D分岐コードが混在
- コードベースの可読性低下

**削除対象**:
```
scenes/game.tscn
scripts/board_system.gd (存在する場合)
2D関連の条件分岐コード
```

---

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

---

**最終更新**: 2025年1月10日
