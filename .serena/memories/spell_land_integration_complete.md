# SpellLand - GameFlowManager統合完了記録

**実装日**: 2025年11月9日

## 完了した作業

### 1. 密命システムの説明追加
- `docs/design/spells_design.md`に「密命（Mission）システム」セクションを追加
- 密命の概要、動作フロー、実装例を記載
- 密命は個別スペルで実装し、専用システムは不要と明記

### 2. GameFlowManagerへの統合 ✅
**ファイル**: `scripts/game_flow_manager.gd`

#### 変数追加
```gdscript
var spell_land: SpellLand
```

#### 初期化メソッド追加
```gdscript
func _setup_spell_systems(board_system):
    # SpellDraw初期化
    # SpellMagic初期化
    # SpellLand初期化（CreatureManagerも参照）
```

#### 統合箇所
`setup_systems()`メソッド内で`_setup_spell_systems(b_system)`を呼び出し

### 3. SpellLandへのメソッド追加
**ファイル**: `scripts/spells/spell_land.gd`

#### 新規メソッド
1. `find_highest_level_land(player_id)` - 最高レベル領地検索
2. `find_lowest_level_land(player_id)` - 最低レベル領地検索

#### 属性の拡張
- `_validate_element()`に"none"（無属性）を追加

### 4. ドキュメント更新
- `docs/design/spells/領地変更.md`に検索メソッドの説明追加
- 使用例（サブサイド）を記載

---

## 現在の状態

### ✅ 完全統合済み
- GameFlowManagerに統合完了
- 初期化処理実装済み
- エラーハンドリング実装済み

### 🎯 次のステップ

#### 優先度：高
1. **SpellPhaseHandlerへの統合**
   - 土地操作系スペルの`effect_type`処理
   - ターゲット選択UIとの連携
   
2. **個別スペルカードのJSON定義**
   - `effect_parsed`フィールドの定義
   - 最低でも基本的な3つ（アースシフト、アステロイド、ランドトランス）

#### 優先度：中
3. **特殊スペルの実装**
   - サブサイド（最高レベル検索使用）
   - ストームシフト（条件分岐）
   - マグマシフト（条件分岐）

4. **密命スペルの実装**
   - フラットランド
   - ホームグラウンド
   - サドンインパクト

---

## 技術仕様

### 初期化順序（重要）
```
1. PlayerSystem
2. CardSystem
3. BoardSystem3D
   └─ CreatureManager（自動初期化）
4. SpellDraw
5. SpellMagic
6. SpellLand（BoardSystem3DとCreatureManagerが必要）
```

### SpellLandの依存関係
- **BoardSystem3D**: タイルデータへのアクセス
- **CreatureManager**: クリーチャー管理
- **PlayerSystem**: プレイヤーデータアクセス

### エラーハンドリング
- 各システムの参照が`null`の場合は`push_error()`
- BoardSystemが未設定の場合は`push_warning()`（オプション扱い）

---

## 属性一覧（確認済み）

| 内部名 | 表示名 | 実装状況 |
|--------|--------|---------|
| fire | 火 | ✅ |
| water | 水 | ✅ |
| earth | 地 | ✅ |
| air | 風 | ✅ |
| none | 無 | ✅ |

---

## 実装済みメソッド一覧（合計10個）

### 基本メソッド（5個）
1. `change_element()` - 土地属性変更
2. `change_level()` - レベル増減
3. `set_level()` - レベル固定
4. `destroy_creature()` - クリーチャー破壊
5. `abandon_land()` - 土地放棄（価値計算含む）

### 高度なメソッド（3個）
6. `change_element_with_condition()` - 条件付き属性変更
7. `get_player_dominant_element()` - 最多属性取得
8. `change_level_multiple_with_condition()` - 条件付き一括レベル変更

### 検索メソッド（2個） ⭐NEW
9. `find_highest_level_land()` - 最高レベル領地検索
10. `find_lowest_level_land()` - 最低レベル領地検索

---

## 対応可能なスペル（現時点）

### 完全対応可能（11個）
- 2001: アースシフト
- 2010: ウォーターシフト
- 2011: エアーシフト
- 2074: ファイアーシフト
- 2022: クインテッセンス
- 2008: インフルエンス
- 2003: アステロイド
- **2030: サブサイド** ⭐NEW（find_highest_level_land使用）
- 2029: サドンインパクト（条件チェックのみ追加）
- 2085: フラットランド（change_level_multiple_with_condition使用）
- 2118: ランドトランス

### 追加実装が必要（2個）
- 2040: ストームシフト（複雑な条件分岐）
- 2103: マグマシフト（複雑な条件分岐）

---

## 使用例（サブサイド）

```gdscript
# SpellPhaseHandler内での処理例
func _execute_subside_spell(target_player_id: int):
    # 最高レベル領地を検索
    var highest_tile = game_flow_manager.spell_land.find_highest_level_land(target_player_id)
    
    if highest_tile != -1:
        # レベルを1下げる
        game_flow_manager.spell_land.change_level(highest_tile, -1)
        print("サブサイド発動: タイル%dのレベルを下げました" % highest_tile)
    else:
        print("サブサイド: 対象プレイヤーは土地を所有していません")
```

---

**最終更新**: 2025年11月9日
