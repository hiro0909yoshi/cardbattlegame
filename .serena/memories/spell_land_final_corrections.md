# SpellLand - 属性と復帰スキルの修正

**実施日**: 2025年11月9日

## 修正内容

### 1. 属性名の修正 ✅
**誤**: "none"
**正**: "neutral"

#### 修正箇所
- `scripts/spells/spell_land.gd`の`_validate_element()`
- 有効な属性リスト更新

#### 正しい属性一覧
| 内部名 | 表示名 |
|--------|--------|
| fire | 火 |
| water | 水 |
| earth | 地 |
| air | 風 |
| wind | 風（別名） |
| neutral | 無 |

### 2. 復帰[ブック]システムの確認 ✅
**既存システムを活用**:
- 実装場所: `scripts/battle/skills/skill_item_return.gd`
- CardSystemの`return_card_to_deck()`メソッド使用

#### スペルでの使用方法
```gdscript
# 密命失敗時にカードをブックに戻す
card_system.return_card_to_deck(card_id, player_id)
```

#### 復帰の種類
- **復帰[ブック]**: `return_card_to_deck()` - デッキの一番上に戻る
- **復帰[手札]**: `return_card_to_hand()` - 手札に戻る（上限超過OK）

### 3. ドキュメント更新 ✅
- `docs/design/spells_design.md`に「復帰[ブック]について」セクション追加
- 既存システムの活用方法を記載

---

## 現在の実装状況（最終）

### SpellLand完全実装 ✅
- メソッド数: 10個
- 属性サポート: 6種類（fire, water, earth, air, wind, neutral）
- GameFlowManagerへの統合: 完了
- 検索メソッド: 最高/最低レベル領地検索実装済み

### 対応可能なスペル: 11個
1. アースシフト（地）
2. ウォーターシフト（水）
3. エアーシフト（風）
4. ファイアーシフト（火）
5. クインテッセンス（無）⭐ neutral対応
6. インフルエンス
7. アステロイド
8. サブサイド ⭐ find_highest_level_land使用
9. サドンインパクト（密命）
10. フラットランド（密命、復帰[ブック]使用）
11. ランドトランス

---

## 密命スペルの実装パターン

### フラットランド（ID: 2085）
```gdscript
func _execute_flatten_land_spell(player_id: int, card_id: int):
    # 条件チェック: レベル2領地を5つ持つか
    var condition = {"required_level": 2}
    var changed_count = spell_land.change_level_multiple_with_condition(
        player_id, condition, 1
    )
    
    if changed_count >= 5:
        # 成功: レベルアップ完了
        print("フラットランド成功: %d個の領地をレベルアップ" % changed_count)
    else:
        # 失敗: カードをブックに戻す
        card_system.return_card_to_deck(card_id, player_id)
        print("フラットランド失敗: カードをブックに戻しました")
```

### ホームグラウンド（ID: 2096）
```gdscript
func _execute_home_ground_spell(player_id: int, card_id: int):
    # 条件チェック: 属性違いの領地を4つ持つか
    var mismatched_lands = []
    var dominant_element = spell_land.get_player_dominant_element(player_id)
    
    for tile_index in range(20):
        var tile = board_system.tiles[tile_index]
        if tile.tile_owner == player_id and tile.element != dominant_element:
            mismatched_lands.append(tile_index)
    
    if mismatched_lands.size() >= 4:
        # 成功: 属性を合わせる
        for tile_index in mismatched_lands:
            spell_land.change_element(tile_index, dominant_element)
        print("ホームグラウンド成功")
    else:
        # 失敗: カードをブックに戻す
        card_system.return_card_to_deck(card_id, player_id)
        print("ホームグラウンド失敗")
```

---

## 次のステップ

1. **SpellPhaseHandlerへの統合**（最優先）
2. 個別スペルカードのJSON定義（effect_parsed）
3. ターゲット選択UIの土地選択対応
4. 特殊スペル（ストームシフト、マグマシフト）の実装

---

**最終更新**: 2025年11月9日
