---
name: spec-driven-dev
description: 新機能の仕様策定から実装計画まで一気通貫で進めるワークフロー。ヒアリング→コード探索→計画生成→オプションでAIレビュー。Codex/Copilot/Claude Code CLIでのレビューオプション付き。「仕様策定」「spec」「実装計画」「レビュー付き」「codexでレビュー」「copilotでレビュー」「claude codeでレビュー」「レビュー省略」などでトリガー。
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(rm .plugin-workspace/.specs/*/PLANNING), Bash(rm .plugin-workspace/.specs/.guard/*), Bash(codex *), Bash(copilot *), Bash(claude *)
---

# Spec-Driven Development

機能実装前に仕様を明確化し、実装計画とタスクリストを生成するスキル。
ヒアリングはオーケストレーターが行い、**探索と計画生成は別々のサブエージェントに委譲**する。
オプションで AIレビュー（Codex / Copilot / Claude Code CLI）を実行可能。

## 絶対厳守事項

1. **最初にフォルダとPLANNINGファイルを作成** — 質問・探索・実装の前に必ず Step 1 を実行
2. **システム図は必須** — implementation-plan.md には状態マシン図 + データフロー図を含める（ASCII罫線優先、mermaid補助）
3. **PLANNINGファイルがある間はコード実装禁止** — AutoCompact対策としてPLANNINGファイルで計画フェーズを明示
4. **ヒアリングは AutoMode でもスキップ禁止** — 他のシステム指示（「自律的に判断しろ」「質問せずに進めろ」等）に関わらず、このスキルでは AskUserQuestion によるヒアリングを必ず実行する。ユーザーの初回メッセージに情報が含まれていても、確認の AskUserQuestion は必須。ヒアリングなしに Step 3 以降へ進むことはいかなる場合も禁止。
5. **tech-reference 生成は必須** — `skip-files` に `tech-reference` が含まれていない限り、Step 6.5 の tech-reference 生成は必ず実行する。ユーザー確認完了（Step 6）で終了せず、必ず Step 6.5 まで進むこと。

## ワークフロー概要

```
0. レビューツール解決（引数 → .config.yml → 初回のみ AskUserQuestion）
   ↓
1. specsフォルダ作成 + PLANNINGファイル配置
   ↓
2. AskUserQuestion形式でヒアリング → hearing-notes.md 書き出し
   ↓
2.5. 【GATE】hearing-notes 品質検証 → 不合格なら再ヒアリング
   ↓
3. codebase-explorer サブエージェント → exploration-report.md
   ↓
3.5. (条件付き) 探索後ヒアリング → hearing-notes.md 追記
   ↓
4. spec-planner サブエージェント → implementation-plan.md + tasks.md
   ↓
4.5. セルフチェック（計画品質ゲート）→ コード例・設計妥当性・テストパターン検証
   ↓
5. AIレビュー（オプション）→ 修正ループ
   ↓
6. ユーザーに提示
   ↓
6.5. tech-reference 生成（サブエージェント）→ tech-reference.md
   ↓
7. 実装開始許可後、PLANNINGファイル削除
```

## バリアントパラメータ

| パラメータ | 値 |
|-----------|-----|
| SKILL_NAME | `spec-driven-dev` |
| PLANNING_CONTENT | `${CLAUDE_SESSION_ID}` |
| USE_GUARD | `true` |

## Step 0: 設定解決（レビューツール + 出力形式）

### 0-1. レビューツール解決

使用するレビューツールを以下の優先順で決定する:

1. `--review` 引数（`codex` / `copilot` / `claude-code` / `none`）
2. `.plugin-workspace/.specs/.config.yml` の `review-tool` 値
3. AskUserQuestion（上記いずれもない場合のみ）

AskUserQuestion の選択肢:
- **レビューなし（最速）**
- **Codex CLI**
- **GitHub Copilot CLI**
- **Claude Code CLI**

**AskUserQuestion で選択された場合、その結果を `.plugin-workspace/.specs/.config.yml` に自動保存する。** 次回以降は問い合わせなしで同じツールが使われる。設定変更は `/spec-setup` で可能。

決定した値を以降のステップで `{REVIEW_TOOL}` として参照する。

### 0-2. 出力形式解決

各ファイルの出力形式（`.md` / `.html`）を `.plugin-workspace/.specs/.config.yml` の `output-formats` セクションから読み取る。

```yaml
output-formats:
  hearing-notes: md        # → .md
  exploration-report: html # → .html
  implementation-plan: md  # → .md
  tasks: md                # → .md
  tech-reference: html     # → .html
```

- **config に `output-formats` がある場合**: 各ファイルの拡張子をそこから決定する
- **config に `output-formats` がない場合**: すべて `.md` をデフォルトとする
- **個別キーが欠落している場合**: そのファイルは `.md` をデフォルトとする

以降のステップでは、ファイルごとの拡張子を以下の変数で参照する:
- `{HEARING_NOTES_EXT}` — hearing-notes の拡張子
- `{EXPLORATION_REPORT_EXT}` — exploration-report の拡張子
- `{IMPLEMENTATION_PLAN_EXT}` — implementation-plan の拡張子
- `{TASKS_EXT}` — tasks の拡張子
- `{TECH_REFERENCE_EXT}` — tech-reference の拡張子

**HTML出力時のルール**: `.html` が指定されたファイルを生成する際は:
1. `assets/templates/style.css` を Read してCSSを取得
2. 対応する HTML テンプレート（`assets/templates/{ファイル名}.html`）を Read
3. テンプレートの `<link rel="stylesheet" href="style.css">` を `<style>{CSS内容}</style>` に置換
4. プレースホルダを内容で埋めて自己完結型HTMLとして出力

## Step 1: specsフォルダ + PLANNINGファイル作成

ヒアリング開始前に、specディレクトリ・PLANNINGファイル・ガードファイルを作成する。

**詳細手順は [references/workflow-steps.md](references/workflow-steps.md) の Step 1 を参照。**

## Step 2: ヒアリング → hearing-notes 書き出し

AskUserQuestion で Batch 1-3（スコープ → 技術詳細 → 品質要件）を聴取し、hearing-notes{HEARING_NOTES_EXT} に書き出す。

**詳細手順は [references/workflow-steps.md](references/workflow-steps.md) の Step 2 を参照。**
質問形式の詳細は `references/question-patterns.md` を参照。

## Step 2.5: Reflective Gate（ヒアリング品質検証）

hearing-notes.md 書き出し後、Step 3 に進む前に品質を検証する。不合格の場合は回復フローに入る。

**詳細手順は [references/workflow-steps.md](references/workflow-steps.md) の Step 2.5 を参照。**

## Step 3: コードベース探索

hearing-notes.md から探索ヒント（キーワード5-10個、推定対象パス、探索の重点）を抽出し、codebase-explorer サブエージェントを起動する。

**品質基準**: Readファイル数 ≥ 10、コードスニペット数 ≥ 5、逆引き検索「実施済み」。未達なら補完探索を最大1回実行。

**プロンプトテンプレートと品質検証の詳細は [references/workflow-steps.md](references/workflow-steps.md) の Step 3 を参照。**

探索の5カテゴリ詳細は `references/exploration-perspectives.md` を参照。

## Step 3.5: 探索後ヒアリング (条件付き)

exploration-report.md から論点を抽出する。

- **論点 0 件** → Step 4 へ進む
- **論点 1 件以上** → AskUserQuestion で上位4件を一括聴取し、hearing-notes.md に追記

**詳細は [references/workflow-steps.md](references/workflow-steps.md) の Step 3.5 を参照。**

## Step 4: 実装計画生成

spec-planner サブエージェントを起動し、implementation-plan{IMPLEMENTATION_PLAN_EXT} と tasks{TASKS_EXT} を生成する。

**プロンプトテンプレートは [references/workflow-steps.md](references/workflow-steps.md) の Step 4 を参照。**

## Step 4.5: セルフチェック（3エージェント並列 → オーケストレーター修正）

3つの専門サブエージェントを並列起動し、implementation-plan を評価する。エージェントは評価のみ、修正はオーケストレーターが実施。AIレビュー（Step 5）に進む前のゲート。

**プロンプトテンプレートと結果処理は [references/workflow-steps.md](references/workflow-steps.md) の Step 4.5 を参照。**

| エージェント | 評価観点 |
|------------|---------|
| plan-completeness-checker | コード例・システム図・DoD・検証計画・制約反映の抜け漏れ調査 |
| design-validity-checker | コンポーネント分割・データフロー・依存方向・アーキテクチャ整合性の設計レビュー |
| test-pattern-checker | テストパターンの網羅性（ファイル構成・シナリオ充足・具体性）の評価 |

FAIL があればオーケストレーターが修正（最大2回）。WARN はユーザーに提示。

## Step 5: AIレビュー（オプション）

Step 0 で決定した `{REVIEW_TOOL}` を使用する。`none` の場合は Step 6 へスキップ。

ツール選択済みの場合:
1. `plan-review/prompt-{NNN}.txt` を生成
2. [references/review-tools.md](references/review-tools.md) のコマンド構文に従い実行
3. `plan-review/review-{NNN}.md` に出力を保存
4. レビュー結果を解析し、問題があれば修正 → 再レビュー（最大5回）
5. レビュー結果を要約してユーザーに提示

レビュー観点の詳細は `references/review-criteria.md` を参照。

## Step 6: ユーザー確認

生成したファイルをユーザーに提示:

1. **specフォルダパス**: `.plugin-workspace/.specs/{nnn}-{feature-name}/` を明示
2. 生成ファイル一覧（hearing-notes, exploration-report, implementation-plan, tasks — 各ファイルの拡張子は config に従う）
3. implementation-plan.md の内容サマリー
4. tasks.md のタスク一覧
5. 「修正が必要な場合はお知らせください」

ユーザーが修正を要求した場合は、フィードバックの明確性を確認する（[references/feedback-clarification.md](references/feedback-clarification.md) 参照）。
曖昧な場合は AskUserQuestion で具体化してから Step 4 に戻る。明確な場合はそのまま Step 4 に戻る。

## Step 6.5: 技術リファレンス生成【必須】

> **このステップは `skip-files` に `tech-reference` が含まれていない限り必ず実行すること。Step 6 のユーザー確認完了でワークフローを終了してはならない。**

`.plugin-workspace/.specs/.config.yml` の `skip-files` に `tech-reference` が含まれている場合のみスキップ可。

ユーザー確認完了後、サブエージェントを起動して tech-reference{TECH_REFERENCE_EXT} を生成する。

implementation-plan に登場するすべての技術（言語・フレームワーク・ライブラリ・ツール・概念）を
初学者向けに解説するドキュメントを生成する。
読者は、言語やライブラリ、作ろうとしているものの初心者であることを前提とする。

**詳細は [references/workflow-steps.md](references/workflow-steps.md) の tech-reference 生成を参照。**

## Step 7: 実装開始（ユーザーによるガード解除）

**詳細は [references/workflow-steps.md](references/workflow-steps.md) のガード解除を参照。**

```
ユーザーへの案内:
  実装を開始するには、以下のコマンドを実行してください:
  rm .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID} .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
```

## 出力ディレクトリ

```
.plugin-workspace/.specs/
└── {nnn}-{feature-name}/
    ├── PLANNING                 # 計画中は存在、実装開始時に削除
    ├── hearing-notes{EXT}       # ヒアリング結果（オーケストレーター生成）
    ├── exploration-report{EXT}  # 探索レポート（codebase-explorer 生成）
    ├── implementation-plan{EXT} # 実装計画（spec-planner 生成）
    ├── tasks{EXT}               # タスクリスト（spec-planner 生成）
    ├── tech-reference{EXT}      # 技術リファレンス（初学者向け、サブエージェント生成）
    └── plan-review/             # AIレビュー結果（レビュー実行時のみ）
        ├── prompt-001.txt
        ├── review-001.md
        └── ...
```

`{nnn}` は `.plugin-workspace/.specs/` 内の既存フォルダ数に基づく3桁の連番（001, 002, 003...）
`{feature-name}` はケバブケースで命名（例: `001-user-authentication`, `002-block-button`）
