# GitHub Issue への計画追記（issue-update）

`.plugin-workspace/.specs/.config.yml` の `issue-update` に応じて、計画内容を紐づく GitHub Issue へ追記するための手順。設定は `/spec-setup` で行う。

## 設定値

| 値 | このスキルでの動作 |
|---|---|
| `none`（未設定時のデフォルト） | 何もしない |
| `hook` | このスキルは何もしない。実装フェーズに入ってから `issue-sync.sh`（PostToolUse）が計画サマリ + タスク進捗のコメントを機械的に作成・更新する |
| `ai` | 計画確定後（Step 6.8）に、このスキルが計画サマリのコメントを Issue へ投稿する |

`hook` は計画フェーズ（ガードファイル `.plugin-workspace/.specs/.guard/{SESSION_ID}` が存在する間）には投稿しない。計画段階の未確定な内容が Issue に出ないようにするため。

## アーカイブとの関係

PLANNINGファイルのない spec フォルダはセッション終了時に `.plugin-workspace/.specs/archive/` へ移動される。計画フェーズ中は PLANNINGファイルがあるためこのスキルの実行中に移動されることはないが、**ガード解除（Step 7）で PLANNINGファイルを消した後は、実装を始める前でもセッション終了時に移動される**。

- `hook`: `archive/` 配下の更新も検知し、移動前と同じコメントを編集し続ける（マーカーと状態ファイルの鍵が spec 名のため）
- 次のセッションで `/spec-implement {nnn}` を実行すると、`archive/` 配下の spec は直下へ戻されてから実装が始まる
- コメント本文に spec フォルダのパスを書く場合は、完了後に `archive/` 配下へ移動することを併記する（下のテンプレート参照）

## 追記先 Issue の決定

追記先は **implementation-plan の `**関連Issue**: #{番号}`** で決まる（`hook` / `ai` 共通）。

- ユーザーの依頼に `#123` が含まれる、または Issue から起票された計画であれば、その番号をヘッダに記載する
- 番号が分からない場合は AskUserQuestion で確認する（選択肢に「Issue と紐づけない」を含める）
- 「紐づけない」またはプレースホルダ `#{Issue番号}` のままの場合、追記処理はスキップされる（エラーにはしない）

## ai モードの手順（Step 6.8）

### 1. 前提条件の確認

以下のいずれかを満たさない場合はスキップし、その理由をユーザーに1行で報告する:

- `issue-update` が `ai`
- implementation-plan に `**関連Issue**: #{番号}` がある
- `gh` CLI が利用可能（`command -v gh`）

### 2. 本文の作成

`.plugin-workspace/.specs/{nnn}-{feature-name}/plan-comment.md` に以下の構成で書き出す（spec フォルダ内のため計画フェーズでも書き込める）:

```markdown
<!-- spec-plugin:issue-update:{nnn}-{feature-name}:plan -->

## 📋 実装計画: {計画のタイトル}

{背景・目的を1-2文}

### 設計方針

- {方針1}
- {方針2}

### 変更対象ファイル

- [NEW] `{パス}` — {役割}
- [MODIFY] `{パス}` — {変更点}

### タスク

- [ ] {タスク1}
- [ ] {タスク2}

### 確認してほしい点

- {ユーザーレビューが必要な点。なければこのセクションを省く}

---
<sub>spec-plugin `/spec-driven-dev` が生成した計画サマリです（`.plugin-workspace/.specs/{nnn}-{feature-name}/`。実装完了後は `.plugin-workspace/.specs/archive/{nnn}-{feature-name}/` へ移動します）。</sub>
```

- implementation-plan の「ユーザーレビューが必要な点」「変更案」、tasks のタスク一覧を要約して埋める
- コードブロックや図は貼らない（Issue が読みづらくなるため、詳細は spec フォルダを参照させる）
- 全体で 100 行以内に収める

### 3. 投稿

```bash
gh issue comment {番号} --body-file .plugin-workspace/.specs/{nnn}-{feature-name}/plan-comment.md
```

- 同じ spec で計画を修正して再投稿する場合も、新規コメントとして投稿してよい（履歴が残るため）
- 投稿に失敗した場合（未認証・リポジトリ不一致など）は、失敗した旨とコマンドをユーザーに提示して処理を継続する。計画そのものは完了しているため、失敗を理由にワークフローを止めない

### 4. 報告

投稿したコメントの URL（`gh issue comment` の出力）をユーザーに提示する。
