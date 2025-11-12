# 🎮 バトルシステム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**最終更新**: 2025年11月13日（v1.1 - 準備フェーズ詳細化、HP階層構造更新）

---

## 📋 目次

1. [バトルフロー全体](#バトルフロー全体)
2. [BattleParticipantとHP管理](#battleparticipantとhp管理)
3. [スキル適用順序](#スキル適用順序)
4. [土地ボーナスシステム](#土地ボーナスシステム)
5. [先制・後手判定](#先制後手判定)
6. [バトル結果判定](#バトル結果判定)
7. [関連ファイル](#関連ファイル)

---

## バトルフロー全体

### 準備フェーズ (`prepare_participants()`)

```
1. BattleParticipant作成
   ├─ 攻撃側・防御側の基本ステータス設定
   └─ 先制・後手フラグをスキルから読み込み
   
2. 効果配列適用 (apply_effect_arrays)
   ├─ permanent_effects を HP/AP に反映
   └─ temporary_effects を HP/AP に反映（呪いなど）
   
3. 呪い変換 (_apply_creature_curses)
   ├─ 呪い（stat_boost/stat_reduce）を temporary_effects に追加
   └─ temporary_bonus_hp/ap を加算
   
4. アイテム効果適用 (apply_item_effects)
   ├─ 複数の効果タイプに対応（ST加算、スキル付与等）
   └─ 援護クリーチャー処理を含む
   
5. 特殊クリーチャー処理
   ├─ リビングアーマー (ID: 438) → ST+50
   ├─ ブルガサリ (ID: 339) → アイテム使用時 ST+20
   └─ オーガロード (ID: 407) → 隣接自領地ボーナス
   
6. 変身スキル処理 (on_battle_start)
   └─ 戦闘開始時変身を実行
```

### 実行フェーズ (`_execute_battle_core()`)

```
1. pre_battle_skills 適用 (battle_skill_processor)
   ├─ 応援スキル（盤面の支援クリーチャー）
   ├─ 感応スキル（属性ボーナス）
   └─ その他のバトル前スキル
   
2. 攻撃順決定
   ├─ アイテム先制 > 先制スキル > 防御側後手 > デフォルト
   └─ 順序は [先攻者, 後攻者] で返却
   
3. 攻撃シーケンス実行
   ├─ 先攻者が攻撃 → ダメージ処理 → 即死判定
   └─ 後攻者が攻撃（生存時）→ ダメージ処理 → 即死判定
   
4. 結果判定 (resolve_battle_result)
   └─ HP状態から ATTACKER_WIN / DEFENDER_WIN / BOTH_DEFEATED / ATTACKER_SURVIVED を決定
   
5. バトル後処理 (_apply_post_battle_effects)
   ├─ 再生スキル（生存者のみ）
   ├─ 永続バフ適用
   └─ 土地処理（獲得・消滅・無所有化）
```

---

## BattleParticipantとHP管理

### BattleParticipantクラス

**役割**: バトル参加者のステータスとHP管理を担当

**実装場所**: `scripts/battle_participant.gd`

### HPフィールド一覧

| フィールド | 説明 |
|-----------|------|
| `base_hp` | クリーチャーの基本HP |
| `base_up_hp` | 永続的な基礎HP上昇（合成・マスグロース等） |
| `temporary_bonus_hp` | 一時効果による加算HP（効果配列から計算） |
| `resonance_bonus_hp` | 感応スキルのボーナスHP |
| `land_bonus_hp` | 土地ボーナスHP（属性一致時） |
| `item_bonus_hp` | アイテム効果のボーナスHP |
| `spell_bonus_hp` | スペル効果のボーナスHP |
| `current_hp` | 合計HP（上記すべての合計） |

### ダメージ消費順序

1. **感応ボーナス** (最優先で消費)
2. **土地ボーナス** (戦闘ごとに復活)
3. **一時効果** (temporary_bonus_hp)
4. **アイテムボーナス**
5. **スペルボーナス**
6. **永続基礎HP** (base_up_hp)
7. **基本HP** (base_hp - 最後に消費) (`base_hp`) - 最後に消費

### 設計思想

- **一時的なボーナスを先に消費**し、クリーチャーの本来のHPを守る
- **感応ボーナス**: 最も一時的（バトル限定）なため、最優先消費
- **土地ボーナス**: 戦闘ごとに復活するため、次に消費
- **基本HP**: 減ると配置クリーチャーの永続的なダメージとなる

### ダメージ処理

`take_damage()` は消費順序に従い、残ったダメージを次のHPフィールドに適用します。

**戻り値**: `damage_breakdown` 辞書
- 各フィールドがいくら消費されたかを記録
- デバッグ出力用に使用

**副作用**:
- `was_attacked_by_enemy` フラグを設定（バイロマンサー用）
- `_trigger_magic_from_damage()` を呼ぶ（ゼラチンアーマー用）

### 主要メソッド

| メソッド | 説明 |
|---------|------|
| `update_current_hp()` | 全フィールドから current_hp を再計算 |
| `get_max_hp()` | 真のMHP（base_hp + base_up_hp） |
| `is_alive()` | current_hp > 0 かチェック |
| `take_damage(damage)` | ダメージ処理（消費順序に従う） |
| `take_mhp_damage(damage)` | MHPに直接ダメージ（雪辱効果用） |
| `is_damaged()` | current_hp < get_max_hp() かチェック |
| `apply_item_first_strike()` | アイテムで先制付与（後手を無効化） |



---

## スキル適用順序

### 相乗効果の設計思想

この順序により、複数スキルを持つクリーチャーは相乗効果を得られる。

**例: 感応+強打の組み合わせ**
```
モルモ（感応[火]+30、強打×1.5を仮定）

基本AP: 20
  ↓ 感応発動（火土地1個所有）
AP: 50 (+30)
  ↓ 強打発動（隣接自領地あり）
AP: 75 (×1.5)

→ 最終的にAP: 75で攻撃！
```

この設計により、感応で上昇したAPが強打の基準値となり、大きな戦力増強が可能。

詳細な個別スキル仕様は **[skills_design.md](skills_design.md)** を参照。

---

## 土地ボーナスシステム

### 計算式

```
土地ボーナスHP = land_level × 10
```

### 適用条件

- **クリーチャーの属性** = **タイルの属性** のときのみ適用
- 例: 火属性クリーチャーが火属性タイルにいる

### 保存場所

- `land_bonus_hp` フィールドに独立して保存
- 基本HPとは分離管理

### 特殊ルール

- **貫通スキル**: 相手の土地ボーナスを無効化可能
- **戦闘ごとに復活**: 次のバトルでは再度適用される

詳細は **[land_system.md](land_system.md)** を参照。

---

## 先制・後手判定

### 判定順序

1. **先制スキル保持者**が先攻
2. **後手スキル保持者**が後攻
3. 両方なし → **攻撃側が先攻**（デフォルト）
4. 両方あり → 打ち消し合い → **攻撃側が先攻**

### 実装

```gdscript
func _determine_attack_order(attacker: BattleParticipant, defender: BattleParticipant) -> String:
	var attacker_has_first = attacker.has_first_strike
	var attacker_has_last = attacker.has_last_strike
	var defender_has_first = defender.has_first_strike
	var defender_has_last = defender.has_last_strike
	
	# 攻撃側が先制 && 防御側が後手でない
	if attacker_has_first and not defender_has_first:
		return "attacker_first"
	
	# 防御側が先制 && 攻撃側が後手でない
	if defender_has_first and not attacker_has_last:
		return "defender_first"
	
	# デフォルト: 攻撃側先攻
	return "attacker_first"
```

---

## バトル結果判定

### 結果の種類

バトル結果は以下の4種類に分類される：

| 結果 | enum値 | 説明 |
|------|--------|------|
| **侵略成功** | `ATTACKER_WIN` | 防御側のみ死亡 → 攻撃側が土地を獲得 |
| **防御成功** | `DEFENDER_WIN` | 攻撃側のみ死亡 → 攻撃側カードは破壊 |
| **侵略失敗** | `ATTACKER_SURVIVED` | 両方生存 → 攻撃側カードは手札に戻る |
| **相打ち** | `BOTH_DEFEATED` | 両方死亡 → 土地は無所有になる |

### 判定ロジック

```gdscript
func resolve_battle_result(attacker: BattleParticipant, defender: BattleParticipant) -> int:
	# 1. 両方死亡 → 相打ち（土地は無所有）
	if not attacker.is_alive() and not defender.is_alive():
		return BOTH_DEFEATED
	
	# 2. 防御側のみ死亡 → 攻撃側勝利
	elif not defender.is_alive():
		return ATTACKER_WIN
	
	# 3. 攻撃側のみ死亡 → 防御側勝利
	elif not attacker.is_alive():
		return DEFENDER_WIN
	
	# 4. 両方生存 → 攻撃側生還
	else:
		return ATTACKER_SURVIVED
```

### 死亡時効果（道連れ・雪辱）

**重要**: バトル結果判定の前に、死亡時効果が発動する。

#### 発動タイミング

```
攻撃実行
  ↓
ダメージ処理
  ↓
即死判定
  ↓
【撃破判定】← ここで死亡時効果をチェック
  ├─ 道連れ（instant_death）
  └─ 雪辱（revenge_mhp_damage）
  ↓
死者復活チェック
  ↓
バトル結果判定 ← ここで最終的な生存状況を判定
```

#### 死亡時効果の種類

| 効果 | effect_type | 説明 |
|------|-------------|------|
| **道連れ** | `instant_death` | 使用者が死亡時、相手を即死させる（確率判定あり） |
| **雪辱** | `revenge_mhp_damage` | 使用者が死亡時、相手のMHPに直接ダメージ |

詳細は **[skills/on_death_effects.md](skills/on_death_effects.md)** を参照。

#### 相打ちの発生パターン

1. **道連れによる相打ち**
   - A攻撃 → B死亡 → 道連れ発動 → A死亡 → 相打ち

2. **雪辱による相打ち**
   - A攻撃 → B死亡 → 雪辱発動 → AのMHP-40 → A即死 → 相打ち

3. **反射による相打ち**
   - A攻撃 → B死亡 → 反射ダメージ → A死亡 → 相打ち

### バトル後処理

各結果に応じた処理：

#### ATTACKER_WIN（侵略成功）
1. 破壊カウンター更新
2. 攻撃側の永続バフ適用
3. 土地所有権を攻撃側に変更
4. 攻撃側クリーチャーを配置（残りHP反映）
5. 土地レベルアップ効果（シルバープロウ）

#### DEFENDER_WIN（防御成功）
1. 破壊カウンター更新
2. 防御側の永続バフ適用
3. 防御側クリーチャーのHP更新
4. 土地レベルアップ効果（シルバープロウ）
5. 攻撃側カードは破壊（手札に戻らない）

#### ATTACKER_SURVIVED（侵略失敗）
1. 攻撃側カードを手札に戻す（HP全回復）
2. 防御側クリーチャーのHP更新

#### BOTH_DEFEATED（相打ち）
1. 破壊カウンター更新×2
2. 両方の永続バフ適用
3. 土地を無所有にする（owner = -1）
4. クリーチャーを削除
5. 両方のカードは破壊（手札に戻らない）
3. **クリーチャーHP更新**

---

## 関連ファイル

### 実装ファイル

| ファイル | 役割 |
|---------|------|
| `scripts/battle_system.gd` | バトルシステムメインロジック |
| `scripts/battle_participant.gd` | BattleParticipantクラス |
| `scripts/skills/condition_checker.gd` | スキル条件判定 |
| `scripts/skills/effect_combat.gd` | スキル効果適用 |
| `scripts/battle/battle_preparation.gd` | バトル前準備（アイテム適用等） |

### 設計ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| **[skills_design.md](skills_design.md)** | スキルシステム全体設計 |
| **[land_system.md](land_system.md)** | 土地システム・土地ボーナス |
| **[item_system.md](item_system.md)** | アイテムシステム・アイテムフェーズ |

---

**最終更新**: 2025年11月13日（v1.1 - 準備フェーズ詳細化、HP階層構造更新）
