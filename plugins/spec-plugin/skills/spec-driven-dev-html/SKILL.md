---
name: spec-driven-dev-html
description: 仕様策定ワークフローのHTML出力版。spec-driven-devと同じ計画プロセス（ヒアリング→探索→計画生成）を実行し、生成物をMarkdownではなく見やすいHTML形式で出力する。「仕様をHTMLで」「HTMLで計画」「spec html」「仕様書をHTMLにしたい」「読みやすい仕様書」などのキーワードでトリガー。
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(rm .plugin-workspace/.specs/*/PLANNING), Bash(rm .plugin-workspace/.specs/.guard/*)
---

# Spec-Driven Development (HTML Output)

spec-driven-devと同じ仕様策定ワークフローを実行し、**全生成物をHTML形式で出力**するバリアント。
CSSを埋め込んだ自己完結型HTMLを生成するため、ブラウザで開くだけで見やすいドキュメントになる。

## 🚨 絶対厳守: 最初にフォルダとPLANNINGファイルを作成

**このスキルが起動されたら、ユーザーへの質問・コード探索・実装の前に、必ず最初に Step 1（specフォルダ + PLANNINGファイル作成）を実行すること。**
Step 1 が完了するまで、他の一切のアクションを取ってはならない。

## ⚠️ 重要: システム図は必須

生成する implementation-plan.html には**必ずシステム図（状態マシン図 + データフロー図）を含めること**。
**ASCII罫線図を優先**し、mermaidは補助的に使用する。

## ⚠️ 重要: AutoCompact対策

PLANNINGファイルが存在する間は計画フェーズ。AutoCompact時にPreCompact hookがPLANNINGファイルを検出し警告を出力。
**PLANNINGファイルがある限り、絶対にコードを実装しない。**

## ⚠️ HTML出力ルール

全生成物は `.html` 形式で出力する。HTML生成時:

1. `assets/templates/style.css` を Read し、`<style>` タグとしてHTMLの `<head>` 内に埋め込む（`<link>` は使わない）
2. 対応するHTMLテンプレート（`assets/templates/*.html`）の構造に従う
3. プレースホルダ `{...}` を実際の内容で置換する
4. 出力は**自己完結型HTML**（外部ファイル参照なし、CSSインライン埋め込み）

## ワークフロー概要

```
1. specsフォルダ作成 + PLANNINGファイル配置
   ↓
2. AskUserQuestion形式でヒアリング → hearing-notes.html 書き出し
   ↓
3. codebase-explorer サブエージェント → exploration-report.html
   ↓
3.5. (条件付き) 探索後ヒアリング → hearing-notes.html 追記
   ↓
4. spec-planner サブエージェント → implementation-plan.html + tasks.html
   ↓
5. ユーザーに提示
   ↓
6. 実装開始許可後、PLANNINGファイル削除
```

## Step 1: specsフォルダ + PLANNINGファイル作成

spec-driven-dev と同一。以下の3ブロックを順に実行する。

### 1-a. 次のspec番号を算出

```bash
next_num=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* .plugin-workspace/.specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1)
next_num=$(printf "%03d" $(( 10#${next_num:-0} + 1 )))
```

### 1-b. specディレクトリとPLANNINGファイル作成

```bash
mkdir -p .plugin-workspace/.specs/${next_num}-{feature-name}
echo "${CLAUDE_SESSION_ID}" > .plugin-workspace/.specs/${next_num}-{feature-name}/PLANNING
```

### 1-c. ガードファイル作成

```bash
mkdir -p .plugin-workspace/.specs/.guard && touch .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID}
```

**重要**: PLANNINGファイルが存在する間は計画フェーズであり、コードの実装は禁止。
**ガード**: `.plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID}` が存在する間、`.plugin-workspace/.specs/` 以外への書き込みがhookによりブロックされる。

## Step 2: ヒアリング → hearing-notes.html 書き出し

AskUserQuestion でヒアリングし、結果を **hearing-notes.html** として出力する。
質問形式の詳細は `references/question-patterns.md` を参照。

### HTML生成手順

1. `assets/templates/style.css` を Read する
2. `assets/templates/hearing-notes.html` を Read する
3. テンプレートの `<link rel="stylesheet" href="style.css">` を `<style>{CSSの内容}</style>` に置換する
4. プレースホルダ `{...}` をヒアリング結果で置換する
5. `.plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes.html` に Write する

## Step 3: コードベース探索（codebase-explorer サブエージェントに委譲）

hearing-notes.html を書き出したら、codebase-explorer サブエージェントを起動する。

### 3-1. 探索ヒントの抽出

hearing-notes.html から探索キーワード（5-10個）、推定対象パス、探索の重点を抽出する。

### 3-2. サブエージェント起動

```
Task tool:
  description: "codebase-explorer: {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはcodebase-explorerエージェントです。
    .plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes.html を読み込み、
    その目的・スコープに基づいてコードベースを探索してください。

    ## 探索ヒント（オーケストレーターが抽出）
    **キーワード**: {キーワード5-10個}
    **推定対象パス**: {推定パターン}
    **探索の重点**: {重点事項}

    ## 参照スキル
    spec-driven-dev-html:exploration-perspectives

    ## 出力形式
    **HTML形式で出力すること。**
    1. spec-driven-dev-html:style を Read してCSSを取得
    2. spec-driven-dev-html:exploration-report を Read してテンプレートを取得
    3. テンプレートの <link> を <style>{CSS}</style> に置換
    4. プレースホルダを探索結果で埋める
    5. 自己完結型HTMLとして出力

    ## 出力先
    .plugin-workspace/.specs/{nnn}-{feature-name}/exploration-report.html
```

### 3-3. 探索結果の品質検証

exploration-report.html を読み込み、セクション 8「探索メトリクス」を確認。品質基準未達なら補完探索を最大1回実行する。

## Step 3.5: 探索後ヒアリング (条件付き)

spec-driven-dev と同一ロジック。論点があれば AskUserQuestion で聴取し、hearing-notes.html に追記する。

## Step 4: 実装計画生成（spec-planner サブエージェントに委譲）

```
Task tool:
  description: "spec-planner: {feature-name}"
  subagent_type: general-purpose
  run_in_background: true
  prompt: |
    あなたはspec-plannerエージェントです。
    以下のファイルを読み込み、implementation-plan.html と tasks.html を生成してください。

    ## 入力
    - .plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes.html
    - .plugin-workspace/.specs/{nnn}-{feature-name}/exploration-report.html

    ## 出力形式
    **HTML形式で出力すること。**
    1. spec-driven-dev-html:style を Read してCSSを取得
    2. spec-driven-dev-html:implementation-plan と spec-driven-dev-html:tasks を Read してテンプレートを取得
    3. テンプレートの <link> を <style>{CSS}</style> に置換
    4. プレースホルダを計画内容で埋める
    5. 自己完結型HTMLとして出力

    ## 出力先
    - .plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan.html
    - .plugin-workspace/.specs/{nnn}-{feature-name}/tasks.html

    ## 重要
    - システム図（状態マシン図 + データフロー図）は必須。省略禁止。ASCII罫線図を <pre><code> 内に記述。
    - exploration-report.html の制約・リスクを implementation-plan.html に反映すること。
    - "Definition of Done" セクションを必ず含めること。
    - テスト戦略分析を必ず実施すること。
    - 変更案の [NEW] には実装骨格、[MODIFY] には before/after コードスニペットを含めること。
```

## Step 5: ユーザー確認

生成したファイルをユーザーに提示:

1. **specフォルダパス**: `.plugin-workspace/.specs/{nnn}-{feature-name}/` を明示
2. 生成ファイル一覧（各ファイルのフルパス）:
   - `hearing-notes.html`
   - `exploration-report.html`
   - `implementation-plan.html`
   - `tasks.html`
3. **ブラウザで開く方法を案内**: `open .plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan.html`
4. implementation-plan.html の内容サマリー
5. tasks.html のタスク一覧

## Step 6: 実装開始（ユーザーによるガード解除）

spec-driven-dev と同一。ガードファイルとPLANNINGファイルの手動削除を案内する。

```
ユーザーへの案内:
  実装を開始するには、以下のコマンドを実行してください:
  rm .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID} .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
```

## 出力ディレクトリ

```
.plugin-workspace/.specs/
└── {nnn}-{feature-name}/
    ├── PLANNING                    # 計画中は存在、実装開始時に削除
    ├── hearing-notes.html          # ヒアリング結果（HTML）
    ├── exploration-report.html     # 探索レポート（HTML）
    ├── implementation-plan.html    # 実装計画（HTML）
    └── tasks.html                  # タスクリスト（HTML）
```
