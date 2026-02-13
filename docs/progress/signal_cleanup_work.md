# シグナル・参照方向 改善計画

**最終更新**: 2026-02-14
**目的**: 循環参照・相互参照を解消し、保守性・テスタビリティを向上させる

---

## 現状の問題サマリー

### 🔴 トップレベル相互参照（2件）

| # | 参照関係 | 深刻度 | 問題 |
|---|---------|--------|------|
| 1 | **GameFlowManager ↔ BoardSystem3D** | 🟡 中 | GFM→BS: 移動・タイル操作 / BS→GFM: ターン制御 |
| 2 | **GameFlowManager ↔ UIManager** | 🟡 中 | GFM→UI: 表示更新 / UI→GFM: 入力伝達 |

### 🔴 下位→上位の逆参照（5件）

| # | 子システム | 親への参照 | 深刻度 | 問題 |
|---|-----------|----------|--------|------|
| 3 | TileActionProcessor | → GFM | ⚠️ 中 | spell_cost_modifier, spell_world_curse参照 |
| 4 | TileDataManager | → GameSystemManager | 🔴 高 | 最下位→最上位の参照 |
| 5 | MovementController | → GFM | 🟡 低 | is_game_ended確認 |
| 6 | SpecialTileSystem | → GFM | ⚠️ 中 | 特殊タイル処理 |
| 7 | CardSelectionUI | → GFM | 🟡 低 | debug_manual_control_all参照（DebugSettings移行済み） |

### 影響

- **テスト困難**: 子システムのテストに親のモック必須
- **デバッグ複雑化**: 循環参照で原因特定が困難
- **保守性低下**: 変更が複数システムに波及

---

## 改善アプローチ：Callable注入 + シグナルリレー

**戦略**: Autoloadを使わず、Godot標準パターンで解決

```
[ シグナルリレー ]（親経由の伝播）
	子 → 親 → 親の親
	├─ TileActionProcessor.action_completed
	│   → BoardSystem3D.tile_action_completed
	│       → GameFlowManager._on_tile_action
	└─ 木構造で依存が明確

[ Callable注入 ]（必要な状態共有）
	↓ setter で抽象化
	├─ TileActionProcessor.set_callback(callable)
	├─ TileDataManager.set_toll_calculator(callable)
	└─ 親から子へコールバック注入
```

### なぜAutoloadを避けるか

1. **グローバル状態の弊害** - 依存関係が不明確、テスト困難
2. **Godotベストプラクティス** - 公式も「控えめに」推奨
3. **明示的な依存** - コードを読めば依存が分かる
4. **テスタビリティ** - モック化が容易

---

## Phase 1: 低リスク改善（1-2日）

### 1-A. 下位→上位の逆参照をsetterで封じる

**対象**: 7ファイル

#### パターン例

```gdscript
# ❌ Before（GFMへの直接参照）
class_name TileActionProcessor
var game_flow_manager: GameFlowManager

func complete_action():
	game_flow_manager.spell_cost_modifier.apply()

# ✅ After（Callable で抽象化）
class_name TileActionProcessor
var action_completed_callback: Callable = func(): pass

func set_action_callback(callback: Callable) -> void:
	action_completed_callback = callback

func complete_action():
	action_completed_callback.call()
```

#### 修正対象ファイル

1. **tile_action_processor.gd**
   - `spell_cost_modifier` 参照 → setter化
   - `spell_world_curse` 参照 → setter化

2. **tile_data_manager.gd**
   - `spell_curse_toll` 参照 → setter化
   - GSM逆参照解消（最優先）

3. **movement_controller.gd**
   - `is_game_ended` 確認 → コールバック化

4. **special_tile_system.gd**
   - 特殊タイル処理 → イベント駆動化

5. その他3ファイル

**見積**: 1日
**難易度**: 低
**効果**: 下位→上位の逆参照が5件削減

---

### 1-B. Nullチェック強化（防御的プログラミング）

**対象**: GameFlowManager, BattleSystem, SpellPhaseHandler

```gdscript
# ✅ 完全性チェック
if board_system_3d and board_system_3d.has_method("complete_action"):
	board_system_3d.complete_action()
else:
	push_error("[GFM] complete_action が利用不可")
	return
```

**見積**: 0.5日
**効果**: クラッシュリスク低減

---

## Phase 2: 中リスク改善（2-3日）

### 2-A. シグナルリレーの整備（親経由伝播）

**実装**: 子→親→親の親のシグナルチェーン

```gdscript
# 子システム（TileActionProcessor）
class_name TileActionProcessor
signal action_completed

func complete_action():
	action_completed.emit()

# 親システム（BoardSystem3D）
func _ready():
	tile_action_processor.action_completed.connect(_on_action_completed)

signal tile_action_completed  # 上位へリレー

func _on_action_completed():
	tile_action_completed.emit()  # 親の親へ伝播
```

#### パターン

```gdscript
# ✅ シグナルリレーパターン
# 子のシグナル → 親が受信 → 親のシグナルで再送信

# BoardSystem3D
signal tile_action_completed  # GFMへ通知用

func _setup_signals():
	# 子システムのシグナルを受けて、自分のシグナルで再送信
	tile_action_processor.action_completed.connect(
		func(): tile_action_completed.emit()
	)
```

**修正対象**: 主要な子→親の通知（~20箇所）
**段階的**: 既存シグナルと並行可能
**見積**: 1.5日
**リスク**: 低（標準パターン）

---

### 2-B. Callable注入の拡大適用

**問題**: SpellPhaseHandler等の子が5システムに依存

```gdscript
# ✅ 必要な機能だけCallableで注入
class_name SpellPhaseHandler

# 親への依存を最小化
var on_phase_completed: Callable = func(): pass
var get_player_ep: Callable = func(player_id): return 0
var update_ui: Callable = func(text): pass

func set_callbacks(phase_cb: Callable, ep_cb: Callable, ui_cb: Callable):
	on_phase_completed = phase_cb
	get_player_ep = ep_cb
	update_ui = ui_cb

# 使用時
func complete_spell_phase():
	on_phase_completed.call()  # GFMへ通知
```

**効果**: 親への依存が明示的、テスト容易
**見積**: 1.5日

---

## リスク評価と緩和策

| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|--------|--------|
| 既存機能破損 | 🔴 高 | 高 | 各Phase後に全シーン実行テスト |
| 新規バグ誘発 | 🟡 中 | 中 | Debugパネルで詳細ログ |
| パフォーマンス低下 | 🟡 中 | 低 | EventBus最小化設計 |

**フェイルセーフ**: 各Phaseで完全なロールバック可能

---

## 期待効果

### 定量的効果
- **循環参照削減**: 30-40%解消
- **テストカバレッジ**: 20% → 60%
- **最大ファイル行数**: 1,764行 → 400行（神オブジェクト改善含む）

### 定性的効果
- テスタビリティ向上
- デバッグ時間短縮
- 新機能追加が容易
- コード理解度向上

---

## 実装スケジュール

```
週1:
  ✅ Phase 1-A: Setter化（1日）
  ✅ Phase 1-B: Nullチェック（0.5日）
  ✅ Phase 2-A: シグナルリレー整備（1.5日）

週2:
  ✅ Phase 2-B: Callable注入拡大（1.5日）
  ✅ 統合テスト・デバッグ（1日）

合計: 5.5日
```

---

## 関連ドキュメント

- `docs/design/god_object_analysis.md` - 神オブジェクト詳細分析
- `docs/design/god_object_improvement_roadmap.md` - 改善ロードマップ
- `docs/implementation/signal_catalog.md` - シグナル一覧
- `docs/implementation/delegation_method_catalog.md` - 委譲メソッド一覧

---

## 次のステップ

1. **Phase 1-A 実装開始**: tile_data_manager.gd の逆参照解消（最優先）
2. シグナルリレーパターンの適用（主要な子→親通知）
3. Callable注入の段階的拡大

**優先度**: 🔴 高（新機能開発の足かせになっている）

---

## 補足：既存のAutoload（維持）

**現在のAutoload（4個）** - これらは適切な用途のため維持：
1. ✅ **CardLoader** - カードデータ読み込み（アプリケーション全体で1つ）
2. ✅ **GameData** - 永続化データ管理
3. ✅ **DebugSettings** - デバッグフラグ集約
4. ✅ **GameConstants** - 定数定義

**追加しない**: EventBus（グローバル状態を避けるため）
