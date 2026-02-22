# EP増減効果

**バージョン**: 3.0  
**最終更新**: 2025年11月29日  
**実装ファイル**: `scripts/spells/spell_magic.gd`

---

## 概要

EPの増加・減少・奪取・平均化を一元管理するモジュール。

---

## 実装済みスペル一覧

### スペル（16個）

| ID | 名前 | 効果 | 状態 |
|----|------|------|------|
| 2004 | アセンブルカード | 手札に4属性あり → 500EP | ✅ |
| 2007 | インシネレート | 破壊数×20蓄魔、カウントリセット | ✅ |
| 2020 | ギフト | 順位×50蓄魔 | ✅ |
| 2025 | クレアボヤンス | 敵スペルコスト合計×50%獲得 | ✅ |
| 2038 | スクイーズ | 敵カード破壊 + 150EP | ✅ |
| 2044 | スピードペナルティ | (敵周回-自周回)×100吸魔 | ✅ |
| 2051 | ジャーニー | ダイス呪い + 50EP | ✅ |
| 2062 | ドレインシジル | アルカナアーツ付与: 敵EP10%奪取(20EP) | ✅ |
| 2063 | ドレインマジック | 敵EP30%奪取 | ✅ |
| 2069 | バウンティハント | 呪い: 武器で破壊時300EP | ✅ |
| 2082 | フラクション | 敵EP30%奪取(自分より多い敵のみ) | ✅ |
| 2083 | ブラストトラップ | 土地呪い: 停止時EP40%減+HP-20 | ✅ |
| 2109 | マナ | 周回数×50蓄魔 | ✅ |
| 2118 | ランドトランス | 自ドミニオ放棄→価値×70%獲得 | ✅ |
| 2119 | ランドドレイン | 敵ドミニオ数×30吸魔 | ✅ |
| 2130 | レディビジョン | 全プレイヤーEP平均化 | ✅ |
| 2131 | ロングライン | 4連続ドミニオで500EP、未達成→ドロー | ✅ |

### クリーチャーアルカナアーツ（2個）

| ID | 名前 | アルカナアーツ効果 | 状態 |
|----|------|----------|------|
| 230 | ドワーフマイナー | 周回数×30蓄魔 | ✅ |
| 413 | ゴールドトーテム | 200蓄魔 + 自滅 | ✅ |

---

## effect_type一覧

| effect_type | 説明 | 主なスペル |
|-------------|------|-----------|
| `gain_magic` | 固定値獲得 | ジャーニー |
| `gain_magic_by_rank` | 順位×倍率 | ギフト |
| `gain_magic_by_lap` | 周回×倍率 | マナ、ドワーフマイナー |
| `gain_magic_from_destroyed_count` | 破壊数×倍率 | インシネレート |
| `gain_magic_from_spell_cost` | 敵スペルコスト参照 | クレアボヤンス |
| `gain_magic_from_land_chain` | 連続ドミニオ条件 | ロングライン |
| `drain_magic` | 固定値奪取 | - |
| `drain_magic_percentage` | 割合奪取 | ドレインマジック、フラクション |
| `drain_magic_by_land_count` | ドミニオ数×倍率奪取 | ランドドレイン |
| `drain_magic_by_lap_diff` | 周回差×倍率奪取 | スピードペナルティ |
| `balance_all_magic` | 全員平均化 | レディビジョン |
| `reduce_magic_percentage` | 割合減少（土地呪い） | ブラストトラップ |
| `self_destroy` | 自滅（アルカナアーツ用） | ゴールドトーテム |

---

## 主要関数

### 基本操作

```gdscript
# EP増減
add_magic(player_id, amount)
reduce_magic(player_id, amount) -> int  # 実際の減少量を返す

# 奪取（from → to）
drain_magic(from_player_id, to_player_id, amount) -> int
drain_magic_percentage(from_id, to_id, percentage) -> int
```

### 計算型

```gdscript
# 乗算型獲得
gain_magic_by_lap(player_id, multiplier)           # 周回×倍率
gain_magic_from_destroyed_count(player_id, effect) # 破壊数×倍率
gain_magic_from_spell_cost(player_id, effect, target_id, card_system)

# 乗算型奪取
drain_magic_by_land_count(effect, from_id, to_id)  # ドミニオ数×倍率
drain_magic_by_lap_diff(effect, from_id, to_id)    # 周回差×倍率
```

### 特殊効果

```gdscript
# グローバル
balance_all_magic() -> Dictionary  # 全員平均化

# 土地呪い
trigger_land_curse(tile_index, stopped_player_id)

# アルカナアーツ用
apply_self_destroy(tile_index, clear_land) -> bool
```

---

## JSON定義例

### スペル

```json
// ドレインマジック（割合奪取）
{
  "effect_type": "drain_magic_percentage",
  "target": "enemy",
  "percentage": 30
}

// マナ（周回×倍率）
{
  "effect_type": "gain_magic_by_lap",
  "multiplier": 50
}

// ブラストトラップ（土地呪い）
{
  "effect_type": "land_curse",
  "curse_type": "blast_trap",
  "trigger": "on_enemy_stop",
  "one_shot": true,
  "curse_effects": [
	{"effect_type": "reduce_magic_percentage", "target": "stopped_player", "percentage": 40},
	{"effect_type": "damage_creature", "target": "land_creature", "amount": 20}
  ]
}
```

### クリーチャーアルカナアーツ

```json
// ドワーフマイナー（マナ参照、倍率上書き）
"mystic_art": {
  "name": "EP採掘",
  "cost": 0,
  "spell_id": 2109,
  "effect_override": {"multiplier": 30}
}

// ゴールドトーテム（独自効果）
"mystic_art": {
  "name": "黄金献身",
  "cost": 0,
  "target_type": "none",
  "effects": [
	{"effect_type": "gain_magic", "amount": 200},
	{"effect_type": "self_destroy", "clear_land": true}
  ]
}
```

---

## 呼び出しフロー

### 土地呪い（ブラストトラップ）

```
BoardSystem3D._on_movement_completed()
  └→ GameFlowManager.trigger_land_curse_on_stop()
	   └→ SpellMagic.trigger_land_curse()
			└→ _apply_land_curse_effect()
```

### アルカナアーツ効果（ゴールドトーテム）

```
SpellPhaseHandler._execute_mystic_art()
  └→ SpellMysticArts.apply_mystic_art_effect()
	   └→ _apply_gain_magic() → SpellMagic.add_magic()
	   └→ _apply_self_destroy() → SpellMagic.apply_self_destroy()
```

---

## 更新履歴

| 日付 | Ver | 内容 |
|------|-----|------|
| 2025/11/29 | 3.0 | ドワーフマイナー、ゴールドトーテム、ブラストトラップ追加。ドキュメント簡潔化 |
| 2025/11/28 | 2.3 | 11スペル実装完了（ドレインマジック〜ロングライン） |
| 2025/11/27 | 2.0 | 通知ポップアップ機能追加 |
| 2025/11/26 | 1.0 | 初版作成 |
