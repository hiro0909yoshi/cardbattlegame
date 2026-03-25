# 📅 日次作業ログ

**目的**: チャット間の継続性を保つため、各日の作業内容を簡潔に記録

**ルール**:
- 各作業は1〜3行で簡潔に
- 完了したタスクに ✅
- 次のステップを必ず明記
- 詳細は該当ドキュメントにリンク
- **前日以前のログは削除し、直近の作業のみ記録**
- **⚠️ ログ更新時は必ず残りトークン数を報告すること**

---

## 2026年3月25日（Session: キャラクター3Dプレビュー）

### 完了した作業

#### キャラクター3Dプレビュー表示
- ✅ `character_preview.gd` 作成 — SubViewport + Camera3Dで3Dモデルを2D UIに静止画表示
- ✅ MainMenu / StatusScreen の TextureRect → SubViewportContainer に置換
- ✅ モバイル負荷対策: UPDATE_DISABLED + 数フレームだけ描画してキャプチャ
- ✅ メイン画面に仮グラデーション背景追加（透過確認済み）

---

## 2026年3月25日（Session: プレイヤーアカウント設計）

### 完了した作業

#### CPU AIポリシー統一
- ✅ `game_flow_manager.gd` に `_apply_default_cpu_policy()` 追加（切断時balancedポリシー自動適用）
- ✅ `network_design.md` に実装済み基盤の記載追加

#### プレイヤーアカウント設計（`docs/design/player_account_design.md`）
- ✅ プレイヤーデータ3層分類（Core/Sub/Local）
- ✅ アカウント認証設計（ゲスト→登録フロー、DB 7テーブル、API設計）
- ✅ 外部フィードバック5項目適用:
  - 楽観ロック（versionフィールド）
  - match_history肥大化対策（100件制限+ページング）
  - 一括同期方針（bulk save + 通貨操作のみ個別API）
  - JWTデュアルトークン（access 30分 + refresh 14日）
  - device_id利用ルール（識別専用、認証に使わない）
- ✅ セキュリティ詳細追加:
  - ログイン時トークン発行フロー（5ステップ）
  - APIリクエスト検証フロー
  - 不正状態ハンドリング（5ケース対応表 + クライアント401処理）
  - 1端末同時ログインポリシー
  - 将来拡張性（複数端末・セッション一覧・強制ログアウト）

#### キャラクター選択・カスタマイズ設計
- ✅ 解放方式3種（初期/クエストクリア/購入）
- ✅ マスターデータ拡張方針（characters.jsonにplayable_characters追加）
- ✅ GameData拡張（character.selected_id + character.unlocked）
- ✅ backend_design.mdの既存テーブル（user_unlocked_characters）と統合
- ✅ 全16体の3Dモデル一覧記録

### 次のステップ
- サーバー実装（Go リレーサーバー + 認証API）
- クライアント実装（AuthManager, DataSyncManager）
- GameData リファクタ（core/sub/local 分離）
- キャラクター選択UI実装

#### バグ修正: skill_conditions内のuser_rarity条件が付与時チェックされない
- ✅ 原因: `battle_item_applier._apply_grant_skill()` が `condition`（辞書）のみチェックし `skill_conditions`（配列）を無視
- ✅ 修正: `user_rarity` 条件を付与時にチェックするロジック追加（他の条件は発動時チェックのため除外）
- ✅ 全222テスト、1276アサート全パス

#### Phase 2後半: 残りアイテムテスト完了（195テスト、877アサート全パス）
- ✅ トールカーサー(124): on_battle_end刻印がサイレントローブで防げないことを検証
- ✅ コピースパイク(1036): 変質（forced_copy_attacker）肯定・否定・敵生存テスト
- ✅ グランドハンマー(1012): 蓄魔[200EP] 肯定・否定テスト
- ✅ デスペラード(1048): on_death即死 肯定・否定テスト
- ✅ バーニングコア(1044): on_death報復MHP-40 肯定・否定テスト
- ✅ フォートレスブレイカー(1051): 即死[堅守] vs 堅守/重結界刻印/非堅守テスト
- ✅ バグ修正: `battle_special_effects.gd` 即死[堅守]条件が刻印`defensive_form`を未チェック → 追加
- ✅ バトル効果検出リファクタ: `_snapshot_battle_state()`/`_diff_battle_state()`でEP/刻印/変質/APドレインを状態差分検出（本番コード汚染なし）
- ✅ `BattleTestResult`に`attacker_battle_effects`/`defender_battle_effects`追加

#### ディスペルオーブ(1004): 沈黙テスト網羅（23テスト追加）
- ✅ 全22スキル持ちクリーチャーの無効化テスト（先制/強化/共鳴/2回攻撃/再生/反射/反射[1/2]/相討/変身/アイテム破壊/アイテム盗み/吸魔/蓄魔/即死/刺突/術攻撃/加勢/強化術/強化/形見/蘇生）
- ✅ 攻撃側/防御側の適切な配置: 後手・鼓舞は攻撃側スキル持ち+防御側ディスペル
- ✅ 鼓舞テスト: ボード上のアークデーモンから戦闘クリーチャーへのボーナス阻止を検証
- ✅ 共鳴テスト: 地タイル追加で共鳴環境を整備した上で無効化を検証
- ✅ 沈黙相互作用: カースウィップ(1050)のstat_bonus(AP+30)は残り、刻印[消沈]は無効化されることを検証

#### Phase 3k: 刺突テスト（8テスト追加、323テスト全パス）
- ✅ 無条件刺突（ナイトメア334）: land_bonus無効化確認
- ✅ 条件付き刺突（レイドワイバーン36, 敵AP≧40）: 発動/不発/蓄魔[100EP]検出
- ✅ 防御側の刺突は無効: land_bonus維持の証拠
- ✅ 属性条件刺突（インフェルノイーグル38, 水風）: 発動（+強化+先制複合）/ 不発
- ✅ 蓄魔は侵略側のみ: レイドワイバーン防御側→蓄魔なし
- ✅ 鼓舞AP上昇と刺突条件: current_ap上昇でもベースAPで判定→不発を確認
- ✅ Executor修正: EPスナップショットをpre_battle_skills前に取得（蓄魔の差分検出対応）

#### Phase 3p: 個別クリーチャーテスト（16テスト追加、113テスト全パス）
- ✅ `test_creature_individual.gd` 新規作成（スキルテストから個別クリーチャーテストを分離）
- ✅ フレイムパラディン(1): AP変動[火地×10]基本/ゼロAP/無効化[巻物]/強化アイテム併用 (4件)
- ✅ ウリエル(4): 強化[刻印有]発動/不発/ガイアハンマー2重防止 (3件)
- ✅ ボムスライム(13): 死亡時HP-40（攻撃側/相討ち/生存不発/防御側/刻印弱体） (5件)
- ✅ マルコシアス(15): AP+MHP50以上配置数×5（混合配置テスト） (1件)
- ✅ ショックブリンガー(18): 攻撃成功時ダウン/奮闘でブロック/サイレントローブで無効化 (3件)
- ✅ ダウン状態テスト基盤: MockTileにset_down_state/is_down追加、BattleTestResultにdefender_tile_down追加
- ✅ battle_execution.gd: タイル参照をtile_data_manager経由に修正（テスト環境でも動作）
- ✅ skill_land_effects.gd: 型パラメータをNode→Variant化（MockTile互換性）
- ✅ board_system_3d.gd: get_player_tiles()をtile_data_manager経由に修正

---

## 2026年3月25日（Session: control_type基盤導入 + CPU切り替え機構）

### 完了した作業

#### player_control_types 基盤導入
- ✅ GFM: `player_is_cpu: Array[bool]` → `_player_control_types: Array[String]`（"local"/"cpu"、将来"remote"）
- ✅ 互換プロパティ: 外部11ファイルからの `player_is_cpu` 参照を維持（getter/setter変換）
- ✅ `get_control_type(player_id)` 追加: 制御タイプを文字列で取得
- ✅ `is_cpu_player()` を `get_control_type()` ベースに書き換え（既存互換維持）
- ✅ GFM内のインライン判定3箇所を `is_cpu_player()` に統一

#### CPU切り替え機構
- ✅ `convert_to_cpu(player_id)` / `convert_to_local(player_id)`: フラグ変更のみ、即実行しない
- ✅ 次のターン/フェーズ開始時に反映される安全設計

#### テスト導線
- ✅ `DebugSettings.test_cpu_takeover` トグル追加
  - true時: ソロバトル/クエストでP2をローカル操作で開始
- ✅ `game_3d.gd` / `quest_game.gd`: test_cpu_takeover時にplayer_is_cpu[1]=falseに上書き
- ✅ DebugController: `C`キーでP2のcontrol_typeをトグル（cpu↔local、次フェーズから反映）

#### CPU判定のGFM統一化
- ✅ `tile_action_processor.gd`: インライン判定 → `game_flow_manager.is_cpu_player()` に統一
- ✅ `board_system_3d.gd`: 同上（ドミニオボタン表示判定）
- ✅ `discard_handler.gd`: GFM参照追加 + `is_cpu_player()` 統一
- ✅ `_sync_board_cpu_flags()`: convert時にboard_system_3d/discard_handlerのコピーを同期
- ✅ `_control_type_overridden`: 明示的convert呼び出しはmanual_control_allより優先

#### 対戦モード通知自動進行
- ✅ `GlobalCommentUI.battle_auto_advance`: 対戦モードで全コメント3秒自動進行
- ✅ `SpellCastNotificationUI.battle_auto_advance`: スペル通知も同様に3秒自動進行
- ✅ ソロバトル開始時に両UIに `battle_auto_advance = true` を設定
- ✅ クエストモードは従来通り（クリック待ち + 7秒タイムアウト）
- ✅ `force_click_wait` は対戦モードでは無視される設計

#### バグ修正
- ✅ `test_spell_player_move.gd`: PlayerData.buffs → direction_choice_pending 直接アクセスに修正（4箇所）

#### CPU引き継ぎ時のデフォルトポリシー統一
- ✅ `convert_to_cpu()` 時に `_apply_default_cpu_policy()` で "balanced" ポリシーを自動適用
- ✅ プレイヤーキャラにはCPU設定がないため、統一デフォルトで対応
- ✅ ネット対戦は全員人間スタート→切断者1人のみCPU化→ポリシー1つで十分
- ✅ `docs/design/network_design.md` Phase 4 更新（実装済みマーク）

### 設計判断
- `player_is_remote` 配列は今回追加しない（ネットワーク入力待ちはサーバー実装時に作る）
- 時間制限タイマーもネット対戦実装時に追加（convert_to_cpuが受け口になる）
- 入力入口の1本化は将来のリファクタ対象
- CPU引き継ぎポリシーは統一（"balanced"）: プレイヤーキャラにはCPU AI設定がないため

### 📋 次のステップ
- ネット対戦: Goリレーサーバー雛形 or NetworkService抽象レイヤー

---

## 2026年3月24日（Session 2: GameLoggerログ拡充 + PlayerData手入れ + MatchSnapshotBuilder）

### 完了した作業

#### GameLoggerログ拡充（STEP 1完了）
- ✅ スペル使用時にスペル名・ID記録（選択確定はGameLog、選択開始はDebugLog）
- ✅ バトル開始/結果にクリーチャー名・ID・アイテム名を記録
- ✅ アイテム使用・合体をバトルログに記録
- ✅ アルカナアーツ使用を記録（spell_idで識別、id:-1問題修正）
- ✅ カードドロー名・IDを記録（STEP 2から前倒し）
- ✅ ドミニオコマンドにレベル情報追加
- ✅ ゲーム終了ログ追加（勝利/敗北+ラウンド数 — STEP 1最後の欠落）
- ✅ GameLog/DebugLog分離方針をlogger_system.mdに記載
- ✅ 構造化ログ・turn・action_idはSTEP 6（ネットワーク対戦時）で対応する方針を記載

#### PlayerData周辺の手入れ（設計書の既知問題3件修正）
- ✅ `destroyed_count` 削除: PlayerDataでは未使用、LapSystem.destroy_countが正
- ✅ `magic_power`/`target_magic` デフォルト値を0に変更（initialize_players()で上書きされるため）
- ✅ `buffs: Dictionary` → `direction_choice_pending: bool` に変更（10箇所書き換え）
  - PlayerData.buffsは"direction_choice_pending"フラグ専用だった
  - PlayerBuffSystem.player_buffsとは用途が完全に異なることを確認

#### MatchSnapshotBuilder 作成
- ✅ `scripts/system_manager/match_snapshot_builder.gd` 新規作成
  - `get_player_snapshot(player_id)`: PlayerSystem + LapSystem + BuffSystem + SpellState + CardSystem から集約
  - `get_match_snapshot()`: 全プレイヤー + ボード + ターン + 世界刻印 + 破壊カウント
  - 各システムからデータを「集めるだけ」。状態変更は一切行わない
- ✅ GameSystemManager に組み込み（Phase 6後に_setup_snapshot_builder()実行）
- ✅ player_data_design.md にAPI・データソースマッピング・将来用途を記載

### 📋 次のステップ

- エフェクト作成ブランチの本来タスクへ
- 残りスペルテスト3件（スペル借用系2、ミリティア1）

---

## 2026年3月24日（Session 1: ナビゲーター方向選択UI修正 + テスト警告全解消）

### 完了した作業

#### ナビゲーター方向選択UI修正
- ✅ `movement_controller.gd`: `_select_first_tile()` に `has_direction_choice` パラメータ追加
  - `direction_choice_pending` 時は `came_from` フィルタリングをスキップ → 両方向が選択肢に残る
  - これにより `MovementBranchSelector` が起動し、黄色マーカー + 到着予測マーカーが正常表示
- ✅ `spell_player_move.gd`: `direction_choice` → `direction_choice_pending` キー名修正（`get_available_directions`, `consume_direction_choice`）

#### 3チェーンアクセス違反修正（コーディング規約準拠）
- ✅ `MovementController3D` に `board_system: BoardSystem3D` 直接参照を追加
- ✅ `board_system_3d.gd`: `set_movement_controller_gfm()` で `board_system = self` を注入
- ✅ `movement_direction_selector.gd`: `controller.game_flow_manager.board_system_3d` → `controller.board_system`（全箇所）
- ✅ `movement_branch_selector.gd`: 同様に3チェーン → 2チェーンに修正（`gfm`/`gfm2` ローカル変数削除）

#### GUT自動テスト警告全解消（39警告 → 0警告）
- ✅ Float/Int比較警告修正（22箇所）: JSON値を `int()` でキャスト（GodotのJSONパーサーが数値をfloatで返すため）
- ✅ unfreed children警告修正（15ファイル）: `queue_free()` → `free()` に変更（即時解放で蓄積防止）
- ✅ `test_spell_player_move.gd`: `get_children()` ループ → 明示的な変数名指定の `free()` に変更（GUT内部の `_awaiter` ノード誤解放防止）
- ✅ `test_spell_purify.gd`: 欠落していた `after_each()` を追加
- ✅ 最終結果: **962テスト、0警告、全パス**

### 📋 次のステップ

- 残りスペルテスト3件（スペル借用系2、ミリティア1）→ 進捗 195/198 (98%)
- エフェクト作成ブランチの本来タスクへ

---

## 2026年3月22日（Session: クリーチャー自動テスト完了）

### 完了した作業

#### Phase 3p続行: 個別クリーチャーテスト追加
- ✅ ストームブリンガー(18): 攻撃成功時ダウン関連テスト追加
- ✅ ドラゴニュート: 変身系テスト
- ✅ オーガロード(407): オーガ数依存AP/HP強化 + 強化術自動発動の相互作用テスト (4件)
  - 強化術は巻物不要で自動発動（APバフ未検出時に発動）
  - temporary_bonus_hpはcurrent_hpとは別プール
- ✅ ゴブリンシャーマン(445): ゴブリン族ボード配置依存AP/HP強化テスト (2件)
- ✅ ライフリンク関連テスト

#### 合体(Merge)テスト基盤構築 + テスト2件
- ✅ `BattleTestConfig` に `attacker_merge_partner_id` / `defender_merge_partner_id` 追加
- ✅ `BattleTestExecutor` に `_apply_merge()` ヘルパー追加（手札操作・EP確保・SkillMerge呼出）
- ✅ グランギア(409)+スカイギア(419)→アンドロギア(406) 合体テスト
- ✅ アンドロギア(406)+ビーストギア(434)→ギアリオン(408) 合体テスト

#### skill_merge.gd バグ修正3件（テストで発見）
- ✅ `participant.tile_index` → 安全アクセスパターンに修正（BattleParticipantにtile_indexプロパティなし）
- ✅ `participant.base_ap` 代入削除（BattleParticipantにbase_apインスタンス変数なし）
- ✅ print文の `participant.base_ap` → `participant.current_ap` に修正

#### クリーチャー自動テスト完了
- ✅ **639テスト / 2201アサート 全パス**
- ✅ `docs/specs/gut_test_spec.md` に完了マーカー記載

### 📋 次のステップ

- Phase 4: スペルテスト
- エフェクト作成ブランチの本来タスクへ

---

## 2026年3月20日（Session: GUT自動テスト導入 - バトルアイテムテスト）

### 完了した作業（省略 - 詳細は git log 参照）
- ✅ GUT環境セットアップ、Phase 1-2 バトルアイテムテスト完了
- ✅ MockBoard設計、Phase 3k 刺突テスト、Phase 3p 個別クリーチャーテスト開始
- ✅ 323テスト全パス

### 📋 次のステップ

- Phase 3p続行 → 完了済み（3/22）

---

## 2026年3月19日（Session: GameLoggerシステム導入）

### 完了した作業

#### GameLogger Autoload 導入（STEP 1）
- ✅ `scripts/autoload/logger.gd` 作成（ファイル書き込み + コンソール出力、毎行flush）
- ✅ `project.godot` に GameLogger Autoload 登録（`Logger` は Godot 4.5 組み込みクラス名と衝突するため `GameLogger` に変更）
- ✅ 13ファイル31箇所にログ埋め込み
  - フェーズ遷移（SM）、ターン開始/終了（GFM）、ダイス結果（Dice）
  - 移動完了（Move）、スペルフェーズ開始/完了（Spell）、効果実行（Spell）
  - アーツ実行（Spell）、バトルUI開始/終了/異常（BattleUI）
  - 召喚成功/失敗（Summon）、ドミニオコマンド/移動侵略（Dominio）
  - 通行料（Toll）、チェックポイント/周回完了/勝利（Lap/Game）、破産（Game）
- ✅ 設計ドキュメント `docs/design/logger_system.md` 更新（GameLogger名前変更反映）
- ✅ 動作確認済み: ログファイル `user://logs/game_YYYYMMDD_HHMMSS.log` に正常出力

#### 移動詳細ログ追加（STEP 1.5）
- ✅ `movement_controller.gd` 2箇所: 強制停止ログ（理由付き）
- ✅ `special_tile_system.gd` 2箇所: 停止型ワープログ（発動/ペアなし）
- ✅ `special_tile_system.gd` 1箇所: CPU遠隔召喚ログ
- ✅ `movement_warp_handler.gd` 1箇所: 通過型ワープログ（STEP 1で追加済み）
- ✅ 動作確認済み: ワープ発動時にログ正常出力（停止型ワープ + ワープアニメーション）

#### push_error/push_warning → GameLogger 変換（STEP 2）
- ✅ `logger.gd` 改修: error→push_error, warn→push_warning でエディタErrors タブ連携
- ✅ 67ファイル271箇所を GameLogger.error() / GameLogger.warn() に変換
  - 全件カテゴリ付き（Init, Spell, Battle, Board, Card, CPU 等15カテゴリ）
  - ERROR は状況付き必須ルール（player_id, tile_idx, spell_id 等）
- ✅ 抽象メソッド3件は push_error 維持（spell_strategy.gd, skill_effect_base.gd）
- ✅ 6コミットに機能単位で分割
- 📋 詳細: `docs/progress/push_error_migration.md`

#### null参照ガード強化（スペル系完了）
- ✅ スペル系の調査完了: 49箇所のリスク特定（Critical 31 + Moderate 18）
- ✅ spell_effect_executor: 早期return時の完了シグナル保証（spell_used + complete_spell_phase）
- ✅ spell_flow_handler: current_player null チェック追加
- ✅ spell_land_new.gd: tile_nodes アクセス全箇所確認（_validate_tile_index / .has() / keys()ループで保護済み）
- ✅ spell_mystic_arts.gd: 4箇所修正（board_system_ref, spell_ui_manager, _set_caster_down_state）
- ✅ mystic_arts_handler.gd: 4箇所修正（spell_state チェーンアクセスガード）
- ✅ spell_target_selection_handler.gd: 4箇所修正（spell_state null ガード）
- ✅ spell_creature_move.gd: 3箇所修正（board_system_ref null ガード）
- ✅ spell_flow_handler.gd: 確認済み（ternary で保護済み、追加修正不要）
- ✅ spell_effect_executor.gd: 確認済み（前セッションで修正 + ternary保護済み）
- ✅ spell_magic.gd: 確認済み（ループ内アクセスは安全、追加修正不要）
- 🔄 残り: ドミニオ → バトル → 召喚

### 📋 次のステップ

- null参照ガード: ドミニオシステム（move_source_tile, selected_tile, state不整合）
- null参照ガード: バトルシステム（attacker/defender null, battle_data null）
- null参照ガード: 召喚システム（tile null, creature_data null）
- 自動テスト（GUT フレームワーク導入）
