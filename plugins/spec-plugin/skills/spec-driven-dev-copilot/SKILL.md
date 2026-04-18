---
name: spec-driven-dev-copilot
description: 仕様策定ワークフロー。GitHub Copilot CLIで実装計画をレビューする版。Codexが使えない環境向け。
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(rm .specs/*/PLANNING), Bash(rm .specs/.guard/*), Bash(copilot *)
---

# Spec-Driven Development (Copilot版)

機能実装前に仕様を明確化し、実装計画とタスクリストを生成するスキル。
ヒアリングはオーケストレーターが行い、**探索と計画生成は別々のサブエージェントに委譲**する。

## ⚠️ 重要: システム図は必須

このスキルで生成するimplementation-plan.mdには**必ずシステム図（状態マシン図 + データフロー図）を含めること**。
**ASCII罫線図を優先**し、mermaidは補助的に使用する。
システム図がないimplementation-plan.mdは不完全であり、生成完了とみなさない。

## ⚠️ 重要: AutoCompact対策

計画フェーズ中にAutoCompactが発生すると、コンテキストが要約され意図しない実装が始まる可能性がある。
これを防ぐため、**PLANNINGファイル**を使用して計画中であることを明示する。

- `.specs/{nnn}-{feature-name}/PLANNING` ファイルが存在する間は**計画フェーズ**
- AutoCompact時にPreCompact hookがPLANNINGファイルを検出し、警告を出力
- **PLANNINGファイルがある限り、絶対にコードを実装しない**

## ワークフロー概要

```
1. specsフォルダ作成 + PLANNINGファイル配置
   ↓
2. AskUserQuestion形式でヒアリング → hearing-notes.md 書き出し
   ↓
3. codebase-explorer サブエージェント → exploration-report.md
   ↓
3.5. (条件付き) 探索後ヒアリング → hearing-notes.md 追記
   ↓
4. spec-planner サブエージェント → implementation-plan.md + tasks.md
   ↓
5. Copilotレビュー → 修正ループ（自動）
   ↓
6. ユーザーに提示
   ↓
7. 実装開始許可後、PLANNINGファイル削除
```

## Step 1: specsフォルダ + PLANNINGファイル作成

ヒアリング開始前に、specディレクトリとPLANNINGファイルを作成する。以下の3ブロックを順に実行する。

### 1-a. 次のspec番号を算出

`.specs/` と `.specs/archive/` の両方をスキャンし、最大番号+1 をゼロ埋め3桁で `$next_num` にセットする。

```bash
next_num=$(ls -1d .specs/[0-9][0-9][0-9]-* .specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1)
next_num=$(printf "%03d" $(( 10#${next_num:-0} + 1 )))
```

### 1-b. specディレクトリとPLANNINGファイル作成

`{feature-name}` は実際の機能名（kebab-case）に置き換えてコマンドを発行する。

```bash
mkdir -p .specs/${next_num}-{feature-name}
echo "${CLAUDE_SESSION_ID}" > .specs/${next_num}-{feature-name}/PLANNING
```

### 1-c. ガードファイル作成

```bash
mkdir -p .specs/.guard && touch .specs/.guard/${CLAUDE_SESSION_ID}
```

作成されるディレクトリは例: `.specs/003-user-auth`。

**重要**: PLANNINGファイルが存在する間は計画フェーズであり、コードの実装は禁止。
**ガード**: `.specs/.guard/${CLAUDE_SESSION_ID}` が存在する間、このセッションでは `.specs/` 以外への書き込みがhookによりブロックされる。

## Step 2: ヒアリング → hearing-notes.md 書き出し

ユーザーの要求を受けたら、AskUserQuestion で質問し、結果を `.specs/{nnn}-{feature-name}/hearing-notes.md` に書き出す。

一度に1-4個の質問をまとめて聞く。

### 必須ヒアリング項目

**Batch 1: スコープ確認**
探索範囲を絞り込み、関係ないコードの読み込みを避けるために確認する。
- 何を実現したいか（目的）
- 影響範囲（新規 / 既存修正）

**Batch 2: 技術的詳細**
実装計画の精度を高め、既存コードとの整合性を確保するために確認する。
- 使用技術・フレームワーク
- 依存関係
- データ構造・API設計

**Batch 3: 品質要件**
テスト計画とエッジケースの洗い出しに必要な情報を確認する。
- エッジケース・エラーハンドリング
- テスト要件
- パフォーマンス要件

質問形式の詳細は `references/question-patterns.md` を参照。

### hearing-notes.md 書き出し

ヒアリング完了後、テンプレートに沿って結果をファイルに書き出す。

テンプレート: `assets/templates/hearing-notes.md`
出力先: `.specs/{nnn}-{feature-name}/hearing-notes.md`

## Step 3: コードベース探索（codebase-explorer サブエージェントに委譲）

hearing-notes.md を書き出したら、codebase-explorer サブエージェントを起動する。

### 3-1. 探索ヒントの抽出

サブエージェント起動前に、hearing-notes.md の内容から以下を抽出する：

- **探索キーワード**: 機能名、技術用語、ライブラリ名、コンポーネント名など（5-10個）
- **推定対象パス**: 影響しそうなディレクトリやファイルパターン（hearing-notesの技術スタック・影響範囲から推定）
- **探索の重点**: 新規機能なら類似実装の発見を重視、既存修正なら依存の逆引きを重視

### 3-2. サブエージェント起動

```
Task tool:
  description: "codebase-explorer: {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはcodebase-explorerエージェントです。
    .specs/{nnn}-{feature-name}/hearing-notes.md を読み込み、
    その目的・スコープに基づいてコードベースを探索してください。

    ## 探索ヒント（オーケストレーターが抽出）

    **キーワード**: {hearing-notesから抽出したキーワード5-10個をカンマ区切りで列挙}
    **推定対象パス**: {推定したディレクトリ/ファイルパターンを列挙}
    **探索の重点**: {新規→類似実装発見 / 既存修正→依存逆引き / リファクタリング→全使用箇所 等}

    ## 参照スキル
    spec-driven-dev-copilot:exploration-perspectives

    ## テンプレート
    spec-driven-dev-copilot:exploration-report

    ## 出力先
    .specs/{nnn}-{feature-name}/exploration-report.md
```

`{...}` はオーケストレーターが hearing-notes.md の内容に基づいて埋める。

```
TaskOutput:
  task_id: "{codebase-explorerのtask_id}"
  block: true
  timeout: 300000
```

### 3-3. 探索結果の品質検証

TaskOutput 受信後、exploration-report.md を読み込み、セクション 8「探索メトリクス」を確認する：

1. **基準チェック**:
   - Read したファイル数が 10 未満 → 補完探索を要求
   - コードスニペット数が 5 未満 → 補完探索を要求
   - 逆引き検索が「未実施」→ 補完探索を要求

2. **空セクション検出**:
   - セクション 1-5 のいずれかがテンプレートのプレースホルダのまま → 補完探索を要求

3. **補完探索の実行**（品質基準未達の場合のみ、**最大 1 回**）:

```
Task tool:
  description: "codebase-explorer (補完): {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはcodebase-explorerエージェントです。
    前回の探索レポートが品質基準に達していないため、補完探索を行います。

    ## 前回のレポート
    .specs/{nnn}-{feature-name}/exploration-report.md

    ## 不足している項目
    {具体的な不足項目を列挙}

    ## 指示
    前回のレポートに不足している情報を追加してください。
    特に以下に重点を置いてください：
    - 不足しているコードスニペットの追加（ファイルを Read して具体的なコードを記載）
    - 不足しているセクションの探索と記入
    - 探索メトリクスの更新

    ## 参照スキル
    spec-driven-dev-copilot:exploration-perspectives

    ## 出力先
    .specs/{nnn}-{feature-name}/exploration-report.md（上書き更新）
```

```
TaskOutput:
  task_id: "{補完codebase-explorerのtask_id}"
  block: true
  timeout: 300000
```

探索の5カテゴリ: アーキテクチャ概要 / 関連コード分析 / 技術的制約・リスク / 変更影響範囲 / テストインフラストラクチャ

詳細は `references/exploration-perspectives.md` を参照。

## Step 3.5: 探索後ヒアリング (条件付き)

exploration-report.md を読み込み、ユーザー判断が必要な論点を抽出する。論点が無ければスキップして Step 4 へ進む。

### 3.5-1. 論点抽出

以下のセクションをスキャンし、ユーザー確認が必要な論点を最大 5 件抽出する:

- **Section 3 技術的制約・リスク**: 対応方針が複数ある場合
- **Section 4 変更影響範囲**: 破壊的変更の方針判断が必要な場合
- **Section 6 追加調査が必要な項目**: 設計判断に直結する未確定事項
- **Section 2.2 再利用可能なパターン**: 候補が複数ある場合の選択

抽出した論点を exploration-report.md の Section 7「ユーザー判断が必要な論点」に書き戻す（監査証跡）。

### 3.5-2. 論点の有無で分岐

- **論点 0 件**: Section 7 に「該当なし」と記載し、Step 4 へ進む
- **論点 1 件以上**: 3.5-3 へ進む

### 3.5-3. AskUserQuestion 発動

論点を重要度順に並べ、上位 4 件 (AskUserQuestion 上限) を 1 ターンで一括聴取する。

- **question**: 論点の概要 (1 文)
- **header**: 12 文字以内の短いラベル
- **options**: 探索で見つかった選択肢 + 推奨案を先頭に「(推奨)」付きで配置
- 5 件以上ある場合、優先度の低いものは Section 7 末尾の「未確認論点」に記載し、spec-planner が assumption として扱う

### 3.5-4. hearing-notes.md に追記

AskUserQuestion の回答結果を hearing-notes.md 末尾の `## 探索後ユーザー判断` セクションに追記する:

- 各論点 (question) と選択された option label
- ユーザーが Other で自由記述した場合はその内容も含める

## Step 4: 実装計画生成（spec-planner サブエージェントに委譲）

exploration-report.md が完成したら、spec-planner サブエージェントを起動する。

```
Task tool:
  description: "spec-planner: {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはspec-plannerエージェントです。
    以下のファイルを読み込み、implementation-plan.md と tasks.md を生成してください。

    ## 入力
    - .specs/{nnn}-{feature-name}/hearing-notes.md
    - .specs/{nnn}-{feature-name}/exploration-report.md

    ## テンプレート
    - spec-driven-dev-copilot:implementation-plan
    - spec-driven-dev-copilot:tasks

    ## 出力先
    - .specs/{nnn}-{feature-name}/implementation-plan.md
    - .specs/{nnn}-{feature-name}/tasks.md

    ## 重要
    - システム図（状態マシン図 + データフロー図）は必須。省略禁止。ASCII罫線図を優先。
    - exploration-report.md の制約・リスクを implementation-plan.md に反映すること。
    - implementation-plan.md に "## Definition of Done" セクションを必ず含めること。機能固有の受入条件を具体的に記載すること。
    - テスト戦略分析を必ず実施すること。references/test-design-patterns.md に基づき、機能タイプを分類してテストパターンを決定すること。
    - テスト要件がある場合、t-wada TDD ベースで tasks.md を構成すること（Red-Green-Refactor サイクル、TODOリスト駆動）。テンプレートの TDD 構成例を参照。
    - 変更案セクションの [NEW] には実装骨格（型定義・関数シグネチャ・import文）、[MODIFY] には before/after 形式のコードスニペットを必ず含めること。
```

```
TaskOutput:
  task_id: "{spec-plannerのtask_id}"
  block: true
  timeout: 300000
```

## Step 5: Copilotレビューループ

生成した implementation-plan.md を GitHub Copilot CLI でレビューする。
レビュー結果はファイルに保存し、コンテキストの消費を抑える。

### レビュー結果の保存先

```bash
mkdir -p .specs/{nnn}-{feature-name}/plan-review
```

レビュー結果は `.specs/{nnn}-{feature-name}/plan-review/review-{NNN}.md` に保存する。
`{NNN}` は3桁の連番（001, 002, 003...）。

### コンテキストファイルの組み立て

レビュー実行前に、Writeツールで `.specs/{nnn}-{feature-name}/plan-review/prompt-{NNN}.txt` にレビュー指示文を書き出す。
`{NNN}` は `review-{NNN}.md` と同じ連番。再レビュー時はインクリメントする。
コンテキストは `implementation-plan.md` をそのまま使用する（別ファイル不要）。

**prompt-{NNN}.txt の内容**:

```
以下の実装計画をレビューしてください。

【重要】ファイルの作成・編集は一切行わないでください。レビュー結果は標準出力のみで回答してください。

レビュー観点:
1. 仕様の曖昧さ・抜け漏れはないか
2. 実装可能性に問題はないか
3. エッジケースは考慮されているか
4. ファイル構成は妥当か
5. 全体アーキテクチャとの整合性はあるか

問題がなければ「問題なし」と回答してください。
問題があれば具体的な指摘と改善案を提示してください。

以下は標準入力で渡される implementation-plan.md の内容です:
```

### レビュー実行

プロンプトファイルを `cat` で読み込んで `copilot -p` に渡し、対象の implementation-plan.md を標準入力で渡した結果を `.specs/` 配下に出力する。

```bash
copilot -p "$(cat .specs/{nnn}-{feature-name}/plan-review/prompt-{NNN}.txt)" < .specs/{nnn}-{feature-name}/implementation-plan.md > .specs/{nnn}-{feature-name}/plan-review/review-{NNN}.md
```

### ループ処理

1. 保存したレビュー結果ファイルを読み込み、内容を解析
2. 「問題なし」なら Step 6 へ
3. 問題があれば:
   - 指摘内容を元に implementation-plan.md を修正
   - 連番をインクリメントして再度 Copilot レビューを実行・保存
   - 最大5回までループ

レビュー観点の詳細は `references/review-criteria.md` を参照。

## Step 6: ユーザー確認

生成したファイルをユーザーに提示:

1. **specフォルダパス**: `.specs/{nnn}-{feature-name}/` を明示
2. 生成ファイル一覧（各ファイルのフルパス）:
   - `.specs/{nnn}-{feature-name}/hearing-notes.md`
   - `.specs/{nnn}-{feature-name}/exploration-report.md`
   - `.specs/{nnn}-{feature-name}/implementation-plan.md`
   - `.specs/{nnn}-{feature-name}/tasks.md`
3. implementation-plan.md の内容サマリー
4. tasks.md のタスク一覧
5. 「修正が必要な場合はお知らせください」

ユーザーが修正を要求した場合は Step 5 のループに戻る。

## Step 7: 実装開始（ユーザーによるガード解除）

計画が完了したら、ユーザーに以下を案内する:

1. ガードファイルの削除（**ユーザーが手動で実行**）
2. PLANNINGファイルの削除

```
ユーザーへの案内:
  実装を開始するには、以下のコマンドを実行してください:
  rm .specs/.guard/${CLAUDE_SESSION_ID} .specs/{nnn}-{feature-name}/PLANNING
```

**注意**: ガードファイルはhookにより自動削除がブロックされる。必ずユーザーが手動で削除すること。
**注意**: ガード解除前に実装コードを書いてはならない。

## 出力ディレクトリ

```
.specs/
└── {nnn}-{feature-name}/
    ├── PLANNING                 # 計画中は存在、実装開始時に削除
    ├── hearing-notes.md         # ヒアリング結果（オーケストレーター生成）
    ├── exploration-report.md    # 探索レポート（codebase-explorer 生成）
    ├── implementation-plan.md   # 実装計画（spec-planner 生成）
    ├── tasks.md                 # タスクリスト（spec-planner 生成）
    └── plan-review/             # Copilotレビュー結果
        ├── review-001.md
        ├── review-002.md
        └── ...
```

`{nnn}` は `.specs/` 内の既存フォルダ数に基づく3桁の連番（001, 002, 003...）
`{feature-name}` はケバブケースで命名（例: `001-user-authentication`, `002-block-button`）
