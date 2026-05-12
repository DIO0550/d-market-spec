---
name: spec-implement
description: .plugin-workspace/.specsの実装計画に沿ってタスクを順番に実装する。番号を指定すると、該当specのtasks.mdを読み込み、未完了タスクを順次実装していく。全タスク完了後にオプションでCodex/Copilot/Claude Codeによるコードレビ��ーを実行可能。「実装」「implement」「タスク実装」「コードレビュー付き」「codexレビュー」「copilotレビュー」などでトリガー。
disable-model-invocation: true
argument-hint: "[番号] [--review codex|copilot|claude-code]"
allowed-tools: Bash(rm .plugin-workspace/.specs/*/PLANNING), Bash(rm .plugin-workspace/.specs/.guard/*), Bash(mkdir *), Bash(codex *), Bash(copilot *), Bash(claude *)
---

# Spec Implement

番号指定で `.plugin-workspace/.specs/{nnn}-{feature-name}/` の実装計画に沿って実装を進めるスキル。
全タスク完了後にオプションで AIレビュー（Codex / Copilot / Claude Code CLI）を実行可能。

## ワークフロー

```
0. レビューツール解決（引数 → .config.yml → 初回のみ AskUserQuestion）
   ↓
1. ユーザーが `/spec-implement {nnn}` を実行
   ↓
2. .plugin-workspace/.specs/ から {nnn}-* にマッチするフォルダを特定
   ↓
3. implementation-plan.md を読み込み、変更内容を把握
   ↓
4. tasks.md を読み込み、未完了タスクを確認
   ↓
5. タスクを順番に実装（□のタスクを処理）
   ↓
6. 各タスク完了時に tasks.md を更新（□ → ■）
   ↓
7. 全タスク完了後、AIレビュー（オプション）
   ↓
8. PLANNINGファイルを削除
   ↓
9. DoD照合 → 完了報告
```

## Step 0: レビューツール解決

ワークフロー開始時に、使用するレビューツールを以下の優先順で決定する:

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

## Step 1: specフォルダの特定

指定された番号 `$0` を使い、`.plugin-workspace/.specs/` 配下からマッチするフォルダを検索する。

```bash
spec_dir=$(ls -1d .plugin-workspace/.specs/$0-* 2>/dev/null | head -1)
```

- マッチするフォルダが見つからない場合はエラーメッセージを表示して終了
- 複数マッチした場合は最初のものを使用

## Step 2: implementation-plan.md の読み込み

`.plugin-workspace/.specs/{nnn}-{feature-name}/implementation-plan.md` を読み込み、以下を把握する：

- 変更対象ファイル（`[NEW]` `[MODIFY]` `[DELETE]`）
- 設計方針
- データ構造・API設計
- 検証計画
- **関連Issue番号**（`**関連Issue**: #123` の形式で記載されている場合）

### 関連Issue番号の抽出

implementation-plan.md から `**関連Issue**: #{番号}` を読み取り、以降のコミットメッセージに使用する。
Issue番号が記載されていない場合はスキップする。

## Step 3: tasks.md の読み込み

`.plugin-workspace/.specs/{nnn}-{feature-name}/tasks.md` を読み込み、タスク状態を確認する。

### タスク状態の判定

- `□` — 未完了タスク（実装対象）
- `■` — 完了済みタスク（スキップ）

未完了タスク（`□`）がない場合は「全タスク完了済み」と報告して終了。

## Step 3.5: TaskCreate による進捗管理の初期化

tasks.md の未完了タスク（`□`）をすべて TaskCreate で登録し、TaskUpdate の `addBlockedBy` でセクション間の依存関係を設定する。

- `subject`: タスク行のテキスト
- `activeForm`: 進行形に変換（例: "型定義を作成" → "型定義を作成中"）
- 依存: Research → Implementation → Verification の順

## Step 4: タスクの順次実装

未完了タスク（`□`）を上から順番に実装する。

### 各タスクの実装手順

1. TaskUpdate で該当タスクの status を `in_progress` に変更
2. タスク内容を確認
3. implementation-plan.md の該当セクションを参照
4. コードを実装
5. TaskUpdate で該当タスクの status を `completed` に変更
6. tasks.md の該当タスクを更新（`□` → `■`）

### tasks.md の更新

タスク完了時に、該当行の `□` を `■` に変更する。

```
変更前: □ コンポーネントの型定義を作成
変更後: ■ コンポーネントの型定義を作成
```

**重要**: 親タスクは、すべての子タスクが `■` になった時点で `■` に更新する。

## Step 5: AIレビュー（オプション）

Step 0 で決定した `{REVIEW_TOOL}` を使用する。`none` の場合は Step 6 へスキップ。

ツール選択済みの場合:
1. `code-review/context-{NNN}.md` と `code-review/prompt-{NNN}.txt` を生成
2. [references/review-tools.md](references/review-tools.md) のコマンド構文に従い実行
3. `code-review/review-{NNN}.md` に出力を保存
4. レビュー結果を解析し、問題があれば修正 → 再レビュー（最大5回）
5. レビュー結果を要約してユーザーに提示

## Step 6: PLANNINGファイル + ガードファイルの削除

すべてのタスクが完了（`□` が残っていない）したら、PLANNINGファイルとガードファイルを削除する。

PLANNINGファイルには計画時のセッションIDが記録されている。これを読み取り、対応するガードファイルも削除する。

```bash
# PLANNINGファイルからセッションIDを読み取り、ガードファイルを削除
guard_session=$(cat .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING 2>/dev/null)
rm .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
rm -f ".plugin-workspace/.specs/.guard/$guard_session" 2>/dev/null
```

PLANNINGファイルが存在しない場合はスキップする。

## Step 7: DoD照合

implementation-plan.md の "Definition of Done" セクションを読み込み、各条件の充足を確認する。

1. DoDの各項目を順番にチェック
2. すべて満たしていれば Step 8 へ
3. 未達の項目がある場合はユーザーに報告し、対応方針を確認する

**注意**: DoDセクションが存在しない場合はスキップして Step 8 へ進む。

## Step 8: 完了報告

実装完了後、ユーザーに以下を報告する：

1. 実装したタスクの一覧
2. 変更したファイルの一覧
3. 関連Issue番号（あれば）
4. AIレビューの結果サマリー（レビュー実行時）
5. PLANNINGファイルの削除状態
6. DoD充足状況（DoDがある場合）

## コミットメッセージのフォーマット

関連Issue番号がある場合、コミットメッセージに含める。

```
{コミットメッセージ}

Refs #{Issue番号}
```

例:
```
Add user authentication component

Refs #42
```

## 重要な制約

- implementation-plan.md に記載されていない変更は行わない
- tasks.md の順序に従って実装する（スキップしない）
- 各タスク完了ごとに tasks.md を更新する（まとめて更新しない）
- 実装中に問題が発生した場合はユーザーに確認する
- PLANNINGファイルの削除は全タスク完了後のみ
- 関連Issue番号がある場合はコミットメッセージに含める
