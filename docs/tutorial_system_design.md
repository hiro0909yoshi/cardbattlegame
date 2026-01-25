# チュートリアルシステム 再設計ドキュメント

## 現状の問題点

### 1. ゲーム進行との競合
- ゲームのシグナル（turn_started, movement_completed等）とチュートリアル進行が複雑に絡み合っている
- `wait_for_click`中にゲームが進行してステップがスキップされる
- シグナルハンドラ内で`advance_step()`を呼ぶタイミングが予測困難

### 2. ステップ定義の問題
- ステップごとに特殊処理が必要（if文の羅列）
- 新しいステップ追加時に既存コードの修正が必要
- `highlight`, `disable_all_buttons`, `highlight_tile_toll`などが排他的に処理されている

### 3. 拡張性の欠如
- 新しいチュートリアルステージ追加が困難
- ハイライト対象の追加に大量のコード変更が必要
- ステップデータとロジックが同じファイルに混在

---

## 新設計の方針

### 基本原則
1. **チュートリアルはゲームの「オブザーバー」**
   - ゲームの進行を監視し、適切なタイミングで割り込む
   - ゲームロジックを変更しない

2. **イベント駆動型**
   - ステップの進行は「トリガー条件」で決定
   - シグナルハンドラは条件判定のみ、ステップ進行は統一的に処理

3. **データ駆動型**
   - ステップ定義はJSONまたは辞書で完結
   - ロジックはステップ定義を解釈するだけ

---

## 新アーキテクチャ

```
TutorialSystem/
├── TutorialController.gd      # メインコントローラー
├── TutorialStepExecutor.gd    # ステップ実行エンジン
├── TutorialTriggerSystem.gd   # トリガー条件監視
├── TutorialHighlighter.gd     # ハイライト管理（統一）
├── TutorialUI.gd              # UI管理（Popup, Overlay統合）
└── data/
    ├── tutorial_stage1.json   # ステージ1のステップ定義
    ├── tutorial_stage2.json   # ステージ2のステップ定義
    └── tutorial_stage3.json   # ステージ3のステップ定義
```

---

## ステップ定義フォーマット（新）

```json
{
  "id": 9,
  "trigger": {
    "type": "signal",
    "signal_name": "summon_completed",
    "conditions": { "player_id": 0 }
  },
  "actions": {
    "pause_game": true,
    "show_message": {
      "text": "クリーチャーを召喚しました！",
      "position": "top"
    },
    "highlight": [
      { "type": "tile_toll", "target": "player_creature" }
    ],
    "disable_buttons": true
  },
  "completion": {
    "type": "click"
  },
  "next_step": 10
}
```

### トリガータイプ
| タイプ | 説明 | 例 |
|--------|------|-----|
| `immediate` | 前のステップ完了直後 | 連続説明 |
| `signal` | 特定シグナル受信時 | `turn_started`, `movement_completed` |
| `phase` | ゲームフェーズ変化時 | `dice`, `summon_select` |
| `delay` | 指定秒数後 | 自動進行 |

### 完了タイプ
| タイプ | 説明 |
|--------|------|
| `click` | ユーザークリック待ち |
| `signal` | 特定シグナル受信 |
| `auto` | 即座に完了（表示のみ） |

### ハイライトタイプ
| タイプ | ターゲット例 |
|--------|-------------|
| `button` | `["confirm", "up", "down"]` |
| `card` | `{ "filter": "green_ogre" }` |
| `tile_toll` | `"player_creature"`, `"player_position"`, `3` |
| `3d_object` | `{ "tile_index": 3 }` |

---

## TutorialController（メイン）

```gdscript
class_name TutorialController
extends Node

signal step_started(step_id: int)
signal step_completed(step_id: int)
signal tutorial_completed

var current_step: Dictionary = {}
var step_executor: TutorialStepExecutor
var trigger_system: TutorialTriggerSystem
var highlighter: TutorialHighlighter
var ui: TutorialUI

func start_tutorial(stage_data: Array):
    _steps = stage_data
    _execute_step(0)

func _execute_step(index: int):
    if index >= _steps.size():
        tutorial_completed.emit()
        return
    
    current_step = _steps[index]
    step_started.emit(current_step.id)
    
    # アクション実行
    step_executor.execute(current_step.actions)
    
    # 完了条件を設定
    match current_step.completion.type:
        "click":
            await ui.wait_for_click()
        "signal":
            await trigger_system.wait_for_signal(current_step.completion.signal_name)
        "auto":
            pass
    
    # クリーンアップ
    step_executor.cleanup()
    step_completed.emit(current_step.id)
    
    # 次のステップへ
    _execute_step(current_step.next_step)
```

---

## TutorialTriggerSystem

ゲームシグナルを監視し、ステップのトリガー条件と照合する。

```gdscript
class_name TutorialTriggerSystem
extends Node

signal trigger_matched(trigger_id: String)

var _pending_triggers: Dictionary = {}

func register_trigger(trigger: Dictionary, callback: Callable):
    match trigger.type:
        "signal":
            _connect_game_signal(trigger.signal_name, trigger.conditions, callback)
        "phase":
            _watch_phase(trigger.phase_name, callback)

func _connect_game_signal(signal_name: String, conditions: Dictionary, callback: Callable):
    # ゲームの各システムからシグナルを取得して接続
    # 条件が一致した場合のみcallbackを呼ぶ
```

---

## TutorialHighlighter（統一ハイライト管理）

すべてのハイライト処理を一元管理。

```gdscript
class_name TutorialHighlighter
extends Node

var _active_highlights: Array = []

func apply_highlights(highlights: Array):
    clear_all()
    for h in highlights:
        match h.type:
            "button":
                _highlight_buttons(h.targets)
            "card":
                _highlight_cards(h.filter)
            "tile_toll":
                _highlight_tile_toll(h.target)
            "3d_object":
                _highlight_3d(h.target)
        _active_highlights.append(h)

func clear_all():
    # すべてのハイライトを解除
    _active_highlights.clear()
```

---

## 実装状況

### 完了
- [x] `TutorialController.gd` - メインコントローラー
- [x] `TutorialTriggerSystem.gd` - シグナル監視・トリガー管理
- [x] `TutorialStepExecutor.gd` - アクション実行
- [x] `TutorialHighlighter.gd` - ハイライト統合管理
- [x] `TutorialUI.gd` - UI管理
- [x] `data/tutorial/tutorial_stage1.json` - ステージ1データ

### 残作業
- [ ] 既存の`TutorialManager`との統合・置き換え
- [ ] 動作テスト
- [ ] ステージ2, 3のデータ作成

---

## ファイル構成

```
scripts/tutorial/
├── tutorial_controller.gd      # メインコントローラー（新）
├── tutorial_trigger_system.gd  # トリガー管理（新）
├── tutorial_step_executor.gd   # アクション実行（新）
├── tutorial_highlighter.gd     # ハイライト管理（新）
├── tutorial_ui.gd              # UI管理（新）
├── tutorial_popup.gd           # ポップアップ（既存・再利用）
├── tutorial_overlay.gd         # オーバーレイ（既存・再利用）
└── tutorial_manager.gd         # 旧マネージャー（段階的に置換）

data/tutorial/
├── tutorial_stage1.json        # 基本チュートリアル
├── tutorial_stage2.json        # （予定）
└── tutorial_stage3.json        # （予定）
```

---

## 移行手順

### Phase 1: 並行運用
1. 新システムをオプションとして追加
2. 設定で新旧を切り替え可能に
3. 新システムで動作確認

### Phase 2: 完全移行
1. 旧TutorialManagerを削除
2. 新システムをデフォルトに
3. ステージ2, 3を追加