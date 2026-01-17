# データベース設計書

## 概要

本ドキュメントは、カードバトルゲームのデータ管理をJSONファイルベースからデータベース（SQLite）へ段階的に移行するための設計書です。

## 基本方針

**段階的移行** - 必要な部分から順次DB化し、未決定の部分は後回し

### データ分類

| 分類 | 管理方式 | 理由 |
|------|---------|------|
| カードマスター | JSON維持 | 読み取り専用、編集しやすい |
| マップ/ステージ | JSON維持 | 開発中で頻繁に編集が必要 |
| カード所持＋図鑑 | **DB化** | ユーザーデータ管理に必要 |
| カードレベル | **DB化（後から実装）** | 仕様検討中 |
| その他ユーザーデータ | JSON維持（当面） | 仕様未決定 |

---

## Phase 1: カード所持・図鑑のDB化（最小構成）

### 対象

- カード所持数（collection）
- 図鑑フラグ（unlocks.cards → obtained）
- カードレベル（カラムのみ用意、実装は後から）

### collectionとobtainedの違い

| 項目 | collection (count) | unlocks.cards (obtained) |
|------|-------------------|--------------------------|
| 目的 | デッキ編集・所持管理 | 図鑑・コンプリート率 |
| 0枚時 | 0になる | trueのまま残る |
| 用途 | 「何枚持っているか」 | 「一度でも入手したか」 |

```
例：
1. カードAを4枚入手 → count: 4, obtained: true
2. カードAを4枚売却 → count: 0, obtained: true ← 図鑑には残る
3. 図鑑で「入手済み」として表示可能
```

### テーブル設計

```sql
-- カード所持情報
CREATE TABLE user_cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL DEFAULT 'player1',  -- 当面は固定値
  card_id INTEGER NOT NULL,
  count INTEGER DEFAULT 0,                   -- 所持数
  level INTEGER DEFAULT 1,                   -- レベル（後から実装）
  obtained BOOLEAN DEFAULT 0,                -- 図鑑用フラグ
  UNIQUE(user_id, card_id)
);
```

### レベル設計方針

**方針A（カード単位でレベル共有）を採用**

```
カードID:1を4枚所持 → 4枚全部が同じレベル
```

- 同じカードは全て同じレベル
- 1枚レベル上げたら、所持している全枚数に適用
- UIがシンプル、管理しやすい

※ Clash Royale等と同じ方式

### 既存JSONとの併用

```
data/
├── default_save.json      ← 従来通り使用（デッキ、設定、進行等）
└── local/
	└── user_cards.db      ← 新規追加（カード所持＋図鑑＋レベル）
```

### データフロー

```
カード情報取得時:
1. CardLoader.get_card_by_id(123)  → JSON（マスターデータ）
2. UserCardDB.get_card(123)        → DB（所持数＋図鑑＋レベル）
3. 両方を結合して使用
```

---

## クリーチャーレベルシステム（後から実装）

### 仕様（案）

| レベル | HP/AP補正 | スキル/秘術 |
|--------|-----------|------------|
| 1 | 基礎値-4 | 使用不可 |
| 2 | 基礎値-3 | 使用不可 |
| 3 | 基礎値-2 | 使用不可 |
| 4 | 基礎値-1 | 使用不可 |
| 5 | 基礎値 | 使用不可 |
| MAX(6) | 基礎値 | **使用可能** |

※ 基礎値 = JSONで定義されているHP/AP

### レベルアップ条件（未定）

- 素材消費方式？
- 経験値方式？
- ハイブリッド？

→ 仕様決定後に実装

### 実装の分離

**Phase 1（今回）:**
- DBに`level`カラムを用意（初期値1）
- レベル関連の処理は実装しない

**Phase 2（後から）:**
- レベルアップUI
- レベルアップ条件
- ステータス補正処理
- スキル/秘術の解放判定

---

## Phase 1で必要な修正ファイル

| ファイル | 修正内容 |
|---------|---------|
| `scripts/user_card_db.gd` | **新規作成**: カードDB管理（CRUD） |
| `scripts/game_data.gd` | DB連携（collection → DB参照に変更） |

### 後から追加（レベルシステム実装時）

| ファイル | 修正内容 |
|---------|---------|
| `scripts/creature_level_system.gd` | **新規作成**: レベル計算・補正 |
| `scripts/spells/spell_mystic_arts.gd` | レベルチェック追加 |
| `scripts/battle/condition_checker.gd` | スキル発動条件にレベル追加 |
| UI関連 | レベル表示・レベルアップ画面 |

---

## 将来のPhase（未定・後回し）

以下は仕様が決まり次第、必要に応じて追加：

### Phase 2: レベルシステム実装
- レベルアップUI
- ステータス補正
- スキル/秘術解放

### Phase 3: ユーザーアカウント
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT UNIQUE NOT NULL,
  name TEXT,
  -- その他は仕様決定後
);
```

### Phase 4: デッキ管理のDB化
- 現状: `default_save.json`内のdecks配列
- 移行: 必要になったら

### Phase 5: ストーリー進行のDB化
- 現状: `default_save.json`内のstory_progress
- 移行: ステージJSON整備後

### Phase 6: マスターデータのDB化（オプション）
- マップ/ステージ定義
- 必要性が出たら検討

---

## 現状維持するもの

### マスターデータ（JSONのまま）

| ファイル | 内容 | 状態 |
|---------|------|------|
| `fire_*.json`等 | クリーチャー定義 | 完成 |
| `spell_*.json` | スペル定義 | 完成 |
| `item.json` | アイテム定義 | 完成 |
| `spell_mystic.json` | ミスティックアーツ | 完成 |
| `maps/*.json` | マップ定義 | **整理中** |
| `stages/*.json` | ステージ定義 | **整理中** |

### ユーザーデータ（JSONのまま・当面）

| 項目 | 現在の場所 | 備考 |
|------|-----------|------|
| デッキ | default_save.json | 仕様未定 |
| 設定 | default_save.json | 変更予定なし |
| 統計 | default_save.json | 仕様未定 |
| ストーリー進行 | default_save.json | ステージ整備後 |

---

## タスクリスト

### Phase 1（今回実装）

- [ ] godot-sqliteプラグイン導入
- [ ] `user_card_db.gd` 作成
- [ ] `game_data.gd` のDB連携
- [ ] 既存JSONからのデータ移行処理

### Phase 2（レベルシステム・後から）

- [ ] `creature_level_system.gd` 作成
- [ ] ステータス補正処理
- [ ] スキル/秘術の発動条件修正
- [ ] UI: カードレベル表示
- [ ] UI: レベルアップ画面

### 後回し（仕様決定後）

- [ ] ユーザーアカウント機能
- [ ] デッキDB化
- [ ] ストーリー進行DB化
- [ ] マップ/ステージJSON整理

---

## 技術メモ

### SQLiteプラグイン
- **godot-sqlite**: Godot用SQLiteバインディング
- AssetLibから導入

### DBファイル配置
```
user://user_cards.db  # Godotのユーザーディレクトリ
```

---

## カード売却機能

### 仕様

| 項目 | 内容 |
|------|------|
| 報酬 | ゴールド（変更の可能性あり） |
| 価格 | レアリティで変動 |
| 制限 | なし（0枚まで売却可） |
| 場所 | ショップ画面 |
| 図鑑 | 0枚でも`obtained: true`維持 |
| レベル | 売却しても維持（再入手時に引き継ぐ） |

### 売却価格（案）

| レアリティ | 売却価格 |
|-----------|---------|
| N | 10G |
| R | 50G |
| SR | 200G |
| SSR | 500G |

※ 価格は調整予定

### 動作例

```
1. カードA（Lv5）を4枚所持
2. 4枚全部売却 → count: 0, level: 5, obtained: true
3. 後でカードAを1枚入手 → count: 1, level: 5（引き継ぎ）
```

---

## 関連ドキュメント

- `docs/design/card_system_multi_deck.md` - デッキシステム
- `docs/design/mystic_arts.md` - ミスティックアーツ
- `docs/design/skills_design.md` - スキルシステム
