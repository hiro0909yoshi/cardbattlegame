# 秘術追加タスク（spell_mystic.json）

spell_idが設定されていない秘術をspell_mystic.jsonに追加する作業。

---

## 現状

- **spell_mystic.json**: 41件（9001〜9041）
- **追加対象**: 19件

---

## 追加対象一覧

### 1. やりやすい（単純なeffect_type）✅ 完了

| 新ID | クリーチャー | 秘術名 | effect_type | cpu_rule |
|------|-------------|--------|-------------|----------|
| 9042 | フェイト | カードドロー | draw_cards | immediate |
| 9043 | アイアンモンガー | アイテムドロー | draw_by_type | immediate |
| 9044 | キャプテンコック | ダウン解除 | clear_down | has_target (own_downed_creature) |
| 9045 | クラウドギズモ | 手札破壊ドロー | destroy_and_draw | immediate |

**ステータス**: ✅ 完了（2026/01/03）

---

### 2. 変身系（transform）✅ 完了

| ID | クリーチャー | 秘術名 | 変身先ID | 変身先名 | cpu_rule |
|----|-------------|--------|----------|----------|----------|
| 9020 | スプラウトリング | オールドウィロウに変身 | 5 | オールドウィロウ | immediate |
| 9046 | デスサイズ | マミーに変身 | 239 | マミー | immediate |
| 9047 | ヒッポカンパス | ケルピーに変身 | 121 | ケルピー | immediate |
| 9048 | ミストウィング | アクアホーンに変身 | 104 | アクアホーン | immediate |
| 9049 | アクアホーン | ミストウィングに変身 | 142 | ミストウィング | immediate |
| 9050 | シルフ | ガルーダに変身 | 307 | ガルーダ | immediate |
| 9051 | ソードプリンセス | アームドプリンセスに変身 | 300 | アームドプリンセス | immediate |
| 9052 | ブランチアーミー | マッドマンに変身 | 238 | マッドマン | immediate |

**備考**: 9020は既存だがcreature_idが間違っていたので修正（231→5）、cpu_ruleもimmediateに変更

**ステータス**: ✅ 完了（2026/01/03）

---

### 3. 召喚系（place_creature / add_specific_card）✅ 完了

| ID | クリーチャー | 秘術名 | effect_type | 召喚先ID | cpu_rule |
|----|-------------|--------|-------------|----------|----------|
| 9053 | ハイプクイーン | ハイプワーカー生成 | add_specific_card | 32 | immediate |
| 9054 | コンジャラー | バーアル召喚 | place_creature | 27 | has_target (has_empty_land) |
| 9055 | グーバクイーン | グーバ配置 | place_creature | 208 | has_target (has_empty_land) |
| 9056 | レジェンドファロス | スタチュー配置 | place_creature | 421 | has_target (has_adjacent_empty_land) |

**ステータス**: ✅ 完了（2026/01/03）

---

### 4. 特殊 ✅ 完了

| ID | クリーチャー | 秘術名 | effect_type | cpu_rule |
|----|-------------|--------|-------------|----------|
| 9057 | シェイプシフター | 対象と同じクリーチャーに変身 | transform (copy_target) | skip |
| 9058 | ルーンアデプト | スペル借用 | use_hand_spell | skip |
| 9059 | レムレース | クリーチャー交換 | swap_creature | skip |

**ステータス**: ✅ 完了（2026/01/03）- cpu_ruleはskip

---

## 作業手順

### Phase 1: やりやすい4件
1. spell_mystic.jsonに9042〜9045を追加
2. クリーチャーJSONのspell_idを更新
3. 動作確認

### Phase 2: 変身系7件
1. spell_mystic.jsonに9046〜9052を追加
2. クリーチャーJSONのspell_idを更新
3. スプラウトリングは既存9020にspell_id設定のみ
4. 動作確認

### Phase 3: 召喚系4件
1. spell_mystic.jsonに9053〜9056を追加
2. クリーチャーJSONのspell_idを更新
3. 動作確認

### Phase 4: 特殊3件（必要に応じて）
1. 処理実装が必要なため後回し
2. 現状はskip扱い

---

## クリーチャーJSON更新箇所

| ファイル | クリーチャーID | クリーチャー名 | 追加するspell_id |
|----------|---------------|----------------|------------------|
| data/water_2.json | 136 | フェイト | 9042 |
| data/neutral_1.json | 405 | アイアンモンガー | 9043 |
| data/earth_1.json | 207 | キャプテンコック | 9044 |
| data/wind_1.json | 310 | クラウドギズモ | 9045 |
| data/fire_1.json | 20 | デスサイズ | 9046 |
| data/water_2.json | 135 | ヒッポカンパス | 9047 |
| data/water_2.json | 142 | ミストウィング | 9048 |
| data/water_1.json | 104 | アクアホーン | 9049 |
| data/wind_1.json | 319 | シルフ | 9050 |
| data/wind_1.json | 324 | ソードプリンセス | 9051 |
| data/earth_2.json | 236 | ブランチアーミー | 9052 |
| data/earth_1.json | 224 | スプラウトリング | 9020（既存） |
| data/fire_2.json | 31 | ハイプクイーン | 9053 |
| data/fire_1.json | 12 | コンジャラー | 9054 |
| data/earth_1.json | 209 | グーバクイーン | 9055 |
| data/neutral_2.json | 444 | レジェンドファロス | 9056 |
| data/neutral_1.json | 417 | シェイプシフター | 9057 |
| data/water_2.json | 147 | ルーンアデプト | 9058 |
| data/wind_2.json | 346 | レムレース | 9059 |

---

## 更新履歴

| 日付 | 内容 |
|------|------|
| 2026/01/03 | 初版作成 |
| 2026/01/03 | Phase 1完了（9042〜9045追加） |
| 2026/01/03 | Phase 2完了（9046〜9052追加、9020修正） |
| 2026/01/03 | Phase 3完了（9053〜9056追加） |
| 2026/01/03 | Phase 4完了（9057〜9059追加、skip扱い） |
| 2026/01/03 | **全Phase完了** |
