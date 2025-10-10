# カルドセプト風カードバトルゲーム - プロジェクト詳細情報

## プロジェクト概要
- **プロジェクト名**: cardbattlegame
- **ジャンル**: カルドセプト風ボードゲーム型カードバトル
- **エンジン**: Godot Engine 4.4.1
- **言語**: GDScript
- **開発状況**: プロトタイプ完成（完成度75%）

## 重要な設計パターン

### 1. システム分離アーキテクチャ
- **GameFlowManager**: ゲーム進行・フェーズ管理
- **BoardSystem/BoardSystem3D**: マップ・タイル管理（2D/3D両対応）
- **CardSystem**: デッキ・手札管理
- **BattleSystem**: 戦闘判定・ボーナス計算
- **PlayerSystem**: プレイヤー情報・ターン管理
- **SkillSystem**: スキル効果・条件判定

### 2. シグナル駆動通信
```gdscript
# 各システムがシグナルで疎結合
signal tile_action_completed()
signal battle_ended(winner, result)
signal phase_changed(new_phase)
```

### 3. 2D/3D統合設計
- 同じロジックを2D/3Dで共有
- `is_3d_mode`フラグで分岐
- BoardSystem/BoardSystem3Dで実装切り替え

## ゲームフローの詳細

### メインループ（GameFlowManager）
```
GamePhase.SETUP
  ↓
GamePhase.DICE_ROLL (サイコロ入力待ち)
  ↓
GamePhase.MOVING (移動アニメーション)
  ↓
GamePhase.TILE_ACTION (マスイベント処理)
  ├─ 空き地: 召喚選択
  ├─ 敵の土地: バトル/通行料選択
  ├─ 自分の土地: レベルアップ選択
  └─ 特殊マス: イベント発火
  ↓
GamePhase.END_TURN
  ↓
次のプレイヤーへ（SETUPに戻る）
```

### CPU AI処理フロー
1. **cpu_ai_handler**が意思決定
2. シグナルで結果を通知
   - `summon_decided(card_index)`
   - `battle_decided(card_index)`
   - `level_up_decided(do_upgrade)`
3. GameFlowManagerが受け取り実行

### バトル判定の詳細実装

#### 先制攻撃システム
```gdscript
# BattleSystem.determine_battle_result_with_priority()
1. 攻撃側の先制攻撃
   AP >= 防御側HP? → 攻撃側勝利（終了）
   
2. 防御側生存なら反撃
   ST >= 攻撃側HP? → 防御側勝利
   
3. 両者生存 → 攻撃側勝利（土地獲得）
```

#### ボーナス計算の分離
```gdscript
# calculate_creature_bonuses()
return {
  "st_bonus": 属性相性ボーナス(+20),
  "hp_bonus": 地形ボーナス(+10~40) + 連鎖ボーナス
}
```

## スキルシステムの実装状態

### ability_parsed構造
```json
{
  "effects": [
    {
      "effect_type": "modify_stats|power_strike|instant_death|...",
      "target": "self|enemy|all_enemies|...",
      "conditions": [
        {
          "condition_type": "mhp_below|on_element_land|...",
          "value": 40,
          "element": "火"
        }
      ],
      "stat": "AP|HP",
      "operation": "add|multiply|set",
      "value": 20
    }
  ],
  "keywords": ["強打", "先制", "無効化[巻物]"]
}
```

### 実装済みの条件タイプ（ConditionChecker）
- `mhp_below` / `mhp_above`: MHP条件
- `on_element_land`: 特定属性の土地
- `has_all_elements`: 火水地風全保有
- `enemy_is_element`: 敵の属性判定
- `with_item_type` / `with_weapon`: アイテム条件
- `adjacent_ally_land`: 隣接自領地
- `is_defender_type`: 防御型判定

### 実装済みのエフェクト（EffectCombat）
- `power_strike`: 強打（AP×1.5倍）
- `modify_stats`: ステータス変更
- `instant_death`: 即死判定
- `nullify`: 無効化判定
- `affinity`: 感応（属性ボーナス）

## 重要な技術的制約

### 1. 予約語回避パターン
```gdscript
# NG: owner（Nodeの予約語）
var tile_owner: int

# NG: is_processing()（Nodeのメソッド）
func is_battle_active() -> bool
```

### 2. TextureRect制約
```gdscript
# NG: color プロパティは使用不可
texture_rect.color = Color.RED

# OK: modulate を使用
texture_rect.modulate = Color.RED
```

### 3. コスト正規化
```gdscript
# JSONデータが辞書形式の場合
if typeof(card_data.cost) == TYPE_DICTIONARY:
    card_data.cost = card_data.cost.mp
```

## データファイル構造

### カードデータ（fire.json等）
- **id**: 一意のカードID
- **name**: カード名
- **rarity**: E/R/S/N
- **type**: creature/spell/item
- **element**: 火/水/風/土/中立
- **cost**: {mp: 値, lands_required: [...]}
- **ap** / **hp**: 基礎ステータス
- **ability**: 簡易説明
- **ability_detail**: 詳細説明（日本語）
- **ability_parsed**: 解析済み効果（未実装多数）

### GameDataの構造
```gdscript
{
  "selected_deck_index": 0,
  "player_data": {
    "book_1": {
      "name": "炎の書",
      "cards": {
        1: 3,  # card_id: count
        2: 2
      }
    }
  }
}
```

## デバッグ機能

### キーボードショートカット
- **D**: CPU手札表示切替
- **1-6**: サイコロ固定（デバッグ用）
- **0**: サイコロ固定解除
- **7**: 敵の土地へ直接移動
- **8**: 空き地へ直接移動
- **9**: 魔力+1000G

### DebugPanel表示内容
- プレイヤー情報（魔力、位置、土地数）
- デッキ・捨て札枚数
- CPU手札（D キー切替）

## 完成度の内訳

### ✅ 実装済み（75%）
- ボードシステム（菱形20マス）
- 属性連鎖（通行料・HP）
- カードシステム（ドロー・使用）
- バトルシステム（先制攻撃・相性）
- プレイヤーシステム（4人対応）
- CPU AI基礎
- UI基本セット

### 🚧 部分実装（15%）
- スキルシステム（強打のみ実装）
- グラフィック（タイル画像のみ）
- デッキ編集（機能不足）

### ❌ 未実装（10%）
- スペルカード
- アイテムシステム
- チュートリアル
- バトルアニメーション
- BGM/SE

## 開発上の重要な注意点

### 1. フェーズ管理の厳格化
```gdscript
# 重複処理を防ぐ
if current_phase == GamePhase.END_TURN:
    return
```

### 2. シグナル接続の注意
```gdscript
# CONNECT_ONE_SHOTで多重接続防止
signal.connect(callback, CONNECT_ONE_SHOT)
```

### 3. ノード有効性チェック
```gdscript
if card_node and is_instance_valid(card_node):
    card_node.queue_free()
```

### 4. await使用時の注意
```gdscript
# ターン遷移前に必ず待機
await get_tree().create_timer(1.0).timeout
```

## パフォーマンス最適化ポイント

### 1. テクスチャサイズ
- 推奨: 128x128pxで作成、表示時に縮小
- 実際: 64x64px（50x50px表示）

### 2. ノード数削減
- カードノード: プレイヤー1のみ表示
- CPU手札: データのみ保持

### 3. z-index活用
- 奥行き表現に使用
- 描画順序の制御

## 次の開発優先事項

### 高優先度（2週間以内）
1. スペルカード実装
2. アイテムシステム基礎
3. CPU無限ループ修正（BUG-002）

### 中優先度（1ヶ月以内）
1. バランス調整（初期魔力、連鎖倍率）
2. UI改善（カード選択フィードバック）
3. グラフィック追加（背景、アイコン）

### 低優先度（3ヶ月以内）
1. リファクタリング（game_flow_manager分割）
2. テストコード追加
3. マルチプレイヤー対応
