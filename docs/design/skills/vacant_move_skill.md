# 特殊移動スキル - 設計仕様書

**作成日**: 2025年10月25日  
**バージョン**: 1.2  
**最終更新**: 2025年10月26日

---

## 📋 概要

特殊移動は、通常の隣接移動を超えた移動能力の総称です。空地移動、敵地移動など、様々なバリエーションが存在します。

---

## 🎯 移動系スキルの体系

### 発動タイミング別分類

| タイミング | 種類 | 例 | 実装優先度 |
|-----------|------|-----|----------|
| **ドミニオオーダー** | 空地移動、敵地移動 | ブリーズスピリット、サンダースポーン | **高（Phase 1）** |
| **スペルフェーズ** | 強制移動 | チャリオット、アウトレイジ | **中（Phase 2）** |
| **戦闘後** | 条件付き移動 | アージェントキー | **低（Phase 3）** |

### 移動タイプ別分類

#### 1. 空地移動
- **対象**: 空き地（所有者のいない土地）
- **制限**: 属性制限あり/なし
- **発動**: ドミニオオーダー
- **例**: 空地移動[風]、空地移動[風水]、空地移動[全]

#### 2. 敵地移動
- **対象**: 敵が所有する土地（全マップ）
- **範囲**: 通常の隣接移動 + 全マップの敵地
- **効果**: 移動後に戦闘発生
- **発動**: ドミニオオーダー
- **通常移動**: 敵地移動スキル持ちでも隣接タイルへの通常移動は可能
- **例**: サンダースポーン（敵ドミニオ移動[属性の違う敵ドミニオ]）

#### 3. 強制移動（スペル）
- **対象**: 任意のクリーチャーを移動させる
- **発動**: スペルフェーズ
- **例**: チャリオット（2マス移動）、アウトレイジ（敵ドミニオへ）

#### 4. 戦闘後移動
- **対象**: 戦闘に参加したクリーチャー
- **発動**: 戦闘終了後
- **例**: アージェントキー（攻撃で敵非破壊時、ランダムな空地へ）

#### 5. 特殊移動
- **例**: バウダーイーター（移動時、元のドミニオと移動先の両方に配置）

---

## 🎯 基本仕様

### スキルタイプ
- **分類**: 移動系スキル
- **発動タイミング**: ドミニオオーダー「移動」選択時
- **優先度**: 通常移動の代替

### 移動条件
1. **移動元**: 空地移動スキルを持つクリーチャーがいる自ドミニオ
2. **移動先**: 指定属性の空き地のみ
   - 所有者がいない土地（owner_id == -1）
   - スキルで指定された属性の土地

### 属性制限パターン

| パターン | 表記 | 移動可能な空き地 |
|---------|-----|----------------|
| 単一属性 | 空地移動[風] | 風属性の空き地のみ |
| 複数属性 | 空地移動[風水] | 風または水属性の空き地 |
| 全属性 | 空地移動[全] | すべての空き地 |

---

## 🔍 実装対象

### 空地移動クリーチャー

| ID | 名前 | 属性 | スキル詳細 | 移動可能先 |
|----|-----|------|----------|-----------|
| 337 | ブリーズスピリット | 風 | 空地移動[風水] | 風・水属性の空き地 |
| 348 | ワイバーン | 風 | 先制；空地移動[風] | 風属性の空き地 |
| 229 | ドリアード | 地 | 援護[無火地]；空地移動[地] | 地属性の空き地 |

### 敵地移動クリーチャー

| ID | 名前 | 属性 | スキル詳細 | 移動可能先 |
|----|-----|------|----------|-----------|
| 318 | サンダースポーン | 風 | 敵ドミニオ移動[属性の違う敵ドミニオ] | 隣接タイル全て + 今いるタイルと異なる属性の敵地 |

**敵地移動の詳細:**
- **通常移動も可能**: 敵地移動スキル持ちでも、隣接タイルへの通常移動は可能
- **サンダースポーン条件**: 今いるタイルの属性（例: neutral）と異なる属性（wind, water, fire, earth）の敵地に移動可能
- **基本の敵地移動**: 条件なしで全マップの全敵地に移動可能

### 強制移動スペル

| ID | 名前 | コスト | 効果 | 移動タイプ |
|----|-----|--------|------|-----------|
| 2052 | チャリオット | 50MP | 対象自クリーチャーを2マス移動 | 強制移動 |
| 2002 | アウトレイジ | 100MP | 対象クリーチャーを隣接敵ドミニオへ | 強制移動（敵地） |
| 2045 | スピリットウォーク | 20MP | ドミニオ効果"遠隔移動"付与 | ドミニオ効果 |

---

## 💻 技術設計

### アーキテクチャ概要

```
発動タイミング処理（前処理）
├─ ドミニオオーダー → land_action_helper
├─ スペルフェーズ → spell_phase_handler  
└─ 戦闘後 → battle_system
		  ↓
	移動先候補取得（共通処理）
	get_move_destinations()
		  ↓
	移動実行（共通処理）
	execute_creature_move()
```

### 1. データ構造

#### ability_parsed拡張
```json
{
  "keywords": ["空地移動"],
  "keyword_conditions": {
	"空地移動": {
	  "target_elements": ["wind", "water"]  // 移動可能な属性
	}
  }
}
```

### 2. 共通移動処理（コア実装）

#### movement_helper.gd（新規作成）
```gdscript
# 共通の移動先取得処理（どの発動タイミングからも呼ばれる）
static func get_move_destinations(
	board_system: Node,
	creature_data: Dictionary,
	from_tile_index: int,
	move_type_override: String = ""  # スペルなどで強制的に移動タイプを指定
) -> Array:
	"""
	移動可能な土地のインデックス配列を返す
	発動タイミングに関わらず、移動タイプに応じた候補を返す
	"""
	
	# 移動タイプの判定（オーバーライドがあればそれを優先）
	var move_type = move_type_override
	if move_type.is_empty():
		move_type = _detect_move_type(creature_data)
	
	match move_type:
		"vacant_move":
			# 空地移動 + 通常の隣接移動も可能
			var elements = _get_vacant_move_elements(creature_data)
			var vacant_destinations = _get_vacant_tiles_by_elements(board_system, elements)
			var adjacent_destinations = board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
			# 重複を避けて結合
			return vacant_destinations + adjacent_destinations (重複除去)
		"enemy_move":
			# 敵地移動 + 通常の隣接移動も可能
			var condition = _get_enemy_move_condition(creature_data)
			var enemy_destinations = _get_enemy_tiles_by_condition(board_system, condition, from_tile_index, creature_data)
			var adjacent_destinations = board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
			# 重複を避けて結合
			return enemy_destinations + adjacent_destinations (重複除去)
		"adjacent":
			return board_system.tile_neighbor_system.get_spatial_neighbors(from_tile_index)
		"random_vacant":  # 戦闘後のアージェントキー用
			return _get_all_vacant_tiles(board_system)
		_:
			return []

# 実際の移動実行（共通処理）
static func execute_creature_move(
	board_system: Node,
	from_tile: int,
	to_tile: int,
	creature_data: Dictionary = {}  # 空の場合は移動元から取得
) -> void:
	"""
	クリーチャーの移動を実行する共通処理
	CRITICAL: duplicate()を使わない - base_up_ap/hp等のバフを保持するため
	"""
	var from_tile_node = board_system.tile_nodes[from_tile]
	var to_tile_node = board_system.tile_nodes[to_tile]
	
	# creature_dataが空の場合は移動元から取得（直接参照）
	if creature_data.is_empty():
		creature_data = from_tile_node.creature_data
	
	# 移動元をクリア
	from_tile_node.creature_data = {}
	from_tile_node.owner_id = -1
	if from_tile_node.has_method("update_display"):
		from_tile_node.update_display()
	
	# 移動先に配置（直接参照を使用 - duplicate()しない）
	to_tile_node.creature_data = creature_data
	to_tile_node.owner_id = from_tile_node.owner_id
	
	# ダウン状態設定（不屈チェック）
	if to_tile_node.has_method("set_down_state"):
		if not SkillSystem.has_unyielding(creature_data):
			to_tile_node.set_down_state(true)
	
	if to_tile_node.has_method("update_display"):
		to_tile_node.update_display()
```

### 3. 発動タイミング別の実装

#### ドミニオオーダー（Phase 1）
```gdscript
# land_action_helper.gd
func get_available_move_destinations(tile_index: int) -> Array:
	var creature = board_system.tile_nodes[tile_index].tile_data.creature
	# 共通処理を呼び出し
	return MovementHelper.get_move_destinations(
		board_system, creature, tile_index
	)
```

#### スペルフェーズ（Phase 2）
```gdscript
# spell_phase_handler.gd
func execute_chariot(target_creature_tile: int) -> void:
	var creature = board_system.tile_nodes[target_creature_tile].tile_data.creature
	# 強制的に2マス移動の候補を取得
	var destinations = MovementHelper.get_move_destinations(
		board_system, creature, target_creature_tile, "two_tiles"
	)
	# 移動先選択UI表示...
```

#### 戦闘後（Phase 3）
```gdscript
# battle_system.gd
func _handle_argent_key_effect(attacker_tile: int) -> void:
	if not enemy_destroyed and attacker_has_argent_key:
		# ランダムな空地を取得
		var destinations = MovementHelper.get_move_destinations(
			board_system, attacker_creature, attacker_tile, "random_vacant"
		)
		if destinations.size() > 0:
			var random_dest = destinations[randi() % destinations.size()]
			MovementHelper.execute_creature_move(
				board_system, attacker_tile, random_dest, attacker_creature
			)
```

### 3. UI表示の対応

#### tile_action_processor.gd
```gdscript
func _execute_move_action() -> void:
	var destinations = land_action_helper.get_available_move_destinations(selected_tile_index)
	
	if destinations.is_empty():
		_show_error("移動可能な土地がありません")
		return
	
	# 空地移動の場合は特別なUIメッセージ
	var creature = board_system.tile_nodes[selected_tile_index].tile_data.creature
	if _has_vacant_move_skill(creature):
		_show_message("空地移動: 対象属性の空き地を選択してください")
	
	# 移動先候補を表示（ハイライト）
	_highlight_move_destinations(destinations)
	
	# 移動先選択モードへ
	current_state = ActionState.SELECTING_MOVE_DESTINATION
	move_destinations = destinations
```

### 4. 移動実行処理

既存の移動処理（`execute_move`）をそのまま使用可能。空地移動も通常移動も、移動実行自体は同じ処理：

1. 移動元からクリーチャーを削除
2. 移動先にクリーチャーを配置
3. 土地所有権を更新
4. ダウン状態にする

---

## 🎮 ゲームプレイフロー

### 移動タイプ別の違い

| 項目 | 通常移動 | 空地移動 | 敵地移動 |
|-----|---------|---------|----------|
| **移動範囲** | 隣接タイルのみ | 全マップの対象空き地 | 隣接タイル + 全マップの対象敵地 |
| **移動先** | すべての隣接（空地、自分の土地、敵地） | 指定属性の空き地のみ | 隣接タイル全て + 条件に合う敵地 |
| **戦闘** | 敵地の場合発生 | なし（空き地のみ） | 敵地の場合発生 |
| **ダウン状態** | あり | あり | あり |
| **1ターン制限** | 1回のみ | 1回のみ | 1回のみ |

### 空地移動の操作フロー
```
1. ドミニオオーダー選択
   ↓
2. 空地移動持ちクリーチャーの土地を選択
   ↓
3. 「移動」を選択
   ↓
4. 移動可能な空き地がハイライト表示
   ↓
5. 移動先を選択
   ↓
6. 移動実行 → ダウン状態 → ターン終了
```

### 敵地移動の操作フロー
```
1. ドミニオオーダー選択
   ↓
2. 敵地移動持ちクリーチャーの土地を選択
   ↓
3. 「移動」を選択
   ↓
4. 移動可能な敵地がハイライト表示
   ↓
5. 移動先を選択
   ↓
6. 移動実行 → 戦闘発生 → 結果処理 → ダウン状態
```

---

## ⚠️ 注意事項・制限

### 実装上の注意
1. **敵地には移動不可** - 空き地のみが対象
2. **自ドミニオには移動不可** - 空き地のみが対象
3. **クリーチャーがいる土地は不可** - 純粋な空き地のみ
4. **ダウン状態の土地からは移動不可** - 通常移動と同じ

### バランス考慮
- 空地移動は強力なので、属性制限でバランスを取る
- 全属性移動可能な「空地移動[全]」は慎重に扱う

---

## 📝 テストケース

### 基本動作テスト

1. **ブリーズスピリット（風水）**
   - ✅ 風属性の空き地に移動可能
   - ✅ 水属性の空き地に移動可能
   - ❌ 火属性の空き地に移動不可
   - ❌ 地属性の空き地に移動不可
   - ❌ 無属性の空き地に移動不可

2. **ワイバーン（風のみ）**
   - ✅ 風属性の空き地に移動可能
   - ❌ その他属性の空き地に移動不可

3. **エッジケース**
   - ❌ 敵地には移動不可（空き地ではない）
   - ❌ 自ドミニオには移動不可（空き地ではない）
   - ❌ クリーチャーがいる空き地には移動不可

### UI/UXテスト
- 移動可能タイルのハイライト表示
- 移動不可時のエラーメッセージ
- 空地移動時の特別なメッセージ表示

---

## 🚀 実装手順

### Phase 1: ドミニオオーダーの空地移動（完了）
1. ✅ クリーチャーデータに`ability_parsed`追加
2. ✅ `movement_helper.gd`作成（共通処理）
3. ✅ 空地移動の移動先取得処理
4. ✅ `land_action_helper.gd`から共通処理を呼び出し
5. ✅ 移動可能タイルのハイライト表示
6. ✅ テスト（ブリーズスピリット、ワイバーン、ドリアード）

### Phase 1.5: ドミニオオーダーの敵地移動（完了）
7. ✅ サンダースポーンのデータ更新（ID: 318）
8. ✅ 敵地移動の移動先取得処理
9. ✅ 移動後の戦闘処理確認
10. ✅ テスト完了

### Phase 2: スペルによる強制移動
11. 🔲 `spell_phase_handler.gd`の拡張
12. 🔲 チャリオット（2マス移動）実装
13. 🔲 アウトレイジ（敵ドミニオへ）実装
14. 🔲 スピリットウォーク（ドミニオ効果）実装

### Phase 3: 戦闘後移動
15. 🔲 `battle_system.gd`の拡張
16. 🔲 アージェントキーの効果実装
17. 🔲 ランダム空地選択処理

---

## 🔮 将来の拡張

### 実装予定の移動系能力

1. **属性制限の緩和**
   - 空地移動[全] - すべての属性の空き地へ移動可能
   - 敵地移動[全] - すべての敵地へ移動可能

2. **条件付き移動**
   - HP条件付き空地移動
   - ドミニオ効果による移動範囲拡張

3. **特殊な移動効果**
   - 移動時分身（バウダーイーター型）
   - 移動後の追加効果

---

## 📊 実装の統一設計

### 移動タイプの判定フロー
```
クリーチャーのスキル確認
├─ 空地移動あり → 空き地 + 隣接タイル表示
├─ 敵地移動あり → 敵地 + 隣接タイル表示
├─ 特殊移動あり → 条件に応じた表示
└─ なし → 隣接タイルのみ表示
```

### データ構造の統一
```json
{
  "keyword_conditions": {
	"空地移動": {
	  "target_elements": ["wind", "water"]  // または ["全"]
	},
	"敵ドミニオ移動": {
	  "condition": {
		"different_element": true  // 属性が異なる敵地
	  }
	}
  }
}
```

---

## ✅ 実装済み機能（2025年10月26日時点）

### 完了した実装

#### 1. 空地移動（ID: 337, 348, 229）
- ✅ `MovementHelper.get_move_destinations()` - 移動先候補取得
- ✅ 属性フィルタリング（風、水、地など）
- ✅ 隣接タイルとの重複除去
- ✅ 空き地への移動実行
- ✅ ダウン状態設定

#### 2. 敵地移動（ID: 318 サンダースポーン）
- ✅ `ability_parsed`データ追加
- ✅ 条件付き敵地検出（属性が異なる敵地）
- ✅ 隣接タイルとの重複除去
- ✅ 戦闘システム統合
- ✅ **戦闘敗北時の処理**: 移動元に戻る
  - HPは戦闘後の残りHP
  - ダウン状態になる
  - 不屈スキル対応
- ✅ **戦闘勝利時の処理**: 移動先占領

#### 3. 戦闘システム拡張
- ✅ `execute_3d_battle_with_data()`に`from_tile_index`パラメータ追加
- ✅ `_execute_battle_core()`に`from_tile_index`パラメータ追加
- ✅ `_apply_post_battle_effects()`に`from_tile_index`パラメータ追加
- ✅ `ATTACKER_SURVIVED`時の分岐処理
  - 移動侵略（`from_tile_index >= 0`）: 移動元に戻す
  - 通常侵略（`from_tile_index < 0`）: 手札に戻す

### テスト結果

| テスト項目 | 結果 | 備考 |
|-----------|------|------|
| 空地移動（風属性のみ） | ✅ | 風空き地のみ表示 |
| 空地移動（風水属性） | ✅ | 風・水空き地表示 |
| 空地移動（地属性） | ✅ | 地空き地のみ表示 |
| 敵地移動（属性違い条件） | ✅ | 条件に合う敵地表示 |
| 敵地移動 + 隣接移動 | ✅ | 両方表示される |
| 敵地移動戦闘勝利 | ✅ | 土地占領、ダウン状態 |
| **敵地移動戦闘敗北** | ✅ | **移動元に戻る、残りHP、ダウン状態** |
| 通常侵略敗北 | ✅ | 手札に戻る（従来通り） |

### 既知の制限事項

1. **空地移動[全]**: 未実装（将来の拡張）
2. **条件付き空地移動**: 未実装（HP条件など）
3. **スペルによる強制移動**: 未実装（Phase 2）
4. **戦闘後移動**: 未実装（Phase 3）

---
