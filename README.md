# d-market-spec

Claude Code 向けの**仕様駆動開発（Spec-Driven Development）プラグイン**です。要件ヒアリングからコードベース探索、実装計画の策定、タスク実行、コードレビュー、GitHub Issue 作成までを一貫したワークフローで支援します。

## 特徴

- **構造化されたヒアリング** — 対話形式でスコープ・技術要件・品質基準を整理し `hearing-notes.md` を生成
- **コードベース自動探索** — アーキテクチャ・関連コード・技術的制約・変更影響・テスト基盤を体系的に分析
- **システム図の必須化** — 状態遷移図・データフロー図をフックで強制し、設計品質を担保
- **テスト戦略の自動分類** — Pure Logic / API Integration / UI Component 等のパターンに応じて TDD 適用を判断
- **フェーズ分離** — `PLANNING` ファイルとガードフックにより、計画フェーズ中の実装を禁止
- **マルチレビュー対応** — Codex / GitHub Copilot / Claude Code によるレビューループ（最大5回）
- **GitHub Issue 連携** — 実装計画から Epic + 子 Issue を自動生成

## ワークフロー

```
ヒアリング → コードベース探索 → 実装計画策定 → (AIレビュー) → ユーザー確認
    ↓
タスク順次実装 → (コードレビュー) → DoD検証 → 完了・アーカイブ
```

## インストール

Claude Code の設定で本プラグインのパスを追加してください。

```jsonc
// .claude/settings.json
{
  "plugins": ["path/to/d-market-spec/plugins/spec-plugin"]
}
```

## スキル一覧

### 計画・設計

| スキル | 説明 |
|--------|------|
| `design-doc` | プロジェクトレベルの設計ドキュメント作成 |
| `implementation-plan` | 機能単位の実装設計書作成 |

### 仕様駆動開発（ヒアリング → 計画）

| スキル | レビュー方式 |
|--------|-------------|
| `spec-driven-dev` | レビューなし（最速） |
| `spec-driven-dev-copilot` | GitHub Copilot CLI |
| `spec-driven-dev-codex` | Codex CLI |
| `spec-driven-dev-claude-code` | Claude Code CLI |

### 実装

| スキル | レビュー方式 |
|--------|-------------|
| `spec-implement` | レビューなし |
| `spec-implement-copilot` | GitHub Copilot CLI |
| `spec-implement-codex` | Codex CLI |
| `spec-implement-claude-code` | Claude Code CLI |

### Issue 連携

| スキル | 説明 |
|--------|------|
| `plan-to-issues` | 実装計画を GitHub Issues（Epic + 子Issue）に変換 |

## エージェント

| エージェント | 役割 |
|-------------|------|
| `spec-driven-developer` | ワークフロー全体のオーケストレーション |
| `spec-driven-developer-lite` | 外部AIレビューなしの軽量版 |
| `codebase-explorer` | コードベースの体系的探索（3層アプローチ） |
| `spec-planner` | 探索結果+ヒアリングから実装計画を生成 |
| `spec-implementer` | 計画に基づくタスク順次実装 |
| `design-doc-writer` | 設計ドキュメント作成 |
| `implementation-planner` | 機能レベルの実装設計 |
| `issue-creator` | GitHub Issue 自動作成 |

## フック

| フック | タイミング | 説明 |
|--------|-----------|------|
| `guard-planning-writes.sh` | PreToolUse | 計画フェーズ中の `.specs/` 外への書き込みをブロック |
| `auto-allow-spec-commands.sh` | PreToolUse | spec フォルダ番号取得コマンドの自動許可 |
| `enforce-diagrams.sh` | PostToolUse | 実装計画・設計書にシステム図が含まれているか検証 |
| PreCompact | PreCompact | 計画中のコンテキスト圧縮時に実装禁止を警告 |
| Stop | Stop | 完了した spec を自動アーカイブ |

## 生成されるディレクトリ構造

```
.specs/
├── {nnn}-{feature-name}/
│   ├── PLANNING                    # 計画フェーズ中マーカー
│   ├── hearing-notes.md            # ヒアリング記録
│   ├── exploration-report.md       # コードベース探索レポート
│   ├── implementation-plan.md      # 実装計画（システム図含む）
│   ├── tasks.md                    # タスクリスト（□/■）
│   ├── code-review/                # コードレビュー成果物
│   └── plan-review/                # 計画レビュー成果物
├── .guard/                         # セッション保護
└── archive/                        # 完了済み spec
```

## ライセンス

[MIT](LICENSE)