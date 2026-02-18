# Phase 8 UIManager 最終評価レポート

**評価日**: 2026-02-18
**評価対象**: `scripts/ui_manager.gd`（1,024行、93メソッド）
**Phase 8 実施期間**: 2026-02-18（15サブフェーズ完了）

---

## 1. 神オブジェクト（God Object）評価

### 1.1 数値指標

| 指標 | Phase 8 前（推定） | Phase 8 後 | 改善率 | 備考 |
|------|-------------------|-----------|--------|------|
| **総行数** | ~1,094 | 1,024 | 6%減 | 委譲プロパティ追加で相殺 |
| **メソッド数** | ~87 | 93 | +6 | getter/setter 追加のため |
| **シグナル** | 4 | 4 | 変化なし | |
| **外部システム参照** | 6 | 6 | 変化なし | 後述 |
| **UIコンポーネント管理** | 15 | 15 | 変化なし | 正当な親→子 |
| **責務カテゴリ数** | 10+ | 10 | — | 後述 |
| **依存ファイル数** | 54 | 47（実質） | 13%減 | backup除外 |
| **被参照数（全体）** | — | 955 | — | 47ファイル合計 |

### 1.2 UIManager の行数が減っていない理由

Phase 8 の目標は「行数削減」ではなく「**依存方向の固定**」。UIManager 自体の行数は以下の理由で微減にとどまった：

1. **サービス委譲プロパティの追加**（+50行）: `card_selection_filter` 等5プロパティの getter/setter
2. **サービス公開アクセサの追加**（+8行）: `message_service`, `navigation_service` 等
3. **委譲メソッドは残存**（~47メソッド）: UIManager が依然 facade として機能しており、外部から `ui_manager.show_toast()` を呼ぶコードが多数残存

**本質的な改善**: 4つのサービス（計551行）に責務を移転し、外部ファイルからはサービスへの直接参照が可能になった。UIManager 経由でもサービス直接でも呼べる移行期の状態。

### 1.3 責務の分類（10カテゴリ）

| # | カテゴリ | メソッド数 | 行数（概算） | 評価 |
|---|---------|----------|------------|------|
| 1 | **UIコンポーネント生成・初期化** | 3 | ~110 | ✅ 正当（親ノードの責務） |
| 2 | **シグナル接続** | 1 | ~40 | ✅ 正当 |
| 3 | **メッセージ委譲** | 11 | ~55 | ⚠️ 純粋委譲（facade 残存） |
| 4 | **ナビゲーション委譲** | 14 | ~80 | ⚠️ 純粋委譲 + `restore_current_phase`(44行) |
| 5 | **カード選択委譲** | 6 | ~30 | ⚠️ 純粋委譲 |
| 6 | **情報パネル委譲** | 7 | ~60 | ⚠️ `show_card_info` に37行のロジック |
| 7 | **プレイヤー情報パネル** | 4 | ~40 | ✅ 正当（UIManager 固有） |
| 8 | **ドミニオUI** | 7 | ~50 | ✅ コンポーネント管理 |
| 9 | **レベルアップ/デバッグUI** | 5 | ~30 | ✅ コンポーネント管理 |
| 10 | **入力処理/カメラ連携** | 3 | ~40 | ⚠️ `on_card_button_pressed`(27行) |

**純粋委譲メソッド**: 47/93（50%）
**ビジネスロジック含有メソッド**: 6/93（6%）
**正当なコンポーネント管理**: 40/93（43%）

### 1.4 神オブジェクト判定

| 判定項目 | Phase 8 前 | Phase 8 後 | 判定 |
|---------|-----------|-----------|------|
| メソッド数 > 20 | ❌ 87 | ❌ 93 | **形式上は未改善**（委譲メソッド含む） |
| 変数 > 15 | ❌ ~35 | ❌ 38 | **形式上は未改善**（コンポーネント参照） |
| 責務 > 3 | ❌ 10+ | ❌ 10 | **未改善** |
| Fan-in > 10 | ❌ 54 | ❌ 47 | **微改善** |
| 後方参照あり | ❌ 6 | ❌ 6 | **未改善** |

**結論**: **God Object の中心ロジック（UI操作）は4サービスに分離済み。ただし Facade 肥大 + 状態ルーターが残存。**

UIManager の現在の正確な姿は：

```
UIManager = UIルートノード管理（正当）
		   + 互換レイヤー/Facade（47委譲メソッド、移行期の残存物）
		   + 状態ルーター（restore_current_phase: 5フェーズの状態判定）
		   + 入力ディスパッチャー（on_card_button_pressed: 入力ロック+分岐判定）
```

「実質分離済み」と言える状態は「UIManager = UIのルートノード管理のみ」になった時。
現時点では **設計的には成功、構造的には移行中** が正確な表現。

---

## 2. 兄弟参照の異常検出

### 2.1 UIManager が保持する逆方向参照（6件）

UIManager は子ノード（GSM が生成）だが、自身を生成した上位システムを参照している：

| 参照先 | 行 | 使用箇所 | 双方向か | 問題度 |
|-------|-----|---------|---------|--------|
| `game_flow_manager_ref` | L57 | `on_card_button_pressed()` input lock, `restore_current_phase()` | **双方向** | 🔴 |
| `board_system_ref` | L56 | `on_creature_updated()`, `restore_current_phase()` direction selector | **双方向** | 🔴 |
| `spell_phase_handler_ref` | L58 | `restore_current_phase()` spell phase check | **双方向** | 🟡 |
| `dominio_command_handler_ref` | L59 | `restore_current_phase()` dominio state check, `show_dominio_order_button()` | **双方向** | 🟡 |
| `card_system_ref` | L54 | `connect_card_system_signals()` | 片方向 | 🟢 |
| `player_system_ref` | L55 | `update_player_info_panels()`, `get_player_ranking()` | 片方向 | 🟢 |

**双方向参照の内訳**:
- GFM → `ui_manager` 保持（コーディネーター） AND UIManager → `game_flow_manager_ref`
- BoardSystem3D → UIManager 経由の通知 AND UIManager → `board_system_ref`

### 2.2 外部から UIManager を参照するファイル分類

**47ファイル（955参照）を性質別に分類**:

#### ✅ 正当な参照（319 refs, 15ファイル）

| 分類 | ファイル数 | 代表 | 参照数 | 理由 |
|------|----------|------|--------|------|
| UIコンポーネント（親参照） | 9 | card_selection_ui(83), creature_info_panel(30) | 218 | 子→親は正当 |
| UIハンドラー（サブシステム） | 3 | ui_tap_handler(21), ui_win_screen(15) | 45 | UIManager の内部委譲先 |
| SpellUIManager | 1 | spell_ui_manager(90) | 90 | UIManager の委譲サービス |
| 初期化コーディネーター | 1 | game_system_manager(133) | 133 | 初期化は正当 |
| ゲームフローコーディネーター | 1 | game_flow_manager(39) | 39 | UIManager の所有者 |

#### ⚠️ サービス移行済みだが残存する参照（268 refs, 17ファイル）

Phase 8 でサービス直接注入を実施済み。`ui_manager.` 経由の参照は徐々にサービス直接に移行中。

| ファイル | 参照数 | 移行済みサービス | 残存理由 |
|---------|--------|---------------|---------|
| card_selection_handler.gd | 53 | 4サービス | `update_player_info_panels` 等の未サービス化メソッド |
| land_action_helper.gd | 25 | 4サービス | 同上 |
| spell_mystic_arts.gd | 20 | 3サービス getter | `tap_target_manager` 参照 |
| spell_target_selection_handler.gd | 18 | 2サービス | カード選択UI直接参照 |
| special_tile_system.gd | 15 | 3サービス | `update_player_info_panels` |
| lap_system.gd | 14 | 1サービス | `update_player_info_panels` |
| target_ui_helper.gd | 13 | info_panel getter | フォールバックパス |
| spell_flow_handler.gd | 12 | Signal駆動 | spell_ui_manager 経由 |
| debug_controller.gd | 11 | 2サービス | `toggle_debug_mode` 等 |
| board_system_3d.gd | 10 | 1サービス | `update_player_info_panels` |
| game_result_handler.gd | 10 | — | 勝敗画面表示 |
| dominio_command_handler.gd | 9 | 4サービス | `show_dominio_order_button` |
| tile_action_processor.gd | 9 | 2サービス | `update_player_info_panels` |
| その他4ファイル | ~25 | 部分的 | 個別メソッド |

**共通残存パターン**: `update_player_info_panels()` — 未サービス化のためサービス移行できない。

#### ❌ 要注意の参照（80 refs, 4ファイル）

| ファイル | 参照数 | 問題 | 深刻度 |
|---------|--------|------|--------|
| **card.gd** | 32 | **再帰的な親ノード探索で UIManager を取得** — アンチパターン | 🔴 高 |
| **tutorial_manager.gd** | 22 | チュートリアルからの直接 UI 操作 | 🟡 中 |
| **explanation_mode.gd** | 22 | 同上 | 🟡 中 |
| **spell_draw.gd** | 5 | レガシー参照 | 🟢 低 |

### 2.3 異常な兄弟参照の有無

**結論: 深刻な異常はなし。ただし以下の2点は改善余地あり。**

1. **card.gd の再帰的親探索**（32参照）: `get_parent()` をループして UIManager を探す。これは UI コンポーネントの配置に依存する脆い実装。
2. **UIManager の後方参照4件**（GFM, BoardSystem3D, SPH, DCH）: `restore_current_phase()` がこれらを参照しているため残存。この関数を各ハンドラーに委譲すれば解消可能。

---

## 3. 元の計画との乖離

### 3.1 Phase 8 ターゲットアーキテクチャ（計画時）

```
UIManager（~200行、コーディネーターのみ）
├─ _ready(): サービス生成
├─ create_ui(): UIコンポーネントのライフサイクル管理
├─ get_*_service(): 個別サービスの getter（GSM が配布に使用）
└─ UIレイヤー管理
```

### 3.2 実際の到達点

```
UIManager（1,024行）
├─ _ready(): サービス生成 + UIコンポーネント生成（~110行） ✅
├─ connect_ui_signals(): シグナル接続（~40行） ✅
├─ 委譲メソッド 47個（~250行） ⚠️ facade として残存
├─ restore_current_phase(): 44行のフェーズ判定ロジック ❌
├─ on_card_button_pressed(): 27行の分岐ロジック ❌
├─ show_card_info(): 37行の条件付きUI操作 ❌
├─ コンポーネント管理メソッド ~30個（~200行） ✅ 正当
├─ プロパティ getter/setter（~70行） ✅ サービス委譲
└─ 入力処理・カメラ連携（~40行） ⚠️
```

### 3.3 乖離の原因分析

| 項目 | 計画 | 実際 | 乖離理由 |
|------|------|------|---------|
| **行数** | ~200行 | 1,024行 | 委譲メソッド47個が残存。外部が `ui_manager.show_toast()` を呼ぶ限り削除不可 |
| **委譲メソッド** | 0（サービスに直接アクセス） | 47 | 全47ファイルの呼び出しを一斉変更するリスクが高く、段階的移行を選択 |
| **後方参照** | 0 | 6 | `restore_current_phase()` の解体が未実施。5フェーズの状態判定がUIManager に残存 |
| **`restore_current_phase()`** | 各ハンドラーに委譲 | UIManager に44行残存 | ドミニオ/スペル/カード選択/移動の4フェーズの状態を知る必要があり、分解の設計が複雑 |
| **`on_card_button_pressed()`** | CardSelectionService に移行 | UIManager に27行残存 | card.gd の再帰的親探索が UIManager を前提としているため |
| **サービス4つ** | 計画通り | ✅ 計画通り（551行） | MessageService, NavigationService, CardSelectionService, InfoPanelService |

### 3.4 達成率

| 目標 | 達成度 | 備考 |
|------|-------|------|
| **4サービス分割** | ✅ 100% | 551行、58メソッド |
| **ハンドラー Signal 駆動化** | ✅ 100% | 8/8 ハンドラー完了、37 Signals |
| **外部ファイルのサービス直接注入** | ✅ 80% | 17ファイルで実施済み。`update_player_info_panels` 依存が残存 |
| **CardSelectionService SSoT** | ✅ 100% | プロパティ重複解消、card_selected シグナル統一 |
| **3段チェーン解消** | ✅ 100% | spell系、helper系 全て解消 |
| **private アクセス解消** | ✅ 100% | `_ui_manager` 外部アクセス 0件 |
| **UIManager 200行化** | ❌ 20% | 1,024行。委譲メソッド削除には全ファイル一斉移行が必要 |
| **後方参照 0** | ❌ 0% | 6件全て残存。`restore_current_phase()` 解体が前提 |

---

## 4. 延期・取りやめた項目と理由

### 4.1 延期した Phase

| Phase | 内容 | 延期理由 |
|-------|------|---------|
| **8-H** | UIコンポーネント逆参照除去 | コーディング規約変更（2段チェーン許容）により**大部分が不要**になった。hand_display の `get_parent()` は 8-M で解消済み。ui_tap_handler, global_comment_ui の UI→Logic 参照は影響小 |
| **8-C** | BankruptcyHandler パネル分離 | 56行の小規模コンポーネント。既に 5 Signal 化済みで機能上の問題なし。投資対効果が低い |

### 4.2 計画から取り下げた目標

| 目標 | 取り下げ理由 |
|------|------------|
| **UIManager 200行化** | 委譲メソッド47個の削除には、47ファイルの `ui_manager.show_toast()` を `message_service.show_toast()` に一斉変更する必要がある。リグレッションリスクが高く、現時点でのメリット（関数呼び出しが1段減るだけ）に対してコストが不釣り合い |
| **後方参照の完全削除** | `restore_current_phase()` は5フェーズの状態を判定する複雑なルーティングロジック。各ハンドラーが `restore_navigation()` を自律的に呼ぶ仕組みに変更するには、カード閲覧モードの設計変更が必要。Phase 8 のスコープを超える |
| **card.gd 再帰探索の解消** | card.gd は UIManager を `get_parent()` ループで探索する。CardSelectionService の直接注入に変更するには card.gd（32箇所）の大幅改修が必要。機能に問題がないため延期 |
| **tutorial 系の移行** | tutorial_manager.gd(22), explanation_mode.gd(22) は直接 UIManager を操作する。チュートリアルシステム全体の再設計が必要であり、Phase 8 のスコープ外 |

### 4.3 コーディング規約変更の影響

2026-02-18 にコーディング規約を3点変更し、Phase 8 の必要作業が大幅に縮小された：

| 規約変更 | 影響 |
|---------|------|
| **チェーンアクセス 2段まで許容** | `ui_manager.message_service.show_toast()` が合法化。多くのサービス移行が「推奨」から「必須でない」に変わった |
| **兄弟参照の表示系は許容** | dominio_order_ui → ui_manager の `show_card_info()` 等が正当化された |
| **ドメイン機能群の密結合許容** | battle/dominio 内部の UIManager 参照が許容された |

---

## 5. Phase 8 の実績と成果

### 5.1 完了した15サブフェーズ

| Phase | 内容 | 主な成果 |
|-------|------|---------|
| **8-F** | UIManager 内部4サービス分割 | 551行を4サービスに分離 |
| **8-G** | ヘルパーファイル サービス直接注入 | CSH 63%減、LAH 67%減 |
| **8-A** | ItemPhaseHandler Signal化 | ui_manager 完全削除、4 Signals |
| **8-B** | DominioCommandHandler サービス注入 | 90→49 refs (46%減) |
| **8-E** | 兄弟システム サービス注入 | BattleSystem ui_manager 100%排除 |
| **8-I** | タイル系 ui_manager → サービス移行 | 6タイル完了 |
| **8-J** | Spell系ファイル サービス注入 | 3ファイル完了 |
| **8-K** | 移動系 ui_manager → サービス移行 | 3ファイル完了 |
| **8-L** | 小規模ファイル サービス注入 | 3ファイル完了 |
| **8-N** | STSH + LSH サービス注入 | 28→18, 9→2 refs |
| **8-O** | spell_mystic_arts + debug_controller | 46→29, 31→11 refs |
| **8-M** | CardSelectionService SSoT化 | プロパティ重複解消、card_selected 統一 |
| **8-P** | Spell系 3段チェーン解消 | 4ファイル、43行純減 |
| **8-D2** | private アクセス解消 | `_ui_manager` 外部アクセス 0件 |
| **8-D** | 最終評価 | 本ドキュメント |

### 5.2 定量的成果

| 指標 | Before | After | 改善 |
|------|--------|-------|------|
| UI サービス | 0 | 4（551行） | 新規 |
| UI Signals | 4 | 37 | +33 |
| ハンドラー UI 分離 | 0/8 | 8/8 | 100% |
| 3段以上チェーンアクセス | 複数 | 0 | 100%解消 |
| private 外部アクセス | 複数 | 0 | 100%解消 |
| `set_message()` バグ | 3箇所 | 0 | 修正済み |
| `game_stats` 未注入バグ | 1箇所 | 0 | 修正済み |

### 5.3 総合評価

**Phase 8 の状態: 設計的には成功、構造的には移行中。**

**達成したこと（アーキテクチャ的に重要な改善）**:
- 依存方向を固定した（Signal 駆動 37個、サービス直接注入 17ファイル）
- private アクセスをゼロにした
- 3段チェーンを解消した
- UIの中心ロジック（表示・ナビ・カード選択・情報パネル）を4サービスに分離した

**まだ達成していないこと**:
- UIManager は依然として **Facade 肥大**（47委譲メソッド）+ **状態ルーター**（`restore_current_phase` 44行）+ **入力ディスパッチャー**（`on_card_button_pressed` 27行）
- 後方参照6件が全て残存（うち `restore_current_phase` が3件の根源）
- 「UIManager = UIのルートノード管理のみ」には到達していない

**現在の分岐点**:

UIManager は今「安全な互換期」にある。プロダクト開発としては正しい状態。
次に進むなら2つの選択肢がある:

1. **安全路線**: このまま互換レイヤーを維持し、新機能開発に注力
2. **完成路線**: `restore_current_phase` を解体し、各ハンドラーが自律的にナビ復帰する構造に変更

完成路線に進む場合、最大のレバレッジポイントは `restore_current_phase()` の解体。
これ1つを解体すれば後方参照3件（SPH, DCH, BoardSystem）が削除可能になり、UIManager から状態ルーターの責務が消える。

### 5.4 restore_current_phase フォールバック計測結果（2026-02-18）

フォールバック5分岐にログを入れて実測した結果:

| 分岐 | 到達 | 発生条件 |
|------|------|---------|
| 分岐1: ドミニオ | ✅ 到達 | ドミニオコマンド中にカード情報閲覧→閉じる |
| 分岐2: スペルフェーズ | ✅ 到達（複数回） | スペル確認中・ダイスフェーズ中にカード情報閲覧→閉じる |
| 分岐3: カード選択UI | ✅ 到達 | 召喚/捨てる等の選択中にカード情報閲覧→閉じる |
| 分岐4: 方向/分岐選択 | ✅ 到達 | 移動方向選択中にクリーチャー情報閲覧→閉じる |
| 分岐5: 該当なし | 未確認 | — |

**結論: 4/5分岐が実際に使用されている。フォールバックは現在も活発に使われている安全装置であり、単純削除は不可能。**

解体するには先に「全ての情報パネル表示経路で `save_navigation_state()` が呼ばれる」設計変更が必要。
`show_card_info_only()` が「ナビに触らない」設計のため、この経路で開いたパネルを空タップ等で閉じるとフォールバックに到達する。

計測ログは `ui_manager.gd` に `[FALLBACK]` で残存中（コミット 6c6ad80）。

---

## 6. 将来の改善候補（優先順位順）

### 6.1 状態ルーター解体（Phase 9 候補）

`restore_current_phase()` は UIManager を状態ルーターにしている最大要因。
**計測により4/5分岐が活発に使用されていることが判明**。単純削除は不可。

解体に必要な前提条件:
1. `show_card_info_only()` 経由でもナビ状態を保存する設計変更
2. 全経路で `save_navigation_state()` が呼ばれることの保証
3. フォールバック到達がゼロになることの再計測

| # | 内容 | 効果 | リスク | 推奨時期 |
|---|------|------|--------|---------|
| 1 | **`restore_current_phase()` 解体** | 後方参照3件削除（SPH, DCH, BoardSystem）、状態ルーター責務消滅 | **高**（情報パネル全経路の設計変更が前提） | Phase 9 |
| 2 | **`on_card_button_pressed()` 移行** | 後方参照1件削除（GFM）、入力ディスパッチャー責務消滅 | 中（card.gd 改修前提） | Phase 9 |

### 6.2 Facade 削減（Phase 10 候補）

| # | 内容 | 効果 | リスク | 推奨時期 |
|---|------|------|--------|---------|
| 3 | `update_player_info_panels()` サービス化 | 残存参照の最大共通要因を解消 | 低 | Phase 10 |
| 4 | card.gd 再帰探索の解消 | 32参照削除、脆い実装の改善 | 中（card.gd 改修） | Phase 10 |
| 5 | 委譲メソッド一斉削除 | UIManager ~400行削減 | 高（47ファイル変更） | Phase 10+ |
| 6 | tutorial 系移行 | 44参照削除 | 高（チュートリアル再設計） | 別プロジェクト |
