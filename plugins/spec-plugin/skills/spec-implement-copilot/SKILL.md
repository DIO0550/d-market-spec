---
name: spec-implement-copilot
description: 番号指定で実装を開始し、GitHub Copilot CLIでコードレビューを行うスキル。「/implement 001」のように番号を指定して、該当するspecの実装計画に沿ってタスクを順番に実装する。各タスク完了後にCopilot CLIでレビューし、指摘があれば修正する。tasks.mdのチェックリストを更新しながら進め、全タスク完了後にPLANNINGファイルを削除する。
---

# Spec Implement (Copilot版)

番号指定で `.specs/{nnn}-{feature-name}/` の実装計画に沿って実装を進めるスキル。
各タスクの実装後に **GitHub Copilot CLI** でコードレビューを行い、品質を担保する。

## ワークフロー

```
1. ユーザーが番号を指定して実行
   ↓
2. .specs/ から {nnn}-* にマッチするフォルダを特定
   ↓
3. implementation-plan.md を読み込み、変更内容を把握
   ↓
4. tasks.md を読み込み、未完了タスクを確認
   ↓
5. タスクを順番に実装（□のタスクを処理）
   ↓
6. 各タスク完了時に Copilot レビュー → 修正ループ
   ↓
7. レビュー通過後、tasks.md を更新（□ → ■）
   ↓
8. 全タスク完了後、PLANNINGファイルを削除
   ↓
9. DoD照合 → 完了報告
```

## Step 1: specフォルダの特定

引数として受け取った番号（例: `001`）を使い、`.specs/` 配下から `{nnn}-*` にマッチするフォルダを検索する。

```bash
spec_dir=$(ls -1d .specs/${nnn}-* 2>/dev/null | head -1)
```

- マッチするフォルダが見つからない場合はエラーメッセージを表示して終了
- 複数マッチした場合は最初のものを使用

## Step 2: implementation-plan.md の読み込み

`.specs/{nnn}-{feature-name}/implementation-plan.md` を読み込み、以下を把握する：

- 変更対象ファイル（`[NEW]` `[MODIFY]` `[DELETE]`）
- 設計方針
- データ構造・API設計
- 検証計画
- **関連Issue番号**（`**関連Issue**: #123` の形式で記載されている場合）

### 関連Issue番号の抽出

implementation-plan.md から `**関連Issue**: #{番号}` を読み取り、以降のコミットメッセージに使用する。
Issue番号が記載されていない場合はスキップする。

## Step 3: tasks.md の読み込み

`.specs/{nnn}-{feature-name}/tasks.md` を読み込み、タスク状態を確認する。

### タスク状態の判定

- `□` — 未完了タスク（実装対象）
- `■` — 完了済みタスク（スキップ）

未完了タスク（`□`）がない場合は「全タスク完了済み」と報告して終了。

## Step 3.5: TaskCreate による進捗管理の初期化

tasks.md の未完了タスク（`□`）をすべて TaskCreate ツールで登録する。

### 登録ルール

- 各 `□` 行に対して TaskCreate を実行
- `subject`: タスク行のテキストをそのまま使用
- `activeForm`: 進行形に変換（例: "型定義を作成" → "型定義を作成中"）
- `description`: implementation-plan.md の該当セクションから補足情報を含める

### 依存関係の設定

TaskUpdate の `addBlockedBy` を使い、以下の順序で依存関係を設定する：

- Research & Planning のタスク → Implementation のタスクが blockedBy で依存
- Implementation のタスク → Verification のタスクが blockedBy で依存
- 同一セクション内で順序依存がある場合も blockedBy を設定
- 独立して実行可能なタスク同士には依存関係を設定しない

## Step 4: タスクの順次実装

未完了タスク（`□`）を上から順番に実装する。

### 各タスクの実装手順

1. TaskUpdate で該当タスクの status を `in_progress` に変更
2. タスク内容を確認
3. implementation-plan.md の該当セクションを参照
4. コードを実装

## Step 5: Copilot レビュー（各タスク完了後）

タスクの実装が完了したら、GitHub Copilot CLI でコードレビューを実行する。
レビュー結果はファイルに保存し、コンテキストの消費を抑える。

### レビュー結果の保存先

```bash
mkdir -p .specs/{nnn}-{feature-name}/code-review
```

レビュー結果は `.specs/{nnn}-{feature-name}/code-review/review-{NNN}.md` に保存する。
`{NNN}` は3桁の連番（001, 002, 003...）。タスクをまたいで通し番号とする。

### レビュー実行

```bash
copilot -p "以下のタスクの実装をレビューしてください。

【重要】ファイルの作成・編集は一切行わないでください。レビュー結果は標準出力のみで回答してください。

## 実装計画
$(cat .specs/{nnn}-{feature-name}/implementation-plan.md)

## 対象タスク
{現在のタスク内容}

## 変更されたファイル
$(git diff --name-only)

## 変更内容
$(git diff)

## レビュー観点
1. 実装計画との整合性: 計画通りに実装されているか
2. コード品質: 可読性、保守性、命名規則は適切か
3. エッジケース: 空データ、エラー、境界値を考慮しているか
4. セキュリティ: インジェクション、XSSなどの脆弱性はないか
5. パフォーマンス: 不要なループ、N+1問題などはないか

問題がなければ「問題なし」と回答してください。
問題があれば具体的な指摘と改善案を提示してください。
" > .specs/{nnn}-{feature-name}/code-review/review-001.md
```

### ループ処理

1. 保存したレビュー結果ファイルを読み込み、内容を解析
2. 「問題なし」なら Step 6 へ
3. 問題があれば:
   - 指摘内容を元にコードを修正
   - 連番をインクリメントして再度 Copilot レビューを実行・保存
   - 最大5回までループ
4. 5回超えたらユーザーに相談

## Step 6: タスク完了処理

レビュー通過後、タスクを完了にする。

1. TaskUpdate で該当タスクの status を `completed` に変更
2. tasks.md の該当タスクを更新（`□` → `■`）

```
変更前: □ コンポーネントの型定義を作成
変更後: ■ コンポーネントの型定義を作成
```

**重要**: 親タスクは、すべての子タスクが `■` になった時点で `■` に更新する。

## Step 7: PLANNINGファイルの削除

すべてのタスクが完了（`□` が残っていない）したら、PLANNINGファイルを削除する。

```bash
rm .specs/{nnn}-{feature-name}/PLANNING
```

PLANNINGファイルが存在しない場合はスキップする。

## Step 8: DoD照合

implementation-plan.md の "Definition of Done" セクションを読み込み、各条件の充足を確認する。

1. DoDの各項目を順番にチェック
2. すべて満たしていれば Step 9 へ
3. 未達の項目がある場合はユーザーに報告し、対応方針を確認する

**注意**: DoDセクションが存在しない場合はスキップして Step 9 へ進む。

## Step 9: 完了報告

実装完了後、ユーザーに以下を報告する：

1. 実装したタスクの一覧
2. 変更したファイルの一覧
3. 関連Issue番号（あれば）
4. Copilotレビューの結果サマリー
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
- 各タスク完了ごとに Copilot レビューを実施する
- レビュー通過後に tasks.md を更新する（まとめて更新しない）
- 実装中に問題が発生した場合はユーザーに確認する
- PLANNINGファイルの削除は全タスク完了後のみ
- 関連Issue番号がある場合はコミットメッセージに含める
