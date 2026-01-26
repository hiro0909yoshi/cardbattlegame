# CPU アクション Handler 経由実行 設計書

**作成日**: 2026年1月7日  
**ステータス**: 設計中

---

## 📋 目次

1. [背景と目的](#背景と目的)
2. [現状の問題](#現状の問題)
3. [設計方針](#設計方針)
4. [対象アクション一覧](#対象アクション一覧)
5. [詳細設計](#詳細設計)
6. [実装計画](#実装計画)
7. [影響範囲](#影響範囲)

---

## 背景と目的

### 背景

現在CPUのアクション実行は、各Handlerを経由せず直接実行関数を呼び出している。
これによりプレイヤーと異なるコードパスを通り、以下の問題が発生している：

- ダウンチェック等のバリデーションがバイパスされる
- UI側で行われるべき状態管理が行われない
- 同じロジックが複数箇所に存在（保守性の低下）

### 目的

CPUもプレイヤーと同じHandler経由でアクションを実行することで：

1. **一貫性**: 同じバリデーション・処理フローを通る
2. **保守性**: ロジックの一元化
3. **信頼性**: バグの発生箇所を限定

---

## 現状の問題

### ドミニオオーダーの例

**プレイヤーのフロー:**
```
DominioOrderHandler
  ├─ SELECTING_LAND（土地選択）
  │    └─ ダウンチェック、所有権チェック
  ├─ SELECTING_ACTION（アクション選択）
  │    └─ 利用可能アクションの表示
  ├─ SELECTING_LEVEL（レベル選択）※レベルアップ時
  │    └─ EPチェック、コスト計算
  └─ 実行
```

**CPUの現状:**
```
cpu_turn_processor._execute_level_up_command()
  └─ land_handler.execute_level_up_with_level() を直接呼び出し
	  └─ ダウンチェックなし（※後から追加したが不完全）
```

### 問題のあるコード箇所

| ファイル | 関数 | 問題 |
|---------|------|------|
| cpu_turn_processor.gd | _execute_level_up_command | 直接実行 |
| cpu_turn_processor.gd | _execute_element_change_command | 直接実行 |
| cpu_turn_processor.gd | _execute_move_invasion_command | 直接実行 |
| cpu_turn_processor.gd | _execute_creature_swap_command | 独自実装 |

---

## 設計方針

### 基本方針

**「CPUは判断のみ、実行はHandler」**

```
┌─────────────────┐     判断結果      ┌─────────────────┐
│   CPU AI        │ ───────────────> │   Handler       │
│ (何をするか決定) │                   │ (実行・検証)    │
└─────────────────┘                   └─────────────────┘
											  │
											  v
									  ┌─────────────────┐
									  │   実行結果      │
									  │ (成功/失敗)     │
									  └─────────────────┘
```

### Handler への追加インターフェース

各Handlerに「CPUモード」用のメソッドを追加する：

```gdscript
## DominioOrderHandler に追加

# CPUが土地を選択
func select_tile_for_cpu(tile_index: int) -> bool:
	# 通常の土地選択と同じバリデーション
	# ダウンチェック、所有権チェック等
	pass

# CPUがアクションを選択
func select_action_for_cpu(action: String) -> bool:
	# "level_up", "terrain_change", "move", "swap"
	pass

# CPUがレベルを確定（レベルアップ時）
func confirm_level_for_cpu(target_level: int) -> bool:
	pass

# CPUが属性を確定（属性変更時）
func confirm_terrain_for_cpu(element: String) -> bool:
	pass

# CPUが移動先を確定（移動時）
func confirm_move_for_cpu(dest_tile_index: int) -> bool:
	pass

# CPUが交換カードを確定（交換時）
func confirm_swap_for_cpu(hand_index: int) -> bool:
	pass
```

### 既存メソッドとの関係

新メソッドは内部で既存の処理を呼び出す：

```gdscript
func select_tile_for_cpu(tile_index: int) -> bool:
	# 既存のバリデーションを使用
	if not _can_select_tile(tile_index):
		return false
	
	selected_tile_index = tile_index
	current_state = State.SELECTING_ACTION
	return true

func confirm_level_for_cpu(target_level: int) -> bool:
	# 既存のレベルアップ処理を使用
	var cost = _calculate_level_up_cost(target_level)
	return LandActionHelper.execute_level_up_with_level(self, target_level, cost)
```

---

## 対象アクション一覧

### 1. ドミニオオーダー

| アクション | Handler | 現状 | 対応方針 |
|-----------|---------|------|---------|
| レベルアップ | DominioOrderHandler | 直接実行 | CPU用メソッド追加 |
| 属性変更 | DominioOrderHandler | 直接実行 | CPU用メソッド追加 |
| 移動侵略 | DominioOrderHandler | 直接実行 | CPU用メソッド追加 |
| クリーチャー交換 | DominioOrderHandler | 独自実装 | CPU用メソッド追加 |

### 2. スペル

| アクション | Handler | 現状 | 対応方針 |
|-----------|---------|------|---------|
| スペル発動 | SpellCastHandler | 要確認 | CPU用メソッド追加 |
| ターゲット選択 | SpellCastHandler | 要確認 | CPU用メソッド追加 |

### 3. アルカナアーツ

| アクション | Handler | 現状 | 対応方針 |
|-----------|---------|------|---------|
| アーツ発動 | MysticArtsHandler | 要確認 | CPU用メソッド追加 |

### 4. 召喚

| アクション | Handler | 現状 | 対応方針 |
|-----------|---------|------|---------|
| クリーチャー召喚 | TileActionProcessor | 要確認 | 確認後判断 |

### 5. 戦闘

| アクション | Handler | 現状 | 対応方針 |
|-----------|---------|------|---------|
| 侵略開始 | BattleHandler | 要確認 | 確認後判断 |
| アイテム使用 | BattleHandler | 要確認 | 確認後判断 |

---

## 詳細設計

### ドミニオオーダー

#### DominioOrderHandler への追加

```gdscript
# === CPU用インターフェース ===

## CPUがドミニオオーダーを実行（統合メソッド）
## 戻り値: 実行成功/失敗
func execute_for_cpu(command: Dictionary) -> bool:
	var command_type = command.get("type", "")
	var tile_index = command.get("tile_index", -1)
	
	# 1. 土地選択（バリデーション含む）
	if not select_tile_for_cpu(tile_index):
		return false
	
	# 2. コマンド実行
	match command_type:
		"level_up":
			return _execute_level_up_for_cpu(command)
		"element_change":
			return _execute_element_change_for_cpu(command)
		"move_invasion":
			return _execute_move_for_cpu(command)
		"creature_swap":
			return _execute_swap_for_cpu(command)
	
	return false

## CPU用土地選択
func select_tile_for_cpu(tile_index: int) -> bool:
	if not board_system or not board_system.tile_nodes.has(tile_index):
		return false
	
	var tile = board_system.tile_nodes[tile_index]
	
	# ダウンチェック
	if tile.has_method("is_down") and tile.is_down():
		print("[DominioOrderHandler] CPU: タイル%d はダウン中" % tile_index)
		return false
	
	# 所有権チェック
	var current_player = player_system.get_current_player()
	if tile.owner_id != current_player.id:
		print("[DominioOrderHandler] CPU: タイル%d は所有していない" % tile_index)
		return false
	
	selected_tile_index = tile_index
	return true

## CPU用レベルアップ
func _execute_level_up_for_cpu(command: Dictionary) -> bool:
	var target_level = command.get("target_level", 1)
	var cost = command.get("cost", 0)
	
	# LandActionHelperの既存処理を使用
	return LandActionHelper.execute_level_up_with_level(self, target_level, cost)

## CPU用属性変更
func _execute_element_change_for_cpu(command: Dictionary) -> bool:
	var new_element = command.get("new_element", "")
	
	return LandActionHelper.execute_terrain_change_with_element(self, new_element)

## CPU用移動侵略
func _execute_move_for_cpu(command: Dictionary) -> bool:
	var from_tile = command.get("from_tile_index", -1)
	var to_tile = command.get("to_tile_index", -1)
	
	# 移動元を選択
	if not select_tile_for_cpu(from_tile):
		return false
	
	# 移動処理
	return LandActionHelper.confirm_move(self, to_tile)

## CPU用クリーチャー交換
func _execute_swap_for_cpu(command: Dictionary) -> bool:
	var hand_index = command.get("hand_index", -1)
	
	# 交換処理（既存のexecute_swapを使用）
	return _execute_swap_with_hand_index(hand_index)
```

#### cpu_turn_processor.gd の修正

```gdscript
# 修正前
func _execute_territory_command(current_player, command: Dictionary):
	match command_type:
		"level_up":
			_execute_level_up_command(current_player, command)
		# ...

# 修正後
func _execute_territory_command(current_player, command: Dictionary):
	var land_handler = _get_dominio_order_handler()
	if land_handler == null:
		_complete_action()
		return
	
	var success = land_handler.execute_for_cpu(command)
	
	if success:
		print("[CPU] ドミニオオーダー実行成功: %s" % command.get("type", "?"))
	else:
		print("[CPU] ドミニオオーダー実行失敗: %s" % command.get("type", "?"))
	
	_complete_action()
```

### スペル

#### SpellCastHandler への追加（案）

```gdscript
## CPUがスペルを発動
func cast_spell_for_cpu(spell_index: int, targets: Array = []) -> bool:
	# 1. スペル選択
	if not _select_spell(spell_index):
		return false
	
	# 2. ターゲット選択（必要な場合）
	for target in targets:
		if not _select_target(target):
			return false
	
	# 3. 発動
	return _execute_spell()
```

### アルカナアーツ

#### MysticArtsHandler への追加（案）

```gdscript
## CPUがアルカナアーツを発動
func use_arts_for_cpu(spell_id: int, targets: Array = []) -> bool:
	# スペルと同様のフロー
	pass
```

---

## 実装計画

### Phase 1: ドミニオオーダー（優先度: 高）

**対象ファイル:**
- `scripts/game_flow/dominio_order_handler.gd` - CPU用メソッド追加
- `scripts/cpu_ai/cpu_turn_processor.gd` - Handler経由に修正

**作業内容:**
1. DominioOrderHandler に `execute_for_cpu()` 等を追加
2. cpu_turn_processor の `_execute_*_command()` を修正
3. 動作確認・テスト

**見積もり:** 2-3時間

### Phase 2: スペル（優先度: 中）

**対象ファイル:**
- `scripts/game_flow/spell_cast_handler.gd` - CPU用メソッド追加
- 関連するCPU処理ファイル

**作業内容:**
1. 現状の実装を確認
2. SpellCastHandler に CPU用メソッド追加
3. CPU処理を修正

**見積もり:** 2-3時間

### Phase 3: アルカナアーツ（優先度: 中）

**対象ファイル:**
- アルカナアーツ関連Handler
- 関連するCPU処理ファイル

**見積もり:** 1-2時間

### Phase 4: 召喚・戦闘（優先度: 低）

**作業内容:**
1. 現状確認（既にHandler経由の可能性）
2. 必要に応じて修正

**見積もり:** 1-2時間

---

## 影響範囲

### 修正が必要なファイル

| ファイル | 修正内容 |
|---------|---------|
| dominio_order_handler.gd | CPU用メソッド追加 |
| cpu_turn_processor.gd | Handler経由に変更 |
| spell_cast_handler.gd | CPU用メソッド追加（要確認） |
| cpu_ai_handler.gd | 必要に応じて修正 |

### 修正不要なファイル

| ファイル | 理由 |
|---------|------|
| cpu_territory_ai.gd | 判断ロジックのみ、実行は行わない |
| cpu_battle_ai.gd | 判断ロジックのみ |
| land_action_helper.gd | 既存処理はそのまま使用 |

### 削除予定のコード

| ファイル | 関数 | 理由 |
|---------|------|------|
| cpu_turn_processor.gd | _execute_level_up_command | Handler経由に置換 |
| cpu_turn_processor.gd | _execute_element_change_command | Handler経由に置換 |
| cpu_turn_processor.gd | _execute_move_invasion_command | Handler経由に置換 |
| cpu_turn_processor.gd | _execute_creature_swap_command | Handler経由に置換 |

---

## 移動侵略の詳細設計

### 現状の問題

**プレイヤーの移動侵略フロー:**
```
DominioOrderHandler
  └─ LandActionHelper.confirm_move()
	   ├─ 空き地の場合 → クリーチャー移動、土地獲得
	   └─ 敵ドミニオの場合
			├─ peace呪いチェック等
			├─ pending_move_battle_* に情報保存
			├─ ItemPhaseHandler.start_item_phase()（攻撃側アイテム）
			├─ ItemPhaseHandler.start_item_phase()（防御側アイテム）
			└─ _execute_move_battle()
```

**CPUの移動侵略（現状 - 誤り）:**
```
cpu_turn_processor._execute_move_to_enemy()
  └─ cpu_ai_handler.decide_battle()  ← 手札から選ぶ通常侵略のフロー
	   └─ 誤り：移動元のクリーチャーで攻撃すべき
```

### 修正後のフロー

CPUも`DominioOrderHandler`経由で移動侵略を実行：

```
cpu_turn_processor._execute_move_invasion_command()
  └─ land_handler.execute_move_for_cpu(from_tile, to_tile)
	   └─ LandActionHelper.confirm_move()
			├─ 空き地 → 通常移動
			└─ 敵ドミニオ → ItemPhaseHandler経由で戦闘
						 ├─ start_item_phase()で攻撃側アイテム
						 │    └─ _cpu_decide_item()（既存）
						 ├─ start_item_phase()で防御側アイテム
						 │    └─ _cpu_decide_item()（既存）
						 └─ _execute_move_battle()
```

### アイテム選択について

**既に Handler 経由で動作している:**
- `ItemPhaseHandler.start_item_phase()` でCPUかどうかを判定
- CPUの場合は `_cpu_decide_item()` が呼ばれる
- 合体判断、アイテム破壊対策、無効化アイテム使用等の判断ロジックが実装済み

**修正不要:**
- `ItemPhaseHandler` のCPU処理は既に完成している
- 移動侵略を正しいフローに修正すれば、アイテム選択も自動的に動作する

---

## 調査結果まとめ

| 機能 | プレイヤー | CPU | 状態 |
|------|-----------|-----|------|
| **スペル発動** | SpellPhaseHandler | SpellPhaseHandler._handle_cpu_spell_turn() | ✅ Handler経由 |
| **アルカナアーツ** | SpellPhaseHandler | SpellPhaseHandler._execute_cpu_mystic_arts() | ✅ Handler経由 |
| **アイテム選択** | ItemPhaseHandler | ItemPhaseHandler._cpu_decide_item() | ✅ Handler経由 |
| **召喚** | TileActionProcessor.execute_summon() | cpu_turn_processor._execute_summon() | ❌ 別コード |
| **通常侵略** | TileActionProcessor.execute_battle() | cpu_turn_processor._on_cpu_invasion_decided() | ❌ 別コード |
| **ドミニオオーダー** | DominioOrderHandler | cpu_turn_processor._execute_*_command() | ❌ 直接実行 |
| **移動侵略** | LandActionHelper.confirm_move() | cpu_turn_processor._execute_move_to_enemy() | ❌ 間違ったフロー |

### 修正が必要なもの

1. **召喚** - CPUは土地条件チェック・カード犠牲・合成処理がない
2. **通常侵略** - CPUは土地条件チェック・カード犠牲・合成処理がない
3. **ドミニオオーダー** - CPUは直接実行でダウンチェック等がバイパスされる
4. **移動侵略** - CPUは間違ったフロー（手札選択）を使用

### 修正不要なもの

1. **スペル発動** - 既にHandler経由
2. **アルカナアーツ** - 既にHandler経由
3. **アイテム選択** - 既にHandler経由

---

## 修正後の設計

### 召喚

**現状のCPU召喚（問題あり）:**
```
cpu_turn_processor._execute_summon()
  └─ 簡易実装（土地条件・合成処理なし）
```

**修正後:**
```
cpu_turn_processor._execute_summon()
  └─ tile_action_processor.execute_summon_for_cpu(card_index)
	   └─ execute_summon() と同じ処理（土地条件・合成含む）
```

**TileActionProcessor に追加するメソッド:**
```gdscript
## CPU用召喚実行
func execute_summon_for_cpu(card_index: int) -> bool:
	# 通常の execute_summon() と同じ処理を実行
	# - 土地条件チェック
	# - カード犠牲処理（CPUは自動選択）
	# - 合成処理
	# - コスト支払い
	# - クリーチャー配置
	pass
```

### 通常侵略

**現状のCPU侵略（問題あり）:**
```
cpu_turn_processor._on_cpu_invasion_decided()
  └─ 簡易実装（土地条件・合成処理なし）
```

**修正後:**
```
cpu_turn_processor._on_cpu_invasion_decided()
  └─ tile_action_processor.execute_battle_for_cpu(card_index, tile_info)
	   └─ execute_battle() と同じ処理（土地条件・合成含む）
	   └─ ItemPhaseHandler 経由でアイテムフェーズ
```

**TileActionProcessor に追加するメソッド:**
```gdscript
## CPU用バトル実行
func execute_battle_for_cpu(card_index: int, tile_info: Dictionary) -> bool:
	# 通常の execute_battle() と同じ処理を実行
	# - 土地条件チェック
	# - カード犠牲処理（CPUは自動選択）
	# - 合成処理
	# - アイテムフェーズ
	# - バトル実行
	pass
```

### ドミニオオーダー

**現状のCPUドミニオオーダー（問題あり）:**
```
cpu_turn_processor._execute_level_up_command()
  └─ land_handler.execute_level_up_with_level() 直接呼び出し
	  └─ ダウンチェックなし
```

**修正後:**
```
cpu_turn_processor._execute_territory_command()
  └─ land_handler.execute_for_cpu(command)
	   ├─ select_tile_for_cpu() でダウンチェック・所有権チェック
	   └─ 各コマンド実行
```

### 移動侵略

**現状のCPU移動侵略（間違ったフロー）:**
```
cpu_turn_processor._execute_move_to_enemy()
  └─ cpu_ai_handler.decide_battle()  ← 手札から選ぶ通常侵略のフロー（誤り）
```

**修正後:**
```
cpu_turn_processor._execute_move_invasion_command()
  └─ land_handler.execute_move_for_cpu(from_tile, to_tile)
	   └─ LandActionHelper.confirm_move()
			├─ 空き地 → 通常移動
			└─ 敵ドミニオ → ItemPhaseHandler経由で戦闘
```

---

## 実装計画（修正版）

### Phase 1: ドミニオオーダー（優先度: 高）

**対象:**
- レベルアップ
- 属性変更
- 移動（空き地）
- 移動侵略（敵ドミニオ）
- クリーチャー交換

**作業:**
1. DominioOrderHandler に `execute_for_cpu()` 追加
2. cpu_turn_processor を Handler経由に修正

**見積もり:** 2-3時間

### Phase 2: 召喚（優先度: 高）

**作業:**
1. TileActionProcessor に `execute_summon_for_cpu()` 追加
2. cpu_turn_processor を Handler経由に修正
3. カード犠牲のCPU自動選択を実装

**見積もり:** 2-3時間

### Phase 3: 通常侵略（優先度: 高）

**作業:**
1. TileActionProcessor に `execute_battle_for_cpu()` 追加
2. cpu_turn_processor を Handler経由に修正
3. カード犠牲のCPU自動選択を実装

**見積もり:** 2-3時間

### Phase 4: テスト・検証

**作業:**
- 各機能の動作確認
- プレイヤーとCPUの挙動一致確認

**見積もり:** 1-2時間

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026/01/07 | 初版作成 |
| 2026/01/07 | 移動侵略の詳細設計を追加、アイテム選択は既にHandler経由であることを確認 |
| 2026/01/07 | 全機能の調査完了、召喚・通常侵略も修正が必要であることを確認 |
