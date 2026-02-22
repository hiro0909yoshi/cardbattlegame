# 戦闘終了時効果スキル (Battle End Effects)

## 概要

戦闘終了時（両者の攻撃完了後）に発動する効果を統一管理するシステム。
`trigger: "on_battle_end"` を持つ効果をチェックし、適用する。

## トリガーシステム

### 対応トリガー一覧

| trigger | タイミング | 例 |
|---------|-----------|-----|
| `on_attack_success` | 攻撃成功時 | ショッカー、ナイキー |
| `on_battle_end` | 戦闘終了時 | ルナティックヘア、サムハイン、スキュラ |
| `on_death` | 死亡時 | コーンフォーク、相討 |

### JSON形式

```json
"ability_parsed": {
  "effects": [
	{
	  "effect_type": "swap_ap_mhp",
	  "trigger": "on_battle_end",
	  "target": "enemy"
	}
  ]
}
```

## 対応クリーチャー

### 実装済み

| ID | 名前 | effect_type | 効果 |
|----|------|-------------|------|
| 443 | ルナティックヘア | swap_ap_mhp | 敵のAP⇔MHP交換 |
| 124 | スキュラ | apply_curse | 敵に刻印"免罪" |
| 317 | サムハイン | reduce_enemy_mhp | 敵のMHP-自分の基本AP |
| 245 | レーシィ | level_up_battle_land | 戦闘地レベル+1 |

### JSON設定済み（処理は既存クラスで対応）

| ID | 名前 | effect_type | condition | 効果 |
|----|------|-------------|-----------|------|
| 446 | ロックタイタン | after_battle_permanent_change | - | 自分のAP&MHP-10 |
| 130 | トリトン | draw_cards | self_item_used | カード1枚獲得 |
| 140 | マイコロン | spawn_creature | was_attacked | ランダム空地に配置 |
| 339 | ブルガサリ | permanent_stat_change | enemy_item_used | 自分のMHP+10 |

### condition一覧

| condition | 意味 |
|-----------|------|
| なし/省略 | 無条件（戦闘後に必ず発動）|
| was_attacked | 敵から攻撃を受けた場合 |
| self_item_used | 自分がアイテムを使用した場合 |
| enemy_item_used | 敵がアイテムを使用した場合 |

## 無効化システム

### ハングドマンズシール (ID: 2064)

世界刻印「吊人」により以下のトリガーを無効化：
- `on_battle_end` (戦闘終了時効果)
- `on_death` (自破壊時効果)
- `mystic_arts` (アルカナアーツ)

```json
// spell_world.json での定義
{
  "id": 2064,
  "name": "ハングドマンズシール",
  "effect_parsed": {
	"world_curse_type": "natural_world",
	"nullify_triggers": ["on_battle_end", "on_death", "mystic_arts"],
	"duration": 6
  }
}
```

### 無効化チェック

```gdscript
# SpellWorldCurse でチェック
if spell_world_curse.is_trigger_nullified("on_battle_end"):
	return  # 効果発動しない
```

## 処理フロー

```
battle_execution.gd
  ↓ 戦闘攻撃完了
  ↓ 生き残り効果チェック
  ↓ 崩壊刻印チェック
  ↓
SkillBattleEndEffects.process_all(attacker, defender, context)
  ├─ ハングドマンズシール無効化チェック
  ├─ 攻撃側の on_battle_end 効果を処理
  │   └─ swap_ap_mhp, apply_curse, reduce_enemy_mhp 等
  ├─ 防御側の on_battle_end 効果を処理
  └─ 死亡判定を返却
  ↓
battle_execution.gd
  ↓ 死亡フラグがあれば追加の撃破処理
```

## 実装クラス

**ファイル**: `scripts/battle/skills/skill_battle_end_effects.gd`

### メソッド

| メソッド | 説明 |
|---------|------|
| `process_all()` | 両者の戦闘終了時効果を処理 |
| `_process_effects()` | 単体の効果リストを処理 |
| `_apply_swap_ap_mhp()` | AP⇔MHP交換（ルナティックヘア）|
| `_apply_curse_effect()` | 刻印付与（スキュラ）|
| `_apply_reduce_mhp()` | MHP減少（サムハイン）|
| `_apply_level_up_battle_land()` | 土地レベルアップ（レーシィ）|
| `_is_battle_end_nullified()` | ハングドマンズシール無効化チェック |

## 注意事項

1. **死亡判定**: MHP=0になる効果は死亡を引き起こす
2. **発動順序**: 攻撃側→防御側の順で処理
3. **生存チェック**: 既に死亡している場合は効果発動しない
4. **永続効果**: ステータス変更は戦闘後も永続
