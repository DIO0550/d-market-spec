---
name: spec-driven-dev-copilot
description: 仕様策定ワークフロー。GitHub Copilot CLIで実装計画をレビューする版。Codexが使えない環境向け。
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(rm .plugin-workspace/.specs/*/PLANNING), Bash(rm .plugin-workspace/.specs/.guard/*), Bash(copilot *)
---

# Spec-Driven Development (Copilot版)

機能実装前に仕様を明確化し、実装計画とタスクリストを生成するスキル。
ヒアリングはオーケストレーターが行い、**探索と計画生成は別々のサブエージェントに委譲**する。

## 絶対厳守事項

1. **最初にフォルダとPLANNINGファイルを作成** — 質問・探索・実装の前に必ず Step 1 を実行
2. **システム図は必須** — implementation-plan.md には状態マシン図 + データフロー図を含める（ASCII罫線優先、mermaid補助）
3. **PLANNINGファイルがある間はコード実装禁止** — AutoCompact対策としてPLANNINGファイルで計画フェーズを明示

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

## バリアントパラメータ

| パラメータ | 値 |
|-----------|-----|
| SKILL_NAME | `spec-driven-dev-copilot` |
| PLANNING_CONTENT | `${CLAUDE_SESSION_ID}` |
| USE_GUARD | `true` |
| OUTPUT_EXT | `.md` |

## Step 1: specsフォルダ + PLANNINGファイル作成

ヒアリング開始前に、specディレクトリ・PLANNINGファイル・ガードファイルを作成する。

**詳細手順は [references/workflow-steps.md](references/workflow-steps.md) の Step 1 を参照。**

## Step 2: ヒアリング → hearing-notes.md 書き出し

AskUserQuestion で Batch 1-3（スコープ → 技術詳細 → 品質要件）を聴取し、hearing-notes.md に書き出す。

**詳細手順は [references/workflow-steps.md](references/workflow-steps.md) の Step 2 を参照。**
質問形式の詳細は `references/question-patterns.md` を参照。

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

spec-planner サブエージェントを起動し、implementation-plan.md と tasks.md を生成する。

**プロンプトテンプレートは [references/workflow-steps.md](references/workflow-steps.md) の Step 4 を参照。**

## Step 5: Copilotレビューループ

生成した implementation-plan.md を GitHub Copilot CLI でレビューする。

### レビューコマンド

```bash
copilot -p "$(cat .plugin-workspace/.specs/{nnn}-{feature-name}/plan-review/prompt-{NNN}.txt)" < .plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan.md > .plugin-workspace/.specs/{nnn}-{feature-name}/plan-review/review-{NNN}.md
```

### プロンプト補足

prompt-{NNN}.txt 末尾に以下を追記する:

```
以下は標準入力で渡される implementation-plan.md の内容です:
```

**ループ手順・判定ロジックは [references/review-loop.md](references/review-loop.md) を参照。**
レビュー観点の詳細は `references/review-criteria.md` を参照。

## Step 6: ユーザー確認

生成したファイルをユーザーに提示:

1. **specフォルダパス**: `.plugin-workspace/.specs/{nnn}-{feature-name}/` を明示
2. 生成ファイル一覧（hearing-notes.md, exploration-report.md, implementation-plan.md, tasks.md）
3. implementation-plan.md の内容サマリー
4. tasks.md のタスク一覧
5. 「修正が必要な場合はお知らせください」

ユーザーが修正を要求した場合は Step 5 のループに戻る。

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
    ├── hearing-notes.md         # ヒアリング結果（オーケストレーター生成）
    ├── exploration-report.md    # 探索レポート（codebase-explorer 生成）
    ├── implementation-plan.md   # 実装計画（spec-planner 生成）
    ├── tasks.md                 # タスクリスト（spec-planner 生成）
    └── plan-review/             # Copilotレビュー結果
        ├── review-001.md
        ├── review-002.md
        └── ...
```

`{nnn}` は `.plugin-workspace/.specs/` 内の既存フォルダ数に基づく3桁の連番（001, 002, 003...）
`{feature-name}` はケバブケースで命名（例: `001-user-authentication`, `002-block-button`）
