---
name: test-review
description: テストコード品質レビュースキル（オーケストレーター）。spec番号を指定すると計画ドキュメント（hearing-notes, exploration-report, implementation-plan, tasks.md）を読み込み、古典学派（Classical School）のテスト原則に基づいてテストコードをレビューする。test-quality-reviewerサブエージェントを起動してレビューを委譲し、結果を統合する。計画のテスト戦略を理解した上でレビューするため、仕様上のモック方針に従ったテストを「過剰なモック」と切り捨てない。番号省略時はarchive外で最大番号のspecを自動選択。「テストレビュー」「test review」「テスト品質チェック」「モック使いすぎ」「テストの書き方チェック」「古典学派」「classical school」「テストコードレビュー」「test-review」などでトリガー。
disable-model-invocation: true
argument-hint: "[番号]"
---

# テストコード品質レビュー（オーケストレーター）

spec番号を指定して、計画ドキュメントに基づくテストコード品質レビューを実行するスキル。
自分ではレビューせず、test-quality-reviewerサブエージェントを起動してレビューを委譲し、結果を統合する。

## ワークフロー

```
Step 0: Specフォルダの特定と検証
  ↓
Step 1: 計画ドキュメントの読み込み
  ↓
Step 2: テストコードの収集
  ↓
Step 3: サブエージェントを起動
  ↓
Step 4: 結果統合・保存
  ↓
Step 5: ユーザーへの提示とアクション提案
```

## Step 0: Specフォルダの特定と検証

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

以下の存在を確認する（.md または .html）:

1. `implementation-plan.md`（必須）— 存在しない場合はエラー終了
2. `tasks.md`（推奨）— 存在しない場合は WARNING を表示して続行
3. `hearing-notes.md`（推奨）— 存在しない場合は WARNING を表示して続行
4. `exploration-report.md`（推奨）— 存在しない場合は WARNING を表示して続行

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

## Step 1: 計画ドキュメントの読み込み

以下のファイルを Read で読み込む（存在するもののみ）:

1. `{spec_dir}/hearing-notes.md`（または `.html`）
2. `{spec_dir}/exploration-report.md`（または `.html`）
3. `{spec_dir}/implementation-plan.md`（または `.html`）
4. `{spec_dir}/tasks.md`（または `.html`）

### 抽出する情報

各文書からサブエージェントへの入力用に整理する:

- **テスト戦略**: TDD / ポスト実装 / 手動（implementation-plan）
- **モック方針**: どの層をモックするか（implementation-plan）
- **テストTODOリスト**: テストすべきシナリオ一覧（implementation-plan）
- **テストインフラ規約**: テストフレームワーク・ファイル配置・既存モックパターン（exploration-report）
- **要件・エッジケース**: テストで網羅すべきケース（hearing-notes）
- **変更ファイル一覧**: `[NEW]` / `[MODIFY]` / `[DELETE]`（implementation-plan）
- **タスク完了状態**: ■ / □（tasks.md）

## Step 2: テストコードの収集

### レビュー対象の決定

AskUserQuestion でレビュー範囲を確認する:

```yaml
question: "レビュー対象を選択してください"
header: "レビュー範囲"
options:
  - label: "全テストコード（推奨）"
    description: "implementation-planに記載されたテストファイルとgit diff内のテストファイルを対象にレビュー"
  - label: "完了タスクのテストのみ"
    description: "tasks.mdで■になっているタスクの関連テストファイルのみ"
  - label: "git diff（直近の変更）"
    description: "最新のgit diff内のテストファイルのみを対象にレビュー"
```

### テストファイルの検出

テストファイルのパターン: `*.test.*`, `*.spec.*`, `test_*.*`, `__tests__/**`

**「全テストコード」の場合**:
1. implementation-plan の変更ファイル一覧からテストファイルを抽出
2. `git diff --name-only` からテストファイルを抽出
3. 両方をマージして重複排除

**「完了タスクのテストのみ」の場合**:
1. tasks.md から ■ のテスト関連タスクを抽出
2. 対応するテストファイルを特定

**「git diff」の場合**:
1. `git diff --name-only` からテストファイルパターンにマッチするファイルを抽出

### 収集結果の整理

サブエージェントに渡すための情報を整理する:
- テストファイル一覧（パス）
- git diff の内容（テストファイル部分）
- テスト対象のソースファイル情報（内部/外部判定用）

## Step 3: サブエージェントを起動

出力先ディレクトリを作成:

```bash
mkdir -p {spec_dir}/test-review
```

### 連番の決定

既存のレビューファイルから次の連番を決定する:

```bash
next_num=$(printf "%03d" $(( $(ls -1 {spec_dir}/test-review/test-review-*.md 2>/dev/null | wc -l | tr -d ' ') + 1 )))
```

### エージェントを Task で起動

```
Task tool:

1. test-quality-reviewer:
   description: "test-quality-reviewer: {feature-name}"
   run_in_background: true
   prompt: |
     あなたは test-quality-reviewer エージェントです。
     計画ドキュメントを先に読んでテスト戦略を理解してから、古典学派のテスト原則に基づいてテストコードをレビューしてください。

     ## レビュー基準
     Read: {spec-based-code-review-plugin-path}/skills/test-review/references/test-review-rules.md
     Read: {spec-based-code-review-plugin-path}/skills/test-review/references/finding-classification.md

     ## 計画ドキュメント（先に読むこと）
     - {spec_dir}/implementation-plan.md
     - {spec_dir}/exploration-report.md
     - {spec_dir}/hearing-notes.md
     - {spec_dir}/tasks.md

     ## テストコード情報
     テストファイル一覧:
     {テストファイルリスト}

     git diff（テスト部分）:
     {git diff の内容}

     ## 出力先
     {spec_dir}/test-review/quality-{NNN}.md

     ## 重要
     - 計画ドキュメントを読んでからテストコードを読むこと
     - すべての指摘に「仕様根拠」を含めること
     - 仕様根拠のない指摘は出さないこと
     - 仕様のテスト戦略に従ったパターンは PROTECTED とすること
     - 外部依存への spy アサーションは CRITICAL にしないこと
     - 迷ったら PROTECTED 寄りに判定すること
```

### 完了待ち

```
TaskOutput:
  task_id: "{エージェントのtask_id}"
  block: true
  timeout: 300000
```

## Step 4: 結果統合・保存

サブエージェントの個別レポートを Read で読み込む:

1. `{spec_dir}/test-review/quality-{NNN}.md`

### 統合ルール

1. **通し番号で再採番**: C-001, W-001, P-001, I-001 から順に
2. **サマリー集計**: 各分類の件数を集計
3. **ルール別集計**: MOCK-SCOPE / BEHAVIOR-TEST ごとの指摘件数

### 統合レポート生成

テンプレート `test-review:test-review-report` に沿って統合レポートを生成し、以下に保存:

```
Write: {spec_dir}/test-review/test-review-{NNN}.md
```

## Step 5: ユーザーへの提示とアクション提案

### レビュー結果サマリーの提示

統合レポートのサマリーをユーザーに提示する:

- CRITICAL / WARNING / INFO / PROTECTED の件数
- CRITICAL がある場合は具体的な指摘内容を表示
- PROTECTED がある場合は「仕様により正当化されたテストパターン」として特筆

### 対応アクションの提案

CRITICAL または WARNING がある場合:

```yaml
question: "レビュー結果への対応を選択してください"
header: "対応方針"
options:
  - label: "指摘を修正する"
    description: "CRITICAL/WARNINGの指摘に対応します"
  - label: "レビュー結果を確認のみ"
    description: "レビュー結果を保存し、後で対応します"
  - label: "再レビュー"
    description: "修正後にもう一度レビューを実行します（連番インクリメント）"
```

### 「指摘を修正する」選択時

CRITICAL → WARNING の優先順でユーザーに指摘内容を提示し、修正を進める。修正後に「再レビュー」を提案する。

### 「再レビュー」選択時

連番をインクリメントして Step 2 からやり直す。最大5回までループ。5回超えたらユーザーに相談。

### 全て OK の場合

CRITICAL も WARNING もない場合は「テストコード品質レビュー完了 — 問題なし」と報告。PROTECTED がある場合はその一覧を添えて「仕様で正当化されたテストパターンが {n} 箇所あります」と報告。

## 出力ディレクトリ

```
.plugin-workspace/.specs/{nnn}-{feature-name}/
└── test-review/
    ├── quality-{NNN}.md        # test-quality-reviewer 出力
    └── test-review-{NNN}.md    # 統合レポート
```

## 重要な制約

- **コードの変更はオーケストレーター自身では行わない** — サブエージェントもレビュー結果の出力のみ
- implementation-plan.md が存在しない場合はレビューを実行しない
- 計画ドキュメントを読む前にレビューを開始しない（サブエージェントに対しても徹底）
- 仕様のテスト戦略に従ったパターンは PROTECTED として保護する
- 再レビューは最大5回まで
