# 汎用アンロックシステム設計

## 概要

ゲーム内のすべての解放要素を**キー方式 + イベント駆動**で統一管理するシステム。
1つのマスターデータ (`unlock_conditions.json`) + 1つのエンジン (`UnlockManager`) に集約する。

## 現状の問題

- 解放条件が各スクリプトにハードコードされている（gacha_system.gd の UNLOCK_CONDITIONS 等）
- キャラクター解放は `unlock_character()` が存在するが呼び出し元がない
- マップの利用可否はファイル名フィルタのみ（解放条件なし）
- モードの解放（`unlocks.modes`）は定義だけで未使用
- 新しい解放対象を追加するたびにスクリプト修正が必要

---

## 設計方針

### 3つの柱

1. **キー方式** - `"character.necromancer"` のようにドット区切りの文字列1本で管理。カテゴリ分岐不要、拡張無限
2. **イベント駆動** - 条件を毎回全チェックしない。「何が起きたか」に応じて該当条件だけ判定
3. **データドリブン** - 解放条件はすべてJSONマスターデータで定義。コード変更不要で拡張可能

### キー方式の利点

```
# カテゴリ方式（弱い）- 対象が増えるたびにコード分岐が増える
{"category": "character", "target_id": "necromancer"}

# キー方式（強い）- 文字列1本、分岐不要、拡張無限
"character.necromancer"
```

チェックも超シンプル:
```gdscript
if UnlockManager.is_unlocked("character.necromancer"):
    # 使える
```

称号、アイコン、イベント、シーズン要素など将来何が増えてもコード変更不要。

### イベント駆動の利点

```gdscript
# NG: 毎回全条件チェック（無駄が多い、何で発火したか不明）
UnlockManager.check_and_unlock()

# OK: 起きたイベントに応じて該当条件だけチェック（効率的、ログと一致）
UnlockManager.on_stage_cleared("stage_1_3")
UnlockManager.on_battle_finished()
UnlockManager.on_purchased("map_volcano_pack")
```

---

## アンロック対象

| プレフィックス | 説明 | キー例 |
|--------------|------|--------|
| `character.` | プレイアブルキャラクター | `character.necromancer`, `character.goblin` |
| `gacha.` | ガチャパック | `gacha.s_gacha`, `gacha.r_gacha` |
| `map.` | ソロバトル・ネット対戦用マップ | `map.cross_1`, `map.volcano` |
| `mode.` | ゲームモード | `mode.net_battle`, `mode.tournament` |
| `world.` | クエストワールド | `world.world_2`, `world.world_3` |
| `feature.` | 機能 | `feature.facility`, `feature.storage` |

※ プレフィックスは規約であり、コード上の分岐には使わない
※ ステージ解放は既存の「前ステージクリアで次を開放」方式を維持（このシステムの対象外）
※ デッキスロットはゴールド/課金石購入のため対象外

---

## マスターデータ定義

### ファイル: `data/master/unlock_conditions.json`

```json
{
  "conditions": [
    {
      "id": "c001",
      "type": "stage_clear",
      "requirement": { "stage_id": "stage_1_3" },
      "unlock": ["character.necromancer"],
      "notification": "ネクロマンサーが使えるようになった！"
    },
    {
      "id": "c002",
      "type": "stage_clear",
      "requirement": { "stage_id": "stage_1_4" },
      "unlock": ["map.cross_1"],
      "notification": "十字型マップが使えるようになった！"
    },
    {
      "id": "c003",
      "type": "stage_clear",
      "requirement": { "stage_id": "stage_1_5" },
      "unlock": ["character.goblin", "mode.net_battle"],
      "notification": "ゴブリンとネット対戦が解禁された！"
    },
    {
      "id": "c004",
      "type": "stage_clear",
      "requirement": { "stage_id": "stage_1_8" },
      "unlock": ["gacha.s_gacha", "world.world_2"],
      "notification": "Sガチャとワールド2が解禁された！"
    },
    {
      "id": "c005",
      "type": "stage_clear",
      "requirement": { "stage_id": "stage_2_8" },
      "unlock": ["gacha.r_gacha", "world.world_3"],
      "notification": "Rガチャとワールド3が解禁された！"
    },
    {
      "id": "c006",
      "type": "battle_count",
      "requirement": { "count": 30 },
      "unlock": ["character.bowser"],
      "notification": "クッパが使えるようになった！"
    },
    {
      "id": "c007",
      "type": "purchase",
      "requirement": { "item_id": "map_volcano_pack", "currency": "stone", "price": 500 },
      "unlock": ["map.volcano"],
      "notification": "溶岩マップを購入しました！"
    },
    {
      "id": "c008",
      "type": "purchase",
      "requirement": { "item_id": "character_dark_elf_pack", "currency": "gold", "price": 50000 },
      "unlock": ["character.dark_elf"],
      "notification": "ダークエルフを購入しました！"
    },
    {
      "id": "c100",
      "type": "always",
      "requirement": {},
      "unlock": ["map.diamond_20", "mode.story", "character.hero"],
      "notification": ""
    }
  ]
}
```

**ポイント:**
- `unlock` は配列 — 1条件で複数キーを同時解放
- `c003`: ステージ1-5クリアでゴブリンとネット対戦の両方が解禁
- `c007`, `c008`: ショップ購入で解放（課金石・ゴールド対応）
- `c100`: `always` タイプで初期解放を明示的に定義

---

## 条件タイプ（type）とイベントの対応

| type | requirement | 判定ソース | 発火イベント |
|------|------------|-----------|------------|
| `stage_clear` | `{"stage_id": "stage_1_3"}` | `StageRecordManager.is_cleared()` | `on_stage_cleared()` |
| `battle_count` | `{"count": 30}` | `GameData.player_data.stats.total_battles` | `on_battle_finished()` |
| `win_count` | `{"count": 10}` | `GameData.player_data.stats.wins` | `on_battle_finished()` |
| `card_count` | `{"count": 50}` | `UserCardDB.get_all_obtained_cards().size()` | `on_card_obtained()` |
| `purchase` | `{"item_id": "xxx", "currency": "stone", "price": 500}` | 購入処理成功時 | `on_purchased()` |
| `always` | `{}` | 常にtrue | `_ready()` |

---

## セーブデータ構造

### player_data.unlocks

```gdscript
# 変更後
"unlocks": {
    "stages": [1],          # ステージ解放（既存維持）
    "keys": [               # キー方式の解放済みリスト
        "character.hero",
        "character.necromancer",
        "map.diamond_20",
        "map.volcano",
        "mode.story",
        "gacha.s_gacha"
    ]
}
```

- `keys`: 解放済みキーの配列（文字列のフラットリスト）
- 既存の `character.unlocked` と `unlocks.modes` は `keys` に統合
- 判定は `"xxx" in player_data.unlocks.keys` のみ

---

## UnlockManager クラス設計

### ファイル: `scripts/autoload/unlock_manager.gd`（Autoloadシングルトン）

```gdscript
class_name UnlockManager
extends Node

signal unlocked(keys: Array[String], notification: String)

var _conditions: Array[Dictionary] = []
## type別のインデックス（イベント駆動用）
var _conditions_by_type: Dictionary = {}

func _ready():
    _load_conditions()
    _build_index()
    # always条件を初回に処理
    _process_conditions_by_type("always")

# --- 判定API ---

## キーが解放済みか
func is_unlocked(key: String) -> bool:
    return key in GameData.player_data.unlocks.keys

## プレフィックスに一致する解放済みキー一覧
func get_unlocked_by_prefix(prefix: String) -> Array[String]:
    var result: Array[String] = []
    for key in GameData.player_data.unlocks.keys:
        if key.begins_with(prefix):
            result.append(key)
    return result

# --- イベントハンドラー ---

## ステージクリア時
func on_stage_cleared(stage_id: String) -> Array[Dictionary]:
    return _process_conditions_by_type("stage_clear", "stage_id", stage_id)

## バトル終了時（勝敗問わず）
func on_battle_finished() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    result.append_array(_process_conditions_by_type("battle_count"))
    result.append_array(_process_conditions_by_type("win_count"))
    return result

## カード入手時
func on_card_obtained() -> Array[Dictionary]:
    return _process_conditions_by_type("card_count")

## ショップ購入時
func on_purchased(item_id: String) -> Array[Dictionary]:
    return _process_conditions_by_type("purchase", "item_id", item_id)

# --- 内部処理 ---

## 指定typeの条件をチェックし、達成済みのキーを解放
func _process_conditions_by_type(type: String, filter_key: String = "", filter_value: String = "") -> Array[Dictionary]:
    var newly_unlocked: Array[Dictionary] = []
    var conditions = _conditions_by_type.get(type, [])

    for condition in conditions:
        # 既に全キーが解放済みならスキップ
        if _all_keys_unlocked(condition.unlock):
            continue
        # フィルター条件がある場合、一致するものだけ処理
        if filter_key != "" and str(condition.requirement.get(filter_key, "")) != filter_value:
            continue
        # 条件達成チェック
        if _evaluate(condition):
            var new_keys = _unlock_keys(condition.unlock)
            if not new_keys.is_empty():
                newly_unlocked.append({
                    "id": condition.id,
                    "keys": new_keys,
                    "notification": condition.get("notification", "")
                })
                unlocked.emit(new_keys, condition.get("notification", ""))
    return newly_unlocked

## 条件達成判定
func _evaluate(condition: Dictionary) -> bool:
    var req = condition.requirement
    match condition.type:
        "always":
            return true
        "stage_clear":
            return StageRecordManager.is_cleared(req.stage_id)
        "battle_count":
            return GameData.player_data.stats.total_battles >= req.count
        "win_count":
            return GameData.player_data.stats.wins >= req.count
        "card_count":
            return UserCardDB.get_all_obtained_cards().size() >= req.count
        "purchase":
            return true  # 購入成功時に呼ばれるので常にtrue
        _:
            return false

## キーを解放してセーブ
func _unlock_keys(keys: Array) -> Array[String]:
    var new_keys: Array[String] = []
    for key in keys:
        if key not in GameData.player_data.unlocks.keys:
            GameData.player_data.unlocks.keys.append(key)
            new_keys.append(key)
    if not new_keys.is_empty():
        GameData.save_to_file()
    return new_keys

## type別インデックス構築
func _build_index():
    _conditions_by_type.clear()
    for condition in _conditions:
        var type = condition.type
        if not _conditions_by_type.has(type):
            _conditions_by_type[type] = []
        _conditions_by_type[type].append(condition)
```

---

## 呼び出し側

### ステージクリア時（game_result_handler.gd）

```gdscript
func _process_victory_result():
    # ... 既存処理 ...
    GameData.record_battle_result(true)

    # アンロックチェック
    var newly = UnlockManager.on_stage_cleared(stage_id)
    newly.append_array(UnlockManager.on_battle_finished())
    # newly をリザルト画面に渡して通知表示
```

### バトル敗北時（game_result_handler.gd）

```gdscript
func _process_defeat_result():
    GameData.record_battle_result(false)

    # バトル回数系のアンロックチェック
    var newly = UnlockManager.on_battle_finished()
```

### ショップ購入時（shop.gd）

```gdscript
func _on_purchase_confirmed(item_id: String):
    # 通貨消費処理...
    if success:
        var newly = UnlockManager.on_purchased(item_id)
        # 購入完了 + 解放通知を表示
```

### ガチャ判定（gacha_system.gd）

```gdscript
# 旧: 独自ロジック
func is_gacha_unlocked(type: GachaType) -> bool:
    var required_stage = UNLOCK_CONDITIONS.get(type, "")
    ...

# 新: UnlockManagerに委譲
func is_gacha_unlocked(type_name: String) -> bool:
    return UnlockManager.is_unlocked("gacha." + type_name)
```

### マップ選択（solo_battle_setup.gd）

```gdscript
# 旧: ファイル名フィルタ
if not ("tutorial" in file_name or "test_" in file_name):

# 新: 解放済みマップのみ表示
var unlocked_maps = UnlockManager.get_unlocked_by_prefix("map.")
```

---

## 購入型アンロックの詳細

### フロー

```
ショップ画面
    |
    v
購入可能アイテム一覧表示（unlock_conditions.json の purchase タイプから生成）
    |
    v
プレイヤーが購入ボタンを押す
    |
    v
通貨チェック（gold / stone）
    |
    v
通貨消費 → GameData.spend_gold() or GameData.spend_stone()
    |
    v
UnlockManager.on_purchased("map_volcano_pack")
    |
    v
"map.volcano" が keys に追加される
    |
    v
購入完了通知
```

### ショップでの表示

```gdscript
# purchase型の条件から未購入アイテムを取得
func _get_purchasable_items() -> Array[Dictionary]:
    var items: Array[Dictionary] = []
    for condition in UnlockManager.get_conditions_by_type("purchase"):
        if not UnlockManager._all_keys_unlocked(condition.unlock):
            items.append(condition)
    return items
```

これにより、ショップに並ぶアイテムもJSONで管理できる。

---

## 解放通知フロー

```
イベント発生（ステージクリア / バトル終了 / 購入）
    |
    v
UnlockManager.on_xxx() → 該当条件だけチェック
    |
    v
新規解放あり？ → Array[Dictionary] を返す
    [{"keys": ["character.goblin", "mode.net_battle"],
      "notification": "ゴブリンとネット対戦が解禁された！"}]
    |
    v
呼び出し元で通知表示（リザルト画面 / ショップ画面 / メイン画面）
```

---

## NGパターン（絶対避けること）

- 毎フレーム条件チェック
- 各システムで個別unlockロジック
- if文だらけの条件分岐

---

## 既存システムからの移行

### Phase 1: 基盤（新規実装のみ）

1. `data/master/unlock_conditions.json` マスターデータ作成
2. `scripts/autoload/unlock_manager.gd` Autoload 実装（イベント駆動 + type別インデックス）
3. `project.godot` に UnlockManager Autoload 登録
4. セーブデータに `unlocks.keys` 追加 + 既存データからの移行処理
5. `game_result_handler` にイベント呼び出し追加
6. 解放通知UIの実装

#### Step 4 詳細: セーブデータ移行

`game_data.gd` の `_validate_save_data()` で既存データを `unlocks.keys` に変換する。

```gdscript
# _validate_save_data() に追加
if not player_data.unlocks.has("keys"):
    player_data.unlocks["keys"] = []
    # 既存の character.unlocked を移行
    if player_data.has("character"):
        for char_id in player_data.character.unlocked:
            var key = "character." + char_id
            if key not in player_data.unlocks.keys:
                player_data.unlocks.keys.append(key)
    # always 条件の初期キーも追加
    for initial_key in ["map.diamond_20", "mode.story"]:
        if initial_key not in player_data.unlocks.keys:
            player_data.unlocks.keys.append(initial_key)
```

#### Step 5 詳細: game_result_handler.gd への呼び出し追加

**ファイル**: `scripts/game_flow/game_result_handler.gd`

勝利時 `_process_victory_result()` (L201付近):
```gdscript
# 既存: GameData.record_battle_result(true) の直後に追加
var newly = UnlockManager.on_stage_cleared(stage_id)
newly.append_array(UnlockManager.on_battle_finished())
# newly を result_data に追加してリザルト画面に渡す
```

敗北時 `_process_defeat_result()` (L257付近):
```gdscript
# 既存: GameData.record_battle_result(false) の直後に追加
var newly = UnlockManager.on_battle_finished()
# newly があれば敗北リザルトにも通知データを渡す
```

`result_data` Dictionary に `"unlocked_items": newly` を追加し、リザルト画面に渡す。

---

### Phase 2: 既存移行（段階的に、1つずつ動作確認）

#### 2-1. gacha_system.gd — ガチャ解放判定の委譲

**削除するもの:**
- `UNLOCK_CONDITIONS` 定数 (L34-38) — 解放条件は `unlock_conditions.json` に移動済み
- `is_gacha_unlocked()` メソッド (L59-65) — `UnlockManager.is_unlocked()` に置換
- `get_newly_unlocked_gacha_types()` メソッド (L69-79) — `UnlockManager` のイベント駆動に統合

**変更するもの:**

`pull_single_typed()` (L95) / `pull_multi_10_typed()` (L117):
```gdscript
# 変更前
if not is_gacha_unlocked(type):

# 変更後（GachaType enum → キー文字列のマッピングが必要）
var gacha_key_map = {
    GachaType.NORMAL: "gacha.normal",
    GachaType.S_GACHA: "gacha.s_gacha",
    GachaType.R_GACHA: "gacha.r_gacha"
}
if not UnlockManager.is_unlocked(gacha_key_map[type]):
```

※ マッピング定数は `gacha_system.gd` 内に `GACHA_UNLOCK_KEYS` として定義。

#### 2-2. shop.gd — ガチャボタン表示の委譲

**ファイル**: `scripts/shop.gd`

`_create_gacha_type_buttons()` (L100-130):
```gdscript
# 変更前 (L112)
var is_unlocked = gacha_system.is_gacha_unlocked(type_id)

# 変更後
var gacha_keys = ["gacha.normal", "gacha.s_gacha", "gacha.r_gacha"]
var is_unlocked = UnlockManager.is_unlocked(gacha_keys[type_id])
```

ロック時の解放条件テキスト (L120-125) も変更:
```gdscript
# 変更前: ハードコードされた "1-8" / "2-8"
var unlock_stage = ""
if type_id == 1:
    unlock_stage = "1-8"
elif type_id == 2:
    unlock_stage = "2-8"

# 変更後: unlock_conditions.json から条件を取得
var condition = UnlockManager.get_condition_for_key(gacha_keys[type_id])
var unlock_text = condition.get("lock_description", "") if condition else ""
```

※ `get_condition_for_key()` は UnlockManager に追加するヘルパー（指定キーを解放する条件を返す）。

#### 2-3. result_screen.gd — ガチャ解禁通知の統合

**ファイル**: `scripts/game_result/result_screen.gd`

**削除するもの:**
- `const GachaSystemScript = preload(...)` (L7) — 不要になる

**変更するもの:**

`show_victory()` (L136-143):
```gdscript
# 変更前: ガチャ専用の解禁チェック
if data.get("is_first_clear", false):
    var stage_id = data.get("stage_id", "")
    var unlocked_list = GachaSystemScript.get_newly_unlocked_gacha_types(stage_id)
    if not unlocked_list.is_empty():
        await get_tree().create_timer(0.5).timeout
        for gacha_name in unlocked_list:
            await _show_unlock_popup(gacha_name)

# 変更後: game_result_handler から渡された統合通知を表示
var unlocked_items = data.get("unlocked_items", [])
if not unlocked_items.is_empty():
    await get_tree().create_timer(0.5).timeout
    for item in unlocked_items:
        if item.notification != "":
            await _show_unlock_popup(item.notification)
```

これにより、ガチャ・キャラクター・マップ・モード等すべての解放通知が統一される。

#### 2-4. game_data.gd — キャラクター解放の統合

**ファイル**: `scripts/game_data.gd`

**方針**: `character.unlocked` と `unlocks.keys` の二重管理を避ける。
`character.selected_id` は GameData に残す（選択状態はアンロックとは別の関心）。
解放判定は UnlockManager に委譲する。

**削除するもの:**
- `player_data.character.unlocked` フィールド — `unlocks.keys` に統合
- `is_character_unlocked()` メソッド — `UnlockManager.is_unlocked("character.xxx")` に置換
- `unlock_character()` メソッド — `UnlockManager` 経由で解放

**変更するもの:**

`select_character()`:
```gdscript
# 変更前
func select_character(char_id: String) -> bool:
    if not is_character_unlocked(char_id):
        return false

# 変更後
func select_character(char_id: String) -> bool:
    if not UnlockManager.is_unlocked("character." + char_id):
        return false
```

`_validate_save_data()`:
```gdscript
# character セクションから unlocked を削除し、selected_id のみ残す
if not player_data.has("character"):
    player_data["character"] = {
        "selected_id": "hero"
    }
```

#### 2-5. status_screen.gd — キャラクター一覧の委譲

**ファイル**: `scripts/status_screen.gd`

キャラクター一覧表示 (L131-133):
```gdscript
# 変更前
var is_unlocked = GameData.is_character_unlocked(char_id)

# 変更後
var is_unlocked = UnlockManager.is_unlocked("character." + char_id)
```

ロック中キャラの解放条件表示も追加可能:
```gdscript
# 既存: btn.text = "%s\n🔒" % char_data.name
# 改善: 解放条件を表示
var condition = UnlockManager.get_condition_for_key("character." + char_id)
var lock_text = condition.get("lock_description", "???") if condition else "???"
btn.text = "%s\n🔒 %s" % [char_data.name, lock_text]
```

#### 2-6. world_stage_select.gd — ワールド解放判定の委譲

**ファイル**: `scripts/quest/world_stage_select.gd`

**方針**: ワールド解放は「前ワールド最終ステージクリア」という連鎖条件。
これは `unlock_conditions.json` の `stage_clear` タイプで表現できるが、
ステージ順序の連鎖解放（前ステージクリアで次を開放）は既存方式を維持する（設計書で対象外と明記済み）。

**変更するもの:**

`_is_world_unlocked()` (L117-127):
```gdscript
# 変更前: 前ワールド最終ステージのクリア判定を直接実装
func _is_world_unlocked(world_index: int) -> bool:
    if world_index == 0:
        return true
    var prev_world = worlds[world_index - 1]
    ...
    return StageRecordManager.is_cleared(last_stage_id)

# 変更後: UnlockManager に委譲
func _is_world_unlocked(world_index: int) -> bool:
    if world_index == 0:
        return true
    var world_id = worlds[world_index].id  # "world_2", "world_3" 等
    return UnlockManager.is_unlocked("world." + world_id)
```

※ `unlock_conditions.json` に対応する条件を追加:
```json
{"id": "c004", "type": "stage_clear", "requirement": {"stage_id": "stage_1_8"},
 "unlock": ["gacha.s_gacha", "world.world_2"], ...}
```

**注意**: ステージ内の連鎖解放（1-1クリア→1-2解放）は `_is_stage_unlocked()` で
`StageRecordManager.is_cleared()` を直接使う既存方式を維持。UnlockManager の対象外。

---

### Phase 3: 拡張

10. ショップ購入型アンロックの実装
11. 各キャラクター・マップの具体的な解放条件を設定
12. 解放条件UIの追加（「あと○○で解禁」表示）

---

## UnlockManager 追加ヘルパー（Phase 2 で必要になるもの）

Phase 2 の移行で、ロック中アイテムの解放条件テキストを表示するためのヘルパーが必要:

```gdscript
## 指定キーを解放する条件を返す（ロック理由表示用）
func get_condition_for_key(key: String) -> Dictionary:
    for condition in _conditions:
        if key in condition.unlock:
            return condition
    return {}

## 指定typeの条件一覧を返す（ショップ表示用）
func get_conditions_by_type(type: String) -> Array[Dictionary]:
    return _conditions_by_type.get(type, [])

## 指定キーが全て解放済みか
func _all_keys_unlocked(keys: Array) -> bool:
    for key in keys:
        if key not in GameData.player_data.unlocks.keys:
            return false
    return true
```

---

## 移行時の注意事項

### `unlock_conditions.json` に必要な追加フィールド

ロック中の表示テキスト用に `lock_description` を追加:
```json
{
    "id": "c002", "type": "stage_clear",
    "requirement": {"stage_id": "stage_1_4"},
    "unlock": ["map.cross_1"],
    "notification": "十字型マップが使えるようになった！",
    "lock_description": "ステージ1-4クリアで解禁"
}
```

### 二重管理の回避

- `character.unlocked`（GameData）と `unlocks.keys`（UnlockManager）が共存する期間を最小化する
- Phase 2-4 完了後、`character.unlocked` は完全削除
- 移行中は `_validate_save_data()` で `character.unlocked` → `unlocks.keys` への一方向変換を行う

### 既存セーブデータの互換性

- `unlocks.keys` が存在しない古いセーブデータは `_validate_save_data()` で自動生成
- `character.unlocked` が存在する場合は `unlocks.keys` にマージ後、`character.unlocked` を削除
