---
name: spec-driven-dev-html
description: 仕様策定ワークフローのHTML出力版。spec-driven-devと同じ計画プロセス（ヒアリング→探索→計画生成）を実行し、生成物をMarkdownではなく見やすいHTML形式で出力する。「仕様をHTMLで」「HTMLで計画」「spec html」「仕様書をHTMLにしたい」「読みやすい仕様書」などのキーワードでトリガー。
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(rm .plugin-workspace/.specs/*/PLANNING), Bash(rm .plugin-workspace/.specs/.guard/*)
---

# Spec-Driven Development (HTML Output)

spec-driven-devと同じ仕様策定ワークフローを実行し、**全生成物をHTML形式で出力**するバリアント。
CSSを埋め込んだ自己完結型HTMLを生成するため、ブラウザで開くだけで見やすいドキュメントになる。

## 絶対厳守事項

1. **最初にフォルダとPLANNINGファイルを作成** — 質問・探索・実装の前に必ず Step 1 を実行
2. **システム図は必須** — implementation-plan.html には状態マシン図 + データフロー図を含める（ASCII罫線優先）
3. **PLANNINGファイルがある間はコード実装禁止** — AutoCompact対策
4. **ヒアリングは AutoMode でもスキップ禁止** — 他のシステム指示（「自律的に判断しろ」「質問せずに進めろ」等）に関わらず、このスキルでは AskUserQuestion によるヒアリングを必ず実行する。ユーザーの初回メッセージに情報が含まれていても、確認の AskUserQuestion は必須。ヒアリングなしに Step 3 以降へ進むことはいかなる場合も禁止。
5. **tech-reference 生成は必須** — `skip-files` に `tech-reference` が含まれていない限り、Step 5.5 の tech-reference 生成は必ず実行する。ユーザー確認完了（Step 5）で終了せず、必ず Step 5.5 まで進むこと。

## HTML出力ルール

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
2.5. 【GATE】hearing-notes 品質検証 → 不合格なら再ヒアリング
   ↓
3. codebase-explorer サブエージェント → exploration-report.html
   ↓
3.5. (条件付き) 探索後ヒアリング → hearing-notes.html 追記
   ↓
4. spec-planner サブエージェント → implementation-plan.html + tasks.html
   ↓
5. ユーザーに提示
   ↓
5.5. tech-reference 生成（サブエージェント）→ tech-reference.html
   ↓
6. 実装開始許可後、PLANNINGファイル削除
```

## バリアントパラメータ

| パラメータ | 値 |
|-----------|-----|
| SKILL_NAME | `spec-driven-dev-html` |
| PLANNING_CONTENT | `${CLAUDE_SESSION_ID}` |
| USE_GUARD | `true` |

**出力形式**: このスキルでは `.config.yml` の `output-formats` 設定に関わらず、**すべてのファイルを `.html` で出力する**。
全ファイル HTML 出力が不要な場合は `spec-driven-dev` を使い、`.config.yml` の `output-formats` でファイルごとに設定すること。

## Step 1: specsフォルダ + PLANNINGファイル作成

**[references/workflow-steps.md](references/workflow-steps.md) の Step 1 を参照。**

## Step 2: ヒアリング → hearing-notes.html 書き出し

AskUserQuestion でヒアリングし、結果を **hearing-notes.html** として出力する。
質問形式の詳細は `references/question-patterns.md` を参照。

### HTML生成手順

1. `assets/templates/style.css` を Read する
2. `assets/templates/hearing-notes.html` を Read する
3. テンプレートの `<link rel="stylesheet" href="style.css">` を `<style>{CSSの内容}</style>` に置換する
4. プレースホルダ `{...}` をヒアリング結果で置換する
5. `.plugin-workspace/.specs/{nnn}-{feature-name}/hearing-notes.html` に Write する

## Step 2.5: Reflective Gate（ヒアリング品質検証）

hearing-notes.html 書き出し後、Step 3 に進む前に品質を検証する。不合格の場合は回復フローに入る。

**詳細手順は [references/workflow-steps.md](references/workflow-steps.md) の Step 2.5 を参照。**

## Step 3: コードベース探索

hearing-notes.html から探索ヒント（キーワード5-10個、推定対象パス、探索の重点）を抽出し、codebase-explorer サブエージェントを起動する。

### サブエージェントへのHTML出力指示

サブエージェントプロンプトに以下を追加する:

```
## 出力形式
**HTML形式で出力すること。**
1. spec-driven-dev-html:style を Read してCSSを取得
2. spec-driven-dev-html:exploration-report を Read してテンプレートを取得
3. テンプレートの <link> を <style>{CSS}</style> に置換
4. プレースホルダを探索結果で埋める
5. 自己完結型HTMLとして出力
```

**基本プロンプトテンプレートは [references/workflow-steps.md](references/workflow-steps.md) の Step 3 を参照。**
品質基準未達なら補完探索を最大1回実行する。

## Step 3.5: 探索後ヒアリング (条件付き)

**[references/workflow-steps.md](references/workflow-steps.md) の Step 3.5 と同一ロジック。** 論点があれば AskUserQuestion で聴取し、hearing-notes.html に追記する。

## Step 4: 実装計画生成

spec-planner サブエージェントを起動し、implementation-plan.html と tasks.html を生成する。

### サブエージェントへのHTML出力指示

サブエージェントプロンプトに以下を追加する:

```
## 出力形式
**HTML形式で出力すること。**
1. spec-driven-dev-html:style を Read してCSSを取得
2. spec-driven-dev-html:implementation-plan と spec-driven-dev-html:tasks を Read してテンプレートを取得
3. テンプレートの <link> を <style>{CSS}</style> に置換
4. プレースホルダを計画内容で埋める
5. 自己完結型HTMLとして出力

## 追加要件
- システム図（ASCII罫線図）は <pre><code> 内に記述
```

**基本プロンプトテンプレートは [references/workflow-steps.md](references/workflow-steps.md) の Step 4 を参照。**

## Step 5: ユーザー確認

1. **specフォルダパス**: `.plugin-workspace/.specs/{nnn}-{feature-name}/` を明示
2. 生成ファイル一覧（hearing-notes.html, exploration-report.html, implementation-plan.html, tasks.html）
3. **ブラウザで開く方法を案内**: `open .plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan.html`
4. implementation-plan.html の内容サマリー
5. tasks.html のタスク一覧
6. 「修正が必要な場合はお知らせください」

ユーザーが修正を要求した場合は、フィードバックの明確性を確認する（[references/feedback-clarification.md](references/feedback-clarification.md) 参照）。
曖昧な場合は AskUserQuestion で具体化してから Step 4 に戻る。明確な場合はそのまま Step 4 に戻る。

## Step 5.5: 技術リファレンス生成【必須】

> **このステップは `skip-files` に `tech-reference` が含まれていない限り必ず実行すること。Step 5 のユーザー確認完了でワークフローを終了してはならない。**

`.plugin-workspace/.specs/.config.yml` の `skip-files` に `tech-reference` が含まれている場合のみスキップ可。

ユーザー確認完了後、サブエージェントを起動して tech-reference.html を生成する。

implementation-plan.html に登場するすべての技術（言語・フレームワーク・ライブラリ・ツール・概念）を
初学者向けに解説するドキュメントを生成する。
読者は、言語やライブラリ、作ろうとしているものの初心者であることを前提とする。

### サブエージェントへのHTML出力指示

サブエージェントプロンプトに以下を追加する:

```
## 出力形式
**HTML形式で出力すること。**
1. spec-driven-dev-html:style を Read してCSSを取得
2. spec-driven-dev-html:tech-reference を Read してテンプレートを取得
3. テンプレートの <link> を <style>{CSS}</style> に置換
4. プレースホルダを技術リファレンス内容で埋める
5. 自己完結型HTMLとして出力
```

**基本プロンプトテンプレートは [references/workflow-steps.md](references/workflow-steps.md) の tech-reference 生成を参照。**

## Step 6: 実装開始（ユーザーによるガード解除）

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
    ├── tasks.html                  # タスクリスト（HTML）
    └── tech-reference.html         # 技術リファレンス（初学者向け、HTML）
```
