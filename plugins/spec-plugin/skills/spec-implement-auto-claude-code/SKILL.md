---
name: spec-implement-auto-claude-code
description: .specsの実装計画に沿って実装し、全タスク完了後にClaude Code CLIで一括コードレビュー（自動コンテキスト注入版）。
disable-model-invocation: true
argument-hint: "[番号]"
allowed-tools: Bash(cat .specs/*), Bash(ls .specs/*), Bash(grep *), Bash(claude *), Bash(mkdir *), Bash(rm .specs/*/PLANNING), Bash(rm .specs/.guard/*)
---

# Spec Implement (Auto-Inject + Claude Code版)

番号指定で `.specs/{nnn}-{feature-name}/` の実装計画に沿って実装を進めるスキル。
起動時にシェルで計画・タスクを**強制注入**し、全タスク完了後に **Claude Code CLI** で一括コードレビューを行う。

## Pre-flight: 実装計画の強制注入

以下は `/spec-implement-auto-claude-code $0` 起動時点で注入された計画のスナップショット。
**この内容を基準に実装する**。実装中に不明点があれば、ファイルを Read で再取得すること
（この注入内容は AutoCompact で失われる可能性があるため）。

### 対象spec
!`ls -1d .specs/$0-* 2>/dev/null | head -1`

### PLANNING状態
!`ls .specs/$0-*/PLANNING > /dev/null 2>&1 && echo "⚠️ 計画中(実装禁止)。計画フェーズに戻ってください。" || echo "✅ 実装可能"`

### implementation-plan.md (全文)

!`cat .specs/$0-*/implementation-plan.md 2>/dev/null || echo "FILE_NOT_FOUND"`

### tasks.md (全文)

!`cat .specs/$0-*/tasks.md 2>/dev/null || echo "FILE_NOT_FOUND"`

### 未完了タスク数
!`grep -c '□' .specs/$0-*/tasks.md 2>/dev/null || echo "0"`

---

## ワークフロー

```
1. ユーザーが `/spec-implement-auto-claude-code {nnn}` を実行
   ↓
2. Pre-flight で計画・タスクを注入（ここまで自動）
   ↓
3. 未完了タスクを順次実装（□のタスクを処理）
   ↓
4. 各タスク完了時に tasks.md を更新（□ → ■）
   ↓
5. 全タスク完了後、Claude Code レビュー → 修正ループ
   ↓
6. PLANNINGファイルを削除
   ↓
7. DoD照合 → 完了報告
```

## Step 1: 注入内容の確認

Pre-flight で注入された内容を確認する。

- 対象ディレクトリが見つからない → エラー報告して終了
- PLANNING状態が「計画中」→ 実装を中止し、計画フェーズに戻るようユーザーに伝える
- `FILE_NOT_FOUND` が出ている → ユーザーに確認

### 関連Issue番号の抽出

注入された implementation-plan.md から `**関連Issue**: #{番号}` を読み取り、以降のコミットメッセージに使用する。
Issue番号が記載されていない場合はスキップする。

## Step 2: TaskCreate による進捗管理の初期化

tasks.md の未完了タスク（`□`）をすべて TaskCreate で登録し、TaskUpdate の `addBlockedBy` でセクション間の依存関係を設定する。

- `subject`: タスク行のテキスト
- `activeForm`: 進行形に変換（例: "型定義を作成" → "型定義を作成中"）
- 依存: Research → Implementation → Verification の順

## Step 3: タスクの順次実装

未完了タスク（`□`）を上から順番に実装する。

### 各タスクの実装手順

1. TaskUpdate で該当タスクの status を `in_progress` に変更
2. **implementation-plan.md を Read ツールで再読込**し、該当セクションを確認（記憶に頼らない）
3. **tasks.md を Read ツールで再読込**し、最新の進捗を確認
4. タスク内容と plan.md の該当箇所を照合
5. コードを実装
6. TaskUpdate で該当タスクの status を `completed` に変更
7. **tasks.md の該当タスクのみを Edit**（`□` → `■`）
8. コミット（このタスク分のみ）

### tasks.md の更新

タスク完了時に、該当行の `□` を `■` に変更する。

```
変更前: □ コンポーネントの型定義を作成
変更後: ■ コンポーネントの型定義を作成
```

**重要**: 親タスクは、すべての子タスクが `■` になった時点で `■` に更新する。

## Step 4: Claude Code レビュー（全タスク完了後）

すべてのタスクの実装が完了したら、Claude Code CLI で全変更の一括コードレビューを実行する。
レビュー結果はファイルに保存し、コンテキストの消費を抑える。

### レビュー結果の保存先

```bash
mkdir -p .specs/{nnn}-{feature-name}/code-review
```

レビュー結果は `.specs/{nnn}-{feature-name}/code-review/review-{NNN}.md` に保存する。
`{NNN}` は3桁の連番（001, 002, 003...）。タスクをまたいで通し番号とする。

### コンテキストファイルの組み立て

レビュー実行前に、Writeツールで以下の2ファイルを作成する。`{NNN}` は `review-{NNN}.md` と同じ連番。再レビュー時はインクリメントする。

**`.specs/{nnn}-{feature-name}/code-review/context-{NNN}.md`**:

以下の内容を結合して書き出す:
1. `## 実装計画` + implementation-plan.md の内容
2. `## 実装タスク一覧` + tasks.md の全タスク内容
3. `## 変更されたファイル` + `git diff --name-only` の結果
4. `## 変更内容` + `git diff` の結果

**`.specs/{nnn}-{feature-name}/code-review/prompt-{NNN}.txt`**:

以下のレビュー指示文を書き出す:

```
全タスクの実装をレビューしてください。

【重要】ファイルの作成・編集は一切行わないでください。レビュー結果は標準出力のみで回答してください。

## レビュー観点
1. 実装計画との整合性: 計画通りに実装されているか
2. コード品質: 可読性、保守性、命名規則は適切か
3. エッジケース: 空データ、エラー、境界値を考慮しているか
4. セキュリティ: インジェクション、XSSなどの脆弱性はないか
5. パフォーマンス: 不要なループ、N+1問題などはないか

問題がなければ「問題なし」と回答してください。
問題があれば具体的な指摘と改善案を提示してください。
```

### レビュー実行

プロンプトファイルを `cat` で読み込んで `claude -p` に渡し、コンテキストファイルを位置引数で渡した結果を `.specs/` 配下に出力する。

```bash
claude -p "$(cat .specs/{nnn}-{feature-name}/code-review/prompt-{NNN}.txt)" .specs/{nnn}-{feature-name}/code-review/context-{NNN}.md > .specs/{nnn}-{feature-name}/code-review/review-{NNN}.md
```

### ループ処理

1. 保存したレビュー結果ファイルを読み込み、内容を解析
2. 「問題なし」なら Step 5 へ
3. 問題があれば:
   - 指摘内容を元にコードを修正
   - 連番をインクリメントして再度 Claude Code レビューを実行・保存
   - 最大5回までループ
4. 5回超えたらユーザーに相談

## Step 5: PLANNINGファイル + ガードファイルの削除

すべてのタスクが完了（`□` が残っていない）したら、PLANNINGファイルとガードファイルを削除する。

PLANNINGファイルには計画時のセッションIDが記録されている。これを読み取り、対応するガードファイルも削除する。

```bash
guard_session=$(cat .specs/{nnn}-{feature-name}/PLANNING 2>/dev/null)
rm .specs/{nnn}-{feature-name}/PLANNING
rm -f ".specs/.guard/$guard_session" 2>/dev/null
```

PLANNINGファイルが存在しない場合はスキップする。

## Step 6: DoD照合

implementation-plan.md の "Definition of Done" セクションを読み込み、各条件の充足を確認する。

1. DoDの各項目を順番にチェック
2. すべて満たしていれば Step 7 へ
3. 未達の項目がある場合はユーザーに報告し、対応方針を確認する

**注意**: DoDセクションが存在しない場合はスキップして Step 7 へ進む。

## Step 7: 完了報告

実装完了後、ユーザーに以下を報告する:

1. 実装したタスクの一覧
2. 変更したファイルの一覧
3. 関連Issue番号（あれば）
4. Claude Codeレビューの結果サマリー
5. PLANNINGファイルの削除状態
6. DoD充足状況（DoDがある場合）

## AutoCompact後の復帰プロトコル

会話の流れで「要約された」「以前の会話」という言及や、計画の詳細が曖昧になった感覚がある場合、**次のアクションの前に以下を実行**する。

1. Read `.specs/{nnn}-*/implementation-plan.md` で計画を再ロード
2. Read `.specs/{nnn}-*/tasks.md` で現在の進捗を再ロード
3. TaskGet で作業中タスクの状態を確認
4. 上記3点が揃ってから次のアクションに進む

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
- 全タスク完了後に Claude Code レビューを一括実施する（タスクごとのレビューは行わない）
- 各タスク完了ごとに tasks.md を更新する（まとめて更新しない）
- 実装中に問題が発生した場合はユーザーに確認する
- PLANNINGファイルの削除は全タスク完了後のみ
- 関連Issue番号がある場合はコミットメッセージに含める
- レビュー用Bashコマンドは**必ず1行**で、`claude` で始めること。プロンプト文字列を直接埋め込まず、ファイル経由で渡す
- tasks.md は実装の進行とともに変わるため、タスク完了時に必ず最新を確認すること
