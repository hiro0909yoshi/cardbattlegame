# 🚨 開発時の必須確認事項

## 最重要：design.md を必ず読むこと

**ファイル**: `docs/design/design.md`

このファイルには以下の重要情報が含まれています：

### 1. コーディング規約・技術的制約

#### 予約語回避パターン
```gdscript
# ❌ NG: owner（Nodeの予約語）
var tile_owner: int

# ✅ OK: 別の名前を使用
var tile_owner_id: int

# ❌ NG: is_processing()（Nodeのメソッド）
func is_processing() -> bool

# ✅ OK: 別の名前を使用
func is_battle_active() -> bool
```

#### TextureRect制約
```gdscript
# ❌ NG: color プロパティは使用不可
texture_rect.color = Color.RED

# ✅ OK: modulate を使用
texture_rect.modulate = Color.RED
```

### 2. システムアーキテクチャ

#### 主要システム
- **GameFlowManager**: ゲーム進行・フェーズ管理
- **BoardSystem3D**: マップ・タイル管理
- **CardSystem**: デッキ・手札管理
- **BattleSystem**: 戦闘判定・ボーナス計算
- **PlayerSystem**: プレイヤー情報・ターン管理
- **SkillSystem**: スキル効果・条件判定
- **UIManager**: UI統括管理（7コンポーネントに分割）

#### シグナル駆動通信
各システムはシグナルで疎結合に通信：
```gdscript
signal tile_action_completed()
signal battle_ended(winner, result)
signal phase_changed(new_phase)
```

### 3. データ構造

#### ability_parsed の標準形式
```json
{
  "keywords": ["感応", "先制", "強打"],
  "keyword_conditions": {
    "感応": {
      "element": "fire",
      "stat_bonus": {
        "ap": 20,
        "hp": 20
      }
    }
  },
  "effects": [
    {
      "effect_type": "power_strike",
      "multiplier": 1.5,
      "conditions": [
        {
          "condition_type": "adjacent_ally_land"
        }
      ]
    }
  ]
}
```

#### カードデータ構造
```json
{
  "id": 1,
  "name": "クリーチャー名",
  "rarity": "N|R|S|E",
  "type": "creature|spell|item",
  "element": "fire|water|earth|wind|neutral",
  "cost": {
    "mp": 50,
    "lands_required": ["fire"]
  },
  "ap": 30,
  "hp": 40,
  "ability": "感応・先制",
  "ability_detail": "感応[地・ST&HP+20]；先制",
  "ability_parsed": { /* 上記の形式 */ }
}
```

### 4. 開発上の重要な注意点

#### フェーズ管理の厳格化
```gdscript
# 重複処理を防ぐ
if current_phase == GamePhase.END_TURN:
    return
```

#### シグナル接続の注意
```gdscript
# CONNECT_ONE_SHOTで多重接続防止
signal.connect(callback, CONNECT_ONE_SHOT)
```

#### ノード有効性チェック
```gdscript
if card_node and is_instance_valid(card_node):
    card_node.queue_free()
```

#### await使用時の注意
```gdscript
# ターン遷移前に必ず待機
await get_tree().create_timer(1.0).timeout
```

#### 変数シャドウイングの回避
```gdscript
# ❌ NG: クラスメンバと同名のローカル変数
var player_system = ...

# ✅ OK: 異なる名前を使用
var p_system = ...
```

### 5. バトルシステムの仕様

#### 先制攻撃システム
```
1. 攻撃側の先制攻撃
   AP >= 防御側HP? → 攻撃側勝利（終了）
   
2. 防御側生存なら反撃
   ST >= 攻撃側HP? → 防御側勝利
   
3. 両者生存 → 攻撃側勝利（土地獲得）
```

#### ボーナス計算
```gdscript
return {
  "st_bonus": 属性相性ボーナス(+20),
  "hp_bonus": 地形ボーナス(+10~40) + 連鎖ボーナス
}
```

### 6. 属性連鎖システム

```
連鎖数    通行料倍率    HPボーナス
  1個        1.0倍        +10
  2個        1.5倍        +20
  3個        2.5倍        +30
  4個以上    4.0倍        +40 (上限)
```

---

## チェックリスト

新機能実装前に必ず確認：

- [ ] `docs/design/design.md` を読んだ
- [ ] 予約語を使っていないか確認
- [ ] データ構造が正しいか確認（特に `ability_parsed`）
- [ ] システム間の連携方法を理解した
- [ ] シグナル駆動通信を使っている
- [ ] ノード有効性チェックを入れた
- [ ] フェーズ管理の重複防止を入れた

---

**最終更新**: 2025年10月23日
