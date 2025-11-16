# 効果システム設計書

**プロジェクト**: カルドセプト風カードバトルゲーム  
**バージョン**: 1.0  
**作成日**: 2025年10月21日  
**ステータス**: 設計中

---

## 📋 目次

1. [概要](#概要)
2. [効果の種類と持続期間](#効果の種類と持続期間)
3. [データ構造設計](#データ構造設計)
4. [HP/AP管理構造](#hpap管理構造)
5. [効果の適用順序](#効果の適用順序)
6. [今後の検討事項](#今後の検討事項)

---

## 概要

### 目的
アイテム、スペル、クリーチャースキルによる様々な効果を統一的に管理するシステムを設計する。

### 設計方針
- **効果の分離管理**: バトル中の一時効果と永続効果を分けて管理
- **データの明確化**: 効果の種類、持続期間、削除条件を明示
- **拡張性の確保**: 将来的な新効果の追加が容易

---

## 効果の種類と持続期間

### 1. 1回の戦闘のみの効果
**例**: アイテム「ロングソード」使用でAP+30

- **持続期間**: バトル開始〜バトル終了
- **管理場所**: `BattleParticipant` の一時フィールド
- **削除タイミング**: バトル終了時に自動削除

```gdscript
participant.item_bonus_ap = 30  # バトル後に消える
```

---

### 2. スペルによる一時的な効果（移動で消える）
**例**: スペル「ブレッシング」でHP+10

- **持続期間**: 効果付与〜移動まで
- **管理場所**: `creature_data["temporary_effects"]`
- **削除タイミング**: 移動時、交換時

```gdscript
creature_data["temporary_effects"] = [
	{
		"id": "blessing_002",
		"type": "stat_bonus",
		"stat": "hp",
		"value": 10,
		"source": "spell_blessing",
		"removable": true,
		"lost_on_move": true
	}
]
```

---

### 3. 条件付きで上昇する効果

#### 3-1. 毎バトル時に条件チェック
**例**: 「火土地を3つ以上保有している場合、AP+30」

- **管理場所**: `ability_parsed` の conditions
- **適用タイミング**: バトル開始時に毎回チェック
- **実装**: 既存のConditionCheckerシステムを使用

```gdscript
# バトル時に動的計算
if player_lands["fire"] >= 3:
	participant.current_ap += 30
```

#### 3-2. 条件を満たした時点で効果付与
**例**: （今後定義）

- **管理場所**: `creature_data["permanent_effects"]` または `temporary_effects`
- **適用タイミング**: 条件を満たした時点で配列に追加
- **削除タイミング**: 条件により異なる

---

### 4. 土地の保有数で変化する効果
**例**: 「火土地1つごとにAP+10」

- **計算方法**: 毎バトル時に動的計算（Option A採用）
- **実装**: 感応スキルと同様の処理
- **管理場所**: `ability_parsed` の effects

```gdscript
# バトル時
var fire_lands = player_lands.get("fire", 0)
participant.current_ap += fire_lands * 10
```

---

### 5. マップ周回で上昇する効果
**例**: キメラ「マップを1周したらAP+10」

- **カウント管理**: `creature_data` に持たせる
- **適用方法**: 1周時点でAP+10を加算
- **永続性**: 移動しても維持、交換で消える

```gdscript
creature_data["map_lap_count"] = 2
creature_data["lap_bonus_ap"] = 20  # 10 × 2周

# または permanent_effects に追加
creature_data["permanent_effects"].append({
	"id": "lap_bonus_003",
	"type": "stat_bonus",
	"stat": "ap",
	"value": 10,
	"source": "map_lap",
	"removable": false,
	"lost_on_move": false
})
```

---

### 6. 隣接条件で上昇する効果
**例**: 「隣接に自領地がある場合、AP+20、HP+20」

- **実装**: 既存の強打スキルシステムと同様
- **適用タイミング**: バトル開始時に条件チェック
- **管理場所**: `ability_parsed` の conditions

```gdscript
# バトル時に動的計算
if has_adjacent_ally_land:
	participant.current_ap += 20
	participant.temporary_bonus_hp += 20
```

---

### 7. スキル「合成」による永続的な効果
**例**: 合成[地]を持つカードを生贄にして召喚、条件を満たせば能力上昇

- **適用タイミング**: 召喚時
- **永続性**: 交換で消える
- **実装方法**: 
  - **Option A**: 基礎ステータス（`hp`, `ap`）を直接変更
  - **Option B**: `permanent_effects` に追加（removable: false）

```gdscript
# Option A
creature_data["hp"] += 10
creature_data["ap"] += 20

# Option B
creature_data["permanent_effects"].append({
	"id": "synthesis_earth_004",
	"type": "stat_bonus",
	"stat": "hp",
	"value": 10,
	"source": "synthesis",
	"removable": false,  # 打ち消し効果で消えない
	"lost_on_move": false
})
```

**検討中**: 打ち消し効果に反応しない新しいHPの枠を作るか？

---

### 8. スペルによる永続的な効果

#### 8-1. 移動で失われる効果
**例**: スペル「ブレッシング」HP+10

- **管理場所**: `creature_data["temporary_effects"]`
- **削除タイミング**: 移動時、交換時

#### 8-2. 移動で失われない効果
**例**: スペル「マスグロース」全クリーチャーのMHP+5

- **管理場所**: `creature_data["permanent_effects"]`
- **削除タイミング**: 打ち消し効果、交換時
- **適用対象**: 全自クリーチャー

```gdscript
# 全自クリーチャーにループ適用
for tile in board_system.get_player_tiles(player_id):
	if tile.creature_data:
		tile.creature_data["permanent_effects"].append({
			"id": "mass_growth_" + str(effect_counter),
			"type": "stat_bonus",
			"stat": "hp",
			"value": 5,
			"source": "spell_mass_growth",
			"removable": true,
			"lost_on_move": false
		})
```

---

### 9. 条件付きで永続的なスキル効果（移動で失われない）
**例**: キメラ（マップ周回でAP上昇）、合成効果

- **管理場所**: `creature_data["permanent_effects"]`
- **削除タイミング**: 交換時のみ
- **打ち消し**: removableフラグにより制御

---

### 10. スペルによる上書きされるまで永続的な効果
**例**: 土地の属性変更（土地にかかる効果）

- **対象**: 土地（クリーチャーではない）
- **管理場所**: `tile_data["overwritable_effects"]`
- **削除タイミング**: 同種の効果で上書き

```gdscript
# 土地の属性変更
tile_data["element"] = "fire"  # 上書き
tile_data["element_changed_by"] = "spell_element_change"
```

**クリーチャーに対する例**: （今後定義）

---

### 11. 強打の判定前に入れる
**適用順序**: おそらく全ての上昇系効果は強打の前に計算される

```
1. 基礎値設定（base_hp, base_ap）
2. permanent_effects 適用
3. temporary_effects 適用
4. 土地保有数による効果
5. 隣接条件による効果
6. 感応スキル
7. その他の条件効果
8. 強打スキル（最後）
```

---

### 13. HPが増えるものの分類

#### 基礎HPに影響するもの
**例**: マスグロース、ドミナントグロース

- **効果**: `base_hp` または `base_up_hp` に加算
- **永続性**: 移動しても維持、交換で消える
- **削除**: 打ち消し効果で削除可能（removable: true）

#### 基礎HPに影響しないもの
**例**: スペルや一時効果

- **効果**: `temporary_bonus_hp` に加算
- **永続性**: 移動で消える
- **削除**: 移動時、打ち消し効果で削除

---

## データ構造設計

### creature_dataの構造

```gdscript
{
	"id": 1,
	"name": "アモン",
	"hp": 30,           # 元の基礎HP
	"ap": 20,           # 元の基礎AP
	"element": "fire",
	"ability_parsed": {...},  # スキル定義（既存）
	
	# 永続的な効果（移動で消えない、交換で消える）
	"permanent_effects": [
		{
			"id": "mass_growth_001",
			"type": "stat_bonus",
			"stat": "hp",
			"value": 5,
			"source": "spell",
			"source_name": "マスグロース",
			"removable": true,        # 打ち消し効果で消せるか
			"lost_on_move": false     # 移動で消えるか
		},
		{
			"id": "synthesis_fire_002",
			"type": "stat_bonus",
			"stat": "ap",
			"value": 20,
			"source": "synthesis",
			"source_name": "合成[火]",
			"removable": false,       # 打ち消しできない
			"lost_on_move": false
		}
	],
	
	# 一時的な効果（移動で消える）
	"temporary_effects": [
		{
			"id": "blessing_003",
			"type": "stat_bonus",
			"stat": "hp",
			"value": 10,
			"source": "spell",
			"source_name": "ブレッシング",
			"removable": true,
			"lost_on_move": true      # 移動で消える
		}
	],
	
	# マップ周回カウント（キメラ等）
	"map_lap_count": 0
}
```

---

### effectオブジェクトの構造

```gdscript
{
	"id": "unique_id_string",         # 一意のID
	"type": "stat_bonus",              # 効果タイプ
	"stat": "hp",                      # 対象ステータス（hp/ap）
	"value": 10,                       # 効果値
	"source": "spell",                 # 発生源（spell/item/skill/synthesis）
	"source_name": "マスグロース",      # 効果名（UI表示用）
	"removable": true,                 # 打ち消し効果で消せるか
	"lost_on_move": false              # 移動で消えるか
}
```

**効果タイプ（type）**:
- `stat_bonus`: HP/APボーナス
- （将来追加）`attribute_change`: 属性変更
- （将来追加）`skill_grant`: スキル付与

---

## HP/AP管理構造

### BattleParticipantの構造（バトル中）

```gdscript
class BattleParticipant:
	# 基礎値
	var base_hp: int              # 元のHPの現在値（ダメージで削られる）
	var base_up_hp: int = 0       # 永続的な基礎HP上昇（マスグロース、合成等、バトル後も creature_data に保存）
	var base_ap: int              # 元のAP
	var base_up_ap: int = 0       # 永続的な基礎AP上昇（バトル後も creature_data に保存）
	
	# バトル中の一時ボーナス
	var temporary_bonus_hp: int = 0   # 一時的なHPボーナス（移動で消える）
	var temporary_bonus_ap: int = 0   # 一時的なAPボーナス
	var resonance_bonus_hp: int = 0   # 感応ボーナス
	var land_bonus_hp: int = 0        # 土地ボーナス
	var item_bonus_hp: int = 0        # アイテムボーナス（バトルのみ）
	var item_bonus_ap: int = 0        # アイテムボーナス（バトルのみ）
	
	# 計算後の値
	var current_hp: int
	var current_ap: int
```

### HP/APの計算式

```gdscript
# HP計算
current_hp = base_hp + 
			 base_up_hp + 
			 temporary_bonus_hp + 
			 land_bonus_hp + 
			 resonance_bonus_hp + 
			 item_bonus_hp +
			 spell_bonus_hp

# AP計算
current_ap = base_ap + 
			 base_up_ap + 
			 temporary_bonus_ap + 
			 item_bonus_ap + 
			 (感応AP) + 
			 (条件効果AP)
# その後、強打で乗算
```

### ダメージ消費順序

**重要**: `base_up_hp`（永続的な基礎HP上昇）は消費されません。これは永続的なMHPボーナスで、ダメージでは削られません。

```
1. resonance_bonus_hp（感応ボーナス）
2. land_bonus_hp（土地ボーナス）
3. temporary_bonus_hp（一時ボーナス）
4. item_bonus_hp（アイテムボーナス）
5. spell_bonus_hp（スペルボーナス）
6. base_hp（元のHPの現在値、最後に消費）
```

※ `current_hp` は計算値（`base_hp + base_up_hp + ボーナス群`）のため、直接削られません。

#### base_up_hp が消費されない理由

`base_up_hp` はマスグロース、周回ボーナス、合成などで得た永続的なMHP増加であり、戦闘終了後も creature_data に保存されます。ダメージでは削られず、MHP計算にのみ使用されます。一方 `base_hp` はダメージで削られます。

---

## 効果の適用順序

### バトル時の計算順序

```
1. 基礎値を設定
   base_hp = creature_data["hp"]
   base_ap = creature_data["ap"]

2. permanent_effectsから base_up_hp, base_up_ap を計算
   for effect in permanent_effects:
	   if effect["stat"] == "hp":
		   base_up_hp += effect["value"]
	   elif effect["stat"] == "ap":
		   base_up_ap += effect["value"]

3. temporary_effectsから temporary_bonus_hp, temporary_bonus_ap を計算
   for effect in temporary_effects:
	   if effect["stat"] == "hp":
		   temporary_bonus_hp += effect["value"]
	   elif effect["stat"] == "ap":
		   temporary_bonus_ap += effect["value"]

4. 土地ボーナスを加算（HPのみ）
   land_bonus_hp = tile.level * 10

5. アイテム効果を加算
   item_bonus_ap = 30  # 例
   item_bonus_hp = 20

6. 感応効果を加算
   if 条件を満たす:
	   current_ap += 30
	   resonance_bonus_hp += 30

7. その他の条件効果を加算
   if 土地保有数条件:
	   current_ap += 計算値
   if 隣接条件:
	   current_ap += 20

8. 強打を適用（最後）
   current_ap = current_ap * 強打倍率
```

---

## 変身・死者復活効果

### 概要

変身と死者復活は、クリーチャースキル、アイテム、スペルのすべてで使用される特殊な効果です。これらは通常のステータス変更とは異なり、クリーチャーそのものを変更する効果として扱います。

### 効果の種類

#### 1. 変身効果
クリーチャーを別のクリーチャーに変える効果

**発動タイミング**:
- 召喚時/配置時（クリーチャースキル）
- アイテム使用時
- スペル使用時
- 特定条件達成時（スペル破壊時など）

**変身パターン**:
- ランダム変身（例: ハルゲンダース）
- 特定クリーチャーへの変身（例: シルフ→ガルーダ）
- 対象を強制変身（例: コカトリス→ストーンウォール）
- 同じクリーチャーへの変身（例: シェイプシフター）
- いずれかのグループから選択（例: ドラゴンオーブ→いずれかのドラゴン）

#### 2. 死者復活効果
墓地から特定のクリーチャーを復活させる効果

**発動タイミング**:
- 召喚時/配置時（クリーチャースキル）
- アイテム使用時
- スペル使用時

**復活パターン**:
- 特定クリーチャーを復活（例: ヘルグラマイト→サーペントフライ）
- 条件付き復活（例: 墓地に存在する場合のみ）

### 既存システムとの関係

**変身効果**:
- HP/APボーナスシステムとは独立
- クリーチャーデータそのものを置き換える
- 既存の効果（permanent_effects等）は変身時にリセット

**死者復活効果**:
- 墓地システムと連携
- 復活したクリーチャーは元の状態で配置
- 復活時の効果適用は別途設計

### 詳細設計

詳細な仕様は以下のドキュメントを参照:
- [変身効果の詳細設計](spells/transform_effect.md)
- [死者復活効果の詳細設計](spells/revive_effect.md)

---

## 今後の検討事項

### 未決定事項

1. **permanent_effectsの適用方法**
   - base_hpに事前計算して含めるか
   - バトル時に毎回計算するか
   - → 次回チャットで決定

2. **合成効果の実装方法**
   - 基礎ステータスを直接変更するか
   - permanent_effectsに追加するか
   - 打ち消し効果に反応しない新しいHPの枠を作るか
   - → 次回チャットで決定

3. **効果管理の責任所在**
   - EffectManagerクラスを新規作成するか
   - 既存のクラスに機能を追加するか
   - → 実装時に決定

4. **UI表示**
   - クリーチャー詳細画面での効果表示
   - バトルテストツールでの効果表示
   - → UI実装時に決定

5. **セーブ/ロードシステム**
   - permanent_effects, temporary_effectsの永続化
   - → セーブシステム実装時に検討

6. **効果の削除処理**
   - 移動時の削除タイミング
   - 打ち消し効果の実装
   - → 実装時に詳細設計

---

## 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025/10/21 | 1.0 | 初版作成 - 効果システムの基本設計を確定 |

---

**最終更新**: 2025年10月21日（v1.0）
