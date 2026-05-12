---
name: spec-setup
description: spec-pluginのワークスペース初期化と設定を行う。.plugin-workspace/.specs/ディレクトリの作成とデフォルトのレビューツール設定(.config.yml)を対話的にセットアップする。「spec setup」「spec初期化」「specセットアップ」「レビューツール設定」「デフォルトレビュー変更」「spec config」などでトリガー。設定ファイルにより各スキル実行時のAskUserQuestion問い合わせを省略できる。
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

## ワークフロー

### Step 1: ワークスペースの確認・作成

`.plugin-workspace/.specs/` が存在するか確認する。

- **存在しない場合**: `mkdir -p .plugin-workspace/.specs/.guard` で作成し、ユーザーに報告
- **存在する場合**: 既存のspecフォルダ数を表示

### Step 2: レビューツールの選択

`.plugin-workspace/.specs/.config.yml` が存在する場合は現在の設定を表示した上で、AskUserQuestion でレビューツールを選択:

- **レビューなし（最速）** → `review-tool: none`
- **Codex CLI** → `review-tool: codex`
- **GitHub Copilot CLI** → `review-tool: copilot`
- **Claude Code CLI** → `review-tool: claude-code`
- **変更しない**（既存設定がある場合のみ）→ 終了

### Step 3: 設定ファイルの書き出し

Write ツールで `.plugin-workspace/.specs/.config.yml` に書き出す:

```yaml
# spec-plugin 設定
# 各スキルの --review 引数で個別にオーバーライド可能

review-tool: {選択した値}
```

### Step 4: 完了報告

設定内容をユーザーに提示し、以下を案内:

- この設定は `/spec-driven-dev`, `/spec-implement`, `/spec-implement-auto` で自動適用される
- `--review` 引数で個別にオーバーライド可能
- 設定を変更したい場合は `/spec-setup` を再実行
