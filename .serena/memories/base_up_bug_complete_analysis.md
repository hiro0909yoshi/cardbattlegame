# ベースアップバグの根本原因と問題点 - 完全分析 (2025-11-16)

## 🎯 根本原因

**CardLoaderのall_cardsが「マスターデータ（読み込み専用）」として扱われていない**

ゲーム中に複数のレイヤーで参照が直接渡され、最終的にCardLoaderのall_cardsが直接修正される。

## 📋 問題点の階層

### 問題1：初期化時の参照管理（CardLoaderレベル）

```
CardLoader.load_all_cards()
  ↓
all_cards = JSONから読み込んだカードデータ
  ↓
all_cardsは「マスターデータ」のはずだが、参照で渡される
```

**問題**: CardLoader.get_card_by_id()が参照を返しており、呼び出し側がコピーを取っていない

### 問題2：手札初期化時の参照管理（CardSystemレベル）

```
game_start()
  ↓
card_system.deal_initial_hands_all_players()
  ↓
draw_card_data_v2(player_id)
  ↓
_load_card_data(card_id)
  ↓
CardLoader.get_card_by_id(card_id)  // 参照
  ↓
return card_data  // 参照をそのまま返す
  ↓
player_hands[player_id]["data"].append(card_data)  // 参照を保存
```

**問題**: _load_card_data()でduplicateせず、参照を手札に保存している

### 問題3：バトル開始時の参照管理（BattleSystemレベル）

```
battle_system.execute_3d_battle()
  ↓
card_data = card_system.get_card_data_for_player(attacker_index, card_index)
// ← 手札から参照を取得
  ↓
battle_preparation.prepare_participants(attacker_index, card_data, ...)
// ← 参照をそのまま渡す
  ↓
BattleParticipant.new(card_data, ...)
// ← 参照を保持
  ↓
creature_data = p_creature_data  // 参照を保持
```

**問題**: バトル開始時にカードデータをコピーしていない

### 問題4：バトル中の永続バフ処理

```
battle_system._apply_on_destroy_permanent_buffs(participant)
  ↓
participant.creature_data["base_up_hp"] += 10
// ← CardLoaderのall_cardsを直接修正！
```

**問題**: BattleParticipantが参照を保持しているため、修正がCardLoaderに反映される

## 🔗 参照伝播チェーン

```
CardLoader.all_cards[カードID]
    ↓ (参照)
CardLoader.get_card_by_id()
    ↓ (参照)
CardSystem._load_card_data()
    ↓ (参照)
CardSystem.player_hands[player_id]["data"][card_index]
    ↓ (参照)
CardSystem.get_card_data_for_player()
    ↓ (参照)
BattleSystem.execute_3d_battle()
    ↓ (参照)
BattlePreparation.prepare_participants()
    ↓ (参照)
BattleParticipant.creature_data
    ↓ (参照)
BattleSystem._apply_on_destroy_permanent_buffs()
    ↓
creature_data["base_up_hp"] += 10  // ★ CardLoaderを直接修正！
```

## 🐛 バグの現象

1. プレイヤー2がダスクドウェラーで敵を倒す (base_up_hp +10 × 3回 = +30)
   → CardLoader.all_cards内のダスクドウェラーが +30 に修正される

2. プレイヤー1がダスクドウェラーを手札から出す
   → 同じCardLoaderの参照を取得
   → 既に +30 になった状態で出現

3. 毎回上昇するわけではない理由
   → バトルテスト（battle_test_executor.gd）では duplicate(true) を使用しているため正常
   → ゲーム本体（execute_3d_battle）では duplicate(true) を使用していないため発生

## ✅ タイル側は正常に機能している

```
バトル終了時：
  place_creature_data = attacker.creature_data.duplicate(true)  // ← コピー！
  board_system.place_creature(tile_index, place_creature_data)
```

タイル上のクリーチャーデータは独立したコピーで保持されているため、タイル間の参照汚染は発生していない。

## 📝 修正が必要な箇所（優先度順）

### 最優先：CardSystem._load_card_data()
```gdscript
func _load_card_data(card_id: int) -> Dictionary:
	if CardLoader:
		var card_data = CardLoader.get_card_by_id(card_id)
		if card_data.is_empty():
			return {}
		
		# ★ ここでduplicateを追加 ★
		card_data = card_data.duplicate(true)
		
		// costを正規化...
		return card_data
```

理由: 手札初期化時から独立したコピーを保持させる

### 次点：BattleSystem.execute_3d_battle()
```gdscript
var card_data = card_system_ref.get_card_data_for_player(attacker_index, card_index)
# ★ ここでもduplicateを追加 ★
card_data = card_data.duplicate(true)

var participants = battle_preparation.prepare_participants(attacker_index, card_data, ...)
```

理由: 多重防御（レイヤーごとの初期化）

### 参考：BattleParticipant._init()
現状でも問題ないが、念のため：
```gdscript
func _init(p_creature_data: Dictionary, ...):
    # ★ ここでもduplicateを取ることを検討 ★
    creature_data = p_creature_data.duplicate(true)
```

## 🔍 追加調査結果 (2025-11-16 更新)

### バトル中の永続バフ処理の詳細な問題

**問題のコード（battle_system.gd）：**
```gdscript
# _apply_on_destroy_permanent_buffs 内
participant.creature_data["base_up_hp"] += value  // ← 参照を直接変更！
```

このコードが引き起こす問題：
1. **攻撃側の場合**：手札の参照 → CardLoaderのマスターデータを汚染
2. **防御側の場合**：タイルのコピーなので汚染はないが、`update_defender_hp`で元のタイルデータから再取得するため変更が失われる

### 正しい修正方法

**根本的な解決策**：
```gdscript
# ❌ 悪い：辞書に直接書き込み
participant.creature_data["base_up_hp"] += value

# ✅ 良い：BattleParticipantのプロパティに保存
participant.base_up_hp += value
```

**修正が必要な箇所（battle_system.gd）：**
- 668行目: `participant.creature_data["base_up_hp"] += value` → `participant.base_up_hp += value`
- 692行目: `participant.creature_data["base_up_hp"] -= 30` → `participant.base_up_hp -= 30`  
- 706行目: `participant.creature_data["base_up_hp"] += 10` → `participant.base_up_hp += 10`
- 746行目: `participant.creature_data["base_up_hp"] = new_base_up_hp` → `participant.base_up_hp = new_base_up_hp`

**タイル配置時の処理：**

攻撃側勝利時（288行目付近）：
```gdscript
var place_creature_data = attacker.creature_data.duplicate(true)
# BattleParticipantのプロパティから永続バフを反映
place_creature_data["base_up_hp"] = attacker.base_up_hp
place_creature_data["base_up_ap"] = attacker.base_up_ap
place_creature_data["current_hp"] = attacker.current_hp
board_system_ref.place_creature(tile_index, place_creature_data)
```

防御側勝利時（update_defender_hp内）：
```gdscript
func update_defender_hp(tile_info: Dictionary, defender: BattleParticipant) -> void:
    var tile_index = tile_info["index"]
    # defenderのcreature_dataを使う（バトル中の変更は含まない）
    var creature_data = defender.creature_data.duplicate()
    
    # BattleParticipantのプロパティから永続バフを反映
    creature_data["base_up_hp"] = defender.base_up_hp
    creature_data["base_up_ap"] = defender.base_up_ap
    
    # 現在HPを保存
    creature_data["current_hp"] = defender.base_hp + defender.base_up_hp
    
    # タイルのクリーチャーデータを更新
    board_system_ref.tile_data_manager.tile_nodes[tile_index].creature_data = creature_data
```

### この修正により解決される問題

1. **マスターデータ汚染の解消**：CardLoaderのall_cardsが変更されなくなる
2. **手札の汚染防止**：手札のカードデータが変更されなくなる
3. **防御側の永続バフ適用**：防御側が勝利した場合も永続バフが正しく適用される
4. **タイル上のみで永続バフ管理**：永続バフはタイル上のクリーチャーのみが保持する設計思想に合致

### 他への影響

スペル効果（マスグロース等）やレベルアップ効果（アースシフト等）は既にタイル上のクリーチャーを直接変更しているため、修正不要。

## 🎓 設計の教訓

1. **マスターデータは常に読み込み専用とすべき**
   - CardLoaderのall_cardsは修正されてはいけない

2. **参照チェーンを断ち切るべき**
   - 各レイヤーで独立したコピーを作成する
   - 参照で渡すべきではない

3. **初期化は複数レベルで行うべき**
   - CardLoader読み込み時
   - 手札作成時
   - バトル開始時
   - バトルパーティクル作成時

4. **参照と値の管理を明確にすべき**
   - 参照を渡す場所を限定する
   - コピーが必要な場所を明確にする
