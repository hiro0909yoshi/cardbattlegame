# 秘術システム実装設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**対象ドキュメント**: `docs/design/mystic_arts_system.md`  
**バージョン**: 1.0  
**最終更新**: 2025年11月24日  
**ステータス**: 実装準備完了

---

## 📋 目次

1. [実装戦略](#実装戦略)
2. [Phase 1: 基盤構築](#phase-1-基盤構築)
3. [Phase 2: スペルフェーズ統合](#phase-2-スペルフェーズ統合)
4. [Phase 3: 効果実装](#phase-3-効果実装)
5. [テスト戦略](#テスト戦略)
6. [既知の問題と対策](#既知の問題と対策)

---

## 実装戦略

### 基本方針

1. **既存システムの最大活用**
   - `spell_phase_handler.gd`の既存ロジックを流用
   - `TargetSelectionHelper`を統合
   - `effect_type`は既存のものを使用
   - **ターゲット取得は共通**: `spell_phase_handler._get_valid_targets()`を統一（重複回避）

2. **最小限の新規クラス追加**
   - `SpellMysticArts`クラスのみ新規作成
   - 既存クラスの拡張は最小限（`spell_phase_handler.gd`のみ）

3. **段階的実装**
   - 秘術基盤 → UI統合 → 効果実装 → カード定義

4. **依存関係の最小化**
   - 秘術と通常スペルはデータ構造のみ異なる
   - ロジック（ターゲット取得・効果適用）は共用可能

### アーキテクチャ図

```
GameFlowManager
  └─ spell_phase_handler.gd
	 ├─ _handle_spell_phase()        # 既存：スペル処理
	 ├─ _handle_mystic_arts_phase()  # 新規：秘術処理
	 ├─ _apply_single_effect()       # 共用：効果適用
	 ├─ _get_valid_targets()         # 共用：ターゲット取得（スペル・秘術統一）
	 └─ target_selection_helper      # 共用：ターゲット選択UI
		├─ SpellMysticArts
		├─ SpellLand
		├─ SpellDraw
		└─ ...

SpellMysticArts (新規)
  ├─ get_available_creatures()
  ├─ get_mystic_arts()
  ├─ can_cast_mystic_art()
  ├─ _has_valid_target()           # spell_phase_handler._get_valid_targets()を流用
  ├─ apply_mystic_art_effect()
  └─ _set_caster_down_state()      # 秘術発動後にキャスターをダウン状態に（新規）
```

---

## Phase 1: 基盤構築

### 初期化タイミング（GameSystemManager）

`SpellMysticArts`の初期化は**GameSystemManager.phase_4_setup_system_interconnections()**内で行われます。

**Phase 4-2: GameFlowManager 子システム初期化内**:
```gdscript
# SpellMysticArts の初期化（新規追加）
if game_flow_manager and game_flow_manager.spell_phase_handler:
	game_flow_manager.spell_phase_handler.spell_mystic_arts = SpellMysticArts.new(
		board_system_3d,
		player_system,
		card_system,
		game_flow_manager.spell_phase_handler
	)
	game_flow_manager.spell_phase_handler.spell_mystic_arts.name = "SpellMysticArts"
	game_flow_manager.spell_phase_handler.add_child(game_flow_manager.spell_phase_handler.spell_mystic_arts)
	print("[SpellMysticArts] 初期化完了（GameSystemManager.Phase 4-2）")
```

この方式により、全必要なシステム参照が既に設定されている状態で`SpellMysticArts`が初期化されます。

---

### Step 1-1: SpellMysticArts クラス作成

**ファイル**: `scripts/spells/spell_mystic_arts.gd`

```gdscript
class_name SpellMysticArts
extends Reference

# 参照
var board_system_ref: Reference
var player_system_ref: Reference
var card_system_ref: Reference
var spell_phase_handler_ref: Reference  # ターゲット取得用

func _init(board_sys, player_sys, card_sys, spell_phase_handler):
	board_system_ref = board_sys
	player_system_ref = player_sys
	card_system_ref = card_sys
	spell_phase_handler_ref = spell_phase_handler

# ============ 秘術情報取得 ============

func get_available_creatures(player_id: int) -> Array:
	"""プレイヤーの秘術発動可能クリーチャーを取得"""
	var available = []
	
	for tile in board_system_ref.get_player_tiles(player_id):
		if not tile.creature_data:
			continue
		
		var mystic_arts = tile.creature_data.get("ability_parsed", {}).get("mystic_arts", [])
		if mystic_arts.size() > 0:
			available.append({
				"tile_index": tile.tile_index,
				"creature_data": tile.creature_data,
				"mystic_arts": mystic_arts
			})
	
	return available

func get_mystic_arts_for_creature(creature_data: Dictionary) -> Array:
	"""クリーチャーの秘術一覧を取得"""
	return creature_data.get("ability_parsed", {}).get("mystic_arts", [])

# ============ 発動判定 ============

func can_cast_mystic_art(mystic_art: Dictionary, context: Dictionary) -> bool:
	"""秘術発動可能か判定"""
	
	# 魔力確認
	if context.player_magic < mystic_art.get("cost", 0):
		return false
	
	# スペル未使用確認
	if context.spell_used_this_turn:
		return false
	
	# クリーチャーが行動可能か確認（ダウン状態チェック）
	var caster_tile_index = context.get("tile_index", -1)
	if caster_tile_index != -1:
		var caster_tile = board_system_ref.get_tile(caster_tile_index)
		if caster_tile and caster_tile.is_down():
			return false  # ダウン状態のクリーチャーは秘術使用不可
	
	# ターゲット有無確認
	if not _has_valid_target(mystic_art, context):
		return false
	
	return true

func _has_valid_target(mystic_art: Dictionary, context: Dictionary) -> bool:
	"""有効なターゲットが存在するか確認"""
	var target_type = mystic_art.get("target_type", "")
	var target_filter = mystic_art.get("target_filter", "any")
	
	# セルフターゲットは常に有効
	if target_filter == "self":
		return true
	
	# spell_phase_handler._get_valid_targets() を呼び出して確認
	# スペルと秘術で同じターゲット取得ロジックを共用（重複回避）
	var valid_targets = spell_phase_handler_ref._get_valid_targets(target_type, target_filter)
	
	return valid_targets.size() > 0

# ============ ターゲット取得 ============

# スペルシステムの既存 spell_phase_handler._get_valid_targets() を流用
# 秘術とスペルで同じターゲット取得ロジックを使用して重複を回避

# ============ 効果適用 ============

func apply_mystic_art_effect(mystic_art: Dictionary, 
							 target_data: Dictionary, 
							 context: Dictionary) -> bool:
	"""秘術効果を適用（メインエンジン）"""
	
	var effects = mystic_art.get("effects", [])
	var success = true
	
	for effect in effects:
		var applied = _apply_single_effect(effect, target_data, context)
		if not applied:
			success = false
	
	return success

func _apply_single_effect(effect: Dictionary, 
						  target_data: Dictionary, 
						  context: Dictionary) -> bool:
	"""1つの効果を適用"""
	
	var effect_type = effect.get("effect_type", "")
	
	# 既存のspell_phase_handler.gdの_apply_single_effect()と同じ処理
	# 秘術固有の処理が必要な場合のみここに追加
	
	match effect_type:
		"destroy_deck_top":
			return _apply_destroy_deck_top(effect, target_data, context)
		"curse_attack":
			return _apply_curse_attack(effect, target_data, context)
		# その他は spell_phase_handler に委譲
		_:
			return false

# ============ 秘術専用効果 ============

func _apply_destroy_deck_top(effect: Dictionary, 
							  target_data: Dictionary, 
							  context: Dictionary) -> bool:
	"""効果：デッキ破壊"""
	var target_player_id = target_data.get("player_id", -1)
	var count = effect.get("value", 1)
	
	if target_player_id == -1:
		return false
	
	var destroyed = card_system_ref.destroy_deck_top_cards(target_player_id, count)
	return destroyed == count

func _apply_curse_attack(effect: Dictionary, 
						 target_data: Dictionary, 
						 context: Dictionary) -> bool:
	"""効果：呪いの一撃"""
	var target_tile_index = target_data.get("tile_index", -1)
	var duration = effect.get("duration", 0)
	
	if target_tile_index == -1:
		return false
	
	var tile = board_system_ref.get_tile(target_tile_index)
	if not tile or not tile.creature_data:
		return false
	
	# 呪い効果の追加（effect_system.mdを参照）
	# TODO: 呪いシステム実装後に実装
	
	return true

# ============ ダウン状態管理 ============

func _set_caster_down_state(caster_tile_index: int, board_system_ref: Reference) -> void:
	"""秘術発動後、キャスター（クリーチャー）をダウン状態に設定"""
	
	if caster_tile_index == -1:
		return
	
	var caster_tile = board_system_ref.get_tile(caster_tile_index)
	if not caster_tile:
		return
	
	var creature_data = caster_tile.creature_data
	if not creature_data:
		return
	
	# 不屈スキルで例外処理（ランドシステム仕様に準拠）
	# 不屈を持つクリーチャーはダウン状態にならない
	if _has_unyielding(creature_data):
		print("不屈により、『%s』はダウン状態になりません" % creature_data.get("name", ""))
		return
	
	# ダウン状態を設定
	caster_tile.set_down(true)
	print("『%s』はダウン状態になりました" % creature_data.get("name", ""))

func _has_unyielding(creature_data: Dictionary) -> bool:
	"""不屈スキルを持つか確認（ランドシステム仕様に準拠）"""
	if creature_data.is_empty():
		return false
	var ability_detail = creature_data.get("ability_detail", "")
	return "不屈" in ability_detail

# ============ ユーティリティ ============

func get_mystic_art_info(mystic_art: Dictionary) -> Dictionary:
	"""秘術の情報を整形（UI表示用）"""
	return {
		"name": mystic_art.get("name", ""),
		"description": mystic_art.get("description", ""),
		"cost": mystic_art.get("cost", 0),
		"target_type": mystic_art.get("target_type", ""),
		"effects_count": mystic_art.get("effects", []).size()
	}
```

### Step 1-2: creature_data への秘術フィールド追加

**ファイル**: `scripts/creatures/base_tiles.gd`

```gdscript
# 既存の base_creature_data() に追加
static func base_creature_data() -> Dictionary:
	return {
		# ... 既存フィールド ...
		"ability_parsed": {
			"skills": [],
			"effects": [],
			"keywords": [],
			"mystic_arts": []  # 新規追加：秘術配列
		}
	}
```

### Step 1-3: テスト用のダミー秘術定義

**ファイル**: `data/fire_1.json`（アモン）

```json
{
  "id": 1,
  "name": "アモン",
  "type": "creature",
  "hp": 30,
  "ap": 20,
  "element": "fire",
  "ability_parsed": {
	"skills": [...],
	"mystic_arts": [
	  {
		"id": "mystic_test_001",
		"name": "テスト秘術",
		"description": "テスト用の秘術です",
		"cost": 30,
		"target_type": "creature",
		"target_filter": "enemy",
		"effects": [
		  {
			"effect_type": "damage",
			"value": 15
		  }
		]
	  }
	]
  }
}
```

### Phase 1 テストケース

```gdscript
# test_spell_mystic_arts.gd

func test_get_available_creatures():
	# プレイヤー0のクリーチャーから秘術持ちを取得
	var available = spell_mystic_arts.get_available_creatures(0)
	assert_true(available.size() > 0, "秘術持ちクリーチャーが取得できる")

func test_can_cast_mystic_art():
	var mystic_art = {...}  # テスト用秘術
	var context = {
		"player_magic": 50,
		"spell_used_this_turn": false,
		"tile_index": 5
	}
	
	var can_cast = spell_mystic_arts.can_cast_mystic_art(mystic_art, context)
	assert_true(can_cast, "条件を満たす秘術は発動可能")

func test_has_valid_target():
	var mystic_art = {"target_type": "creature", "target_filter": "enemy"}
	var context = {"player_id": 0}
	
	var has_target = spell_mystic_arts._has_valid_target(mystic_art, context)
	assert_true(has_target, "敵クリーチャーが存在する場合ターゲット有効")

func test_cannot_cast_down_creature():
	# ダウン状態のクリーチャーは秘術不可
	var mystic_art = {...}
	var context = {
		"player_magic": 50,
		"spell_used_this_turn": false,
		"tile_index": 3  # ダウン状態のタイル
	}
	
	# タイル3をダウン状態に設定
	board_system.get_tile(3).set_down(true)
	
	var can_cast = spell_mystic_arts.can_cast_mystic_art(mystic_art, context)
	assert_false(can_cast, "ダウン状態のクリーチャーは秘術発動不可")

func test_unyielding_not_down():
	# 不屈スキル持ちはダウン状態にならない
	var creature_with_unyielding = {
		"name": "シールドメイデン",
		"ability_detail": "不屈"
	}
	
	var tile = board_system.get_tile(5)
	tile.creature_data = creature_with_unyielding
	
	spell_mystic_arts._set_caster_down_state(5, board_system)
	
	assert_false(tile.is_down(), "不屈スキル持ちはダウン状態にならない")
```

---

## Phase 2: スペルフェーズ統合

### ターゲットクリーチャー情報の表示

ターゲットがクリーチャーの場合、選択中にターゲット側のクリーチャー情報を表示します。

**表示項目**（ターゲット側UI）:
- **Current HP**: 現在のHP
- **Max HP**: 最大HP
- **AP**: 攻撃力

これにより、秘術の効果（ダメージ、能力値変更など）の影響を事前に確認できます。

実装例：
```gdscript
# ターゲットクリーチャーの情報取得
if target_type == "creature" and selected_target:
    var target_creature = selected_target.creature_data
    var display_info = {
        "current_hp": target_creature.get("current_hp", 0),
        "max_hp": target_creature.get("hp", 0) + target_creature.get("land_bonus_hp", 0),
        "ap": target_creature.get("ap", 0)
    }
    # UI側で display_info を表示
```

---

### Step 2-1: spell_phase_handler.gd の拡張

**ファイル**: `scripts/game_flow/spell_phase_handler.gd`

```gdscript
# 初期化時に SpellMysticArts を追加
func _init(...):
	# ... 既存 ...
	spell_mystic_arts = SpellMysticArts.new(board_system_ref, player_system_ref, card_system_ref)

# スペルフェーズメインロジック
func _handle_spell_phase() -> void:
	while true:
		var choice = await _show_spell_choice_menu()
		
		match choice:
			"spell":
				await _handle_spell_card_phase()
				break  # スペル使用後は秘術UI非表示化
			"mystic_art":
				await _handle_mystic_arts_phase()
				break  # 秘術使用後はスペルUI非表示化
			"skip":
				break
	
	# スペルフェーズ終了

# 新規：秘術発動フロー
func _handle_mystic_arts_phase() -> void:
	# 1. 発動可能クリーチャー取得
	var available_creatures = spell_mystic_arts.get_available_creatures(current_player_id)
	
	if available_creatures.is_empty():
		ui_manager.show_message("秘術を持つクリーチャーがありません")
		return
	
	# 2. クリーチャー選択
	var selected_creature = await _select_mystic_arts_creature(available_creatures)
	if selected_creature == null:
		return  # キャンセル
	
	# 3. 秘術選択
	var selected_mystic_art = await _select_mystic_art(selected_creature["mystic_arts"])
	if selected_mystic_art == null:
		return  # キャンセル
	
	# 4. 発動判定
	var context = {
		"player_id": current_player_id,
		"player_magic": player_system_ref.get_magic(current_player_id),
		"spell_used_this_turn": spell_used_this_turn,
		"tile_index": selected_creature["tile_index"]
	}
	
	if not spell_mystic_arts.can_cast_mystic_art(selected_mystic_art, context):
		var error = _get_mystic_art_error(selected_mystic_art, context)
		ui_manager.show_message(error)
		return
	
	# 5. ターゲット選択
	var target_data = await _select_mystic_arts_target(selected_mystic_art, context)
	if target_data == null:
		return  # キャンセル
	
	# 6. 秘術実行
	var success = spell_mystic_arts.apply_mystic_art_effect(selected_mystic_art, target_data, context)
	
	if success:
		# 7. 完了処理
		var cost = selected_mystic_art.get("cost", 0)
		player_system_ref.consume_magic(current_player_id, cost)
		spell_used_this_turn = true
		
		# 8. キャスター（秘術を発動したクリーチャー）をダウン状態に設定
		# ランドシステムの仕様に準拠：アクション実行後のダウン状態化
		spell_mystic_arts._set_caster_down_state(selected_creature["tile_index"], board_system_ref)
		
		ui_manager.show_message("『%s』を発動した！" % selected_mystic_art.get("name", ""))
	else:
		ui_manager.show_message("秘術の発動に失敗しました")

# 新規：クリーチャー選択UI
func _select_mystic_arts_creature(available_creatures: Array):
	"""秘術を持つクリーチャーを選択"""
	# UI実装は spell_and_mystic_ui.gd に委譲
	return await ui_manager.spell_and_mystic_ui.select_creature(available_creatures)

# 新規：秘術選択UI
func _select_mystic_art(mystic_arts: Array):
	"""クリーチャーの複数秘術から1つを選択"""
	return await ui_manager.spell_and_mystic_ui.select_mystic_art(mystic_arts)

# 新規：ターゲット選択
func _select_mystic_arts_target(mystic_art: Dictionary, context: Dictionary):
	"""秘術のターゲット選択"""
	var target_type = mystic_art.get("target_type", "")
	var target_filter = mystic_art.get("target_filter", "any")
	
	# セルフターゲット時はUI表示なし
	if target_filter == "self":
		# 発動者（プレイヤー）またはクリーチャーに自動設定
		return {
			"type": target_type,
			"player_id": context.get("player_id"),
			"tile_index": context.get("tile_index")  # クリーチャー自身の場合
		}
	
	# 通常ターゲット選択UI（spell_phase_handlerと同じ方式）
	return await target_selection_helper.select_target(target_type, target_filter)

# 新規：エラーメッセージ取得
func _get_mystic_art_error(mystic_art: Dictionary, context: Dictionary) -> String:
	var cost = mystic_art.get("cost", 0)
	var player_magic = context.get("player_magic", 0)
	
	if player_magic < cost:
		return "魔力が不足しています（%dMP必要、%dMP所有）" % [cost, player_magic]
	
	if context.get("spell_used_this_turn", false):
		return "このターンはスペルを使用済みです"
	
	# クリーチャーがダウン状態か確認
	var caster_tile_index = context.get("tile_index", -1)
	if caster_tile_index != -1:
		var caster_tile = board_system_ref.get_tile(caster_tile_index)
		if caster_tile and caster_tile.is_down():
			return "このクリーチャーはダウン状態です"
	
	return "秘術の発動に失敗しました"

# 新規：スペル・秘術の排他制御
func _show_spell_choice_menu() -> String:
	"""スペル・秘術の選択メニュー"""
	var choices = ["spell", "mystic_art", "skip"]
	var choice = await ui_manager.show_choice_menu(choices)
	return choice
```

### Step 2-2: UI マネージャーの拡張

**ファイル**: `scripts/ui_components/spell_and_mystic_ui.gd`（新規作成）

```gdscript
class_name SpellAndMysticUI
extends Control

signal creature_selected(creature_data)
signal mystic_art_selected(mystic_art)
signal target_selected(target_data)
signal selection_cancelled

# UI要素の参照
var creature_list_ui: ItemList
var mystic_art_list_ui: ItemList
var current_selection_mode: String = ""  # "creature", "mystic_art", "target"

func _ready():
	_create_ui_elements()

func _create_ui_elements():
	"""UI要素を動的作成"""
	
	# クリーチャーリスト
	creature_list_ui = ItemList.new()
	creature_list_ui.item_selected.connect(_on_creature_selected)
	add_child(creature_list_ui)
	
	# 秘術リスト
	mystic_art_list_ui = ItemList.new()
	mystic_art_list_ui.item_selected.connect(_on_mystic_art_selected)
	add_child(mystic_art_list_ui)
	
	_position_ui_elements()

func _position_ui_elements():
	"""UI位置設定（viewport相対）"""
	var viewport_size = get_viewport().get_visible_rect().size
	
	creature_list_ui.position = Vector2(viewport_size.x - 300 - 20, 100)
	creature_list_ui.size = Vector2(300, 200)
	
	mystic_art_list_ui.position = Vector2(viewport_size.x - 300 - 20, 320)
	mystic_art_list_ui.size = Vector2(300, 200)

func select_creature(available_creatures: Array):
	"""クリーチャー選択UI表示"""
	current_selection_mode = "creature"
	creature_list_ui.clear()
	
	for creature in available_creatures:
		var name_text = creature["creature_data"].get("name", "Unknown")
		creature_list_ui.add_item(name_text)
	
	creature_list_ui.visible = true
	
	var selection = await creature_selected
	creature_list_ui.visible = false
	
	return selection

func select_mystic_art(mystic_arts: Array):
	"""秘術選択UI表示"""
	current_selection_mode = "mystic_art"
	mystic_art_list_ui.clear()
	
	for mystic_art in mystic_arts:
		var name_text = "%s [%dMP]" % [
			mystic_art.get("name", "Unknown"),
			mystic_art.get("cost", 0)
		]
		mystic_art_list_ui.add_item(name_text)
	
	mystic_art_list_ui.visible = true
	
	var selection = await mystic_art_selected
	mystic_art_list_ui.visible = false
	
	return selection

func _on_creature_selected(index: int):
	"""クリーチャー選択時"""
	creature_selected.emit(index)

func _on_mystic_art_selected(index: int):
	"""秘術選択時"""
	mystic_art_selected.emit(index)

func hide_all():
	"""全UI非表示"""
	creature_list_ui.visible = false
	mystic_art_list_ui.visible = false
```

### Phase 2 テストケース

```gdscript
func test_spell_mystic_art_exclusivity():
	# スペル使用 → 秘術UI非表示
	await spell_phase_handler._handle_spell_card_phase()
	assert_true(spell_phase_handler.spell_used_this_turn)
	assert_false(ui_manager.spell_and_mystic_ui.mystic_art_list_ui.visible)

func test_mystic_art_then_spell_blocked():
	# 秘術使用 → スペルUI非表示
	await spell_phase_handler._handle_mystic_arts_phase()
	assert_true(spell_phase_handler.spell_used_this_turn)
	# スペルカード選択UIが表示されない
```

---

## Phase 3: 効果実装

### 秘術専用効果

```gdscript
# SpellMysticArts._apply_single_effect() での処理

"destroy_deck_top":
	# 敵のデッキ上1枚を破壊
	card_system_ref.destroy_top_cards(target_player_id, count)

"curse_attack":
	# 敵クリーチャーに呪い付与
	board_system_ref.apply_curse_to_creature(target_tile, curse_type, duration)

"steal_magic":
	# 敵の魔力を奪う
	var stolen = player_system_ref.consume_magic(opponent_id, amount)
	player_system_ref.add_magic(current_player_id, stolen)

"mass_buff":
	# 自分の全クリーチャーを強化
	for tile in board_system_ref.get_player_tiles(current_player_id):
		if tile.creature_data:
			tile.creature_data["base_up_ap"] += bonus_ap
```

### 既存effect_typeの流用

秘術でも同じ`effect_type`を使用可能：
- `stat_bonus`
- `stat_debuff`
- `damage`
- その他スペルと共通の効果

---

## テスト戦略

### ユニットテスト

1. **SpellMysticArts クラス**
   - 秘術取得: `get_mystic_arts_for_creature()`
   - 発動判定: `can_cast_mystic_art()`
   - ターゲット取得: `_get_valid_creatures()` 等

2. **効果適用**
   - 各効果タイプの正常動作
   - コンテキスト情報の正確性

### 統合テスト

1. **フロー全体**
   - クリーチャー選択 → 秘術選択 → ターゲット選択 → 実行
   - キャンセル処理の確認

2. **排他制御**
   - スペル使用後は秘術不可
   - 秘術使用後はスペル不可

3. **エラーハンドリング**
   - 魔力不足
   - ターゲットなし
   - ターン内重複使用

### マニュアルテスト項目

- [ ] 秘術UI表示/非表示が正常
- [ ] 複数クリーチャーの秘術が区別できる
- [ ] 複数秘術を持つクリーチャーの選択が正常
- [ ] ターゲット選択がスペルと同じ動作
- [ ] 魔力消費が正確
- [ ] バトルテスト時に効果が正常適用

---

## 既知の問題と対策

### Issue 1: クリーチャーが複数の秘術を持つ場合

**問題**: 秘術選択UIでどの秘術を選ぶかが曖昧

**対策**: 秘術一覧UIで名前とコストを表示
```gdscript
for mystic_art in mystic_arts:
	display_text = "%s [%dMP]" % [mystic_art["name"], mystic_art["cost"]]
```

### Issue 2: ターゲット取得の統一 ✅ **解決済み**

**問題**: ターゲット選択で秘術と通常スペルの重複ロジックが発生する

**対策**: `spell_phase_handler._get_valid_targets()`を統一して使用
- `SpellMysticArts._has_valid_target()`内で`spell_phase_handler_ref._get_valid_targets()`を呼び出し
- 秘術固有の`_get_valid_creatures()`, `_get_valid_lands()`, `_get_valid_players()`は不要（削除）
- セルフターゲット時は`target_filter == "self"`でUI非表示に統一

### Issue 3: クリーチャーが倒された場合

**問題**: 秘術を持つクリーチャーがバトル中に倒された場合、秘術が使えるままになる

**対策**: スペルフェーズ前にクリーチャー状態を再確認
```gdscript
var available = spell_mystic_arts.get_available_creatures(current_player_id)
```

### Issue 4: ダウン状態と不屈スキルの連携 ✅ **実装済み**

**問題**: 秘術発動後のダウン状態設定で、不屈スキルを考慮する必要がある

**対策**: `_set_caster_down_state()`内で`_has_unyielding()`を呼び出し
- 不屈スキル持ちのクリーチャーはダウン状態にならない
- ランドシステムの領地コマンド仕様と統一

---

## 実装チェックリスト

### Phase 1
- [ ] `SpellMysticArts`クラス作成
- [ ] メソッド実装：`get_available_creatures()`
- [ ] メソッド実装：`get_mystic_arts_for_creature()`
- [ ] メソッド実装：`can_cast_mystic_art()`
- [ ] メソッド実装：`_has_valid_target()`
- [ ] メソッド実装：`_set_caster_down_state()` ⭐ ダウン状態設定
- [ ] メソッド実装：`_has_unyielding()` ⭐ 不屈スキル判定
- [ ] creature_data に `mystic_arts` フィールド追加
- [ ] テスト用JSON定義
- [ ] ユニットテスト作成・実行

### Phase 2
- [ ] `spell_phase_handler.gd` に秘術フロー追加
- [ ] `SpellAndMysticUI`クラス作成
- [ ] クリーチャー選択UI実装
- [ ] 秘術選択UI実装
- [ ] 排他制御実装
- [ ] 統合テスト実施

### Phase 3
- [ ] 秘術専用effect_type実装
- [ ] 既存effect_typeの流用確認
- [ ] 効果テスト実施
- [ ] マニュアルテスト実施

---

## 参考資料

- `docs/design/spells_design.md` - スペルシステム設計書
- `docs/design/effect_system.md` - 効果システム仕様書
- `scripts/game_flow/spell_phase_handler.gd` - 既存スペルフェーズ処理
- `scripts/ui_components/target_selection_helper.gd` - ターゲット選択ヘルパー

---

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/11/24 | 1.0 | 初版作成 - 実装準備完了 |
| 2025/11/24 | 1.1 | 🔧 ターゲット取得統一 - `spell_phase_handler._get_valid_targets()`を共用し重複回避、セルフターゲット処理を統一、Issue 2を解決済みに |
| 2025/11/24 | 1.2 | ⭐ ダウン状態システム統合 - `_set_caster_down_state()`と`_has_unyielding()`メソッド追加、ランドシステム仕様に準拠、クリーチャー行動可能性チェック実装、Issue 4追加 |

---

**最終更新**: 2025年11月24日（v1.2 - ダウン状態システム統合）
