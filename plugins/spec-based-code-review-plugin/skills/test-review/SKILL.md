---
name: test-review
description: テストコード品質レビュースキル。テストコードが古典学派（Classical School）のテスト原則に従っているかを検証する。モック制限（外部依存のみ）と振る舞いテスト（実装詳細ではなく観察可能な結果を検証）のルールに基づいてレビューする。spec番号を指定すると対応するspecフォルダにレポートを出力する。番号省略時はarchive外で最大番号のspecを自動選択。「テストレビュー」「test review」「テスト品質チェック」「モック使いすぎ」「テストの書き方チェック」「古典学派」「classical school」「テストコードレビュー」「test-review」などでトリガー。
argument-hint: "[番号]"
allowed-tools: "Bash(git diff *), Bash(git log *), Bash(git show *), Bash(find *), Bash(grep *), Bash(wc *), Bash(ls *), Bash(cat *), Bash(mkdir *), Read, Write, Glob, Grep"
---

# テストコード品質レビュー

spec番号を指定して、テストコードが古典学派のテスト原則に従っているかをレビューするスキル。
単一エージェントとしてレビューを実行し、結果をspecフォルダに保存する。

## ワークフロー

```
Step 0: ルール定義の読み込み
  ↓
Step 1: Specフォルダの特定と検証
  ↓
Step 2: テストファイルの収集・読み込み
  ↓
Step 3: ルール適用とレビュー実行
  ↓
Step 4: レポート生成・保存
  ↓
Step 5: ユーザーへの提示とアクション提案
```

## Step 0: ルール定義の読み込み

レビュー開始前に、ルール定義と指摘分類を読み込む:

```
Read: test-review:finding-classification
Read: test-review:test-review-rules
```

## Step 1: Specフォルダの特定と検証

### 番号が指定された場合

```bash
spec_dir=$(ls -1d .plugin-workspace/.specs/$0-* 2>/dev/null | head -1)
```

マッチしない場合は archive 内も検索する:

```bash
spec_dir=$(ls -1d .plugin-workspace/.specs/archive/$0-* 2>/dev/null | head -1)
```

いずれもマッチしない場合はエラーメッセージを表示して終了。

### 番号が省略された場合

archive外で最大番号のspecを自動選択:

```bash
spec_dir=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* 2>/dev/null | sort -rn | head -1)
```

自動選択したspecのフォルダ名をユーザーに表示する。

### 検証

1. specフォルダが存在すること（必須）— 存在しない場合はエラー終了
2. `implementation-plan.md`（任意）— 存在する場合、テスト戦略セクションを参考情報として読み込む。存在しなくてもレビューは続行する

### PLANNINGファイルの検出

`PLANNING` ファイルが存在する場合、計画フェーズがまだ進行中。AskUserQuestion で確認する:

```yaml
question: "PLANNINGファイルが残っています。計画フェーズがまだ進行中の可能性があります。現時点のテストコードでレビューを実行しますか？"
header: "PLANNING検出"
options:
  - label: "はい、レビューを実行"
    description: "現時点のテストコードに対してレビューを行います"
  - label: "いいえ、中止"
    description: "計画完了後に再度実行してください"
```

## Step 2: テストファイルの収集

### レビュー対象の決定

AskUserQuestion でレビュー範囲を確認する:

```yaml
question: "レビュー対象を選択してください"
header: "レビュー範囲"
options:
  - label: "全テストファイル（推奨）"
    description: "implementation-planに記載されたテストファイル + git diffのテストファイル"
  - label: "git diffのテストファイルのみ"
    description: "直近の変更に含まれるテストファイルのみ"
  - label: "指定パス"
    description: "ファイルパスまたはディレクトリを指定"
```

### テストファイルの検出

以下のパターンでテストファイルを検出する:

```
*.test.ts, *.test.tsx, *.test.js, *.test.jsx
*.spec.ts, *.spec.tsx, *.spec.js, *.spec.jsx
test_*.py, *_test.py, *_test.go
__tests__/**
```

**「全テストファイル」の場合**:
1. implementation-plan の変更ファイル一覧からテストファイルを抽出
2. `git diff --name-only` からテストファイルを抽出
3. 両方をマージして重複排除

**「git diff のテストファイルのみ」の場合**:
1. `git diff --name-only` からテストファイルパターンにマッチするファイルを抽出

**「指定パス」の場合**:
1. ユーザーにパスを入力してもらう
2. ディレクトリの場合は配下のテストファイルを再帰的に検出

### テストファイルの読み込み

各テストファイルを Read で読み込む。同時に、テストファイル内の import 文からテスト対象のソースファイルも特定し、内部モジュール vs 外部依存の判定に備える。

## Step 3: ルール適用とレビュー実行

各テストファイルに対して、2つのルールを順番に適用する。

### Rule 1: MOCK-SCOPE（モック制限）

テストファイル内の mock/spy パターンを検出する:

1. **モックパターンの検出**: `vi.mock(...)`, `jest.mock(...)`, `vi.spyOn(...)`, `jest.spyOn(...)`, `vi.fn()`, `jest.fn()` 等
2. **対象の判定**: モック対象が外部依存か内部モジュールかを判定
   - 相対パス (`./`, `../`) → 内部モジュール → **VIOLATION**
   - プロジェクトのパスエイリアス (`@/`, `~/`, `#/` 等) → 内部モジュール → **VIOLATION**
   - `node_modules` のパッケージ名 → 外部依存 → **OK**
   - `vi.useFakeTimers()`, `vi.stubEnv()` 等のユーティリティ → **OK**
   - 内部インターフェースが外部依存をラップしている可能性がある場合 → **WARNING**

3. **パスエイリアスの解決**: `tsconfig.json` や `vite.config.ts` の `resolve.alias` を確認し、エイリアスが内部パスを指しているかを判定する

### Rule 2: BEHAVIOR-TEST（振る舞いテスト）

テストファイル内のアサーションパターンを検出する:

1. **spy アサーションの検出**: `toHaveBeenCalled()`, `toHaveBeenCalledWith(...)`, `toHaveBeenCalledTimes(...)` 等
2. **spy 対象の判定**: spy 対象が内部コラボレーターか外部依存かを判定
   - 内部コラボレーターへの spy アサーション → **VIOLATION**
   - 外部依存への spy アサーション → **OK**（システム出力の検証）
3. **プライベートアクセスの検出**: `obj['_privateMethod']`, `(obj as any).privateField` 等のパターン → **VIOLATION**
4. **中間データ形状のアサーション**: 出力契約の一部でない内部的なデータ構造への検証 → **WARNING**

### 判定の原則

- 迷った場合は WARNING に分類する（過剰な VIOLATION より、レビュイーの判断に委ねるほうがよい）
- 各指摘には必ずコードスニペットと具体的な修正案を含める
- ルール定義（`test-review-rules.md`）の「OK」パターンに該当するものは指摘しない

## Step 4: レポート生成・保存

### 出力先ディレクトリの作成

```bash
mkdir -p {spec_dir}/test-review
```

### 連番の決定

```bash
next_num=$(printf "%03d" $(( $(ls -1 {spec_dir}/test-review/test-review-*.md 2>/dev/null | wc -l | tr -d ' ') + 1 )))
```

### レポートの生成

テンプレート `test-review:test-review-report` に沿ってレビューレポートを生成し、以下に保存:

```
Write: {spec_dir}/test-review/test-review-{NNN}.md
```

レポートに含める情報:
- レビュー日時、レビュー回数、レビュー対象範囲
- VIOLATION / WARNING / OK の件数サマリー
- ルール別集計
- 各指摘の詳細
- レビュー対象ファイル一覧と判定結果

## Step 5: ユーザーへの提示とアクション提案

### レビュー結果サマリーの提示

レポートのサマリーをユーザーに提示する:

- VIOLATION / WARNING の件数
- VIOLATION がある場合は具体的な指摘内容を表示
- 全ファイル OK の場合は「テストコード品質レビュー完了 — 問題なし」と報告

### 対応アクションの提案

VIOLATION または WARNING がある場合:

```yaml
question: "レビュー結果への対応を選択してください"
header: "対応方針"
options:
  - label: "指摘を修正する"
    description: "VIOLATION/WARNINGの指摘に対応します"
  - label: "レビュー結果を確認のみ"
    description: "レビュー結果を保存し、後で対応します"
  - label: "再レビュー"
    description: "修正後にもう一度レビューを実行します（連番インクリメント）"
```

### 「指摘を修正する」選択時

VIOLATION → WARNING の優先順でユーザーに指摘内容を提示し、修正を進める。修正後に「再レビュー」を提案する。

### 「再レビュー」選択時

連番をインクリメントして Step 2 からやり直す。最大5回までループ。5回超えたらユーザーに相談。

## 出力ディレクトリ

```
.plugin-workspace/.specs/{nnn}-{feature-name}/
└── test-review/
    └── test-review-{NNN}.md    # レビュー結果（連番で蓄積）
```

## 重要な制約

- implementation-plan.md は参考情報として読むが、なくてもレビューを実行する
- 迷ったら WARNING に分類する（VIOLATION の過剰検出を避ける）
- 各指摘にはコードスニペットと修正案を必ず含める
- 外部依存への spy アサーションは VIOLATION としない（BEHAVIOR-TEST ルールの例外）
- 再レビューは最大5回まで
