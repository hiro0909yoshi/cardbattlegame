# 方向ボーナス修正 - 正常動作バージョン（2025-01-14）✓確認済み

## 概要
分岐選択時の方向ボーナスを、分岐タイルの方向ごとに計算。ターン開始位置のCPを除外する機能付き。

## 正常動作確認済みの結果

### タイル0での分岐選択（ターン開始位置=タイル0=N）
visited = ["N"]（ターン開始CP除外済み）
- タイル1方向: W:6歩 → ボーナス840
- タイル23方向: E:6歩 → ボーナス840
- **選択: タイル1** (経路スコア差で決定)

### タイル2での分岐選択（残り16歩、turn_start_cp=N）
visited = ["N"]（ターン開始CP除外済み）
- タイル3方向: W:4歩 → ボーナス960 → スコア2770
- タイル24方向: E:8歩 → ボーナス720 → スコア2750
- **選択: タイル3** ✓

### タイル9での分岐選択（W取得後、turn_start_cp=N）
visited = ["W", "N"]
- タイル27方向: E:8歩 → ボーナス720 → スコア2420
- タイル10方向: E:9歩 → ボーナス660 → スコア2290
- **選択: タイル27** ✓

### タイル15での分岐選択
visited = ["W", "N"]
- タイル16方向: E:3歩 → ボーナス1020 → スコア2650
- タイル14方向: E:21歩 → ボーナス0 → スコア130
- **選択: タイル16** ✓

### 最終結果
経路: タイル0→1→2→3→W取得→9→27→ワープ→15→16→E取得→19
2ターンでW、Eを取得 ✓

## 主要なコード

### 変数（L53-58）
```gdscript
var _current_branch_tile: int = -1
var _turn_start_cp: String = ""
var _turn_start_cp_player: int = -1
```

### evaluate_path（L148-156）
```gdscript
var total_score = stop_score + (path_score / SCORE_PATH_DIVISOR) + checkpoint_bonus
```

### decide_branch_choice（L560-580）
ターン開始CP記録 + 方向ボーナス計算

### _calculate_direction_bonus_for_branch（L475-518）
ターン開始CP除外 + 分岐タイルCP除外 + 距離計算

## ファイル
scripts/cpu_ai/cpu_movement_evaluator.gd
