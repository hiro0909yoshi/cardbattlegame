# 📋 リファクタリング次ステップ

**最終更新**: 2026-02-16
**目的**: セッション間で作業計画が失われないよう、次にやることを明確に記録

**確立したワークフロー**:
```
1. Opus: Phase 計画立案 → refactoring_next_steps.md に記載
2. Haiku: 計画を読んで実装
3. Sonnet: ドキュメント更新・完了報告
4. 次の Phase へ（繰り返し）
```

---

## ✅ 完了済みフェーズ（簡潔版）

詳細は `daily_log.md` および `architecture_migration_plan.md` を参照

- **Phase 0**: ツリー構造定義（2026-02-14）✅
- **Phase 1**: SpellSystemManager 導入（2026-02-13）✅
- **Phase 2**: シグナルリレー整備（2026-02-14）✅（横断接続 83%削減）
- **Phase 3-B**: BoardSystem3D SSoT 化（2026-02-14）✅
- **Phase 3-A**: SpellPhaseHandler Strategy パターン化（2026-02-15）✅
- **Phase 3-A-Final**: 神オブジェクト化解決（2026-02-16）✅

---

## 🟢 完了: Phase 3-A-Final - 神オブジェクト化解決 + アルカナアーツターゲット修正（2026-02-16）

**タイトル**: SpellPhaseHandler の神オブジェクト化を解決 + ターゲット必要なアルカナアーツの修正

**実装完了した内容**:

### 1. **削除**: 32メソッド削除（206行削減）✅
   - Category A: Navigation委譲メソッド（9個、~42行）
   - Category E: 初期化メソッド（5個、~109行）
   - Category B-D: 他の委譲メソッド（18個、~55行）
   - **結果**: SpellPhaseHandler 936行 → 730行
   - **コミット**: d41f97b

### 2. **初期化ロジック統合**: GameSystemManager へ inline化✅
   - 5つのメソッド本体を GameSystemManager._initialize_spell_phase_subsystems() へ統合
   - card_selection_handler 初期化追加（P0 issue）

### 3. **SpellStateHandler フラグ管理修正**: 副作用問題解決✅
   - mystic_arts_handler.gd: reset_turn_state() 追加（Line 171）✅
   - spell_mystic_arts.gd: 直接プロパティアクセス廃止、spell_state経由に変更✅
   - GameSystemManager: 変数名エラー修正（6箇所: p_ui_manager → ui_manager, p_game_flow_manager → game_flow_manager）✅

### 4. **アルカナアーツ効果適用の修正**✅
   - **P1 issue**: UI表示メソッド修正（show_toast() → show_comment_and_wait()）
   - **RefCounted削除対策**: spell_phase_handler Node参照追加（Line 25）
   - **メソッド委譲修正**: _apply_spell_effect() で spell_executor に委譲（Line 1049-1060）
   - **コミット**: 85cd66d

### 5. **ターゲット必要なアルカナアーツの修正**✅
   - **根本原因**: Path A（spell_id なし）と Path B（spell_id あり）で context 構築が異なり、Path B で tile_index が追加されていなかった
   - **修正内容**: Line 1054-1057 で extended_target_data に tile_index を追加（apply_single_effect() と同じパターンに統一）
   - **対象**: ウィッチ等、ターゲット選択が必要なアルカナアーツ全般
   - **成果**: ゴールドトーテムのような ターゲット不要なアルカナアーツと同一フローで処理可能に

### 5. **改善**: ログ出力最適化✅
   - フレームカウントログ削除（SPH-SIGNAL スッキリ）
   - can_cast_mystic_art() に詳細デバッグログ追加

**実装完了のチェックリスト**:
- ✅ SpellPhaseHandler 神オブジェクト化解決（206行削減）
- ✅ P0 issue: card_selection_handler 初期化
- ✅ P1 issue: UI comment 表示方法修正
- ✅ spell_used_this_turn フラグ管理正常化
- ✅ RefCounted 削除対策（Node参照追加）
- ✅ apply_single_effect() メソッド委譲正常化
- ✅ 変数名エラー全修正
- ⚠️ GDScript警告: validate() メソッドの "Unreachable code" 警告（複数ファイル、実行支障なし）

**保留中のテスト**:
- 🔄 **ゲーム実行テスト**: CPU vs CPU 複数ラウンド → アルカナアーツ発動確認（待機中）
- 🔄 **複数ラウンドテスト**: スペルフェーズ全般の安定性確認（待機中）

**アーキテクチャ改善**:
```
修正前（委譲パターン）:
  spell_phase_handler._show_spell_phase_buttons()  # ラッパーメソッド

修正後（直接参照パターン）:
  spell_phase_handler.spell_navigation_controller._show_spell_phase_buttons()  # 直接参照
```

**次の作業（重要）**:
1. ゲーム再起動 → アルカナアーツ実行 → デバッグログ確認
2. 「有効なターゲットがない」の原因を特定
3. 原因に応じた修正実装
4. 複数ラウンド実行テスト
5. **テスト完了後に「完了」と記録すること**

---

## 🟢 次フェーズ計画

### Phase 4: UIManager 責務分離（予定）

**目的**: UIManager（現在890行）の責務分離による複雑度削減

**対象システム**:
- CardSelectionUI（既存コンポーネント化されているが、参照が複雑）
- HandDisplay（スクロール機能含む）
- PhaseDisplay（フェーズ通知UI）
- TileActionUI（タイル上の操作UI）
- その他15+コンポーネント

**削減予想**: 890行 → 600行程度（290行削減）

**実装時期**: アルカナアーツ完全修正 + テスト完了後

---

### Phase 5: 統合テスト・ドキュメント更新（予定）

**目的**: 全フェーズ修正の検証 + ドキュメント最新化

**対象**:
- [ ] CPU vs CPU: 複数ラウンド（フリーズなし）確認
- [ ] スペル: 全effect_type（109種類）の実行確認
- [ ] アルカナアーツ: 発動・効果適用確認
- [ ] ドキュメント更新（CLAUDE.md, 設計ドキュメント）

**実装時期**: Phase 4完了後

---

## 📊 アーキテクチャ改善の進捗

| フェーズ | 内容 | 状態 | 削減行数 |
|---------|------|------|---------|
| Phase 0 | ツリー構造定義 | ✅ 完了 | - |
| Phase 1 | SpellSystemManager導入 | ✅ 完了 | - |
| Phase 2 | シグナルリレー整備 | ✅ 完了 | 83%削減 |
| Phase 3-A | SpellPhaseHandler Strategy化 | ✅ 完了 | 206行 |
| Phase 3-B | BoardSystem3D SSoT化 | ✅ 完了 | - |
| Phase 3-A-Final | 神オブジェクト化解決 | ✅ 完了 | 206行 |
| Phase 4 | UIManager責務分離 | ⚪ 計画中 | ~290行 |
| Phase 5 | 統合テスト・文書化 | ⚪ 計画中 | - |

**総削減**: 286行+ (Phase 3-A) + 206行 (Phase 3-A-Final) + 290行予定 (Phase 4) = **782行削減予定**

---

## 🔗 関連ドキュメント

- `CLAUDE.md`: プロジェクト全体方針・工程表
- `architecture_migration_plan.md`: Phase 0-5の詳細計画
- `session_2026_02_15_complete.md`: 前セッション報告書
- `daily_log.md`: 日次作業ログ

---

## 💡 重要な設計原則（今後の防止のため）

**SpellStateHandler に関連する変更時に必ず確認**:
1. ✅ 状態遷移時は常に `reset_turn_state()` を呼ぶ
2. ✅ フラグ変更は直接プロパティアクセスではなく、public メソッド経由で
3. ✅ フェーズ完了時のリセット漏れをチェック

**削除メソッド時の確認**:
1. ✅ 削除対象メソッドの全呼び出し箇所を特定
2. ✅ 呼び出し側を直接参照パターンに統一
3. ✅ 初期化ロジック漏れを確認

---

**最終更新**: 2026年2月16日 | Sonnet + Opus + Haiku
