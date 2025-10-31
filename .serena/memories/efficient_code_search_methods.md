# 効率的なコード検索方法

## 問題
2025年10月31日のセッション中、以下の検索で時間がかかった：
- `grep`コマンドが機能しない
- `bash_tool`でのファイルパス指定が失敗
- Serenaツールの`search_for_pattern`が空結果を返す

## 原因
1. **bash_toolの制限**: プロジェクトディレクトリへの直接アクセスができない
2. **検索パターンの複雑さ**: 正規表現が複雑すぎると結果が得られない
3. **ファイルパスの問題**: 絶対パスではなく相対パスを使う必要がある

## 効率的な検索方法

### 1. まず全体構造を把握する
```
serena:list_dir (recursive=true) でディレクトリ構造を確認
serena:find_file でファイルを特定
```

**例**:
```
serena:list_dir("scripts/battle/skills", recursive=false)
→ スキルファイル一覧を取得

serena:find_file("*double_attack*", "scripts/battle/skills")
→ 該当ファイルを特定
```

### 2. ファイル全体を読む
検索パターンが見つからない場合、まずファイル全体を読む：
```
serena:read_file("scripts/battle/battle_preparation.gd")
```

**利点**:
- ファイル全体の構造を把握できる
- 予想外の実装方法を発見できる
- 正確な関数名・変数名が分かる

### 3. シンボル検索を活用
```
serena:get_symbols_overview("scripts/battle/battle_preparation.gd")
→ トップレベルシンボル一覧を取得

serena:find_symbol("apply_item_effects", relative_path="scripts/battle")
→ 関数の定義場所を特定
```

### 4. 検索パターンはシンプルに
**❌ 悪い例**:
```
substring_pattern="grant_first_strike.*effect_type"  # 複雑すぎる
```

**✅ 良い例**:
```
substring_pattern="grant_first_strike"  # シンプル
substring_pattern="apply_item_effects"  # 関数名のみ
```

### 5. コンテキスト行数を調整
```
context_lines_before=5
context_lines_after=50  # 関数全体を取得
```

## 推奨検索フロー

### ケース1: 新しい機能の実装場所を探す
```
1. serena:list_dir で関連ディレクトリを確認
2. serena:find_file でファイル名から推測
3. serena:get_symbols_overview で関数一覧を確認
4. serena:read_file で該当ファイル全体を読む
5. 必要に応じて serena:search_for_pattern で詳細検索
```

### ケース2: 既存の実装パターンを確認
```
1. serena:find_symbol で既存の類似機能を検索
2. serena:read_file でその実装を確認
3. 同じパターンを新機能に適用
```

### ケース3: 特定の処理がどこで呼ばれているか
```
1. serena:find_referencing_symbols で参照箇所を特定
2. serena:read_file で呼び出し元を確認
```

## 具体例：今回のセッション

### 効率的だった検索
```gdscript
// 1. ファイル特定
serena:find_file("battle_preparation.gd", "scripts")

// 2. 全体を読む
serena:read_file("scripts/battle/battle_preparation.gd")
→ apply_item_effects関数（217行目）を発見
→ grant_skill_to_participant関数（351行目）を発見
```

### 非効率だった検索
```gdscript
// bash_toolを使った検索（失敗）
bash_tool: grep -rn "SkillFirstStrike.grant_skill"
→ パスの問題で失敗

// 複雑な正規表現検索（結果なし）
search_for_pattern: "grant_first_strike.*effect_type"
→ パターンが複雑すぎて結果なし
```

## ベストプラクティス

### DO ✅
- **シンプルな検索パターンを使う**
- **ファイル全体を読んで理解する**
- **シンボル検索を優先する**
- **find_file → read_file の順で進む**
- **相対パスを使う**

### DON'T ❌
- **複雑な正規表現で検索しない**
- **bash_toolに頼りすぎない**
- **絶対パスを使わない**
- **検索結果が空の時に諦めない（read_fileで確認）**

## 時間がかかる原因と対策

| 原因 | 対策 |
|------|------|
| 検索パターンが見つからない | ファイル全体を読む |
| bash_toolが失敗する | Serenaツールを使う |
| 複雑な正規表現 | シンプルなパターンに分割 |
| ファイルの場所が不明 | list_dir → find_file の順 |
| 関数名が不明確 | get_symbols_overview で一覧確認 |

## まとめ

**最も効率的な方法**: 
1. `find_file`でファイルを特定
2. `read_file`で全体を読む
3. 必要に応じて`search_for_pattern`で詳細検索

**時間がかかったら**:
- 検索を諦めて`read_file`で直接読む
- `get_symbols_overview`で構造を把握
- ドキュメント（memory）で既知の情報を確認

**最終更新**: 2025年10月31日
