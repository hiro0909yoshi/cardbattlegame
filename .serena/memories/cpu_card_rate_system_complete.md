# CPU AI カードレート評価システム - 実装完了サマリ

## 概要
カードの価値を統一的に評価する「レート」システムを実装し、CPUの様々な判断に組み込んだ。

## レート評価システム (card_rate_evaluator.gd)

### レート計算式
- **クリーチャー**: (ST + HP) / 2 + スキル補正 + 特殊効果補正 - 制限ペナルティ - (コスト / 5)
- **スペル**: 効果補正40（統一値）、JSON個別設定で上書き可能
- **アイテム**: 基礎値30、JSON個別設定で上書き可能

### スキル補正 (SKILL_RATE_BONUS)
- 先制/強打/不屈/復活: +50
- 無効化: +50（巻物攻撃無効化は+20）
- アルカナアーツ: +40
- 攻撃成功時: +35
- 増殖: +30
- アイテム使用時ボーナス: +25
- 敵アイテム反応: +20
- その他多数...

### 制限ペナルティ
- 防具使用不可: -15
- アクセサリ使用不可: -10

### JSON固定レート設定済みカード
- アイテム: グレムリンアイ(110), ティアリングハロー(75), バタリングラム(70), バックラー(70)
- スペル: シャイニングガイザー(110)
- クリーチャー: シルフ(75), シーボンズ(100), スキュラ(90), ガルーダ(88)等

---

## レートを組み込んだ機能

### 1. 手札破棄判断 (cpu_hand_utils.gd)
- 3枚目以降の重複カード: -100ペナルティ
- レート最低のカードを破棄

### 2. クリーチャー配置判断 (cpu_hand_utils.gd)
- 属性一致 → レート最高を選択
- アルカナアーツ持ち → レート最高を選択
- それ以外 → レート最低を選択

### 3. スペル・アルカナアーツのクリーチャー対象選択
**ファイル**: cpu_spell_target_selector.gd, cpu_mystic_arts_ai.gd

**スコア計算**:
```
スコア = 土地レベル × 30 + クリーチャーレート + ボーナス
```
- 倒せるボーナス: +200（最優先）
- 敵クリーチャー: +1

### 4. 手札破壊/奪取系スペル (card_selection_handler.gd)
- **敵に使う場合**: レート最高を破壊/奪取
- **自分に使う場合（スクイーズ）**: レート最低を破壊

対象スペル: シャッター, スクイーズ, ポイズンマインド, セフト, スニークハンド, メタモルフォシス

### 5. ドミニオオーダー交換判断 (cpu_territory_ai.gd)
- コスト差 → レート差に変更
- 最低スコア閾値: 25
- **アルカナアーツ持ちは交換対象外**

### 6. エクスチェンジ (spell_creature_swap.gd, cpu_spell_target_selector.gd)
- 盤面のアルカナアーツ持ちは交換対象外
- レート + 属性一致ボーナス(+200)で手札クリーチャー選択
- 使用条件: `has_spare_hand_card`（手札2枚以上）

### 7. バトルリスク評価 (cpu_battle_ai.gd)
- クリーチャーを失うリスク: レート × 0.5 のペナルティ

### 8. 援護（アシスト）選択 (cpu_defense_ai.gd)
- 低レート優先（価値の低いカードを援護に使う）

### 9. ターンウォール対象選択 (cpu_target_resolver.gd)
- アルカナアーツ持ちまたはレート50以上を対象

---

## アルカナアーツ持ち保護ルール
以下の場面でアルカナアーツ持ちクリーチャーを保護:
1. ドミニオオーダー交換 - 交換対象外
2. エクスチェンジ - 盤面のアルカナアーツ持ちは交換対象外
3. 配置時 - 属性不一致でもアルカナアーツ持ちを優先配置

アルカナアーツ判定関数 `_has_mystic_arts()` は以下をチェック:
- トップレベル `mystic_arts` フィールド
- `ability_parsed.mystic_arts` 配列
- `ability_parsed.keywords` に「アルカナアーツ」

---

## 次回タスク: 呪い効果の有利/不利判別と上書き

### 目的
CPUが呪いの効果を判断し、場合によっては上書きする思考を持たせる。

### 検討事項
1. **呪いの有利/不利判定**
   - 自クリーチャーへの有利な呪い（能力値+20, 不屈等）
   - 敵クリーチャーへの不利な呪い（能力値-20, 戦闘行動不可等）
   
2. **上書き判断**
   - 既存の呪いより有利な呪いで上書き
   - 敵の有利な呪いを不利な呪いで上書き
   
3. **関連ファイル**
   - scripts/cpu_ai/cpu_spell_ai.gd
   - scripts/cpu_ai/cpu_spell_condition_checker.gd
   - scripts/spells/spell_curse_*.gd
   - data/spell_*.json (呪い系スペルのcpu_rule)

### 呪い系スペル（参考）
- 有利系: エナジーフィールド, グリード, バイタリティ, ハイパーアクティブ, マジックシェルター, メタルフォーム等
- 不利系: シニリティ, ディジーズ, ディスエレメント, バインドミスト, ボーテックス等

---

## 関連ファイル一覧

### コア
- scripts/cpu_ai/card_rate_evaluator.gd - レート計算

### CPU判断
- scripts/cpu_ai/cpu_hand_utils.gd - 手札管理
- scripts/cpu_ai/cpu_spell_ai.gd - スペル使用判断
- scripts/cpu_ai/cpu_spell_target_selector.gd - スペル対象選択
- scripts/cpu_ai/cpu_spell_condition_checker.gd - スペル条件判定
- scripts/cpu_ai/cpu_mystic_arts_ai.gd - アルカナアーツ使用判断
- scripts/cpu_ai/cpu_territory_ai.gd - ドミニオオーダー判断
- scripts/cpu_ai/cpu_battle_ai.gd - バトル判断
- scripts/cpu_ai/cpu_defense_ai.gd - 防御判断
- scripts/cpu_ai/cpu_target_resolver.gd - ターゲット解決

### スペル処理
- scripts/spells/card_selection_handler.gd - カード選択
- scripts/spells/spell_creature_swap.gd - クリーチャー交換

### データ
- data/item.json, data/spell_*.json, data/water_*.json, data/earth_*.json, data/wind_*.json
- docs/design/spells_tasks.md - スペル実装タスク一覧
