# スペルフェーズ実装 - 完了記録

**実装日**: 2025年10月17日  
**ステータス**: ✅ 完了・動作確認済み

---

## 📊 実装内容

### 完了した機能

#### 1. スペルフェーズシステム ✅
- ターン開始時にスペルを使用できるフェーズを追加
- 1ターン1回の使用制限
- MPコストによる使用判定
- ダイスボタンでスキップ可能
- CPU AI対応（30%確率でスペル使用）

#### 2. カードフィルタリングシステム ✅
- スペルフェーズ: スペルカードのみ選択可能（クリーチャーカードはグレーアウト）
- 召喚フェーズ: クリーチャーカードのみ選択可能（スペルカードはグレーアウト）
- グレーアウトと選択可否の分離管理
- `UIManager.card_selection_filter`による制御

#### 3. 対象選択システム ✅
- 敵クリーチャー/敵プレイヤーを選択するUI
- リスト形式で上下キー操作
- 選択中の対象にカメラ自動フォーカス
- Enter決定、Escキャンセル

#### 4. スペル効果実装 ✅

**damage - クリーチャーへのダメージ**:
- 基本HPと土地ボーナスHPの両方を削る
- HP≤0でクリーチャー撃破
- 土地を空き地化（owner=-1, level=1, creature={}）
- 実装例: マジックボルト（コスト50MP、ダメージ20）

**drain_magic - 魔力吸収**:
- 対象プレイヤーから魔力を奪う
- percentage/fixed対応
- 所持魔力以上は吸収不可
- 実装例: ドレインマジック（コスト80MP、30%吸収）

#### 5. テスト用スペルカード ✅
- マジックボルト: 敵クリーチャーにHP-20ダメージ
- ドレインマジック: 敵プレイヤーから魔力30%吸収

---

## 🔧 実装した技術的修正

### 1. コスト処理の統一
```gdscript
# スペルカードのコストが辞書型{"mp": 値}の場合に対応
var cost_data = card_data.get("cost", 1)
var cost = 0
if typeof(cost_data) == TYPE_DICTIONARY:
	cost = cost_data.get("mp", 0) * GameConstants.CARD_COST_MULTIPLIER
else:
	cost = cost_data * GameConstants.CARD_COST_MULTIPLIER
```

### 2. 型指定エラーの回避
```gdscript
# CPUTurnProcessorクラスの動的ロード
var CPUTurnProcessorClass = load("res://scripts/flow_handlers/cpu_turn_processor.gd")
if CPUTurnProcessorClass:
	cpu_turn_processor = CPUTurnProcessorClass.new()
```

### 3. カード種別チェックの追加
```gdscript
# GameFlowManager.on_card_selected()
var card_type = card.get("type", "")

# スペルフェーズ中かチェック
if spell_phase_handler and spell_phase_handler.is_spell_phase_active():
	if card_type == "spell":
		spell_phase_handler.use_spell(card)
		return
	else:
		print("スペルフェーズ中はスペルカードのみ使用可能")
		return

# スペルフェーズ以外でスペルカードが選択された場合
if card_type == "spell":
	print("スペルカードはスペルフェーズでのみ使用できます")
	return
```

### 4. グレーアウト制御の改善
```gdscript
# HandDisplay: フィルターモードに応じてグレーアウト
if filter_mode == "spell":
	# スペルフェーズ中: スペルカード以外をグレーアウト
	if not is_spell_card:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
elif filter_mode == "":
	# 通常フェーズ: スペルカードをグレーアウト
	if is_spell_card:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
```

### 5. CardSelectionUIの選択制御
```gdscript
# enable_card_selection()
var spell_phase_only = ui_manager_ref.card_selection_filter == "spell"

if spell_phase_only:
	# スペルフェーズ中: スペルカードのみ選択可能
	is_selectable = card_type == "spell"
else:
	# 召喚フェーズ等: スペルカード以外が選択可能
	is_selectable = card_type != "spell"
```

---

## 🐛 修正したバグ

### 1. target_selection_ui.gdのインデントエラー
**問題**: ファイルの先頭が壊れていた  
**修正**: ファイル全体を再作成、正しいクラス定義とシグナル定義を追加

### 2. show_selection()の引数エラー
**問題**: `show_selection(hand_data, available_magic, player_id, "message")`  
**修正**: `show_selection(current_player, "spell")`に統一

### 3. プレイヤーオブジェクトの構造エラー
**問題**: `player`オブジェクトをそのまま渡していた  
**修正**: 辞書形式に変換して渡す
```gdscript
targets.append({
	"type": "player",
	"player_id": player.id,
	"player": {
		"name": player.name,
		"magic_power": player.magic_power,
		"id": player.id
	}
})
```

### 4. クリーチャーデータアクセスエラー
**問題**: `tile.get_creature_data()`メソッドが存在しない  
**修正**: `tile.creature_data`プロパティに直接アクセス

### 5. 魔力取得エラー
**問題**: `target_player.get("magic_power")`で辞書から取得しようとしていた  
**修正**: `player_system.get_magic(target_player_id)`で取得

---

## 📂 主要ファイル一覧

### 新規作成
- `scripts/game_flow/spell_phase_handler.gd` (約450行) - スペルフェーズ管理
- `scripts/ui_components/target_selection_ui.gd` (約230行) - 対象選択UI
- `data/spell_test.json` - テスト用スペルデータ

### 重要な変更
- `scripts/game_flow_manager.gd` - スペルフェーズ統合、カード種別チェック追加
- `scripts/ui_manager.gd` - カードフィルター機能追加
- `scripts/ui_components/hand_display.gd` - フィルター対応グレーアウト
- `scripts/ui_components/card_selection_ui.gd` - スペルモード対応
- `scripts/tile_action_processor.gd` - 召喚/バトル時のフィルター設定
- `scripts/card_system.gd` - テストカード自動追加

---

## 🎯 動作確認項目

### ✅ 確認済み
1. スペルフェーズ開始時に正しくスペルカードのみ選択可能
2. クリーチャーカードがグレーアウトされる
3. スペル選択UIが表示される
4. 対象選択UIが正常に動作（↑↓キー、Enter、Esc）
5. マジックボルトでクリーチャーにダメージを与えられる
6. ドレインマジックで魔力を吸収できる
7. クリーチャーHP≤0で土地が空き地になる
8. スペルフェーズ完了後にグレーアウトが解除される
9. 召喚フェーズでスペルカードがグレーアウトされる
10. 召喚フェーズでスペルカードが選択不可
11. ダイスボタンでスペルフェーズをスキップできる
12. 1ターン1回の制限が機能する

---

## 🚀 今後の拡張予定

### 未実装のスペル効果
- `heal`: HP回復
- `buff_st`: ST上昇
- `buff_hp`: HP上昇
- `debuff`: 能力低下
- `aoe_damage`: 範囲ダメージ
- `summon`: クリーチャー召喚
- `teleport`: 移動
- `land_transform`: 土地属性変更
- `magic_boost`: 魔力増加
- `draw_card`: カードドロー

### 世界呪システム（計画中）
- 持続効果の管理
- 画面上部への表示
- 全プレイヤーへの影響
- ターン経過による効果減衰

### アイテム/巻物システム（計画中）
- バトル準備フェーズ
- アイテム選択UI
- バトル中の巻物使用
- 即時効果（回復、ダメージ等）

---

## 📝 設計上の注意事項

### スキルとスペルの分離

**スキル**:
- 実装場所: `SkillSystem`
- 発動タイミング: バトル中
- 効果範囲: バトル参加者のみ
- データ: `ability_parsed`
- 例: 感応、貫通、強打、先制

**スペル**:
- 実装場所: `SpellPhaseHandler`
- 発動タイミング: スペルフェーズ
- 効果範囲: 任意の対象
- データ: `ability_parsed`
- 例: マジックボルト、ドレインマジック

### カード種別の判定
```gdscript
var card_type = card.get("type", "")
# "creature" - クリーチャーカード
# "spell" - スペルカード
# "item" - アイテムカード（未実装）
```

### フィルターシステム
```gdscript
# UIManager.card_selection_filter
"spell"  # スペルフェーズ: スペルカードのみ
""       # 召喚フェーズ: クリーチャーカードのみ
```

### 新しいスペル効果の追加方法

`spell_phase_handler.gd`の`_apply_single_effect()`に新しいケースを追加:
```gdscript
match effect_type:
	"damage":
		# 既存
	"drain_magic":
		# 既存
	"heal":  # 新規
		# HP回復処理を実装
```

---

## 🎉 完了

スペルフェーズシステムの実装が完了しました。
- ターン開始時にスペルを使用できる
- 対象を選択して効果を発動
- スキルとは完全に分離された独立システム

次のフェーズ（アイテム/巻物システムまたは世界呪システム）の実装に進めます。

---

**作成日**: 2025年10月17日  
**最終更新**: 2025年10月17日  
**ステータス**: Phase 1-E 完了
