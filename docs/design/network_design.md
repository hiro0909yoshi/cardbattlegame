# ネット対戦基盤 設計書

**最終更新**: 2026-04-20
**ステータス**: 薄型リレーモデルへリファクタ中（旧: サーバー権威モデル）
**決定履歴**: 2026-02-21 案B採択（backend_design.md） → 2026-04 権威モデルに逸脱 → 2026-04-20 薄型に戻す判断

---

## 0. 方針（2026-04-20 確定）

### 採用方式: 薄型リレー + 要所検証モデル

`backend_design.md` の本来方針（案B）に合わせ、**対戦ロジックはクライアント（GDScript）が計算し、サーバーは検証・リレー・永続化のみ**担当する。Go サーバー側にバトル・スキル・スペル効果のロジックを再実装しない。

### 選定理由

- 既存 GDScript 実装（バトル5ファイル、スキル11種、スペル25+ファイル、アルカナアーツ59件）を Go 移植する工数は極大
- スキル追加のたびに 2 言語で保守する二重管理を避ける
- ターン制ゲームはリアルタイム要求が低く、ホスト権威方式で十分

### サーバー責任範囲

| カテゴリ | 担当 |
|---|---|
| 接続管理・ルーム・マッチメイキング | サーバー |
| ターン順・Phase 遷移管理 | サーバー |
| ダイス生成（乱数） | サーバー |
| 手札所持・EP残高・Phase一致の検証 | サーバー |
| 勝利条件判定・`game_over` 発行 | サーバー |
| 揮発状態保持（EP・位置・手札ID・タイル所有） | サーバー |
| `match_history` 記録・レーティング更新 | サーバー |
| **バトル計算・ダメージ算出・スキル発動** | **クライアント** |
| **スペル効果・アイテム効果・ドミニオ結果** | **クライアント** |
| **タイル価値・通行料・レベルアップコスト** | **クライアント** |

### クライアント責任範囲

- アクション結果（ダメージ・HP・タイル変化等）をすべて計算し `*_report` メッセージでサーバーに送信
- サーバーから受信した状態を**信頼して**表示（ローカル計算は検証のためにのみ保持）
- 永続データ（gold/gem/カード/デッキ）はサーバーAPI経由でのみ変更

### データの二分類

| 分類 | 保持場所 | 変更方法 | 例 |
|---|---|---|---|
| **永続データ** | PostgreSQL | REST API経由（サーバー権威） | gold, stone, user_cards, decks, ts_mu |
| **揮発データ** | サーバーメモリ（GameState） | WS経由（薄型・クライアント計算） | EP, 手札ID, 駒位置, タイル所有 |

### 計算結果の扱い（不一致時）

- **楽観モデル**: ターン保持者（アクション実行者）の計算結果を権威として採用
- 他プレイヤーは受信した結果で状態を上書き
- 検証失敗時（手札所持なし・EP不足等）は拒否＋`fraud_alerts` 記録
- 計算値の妥当性は事後ログ解析で検知（リアルタイム照合はしない）

### 検証の深さ（中レベル）

| 検証項目 | 受信時 | 方法 |
|---|---|---|
| 送信者 = ActivePlayer | ✅ | slot_index 比較 |
| Phase が許可状態 | ✅ | phase 比較 |
| 使用カードが手札にある | ✅ | `Hand` 配列検索 |
| EP がコスト分ある | ✅ | `EP >= cost` |
| ダメージ・HPが負数や異常値でない | ✅ | 範囲チェック |
| スキル発動条件の厳密チェック | ❌（中期以降） | クライアント計算を信頼 |
| 属性相性・アイテム効果の計算値 | ❌（中期以降） | クライアント計算を信頼 |

### WebSocket メッセージ設計（新プロトコル概要）

```
クライアント → サーバー:
  action_intent        アクション意図（summon, spell_cast 等）
  battle_result_report バトル計算結果の報告（ダメージ・HP確定値）
  action_result_report アクション結果の報告（召喚後のタイル状態等）
  end_turn             ターン終了宣言

サーバー → クライアント:
  game_state           初期/再接続時の全状態スナップショット
  turn_start           ターン開始通知（手札含む）
  your_hand            個別手札同期
  dice_result          ダイス結果（サーバー生成）
  action_broadcast     他プレイヤーのアクションを全員に配信
  battle_broadcast     バトル結果を全員に配信
  game_over            試合終了
  error                検証エラー
```

### 段階的リファクタ手順

- **Phase 0**: 本ドキュメント更新（本節）
- **Phase 1**: バトル結果送信化（`battle.go:ResolveBattle()` 削除 → クライアント計算）
- **Phase 2**: アクション結果送信化（召喚・スペル・ドミニオ）
- **Phase 3**: ゲーム定数のハードコード除去（マップJSON参照）
- **Phase 4**: 1試合フルテスト（スキル発動含む）

---

## 1. アーキテクチャ（旧: サーバー権威モデル — 参考情報）

> ⚠️ 以下は 2026-04 時点の旧方針。現在は §0 の薄型リレーモデルに移行中。
> Phase 1-4 完了後、本セクションは削除予定。

### 採用方式（旧）: サーバー権威（Server-Authoritative）

```
スマホ/PC ─── WebSocket ──→ [VPS: Go サーバー] ←── WebSocket ─── スマホ/PC
                                  ↑
                           ゲームロジック全実行
                           ＋ PostgreSQL
                           ＋ TrueSkillレーティング
                           ＋ マスタデータ検証
```

ダイス、EP、HP、ダメージ、勝敗の全てをサーバーが計算。クライアントは操作を送信し、結果を受け取って表示するのみ。

### 選定理由

| 観点 | 評価 |
|------|------|
| チート対策 | 強い（サーバーで全判定） |
| メモリ効率 | Go は 10-50MB（Godotヘッドレスの200-500MBと比較） |
| 同時接続 | 1台で1,000-10,000人対応可能 |
| コード管理 | サーバーとクライアントで別言語だが、プロトコル（JSON）で分離 |
| 将来性 | スケールアウト容易（Go + PostgreSQL） |

---

## 2. 通信プロトコル

### 2.1 REST API（認証・データ管理）

| メソッド | パス | 認証 | 説明 |
|---------|------|------|------|
| POST | `/api/auth/guest/register` | 不要 | ゲスト登録 |
| POST | `/api/auth/guest/login` | 不要 | ゲストログイン |
| POST | `/api/auth/refresh` | 不要 | トークンリフレッシュ |
| GET | `/api/player/profile` | JWT | プロフィール取得 |
| PUT | `/api/player/profile` | JWT | プロフィール更新 |
| GET | `/api/player/stats` | JWT | プレイ統計取得 |
| PUT | `/api/player/settings` | JWT | 設定更新 |
| GET | `/api/player/cards` | JWT | 所持カード一覧 |
| GET | `/api/player/decks` | JWT | デッキ一覧 |
| GET | `/api/player/unlocks` | JWT | 解放状態一覧 |

### 2.2 WebSocket（リアルタイム通信）

接続: `ws://server:8080/ws?token=<access_token>`

接続時にJWT検証。`Client`構造体に`UserID`(DB内部ID)と`UserUUID`(クライアントUUID)を保持。

### 2.3 認証フロー

```
[初回起動]
Client → POST /api/auth/guest/register { user_id, device_id, display_name }
       ← 201 { access_token, refresh_token, expires_in: 900, user_id }

[再ログイン]
Client → POST /api/auth/guest/login { user_id, device_id }
       ← 200 { access_token, refresh_token, expires_in: 900, user_id }

[トークン更新]
Client → POST /api/auth/refresh { user_id, refresh_token }
       ← 200 { access_token, refresh_token(新), expires_in: 900, user_id }
```

| トークン | 方式 | 有効期限 | 保存 |
|---------|------|---------|------|
| Access Token | JWT HS256 | 15分 | クライアントメモリ |
| Refresh Token | ランダム64hex + bcryptハッシュ | 30日 | DB（ハッシュのみ） |

---

## 3. WebSocket メッセージ体系

### 3.1 メッセージフォーマット

**ロビーメッセージ**（ws/message.go）:
```json
{"type": "room_state", "data": {...}, "ts": 1713500000000}
```

**ゲームメッセージ**（game/session.go newMsg）:
```json
{
  "type": "action_result",
  "data": {
    "player": 0,
    "action_type": "summon",
    "turn_number": 5,
    "state_version": 42,
    "data": {"card_id": 101, "tile": 7, "creature": {...}}
  },
  "ts": 1713500000000
}
```

ゲームメッセージには常に`state_version`（単調増加カウンター）を含む。

### 3.2 ロビーメッセージ一覧

| Client → Server | 説明 |
|----------------|------|
| `create_room` | ルーム作成 |
| `join_room` | ルーム参加 |
| `leave_room` | ルーム退出 |
| `set_ready` | 準備完了/解除 |
| `set_deck` | デッキ設定 |
| `start_game` | ゲーム開始（ホストのみ） |
| `list_rooms` | ルーム一覧取得 |
| `reconnect` | 再接続 |
| `start_matchmaking` | マッチング開始 |
| `cancel_matchmaking` | マッチング取消 |

### 3.3 ゲームアクション一覧

| Client → Server | フェーズ | 説明 |
|----------------|---------|------|
| `spell_cast` | spell | スペルカード使用 |
| `spell_pass` | spell | スペルスキップ → 自動ダイスロール |
| `move_complete` | move | 移動方向確定 |
| `summon` | tile_action | クリーチャー召喚 |
| `dominio_action` | tile_action | レベルアップ / 移動 / 交換 |
| `pass` | spell / tile_action | フェーズスキップ |
| `end_turn` | end_turn | ターン終了 |
| `card_selected` | - | カード選択通知（情報のみ） |

| Server → Client | 説明 |
|----------------|------|
| `game_state` | 完全なゲーム状態（開始時・再接続時） |
| `turn_start` | ターン開始通知 |
| `your_hand` | 手札情報（個別送信） |
| `action_result` | アクション結果（全員送信） |
| `dice_result` | ダイス結果（全員送信） |
| `action_error` | アクションエラー（個別送信） |
| `turn_timeout` | ターンタイムアウト通知 |
| `game_over` | ゲーム終了結果 |

---

## 4. 接続管理

### 4.1 Hub（接続管理中枢）

全クライアント接続とルームを管理するシングルトン。`sync.RWMutex`で保護。

**重複接続処理**: 同一UserIDの新規接続時、旧接続に`error`メッセージ送信後`conn.Close()`。
`close(send)`ではなく`conn.Close()`を使用（Room.Broadcastからのパニック防止）。

### 4.2 Room（接続管理層）

Roomは接続の管理のみを担当。ゲームロジックには一切関与しない。

```
ライフサイクル:
NewRoom (waiting) → Join × N → SetReady × N → AllReady (ready)
  → StartGame (host) → Playing（Session.Start()）
  → Finished（Session.Stop() or GameOver）
```

### 4.3 切断・再接続

```
切断検知（ReadPump終了）
  → Room.HandleDisconnect
    → PlayerSlot.Connected = false
    → Session.HandleDisconnect（channel経由）
    → 切断タイマー開始
      ├─ ranked: 30秒 → Session.HandleDefeat
      └─ friend: 60秒 → AI引き継ぎ通知

再接続
  → Room.HandleReconnect
    → PlayerSlot復元 → タイマーキャンセル
    → Session.HandleReconnect（完全state同期）
```

### 4.4 Keep-Alive

| パラメータ | 値 |
|-----------|-----|
| pingInterval | 10秒 |
| pongWait | 30秒 |
| writeWait | 10秒 |

---

## 5. ゲームエンジン（単一goroutineモデル）

### 5.1 設計原則

Sessionの全状態は1つのgoroutineからのみアクセス。mutexは不要。
外部からの全操作はchannel経由（バッファ64）でキューイングされ、厳密な順序保証のもと処理。

```go
// 全ての公開メソッドはノンブロッキングなchannel送信のみ
func (s *Session) HandleAction(slotIndex int, msgType string, data json.RawMessage) {
    select {
    case s.commands <- command{kind: cmdAction, slot: slotIndex, ...}:
    case <-s.ctx.Done():
    }
}
```

### 5.2 ターンフロー

```
turn_start + your_hand（個別）
  → spell_cast / spell_pass / pass
  → 自動DiceRoll → dice_result
  → move_complete → TransitionAfterLanding
    → 敵タイル: Battle / 空・味方: TileAction
  → summon / dominio_action / pass
  → end_turn → 勝利チェック → 次プレイヤー → DrawCard
```

### 5.3 ターンタイムアウト（60秒）

タイマーはchannel経由でcmdTimeoutを送信。フェーズに応じた強制進行:
- PhaseSpell → 自動dice → 自動移動 → EndTurn
- PhaseDice → 自動dice → 自動移動 → EndTurn
- PhaseMove/TileAction/Battle → 強制EndTurn

---

## 6. マッチメイキング

### レートティア

| ティア | DisplayRate範囲 |
|--------|----------------|
| Bronze | 0 - 9.99 |
| Silver | 10 - 19.99 |
| Gold | 20 - 29.99 |
| Platinum | 30 - 39.99 |
| Diamond | 40+ |

### マッチング方式

1. **同ティア内**: 1秒間隔スキャン、ベースレート範囲 ±5.0、待機時間に応じて閾値拡大
2. **クロスティア**: 30秒以上待機で発動、全ティアの長期待機者を集約

---

## 7. セキュリティ

### 7.1 実装済み

| 対策 | 実装 |
|------|------|
| JWT署名検証 | HS256、環境変数`JWT_SECRET` |
| リフレッシュトークン | bcryptハッシュDB保存 + 有効期限チェック（NULL=無効） |
| WS Origin検証 | `ALLOWED_ORIGINS`環境変数で許可オリジン制御 |
| WSメッセージサイズ制限 | `SetReadLimit(64KB)` |
| WSレートリミット | 30メッセージ/秒（スライディングウィンドウ） |
| WS同時接続制限 | maxClients = 2000 |
| WS送信バッファ溢れ | バッファフル時にconn.Close()で強制切断 |
| 重複接続防止 | conn.Close()で旧接続を安全に切断 |
| HTTPボディ制限 | 全POSTでMaxBytesReader(1MB) |
| RoomConfig検証 | InitialMagic/TargetMagic/MaxTurnsの範囲制限 |
| マスタデータ検証 | Summon: creature型, SpellCast: spell型チェック |
| アクションバリデーション | 手番・フェーズ・カード所持チェック |
| サーバー権威ダイス | math/rand/v2 PCG（シード記録） |
| Repositoryエラーラップ | 全DB操作でfmt.Errorf("operation: %w", err) |
| メッセージMarshalエラー | 失敗時にフォールバックJSON返却 |

### 7.2 防御的コーディング

「起きないはず」ではなく「起きても死なない」方針:
- ActivePlayerState() nilガード — session.go全5箇所
- Board長ゼロガード — processTurnTimeoutでゼロ除算防止
- Board/OwnerIndex範囲チェック — TransitionAfterLanding, ResolveBattle
- EndTurn最大ターン時の正確な勝者SlotIndex返却

### 7.3 本番環境で必要（未実装）

- JWT_SECRET 256bit以上のランダム値
- WSS (TLS) — Let's Encrypt等
- CORS設定 — 本番ドメインのみ
- REST Rate Limiting — 認証エンドポイント
- operation_logs活用 — チート検知ロジック

---

## 8. Godot クライアント側対応

### 8.1 実装済み基盤

- **control_type システム**: `"local"` / `"cpu"` / 将来 `"remote"`
- **CPU切り替え機構**: `convert_to_cpu()` / `convert_to_local()`（切断時のAI引き継ぎ受け口）
- **対戦モード通知**: `battle_auto_advance`（3秒自動進行）
- **ロビーUI**: `NetBattleLobby.tscn` / `net_battle_lobby.gd`
- **NetworkManager**: `network_manager.gd` WebSocket基盤

### 8.2 未実装（サーバー統合後）

- `control_type` に `"remote"` 追加 → サーバーからの結果待ち
- ローカルプレイヤーの操作 → サーバーに送信
- 回線切断検知 → `convert_to_cpu()` 呼び出し
- REST API クライアント（認証・データ同期）
- ログイン画面
- 接続状態表示UI

---

## 9. インフラ構成

| 項目 | 選定 |
|------|------|
| サーバー | Go バイナリ（1プロセス） |
| DB | PostgreSQL 16+（同一VPS or 別サーバー） |
| VPS | 月1,500円程度で十分（ターン制のため通信量・CPU負荷は極小） |

### スケーラビリティ

```
【〜1,000人】 VPS 1台、Go + PostgreSQL
     ↓
【〜5,000人】 VPS性能アップ（月2,000〜5,000円）
     ↓
【〜10,000人】 VPS複数台 + ロードバランサー
     ↓
【10,000人超】 水平スケーリング + DB分離
```

---

## 10. プラットフォーム対応

全プラットフォームから同じサーバーに接続。クロスプレイ対応。

```
同じGDScriptコード
  ├── Android版（.apk）→ Google Play
  ├── iOS版（.ipa）    → App Store
  ├── PC版（.exe/.app） → Steam / 直接配布
  └── Web版（.html）    → ブラウザで遊べる
```

---

## 関連ドキュメント

- `docs/design/server_architecture.md` — サーバー全体設計（詳細）
- `docs/design/database_design.md` — データベース設計
- `docs/design/backend_design.md` — バックエンド詳細設計
