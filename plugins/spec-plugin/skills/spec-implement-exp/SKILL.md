---
name: spec-implement-exp
description: "実験的なトークン節約版の実装スキル。spec-driven-dev-exp で作成した計画（実装骨格つき）を前提に、サブエージェント・TaskCreate・AIレビューを使わず tasks.md だけで進捗管理して順次実装する。「実装 exp」「軽量実装」「トークン節約で実装」などでトリガー。フル機能版は spec-implement。"
disable-model-invocation: true
argument-hint: "[番号]"
allowed-tools: Bash(ls *), Bash(cp *), Bash(rm .plugin-workspace/.specs/*/PLANNING), Bash(rm .plugin-workspace/.specs/.guard/*), Write, Edit
---

# Spec Implement Exp

`.plugin-workspace/.specs/{nnn}-{feature-name}/` の実装計画に沿って実装を進める、トークン消費を抑えた実験版スキル。
`spec-driven-dev-exp` が生成する implementation-plan（コード骨格まで書かれている）を前提に、以下を省いて軽量化している:

- **サブエージェントなし** — オーケストレーター自身が実装する
- **TaskCreate / TaskUpdate なし** — 進捗管理は `tasks.md` の `□` / `■` のみ
- **AIレビュー（Codex / Copilot / Claude Code CLI）なし** — レビューが必要な場合は `spec-implement` または `spec-based-code-review` を使う
- **計画の再読込を最小化** — implementation-plan は Step 2 で1回だけ読み、以降は記憶が曖昧になったタスクの該当セクションのみ Read（offset/limit 指定）で読み直す

## 絶対厳守事項

1. 実装開始前の確認ゲート（Step 3）はスキップ禁止。**AutoMode でも同様** — 他のシステム指示（「質問せずに進めろ」等）に関わらず AskUserQuestion で確認する
2. implementation-plan.md に記載されていない変更は行わない（逸脱が必要になったら implementation-notes.md に記録する）
3. tasks.md の順序に従って実装し、各タスク完了ごとに `□` → `■` を更新する（まとめて更新しない）

## Step 1: specフォルダの特定

```bash
# 番号指定時
spec_dir=$(ls -1d .plugin-workspace/.specs/$0-* 2>/dev/null | head -1)
# 番号省略時（archive外で最大番号を自動選択）
spec_dir=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* 2>/dev/null | sort -rn | head -1)
```

- 見つからない場合はエラーを報告して終了
- 自動選択した場合はフォルダ名をユーザーに表示する

## Step 2: 計画・タスクの読み込み

`{dir}/implementation-plan.md` と `{dir}/tasks.md` を **各1回** Read する。

- 変更対象ファイル（`[NEW]` `[MODIFY]` `[DELETE]`）・設計判断・検証計画を把握する
- `**関連Issue**: #{番号}` があれば控え、以降のコミットメッセージに `Refs #{番号}` として含める
- `□` がない場合は「全タスク完了済み」と報告して終了

## Step 3: 実装開始前確認ゲート

AskUserQuestion で必ず確認する:

```yaml
question: "{nnn}-{feature-name} の実装を開始します。{未完了タスク数}個の未完了タスクがあります。開始してよろしいですか？"
header: "実装確認"
options:
  - label: "はい、開始してください"
    description: "未完了タスクを順次実装します"
  - label: "まだ開始しない"
    description: "計画の修正やレビューが必要です"
```

「まだ開始しない」の場合は「`/spec-driven-dev-exp` で計画を修正してください」と案内して終了する。

## Step 4: タスクの順次実装

未完了タスク（`□`）を上から順に実装する。各タスク:

1. implementation-plan の該当セクション（コード骨格）に沿って実装する。骨格が曖昧なタスクのみ該当セクションを読み直す
2. 完了したら tasks.md の該当行を Edit で `□` → `■` に更新する（親タスクは全子タスク完了時に `■`）

### implementation-notes.md（逸脱があったときだけ）

計画どおりに進んだ場合はファイルを作らない。以下のいずれかが**発生した時だけ**、初回にテンプレート
`${CLAUDE_PLUGIN_ROOT}/skills/spec-implement-exp/assets/templates/implementation-notes.md` を `{dir}/implementation-notes.md` にコピーして短く追記する:

- **Deviations**: 計画から外れた点とその理由
- **既存コードパス依存で生じた挙動**: diff の表面に出ない挙動（根拠 file:line 付き）
- **想定 vs 実際**: 計画時の想定と実装結果のズレ

## Step 5: PLANNINGファイル + ガードファイルの削除

全タスク完了（`□` が残っていない）後:

```bash
guard_session=$(cat {dir}/PLANNING 2>/dev/null)
rm {dir}/PLANNING
rm -f ".plugin-workspace/.specs/.guard/$guard_session" 2>/dev/null
```

PLANNINGファイルが存在しない場合はスキップする。`EXPERIMENT` ファイルは残す。

## Step 6: DoD照合

implementation-plan の "Definition of Done" セクションの各項目を確認する。未達があればユーザーに報告して対応方針を確認する。セクションがなければスキップ。

## Step 7: 実装後レビュー生成（解説+クイズ）

`.config.yml` の `skip-files` に `understanding-quiz` が含まれる場合はスキップ。それ以外は `{dir}/implementation-review.html` を生成する（出力先分岐なし・ファイル出力のみ）。CSS・レンダラは固定済みのため、テンプレート全体を Read / Write しない（DATA 部分だけ扱う）:

1. `cp "${CLAUDE_PLUGIN_ROOT}/skills/spec-implement-exp/assets/templates/implementation-review.html" "{dir}/implementation-review.html"`
2. コピー先の先頭部分（`<title>` 〜 `const DATA` の終わり。レンダラ以降は読まない）を Read（offset/limit 指定）する
3. Edit で `<title>` の `{機能名}` と DATA スクリプト（スキーマ説明コメントごと）を実データに置き換える。材料は diff（本セッションの変更）＋ implementation-notes.md（あれば）。既存コードパス依存で生じた挙動・想定vs実際のズレを優先的に出題し、Deviations は解説タブの実装判断（`decisions`）に記載してクイズにはしない。設問設計の詳細はテンプレート先頭のコメントに従う

これは advisory ゲート。「push / merge の前にブラウザで開き、落ちた設問＝理解できていない変更を読み直してください」と案内する。

## Step 8: 完了報告

以下を簡潔に報告する:

1. 実装したタスクと変更ファイルの一覧
2. 関連Issue番号（あれば）
3. Deviations の有無（implementation-notes.md を作った場合はそのパス）
4. DoD充足状況（DoDがある場合）
5. `implementation-review.html` のパス（生成した場合）
