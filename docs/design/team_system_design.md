# チームシステム設計

**プロジェクト**: カルドセプト風カードバトルゲーム
**バージョン**: 2.0
**作成日**: 2026年2月21日
**ステータス**: 設計完了（v2: Team概念導入）

---

## 目次

1. [設計思想](#設計思想)
2. [アーキテクチャ](#アーキテクチャ)
3. [チームルール仕様](#チームルール仕様)
4. [データ構造](#データ構造)
5. [ゲームフロー影響箇所](#ゲームフロー影響箇所)
6. [CPU AI への影響](#cpu-ai-への影響)
7. [ネット対戦対応](#ネット対戦対応)
8. [後方互換性](#後方互換性)
9. [実装フェーズ](#実装フェーズ)
10. [関連ドキュメント](#関連ドキュメント)

---

## 設計思想

### 何をやるか

**「2対2を実装する」のではなく、「ゲームの単位をプレイヤーからチームへ一段上げる」。**

### 現状の構造（変更前）

- ゲームはプレイヤーの集合
- 勝敗判定はプレイヤー単位
- 資産はプレイヤー単位
- 敵味方判定は ID 直接比較

### 目指す構造（変更後）

- ゲームはチームの集合
- 勝敗判定はチーム単位
- 資産はチーム合算で判定
- 敵味方判定はチーム経由

### 責務の分離

**プレイヤーの責務**:
- 自分の資産（EP、土地、魔法石）
- 自分の状態（位置、刻印、バフ）
- 自分が所属しているチーム参照（`team_id` のみ）

**チームの責務**:
- メンバー一覧を持つ
- チーム合計資産を計算する
- チームが全滅したか判定する
- 2人のプレイヤーが味方かどうか判定する
- 将来: チームスキル、共有効果

**ゲームフローの責務**:
- 生存しているチームが1つなら終了
- ターン順はプレイヤー順のまま（変更なし）

### この設計の利点

| モード | 表現 |
|--------|------|
| 1対1 | チーム2つ、メンバー1人ずつ |
| 2対2 | チーム2つ、メンバー2人ずつ |
| 1対1対1対1 (FFA) | チーム4つ、メンバー1人ずつ |
| 3対1 | チーム2つ、メンバー3人と1人 |
| 全員協力 | チーム1つ、全員メンバー |

ゲームの構造が変わらない。これが「抽象化できている状態」。

### ターン順

- **現行のプレイヤーインデックス順のまま**（0→1→2→3）
- TeamSystem にターン管理の責務は持たせない
- ネット対戦時のランダム化はネットワーク層で別途対応

---

## アーキテクチャ

### 新規クラス

```
TeamData (RefCounted) — チームの状態と計算
├── team_id: int
├── members: Array[int]  # 固定配列（ゲーム中に変更しない）
└── has_member(player_id) -> bool

TeamSystem (Node) — チーム管理と判定の一元化（Source of Truth）
├── _teams: Array[TeamData]
├── _player_team_map: Dictionary  # player_id → TeamData（唯一の真実）
├── _player_system: PlayerSystem
├── setup_teams(teams_array, player_system)
├── are_allies(id_a, id_b) -> bool
├── get_team_for_player(player_id) -> TeamData
├── get_team_members(player_id) -> Array[int]
├── get_team_total_assets(player_id) -> int
├── get_surviving_teams() -> Array[TeamData]  # player_system.is_alive() で生存判定
├── is_game_over() -> bool
└── has_teams() -> bool

PlayerSystem — TeamSystem への委譲のみ
├── var team_system: TeamSystem = null
├── is_same_team(a, b) -> bool  # team_system.are_allies() に委譲
└── is_alive(player_id) -> bool  # 生存判定（EP > 0 かつ脱落フラグなし）
```

**注意**: `PlayerData.team_id` は持たない。チーム所属情報の唯一の真実は
`TeamSystem._player_team_map` であり、二重管理を避ける。
チーム情報が必要な場合は `team_system.get_team_for_player(id)` で取得する。

### 既存クラスへの変更

```
PlayerData — 変更なし（team_id は持たない）
  ※ チーム所属は TeamSystem._player_team_map が唯一の真実

PlayerSystem — TeamSystem への委譲 + 生存判定を提供
├── var team_system: TeamSystem = null  # 追加
├── is_same_team(a, b) -> bool  # 追加（team_system.are_allies() に委譲）
└── is_alive(player_id) -> bool  # 追加（生存判定）
```

### ツリー構造上の配置

```
GameSystemManager
├── PlayerSystem (既存)
├── TeamSystem (新規、PlayerSystemの兄弟)
├── BoardSystem3D (既存)
├── ...
```

TeamSystem は GSM が生成し、PlayerSystem と同レベルに配置する。

### 判定ロジックの一元化

**Source of Truth は TeamSystem**。

`player_system.is_same_team(a, b)` は便宜メソッドで、内部では `team_system.are_allies(a, b)` に委譲する。
これにより:
- 既存の25+箇所は `player_system.is_same_team()` を呼ぶ（注入変更なし）
- 判定ロジックは TeamSystem の1箇所に集約
- 将来「条件付き同盟」「一時的敵対」は TeamSystem だけ変えればよい

チーム合算TEP・勝利判定など **チームレベルの操作** は `team_system` を直接使用する。

### アクセスパターン

| ファイル種別 | team_system アクセス | is_same_team アクセス |
|-------------|--------------------|--------------------|
| Node（Handler系） | 不要（チーム判定は player_system 経由） | `player_system.is_same_team()` |
| Node（勝利判定系） | `team_system` を直接注入 | - |
| static ヘルパー | 不要 | `board_system.get_meta("player_system")` 経由 |
| RefCounted | 不要 | `systems.get("player_system")` 経由 |
| CPU AI | 不要 | `_context.player_system` 経由 |

**例外**: `lap_system.gd` と `game_result_handler.gd` は勝利判定にチーム合算TEPを使うため、
`team_system` を直接参照する（player_system 経由のチェーンではなく直接注入）。

---

## チームルール仕様

### 同盟の土地

- **通行料**: なし（自分の土地と同様の扱い）
- **バトル**: 発生しない（自分の土地と同様の扱い）
- **クリーチャー召喚**: 不可（自分の土地と同じ制限）

### 連鎖ボーナス

- **チーム合算**: 同盟メンバーの同属性タイルも連鎖にカウント
  - 例: プレイヤー火2 + 同盟CPU火2 = 火連鎖4
- **敵チームも同様**: 敵チームの連鎖もチーム合算で計算される
- 修正箇所: `tile_data_manager.gd` `get_element_chain_count()` L291

### バトルスキル

- **鼓舞（Support）**: `owner_match` 条件を `is_same_team()` に拡張 → 同盟のクリーチャーも鼓舞対象
  - 修正箇所: `skill_support.gd` L169
- **加勢（Assist）**: 手札からの使用のため変更不要（自分の手札 = 自分のクリーチャー）

### UI表示

- **チームカラー**: 同盟メンバーは同じプレイヤーカラーを共有
  - タイル所有色: チームで統一
  - プレイヤー駒: 番号や形状で個別に区別
- **実装優先度**: コアロジック完成後に対応

### 勝利条件

| 勝利タイプ | 判定方法 |
|----------|--------|
| チェックポイント通過 | `team_system.get_team_total_assets()` が目標 EP 以上で勝利 |
| ターン制限終了 | チーム合算 TEP が最も高いチームが勝利 |

### 破産処理

- **破産判定**: 個人EP < 0 で発動（チーム合算ではない）
- **チーム敗北ではない**: 破産は個人リセット、チームは続行
- **売却対象**: 自分の土地 + 同盟の土地
  - **プレイヤー**: UIで自分 + 同盟の土地を表示、選択可能
  - **CPU**: 自分の土地を優先売却 → 足りなければ同盟の土地を売却
- **EP加算先**: 売却EPは破産中のプレイヤーに加算（土地の所有者ではない）

### スペル・刻印システム

- **プレイヤー（人間）**: 同盟相手にもスペル・刻印を自由にかけられる（制限なし）
- **CPU AI 挙動**: 以下の2つの仕組みでチーム対応

#### (A) 刻印スペルの分類（既存）
- 判定ソース: `cpu_spell_target_selector.gd` の `BENEFICIAL_CURSE_EFFECTS` / `HARMFUL_CURSE_EFFECTS` 定数
- **有利な刻印**: 自分 + 同盟のクリーチャーにかける
- **不利な刻印**: 敵のみ。同盟にはかけない

#### (B) 非刻印スペルの `cpu_rule.target_condition`（既存）
- 各スペルの `cpu_rule.target_condition` でCPUの対象を制御
- **チーム対応**: `own_creature` = 自分 + 同盟、`enemy_creature` = 敵のみ（同盟除外）

### ドミニオオーダー（ドミニオコマンド）

#### EP負担の原則（ネット対戦にも適用）

**コマンドのEP負担は、土地の所有者ではなく「コマンドを実行したプレイヤー」が支払う。**

#### 操作権限

| 操作者 | 自分の土地 | 同盟の土地 | 備考 |
|--------|-----------|-----------|------|
| プレイヤー（人間） | ○ 全コマンド | ○ 全コマンド | EP は操作者負担 |
| CPU | ○ 全コマンド | × 操作しない | 変更不要（現状維持） |

#### 全コマンドの同盟土地での挙動

| コマンド | 挙動 |
|---------|------|
| レベルアップ | 操作者がEP支払い。土地 `owner_id` は同盟のまま |
| 属性変更 | 操作者がEP支払い。土地 `owner_id` は同盟のまま |
| クリーチャー交換 | 操作者の手札から配置。同盟の元クリーチャーは操作者の手札に入る |
| 移動 | 移動先の `owner_id` は移動元の所有者（同盟）になる。移動元は空き地化 |

#### 着地・移動侵略

- **同盟の土地への着地**: バトル不発生（自分の土地と同様の扱い、召喚不可）
- **移動侵略**: 同盟の土地は移動先候補から除外（敵地移動・隣接敵地移動スキル等）

---

## データ構造

### 4.1 TeamData（新規クラス）

```gdscript
## チームデータ — メンバー管理と基本判定
class_name TeamData
extends RefCounted

var team_id: int = -1
var members: Array[int] = []  # 固定配列（ゲーム中に変更しない）

func has_member(player_id: int) -> bool:
	return player_id in members
```

TeamData はデータと基本判定のみ。計算・生存判定ロジックは TeamSystem に置く。
`members` は固定配列であり、脱落・破産してもメンバーからは消えない。
生存判定は TeamSystem が `player_system.is_alive()` を使って行う。

### 4.2 TeamSystem（新規クラス）

```gdscript
## チーム管理システム — 敵味方判定・勝利判定の一元化
class_name TeamSystem
extends Node

var _teams: Array[TeamData] = []
var _player_team_map: Dictionary = {}  # player_id → TeamData（高速逆引き）
var _player_system: PlayerSystem = null

## チームをセットアップ
## teams_array: [[0, 2], [1]] 形式
func setup_teams(teams_array: Array, player_system: PlayerSystem) -> void:
	_player_system = player_system
	_teams.clear()
	_player_team_map.clear()

	for team_index in range(teams_array.size()):
		var team = TeamData.new()
		team.team_id = team_index
		for player_id in teams_array[team_index]:
			if player_id >= 0 and player_id < player_system.players.size():
				team.members.append(player_id)
				_player_team_map[player_id] = team
				# ※ PlayerData.team_id は持たない — _player_team_map が唯一の真実
		_teams.append(team)

## チームが存在するか
func has_teams() -> bool:
	return not _teams.is_empty()

## 2人のプレイヤーが同盟か
func are_allies(player_id_a: int, player_id_b: int) -> bool:
	if player_id_a == player_id_b:
		return true  # 自分自身は常に味方
	if not _player_team_map.has(player_id_a) or not _player_team_map.has(player_id_b):
		return false  # チーム未割り当て = 味方ではない
	return _player_team_map[player_id_a] == _player_team_map[player_id_b]

## プレイヤーのチームを取得
func get_team_for_player(player_id: int) -> TeamData:
	return _player_team_map.get(player_id, null)

## プレイヤーの同チームメンバーを取得（自分含む）
func get_team_members(player_id: int) -> Array[int]:
	var team = get_team_for_player(player_id)
	if team:
		return team.members
	return [player_id]  # チームなし = 自分だけ

## チーム合算TEPを計算
func get_team_total_assets(player_id: int) -> int:
	if not _player_system:
		return 0
	var team = get_team_for_player(player_id)
	if not team:
		return _player_system.calculate_total_assets(player_id)
	var total: int = 0
	for member_id in team.members:
		total += _player_system.calculate_total_assets(member_id)
	return total

## 生存チーム一覧（生存プレイヤーが1人以上いるチーム）
## members は固定配列のため、player_system.is_alive() で実際の生存を確認する
func get_surviving_teams() -> Array[TeamData]:
	var surviving: Array[TeamData] = []
	for team in _teams:
		for member_id in team.members:
			if _player_system and _player_system.is_alive(member_id):
				surviving.append(team)
				break  # 1人でも生存していればチーム生存
	return surviving

## ゲーム終了判定（生存チームが1つ以下）
func is_game_over() -> bool:
	return get_surviving_teams().size() <= 1
```

### 4.3 PlayerData

**変更なし。`team_id` は持たない。**

チーム所属情報は `TeamSystem._player_team_map` が唯一の真実。
PlayerData に `team_id` を持たせると二重管理になり、「どっちが正しい？」問題が発生する。
チーム情報が必要な場合は `team_system.get_team_for_player(id)` で取得する。

### 4.4 PlayerSystem への追加

```gdscript
# player_system.gd に追加

## TeamSystem参照（便宜メソッド用）
var team_system: TeamSystem = null

## 2人のプレイヤーが同じチームか（TeamSystemへの委譲）
## 25+箇所の既存アクセスパターンを維持するための便宜メソッド
func is_same_team(player_id_a: int, player_id_b: int) -> bool:
	if not team_system or not team_system.has_teams():
		return player_id_a == player_id_b  # FFA: 自分自身のみ味方
	return team_system.are_allies(player_id_a, player_id_b)

## プレイヤーが生存しているか（破産・脱落判定）
func is_alive(player_id: int) -> bool:
	if player_id < 0 or player_id >= players.size():
		return false
	return players[player_id].magic_power >= 0
	# 将来: 脱落フラグ（ネット対戦切断等）も考慮する
```

**設計原則**:
- `is_same_team()` のロジックは TeamSystem に集約（Source of Truth）
- PlayerSystem は委譲するだけ
- `has_teams() == false`（FFA）のとき: `player_id_a == player_id_b`（自分自身のみ味方）
- `team_system == null`（未初期化）のとき: 同上
- TeamSystem が null かどうかではなく、`has_teams()` で分岐するのが意味的に正しい

### 4.5 ステージ JSON 形式

```json
{
  "id": "stage_2_7",
  "name": "迷路のクレリック",
  "teams": [[0, 2], [1]],
  "quest": {
	"enemies": [...]
  }
}
```

| シナリオ | teams 配列 | 説明 |
|--------|-----------|------|
| ユーザー単独、CPU1・2同盟 | `[[0], [1, 2]]` | ユーザーvs同盟チーム |
| ユーザー・CPU2同盟、CPU1敵 | `[[0, 2], [1]]` | ユーザーチームvsCPU1 |
| 全員同盟（協力モード） | `[[0, 1, 2]]` | 協力プレイ |
| Free-for-all（従来型） | 未指定 | TeamSystem 未初期化、全員敵 |

---

## ゲームフロー影響箇所

### 初期化フロー

```
GSM.setup_systems()
  ├── PlayerSystem 生成（既存）
  ├── TeamSystem 生成（新規）
  ├── PlayerSystem.team_system = team_system（参照注入）
  └── ...

quest_game._apply_stage_settings()
  ├── var teams = stage_loader.get_teams()
  └── if not teams.is_empty():
		team_system.setup_teams(teams, player_system)
```

### 変更一覧

| 処理 | ファイル | 呼び出し | 変更内容 |
|------|---------|---------|---------|
| **チーム初期化** | `game_system_manager.gd` | — | TeamSystem 生成・参照注入 |
| **チーム割り当て** | `quest_game.gd` | `team_system.setup_teams()` | ステージデータからチーム設定 |
| **ステージ読み込み** | `stage_loader.gd` | `get_teams()` | teams フィールド取得 |
| **通行料判定** | `toll_payment_handler.gd` | `player_system.is_same_team()` | 同盟の土地は通行料免除 |
| **着地時敵判定** | `tile_action_processor.gd` | `player_system.is_same_team()` | 同盟の土地はバトルなし |
| **ターゲット選択** | `target_finder.gd` | `player_system.is_same_team()` | own/enemy フィルタ拡張（3箇所） |
| **移動先敵判定** | `movement_helper.gd` | `player_system.is_same_team()` | 同盟を敵から除外（3箇所） |
| **移動確定時敵判定** | `land_action_helper.gd` | `player_system.is_same_team()` | 同盟を敵から除外 |
| **ドミニオ土地選択** | `land_selection_helper.gd` | `player_system.is_same_team()` | プレイヤーのみ同盟土地も選択可能 |
| **連鎖ボーナス** | `tile_data_manager.gd` | `player_system.is_same_team()` | チーム合算連鎖 |
| **鼓舞スキル** | `skill_support.gd` | `player_system.is_same_team()` | 同盟クリーチャーも鼓舞対象 |
| **勝利判定** | `lap_system.gd` | `team_system.get_team_total_assets()` | チーム合算TEP |
| **順位決定** | `game_result_handler.gd` | `team_system.get_team_total_assets()` | チーム合算TEPで順位 |
| **破産処理** | `bankruptcy_handler.gd` | `player_system.is_same_team()` | 同盟土地の売却対応 |
| **CPU AI（共通）** | `cpu_target_resolver.gd` | `player_system.is_same_team()` | ヘルパー根元修正 |
| **CPU AI（個別）** | 6ファイル | `player_system.is_same_team()` | 敵味方判定修正 |
| **ミスティックアーツAI** | `cpu_mystic_arts_ai.gd` | `player_system.is_same_team()` | 独自判定7箇所修正 |

### target_finder.gd（プレイヤーUI + CPU 共通の中核）

プレイヤーのスペルターゲット選択UIとCPUのターゲットフィルタリングは、
`target_finder.gd` の `owner_filter` 判定を共有している。ここを修正すれば両方に波及。

**修正箇所 3箇所**:

#### クリーチャーターゲット（L156-160）
```gdscript
# 変更前
if owner_filter == "own" and tile_owner != current_player_id:
if owner_filter == "enemy" and (tile_owner == current_player_id or tile_owner < 0):

# 変更後
var _ps = systems.get("player_system")
if owner_filter == "own" and tile_owner != current_player_id:
	if not (_ps and _ps.is_same_team(current_player_id, tile_owner)):
		continue
if owner_filter == "enemy" and (tile_owner < 0 or tile_owner == current_player_id or (_ps and _ps.is_same_team(current_player_id, tile_owner))):
	continue
```

#### 土地ターゲット（L361-364）、プレイヤーターゲット（L300-303）も同様のパターン。

**注意**: `is_same_team()` は FFA 時に `player_id_a == player_id_b` を返すため、
自分自身のマッチは自動的にカバーされる。追加の `tile_owner == current_player_id` チェックは不要。

### 破産処理の詳細

```gdscript
# sell_land() の EP加算先を変更可能にする
func sell_land(tile_index: int, ep_recipient_id: int = -1) -> int:
	# ...
	var recipient = ep_recipient_id if ep_recipient_id >= 0 else owner_id
	player_system.add_magic(recipient, value)

# CPU破産：自分の土地を優先、不足時に同盟の土地を売却
func process_cpu_bankruptcy(player_id: int):
	# 1. まず自分の土地を売却
	while check_bankruptcy(player_id):
		var own_lands = board_system.get_player_owned_tiles(player_id)
		if own_lands.is_empty():
			break
		var best = _select_land_to_sell_cpu(player_id, own_lands)
		sell_land(best, player_id)

	# 2. まだ破産なら同盟の土地を売却
	while check_bankruptcy(player_id):
		var allied_lands = _get_allied_lands(player_id)
		if allied_lands.is_empty():
			break
		var best = _select_land_to_sell_cpu(player_id, allied_lands)
		sell_land(best, player_id)
```

### ドミニオコマンドの詳細

#### tile_action_processor.gd（着地時の敵判定、L179-198）

```gdscript
# 変更前
elif tile_info["owner"] == player_index:
	show_summon_ui_disabled()

# 変更後
elif tile_info["owner"] == player_index or player_system.is_same_team(player_index, tile_info["owner"]):
	show_summon_ui_disabled()
```

#### movement_helper.gd（移動先候補の敵判定、3箇所）

```
関数                              行    現在の敵判定                              チーム対応
────────────────────────────────────────────────────────────────────────────────────────
_get_adjacent_enemy_tiles()       L171  owner_id != -1 and owner_id != player_id  + and not is_same_team()
_get_enemy_tiles_by_condition()   L310  owner_id == -1 or owner_id == player_id   + or is_same_team()（skipに追加）
_filter_invalid_destinations()    L356  owner_id == current_player_id（自分skip）  + or is_same_team()
```

#### land_action_helper.gd（移動確定時の敵判定、L353-409）

```gdscript
# 変更前
elif dest_owner == current_player_index:
	# 自分の土地 → エラー

# 変更後
elif dest_owner == current_player_index or player_system.is_same_team(current_player_index, dest_owner):
	# 自分 or 同盟の土地 → エラー（移動先候補から除外済みなので通常到達しない）
```

#### land_selection_helper.gd（プレイヤーのドミニオ土地選択）

```gdscript
# get_player_owned_lands() L93
# 変更前
if tile.owner_id == player_id:

# 変更後（player_system は board_system.get_meta() 経由）
var _ps = board_system.get_meta("player_system") if board_system and board_system.has_meta("player_system") else null
if tile.owner_id == player_id or (_ps and _ps.is_same_team(player_id, tile.owner_id)):
```

CPU側（`cpu_territory_ai._get_own_lands()`）は `tile.owner_id == player_id` で変更不要。

---

## CPU AI への影響

### 修正方針: ヘルパー関数の根元修正

CPU AI の敵味方判定は `cpu_target_resolver.gd` のヘルパー関数に集約されている。
**根元を修正すれば全体に波及する。**

### cpu_target_resolver.gd の修正対象

| ヘルパー関数 | 現状 | チーム対応 |
|-------------|------|-----------|
| `_get_creatures_by_owner("enemy")` | `owner_id != player_id` | `not player_system.is_same_team()` |
| `_get_creatures_by_owner("own")` | `owner_id == player_id` | `player_system.is_same_team()` |
| `_get_creatures_by_elements(elems, "enemy")` | 敵のみ | 同盟を除外 |
| `_get_enemies_with_*()` 系（6関数） | 敵プレイヤーのみ | 同盟を除外 |
| `_get_killable_targets()` | 敵のみ | 同盟を除外 |

**変更パターン**:
```gdscript
# 変更前
if owner_id != player_id:
# 変更後
if not player_system.is_same_team(player_id, owner_id):
```

`player_system.is_same_team()` は `player_id_a == player_id_b` のとき
TeamSystem 経由で true を返すため、自分自身の判定も正しく動作する。

### 個別修正が必要な CPU AI ファイル

| ファイル | 箇所数 | 内容 |
|---------|--------|------|
| cpu_movement_evaluator.gd | 4 | タイル安全性評価 |
| cpu_territory_ai.gd | 2 | 侵略評価・移動先評価 |
| cpu_spell_ai.gd | 4 | スペル使用判断 |
| cpu_board_analyzer.gd | 4 | 盤面分析 |
| cpu_holy_word_evaluator.gd | 2 | ホーリーワード評価 |
| cpu_spell_utils.gd | 1 | スペル有益性判定 |

全て `_context.player_system` 経由でアクセス。

### 全体効果スペルの敵存在チェック

```gdscript
# 有害な全体スペルは敵が対象にいる場合のみ使用
if target_type in ["all_creatures", "all_lands"]:
	if _is_harmful_spell(spell_data):
		if not _has_enemy_in_targets(player_id):
			return {"should_use": false, "score": 0.0, "target": null}
	return {"should_use": true, "score": base_score, "target": null}
```

### ミスティックアーツ CPU AI（独立検証）

`cpu_mystic_arts_ai.gd` は `cpu_target_resolver.gd` を通さない独自判定があるため、個別修正が必要:

| 行 | コード | 変更内容 |
|---|--------|---------|
| L437 | `owner_id != player_id` | `not player_system.is_same_team()` |
| L522 | `owner_id == player_id` | `player_system.is_same_team()` |
| L564 | `owner == context.player_id` | 同盟を含める |
| L604 | `owner == context.player_id` | 同上 |
| L631 | `i != player_id` | 同盟を除外 |
| L670 | `i != player_id` | 同盟を除外 |
| L686 | `i != player_id` | 同盟を除外 |

L126（`owner != player_id`）は自分のクリーチャーのアルカナアーツ取得のため変更不要。

---

## ネット対戦対応

### サーバー側の処理

1. **ステージ配信**: サーバーが `teams` フィールドを含むステージ JSON をクライアントに配信
2. **チーム割り当て**: ユーザーが参加時に、サーバーが `setup_teams()` に渡す配列を決定
3. **全クライアント同期**: すべてのクライアントが同じ `teams` 配列を受け取る

### クライアント側の処理

```gdscript
# クライアント側（ネット対戦時）
func setup_multiplayer_game(stage_data: Dictionary) -> void:
	if stage_data.has("teams"):
		team_system.setup_teams(stage_data["teams"], player_system)
```

### クライアント間の同期不要箇所

- **チーム構成**: ステージ JSON から自動決定（同期不要）
- **チーム変更**: ゲーム中は発生しない（固定チーム制）

### プレイヤー脱落・AI引き継ぎ

TeamSystem がチーム構造を一元管理しているため:

- プレイヤー切断 → チームメンバーシップは変わらない
- AI に操作を引き継がせる → `is_cpu` フラグを切り替えるだけ
- チームの土地・資産・連鎖はそのまま維持
- `get_surviving_teams()` が `is_alive()` で生存を正しく判定

「プレイヤーの操作者が変わる」だけで、チーム構造は一切変わらない。
これにより途中参加・途中脱落・AI切り替えが TeamSystem の変更なしで実現可能。

---

## 後方互換性

### teams 未指定ステージの動作

```gdscript
# quest_game.gd
var teams = stage_loader.get_teams()
if not teams.is_empty():
	team_system.setup_teams(teams, player_system)
# teams が未指定 → setup_teams() を呼び出さない
# → TeamSystem._teams は空、has_teams() == false
# → player_system.is_same_team(a, b) は player_id_a == player_id_b を返す
# → 「自分自身のみ味方」= 従来の FFA 動作と同一
```

### 既存ステージ JSON の互換性

- 既存の全ステージ JSON に `teams` フィールドの追加は不要
- `teams` 未指定ステージは自動的に Free-for-all モードで動作

### メソッド互換性

```gdscript
# FFA（team 未初期化）の場合
player_system.is_same_team(a, b)
→ a == b のとき true、それ以外 false（自分自身のみ味方）

team_system.get_team_total_assets(player_id)
→ player_system.calculate_total_assets(player_id) と同値を返す
```

---

## 実装フェーズ

### player_system アクセスパターン（全フェーズ共通）

`is_same_team()` を呼ぶファイルは **全て player_system 経由**（TeamSystem 直接アクセス不要）:

| ファイル | 種別 | player_system アクセス |
|---------|------|----------------------|
| `toll_payment_handler.gd` | Node | ✅ クラス変数（`setup()` で注入済み） |
| `tile_action_processor.gd` | Node | ✅ クラス変数（`setup()` で注入済み） |
| `bankruptcy_handler.gd` | Node | ✅ クラス変数（`setup()` で注入済み） |
| `tile_data_manager.gd` | Node | ❌ **追加必要**（`setup()` で注入） |
| `target_finder.gd` | RefCounted | `systems.get("player_system")` 経由 |
| `movement_helper.gd` | static | `board_system.get_meta("player_system")` 経由 |
| `land_action_helper.gd` | static | `handler.player_system` 経由 |
| `land_selection_helper.gd` | static | `board_system.get_meta("player_system")` 経由 |
| `skill_support.gd` | static | `board_system_ref.get_meta("player_system")` 経由 |
| CPU AI 各ファイル | RefCounted | `_context.player_system` 経由 |

**TeamSystem 直接アクセスが必要なファイル**（勝利判定のみ）:

| ファイル | 用途 | 注入方法 |
|---------|------|---------|
| `lap_system.gd` | チェックポイント勝利判定 | `setup()` で注入 |
| `game_result_handler.gd` | ターン制限勝利判定 | `setup()` で注入 |

---

### Phase 1: 基盤（TeamData + TeamSystem + 初期化）
**難易度: ★☆☆** | 新規2ファイル + 既存4ファイル修正

#### 実装内容

1. **`scripts/team_system.gd`** 新規作成 — TeamData + TeamSystem
2. **`player_system.gd`** — `team_system` 参照追加、`is_same_team()` 委譲メソッド追加、`is_alive()` 追加
3. **`game_system_manager.gd`** — TeamSystem 生成・参照注入
4. **`stage_loader.gd`** — `get_teams()` 追加
5. **`quest_game.gd`** — チーム割り当て呼び出し

#### コード例

**team_system.gd**（新規、上記4.1-4.2のクラス定義を実装）

**player_system.gd**:
```gdscript
# PlayerData クラス — 変更なし（team_id は持たない）

# PlayerSystem クラスに追加
var team_system: TeamSystem = null

func is_same_team(player_id_a: int, player_id_b: int) -> bool:
	if not team_system or not team_system.has_teams():
		return player_id_a == player_id_b  # FFA: 自分自身のみ味方
	return team_system.are_allies(player_id_a, player_id_b)

func is_alive(player_id: int) -> bool:
	if player_id < 0 or player_id >= players.size():
		return false
	return players[player_id].magic_power >= 0
```

**game_system_manager.gd**:
```gdscript
# Phase 0 でシステム生成
var team_system = TeamSystem.new()
team_system.name = "TeamSystem"
game_3d.add_child(team_system)

# PlayerSystem に参照注入
player_system.team_system = team_system
```

**stage_loader.gd**:
```gdscript
func get_teams() -> Array:
	return _stage_data.get("teams", [])
```

**quest_game.gd**:
```gdscript
var teams = stage_loader.get_teams()
if not teams.is_empty():
	team_system.setup_teams(teams, player_system)
```

**規約チェック**:
- ✅ TeamData は RefCounted（プロジェクトのコンテナパターン踏襲）
- ✅ TeamSystem は Node（ツリー構造上 PlayerSystem の兄弟）
- ✅ 依存方向: GSM → TeamSystem → PlayerSystem（上→下）
- ✅ `is_same_team()` は委譲のみ（ロジックは TeamSystem に集約）

テスト: `stage_2_7.json` に `"teams": [[0, 2], [1]]` 追加、起動確認

---

### Phase 2: 通行料・バトル免除
**難易度: ★☆☆** | 2ファイル・2箇所

#### 実装内容

**toll_payment_handler.gd** — 通行料判定に同盟チェック追加:
```gdscript
# 変更前
if tile_owner != current_player_id:
	# 通行料発生

# 変更後
if tile_owner != current_player_id and not player_system.is_same_team(current_player_id, tile_owner):
	# 通行料発生
```

**tile_action_processor.gd** L179-183:
```gdscript
# 変更前
elif tile_info["owner"] == player_index:
	show_summon_ui_disabled()

# 変更後
elif tile_info["owner"] == player_index or player_system.is_same_team(player_index, tile_info["owner"]):
	show_summon_ui_disabled()
```

**規約チェック**:
- ✅ 両ファイルとも `player_system` はクラス変数で注入済み（チェーン不要）
- ✅ 既存の条件分岐に `or` / `and not` を追加するだけ

テスト: 同盟CPUの土地に止まる → 通行料なし・バトルなし

---

### Phase 3: 連鎖ボーナス合算
**難易度: ★☆☆** | 1ファイル・1箇所 + 参照注入

#### 実装内容

**tile_data_manager.gd** — `player_system` 参照を追加注入:
```gdscript
var player_system = null

func setup(p_tile_nodes, p_player_system = null):
	tile_nodes = p_tile_nodes
	player_system = p_player_system
```

**get_element_chain_count()** L291:
```gdscript
# 変更前
if tile.owner_id == owner_id:

# 変更後（is_same_team は FFA 時に a == b を返すため、自分自身も自動マッチ）
if player_system and player_system.is_same_team(owner_id, tile.owner_id):
```

**game_system_manager.gd** — 注入追加:
```gdscript
board_system.tile_data_manager.setup(tile_nodes, player_system)
```

テスト: 同盟と同属性の土地を持つ → 連鎖数が合算される

---

### Phase 4: 勝利条件
**難易度: ★★☆** | 2ファイル

#### 実装内容

**lap_system.gd** — TeamSystem 直接参照でチーム合算:
```gdscript
# team_system 参照を setup() で注入
var team_system: TeamSystem = null

# 変更前
var total_assets = player_system.calculate_total_assets(player_id)

# 変更後
var total_assets = team_system.get_team_total_assets(player_id) if team_system else player_system.calculate_total_assets(player_id)
```

**game_result_handler.gd** — チーム合算TEPで順位決定:
```gdscript
# 同様に team_system 直接参照
var total_assets = team_system.get_team_total_assets(player_id) if team_system else player_system.calculate_total_assets(player_id)
```

テスト: チーム合算TEPが目標到達 → 勝利判定

---

### Phase 5: ターゲット選択（プレイヤー+CPU共通）
**難易度: ★★☆** | 1ファイル・3箇所

（実装方法は「ゲームフロー影響箇所」セクションの target_finder.gd 記述と同じ）

テスト: スペル使用 → 有利スペルが同盟にも使える、有害スペルが同盟を除外

---

### Phase 6: ドミニオコマンド + 移動
**難易度: ★★☆** | 4ファイル

（実装方法は「ゲームフロー影響箇所」セクションの各ファイル記述と同じ）

テスト: ドミニオコマンドで同盟の土地を選択可能、移動侵略が同盟を除外

---

### Phase 7: 破産処理
**難易度: ★★☆** | 1ファイル

（実装方法は「ゲームフロー影響箇所」セクションの破産処理記述と同じ）

テスト: 破産時に同盟の土地も売却選択肢に表示、CPUは自分の土地を優先売却

---

### Phase 8: CPU AI チーム認識（ミスティックアーツ以外）
**難易度: ★★★** | 7+ファイル・20+箇所

（実装方法は「CPU AI への影響」セクションの記述と同じ）

テスト: CPUが同盟を攻撃しない、有利な刻印を同盟にかける、敵のみに有害スペル

---

### Phase 9: ミスティックアーツ CPU AI
**難易度: ★★☆** | 1ファイル・7箇所

（実装方法は「CPU AI への影響」セクションのミスティックアーツ記述と同じ）

テスト:
1. チーム有りステージ → ミスティックアーツが同盟に有害効果を使わない
2. チーム無しステージ → 既存動作と変化なし

---

### Phase 10: バトルスキル（鼓舞）
**難易度: ★☆☆** | 1ファイル・1箇所

**skill_support.gd** L167-170:
```gdscript
# 変更前
elif condition_type == "owner_match":
	if participant.player_id != supporter_player_id:
		return false

# 変更後（is_same_team は FFA 時に自分自身 true を返すため、既存動作を維持）
elif condition_type == "owner_match":
	var _ps = board_system_ref.get_meta("player_system") if board_system_ref and board_system_ref.has_meta("player_system") else null
	if _ps and not _ps.is_same_team(participant.player_id, supporter_player_id):
		return false
	elif not _ps and participant.player_id != supporter_player_id:
		return false  # フォールバック（player_system 未設定時）
```

テスト: 同盟クリーチャーの鼓舞が有効になる

---

### Phase 11: UI（チームカラー）
**難易度: ★★☆** | 要調査

TeamSystem を使ってチームメンバーに同一カラーを割り当て:

```gdscript
func _assign_team_colors():
	if not team_system or not team_system.has_teams():
		return
	# チームごとに最初のメンバーの色を全員に適用
	for team in team_system._teams:
		if team.members.is_empty():
			continue
		var team_color = _get_player_color(team.members[0])
		for member_id in team.members:
			_set_player_color(member_id, team_color)
```

テスト: ボード上で同盟の土地が同色、駒が区別可能

---

### 全体まとめ

| Phase | 内容 | 難易度 | ファイル数 | 依存 |
|-------|------|--------|-----------|------|
| 1 | 基盤（TeamData + TeamSystem） | ★☆☆ | 6 | なし |
| 2 | 通行料・バトル | ★☆☆ | 2 | Phase 1 |
| 3 | 連鎖合算 | ★☆☆ | 1 | Phase 1 |
| 4 | 勝利条件 | ★★☆ | 2 | Phase 1 |
| 5 | ターゲット選択 | ★★☆ | 1 | Phase 1 |
| 6 | ドミニオ+移動 | ★★☆ | 4 | Phase 1,2 |
| 7 | 破産 | ★★☆ | 1 | Phase 1 |
| 8 | CPU AI（一般） | ★★★ | 7+ | Phase 1,5 |
| 9 | ミスティックアーツ | ★★☆ | 1 | Phase 1,5 |
| 10 | バトルスキル | ★☆☆ | 1 | Phase 1 |
| 11 | UI | ★★☆ | 要調査 | Phase 1 |

### 規約遵守サマリー

| 規約項目 | 対応方法 |
|---------|---------|
| チェーンアクセス2段まで | `handler.player_system.is_same_team()` は2段で許容。static ヘルパーは `board_system.get_meta()` で取得 |
| `_` プレフィックス | `_teams`, `_player_team_map`, `_player_system`（TeamSystem内部）、`_get_allied_lands` 等 |
| null チェック | `player_system and player_system.is_same_team()` パターンで統一 |
| 依存方向 | GSM → TeamSystem → PlayerSystem。逆方向参照なし |
| is_connected() | 新規シグナル接続なし（既存シグナルの判定ロジック変更のみ） |
| 後方互換 | FFA 時は `is_same_team(a,b)` が `a == b` を返す（従来動作維持） |
| `set_meta()` パターン | `spell_curse_toll` で使用実績ある既存パターンを踏襲 |
| Source of Truth | チーム所属は `_player_team_map` のみ（PlayerData.team_id なし） |
| | 敵味方判定は TeamSystem に集約。PlayerSystem は委譲のみ |
| 生存判定 | `get_surviving_teams()` は `player_system.is_alive()` で実際の生存を確認 |

---

## 関連ドキュメント

- [quest_system_design.md](quest_system_design.md) - クエストシステム設計
- [toll_system.md](toll_system.md) - 通行料システム
- [cpu_ai_design.md](cpu_ai_design.md) - CPU AI 設計
- [lap_system.md](lap_system.md) - 周回システム

---

**Last Updated**: 2026-02-21（v2.1: 生存判定強化、二重管理解消、FFA動作修正）
