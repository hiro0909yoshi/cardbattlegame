# Arcana Conquest サーバー アーキテク���ャ詳細設計書

**最終更新**: 2026-04-19
**ステータス**: Phase 1 実装完了（コアエンジン + 認証 + 対戦基盤） + セキュリティレビュー4周完了 + 依存方向修正済み
**総コード量**: Go 約4,000行 / 31ファイル / 15パッケージ

---

## 1. 全体構成

### 1.1 技術スタック

| 項目 | 選定 | バージョン |
|------|------|-----------|
| 言語 | Go | 1.26.2 |
| DB | PostgreSQL | 16+ |
| WebSocket | gorilla/websocket | v1.5.3 |
| DB Driver | pgx/v5 | v5.9.1 |
| JWT | golang-jwt/jwt/v5 | v5.3.1 |
| パスワード | golang.org/x/crypto (bcrypt) | v0.50.0 |

### 1.2 アーキテクチャ概観

```
┌─────────────────────────────────────────────────────────────────┐
│                        main.go (エントリポイント)                  │
│  Config読込 → DB接続 → マスタデータ読込 → リポジトリ構築 → HTTP起動    │
└────────┬──────────────────────────────────┬──────────────────────┘
         │                                  │
    ┌────▼─────┐                    ┌───────▼────────┐
    │ REST API │                    │   WebSocket    │
    │ (認証不要) │                    │ (JWT query認証) │
    │          │                    │                │
    │ /health  │  ┌──────────┐     │ /ws?token=xxx  │
    │ /auth/*  │  │ 認証必須   │     └───────┬────────┘
    └──────────┘  │ /player/* │             │
                  └──────────┘     ┌───────▼────────┐
                                   │      Hub       │
                                   │ (接続管理中枢)   │
                                   └──┬─────────┬───┘
                                      │         │
                              ┌───────▼──┐  ┌──▼────────┐
                              │   Room   │  │ MatchQueue │
                              │ (接続層)  │  │ (待ち行列)  │
                              └────┬─────┘  └────────────┘
                                   │
                              ┌────▼─────┐
                              │ Session  │
                              │ (ゲーム   │
                              │  エンジン) │
                              └──────────┘
```

### 1.3 パッケージ構成

```
server/
├── main.go                   # エントリポイント（76行）
├── config/config.go          # 環境変数ベース設定（44行）
├── db/db.go                  # pgx接続プール（24行）
│
├── auth/                     # 認証基盤
│   ├── jwt.go                # JWT生成・検証・リフレッシュトークン（83行）
│   └── middleware.go         # HTTP認証ミドルウェア（38行）
│
├── model/                    # データモデル（DB構造体）
│   ├── user.go               # User構造体（57行）
│   ├── player_stats.go       # PlayerStats構造体（30行）
│   ├── card.go               # UserCard / Deck構造体（24行）
│   └── unlock.go             # UserUnlock構造体（11行）
│
├── repository/               # データアクセス層
│   ├── user.go               # CRUD + TrueSkill更新（179行）
│   ├��─ player_stats.go       # 統計UPSERT + 戦績更新（89行）
│   ├─��� card.go               # カード・デッキ同期（129行）
│   └── unlock.go             # 解放管理（58行）
│
├── handler/                  # HTTPハンドラ
│   ├── auth.go               # ゲスト登録・ログイン・リフレッシュ（180行）
│   ��── player.go             # プロフィール・統計・カード・デッキ（161行）
│   ├── websocket.go          # WS接続確立（47行）
│   ├── health.go             # ヘルスチェック（13行��
│   └── json.go               # レスポンスヘルパー（12行）
│
├── ws/                       # WebSocket接続管理層
│   ├── hub.go                # 接続管理・メッセージルーティング（313行）
���   ├── room.go               # ルーム管理（接続層のみ）（462行）
│   ├── client.go             # クライアント接続（103行）
│   ��── message.go            # メッセージフォーマット（34行）
│
├── game/                     # ゲームロジック（pure logic — DB依存禁止）
│   ├── session.go            # セッション管理（単一goroutine）
│   ├── state.go              # ゲーム状態
│   ├── action.go             # アクション処理
│   ├── battle.go             # バトル解決
│   └── result.go             # PlayerResult型・FormatRateChange（データのみ）
│
├── service/                  # ビジネスロジック層（game + repository を組み合わせ）
│   └── match_result.go       # 試合結果DB保存・レーティング更新
│
├── masterdata/card.go        # カードマスタデータ読込
├── rating/trueskill.go       # TrueSkillレーティング計算
├── matchmaking/queue.go      # レート別マッチメイキング
│
└── migration/                # DBマイグレーション（7組 × up/down）
    ├── 000001_create_users
    ├── 000002_create_player_stats
    ├── 000003_create_cards_and_decks
    ├── 000004_create_unlocks
    ├── 000005_create_rooms
    ├── 000006_create_match_history
    └── 000007_create_operation_logs
```

---

### 1.4 パッケージ依存方向

上位→下位の一方向のみ。逆方向・横断参照・相互参照は禁止。

```
main.go (組み立て — 全パッケージを知る唯一の場所)
  ├── handler ──→ auth, repository, ws, model
  ├── ws ────────→ game, matchmaking           ※ repository禁止、callback注入
  ├── service ──→ game, rating, repository     ※ DB操作はここで
  │
  ├── game ─────→ masterdata                   ※ pure logic、DB/repository禁止
  ├── repository → model
  └── model, auth, config, db, masterdata, rating (基盤層)
```

**設計原則:**
- **game パッケージ**: 計算のみ。結果を返すだけでDBを知らない
- **ws パッケージ**: 接続管理のみ。DB操作は `DeckLoader` 関数型のcallback注入で対応
- **service パッケージ**: game + repository を組み合わせるDB操作レイヤー
- **main.go**: 全パッケージを組み立てる唯一の場所

---

## 2. 認証システム

### 2.1 認証フロー

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

### 2.2 トークン仕様

| 種別 | アルゴリズム | 有効期限 | 保存場所 |
|------|------------|---------|---------|
| Access Token | JWT HS256 | 15分 | クライアントメモリ |
| Refresh Token | ランダム64hex + bcryptハッシュ | 30日 | DB（ハッシュのみ） |
| Transfer Code | ランダム16hex | 無期限 | DB（平文） |

### 2.3 JWT Claims

```go
type Claims struct {
    UserID int64  `json:"uid"`   // DB内部ID（自動採番）
    Sub    string `json:"sub"`   // ユーザーUUID（クライアント生成）
}
```

### 2.4 WebSocket認証

REST APIはBearerヘッダ認証。WebSocketはクエリパラメータで渡す。

```
ws://server:8080/ws?token=<access_token>
```

接続時にJWT検証し、`Client`構造体に`UserID`と`UserUUID`を保持。

---

## 3. WebSocket通信層

### 3.1 Client（クライアント接続）

各WebSocket接続に対して1つの`Client`が生成される。

```go
type Client struct {
    UserID   int64           // DB内部ID
    UserUUID string          // ユーザーUUID
    hub      *Hub            // Hub参照
    conn     *websocket.Conn // WebSocket接続
    send     chan []byte      // 送信バッファ（256）
    Room     *Room           // 参加中のRoom
}
```

**Pump構成**:
- **ReadPump**: メッセージ受信 → `Hub.HandleMessage`に委譲
- **WritePump**: sendチャネルからメッセージを順次送信 + Ping送信

**Keep-Alive設定**:

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| pingInterval | 10秒 | Ping送信間隔 |
| pongWait | 30秒 | Pong応答タイムアウト |
| writeWait | 10秒 | 書き込みデッドライン |

### 3.2 Hub（接続管理中枢）

全クライアント接続とルームを管理するシングルトン。

```go
type Hub struct {
    mu      sync.RWMutex
    clients map[int64]*Client    // userID → Client
    rooms   map[string]*Room     // roomID → Room
    queue   *matchmaking.Queue   // マッチメイキングキュー
}
```

**メッセージルーティング**:

| メッセージタイプ | 処理 | 認証 |
|----------------|------|------|
| `create_room` | ルーム作成 | WS認証済み |
| `join_room` | ルーム参加 | WS認証済み |
| `leave_room` | ルーム退出 | WS認証済み |
| `set_ready` | 準備完了 | WS認証済み |
| `set_deck` | デッキ設定 | WS認証済み |
| `start_game` | ゲーム開始（ホストのみ） | WS認証済み |
| `list_rooms` | ルーム一覧 | WS認証済み |
| `reconnect` | 再接続 | WS認証済み |
| `start_matchmaking` | マッチング開始 | WS認証済み |
| `cancel_matchmaking` | マッチング取消 | WS認証済み |
| **その他** | **→ Room.HandleGameAction** | **ゲーム中のみ** |

**重複接続処理**: 同一UserIDの新規接続時、旧接続にerrorメッセージ送信後close。

### 3.3 Room（接続管理層）

Roomは**接続の管理のみ**を担当し、ゲームロジックには一切関与しない。

```go
type Room struct {
    ID       string
    HostID   int64
    Config   RoomConfig
    Status   RoomStatus      // waiting → ready → playing → finished
    Players  []*PlayerSlot
    hub      *Hub
    Session  *game.Session   // ゲームセッション参照（playing以降）
    disconnectTimers map[int64]*time.Timer
}
```

**Roomのライフサイクル**:

```
NewRoom (waiting)
  ↓ Join × N
  ↓ SetReady × N
AllReady (ready)
  ↓ StartGame (host)
Playing ──→ Session.Start()
  ↓
Finished ──→ Session.Stop() or GameOver
```

**Roomの責務範囲（厳密な境界）**:

| Roomがやること | Roomがやらないこと |
|--------------|-----------------|
| PlayerSlot ↔ PlayerInit変換 | ゲーム状態の読み取り |
| broadcast/sendToコールバック提供 | フェーズ管理 |
| 切断タイマー管理 | ダメージ計算 |
| Session公開APIの呼び出し | StateVersionの管理 |

**切断・再接続処理**:

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
    → PlayerSlot復元
    → タイマーキャンセル
    → Session.HandleReconnect（完全state同期）
```

### 3.4 メッセージフォーマット

**ロビーメッセージ**（ws/message.go）:

```json
{
  "type": "room_state",
  "data": { ... },
  "ts": 1713500000000
}
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
    "data": { "card_id": 101, "tile": 7, "creature": {...} }
  },
  "ts": 1713500000000
}
```

ロビーメッセージにはStateVersionを含めない（不要）。ゲームメッセージはSession内の`newMsg`ヘルパーで生成し、常に`GameState.StateVersion`を埋め込む。

---

## 4. ゲームエンジン（game パ���ケージ）

### 4.1 設計原則

**サーバー権威（Server-Authoritative）**: ダイス、EP、HP、ダメージ、勝敗の全てをサーバーが計算。クライアントは結果を受け取って表示するのみ。

**単一goroutineモデル**: Sessionの全状態は1つのgoroutineからのみアクセスされる。mutexは不要。外部からの全操作はchannel経由でキューイングされ、厳密な順序保証のもと処理される。

### 4.2 Session（セッション = ゲームエンジン）

```go
type Session struct {
    state     *GameState       // 全ゲーム状態（このgoroutineのみがアクセス）
    RoomID    string
    MatchType string
    broadcast BroadcastFunc    // 全員送信（Room提供）
    sendTo    SendToFunc       // 個別送信（Room提供）
    onGameOver GameOverFunc    // 終了コールバック（Room提供）
    ctx       context.Context
    cancel    context.CancelFunc
    commands  chan command      // イベントキュー（バッファ64）
    turnTimer *time.Timer
}
```

#### 4.2.1 コマンドパターン

全ての外部操作は`command`構造体としてchannelに送信される。

```go
type command struct {
    kind    cmdKind          // コマンド種別
    slot    int              // プレイヤースロット
    msgType string           // アクション種別（cmdActionのみ）
    data    json.RawMessage  // アクションデータ（cmdActionのみ）
}

type cmdKind int
const (
    cmdAction     cmdKind = iota  // ゲームアクション
    cmdTimeout                     // ターンタイムアウト
    cmdDisconnect                  // 切断
    cmdReconnect                   // 再接続
    cmdDefeat                      // 敗北（切断タイムアウト）
    cmdStop                        // 強制停止
)
```

#### 4.2.2 メインループ

```go
func (s *Session) run() {
    defer s.stopTurnTimer()
    for {
        select {
        case <-s.ctx.Done():
            return
        case cmd := <-s.commands:
            switch cmd.kind {
            case cmdAction:    s.processAction(cmd.slot, cmd.msgType, cmd.data)
            case cmdTimeout:   s.processTurnTimeout()
            case cmdDisconnect: s.processDisconnect(cmd.slot)
            case cmdReconnect:  s.processReconnect(cmd.slot)
            case cmdDefeat:     s.processDefeat(cmd.slot)
            case cmdStop:       s.cancel(); return
            }
        }
    }
}
```

**全ての公開メソッドはノンブロッキングなchannel送信のみ**:

```go
func (s *Session) HandleAction(slotIndex int, msgType string, data json.RawMessage) {
    select {
    case s.commands <- command{kind: cmdAction, slot: slotIndex, ...}:
    case <-s.ctx.Done():
    }
}
```

#### 4.2.3 この設計が保証するもの

| 保証 | 根拠 |
|------|------|
| レースコンディションなし | stateにアクセスするgoroutineが1つだけ |
| 厳密な順序保証 | channelのFIFO特性 |
| デッドロックなし | mutexを使っていない |
| タイマーの安全性 | タイマーもchannel経由でキューイング |

### 4.3 GameState（ゲーム状態）

```go
type GameState struct {
    Players      []*PlayerState  // プレイヤー状態配列
    CurrentTurn  int             // 現在のターン番号
    ActivePlayer int             // アクティブプレイヤーのスロットインデックス
    Phase        Phase           // 現在のフェーズ
    Board        []*TileState    // ボード上の全タイル
    TargetTEP    int             // 勝利条件TEP
    MaxTurns     int             // 最大ターン数（0=無制限）
    TotalTurns   int             // 経過ターン数
    DiceResult   int             // 最新のダイス結果
    Seed         int64           // RNGシード
    rng          *rand.Rand      // PCG乱数生成器（非公開）
    Finished     bool            // ゲーム終了フラグ
    StateVersion int64           // 状態バージョン（単調増加）
}
```

#### 4.3.1 PlayerState

```go
type PlayerState struct {
    UserID       string  // ユーザーUUID
    InternalID   int64   // DB内部ID
    SlotIndex    int     // スロットインデックス（0-3）
    EP           int     // エネルギーポイント（通貨）
    Hand         []int   // 手札のカードID配列
    Deck         []int   // デッキ（残り山札）
    Discard      []int   // 捨て札
    Position     int     // ボード上の位置（タイルインデックス）
    LapCount     int     // 周回数
    TEP          int     // 総合評価ポイント（EP + タイル価値）
    Alive        bool    // 生存フラグ
    FinalRank    int     // 最終順位（ゲーム終了時に確定）
    Disconnected bool    // 切断フラグ
}
```

#### 4.3.2 TileState

```go
type TileState struct {
    Index      int     // タイルインデックス
    OwnerIndex int     // 所有者スロット（-1 = 無主）
    CreatureID int     // 配置クリーチャーID（0 = 空）
    CreatureHP int     // クリーチャーHP
    Level      int     // タイルレベル（1-5）
    IsDown     bool    // ダウン状態
    Element    string  // 属性（fire/water/earth/wind/neutral）
}
```

### 4.4 フェーズシステム

```
PhaseSpell → PhaseDice → PhaseMove → PhaseTileAction or PhaseBattle → PhaseEndTurn
                                           │                │
                                           │                ↓
                                           │         （敵タイルに着地）
                                           ↓
                                     （空/味方タイルに着地）
```

| フェーズ | 許可アクション | 説明 |
|---------|-------------|------|
| `spell` | spell_cast, spell_pass, pass | スペルカード使用またはスキップ |
| `dice` | （自動） | サーバーがダイスを振る |
| `move` | move_complete | 移動方向選択 |
| `tile_action` | summon, dominio_action, pass | 召喚 / レベルアップ / 移動 / 交換 |
| `battle` | （将来実装） | バトル解決 |
| `end_turn` | end_turn | ターン終了 |

#### 4.4.1 TransitionTo — 単一遷移ポイント

全てのフェーズ遷移は`TransitionTo`メソッドを通る。直接の`Phase`代入は禁止。

```go
func (gs *GameState) TransitionTo(next Phase) {
    gs.Phase = next
    gs.StateVersion++
}
```

### 4.5 StateVersion（状態バージョン管理）

**設計原則**: 「クライアントの表示が変わる変更は全てversion++」

StateVersionが増加するタイミング:

| 変更内容 | 発生箇所 | 方法 |
|---------|---------|------|
| フェーズ遷移 | `TransitionTo()` | 自動 |
| カードドロー（手札増加） | `DrawCard()` | `StateVersion++` |
| ダイスロール（ダイス結果変更） | `RollDice()` | `StateVersion++` |
| カード使用（手札減少） | `RemoveFromHand()` | `StateVersion++` |
| バトル解決（HP/EP/タイル変更） | `ResolveBattle()` | `StateVersion++` |
| 位置変更（タイムアウト時の強制移動） | `processTurnTimeout()` | `StateVersion++` |
| 切断フラグ変更 | `processDisconnect()` | `StateVersion++` |
| 再接続フラグ変更 | `processReconnect()` | `StateVersion++` |
| 生存フラグ変更 | `processDefeat()` | `StateVersion++` |

**単一ソース**: StateVersionは`GameState`構造体にのみ存在する。ws/message.goにグローバルカウンターは持たない。

**broadcast順序の保証**: 必ず「状態変更 → version確定 → broadcast」の順序で実行。Sessionが単一goroutineで動作するため、この順序は構造的に保証される。

### 4.6 アクション処理

#### 4.6.1 バリデーション

全アクションは2段階バリデーションを通る:

```go
if err := gs.ValidateActivePlayer(slotIndex); err != nil { return err }  // 手番チェック
if err := gs.ValidatePhase(expected); err != nil { return err }          // フェーズチェック
```

#### 4.6.2 JSON Unmarshalエラー処理

全てのクライアントデータのUnmarshalにはエラーチェックを実装:

```go
if err := json.Unmarshal(data, &req); err != nil {
    s.sendTo(slotIndex, newMsg("action_error", &ActionError{
        Code: "bad_request", Message: "invalid JSON",
    }))
    return
}
```

壊れたJSONを送信してきたクライアントには即座にエラーを返し、ゲーム状態は一切変更しない。

#### 4.6.3 アクション一覧

| アクション | フェーズ | 説明 |
|-----------|---------|------|
| `spell_cast` | spell | スペルカード使用（手札消費 → dice移行） |
| `spell_pass` | spell | スペルスキップ → 自動ダイスロール |
| `move_complete` | move | 移動方向確定 → 着地判定 |
| `summon` | tile_action | クリーチャー召喚（空タイルのみ） |
| `dominio_action` | tile_action | レベルアップ / クリーチャー移動 / 交換 |
| `pass` | spell / tile_action | 現フェーズスキップ |
| `end_turn` | end_turn | ターン終了 → 勝利判定 → 次プレイヤー |
| `card_selected` | - | カード選択通知（バリデーションなし） |

#### 4.6.4 ターンタイムアウト（60秒）

```
タイマー発火 → channel送信 → processTurnTimeout
  ├─ PhaseSpell → 自動dice → 自動移動 → EndTurn
  ├─ PhaseDice → 自動dice → 自動移動 → EndTurn
  ├─ PhaseMove/TileAction/Battle → 強制EndTurn
  └─ PhaseEndTurn → 即EndTurn
```

タイマーはSession内のcommands channelに`cmdTimeout`を送信する。直接メソッドを呼ばないため、goroutineの排他性が崩れない。

### 4.7 勝利条件・順位決定

#### 4.7.1 TEP（総合評価ポイント）

```
TEP = EP + Σ (所有タイルのLevel × 100)
```

#### 4.7.2 勝利条件

TEPがTargetTEP以上に到達した最初のプレイヤーが勝利。

#### 4.7.3 最大ターン到達時の順位

タイブレイクルール（優先順）:
1. **TEP** が高い方が上位
2. TEP同値 → **EP** が高い方が上位
3. EP同値 → **所持タイル数** が多い方が上位

### 4.8 バトルシステム

```go
type BattleContext struct {
    AttackerSlot   int  // 侵入者
    DefenderSlot   int  // 防御者（タイル所有者）
    TileIndex      int  // バトル発生タイル
    AttackerItemID int  // 攻撃側アイテム
    DefenderItemID int  // 防御側アイテム
}
```

**ダメージ計算**:

```
攻撃側: atkAP（基本AP + アイテムAP）
防御側: defHP（基本HP + 地形ボーナス + アイテムHP）

地形ボーナス = タイルLevel × 10
同時攻撃: defHP -= atkAP, atkHP -= defAP
```

**バトル結果**:
- 防御側HP ≤ 0 かつ 攻撃側HP > 0 → **攻撃側勝利**（タイル奪取）
- 攻撃側HP ≤ 0 → **防御側勝利**（相討ちも防御側有利）
- 両者生存 → 防御側残留、攻撃側通過

**通行料**: 防御側勝利時、攻撃側は `Level × 100` EPを防御側に支払う。

### 4.9 EndTurn処理フロー

```
EndTurn(slotIndex)
  ├── バリデーション（手番 + フェーズ）
  ├── ダウン状態解除（自分の全タイル）
  ├── 勝利条件チェック → 該当あり → assignRanks → GameOver
  ├── 最大ターンチェック → 到達 → assignRanksByTEP → GameOver
  ├── 次プレイヤー検索
  │   └── 全員不能 → GameOver
  ├── ターン番号更新
  ├── アクティブプレイヤー変更
  ├── TransitionTo(PhaseSpell)
  └── DrawCard（次プレイヤーにカードドロー）
```

---

## 5. マッチメイキングシステム

### 5.1 レートティア

| ティア | DisplayRate範囲 | サブティア |
|--------|----------------|-----------|
| Bronze | 0 - 9.99 | _1, _2, _3 |
| Silver | 10 - 19.99 | _1, _2, _3 |
| Gold | 20 - 29.99 | _1, _2, _3 |
| Platinum | 30 - 39.99 | _1, _2, _3 |
| Diamond | 40+ | _1, _2, _3 |

### 5.2 マッチング方式

```
同ティア内マッチング
  ├── 1秒間隔スキャン
  ├── ベースレート範囲: ±5.0
  ├── 待機時間に応じて閾値拡大: +5.0 / 10秒
  └── 条件: |rateA - rateB| ≤ baseRange + (waitSec / 10) × expansion

クロスティアマッチング（30秒以上待機で発動）
  ├── 全ティアの長期待機者を集約
  ├── レート順ソート
  ├── スライディングウィンドウでmatchSize人の最適グループを探索
  └── 同じ閾値計算で判定
```

### 5.3 マッチ成立フロー

```
QueueEntry → Queue.Enqueue()
  → scanLoop (1秒間隔)
    → tryMatch (同ティア) or tryCrossTierMatch
      → CreateRoomFunc callback
        → Hub内でRoom自動生成
          → 全参加者にmatch_found送信
```

---

## 6. TrueSkillレーティング

### 6.1 パラメータ

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| μ (mu) 初期値 | 25.0 | 平均スキル |
| σ (sigma) 初期値 | 8.333 | 不確実性 |
| β (beta) | 4.167 | パフォーマンスの標準偏差 |
| τ (tau) | 0.083 | ダイナミクス係数 |
| DrawProb | 0.0 | 引き分け確率（なし） |

### 6.2 計算方式

**ペアワイズFFA更新**: 2-4人の自由対戦（FFA）に対応。全ペアの組み合わせでTrueSkill更新を計算し、プレイヤー数に応じたスケール係数（`2/N`）で減衰させる。

```
DisplayRate = μ - 3σ (最小0)
```

### 6.3 ランクマッチ結果処理

```
GameOver
  → MatchResultProcessor.ProcessRankedResult
    → DB から各プレイヤーの現在μ/σ取得
    → rating.Update で新μ/σ計算
    → DisplayRate / RankTier算出
    → DB更新（users.ts_mu, ts_sigma, display_rate, rank_tier）
    → stats更新（total_battles++, wins++）
```

---

## 7. データベース

### 7.1 テーブル一覧

| テーブル | マイグレーション | 用途 |
|---------|----------------|------|
| `users` | 000001 | ユーザーアカウント・認証・レーティング |
| `player_stats` | 000002 | プレイ統計 |
| `user_cards` | 000003 | カード所持情報 |
| `decks` | 000003 | デッキ構成 |
| `user_unlocks` | 000004 | 解放管理 |
| `rooms` / `room_players` | 000005 | ルーム管理（将来の永続化用） |
| `match_history` / `match_players` | 000006 | 対戦履歴 |
| `operation_logs` | 000007 | 操作ログ（チート検知） |

### 7.2 Repository層

全Repositoryは`pgxpool.Pool`を受け取り、SQLを直接実行する薄いラッパー。ORMは不使用。

| Repository | 主要操作 |
|------------|---------|
| `UserRepo` | Create, GetByID, GetByUserID, UpdateProfile, UpdateGold, UpdateStone, UpdateStamina, UpdateLoginBonus, UpdateSettings, UpdateInventory, UpdateTrueSkill, UpdateRefreshToken, UpdateTransferCode, GetByTransferCode |
| `PlayerStatsRepo` | Upsert (ON CONFLICT), GetByUserID, IncrementBattle, UpdateCollectionComplete |
| `CardRepo` | UpsertCard, GetCards, RemoveCard, UpsertDeck, GetDecks, DeleteDeck, SyncCards, SyncDecks（バルクトランザクション同期） |
| `UnlockRepo` | Add (ON CONFLICT DO NOTHING), GetAll, HasKey, Remove |

---

## 8. マスタデータ

### 8.1 カードデータ読込

サーバー起動時に全JSONファイルをメモリにロードする。

```
data/
├── fire_1.json, fire_2.json          # 火属性クリーチャー
├── water_1.json, water_2.json        # 水属性クリーチャー
├── earth_1.json, earth_2.json        # 地属性クリーチャー
├── wind_1.json, wind_2.json          # 風属性クリーチャー
��── neutral_1.json, neutral_2.json    # 無属性クリーチャー
├── spell_1.json, spell_2.json        # スペルカード
└── item.json                          # アイテムカード
```

**Card構造体**:

```go
type Card struct {
    ID            int
    Name          string
    Rarity        string
    Type          string          // "creature" / "spell" / "item"
    Element       string
    Cost          CardCost        // { EP, LandsRequired }
    AP            int
    HP            int
    AbilityParsed json.RawMessage // クリーチャースキル
    EffectParsed  json.RawMessage // アイテム効果
}
```

アクセスは`sync.RWMutex`で保護（読み取り頻度が極めて高いため`RLock`最適化）。

---

## 9. REST API一覧

### 9.1 公開エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/health` | ヘルスチェック |
| POST | `/api/auth/guest/register` | ゲスト登録 |
| POST | `/api/auth/guest/login` | ゲストログイン |
| POST | `/api/auth/refresh` | トークンリフレッシュ |
| GET | `/ws?token=xxx` | WebSocket接続 |

### 9.2 認証必須エンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| GET | `/api/player/profile` | プロフィール取得 |
| PUT | `/api/player/profile` | プロフィール更新 |
| GET | `/api/player/stats` | プレイ統計取得 |
| PUT | `/api/player/settings` | 設定更新 |
| GET | `/api/player/cards` | 所持カード一覧 |
| GET | `/api/player/decks` | デッキ一覧 |
| GET | `/api/player/unlocks` | 解放状態一覧 |

---

## 10. セキュリティ設計

### 10.1 実装済み

| 対策 | 実装 |
|------|------|
| JWT署名検証 | HS256、環境変数`JWT_SECRET` |
| リフレッシュトークン | bcryptハッシュでDB保存（平文非保存） + 有効期限チェック |
| WebSocket認証 | 接続時にJWT検証必須 |
| WS Origin検証 | `ALLOWED_ORIGINS`環境変数（カンマ区切り）で許可オリジン制御。空=全許可（開発用） |
| WSメッセージサイズ制限 | `SetReadLimit(64KB)` で巨大メッセージを遮断 |
| WSレートリミット | 1秒あたり30メッセージ上限（スライディングウィンドウ） |
| WS同時接続制限 | `maxClients = 2000`、超過時は接続拒否 |
| WS送信バッファ溢れ | バッファフル時に`conn.Close()`で強制切断（デッドクライアント排除） |
| DBコネクションプール | `MaxConns=25, MinConns=5, MaxConnLifetime=30m, HealthCheck=1m` |
| トランザクション境界 | ランクマッチ結果（TrueSkill + stats）を単一トランザクションで更新 |
| アクションバリデーション | 手番・フェーズ・カード所持チェック |
| JSONパースエラー | 即座にエラー返却、状態変更なし |
| サーバー権威ダイス | `math/rand/v2` PCG（シード記録） |
| 重複接続防止 | 同一ユーザーの旧接続を切断 |
| RoomConfig検証 | InitialMagic/TargetMagic/MaxTurnsの範囲制限 |
| Repositoryエラーラップ | 全DB操作で`fmt.Errorf("operation: %w", err)`によるコンテキスト付きエラー |
| HTTPリクエストボディ制限 | 全POSTエンドポイントで`MaxBytesReader(1MB)`適用 |
| マスタデータ検証 | Summon時にcreature型チェック、SpellCast時にspell型チェック |
| メッセージMarshalエラー | json.Marshal失敗時にslog.Error + フォールバックJSON返却 |
| 認証エラーJSON統一 | auth/middleware.goで`writeAuthError`ヘルパーによるJSON形式統一 |

### 10.2 防御的コーディング（"起きても死なない"方針）

バックエンドは「起きないはず」ではなく「起きても死なない」に寄せた設計。

| 対策 | 実装箇所 | 説明 |
|------|---------|------|
| ActivePlayerState() nilガード | session.go 全5箇所 + action.go MoveComplete/Summon | broadcastTurnStart, processReconnect, processAction、MoveComplete、Summon |
| Board長ゼロガード | session.go processTurnTimeout | `len(s.state.Board) > 0` チェックでゼロ除算防止 |
| Board範囲チェック | action.go Summon, state.go TransitionAfterLanding | `p.Position < 0 \|\| p.Position >= len(gs.Board)` |
| OwnerIndex境界チェック | state.go TransitionAfterLanding | `tile.OwnerIndex >= 0 && tile.OwnerIndex < len(gs.Players)` |
| TileIndex境界チェック | battle.go ResolveBattle | バトルタイル参照前に範囲確認 |
| プレイヤースロット境界チェック | battle.go ResolveBattle, getAttackerCard | AttackerSlot/DefenderSlotの境界確認 |
| Reconnectスロット境界チェック | session.go processReconnect | 無効なスロットで即return（Players配列外アクセス防止） |
| EndTurn最大ターン勝者検索 | action.go EndTurn | `FinalRank==1`のSlotIndexを返す（rank番号ではなくslot番号） |
| Room終了ガード | room.go handleDisconnectTimeout + HandleReconnect | `RoomFinished`チェックで二重処理・終了後再接続防止 |
| タイマークリーンアップ | room.go Leave | 部屋が空になった時に全タイマーStop |
| TX失敗エラー伝達 | game/result.go ProcessRankedResult | 戻り値にerror追加、DB更新失敗を呼び出し元に通知 |

### 10.3 本番環境で必要な対策（未実装）

| 対策 | 説明 |
|------|------|
| JWT_SECRET強度 | 256bit以上のランダム値 |
| WSS (TLS) | Let's Encrypt等によるTLS終端 |
| CORS設定 | 本番ドメインのみ許可 |
| REST Rate Limiting | 認証エンドポイントに対する制限 |
| operation_logs活用 | チート検知ロジック |

---

## 11. 設定（環境変数）

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `PORT` | 8080 | リッスンポート |
| `DB_HOST` | localhost | PostgreSQLホスト |
| `DB_PORT` | 5432 | PostgreSQLポート |
| `DB_USER` | (現ユーザー) | DB接続ユーザー |
| `DB_NAME` | arcana_conquest | DB名 |
| `DB_PASS` | (空) | DBパスワード |
| `DATA_DIR` | ../data | マスタデータディレクトリ |
| `JWT_SECRET` | dev-secret-... | JWT署名鍵 |

---

## 12. データフロー図

### 12.1 ゲームアクション（例: summon）

```
Client
  │ {"type":"summon","data":{"card_id":101}}
  ▼
WebSocket (ReadPump)
  │ ParseMessage
  ▼
Hub.HandleMessage
  │ default case (game action)
  ▼
Room.HandleGameAction
  │ slotIndex特定、Session参照取得
  ▼
Session.HandleAction           ← ここまで呼び出し元goroutine
  │ commands <- command{...}   ← channel送信（ノンブロッキング）
  ▼
Session.run() goroutine        ← ここからSession goroutine
  │ case cmd := <-s.commands
  ▼
processAction("summon")
  │
  ├── json.Unmarshal → エラーなら即return
  ├── ValidateActivePlayer → 手番チェック
  ├── ValidatePhase(PhaseTileAction) → フェーズチ��ック
  ├── hasCard → 手札チェック
  │
  ├── RemoveFromHand → StateVersion++
  ├── タイル更新（owner, creature, HP, level, down）
  ├── TransitionTo(PhaseEndTurn) → StateVersion++
  │
  └── broadcastAction → 全クライアントに結果送信
        │ state_version: 最新値を埋め込み
        ▼
      Room.broadcastFn
        │
        ▼
      各Client.Send → send channel → WritePump → WebSocket
```

### 12.2 ターン全体フロー

```
turn_start (broadcast) + your_hand (個別送信)
  │
  ├── [spell_cast] or [spell_pass] or [pass]
  │     → TransitionTo(PhaseDice)
  │
  ├── [自動] DiceRoll
  │     → dice_result (broadcast)
  │     → TransitionTo(PhaseMove)
  │
  ├── [move_complete]
  │     → 位置更新
  │     → TransitionAfterLanding
  │       ├── 敵タイル → TransitionTo(PhaseBattle)
  │       └── 空/味方 → TransitionTo(PhaseTileAction)
  │
  ├── [summon] or [dominio_action] or [pass]
  │     → TransitionTo(PhaseEndTurn)
  │
  └── [end_turn]
        → ダウン解除
        → 勝利チェック → game_over?
        → 最大ターンチェック → game_over?
        → 次プレイヤー → DrawCard
        → turn_start (次ターン開始)
```

---

## 13. 未実装・将来対応

| 項目 | 優先度 | 説明 |
|------|--------|------|
| バトルハンドラ統合 | 高 | session.goにbattleアクションのハンドリング追加 |
| スペル効果処理 | 高 | SpellCast内でマスタデータに基づく効果適用 |
| マップデータ | 中 | 固定20タイルから動的マップ生成へ |
| cloud_saves | 中 | セーブデータのクラウド同期 |
| operation_logs書込 | 中 | アクションごとの操作ログ記録 |
| match_history書込 | 中 | ゲーム終了時の対戦履歴保存 |
| AI引き継ぎ | 低 | friend戦切断時のCPU代打 |
| フレンドシステム | 低 | friends テーブル活用 |
| 管理画面API | 低 | ユーザー管理・統計閲覧 |
| GDScript側ネットワーク実装 | 高 | クライアント側WebSocket + REST統合 |
