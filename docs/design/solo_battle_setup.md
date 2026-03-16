# ソロバトル準備画面 設計ドキュメント

## 概要

ソロバトルボタンから遷移する専用の準備画面。ブック選択・マップ選択・CPU設定・ルール設定を1画面で行い、対戦を開始する。

## 画面遷移フロー

```
MainMenu → SoloBattleSetup → Main.tscn（バトル） → SoloBattleSetup（勝敗後）
                ↑                                         ↓
                └─────────────────────────────────────────┘
```

- メインメニューの「ソロバトル」ボタン → `SoloBattleSetup.tscn`
- 対戦開始 → `Main.tscn`（`solo_battle_config` メタデータ経由で設定を渡す）
- 勝利/敗北後 → `SoloBattleSetup.tscn` に戻る
- 戻るボタン → `MainMenu.tscn`

## UIレイアウト

```
┌─────────────────────────────────────────────────────────────────┐
│  [←戻る]              ソロバトル準備                             │
├────────────────────┬────────────────────────────────────────────┤
│                    │                                            │
│  ■ ブック選択       │  ■ マップ選択                              │
│  [スクロール可能]   │  [ボタンリスト]    [3Dマッププレビュー]     │
│  ┌──┐┌──┐ ┌─────┐ │                                            │
│  │ 1 ││ 2 │ │プレ │ │                                            │
│  └──┘└──┘ │ビュー│ ├────────────────────────────────────────────┤
│  ┌──┐┌──┐ │     │ │  ■ ルール設定                              │
│  │ 3 ││ 4 │ └─────┘ │  ▲ [数値] ▼ 形式のカスタムSpinBox        │
│  └──┘└──┘          │                                            │
│                    │  プリセット  最大ターン  目標TEP            │
│  ■ CPU対戦相手      │  初期EP(自分)  初期EP(CPU)                 │
│  [下寄せ配置]       │                                            │
│                    │                                            │
│  CPU1: [名前▼] ★☆☆│                                            │
│  CPU2: [なし▼] ☆☆☆│                                            │
│  CPU3: [なし▼] ☆☆☆│         【 対戦開始 】                      │
│  [3Dキャラプレビュー]│                                            │
└────────────────────┴────────────────────────────────────────────┘
```

### 左パネル
- **ブック選択**: GridContainer（2列） + 右側にプレビューボックス（プレースホルダー）
- **CPU対戦相手**: 下寄せ配置、最大3名、右側に3DキャラプレビューSubViewport×3

### 右パネル
- **マップ選択**: ボタンリスト + 3Dマッププレビュー
- **ルール設定**: 左グリッド（プリセット・最大ターン） + 右グリッド（目標TEP・初期EP）
- **対戦開始ボタン**: 下部中央、黄色文字

## CPU対戦相手

- CPU1は必須（「なし」選択不可）
- CPU2/CPU3はオプション（「なし」選択可）
- キャラクターは `characters.json` の `difficulties` 配列を持つキャラのみ表示
- 難易度 = デッキ切り替え（★ボタンで選択、最大3段階）
- 3Dキャラプレビュー: SubViewportContainer + SubViewport（own_world_3d=true）
  - IdleModelのメッシュ + WalkModelのアニメーション（root_nodeリマップ）

## ルール プリセット

| プリセット | 初期EP | 目標TEP | 最大ターン | 勝利条件 |
|-----------|--------|---------|-----------|---------|
| standard | 300 | 8000 | ∞ | TEP達成 |
| quick | 2000 | 4000 | 30 | TEP達成 |
| elimination | 1000 | - | ∞ | 敵全滅 |
| territory | 1000 | 10 | 50 | 領地数達成 |

- プリセット変更時、全パラメータが連動更新される
- 各値は手動で微調整可能
- 最大ターン 0 は「∞」（無制限）で表示

## データフロー

### solo_battle_config 構造

```gdscript
var config = {
    "map_id": "map_diamond_20",          # マップID
    "rule_preset": "standard",            # ルールプリセット名
    "initial_magic_player": 300,          # 初期EP（自分）
    "initial_magic_cpu": 300,             # 初期EP（CPU）
    "target_magic": 8000,                 # 目標TEP
    "max_turns": 0,                       # 最大ターン（0=無制限）
    "enemies": [                          # CPU敵リスト
        {"character_id": "bowser", "deck_id": "cpu_deck_1"},
        {"character_id": "zako_1", "deck_id": "cpu_deck_1"}
    ]
}
```

### 設定の受け渡し

1. `SoloBattleSetup` → `GameData.set_meta("solo_battle_config", config)` で保存
2. `game_3d.gd` の `_ready()` で `GameData.get_meta("solo_battle_config")` を検出
3. `_build_stage_from_config()` でステージデータに変換
4. `stage_loader.load_stage_from_data()` で読み込み
5. `system_manager.set_stage_data()` で GameResultHandler に渡す（遷移先判定用）

### ステージデータ変換結果

```gdscript
{
    "id": "solo_battle_custom",           # ソロバトル識別用固定ID
    "name": "ソロバトル",
    "map_id": "map_diamond_20",
    "rule_preset": "standard",
    "max_turns": 0,
    "rule_overrides": {
        "initial_magic": {"player": 300, "cpu": 300},
        "win_conditions": {"mode": "all", "conditions": [...]}
    },
    "quest": {
        "enemies": [...]
    }
}
```

## 背景

- CastleEnvironment を SubViewport 内で3Dレンダリング
- `setup_with_fixed_size(Vector3.ZERO, 12.0)` で固定サイズ生成
- ProceduralSkyMaterial で空を表示
- 半透明オーバーレイ（alpha 0.3）でUIの視認性確保
- バトル画面（Main.tscn）も同じ CastleEnvironment を使用（タイルから動的サイズ）

## ファイル構成

| ファイル | 役割 |
|---------|------|
| `scenes/SoloBattleSetup.tscn` | シーンファイル（最小限、スクリプト駆動） |
| `scripts/solo_battle_setup.gd` | 準備画面の全UI・ロジック |
| `scripts/game_3d.gd` | `solo_battle_config` 検出 + ステージデータ構築 |
| `scripts/game_flow/game_result_handler.gd` | ソロバトル終了後の遷移先判定 |
| `scripts/quest/base_environment.gd` | `setup_with_fixed_size()` 公開メソッド |
| `data/master/characters/characters.json` | CPU キャラ + difficulties 定義 |
| `scripts/game_constants.gd` | ルールプリセット定義 |

## 未実装・今後の対応

- **ブックプレビュー**: プレースホルダーボックスのみ作成済み
- **解放管理**: クリア状況によるキャラクター・マップの選択制限（全開放状態）
- **リザルト画面**: ソロバトル用リザルト画面（現在はWIN/LOSE簡易表示のみ）
