# リファクタリング作業計画

**最終更新**: 2026-02-20
**前提**: Phase 0〜12 完了済み（アーキテクチャ移行・UI層分離・UIEventHub・BankruptcyHandler分離）

---

## 現状分析（2026-02-20 参照方向総点検）

Phase 0〜12 で UI Signal 駆動化・サービス分割・チェーンアクセス削減を進めたが、
**参照方向の問題**がまだ相当数残っている。

### 問題サマリー

| 分類 | 件数 | 深刻度 |
|------|------|--------|
| 相互参照（循環） | 4組 | CRITICAL |
| UIManager 残存参照（game_flow/配下） | 7ファイル/~170行 | HIGH |
| GFM 逆参照チェーン（子→親→兄弟） | ~20箇所 | HIGH |
| Spell系の逆参照（GFM/UIManager） | 5ファイル | MEDIUM |
| CPU AI 層の GFM 参照 | ~5ファイル | LOW（Context化済み） |
| tutorial系 | 1ファイル | 保留 |

---

## Phase A: 相互参照の解消（CRITICAL）

最も深刻な循環参照を先に潰す。

### A-1: ItemPhaseHandler 遅延取得の解消

**問題**: DCH と TileBattleExecutor が `game_flow_manager.item_phase_handler` を遅延取得（兄弟間の逆チェーン）

```gdscript
# 現在（アンチパターン）
var iph = game_flow_manager.item_phase_handler
iph.start_item_selection(...)
```

**方針**: GSM で ItemPhaseHandler を直接注入

**対象ファイル**:
- `scripts/game_flow/dominio_command_handler.gd`
- `scripts/game_flow/tile_battle_executor.gd`

**ステータス**: ✅ 完了（`6decb4b`）

---

### A-2: GameResultHandler → GFM 逆参照の解消

**問題**: GameResultHandler が `game_flow_manager.change_phase()` を直接呼び出し（子→親の逆参照）

**方針**: Signal emit または Callable 注入で change_phase を呼べるようにする

**対象ファイル**:
- `scripts/game_flow/game_result_handler.gd`

**ステータス**: ✅ 完了（`8235a7e` + `43d27a3` inject_callbacks統一）

---

### A-3: SpellPhaseHandler → GFM 相互参照の整理

**問題**: SPH が `game_flow_manager` を保持し、以下の用途でランタイム使用:
- `is_cpu_player()` 判定
- `change_phase()` 呼び出し
- `spell_container` 経由のアクセス

**方針**:
- `is_cpu_player` → Callable 注入
- `change_phase` → Callable 注入
- `spell_container` → 直接参照注入（SPH初期化時に渡す）

**サブフェーズ**:
- A-3a: is_cpu_player() Callable化 → ✅ 完了（`5480027`）
- A-3b: spell_draw/spell_container 直接注入 → ✅ 完了（`43d27a3`）
- A-3c: unlock_input / roll_dice Callable化 → ✅ 完了（`25bde52`）
- A-3d: change_phase / game_stats Callable化 → ✅ 完了（`25bde52`）

**成果**:
- SpellFlowHandler: `_game_flow_manager` 完全削除
- DicePhaseHandler: `game_flow_manager` 完全削除
- SpellUIManager: GFMチェーンアクセス解消
- CSH: `spell_phase_handler` 完全削除

**ステータス**: ✅ Phase A-3 全完了

---

## Phase B: UIManager 残存参照の削減（HIGH）

game_flow/ 配下でまだ `ui_manager` を直接参照しているファイル。
Phase 8 で開始したサービス直接注入を完遂する。

### B-0: GameResultHandler（ui_manager 未使用変数削除）

**方針**: ui_manager 変数削除 + ランタイム参照4箇所を Callable 注入
**ステータス**: ✅ 完了（`8f0a1bd`）

---

### B-1+B-3: DominioCommandHandler + helpers（ui_manager 完全除去）

**対象**: DCH本体3箇所 + land_action_helper 15箇所 + land_selection_helper 1箇所

**方針**:
- `var ui_manager` 変数を完全削除
- `_player_info_service`, `_ui_layer` 直接参照を追加
- `inject_ui_callbacks()` で7つのUI Callable を一括注入
- helpers の `handler.ui_manager.*` チェーンアクセスを全て Callable/Service に置換

**ステータス**: ✅ 完了（`e3bd268`）

---

### B-2: LapSystem（ui_manager 完全削除）

**方針**: `_ui_layer` 直接参照 + `_show_dominio_order_button_cb` Callable + フォールバック削除
**ステータス**: ✅ 完了（`8f0a1bd`）

---

### B-3: TileBattleExecutor / TileSummonExecutor（Service化済み）

**現状**: setup時のサービス解決のみで `ui_manager` 保持。ランタイムは Service 経由のみ。
**ステータス**: 低優先（Service化済みのため実害なし）

---

### B-4: SpellTargetSelectionHandler（Service化済み）

**現状**: setup時のサービス解決のみで `ui_manager` 保持。ランタイムは Service 経由のみ。
**ステータス**: 低優先（Service化済みのため実害なし）

---

### B-5: CardSelectionHandler（Service化済み）

**現状**: setup時のサービス解決のみで `ui_manager` 保持。ランタイムは Service 経由のみ。
**ステータス**: 低優先（Service化済みのため実害なし）

---

### B-6: SpellUIManager（設計上の UIManager 橋渡し層）

**方針**: UI Signal リスナーとして UIManager 参照は設計上必要。現状維持。
**ステータス**: 現状維持（26箇所、全て設計上正当）

---

## Phase C: Spell系の逆参照削減（MEDIUM）

Spell システムが game_flow_manager / ui_manager を直接参照している問題。

### C-1: spell_curse → game_flow_manager

**用途**: ゲーム統計参照、magic_tile_mode 判定
**方針**: 必要な情報を Context または Callable で注入

---

### C-2: spell_world_curse → ui_manager

**用途**: player_info_service.update_panels()
**方針**: Signal emit に変更

---

### C-3: spell_player_move → game_flow_manager

**用途**: lap_system 参照
**方針**: lap_system を直接注入

---

### C-4: spell_draw 系 → ui_manager

**用途**: SpellAndMysticUI 参照
**方針**: 必要なサービスを直接注入

---

## Phase D: GFM チェーンアクセスの解消（MEDIUM）

`spell_phase_handler.game_flow_manager.xxx` のような多段チェーンアクセス。

### D-1: CardSelectionHandler のチェーンアクセス

```gdscript
# 現在
spell_phase_handler.game_flow_manager.spell_container.spell_draw.xxx
```

**方針**: spell_container を直接注入

---

### D-2: SpellFlowHandler の多段参照

**方針**: `_game_flow_manager` の各用途を Callable / 直接参照に分解

---

## 推奨実行順序

| 順番 | Phase | 内容 | 深刻度 | 規模 |
|------|-------|------|--------|------|
| 1 | **A-1** | ItemPhaseHandler 遅延取得解消 | CRITICAL | 小 |
| 2 | **A-2** | GameResultHandler 逆参照解消 | CRITICAL | 小 |
| 3 | **A-3** | SPH → GFM 相互参照整理 | CRITICAL | 中 |
| 4 | **B-1** | DCH ui_manager 73行削減 | HIGH | 大 |
| 5 | **B-2** | LapSystem ui_manager 削除 | HIGH | 小 |
| 6 | **B-3** | TileBattle/Summon Executor | HIGH | 中 |
| 7 | **B-4** | STSH ui_manager 削除 | HIGH | 小 |
| 8 | **B-5** | CSH ui_manager 削除 | HIGH | 小 |
| 9 | **B-6** | SpellUIManager ui_manager 削減 | HIGH | 中 |
| 10 | **C-1〜4** | Spell系逆参照削減 | MEDIUM | 中 |
| 11 | **D-1〜2** | GFM チェーンアクセス解消 | MEDIUM | 中 |

---

## 保留事項

| 項目 | 理由 |
|------|------|
| tutorial_manager の UIManager 直接参照 | チュートリアル再設計が前提 |
| CPU AI 層の GFM 参照 | CPUAIContext パターンで既に整理済み、実害低 |

---

## 完了済みアーカイブ

Phase 0〜12 の詳細は `docs/progress/daily_log.md` を参照。

| Phase | 内容 | 完了日 |
|-------|------|--------|
| 0〜9 | アーキテクチャ移行・UI層分離・状態ルーター解体 | 〜2026-02-19 |
| 10 | PlayerInfoService・card.gd改善・双方向参照削減・デッドコード削除 | 2026-02-19 |
| 11 | UIManager適正化（ファサード化・Node整理・デッドコード削除） | 2026-02-20 |
| UIEventHub | UI→ロジック間イベント駆動化 | 2026-02-20 |
| 12 | BankruptcyHandler パネル分離 + TapTargetManager 直接注入 | 2026-02-20 |
| バグ修正 | ナビ状態・ボタン消失・GDScript警告等（7件） | 2026-02-20 |
