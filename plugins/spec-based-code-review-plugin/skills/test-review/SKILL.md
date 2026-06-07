---
name: test-review
description: テストコード品質レビュースキル（spec非依存）。specフォルダがなくてもテストコードを古典学派（Classical School）のテスト原則に基づいてレビューできる。test-quality-reviewerエージェントを起動し、モック制限・振る舞いテスト・テスト価値・テストケース網羅性の4次元でレビューする。specフォルダが存在する場合は計画ドキュメントも参照してPROTECTED判定を行う。「テストレビュー」「test review」「テスト品質チェック」「モック使いすぎ」「テストの書き方チェック」「古典学派」「classical school」「テストコードレビュー」「test-review」「テストケース不足」などでトリガー。
disable-model-invocation: true
argument-hint: "[ファイルパス or spec番号]"
---

# テストコード品質レビュー（spec非依存）

テストコードを古典学派のテスト原則に基づいてレビューするスキル。
specフォルダの有無に関わらず動作する。specがあれば PROTECTED 判定も行い、なければ普遍的ルールのみで判定する。

test-quality-reviewer エージェントを起動してレビューを委譲し、結果を提示する。

## ワークフロー

```
Step 0: モード判定（spec有無）
  ↓
Step 1: テストファイルの収集
  ↓
Step 2: サブエージェントを起動
  ↓
Step 3: 結果の提示とアクション提案
```

## Step 0: モード判定

### 引数がspec番号の場合

```bash
spec_dir=$(ls -1d .plugin-workspace/.specs/$0-* 2>/dev/null | head -1)
```

マッチすればspecモード。計画ドキュメントを読み込みに含める。

### 引数がファイルパス/ディレクトリの場合

直接そのパスをレビュー対象とする。specなしモード。

### 引数なしの場合

以下の順で判定する:

1. `.plugin-workspace/.specs/` が存在し、archive外にspecフォルダがある → 最大番号を自動選択してspecモード
2. 上記に該当しない → specなしモード（git diff のテストファイルを対象）

### specモード時の追加読み込み

以下が存在すれば読み込む（なくてもエラーにしない）:

- `{spec_dir}/implementation-plan.md` — テスト戦略・モック方針
- `{spec_dir}/exploration-report.md` — テストインフラ規約
- `{spec_dir}/hearing-notes.md` — 要件・エッジケース
- `{spec_dir}/tasks.md` — タスク完了状態

## Step 1: テストファイルの収集

### specモードの場合

AskUserQuestion でレビュー範囲を確認する:

```yaml
question: "レビュー対象を選択してください"
header: "レビュー範囲"
options:
  - label: "全テストコード（推奨）"
    description: "implementation-planに記載されたテストファイルとgit diffのテストファイル"
  - label: "git diffのテストファイルのみ"
    description: "直近の変更に含まれるテストファイルのみ"
  - label: "指定パス"
    description: "ファイルパスまたはディレクトリを指定"
```

### specなしモードの場合（引数なし）

AskUserQuestion でレビュー範囲を確認する:

```yaml
question: "レビュー対象を選択してください"
header: "レビュー範囲"
options:
  - label: "git diffのテストファイル（推奨）"
    description: "直近の変更に含まれるテストファイルをレビュー"
  - label: "指定パス"
    description: "ファイルパスまたはディレクトリを指定"
  - label: "全テストファイル"
    description: "プロジェクト全体のテストファイルをスキャン"
```

### specなしモードの場合（引数あり）

引数で指定されたパスを直接使用。ディレクトリならテストファイルパターンで再帰検出。

### テストファイルの検出パターン

`*.test.*`, `*.spec.*`, `test_*.*`, `*_test.*`, `__tests__/**`

## Step 2: サブエージェントを起動

### specモード時の出力先

```bash
mkdir -p {spec_dir}/spec-based-code-review
next_num=$(printf "%03d" $(( $(ls -1 {spec_dir}/spec-based-code-review/test-quality-*.md 2>/dev/null | wc -l | tr -d ' ') + 1 )))
```

出力先: `{spec_dir}/spec-based-code-review/test-quality-{NNN}.md`

### specなしモード時の出力

ファイル出力はせず、エージェントの出力を直接会話に提示する。

### エージェント起動

```
Task tool:

1. test-quality-reviewer:
   description: "test-quality-reviewer: テスト品質レビュー"
   run_in_background: true
   prompt: |
     あなたは test-quality-reviewer エージェントです。
     古典学派のテスト原則に基づいてテストコードをレビューしてください。

     ## レビュー基準
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/review-dimensions.md
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/finding-classification.md
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/test-review-rules.md

     ## 計画ドキュメント（specモードの場合のみ — 存在するものだけ読む）
     {specモード時: 計画ドキュメントのパス一覧}
     {specなしモード時: 「計画ドキュメントはありません。普遍的ルールのみでレビューしてください。PROTECTED 判定は行わず、CRITICAL / WARNING / INFO のみで分類してください。」}

     ## テストコード情報
     テストファイル一覧:
     {テストファイルリスト}

     git diff（テスト部分）:
     {git diff の内容（テストファイル部分）}

     ## 出力先
     {specモード時: ファイルパス}
     {specなしモード時: 「ファイル出力不要。結果をそのままテキストで返してください。」}

     ## 重要
     - テストコードだけでなく、テスト対象の実装コードも読んでロジックの有無を確認すること
     - すべての指摘にコードスニペットと修正案を含めること
     - 外部依存への spy アサーションは CRITICAL にしないこと
     - 迷ったら WARNING に分類すること（specなしモード時）
     - 迷ったら PROTECTED 寄りに判定すること（specモード時）
```

### 完了待ち

```
TaskOutput:
  task_id: "{エージェントのtask_id}"
  block: true
  timeout: 300000
```

## Step 3: 結果の提示とアクション提案

### specモードの場合

統合レポートを生成（spec-based-code-review と同じ形式）し、サマリーを提示する。

### specなしモードの場合

エージェントの出力をそのままユーザーに提示する。

### 対応アクションの提案

CRITICAL または WARNING がある場合:

```yaml
question: "レビュー結果への対応を選択してください"
header: "対応方針"
options:
  - label: "指摘を修正する"
    description: "CRITICAL/WARNINGの指摘に対応します"
  - label: "レビュー結果を確認のみ"
    description: "後で対応します"
  - label: "再レビュー"
    description: "修正後にもう一度レビューを実行します"
```

## 重要な制約

- **コードの変更はオーケストレーター自身では行わない**
- specなしモードでは PROTECTED 判定を行わない（仕様根拠がないため）
- specなしモードでも実装コードを読んでロジックの有無を確認する（次元12・13に必要）
- 再レビューは最大5回まで
