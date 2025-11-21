# 直接操作箇所 - 詳細分析

## 概要
`tile.creature_data = ...` で**直接代入**している箇所。これらは CreatureManager の setter を通るので実は問題ないが、コードの明確性の観点から注意が必要。

---

## 1. scripts/board_system_3d.gd

### 1-1. Line 268: クリーチャー除去（フォールバック）
```gdscript
func remove_creature(tile_index: int):
	var tile = tile_nodes[tile_index]
	
	# BaseTileのremove_creature()を呼び出して3Dカードも削除
	if tile.has_method("remove_creature"):
		tile.remove_creature()
	else:
		# フォールバック: データだけクリア
		tile.creature_data = {}  # ← 直接操作
		if tile.has_method("update_visual"):
			tile.update_visual()
```

**何をしているか：**
- クリーチャーをタイルから完全に削除
- 通常は `tile.remove_creature()` メソッド呼び出し
- フォールバック時のみ直接 `= {}` で空にする

**実装上の動作：**
✅ `tile.creature_data = {}` は setter 経由で `CreatureManager.set_data(tile_index, {})` を呼ぶ
✅ CreatureManager が自動的に creature を削除
⚠️ ただしコード読み手にとって「これが CreatureManager に反映される」が不明確

---

### 1-2. Line 368: タイル交換時のデータ引き継ぎ
```gdscript
func exchange_tile(tile_index: int, new_tile_type: str):
	var old_tile = tile_nodes[tile_index]
	var old_creature = old_tile.creature_data.duplicate() if not old_tile.creature_data.is_empty() else {}
	
	# 新しいタイルに交換
	var new_tile = create_tile(tile_index, new_tile_type)
	tile_nodes[tile_index] = new_tile
	
	# データ引き継ぎ
	new_tile.creature_data = old_creature  # ← 直接操作
```

**何をしているか：**
- 古いタイルノードを新しいタイルノードに交換
- 古いタイルの creature_data を新しいタイルに引き継ぎ

**実装上の動作：**
✅ 新しいタイル（別オブジェクト）の creature_data setter が呼ばれ、CreatureManager に登録
✅ 古いタイルは queue_free() されるので参照が失われる
✅ 同じ tile_index に対する操作なので tile_index の整合性も取れる

---

## 2. scripts/battle_system.gd

### Line 365: 移動侵略で配置
```gdscript
func complete_movement_invasion(attacker_index: int, defender_index: int):
	var return_data = attacker.creature_data.duplicate(true)
	
	# BattleParticipantのプロパティから永続バフを反映
	return_data["base_up_hp"] = attacker.base_up_hp
	return_data["base_up_ap"] = attacker.base_up_ap
	return_data["current_hp"] = attacker.current_hp
	
	from_tile.creature_data = return_data  # ← 直接操作
```

**何をしているか：**
- バトル中の BattleParticipant から最新の creature_data を構築
- 永続バフと現在HPを同期
- 元のタイルにクリーチャーを再配置

**実装上の動作：**
✅ `from_tile.creature_data = return_data` は setter を通す
✅ CreatureManager に正しく反映される
⚠️ 複雑なデータ構築プロセスのため、「何がどこで更新されるのか」が追いづらい

---

## 3. scripts/game_flow/spell_phase_handler.gd

### Line 492: スペル効果でクリーチャー倒す
```gdscript
if creature["hp"] <= 0 and creature.get("land_bonus_hp", 0) <= 0:
	tile.creature_data = {}  # ← 直接操作
	tile.owner_id = -1
	tile.level = 1
	tile.update_visual()
```

**何をしているか：**
- スペルダメージでクリーチャーが倒れた時、タイルをクリア
- クリーチャーデータを空に
- タイルの所有者をリセット

**実装上の動作：**
✅ CreatureManager.set_data(tile_index, {}) が呼ばれる
✅ creatures[tile_index] が削除される
✅ シンプルで読みやすい

---

## 全体の安全性評価

### ✅ 実装上は全て正しい

全ての直接操作が `setter` 経由で CreatureManager に反映されている。

```
tile.creature_data = new_value
  ↓
setter 実行: creature_manager.set_data(tile_index, new_value)
  ↓
CreatureManager.creatures[tile_index] に反映
  ↓
SSoT（CreatureManager）が正しく保持
```

### ⚠️ コード明確性の問題

1. **可読性**: `tile.creature_data = {}` がどの層に反映されるか、パッと見ではわからない
2. **複雑性**: battle_system の return_data 構築が複雑
3. **エラーリスク**: 将来、誰かが CreatureManager を経由せずに creature_data を操作する可能性

---

## 改善案（オプション）

### 案1: メソッド化（明確性向上）
```gdscript
# 現在
tile.creature_data = {}

# 改善後
creature_manager.clear_creature(tile_index)
```

### 案2: ドキュメント追加（コメント）
```gdscript
# tile.creature_data は内部的に CreatureManager に委譲される
# 設定は自動的に CreatureManager.creatures[tile_index] に反映される
tile.creature_data = {}
```

---

## 結論

**SSoT 統一は既に実装されており、直接操作も正しく機能している。**

改善の必要性：
- 🟢 **機能的には OK** - データ整合性は取れている
- 🟡 **コード明確性は改善の余地あり** - ただし緊急度は低い
- 🔵 **リファクタリング優先度は低い** - 現状のままで動作する

