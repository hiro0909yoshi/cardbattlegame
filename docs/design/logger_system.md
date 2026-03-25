# Logger システム設計

**作成日**: 2026-03-19
**ステータス**: 設計中

---

## 目的

ゲーム全体の動作を記録し、以下を実現する：

1. **クラッシュ原因の特定** — どのターン・どのフェーズで何が起きたかを追跡
2. **ユーザーバグ報告対応** — ユーザーの端末にログファイルが残り、送付してもらえる
3. **開発時デバッグ** — コンソール出力は今まで通り維持

---

## 現状の課題

| 現状 | 問題点 |
|------|--------|
| `print()` でコンソール出力 | クラッシュしたら消える。ユーザー端末では見られない |
| `push_error()` / `push_warning()` | Godotログに残るが構造化されていない |
| `SkillLogSystem` | バトル専用。ゲーム全体のフローをカバーしていない |
| `DebugSettings` | デバッグフラグ集であり、ログ機能ではない |

---

## 既存システムとの関係

```
DebugSettings (Autoload)    — デバッグフラグ管理。変更なし
SkillLogSystem (Node)       — バトル専用ログ。変更なし
Logger (Autoload) ★新規★   — ゲーム全体のログ。ファイル書き込み担当
```

- `Logger` は `DebugSettings` や `SkillLogSystem` を置き換えない
- 将来的に `SkillLogSystem` のログも `Logger` 経由でファイルに書き出す統合は可能（STEP 2以降）

---

## ログ設計の原則

### 基本思想

**「再現できる最低限のストーリー」を残す**

- 全部残すのではなく、5行読めばバグの原因がわかるログを目指す
- 「このログがないと再現できないか？」→ YES なら入れる、NO なら捨てる

### GameLog と DebugLog の分離

| 種別 | 出力先 | タイムスタンプ | 用途 |
|------|--------|-------------|------|
| **GameLog** | `GameLogger.info()` → ファイル + コンソール | あり | 本番。確定したアクションのみ記録 |
| **DebugLog** | `print()` → コンソールのみ | なし | 開発用。中間状態・選択開始など |

**判断基準**: 「そのログが無いと試合を再現できないか？」→ YES なら GameLog、NO なら DebugLog

例:
- スペル選択開始（カードをタップした瞬間）→ **DebugLog**（キャンセルされる可能性がある）
- スペル選択確定（ターゲット決定＋実行開始）→ **GameLog**（確定アクション）

### 良いログの例

```
[14:32:01] [INFO]  [GFM]     ターン開始: P1, ラウンド5
[14:32:06] [INFO]  [SM]      DICE_ROLL -> TILE_ACTION
[14:32:07] [INFO]  [Spell]   スペル使用: P1 "ランドプロテクト" → タイル3
[14:32:07] [ERROR] [Spell]   spell_land: tile_data が null - tile_index: 3
```

→ 「ラウンド5、P1がランドプロテクトをタイル3に使った時にクラッシュ」と即特定できる

### 悪いログの例

1000行あるのに、どのカードが原因か書いていないログ

---

## STEP 1 で記録するログ種別

### 記録対象

| 種別 | tag | 記録する情報 | なぜ必要か |
|------|-----|-------------|-----------|
| **ターン開始** | `GFM` | プレイヤーID、ラウンド数 | 「何ターン目に起きたか」の時間軸 |
| **フェーズ遷移** | `SM` | 遷移元 → 遷移先 | 「どこで止まったか」の特定 |
| **ダイス結果** | `Dice` | プレイヤーID、出目、修正後の値 | 移動先の妥当性検証（出目と着地点の整合性） |
| **移動完了** | `Move` | プレイヤーID、出発タイル → 着地タイル | UIが消える・着地点がおかしい等の移動バグ追跡 |
| **スペルフェーズ開始** | `Spell` | プレイヤーID、手札スペル枚数 | スペルフェーズの開始/完了ペアでフリーズ検知 |
| **スペル選択開始** | `Spell` | スペル名、スペルID | スペルカード選択直後、ターゲットUI表示前。「開始なし」→UI以前で死んでいる |
| **スペル選択確定** | `Spell` | スペル名、スペルID、対象種別、対象ID、タイル | ターゲット選択完了。「開始あり・確定なし」→ターゲット生成で死んでいる |
| **スペル効果完了** | `Spell` | スペル名、スペルID、result(success/fail/no_effect) | 効果実行完了。「確定あり・完了なし」→効果実行中クラッシュ |
| **アーツ選択開始** | `Spell` | アーツ名、ID | アルカナアーツ選択直後。スペルと別フロー（MysticArtsHandler経由） |
| **アーツ選択確定** | `Spell` | アーツ名、ID、対象種別、対象ID、タイル | アルカナアーツのターゲット選択完了 |
| **アーツ効果完了** | `Spell` | アーツ名、ID、result(success/fail/no_effect) | アルカナアーツの効果実行完了。CPU専用パスもあり追跡が重要 |
| **スペルフェーズ完了** | `Spell` | プレイヤーID、使用枚数 | 開始とペア。完了がなければスペルフェーズでフリーズ |
| **バトル結果** | `Battle` | 攻撃側/防御側のクリーチャー名・ID、勝敗、HP変化 | カルドセプト系はバトル起因のバグが多い。HP変化で即死バグ・ダメージ異常を検出 |
| **バトルUI開始** | `BattleUI` | 攻撃側/防御側のクリーチャー名・ID、タイル | バトル画面の表示異常追跡。開始ログと終了ログのペアで閉じ忘れ・Tween詰まりを検出 |
| **バトルUI終了** | `BattleUI` | バトル結果 | 開始とペアで記録。終了がなければUI閉じ忘れ確定。タイムスタンプ差が大きければTween詰まり |
| **バトルUI異常** | `BattleUI` | 異常種別、状態情報 | BattleScreen取得失敗、バトル重複検出、演出中の_battle_screen null 等 |
| **召喚成功** | `Summon` | クリーチャー名・ID、タイル、属性、コスト | 配置制限・コスト計算・ダウン状態が絡む |
| **召喚失敗** | `Summon` | クリーチャー名・ID、タイル、失敗理由 | 「なぜ召喚できなかったか」の特定（土地条件未達、配置制限、EP不足等） |
| **ドミニオコマンド実行** | `Dominio` | コマンド種類、タイル、クリーチャー名・ID | レベルアップ・移動・交換で状態変更が多い |
| **移動侵略** | `Dominio` | 移動元タイル → 移動先タイル、クリーチャー名・ID | 移動先のバトル発生を追跡。バトル結果は別途記録。`move_source_tile` の整合性検証 |
| **ドミニオコマンド完了** | `Dominio` | コマンド種類 | 開始とのペアで完了確認。完了がなければステート不整合の疑い |
| **ドミニオ異常** | `Dominio` | ステート不整合、無効なタイル参照等 | DCHのステートマシン（6状態）のずれ、`move_source_tile` が無効等 |
| **ゲーム開始** | `Game` | プレイヤー数、ステージ名 | ログの始まり。セッションの区切り |
| **ゲーム終了** | `Game` | 勝者、最終ラウンド数 | ログの終わり。結果不明だと全てのログが宙に浮く |
| **勝利判定** | `Game` | プレイヤーID、TEP、目標TEP | 「誰がいつ勝ったか」の記録。チーム合算TEPの妥当性検証 |
| **破産** | `Game` | プレイヤーID、EP | プレイヤー脱落はゲーム状態の大転換。「いつ破産した？」の追跡 |
| **通行料** | `Toll` | 支払者ID、受取者ID、金額、タイル、レベル、残EP | EP変動の最大原因。残EPで破産直前の状況が即判明 |
| **チェックポイント通過** | `Lap` | プレイヤーID、タイル、EPボーナス | 周回進行の追跡。シグナル既取得の二重処理検知 |
| **周回完了** | `Lap` | プレイヤーID、周回数 | ダウン全解除・HP全回復・EP付与が発生。「なぜ急に状態が変わった？」の追跡 |
| **エラー** | 各所 | エラーメッセージ、フェーズ、ターン | クラッシュ原因の直接的手がかり |

### ID記録の方針

カード名・クリーチャー名だけでなく **IDも必ず記録する**。理由：
- 同名カードが存在する可能性
- 将来の多言語化でカード名が変わる
- IDなら一意にカードを特定できる

ログは「人間は名前で読み、機械はIDで特定する」形式にする。

### 記録しないもの（STEP 1）

| 種別 | 理由 | 追加時期 |
|------|------|---------|
| 移動中ワープ/強制停止 | 移動完了ログで着地点は分かる。原因追跡が必要になったら追加 | STEP 1.5 |
| 特殊タイル効果（ワープ停止・遠隔召喚） | 盤面変更が大きいもののみ。軽い効果はノイズになる | STEP 1.5 |
| 分岐タイル選択 | バグ原因になることが少ない | STEP 2 |
| AI思考過程 | 開発者向け内部詳細。ユーザーログでは不要 | STEP 2以降 |
| ダメージ計算の中間値 | 最終結果だけあれば十分 | STEP 2以降 |
| ~~カードドロー~~ | ~~毎ターン発生する日常動作~~ | **STEP 1で実装済み**（カード名+IDを記録） |
| スキル発動の全詳細 | 量が多すぎてノイズになる | STEP 2以降 |
| スペル効果の詳細 | 量が多い。ただし土地奪取・位置移動など盤面変更系は例外的にSTEP 2で早期追加 | STEP 2 |

### 直前アクション追跡の仕組み

バグは「どの操作で起きたか」がわからないと追えない。
毎行flushにより、ログファイルの**最後の行の直前**が常に「直前アクション」になる。
特別な仕組みは不要 — 重要なアクション（スペル使用、バトル開始、召喚、土地コマンド）をログに書いておけば、自動的に直前アクションが残る。

---

## 設計

### Autoload 登録

```
GameLogger = *res://scripts/autoload/logger.gd
```

`project.godot` の `[autoload]` セクションに追加。`DebugSettings` の直後に配置。
**注意**: Godot 4.5 で `Logger` は組み込みクラス名と衝突するため `GameLogger` を使用。

### ログレベル

```gdscript
enum LogLevel {
    INFO,     # 通常の動作記録（ターン開始、フェーズ遷移、アクション）
    WARN,     # 異常だが続行可能（nullだがフォールバックした等）
    ERROR     # エラー（ゲーム進行に影響するバグ）
}
```

### ERROR と WARN の使い分け基準

**サーバーは `[ERROR]` を含むログを自動検知する。** そのため ERROR は「開発者が確認すべきバグ」にのみ使う。

| レベル | 基準 | サーバー検知 | 例 |
|--------|------|-------------|-----|
| **ERROR** | ゲーム進行に影響する。本来起きてはいけない | **自動フラグ** | null参照でスキップ、不正なフェーズ遷移、データ不整合 |
| **WARN** | 異常だが処理済み。ゲームは正常に続行 | しない | フォールバック使用、重複シグナル接続スキップ、プール枯渇で新規作成 |
| **INFO** | 正常な動作記録 | しない | ターン開始、ダイス結果、召喚成功 |

**判断フロー:**
```
この異常でゲームの結果が変わる可能性がある？
  → YES → ERROR（バグ。修正が必要）
  → NO  → WARN（安全にスキップ/フォールバックした）
```

### ERROR を入れるべき箇所（カテゴリ別）

既存の `push_error()` 約286件のうち、GameLogger.error() に変換すべきものを以下に分類する。

#### カテゴリ1: ゲームフロー中の初期化失敗（最重要）

ゲーム進行中にシステム参照がnullになっている場合。初期化順序のバグを示す。

```
対象ファイル例:
- game_flow_manager.gd: spell_draw/dice_phase_handler/spell_phase_handler が null
- spell_phase_handler.gd: spell_state/spell_flow/cpu_spell_phase_handler が null
- spell_effect_executor.gd: handler/spell_state/spell_container が null
- mystic_arts_handler.gd: 必要なシステム参照が未設定
- battle_system.gd: spell_draw/spell_magic/board_system_ref が null
```

→ **全て GameLogger.error()。** ゲームが進行不能になるバグ。

#### カテゴリ2: データ不整合（重要）

存在するはずのデータが見つからない、または不正な値が渡された場合。

```
対象ファイル例:
- board_system_3d.gd: 不明な属性、タイル生成失敗、矛盾したデータ
- spell_land_new.gd: 無効な属性、タイルが見つかりません
- card_system.gd: 不正なplayer_id、デッキが空
- game_flow_state_machine.gd: Invalid transition
- spell_effect_executor.gd: Strategy作成失敗、未実装のeffect_type
```

→ **全て GameLogger.error()。** ロジックバグまたはデータ破損を示す。

#### カテゴリ3: 処理済み異常（WARNに変換）

異常を検知したが、フォールバックで安全に続行した場合。

```
対象ファイル例:
- object_pool.gd: プール枯渇→新規作成
- battle_screen_manager.gd: バトルが既にアクティブ→警告のみ
- game_system_manager.gd: シグナルが既に接続済み→スキップ
- cpu_movement_evaluator.gd: movement_controller未設定→計算スキップ
- network_manager.gd: Already connected
```

→ **GameLogger.warn()。** ゲーム結果に影響しない。

#### カテゴリ4: 開発専用（変換不要）

バトルテストやデバッグ用のエラー。本番ゲームでは実行されない。

```
対象ファイル:
- battle_test_ui.gd, battle_test_config.gd, battle_test_executor.gd
```

→ **push_error() のまま。** Logger に変換しない。

### 公開API

```gdscript
# 基本ログ
GameLogger.info(tag: String, message: String)
GameLogger.warn(tag: String, message: String)
GameLogger.error(tag: String, message: String)
```

- `tag` — 発信元を識別する短いラベル（例: `"GFM"`, `"SM"`, `"Battle"`, `"Spell"`）
- `message` — 人間が読むログメッセージ。**カード名・クリーチャー名を必ず含める**

### 呼び出し例

```gdscript
# ターン開始
GameLogger.info("GFM", "ターン開始: P%d, ラウンド%d" % [player_id + 1, round_number])

# フェーズ遷移
GameLogger.info("SM", "フェーズ遷移: %s -> %s" % [from_name, to_name])

# ダイス結果
GameLogger.info("Dice", "ダイス: P%d 出目%d (修正後:%d)" % [player_id + 1, raw_dice, modified_dice])

# 移動完了（出発タイルと着地タイルの両方を記録 → 出目との整合性が検証できる）
GameLogger.info("Move", "移動完了: P%d タイル%d → タイル%d" % [player_id + 1, from_tile, final_tile])

# スペルフェーズ開始（フェーズの開始/完了ペアでフリーズ検知）
GameLogger.info("Spell", "スペルフェーズ開始: P%d 手札スペル%d枚" % [player_id + 1, spell_count])

# スペル選択開始（スペルカード選択直後、ターゲットUI表示前）— print()のみ（DebugLog）
print("[Spell] 選択開始: P%d %s(id:%d)" % [player_id + 1, spell_name, spell_id])

# スペル選択確定（ターゲット選択完了時。対象種別 + ID + タイル位置）
GameLogger.info("Spell", "選択確定: P%d %s(id:%d) → %s:%s tile:%d" % [
    player_id + 1, spell_name, spell_id, target_type, target_id, tile_idx])
# target_type: "tile", "creature", "player"

# スペル効果完了（result で成功/失敗/効果なしを区別）
GameLogger.info("Spell", "効果完了: P%d %s(id:%d) result=%s" % [
    player_id + 1, spell_name, spell_id, result])
# result: "success", "fail", "no_effect"

# アーツ選択開始（アーツ選択直後）— print()のみ（DebugLog）
print("[Spell] アーツ選択開始: P%d %s(spell_id:%s)" % [player_id + 1, arts_name, arts_sid])

# アーツ選択確定（ターゲット選択完了時）
GameLogger.info("Spell", "アーツ選択確定: P%d %s(spell_id:%s) → %s tile:%d" % [
    player_id + 1, arts_name, arts_sid, target_type, tile_idx])

# アーツ効果完了
GameLogger.info("Spell", "アーツ効果完了: P%d %s(spell_id:%s) result=%s" % [
    player_id + 1, arts_name, arts_sid, result])

# CPU版も同じ形式（CPUプレフィックスで区別）
GameLogger.info("Spell", "アーツ効果実行: CPU P%d %s(spell_id:%s)" % [player_id + 1, arts_name, arts_sid])

# ※ アーツのIDについて:
#   アーツデータは `id` フィールドを持たないものが多い（一部は文字列ID: "amon_mystic_001"等）
#   大半は `spell_id`（整数）で内部スペルを参照するため、`spell_id` を識別子として使用
#   取得方法: mystic_art.get("spell_id", mystic_art.get("id", "none"))

# スペルフェーズ完了（開始とペア）
GameLogger.info("Spell", "スペルフェーズ完了: P%d 使用%d枚" % [player_id + 1, used_count])

# バトル開始（クリーチャー名 + ID + タイル + 使用アイテム）
GameLogger.info("Battle", "バトル開始: P%d %s(id:%d) vs %s(id:%d) タイル%d ATKアイテム:%s DEFアイテム:%s" % [
    attacker_id + 1, atk_name, atk_id, def_name, def_id, tile_idx, atk_item, def_item])

# バトル結果（クリーチャー名 + ID + 勝敗 — 即死バグ・ダメージ異常の検出）
GameLogger.info("Battle", "バトル結果: P%d %s(id:%d) vs P%d %s(id:%d) → %s (タイル%d)" % [
    attacker_id + 1, atk_name, atk_id, defender_id + 1, def_name, def_id, result_label, tile_idx])
# result_label: "攻撃側勝利", "防御側勝利", "攻撃側生存", "相打ち"

# アイテム使用（バトル準備フェーズ）
GameLogger.info("Battle", "アイテム使用: P%d %s %s(id:%d)" % [player_id + 1, phase_side, item_name, item_id])
# phase_side: "攻撃側", "防御側"

# 合体（バトル準備フェーズ）
GameLogger.info("Battle", "合体: P%d %s(id:%d) → %s(id:%d)" % [
    player_id + 1, base_name, base_id, merge_name, merge_id])

# バトルUI開始（seq + phase 付き。開始・終了のペアで追跡）
# _battle_seq はBattleScreenManagerのメンバ変数（var _battle_seq: int = 0）
GameLogger.info("BattleUI", "開始[seq:%d]: %s(id:%d) vs %s(id:%d) タイル%d phase:%s" % [
    _battle_seq, atk_name, atk_id, def_name, def_id, tile_idx, phase_name])

# バトルUI終了（seqで開始とペア対応。タイムスタンプ差が大きければTween詰まりの疑い）
GameLogger.info("BattleUI", "終了[seq:%d]: %s" % [_battle_seq, result_name])

# バトルUI異常（異常検知時のみ記録 — 正常時はstateを出さない）
GameLogger.error("BattleUI", "BattleScreen取得失敗[seq:%d]: pool empty" % _battle_seq)
GameLogger.warn("BattleUI", "重複検出[seq:%d]: _battle_screen=%s, _is_battle_active=%s" % [
    _battle_seq, str(_battle_screen != null), str(_is_battle_active)])
GameLogger.warn("BattleUI", "演出スキップ[seq:%d]: _battle_screen が null (show_attack)" % _battle_seq)

# 召喚成功（クリーチャー名 + ID + コスト）
GameLogger.info("Summon", "召喚: P%d %s(id:%d) → タイル%d (%s) コスト:%dEP" % [
    player_id + 1, creature_name, creature_id, tile_idx, element, cost])

# 召喚失敗（理由を含める — なぜ出せなかったかが重要）
GameLogger.warn("Summon", "召喚失敗: P%d %s(id:%d) → %s (タイル%d)" % [
    player_id + 1, creature_name, creature_id, reason, tile_idx])
# reason例: "土地条件未達", "配置制限", "EP不足", "堅守は空き地のみ"

# ドミニオコマンド実行（コマンド種類 + タイル + レベル + クリーチャー）
GameLogger.info("Dominio", "コマンド: P%d %s タイル%d Lv%d %s(id:%d)" % [
    player_id + 1, action_type, tile_idx, tile_level, creature_name, creature_id])
# action_type: "level_up", "move_creature", "swap_creature", "terrain_change"

# 移動侵略（from → to。バトル結果は Battle タグで別途記録される）
GameLogger.info("Dominio", "移動侵略: P%d タイル%d → タイル%d %s(id:%d)" % [
    player_id + 1, from_tile, to_tile, creature_name, creature_id])

# ドミニオコマンド完了（開始とペア。成否を含める）
GameLogger.info("Dominio", "コマンド完了: %s タイル%d result=%s" % [action_type, tile_idx, "success" if success else "failed"])

# ドミニオ異常（ステート不整合・無効参照）
GameLogger.warn("Dominio", "ステート不整合: 期待=%s, 実際=%s" % [expected_state, actual_state])
GameLogger.error("Dominio", "移動元タイルが無効: move_source_tile=%d" % move_source_tile)

# ===== ゲーム開始/終了 =====

# ゲーム開始（ログの始まり。セッション全体の区切り）
GameLogger.info("Game", "ゲーム開始: %d人 ステージ:%s" % [player_count, stage_name])

# ゲーム終了（ログの終わり）
GameLogger.info("Game", "ゲーム終了: ラウンド%d" % round_number)

# 勝利判定（チーム合算TEPの場合もある）
GameLogger.info("Game", "勝利: P%d TEP:%d (目標:%d)" % [player_id + 1, tep, target])

# 破産（プレイヤー脱落の重大イベント）
GameLogger.warn("Game", "破産: P%d EP:%d" % [player_id + 1, ep])

# ===== 通行料 =====

# 通行料支払い（残EPを含めると破産直前の状況が即判明）
GameLogger.info("Toll", "通行料: P%d → P%d %dEP (タイル%d Lv%d 残EP:%d)" % [
    payer_id + 1, owner_id + 1, amount, tile_idx, level, remaining_ep])

# ===== 周回/チェックポイント =====

# チェックポイント通過（EPボーナス付与）
GameLogger.info("Lap", "チェックポイント通過: P%d タイル%d EP+%d" % [player_id + 1, tile_idx, bonus])

# 周回完了（ダウン全解除 + HP全回復 + EPボーナス + 永続ステータスボーナスが走る）
GameLogger.info("Lap", "周回完了: P%d %d周目 ダウン全解除+HP回復" % [player_id + 1, lap_count])

# ===== エラー =====

# エラー（ターンとフェーズを必ず含める — ログ単体で状況がわかる）
GameLogger.error("Spell", "spell_land: tile_data が null (turn:%d, phase:%s, tile:%d)" % [turn, phase_name, tile_index])
```

### ファイル出力

| 項目 | 仕様 |
|------|------|
| 保存先 | `user://logs/` |
| ファイル名 | `game_YYYYMMDD_HHMMSS.log` （セッション開始時に生成） |
| 書き込み方式 | 1行ごとに即 `flush`（クラッシュ対策） |
| フォーマット | `[HH:MM:SS.mmm] [LEVEL] [Tag] メッセージ` |
| 古いログ | 最大10ファイル保持。超過分は古い順に自動削除 |

### コンソール出力

ファイルに書くと同時に `print()` でコンソールにも出力する（今まで通りの開発体験を維持）。

### ログ出力の完全な流れ

**ゲーム開始:**
```
[14:30:00.000] [INFO]  [Game]    ゲーム開始: 2人 ステージ:stage_1_1
```

**1ターン分の例（ラウンド5）:**
```
[14:32:01.234] [INFO]  [GFM]     ターン開始: P1, ラウンド5
[14:32:01.240] [INFO]  [SM]      フェーズ遷移: SETUP -> DICE_ROLL
[14:32:01.300] [INFO]  [Spell]   スペルフェーズ開始: P1 手札スペル2枚
[14:32:02.400] [INFO]  [Spell]   選択開始: P1 ランドプロテクト(id:201)
[14:32:02.500] [INFO]  [Spell]   選択確定: P1 ランドプロテクト(id:201) → tile:3 tile:3
[14:32:02.600] [INFO]  [Spell]   効果完了: P1 ランドプロテクト(id:201) result=success
[14:32:02.700] [INFO]  [Spell]   スペルフェーズ完了: P1 使用1枚
[14:32:03.100] [INFO]  [SM]      フェーズ遷移: DICE_ROLL -> MOVING
[14:32:03.150] [INFO]  [Dice]    ダイス: P1 出目5 (修正後:5)
[14:32:05.500] [INFO]  [Move]    移動完了: P1 タイル3 → タイル8
[14:32:05.510] [INFO]  [SM]      フェーズ遷移: MOVING -> TILE_ACTION
[14:32:05.600] [INFO]  [Toll]    通行料: P1 → P2 120EP (タイル8 Lv3 残EP:180)
[14:32:06.000] [INFO]  [Summon]  召喚: P1 フレイムドラゴン(id:105) → タイル8 (火) コスト:3EP
[14:32:08.500] [INFO]  [SM]      フェーズ遷移: TILE_ACTION -> BATTLE
[14:32:08.600] [INFO]  [BattleUI] 開始[seq:3]: フレイムドラゴン(id:105) vs アイスゴーレム(id:203) タイル8 phase:BATTLE
[14:32:10.000] [INFO]  [Battle]  バトル結果: フレイムドラゴン(id:105) vs アイスゴーレム(id:203) → フレイムドラゴン勝利 (HP:40→0, タイル8)
[14:32:10.500] [INFO]  [BattleUI] 終了[seq:3]: attacker_win
[14:32:11.000] [INFO]  [Dominio] コマンド: P1 level_up タイル8 フレイムドラゴン(id:105)
[14:32:11.500] [INFO]  [Dominio] コマンド完了: level_up タイル8 result=success
[14:32:12.000] [INFO]  [SM]      フェーズ遷移: TILE_ACTION -> END_TURN
```

→ 20行でターン全体が読める。どこで何が起きたか一目瞭然。

**移動バグの発見例:**
```
[14:32:03.150] [INFO]  [Dice]    ダイス: P1 出目5 (修正後:5)
[14:32:05.500] [INFO]  [Move]    移動完了: P1 タイル3 → タイル12
```
→ 出目5なのにタイル3→12（9マス移動）はおかしい → ワープか足止めの判定バグ

**バトルUIバグの発見例:**
```
[14:32:08.600] [INFO]  [BattleUI] 開始[seq:3]: フレイムドラゴン(id:105) vs アイスゴーレム(id:203) タイル8 phase:BATTLE
（... 終了ログがない ...）
[14:32:30.000] [INFO]  [SM]      フェーズ遷移: BATTLE -> END_TURN
```
→ BattleUI開始[seq:3]から終了ログがない → 画面が閉じずにフリーズしている。タイムスタンプから20秒以上経過 → Tween詰まりの疑い

**バトルロジックバグの発見例:**
```
[14:32:10.000] [INFO]  [Battle]  バトル結果: フレイムドラゴン(id:105) vs アイスゴーレム(id:203) → フレイムドラゴン勝利 (HP:40→0, タイル8)
[14:32:10.001] [ERROR] [Battle]  tile_data が null (turn:5, phase:BATTLE, tile:8)
```
→ バトル後のタイル処理でクラッシュ。id:105 と id:203 の組み合わせで再現可能

**バトルUI異常の発見例:**
```
[14:32:08.500] [WARN]  [BattleUI] 重複検出[seq:4]: _battle_screen=true, _is_battle_active=true
[14:32:08.501] [INFO]  [Battle]  バトル結果: ...
```
→ seq:3 の終了がないまま seq:4 が来た → 前回のバトルUIが正常終了していない → Object Pool返却漏れの疑い

**移動侵略バグの発見例:**
```
[14:33:01.000] [INFO]  [Dominio] 移動侵略: P1 タイル5 → タイル9 ストーンゴーレム(id:108)
[14:33:03.000] [INFO]  [BattleUI] 開始[seq:4]: ストーンゴーレム(id:108) vs ウィンドスピリット(id:301) タイル9 phase:TILE_ACTION
[14:33:05.000] [INFO]  [Battle]  バトル結果: ストーンゴーレム(id:108) vs ウィンドスピリット(id:301) → ストーンゴーレム勝利 (HP:30→0, タイル9)
[14:33:05.001] [ERROR] [Dominio] 移動元タイルが無効: move_source_tile=-1
```
→ バトルには勝ったが `move_source_tile` がリセットされていた → 土地所有権移転が正しく行われない

**通行料→破産の追跡例:**
```
[14:35:01.000] [INFO]  [Toll]    通行料: P1 → P2 500EP (タイル12 Lv5 残EP:30)
[14:35:01.001] [WARN]  [Game]    破産: P1 EP:30
```
→ タイル12のLv5通行料500EPで残EP30に。直後に破産。通行料の金額とレベルが正しいか検証可能

**周回完了による状態変化の追跡例:**
```
[14:36:00.000] [INFO]  [Lap]     チェックポイント通過: P2 タイル15 EP+100
[14:36:00.100] [INFO]  [Lap]     周回完了: P2 3周目 ダウン全解除+HP回復
[14:36:00.200] [INFO]  [Game]    勝利: P2 TEP:8500 (目標:8000)
```
→ チェックポイント通過 → 周回完了 → 勝利判定の流れが一目瞭然。TEP 8500 が正しいか検証可能

**スペル: UI以前のクラッシュ（選択開始すら出ない）:**
```
[14:32:01.300] [INFO]  [Spell]   スペルフェーズ開始: P1 手札スペル2枚
（... 選択開始ログがない ...）
```
→ 「選択開始」すらない → **スペルカード選択のUI処理以前で死んでいる**

**スペル: ターゲット生成中クラッシュ（選択開始あり・確定なし）:**
```
[14:32:01.300] [INFO]  [Spell]   スペルフェーズ開始: P1 手札スペル2枚
[14:32:02.400] [INFO]  [Spell]   選択開始: P1 ランドドレイン(id:215)
（... 選択確定ログがない ...）
```
→ 「選択開始」はあるが「選択確定」がない → **ターゲット候補生成やターゲットUI表示で死んでいる**。SpellTargetSelectionHandler のバグ

**スペル: 効果実行中クラッシュ（確定あり・効果完了なし）:**
```
[14:32:02.400] [INFO]  [Spell]   選択開始: P1 ランドドレイン(id:215)
[14:32:02.500] [INFO]  [Spell]   選択確定: P1 ランドドレイン(id:215) → tile:7 tile:7
（... 効果完了ログがない ...）
```
→ 「選択確定」はあるが「効果完了」がない → **効果実行中にクラッシュ**。ランドドレインのStrategy内のバグ

**スペル: 効果なし（バグか仕様か判別）:**
```
[14:32:02.500] [INFO]  [Spell]   選択確定: P1 ホーリーワード6(id:220) → player:2 tile:5
[14:32:02.600] [INFO]  [Spell]   効果完了: P1 ホーリーワード6(id:220) result=no_effect
```
→ 効果は走ったが何も起きなかった → 条件不成立か対象無効。「バグか仕様か」をログだけで判別可能

**アルカナアーツ: 効果実行中クラッシュ:**
```
[14:33:05.000] [INFO]  [Battle]  バトル結果: フレイムドラゴン(id:105) vs アイスゴーレム(id:203) → フレイムドラゴン勝利 (HP:40→0, タイル8)
[14:33:05.100] [INFO]  [Spell]   アーツ選択開始: P2 リジェネレーション(id:305)
[14:33:05.150] [INFO]  [Spell]   アーツ選択確定: P2 リジェネレーション(id:305) → creature:203 tile:8
[14:33:05.151] [ERROR] [Spell]   mystic_arts: player_system が null (turn:5, phase:BATTLE)
```
→ 「アーツ選択確定」はあるが「アーツ効果完了」がない → **効果実行中にクラッシュ**。タイル8のcreature:203に対する処理で player_system null

**CPUアルカナアーツ:**
```
[14:33:06.000] [INFO]  [Spell]   アーツ選択開始: CPU P3 フレイムシールド(id:310)
[14:33:06.001] [INFO]  [Spell]   アーツ効果完了: CPU P3 フレイムシールド(id:310) result=success
[14:33:06.002] [WARN]  [BattleUI] 演出スキップ[seq:5]: _battle_screen が null (show_attack)
```
→ CPUアーツ自体は成功したがバトルUI側で演出できていない → BattleScreen のライフサイクル不整合

**召喚失敗の発見例:**
```
[14:32:06.000] [WARN]  [Summon]  召喚失敗: P1 アースドラゴン(id:110) → 土地条件未達 (タイル8)
[14:32:06.001] [INFO]  [Summon]  召喚: P1 ファイアリザード(id:102) → タイル8 (火) コスト:2EP
```
→ 最初にアースドラゴンを出そうとして失敗、代わりにファイアリザードを召喚。ユーザーが「召喚できない」と報告した時に原因が即わかる

---

## 実装ステップ

### STEP 1: Logger Autoload + 重要アクションログ（最優先）

**作るもの:**
- `scripts/autoload/logger.gd` — Autoload スクリプト
- `project.godot` に Autoload 登録

**埋め込み箇所:**

| ファイル | 箇所 | ログ種別 |
|----------|------|---------|
| `game_flow_state_machine.gd` | `transition_to()` | フェーズ遷移 / 不正遷移エラー |
| `game_flow_manager.gd` | `start_game()` | ゲーム開始 |
| `game_flow_manager.gd` | `start_turn()` | ターン開始 |
| `game_flow_manager.gd` | `end_turn()` | ターン終了 |
| `dice_phase_handler.gd` | `roll_dice()` ダイス確定後 | ダイス結果（出目・修正値） |
| `board_system_3d.gd` | `_on_movement_completed()` | 移動完了（出発タイル → 着地タイル） |
| `spell_phase_handler.gd` | `start_spell_phase()` | スペルフェーズ開始（手札スペル枚数） |
| `spell_phase_handler.gd` | `complete_spell_phase()` | スペルフェーズ完了（使用枚数） |
| `spell_phase_handler.gd` | スペルカード選択直後 | スペル選択開始（スペル名・ID） |
| `spell_effect_executor.gd` | `execute_spell_effect()` 開始時 | スペル選択確定（スペル名・ID・対象種別・対象ID・タイル） |
| `spell_effect_executor.gd` | `execute_spell_effect()` 完了後 | スペル効果完了（スペル名・ID・result） |
| `spell_effect_executor.gd` | バリデーション失敗・null参照時 | スペルエラー（push_error→GameLogger.error置換） |
| `mystic_arts_handler.gd` | アーツ選択直後 | アーツ選択開始（アーツ名・ID） |
| `mystic_arts_handler.gd` | アーツ対象選択完了時 | アーツ選択確定（アーツ名・ID・対象種別・対象ID・タイル） |
| `mystic_arts_handler.gd` | アーツ効果実行完了時 | アーツ効果完了（アーツ名・ID・result） |
| `mystic_arts_handler.gd` | `_execute_cpu_mystic_arts()` 内 | CPUアーツ選択開始+効果完了 |
| `tile_battle_executor.gd` または `battle_execution.gd` | バトル終了時 | バトル結果（クリーチャー名・ID・勝敗・HP変化） |
| `battle_screen_manager.gd` | `start_battle()` | バトルUI開始（クリーチャー名・ID・タイル） |
| `battle_screen_manager.gd` | `close_battle_screen()` / `end_battle()` | バトルUI終了（結果） |
| `battle_screen_manager.gd` | 各所の `if not _battle_screen: return` | バトルUI異常（異常検知時のみ） |
| `tile_summon_executor.gd` | `execute_summon()` 成功時 | 召喚成功（クリーチャー名・ID・タイル・コスト） |
| `tile_summon_executor.gd` | 各チェック失敗箇所 | 召喚失敗（理由: 土地条件、配置制限、EP不足等） |
| `dominio_command_handler.gd` | `execute_action()` | ドミニオコマンド実行（種類・タイル・クリーチャー） |
| `land_action_helper.gd` | `confirm_move()` 敵地侵入時 | 移動侵略（from → to・クリーチャー） |
| `land_action_helper.gd` | 各コマンド完了時 | ドミニオコマンド完了 |
| `dominio_command_handler.gd` | ステート不整合検出時 | ドミニオ異常（ステート・タイル参照） |
| `game_flow_manager.gd` | `start_game()` 冒頭 | ゲーム開始（プレイヤー数・ステージ名） |
| `game_flow_manager.gd` | ゲーム終了処理 | ゲーム終了（最終ラウンド数） |
| `lap_system.gd` | `_check_win_condition()` 勝利確定時 | 勝利判定（プレイヤーID・TEP・目標TEP） |
| `player_system.gd` | 破産判定箇所 | 破産（プレイヤーID・EP） |
| `player_system.gd` | `pay_toll()` | 通行料（支払者・受取者・金額・タイル・レベル・残EP） |
| `lap_system.gd` | `_on_checkpoint_passed()` | チェックポイント通過（プレイヤーID・タイル・EPボーナス） |
| `lap_system.gd` | `_complete_lap()` | 周回完了（プレイヤーID・周回数） |

**成功基準:**
- ログファイルから「何ターン目の、どのフェーズで、どのカード/クリーチャーが原因で壊れたか」が特定できる
- 1ターンあたり約20行以内（通行料・チェックポイント発生時は増加）

### STEP 1.5: 移動詳細ログ（余裕があれば）

**追加する箇所:**

| ファイル | 箇所 | ログ種別 |
|----------|------|---------|
| `movement_controller.gd` | ワープ処理後 | 移動中ワープ（from → to） |
| `movement_controller.gd` | 強制停止判定時 | 強制停止（タイル・理由） |
| `special_tile_system.gd` | ワープ停止・遠隔召喚実行時 | 特殊タイル効果（盤面変更を伴うもののみ） |

**成功基準:** 移動完了ログで「出目と着地が合わない」場合に、原因（ワープ/強制停止）まで特定できる

### STEP 2: 行動ログ拡充

**追加する箇所:**
- カードドロー
- スペル効果の詳細（盤面変更系を優先: 土地奪取、位置移動）
- 分岐タイル選択
- SkillLogSystem との統合（SkillLogSystem のログもファイルに書き出す）

**成功基準:** 「何をしていたか」がログから再現できる

### STEP 3: 状態スナップショット（軽量）

**記録する状態:**
- アクティブプレイヤーID、EP
- 現在のフェーズ
- 手札枚数
- ボード上のクリーチャー数

**タイミング:** ターン開始時、エラー発生時に自動記録

**成功基準:** 「なぜ壊れたか」の手がかりが残る

### STEP 4: リングバッファ

**仕様:**
- メモリ上は直近N件（200件目安）のみ保持
- ファイルには全件書き込み（flush済みなので問題なし）
- 長時間プレイでのメモリ使用量を抑制

### STEP 5: クラッシュ時ダンプ

**仕様:**
- `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` でログ flush
- `_notification(NOTIFICATION_CRASH)` でスナップショット書き出し（ただしGodotの完全クラッシュでは呼ばれない場合がある）
- STEP 1 で毎行 flush しているため、完全クラッシュでも直前までのログは残る

### STEP 6: サーバー送信（バックエンド連携）

**前提:** Go リレーサーバー + PostgreSQL が稼働済み（`docs/design/backend_design.md` 参照）

**方針:** 全ユーザーのログを常に収集する（バグ報告待ちでは取りこぼしが多い）

#### 送信タイミング

| タイミング | 送る内容 | 仕組み |
|-----------|---------|--------|
| ゲーム正常終了時 | ログファイル（gzip圧縮） | `POST /api/match/result` に添付 |
| クラッシュ後の次回起動時 | 前回のログファイル（gzip圧縮） | Logger._ready() で前回ログの最終行を確認。「ゲーム終了」がなければクラッシュと判定し自動送信 |
| バグ報告ボタン押下時 | ログファイル + ユーザーコメント | `POST /api/logs/report` |

#### クラッシュ検知の仕組み

```gdscript
# Logger._ready() で前回セッションのログをチェック
func _check_previous_session():
    var prev_log = _get_latest_log_file()
    if prev_log == "":
        return

    var last_line = _read_last_line(prev_log)
    if "ゲーム終了" not in last_line:
        # 前回クラッシュした → 自動送信
        _send_crash_log(prev_log)
```

#### サーバー側

**追加API:**

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `POST /api/match/result` | 既存を拡張 | ログファイルを添付フィールドに追加 |
| `POST /api/logs/report` | 新規 | バグ報告（ログ + ユーザーコメント） |
| `GET /api/admin/logs` | 新規（管理画面用） | ログ検索・閲覧 |

**追加テーブル:**

```sql
CREATE TABLE game_logs (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id),
    match_id    INTEGER REFERENCES match_history(id),  -- NULL = クラッシュログ
    log_type    TEXT NOT NULL,                          -- normal / crash / report
    log_data    TEXT NOT NULL,                          -- ログ本文（圧縮解凍後）
    user_comment TEXT,                                  -- バグ報告時のコメント
    client_version TEXT,                                -- クライアントバージョン
    platform    TEXT,                                   -- OS情報
    created_at  TIMESTAMP DEFAULT NOW()
);

-- ユーザー別ログ検索
CREATE INDEX idx_game_logs_user ON game_logs(user_id, created_at DESC);
-- クラッシュログ・バグ報告の優先確認用
CREATE INDEX idx_game_logs_type ON game_logs(log_type) WHERE log_type IN ('crash', 'report');
```

#### サーバー負荷の試算

```
150KB/ゲーム × gzip圧縮（1/5） = 約30KB/ゲーム
700ユーザー × 3ゲーム/日 = 約63MB/日（圧縮後）
月間約1.9GB → VPS 1台で問題なし
保持期間: 90日（古いログは自動削除）
```

#### クライアント側の実装（Logger に追加）

```gdscript
# サーバー送信（HTTPRequest使用）
func send_log_to_server(log_path: String, log_type: String, comment: String = ""):
    var file = FileAccess.open(log_path, FileAccess.READ)
    if not file:
        return

    var content = file.get_as_text()
    file.close()

    var body = {
        "log_type": log_type,       # "normal", "crash", "report"
        "log_data": content,
        "user_comment": comment,
        "client_version": ProjectSettings.get_setting("application/config/version", "unknown"),
        "platform": OS.get_name()
    }

    # HTTPRequest で POST（NetworkService 経由）
    # 送信失敗時はローカルに残すだけ（リトライしない）
```

#### 送信失敗時の方針

- 送信失敗してもゲームに影響しない（fire-and-forget）
- リトライしない（次のゲーム終了時に新しいログが送られるため）
- ローカルのログファイルは送信成否に関係なく保持（最大10ファイル）

#### サーバー側の自動検知

ログ受信時に `[ERROR]` の有無をチェックし、`game_logs` テーブルにフラグを立てる。

```sql
-- game_logs テーブルに追加
has_error   BOOLEAN DEFAULT FALSE,   -- [ERROR] が1件以上含まれる
error_count INTEGER DEFAULT 0        -- [ERROR] の件数
```

```go
// サーバー側（Go）: ログ受信時の処理
func processGameLog(logData string) GameLogRecord {
    lines := strings.Split(logData, "\n")
    errorCount := 0
    for _, line := range lines {
        if strings.Contains(line, "[ERROR]") {
            errorCount++
        }
    }
    return GameLogRecord{
        HasError:   errorCount > 0,
        ErrorCount: errorCount,
    }
}
```

**管理画面での使い方:**
- `has_error = true` のログだけ一覧表示 → 毎日確認
- `error_count` が多いログを優先的に調査
- `log_type = 'crash'` は最優先で確認（クラッシュ = ERROR すら出せずに落ちた）

**成功基準:**
- 管理画面でクラッシュログ・エラー含有ログを日付・ユーザー・log_type で検索できる
- `has_error = true` のフィルターでバグを含むセッションだけ抽出できる
- バグ報告をユーザーコメント付きで確認できる
- 500人規模でサーバー負荷が問題にならない

---

## 既存 print() の扱い

### 方針

既存の約1,900件の `print()` を一括で `Logger` に置き換えない。

1. STEP 1 では Logger 埋め込み箇所の `print()` のみ `GameLogger.info()` に置換
2. それ以外の `print()` はそのまま残す（コンソール出力として機能し続ける）
3. 後のSTEPで、必要なものだけ選別して `Logger` に移行し、不要な `print()` は段階的に削除

### 削除候補（将来）

| カテゴリ | 件数目安 | 理由 |
|----------|---------|------|
| handler内の中間状態出力 | ~100件 | 結果だけあれば十分 |
| CPU AI思考過程 | ~70件 | 開発者向け内部詳細 |
| カードドロー通知 | ~30件 | 毎ターンの日常動作 |
| ダメージ計算中間値 | ~50件 | 最終結果だけあれば十分 |

---

## 設計判断

### なぜ DebugSettings と分離するか

- `DebugSettings` はデバッグフラグ（ON/OFF設定）の管理が責務
- `Logger` はログの記録・保存が責務
- 責務が異なるため分離する

### なぜ SkillLogSystem を改修しないか

- `SkillLogSystem` はバトル中のスキル発動に特化した構造化ログ
- UI表示（色付き、シグナル連携）にも使われており、汎用ログとは目的が異なる
- STEP 2 で `Logger` と連携させるが、`SkillLogSystem` 自体は変更しない

### なぜ毎行 flush するか

- Godotの完全クラッシュ時に `_notification(NOTIFICATION_CRASH)` が呼ばれない場合がある
- バッファリングすると、クラッシュ直前のログが失われるリスクがある
- パフォーマンスへの影響は、1行のテキスト書き込みなので無視できるレベル

### なぜ Dictionary 形式ではなく文字列形式か

- GDScriptでは文字列のほうがシンプルで読みやすい
- ファイルへの flush が速い
- ログファイルを人間が直接読むことを前提としている
- 将来的に構造化が必要になったら STEP 3以降で対応

### 構造化ログ・turn・action_id について

ネットワーク対戦設計（`network_design.md`）では既にJSON構造化メッセージを定義済み:
```json
{"type": "spell_cast", "player_id": 0, "spell_id": 42, "target": {"type": "player", "id": 1}}
```

現在のGameLoggerは人間用テキスト形式であり、この構造とは異なる。
以下の3要素はネットワーク対戦・リプレイ実装時（STEP 6）に対応する:

| 要素 | 必要な理由 | 現在の代替手段 |
|------|-----------|--------------|
| 構造化ログ（key=value / JSON） | サーバー送信・検索・リプレイ | テキストログ + grep で十分 |
| turn（ターン番号） | 時系列特定 | `[GFM] ターン開始` 行で区切り可能 |
| action_id（連番） | 重複防止・順序保証 | シングルスレッド + flush で順序保証済み |

**方針**: GameLoggerとは別に「ActionLog（構造化）」をSTEP 6で新設する。GameLoggerはデバッグ・クラッシュ追跡用として残す。

### なぜゲーム開始ログにseedを入れないか

- 現在ゲームロジックでランダムシードを明示的に管理していない（`randi()` 等のグローバル乱数を使用）
- seedを記録しても、同じゲームを再現する仕組み（リプレイシステム）がない
- 将来リプレイシステムを導入する際に、まずseed管理の仕組みを入れてからログに記録する

### 古いログファイルの自動削除

- `user://logs/` に無制限にファイルが溜まるのを防止
- 最大10ファイル（10セッション分）を保持
- ユーザーの端末ストレージを圧迫しない
