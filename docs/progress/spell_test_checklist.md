# スペルテスト チェックリスト

全191スペル（spell_1: 64枚, spell_2: 68枚, spell_mystic: 59枚）のテスト進捗管理。
1枚のスペルに複数effect_typeを持つものがあるため、effect単位では約170効果。

**テスト方針**: 各effect_typeに対してユニットテストで効果の正しさを検証する。
合成効果(synthesis)は別途テストが必要な場合がある。

**テストファイル一覧**:
- `test/spell/spell_test_helper.gd` - 共通ヘルパー（MockTile, create_tile_nodes等）
- `test/spell/spell_test_board.gd` - MockBoardSystem（change_tile_terrain対応）
- `test/spell/test_spell_land.gd` - 土地変更系テスト
- `test/spell/test_spell_damage.gd` - ダメージ・回復系テスト
- `test/spell/test_spell_magic.gd` - EP/Magic操作系テスト
- `test/spell/test_spell_curse.gd` - クリーチャー刻印系テスト
- `test/spell/test_spell_self_destroy.gd` - 自滅効果系テスト
- `test/spell/test_spell_creature_place.gd` - クリーチャー配置系テスト
- `test/spell/test_spell_creature_return.gd` - クリーチャー手札戻し系テスト
- `test/spell/test_spell_transform.gd` - クリーチャー変身系テスト
- `test/spell/test_spell_creature_swap.gd` - クリーチャー交換系テスト
- `test/spell/test_spell_creature_move.gd` - クリーチャー移動系テスト
- `test/spell/test_spell_player_move.gd` - プレイヤー移動系テスト

---

## 1. ダメージ系（damage_effect_strategy） - 16スペル

テストファイル: `test/spell/test_spell_damage.gd`（共通）, `test/spell/test_spell_damage_cards.gd`（個別カード）
担当システム: `SpellDamage`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2016 | クリティカル | damage | spell_1 | [x] | ダメージ値+apply_damage検証 |
| 2 | 2023 | マッサカー | damage | spell_1 | [x] | ダメージ値+apply_damage検証 |
| 3 | 2031 | ボルト | damage | spell_1 | [x] | ダメージ値+apply_damage検証 |
| 4 | 2033 | ラディエンス | damage | spell_1 | [x] | ダメージ値検証 |
| 5 | 2037 | プレデター | damage | spell_1 | [x] | ダメージ値検証 |
| 6 | 2041 | ロックストーム | damage | spell_1 | [x] | ダメージ値検証 |
| 7 | 2053 | スナイプ | damage | spell_1 | [x] | ダメージ値検証 |
| 8 | 2065 | フレア | damage | spell_2 | [x] | ダメージ値検証 |
| 9 | 2086 | フロスト | damage | spell_2 | [x] | ダメージ値検証 |
| 10 | 2088 | フュージョン | damage | spell_2 | [x] | ダメージ値検証 |
| 11 | 2106 | スパーク | damage | spell_2 | [x] | ダメージ値検証 |
| 12 | 9004 | マジックボルト | damage | spell_mystic | [x] | ダメージ値+apply_damage検証 |
| 13 | 9005 | ロックブレス | damage | spell_mystic | [x] | ダメージ値検証 |
| 14 | 9006 | ストームコール | damage | spell_mystic | [x] | ダメージ値検証 |
| 15 | 9007 | クロムレイ | damage | spell_mystic | [x] | ダメージ値検証 |
| 16 | 9008 | 熾天断罪 | damage | spell_mystic | [x] | ダメージ値検証 |

**共通テスト済み（SpellDamage単体テスト）**: apply_damage基本/致死/base_up_hp/空タイル/無効タイル, apply_heal基本/上限/全回復/base_up/満タン, 連続ダメージ, ダメージ後回復
**個別カードテスト（19テスト全通過）**: 全16スペルのJSON定義ダメージ値検証 + apply_damageによる効果検証（クリティカル/マッサカー/ボルト/マジックボルト） + 撃破ボーダーテスト3件（ちょうど撃破/生存/最小HP撃破）

---

## 2. 回復系（heal_effect_strategy） - 3スペル

テストファイル: `test/spell/test_spell_damage.gd`
担当システム: `SpellDamage`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2116 | スプリング | full_heal | spell_2 | [x] | 全回復+base_up込み+満タン時 |
| 2 | 2121 | リジェネ | full_heal | spell_2 | [x] | clear_down+full_heal複合(3パターン) |
| 3 | 9009 | ヒール | heal | spell_mystic | [x] | 固定値30回復+MHPキャップ+base_up |

**テスト済み（12テスト全通過）**: JSON定義3スペル(target_type確認含む) + ヒール固定値回復(基本/MHPキャップ/base_up込み) + スプリング全回復(基本/base_up/満タン) + リジェネ複合テスト(ダウン+ダメージ/ダウンなし/ダウン+満タン)
**共通テスト済み**: apply_heal, apply_full_heal は SpellDamage単体テストでもカバー済み

---

## 3. 土地変更系（land_change_effect_strategy） - 18スペル

テストファイル: `test/spell/test_spell_land.gd`
担当システム: `SpellLand`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2001 | アースフォージ | change_element | spell_1 | [x] | earth変更 |
| 2 | 2010 | ウォーターフォージ | change_element | spell_1 | [x] | water変更 |
| 3 | 2011 | エアーフォージ | change_element | spell_1 | [x] | wind変更 |
| 4 | 2022 | リセット | change_element | spell_1 | [x] | neutral変更 |
| 5 | 2074 | ファイアーフォージ | change_element | spell_2 | [x] | fire変更 |
| 6 | 9040 | アースシフト | change_element | spell_mystic | [x] | earth変更 |
| 7 | 9041 | ニュートラルシフト | change_element | spell_mystic | [x] | neutral+self_destruct |
| 8 | 2040 | タイダルフォージ | change_element_bidirectional | spell_1 | [x] | fire<->water |
| 9 | 2103 | ガイアフォージ | change_element_bidirectional | spell_2 | [x] | 同上テスト済み |
| 10 | 2008 | アライン | change_element_to_dominant | spell_1 | [x] | 最多属性テスト済み |
| 11 | 2003 | コメット | change_level | spell_1 | [x] | レベル-1 |
| 12 | 2029 | クラッシュ | change_level | spell_1 | [x] | レベル変更テスト済み |
| 13 | 2118 | セール | abandon_land | spell_2 | [x] | 土地放棄テスト済み |
| 14 | 2030 | ダウナー | find_and_change_highest_level | spell_1 | [x] | 最高レベル検索+レベル変更+土地なし |
| 15 | 2085 | グラウンド | conditional_level_change | spell_2 | [x] | 条件成立/不成立/超過 |
| 16 | 2096 | マッチ | align_mismatched_lands | spell_2 | [x] | 不一致検索+条件成立/不成立 |
| 17 | 9039 | アクアシフト | change_caster_tile_element | spell_mystic | [x] | 術者タイル属性変更 |
| 18 | 9041 | ニュートラルシフト | self_destruct | spell_mystic | [x] | 自滅+クリーチャーなし失敗 |

**テスト済み（33テスト全通過）**: change_element(全5属性), bidirectional, change_level(上下限), set_level, abandon_land, dominant_element + JSON定義5スペル + find_highest_level(検索/変更/土地なし) + conditional_level_change(成立/不成立/超過) + align_mismatched(検索/成立/不成立) + change_caster_tile_element + self_destruct(成功/クリーチャーなし)

---

## 4. ドロー系（draw_effect_strategy） - 15スペル

テストファイル: `test/spell/test_spell_draw_cards.gd`
担当システム: `CardSystem` / `SpellDraw`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2024 | プライス | draw | spell_1 | [x] | JSON定義(draw+toll_multiplier) |
| 2 | 2054 | カース | draw | spell_1 | [x] | JSON定義(draw+stat_reduce) |
| 3 | 2058 | ウィークネス | draw | spell_1 | [x] | JSON定義(draw持ち確認) |
| 4 | 2066 | エンハンス | draw | spell_2 | [x] | JSON定義(draw+stat_boost) |
| 5 | 2094 | ヌル | draw | spell_2 | [x] | JSON定義(draw持ち確認) |
| 6 | 2120 | フラックス | draw | spell_2 | [x] | JSON定義(draw持ち確認) |
| 7 | 2020 | ラッキー | draw_by_rank | spell_1 | [x] | JSON定義+効果(1位/3位ドロー) |
| 8 | 2090 | チョイス | draw_by_type | spell_2 | [x] | JSON定義+効果(type指定ドロー) |
| 9 | 9003 | アイテムリプレニッシュ | draw_by_type | spell_mystic | [x] | JSON定義確認 |
| 10 | 9043 | アイテムドロー | draw_by_type | spell_mystic | [x] | JSON定義確認 |
| 11 | 2095 | ラック | draw_cards | spell_2 | [x] | JSON定義(count=2)+効果(複数ドロー) |
| 12 | 9042 | カードドロー | draw_cards | spell_mystic | [x] | JSON定義確認 |
| 13 | 2078 | オラクル | draw_from_deck_selection | spell_2 | [x] | JSON定義確認 |
| 14 | 2132 | ディスカバー | draw_and_place | spell_2 | [x] | JSON定義確認 |
| 15 | 9002 | カード獲得 | draw_until | spell_mystic | [x] | JSON定義(target_hand_size=5)+効果 |

**テスト済み（28テスト全通過）**: JSON定義15スペル + draw_one(基本/デッキ空) + draw_cards(2枚/超過) + draw_until(補充/既足) + draw_by_rank(3位/1位) + draw_card_by_type(成功/なし) + discard_and_draw_plus(3枚/0枚) + add_specific_card

---

## 5. クリーチャー刻印系（creature_curse_effect_strategy） - 30スペル

テストファイル: `test/spell/test_spell_curse.gd`
担当システム: `SpellCurse`

### 5-A. テスト済み effect_type

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2094 | ヌル | skill_nullify | spell_2 | [x] | 錯乱 |
| 2 | 2057 | スタン | battle_disable | spell_1 | [x] | 消沈 |
| 3 | 2068 | ディスペア | battle_disable | spell_2 | [x] | 同上 |
| 4 | 2058 | ウィークネス | ap_nullify | spell_1 | [x] | AP=0 |
| 5 | 2067 | ライズアップ | indomitable | spell_2 | [x] | 奮闘 |
| 6 | 2054 | カース | stat_reduce | spell_1 | [x] | 零落 |
| 7 | 2087 | ウイルス | plague_curse | spell_2 | [x] | 衰弱 |
| 8 | 2021 | グリップ | forced_stop | spell_1 | [x] | 停滞 |
| 9 | 2006 | スタシス | creature_curse | spell_1 | [x] | 枷（move_disable） |
| 10 | 2045 | エアリアル | creature_curse | spell_1 | [x] | 天駆（fly） |
| 11 | 2105 | フォートレス | creature_curse | spell_2 | [x] | 結界（spell_protection） |
| 12 | 9013 | 枷刻印付与 | creature_curse | spell_mystic | [x] | move_disable |
| 13 | 9014 | 天駆刻印付与 | creature_curse | spell_mystic | [x] | fly |
| 14 | 9022 | 結界刻印付与 | creature_curse | spell_mystic | [x] | spell_protection |
| 15 | 9028 | 衰弱刻印付与 | creature_curse | spell_mystic | [x] | creature_curse(plague) |
| 16 | 2035 | ウィザー | grant_mystic_arts | spell_1 | [x] | spell_id方式+配列方式 |
| 17 | 2062 | サイフォン | grant_mystic_arts | spell_1 | [x] | 同上 |
| 18 | 2089 | スプリント | grant_mystic_arts | spell_2 | [x] | 同上 |
| 19 | 2120 | フラックス | random_stat_curse | spell_2 | [x] | params(min,max)検証 |
| 20 | 2060 | ブースト | command_growth_curse | spell_1 | [x] | 付与+trigger_command_growth効果検証 |
| 21 | 2069 | マーク | bounty_curse | spell_2 | [x] | params(reward,caster_id等)検証 |
| 22 | 2083 | トラップ | land_curse | spell_2 | [x] | 付与+発動(EP減少/one_shot/自分不発/永続) |
| 23 | 2055 | イナート | land_effect_disable | spell_1 | [x] | 付与+has_チェック（効果は戦闘依存） |
| 24 | 9018 | 暗転刻印付与 | land_effect_disable | spell_mystic | [x] | 同上 |
| 25 | 9019 | 恩寵刻印付与 | land_effect_grant | spell_mystic | [x] | 付与+has_チェック+grant_elements検証 |
| 26 | 2114 | スチール | metal_form | spell_2 | [x] | 付与+has_チェック（効果は戦闘依存） |
| 27 | 2015 | ウォード | magic_barrier | spell_1 | [x] | 付与+has_チェック+ep_transfer検証 |
| 28 | 2032 | リクイエム | destroy_after_battle | spell_1 | [x] | 付与+has_チェック（効果は戦闘依存） |
| 29 | 2108 | グラナイト | apply_curse | spell_2 | [x] | 汎用刻印curse_type検証 |

### 5-B. SpellCostModifier経路

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 30 | 2117 | エンジェルギフト | life_force_curse | spell_2 | [x] | 付与+スペル無効化+刻印解除+コスト0化+スペルコスト不変 |

---

## 6. プレイヤー刻印系（player_curse_effect_strategy） - 5スペル

テストファイル: `test/spell/test_spell_player_curse.gd`
担当システム: `SpellCurse` (player_curse)

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2027 | ミュート | player_curse | spell_1 | [x] | spell_disable: 禁呪→スペル使用不可検証 |
| 2 | 2070 | トゥルース | player_curse | spell_2 | [x] | invasion_disable: 休戦刻印付与検証 |
| 3 | 2071 | ブレス | player_curse | spell_2 | [x] | spell_protection: 祝福→対象外検証 |
| 4 | 2125 | フリー | player_curse | spell_2 | [x] | restriction_release: 制限解除検証 |
| 5 | 9023 | 祝福刻印付与 | player_curse | spell_mystic | [x] | spell_protection確認 |

**テスト済み（15テスト全通過）**: JSON定義5スペル + spell_disable効果検証(ブロック/否定2件) + spell_protection効果検証(対象外/否定) + invasion_disable付与 + restriction_release(params検証) + 刻印上書き + 刻印除去|

---

## 7. 世界刻印系（world_curse_effect_strategy） - 9スペル

テストファイル: `test/spell/test_spell_world_curse.gd`
担当システム: `SpellWorldCurse`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2009 | ライズオブサン | world_curse | spell_1 | [x] | cost_increase: R=2倍,S=1.5倍,N/C=1倍 |
| 2 | 2036 | ボンドオブラバーズ | world_curse | spell_1 | [x] | element_chain: fire-earth,water-wind連鎖 |
| 3 | 2047 | インペリアルガード | world_curse | spell_1 | [x] | land_protect: 属性変化ブロック |
| 4 | 2048 | ハイプリーステス | world_curse | spell_1 | [x] | cursed_protection: 刻印クリーチャー結界 |
| 5 | 2064 | ハングドマンズシール | world_curse | spell_1 | [x] | skill_disable: 3トリガー無効 |
| 6 | 2081 | フールズフリーダム | world_curse | spell_2 | [x] | summon_cost_free: 召喚条件無視 |
| 7 | 2102 | テンパランスロウ | world_curse | spell_2 | [x] | invasion_restrict: 上位→下位侵略制限 |
| 8 | 2110 | エンプレスドメイン | world_curse | spell_2 | [x] | world_spell_protection: 全員スペル免疫 |
| 9 | 2111 | ハーミットズパラドックス | world_curse | spell_2 | [x] | same_creature_destroy: 同名相殺 |

**テスト済み（71テスト全通過）**: 全9種のJSON定義確認 + static判定メソッド正常系 + 全種に否定テスト（刻印なし/別刻印） + 刻印上書き排他テスト + 統合テスト（インペリアルガード×SpellLand土地変更ブロック、ハイプリーステス×SpellProtectionクリーチャー結界、エンプレスドメイン×SpellProtectionプレイヤー結界、ハングドマンズシール×トリガー無効化、ライズオブサン×コスト計算、ボンドオブラバーズ×連鎖判定）|

---

## 8. 通行料刻印系（toll_curse_effect_strategy） - 7スペル

テストファイル: `test/spell/test_spell_toll.gd`
担当システム: `SpellCurseToll`

### テスト済み（16テスト）
- 付与+計算: peace/toll_multiplier(1.5x,2x)/toll_half/creature_toll_disable/toll_disable/toll_fixed/toll_share
- ユーティリティ: has_peace_curse/is_invasion_disabled/apply_tile_curse_to_toll(3パターン)
- 優先度: peaceがセプター刻印より優先/toll_disableがtoll_fixedより優先

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2024 | プライス | toll_multiplier | spell_1 | [x] | 1.5倍/2倍テスト済 |
| 2 | 2061 | コマース | toll_share | spell_1 | [x] | 副収入50%+受取者検証 |
| 3 | 2072 | アコード | peace | spell_2 | [x] | 通行料0+侵略不可+優先度 |
| 4 | 2084 | パードン | toll_disable | spell_2 | [x] | 支払い免除+優先度 |
| 5 | 2115 | フラット | toll_fixed | spell_2 | [x] | 固定値200 |
| 6 | 9001 | 減税刻印付与 | curse_toll_half | spell_mystic | [x] | 半減(multiplier=0.5) |
| 7 | 9027 | 安寧刻印付与 | peace | spell_mystic | [x] | 同上 |

---

## 9. ステータスブースト系（stat_boost_effect_strategy） - 2スペル

テストファイル: 未作成
担当システム: `SpellCurseStat`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2066 | エンハンス | stat_boost | spell_2 | [x] | JSON定義+draw併有確認+刻印付与検証 |
| 2 | 9030 | 暁光刻印付与 | stat_boost | spell_mystic | [x] | JSON定義+刻印付与検証 |

**テスト済み（8テスト全通過）**: JSON定義2スペル + draw併有確認 + apply_stat_boost基本付与 + apply_curse_from_effect経由 + デフォルト値 + カスタム値 + 既存刻印上書き

---

## 10. EP/Magic操作系（magic_effect_strategy） - 15スペル

テストファイル: `test/spell/test_spell_magic.gd`（共通）, `test/spell/test_spell_magic_effects.gd`（個別効果）
担当システム: `SpellMagic`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2063 | リーチ | drain_magic | spell_1 | [x] | drain_magicテスト済み |
| 2 | 9012 | 吸魔 | drain_magic | spell_mystic | [x] | 同上 |
| 3 | 9015 | 黄金献身 | gain_magic | spell_mystic | [x] | gain_magicテスト済み |
| 4 | 2082 | ドレイン | drain_magic_conditional | spell_2 | [x] | 条件成立/不成立テスト |
| 5 | 2044 | オーバーテイク | drain_magic_by_lap_diff | spell_1 | [x] | JSON定義確認 |
| 6 | 2119 | ハーベスト | drain_magic_by_land_count | spell_2 | [x] | 土地数×吸魔+0土地テスト |
| 7 | 9036 | 魔女の奪取 | drain_magic_by_spell_count | spell_mystic | [x] | スペル数×吸魔+キャップ |
| 8 | 2020 | ラッキー | gain_magic_by_rank | spell_1 | [x] | 1位/3位テスト |
| 9 | 2109 | サイクル | gain_magic_by_lap | spell_2 | [x] | JSON定義確認 |
| 10 | 2007 | キルボーナス | gain_magic_from_destroyed_count | spell_1 | [x] | JSON定義確認 |
| 11 | 9035 | デスリワード | gain_magic_from_destroyed_count | spell_mystic | [x] | JSON定義確認 |
| 12 | 2025 | インサイト | gain_magic_from_spell_cost | spell_1 | [x] | JSON定義確認 |
| 13 | 2131 | コネクト | gain_magic_from_land_chain | spell_2 | [x] | 連鎖達成/未達成テスト |
| 14 | 2130 | バランス | balance_all_magic | spell_2 | [x] | 2人/3人平均化+端数テスト |
| 15 | 9034 | 生命変換 | mhp_to_magic | spell_mystic | [x] | MHP変換+ペナルティ検証 |

**個別効果テスト（36テスト全通過）**: 基本EP操作(add/reduce/steal/cap) + 固定値/割合吸魔 + 条件付き吸魔(成立/不成立) + ランク別EP(1位/3位) + 全員EP平均化(2人/3人端数) + 土地数吸魔(3土地/0土地) + 連続ドミニオ(達成/未達成) + スペル数吸魔(3枚/0枚/上限) + MHP変換(基本/base_up/空タイル) + JSON定義12スペル確認

---

## 11. 手札操作系（hand_manipulation_effect_strategy） - 17スペル

テストファイル: `test/spell/test_spell_hand_manipulation.gd`
担当システム: `CardSystem` / `SpellDraw`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2004 | ハーモニー | check_hand_elements | spell_1 | [x] | JSON定義+属性確認テスト |
| 2 | 2077 | ウィズダム | check_hand_synthesis | spell_2 | [x] | JSON定義確認 |
| 3 | 2017 | クリーン | destroy_duplicate_cards | spell_1 | [x] | JSON定義+重複破壊(あり/なし) |
| 4 | 2034 | スマッシュ | destroy_selected_card | spell_1 | [x] | JSON定義+index破壊(成功/無効) |
| 5 | 2038 | ディール | destroy_selected_card | spell_1 | [x] | JSON定義確認 |
| 6 | 2046 | スナッチ | steal_selected_card | spell_1 | [x] | JSON定義+奪取(成功/空手札) |
| 7 | 2042 | ピック | steal_item_conditional | spell_1 | [x] | JSON定義+アイテムカウント |
| 8 | 2093 | コンタミ | destroy_from_deck_selection | spell_2 | [x] | JSON定義確認 |
| 9 | 2127 | リボーン | discard_and_draw_plus | spell_2 | [x] | JSON定義確認 |
| 10 | 2128 | クリーンズ | destroy_curse_cards | spell_2 | [x] | JSON定義+呪いカード破壊 |
| 11 | 2129 | ラス | destroy_expensive_cards | spell_2 | [x] | JSON定義+高コスト破壊 |
| 12 | 2113 | トランス | transform_to_card | spell_2 | [x] | JSON定義確認 |
| 13 | 2122 | シャッフル | reset_deck | spell_2 | [x] | JSON定義+デッキリセット |
| 14 | 9038 | ブックバーン | destroy_deck_top | spell_mystic | [x] | JSON定義+デッキカード破壊 |
| 15 | 9045 | トリックスティール | destroy_and_draw | spell_mystic | [x] | JSON定義確認 |
| 16 | 9053 | ハイヴソルジャー召喚 | add_specific_card | spell_mystic | [x] | JSON定義+特定カード追加 |
| 17 | 9059 | チェンジリング | swap_creature | spell_mystic | [x] | JSON定義確認 |

**テスト済み（34テスト全通過）**: JSON定義17スペル + destroy_duplicate_cards(重複あり/なし) + destroy_card_at_index(成功/無効) + steal_card_at_index(成功/空) + destroy_curse_cards + destroy_expensive_cards + get_top_cards(3枚/超過) + destroy_deck_card + reset_deck + has_all_elements(あり/なし) + count_items(あり/なし) + add_specific_card

---

## 12. クリーチャー移動系（creature_move_effect_strategy） - 2スペル + 3アルカナアーツ

テストファイル: `test/spell/test_spell_creature_move.gd`
担当システム: `SpellCreatureMove`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2002 | インベイド | move_to_adjacent_enemy | spell_1 | [x] | JSON定義+移動先計算+移動実行 |
| 2 | 2052 | ラッシュ | move_steps | spell_1 | [x] | JSON定義+exact_steps計算+移動実行 |
| 3 | 10 | ワンダーフレア | move_self | fire_1 | [x] | JSON定義（アルカナアーツ） |
| 4 | 21 | ファントムクロー | destroy_and_move | fire_1 | [x] | JSON定義+破壊移動テスト |
| 5 | 322 | ゲイルスタリオン | move_steps | wind_1 | [x] | JSON定義（アルカナアーツ） |

**テスト済み（32テスト全通過）**: JSON定義5件 + _execute_move(基本/ダウン/刻印消滅/所有者移動/無効タイル) + _apply_destroy_and_move(基本/HP満タン/ダウンなし/空タイル/無効タイル) + 枷刻印チェック(4件) + get_adjacent_enemy_destinations(3件) + _get_tiles_within_steps(4件) + _get_tiles_at_exact_steps(3件) + ターゲット取得(3件)

---

## 13. サイコロ操作系（dice_effect_strategy） - 10スペル

テストファイル: `test/spell/test_spell_dice.gd`
担当システム: `SpellDice`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2098 | フェイト1 | dice_fixed | spell_2 | [x] | value=1確認+出目固定テスト |
| 2 | 2099 | フェイト3 | dice_fixed | spell_2 | [x] | value=3確認 |
| 3 | 2100 | フェイト6 | dice_fixed | spell_2 | [x] | value=6確認+出目固定テスト |
| 4 | 2101 | フェイト8 | dice_fixed | spell_2 | [x] | value=8確認+出目固定テスト |
| 5 | 9016 | 翼神刻印付与 | dice_fixed | spell_mystic | [x] | JSON定義確認 |
| 6 | 9017 | 快足刻印付与 | dice_fixed | spell_mystic | [x] | JSON定義確認 |
| 7 | 2091 | ダッシュ | dice_range | spell_2 | [x] | 範囲6-8テスト(10回試行) |
| 8 | 9029 | 泥沼刻印付与 | dice_range | spell_mystic | [x] | JSON定義確認 |
| 9 | 2080 | マルチ | dice_multi | spell_2 | [x] | 2/3ダイスロール判定テスト |
| 10 | 2051 | ジャーニー | dice_range_magic | spell_1 | [x] | 範囲+蓄魔100EP付与テスト |

**テスト済み（31テスト全通過）**: JSON定義10スペル + dice_fixed出目固定(1/6/8) + dice_range範囲検証(6-8/1-2各10回) + dice_multi判定(needs_multi/third/count) + dice_range_magic(範囲+蓄魔付与+should_grant) + ターゲット指定(none/player) + 刻印なし否定テスト

---

## 14. プレイヤー移動系（player_move_effect_strategy） - 6スペル

テストファイル: `test/spell/test_spell_player_move.gd`
担当システム: `SpellPlayerMove`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2014 | テレポ | warp_to_nearest_vacant | spell_1 | [x] | JSON定義+find_nearest_tile+距離計算 |
| 2 | 2079 | ポータル | warp_to_nearest_gate | spell_2 | [x] | JSON定義+find_nearest_tile |
| 3 | 2104 | ジャンプ | warp_to_target | spell_2 | [x] | JSON定義+warp_to_target(成功/距離超過/同タイル) |
| 4 | 2019 | インバート | curse_movement_reverse | spell_1 | [x] | JSON定義+全P反転刻印+方向判定 |
| 5 | 2123 | ルート | gate_pass | spell_2 | [x] | JSON定義+ゲート通過+周回完了 |
| 6 | 9021 | ナビゲート | grant_direction_choice | spell_mystic | [x] | JSON定義+方向選択権付与/消費 |

**テスト済み（36テスト全通過）**: JSON定義6件 + calculate_tile_distance(5件) + find_nearest_tile(3件) + get_tiles_in_range(2件) + warp_to_target(3件) + grant/consume_direction_choice(4件) + get_available_directions(3件) + get_final_direction(4件) + apply_movement_reverse_curse(2件) + trigger_gate_pass(2件) + get_selectable_gates(2件)

---

## 15. ステータス増減系（stat_change_effect_strategy） - 10スペル

テストファイル: `test/spell/test_spell_stat.gd`
担当システム: `SpellCurseStat` / `EffectManager`

### コアロジックテスト済み（14テスト）
- permanent_hp_change: 増加/減少/0クランプ/ダメージ後増加/ダメージ後減少/超過なし/既存base_up (7テスト)
- permanent_ap_change: 増加/減少/0クランプ/既存base_up (4テスト)
- conditional_ap_change: 低AP条件一致/高AP条件一致/条件不一致 (3テスト)

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2026 | フォーティファイ | permanent_hp_change | spell_1 | [x] | コアロジックテスト済 |
| 2 | 2075 | タンク | permanent_hp_change | spell_2 | [x] | コアロジックテスト済 |
| 3 | 2107 | ブルーム | permanent_hp_change | spell_2 | [x] | コアロジックテスト済 |
| 4 | 9010 | ライフフォージ | permanent_hp_change | spell_mystic | [x] | コアロジックテスト済 |
| 5 | 9011 | ライフドレイン | permanent_hp_change | spell_mystic | [x] | コアロジックテスト済 |
| 6 | 2075 | タンク | permanent_ap_change | spell_2 | [x] | コアロジックテスト済 |
| 7 | 9031 | オーバーレイジ | permanent_ap_change | spell_mystic | [x] | コアロジックテスト済 |
| 8 | 9032 | レイジ | permanent_ap_change | spell_mystic | [x] | コアロジックテスト済 |
| 9 | 9033 | イコライズ | conditional_ap_change | spell_mystic | [x] | コアロジックテスト済 |
| 10 | 2050 | ミリティア | secret_tiny_army | spell_1 | [ ] | ボード依存（条件判定+一括HP増+EP付与） |

---

## 16. 刻印除去系（purify_effect_strategy） - 4スペル

テストファイル: `test/spell/test_spell_purify.gd`
担当システム: `SpellPurify`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2073 | キュア | purify_all | spell_2 | [x] | 全刻印除去+蓄魔(種類×50EP)+刻印なし=0EP |
| 2 | 9024 | ディスペル | remove_creature_curse | spell_mystic | [x] | 刻印あり成功/刻印なし失敗 |
| 3 | 9025 | ワールドディスペル | remove_world_curse | spell_mystic | [x] | 除去成功/なし失敗+効果検証(インペリアルガード解除) |
| 4 | 9026 | 浄化の炎 | remove_all_player_curses | spell_mystic | [x] | 2人除去/0人+効果検証(禁呪解除→スペル使用可) |

**テスト済み（14テスト全通過）**: JSON定義4スペル + remove_creature_curse(成功/失敗) + remove_world_curse(成功/失敗/効果検証) + remove_all_player_curses(2人/0人/効果検証) + purify_all統合(全種刻印除去+蓄魔/刻印なし)

---

## 17. ダウン操作系（down_state_effect_strategy） - 4スペル

テストファイル: `test/spell/test_spell_down_state.gd`
担当システム: タイル状態管理

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2005 | ラリー | down_clear | spell_1 | [x] | JSON定義確認 |
| 2 | 2121 | リジェネ | clear_down | spell_2 | [x] | full_heal+clear_down両方確認 |
| 3 | 9037 | スリープ | set_down | spell_mystic | [x] | JSON定義確認 |
| 4 | 9044 | リバイブ | clear_down | spell_mystic | [x] | JSON定義確認 |

**テスト済み（10テスト全通過）**: JSON定義4スペル + set_down/clear_down/トグル/複数タイル一括解除/クリーチャー独立/ダウンなしclear無害

---

## 18. クリーチャー配置系（creature_place_effect_strategy） - 5スペル

テストファイル: `test/spell/test_spell_creature_place.gd`
担当システム: `SpellCreaturePlace` / `BoardSystem3D`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2028 | サモン | place_creature | spell_1 | [x] | JSON定義+配置検証 |
| 2 | 2043 | ネクロ | place_creature | spell_1 | [x] | JSON定義+ランダム配置 |
| 3 | 9054 | ケルベロス召喚 | place_creature | spell_mystic | [x] | JSON定義+select配置 |
| 4 | 9055 | ダートリング召喚 | place_creature | spell_mystic | [x] | JSON定義+select+down |
| 5 | 9056 | ストーンゴーレム召喚 | place_creature | spell_mystic | [x] | JSON定義+adjacent |

---

## 19. クリーチャー交換系（creature_swap_effect_strategy） - 2スペル

テストファイル: `test/spell/test_spell_creature_swap.gd`
担当システム: `SpellCreatureSwap` / `BoardSystem3D` / `CardSystem`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2013 | トレード | swap_with_hand | spell_1 | [x] | JSON定義+手札交換実行 |
| 2 | 2126 | ローテート | swap_board_creatures | spell_2 | [x] | JSON定義+盤面交換実行 |

---

## 20. スペル借用系（spell_borrow_effect_strategy） - 2スペル

テストファイル: 未作成
担当システム: 特殊

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2059 | コマンド | use_target_mystic_art | spell_1 | [ ] | カード犠牲 |
| 2 | 9058 | スペルスティール | use_hand_spell | spell_mystic | [ ] | |

---

## 21. クリーチャー変身系（transform_effect_strategy） - 11スペル

テストファイル: `test/spell/test_spell_transform.gd`
担当システム: `SpellTransform` / `BoardSystem3D`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2049 | ガード | transform | spell_1 | [x] | same_element_defensive全5属性 |
| 2 | 2056 | モーフ | discord_transform | spell_1 | [x] | discord_transform効果検証 |
| 3 | 9020 | バーニングウォーデン変身 | transform | spell_mystic | [x] | JSON定義+固定ID変身 |
| 4 | 9046 | ファラオズギフト変身 | transform | spell_mystic | [x] | JSON定義確認 |
| 5 | 9047 | タイダルウォーデン変身 | transform | spell_mystic | [x] | JSON定義確認 |
| 6 | 9048 | ミストシフター変身 | transform | spell_mystic | [x] | JSON定義確認 |
| 7 | 9049 | トランスフェザー変身 | transform | spell_mystic | [x] | JSON定義確認 |
| 8 | 9050 | ガルーダ変身 | transform | spell_mystic | [x] | JSON定義確認 |
| 9 | 9051 | ヴァルキリー変身 | transform | spell_mystic | [x] | JSON定義確認 |
| 10 | 9052 | リビングソイル変身 | transform | spell_mystic | [x] | JSON定義確認 |
| 11 | 9057 | 変身 | transform | spell_mystic | [x] | copy_target効果検証 |

---

## 22. クリーチャー手札戻し系（creature_return_effect_strategy） - 3スペル

テストファイル: `test/spell/test_spell_creature_return.gd`
担当システム: `SpellCreatureReturn` / `BoardSystem3D` / `CardSystem`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 2012 | パージ | return_to_hand | spell_1 | [x] | JSON定義+exile条件判定 |
| 2 | 2076 | エクストラクト | return_to_hand | spell_2 | [x] | JSON定義+最低MHP選択 |
| 3 | 2097 | ネゲート | return_to_hand | spell_2 | [x] | JSON定義+属性不一致判定 |

---

## 23. 自滅効果系（self_destroy_effect_strategy） - 2スペル

テストファイル: `test/spell/test_spell_self_destroy.gd`
担当システム: `SpellMagic` / `BoardSystem3D`

| # | ID | スペル名 | effect_type | source | テスト済み | 備考 |
|---|-----|---------|------------|--------|-----------|------|
| 1 | 9015 | 黄金献身 | self_destroy | spell_mystic | [x] | JSON定義+自滅効果検証 |
| 2 | 9054 | ケルベロス召喚 | self_destroy | spell_mystic | [x] | JSON定義+自滅+配置検証 |

---

## バトル刻印効果テスト（battle_curse_effects）

テストファイル: `test/battle/curse/test_battle_curse_effects.gd`
担当: BattleTestExecutor + pre_curse で刻印付与→実バトル実行→効果検証

**方針**: 付与テスト（test_spell_curse.gd）とは別に、刻印がバトル中に正しく効果を発揮するかを検証する。

### テスト済み

| # | curse_type | 刻印名 | 検証内容 | テスト済み |
|---|-----------|--------|---------|-----------|
| 1 | skill_nullify | 錯乱 | 先制スキルが発動しない | [x] |
| 2 | battle_disable | 消沈 | 攻撃不可、ダメージ0 | [x] |
| 3 | ap_nullify | AP=0 | AP=0、ダメージ0 | [x] |
| 4 | stat_reduce | 零落 | AP/HP-10、ダメージ減少 | [x] |
| 5 | metal_form | メタルフォーム | 通常攻撃無効 | [x] |
| 6 | destroy_after_battle | 崩壊 | 戦闘後破壊、刻印除去 | [x] |

### テスト済み（追加分）

| # | curse_type | 刻印名 | 検証内容 | テスト済み |
|---|-----------|--------|---------|-----------|
| 7 | plague | 衰弱 | 戦闘終了時HP -= MHP/2 | [x] |
| 8 | magic_barrier | マジックバリア | 通常攻撃無効 | [x] |
| 9 | land_effect_disable | 暗転 | 地形ボーナス無効（+対照実験） | [x] |
| 10 | land_effect_grant | 恩寵 | 属性不一致で地形ボーナス取得（+対照実験） | [x] |
| 11 | random_stat | 狂星 | AP/HPランダム化（範囲チェック） | [x] |
| 12 | stat_boost | ステ上昇 | HP/AP増加で勝敗変化 | [x] |

---

## 進捗サマリー

| カテゴリ | スペル数 | テスト済み | 進捗率 |
|---------|---------|-----------|--------|
| 1. ダメージ系 | 16 | 16 | 100% |
| 2. 回復系 | 3 | 3 | 100% |
| 3. 土地変更系 | 18 | 18 | 100% |
| 4. ドロー系 | 15 | 15 | 100% |
| 5. クリーチャー刻印系 | 30 | 30 | 100% |
| 6. プレイヤー刻印系 | 5 | 5 | 100% |
| 7. 世界刻印系 | 9 | 9 | 100% |
| 8. 通行料刻印系 | 7 | 7 | 100% |
| 9. ステータスブースト系 | 2 | 2 | 100% |
| 10. EP/Magic操作系 | 15 | 15 | 100% |
| 11. 手札操作系 | 17 | 17 | 100% |
| 12. クリーチャー移動系 | 2 | 2 | 100% |
| 13. サイコロ操作系 | 10 | 10 | 100% |
| 14. プレイヤー移動系 | 6 | 6 | 100% |
| 15. ステータス増減系 | 10 | 9 | 90% |
| 16. 刻印除去系 | 4 | 4 | 100% |
| 17. ダウン操作系 | 4 | 4 | 100% |
| 18. クリーチャー配置系 | 5 | 5 | 100% |
| 19. クリーチャー交換系 | 2 | 2 | 100% |
| 20. スペル借用系 | 2 | 0 | 0% |
| 21. クリーチャー変身系 | 11 | 11 | 100% |
| 22. クリーチャー手札戻し系 | 3 | 3 | 100% |
| 23. 自滅効果系 | 2 | 2 | 100% |
| **合計** | **約198効果** | **195** | **98%** |

※1枚のスペルが複数カテゴリに属する場合があるため、合計はスペル枚数(191)より多い

---

## テスト優先度ガイド

### Priority 1（ゲームコアロジック）
- クリーチャー刻印系 - 完了（30/30）
- ステータス増減系（10） - 戦闘バランスに影響
- ダメージ系（16） - 個別スペルテスト

### Priority 2（ゲーム進行）
- 通行料刻印系（7） - EP経済に影響
- EP/Magic操作系（残り12） - EP経済に影響
- サイコロ操作系（10） - 移動に影響
- ダウン操作系（4） - 行動制限

### Priority 3（ゲーム補助）
- ドロー系（15） - カードUI連携が必要
- 手札操作系（17） - カードUI連携が必要
- プレイヤー移動系（6） - ボード連携が必要
- 刻印除去系（4）

### Priority 4（特殊系）
- クリーチャー配置系（5） - Node依存高い
- クリーチャー変身系（11） - Node依存高い
- クリーチャー交換系（2）
- クリーチャー手札戻し系（3）
- スペル借用系（2）
- 自滅効果系（2）
- 世界刻印系（9）
- プレイヤー刻印系（5）
- ステータスブースト系（2）
