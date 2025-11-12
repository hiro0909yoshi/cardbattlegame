## 呪いシステム実装完了ステータス（2025年11月13日）

### 完了した修正

#### 1. movement_controller.gd の削除
- **削除内容**: 移動時に `spell_curse.remove_curse_from_creature()` を直接呼び出していたコード
- **理由**: 効果システムの設計に従い、temporary_effects 経由で管理すべき
- **代替**: battle_system.clear_temporary_effects_on_move() で自動処理

#### 2. battle_preparation.gd._apply_creature_curses() の修正
- **変更前**: 呪いを temporary_bonus_hp/ap に直接加算（temporary_effects を無視）
- **変更後**: 呪いを temporary_effects 配列に効果オブジェクトとして追加
- **効果オブジェクトの構造**:
  ```gdscript
  {
    "type": "stat_bonus",
    "stat": "hp" / "ap",
    "value": curse_value,
    "source": "curse",
    "source_name": curse_name,
    "removable": true,
    "lost_on_move": true
  }
  ```
- **lost_on_move フラグ**: true に設定し、移動時に自動削除される

#### 3. 効果計算の統一
- apply_effect_arrays() で permanent_effects と temporary_effects を処理済み
- _apply_creature_curses() で temporary_effects に追加後、手動で temporary_bonus に反映
- current_hp と current_ap を更新

### UIへの影響
- ✅ temporary_bonus_hp/ap は従来通りアクセス可能
- ✅ 青色（基礎HP）と赤色（テンポラリーHP）の表示分離が実装可能
- ✅ 今後の効果追跡機能拡張に対応

### ドキュメント適合性
- ✅ effect_system.md の設計に完全準拠
- ✅ hp_structure.md の HP 管理構造に準拠
- ✅ temporary_effects 配列の lost_on_move フラグに対応

### ドキュメント更新完了
- [x] ステータス増減.md - 実装完了版に更新
- [x] 変更履歴を記録
- [x] UI表示セクションを追加

### 次のステップ
- [ ] バトルテストで呪い効果の適用確認
- [ ] 移動時の temporary_effects クリアの動作確認
- [ ] UI 表示テスト
