# プレイヤーデータ & アカウント設計書

## 1. データ分類の原則

プレイヤーデータを **性質** で3つに分類する。
全部を最初からサーバー管理する必要はない。コアだけ最優先。

| 分類 | 特徴 | 保存先 | 優先度 |
|------|------|--------|--------|
| **コア** | 失ったら復元不可。チート対策必須 | サーバー（登録後） | 最優先 |
| **サブ** | なくても復元可能 or 多少ズレてもOK | サーバー（後回しOK） | 後回し |
| **ローカル** | 端末固有。アカウントと無関係 | ローカルのみ | 同期不要 |

---

## 2. コアデータ（最優先・サーバー保存対象）

失ったらゲームが壊れるデータ。サーバー保存 + チート対策の対象。

### 2-1. アイデンティティ

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| user_id | String | GameData ("player1"固定) | 一意識別子 → UUID自動生成に変更 |
| name | String | GameData.profile.name | 表示名 |
| level | int | GameData.profile.level | プレイヤーレベル |
| exp | int | GameData.profile.exp | 経験値 |

### 2-2. 通貨

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| gold | int | GameData.profile.gold | ゲーム内通貨（ガチャ・ショップ） |
| stone | int | GameData.profile.stone | 課金石 |

### 2-3. カード所持

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| card_id | int | UserCardDB (SQLite) | カードID |
| count | int | UserCardDB | 所持枚数 |
| level | int | UserCardDB | カードレベル |
| obtained | int | UserCardDB | 図鑑フラグ（0/1） |

### 2-4. デッキ

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| decks | Array | GameData.decks | デッキ構成（最大6個） |
| max_decks | int | GameData.max_decks | デッキ上限 |

### 2-5. クエスト進行

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| current_stage | int | GameData.story_progress | 現在挑戦中のステージ |
| cleared_stages | Array | GameData.story_progress | クリア済みステージID |
| stage_stars | Dictionary | GameData.story_progress | ステージ別星数(1-3) |
| stage_records | Dictionary | StageRecordManager | クリア記録（ベストランク・ターン数） |

### 2-6. アンロック

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| stages | Array | GameData.unlocks.stages | アンロック済みステージ |
| modes | Array | GameData.unlocks.modes | アンロック済みモード |

### 2-7. インベントリ

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| inventory | Dictionary | GameData.inventory | アイテム所持数 {item_id: count} |

### 2-8. ネット対戦（未実装）

| データ | 型 | 説明 |
|--------|-----|------|
| rating | int | レーティング（初期値1500） |
| rank_tier | String | ランク帯 |

### 2-9. コスメ所持（未実装）

| データ | 型 | 説明 |
|--------|-----|------|
| owned_cosmetics | Array | 所持スキン・カスタマイズアイテムID |
| equipped | Dictionary | 装備中のスキン（サイコロ、カード裏面等） |

---

## 3. サブデータ（後回しOK）

なくても復元できる、または多少ズレても致命的でないデータ。
最初はローカル保存で十分。サーバー同期は後のフェーズで。

### 3-1. 統計

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| total_battles | int | GameData.stats | バトル総数 |
| wins / losses | int | GameData.stats | 勝敗数 |
| play_time_seconds | int | GameData.stats | 総プレイ時間 |
| story_cleared | int | GameData.stats | クリアしたストーリー数 |
| gacha_count | int | GameData.stats | ガチャを引いた回数 |
| cards_obtained | int | GameData.stats | 入手したカード総数 |

### 3-2. スタミナ

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| current | int | GameData.stamina | 現在スタミナ |
| max | int | GameData.stamina | 最大スタミナ |
| updated_at | String | GameData.stamina | 最終更新時刻 |

※ チート対策するならコアに昇格。ただし最初はローカルで十分。

### 3-3. ログインボーナス

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| login_streak | int | GameData.login_bonus | 連続ログイン日数 |
| total_login_days | int | GameData.login_bonus | 累計ログイン日数 |
| last_daily_date | String | GameData.login_bonus | 最終受取日 |
| claimed_campaigns | Array | GameData.login_bonus | 受取済みキャンペーンID |

### 3-4. 対戦履歴（未実装）

| データ | 型 | 説明 |
|--------|-----|------|
| match_history | Array | 直近の対戦履歴 |

### 3-5. ソーシャル（未実装）

| データ | 型 | 説明 |
|--------|-----|------|
| friend_ids | Array | フレンドリスト |
| blocked_ids | Array | ブロックリスト |

---

## 4. ローカルデータ（同期不要）

端末固有の設定。アカウントに紐づけない。

| データ | 型 | 現在の実装 | 説明 |
|--------|-----|-----------|------|
| master_volume | float | GameData.settings | マスター音量 |
| bgm_volume | float | GameData.settings | BGM音量 |
| se_volume | float | GameData.settings | SE音量 |
| language | String | GameData.settings | 言語 |
| auto_save | bool | GameData.settings | 自動セーブ |
| device_id | String | 未実装 | 端末識別用UUID |

---

## 5. 最終データ構造（JSON表現）

GameDataの `player_data` をこの構造に整理する目標形。

```json
{
  "core": {
    "identity": {
      "user_id": "uuid-xxxx-xxxx",
      "name": "プレイヤー",
      "level": 1,
      "exp": 0
    },
    "currency": {
      "gold": 100000,
      "stone": 0
    },
    "decks": [],
    "max_decks": 6,
    "progression": {
      "current_stage": 1,
      "cleared_stages": [],
      "stage_stars": {},
      "stage_records": {}
    },
    "unlocks": {
      "stages": [1],
      "modes": ["story"]
    },
    "inventory": {},
    "pvp": {
      "rating": 1500,
      "rank_tier": "bronze"
    },
    "cosmetics": {
      "owned": [],
      "equipped": {
        "dice_skin": "default",
        "card_back": "default",
        "player_icon": "default",
        "title": ""
      }
    }
  },
  "sub": {
    "stats": {
      "total_battles": 0,
      "wins": 0,
      "losses": 0,
      "play_time_seconds": 0,
      "story_cleared": 0,
      "gacha_count": 0,
      "cards_obtained": 0
    },
    "stamina": {
      "current": 50,
      "max": 50,
      "updated_at": ""
    },
    "login_bonus": {
      "login_streak": 0,
      "total_login_days": 0,
      "last_daily_date": "",
      "claimed_campaigns": []
    }
  },
  "local": {
    "settings": {
      "master_volume": 1.0,
      "bgm_volume": 0.8,
      "se_volume": 1.0,
      "language": "ja",
      "auto_save": true
    },
    "device_id": ""
  }
}
```

※ カード所持（collection）は別管理（UserCardDB）のためこのJSONには含めない。
　 将来サーバー同期時はAPIで個別に送受信する。

---

## 6. 現在の構成と課題

### 現在の保存構成

```
GameData (Autoload)
├── player_save.json    ← core + sub + local が混在
└── UserCardDB (Autoload)
    ├── user_cards.db   ← カード所持（SQLite / ネイティブ）
    └── user_cards.json ← カード所持（JSON / Web版）
```

### 課題

| 課題 | 影響 | 対策 |
|------|------|------|
| user_id が "player1" 固定 | サーバー連携不可 | UUID自動生成に変更 |
| 通貨がローカルのみ | JSON編集でチート可能 | サーバー保存（アカウント登録後） |
| core/sub/local が1ファイル混在 | 同期範囲が曖昧 | 構造を分離（上記JSON構造） |
| カードDBとGameDataが分離 | 2箇所の同期が必要 | APIで統一的に送受信 |

---

---
---

# アカウント認証設計

## 7. 認証フロー

### 7-1. 全体の流れ

```
初回起動
  │
  ▼
端末UUIDを生成してローカル保存
  │
  ▼
ゲスト状態で全機能プレイ可能
（データはローカルのみ）
  │
  ├── そのまま遊ぶ ← 大半のユーザー
  │
  └── アカウント登録（任意）
        │
        ▼
      メアド + パスワード入力
        │
        ▼
      サーバーにゲストアカウント作成 or 既存に紐づけ
        │
        ▼
      ローカルのコアデータをサーバーにアップロード
        │
        ▼
      以降はサーバーが正、ローカルはキャッシュ
```

### 7-2. 各シナリオ

#### ゲスト（未登録）

```
起動 → device_id で自動識別
     → データはローカル保存のみ
     → アプリ削除でデータ消失
```

#### アカウント登録

```
設定画面 → 「アカウント登録」ボタン
         → メアド + パスワード入力
         → サーバーに送信
         → users テーブルにレコード作成
         → ローカルのコアデータをアップロード
         → トークン返却 → ローカルに保存
```

#### ログイン（別端末）

```
起動 → ローカルにトークンなし
     → 「ログイン」ボタン
     → メアド + パスワード入力
     → サーバー認証 → トークン返却
     → サーバーからコアデータをダウンロード
     → ローカルに展開してプレイ開始
```

#### 自動ログイン（同端末・次回起動）

```
起動 → ローカルにトークンあり
     → トークンでサーバーに自動認証
     → 成功 → そのままプレイ
     → 失敗（期限切れ等） → ログイン画面へ
```

---

## 8. サーバー側DB設計

### 8-1. テーブル一覧

```
users              ← 認証情報
player_profiles    ← プロフィール・通貨・レベル
quest_progress     ← クエスト進行
decks              ← デッキ構成
user_cards         ← カード所持（UserCardDBのサーバー版）
user_cosmetics     ← コスメ所持・装備
match_history      ← 対戦履歴
```

### 8-2. テーブル定義

#### users（認証）

```sql
CREATE TABLE users (
  id                   TEXT PRIMARY KEY,        -- UUID
  device_id            TEXT,                    -- 端末ID（ゲスト識別専用、認証には使わない）
  email                TEXT UNIQUE,             -- NULL = ゲスト
  password_hash        TEXT,                    -- bcrypt
  active_refresh_token TEXT,                    -- 有効なrefresh_token（1端末制限用）
  refresh_token_expires DATETIME,              -- refresh_token有効期限
  token_issued_at      DATETIME,               -- refresh_token発行日時
  status               TEXT DEFAULT 'active',   -- active / banned / deleted
  created_at           DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_login_at        DATETIME
);
```

#### player_profiles（コアデータ）

```sql
CREATE TABLE player_profiles (
  user_id       TEXT PRIMARY KEY REFERENCES users(id),
  name          TEXT NOT NULL DEFAULT 'ゲスト',
  level         INTEGER DEFAULT 1,
  exp           INTEGER DEFAULT 0,
  gold          INTEGER DEFAULT 100000,
  stone         INTEGER DEFAULT 0,
  rating        INTEGER DEFAULT 1500,
  rank_tier     TEXT DEFAULT 'bronze',
  version       INTEGER DEFAULT 1,               -- 楽観ロック用
  updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### quest_progress（クエスト進行）

```sql
CREATE TABLE quest_progress (
  user_id        TEXT PRIMARY KEY REFERENCES users(id),
  current_stage  INTEGER DEFAULT 1,
  cleared_stages TEXT DEFAULT '[]',       -- JSON配列
  stage_stars    TEXT DEFAULT '{}',        -- JSON辞書
  stage_records  TEXT DEFAULT '{}',        -- JSON辞書
  unlocked_stages TEXT DEFAULT '[1]',      -- JSON配列
  unlocked_modes  TEXT DEFAULT '["story"]',-- JSON配列
  version        INTEGER DEFAULT 1,
  updated_at     DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### decks（デッキ構成）

```sql
CREATE TABLE decks (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id   TEXT NOT NULL REFERENCES users(id),
  slot      INTEGER NOT NULL,            -- 0-5
  name      TEXT DEFAULT '',
  cards     TEXT NOT NULL DEFAULT '[]',  -- JSON配列 [card_id, ...]
  UNIQUE(user_id, slot)
);
```

#### user_cards（カード所持）

```sql
CREATE TABLE user_cards (
  user_id   TEXT NOT NULL REFERENCES users(id),
  card_id   INTEGER NOT NULL,
  count     INTEGER DEFAULT 0,
  level     INTEGER DEFAULT 1,
  obtained  INTEGER DEFAULT 0,           -- 図鑑フラグ
  PRIMARY KEY (user_id, card_id)
);
```

#### user_cosmetics（コスメ）

```sql
CREATE TABLE user_cosmetics (
  user_id       TEXT PRIMARY KEY REFERENCES users(id),
  owned_items   TEXT DEFAULT '[]',        -- JSON配列
  equipped_dice TEXT DEFAULT 'default',
  equipped_card_back TEXT DEFAULT 'default',
  equipped_icon TEXT DEFAULT 'default',
  equipped_title TEXT DEFAULT ''
);
```

#### match_history（対戦履歴）

```sql
CREATE TABLE match_history (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  winner_id   TEXT REFERENCES users(id),
  loser_id    TEXT REFERENCES users(id),
  winner_rating_change INTEGER,
  loser_rating_change  INTEGER,
  turns       INTEGER,
  duration    INTEGER,                    -- 秒
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);
-- 肥大化対策: ユーザーあたり最新100件のみ保持
-- 古いレコードは定期バッチで削除 or アーカイブテーブルに移動
-- クライアントへの返却はページング（20件ずつ）
```

---

## 9. API設計

### 9-1. 認証API

| メソッド | エンドポイント | 説明 |
|---------|---------------|------|
| POST | `/api/auth/register` | アカウント登録（メアド+パスワード） |
| POST | `/api/auth/login` | ログイン → トークン返却 |
| POST | `/api/auth/guest` | ゲスト登録（device_id） |
| POST | `/api/auth/verify` | トークン検証（自動ログイン用） |
| POST | `/api/auth/refresh` | access_token再発行（refresh_token使用） |
| POST | `/api/auth/logout` | ログアウト（トークン無効化） |

#### POST /api/auth/register

```json
// リクエスト
{
  "email": "user@example.com",
  "password": "xxxx",
  "device_id": "uuid-device-xxxx",
  "local_data": { ... }    // ゲスト時のローカルデータ（初回アップロード）
}

// レスポンス
{
  "status": "ok",
  "user_id": "uuid-xxxx",
  "access_token": "jwt-access-xxxx",
  "refresh_token": "jwt-refresh-xxxx",
  "access_expires_in": 1800,
  "refresh_expires_at": "2026-04-08T00:00:00Z"
}
```

#### POST /api/auth/login

```json
// リクエスト
{ "email": "user@example.com", "password": "xxxx" }

// レスポンス
{
  "status": "ok",
  "user_id": "uuid-xxxx",
  "access_token": "jwt-access-xxxx",
  "refresh_token": "jwt-refresh-xxxx",
  "access_expires_in": 1800,
  "player_data": { ... }   // コアデータ全部
}
```

### 9-2. データ同期API

| メソッド | エンドポイント | 説明 |
|---------|---------------|------|
| GET | `/api/player/profile` | プロフィール取得 |
| PUT | `/api/player/profile` | プロフィール更新 |
| GET | `/api/player/data` | コアデータ一括取得 |
| PUT | `/api/player/data` | コアデータ一括保存 |
| GET | `/api/player/cards` | カード所持取得 |
| PUT | `/api/player/cards` | カード所持更新 |
| GET | `/api/player/decks` | デッキ取得 |
| PUT | `/api/player/decks/:slot` | デッキ更新 |

### 9-3. 同期方針

**原則: まとめて保存 + 重要操作だけ個別API**

通信量・競合・バグを減らすため、基本は一括同期。
通貨が絡む操作だけサーバー側で計算・検証する個別API。

#### 個別API（サーバー側で処理）

| タイミング | API | 理由 |
|-----------|-----|------|
| ガチャ実行 | POST `/api/gacha/pull` | 通貨消費 + カード付与をサーバーで計算 |
| 対戦終了 | POST `/api/match/result` | レーティング計算はサーバー |
| 課金購入 | POST `/api/shop/purchase` | 課金石操作はサーバー必須 |

#### 一括同期（まとめて保存）

| タイミング | 同期内容 | 方向 |
|-----------|---------|------|
| ログイン時 | コアデータ全部 | サーバー → クライアント |
| クエストクリア時 | 全コアデータ一括 | クライアント → サーバー |
| デッキ編集時 | 全コアデータ一括 | クライアント → サーバー |
| アプリ終了時 | 全コアデータ一括 | クライアント → サーバー |

#### 楽観ロック

```
クライアント → PUT /api/player/data  { "version": 5, "data": {...} }
サーバー     → version == DB の version ?
               YES → 保存、version = 6 を返却
               NO  → 409 Conflict、最新データを返却
クライアント → 最新データで上書き（1端末なので基本競合しない）
```

---

## 10. クライアント側の実装方針

### 10-1. 新規ファイル（予定）

| ファイル | 役割 |
|----------|------|
| `scripts/network/auth_manager.gd` | 認証処理（登録・ログイン・トークン管理） |
| `scripts/network/data_sync_manager.gd` | データ同期（アップロード・ダウンロード） |
| `scenes/ui/LoginScreen.tscn` | ログイン / 登録画面 |

### 10-2. GameData の変更

```
現在: GameData → player_save.json に直接読み書き

将来: GameData → AuthManager.is_registered?
        ├── YES → DataSyncManager経由でサーバーに保存
        │         ローカルはキャッシュとして併用
        └── NO  → 従来通りローカルJSONに保存
```

### 10-3. トークン管理

```
ローカル保存: user://auth_token.json
{
  "user_id": "uuid-xxxx",
  "refresh_token": "jwt-refresh-xxxx",
  "refresh_expires_at": "2026-04-08T00:00:00Z",
  "is_guest": false
}
※ access_tokenはメモリ上のみ（揮発）、refresh_tokenで都度再発行
```

---

## 11. セキュリティ

| 対策 | 内容 |
|------|------|
| パスワード | bcrypt でハッシュ化（サーバー側） |
| 通信 | HTTPS（WSS for WebSocket） |
| トークン | JWT デュアルトークン方式（下記参照） |
| 通貨操作 | サーバー側で計算・検証（クライアントは結果を受け取るだけ） |
| レート制限 | API呼び出し回数制限（DDoS防止） |
| 同時ログイン | 1端末のみ（下記参照） |
| device_id | 識別専用（下記参照） |

### 11-1. JWT デュアルトークン

```
access_token  : 短寿命（15〜60分）、API認証に使用
refresh_token : 長寿命（数日〜数週間）、access_token再発行に使用

フロー:
1. ログイン → access_token + refresh_token を返却
2. API呼び出し → access_token をヘッダに付与
3. access_token期限切れ → refresh_tokenで再発行
4. refresh_token期限切れ → 再ログイン必要
```

| トークン | 有効期限 | 保存場所 | 用途 |
|---------|---------|---------|------|
| access_token | 30分 | メモリ（揮発） | API認証ヘッダ |
| refresh_token | 14日 | user://auth_token.json | access_token再発行 |

#### 再発行API

```
POST /api/auth/refresh
{ "refresh_token": "xxxx" }
→ { "access_token": "new-xxxx", "expires_in": 1800 }
```

### 11-2. ログイン時のトークン発行フロー

```
1. メアド+パスワード検証（またはゲスト: device_id検証）
2. 既存の active_refresh_token を無効化（DBから削除/上書き）
3. 新しい refresh_token を生成
4. usersテーブルに保存:
   - active_refresh_token = 新token
   - refresh_token_expires = now + 14日
   - token_issued_at = now
   - last_login_at = now
5. access_token + refresh_token をクライアントに返却
```

→ ステップ2で古いトークンが消えるため、**1端末制限が自動的に成立**

### 11-3. APIリクエスト検証フロー

```
クライアント → Authorization: Bearer <access_token>

サーバー側の検証手順:
1. access_tokenのJWT署名を検証
2. 有効期限を確認（exp claim）
3. トークンからuser_idを取得
4. （必要に応じて）DBのactive_refresh_tokenと照合
5. OK → リクエスト処理  /  NG → 401返却
```

### 11-4. 不正状態とエラーハンドリング

| ケース | サーバー応答 | クライアント動作 |
|--------|------------|----------------|
| access_token期限切れ | 401 | refresh_tokenで再発行を試みる |
| refresh_token期限切れ | 401 | ログイン画面へ遷移 |
| 別端末でログインされた | 401（tokenがDBと不一致） | 「別の端末でログインされました」トースト → 自動ログアウト |
| token改ざん | 401（JWT署名不正） | ログイン画面へ遷移 |
| アカウントBAN | 403 | 「アカウントが停止されています」表示 |

#### クライアント側の401ハンドリング

```
APIレスポンス 401 の場合:
1. refresh_tokenで POST /api/auth/refresh を試行
2. 成功 → 新access_tokenでリクエストを再実行
3. 失敗（refresh_tokenも無効） →
   - ローカルのトークン情報を削除
   - 「別の端末でログインされました」トースト表示
   - 3秒後にログイン画面へ自動遷移
```

### 11-5. 同時ログインポリシー

**1端末のみ同時ログイン可能**

```
端末A でログイン中 → 端末B でログイン
→ サーバー: 11-2のフローで端末Aのrefresh_tokenが上書き・無効化
→ 端末A: 次回API呼び出し時に 401 → トースト表示 → ログイン画面
→ 端末B: 正常にプレイ続行
```

### 11-6. device_id の利用ルール

**device_idは識別専用であり、認証には使用しない**

| 用途 | OK / NG |
|------|---------|
| ゲストアカウントの自動作成・紐づけ | OK |
| アカウント登録時にゲストデータと紐づけ | OK |
| device_idだけでログイン | NG（なりすまし可能） |
| device_idをパスワード代わりにする | NG |

```
device_id の役割:
- 初回起動時にランダムUUIDを生成 → ローカルに永続保存
- ゲスト識別: 同じdevice_idなら同じゲストとみなす
- アカウント登録時: ゲストのdevice_idと登録ユーザーを紐づけ
- ログイン後: device_idは利用しない（JWTトークンで認証）
```

### 11-7. 将来拡張

現在のトークンベース設計で、以下の拡張が後から追加可能:

| 拡張 | 実現方法 |
|------|---------|
| 複数端末許可 | active_refresh_tokenを配列化（別テーブル） |
| セッション一覧表示 | token発行履歴テーブル追加 |
| 特定端末の強制ログアウト | 管理画面からtoken削除 |
| ログイン通知 | token発行時にプッシュ通知送信 |

---

## 12. キャラクター選択・カスタマイズ設計

### 12-1. 概要

プレイヤーが対戦・クエストで使用するキャラクター（3Dモデル）を選択できる仕組み。
初期状態では1体のみ使用可能。クエストクリアやショップ購入で解放される。

カスタマイズ（サイコロUI・カード裏面・称号等）は将来拡張。基盤だけ用意する。

### 12-2. キャラクター解放条件

| 解放方法 | 説明 | unlock_type |
|---------|------|-------------|
| 初期解放 | 全ユーザーが最初から使用可能 | `default` |
| クエストクリア | 特定ステージをクリアすると解放 | `quest_clear` |
| ショップ購入 | ゴールドまたは課金石で購入 | `purchase` |

### 12-3. キャラクターマスターデータ

`data/master/characters/characters.json` を拡張。
既存の敵キャラデータに `playable` フラグと解放条件を追加する。

```json
{
  "playable_characters": {
    "hero": {
      "name": "ヒーロー",
      "model_path": "res://scenes/Characters/Hero.tscn",
      "portrait_path": "res://assets/images/characters/hero.png",
      "description": "冒険の主人公",
      "unlock": { "type": "default" }
    },
    "necromancer": {
      "name": "マリオン",
      "model_path": "res://scenes/Characters/Necromancer.tscn",
      "portrait_path": "res://assets/images/characters/marion.png",
      "description": "闇の魔術師",
      "unlock": { "type": "quest_clear", "stage_id": "stage_1_8" }
    },
    "goblin": {
      "name": "ゴブリン",
      "model_path": "res://scenes/Characters/Goblin.tscn",
      "portrait_path": "",
      "description": "ワールド1のボス",
      "unlock": { "type": "quest_clear", "stage_id": "stage_1_8" }
    },
    "fighter": {
      "name": "ファイター",
      "model_path": "res://scenes/Characters/Fighter.tscn",
      "portrait_path": "",
      "description": "剣の達人",
      "unlock": { "type": "purchase", "price": 5000, "currency": "gold" }
    }
  }
}
```

※ 全16モデルを順次登録。上記は代表例。

### 12-4. ローカルデータ（GameData）

```gdscript
# GameData.player_data に追加
"character": {
    "selected_id": "hero",                # 現在選択中のキャラクターID
    "unlocked": ["hero"]                  # 解放済みキャラクターIDリスト
}
```

- **selected_id**: Core（サーバー同期対象）
- **unlocked**: Core（サーバー同期対象、チート防止）

### 12-5. サーバー側（既存設計との統合）

`backend_design.md` の `user_unlocked_characters` テーブルをそのまま使用。

```sql
-- backend_design.md で定義済み
CREATE TABLE user_unlocked_characters (
    id            SERIAL PRIMARY KEY,
    user_id       INTEGER REFERENCES users(id),
    character_id  TEXT NOT NULL,
    unlock_type   TEXT NOT NULL,       -- default / quest_clear / purchase
    unlocked_at   TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, character_id)
);
```

`player_profiles` テーブルに選択中キャラを追加:

```sql
ALTER TABLE player_profiles ADD COLUMN selected_character TEXT DEFAULT 'hero';
```

### 12-6. 解放フロー

#### クエストクリア時

```
クエストクリア → stage_idを確認
→ playable_characters内にそのstage_idで解放されるキャラがあるか
→ あれば GameData.player_data.character.unlocked に追加
→ 「新キャラクター解放!」演出表示
→ サーバー同期（登録済みユーザーのみ）
```

#### ショップ購入時

```
キャラクターショップ → 購入ボタン
→ ゴールドまたは石を消費
→ unlocked に追加
→ サーバー同期
```

### 12-7. キャラクター選択フロー

```
メインメニュー or デッキ編集画面 → 「キャラクター」ボタン
→ キャラクター一覧表示
   ├── 解放済み: 選択可能（3Dモデルプレビュー）
   └── 未解放: グレーアウト + 解放条件表示
→ キャラクター選択 → selected_id を更新
→ 対戦・クエスト開始時に selected_id のモデルを読み込み
```

### 12-8. quest_game.gd の変更方針

現在ハードコードされている `Hero.tscn` を、GameDataの選択キャラに差し替える。

```
現在: var mario_scene = load("res://scenes/Characters/Hero.tscn")

将来: var char_id = GameData.player_data.character.selected_id
      var char_data = characters_master.playable_characters[char_id]
      var player_scene = load(char_data.model_path)
```

### 12-9. カスタマイズ基盤（将来拡張）

初期実装では構造のみ。UIや購入機能は後回し。

```gdscript
# GameData.player_data に追加（将来）
"cosmetics": {
    "equipped_dice": "default",
    "equipped_card_back": "default",
    "equipped_icon": "default",
    "equipped_title": ""
}
```

対応するサーバーテーブル `user_cosmetics` は 8-2 で定義済み。

### 12-10. 利用可能な3Dモデル一覧（現在16体）

| ID | モデル | 備考 |
|----|-------|------|
| hero | Hero.tscn | 初期キャラ |
| necromancer | Necromancer.tscn | マリオン |
| goblin | Goblin.tscn | W1ボス |
| fighter | Fighter.tscn | |
| thief | Thief.tscn | |
| clown | Clown.tscn | |
| undead_monk | UndeadMonk.tscn | |
| old_sage | OldSage.tscn | |
| witch | Witch.tscn | |
| witch2 | Witch2.tscn | |
| elf | Elf.tscn | |
| dark_elf | DarkElf.tscn | |
| golem | Golem.tscn | |
| orc | Orc.tscn | |
| mario | Mario.tscn | 開発用 |
| bowser | Bowser.tscn | 開発用 |

---

## 13. 次のステップ

1. [x] プレイヤーデータ構造の定義
2. [x] アカウント認証設計
3. [x] キャラクター選択・カスタマイズ設計
4. [ ] サーバー実装（Go リレーサーバー + 認証API）
5. [ ] クライアント実装（AuthManager, DataSyncManager）
6. [ ] GameData リファクタ（core/sub/local 分離）
7. [ ] キャラクター選択UI実装
8. [ ] クエストクリア時のキャラ解放処理実装
