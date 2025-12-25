# アイテム効果リファクタリング計画

## 概要

アイテムの「戦闘後/死亡時/攻撃成功時効果」を整理し、以下を達成する：
1. trigger名の統一
2. ナチュラルワールド（ID: 2064）の無効化対象を正しく設定
3. スクイドマントル（ID: 1017）の無効化対象を正しく設定
4. `battle_system.gd`から専用クラスへの処理移動
5. JSONのtrigger設定だけで無効化対象を制御できる設計

---

## 現状の問題点

### アイテム効果の処理がバラバラ
```
クリーチャー効果:
  SkillBattleEndEffects → triggerでフィルタして処理 ✅

アイテム効果:
  battle_system.gd → effect_typeで直接判定（triggerを見ていない）❌
  battle_item_applier.gd → 戦闘前のみ
```

### ナチュラルワールド無効化がアイテムに効いていない
- クリーチャーの`on_battle_end`は無効化される ✅
- アイテムの`on_battle_end`系は無効化されていない ❌

---

## 実装方針

### 既存クラスの拡張で対応

新クラス作成ではなく、既存の`SkillBattleEndEffects`を拡張する。

**変更内容：**
```gdscript
// 変更前：クリーチャーのeffectsのみ
var effects = ability_parsed.get("effects", [])

// 変更後：アイテムのeffectsも追加
var effects = ability_parsed.get("effects", [])
var items = participant.creature_data.get("items", [])
for item in items:
	effects.append_array(item.get("effect_parsed", {}).get("effects", []))
```

**メリット：**
- クリーチャーと同じ仕組みでアイテムも動作
- JSONのtrigger名だけで無効化判定が自動適用
- コード変更が最小限

### 対応が必要なクラス

| クラス | trigger | 修正内容 |
|--------|---------|---------|
| SkillBattleEndEffects | on_battle_end | アイテムeffects読み込み追加 |
| battle_special_effects.gd | on_death | アイテムeffects読み込み追加 |
| battle_execution.gd | on_attack_success | アイテムeffects読み込み追加（既存処理の確認） |

---

## 現状のtrigger一覧

### JSONで使用されているtrigger/triggers

| trigger名 | 使用箇所 | 無効化対象 |
|-----------|---------|-----------|
| `on_death` | 死亡時 | ナチュラルワールド |
| `on_battle_end` | 戦闘終了時（クリーチャーのみ） | ナチュラルワールド |
| `on_battle_win` | 勝利時 | → `on_battle_end`に統一？ |
| `after_battle` | 戦闘後 | → `on_battle_end`に統一？ |
| `on_attack_success` | 攻撃成功時 | スクイドマントル |
| `on_battle_start` | 戦闘開始時 | なし |
| `on_damaged` | 被ダメージ時 | ？ |
| `before_battle` | 戦闘前 | なし |
| `before_attack` | 攻撃前 | なし |
| `after_item_use` | アイテム使用後 | なし |
| `battle_preparation` | 戦闘準備時 | なし |

---

## ナチュラルワールド（ID: 2064）の無効化対象

**現在のJSON設定：**
```json
"disabled_triggers": [
  "mystic_arts",    // 秘術
  "on_death",       // 死亡時
  "on_battle_end"   // 戦闘終了時
]
```

**原作準拠の無効化対象：**
- 秘術（mystic_arts）
- 自破壊時/死亡時（on_death）
- 戦闘終了時（on_battle_end）

---

## スクイドマントル（ID: 1017）の無効化対象

**現在のJSON設定：**
```json
"nullify_triggers": [
  "on_attack_success"
]
```

**原作準拠の無効化対象：**
- 攻撃成功時能力（on_attack_success）
- 即死も含む？（要確認）

---

## アイテム効果の分類と修正案

### ❓ 要確認：trigger修正が必要なアイテム

| ID | アイテム名 | 効果 | 現trigger | 修正案 | ナチュラルワールド |
|----|-----------|------|-----------|--------|------------------|
| 1011 | ゴールドグース | 遺産[MHP×G7] | on_death | 維持 | 対象 |
| 1012 | ゴールドハンマー | 攻撃で敵非破壊時、G200獲得 | after_battle | on_battle_end? | 対象？ |
| 1016 | シルバープロウ | 土地レベルアップ | on_battle_win | on_battle_end | 対象 |
| 1029 | ゼラチンアーマー | 受けたダメージ×G5獲得 | after_battle | on_battle_end? | 対象？ |
| 1038 | トゥームストーン | 自破壊時、手札6枚まで引く | on_death | 維持 | 対象 |
| 1044 | ナパームアロー | 雪辱[敵のMHP-40] | on_death | 維持 | 対象 |
| 1046 | ネクロスカラベ | 死者復活[スケルトン] | on_death | 維持 | 対象 |
| 1048 | バーニングハート | 道連れ | on_death | 維持 | 対象 |

### ❓ 要確認：攻撃成功時系アイテム

| ID | アイテム名 | 効果 | 現trigger | スクイドマントル |
|----|-----------|------|-----------|-----------------|
| 1036 | ツインスパイク | 強制変化[使用クリーチャー] | on_attack_success | 対象 |
| 1050 | バインドウィップ | 敵に呪い「戦闘行動不可」 | on_attack_success | 対象 |
| 1067 | ムーンシミター | 敵に呪い「通行料無効」 | on_attack_success | 対象 |

### ❓ 要確認：被ダメージ系アイテム

| ID | アイテム名 | 効果 | 現triggers | 無効化対象 |
|----|-----------|------|------------|-----------|
| 1002 | アングリーマスク | 追加ダメージ[受けたダメージ] | on_damaged | ？ |

### ✅ 現状維持で問題なさそうなアイテム

| ID | アイテム名 | 効果 | trigger | 備考 |
|----|-----------|------|---------|------|
| 1004 | ウォーロックディスク | 戦闘中能力無効 | battle_preparation | |
| 1005 | エターナルメイル | 復帰[ブック] | after_item_use | |
| 1017 | スクイドマントル | 敵の攻撃成功時能力無効 | (nullify_triggers) | |
| 1041 | ドラゴンオーブ | 変身[いずれかのドラゴン] | on_battle_start | |
| 1047 | ネクロプラズマ | 巻物攻撃；変身[スケルトン] | on_battle_start | |

---

## 確認結果

### Q1: シルバープロウ (1016) ✅
- 現在: `on_battle_win`
- **変更**: `on_battle_end` + `condition: "win"`
- ナチュラルワールド対象: **はい**

### Q2: ゴールドハンマー/ゼラチンアーマー ✅
- ゼラチンアーマー: `after_battle`のまま、ナチュラルワールド対象外
- ゴールドハンマー: **Q4で対応**（`on_attack_success`に変更）

### Q3: 死亡時系 ✅
- `on_death`のまま
- ナチュラルワールド対象: **はい**
- 対象: ゴールドグース、トゥームストーン、ナパームアロー、ネクロスカラベ、バーニングハート

### Q4: 攻撃成功時系 ✅
- trigger: `on_attack_success`
- ナチュラルワールド対象: **いいえ**
- スクイドマントル対象: **はい**
- 対象アイテム:
  - ツインスパイク（強制変化）
  - バインドウィップ（呪い付与）
  - ムーンシミター（呪い付与）
  - ゴールドハンマー（敵非破壊時魔力獲得）→ **trigger変更 + condition: "enemy_alive"**
  - サキュバスリング（APドレイン）→ **trigger追加**
  - アージェントキー（先制付与）→ **trigger追加**

### Q5: アングリーマスク（被ダメージ/反射系）✅
- **変更**: `triggers: ["on_battle_end", "reflect"]`
- ナチュラルワールド対象: **はい**（on_battle_end）
- ムラサメ対象: **はい**（reflect）

---

## 無効化カテゴリ整理

### ナチュラルワールド（disabled_triggers）
```json
["mystic_arts", "on_death", "on_battle_end"]
```

### スクイドマントル
```json
"nullify_triggers": ["on_attack_success"]
```
※即死は別途`has_squid_mantle`フラグでチェック（triggerベース化しない）

### ムラサメ（nullify_triggers）
```json
["reflect", "nullify"]
```

---

## 無効化対象一覧

### 反射能力（trigger: "reflect"）→ ムラサメで無効化

**アイテム：**
| 名前 | 効果 |
|------|------|
| アングリーマスク | 反射[全・自傷] |
| スパイクシールド | 反射[1/2] |
| ミラーホブロン | 反射[全]（条件付き） |
| メイガスミラー | 反射[巻物] |

**クリーチャー：**
| 名前 | 効果 |
|------|------|
| デコイ | 反射 |
| ナイトエラント | 反射（条件付き） |

### 攻撃無効化能力（trigger: "nullify"）→ ムラサメで無効化

**アイテム：**
| 名前 | 効果 |
|------|------|
| ストームシールド | 水風使用時、無効化[通常攻撃] |
| スフィアシールド | AP=0；無効化[通常攻撃] |
| ターコイズアムル | 即死[水地]；無効化[水地] |
| トパーズアムル | 即死[火風]；無効化[火風] |
| バックラー | 無効化[AP30以下] |
| マグマシールド | 火地使用時、無効化[通常攻撃] |
| マジックシールド | 無効化[巻物] |
| ラグドール | 無効化[巻物]；無効化[自分よりAP大] |
| ワンダーチャーム | 無効化[通常攻撃の80%] |

**クリーチャー：** 多数あり（個別にtrigger追加が必要）

### 攻撃成功時能力（trigger: "on_attack_success"）→ スクイドマントルで無効化

**アイテム：**
| 名前 | 効果 | 要修正 |
|------|------|--------|
| ツインスパイク | 強制変化 | - |
| バインドウィップ | 呪い付与 | - |
| ムーンシミター | 呪い付与 | - |
| ゴールドハンマー | 魔力獲得 | trigger変更 |
| サキュバスリング | APドレイン | trigger追加 |
| アージェントキー | 先制付与 | trigger追加 |

**クリーチャー：**
| 名前 | 効果 |
|------|------|
| コカトリス | ？ |
| ショッカー | ダウン付与 |
| スキュラ | 呪い付与 |
| スカラベンドラ | ？ |
| ナイキー | ？ |
| シャドウガイスト | ？ |
| ブラックナイト | ？ |

※即死は別途`has_squid_mantle`フラグでチェック（trigger対象外）

---

## JSON修正一覧

### trigger変更が必要なアイテム

| ID | アイテム名 | 変更内容 |
|----|-----------|---------|
| 1016 | シルバープロウ | `on_battle_win` → `on_battle_end` + `condition: "win"` |
| 1012 | ゴールドハンマー | `after_battle` → `on_attack_success` + `condition: "enemy_alive"` |
| 1002 | アングリーマスク | `triggers: ["on_damaged"]` → `triggers: ["on_battle_end", "reflect"]` |

### trigger追加が必要なアイテム

| ID | アイテム名 | 追加内容 |
|----|-----------|---------|
| ? | サキュバスリング | `trigger: "on_attack_success"` |
| ? | アージェントキー | `trigger: "on_attack_success"` |
| ? | スパイクシールド | `triggers: ["reflect"]` |
| ? | ミラーホブロン | `triggers: ["reflect"]` |
| ? | メイガスミラー | `triggers: ["reflect"]` |
| ? | ストームシールド | `triggers: ["nullify"]` |
| ? | スフィアシールド | `triggers: ["nullify"]` |
| ? | ターコイズアムル | `triggers: ["nullify"]` |
| ? | トパーズアムル | `triggers: ["nullify"]` |
| ? | バックラー | `triggers: ["nullify"]` |
| ? | マグマシールド | `triggers: ["nullify"]` |
| ? | マジックシールド | `triggers: ["nullify"]` |
| ? | ラグドール | `triggers: ["nullify"]` |
| ? | ワンダーチャーム | `triggers: ["nullify"]` |

### nullify_triggers追加が必要なアイテム

| ID | アイテム名 | 変更内容 |
|----|-----------|---------|
| ? | ムラサメ | `nullify_triggers: ["reflect"]` → `["reflect", "nullify"]` |

---

## 実装タスク

### Phase 1: 確認・設計 ✅
- [x] Q1〜Q5の確認完了
- [x] trigger名の最終決定

### Phase 2: JSON修正 ✅

**trigger変更：**
- [x] シルバープロウ: `on_battle_win` → `on_battle_end` + condition
- [x] ゴールドハンマー: `after_battle` → `on_attack_success` + condition
- [x] アングリーマスク: triggers変更

**trigger追加（攻撃成功時）：**
- [x] サキュバスリング: `trigger: "on_attack_success"`
- ~~アージェントキー~~: 先制付与は戦闘前適用のためスキップ

**trigger追加（反射）：**
- [x] スパイクシールド: `triggers: ["on_battle_end", "reflect"]`
- [x] ミラーホブロン: `triggers: ["on_battle_end", "reflect"]`
- [x] メイガスミラー: `triggers: ["on_battle_end", "reflect"]`

**trigger追加（無効化）：**
- [x] ストームシールド: `triggers: ["nullify"]`
- [x] スフィアシールド: `triggers: ["nullify"]`
- [x] ターコイズアムル: `triggers: ["nullify"]`
- [x] トパーズアムル: `triggers: ["nullify"]`
- [x] バックラー: `triggers: ["nullify"]`
- [x] マグマシールド: `triggers: ["nullify"]`
- [x] マジックシールド: `triggers: ["nullify"]`
- [x] ラグドール: `triggers: ["nullify"]`
- [x] ワンダーチャーム: `triggers: ["nullify"]`

**nullify_triggers追加：**
- [x] ムラサメ: `["reflect", "nullify"]`

### Phase 3: 既存クラス修正 ✅

**アイテムeffects読み込み追加：**
- [x] `SkillBattleEndEffects._process_effects()` - アイテムeffectsを統合
- [ ] on_death系処理（今後の課題）
- [x] on_attack_success系処理 - `_apply_on_attack_success_effects()`追加

**無効化チェック対応：**
- [x] triggers配列対応（`_has_trigger()`ヘルパー関数追加）
- [x] ムラサメのnullify_triggers拡張対応（`_is_effect_nullified_by_enemy()`追加）
- [x] 反射/無効化のtriggersチェック対応

**effect_type処理関数：**
- [x] `level_up_on_win` - シルバープロウ
- [x] `magic_on_enemy_survive` - ゴールドハンマー
- [x] `ap_drain` - サキュバスリング

### Phase 4: 旧コード削除 ✅
- [x] `battle_system.gd`から`_apply_magic_on_enemy_survive`を削除
- [x] `battle_system.gd`から`_check_defender_magic_on_enemy_survive`を削除
- [x] `battle_system.gd`から`_apply_level_up_effect`を削除
- [x] 呼び出し箇所をコメント化

### Phase 5: テスト
- [ ] ナチュラルワールド発動時にアイテム効果が無効化されることを確認
- [ ] スクイドマントル装備時に攻撃成功時能力が無効化されることを確認
- [ ] 各アイテムの通常動作確認

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2025/12/25 | 初版作成、確認事項を整理 |
| 2025/12/25 | 新クラス`SkillItemTrigger`の設計を追加、実装タスクを詳細化 |
| 2025/12/25 | 既存クラス拡張方式に変更、Q1〜Q5確認完了 |
| 2025/12/26 | 無効化対象一覧を追加（反射・無効化・攻撃成功時）、JSON修正一覧を詳細化 |
| 2025/12/26 | Phase 2〜4完了: JSON修正17件、コード修正（SkillBattleEndEffects、battle_execution.gd、battle_system.gd）|
