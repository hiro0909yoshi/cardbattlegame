# current_hp 設計の詳細検討 - 「召喚時に Base HP から設定、上昇時に current_hp も上昇」

**プロジェクト**: カルドセプト風カードバトルゲーム  
**作成日**: 2025年11月17日  
**目的**: HP上昇時の current_hp 自動調整設計の検討

---

## 📋 目次

1. [提案する設計](#提案する設計)
2. [メリット](#メリット)
3. [デメリット・注意点](#デメリット注意点)
4. [具体的な実装例](#具体的な実装例)
5. [比較：他の設計パターン](#比較他の設計パターン)
6. [推奨される実装アプローチ](#推奨される実装アプローチ)
7. [実装チェックリスト](#実装チェックリスト)

---

## 提案する設計

### コンセプト

```
【召喚時】
creature_data["current_hp"] = creature_data["hp"]  # Base HP と同じ値に初期化

【バトル中】
current_hp -= damage  # ダメージで削られる

【HP上昇イベント】
base_up_hp が増加する
  ↓
current_hp も同じ分だけ増加

例：マスグロース（+5）
  base_up_hp: 0 → 5
  current_hp: 30 → 35（+5上昇）
```

### HP構造の概念図

```
【バトル外】
creature_data = {
  "hp": 30,          # 元のHP（不変）
  "base_up_hp": 0,   # 永続ボーナス
  "current_hp": 30   # 現在HP
}
実効MHP = 30 + 0 = 30

【マスグロース適用後】
creature_data = {
  "hp": 30,
  "base_up_hp": 5,   # +5
  "current_hp": 35   # +5（自動調整）
}
実効MHP = 30 + 5 = 35

【ダメージ後】
"current_hp": 35
  ↓ 10ダメージ
"current_hp": 25
MHP は 35 のまま
```

---

## メリット

### 1. **直感的で自然**

プレイヤー視点では：
- 「HP上昇スキル → そのまま HP が増える」
- 複雑な計算がなく理解しやすい

```
ユーザー期待：マスグロース +5 → 現在HP +5
実装（この設計）：その期待通り
```

---

### 2. **バグの温床を減らす**

現在のシステムでありがちな問題：
```
【現在のシステム】
base_up_hp が変わる
  ↓
current_hp を再計算（update_current_hp()）
  ↓
計算タイミングが漏れるとバグ

【提案設計】
base_up_hp が変わる → current_hp も変わる
  ↓
同期が自動的に保たれる
```

---

### 3. **HP上昇スキルのロジック簡潔化**

```
【現在】
base_up_hp += 5
update_current_hp()  # 再計算

【提案】
base_up_hp += 5
current_hp += 5      # 直接加算
```

シンプルで見やすい

---

### 4. **バトル中の動的なHP上昇に対応しやすい**

```
例：バトル中に永続バフが適用される場合
base_up_hp += 10
current_hp += 10  # そのまま反映

UI表示も自動的に更新される
```

---

### 5. **ダメージ後も保存・復元が一貫している**

```
バトル後：creature_data["current_hp"] = current_hp
次のバトル：そのまま復元して use

計算不要、直接代入のみ
```

---

## デメリット・注意点

### 1. **「上昇分だけ回復」との区別**

```
【注意が必要なケース】
マスグロース：MHP+5 かつ 現在HP+5（上昇分と同じだけ回復）
ブレッシング（一時効果）：現在HP+10 のみ

混在する可能性がある
```

**対策**: 効果の種類ごとに処理を分ける

---

### 2. **スキル・スペル側での実装の複雑さ**

```
【スペル処理】
base_up_hp が増加する効果
  ↓
current_hp も増加させる必要がある

スペル/スキル側で current_hp にアクセスする必要あり
  または
バトル側で一括処理する必要あり
```

**対策**: BattleParticipant に増加メソッドを用意

```gdscript
func increase_max_hp(amount: int) -> void:
    base_up_hp += amount
    current_hp += amount
    print("HP上昇: +", amount)
```

---

### 3. **バトル中以外での HP 上昇に対応が必要**

```
【バトル外での上昇】
マスグロース、合成、周回ボーナスなど
  ↓
creature_data["current_hp"] も更新する必要あり

バトル中と同じロジックが必要
```

---

### 4. **一時的なボーナスとの混同リスク**

```
【注意】
base_up_hp（永続）が増加 → current_hp +
temporary_bonus_hp（一時）が増加 → current_hp は変わらない

両者の区別を厳密に
```

---

### 5. **HP上昇が MHP 超過する場合**

```
例：現在HP 28/30 の状態でマスグロース +5
  base_up_hp: 0 → 5
  MHP: 30 → 35
  current_hp: 28 → 33

ユーザー期待：33（上昇分だけ加算）
実装：33（OK）
```

通常は問題ないが、条件付きで上限チェックが必要な場合あり

---

## 具体的な実装例

### 1. 召喚時の初期化

```gdscript
# movement_helper.gd または tile_action_processor.gd

func summon_creature(card_data: Dictionary, tile_index: int, player_id: int):
    # 召喚時に current_hp を base_hp に設定
    var creature = card_data.duplicate()
    
    # 元のHP
    var base_hp = creature.get("hp", 0)
    var base_up_hp = creature.get("base_up_hp", 0)
    
    # current_hp を設定（Base HP と同じ）
    creature["current_hp"] = base_hp
    
    # タイルに配置
    board_system.place_creature(tile_index, creature)
    
    print("[召喚] ", creature["name"], 
          " HP: ", base_hp, 
          " (MHP: ", base_hp + base_up_hp, ")")
```

---

### 2. マスグロース処理

```gdscript
# スペル処理

func apply_mass_growth(creature_data: Dictionary, hp_increase: int = 5):
    """
    マスグロース: MHP+5 かつ 現在HP+5
    """
    # 1. 永続ボーナスを増加
    creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + hp_increase
    
    # 2. 現在HPも同じ分だけ増加（新システム）
    creature_data["current_hp"] = creature_data.get("current_hp", 0) + hp_increase
    
    # MHP計算用
    var base_hp = creature_data.get("hp", 0)
    var new_base_up_hp = creature_data["base_up_hp"]
    var new_mhp = base_hp + new_base_up_hp
    
    print("[マスグロース] ", creature_data.get("name", ""), 
          " MHP+", hp_increase, " → ", new_mhp,
          " 現在HP+", hp_increase, " → ", creature_data["current_hp"])
```

---

### 3. バトル中の HP 上昇（永続バフ適用時）

```gdscript
# battle_special_effects.gd または battle_system.gd

func apply_permanent_buff_during_battle(
    participant: BattleParticipant, 
    buff_type: String, 
    value: int
):
    """
    バトル中に永続バフが適用される場合
    例：バルキリー（敵撃破時 AP+10 または HP+5）
    """
    match buff_type:
        "hp":
            # 方法1：メソッドを用意する場合
            participant.increase_max_hp(value)
            
        "ap":
            participant.increase_base_ap(value)
```

**BattleParticipant に以下のメソッドを追加**:

```gdscript
# battle_participant.gd

func increase_max_hp(amount: int) -> void:
    """
    永続的な基礎HP上昇（base_up_hp を増やす）
    同時に current_hp も増加
    
    用途：マスグロース、バルキリー、周回ボーナスなど
    """
    if amount <= 0:
        return
    
    base_up_hp += amount
    current_hp += amount
    
    print("【HP上昇】", creature_data.get("name", ""), 
          " MHP+", amount, " → ", get_max_hp(),
          " 現在HP+", amount, " → ", current_hp)

func increase_base_ap(amount: int) -> void:
    """
    永続的な基礎AP上昇（base_up_ap を増やす）
    """
    if amount <= 0:
        return
    
    base_up_ap += amount
    current_ap = creature_data.get("ap", 0) + base_up_ap + temporary_bonus_ap + item_bonus_ap
    
    print("【AP上昇】", creature_data.get("name", ""), 
          " AP+", amount, " → ", current_ap)
```

---

### 4. 周回ボーナス処理

```gdscript
# game_flow_manager.gd

func apply_lap_bonus(creature_data: Dictionary, bonus: Dictionary):
    """
    周回ボーナス
    stat: "max_hp" の場合、base_up_hp と current_hp を増加
    """
    var stat = bonus.get("stat", "")
    var value = bonus.get("value", 0)
    
    if stat == "max_hp":
        # 1. 永続ボーナスを増加
        creature_data["base_up_hp"] = creature_data.get("base_up_hp", 0) + value
        
        # 2. 現在HPも増加（新システム）
        creature_data["current_hp"] = creature_data.get("current_hp", 0) + value
        
        var base_hp = creature_data.get("hp", 0)
        var new_mhp = base_hp + creature_data["base_up_hp"]
        
        print("[周回ボーナス] ", creature_data.get("name", ""), 
              " MHP+", value, " → ", new_mhp,
              " 現在HP+", value, " → ", creature_data["current_hp"])
    
    elif stat == "ap":
        creature_data["base_up_ap"] = creature_data.get("base_up_ap", 0) + value
```

---

### 5. 合成処理

```gdscript
# スキル/アイテム処理

func apply_synthesis_effect(
    base_creature_data: Dictionary, 
    sacrifice_creature_data: Dictionary,
    synthesis_data: Dictionary
) -> Dictionary:
    """
    合成効果：生贄のステータスを吸収
    """
    var result = base_creature_data.duplicate()
    
    # ステータス上昇
    var hp_gain = synthesis_data.get("hp_gain", 0)
    var ap_gain = synthesis_data.get("ap_gain", 0)
    
    if hp_gain > 0:
        # 1. 永続ボーナスに加算
        result["base_up_hp"] = result.get("base_up_hp", 0) + hp_gain
        
        # 2. 現在HPも加算（新システム）
        result["current_hp"] = result.get("current_hp", 0) + hp_gain
        
        print("[合成] HP+", hp_gain)
    
    if ap_gain > 0:
        result["base_up_ap"] = result.get("base_up_ap", 0) + ap_gain
        print("[合成] AP+", ap_gain)
    
    return result
```

---

## 比較：他の設計パターン

### パターンA：提案設計（HP上昇時に current_hp も上昇）

```
上昇時の処理：
base_up_hp += 5
current_hp += 5

利点：直感的、シンプル
欠点：base_up_hp の変更箇所すべてで current_hp も変更が必要
```

---

### パターンB：一時的には上昇しない（バトル後に反映）

```
上昇時の処理：
base_up_hp += 5
current_hp は変わらない

バトル後：
current_hp = hp + base_up_hp + ダメージ後の値

利点：バトル中の計算が簡潔
欠点：バトル中に HP が増えたかどうかわかりにくい
```

---

### パターンC：上限までのみ上昇

```
上昇時の処理：
var new_hp = min(current_hp + 5, max_hp + 5)
current_hp = new_hp

利点：上限超過を防ぐ
欠点：複雑、予期しない動作の可能性
```

---

### 推奨：パターンA（提案設計）

**理由**:
1. 最も直感的
2. 実装が単純
3. ユーザー期待と一致
4. デバッグが容易

---

## 推奨される実装アプローチ

### ステップ1: BattleParticipant に増加メソッドを用意

```gdscript
# battle_participant.gd

func increase_max_hp(amount: int) -> void:
    """永続的なHP上昇（base_up_hp と current_hp を同時に増加）"""
    if amount <= 0:
        return
    base_up_hp += amount
    current_hp += amount

func increase_base_ap(amount: int) -> void:
    """永続的なAP上昇（base_up_ap を増加）"""
    if amount <= 0:
        return
    base_up_ap += amount
    # current_ap は update_current_ap() で再計算
```

---

### ステップ2: creature_data 操作用のヘルパー関数を用意

```gdscript
# ゲーム管理側（creature_manager.gd または別のシステム）

func increase_creature_max_hp(tile_index: int, amount: int) -> void:
    """
    タイル上のクリーチャーの永続HP上昇
    """
    var creature = creature_manager.get_creature(tile_index)
    if creature:
        creature["base_up_hp"] = creature.get("base_up_hp", 0) + amount
        creature["current_hp"] = creature.get("current_hp", 0) + amount
        
        print("[永続HP上昇] ", creature.get("name", ""),
              " MHP+", amount, " → ", 
              creature.get("hp", 0) + creature["base_up_hp"],
              " 現在HP+", amount, " → ", creature["current_hp"])
```

---

### ステップ3: スペル・スキル側で統一的に使用

```gdscript
# spell_magic.gd または skill_effect.gd

# バトル中の場合
if battle_participant:
    battle_participant.increase_max_hp(5)

# バトル外の場合
else:
    increase_creature_max_hp(tile_index, 5)
```

---

## 実装チェックリスト

### Phase 1: 基本メソッド整備

- [ ] BattleParticipant.increase_max_hp() を追加
- [ ] BattleParticipant.increase_base_ap() を追加
- [ ] creature_data 操作用ヘルパー関数を追加
- [ ] ドキュメント・コメント記載

### Phase 2: スペル処理の統一

- [ ] マスグロース処理を修正（increase_max_hp() 使用）
- [ ] ドミナントグロース処理を修正
- [ ] 永続HP関連のスペルを修正
- [ ] テスト実行

### Phase 3: スキル処理の統一

- [ ] バルキリー処理を修正
- [ ] その他永続HP上昇スキルを修正
- [ ] テスト実行

### Phase 4: 周回ボーナス処理

- [ ] game_flow_manager.gd を修正
- [ ] テスト実行

### Phase 5: 合成処理

- [ ] 合成処理を修正
- [ ] テスト実行

### Phase 6: 全体テスト

- [ ] 召喚時に current_hp が正しく初期化される
- [ ] マスグロース後に current_hp が増加する
- [ ] バトル終了後に HP が正しく保存される
- [ ] 次のバトルで HP が正しく復元される
- [ ] 複数の HP 上昇イベントが正しく累積される

---

## 実装時の注意事項

### 1. **確実に一貫性を保つ**

```
【チェック項目】
base_up_hp を増やすすべての箇所で current_hp も増やしているか

検索：grep -rn "base_up_hp \+=" scripts/
各箇所で current_hp も変更されているか確認
```

---

### 2. **一時ボーナスとの区別**

```
【区別】
base_up_hp（永続）→ current_hp も増加
temporary_bonus_hp（一時）→ current_hp は変わらない

混在しないことを確認
```

---

### 3. **ログ出力の統一**

```gdscript
# 統一されたログ形式
print("[永続HP上昇] ", name, 
      " MHP+", amount, " → ", new_mhp,
      " 現在HP+", amount, " → ", current_hp)
```

---

### 4. **UI表示の確認**

```
表示すべき値：
- 現在HP：current_hp
- MHP：base_hp + base_up_hp

両方が一貫して表示されるか確認
```

---

## 結論

### この設計は **推奨できます**

**理由**:
1. ✅ 直感的でわかりやすい
2. ✅ バグの温床を減らせる
3. ✅ 実装が単純
4. ✅ ユーザー期待と一致
5. ✅ スケーラブル（新しいHP上昇効果も簡単に対応）

---

### 実装時の重要ポイント

1. **BattleParticipant に increase_max_hp() メソッドを用意**
   - バトル中の処理を統一

2. **creature_data 操作用のヘルパー関数を用意**
   - バトル外の処理を統一

3. **すべての HP 上昇効果で統一的なメソッド使用**
   - マスグロース、バルキリー、周回ボーナス、合成など

4. **テストを十分に実行**
   - HP 上昇、保存、復元の各シナリオ

---

**最終更新**: 2025年11月17日（v1.0）
