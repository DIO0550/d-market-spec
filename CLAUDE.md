# CLAUDE.md

このリポジトリは Claude Code 向けプラグインのマーケットプレイスのソースです。**仕様駆動開発プラグイン** (`spec-plugin`) と **仕様ベースコードレビュープラグイン** (`spec-based-code-review-plugin`) の2つを含みます。

## リポジトリ構成

```
.claude-plugin/marketplace.json   # マーケットプレイス登録情報
plugins/spec-plugin/
├── .claude-plugin/plugin.json    # プラグインメタデータ
├── hooks/                        # フック定義・シェルスクリプト
│   ├── hooks.json
│   ├── guard-planning-writes.sh  # 計画中の実装ブロック
│   ├── guard-requirements.sh     # requirements 未確定時の計画進行ブロック
│   ├── auto-allow-spec-commands.sh
│   ├── enforce-diagrams.sh       # システム図の検証・リマインド
│   ├── enforce-code-examples.sh  # コード例の検証・リマインド
│   └── session-phase-name.sh     # セッションタイトルの自動設定
├── agents/                       # エージェント定義（.md）
├── skills/                       # スキル定義（各 SKILL.md + テンプレート + 参照資料）
└── references/                   # 共有参照資料（TDDガイドライン等）
plugins/spec-based-code-review-plugin/
├── .claude-plugin/plugin.json    # プラグインメタデータ
├── agents/                       # レビューエージェント定義（5ファイル）
└── skills/                       # spec-based-code-review, test-review
```

## 開発ルール

- スキルは `plugins/spec-plugin/skills/{skill-name}/SKILL.md` で定義する
- エージェントは `plugins/spec-plugin/agents/{agent-name}.md` で定義する
- スキルごとに `assets/templates/` と `references/` のサブディレクトリを持つ
- テンプレートや参照資料はスキル単位で独立管理（コピーであっても各スキルに配置）
- フックスクリプトは `plugins/spec-plugin/hooks/` に配置し、`hooks.json` で登録する
- プラグインメタデータは各プラグイン直下の `.claude-plugin/plugin.json` に配置する（プラグイン直下に直接置くと Claude Code がマニフェストとして認識しない）
- プラグインの内容（スキル・エージェント・フック等）を追加・変更した場合は該当プラグインの `.claude-plugin/plugin.json` の `version` と、`.claude-plugin/marketplace.json` 内の該当プラグインエントリの `version` を更新する
- 変更をプッシュする際は `.claude-plugin/marketplace.json` の `metadata.version` も合わせて上げる

## 主要コンセプト

- **PLANNINGファイル**: `.plugin-workspace/.specs/{nnn}-{feature}/PLANNING` が存在する間は計画フェーズ。フェーズマーカーとして使われ、PreCompact フックの実装禁止警告と、セッション終了時のアーカイブ対象判定（PLANNING がないフォルダのみアーカイブ）に用いられる
- **ガードファイル**: `.plugin-workspace/.specs/.guard/{SESSION_ID}` はdevスキル発火時に `guard-skill-init.sh` フックが自動作成する。存在する間、`guard-planning-writes.sh` がそのセッションでの実装（`.plugin-workspace/.specs/` 外への書き込み）をブロックする。worktree内で起動した場合は worktree 外への書き込みもブロックする
- **システム図の検証**: `enforce-diagrams.sh` が実装計画・設計書に状態遷移図とデータフロー図が含まれているかを検証し、不足があればリマインドを出す（ブロックはしない）
- **EXPERIMENTマーカー**: `.plugin-workspace/.specs/{nnn}-{feature}/EXPERIMENT` は実験スキル `spec-driven-dev-exp` が作成するマーカー。存在するフォルダのみ `exp-plan-format.sh` フックが implementation-plan / tasks のフォーマット（必須セクション・プレースホルダ残留・コードブロック有無）を機械検証してリマインドする（チェッカー系サブエージェントの代替）
- **タスク進捗**: `tasks.md` 内の `□`（未完了）/ `■`（完了）で進捗を管理する
- **自動アーカイブ**: セッション終了時、PLANNINGファイルのない spec フォルダは `.plugin-workspace/.specs/archive/` に移動される

## レビューツール統合

レビューツール（Codex / Copilot / Claude Code CLI）はベーススキルにパラメータとして統合されている:

- `--review codex` — Codex CLI
- `--review copilot` — GitHub Copilot CLI
- `--review claude-code` — Claude Code CLI
- (未指定) — ワークフロー内で AskUserQuestion により選択

対象スキル: `spec-driven-dev`, `spec-implement`, `spec-implement-auto`

構造的に異なるバリアント（`-lite`）は独立スキルとして維持。HTML 出力は `spec-setup` の `output-formats` 設定でベーススキルが対応する（独立した `-html` スキルは廃止済み）。

## コマンド

このリポジトリにはビルドやテストのコマンドはありません。プラグインはマークダウンとシェルスクリプトで構成されており、Claude Code から直接ロードされます。
