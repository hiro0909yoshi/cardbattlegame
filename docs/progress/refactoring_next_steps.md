# チーム/同盟システム実装完了 + バグ修正

**最終更新**: 2026-02-21
**ステータス**: Step 0-7 実装完了、プレイテストバグ修正完了、Phase 11 (UI) は後日対応

---

## 完了した作業

### チーム/同盟システム（Team System）

**設計ドキュメント**: `docs/design/team_system_design.md`（v2.1、1021行）

| Step | 内容 | ファイル数 | ステータス |
|------|------|-----------|-----------|
| 0 | 設計ドキュメント作成 | 1 | ✅ |
| 1 | TeamData + TeamSystem + PlayerSystem委譲 | 6 | ✅ |
| 2 | ステージJSON読み込み + 通行料免除 + バトル免除 | 4 | ✅ |
| 3 | 連鎖ボーナスのチーム合算 | 2 | ✅ |
| 4 | 勝利条件のチーム合算TEP化 | 2 | ✅ |
| 5 | ターゲット選択のチーム対応 | 3 | ✅ |
| 6 | ドミニオ + 移動の同盟対応 | 3 | ✅ |
| 7 | 破産処理 + GSM初期化フロー | 2 | ✅ |
| 8 | CPU AI チーム認識（初回：6ファイル18箇所） | 6 | ✅ |
| 9 | ミスティックアーツ AI（7箇所） | 1 | ✅ |
| 10 | バトルスキル Support の同盟対応 | 1 | ✅ |
| 11 | UI チームカラー表示 | - | 🔄 後日 |

### プレイテストバグ修正（2026-02-21）

| コミット | 内容 | ファイル |
|---------|------|---------|
| 19c777c | TEP表示をチーム合算TEPに修正 | player_info_panel, player_status_dialog |
| 75caf15 | CPUスペルターゲット同盟除外 + 連鎖表示更新 + float→int | cpu_spell_ai, board_system_3d, team_system, cpu_spell_target_selector, stage_2_7.json |
| 4661a99 | cpu_spell_utilsの敵判定3箇所をis_same_team()に | cpu_spell_utils |
| 247e156 | ホーリーワード系の敵踏ませ評価で同盟除外 | cpu_spell_ai |
| a70b9de | 土地ターゲット検索のhas_creatureフィルタ追加 | target_finder |
| 1832fce | cpu_curse_evaluatorをplayer_system渡し方式に統一 | cpu_curse_evaluator, cpu_target_resolver |
| 79b3705 | CPU AI思考ロジック全体の敵判定をis_same_team()に統一 | cpu_target_resolver(10メソッド), cpu_movement_evaluator(3箇所), cpu_holy_word_evaluator(4箇所) |

**CPU AI修正の詳細（Step 8 拡張 — 40+箇所）**:

| ファイル | 修正箇所 | 内容 |
|---------|---------|------|
| cpu_spell_ai.gd | 5 | ドレインマジック、ホーリーワード、ドミニオ評価 |
| cpu_spell_target_selector.gd | 1 | 敵プレイヤー候補リスト |
| cpu_spell_utils.gd | 3 | 敵EP取得、周回差計算、敵プレイヤー取得 |
| cpu_target_resolver.gd | 12 | 敵対象選定10メソッド + 刻印判定2箇所 |
| cpu_movement_evaluator.gd | 3 | 足止め判定、通行料計算 |
| cpu_holy_word_evaluator.gd | 4 | ダイス修正評価（攻撃的・防御的） |
| cpu_curse_evaluator.gd | 5関数 | 善良/悪性判定 → _is_ally()ヘルパー + player_system渡し |
| cpu_board_analyzer.gd | 8 | 既に対応済み（確認のみ） |
| cpu_territory_ai.gd | 1 | 敵ドミニオ判定 |
| cpu_mystic_arts_ai.gd | 2 | 敵味方判定（一部対応済み） |

### 修正不要と判断した箇所

| ファイル:行 | 理由 |
|------------|------|
| cpu_mystic_arts_ai.gd:126 | 自クリーチャーの能力発動（所有者のみ操作可能） |
| cpu_spell_condition_checker.gd:415 | 自クリーチャーの属性チェック（所有者のみ） |
| cpu_territory_ai.gd:613 | 自分が管理する土地（レベルアップ・移動対象） |
| cpu_spell_utils.gd:181 | 順位計算（全員との比較が正しい） |

### 核心設計

- **TeamSystem (Node)**: `_player_team_map` が唯一の Source of Truth
- **PlayerSystem 委譲**: `is_same_team(a, b)` で全コードがチーム判定
- **FFA互換**: teams 未指定時は `player_id_a == player_id_b` を返す
- **CPU AI統一パターン**: `player_system.is_same_team(player_id, other_id)` で敵味方判定
- **CpuCurseEvaluator**: `_is_ally(cpu_id, other_id, player_system)` ヘルパーで統一

---

## 次の作業候補

### Phase 11: UI チームカラー表示（後日）
- PlayerInfoPanel にチームカラーインジケータ
- チーム合算TEP表示の視覚的強調

### 追加プレイテスト項目
- [ ] 全スペル種別の同盟除外テスト（特に刻印系）
- [ ] CPU同士が同盟の場合の挙動
- [ ] 3チーム以上の構成テスト
- [ ] teams未指定ステージの退行テスト
