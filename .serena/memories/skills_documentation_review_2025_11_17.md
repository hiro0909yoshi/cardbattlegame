# スキル関連ドキュメント確認完了 (2025-11-17)

## 確認対象

docs/design/skills/ 配下の主要ドキュメント：
- reflect_skill.md（反射スキル）
- penetration_skill.md（貫通スキル）
- indomitable_skill.md（不屈スキル）
- regeneration_skill.md（再生スキル）
- assist_skill.md（援護スキル）
- on_death_effects.md（死亡時効果）※既修正

## 確認結果

### ✅ 矛盾なし・記載なし
- reflect_skill.md: ダメージ反射のみ記載、消費順序に関する記載なし
- penetration_skill.md: 土地ボーナス無効化、消費順序に関する記載なし
- indomitable_skill.md: ダウン状態管理のみ、ダメージ関連記載なし
- regeneration_skill.md: base_hp と base_up_hp の回復について正しく記載
- assist_skill.md: HP加算効果のみ、消費順序に関する記載なし
- on_death_effects.md: **修正済み**（ダメージ消費順序を修正）

### ⚠️ 他のスキルドキュメント
以下のドキュメントもダメージ処理に関連する可能性がありますが、確認推奨：
- power_strike_skill.md（強打スキル）
- resonance_skill.md（感応スキル）
- double_attack_skill.md（二回攻撃）
- instant_death_skill.md（即死スキル）
- nullify_skill.md（無効化スキル）
- support_skill.md（援護スキル）
- transform_skill.md（変身スキル）
- revive_skill.md（復活スキル）
- scroll_attack_skill.md（巻物攻撃）
- item_destruction_theft_skill.md（アイテム破壊・盗み）
- item_return_skill.md（アイテム返却）
- first_strike_skill.md（先制スキル）
- vacant_move_skill.md（空きタイル移動）

## 修正が必要だったドキュメント（すべて修正済み）

| ドキュメント | 修正内容 |
|-----------|---------|
| hp_structure.md | ✅ 修正済み（2025-11-17） |
| effect_system_design.md | ✅ 修正済み（2025-11-17） |
| battle_system.md | ✅ 修正済み（2025-11-17） |
| on_death_effects.md | ✅ 修正済み（2025-11-17） |

## 総括

**主要スキル関連ドキュメント**はダメージ消費に関する矛盾した記載がないことを確認しました。
その他の詳細スキルドキュメント内での矛盾については、必要に応じて追加確認を推奨します。

## 今後の推奨アクション

1. **追加確認推奨**: 上記「他のスキルドキュメント」リストの確認
2. **全体統一**: 各ドキュメントで「ダメージ消費順序」に関する統一的な参照が必要な場合、hp_structure.md への参照リンク追加を検討
3. **定期メンテナンス**: 新しいスキルやシステム変更時には、関連ドキュメント全体の一貫性確認を実施
