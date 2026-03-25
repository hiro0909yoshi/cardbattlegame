# ネット対戦基盤 設計書

カルドセプト風カードバトルゲーム（Godot 4.5 / GDScript）にオンライン対戦機能を追加する。
ターン制のため通信量・リアルタイム性の要求は低い。
モバイル（Android / iOS）での配布を想定。

---

## 1. アーキテクチャ（2案比較、未決定）

### 案A: Godotヘッドレス専用サーバー

```
スマホA ─── WebSocket ──→ [VPS: Godotヘッドレス] ←── WebSocket ─── スマホB
                              ↑
                         ゲームロジック実行（GDScript）
                         ＋ DB保存（SQLite）
                         画面描画なし
```

- Unreal Engine（Fortnite等）、Unity（Fall Guys等）と同じ方式
- VPS上でGodotを画面なしで起動し、GDScriptでゲームロジック実行

### 案B: リレーサーバー

```
スマホA（ホスト役）─── WebSocket ──→ [VPS: Python/Go] ←── WebSocket ─── スマホB
    ↑                                     ↑
  ゲームロジック実行                   メッセージ転送のみ
  （GDScript）                        ＋ DB保存
```

- VPSはメッセージを中継するだけ（ゲームロジックはホスト側で実行）
- サーバー側は別言語（Python/Go）で実装

### 比較表

| 比較項目 | 案A: Godotヘッドレス | 案B: リレーサーバー |
|----------|---------------------|-------------------|
| サーバー言語 | GDScript（同じ） | Python/Go（別言語） |
| 新言語の学習 | 不要 | 必要 |
| コード共有 | ゲームロジック丸ごと共有 | 不可（2言語管理） |
| チート対策 | 強い（サーバーで判定） | 弱い（クライアント側で判定） |
| サーバー費用 | 月1,500円〜 | 月500円〜 |
| バグ修正 | 1箇所 | 2箇所（サーバー＋クライアント） |
| メモリ使用 | 重い（200〜500MB） | 軽い（10〜50MB） |
| 同時接続（VPS1台） | 100〜300人 | 1,000〜10,000人 |

---

## 2. インフラ構成

### VPS（Virtual Private Server）

ネット上に借りる自分専用のPC。24時間稼働。プレイヤーのPCは常時稼働不要。

| サービス | 最安プラン | 特徴 |
|----------|-----------|------|
| さくらVPS | 月643円〜 | 国内、日本語サポート |
| ConoHa | 月296円〜 | 国内、時間課金あり |
| Vultr | 月$2.5〜 | 海外、安い |

ターン制カードゲームは通信量もCPU負荷も極小のため、月1,500円程度のプランで十分。

### DB（データベース）

VPSの中にSQLiteファイル1個を配置。別途DBサーバーは不要。

```
┌─── VPS ──────────────────────────┐
│  サーバーアプリ                      │
│       │                           │
│       ▼                           │
│  SQLiteファイル（users.db、数MB）   │
└──────────────────────────────────┘
```

#### DB設計（最小限）

| テーブル | カラム | 用途 |
|----------|--------|------|
| users | id, name, password_hash, rating, created_at | ユーザーアカウント |
| decks | id, user_id, name, cards_json | 対戦用デッキ |
| match_history | id, winner_id, loser_id, turns, duration, created_at | 対戦履歴 |

#### メモリのみ（DB不要）

- ロビー（部屋リスト）: 対戦終わったら消える一時データ
- ゲーム中の状態: サーバーのインスタンスが保持
- WebSocketセッション: 接続中のみ

#### あると良い（将来）

| テーブル | 用途 |
|----------|------|
| rankings | レーティング・マッチメイキング |
| card_collection | 所持カード（UserCardDBのサーバー版） |
| friends | フレンドリスト |

---

## 3. 通信プロトコル（JSON over WebSocket）

### 接続〜ロビー

```json
// ログイン
→ {"type": "login", "name": "Player1", "token": "xxx"}
← {"type": "login_ok", "user_id": 1, "rating": 1500}

// 部屋作成
→ {"type": "create_room", "room_name": "test", "max_players": 2, "rule_preset": "quick"}
← {"type": "room_created", "room_id": "abc123"}

// 部屋参加
→ {"type": "join_room", "room_id": "abc123"}
← {"type": "room_joined", "players": [{"id": 0, "name": "Player1"}, {"id": 1, "name": "Player2"}]}

// 準備完了
→ {"type": "ready"}
← {"type": "game_start", "seed": 12345, "player_order": [0, 1]}
```

### ゲーム中（サーバー → 全クライアントに送信）

```json
{"type": "turn_start", "player_id": 0, "turn_number": 1}
{"type": "spell_cast", "player_id": 0, "spell_id": 42, "target": {"type": "player", "id": 1}}
{"type": "spell_pass", "player_id": 0}
{"type": "dice_result", "player_id": 0, "dice1": 3, "dice2": 4, "total": 7}
{"type": "move_complete", "player_id": 0, "tile_index": 12}
{"type": "summon", "player_id": 0, "card_id": 15, "tile_index": 12}
{"type": "battle_start", "attacker_id": 0, "card_id": 15, "item_id": 3, "tile_index": 7}
{"type": "battle_result", "winner": "attacker", "attacker_hp": 20, "defender_hp": 0}
{"type": "dominio_action", "player_id": 0, "action": "level_up", "tile_index": 5, "level": 3}
{"type": "turn_end", "player_id": 0, "next_player_id": 1}
{"type": "game_over", "winner_id": 0, "reason": "magic_target_reached"}
```

### クライアント → サーバー（操作入力）

```json
{"type": "card_selected", "player_id": 1, "card_index": 3}
{"type": "pass", "player_id": 1, "phase": "spell"}
{"type": "dominio_input", "player_id": 1, "action": "level_up", "tile_index": 8}
```

---

## 4. ゲームフロー（ネット対戦時）

```
【サーバー】
1. 部屋が成立 → ゲームインスタンス生成
2. ゲームロジック実行
3. プレイヤーの操作待ち → WebSocketで受信
4. 結果を全クライアントにブロードキャスト
5. 勝敗決定 → DB保存

【クライアント（スマホ/PC）】
1. ロビーで部屋に参加
2. ゲーム開始通知 → 盤面初期化
3. 自分のターン: 操作をサーバーに送信
4. 相手のターン: サーバーからの結果を受信 → 画面更新
5. 勝敗決定 → 結果表示
```

---

## 5. プラットフォーム対応

Godotはマルチプラットフォーム対応。同じGDScriptコードから全プラットフォームにビルド可能。

```
同じGDScriptコード
  ├── Android版（.apk）→ Google Play
  ├── iOS版（.ipa）    → App Store
  ├── PC版（.exe/.app） → Steam / 直接配布
  └── Web版（.html）    → ブラウザで遊べる
```

全プラットフォームから同じサーバーに接続。クロスプレイ対応。

### ストア配布時の注意

| 項目 | 内容 |
|------|------|
| アプリ更新 | ストアの審査が必要（数日かかることも） |
| 課金 | ストア手数料30%（将来課金する場合） |
| データ更新 | カードステータス等のJSON → サーバー配信でアプリ更新不要にできる |

---

## 6. Godot側の変更点

### 6-1. サーバー側（案Aと案Bで異なる）

**案A（Godotヘッドレス）の場合:**
- 既存プロジェクトをベースにヘッドレス用に調整
- 描画・UI・サウンドを無効化、ゲームロジックのみ稼働
- WebSocketサーバー機能を追加（既存 network_manager.gd を拡張）

**案B（リレーサーバー）の場合:**
- Python/Go でWebSocketサーバーを新規作成（200〜300行）
- メッセージ転送 + DB保存のみ

### 6-2. クライアント側の変更（既存プロジェクト、どちらの案でも共通）

#### 実装済み基盤
- **control_type システム**: `_player_control_types: Array[String]`（"local"/"cpu"、将来"remote"追加）
  - `player_is_cpu` 互換プロパティ維持（外部11ファイルの参照をそのまま動作）
  - `get_control_type(player_id)` / `is_cpu_player(player_id)` 統一メソッド
  - GFM内・TileActionProcessor・BoardSystem3D・DiscardHandler のCPU判定を統一化済み
- **CPU切り替え機構**: `convert_to_cpu(player_id)` / `convert_to_local(player_id)`
  - フラグ変更のみ、即実行しない（次のターン/フェーズ開始時に反映）
  - `_control_type_overridden` で明示的切り替えが `DebugSettings.manual_control_all` より優先
  - 切り替え時に "balanced" ポリシー自動適用
- **対戦モード通知**: `GlobalCommentUI` / `SpellCastNotificationUI` の `battle_auto_advance`（3秒自動進行）
- **ロビーUI**: `NetBattleLobby.tscn` / `net_battle_lobby.gd` 実装済み
- **NetworkManager**: `network_manager.gd` WebSocket P2P 基盤あり
- **デバッグ**: `C`キーでP2のCPU/ローカル切り替え、`DebugSettings.test_cpu_takeover`

#### 未実装（サーバー構築後）
- `control_type` に `"remote"` 追加 → リモートプレイヤーのターンはサーバーからの結果を待つ
- ローカルプレイヤーの操作 → サーバーに送信
- オフライン（CPU対戦）は今まで通り動く（変更なし）
- 回線切断検知 → `convert_to_cpu()` 呼び出し
- ターンタイムアウト（60秒で自動パス → `convert_to_cpu()`）

### 6-3. 新規UI
- ログイン画面
- ロビー画面（部屋一覧、作成、参加） **[実装済み: NetBattleLobby]**
- 対戦中の接続状態表示

### 6-4. データ配信機能
- 起動時にサーバーからカードデータ（JSON）を取得
- 新しいデータがあればダウンロード → ローカルにキャッシュ
- アプリ更新なしでバランス調整・新カード追加が可能

---

## 7. スケーラビリティ（将来の拡張）

### 案Aの場合（Godotヘッドレス）

```
【〜300人】 VPS 1台（月1,500円）、Godotヘッドレス + SQLite
     ↓
【〜1,000人】VPS性能アップ or 複数台（月3,000〜5,000円）
     ↓
【1,000人超】Go/Rustに移行を検討
```

### 案Bの場合（リレーサーバー）

```
【〜1,000人】VPS 1台（月500円）、Python + SQLite
     ↓
【〜5,000人】VPS性能アップ（月2,000〜5,000円）
     ↓
【〜10,000人】Go に移行、PostgreSQL
     ↓
【10,000人超】VPS複数台 + ロードバランサー
```

### 共通: SQLite → PostgreSQL 移行

コード変更は最小限（ORM使用の場合、接続先1行のみ）。
データはエクスポート→インポートで移行。数時間のメンテナンスで完了。

### 共通: サーバー言語の移行

サーバー側のみ書き換え。
クライアント側（Godot）は一切変更なし（JSONプロトコルが同じため）。

---

## 8. リスクと対策

| リスク | 対策 |
|--------|------|
| 回線切断 | 60秒タイムアウト → AI引き継ぎ |
| チート | 案A: サーバーで全判定（強い） / 案B: ホスト側バリデーション（弱い） |
| サーバーダウン | 対戦中のゲームは失われる（初期は許容） |
| 遅延 | ターン制なので1秒程度の遅延は問題なし |
| サーバーバグ修正 | VPSにファイルアップ → 再起動（30秒）、ユーザーはアプリ更新不要 |
| クライアントバグ修正 | ストア経由でアプリ更新（審査あり） |
| バランス調整 | JSON配信で対応（アプリ更新不要） |

---

## 9. 段階的実装計画

### Phase 1: サーバー基盤
- サーバープロジェクト作成（案A or 案Bに応じて）
- WebSocketサーバー機能実装
- VPSにデプロイ、接続テスト
- **ゴール**: 2台の端末でメッセージが行き来する

### Phase 2: ロビー
- 部屋作成・参加・退出
- 準備完了 → ゲーム開始の流れ
- ロビーUI（クライアント側）
- **ゴール**: ロビーで部屋を作って相手と合流できる

### Phase 3: ターン同期
- サーバー: ゲームロジック稼働
- クライアント: `control_type` に `"remote"` 追加（基盤は実装済み）、操作の送受信
- 各フェーズ（スペル、ダイス、召喚、バトル、ドミニオ）の同期
- **ゴール**: 2人でオンライン対戦が成立する

### Phase 4: 安定化
- 回線切断検知 → AI引き継ぎ（`convert_to_cpu()` が受け口） **[受け口は実装済み]**
- ターンタイムアウト（60秒で自動パス → `convert_to_cpu()` 呼び出し）
- CPU代行時のデフォルトAI設定 **[実装済み]**
  - プレイヤーキャラにはCPU AI設定（バトルポリシー、AI思考レベル）がないため、
    `convert_to_cpu()` 時に統一デフォルトポリシー（"balanced"）を自動適用
  - ネット対戦は全員人間スタート → 切断者1人のみCPU化のため、ポリシー1つで十分
  - クエストモードは切断なし（オフライン）→ ステージ設定のCPUポリシーがそのまま使われる
  - デッキ・手札・キャラはプレイヤーのものをそのまま使用
- グローバルコメントUIのモード分離 **[実装済み]**
  - クエストモード: クリック待ち + 7秒タイムアウト（現行通り）
  - 対戦モード: 全コメント3秒自動進行（`battle_auto_advance = true`）
  - `GlobalCommentUI` と `SpellCastNotificationUI` の両方に対応済み
  - ソロバトル時に自動で有効化（`game_3d.gd`）
- 対戦結果のDB保存（SQLite）
- ユーザー認証（ログイン/登録）
- **ゴール**: 安定して遊べる状態

### Phase 5: モバイル対応
- Android / iOS ビルド
- タッチ操作の最適化
- ストア配布準備
- **ゴール**: スマホで対戦できる

### Phase 6: 拡張（将来）
- レーティング・マッチメイキング
- フレンド対戦
- チーム戦対応（TeamSystem連携）
- データ配信機能（アプリ更新なしのバランス調整）
- スケールアップ（PostgreSQL移行、VPS複数台）
