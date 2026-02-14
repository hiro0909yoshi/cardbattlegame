# Phase 1 実装前の質問セッション

**作成日**: 2026-02-14
**対象**: Phase 1: SpellSystemManager 導入（実装予定）
**主要な参考資料**:
- `docs/progress/refactoring_next_steps.md` の Phase 1 セクション
- `scripts/system_manager/game_system_manager.gd` の _setup_spell_systems() メソッド
- `scripts/spells/spell_system_container.gd`

---

## 質問グループ1: 既存コードの確認

### Q1-1: SpellCurseToll と SpellCostModifier の初期化タイミング

**具体的な質問内容**:

現在、`GameSystemManager._setup_spell_systems()` 行 501-618 を見ると：

1. 行 501-574：コアシステム（8個）を SpellSystemContainer に登録
2. 行 346-392：SpellCurseToll・SpellCostModifier は別途初期化（なぜか行 501-618 より後ろ？）

**コード片**:
```gdscript
# 行 501-574: SpellSystemContainer に登録（コアシステム8個）
spell_container.setup(...)

# ===== その後、行 346-392 で =====
var spell_curse_toll = SpellCurseTollClass.new()
spell_curse_toll.setup(...)
game_flow_manager.add_child(spell_curse_toll)
game_flow_manager.spell_container.set_spell_curse_toll(spell_curse_toll)
```

**確認したい事項**:
- [ ] SpellCurseToll・SpellCostModifier は「派生システム」で、8個のコアシステムと初期化順序が異なるのか？
- [ ] 行 501-618 内で SpellCurseToll・SpellCostModifier も初期化すべきか、それとも現在の場所が正しいのか？

**確認したい理由**: Phase 1 で SpellSystemManager を導入する際、どこに SpellCurseToll・SpellCostModifier の初期化を入れるか決めるため

---

### Q1-2: SpellSystemContainer の setup() メソッドの容量

**具体的な質問内容**:

`spell_system_container.gd` の `setup()` メソッドは現在、**8つのコアシステムのみ** を受け入れます：

```gdscript
# 行 33-50
func setup(
    p_spell_draw,
    p_spell_magic,
    p_spell_land,
    p_spell_curse,
    p_spell_dice,
    p_spell_curse_stat,
    p_spell_world_curse,
    p_spell_player_move
) -> void:
    # ...
```

派生システム（SpellCurseToll、SpellCostModifier）は別途メソッドで設定：
```gdscript
func set_spell_curse_toll(p_spell_curse_toll) -> void:
func set_spell_cost_modifier(p_spell_cost_modifier) -> void:
```

**確認したい事項**:
- [ ] この分割設計は意図的か？（コアシステム vs 派生システムの明確な区別）
- [ ] 今後、さらにスペルシステムが追加される可能性があるか？
- [ ] Phase 1 では SpellSystemContainer の内部構造を変更すべきでないか？

**確認したい理由**: Phase 1 の実装範囲を確定させるため

---

### Q1-3: SpellSystemManager が Node型である理由

**具体的な質問内容**:

計画では：
```gdscript
extends Node
class_name SpellSystemManager
```

と書かれていますが、SpellSystemContainer は RefCounted です。なぜ SpellSystemManager だけ Node型にするのでしょうか？

**現在の実装パターン**:
- SpellSystemContainer: RefCounted（参照カウント管理）
- BankruptcyHandler: Node型（`game_flow_manager.add_child()` で追加）
- SpellCurseToll: Node型（`game_flow_manager.add_child()` で追加）

**確認したい事項**:
- [ ] SpellSystemManager が Node型の理由は何か？
  - A) ノードツリーに統合させるため
  - B) ライフサイクル管理（_ready(), _process() 等）が必要
  - C) その他
- [ ] SpellSystemManager に `_ready()` メソッドが必要か？

**確認したい理由**: Phase 1 実装時に正しいベースクラス（Node vs RefCounted）を選択するため

---

## 質問グループ2: 実装方針の確認

### Q2-1: アクセサメソッド（get_spell_*()）の実装範囲

**具体的な質問内容**:

計画では：
```gdscript
# SpellSystemManager のアクセサ
func get_spell_draw():
    return spell_container.spell_draw if spell_container else null

func get_spell_magic():
    return spell_container.spell_magic if spell_container else null

# ... 他のスペルシステムも同様
```

と書かれていますが、**すべてのスペルシステム分（12個？）のアクセサが必要か、それとも主要なものだけか**？

**確認したい事項**:
- [ ] `get_spell_*()` は全12個実装すべきか？
- [ ] それとも「よく使われるシステム」（SpellDraw, SpellMagic, SpellLand, SpellCurse）だけでよいか？
- [ ] 将来的に追加スペルシステムが増える場合、ここをどう対応するか？

**確認したい理由**: 実装の工数と保守性のバランスを考えるため

---

### Q2-2: 後方互換性の具体的な検証方法

**具体的な質問内容**:

計画では「後方互換性を維持」と書かれていますが、具体的にどう検証するか？

```gdscript
# 既存パターン（変更なし）
game_flow_manager.spell_container.spell_draw

# 新規パターン（Phase 1 後に利用可能）
game_flow_manager.spell_system_manager.spell_container.spell_draw
```

**質問**:
- [ ] 20+個の既存アクセス箇所を全て動作確認すべきか？
- [ ] grep で「spell_container」を検索して確認するだけでよいか？
- [ ] Unit テスト（GDUnit または同等）を書くべきか？

**確認したい理由**: テスト方針の効率性を確保するため

---

### Q2-3: GameFlowManager への spell_system_manager 変数追加の時期

**具体的な質問内容**:

計画の「タスク1-3: GameFlowManager に参照追加」では：

```gdscript
# GameFlowManager
var spell_system_manager: SpellSystemManager = null
var spell_container: SpellSystemContainer = null  # 既存（維持）
```

と書かれていますが、このタイミングについて：

- [ ] タスク1-1 で SpellSystemManager クラスを作成した後、すぐに実施？
- [ ] タスク1-2（GameSystemManager 更新）と同時に実施？
- [ ] 実施順序は重要か？

**確認したい理由**: 依存関係が循環しないことを確認するため

---

## 質問グループ3: テスト・検証方針の確認

### Q3-1: デバッグコンソール検証コマンドの実行環境

**具体的な質問内容**:

計画では検証コマンドが書かれています：

```gdscript
print("GFM spell_system_manager:", game_flow_manager.spell_system_manager)
print("GFM spell_container:", game_flow_manager.spell_container)
print("SpellDraw access:", game_flow_manager.spell_container.spell_draw)
```

**質問**:
- [ ] このコマンドは Godot Editor の「出力」パネルで実行するか？
- [ ] それとも DebugController 経由で実行するか？
- [ ] スクリプトファイル（_ready 等）に仕込んで自動実行する方がいいか？

**確認したい理由**: 検証方法の実行手順を明確にするため

---

### Q3-2: CPU vs CPU 動作テストの実施方法

**具体的な質問内容**:

計画では「3ターン以上 CPU vs CPU で動作」と書かれていますが：

**質問**:
- [ ] このテストを自動化すべきか（スクリプトで 3ターン実行）？
- [ ] それとも手動でゲーム起動して確認すればいいか？
- [ ] 特に確認すべき動作シーン（Spell フェーズ、Move フェーズ等）は？

**確認したい理由**: テスト時間の効率化を図るため

---

### Q3-3: エラーログの確認方法

**計画には** 「エラーログ確認: push_error() なし」と書かれていますが：

**質問**:
- [ ] Godot Editor の「出力」パネルをフル実行中ずっと見ておく必要があるか？
- [ ] それとも `push_error()` は通常時に出力されないのか？
- [ ] 特に監視すべき `push_error()` テキストは？

**確認したい理由**: テスト時の監視負荷を減らすため

---

## 質問グループ4: リスク対策・ロールバックの確認

### Q4-1: リスク「既存スペル処理が動作しなくなる」への具体的な対策

**計画には**:
```
| リスク | 深刻度 | 発生確率 | 緩和策 |
|--------|--------|---------|--------|
| 既存スペル処理が動作しなくなる | 🔴 高 | 低 | 後方互換性を維持 |
```

と書かれていますが：

**質問**:
- [ ] 後方互換性を維持するだけで十分か？
- [ ] それとも実装前に具体的なロールバック計画（git stash 等）を用意すべきか？
- [ ] 問題が発生した場合の対応手順は？

**確認したい理由**: リスク回避策が十分であることを確認するため

---

### Q4-2: 初期化順序の問題への対策

**計画には** 「_setup_spell_systems() で段階的に初期化」と書かれていますが：

**質問**:
- [ ] SpellSystemManager を create → add_child → setup の順序は必須か？
- [ ] 逆順（setup → add_child）ではダメなのか？
- [ ] SpellSystemContainer の setup() をいつ呼び出すべきか？

**確認したい理由**: 初期化順序を確定させるため

---

### Q4-3: ロールバック時の手順確認

**計画には**:
```
ロールバック計画（所要時間: 30分）:
1. SpellSystemManager.gd ファイル削除
2. GameSystemManager の _setup_spell_systems() を元に戻す
3. GameFlowManager の spell_system_manager 変数削除
```

と書かれていますが：

**質問**:
- [ ] git revert を使う方がいいか？
- [ ] 手動で削除・修正する方がいいか？
- [ ] 上記 3手順で十分か、他にすべき操作があるか？

**確認したい理由**: 緊急時の対応手順を明確にするため

---

## 質問グループ5: ドキュメント・メンテナンスの確認

### Q5-1: TREE_STRUCTURE.md の更新箇所

**計画では実装後に以下を更新すると書かれています**:

```
- [ ] `docs/design/TREE_STRUCTURE.md` - SpellSystemManager を追加
```

**質問**:
- [ ] 既に TREE_STRUCTURE.md に SpellSystemManager が記載されているが（行 53-65）、ここが更新が必要な場所か？
- [ ] それとも他の場所も更新が必要か？

**確認したい理由**: ドキュメント更新の正確さを確保するため

---

### Q5-2: CLAUDE.md の更新範囲

**計画では**:
```
- [ ] `CLAUDE.md` - Architecture Overview セクションを更新
```

と書かれていますが：

**質問**:
- [ ] CLAUDE.md 行 47-51 の「Architecture Overview」が該当箇所か？
- [ ] どの部分を具体的に更新すべきか？

**確認したい理由**: ドキュメント更新の効率化を図るため

---

## 要約: 実装前に確認すべき重要ポイント

| # | 質問 | 優先度 | 回答形式 |
|---|------|--------|----------|
| Q1-1 | SpellCurseToll・SpellCostModifier の初期化タイミング | P0 | 確認 + 手順 |
| Q1-2 | SpellSystemContainer の setup() メソッドの設計意図 | P1 | Yes/No |
| Q1-3 | SpellSystemManager が Node型の理由 | P1 | 理由説明 |
| Q2-1 | アクセサメソッドの実装範囲 | P1 | 範囲指定 |
| Q2-2 | 後方互換性の検証方法 | P0 | テスト手順 |
| Q2-3 | GameFlowManager への変数追加の時期 | P1 | 順序確認 |
| Q3-1 | デバッグコンソール検証コマンドの実行方法 | P1 | 実行方法 |
| Q3-2 | CPU vs CPU テストの実施方法 | P1 | 手法選択 |
| Q3-3 | エラーログの確認方法 | P2 | 監視方法 |
| Q4-1 | リスク対策の十分性確認 | P0 | 追加対策 |
| Q4-2 | 初期化順序の問題への対策 | P0 | 順序確定 |
| Q4-3 | ロールバック手順の確認 | P1 | 手順確認 |
| Q5-1 | TREE_STRUCTURE.md の更新箇所 | P1 | 箇所指定 |
| Q5-2 | CLAUDE.md の更新範囲 | P1 | 範囲指定 |

---

**優先度凡例**:
- P0: 実装開始前に必ず確認（ブロッカー）
- P1: 実装途中に確認可能
- P2: テスト時に確認でよい

**次のアクション**: Sonnet に上記質問を送信し、回答を受け取った後、Haiku に実装を依頼

---

**作成日**: 2026-02-14
**作成者**: Haiku (質問セッション)
