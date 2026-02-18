# リファクタリング完了アーカイブ（Phase 0〜9）

**最終更新**: 2026-02-19
**対象期間**: 2026-02-13 〜 2026-02-19
**状態**: ✅ Phase 0〜9 完了

---

## 全体サマリー

### アーキテクチャ移行の成果

| 指標 | Before（Phase 0前） | After（Phase 9後） | 改善 |
|------|-------------------|-------------------|------|
| UI サービス | 0 | 4（551行） | 新規作成 |
| UI Signals | 4 | 37 | +33 |
| ハンドラー UI 分離 | 0/8 | 8/8 | 100% |
| 3段以上チェーンアクセス | 複数 | 0 | 100%解消 |
| private 外部アクセス | 複数 | 0 | 100%解消 |
| restore_current_phase | 58行（5分岐フォールバック） | 1行 | 状態ルーター解体 |
| UIManager 後方参照 | 6 | 5 | SPH削除 |
| SpellPhaseHandler 行数 | 982行 | 724行 | 258行削減 |
| SpellSystemContainer | なし（個別変数） | 10+2システム統合 | 新規 |

### 確立した設計原則

```
Business Logic Layer (GFM, Handlers, Systems)
    ↓ Signal ONLY
UI Service Layer (NavigationService, MessageService, CardSelectionService, InfoPanelService)
    ↓ Direct call（親→子）
UI Component Layer (GlobalActionButtons, GlobalCommentUI, CardSelectionUI, InfoPanels...)
```

**4つの絶対ルール**:
1. ビジネスロジック → UIサービス: **Signal のみ**
2. UIサービス → UIコンポーネント: **直接メソッド呼び出し**（親→子は正当）
3. UIコンポーネント → ビジネスロジック: **禁止**
4. UIサービス → UIサービス: **禁止**（調停は上位のみ）

**アンチパターン**:
- ServiceLocator化 / バンドルオブジェクト配布の禁止
- UIContext クラスは作らない（各ファイルに必要なサービスだけ渡す）
- サービス間横断の禁止

---

## Phase 一覧

### Phase 0〜4: アーキテクチャ基盤

| Phase | 内容 | 主な成果 | 実施日 |
|-------|------|---------|--------|
| 0 | ツリー構造定義 | TREE_STRUCTURE.md, dependency_map.md 作成 | 2026-02-13 |
| 1 | SpellSystemManager 導入 | 10+2個のスペルシステムを一元管理 | 2026-02-13 |
| 2 | シグナルリレー整備 | 横断的シグナル接続 12箇所 → 2箇所（83%削減） | 2026-02-14 |
| 3-B | BoardSystem3D SSoT 化 | creature_updated シグナルチェーン、UI自動更新 | 2026-02-14 |
| 3-A | SPH Strategy パターン化 | 22 Strategies, 109 effect_types | 2026-02-15 |
| 4 | SPH 責務分離 | 5サブフェーズ、~280行削減 | 2026-02-15 |

### Phase 5: 段階的最適化（2026-02-16）

| サブフェーズ | 内容 | 成果 |
|------------|------|------|
| 5-1 | SpellUIManager 新規作成 | 274行、14メソッド |
| 5-2 | CPUSpellAIContainer 新規作成 | 79行、4メソッド |
| 5-3 | グループ3重複参照削除 | 25行削減 |
| 5-5 | GameSystemManager 最適化 | 35行削減 |

### Phase 6: 完全UI層分離（2026-02-17）

| サブフェーズ | 内容 | Signal数 |
|------------|------|---------|
| 6-A | SpellPhaseHandler UI Signal分離 | 16 Signals（SpellFlow 11 + MysticArts 5） |
| 6-B | DicePhaseHandler UI分離 | 8 Signals |
| 6-C | Toll + Discard + Bankruptcy UI分離 | 9 Signals（Toll 2 + Discard 2 + Bankruptcy 5） |

### Phase 7: 依存逆転（2026-02-17）

| サブフェーズ | 内容 | 成果 |
|------------|------|------|
| 7-A | CPU AI パススルー除去 | SPH→CPU AI チェーンアクセス解消、直接注入 |
| 7-B | SPH UI依存逆転 | spell_ui_manager 直接呼び出しゼロ |

### Phase 8: UIManager 依存方向の正規化（2026-02-18）

| サブフェーズ | 内容 | 成果 |
|------------|------|------|
| 8-F | UIManager 内部4サービス分割 | NavigationService, MessageService, CardSelectionService, InfoPanelService |
| 8-G | ヘルパー サービス直接注入（5/6） | CSH 63%減、LAH 67%減 |
| 8-A | ItemPhaseHandler Signal化 | 4 Signals、ui_manager完全削除 |
| 8-B | DominioCommandHandler サービス注入 | 90→49 refs（46%削減） |
| 8-E | 兄弟システム サービス注入 | TileActionProcessor 74%、BattleSystem 100%削減 |
| 8-I | タイル系 context経由サービス | 6タイル完了 |
| 8-J | Spell系 サービス注入 | 3ファイル完了 |
| 8-K | 移動系 サービス移行 | 3ファイル、movement_controller ui_manager完全削除 |
| 8-L | 小規模ファイル サービス注入 | lap_system, cpu_turn_processor, target_ui_helper |
| 8-N | STSH + LSH サービス注入 | 28→18 refs, 9→2 refs |
| 8-O | SMA + DC サービス注入 | 46→29 refs, 31→11 refs |
| 8-M | CardSelectionService SSoT化 | プロパティ重複解消、card_selected統一 |
| 8-P | Spell系 3段チェーン解消 | 4ファイル、68→~34 refs |
| 8-D2 | private アクセス解消 | _ui_manager 外部アクセス 0件 |

**Phase 8 合計**: ~182 refs → ~94 refs（48%削減）

### Phase 9: 状態ルーター解体（2026-02-19）

| サブフェーズ | 内容 | 成果 |
|------------|------|------|
| 9-A | ui_tap_handler is_nav_state_saved() ガード追加 | フォールバック到達ゼロ確認 |
| 9-B | restore_current_phase フォールバック削除 | 58行→1行、spell_phase_handler_ref完全削除 |

### Phase 10-A: PlayerInfoService サービス化（2026-02-19）

| 内容 | 成果 |
|------|------|
| PlayerInfoService 新規作成 | scripts/ui_services/player_info_service.gd（描画更新のみ） |
| UIManager 統合 | 5番目のサービスとして追加、Facadeメソッド削除 |
| 呼び出し元変更 | 16ファイル・23箇所を player_info_service.update_panels() に変更 |
| BankruptcyHandler Signal | PlayerInfoService 経由に変更 |

---

## 延期・取り下げた項目と理由

| 項目 | 理由 |
|------|------|
| 8-H: UIコンポーネント逆参照除去 | コーディング規約変更（2段チェーン許容）により大部分不要 |
| 8-C: BankruptcyHandler パネル分離 | 56行、5 Signal化済み。投資対効果低 |
| UIManager 200行化 | 47委譲メソッド削除は47ファイル変更が必要。リスク対効果不釣り合い |
| card.gd 再帰探索解消 | 32箇所の大幅改修が必要。機能に問題なし |
| tutorial系移行 | チュートリアルシステム全体の再設計が前提 |

---

## Phase 8 最終評価（God Object 分析）

### UIManager の現状（Phase 9 後）

```
UIManager（~970行）
├─ UIルートノード管理（初期化・コンポーネント生成）  ✅ 正当
├─ 互換レイヤー/Facade（47委譲メソッド）            ⚠️ 移行期残存物
├─ 入力ディスパッチャー（on_card_button_pressed 27行）⚠️ card.gd 依存
├─ コンポーネント管理メソッド ~30個                   ✅ 正当
└─ 状態ルーター（restore_current_phase）            ✅ Phase 9 で解体済み
```

### UIManager 後方参照（5件）

| 参照先 | 用途 | 問題度 |
|-------|------|--------|
| game_flow_manager_ref | on_card_button_pressed 入力ロック、UIコンポーネント初期化 | 🔴 |
| board_system_ref | UIコンポーネント初期化（6箇所以上） | 🔴 |
| dominio_command_handler_ref | dominio_order_ui 初期化 | 🟡 |
| card_system_ref | Signal接続 | 🟢 片方向 |
| player_system_ref | update_player_info_panels | 🟢 片方向 |

### UIManager 未サービス化メソッド（残存）

| メソッド | 使用ファイル数 | サービス化候補 |
|---------|-------------|-------------|
| update_player_info_panels() | 8+ | PlayerInfoService |
| tap_target_manager | 2 | TapTargetService |
| on_card_button_pressed() | 1 (card.gd) | Signal化 |
| show_dominio_order_button() / hide | 3 | DominioService |
| set_message() | 3 | MessageService拡張 |
| show_win/lose_screen | 1 | GameResultService |
| toggle_debug_mode() | 1 | DebugService |
| show_level_up_ui() | 1 | LevelUpService |

---

## 設計制約（将来作業でも遵守）

1. **CardSelectionService の責務肥大化防止**: カード選択UIの操作代行に限定。フィルタ判定ロジックはビジネスロジック側
2. **PlayerInfoService は描画更新のみ**: ゲームロジック判定は絶対に持たせない
3. **signal await 移行は1ファイルずつ**: 一括置換禁止、選択→決定/キャンセル両パス確認

---

## 参照ドキュメント

- `docs/design/TREE_STRUCTURE.md` — ツリー構造
- `docs/design/dependency_map.md` — 依存関係マップ
- `docs/progress/refactoring_next_steps_2.md` — 今後の作業計画
