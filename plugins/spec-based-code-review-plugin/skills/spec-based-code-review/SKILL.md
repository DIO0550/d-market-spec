---
name: spec-based-code-review
description: 仕様ベースコードレビュースキル（オーケストレーター）。spec番号を指定すると計画ドキュメント（hearing-notes, exploration-report, implementation-plan, tasks.md）を読み込み、4つの専門サブエージェント（パフォーマンス・設計・仕様整合性・テスト品質）が並列でコードレビューを実行する。計画の意図を理解した上でレビューするため、仕様上の理由で書かれたコードを「冗長」と切り捨てない。番号省略時はarchive外で最大番号のspecを自動選択。「specレビュー」「仕様レビュー」「spec review」「仕様整合性チェック」「計画に基づくレビュー」「実装が計画通りか確認」「意図ベースレビュー」「コードレビュー」「spec-based-code-review」「テストレビュー」「test review」「テスト品質チェック」「モック使いすぎ」「古典学派」などでトリガー。
disable-model-invocation: true
argument-hint: "[番号]"
---

# Spec-Based Code Review（オーケストレーター）

spec番号を指定して、計画ドキュメントに基づくコードレビューを実行するスキル。
自分ではレビューせず、4つの専門サブエージェント（performance-reviewer, design-reviewer, spec-alignment-reviewer, test-quality-reviewer）を並列起動してレビューを委譲し、結果を統合する。

## ワークフロー

```
Step 0: Specフォルダの特定と検証
  ↓
Step 1: 計画ドキュメントの読み込み
  ↓
Step 2: 実装コードの収集（git diff + 変更ファイル）
  ↓
Step 3: 3サブエージェントを並列起動
  ↓
Step 4: 結果統合・重複排除・保存
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
question: "PLANNINGファイルが残っています。計画フェーズがまだ進行中の可能性があります。現時点のコードでレビューを実行しますか？"
header: "PLANNING検出"
options:
  - label: "はい、レビューを実行"
    description: "現時点の実装コードに対してレビューを行います"
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

各文書から以下の情報をサブエージェントへの入力用に整理する:

- **目的とスコープ**（hearing-notes）
- **技術的制約と既存パターン**（exploration-report）
- **変更ファイル一覧**: `[NEW]` / `[MODIFY]` / `[DELETE]`（implementation-plan）
- **設計方針・データフロー・状態遷移**（implementation-plan）
- **テスト戦略とテストTODOリスト**（implementation-plan）
- **Definition of Done**（implementation-plan）
- **タスク完了状態**: ■ / □（tasks.md）

## Step 2: 実装コードの収集

### レビュー対象の決定

AskUserQuestion でレビュー範囲を確認する:

```yaml
question: "レビュー対象を選択してください"
header: "レビュー範囲"
options:
  - label: "全実装コード（推奨）"
    description: "implementation-planに記載された全ファイルを対象にレビュー"
  - label: "完了タスクのみ"
    description: "tasks.mdで■になっているタスクの関連ファイルのみ"
  - label: "git diff（直近の変更）"
    description: "最新のgit diffを対象にレビュー"
```

### コード情報の収集

選択に応じてコード情報を収集する:

**「全実装コード」の場合**:
1. implementation-plan の変更ファイル一覧（`[NEW]`/`[MODIFY]`/`[DELETE]`）を抽出
2. 各ファイルの存在確認
3. `git diff` で変更内容を取得

**「完了タスクのみ」の場合**:
1. tasks.md から ■ のタスクを抽出
2. 対応するファイルを特定
3. 該当ファイルの `git diff` を取得

**「git diff」の場合**:
1. `git diff` で変更一覧を取得
2. `git diff --name-only` で変更ファイル一覧を取得

### 収集結果の整理

サブエージェントに渡すための情報を整理する:
- 変更ファイル一覧（パス）
- git diff の内容
- `[NEW]` ファイルのフルパス

## Step 3: 4サブエージェントを並列起動

出力先ディレクトリを作成:

```bash
mkdir -p {spec_dir}/spec-based-code-review
```

### 連番の決定

既存のレビューファイルから次の連番を決定する:

```bash
next_num=$(printf "%03d" $(( $(ls -1 {spec_dir}/spec-based-code-review/review-*.md 2>/dev/null | wc -l | tr -d ' ') + 1 )))
```

### 4エージェントを同時に Task で起動

```
Task tool: (並列起動 — 4つ同時)

1. performance-reviewer:
   description: "performance-reviewer: {feature-name}"
   run_in_background: true
   prompt: |
     あなたは performance-reviewer エージェントです。
     計画ドキュメントを先に読んで実装の意図を理解してから、パフォーマンス観点でレビューしてください。

     ## レビュー基準
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/review-dimensions.md
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/finding-classification.md

     ## 計画ドキュメント（先に読むこと）
     - {spec_dir}/implementation-plan.md
     - {spec_dir}/exploration-report.md

     ## 実装コード情報
     変更ファイル一覧:
     {変更ファイルリスト}

     git diff:
     {git diff の内容（長すぎる場合はファイル単位で分割）}

     ## 出力先
     {spec_dir}/spec-based-code-review/performance-{NNN}.md

     ## 重要
     - 計画ドキュメントを読んでからコードを読むこと
     - すべての指摘に「仕様根拠」を含めること
     - 仕様根拠のない指摘は出さないこと
     - 仕様で意図的に選択されたアプローチは PROTECTED とすること

2. design-reviewer:
   description: "design-reviewer: {feature-name}"
   run_in_background: true
   prompt: |
     あなたは design-reviewer エージェントです。
     計画ドキュメントを先に読んで設計方針を理解してから、設計・アーキテクチャ観点でレビューしてください。

     ## レビュー基準
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/review-dimensions.md
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/finding-classification.md

     ## 計画ドキュメント（先に読むこと）
     - {spec_dir}/implementation-plan.md
     - {spec_dir}/exploration-report.md

     ## 実装コード情報
     変更ファイル一覧:
     {変更ファイルリスト}

     git diff:
     {git diff の内容}

     ## 出力先
     {spec_dir}/spec-based-code-review/design-{NNN}.md

     ## 重要
     - 計画ドキュメントを読んでからコードを読むこと
     - すべての指摘に「仕様根拠」を含めること
     - 仕様根拠のない指摘は出さないこと
     - 仕様の設計方針に従った構造は PROTECTED とすること

3. spec-alignment-reviewer:
   description: "spec-alignment-reviewer: {feature-name}"
   run_in_background: true
   prompt: |
     あなたは spec-alignment-reviewer エージェントです。
     全計画ドキュメントを読み込んで実装の意図を完全に理解してから、仕様整合性の6次元でレビューしてください。

     ## レビュー基準
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/review-dimensions.md
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/finding-classification.md

     ## 計画ドキュメント（全て読むこと）
     - {spec_dir}/hearing-notes.md
     - {spec_dir}/exploration-report.md
     - {spec_dir}/implementation-plan.md
     - {spec_dir}/tasks.md

     ## 実装コード情報
     変更ファイル一覧:
     {変更ファイルリスト}

     git diff:
     {git diff の内容}

     ## 出力先
     {spec_dir}/spec-based-code-review/alignment-{NNN}.md

     ## 重要
     - 4つ全ての計画ドキュメントを読んでからコードを読むこと
     - すべての指摘に「仕様根拠」を含めること
     - 仕様根拠のない指摘は出さないこと
     - 意図的複雑性の保護（次元5）を最優先で判定すること
     - 迷ったら PROTECTED 寄りに判定すること

4. test-quality-reviewer:
   description: "test-quality-reviewer: {feature-name}"
   run_in_background: true
   prompt: |
     あなたは test-quality-reviewer エージェントです。
     計画ドキュメントを先に読んでテスト戦略を理解してから、古典学派のテスト原則に基づいてテストコードをレビューしてください。

     ## レビュー基準
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/review-dimensions.md
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/finding-classification.md
     Read: {spec-based-code-review-plugin-path}/skills/spec-based-code-review/references/test-review-rules.md

     ## 計画ドキュメント（全て読むこと）
     - {spec_dir}/implementation-plan.md
     - {spec_dir}/exploration-report.md
     - {spec_dir}/hearing-notes.md
     - {spec_dir}/tasks.md

     ## テストコード情報
     テストファイル一覧:
     {テストファイルリスト}

     git diff（テスト部分）:
     {git diff の内容（テストファイル部分）}

     ## 出力先
     {spec_dir}/spec-based-code-review/test-quality-{NNN}.md

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
TaskOutput: (4つそれぞれ)
  task_id: "{各エージェントのtask_id}"
  block: true
  timeout: 300000
```

## Step 4: 結果統合・重複排除・保存

4つの個別レポートを Read で読み込む:

1. `{spec_dir}/spec-based-code-review/performance-{NNN}.md`
2. `{spec_dir}/spec-based-code-review/design-{NNN}.md`
3. `{spec_dir}/spec-based-code-review/alignment-{NNN}.md`
4. `{spec_dir}/spec-based-code-review/test-quality-{NNN}.md`

### 統合ルール

1. **重複排除**: 同じファイル・同じ行範囲に対する指摘をマージ
2. **PROTECTED優先**: あるエージェントが WARNING にしたが別が PROTECTED にした場合 → **PROTECTED が勝つ**
3. **通し番号で再採番**: C-001, W-001, P-001, I-001 から順に
4. **DoD充足状況**: spec-alignment-reviewer の DoD 検証結果をそのまま転記
5. **サマリー集計**: 各分類の件数を集計

### 統合レポート生成

テンプレート `spec-based-code-review:review-report` に沿って統合レポートを生成し、以下に保存:

```
Write: {spec_dir}/spec-based-code-review/review-{NNN}.md
```

## Step 5: ユーザーへの提示とアクション提案

### レビュー結果サマリーの提示

統合レポートのサマリーをユーザーに提示する:

- CRITICAL / WARNING / INFO / PROTECTED の件数
- CRITICAL がある場合は具体的な指摘内容を表示
- PROTECTED がある場合は「仕様により保護されたコード」として特筆

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

CRITICAL も WARNING もない場合は「仕様整合性レビュー完了 — 問題なし」と報告。PROTECTED がある場合はその一覧を添えて「仕様で正当化されたコードが {n} 箇所あります」と報告。

## 出力ディレクトリ

```
.plugin-workspace/.specs/{nnn}-{feature-name}/
└── spec-based-code-review/
    ├── performance-{NNN}.md       # performance-reviewer 出力
    ├── design-{NNN}.md            # design-reviewer 出力
    ├── alignment-{NNN}.md         # spec-alignment-reviewer 出力
    ├── test-quality-{NNN}.md      # test-quality-reviewer 出力
    └── review-{NNN}.md            # 統合レポート
```

## 重要な制約

- **コードの変更はオーケストレーター自身では行わない** — サブエージェントもレビュー結果の出力のみ
- implementation-plan.md が存在しない場合はレビューを実行しない
- 計画ドキュメントを読む前にレビューを開始しない（サブエージェントに対しても徹底）
- PROTECTED 優先ルールを統合時に必ず適用する
- 再レビューは最大5回まで
