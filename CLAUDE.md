# CLAUDE.md

このリポジトリは Claude Code 向けの **仕様駆動開発プラグイン** (`spec-plugin`) のソースです。

## リポジトリ構成

```
.claude-plugin/marketplace.json   # マーケットプレイス登録情報
plugins/spec-plugin/
├── plugin.json                   # プラグインメタデータ
├── hooks/                        # フック定義・シェルスクリプト
│   ├── hooks.json
│   ├── guard-planning-writes.sh  # 計画中の実装ブロック
│   ├── auto-allow-spec-commands.sh
│   └── enforce-diagrams.sh       # システム図の強制
├── agents/                       # エージェント定義（.md）
├── skills/                       # スキル定義（各 SKILL.md + テンプレート + 参照資料）
└── references/                   # 共有参照資料（TDDガイドライン等）
```

## 開発ルール

- スキルは `plugins/spec-plugin/skills/{skill-name}/SKILL.md` で定義する
- エージェントは `plugins/spec-plugin/agents/{agent-name}.md` で定義する
- スキルごとに `assets/templates/` と `references/` のサブディレクトリを持つ
- テンプレートや参照資料はスキル単位で独立管理（コピーであっても各スキルに配置）
- フックスクリプトは `plugins/spec-plugin/hooks/` に配置し、`hooks.json` で登録する
- プラグインの内容（スキル・エージェント・フック等）を追加・変更した場合は `plugins/spec-plugin/plugin.json` の `version` を更新する

## 主要コンセプト

- **PLANNINGファイル**: `.plugin-workspace/.specs/{nnn}-{feature}/PLANNING` が存在する間は計画フェーズ。フックにより実装（`.plugin-workspace/.specs/` 外への書き込み）がブロックされる
- **ガードファイル**: `.plugin-workspace/.specs/.guard/{SESSION_ID}` でセッション単位のフェーズ保護を行う
- **システム図の必須化**: `enforce-diagrams.sh` が実装計画・設計書に状態遷移図とデータフロー図が含まれているかを検証する
- **タスク進捗**: `tasks.md` 内の `□`（未完了）/ `■`（完了）で進捗を管理する
- **自動アーカイブ**: セッション終了時、PLANNINGファイルのない spec フォルダは `.plugin-workspace/.specs/archive/` に移動される

## レビューバリアント

同一ワークフローに対して複数のレビュー方式バリアントが存在する:

- `(base)` — レビューなし（最速）
- `-copilot` — GitHub Copilot CLI
- `-codex` — Codex CLI
- `-claude-code` — Claude Code CLI

スキル名のサフィックスでバリアントを区別する（例: `spec-driven-dev` / `spec-driven-dev-codex`）。

## コマンド

このリポジトリにはビルドやテストのコマンドはありません。プラグインはマークダウンとシェルスクリプトで構成されており、Claude Code から直接ロードされます。
