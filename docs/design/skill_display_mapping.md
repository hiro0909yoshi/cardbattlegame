# スキル表示マッピング一覧

バトルスクリーンに表示するスキルの一覧と、表示名のマッピング。

## 概要

| 分類 | 説明 |
|------|------|
| keywords系 | JSONの`keywords`配列に含まれる日本語名（そのまま表示可） |
| effect_type系 | JSONの`effect_type`（英語→日本語への変換が必要） |

---

## Keywords系スキル（バトル中発動）

keywordsはすでに日本語名なので、そのまま表示できる。

### 戦闘開始前に発動

| keyword | 表示 | エフェクト | 備考 |
|---------|------|-----------|------|
| 先制 | ✅ | 未定 | 攻撃順決定時 |
| 後手 | ✅ | 未定 | 攻撃順決定時 |
| 強打 | ✅ | 未定 | AP×1.5（条件付きの場合あり） |
| 巻物強打 | ✅ | 未定 | 巻物使用時のみ発動する強打 |
| 貫通 | ✅ | 未定 | 土地ボーナス無効化 |
| 感応 | ✅ | 未定 | 同属性クリーチャー数でHP上昇 |
| 2回攻撃 | ✅ | 未定 | 攻撃を2回行う |
| 巻物攻撃 | ✅ | 未定 | 巻物による攻撃 |
| 無効化 | ✅ | 未定 | 条件付きでダメージ無効化 |
| 再生 | ✅ | 未定 | 戦闘終了時HP全回復 |
| 援護 | ✅ | 未定 | 隣接クリーチャーのステータス加算 |
| 応援 | ✅ | 未定 | 同名クリーチャーのステータス加算 |
| 反射 | ✅ | 未定 | ダメージを反射 |
| 即死 | ✅ | 未定 | 条件付きで敵を即死 |
| 道連れ | ✅ | 未定 | 死亡時に敵も道連れ |
| アイテム破壊 | ✅ | 未定 | 敵のアイテムを破壊 |
| アイテム盗み | ✅ | 未定 | 敵のアイテムを盗む |

### 戦闘終了後に発動（バトル画面内）

| keyword | 表示 | エフェクト | 備考 |
|---------|------|-----------|------|
| 死者復活 | ✅ | 未定 | 死亡時に別クリーチャーとして復活 |
| 遺産 | ✅ | 未定 | 死亡時にEP/カード獲得 |
| 戦闘後破壊 | ✅ | 未定 | 両者生存時に敵に呪い付与 |
| 通行料無効付与 | ✅ | 未定 | 両者生存時に敵に呪い付与 |

### バトル外で発動（表示不要）

| keyword | 理由 |
|---------|------|
| アルカナアーツ | アルカナアーツカード使用時（バトル外） |
| 防魔 | スペル対象外（バトル外） |
| 空地移動 | 移動時（バトル外） |
| 移動侵略無効 | 移動侵略対象外（バトル外） |
| 周回回復不可 | 周回時（バトル外） |
| 通行料変化 | 通行料計算時（バトル外） |

### 将来対応予定（イベント連携でバトル画面表示）

| keyword | 表示名 | 備考 |
|---------|--------|------|
| 合体 | 合体 | 配置時に発動、バトル画面でイベント表示予定 |

---

## Effect_type系スキル（バトル中発動）

effect_typeは英語なので、日本語への変換が必要。

### 戦闘開始前（スキル適用フェーズ）

#### 固有名で表示するスキル

| effect_type | 表示名 | エフェクト | 備考 |
|-------------|--------|-----------|------|
| power_strike | 強打 | 未定 | AP×倍率 |
| resonance | 感応 | 未定 | 同属性数でHP上昇 |
| random_stat | ランダムステータス | 未定 | ステータスをランダム決定 |
| support | 援護 | 未定 | 隣接援護効果 |
| scroll_attack | 巻物攻撃 | 未定 | 巻物による攻撃モード |
| magic_gain_on_battle_start | EP獲得 | 未定 | バトル開始時にEP獲得（クリーピングコイン） |

#### 「ステータス変化」で統一表示するスキル

以下のeffect_typeは全て「ステータス変化」として表示する。

| effect_type | 内容 |
|-------------|------|
| land_count_multiplier | 土地数でステータス変動 |
| turn_number_bonus | ターン数でステータス変動 |
| destroy_count_multiplier | 破壊数でステータス変動 |
| hand_count_multiplier | 手札数でステータス変動 |
| constant_stat_bonus | 固定値のステータス補正 |
| battle_land_level_bonus | 戦闘地レベルでステータス変動 |
| battle_land_element_bonus | 戦闘地属性でステータス変動 |
| defender_fixed_ap | 防御時にAPを固定値に |
| owned_land_threshold | ドミニオ数条件でステータス変動 |
| specific_creature_count | 特定名のクリーチャー数で変動 |
| race_creature_stat_replace | 種族数でステータス決定 |
| other_element_count | 他属性クリーチャー数で変動 |
| adjacent_owned_land | 隣接に自ドミニオがあれば発動 |
| base_ap_to_hp | 基礎APをHPに加算 |
| conditional_land_count | 条件を満たす土地数で変動 |
| enemy_element_bonus | 敵の属性で変動 |
| stat_boost | 固定値のステータス上昇 |
| on_item_use_bonus | アイテム使用時ステータス変動 |
| on_enemy_destroy_permanent | 敵破壊でステータス永続上昇 |
| after_battle_permanent_change | 戦闘後にステータス永続変化 |
| permanent_stat_change | ステータス永続変化 |
| per_lap_permanent_bonus | 周回ごとにステータス永続上昇 |

### 攻撃成功時

| effect_type | 表示名 | エフェクト | 備考 |
|-------------|--------|-----------|------|
| ap_drain | APドレイン | 未定 | 敵のAPを0に |
| penetration | 貫通 | 未定 | 土地ボーナス無効化 |
| apply_curse | 呪い付与 | 未定 | 敵に呪いを付与 |
| down_enemy | ダウン付与 | 未定 | 敵にダウンを付与 |
| transform | 変身 | 未定 | 攻撃成功で敵を変身 |
| magic_steal_on_damage | ダメージEP奪取 | 未定 | ダメージでEP奪取 |
| destroy_item | アイテム破壊 | 未定 | 敵のアイテム破壊 |
| steal_item | アイテム盗み | 未定 | 敵のアイテムを盗む |
| magic_gain_on_invasion | EP獲得 | 未定 | 侵略成功時にEP獲得（ピュトン、トレジャーレイダー） |
| magic_gain_on_damage | EP獲得 | 未定 | ダメージを受けた時にEP獲得（ゼラチンウォール） |

### 無効化判定時

| effect_type | 表示名 | エフェクト | 備考 |
|-------------|--------|-----------|------|
| nullify_all_enemy_abilities | 能力無効化 | 未定 | 敵の全能力を無効化 |
| nullify_item_manipulation | アイテム破壊・盗み無効 | 未定 | アイテム破壊・盗み無効 |
| nullify_reflect | 反射無効 | 未定 | 反射を無効化 |

### 即死判定時

| effect_type | 表示名 | エフェクト | 備考 |
|-------------|--------|-----------|------|
| instant_death | 即死 | 未定 | 条件付き即死 |
| annihilate | 抹消 | 未定 | 敵撃破時に同種カードを消滅 |

### 反射判定時

| effect_type | 表示名 | エフェクト | 備考 |
|-------------|--------|-----------|------|
| reflect_damage | 反射 | 未定 | ダメージを反射 |

### 戦闘終了時

| effect_type | 表示名 | エフェクト | 備考 |
|-------------|--------|-----------|------|
| swap_ap_mhp | AP⇔MHP交換 | 未定 | 敵のAPとMHPを交換 |
| change_tile_element | 土地変性 | 属性別 | 勝利時に土地属性変更 |
| reduce_enemy_mhp | MHP減少 | 未定 | 敵のMHPを減少 |
| level_up_battle_land | 戦闘地レベルアップ | 未定 | 戦闘地のレベル上昇 |
| spawn_copy_on_defend_survive | 分裂 | 未定 | 防御生存時にコピー配置 |
| item_return | アイテム復帰 | 未定 | 使用したアイテムがブックに戻る |

### 死亡時

| effect_type | 表示名 | エフェクト | 備考 |
|-------------|--------|-----------|------|
| revive | 死者復活 | 未定 | 別クリーチャーとして復活 |
| revive_to_hand | 手札復活 | 未定 | 手札に戻る |
| self_destruct | 自壊 | 未定 | 条件を満たすと自壊 |
| self_destruct_with_revenge | 道連れ自爆 | 未定 | 自爆して敵も道連れ |
| legacy_magic | 遺産（EP） | 未定 | 死亡時にEP獲得 |
| legacy_card | 遺産（カード） | 未定 | 死亡時にカード獲得 |
| draw_cards_on_death | 死亡時ドロー | 未定 | 死亡時にカードを引く |
| revenge_mhp_damage | 雪辱 | 未定 | 死亡時に敵MHPダメージ |

---

## パラメータ分岐が必要なスキル

同じeffect_typeでも、パラメータによってエフェクトを変える必要があるもの。

### 土地変性（change_tile_element）

| パラメータ | 表示名 | エフェクト |
|-----------|--------|-----------|
| element: "water" | 土地変性[水] | element_change_water |
| element: "fire" | 土地変性[火] | element_change_fire |
| element: "wind" | 土地変性[風] | element_change_wind |
| element: "earth" | 土地変性[地] | element_change_earth |

### 呪い付与（apply_curse）

| パラメータ | 表示名 | エフェクト |
|-----------|--------|-----------|
| curse_type: "toll_disable" | 通行料無効付与 | curse_toll_disable |
| curse_type: "destroy_after_battle" | 戦闘後破壊付与 | curse_destroy |

| curse_type: "land_effect_disable" | 地形効果無効付与 | curse_land_disable |
| curse_type: "land_effect_grant" | 地形効果付与 | curse_land_grant |

### 変身（transform）

| パラメータ | 表示名 | エフェクト |
|-----------|--------|-----------|
| transform_type: "forced" | 強制変化 | transform_forced |
| transform_type: "forced_copy_attacker" | 強制コピー | transform_copy |
| transform_type: "random" | ランダム変身 | transform_random |
| transform_type: "specific" | 変身 | transform_specific |

---

## 表示優先度

同時に複数スキルが発動する場合の表示順序。

1. 攻撃順決定系（先制、後手）
2. ステータス変動系（感応、強打、貫通など）
3. 無効化系
4. 攻撃成功時系
5. 戦闘終了時系
6. 死亡時系

---

## 実装状況

### 対応済み（SkillDisplayConfigに登録済み）

**戦闘開始前**
- [x] ステータス変化（stat_change）
- [x] ランダムステータス（random_stat）
- [x] 応援（support）
- [x] 先制（first_strike）
- [x] 後手（last_strike）
- [x] 感応（resonance）
- [x] 強打（power_strike）
- [x] 貫通（penetration）
- [x] 巻物攻撃（scroll_attack）
- [x] アイテム破壊（destroy_item）
- [x] アイテム盗み（steal_item）
- [x] EP獲得（magic_gain）

**攻撃成功時**
- [x] APドレイン（ap_drain）
- [x] 呪い付与（apply_curse）

**戦闘終了時**
- [x] 再生（regeneration）
- [x] AP⇔MHP交換（swap_ap_mhp）
- [x] MHP減少（reduce_enemy_mhp）
- [x] 土地レベルアップ（level_up_battle_land）
- [x] アイテム復帰（item_return）

**死亡時**
- [x] 自壊（self_destruct）
- [x] 道連れ（death_revenge）
- [x] 遺産・EP（legacy_magic）
- [x] 遺産・カード（legacy_card）
- [x] 死者復活（revive）
- [x] 手札復活（revive_to_hand）
- [x] 抹消（annihilate）
- [x] 雪辱（revenge_mhp_damage）

### 対応済み（ステータス変動あり → 自動表示）

- [x] 各種ステータス変動スキル（_show_skill_change_if_anyで表示）

### 対応済み（発動箇所に表示処理追加済み）

**即死・反射・変身・無効化**
- [x] 即死（instant_death）
- [x] 反射（reflect_damage）
- [x] 変身（transform）
- [x] 能力無効化（nullify_abilities）

**アイテム操作**
- [x] アイテム破壊（destroy_item）
- [x] アイテム盗み（steal_item）

**戦闘終了時効果（SkillBattleEndEffects経由）**
- [x] 戦闘後破壊付与（apply_curse: destroy_after_battle）
- [x] 通行料無効付与（apply_curse: toll_disable）
- [x] AP⇔MHP交換（swap_ap_mhp）
- [x] MHP減少（reduce_enemy_mhp）
- [x] 土地レベルアップ（level_up_battle_land）

**バトル勝利時効果（battle_system.gd）**
- [x] 土地変性（change_tile_element）→ global_comment_uiで通知
- [x] 土地破壊（reduce_tile_level）→ global_comment_uiで通知

### スペル効果（バトル外）

以下はスペルカード使用時に表示されるため、バトル画面スキル表示の対象外：
- 地形効果無効付与（apply_curse: land_effect_disable）
- 地形効果付与（apply_curse: land_effect_grant）

---

## 次のステップ

1. ~~`skill_display_config.gd`を作成~~ ✅ 完了
2. 未対応スキルをCONFIGに追加
3. 各発動箇所に表示処理を追加
4. エフェクトは後から追加（空文字で開始）

## 実装パターン

### ステータス変動ありのスキル
```gdscript
var skill_name = SkillDisplayConfig.get_skill_name("effect_type")
await _show_skill_change_if_any(participant, before, skill_name)
```

### ステータス変動なしのスキル
```gdscript
await _show_skill_no_stat_change(participant, "effect_type")
```
