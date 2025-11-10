# CardSystem マルチデッキ化設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 2.0  
**作成日**: 2025年11月10日  
**ステータス**: 設計完了・実装待ち

---

## 📋 目次

1. [概要](#概要)
2. [現状の問題](#現状の問題)
3. [設計変更](#設計変更)
4. [実装計画](#実装計画)
5. [影響範囲](#影響範囲)
6. [移行手順](#移行手順)
7. [テスト項目](#テスト項目)

---

## 概要

### 🎯 最終ゴール
**アイテム復帰スキル（復帰ブック）が正しく機能すること**

具体的には：
- 使用したアイテムが**使用者自身のデッキ**に戻る
- 敵のデッキに誤って戻らない
- 手札復帰も同様に使用者の手札に戻る

### 目的
各プレイヤーが独立したデッキ（ブック）を持つように CardSystem を改修する。

### 背景
- **現状**: 全プレイヤーが1つの共有デッキを使用
- **問題**: アイテム復帰スキルで復帰先が不明確、CPU個別デッキ管理が不可能
- **必要性**: 各プレイヤーが独自の戦略を持つため、独立したデッキが必須

### 対象プレイヤー
- **プレイヤー0**: 人間プレイヤー（GameDataから選択中のブック使用）
- **プレイヤー1**: 手動操作CPU（専用デッキ1つ用意）
- **プレイヤー2-3**: 将来実装のCPU（構造のみ準備）

---

## 現状の問題

### 現在の実装

```gdscript
# scripts/card_system.gd
class_name CardSystem

var deck = []  # 共有デッキ（全プレイヤー共通）
var discard = []  # 共有捨て札
var player_hands = {}  # player_id -> {"data": [card_data]}
```

**問題点**:
1. 全プレイヤーが同じデッキからドローする
2. アイテム復帰時にどのプレイヤーのデッキに戻すか不明確
3. CPU個別のデッキ戦略が実装不可能
4. 先に引いたプレイヤーが有利になる不公平性

---

## 設計変更

### 新しいデータ構造

```gdscript
# scripts/card_system.gd
class_name CardSystem

# プレイヤーごとのデッキ管理
var player_decks = {}  # player_id -> Array[int] (card_ids)
var player_discards = {}  # player_id -> Array[int] (card_ids)
var player_hands = {}  # player_id -> {"data": [card_data]}

# デッキソース（初期化用）
var deck_sources = {}  # player_id -> {"type": String, "data": Dictionary}
```

### デッキソースの種類

#### プレイヤー0（人間）
```gdscript
deck_sources[0] = {
	"type": "game_data",
	"deck_index": GameData.selected_deck_index
}
```

#### プレイヤー1（手動操作CPU）
```gdscript
deck_sources[1] = {
	"type": "manual_cpu",
	"deck_id": 0,  # 専用デッキID
	"deck_name": "テスト用CPU"
}
```

#### プレイヤー2-3（将来のCPU）
```gdscript
deck_sources[2] = {
	"type": "cpu",
	"cpu_profile": "cpu_beginner_1",
	"deck_index": 0
}
```

---

## 実装計画

### Phase 1: データ構造変更

#### 1.1 変数の置き換え

**変更前**:
```gdscript
var deck = []
var discard = []
```

**変更後**:
```gdscript
var player_decks = {}
var player_discards = {}
var deck_sources = {}
```

#### 1.2 初期化メソッドの修正

**新しい初期化フロー**:
```gdscript
func _initialize_decks(player_count: int):
	for player_id in range(player_count):
		player_decks[player_id] = []
		player_discards[player_id] = []
		player_hands[player_id] = {"data": []}
	
	# プレイヤー0: GameDataから読み込み
	_load_deck_from_game_data(0)
	
	# プレイヤー1: 手動操作CPU用デッキ
	_load_manual_cpu_deck(1)
	
	# プレイヤー2-3: デフォルトデッキ（暫定）
	for player_id in range(2, player_count):
		_load_default_deck(player_id)
```

### Phase 2: メソッドのシグネチャ変更

すべてのデッキ操作メソッドに `player_id` パラメータを追加：

#### 2.1 ドロー系メソッド

**変更前**:
```gdscript
func draw_card_data() -> Dictionary:
	if deck.is_empty():
		if discard.is_empty():
			return {}
		deck = discard.duplicate()
		discard.clear()
		deck.shuffle()
	
	var card_id = deck.pop_front()
	return _load_card_data(card_id)
```

**変更後**:
```gdscript
func draw_card_data(player_id: int) -> Dictionary:
	if not player_decks.has(player_id):
		push_error("Invalid player_id: " + str(player_id))
		return {}
	
	if player_decks[player_id].is_empty():
		if player_discards[player_id].is_empty():
			print("Player ", player_id, ": デッキも捨て札も空")
			return {}
		
		# 捨て札をシャッフルしてデッキに戻す
		player_decks[player_id] = player_discards[player_id].duplicate()
		player_discards[player_id].clear()
		player_decks[player_id].shuffle()
	
	var card_id = player_decks[player_id].pop_front()
	return _load_card_data(card_id)
```

#### 2.2 捨て札系メソッド

**変更前**:
```gdscript
func discard_card(player_id: int, card_index: int, reason: String = "discard") -> Dictionary:
	# ...
	discard.append(card_data.id)
	# ...
```

**変更後**:
```gdscript
func discard_card(player_id: int, card_index: int, reason: String = "discard") -> Dictionary:
	# ...
	player_discards[player_id].append(card_data.id)
	# ...
```

### Phase 3: 呼び出し元の修正

影響を受けるファイル（推定50箇所以上）:

#### 3.1 主要な変更箇所

| ファイル | メソッド | 変更内容 |
|---------|---------|---------|
| `game_flow_manager.gd` | `start_turn()` | `spell_draw.draw_one()` は既に player_id 対応済み |
| `special_tile_system.gd` | `handle_card_tile()` | `draw_cards_for_player()` は既に対応済み |
| `debug_controller.gd` | `fill_hand()` | `draw_cards_for_player()` は既に対応済み |
| `spell_draw.gd` | 全メソッド | `card_system_ref.draw_card_data()` に player_id 追加必要 |
| `skill_item_return.gd` | `_return_to_deck()` | player_id パラメータ追加 |

#### 3.2 SpellDraw の修正例

**変更前**:
```gdscript
func draw_one(player_id: int) -> Dictionary:
	var card = card_system_ref.draw_card_for_player(player_id)
	# ...
```

**変更後**:
```gdscript
func draw_one(player_id: int) -> Dictionary:
	# draw_card_for_player() 内部で draw_card_data(player_id) を呼ぶように修正済み
	var card = card_system_ref.draw_card_for_player(player_id)
	# ...
```

#### 3.3 SkillItemReturn の修正

**変更前**（旧システム - 共有デッキ方式）:
```gdscript
static func _return_to_deck(item_data: Dictionary) -> bool:
	var card_id = item_data.get("id", -1)
	if card_id in card_system_ref.discard:
		card_system_ref.discard.erase(card_id)
	card_system_ref.deck.push_front(card_id)  # ⚠️ 共有デッキの先頭に追加
	return true
```

**変更後**:
```gdscript
static func _return_to_deck(player_id: int, item_data: Dictionary) -> bool:
	var card_id = item_data.get("id", -1)
	
	# プレイヤーの捨て札から削除
	if card_id in card_system_ref.player_discards[player_id]:
		card_system_ref.player_discards[player_id].erase(card_id)
	
	# プレイヤーのデッキのランダムな位置に挿入
	var deck_size = card_system_ref.player_decks[player_id].size()
	if deck_size == 0:
		card_system_ref.player_decks[player_id].append(card_id)
	else:
		var random_position = randi() % (deck_size + 1)
		card_system_ref.player_decks[player_id].insert(random_position, card_id)
	return true
```

### Phase 4: デッキロード機能の実装

#### 4.1 プレイヤー0（GameData連携）

```gdscript
func _load_deck_from_game_data(player_id: int):
	var deck_data = GameData.get_current_deck()["cards"]
	
	if deck_data.is_empty():
		push_warning("Player 0: デッキが空、デフォルトデッキ使用")
		_load_default_deck(player_id)
		return
	
	# 辞書 {card_id: count} を配列に変換
	for card_id in deck_data.keys():
		var count = deck_data[card_id]
		for i in range(count):
			player_decks[player_id].append(card_id)
	
	player_decks[player_id].shuffle()
	print("✅ Player 0: ブック", GameData.selected_deck_index + 1, "読み込み (", player_decks[player_id].size(), "枚)")
```

#### 4.2 プレイヤー1（手動操作CPU用）

```gdscript
func _load_manual_cpu_deck(player_id: int):
	# 暫定: プレイヤー0と同じデッキを使用
	# TODO: 将来的には専用のCPUデッキファイルから読み込む
	var deck_data = GameData.get_current_deck()["cards"]
	
	for card_id in deck_data.keys():
		var count = deck_data[card_id]
		for i in range(count):
			player_decks[player_id].append(card_id)
	
	player_decks[player_id].shuffle()
	print("✅ Player 1: 手動操作CPU用デッキ読み込み (", player_decks[player_id].size(), "枚)")
```

#### 4.3 プレイヤー2-3（デフォルトデッキ）

```gdscript
func _load_default_deck(player_id: int):
	# デフォルトデッキ: ID 1-12 を各3枚
	for card_id in range(1, 13):
		for j in range(3):
			player_decks[player_id].append(card_id)
	
	player_decks[player_id].shuffle()
	print("✅ Player ", player_id, ": デフォルトデッキ読み込み (", player_decks[player_id].size(), "枚)")
```

---

## 影響範囲

### 直接変更が必要なファイル

#### 高優先度（必須変更）
1. **`scripts/card_system.gd`** - コアシステム全体
2. **`scripts/battle/skills/skill_item_return.gd`** - `_return_to_deck()` にplayer_id追加
3. **`scripts/spells/spell_draw.gd`** - 内部で `draw_card_data()` 呼び出し

#### 中優先度（確認・修正）
4. **`scripts/game_flow_manager.gd`** - 初期化とターン処理
5. **`scripts/debug_controller.gd`** - デバッグ用カード追加
6. **`scripts/special_tile_system.gd`** - カードマス処理

#### 低優先度（既に対応済みの可能性）
7. **`scripts/game_flow/spell_phase_handler.gd`**
8. **`scripts/game_flow/item_phase_handler.gd`**

### 変更不要なファイル
- UI系（`scripts/ui_components/*`）: player_id は既に渡されている
- Battle系（`scripts/battle/*`）: CardSystem経由でのみアクセス

---

## 移行手順

### ステップ1: バックアップ
```bash
# 現在のバージョンをコミット
git add .
git commit -m "CardSystem改修前のバックアップ"
git tag "before-multi-deck"
```

### ステップ2: CardSystem の段階的修正

#### 2.1 変数追加（下位互換性維持）
```gdscript
# 新変数を追加（既存変数は残す）
var player_decks = {}
var player_discards = {}

# 既存変数（後で削除）
var deck = []  # DEPRECATED
var discard = []  # DEPRECATED
```

#### 2.2 初期化メソッド修正
```gdscript
func _initialize_deck():
	# 既存の処理を _initialize_decks(1) に移行
	_initialize_decks(1)
	
	# 下位互換のため deck に参照を残す
	deck = player_decks[0]
	discard = player_discards[0]
```

#### 2.3 メソッドの段階的移行
```gdscript
# 新メソッド追加
func draw_card_data_v2(player_id: int) -> Dictionary:
	# 新実装
	pass

# 既存メソッドは新メソッドを呼ぶ
func draw_card_data() -> Dictionary:
	return draw_card_data_v2(0)  # player_id=0 固定
```

### ステップ3: 呼び出し元の修正

1. `spell_draw.gd` を修正
2. `skill_item_return.gd` を修正
3. その他の箇所を順次修正

### ステップ4: 下位互換コードの削除

全ての移行が完了したら：
```gdscript
# 削除
# var deck = []
# var discard = []
# func draw_card_data() -> Dictionary:
```

### ステップ5: テスト
各機能の動作確認（後述のテスト項目参照）

---

## テスト項目

### 🎯 最重要テスト：アイテム復帰機能

#### T0: アイテム復帰（ブック）- 最優先
**テスト方法**:
1. プレイヤー0で「エターナルメイル」(ID: 1005) または「ケンタウロス」(ID: 314) を使用
2. 戦闘でアイテムを使用
3. **確認**: プレイヤー0のデッキの**ランダムな位置**にアイテムが戻っている
4. **確認**: 数ターン後にそのアイテムを再度引ける（次のドローでは引けない）
5. **確認**: プレイヤー1のデッキには影響がない

**期待結果**:
```
【アイテム復帰→ブック】エターナルメイル
→ player_decks[0] のランダムな位置に挿入される
→ player_decks[1] には影響なし
→ 次のドローでは引けない（数ターン後にランダムなタイミングで再ドロー）
```

#### T0-2: アイテム復帰（手札）
**テスト方法**:
1. プレイヤー0で「ソウルレイ」(ID: 1030) または「ブーメラン」(ID: 1054) を使用
2. 戦闘でアイテムを使用
3. **確認**: 即座にプレイヤー0の手札に戻っている
4. **確認**: プレイヤー1の手札には影響がない

**期待結果**:
```
【アイテム復帰→手札】ブーメラン
→ player_hands[0]["data"] に追加される
→ player_hands[1] には影響なし
```

#### T0-3: 敵が復帰アイテムを使った場合
**テスト方法**:
1. プレイヤー1（手動操作CPU）に復帰アイテムを持たせる
2. プレイヤー1で戦闘し、アイテムを使用
3. **確認**: プレイヤー1のデッキ/手札に戻る
4. **確認**: プレイヤー0のデッキ/手札には影響がない

**期待結果**:
```
【アイテム復帰→ブック】（プレイヤー1）
→ player_decks[1] のランダムな位置に挿入される
→ player_decks[0] には影響なし
```

---

### 基本機能テスト

#### T1: デッキ初期化
**優先度**: 高

**テスト箇所**: `CardSystem._initialize_decks()`

**テスト方法**:
```gdscript
# ゲーム開始直後にデバッグコンソールで確認
print("Player 0 deck size: ", card_system.player_decks[0].size())
print("Player 1 deck size: ", card_system.player_decks[1].size())
print("Player 0 first 5 cards: ", card_system.player_decks[0].slice(0, 4))
print("Player 1 first 5 cards: ", card_system.player_decks[1].slice(0, 4))
```

**確認項目**:
- [ ] プレイヤー0のデッキが GameData から正しく読み込まれる（50枚前後）
- [ ] プレイヤー1のデッキが正しく読み込まれる（50枚前後）
- [ ] プレイヤー2-3のデッキがデフォルトで初期化される（36枚）
- [ ] 各デッキが独立している（シャッフル結果が異なる）

#### T2: カードドロー
**優先度**: 高

**テスト箇所**: `CardSystem.draw_card_data()`, `draw_card_for_player()`

**テスト方法**:
```gdscript
# ターン開始時のドロー（複数ターン実施）
# 各プレイヤーの手札を確認
print("Player 0 hand: ", card_system.player_hands[0]["data"])
print("Player 1 hand: ", card_system.player_hands[1]["data"])
```

**確認項目**:
- [ ] プレイヤー0が正しく自分のデッキからドローできる
- [ ] プレイヤー1が正しく自分のデッキからドローできる
- [ ] デッキが空の時、捨て札がシャッフルされて戻る
- [ ] 他プレイヤーのデッキに影響しない

#### T3: カード使用・捨て札
**優先度**: 高

**テスト箇所**: `CardSystem.discard_card()`

**テスト方法**:
```gdscript
# クリーチャー召喚後に確認
print("Player 0 discard: ", card_system.player_discards[0])
print("Player 1 discard: ", card_system.player_discards[1])
```

**確認項目**:
- [ ] 使用したカードが正しいプレイヤーの捨て札に行く
- [ ] 手札から正しく削除される
- [ ] 他プレイヤーの捨て札に混ざらない

---

### 統合テスト

#### T5: 2人対戦（人間 vs 手動CPU）
**優先度**: 最高

**テスト方法**: 実際に2人でプレイ

**確認項目**:
- [ ] 両プレイヤーが独立してデッキ管理される
- [ ] ドローが正しく機能
- [ ] 捨て札が正しく機能
- [ ] **アイテム復帰が正しく動作**（最重要）

**詳細テストシナリオ**:
1. プレイヤー0でケンタウロス + エターナルメイルのコンボ
2. 戦闘でアイテムを使用
3. アイテムが自分のデッキに戻ることを確認
4. 数ターン後にそのアイテムを再度引けることを確認
5. プレイヤー1でも同様のテスト

#### T6: 特殊タイル
**優先度**: 中

**テスト箇所**: カードマス処理

**確認項目**:
- [ ] カードマスで正しいプレイヤーがドローする
- [ ] 各プレイヤーのデッキから正しく引かれる

#### T7: スペルシステム
**優先度**: 中

**テスト箇所**: スペル使用後の捨て札

**確認項目**:
- [ ] スペル使用後、正しいプレイヤーの捨て札に行く
- [ ] SpellDraw系のスペルが正しいデッキからドローする

#### T8: 長期戦テスト
**優先度**: 中

**テスト方法**: 20ターン以上のゲーム

**確認項目**:
- [ ] デッキが空になった時の捨て札リサイクルが正常
- [ ] 各プレイヤーのデッキが独立して機能し続ける
- [ ] メモリリークやエラーが発生しない

---

### テスト実施の優先順位

#### 🔴 Phase 1: 必須テスト（実装完了後すぐ）
1. **T0: アイテム復帰（ブック）** ← 最重要
2. **T0-2: アイテム復帰（手札）** ← 最重要
3. **T1: デッキ初期化**
4. **T2: カードドロー**
5. **T5: 2人対戦**

**所要時間**: 30-45分

#### 🟡 Phase 2: 重要テスト（Phase 1 成功後）
6. **T0-3: 敵が復帰アイテムを使った場合**
7. **T3: カード使用・捨て札**
8. **T6: 特殊タイル**

**所要時間**: 20-30分

#### 🟢 Phase 3: 安定性テスト（時間があれば）
9. **T7: スペルシステム**
10. **T8: 長期戦テスト**

**所要時間**: 30-60分

---

### デバッグ用コマンド活用

テスト時に使える既存のデバッグコマンド:
- **H キー**: 任意のカードを手札に追加（復帰アイテムをすぐ入手）
- **9 キー**: +1000G（アイテムを購入可能に）
- **D キー**: CPU手札表示切替（プレイヤー1の手札確認）

**復帰アイテムのID**:
- 1005: エターナルメイル（ブック復帰）
- 1030: ソウルレイ（手札復帰）
- 1054: ブーメラン（手札復帰）
- 314: ケンタウロス（全アイテムブック復帰）

---

### テスト用デバッグログ追加

実装時に以下のログを追加すると効果的：

```gdscript
# CardSystem.draw_card_data() に追加
func draw_card_data(player_id: int) -> Dictionary:
	print("[DEBUG] Player ", player_id, " drawing from deck (", player_decks[player_id].size(), " cards left)")
	# ...

# SkillItemReturn._return_to_deck() に追加
static func _return_to_deck(player_id: int, item_data: Dictionary) -> bool:
	print("[DEBUG] Returning item ", item_data.get("name"), " to Player ", player_id, "'s deck")
	# ...
```

---

## 実装スケジュール（推定）

| フェーズ | 作業内容 | 推定時間 |
|---------|---------|---------|
| Phase 1 | CardSystem データ構造変更 | 1時間 |
| Phase 2 | メソッドシグネチャ変更 | 1.5時間 |
| Phase 3 | 呼び出し元の修正（50箇所） | 2時間 |
| Phase 4 | デッキロード機能実装 | 1時間 |
| テスト | 動作確認・デバッグ | 1.5時間 |
| **合計** | | **7時間** |

---

## リスクと対策

### リスク1: 見落とした呼び出し元
**対策**: 
- `deck.` と `discard.` をプロジェクト全体で検索
- 段階的移行で下位互換性を維持

### リスク2: セーブデータとの互換性
**対策**: 
- 今回の変更はランタイムのみ
- セーブデータ構造は変更なし（GameData は既存のまま）

### リスク3: バグの混入
**対策**:
- 各Phase ごとにテスト
- Git でこまめにコミット
- 問題があれば前のステップに戻る

---

## 今後の拡張

### CPU デッキ管理（Phase 5）
将来的に以下を実装：
- `data/cpu_decks.json` ファイル作成
- CPUプロファイルとデッキの紐付け
- マップデータでの指定

詳細は `docs/design/cpu_deck_system.md` を参照。

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 2.0 | 2025/11/10 | 初版作成：マルチデッキ化設計 |
| 2.1 | 2025/11/10 | アイテム復帰をランダムな位置への挿入に変更（バランス調整） |

---
