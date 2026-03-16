# ネット対戦ロビー・準備画面 設計ドキュメント

## 概要

ネット対戦ボタンから遷移するロビー画面。ランクマッチとフレンドマッチの2モードをタブで切り替え、マッチング後に準備画面へ遷移してバトルを開始する。

## 画面遷移フロー

```
MainMenu → NetBattleLobby → NetBattleSetup → Main.tscn（バトル） → NetBattleLobby
               ↑                                                         ↓
               └─────────────────────────────────────────────────────────┘
```

- メインメニューの「ネット対戦」ボタン → `NetBattleLobby.tscn`
- マッチング成立 → `NetBattleSetup.tscn`（準備画面）
- 対戦開始 → `Main.tscn`（バトル）
- 勝利/敗北後 → `NetBattleLobby.tscn` に戻る
- 戻るボタン → `MainMenu.tscn`

## シーン構成

### NetBattleLobby.tscn（ロビー画面 / 1シーン）

タブ切り替えで「ランクマッチ」「フレンドマッチ」を表示。将来モード追加にも対応可能。

```
┌─────────────────────────────────────────────────────────────────┐
│  [←戻る]              ネット対戦                                │
├─────────────────────────────────────────────────────────────────┤
│  [ ランクマッチ ]  [ フレンドマッチ ]                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─── ランクマッチタブ ─────────────────────────────────────┐   │
│  │                                                          │   │
│  │  現在のランク: ブロンズ III                               │   │
│  │  レート: 1200                                            │   │
│  │                                                          │   │
│  │  ■ ブック選択                                            │   │
│  │  [スクロール可能なブック一覧]                              │   │
│  │                                                          │   │
│  │  ルール: スタンダード（固定）                              │   │
│  │  対戦人数: 2人（固定）                                    │   │
│  │                                                          │   │
│  │           【 マッチング開始 】                             │   │
│  │                                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─── フレンドマッチタブ ───────────────────────────────────┐   │
│  │                                                          │   │
│  │  ■ ルーム作成    ■ ルーム参加                             │   │
│  │                                                          │   │
│  │  [ルーム作成]                                            │   │
│  │  ルームID: (自動生成)                                    │   │
│  │  対戦人数: [2▼] / [3▼] / [4▼]                           │   │
│  │                                                          │   │
│  │  [ルーム参加]                                            │   │
│  │  ルームID入力: [________]                                │   │
│  │  【 参加 】                                              │   │
│  │                                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### NetBattleSetup.tscn（準備画面 / 1シーン）

マッチング成立後の待機・設定画面。モードによりUI要素の表示/非表示を切り替え。

```
┌─────────────────────────────────────────────────────────────────┐
│  [←退出]              対戦準備                                  │
├────────────────────┬────────────────────────────────────────────┤
│                    │                                            │
│  ■ ブック選択       │  ■ 対戦相手                               │
│  [スクロール可能]   │                                            │
│  ┌──┐┌──┐         │  プレイヤー1: あなた ✓                     │
│  │ 1 ││ 2 │         │  プレイヤー2: Player_xyz ✓                 │
│  └──┘└──┘         │  プレイヤー3: (待機中...)                   │
│  ┌──┐┌──┐         │  プレイヤー4: (待機中...)                   │
│  │ 3 ││ 4 │         │                                            │
│  └──┘└──┘         ├────────────────────────────────────────────┤
│                    │  ■ マップ選択（ホストのみ）                 │
│                    │  [マップボタンリスト]                       │
│                    ├────────────────────────────────────────────┤
│                    │  ■ ルール設定（ホストのみ）                 │
│                    │  プリセット / 初期EP / 目標TEP / 最大ターン │
│                    │                                            │
│                    │                                            │
│                    │       【 準備完了 】 / 【 対戦開始 】       │
│                    │                                            │
└────────────────────┴────────────────────────────────────────────┘
```

## ランクマッチ vs フレンドマッチ

| 項目 | ランクマッチ | フレンドマッチ |
|------|------------|--------------|
| マッチング方式 | 自動（レート近似） | ルームID指定 |
| 対戦人数 | 2人固定 | 2〜4人選択可 |
| マップ選択 | サーバー自動選択 | ホストが選択 |
| ルール設定 | standard固定 | ホストがカスタマイズ可 |
| ブック選択 | ロビーで選択 | 準備画面で選択 |
| レート変動 | あり | なし |
| 準備画面 | 簡易（ブック選択済み） | フル（マップ・ルール設定あり） |

## ランクシステム（TrueSkill ベース）

レーティング計算には **TrueSkill** アルゴリズムを採用予定。多人数対戦（2〜4人）の順位をそのまま扱え、プレイヤーの不確実性も管理できるため、単純なEloより適している。

### TrueSkill パラメータ

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| 初期μ | 25.0 | 実力推定値（平均） |
| 初期σ | 8.333 | 不確実性（μ/3） |
| β | 4.167 | 実力幅（μ/6） |
| τ | 0.083 | 動的係数（σ/100） |

- **表示レート** = `μ - 3σ`（保守的推定、99.7%の確率でこの値以上の実力がある）
- 新規プレイヤーは表示レート 0 からスタート（25 - 3×8.333 ≈ 0）
- σが大きい（試合数が少ない）プレイヤーはレート変動が大きく、収束すると変動が小さくなる
- フレンドマッチではレート変動なし（ランクマッチのみ反映）

### ランク表示

| ランク | 表示レート範囲 | アイコン |
|--------|--------------|---------|
| ブロンズ | 0〜9 | 銅 |
| シルバー | 10〜19 | 銀 |
| ゴールド | 20〜29 | 金 |
| プラチナ | 30〜39 | 白金 |
| ダイヤモンド | 40〜 | ダイヤ |

- 各ランク内にI〜IIIのサブランクあり
- レート範囲はTrueSkillの表示レート（μ - 3σ）に基づく
- バックエンド実装時に具体的な閾値は調整予定

## マッチング フロー

### ランクマッチ

```
1. ブック選択 → マッチング開始ボタン
2. NetworkService.start_matchmaking(rating, deck_id) 呼び出し
3. マッチング待機UI表示（キャンセル可）
4. マッチング成立 → NetworkService.match_found シグナル
5. NetBattleSetup.tscn へ遷移（簡易モード）
6. 両者準備完了 → 対戦開始
```

### フレンドマッチ

```
[ホスト]
1. ルーム作成ボタン → NetworkService.create_room(max_players)
2. ルームID表示（共有用）
3. 参加者待機 → NetworkService.player_joined シグナル
4. NetBattleSetup.tscn へ遷移（フルモード）
5. マップ・ルール設定 → 全員準備完了 → 対戦開始

[ゲスト]
1. ルームID入力 → 参加ボタン
2. NetworkService.join_room(room_id)
3. NetBattleSetup.tscn へ遷移
4. ホストの設定を受信・表示
5. 準備完了ボタン → ホストの開始を待つ
```

## NetworkService インターフェース

バックエンド未決定のため、抽象レイヤーとしてシグナル + 空メソッドで定義。バックエンド決定後に実装を追加する。

```gdscript
class_name NetworkService
extends Node

# === シグナル ===
signal connected()
signal disconnected(reason: String)
signal match_found(match_data: Dictionary)
signal matchmaking_cancelled()
signal room_created(room_id: String)
signal room_joined(room_id: String, players: Array[Dictionary])
signal player_joined(player_data: Dictionary)
signal player_left(player_id: String)
signal player_ready_changed(player_id: String, is_ready: bool)
signal game_starting(game_config: Dictionary)
signal game_state_received(state: Dictionary)
signal error(code: String, message: String)

# === 接続 ===
func connect_to_server() -> void:
    pass

func disconnect_from_server() -> void:
    pass

# === ランクマッチ ===
func start_matchmaking(rating: int, deck_id: String) -> void:
    pass

func cancel_matchmaking() -> void:
    pass

# === フレンドマッチ ===
func create_room(max_players: int) -> void:
    pass

func join_room(room_id: String) -> void:
    pass

func leave_room() -> void:
    pass

# === 準備画面 ===
func set_ready(is_ready: bool) -> void:
    pass

func set_deck(deck_id: String) -> void:
    pass

func set_room_config(config: Dictionary) -> void:
    pass  # ホストのみ

# === ゲーム中 ===
func send_action(action: Dictionary) -> void:
    pass

func request_game_state() -> void:
    pass
```

## データフロー

### net_battle_config 構造

```gdscript
var config = {
    "mode": "ranked",                     # "ranked" or "friend"
    "room_id": "ABC123",                  # ルームID
    "map_id": "map_diamond_20",           # マップID
    "rule_preset": "standard",            # ルールプリセット名
    "initial_magic": 300,                 # 初期EP（全員共通）
    "target_magic": 8000,                 # 目標TEP
    "max_turns": 0,                       # 最大ターン（0=無制限）
    "players": [                          # プレイヤーリスト
        {"player_id": "local", "name": "あなた", "deck_id": "deck_0"},
        {"player_id": "remote_1", "name": "Player_xyz", "deck_id": "deck_2"}
    ]
}
```

### 設定の受け渡し

1. `NetBattleSetup` → `GameData.set_meta("net_battle_config", config)` で保存
2. `game_3d.gd` の `_ready()` で `GameData.get_meta("net_battle_config")` を検出
3. `_build_stage_from_net_config()` でステージデータに変換
4. `stage_loader.load_stage_from_data()` で読み込み
5. ネット対戦終了後 → `NetBattleLobby.tscn` に戻る

## 背景

- ソロバトル準備画面と同じ CastleEnvironment 3D背景を使用
- SubViewport + 半透明オーバーレイ構成

## ファイル構成

| ファイル | 役割 |
|---------|------|
| `scenes/NetBattleLobby.tscn` | ロビー画面シーン |
| `scripts/net_battle_lobby.gd` | ロビー画面の全UI・ロジック |
| `scenes/NetBattleSetup.tscn` | 準備画面シーン |
| `scripts/net_battle_setup.gd` | 準備画面の全UI・ロジック |
| `scripts/network/network_service.gd` | ネットワーク抽象レイヤー |
| `scripts/game_3d.gd` | `net_battle_config` 検出 + ステージデータ構築 |
| `scripts/game_flow/game_result_handler.gd` | ネット対戦終了後の遷移先判定 |

## 関連ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| `docs/design/network_design.md` | バックエンド基盤設計（案A/B比較） |
| `docs/design/online_rules_design.md` | オンラインルール・プリセット定義 |
| `docs/design/solo_battle_setup.md` | ソロバトル準備画面（参考実装） |

## 未実装・今後の対応

- **バックエンド選定**: Godotヘッドレス vs リレーサーバー（`network_design.md` 参照）
- **NetworkService実装**: バックエンド決定後に実装追加
- **観戦モード**: ロビーに「観戦」タブ追加（将来対応）
- **チャット機能**: ルーム内テキストチャット（将来対応）
- **招待システム**: フレンドリスト + 招待送信（将来対応）
- **切断対応**: 切断時の再接続・AI代替プレイ
- **不正対策**: サーバー認証・レート操作防止
