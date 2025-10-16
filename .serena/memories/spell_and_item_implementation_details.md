# スペルフェーズ・アイテムシステム実装状況詳細 (2025/01/16)

## 実装完了内容

### 1. スペルフェーズ基本機能

#### SpellPhaseHandler (scripts/game_flow/spell_phase_handler.gd)
- **機能**: ターン開始時にスペルフェーズを実行
- **状態管理**: 
  - INACTIVE: 非アクティブ
  - WAITING_FOR_INPUT: スペル選択またはダイス待ち
  - SELECTING_TARGET: 対象選択中
  - EXECUTING_EFFECT: 効果実行中
- **使用制限**: 1ターン1回のみスペル使用可能
- **コスト処理**: MP（魔力）を消費してスペルを使用

#### GameFlowManagerとの統合
- ターン開始時の処理順序:
  1. カードドロー
  2. **スペルフェーズ** (新規追加)
  3. ダイスロールフェーズ
- ダイスボタンクリックでスペルをスキップ可能

### 2. テスト用スペルカード

#### data/spell_test.json
```json
{
  "cards": [
    {
      "id": 2106,
      "name": "マジックボルト",
      "type": "spell",
      "spell_type": "single_target",
      "cost": {"mp": 50},
      "effect": "対象敵クリーチャーのHP-20",
      "ability_parsed": {
        "target": {
          "type": "creature",
          "owner": "enemy",
          "count": 1,
          "required": true
        },
        "effects": [{
          "effect_type": "damage",
          "value": 20,
          "target": "selected_creature"
        }]
      }
    },
    {
      "id": 2063,
      "name": "ドレインマジック",
      "type": "spell",
      "spell_type": "single_target", 
      "cost": {"mp": 80},
      "effect": "対象敵セプターから魔力の30%を奪う",
      "ability_parsed": {
        "target": {
          "type": "player",
          "owner": "enemy",
          "count": 1,
          "required": true
        },
        "effects": [{
          "effect_type": "drain_magic",
          "value": 30,
          "value_type": "percentage",
          "target": "selected_player"
        }]
      }
    }
  ]
}
```

### 3. 対象選択システム

#### TargetSelectionUI (scripts/ui_components/target_selection_ui.gd)
- **機能**: スペルの対象を選択するUI
- **操作方法**:
  - ↑↓キー: 対象を選択
  - Enter: 決定
  - Esc: キャンセル
- **表示内容**:
  - クリーチャー選択時: 名前、タイル位置、HP
  - プレイヤー選択時: プレイヤー番号、名前、魔力
- **カメラ連動**: 選択中の対象にカメラが自動フォーカス

### 4. UI統合

#### 手札フィルター機能
- スペルフェーズ中はスペルカード以外をグレーアウト
- `card_selection_filter`プロパティで制御
- HandDisplayクラスで視覚的なフィルタリングを実装

#### デバッグ用初期手札
- プレイヤー1の初期手札にテストスペルカードを自動追加
- CardSystemの`_add_test_spell_cards`メソッドで実装

### 5. エフェクト実行

#### 実装済みエフェクトタイプ
- **damage**: クリーチャーへのダメージ
  - HP減少処理
  - HP0になったクリーチャーの自動除去
- **drain_magic**: 魔力吸収
  - パーセンテージ計算対応
  - 魔力の移動処理（敵→自分）

### 6. CPU AI対応
- 30%の確率でスペルを使用する簡易AI
- デバッグモードでは手動操作可能

## 重要な修正事項

### コスト計算の統一処理
スペルカードのコストが辞書型（`{"mp": 値}`）で定義されているため、全ファイルで以下の処理に統一:

```gdscript
var cost_data = card_data.get("cost", 1)
var cost = 0
if typeof(cost_data) == TYPE_DICTIONARY:
    cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
else:
    cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
```

修正したファイル:
- scripts/ui_components/card_selection_ui.gd
- scripts/tile_action_processor.gd
- scripts/battle_system.gd
- scripts/ui_components/debug_panel.gd
- scripts/flow_handlers/cpu_ai_handler.gd
- scripts/flow_handlers/cpu_turn_processor.gd

### 型指定問題の回避
CPUTurnProcessorクラスの認識問題を回避するため:
- 型指定を削除（`: CPUTurnProcessor` → 削除）
- 動的ロードを使用:
```gdscript
var CPUTurnProcessorClass = load("res://scripts/flow_handlers/cpu_turn_processor.gd")
if CPUTurnProcessorClass:
    cpu_turn_processor = CPUTurnProcessorClass.new()
```

## アイテムシステム準備状況

### 現在の状態
- アイテムカードのデータ構造は定義済み（data/item.json）
- カードタイプ"item"として識別可能
- **未実装**: バトル準備フェーズ
- **未実装**: アイテム効果の適用システム

### 今後の実装予定

#### Phase 1: バトル準備フェーズ
1. バトル開始前の準備フェーズを追加
2. アイテムカードの選択UI
3. 選択したアイテムの効果をバトル中に適用

#### Phase 2: アイテム効果システム
- ST（攻撃力）、HP（体力）の修正
- 属性変更
- 先制攻撃などの特殊効果

#### Phase 3: 巻物システム
- バトル中に使用可能な巻物カード
- 即時効果の実装（回復、ダメージなど）

## 既知の問題と対処

### 解決済み
1. ✅ `has("property")`の誤用 → `"property" in object`に修正
2. ✅ `update_display`メソッド名の誤り → `update_hand_display`に修正
3. ✅ コスト計算で辞書型と整数の混在 → 型チェックで対処
4. ✅ インデントエラー → 修正済み

### 残課題
- 世界呪システムの実装（持続効果の管理）
- より多様なスペル効果の実装
- バトル準備フェーズとアイテム/巻物システム

## 次のステップ推奨事項

1. **動作テスト**: 
   - スペルフェーズの基本動作確認
   - マジックボルトでクリーチャーへのダメージ確認
   - ドレインマジックで魔力吸収確認

2. **バトル準備フェーズの実装**:
   - BattleSystemにprepare_phaseを追加
   - アイテム選択UIの作成
   - アイテム効果の適用ロジック

3. **世界呪システム**:
   - WorldSpellManagerクラスの作成
   - 持続効果の管理システム
   - UI上部への世界呪表示

## ファイル構成

### 新規作成ファイル
- scripts/game_flow/spell_phase_handler.gd
- scripts/ui_components/target_selection_ui.gd
- data/spell_test.json

### 主要な変更ファイル
- scripts/game_flow_manager.gd (スペルフェーズ統合)
- scripts/ui_manager.gd (フィルター機能追加)
- scripts/ui_components/hand_display.gd (フィルター適用)
- scripts/card_system.gd (テストカード追加)
- scripts/board_system_3d.gd (remove_creature追加)

---
作成日: 2025/01/16
