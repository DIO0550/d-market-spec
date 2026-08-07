# GitHub Issue への実装内容追記（issue-update）

`.plugin-workspace/.specs/.config.yml` の `issue-update` に応じて、実装内容を紐づく GitHub Issue へ追記するための手順。設定は `/spec-setup` で行う。

## 設定値

| 値 | このスキルでの動作 |
|---|---|
| `none`（未設定時のデフォルト） | 何もしない |
| `hook` | このスキルは何もしない。tasks.md を `□` → `■` に更新するたびに `issue-sync.sh`（PostToolUse）が Issue 上の進捗コメントを機械的に更新する |
| `ai` | 実装完了後（Step 7.7）に、このスキルが実装サマリのコメントを Issue へ投稿する |

`hook` は spec フォルダごとに1件のコメントを作成し、以降は同じコメントを編集する（コメントが増え続けない）。本文が前回と同じ場合は API を呼ばない。計画フェーズ（ガードファイル `.plugin-workspace/.specs/.guard/{SESSION_ID}` が存在する間）は投稿しない。

## 追記先 Issue の決定

追記先は **implementation-plan の `**関連Issue**: #{番号}`**（Step 2 で抽出済み）で決まる（`hook` / `ai` 共通）。記載がない、またはプレースホルダ `#{Issue番号}` のままの spec は追記対象外（エラーにはしない）。

## ai モードの手順（Step 7.7）

### 1. 前提条件の確認

以下のいずれかを満たさない場合はスキップし、その理由を Step 8 の完了報告に1行で含める:

- `issue-update` が `ai`
- Step 2 で関連Issue番号を抽出できている
- `gh` CLI が利用可能（`command -v gh`）

### 2. 本文の作成

`.plugin-workspace/.specs/{nnn}-{feature-name}/impl-comment.md` に以下の構成で書き出す:

```markdown
<!-- spec-plugin:issue-update:{nnn}-{feature-name}:impl -->

## ✅ 実装完了: {計画のタイトル}

{何を実装したかを1-2文}

### 完了したタスク

- [x] {タスク1}
- [x] {タスク2}

### 変更したファイル

- `{パス}` — {変更内容を1行で}

### 計画からの逸脱

- {implementation-notes.md の Deviations を要約。なければ「なし」}

### DoD

- [x] {充足した条件}
- [ ] {未達の条件と理由}

### 残タスク・ブロッカー

- {未完了タスクやフォローアップ。なければこのセクションを省く}

---
<sub>spec-plugin `/spec-implement` が生成した実装サマリです（`.plugin-workspace/.specs/{nnn}-{feature-name}/`）。</sub>
```

- 材料は tasks（完了タスク）、implementation-notes.md（Deviations・実装判断）、implementation-plan の DoD、変更差分
- diff は貼らない（変更ファイル名と1行説明にとどめる）
- 全体で 100 行以内に収める

### 3. 投稿

```bash
gh issue comment {番号} --body-file .plugin-workspace/.specs/{nnn}-{feature-name}/impl-comment.md
```

- 未完了タスクが残った状態で終了する場合も、「残タスク・ブロッカー」を埋めた上で投稿してよい（見出しは「🔨 実装中間報告」に変える）
- 投稿に失敗した場合（未認証・リポジトリ不一致など）は、失敗した旨とコマンドを完了報告に含めて処理を継続する。実装は完了しているため、失敗を理由にワークフローを止めない
- Issue のクローズはしない（クローズはユーザーまたは PR のマージに委ねる）

### 4. 報告

投稿したコメントの URL（`gh issue comment` の出力）を Step 8 の完了報告に含める。
