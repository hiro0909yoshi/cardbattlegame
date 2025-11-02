# SpellDrawシステム設計（2025-11-03）

## 📋 背景と要件

### ユーザー要望
- トゥームストーン（1038）実装のため、ドロー処理の汎用化が必要
- 今後、バトル外のマップ効果（魔力増減、ダイス操作、手札破壊、領地変更など）が増える
- これらを`scripts/spells/`フォルダに分離して管理したい

### 現在のドロー処理
**使用箇所は実質1箇所のみ**:
- `game_flow_manager.gd` (129行目): ターン開始時に`card_system.draw_card_for_player()`で1枚ドロー
- `card_system.gd`に`deal_initial_hands_all_players()`が存在するが、現在どこからも呼ばれていない

### 重要な仕様
**手札上限の扱い**:
- ドロー時は手札上限チェック不要（何枚でも引ける）
- ターン終了時に6枚を超えていたら超過分を捨てる
  - 人間プレイヤー: 手動選択
  - CPU: 自動（後ろから捨てる）
- `game_flow_manager.gd`の`check_and_discard_excess_cards()`で実装済み

## 📁 新規フォルダ構成

```
scripts/
├── spells/               # 新規作成
│   ├── spell_draw.gd     # ドロー処理（今回実装）
│   ├── spell_magic.gd    # 魔力増減（将来）
│   ├── spell_dice.gd     # ダイス操作（将来）
│   ├── spell_hand.gd     # 手札操作（破壊、交換）（将来）
│   └── spell_land.gd     # 領地変更（将来）
```

**配置理由**:
- `battle/` = バトル中の効果（ダメージ、スキル等）
- `spells/` = バトル外、マップ全体に影響する効果
- 対称的で理解しやすい構造

## 💡 SpellDraw設計

### 実装するメソッド（4つ）

```gdscript
# scripts/spells/spell_draw.gd
class_name SpellDraw

var card_system_ref: CardSystem = null

func setup(card_system: CardSystem):
    card_system_ref = card_system

## 1. 固定枚数ドロー
func draw_cards(player_id: int, count: int) -> int:
    """
    指定枚数カードを引く
    用途: 「2枚引く」「3枚引く」などの固定ドロー
    """
    var drawn = card_system_ref.draw_cards_for_player(player_id, count)
    print("[ドロー] プレイヤー", player_id + 1, "が", drawn.size(), "枚引きました")
    return drawn.size()

## 2. 上限までドロー（手札補充）
func draw_until(player_id: int, target_hand_size: int) -> int:
    """
    手札が指定枚数になるまで引く
    例: 
      - 現在手札2枚、target=6 → 4枚引く
      - 現在手札5枚、target=6 → 1枚引く
      - 現在手札6枚、target=6 → 0枚引く
      - 現在手札7枚、target=6 → 0枚引く（引かない）
    
    用途:
      - トゥームストーン（1038）: draw_until(player_id, 6)  # 6枚まで引く
      - 5枚までドロースペル: draw_until(player_id, 5)
    """
    var current_hand_size = card_system_ref.get_hand_size_for_player(player_id)
    var needed = target_hand_size - current_hand_size
    
    if needed <= 0:
        print("[ドロー] プレイヤー", player_id + 1, "は既に", current_hand_size, 
              "枚持っているため引きません")
        return 0
    
    var drawn = card_system_ref.draw_cards_for_player(player_id, needed)
    print("[ドロー] プレイヤー", player_id + 1, "が手札", target_hand_size, 
          "枚まで補充（", drawn.size(), "枚引いた）")
    return drawn.size()

## 3. 1枚ドロー（ターン開始用）
func draw_one(player_id: int) -> Dictionary:
    """ターン開始時の1枚ドロー"""
    return card_system_ref.draw_card_for_player(player_id)

## 4. 手札交換
func exchange_all_hand(player_id: int) -> int:
    """
    手札を全て捨てて同じ枚数引き直す
    例: 手札4枚 → 4枚捨てて4枚引く
    """
    var hand_size = card_system_ref.get_hand_size_for_player(player_id)
    
    if hand_size == 0:
        print("[手札交換] 手札が0枚のため交換しません")
        return 0
    
    # 全て捨てる（常にindex 0を捨てる、配列が縮むため）
    for i in range(hand_size):
        card_system_ref.discard_card(player_id, 0, "exchange")
    
    # 同じ枚数引く
    var drawn = card_system_ref.draw_cards_for_player(player_id, hand_size)
    print("[手札交換] プレイヤー", player_id + 1, "が", hand_size, "枚交換しました")
    return drawn.size()
```

## 📊 メソッド比較表

| メソッド | 用途 | 使用例 |
|---------|------|--------|
| `draw_cards(player_id, count)` | 固定枚数引く | 2枚引く、3枚引くスペル |
| `draw_until(player_id, target)` | 指定枚数まで補充 | トゥームストーン（6枚まで）、5枚まで引くスペル |
| `draw_one(player_id)` | 1枚引く | ターン開始時 |
| `exchange_all_hand(player_id)` | 全交換 | 手札リセット系スペル |

## 🎯 使用例

### トゥームストーン（1038）の実装
```gdscript
# 自クリーチャー破壊時の効果
if item_has_tombstone_effect:
    SpellDraw.draw_until(player_id, 6)
```

### カードドロースペル
```gdscript
# 2枚引くスペル
SpellDraw.draw_cards(player_id, 2)

# 5枚まで引くスペル
SpellDraw.draw_until(player_id, 5)
```

### ターン開始時（既存の置き換え）
```gdscript
# game_flow_manager.gd (129行目)
# 変更前: var drawn = card_system.draw_card_for_player(current_player.id)
# 変更後: var drawn = SpellDraw.draw_one(current_player.id)
```

## ⚠️ 重要な決定事項

### ゲーム開始時の初期配布は含めない
- `CardSystem.deal_initial_hands_all_players()`が既に存在
- ゲーム初期化は別の責務
- SpellDrawは「ゲーム中のドロー効果」に特化

### 既存のCardSystemメソッドは残す
- `draw_card_for_player()`, `draw_cards_for_player()`は残す
- SpellDrawは内部でこれらを呼び出す
- 下位互換性を保つ

## 🚀 次のステップ

1. **`scripts/spells/spell_draw.gd`を作成**
2. **トゥームストーン（1038）の実装**
   - 破壊時効果として`SpellDraw.draw_until(player_id, 6)`を呼び出す
3. **将来的な拡張**
   - 他のスペル効果モジュールを同様に作成
   - `spell_magic.gd`, `spell_dice.gd`, `spell_hand.gd`, `spell_land.gd`

## 📝 参考情報

### CardSystemの既存メソッド
- `draw_card_for_player(player_id)` - 1枚引く、Dictionaryを返す
- `draw_cards_for_player(player_id, count)` - 複数枚引く、Arrayを返す
- `get_hand_size_for_player(player_id)` - 現在の手札枚数を取得
- `discard_card(player_id, card_index, reason)` - カードを捨てる

### 手札上限管理
- 定数: `GameConstants.MAX_HAND_SIZE = 6`
- 調整処理: `game_flow_manager.check_and_discard_excess_cards()`
- タイミング: ターン終了時（`end_turn()`内で呼ばれる）
