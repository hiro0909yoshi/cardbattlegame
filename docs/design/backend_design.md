# バックエンド設計書

## 概要

**方式**: 案B（Go リレーサーバー + 要所検証）に決定済み
**参照**: `docs/progress/roadmap.md`（決定事項メモ 2026-02-21）
**想定ユーザー規模**: 500-700人（VPS 2-3台で対応可能）

ゲームロジックはクライアント（Godot/GDScript）側で実行し、サーバーはメッセージ中継・データ保存・要所検証を担当する。

---

## アーキテクチャ

```
┌──────────────┐     WebSocket (WSS)     ┌──────────────────┐
│  Godot       │◄──────────────────────►│  Go リレーサーバー  │
│  クライアント  │     JSON メッセージ      │                  │
└──────────────┘                        │  - メッセージ中継   │
										│  - 要所検証        │
┌──────────────┐     WebSocket (WSS)     │  - REST API       │
│  Godot       │◄──────────────────────►│                  │
│  クライアント  │                        └────────┬─────────┘
└──────────────┘                                 │
												 │ SQL
┌──────────────┐     HTTPS (REST)                │
│  管理画面     │◄─────────────────┐      ┌───────▼─────────┐
│  (Web)       │                  │      │  PostgreSQL     │
└──────────────┘                  │      │  データベース     │
								  │      └─────────────────┘
						   ┌──────┴─────────┐
						   │  Go サーバー     │
						   │  (REST API)     │
						   └────────────────┘
```

### 通信方式

| 用途 | プロトコル | 方式 |
|------|-----------|------|
| 対戦中リアルタイム通信 | WebSocket (WSS) | JSON メッセージ |
| データ取得・更新 | HTTPS (REST API) | JSON リクエスト/レスポンス |
| プッシュ通知 | FCM (Firebase Cloud Messaging) | サーバーから配信 |

### ターン制の利点
- リアルタイム性の要求が低い（1秒程度の遅延は問題なし）
- WebSocket のメッセージ頻度が低い（1ターンに数メッセージ）
- サーバー負荷が軽い

---

## サーバー構成

### VPS 選定候補

| サービス | 最安プラン | 特徴 |
|---------|-----------|------|
| さくらVPS | 月643円〜 | 国内、日本語サポート |
| ConoHa | 月296円〜 | 国内、時間課金あり |
| Vultr | 月$2.5〜 | 海外、安い |

### スケーリング目安

| ユーザー規模 | 構成 | 月額目安 |
|------------|------|---------|
| 〜300人 | VPS 1台（Go + DB） | 月500〜1,500円 |
| 〜700人 | VPS 2-3台（Go + DB分離） | 月1,500〜3,000円 |
| 1,000人超 | ロードバランサー + 複数Go | 月5,000円〜 |

---

## データベース設計

### DB 選定
- **PostgreSQL**（本番環境）
- 理由: JSON型サポート、フルテキスト検索、スケーラビリティ

### テーブル一覧

```sql
-- P6: ネット対戦
users              -- ユーザーアカウント（認証・TrueSkillレーティング含む）
player_stats       -- プレイヤー統計（総バトル数、勝率、プレイ時間等）
rooms              -- ルーム管理（一時データ、メモリ併用）
room_players       -- ルーム参加者（roomsの子テーブル）
match_history      -- 対戦履歴（2～4人対応）
match_players      -- 対戦参加者（match_historyの子テーブル）
decks              -- ユーザーデッキ（最大6スロット、課金で拡張可能）
user_cards         -- カード所持情報（card_id, count, level）
operation_logs     -- 操作ログ（チート検知用）

-- P6: 解放管理
user_unlocks       -- 統一解放管理（character/gacha/map/mode/world/feature）

-- P7: アカウント基盤
cloud_saves        -- セーブデータ（クラウド同期）
login_bonus        -- ログインボーナス状態

-- P8: ソーシャル
friends            -- フレンドリスト
rank_history       -- ランク変動履歴（シーズン管理）
seasons            -- シーズン定義
season_rewards     -- シーズン報酬
tournaments        -- 大会データ
tournament_entries -- 大会参加者
tournament_matches -- 大会対戦結果

-- P9: マネタイズ・運営
purchases          -- 課金履歴
announcements      -- お知らせ
user_announcement_reads -- お知らせ既読管理
mail               -- ユーザーメール（運営/フレンド）
missions           -- ミッション定義（デイリー/ウィークリー/恒常）
mission_progress   -- ミッション達成状況
push_tokens        -- プッシュ通知トークン
user_items         -- ユーザー所持アイテム（倉庫）
gacha_events       -- ガチャイベント定義
gacha_history      -- ガチャ履歴
gacha_pity_state   -- ガチャ天井カウンター
banned_users       -- BAN管理
fraud_alerts       -- 不正検知アラート

-- P9: SNS連携
sns_accounts       -- SNS連携アカウント（X / Instagram）
sns_daily_bonus    -- SNSデイリーボーナス受取履歴
```

### 主要テーブル定義

#### users（P6）
```sql
CREATE TABLE users (
	id            SERIAL PRIMARY KEY,
	user_id       TEXT UNIQUE NOT NULL,      -- 表示用ID (#12345)
	device_id     TEXT,                       -- 初回登録端末ID
	display_name  TEXT NOT NULL DEFAULT 'ゲスト',
	password_hash TEXT,                       -- ゲスト時はNULL
	auth_provider TEXT DEFAULT 'guest',       -- guest / apple / google
	auth_token    TEXT,                       -- OAuth トークン
	refresh_token TEXT,                       -- リフレッシュトークン
	token_expires_at TIMESTAMP,              -- トークン有効期限
	status        TEXT DEFAULT 'active',      -- active / banned / deleted
	transfer_code TEXT UNIQUE,               -- 引き継ぎコード（16桁）

	-- TrueSkill レーティング
	ts_mu         REAL DEFAULT 25.0,         -- 実力推定値（平均）
	ts_sigma      REAL DEFAULT 8.333,        -- 不確実性（μ/3）
	display_rate  REAL DEFAULT 0.0,          -- 表示レート = μ - 3σ（計算済みキャッシュ）
	rank_tier     TEXT DEFAULT 'bronze_1',   -- ランク段位（bronze_1 ～ diamond_3）

	-- ランクマッチ戦績
	ranked_wins   INTEGER DEFAULT 0,
	ranked_losses INTEGER DEFAULT 0,
	ranked_draws  INTEGER DEFAULT 0,

	-- プロフィール
	player_level  INTEGER DEFAULT 1,
	experience    INTEGER DEFAULT 0,
	gold          INTEGER DEFAULT 100000,    -- 初期ゴールド
	stone         INTEGER DEFAULT 0,         -- ジェム
	stamina       INTEGER DEFAULT 50,
	stamina_max   INTEGER DEFAULT 50,
	stamina_updated_at TIMESTAMPTZ,          -- スタミナ最終更新時刻
	title_id      TEXT,                      -- 装備中の称号ID
	favorite_card_id INTEGER,                -- お気に入りカード
	character_id  TEXT DEFAULT 'hero',        -- 使用キャラクターID

	-- デッキ・インベントリ
	max_decks     INTEGER DEFAULT 6,         -- デッキスロット上限（課金で拡張可能）
	inventory     JSONB DEFAULT '{}',        -- 倉庫アイテム {item_id: count}

	-- 設定
	settings      JSONB DEFAULT '{"master_volume":1.0,"bgm_volume":0.8,"se_volume":1.0,"language":"ja","auto_save":true,"lightweight_mode":false}',

	-- ログインボーナス
	login_streak      INTEGER DEFAULT 0,     -- 連続ログイン日数
	total_login_days  INTEGER DEFAULT 0,     -- 累計ログイン日数
	last_login_date   TEXT,                  -- 最終ログイン日（YYYY-MM-DD）
	last_daily_date   TEXT,                  -- 最終デイリーボーナス受取日
	claimed_campaigns JSONB DEFAULT '[]',    -- 受取済みキャンペーンID配列

	created_at    TIMESTAMPTZ DEFAULT NOW(),
	last_login_at TIMESTAMPTZ
);

-- 表示レートでのランキング検索用
CREATE INDEX idx_users_display_rate ON users(display_rate DESC);
-- デバイスID検索用
CREATE INDEX idx_users_device_id ON users(device_id);
-- 引き継ぎコード検索用
CREATE INDEX idx_users_transfer_code ON users(transfer_code) WHERE transfer_code IS NOT NULL;
```

**TrueSkill パラメータ定数**（サーバー側で保持）:

| パラメータ | 値 | 説明 |
|-----------|-----|------|
| 初期μ | 25.0 | 実力推定値（平均） |
| 初期σ | 8.333 | 不確実性（μ/3） |
| β | 4.167 | 実力幅（μ/6） |
| τ | 0.083 | 動的係数（σ/100） |
| draw_probability | 0.0 | 引き分け確率（このゲームでは0） |

**表示レート計算**: `display_rate = μ - 3σ`（初期値: 25.0 - 3×8.333 = 0.0）

**ランク段位マッピング**:

| rank_tier | 表示レート範囲 | 表示名 |
|-----------|--------------|--------|
| `bronze_1` ～ `bronze_3` | 0 ～ 9 | ブロンズ I～III |
| `silver_1` ～ `silver_3` | 10 ～ 19 | シルバー I～III |
| `gold_1` ～ `gold_3` | 20 ～ 29 | ゴールド I～III |
| `platinum_1` ～ `platinum_3` | 30 ～ 39 | プラチナ I～III |
| `diamond_1` ～ `diamond_3` | 40～ | ダイヤモンド I～III |

**レート更新タイミング**: 対戦結果報告時にサーバー側で計算し、`ts_mu`・`ts_sigma`・`display_rate`・`rank_tier` を同時更新

#### rooms（P6 — メモリ管理 + DB永続化オプション）

ルームは基本的にサーバーメモリ上で管理し、サーバー再起動時に消失しても問題ない一時データ。
必要に応じてDBに永続化（アクティブルーム一覧の表示用など）。

```sql
CREATE TABLE rooms (
	id            SERIAL PRIMARY KEY,
	room_id       TEXT UNIQUE NOT NULL,      -- 4桁数字（フレンド）or サーバー生成ID（ランク）
	host_user_id  INTEGER REFERENCES users(id),
	match_type    TEXT NOT NULL,              -- ranked / friendly
	status        TEXT DEFAULT 'waiting',     -- waiting / ready / in_game / finished
	max_players   INTEGER NOT NULL,           -- 2 / 3 / 4
	current_players INTEGER DEFAULT 1,
	map_id        TEXT,                       -- ホストが選択（フレンドマッチ）
	rule_preset   TEXT DEFAULT 'standard',
	initial_magic INTEGER DEFAULT 1000,
	target_magic  INTEGER DEFAULT 8000,
	max_turns     INTEGER DEFAULT 0,          -- 0=無制限
	created_at    TIMESTAMP DEFAULT NOW(),
	started_at    TIMESTAMP,                  -- ゲーム開始時刻
	finished_at   TIMESTAMP                   -- ゲーム終了時刻
);

-- アクティブルーム検索用
CREATE INDEX idx_rooms_status ON rooms(status) WHERE status IN ('waiting', 'ready');
-- ルームID重複チェック用（アクティブルームのみ）
CREATE UNIQUE INDEX idx_rooms_active_room_id ON rooms(room_id) WHERE status NOT IN ('finished');
```

#### room_players（P6 — rooms の子テーブル）
```sql
CREATE TABLE room_players (
	id          SERIAL PRIMARY KEY,
	room_id     INTEGER REFERENCES rooms(id) ON DELETE CASCADE,
	user_id     INTEGER REFERENCES users(id),
	slot_index  INTEGER NOT NULL,             -- 0～3（プレイヤースロット番号）
	deck_id     TEXT,                         -- 選択デッキID
	is_ready    BOOLEAN DEFAULT FALSE,
	joined_at   TIMESTAMP DEFAULT NOW(),
	UNIQUE(room_id, user_id),
	UNIQUE(room_id, slot_index)
);
```

#### match_history（P6 — 2～4人対応）
```sql
CREATE TABLE match_history (
	id          SERIAL PRIMARY KEY,
	match_type  TEXT NOT NULL,                -- ranked / friendly / tournament
	player_count INTEGER NOT NULL,            -- 2 / 3 / 4
	map_id      TEXT NOT NULL,
	rule_preset TEXT NOT NULL,
	initial_magic INTEGER,
	target_magic INTEGER,
	max_turns   INTEGER,
	total_turns INTEGER,                      -- 実際にかかったターン数
	duration    INTEGER,                      -- 対戦時間（秒）
	played_at   TIMESTAMP DEFAULT NOW()
);
```

#### match_players（P6 — match_history の子テーブル）
```sql
CREATE TABLE match_players (
	id          SERIAL PRIMARY KEY,
	match_id    INTEGER REFERENCES match_history(id) ON DELETE CASCADE,
	user_id     INTEGER REFERENCES users(id),
	final_rank  INTEGER NOT NULL,             -- 順位（1=優勝, 2=2位...）
	deck_id     TEXT,
	final_tep   INTEGER,                      -- 最終TEP
	-- 対戦詳細統計
	battle_count      INTEGER DEFAULT 0,      -- クリーチャーバトル回数
	spell_casts       INTEGER DEFAULT 0,      -- スペル使用回数
	creature_summons  INTEGER DEFAULT 0,      -- 召喚回数
	territories_at_end INTEGER DEFAULT 0,     -- 終了時領地数
	damage_dealt      INTEGER DEFAULT 0,      -- 与ダメージ合計
	damage_taken      INTEGER DEFAULT 0,      -- 被ダメージ合計
	-- TrueSkill 変動記録
	ts_mu_before    REAL,
	ts_mu_after     REAL,
	ts_sigma_before REAL,
	ts_sigma_after  REAL,
	rate_change     REAL,                     -- 表示レート変動（+/-）
	UNIQUE(match_id, user_id)
);

-- ユーザーの対戦履歴検索用
CREATE INDEX idx_match_players_user ON match_players(user_id, match_id DESC);
```

#### player_stats（P6 — プレイヤー統計）

game_data.gd の stats 構造をサーバー側に永続化。クラウド同期・ランキング・ミッション判定に使用。

```sql
CREATE TABLE player_stats (
	user_id             INTEGER PRIMARY KEY REFERENCES users(id),
	-- 全体統計
	total_battles       INTEGER DEFAULT 0,
	total_wins          INTEGER DEFAULT 0,
	total_losses        INTEGER DEFAULT 0,
	play_time_seconds   INTEGER DEFAULT 0,
	story_cleared       INTEGER DEFAULT 0,
	gacha_count         INTEGER DEFAULT 0,
	cards_obtained      INTEGER DEFAULT 0,
	total_gold_earned   INTEGER DEFAULT 0,
	-- クエスト統計
	quest_plays         INTEGER DEFAULT 0,
	quest_clears        INTEGER DEFAULT 0,
	quest_battles       INTEGER DEFAULT 0,
	quest_creature_summons INTEGER DEFAULT 0,
	quest_spell_uses    INTEGER DEFAULT 0,
	-- ネット対戦統計
	net_battle_plays    INTEGER DEFAULT 0,
	net_battle_wins     INTEGER DEFAULT 0,
	net_battle_battles  INTEGER DEFAULT 0,
	net_battle_creature_summons INTEGER DEFAULT 0,
	net_battle_spell_uses INTEGER DEFAULT 0,
	-- コレクション
	collection_complete JSONB DEFAULT '{}',   -- {"fire": true, "water": false, ...}
	updated_at          TIMESTAMP DEFAULT NOW()
);
```

#### decks（P6 — ユーザーデッキ）

```sql
CREATE TABLE decks (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
	slot_index  INTEGER NOT NULL,             -- 0～5（課金拡張で最大29）
	deck_name   TEXT NOT NULL DEFAULT 'デッキ',
	cards       JSONB NOT NULL DEFAULT '{}',  -- {"card_id": count, ...}
	created_at  TIMESTAMP DEFAULT NOW(),
	updated_at  TIMESTAMP,
	UNIQUE(user_id, slot_index)
);

CREATE TABLE user_deck_slots (
	user_id     INTEGER PRIMARY KEY REFERENCES users(id),
	max_slots   INTEGER DEFAULT 6             -- 課金で拡張可能
);
```

#### user_cards（P6 — カード所持情報）

```sql
CREATE TABLE user_cards (
	user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	card_id     INTEGER NOT NULL,
	count       INTEGER DEFAULT 0,            -- 所持枚数
	card_level  INTEGER DEFAULT 1,            -- カードレベル
	obtained    BOOLEAN DEFAULT FALSE,        -- 図鑑登録済み
	PRIMARY KEY(user_id, card_id)
);

CREATE INDEX idx_user_cards_user ON user_cards(user_id);
```

#### rank_history（P8 — ランク変動履歴）
```sql
CREATE TABLE rank_history (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id),
	season_id   INTEGER REFERENCES seasons(id),
	match_id    INTEGER REFERENCES match_history(id),
	ts_mu       REAL NOT NULL,
	ts_sigma    REAL NOT NULL,
	display_rate REAL NOT NULL,
	rank_tier   TEXT NOT NULL,
	recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_rank_history_user ON rank_history(user_id, recorded_at DESC);
```

#### user_unlocks（P6 — 統一解放管理）

`unlock_system_design.md` の解放キー形式（`category.item_id`）に準拠。
マップ・キャラクター・ガチャ・モード・ワールド・機能を一元管理。

```sql
CREATE TABLE user_unlocks (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
	unlock_key  TEXT NOT NULL,                -- "character.necromancer", "map.map_diamond_20", "gacha.s_gacha" 等
	unlock_type TEXT NOT NULL,                -- always / quest_clear / battle_count / win_count / card_count / purchase
	unlocked_at TIMESTAMP DEFAULT NOW(),
	UNIQUE(user_id, unlock_key)
);

CREATE INDEX idx_user_unlocks_user ON user_unlocks(user_id);
CREATE INDEX idx_user_unlocks_key ON user_unlocks(unlock_key);
```

**初期解放（全ユーザーに `unlock_type = 'always'` で付与）**:
- `character.necromancer`（ネクロマンサー / マリオン）
- `map.map_diamond_20`（ダイヤモンド20）
- `gacha.normal`（ノーマルガチャ）

**解放キー形式一覧**:

| カテゴリ | キー例 | 説明 |
|---------|--------|------|
| `character.{id}` | `character.necromancer` | プレイアブルキャラクター |
| `map.{id}` | `map.map_diamond_20` | 対戦マップ |
| `gacha.{type}` | `gacha.s_gacha` | ガチャ種別 |
| `mode.{name}` | `mode.solo_battle` | ゲームモード |
| `world.{id}` | `world.2` | クエストワールド |
| `feature.{name}` | `feature.album` | UI機能 |

#### 解放管理 API

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/users/me/unlocks` | GET | 解放済みキー一覧 |
| `/api/users/me/unlocks/{category}` | GET | カテゴリ別解放一覧（例: character） |
| `/api/unlocks` | POST | 解放処理（クエストクリア・購入時） |

#### quest_progress（P7 — クエスト進行状況）

```sql
CREATE TABLE quest_progress (
	user_id         INTEGER PRIMARY KEY REFERENCES users(id),
	current_stage   INTEGER DEFAULT 1,
	cleared_stages  JSONB DEFAULT '[]',       -- [1, 2, 3, ...]
	stage_stars     JSONB DEFAULT '{}',       -- {"1": 3, "2": 2, ...}
	stage_records   JSONB DEFAULT '{}',       -- {"1": {"rank": "S", "turns": 12}, ...}
	unlocked_stages JSONB DEFAULT '[1]',      -- [1, 2, 3, ...]
	version         INTEGER DEFAULT 1,        -- 楽観ロック用
	updated_at      TIMESTAMP DEFAULT NOW()
);
```

#### cloud_saves（P7 — クラウドセーブ）

プレイヤーデータ（player_save.json相当）のクラウド同期専用。
対戦中のクラッシュ復帰（game_state.json相当）はサーバー側GameStateから復元するため、ここには含めない。

| 保存対象 | 保存先 | 用途 |
|---------|--------|------|
| プロフィール、カード、デッキ、進行状況 | cloud_saves | アカウント同期・機種変更 |
| 対戦中の盤面状態（ターン、HP、EP等） | サーバーメモリ（GameState） | ネット対戦中のクラッシュ復帰 |

```sql
CREATE TABLE cloud_saves (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
	save_data   JSONB NOT NULL,               -- player_data（プロフィール・カード・デッキ・進行状況）
	save_version INTEGER DEFAULT 1,           -- 競合検知用バージョン
	file_hash   TEXT,                         -- 改ざん検知用ハッシュ
	device_id   TEXT,                         -- 保存元端末ID
	created_at  TIMESTAMP DEFAULT NOW(),
	updated_at  TIMESTAMP DEFAULT NOW()
);

-- 1ユーザー1セーブ（最新のみ保持）
CREATE UNIQUE INDEX idx_cloud_saves_user ON cloud_saves(user_id);
```

#### login_bonus（P7 — ログインボーナスキャンペーン受取履歴）

```sql
CREATE TABLE login_bonus_claims (
	id              SERIAL PRIMARY KEY,
	user_id         INTEGER REFERENCES users(id) ON DELETE CASCADE,
	campaign_id     TEXT NOT NULL,             -- キャンペーンID
	claim_date      DATE NOT NULL,            -- 受取日
	reward_type     TEXT NOT NULL,             -- gold / stone / item
	reward_value    INTEGER NOT NULL,
	claimed_at      TIMESTAMP DEFAULT NOW(),
	UNIQUE(user_id, campaign_id, claim_date)
);
```

#### mail（P9）
```sql
CREATE TABLE mail (
	id          SERIAL PRIMARY KEY,
	recipient_id INTEGER REFERENCES users(id),
	sender_id   INTEGER REFERENCES users(id), -- NULL = 運営メール
	mail_type   TEXT NOT NULL,                 -- system / reward / friend
	subject     TEXT NOT NULL,
	body        TEXT NOT NULL,
	attachment  JSONB,                         -- 添付報酬 {"gold": 100, "items": [...]}
	is_read     BOOLEAN DEFAULT FALSE,
	is_claimed  BOOLEAN DEFAULT FALSE,         -- 添付受け取り済み
	is_protected BOOLEAN DEFAULT FALSE,        -- 削除保護
	expires_at  TIMESTAMP,                     -- 自動削除日（30日後）
	created_at  TIMESTAMP DEFAULT NOW()
);
```

#### announcements（P9）
```sql
CREATE TABLE announcements (
	id          SERIAL PRIMARY KEY,
	category    TEXT NOT NULL,                 -- important / event / update / campaign
	title       TEXT NOT NULL,
	body        TEXT NOT NULL,
	image_url   TEXT,
	starts_at   TIMESTAMP DEFAULT NOW(),
	ends_at     TIMESTAMP,
	created_at  TIMESTAMP DEFAULT NOW()
);
```

#### missions（P9 — ミッション定義）

`mission_system.md` 準拠。デイリー/ウィークリー/恒常の3カテゴリ。

```sql
CREATE TABLE missions (
	id              TEXT PRIMARY KEY,             -- ミッションID（例: daily_quest_play_3）
	category        TEXT NOT NULL,                -- daily / weekly / permanent
	title           TEXT NOT NULL,
	description     TEXT NOT NULL,
	condition_type  TEXT NOT NULL,                -- quest_play / quest_clear / creature_battle / creature_summon / spell_use / gacha_pull / gold_earn / login
	condition_target INTEGER NOT NULL,            -- 目標値（例: 3回）
	reward_type     TEXT NOT NULL,                -- gold / stone
	reward_amount   INTEGER NOT NULL,
	is_active       BOOLEAN DEFAULT TRUE
);
```

#### mission_progress（P9 — ミッション達成状況）

```sql
CREATE TABLE mission_progress (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
	mission_id  TEXT NOT NULL REFERENCES missions(id),
	current     INTEGER DEFAULT 0,            -- 現在の達成数
	is_claimed  BOOLEAN DEFAULT FALSE,        -- 報酬受け取り済み
	-- デイリー/ウィークリー用リセット管理
	period_key  TEXT NOT NULL,                -- "2026-04-19"(daily) / "2026-W16"(weekly) / "permanent"
	UNIQUE(user_id, mission_id, period_key)
);

CREATE INDEX idx_mission_progress_user ON mission_progress(user_id, period_key);
```

**リセット時刻**: 04:00 JST（デイリー: 毎日、ウィークリー: 毎週月曜）

#### friends（P8）
```sql
CREATE TABLE friends (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id),
	friend_id   INTEGER REFERENCES users(id),
	status      TEXT NOT NULL,                 -- pending / accepted / blocked
	requested_at TIMESTAMP DEFAULT NOW(),
	accepted_at TIMESTAMP,
	UNIQUE(user_id, friend_id)
);
```

#### user_items（P9 — 倉庫）

`inventory_system.md` 準拠。スタミナ回復薬等の消費アイテム管理。

```sql
CREATE TABLE user_items (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
	item_type   TEXT NOT NULL,                 -- stamina_small / stamina_large 等
	quantity    INTEGER DEFAULT 0,
	UNIQUE(user_id, item_type)
);
```

#### purchases（P9 — 課金履歴）

```sql
CREATE TABLE purchases (
	id              SERIAL PRIMARY KEY,
	user_id         INTEGER REFERENCES users(id),
	product_id      TEXT NOT NULL,             -- stone_120 / stone_610 等
	stone_amount    INTEGER NOT NULL,          -- 付与ジェム数（ボーナス含む）
	currency        TEXT NOT NULL DEFAULT 'JPY',
	price           DECIMAL(10, 2) NOT NULL,   -- 価格
	status          TEXT DEFAULT 'pending',     -- pending / completed / failed / refunded
	platform        TEXT NOT NULL,             -- apple / google
	transaction_id  TEXT UNIQUE,               -- ストアのトランザクションID
	receipt_data    TEXT,                       -- レシートJSON（検証用）
	validated_at    TIMESTAMP,                 -- レシート検証完了時刻
	created_at      TIMESTAMP DEFAULT NOW(),
	completed_at    TIMESTAMP,
	refunded_at     TIMESTAMP
);

CREATE INDEX idx_purchases_user ON purchases(user_id, created_at DESC);
```

#### gacha_events（P9 — ガチャイベント定義）

```sql
CREATE TABLE gacha_events (
	id          SERIAL PRIMARY KEY,
	gacha_type  TEXT NOT NULL,                 -- normal / s_gacha / r_gacha / pickup
	name        TEXT NOT NULL,
	description TEXT,
	-- 排出率
	rates       JSONB NOT NULL,               -- {"C": 0.50, "N": 0.35, "S": 0.12, "R": 0.03}
	-- ピックアップ対象（pickup時のみ）
	pickup_cards JSONB,                        -- [{"card_id": 123, "rate_boost": 0.5}]
	-- 価格
	cost_single INTEGER NOT NULL,             -- 1回の価格
	cost_ten    INTEGER NOT NULL,             -- 10連の価格
	cost_currency TEXT DEFAULT 'gold',         -- gold / stone
	-- 期間
	starts_at   TIMESTAMP DEFAULT NOW(),
	ends_at     TIMESTAMP,                    -- NULLなら常設
	is_active   BOOLEAN DEFAULT TRUE,
	created_at  TIMESTAMP DEFAULT NOW()
);
```

#### gacha_history（P9 — ガチャ履歴）

```sql
CREATE TABLE gacha_history (
	id              SERIAL PRIMARY KEY,
	user_id         INTEGER REFERENCES users(id),
	gacha_event_id  INTEGER REFERENCES gacha_events(id),
	card_id         INTEGER NOT NULL,
	rarity          TEXT NOT NULL,             -- C / N / S / R
	is_ten_pull     BOOLEAN DEFAULT FALSE,     -- 10連の一部か
	pull_index      INTEGER,                   -- 10連中の何番目（0-9）
	pulled_at       TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_gacha_history_user ON gacha_history(user_id, pulled_at DESC);
```

#### gacha_pity_state（P9 — ガチャ天井カウンター）

```sql
CREATE TABLE gacha_pity_state (
	id              SERIAL PRIMARY KEY,
	user_id         INTEGER REFERENCES users(id) ON DELETE CASCADE,
	gacha_type      TEXT NOT NULL,             -- normal / s_gacha / r_gacha / pickup
	pity_count      INTEGER DEFAULT 0,         -- 天井までの累計回数
	last_high_rarity_at TIMESTAMP,            -- 最後にS以上を引いた時刻
	UNIQUE(user_id, gacha_type)
);
```

#### user_announcement_reads（P9 — お知らせ既読管理）

```sql
CREATE TABLE user_announcement_reads (
	id              SERIAL PRIMARY KEY,
	user_id         INTEGER REFERENCES users(id) ON DELETE CASCADE,
	announcement_id INTEGER REFERENCES announcements(id) ON DELETE CASCADE,
	read_at         TIMESTAMP DEFAULT NOW(),
	UNIQUE(user_id, announcement_id)
);
```

#### push_tokens（P9 — プッシュ通知トークン）

```sql
CREATE TABLE push_tokens (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id) ON DELETE CASCADE,
	token       TEXT UNIQUE NOT NULL,
	platform    TEXT NOT NULL,                 -- ios / android
	is_valid    BOOLEAN DEFAULT TRUE,
	created_at  TIMESTAMP DEFAULT NOW(),
	last_used_at TIMESTAMP
);
```

#### seasons（P8 — シーズン定義）

```sql
CREATE TABLE seasons (
	id              SERIAL PRIMARY KEY,
	season_number   INTEGER UNIQUE NOT NULL,
	name            TEXT NOT NULL,
	starts_at       TIMESTAMP NOT NULL,
	ends_at         TIMESTAMP NOT NULL,
	is_active       BOOLEAN DEFAULT FALSE
);
```

#### season_rewards（P8 — シーズン報酬）

```sql
CREATE TABLE season_rewards (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id),
	season_id   INTEGER REFERENCES seasons(id),
	rank_tier   TEXT NOT NULL,                 -- 最終ランク
	reward_type TEXT NOT NULL,                 -- gold / stone / title / item
	reward_value TEXT NOT NULL,
	claimed_at  TIMESTAMP,
	UNIQUE(user_id, season_id)
);
```

#### tournaments（P8）
```sql
CREATE TABLE tournaments (
	id          SERIAL PRIMARY KEY,
	name        TEXT NOT NULL,
	format      TEXT NOT NULL,                 -- league / tournament / league_to_tournament
	status      TEXT DEFAULT 'upcoming',       -- upcoming / active / finished
	map_id      TEXT NOT NULL,
	rule_preset TEXT NOT NULL,
	max_players INTEGER,
	starts_at   TIMESTAMP NOT NULL,
	ends_at     TIMESTAMP NOT NULL,
	created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tournament_entries (
	id            SERIAL PRIMARY KEY,
	tournament_id INTEGER REFERENCES tournaments(id),
	user_id       INTEGER REFERENCES users(id),
	group_name    TEXT,                         -- リーグのグループ名
	wins          INTEGER DEFAULT 0,
	losses        INTEGER DEFAULT 0,
	league_points INTEGER DEFAULT 0,           -- リーグポイント
	rating_change INTEGER DEFAULT 0,
	final_rank    INTEGER,
	UNIQUE(tournament_id, user_id)
);

CREATE TABLE tournament_matches (
	id              SERIAL PRIMARY KEY,
	tournament_id   INTEGER REFERENCES tournaments(id),
	match_id        INTEGER REFERENCES match_history(id),
	round_number    INTEGER,                   -- ラウンド番号（トーナメント用）
	player_1_id     INTEGER REFERENCES users(id),
	player_2_id     INTEGER REFERENCES users(id),
	winner_id       INTEGER REFERENCES users(id),
	played_at       TIMESTAMP DEFAULT NOW()
);
```

#### operation_logs（P6 — 操作ログ / チート検知）

```sql
CREATE TABLE operation_logs (
	id              SERIAL PRIMARY KEY,
	user_id         INTEGER REFERENCES users(id),
	match_id        INTEGER REFERENCES match_history(id),
	operation_type  TEXT NOT NULL,             -- spell_cast / summon / move / dice / battle / dominio / pass
	operation_data  JSONB,                     -- 操作詳細（ペイロード）
	before_state    JSONB,                     -- 操作前の関連状態（EP, HP等）
	after_state     JSONB,                     -- 操作後の関連状態
	server_verified BOOLEAN DEFAULT FALSE,     -- サーバー検証済みか
	created_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_operation_logs_match ON operation_logs(match_id);
CREATE INDEX idx_operation_logs_user ON operation_logs(user_id, created_at DESC);
```

**before_state / after_state の記録例**:

```json
// spell_cast の場合
{
  "before_state": {"caster_ep": 1200, "target_hp": 30},
  "after_state":  {"caster_ep": 1100, "target_hp": 0}
}

// summon の場合
{
  "before_state": {"player_ep": 800, "tile_owner": -1},
  "after_state":  {"player_ep": 600, "tile_owner": 0, "creature_id": 42, "creature_hp": 30}
}
```

不具合調査時に「何がどう変わったか」を即座に追跡できる。

#### fraud_alerts（P6 — 不正検知アラート）

```sql
CREATE TABLE fraud_alerts (
	id          SERIAL PRIMARY KEY,
	user_id     INTEGER REFERENCES users(id),
	match_id    INTEGER,
	alert_type  TEXT NOT NULL,                 -- impossible_move / invalid_ep / speed_hack / invalid_damage
	description TEXT,
	severity    TEXT NOT NULL,                 -- low / medium / high / critical
	action_taken TEXT DEFAULT 'none',          -- none / warning / temp_ban / permanent_ban
	detected_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_fraud_alerts_user ON fraud_alerts(user_id);
```

#### banned_users（P9 — BAN管理）

```sql
CREATE TABLE banned_users (
	user_id     INTEGER PRIMARY KEY REFERENCES users(id),
	ban_reason  TEXT NOT NULL,
	banned_by   TEXT,                          -- 管理者名 or 'system'
	banned_at   TIMESTAMP DEFAULT NOW(),
	banned_until TIMESTAMP,                   -- NULLなら永久BAN
	is_permanent BOOLEAN DEFAULT FALSE
);
```

---

## API 設計

### 認証

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/auth/guest` | POST | ゲストログイン（UUID生成） |
| `/api/auth/login` | POST | Apple ID / Google ログイン |
| `/api/auth/transfer` | POST | 引き継ぎコード入力 |
| `/api/auth/transfer/code` | GET | 引き継ぎコード発行 |

### ユーザー

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/users/me` | GET | 自分のプロフィール（stats含む） |
| `/api/users/me` | PATCH | プロフィール更新（名前、称号、キャラ等） |
| `/api/users/{id}` | GET | 他ユーザーのプロフィール |
| `/api/users/me/stats` | GET | 詳細戦績取得 |
| `/api/users/me/stats` | PATCH | 統計更新（クエスト完了時等） |

### カード・デッキ

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/users/me/cards` | GET | カード所持一覧 |
| `/api/users/me/cards` | PUT | カード所持情報同期（クラウドセーブ） |
| `/api/users/me/decks` | GET | デッキ一覧 |
| `/api/users/me/decks/{slot}` | PUT | デッキ保存 |
| `/api/users/me/decks/{slot}` | DELETE | デッキ削除 |
| `/api/users/me/deck_slots` | GET | デッキスロット数取得 |

### 対戦

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/match/history` | GET | 対戦履歴取得（ページネーション対応） |
| `/api/match/{id}` | GET | 対戦詳細（参加者の統計含む） |

※ 対戦結果はサーバーが `game_over` 発行時に内部処理で確定する。クライアントからの結果報告APIは設けない（チート防止）。

### 解放管理

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/users/me/unlocks` | GET | 解放済みキー一覧 |
| `/api/users/me/unlocks/{category}` | GET | カテゴリ別解放一覧 |
| `/api/unlocks` | POST | 解放処理（クエストクリア・購入時） |

### クエスト進行

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/users/me/quest_progress` | GET | クエスト進行状況取得 |
| `/api/users/me/quest_progress` | PUT | クエスト進行状況更新 |

### ミッション

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/missions` | GET | ミッション一覧+進捗（カテゴリ別） |
| `/api/missions/{id}/claim` | POST | 報酬受け取り |
| `/api/missions/report` | POST | 進捗報告（バトル完了、召喚等） |

### WebSocket（ロビー・準備画面）

#### ルーム管理

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `create_room` | C→S | ルーム作成（max_players指定） |
| `room_created` | S→C | ルーム作成成功（room_id返却） |
| `join_room` | C→S | ルーム参加（room_id指定） |
| `room_joined` | S→C | ルーム参加成功（プレイヤーリスト返却） |
| `player_joined` | S→C | 他プレイヤーが参加（全員に通知） |
| `player_left` | S→C | プレイヤーが退出（全員に通知） |
| `leave_room` | C→S | ルーム退出 |
| `error` | S→C | エラー通知（ルーム不存在、満員等） |

```json
// ルーム作成
→ {"type": "create_room", "max_players": 4}
← {"type": "room_created", "room_id": "1234"}

// ルーム参加
→ {"type": "join_room", "room_id": "1234"}
← {"type": "room_joined", "room_id": "1234", "players": [
	{"id": "user_1", "name": "ホスト", "slot": 0, "is_ready": false, "character_id": 1},
	{"id": "user_2", "name": "ゲスト", "slot": 1, "is_ready": false, "character_id": 1}
  ]}

// 他プレイヤー参加通知（既存メンバー全員に配信）
← {"type": "player_joined", "player": {"id": "user_3", "name": "新参加者", "slot": 2, "character_id": 1}}

// プレイヤー退出通知
← {"type": "player_left", "player_id": "user_3"}

// エラー
← {"type": "error", "code": "room_not_found", "message": "ルームが見つかりません"}
← {"type": "error", "code": "room_full", "message": "ルームが満員です"}
← {"type": "error", "code": "room_id_duplicate", "message": "ルームID重複、再生成してください"}
```

#### 準備画面（設定同期）

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `set_ready` | C→S | 準備完了/取消（ゲスト→サーバー→全員） |
| `ready_changed` | S→C | 準備状態変更通知（全員に配信） |
| `update_config` | C→S | ルール設定変更（ホスト→サーバー→ゲスト） |
| `config_updated` | S→C | ルール設定更新通知（ゲストに配信） |
| `set_deck` | C→S | デッキ選択通知 |

```json
// 準備完了
→ {"type": "set_ready", "is_ready": true}
← {"type": "ready_changed", "player_id": "user_2", "is_ready": true}

// ルール設定変更（ホストのみ送信可）
→ {"type": "update_config", "config": {
	"map_id": "map_diamond_20",
	"rule_preset": "standard",
	"initial_magic": 1000,
	"target_magic": 8000,
	"max_turns": 0
  }}
← {"type": "config_updated", "config": { ... }}  // ゲスト全員に配信

// デッキ選択
→ {"type": "set_deck", "deck_id": "deck_0"}
```

#### ランクマッチ（マッチメイキング）

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `start_matchmaking` | C→S | マッチング開始（レート・人数指定） |
| `cancel_matchmaking` | C→S | マッチングキャンセル |
| `matchmaking_cancelled` | S→C | キャンセル確認 |
| `match_found` | S→C | マッチング成立（ルーム情報返却） |

```json
// マッチング開始
→ {"type": "start_matchmaking", "player_count": 2, "deck_id": "deck_0"}
← {"type": "match_found", "room_id": "ranked_xyz", "players": [...]}

// マッチングキャンセル
→ {"type": "cancel_matchmaking"}
← {"type": "matchmaking_cancelled"}
```

**マッチメイキングロジック**（サーバー側）:
1. マッチング待機キューに追加（display_rate + 待機時間を保持）
2. **レート帯ごとにキューを分割**（bronze/silver/gold/platinum/diamond）
3. 各レート帯内で定期走査（1秒間隔）
4. レート差が閾値以内のプレイヤーをグループ化
5. 待機時間が長いほど閾値を緩和（10秒ごとにレート差 +5、隣接レート帯まで拡張）
6. 必要人数が揃ったら `match_found` を配信、自動でルーム作成

**スケーリング**: レート帯分割により、全走査を回避。ユーザー増加時も各帯の人数は限定的。

#### ゲーム開始・対戦中

| メッセージタイプ | 方向 | 説明 |
|----------------|------|------|
| `game_start` | S→C | ゲーム開始（seed、プレイヤー順） |
| `turn_start` | S→C | ターン開始通知 |
| `spell_cast` | C→S | スペル使用（card_id, target） |
| `spell_pass` | C→S | スペルパス |
| `dice_result` | S→C | ダイス結果（サーバー生成） |
| `move_complete` | C→S | 移動完了（destination_tile） |
| `summon` | C→S | クリーチャー召喚（card_id, tile_id） |
| `card_selected` | C→S | カード選択（バトルアイテム等） |
| `dominio_action` | C→S | ドミニオコマンド（level_up / move_creature / swap） |
| `pass` | C→S | パス（各フェーズ共通） |
| `end_turn` | C→S | ターン終了 |
| `action_result` | S→C | サーバー検証済みアクション結果（全員に中継） |
| `game_over` | S→C | ゲーム終了（サーバー確定、順位、レート変動） |

```json
// ゲーム開始
← {"type": "game_start", "seed": 12345, "player_order": [0, 1, 2, 3]}

// ゲーム終了（ランクマッチ時、レート変動を含む）
← {"type": "game_over", "results": [
	{"player_id": "user_1", "rank": 1, "rate_change": +3.2, "new_display_rate": 13.2},
	{"player_id": "user_2", "rank": 2, "rate_change": -1.5, "new_display_rate": 8.5}
  ]}
```

### フレンド

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/friends` | GET | フレンドリスト |
| `/api/friends/request` | POST | フレンド申請 |
| `/api/friends/{id}/accept` | POST | 申請承認 |
| `/api/friends/{id}/reject` | POST | 申請拒否 |
| `/api/friends/{id}` | DELETE | フレンド削除 |

### メール

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/mail` | GET | メール一覧 |
| `/api/mail/{id}/read` | POST | 既読にする |
| `/api/mail/{id}/claim` | POST | 添付報酬受け取り |
| `/api/mail/claim_all` | POST | 一括受け取り |
| `/api/mail/send` | POST | フレンドメール送信 |
| `/api/mail/unread_count` | GET | 未読件数 |

### 告知

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/announcements` | GET | お知らせ一覧 |
| `/api/announcements/{id}` | GET | お知らせ詳細 |

### 大会

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/tournaments` | GET | 大会一覧 |
| `/api/tournaments/{id}` | GET | 大会詳細（組み合わせ、結果） |
| `/api/tournaments/{id}/enter` | POST | エントリー |
| `/api/tournaments/{id}/ranking` | GET | 大会ランキング |

### ランキング

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/rankings` | GET | 全体ランキング（Top 100） |
| `/api/rankings/friends` | GET | フレンド内ランキング |

### 倉庫

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/items` | GET | 所持アイテム一覧 |
| `/api/items/{type}/use` | POST | アイテム使用 |

### ショップ・課金

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/shop/products` | GET | 商品一覧（ジェムパッケージ含む） |
| `/api/shop/purchase` | POST | 購入処理 |
| `/api/shop/verify_receipt` | POST | レシート検証（Apple/Google） |
| `/api/gacha/pull` | POST | ガチャ実行（サーバー側抽選） |
| `/api/gacha/events` | GET | 開催中ガチャイベント |
| `/api/gacha/pity` | GET | 天井カウンター状態取得 |

### クラウドセーブ

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/saves` | GET | セーブデータ取得 |
| `/api/saves` | PUT | セーブデータ保存（バージョン競合チェック付き） |
| `/api/saves/conflict` | POST | 競合解決（ローカル/サーバー選択） |

### ログインボーナス

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/login_bonus/status` | GET | ログインボーナス状態（連続日数、受取可否） |
| `/api/login_bonus/claim` | POST | ログインボーナス受取 |

### 管理（Admin）

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/api/admin/users/{id}` | GET | ユーザー詳細（管理者用） |
| `/api/admin/users/{id}/ban` | POST | ユーザーBAN |
| `/api/admin/users/{id}/unban` | POST | BAN解除 |
| `/api/admin/announcements` | POST | お知らせ投稿 |
| `/api/admin/announcements/{id}` | PUT | お知らせ編集 |
| `/api/admin/fraud_alerts` | GET | 不正検知アラート一覧 |
| `/api/admin/gacha_events` | POST | ガチャイベント作成 |

---

## 要所検証（チート対策）

### 設計方針

**対戦結果はサーバーが確定する**。クライアントからの `/api/match/result` による結果報告は廃止。
サーバーが試合状態を追跡し、`game_over` はサーバーのみが発行する。

```
クライアント → 具体的アクション（型固定） → サーバー
										  ├─ 即時検証（合法か？）
										  ├─ サーバー側で状態計算・更新
										  ├─ 勝利条件チェック
										  └─ action_result を全員に中継 or game_over 発行
```

### サーバー責任範囲（明確化）

| 処理 | 責任 | 理由 |
|------|------|------|
| ダイス結果 | **サーバー確定** | チート防止の基本 |
| ターン進行（Phase遷移） | **サーバー確定** | 不正なPhaseスキップ防止 |
| EP計算（消費・獲得） | **サーバー計算** | 改ざん防止 |
| HP計算（バトルダメージ） | **サーバー計算** | 改ざん防止 |
| カード効果の結果 | **サーバー計算** | スペル・スキル効果の改ざん防止 |
| 勝敗判定 | **サーバー確定** | 最重要 |
| 移動先タイル | クライアント選択 → **サーバー検証** | 分岐時の選択はクライアント、合法性はサーバー |
| カード選択（召喚・スペル・アイテム） | クライアント選択 → **サーバー検証** | 手札にあるか＋コスト足りるかをサーバーが検証 |
| ドミニオコマンド | クライアント選択 → **サーバー検証** | レベルアップコスト等をサーバーが検証 |
| UI表示・アニメーション | クライアント | サーバー関与不要 |

### サーバー側ゲーム状態

```go
type GameState struct {
	Players      []PlayerState  // 各プレイヤーの状態
	CurrentTurn  int            // 現在のターン番号
	ActivePlayer int            // 操作中のプレイヤーIndex
	Phase        string         // spell / dice / move / tile_action / battle / end_turn
	Board        []TileState    // 各タイルの状態（所有者、クリーチャー、レベル）
	TargetTEP    int            // 勝利条件TEP
	MaxTurns     int            // 最大ターン数（0=無制限）
}

type PlayerState struct {
	UserID    string
	EP        int              // 現在EP（サーバーが計算・管理）
	Hand      []int            // 手札のカードID
	Position  int              // 現在位置（タイルIndex）
	LapCount  int              // 周回数
	TEP       int              // 現在TEP（サーバーが計算）
}

type TileState struct {
	Index       int
	OwnerIndex  int            // -1 = 空き
	CreatureID  int            // 配置クリーチャーのカードID
	CreatureHP  int            // クリーチャー現在HP（サーバーが管理）
	Level       int            // タイルレベル
	IsDown      bool           // ダウン状態
	Element     string         // 属性
}
```

### WebSocket ペイロード型定義

各アクションのペイロードを厳密に定義し、不正なフィールドは受け付けない：

```json
// spell_cast — スペル使用
{"type": "spell_cast", "card_id": int, "target_player": int, "target_tile": int}

// spell_pass — スペルパス
{"type": "spell_pass"}

// move_complete — 移動方向選択（分岐時）
{"type": "move_complete", "direction": int}

// summon — クリーチャー召喚
{"type": "summon", "card_id": int}

// card_selected — バトルアイテム選択
{"type": "card_selected", "card_id": int}

// dominio_action — ドミニオコマンド
{"type": "dominio_action", "command": "level_up|move_creature|swap", "source_tile": int, "target_tile": int}

// pass — パス
{"type": "pass"}

// end_turn — ターン終了
{"type": "end_turn"}
```

**サーバー側の処理**: 上記以外のフィールドが含まれる場合は無視。型が不正な場合はエラー返却＋fraud_alerts記録。

### 検証タイミング（3段階）

| タイミング | 検証内容 | 失敗時の処理 |
|-----------|---------|-------------|
| **① 受信時（即時）** | アクション合法性チェック | アクション拒否＋エラー返却 |
| **② ターン終了時** | 状態整合性チェック | 不整合をfraud_alertsに記録、状態をサーバー版で上書き |
| **③ 試合終了時** | 最終結果＋統計異常チェック | 異常があればfraud_alerts記録、重度ならBAN |

#### ① 受信時検証（全アクション共通）

| チェック項目 | 内容 |
|------------|------|
| 送信者確認 | ActivePlayerと一致するか |
| Phase確認 | 現在のPhaseで許可されたアクションか |
| 手札確認 | 使用カードが手札にあるか |
| コスト確認 | EP/ゴールドが足りるか |
| ターゲット確認 | 対象タイル/プレイヤーが有効か |

#### ② ターン終了時検証

| チェック項目 | 内容 |
|------------|------|
| EP収支 | ターン中のEP増減が正しいか |
| HP整合 | バトル後のクリーチャーHPが計算と一致するか |
| 盤面整合 | タイル所有者・クリーチャー配置がサーバー状態と一致するか |

#### ③ 試合終了時検証

| チェック項目 | 内容 |
|------------|------|
| 勝敗整合 | TEP計算が正しいか |
| 操作速度 | 異常に速い操作がないか（bot検知） |
| 統計異常 | 直近の勝率・試合時間に異常パターンがないか |

### 初期（P6リリース時 — 必須）

| 検証項目 | 方法 |
|---------|------|
| ダイス結果 | サーバー側で生成・配信 |
| ターン順 | 正しいプレイヤーの操作か検証（Phase + ActivePlayer照合） |
| 手札所持 | 使用カードが手札にあるか |
| EP残高 | スペルコスト分のEPがあるか（サーバー側EP管理） |
| 勝利条件 | 目標TEP到達をサーバーが判定、`game_over` をサーバーが発行 |
| HP変動チェック | サーバー側でダメージ計算、結果を確定 |
| ダメージ範囲 | AP + スキル補正 + アイテム補正の合計をサーバーが計算 |

### 中期（不正報告が出たら）

| 検証項目 | 方法 |
|---------|------|
| バトルロジック完全再現 | サーバーでスキル・アイテム効果を含む完全計算 |
| 召喚コスト | カードコスト分のEPがあるか |
| レベルアップコスト | 正しいEP消費か |
| スキル発動条件 | スキル条件（属性一致、HP閾値等）が満たされているか |

### 後期（必要に応じて）

| 検証項目 | 方法 |
|---------|------|
| 完全サーバー権威 | 全操作をサーバーで処理（クライアントは入力のみ） |

### 異常検知パターン（自動フラグ）

fraud_alertsに記録し、閾値超えで自動対処：

| パターン | 検知条件 | 自動対処 |
|---------|---------|---------|
| 速攻勝利 | 試合時間が通常の1/3以下 | `severity: medium`、手動確認 |
| 異常連勝 | 直近20戦で18勝以上 | `severity: medium`、操作ログ精査 |
| 切断悪用 | 24時間内に5回以上の切断 | `severity: high`、一時マッチング制限（1時間） |
| 不正操作 | 受信時検証で3回以上拒否 | `severity: critical`、即時切断＋一時BAN |
| bot疑い | 操作間隔が一定（標準偏差 < 0.1秒） | `severity: medium`、手動確認 |

### operation_logs の運用ルール

ログは貯めるだけでなく、3段階検証で活用する：

1. **即時検証**: 操作受信時にサーバー側GameStateと照合、不整合なら`fraud_alerts`に記録
2. **ターン終了時検証**: ターン中の操作ログを走査、状態整合性を確認
3. **試合終了時検証**: 全操作ログを再走査、統計的異常を検出（速度異常、勝率異常等）
3. **保存期間**: 通常30日保持、fraud_alertsが出た試合は永久保持

---

## WebSocket メッセージ設計補足

### アクション分割方針

`game_action` 汎用型は使わず、具体的なアクションタイプに分割する。
`network_design.md` に定義済みの以下のタイプを使用：

```
spell_cast       — スペル使用（card_id, target 含む）
spell_pass       — スペルパス
dice_result      — ダイス結果（サーバー→クライアント専用）
move_complete    — 移動完了（destination_tile）
summon           — クリーチャー召喚（card_id, tile_id）
battle_result    — バトル結果（サーバー検証済み）
dominio_action   — ドミニオコマンド（level_up / move_creature / swap）
card_selected    — カード選択（バトルアイテム等）
pass             — パス（各フェーズ共通）
end_turn         — ターン終了
```

**理由**: アクション別に検証ロジックを書ける、不正検知しやすい、サーバー側の実装が明確になる

---

## 切断時の扱い

### 共通

- **切断検知**: WebSocket ping/pong、10秒間隔、3回連続失敗で切断判定

### ランクマッチ

```
切断検知 → 30秒猶予（再接続待ち） → 復帰なし → 敗北確定
				↓ 復帰あり
		  GameState snapshot 送信 → プレイ続行
```

- 猶予中は相手のターンは通常進行（切断側はターンスキップ）
- 敗北確定時: display_rate減少、相手に勝利付与
- **切断悪用防止**: 24時間内に3回以上の切断 → 1時間マッチング制限

### フレンドマッチ

```
切断検知 → 60秒猶予（再接続待ち） → 復帰なし → サーバー側AIが代行
				↓ 復帰あり
		  GameState snapshot 送信 → プレイ続行
```

- ローカルCPU代行ではなくサーバー側で処理（クライアント操作による有利防止）
- レーティング変動なし

---

## 状態同期（State Snapshot）

クライアントとサーバー間の状態ズレを防止するため、定期的に完全状態を送信する。

### 送信タイミング

| タイミング | 内容 | 方向 |
|-----------|------|------|
| **ターン開始時** | 全プレイヤーのEP、手札枚数、位置、盤面状態 | S→C（全員） |
| **バトル終了後** | バトル結果＋タイルの最新状態 | S→C（全員） |
| **切断復帰時** | GameState全体 | S→C（復帰者のみ） |

### State Snapshot メッセージ

```json
{
  "type": "state_snapshot",
  "turn": 5,
  "active_player": 1,
  "phase": "spell",
  "players": [
	{"index": 0, "ep": 1200, "hand_count": 4, "position": 7, "lap": 1, "tep": 3500},
	{"index": 1, "ep": 800, "hand_count": 3, "position": 12, "lap": 0, "tep": 2100}
  ],
  "board": [
	{"index": 0, "owner": 0, "creature_id": 42, "creature_hp": 30, "level": 2, "is_down": false},
	{"index": 1, "owner": -1, "creature_id": 0, "creature_hp": 0, "level": 0, "is_down": false}
  ]
}
```

### クライアント側の処理

1. snapshot受信時、ローカル状態と差分チェック
2. 差分があればサーバー側の値で上書き（サーバーが正）
3. 差分が発生した場合はログ出力（デバッグ用）

---

## ルーム管理のスケーリング

### 現行（P6初期）

- Go サーバーのメモリ上で管理（`sync.RWMutex` + `map`）
- VPS 1台構成では問題なし

### 将来（ユーザー増加時）

複数サーバー構成に移行する場合、ルーム管理を Redis に移行：

| 項目 | メモリ管理（現行） | Redis（将来） |
|------|-------------------|--------------|
| スケール | 1台限定 | 複数サーバー共有可 |
| 再起動 | 全ルーム消失 | 永続化可能 |
| 速度 | 最速 | ほぼ同等 |
| 導入コスト | ゼロ | Redis追加 |

**移行タイミング**: VPS 2台目が必要になった時点（500人超を目安）

**スケール時のWS接続方針**: Sticky Session（同一ルームのプレイヤーは同一サーバーに接続）
- ロードバランサー（Nginx）で `room_id` ベースの振り分け
- 同一試合中のGameStateは1台のサーバーメモリに集約
- ルーム一覧・マッチングキューのみRedisで共有

---

## display_rate の扱い

`display_rate = μ - 3σ` は `ts_mu` と `ts_sigma` から計算可能な値。

**方針**: キャッシュとして保持するが、更新タイミングを厳密に固定する。

- **更新タイミング**: TrueSkill計算時（対戦結果確定時）のみ
- **更新箇所**: `ts_mu`, `ts_sigma`, `display_rate`, `rank_tier` を同一トランザクションで更新
- **理由**: ランキングクエリのパフォーマンス（毎回計算するとインデックスが使えない）

---

## JSONB 使用ガイドライン

### 使って良い場合

- 構造が可変で検索不要なデータ（セーブデータのスナップショット等）
- 内部キャッシュ用途（表示用データの一時保存）

### 使ってはいけない場合

- 検索・フィルタ・ランキングに使うデータ
- ロジック判定に使うデータ（EP残高、勝敗等）

### 現行設計の判定

| テーブル.カラム | JSONB | 判定 | 理由 |
|---------------|-------|------|------|
| `decks.cards` | `{"card_id": count}` | OK | デッキ内容は検索対象にならない |
| `quest_progress.cleared_stages` | `[1, 2, 3]` | **要検討** | ステージ別クリア率の集計に支障 |
| `quest_progress.stage_stars` | `{"1": 3}` | OK | 個別参照のみ、集計不要 |
| `player_stats.collection_complete` | `{"fire": true}` | OK | 表示用キャッシュ |
| `cloud_saves.save_data` | 全データ | OK | スナップショット用途 |
| `gacha_events.rates` | `{"C": 0.5}` | OK | マスタ定義、変更頻度低 |
| `match_history` 関連 | なし | OK | 全て正規化済み |

**quest_progress.cleared_stages の代替案**:
ステージ別クリア率を集計したい場合は `user_stage_clears` テーブルを追加：
```sql
CREATE TABLE user_stage_clears (
	user_id     INTEGER REFERENCES users(id),
	stage_id    INTEGER NOT NULL,
	star_rating INTEGER,          -- 1-3
	best_rank   TEXT,             -- SS/S/A/B/C
	best_turns  INTEGER,
	clear_count INTEGER DEFAULT 1,
	first_cleared_at TIMESTAMP DEFAULT NOW(),
	PRIMARY KEY(user_id, stage_id)
);
```
ただしP6時点では不要。ステージ別集計が必要になった時点で移行する。

---

## パフォーマンス指針

### ボトルネック予測と対策

| ボトルネック | 発生条件 | 対策 |
|------------|---------|------|
| WS接続数 | 同時接続100超 | goroutine per connection（Go標準、問題なし） |
| マッチングキュー | 待機者50超 | レート帯分割キュー（設計済み） |
| GameState管理 | 同時進行30試合超 | 軽量構造（上記struct）＋試合終了時に即破棄 |
| operation_logs | 蓄積 | 30日超のログを日次バッチ削除、fraud_alerts該当分は保持 |
| DBクエリ | ランキング取得 | display_rateインデックス（設計済み）＋キャッシュ（5分TTL） |

### GameState のメモリ見積もり

- 1試合あたり: 約2-5KB（4人×手札＋20タイル）
- 同時100試合: 約500KB（問題なし）
- VPS 512MB でも余裕

---

## セキュリティ

| 項目 | 対応 |
|------|------|
| 通信暗号化 | WSS (WebSocket Secure) / HTTPS |
| 認証 | JWT（ステートレス、有効期限15分） |
| リフレッシュトークン | bcryptハッシュ化してDB保存（生トークンは保存しない） |
| パスワード | bcrypt ハッシュ化 |
| ガチャ | サーバー側で抽選（クライアント改ざん防止） |
| 課金 | Apple/Google レシート検証（サーバー側） |
| 対戦結果 | サーバーが確定（クライアントからの結果報告は受け付けない） |
| 不正検知 | リアルタイム検証 + 操作ログ保存 + 異常値アラート |
| BAN | 管理画面から実行、即時切断 |

### 認証フロー（REST API）

```
1. ログイン → サーバーがJWT(15分)とRefreshToken(30日)を発行
2. API呼び出し → JWTをAuthorizationヘッダーに付与（サーバーはDB参照不要）
3. JWT期限切れ → RefreshTokenで新JWT取得
4. RefreshToken → bcryptハッシュ化してDBに保存（漏洩時の被害軽減）
```

### WebSocket 接続時認証

WebSocket接続時にもJWT検証を行い、未認証・期限切れの接続を拒否する。

```
1. クライアント → ws://server/ws?token=<JWT> で接続要求
2. サーバー: Upgrade前にJWTを検証
   - 無効 or 期限切れ → 接続拒否（HTTP 401）
   - 有効 → WebSocket接続確立、user_idをClientに紐付け
3. 接続中: アクション受信時にClient.user_idとroom_id + slot_indexの一致を検証
   - 不一致 → アクション拒否＋fraud_alerts記録
4. JWT期限（15分）到達前にクライアントがRefreshTokenで新JWTを取得し、
   サーバーに再認証メッセージを送信（接続は維持したまま）
```

```json
// 再認証メッセージ（接続維持したまま）
→ {"type": "reauthenticate", "token": "<new_jwt>"}
← {"type": "reauthenticate_ok"}
```

**セッションハイジャック防止**: 各アクション処理時に `Client.user_id` と `Room.players[slot].user_id` の一致を必ずチェック。別ユーザーの操作が混入することを防ぐ。

---

## Go サーバー技術スタック

| 用途 | ライブラリ/ツール |
|------|----------------|
| HTTP ルーター | `net/http` or `chi` |
| WebSocket | `gorilla/websocket` or `nhooyr/websocket` |
| DB ドライバ | `pgx` (PostgreSQL) |
| マイグレーション | `golang-migrate` |
| 認証 | `golang-jwt` |
| 設定管理 | `envconfig` or `viper` |
| ログ | `slog` (Go 標準) |
| テスト | `testing` (Go 標準) |

---

## クライアント側（Godot）の対応

### 既存実装（クライアント側）
- `scripts/network/network_manager.gd` — WebSocket P2P通信（スタンドアロン）
- `scripts/net_battle_lobby.gd` — ロビー画面（ランクマッチ/フレンドマッチ切替、ルーム作成・参加UI）
- `scripts/net_battle_setup.gd` — 準備画面（ホスト/ゲスト切替、マップ・ルール設定、プレイヤーリスト、3Dキャラプレビュー）
- ネットワーク公開メソッド: `on_player_joined()`, `on_player_left()`, `on_player_ready_changed()`, `on_config_received()`

### GameClock（時刻管理 - 実装済み）

**ファイル**: `scripts/autoload/game_clock.gd`（Autoload）

サーバー時刻とローカル時刻を抽象化するレイヤー。全スクリプトは `GameClock` 経由で時刻を取得しており、`Time.get_unix_time_from_system()` を直接呼ばない。

| メソッド | 説明 |
|---------|------|
| `get_now() -> int` | 現在のUnix時刻（サーバー同期済みならサーバー時刻） |
| `get_today() -> String` | 今日の日付（YYYY-MM-DD） |
| `sync_with_server(server_unix)` | サーバー時刻との差分を計算・保存 |
| `is_synced() -> bool` | サーバー同期済みか |

**サーバー移行時の対応**:
1. ログインAPIのレスポンスにサーバーUnix時刻を含める
2. クライアント側で `GameClock.sync_with_server(response.server_time)` を呼ぶ
3. 以降、スタミナ回復・ログインボーナス・日付判定等が全てサーバー時刻基準になる

**使用箇所**: `game_data.gd`（スタミナ・ログインボーナス・セーブ時刻）、`main_menu.gd`、`stage_record_manager.gd`

### 必要な追加実装

| 実装 | Phase | 説明 |
|------|-------|------|
| `NetworkService` (Autoload) | P6 | WebSocket接続管理 + シグナル駆動の抽象レイヤー |
| HTTPクライアント | P6 | REST API 呼び出し用（`HTTPRequest` ノード） |
| `player_is_remote` フラグ | P6 | GameFlowManager でリモートプレイヤー判定 |
| GFM ↔ NetworkService 統合 | P6 | 各フェーズの操作送受信 |
| ロビー ↔ NetworkService 接続 | P6 | TODO箇所の実装（ルーム作成/参加/マッチング） |
| 準備画面 ↔ NetworkService 接続 | P6 | TODO箇所の実装（設定同期/準備完了/ゲーム開始） |
| 解放状態のローカルキャッシュ | P6 | 解放済みマップ・キャラをローカルに保持、起動時同期 |
| トークン管理 | P7 | JWT の保存・自動付与・リフレッシュ |
| クラウドセーブ同期 | P7 | 起動時同期チェック、競合解決UI |

### GFM 統合の対象フェーズ

```
各フェーズで「ローカル操作 → サーバー送信」or「サーバー受信 → 画面反映」の分岐:

- SpellPhaseHandler      — スペル選択/パス
- DicePhaseHandler       — ダイス結果（サーバーから受信）
- MovementController     — 移動方向選択
- TileActionProcessor    — 召喚カード選択
- BattleSystem           — アイテム選択
- DominioCommandHandler  — ドミニオコマンド
```

---

## Phase 別実装計画

### P6: ネット対戦

#### サーバー基盤
1. Go サーバープロジェクト作成（WebSocket + REST）
2. DB セットアップ（PostgreSQL: users, rooms, room_players, match_history, match_players, decks）
3. DB マイグレーション（golang-migrate）
4. JWT 認証基盤（ゲストログイン最優先）

#### ルーム管理（フレンドマッチ）
5. ルーム作成（4桁ルームID生成、重複チェック）
6. ルーム参加（ID検索、満員チェック、存在チェック）
7. ルーム退出（ホスト退出時は全員退出 or ホスト移譲）
8. 準備完了状態の同期（set_ready → 全員に配信）
9. ルール設定の同期（ホスト → ゲスト全員に配信）
10. ゲーム開始判定（全員Ready → game_start 配信）

#### マッチメイキング（ランクマッチ）
11. マッチング待機キュー管理
12. レート近似マッチング（display_rate 基準、待機時間で閾値緩和）
13. マッチング成立 → 自動ルーム作成 → match_found 配信
14. マッチングキャンセル処理

#### TrueSkill レーティング
15. TrueSkill 計算ロジック実装（Go側）— μ/σ 更新、2～4人対応
16. 対戦結果報告 → レート更新 → DB保存（users + match_players + rank_history）
17. ランク段位の自動判定（display_rate → rank_tier）
18. ランキング API（全体 Top 100、フレンド内）

#### 解放管理
19. ユーザー登録時に初期解放データ挿入（デフォルトマップ・キャラクター）
20. クエストクリア時の解放処理 API
21. ショップ購入時の解放処理 API
22. マップ選択時のバリデーション（解放済みかチェック）— フレンドマッチのみ
23. キャラクター選択時のバリデーション

#### GFM ↔ NetworkManager 統合（ターン同期）
24. 各フェーズの操作送受信（スペル、ダイス、移動、召喚、バトル、ドミニオ）
25. ダイス結果のサーバー生成・配信
26. リモートプレイヤー操作の画面反映

#### 安定化
27. 切断検知（WebSocket ping/pong、60秒タイムアウト）
28. 切断時のAI引き継ぎ（ローカルCPUが代行）
29. ターンタイムアウト（60秒で自動パス）
30. ルーム自動クリーンアップ（全員退出 or 一定時間経過）

#### チート対策（初期）
31. ダイス結果サーバー生成
32. ターン順検証
33. 手札所持検証
34. EP残高検証

### P7: アカウント基盤
1. Apple ID / Google ログイン
2. JWT 認証
3. データ引き継ぎ
4. クラウドセーブ

### P8: ソーシャル
1. フレンドシステム
2. レーティング・ランキング
3. 大会システム
4. 観戦機能
5. SNS共有

### P9: マネタイズ・運営
1. 課金システム（ストア連携、レシート検証）
2. ガチャのサーバー側抽選
3. お知らせ機能
4. メールシステム
5. デイリークエスト
6. 倉庫
7. 管理画面
8. アクセス解析
9. プッシュ通知
10. SNS連携デイリーボーナス

---

## SNS連携デイリーボーナス

### 概要

公式SNSアカウント（X / Instagram）を連携したユーザーに対し、1日1回ジェム100を付与する。

**注意: フォロー検証のリスク**
- SNS APIの利用制限に当たりやすい（特にX Free Tierは月1,500リクエスト制限）
- API仕様変更で突然壊れる可能性がある
- **推奨方式**: フォロー必須にせず「SNS連携だけで報酬」とする（ミッション扱い）
- フォロー検証はオプション機能として将来対応可能な設計にしておく

### テーブル定義

#### sns_accounts（P9 — SNS連携アカウント）
```sql
CREATE TABLE sns_accounts (
	id            SERIAL PRIMARY KEY,
	user_id       INTEGER REFERENCES users(id) ON DELETE CASCADE,
	provider      TEXT NOT NULL,                -- 'x' / 'instagram'
	provider_uid  TEXT NOT NULL,                -- SNS側ユーザーID
	access_token  TEXT NOT NULL,                -- OAuth アクセストークン（暗号化保存）
	refresh_token TEXT,                         -- リフレッシュトークン（暗号化保存）
	token_expires_at TIMESTAMP,                 -- トークン有効期限
	linked_at     TIMESTAMP DEFAULT NOW(),
	UNIQUE(user_id, provider),
	UNIQUE(provider, provider_uid)
);
```

#### sns_daily_bonus（P9 — デイリーボーナス受取履歴）
```sql
CREATE TABLE sns_daily_bonus (
	id            SERIAL PRIMARY KEY,
	user_id       INTEGER REFERENCES users(id) ON DELETE CASCADE,
	provider      TEXT NOT NULL,                -- 'x' / 'instagram'
	bonus_date    DATE NOT NULL,                -- 受取日（JST基準）
	amount        INTEGER NOT NULL DEFAULT 100, -- 付与ジェム数
	claimed_at    TIMESTAMP DEFAULT NOW(),
	UNIQUE(user_id, provider, bonus_date)
);
```

### API設計

| メソッド | エンドポイント | 説明 |
|---------|-------------|------|
| GET | `/api/sns/auth/{provider}` | OAuth認証URL生成（X / Instagram） |
| GET | `/api/sns/callback/{provider}` | OAuthコールバック受信・トークン保存 |
| GET | `/api/sns/status` | 連携状態確認（各SNSの連携有無・フォロー状態） |
| POST | `/api/sns/claim/{provider}` | デイリーボーナス受取（フォロー検証→ジェム付与） |
| DELETE | `/api/sns/unlink/{provider}` | SNS連携解除 |

### フォロー検証フロー

```
クライアント                    Goサーバー                     X API v2
	│                              │                              │
	├─ POST /sns/claim/x ─────────►│                              │
	│                              ├─ GET /users/:id/following ──►│
	│                              │◄─ フォロー一覧 ──────────────┤
	│                              │                              │
	│                              │  公式アカウントID照合          │
	│                              │  ✔ フォロー確認済み            │
	│                              │                              │
	│                              │  bonus_date重複チェック        │
	│                              │  ジェム100付与 (users.stone += 100)
	│                              │  sns_daily_bonus INSERT       │
	│                              │                              │
	│◄─ { "success": true, "gems": 100 } ─┤                      │
```

### X (Twitter) OAuth 2.0 PKCE

| 項目 | 値 |
|------|-----|
| 認証URL | `https://twitter.com/i/oauth2/authorize` |
| トークンURL | `https://api.twitter.com/2/oauth2/token` |
| スコープ | `users.read follows.read tweet.read` |
| フォロー確認API | `GET /2/users/:id/following` |
| 料金 | 無料プラン（Free tier）で可 |

### Instagram Graph API

| 項目 | 値 |
|------|-----|
| 認証URL | `https://api.instagram.com/oauth/authorize` |
| トークンURL | `https://api.instagram.com/oauth/access_token` |
| スコープ | `user_profile` |
| 備考 | フォロー確認APIに制限あり、将来対応 |

### クライアント側（Godot）

ミッション画面内にSNSデイリーボーナスセクションを配置。

- **未連携時**: 「Xアカウント連携」ボタン → ブラウザでOAuth認証
- **連携済み・未受取**: 「デイリーボーナスを受け取る（100ジェム）」ボタン
- **受取済み**: グレーアウト表示（翌日04:00 JSTリセット）

### リセット時刻

ミッションシステムと同じ **04:00 JST** でリセット。

---

## 関連ドキュメント

- `docs/progress/roadmap.md` - プロジェクトロードマップ（Phase定義）
- `docs/design/network_design.md` - ネット対戦通信設計（メッセージ仕様詳細）
- `docs/design/online_rules_design.md` - オンラインルール設計（プリセット定義）
- `docs/design/main_menu_design.md` - メイン画面設計（UI導線）
- `docs/design/database_design.md` - DB設計（SQLite移行計画）
- `docs/design/gacha_system.md` - ガチャシステム
- `docs/design/team_system_design.md` - チームシステム
