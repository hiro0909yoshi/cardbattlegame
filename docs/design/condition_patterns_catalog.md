# 🔍 条件分岐パターン完全カタログ

**作成日**: 2025-10-30  
**最終更新**: 2025-10-31  
**対象範囲**: 全スキル・条件システム  
**調査ファイル**: battle_skill_processor.gd, condition_checker.gd, battle_preparation.gd 他

---

## 📑 条件分岐パターン一覧（全50種類）

### 1. 属性条件
1-1. 自分の属性確認
1-2. 敵の属性確認
1-3. 戦闘地の属性確認
1-4. 同属性・異属性判定
1-5. 複数属性の土地所持チェック（全属性）
1-6. 感応（属性土地所持チェック）
1-7. 属性別土地数カウント（単一）
1-8. 属性別土地数カウント（複数属性合計）

### 2. 土地・配置条件
2-1. 自領地数カウント
2-2. 自領地数閾値チェック
2-3. 戦闘地のレベル取得
2-4. 隣接土地が自領地かチェック
2-5. 隣接自領地数カウント
2-6. 特定クリーチャー名でカウント
2-7. 属性別クリーチャーカウント
2-8. 種族別クリーチャーカウント
2-9. MHP条件を満たすクリーチャー数カウント
2-10. 配置されているか（侵略/防御判定）
2-11. 侵略側か防御側か
2-12. プレイヤー土地情報取得（全属性）
2-13. 同名クリーチャー数カウント（全プレイヤー対象）

### 3. ステータス条件
3-1. MHP（最大HP）閾値以下
3-2. MHP（最大HP）閾値以上
3-3. 敵のMHPチェック
3-4. 敵のSTチェック
3-5. 基礎STの取得と使用
3-6. 現在HP取得

### 4. アイテム条件
4-1. アイテム装備チェック
4-2. アイテムタイプチェック
4-3. 敵アイテム未使用チェック
4-4. アイテムレアリティチェック（レベル額）
4-5. 自分がアイテム未使用
4-6. アイテム効果値取得
4-7. 援護クリーチャーMHP取得

### 5. バトル状況条件
5-1. 巻物攻撃使用中
5-2. バフ検出（巻物攻撃判定用）
5-3. 反射無効持ちチェック
5-4. アイテム操作無効持ちチェック
5-5. 攻撃タイプ判定（通常/巻物）
5-6. 先制攻撃順序
5-7. 貫通スキルチェック
5-8. 変身復帰判定
5-9. 敵がアイテム使用したフラグ

### 6. 数値カウント条件
6-1. 破壊数カウント取得
6-2. ターン数取得
6-3. 周回数取得
6-4. 手札数取得
6-5. 領地レベル取得
6-6. ダイス値取得
6-7. ランダム値生成
6-8. 応援スキル持ちカウント

### 7. 応援スキル専用条件
7-1. 対象範囲チェック
7-2. 名前部分一致条件
7-3. 種族条件
7-4. 所有者一致条件

### 8. 特殊条件
8-1. クリーチャーID直接比較
8-2. キーワード存在チェック
8-3. effect_type による分岐

### 9. 集約可能な条件グループ
9-1. Group A: 土地カウント系（最優先）
9-2. Group B: 属性チェック系（最優先）
9-3. Group C: ステータス閾値チェック系（最優先）
9-4. Group D: クリーチャーカウント系（高優先）
9-5. Group E: アイテム条件系（高優先）
9-6. Group F: 配置条件系（中優先）
9-7. Group G: バトル状況系（中優先）

---

## 📊 統計サマリー

| カテゴリ | パターン数 | 使用頻度 |
|---------|-----------|---------|
| 属性条件 | 8種類 | 高 |
| 土地・配置条件 | 13種類 | 非常に高 |
| ステータス条件 | 6種類 | 中 |
| アイテム条件 | 7種類 | 中 |
| バトル状況条件 | 9種類 | 高 |
| 数値カウント条件 | 8種類 | 高 |
| **合計** | **51種類** | - |

---

## 1️⃣ 属性条件パターン

### 1-1. 自分の属性確認
```gdscript
var my_element = participant.creature_data.get("element", "")
if my_element == "fire":
```
**使用箇所**: 8箇所以上
- condition_checker.gd: 属性判定
- battle_skill_processor.gd: 応援対象判定
- JSON: 各クリーチャーの属性定義

**対象クリーチャー**: 全クリーチャー（属性ベースのスキル持ち）

---

### 1-2. 敵の属性確認
```gdscript
var enemy_element = context.get("enemy_element", "")
if enemy_element in ["water", "wind"]:
```
**使用箇所**: 6箇所
- condition_checker.gd: `enemy_is_element`
- battle_skill_processor.gd: `apply_battle_condition_effects`

**対象クリーチャー**:
- カクタスウォール (205): 敵が水/風の場合 HP+50
- グラディエーター: 敵が特定属性の場合 強打

---

### 1-3. 戦闘地の属性確認
```gdscript
var battle_land_element = context.get("battle_land_element", "")
if battle_land_element == "fire":
```
**使用箇所**: 5箇所
- condition_checker.gd: `on_element_land`
- battle_skill_processor.gd: `apply_battle_condition_effects`

**対象クリーチャー**:
- アンフィビアン (110): 戦闘地が水/風の場合 ST+20
- ネッシー (131): 戦闘地が水の場合 HP+(レベル×10)

---

### 1-4. 同属性・異属性判定
```gdscript
var my_element = context.get("creature_element", "")
var enemy_element = context.get("enemy_element", "")
if my_element == enemy_element:  # 同属性
if my_element != enemy_element:  # 異属性
```
**使用箇所**: 4箇所
- condition_checker.gd: `enemy_same_element`, `enemy_different_element`

**対象クリーチャー**:
- バーサーカー系: 同属性の敵に強打
- レジスタンス系: 異属性の敵に強打

---

### 1-5. 複数属性の土地所持チェック（全属性）
```gdscript
var player_lands = context.get("player_lands", {})
if player_lands.get("fire", 0) > 0 and \
   player_lands.get("water", 0) > 0 and \
   player_lands.get("earth", 0) > 0 and \
   player_lands.get("wind", 0) > 0:
```
**使用箇所**: 1箇所
- condition_checker.gd: `has_all_elements`

**対象クリーチャー**:
- **現在未使用**（コードは存在するが、該当スキルを持つクリーチャーが実装されていない）
- 将来的に「火水地風全て所持で強打」などの条件で使用予定

---

### 1-6. 感応（属性土地所持チェック）
```gdscript
var required_element = resonance_condition.get("element", "")
var player_lands = context.get("player_lands", {})
var owned_count = player_lands.get(required_element, 0)
if owned_count > 0:
```
**使用箇所**: 1箇所（汎用処理）
- battle_skill_processor.gd: `apply_resonance_skill()`

**対象クリーチャー**: 感応持ち全て（約20体以上）
- 各属性のクリーチャーが該当属性の土地を1つでも所持していればバフ

---

### 1-7. 属性別土地数カウント（単一）
```gdscript
var fire_count = player_lands.get("fire", 0)
```
**使用箇所**: 15箇所以上
- battle_skill_processor.gd: `apply_land_count_effects()`
- battle_skill_processor.gd: `apply_resonance_skill()`

**対象クリーチャー**:
- ファイアードレイク (37): ST+火配置数×5
- その他土地数比例系（約7体）

---

### 1-8. 属性別土地数カウント（複数属性合計）
```gdscript
var target_elements = effect.get("elements", [])
var total_count = 0
for element in target_elements:
	total_count += player_lands.get(element, 0)
```
**使用箇所**: 6箇所
- battle_skill_processor.gd: `apply_land_count_effects()`

**対象クリーチャー**:
- **複数属性合計:**
  - アームドパラディン (1): ST+（火+地）配置数×10
- **単属性:**
  - ファイアードレイク (37): ST+火配置数×5
  - ブランチアーミー (236): ST+地配置数×5
  - マッドマン (238): HP+地配置数×5
  - ガルーダ (307): ST&HP=風配置数×10
  - アンダイン (109): HP=水配置数×20

**注**: コードは複数属性合計に対応しており、`elements` 配列に複数指定可能

---

## 2️⃣ 土地・配置条件パターン

### 2-1. 自領地数カウント
```gdscript
var owned_land_count = board_system_ref.get_player_owned_land_count(player_id)
```
**使用箇所**: 3箇所
- battle_skill_processor.gd: `apply_phase_3b_effects()` (バーンタイタン)
- board_system_3d.gd: `get_player_owned_land_count()`

**対象クリーチャー**:
- バーンタイタン (30): 自領地5個以上で ST&HP-30

---

### 2-2. 自領地数閾値チェック
```gdscript
var threshold = effect.get("threshold", 5)
if owned_land_count >= threshold:
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `apply_phase_3b_effects()`

**対象クリーチャー**:
- バーンタイタン (30): 閾値5

---

### 2-3. 戦闘地のレベル取得
```gdscript
var tile_level = context.get("tile_level", 1)
var bonus = tile_level * multiplier
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `apply_phase_3b_effects()` (ネッシー)
- condition_checker.gd: `land_level_check`

**対象クリーチャー**:
- ネッシー (131): 水の土地でHP+(レベル×10)

---

### 2-4. 隣接土地が自領地かチェック
```gdscript
var battle_tile = context.get("battle_tile_index", -1)
var player_id = context.get("player_id", -1)
var result = board_system.tile_neighbor_system.has_adjacent_ally_land(
	battle_tile, player_id, board_system
)
```
**使用箇所**: 4箇所
- condition_checker.gd: `adjacent_ally_land`
- battle_skill_processor.gd: 応援スキルのボーナス計算

**対象クリーチャー**:
- タイガーヴェタ (226): 隣接自領地で ST&HP+20
- 応援スキル持ち: 隣接自領地数でボーナス変動

---

### 2-5. 隣接自領地数カウント
```gdscript
func _count_adjacent_ally_lands(tile_index: int, player_id: int) -> int:
	var neighbors = board_system_ref.tile_neighbor_system.get_spatial_neighbors(tile_index)
	var ally_count = 0
	for neighbor_index in neighbors:
		var tile_info = board_system_ref.tile_data_manager.get_tile_info(neighbor_index)
		if tile_info.get("owner", -1) == player_id:
			ally_count += 1
	return ally_count
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: 応援スキル

**対象クリーチャー**:
- 応援スキル持ち（動的ボーナス計算）

---

### 2-6. 特定クリーチャー名でカウント
```gdscript
var creature_count = board_system.count_creatures_by_name(player_id, target_name)
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `apply_phase_3b_effects()` (ハイプワーカー)
- board_system_3d.gd: `count_creatures_by_name()`

**対象クリーチャー**:
- ハイプワーカー (32): ST&HP+ハイプワーカー配置数×10

---

### 2-7. 属性別クリーチャーカウント
```gdscript
var count = board_system.count_creatures_by_element(player_id, element)
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `apply_phase_3b_effects()` (リビングクローブ)
- board_system_3d.gd: `count_creatures_by_element()`

**対象クリーチャー**:
- リビングクローブ (440): ST&HP=他属性の配置数×5

---

### 2-8. 種族別クリーチャーカウント
```gdscript
for tile_index in tile_data_manager.tile_nodes:
	var tile = tile_data_manager.tile_nodes[tile_index]
	if tile.creature_data.get("race", "") == race:
		count += 1
```
**使用箇所**: 1箇所
- battle_preparation.gd: `_apply_ogre_lord_bonus()` (オーガロード)

**対象クリーチャー**:
- オーガロード (407): オーガ種族カウント

---

### 2-9. MHP条件を満たすクリーチャー数カウント
```gdscript
var player_tiles = board_system_ref.get_player_tiles(player_id)
for tile in player_tiles:
	var creature_mhp = creature_hp + creature_base_up_hp
	if creature_mhp >= threshold:
		qualified_count += 1
```
**使用箇所**: 1箇所
- battle_skill_processor.gd: `apply_phase_3c_effects()` (ジェネラルカン)

**対象クリーチャー**:
- ジェネラルカン (15): ST+MHP50以上配置数×5

---

### 2-10. 配置されているか（侵略/防御判定）
```gdscript
var is_placed_on_tile = context.get("is_placed_on_tile", false)
if not is_placed_on_tile:
	# 侵略側（配置されていない）
```
**使用箇所**: 4箇所
- battle_skill_processor.gd: 各種効果の適用判定

**対象クリーチャー**:
- ハイプワーカーなどのカウント系（自分を含めるか判定）

---

### 2-11. 侵略側か防御側か
```gdscript
var is_attacker = context.get("is_attacker", true)
if not is_attacker:
	# 防御側
```
**使用箇所**: 5箇所
- battle_skill_processor.gd: `apply_phase_3b_effects()` (ガーゴイル)
- battle_skill_processor.gd: 応援対象判定

**対象クリーチャー**:
- ガーゴイル (204): 防御時ST=50
- 応援スキル持ち（侵略側/防御側限定）

---

### 2-12. プレイヤー土地情報取得（全属性）
```gdscript
var player_lands = board_system_ref.get_player_lands_by_element(player_id)
# 結果: {"fire": 2, "water": 1, "earth": 3, "wind": 0}
```
**使用箇所**: 10箇所以上
- battle_skill_processor.gd: 各種土地条件処理
- すべての土地数依存スキル

**対象クリーチャー**: 土地数依存スキル全般

---

### 2-13. 同名クリーチャー数カウント（全プレイヤー対象）
```gdscript
var enemy_name = context.get("enemy_name", "")
var board_system = context.get("board_system", null)
var count = board_system.count_all_creatures_by_name(enemy_name)
if count >= 2:
```
**使用箇所**: 1箇所
- condition_checker.gd: `same_creature_count_check`
- board_system_3d.gd: `count_all_creatures_by_name()`

**対象アイテム**:
- シャドウブレイズ (1015): 敵と同じクリーチャーが盤面に2体以上いる場合、巻物強打

**注**: 敵味方問わず、盤面全体で同名クリーチャーをカウント

---

## 3️⃣ ステータス条件パターン

### 3-1. MHP（最大HP）閾値以下
```gdscript
var target_mhp = context.get("creature_mhp", 100)
if target_mhp <= 40:
```
**使用箇所**: 5箇所
- condition_checker.gd: `mhp_below`

**対象クリーチャー**:
- フロギストン (42): MHP40以下で強打
- その他強打条件持ち

---

### 3-2. MHP（最大HP）閾値以上
```gdscript
var target_mhp = context.get("creature_mhp", 0)
if target_mhp >= 50:
```
**使用箇所**: 5箇所
- condition_checker.gd: `mhp_above`
- battle_skill_processor.gd: ジェネラルカンのカウント条件

**対象クリーチャー**:
- ジェネラルカン (15): MHP50以上のクリーチャー数カウント
- ウォーリアー系: MHP50以上で強打

---

### 3-3. 敵のMHPチェック

```gdscript
var enemy_mhp = context.get("enemy_mhp", 0)
if enemy_mhp >= 50:
```

**使用箇所**: condition_checker.gd: `enemy_max_hp_check`

**対象クリーチャー**: 強打条件として使用

**重要**: 
- JSON条件では`operator`と`value`を使用
  ```json
  {
	"condition_type": "enemy_max_hp_check",
	"operator": ">=",
	"value": 40
  }
  ```
- `battle_skill_processor.gd`で`enemy_mhp_override`を設定し、`defender.get_max_hp()`を渡す
- `get_max_hp()`は`base_hp + base_up_hp`を返す（戦闘ボーナス除く）

---

### 3-4. 敵のSTチェック
```gdscript
var enemy_st = context.get("enemy_st", 0)
if enemy_st <= 30:
```
**使用箇所**: 4箇所
- condition_checker.gd: `enemy_st_check`, `st_below`, `st_above`

**対象クリーチャー**:
- 強打条件として使用
- 即死スキルの条件

---

### 3-5. 基礎STの取得と使用
```gdscript
var base_st = participant.creature_data.get("ap", 0)
var base_up_st = participant.creature_data.get("base_up_ap", 0)
var total_base_st = base_st + base_up_st
```
**使用箇所**: 5箇所
- battle_skill_processor.gd: `apply_phase_3c_effects()` (ローンビースト)
- battle_skill_processor.gd: 巻物攻撃

**対象クリーチャー**:
- ローンビースト (49): HP+基礎ST
- 巻物攻撃持ち全般

---

### 3-6. 現在HP取得
```gdscript
var current_hp = participant.current_hp
var creature_data_current_hp = creature_data.get("current_hp", max_hp)
```
**使用箇所**: 8箇所以上
- 全バトル処理

**対象クリーチャー**: 全クリーチャー

---

## 4️⃣ アイテム条件パターン

### 4-1. アイテム装備チェック
```gdscript
var equipped_item = context.get("equipped_item", {})
if not equipped_item.is_empty():
```
**使用箇所**: 6箇所
- condition_checker.gd: `item_equipped`
- battle_skill_processor.gd: 反射・破壊・盗みスキル

**対象クリーチャー**:
- アイテム関連スキル持ち全般

---

### 4-2. アイテムタイプチェック
```gdscript
var item_type = equipped_item.get("item_type", "")
if item_type == "武器":
```
**使用箇所**: 5箇所
- condition_checker.gd: `with_weapon`, `with_item_type`

**対象クリーチャー**:
- 武器装備で強打系

---

### 4-3. 敵アイテム未使用チェック
```gdscript
var enemy_item = context.get("enemy_item", null)
if enemy_item == null:
```
**使用箇所**: 3箇所
- condition_checker.gd: `enemy_no_item`
- battle_skill_processor.gd: 反射スキル

**対象アイテム・クリーチャー**:
- **ミラーホブロン (1066)**: 敵アイテム未使用時、反射[全]（通常・巻物攻撃100%反射）

**注**: デコイ (426) は無条件反射、ミラーホブロンは敵アイテム未使用が条件

---

### 4-4. アイテムレアリティチェック（レベル額）
```gdscript
var item_rarity = equipped_item.get("rarity", "N")
if item_rarity == "レベル額":
```
**使用箇所**: 2箇所
- condition_checker.gd: `level_cap_item`

**対象クリーチャー**:
- レベル額（特殊レアリティ）使用で強打系

**注**: 「レベル額」は特殊なアイテムレアリティであり、通常の「N/R/S」とは異なる

---

### 4-5. 自分がアイテム未使用
```gdscript
var self_items = participant.creature_data.get("items", [])
if self_items.is_empty():
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: アイテム盗みスキル

**対象クリーチャー**:
- バンディット: 自分がアイテム未使用時に盗める

---

### 4-6. アイテム効果値取得
```gdscript
var effect_parsed = item.get("effect_parsed", {})
var stat_bonus = effect_parsed.get("stat_bonus", {})
var st = stat_bonus.get("st", 0)
var hp = stat_bonus.get("hp", 0)
```
**使用箇所**: 5箇所
- battle_preparation.gd: `apply_item_effects()`
- battle_skill_processor.gd: アイテム破壊・盗み

**対象**: 全アイテム

---

### 4-7. 援護クリーチャーMHP取得
```gdscript
var assist_base_hp = item_data.get("hp", 0)
var assist_base_up_hp = item_data.get("base_up_hp", 0)
var assist_mhp = assist_base_hp + assist_base_up_hp
```
**使用箇所**: 1箇所
- battle_preparation.gd: ブラッドプリン専用

**対象クリーチャー**:
- ブラッドプリン (137): 援護MHP吸収

---

## 5️⃣ バトル状況条件パターン

### 5-1. 巻物攻撃使用中
```gdscript
if participant.is_using_scroll:
```
**使用箇所**: 5箇所
- battle_skill_processor.gd: 強打・感応スキル判定

**対象クリーチャー**:
- 巻物攻撃・巻物強打持ち全般

---

### 5-2. バフ検出（巻物攻撃判定用）
```gdscript
var base_ap = participant.creature_data.get("ap", 0)
var expected_ap = base_ap + participant.base_up_ap
if participant.current_ap != expected_ap:
	# base_up_ap以外のバフが入っている
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `check_scroll_attack()`

**対象クリーチャー**:
- オーガロード (407): バフ時は巻物攻撃不可
- モルモ: バフ時は巻物攻撃不可

---

### 5-3. 反射無効持ちチェック
```gdscript
var effects = attacker_p.creature_data.get("ability_parsed", {}).get("effects", [])
for effect in effects:
	if effect.get("effect_type") == "nullify_reflect":
		return true
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `_has_nullify_reflect()`

**対象クリーチャー**:
- 反射無効持ち

---

### 5-4. アイテム操作無効持ちチェック
```gdscript
if effect.get("effect_type") == "nullify_item_manipulation":
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `_has_nullify_item_manipulation()`

**対象クリーチャー**:
- アイテム操作無効持ち

---

### 5-5. 攻撃タイプ判定（通常/巻物）
```gdscript
var attack_type = "normal"  # or "scroll"
var attack_types = effect.get("attack_types", [])
if attack_type in attack_types:
```
**使用箇所**: 3箇所
- battle_skill_processor.gd: 反射スキル

**対象クリーチャー**:
- 反射スキル持ち全般

---

### 5-6. 先制攻撃順序
```gdscript
# 先に行動する側の処理
_process_item_manipulation(first, second)
# 後に行動する側の処理
_process_item_manipulation(second, first)
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `apply_item_manipulation()`

**対象クリーチャー**:
- アイテム破壊・盗み持ち全般

---

### 5-7. 貫通スキルチェック
```gdscript
if check_penetration_skill(card_data, defender_creature, tile_info):
	defender_land_bonus = 0
```
**使用箇所**: 1箇所
- battle_preparation.gd: `prepare_participants()`

**対象クリーチャー**:
- 貫通スキル持ち全般

---

### 5-8. 変身復帰判定
```gdscript
if participant.creature_data.has("original_creature_data"):
	# 元に戻す
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: 変身処理

**対象クリーチャー**:
- メタモルフォス、コカトリス等

---

### 5-9. 敵がアイテム使用したフラグ
```gdscript
if attacker.enemy_used_item:
	# 永続バフ適用
```
**使用箇所**: 2箇所
- battle_preparation.gd: ブルガサリ専用
- battle_system.gd: 永続バフ適用

**対象クリーチャー**:
- ブルガサリ (339): 敵アイテム使用で永続ST+10

---

## 6️⃣ 数値カウント条件パターン

### 6-1. 破壊数カウント取得
```gdscript
var destroy_count = game_flow_manager.get_destroy_count()
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `apply_destroy_count_effects()`
- game_flow_manager.gd: 破壊数管理

**対象クリーチャー**:
- ソウルコレクター (323): ST=破壊数×5
- バルキリー (35): 破壊ごとにST+10（永続）
- ダスクドウェラー (227): 破壊ごとにST&MHP+10（永続）

---

### 6-2. ターン数取得
```gdscript
var current_turn = game_flow_manager.current_turn_number
```
**使用箇所**: 2箇所
- battle_skill_processor.gd: `apply_turn_number_bonus()`
- game_flow_manager.gd: ターン管理

**対象クリーチャー**:
- ラーバキン (47): ST=現R数、HP+現R数

---

### 6-3. 周回数取得
```gdscript
var lap_count = game_flow_manager.get_player_lap_count(player_id)
```
**使用箇所**: 1箇所
- game_flow_manager.gd: 周回管理

**対象クリーチャー**:
- キメラ (7): 周回ごとにST+10（永続）
- モスタイタン (41): 周回ごとにMHP+10（永続、リセット可能）

---

### 6-4. 手札数取得
```gdscript
var hand_count = card_system.get_hand_size_for_player(player_id)
```
**使用箇所**: 1箇所
- battle_skill_processor.gd: `apply_hand_count_effects()`

**対象クリーチャー**:
- リリス (146): HP=手札数×10

---

### 6-5. 領地レベル取得
```gdscript
var tile_level = context.get("tile_level", 1)
# または
var tile_level = context.get("current_land_level", 1)
```
**使用箇所**: 3箇所
- condition_checker.gd: `land_level_check`
- battle_skill_processor.gd: ネッシー

**対象クリーチャー**:
- ネッシー (131): HP+(レベル×10)

---

### 6-6. ダイス値取得
```gdscript
var dice_value = context.get("dice_value", -1)
if dice_value <= 3:
```
**使用箇所**: 1箇所
- battle_preparation.gd: ドゥームデボラー専用（未完全実装）

**対象クリーチャー**:
- ドゥームデボラー (23): ダイス3以下でST&MHP+10

---

### 6-7. ランダム値生成
```gdscript
randomize()
var random_value = randi() % (max_value - min_value + 1) + min_value
```
**使用箇所**: 3箇所
- battle_skill_processor.gd: スペクター、ランダム変身

**対象クリーチャー**:
- スペクター (321): ST&HP=ランダム10~70
- メタモルフォス: ランダム変身

---

### 6-8. 応援スキル持ちカウント
```gdscript
var support_dict = board_system_ref.get_support_creatures()
var support_creatures = support_dict.values()
```
**使用箇所**: 1箇所
- battle_skill_processor.gd: `apply_support_skills_to_all()`

**対象クリーチャー**: 応援スキル持ち全般

---

## 7️⃣ 応援スキル専用条件パターン

### 7-1. 対象範囲チェック
```gdscript
var scope = target.get("scope", "")
if scope == "all_creatures":
```
**使用箇所**: 1箇所
- battle_skill_processor.gd: `check_support_target()`

**対象クリーチャー**: 応援スキル持ち全般

---

### 7-2. 名前部分一致条件
```gdscript
var name_pattern = condition.get("name_pattern", "")
var creature_name = participant.creature_data.get("name", "")
if name_pattern in creature_name:
```
**使用箇所**: 1箇所
- battle_skill_processor.gd: `check_support_target()`

**対象クリーチャー**:
- "オーガ"を含む名前、"タイタン"を含む名前など

---

### 7-3. 種族条件
```gdscript
var required_race = condition.get("race", "")
var creature_race = participant.creature_data.get("race", "")
if creature_race == required_race:
```
**使用箇所**: 1箇所
- battle_skill_processor.gd: `check_support_target()`

**対象クリーチャー**:
- オーガ種族、ドラゴン種族など

---

### 7-4. 所有者一致条件
```gdscript
if participant.player_id != supporter_player_id:
	return false
```
**使用箇所**: 1箇所
- battle_skill_processor.gd: `check_support_target()`

**対象クリーチャー**: 自クリーチャーのみ応援

---

## 8️⃣ 特殊条件パターン

### 8-1. クリーチャーID直接比較
```gdscript
var creature_id = participant.creature_data.get("id", -1)
if creature_id == 407:  # オーガロード
```
**使用箇所**: 10箇所以上
- battle_preparation.gd: 特殊処理が必要なクリーチャー

**対象クリーチャー**:
- オーガロード (407)
- ブラッドプリン (137)
- リビングアーマー (438)
- ブルガサリ (339)
- スペクター (321)
- ドゥームデボラー (23)

---

### 8-2. キーワード存在チェック
```gdscript
var keywords = ability_parsed.get("keywords", [])
if "感応" in keywords:
if "強打" in keywords:
if "巻物攻撃" in keywords:
```
**使用箇所**: 15箇所以上
- battle_skill_processor.gd: 各種スキル判定

**対象クリーチャー**: スキルキーワード持ち全般

---

### 8-3. effect_type による分岐
```gdscript
var effect_type = effect.get("effect_type", "")
match effect_type:
	"land_count_multiplier":
	"constant_stat_bonus":
	"battle_land_element_bonus":
```
**使用箇所**: 20箇所以上
- battle_skill_processor.gd: 全効果処理

**effect_type 一覧** (26種類):
1. `land_count_multiplier` - 土地数比例
2. `constant_stat_bonus` - 常時補正
3. `battle_land_element_bonus` - 戦闘地属性条件
4. `enemy_element_bonus` - 敵属性条件
5. `destroy_count_multiplier` - 破壊数比例
6. `turn_number_bonus` - ターン数ボーナス
7. `hand_count_multiplier` - 手札数比例
8. `defender_fixed_ap` - 防御時固定ST
9. `battle_land_level_bonus` - 戦闘地レベルボーナス
10. `owned_land_threshold` - 自領地数閾値
11. `specific_creature_count` - 特定クリーチャーカウント
12. `other_element_count` - 他属性カウント
13. `adjacent_owned_land` - 隣接自領地条件
14. `base_st_to_hp` - 基礎ST→HP変換
15. `conditional_land_count` - 条件付き配置数
16. `random_stat` - ランダムステータス
17. `tribe_placement_bonus` - 種族配置ボーナス
18. `support` - 応援
19. `power_strike` - 強打
20. `transform` - 変身
21. `reflect_damage` - 反射
22. `destroy_item` - アイテム破壊
23. `steal_item` - アイテム盗み
24. `nullify_reflect` - 反射無効
25. `nullify_item_manipulation` - アイテム操作無効
26. `dice_condition_bonus` - ダイス条件ボーナス

---

## 9️⃣ 集約可能な条件グループ

### 🔥 最優先集約候補（重複度: 非常に高）

#### 9-1. Group A: 土地カウント系
- 属性別土地数カウント（単一）: 15箇所
- 属性別土地数カウント（複数）: 5箇所
- 全属性所持チェック: 2箇所
- **推奨**: `LandCounter` クラスに集約

#### 9-2. Group B: 属性チェック系
- 戦闘地属性: 5箇所
- 敵属性: 6箇所
- 同属性・異属性: 4箇所
- **推奨**: `ElementChecker` クラスに集約

#### 9-3. Group C: ステータス閾値チェック系
- MHP閾値: 10箇所
- ST閾値: 4箇所
- **推奨**: `StatChecker` クラスに集約

---

### 🌟 高優先度集約候補

#### 9-4. Group D: クリーチャーカウント系
- 種族カウント: 1箇所（要メソッド追加）
- 名前カウント: 2箇所（既存メソッドあり）
- 属性カウント: 2箇所（既存メソッドあり）
- 条件付きカウント: 1箇所
- **推奨**: `board_system_3d.gd` に `count_creatures_by_race()` 追加

#### 9-5. Group E: アイテム条件系
- 装備チェック: 6箇所
- タイプチェック: 5箇所
- **推奨**: `ItemChecker` クラスに集約

---

### 📝 中優先度集約候補

#### 9-6. Group F: 配置条件系
- 隣接土地判定: 4箇所（既存システムあり）
- 配置判定: 4箇所
- **推奨**: 既存の `TileNeighborSystem` 活用

#### 9-7. Group G: バトル状況系
- バフ検出: 2箇所
- 反射無効: 2箇所
- **推奨**: そのまま（使用頻度低い）

---

## 🎯 実装推奨クラス構成

```gdscript
# scripts/utils/condition_helpers.gd
class_name ConditionHelpers

class LandCounter:
	static func count_by_element(player_lands: Dictionary, element: String) -> int
	static func count_by_elements(player_lands: Dictionary, elements: Array) -> int
	static func has_all_elements(player_lands: Dictionary) -> bool

class ElementChecker:
	static func is_battle_land_element(tile_info: Dictionary, target: String) -> bool
	static func is_battle_land_any_of(tile_info: Dictionary, targets: Array) -> bool
	static func is_enemy_element(context: Dictionary, target: String) -> bool
	static func is_same_element_as_enemy(context: Dictionary) -> bool
	static func is_different_element_from_enemy(context: Dictionary) -> bool

class StatChecker:
	static func check_condition(value: int, operator: String, threshold: int) -> bool
	static func is_mhp_below(mhp: int, threshold: int) -> bool
	static func is_mhp_above(mhp: int, threshold: int) -> bool

class ItemChecker:
	static func has_item(participant: BattleParticipant) -> bool
	static func has_item_type(participant: BattleParticipant, item_type: String) -> bool
	static func is_level_cap(participant: BattleParticipant) -> bool
```

---

## 📊 条件分岐使用頻度ランキング TOP 10

| 順位 | 条件パターン | 使用箇所数 | 集約優先度 |
|-----|------------|-----------|----------|
| 1 | 属性別土地数カウント（単一） | 15+ | ⭐⭐⭐⭐⭐ |
| 2 | effect_type分岐 | 20+ | - (既に集約済み) |
| 3 | キーワード存在チェック | 15+ | - (現状維持) |
| 4 | MHP閾値チェック | 10+ | ⭐⭐⭐⭐⭐ |
| 5 | プレイヤー土地情報取得 | 10+ | ⭐⭐⭐⭐ |
| 6 | クリーチャーID直接比較 | 10+ | - (必要な処理) |
| 7 | 自分の属性確認 | 8+ | ⭐⭐⭐⭐ |
| 8 | 敵の属性確認 | 6+ | ⭐⭐⭐⭐ |
| 9 | アイテム装備チェック | 6+ | ⭐⭐⭐ |
| 10 | 戦闘地属性確認 | 5+ | ⭐⭐⭐⭐ |

---

## 📈 期待効果

### コード削減
- 推定削減行数: **150-200行**
- 重複コード削減率: **約35%**

### メンテナンス性
- 条件ロジック修正箇所: **10-15箇所 → 1箇所**
- 新規条件追加の工数: **60%削減**

### テスタビリティ
- ユニットテスト対象が明確化
- モック作成が容易に

---

## 🚀 次のステップ

1. **このドキュメントの確認**
   - 抜けている条件パターンがないか
   - 追加すべき情報があるか

2. **リファクタリング実施の判断**
   - 実施する場合: Group A（土地カウント）から着手
   - 実施しない場合: リファレンスとして保存

3. **新規条件追加時の参照**
   - 既存パターンを確認
   - 重複を避ける

---

## 📍 スキル別使用箇所

### 応援スキル（skill_support.gd）- 分離済み ✅

**使用している条件パターン**:

#### 1-2. 属性条件（element）
- **ファイル**: `scripts/battle/skills/skill_support.gd`
- **関数**: `_check_support_target()`
- **行数**: 約95-100行目
- **使用例**: 火属性クリーチャーにST+10（Boges）

#### 2-11. 侵略側か防御側か（battle_role）
- **ファイル**: `scripts/battle/skills/skill_support.gd`
- **関数**: `_check_support_target()`
- **行数**: 約103-112行目
- **使用例**: 攻撃側にST+10（Salamander）、防御側にHP+10（Naiad）

#### 7-2. 名前部分一致条件（name_contains）
- **ファイル**: `scripts/battle/skills/skill_support.gd`
- **関数**: `_check_support_target()`
- **行数**: 約115-120行目
- **使用例**: 名前に特定文字列を含むクリーチャーへのバフ

#### 7-3. 種族条件（race）
- **ファイル**: `scripts/battle/skills/skill_support.gd`
- **関数**: `_check_support_target()`
- **行数**: 約123-128行目
- **使用例**: ゴブリン種族にST+10、HP+10（Red Cap）

#### 7-4. 所有者一致条件（owner_match）
- **ファイル**: `scripts/battle/skills/skill_support.gd`
- **関数**: `_check_support_target()`
- **行数**: 約131-134行目
- **使用例**: 自分のクリーチャーのみにバフ（Mad Harlequin）

#### 2-5. 隣接自領地数カウント
- **ファイル**: `scripts/battle/skills/skill_support.gd`
- **関数**: `_count_adjacent_ally_lands()`
- **行数**: 約190-200行目
- **使用例**: 隣接自領地数 × 10 のAP加算（Mad Harlequin）

**分離日**: 2025-10-31

---

### 感応スキル（skill_resonance.gd）- 分離済み ✅

**使用している条件パターン**:

#### 1-6. 感応（属性土地所持チェック）
- **ファイル**: `scripts/battle/skills/skill_resonance.gd`
- **関数**: `apply()`
- **行数**: 約67-74行目
- **使用例**: 火土地を1つ以上所有でAP+30（Phoenix）

#### 2-12. プレイヤー土地情報取得（全属性）
- **ファイル**: `scripts/battle/skills/skill_resonance.gd`
- **関数**: `apply()`
- **行数**: 約68行目
- **使用例**: context.get("player_lands", {})でプレイヤーの全土地情報を取得

**分離日**: 2025-10-31

---

### 強打スキル（skill_power_strike.gd）- 分離済み ✅

**使用している条件パターン**:

#### 2-4. 隣接土地が自領地かチェック (adjacent_ally_land)
- **ファイル**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `apply_normal_power_strike()` → `effect_combat.apply_power_strike()`
- **行数**: 約78-86行目
- **使用例**: 隣接自領地で強打×1.5（多数のクリーチャー）

#### 1-3. 戦闘地の属性確認 (on_element_land)
- **ファイル**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `apply_normal_power_strike()` → `effect_combat.apply_power_strike()`
- **使用例**: 火の土地で強打×2.0

#### 2-3. 戦闘地のレベル取得 (land_level_check)
- **ファイル**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `apply_normal_power_strike()` → `effect_combat.apply_power_strike()`
- **使用例**: レベル3以上で強打×1.5

#### 3-1. MHP（最大HP）閾値以下 (mhp_below)
- **ファイル**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `apply_normal_power_strike()` → `effect_combat.apply_power_strike()`
- **使用例**: MHP40以下で強打（フロギストン ID: 42）

#### 3-2. MHP（最大HP）閾値以上 (mhp_above)
- **ファイル**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `apply_normal_power_strike()` → `effect_combat.apply_power_strike()`
- **使用例**: MHP50以上で強打（ウォーリアー系）

#### 4-2. アイテムタイプチェック (has_item_type)
- **ファイル**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `apply_normal_power_strike()` → `effect_combat.apply_power_strike()`
- **使用例**: 武器装備時に強打×1.5

#### 5-1. 巻物攻撃使用中 (is_using_scroll)
- **ファイル**: `scripts/battle/skills/skill_power_strike.gd`
- **関数**: `apply()`, `apply_scroll_power_strike()`
- **行数**: 約49-52行目、60-67行目
- **使用例**: 巻物使用時に無条件で強打×1.5（巻物強打）

**分離日**: 2025-10-31

**注記**: 
- 通常の強打は`EffectCombat.apply_power_strike()`で条件判定を実行
- 巻物強打は条件なしで無条件にAP×1.5
- 感応スキルの**後**に適用されるため、相乗効果あり

---

### 2回攻撃スキル（skill_double_attack.gd）- 分離済み ✅

**使用している条件パターン**:

#### 8-2. キーワード存在チェック
- **ファイル**: `scripts/battle/skills/skill_double_attack.gd`
- **関数**: `apply()`, `has_skill()`
- **行数**: 約32-35行目
- **使用例**: "2回攻撃"キーワードを保持している場合、攻撃回数を2回に設定

**分離日**: 2025-10-31

**注記**: 
- 非常にシンプルなスキル（約40行）
- キーワードチェックのみ
- 条件なしで無条件に発動

---

**作成者**: Claude  
**バージョン**: 1.5（巻物アイテム・同名クリーチャー数条件追加）  
**最終更新**: 2025-11-02
