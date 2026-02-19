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

**ステータス**: 未着手

---

### A-2: GameResultHandler → GFM 逆参照の解消

**問題**: GameResultHandler が `game_flow_manager.change_phase()` を直接呼び出し（子→親の逆参照）

**方針**: Signal emit または Callable 注入で change_phase を呼べるようにする

**対象ファイル**:
- `scripts/game_flow/game_result_handler.gd`

**ステータス**: 未着手

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

**対象ファイル**:
- `scripts/game_flow/spell_phase_handler.gd`
- `scripts/game_flow/spell_flow_handler.gd`（`_game_flow_manager` 23行）
- `scripts/game_flow/dice_phase_handler.gd`（`game_flow_manager` 20行）

**ステータス**: 未着手

---

## Phase B: UIManager 残存参照の削減（HIGH）

game_flow/ 配下でまだ `ui_manager` を直接参照しているファイル。
Phase 8 で開始したサービス直接注入を完遂する。

### B-1: DominioCommandHandler（73行 → 目標: 0）

**最大の課題**。6種以上のサービスを直接使用。

**現在の参照内訳（推定）**:
- MessageService 系: ~20行
- NavigationService 系: ~15行
- CardSelectionService 系: ~10行
- InfoPanelService 系: ~5行
- hand_display / dominio_order_ui: ~15行
- その他（ui_layer, player_info_service）: ~8行

**方針**: Phase 8-B で一部移行済み。残りのサービス参照を全て直接注入に置換。

**ステータス**: 未着手

---

### B-2: LapSystem（23行 → 目標: 0）

**方針**: MessageService 直接注入 + ui_layer 注入で完全分離

**ステータス**: 未着手

---

### B-3: TileBattleExecutor / TileSummonExecutor（14行+11行 → 目標: 0）

**方針**: Phase 8 で部分移行済み。残りを完遂。

**ステータス**: 未着手

---

### B-4: SpellTargetSelectionHandler（12行 → 目標: 0）

**方針**: NavigationService 直接注入で `_ui_manager` 削除

**ステータス**: 未着手

---

### B-5: CardSelectionHandler（10行 → 目標: 0）

**方針**: hand_display 等の残存参照をサービス経由に

**ステータス**: 未着手

---

### B-6: SpellUIManager（28行 → 目標: 0）

**方針**: UI層なので UIManager 参照は許容度が高いが、可能な限りサービス直接注入に

**ステータス**: 未着手

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
