---
name: spec-setup
description: spec-pluginのワークスペース初期化と設定を行う。.plugin-workspace/.specs/ディレクトリの作成、デフォルトのレビューツール設定、ファイルごとの出力形式設定(.config.yml)を対話的にセットアップする。「spec setup」「spec初期化」「specセットアップ」「レビューツール設定」「デフォルトレビュー変更」「spec config」「出力形式変更」などでトリガー。設定ファイルにより各スキル実行時のAskUserQuestion問い合わせを省略できる。
allowed-tools: Bash(ls *), Bash(mkdir *)
---

# Spec Setup

spec-plugin のワークスペース初期化と設定を行うスキル。

- **初回**: `.plugin-workspace/.specs/` ディレクトリ + `.config.yml` を作成
- **2回目以降**: 既存の設定を表示し、変更を受け付ける

## 設定ファイル

```
.plugin-workspace/.specs/.config.yml
```

| キー | 値 | 説明 |
|------|-----|------|
| `review-tool` | `none` / `codex` / `copilot` / `claude-code` | デフォルトのレビューツール |
| `output-formats.hearing-notes` | `md` / `html` | hearing-notes の出力形式 |
| `output-formats.exploration-report` | `md` / `html` | exploration-report の出力形式 |
| `output-formats.implementation-plan` | `md` / `html` | implementation-plan の出力形式 |
| `output-formats.tasks` | `md` / `html` | tasks の出力形式 |
| `output-formats.tech-reference` | `md` / `html` | tech-reference の出力形式 |
| `skip-files` | リスト | 生成をスキップするファイル（例: `[tech-reference]`） |

## ワークフロー

### Step 1: ワークスペースの確認・作成

`.plugin-workspace/.specs/` が存在するか確認する。

- **存在しない場合**: `mkdir -p .plugin-workspace/.specs/.guard` で作成し、ユーザーに報告
- **存在する場合**: 既存のspecフォルダ数を表示

### Step 2: レビューツールの選択

`.plugin-workspace/.specs/.config.yml` が存在する場合は現在の設定を表示する。
設定の有無に関わらず、常に AskUserQuestion でレビューツールを選択:

- **レビューなし（最速）** → `review-tool: none`
- **Codex CLI** → `review-tool: codex`
- **GitHub Copilot CLI** → `review-tool: copilot`
- **Claude Code CLI** → `review-tool: claude-code`

### Step 3: 出力形式の選択

AskUserQuestion（multiSelect）で、**HTMLで出力するファイル**を選択させる。
選択されなかったファイルは Markdown（デフォルト）で出力される。

既存の `.config.yml` に `output-formats` が設定済みの場合は、現在の設定を表示してから質問する。

```
question: "HTMLで出力するファイルを選んでください（未選択のファイルはMarkdownで出力されます）"
header: "出力形式"
multiSelect: true
options:
  - label: "hearing-notes"
    description: "ヒアリング結果"
  - label: "exploration-report"
    description: "コードベース探索レポート"
  - label: "implementation-plan"
    description: "実装計画書"
  - label: "tasks"
    description: "タスクリスト"
  - label: "tech-reference"
    description: "技術リファレンス（初学者向け）"
```

選択結果から `output-formats` マップを構築する:
- 選択されたファイル → `html`
- 選択されなかったファイル → `md`

**何も選択されなかった場合**: すべて `md` として設定する。

### Step 3.5: スキップするファイルの選択

AskUserQuestion（multiSelect）で、**生成をスキップするファイル**を選択させる。

既存の `.config.yml` に `skip-files` が設定済みの場合は、現在の設定を表示してから質問する。

```
question: "生成をスキップするファイルがあれば選んでください（未選択＝すべて生成）"
header: "スキップ"
multiSelect: true
options:
  - label: "tech-reference"
    description: "技術リファレンス（初学者向け解説）を生成しない"
```

選択結果から `skip-files` リストを構築する。何も選択されなかった場合は `skip-files` キーを出力しない。

### Step 4: 設定ファイルの書き出し

Write ツールで `.plugin-workspace/.specs/.config.yml` に書き出す:

```yaml
# spec-plugin 設定
# 各スキルの --review 引数で個別にオーバーライド可能

review-tool: {選択した値}

# ファイルごとの出力形式（md / html）
output-formats:
  hearing-notes: {md or html}
  exploration-report: {md or html}
  implementation-plan: {md or html}
  tasks: {md or html}
  tech-reference: {md or html}

# 生成をスキップするファイル（Step 3.5 で選択された場合のみ出力）
skip-files:
  - tech-reference
```

### Step 5: 完了報告

設定内容をユーザーに提示し、以下を案内:

- この設定は `/spec-driven-dev`, `/spec-implement`, `/spec-implement-auto` で自動適用される
- `--review` 引数で個別にオーバーライド可能
- 設定を変更したい場合は `/spec-setup` を再実行
