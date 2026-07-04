# d-market-spec

Claude Code 向けの**仕様駆動開発（Spec-Driven Development）プラグイン**です。要件ヒアリングからコードベース探索、実装計画の策定、タスク実行、コードレビュー、GitHub Issue 作成までを一貫したワークフローで支援します。

## 特徴

- **構造化されたヒアリング** — 対話形式でスコープ・技術要件・品質基準を整理し `hearing-notes.md` を生成
- **コードベース自動探索** — アーキテクチャ・関連コード・技術的制約・変更影響・テスト基盤を体系的に分析
- **システム図の検証** — 状態遷移図・データフロー図の有無をフックで検証・リマインドし、設計品質を担保
- **テスト戦略の自動分類** — Pure Logic / API Integration / UI Component 等のパターンに応じて TDD 適用を判断
- **フェーズ分離** — ガードファイル（`.guard/{SESSION_ID}`）とガードフックにより、計画フェーズ中の実装（`.plugin-workspace/.specs/` 外への書き込み）をブロック。`PLANNING` ファイルはフェーズマーカーとして警告表示・アーカイブ判定に使用
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

| スキル | 説明 |
|--------|------|
| `spec-driven-dev` | 標準ワークフロー。ヒアリング → コード探索 → 計画生成 → オプションでAIレビュー |
| `spec-driven-dev-lite` | 軽量版。サブエージェントを使わずオーケストレーターが直接計画を生成し、トークン消費を削減 |
| `spec-driven-dev-html` | HTML出力版。同じ計画プロセスで生成物を HTML 形式で出力 |
| `spec-driven-fix-review` | spec-viewer のレビューコメントを implementation-plan.md と tasks.md に反映 |

### 実装

| スキル | 説明 |
|--------|------|
| `spec-implement` | tasks.md の未完了タスクを順次実装。完了後にオプションでコードレビュー |
| `spec-implement-auto` | 自動コンテキスト注入版。計画・進捗をシェルで強制読み込みし、タスク単位でコミット |

### セットアップ・Issue 連携

| スキル | 説明 |
|--------|------|
| `spec-setup` | ワークスペース初期化とデフォルト設定（レビューツール・出力形式） |
| `plan-to-issues` | 実装計画を GitHub Issues（Epic + 子Issue）に変換 |

### レビューツール指定

レビューツール（Codex / GitHub Copilot / Claude Code CLI）は独立したスキルではなく、ベーススキル（`spec-driven-dev`, `spec-implement`, `spec-implement-auto`）にパラメータとして統合されている:

- `--review codex` — Codex CLI
- `--review copilot` — GitHub Copilot CLI
- `--review claude-code` — Claude Code CLI
- (未指定) — ワークフロー内で AskUserQuestion により選択

## エージェント

### スキルから起動されるサブエージェント

各スキルのワークフロー内で `subagent_type` として起動される。

| エージェント | 役割 |
|-------------|------|
| `codebase-explorer` | コードベースの体系的探索（3層アプローチ） |
| `spec-planner` | 探索結果+ヒアリングから実装計画を生成 |
| `plan-format-checker` | implementation-plan がテンプレート構造に沿っているか検証 |
| `design-validity-checker` | implementation-plan の設計判断の妥当性を評価 |
| `test-pattern-checker` | テスト戦略のパターン網羅性を評価 |
| `test-case-designer` | 検証計画を起点にテストケースを詳細設計 |

### スタンドアロン用エージェント

ユーザーが直接起動して使う。

| エージェント | 役割 |
|-------------|------|
| `spec-driven-developer` | ワークフロー全体のオーケストレーション |
| `spec-driven-developer-lite` | 外部AIレビューなしの軽量版 |
| `spec-implementer` | 計画に基づくタスク順次実装 |
| `design-doc-writer` | 設計ドキュメント作成 |
| `implementation-planner` | 機能レベルの実装設計 |
| `issue-creator` | GitHub Issue 自動作成 |

## フック

| フック | タイミング | 説明 |
|--------|-----------|------|
| `guard-planning-writes.sh` | PreToolUse | ガードファイル（`.guard/{SESSION_ID}`）存在時に `.plugin-workspace/.specs/` 外への書き込みをブロック |
| `guard-requirements.sh` | PreToolUse | requirements の「未解決の確認事項」が未解決のまま implementation-plan へ進むのをブロック |
| `auto-allow-spec-commands.sh` | PreToolUse | spec 関連コマンドの自動許可（未許可コマンドはAIに通知） |
| `enforce-diagrams.sh` | PostToolUse | 実装計画・設計書にシステム図が含まれているか検証し、不足があればリマインド |
| `enforce-code-examples.sh` | PostToolUse | 実装計画にコードブロック（型定義・使用例等）が含まれているか検証し、不足があればリマインド |
| `session-phase-name.sh` | UserPromptSubmit | `/spec-driven-dev`・`/spec-implement` の起動を検出しセッションタイトルを設定 |
| PreCompact | PreCompact | 計画中のコンテキスト圧縮時に実装禁止を警告 |
| Stop | Stop | PLANNING ファイルのない spec を自動アーカイブ |

## 生成されるディレクトリ構造

```
.plugin-workspace/.specs/
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