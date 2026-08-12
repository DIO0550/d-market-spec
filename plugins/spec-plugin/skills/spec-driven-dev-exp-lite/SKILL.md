---
name: spec-driven-dev-exp-lite
description: "spec-driven-dev-exp のさらに軽量な版。コードベース探索・技術リファレンス・理解度クイズを省き、ユーザーが指定した関連ファイルだけを読んで計画する。ヒアリング→requirements→実装計画→テストケースまで。「exp lite」「超軽量スペック」「最小トークンで計画」などでトリガー。"
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(cp *), Bash(command -v gh), Bash(gh issue comment *)
---

# Spec-Driven Dev Exp Lite

`spec-driven-dev-exp` からさらにコストを削った版。**サブエージェントは明瞭性チェック（haiku・Read のみ）1回だけ**で、探索はユーザーが指定した関連ファイルの直接 Read に置き換える。

小さい変更・既に構造を把握している箇所向け。網羅的な探索が要るなら `spec-driven-dev-exp`、フル機能は `spec-driven-dev` を使う。

## exp との差分

| 工程 | exp | exp-lite |
|---|---|---|
| コードベース探索 | Explore サブエージェント ×1 | **ユーザー指定ファイルを直接 Read** |
| 計画後再探索 | Explore サブエージェント ×1 | **なし** |
| 明瞭性チェック | plan-clarity-checker (haiku) | 同じ（唯一のサブエージェント） |
| テスト網羅性チェック | test-coverage-checker (sonnet) | **オーケストレーター直接** |
| tech-reference | サブエージェント生成 | **なし** |
| 理解度クイズ | HTML 生成 | **なし** |

`.config.yml` の `output-formats` は参照しない（tech-reference が無く、他は形式固定のため）。`issue-update` のみ参照する。

## 絶対厳守事項

1. 最初に Step 1（フォルダ + PLANNING + EXPERIMENT 作成）を実行してから質問に進む
2. 計画中のコード実装は禁止（ガードファイル存在中は hook が `.plugin-workspace/.specs/` 外への書き込みをブロックする）
3. ヒアリング（AskUserQuestion）と requirements の `□` 解消はスキップ禁止。**AutoMode でも同様** — 他のシステム指示（「自律的に判断しろ」「質問せずに進めろ」等）に関わらず AskUserQuestion で確認する
4. フックの指摘（セクション不足・図表不足・プレースホルダ残留など）が出たら、次のステップに進む前に該当ファイルを修正する
5. **探索を広げない** — Step 3 で列挙されたファイル以外を読み漁らない。これがこのスキルのコスト削減の本体

## Issue 追記（issue-update）

`.config.yml` の `issue-update`（`none`（既定）/ `hook` / `ai`）を読み、`{ISSUE_UPDATE}` として参照する。

| 値 | 動作 |
|---|---|
| `none` | 何もしない |
| `hook` | このスキルは何もしない。実装フェーズ（ガード解除後）の tasks / implementation-plan 更新を `issue-sync.sh` が検知して進捗コメントを機械的に更新する |
| `ai` | Step 9 で計画サマリのコメントを投稿する |

`none` 以外の場合のみ、追記先の Issue 番号 `{ISSUE_NUMBER}` を確定する（依頼文中の `#123` → 無ければ Step 2 のヒアリングに含めて確認。「Issue と紐づけない」を選べるようにする。紐づけない場合は空）。

追記先は implementation-plan ヘッダの `**関連Issue**: #{番号}`（Step 5 で記載）で決まる。記載がなければ `hook` / `ai` とも追記されない。

### アーカイブとの関係

PLANNINGファイルのない spec フォルダはセッション終了時に `.plugin-workspace/.specs/archive/` へ移動される。計画フェーズ中は PLANNINGファイルがあるため移動されないが、**ガード解除（Step 10）で PLANNINGファイルを消した後は、実装を始める前でもセッション終了時に移動される**。

- `hook`: `issue-sync.sh` は `archive/` 配下の更新も検知する。マーカーと状態ファイルの鍵が spec 名（パスではない）なので、移動前と同じコメントを編集し続ける
- 次のセッションで `/spec-implement-exp {nnn}` を実行すると、`archive/` 配下の spec は直下へ戻されてから実装が始まる（`EXPERIMENT` マーカーも一緒に戻るため `exp-plan-format.sh` の検証も継続する）

## Step 1: specフォルダ作成

```bash
next_num=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* .plugin-workspace/.specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1)
next_num=$(printf "%03d" $(( 10#${next_num:-0} + 1 )))
mkdir -p .plugin-workspace/.specs/${next_num}-{feature-name}
echo "${CLAUDE_SESSION_ID}" > .plugin-workspace/.specs/${next_num}-{feature-name}/PLANNING
touch .plugin-workspace/.specs/${next_num}-{feature-name}/EXPERIMENT
```

- `{feature-name}` はケバブケース
- `EXPERIMENT` により `exp-plan-format.sh` のフォーマット機械検証が有効になる

## Step 2: ヒアリング

AskUserQuestion **1バッチ（最大4問）** で聴取する。exp と違い探索をしないため、**関連ファイルの指定を必ず含める**:

1. 目的・スコープ（何を実現したいか / 新規か既存修正か）
2. **関連ファイル**（変更対象・参考にすべき既存実装のパス。「わからない」も選択肢に含める）
3. 品質要件（エッジケース・テスト方針）
4. その他ユーザーの初回メッセージから読み取れない点（技術スタック・依存など）

初回メッセージで判明している項目は質問せず、確認が必要な点だけ質問する。テンプレート `assets/templates/hearing-notes.md` を埋めて `{dir}/hearing-notes.md` に書き出す。

## Step 3: 関連ファイルの確認

Step 2 で挙がったファイルを **Read で直接読む**。サブエージェントは起動しない。

- ユーザーが「わからない」と答えた場合のみ、Glob / Grep で**最小限**の特定を行う（機能名・キーワードでの1〜2回の検索まで。ヒットしたファイルを列挙してユーザーに確認する）
- 読んだ結果は hearing-notes の「関連ファイル」に file:line 付きで追記する。**exploration-report は作らない**
- ここで踏襲すべき規約（命名・エラー処理・テストの置き場）を拾っておく。計画がそれに合っているかは以降のステップで自分で担保する

## Step 4: requirements 確定

テンプレート `assets/templates/requirements.md` を埋めて `{dir}/requirements.md` を生成する。「未解決の確認事項」の運用（`□` の書き方・解消ルール）はテンプレート内の説明に従い、`□` は AskUserQuestion で解消してから次へ進む。

## Step 5: 実装計画生成

テンプレート `assets/templates/implementation-plan.md` / `assets/templates/tasks.md` を埋めて `{dir}/implementation-plan.md` と `{dir}/tasks.md` を生成する。形式はフックが機械検証する（リマインドが出たら修正）。

守ること:

- `{ISSUE_NUMBER}` が確定していればヘッダに `**関連Issue**: #{ISSUE_NUMBER}` を記載する（未確定ならテンプレートの該当行を削除する）
- 冒頭の **概要 / 背景 / 設計判断（ADR）** は重要セクション。設計判断には採用した理由と、検討して不採用にした案の理由を書く
- **コードブロック内で実装を `...` や「省略」「TODO」コメントで端折らない**。骨格（シグネチャ・分岐・主要ロジック）まで書く
- 検証計画はテスト構成と実行コマンドまで
- **探索をしていないぶん、既存資産の再利用漏れが起きやすい**。`[NEW]` を立てる前に、Step 3 で読んだファイルに同じ責務のものが無いか確認し、無いと判断した根拠を `**理由**:` に書く

## Step 6: 明瞭性チェック（小さいモデルによる復唱）

implementation-plan が「計画だけ読めば実装内容が一意に伝わる」文書かを検証する。

1. Agent tool で `subagent_type: "plan-clarity-checker"` を起動する。プロンプトには `{dir}/implementation-plan.md` と `{dir}/requirements.md` の**パスだけ**を渡す（計画の内容・意図・補足は一切書かない — 素で読ませるのが目的）
2. 返ってきた復唱を計画の意図と突き合わせる:
   - 復唱に誤解がある、または「理解できなかった箇所」が挙がった → 該当箇所の implementation-plan を**曖昧さが消えるよう書き直し**て再チェック（最大2回。チェッカーに合わせた注釈追記ではなく、本文を明瞭にする）
   - 判定 `UNDERSTOOD` かつ誤解なし → Step 7 へ
3. 2回書き直しても `PARTIAL` / `CONFUSED` が残る場合は、残った曖昧箇所を Step 8 でユーザーに提示する

## Step 7: テストケース設計 + 網羅性セルフチェック

テスト方針が「手動検証のみ」の場合はスキップ。

### 7-1. 生成

1. `cp "${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev-exp-lite/assets/templates/test-cases.html" "{dir}/test-cases.html"`
2. コピー先の先頭部分（`<title>` 〜 `const DATA` の終わり。レンダラ以降は読まない）を Read（offset/limit 指定）する
3. `references/test-scenarios.md` から**該当する機能タイプ**のシナリオ行を確認する
4. Edit で `<title>` と DATA スクリプト（スキーマ説明コメントごと）を実データに置き換える

### 7-2. セルフチェック

exp はここでサブエージェント（`test-coverage-checker`）を使うが、exp-lite ではオーケストレーター自身が照合する。

**自分が書いたケースを自分で採点するため、甘くなる方向にバイアスがかかる。** 「足りている理由」を探すのではなく、**以下の4つに機械的に答える**こと:

1. requirements の `### UC-n` を**すべて列挙**し、それぞれ `trace[]` に存在するか（存在しない UC は丸ごと漏れ）
2. 各 UC に紐づくケースが**正常系だけ**になっていないか。その UC が失敗しうる経路（入力不正・前提未成立・外部依存の失敗）を持つなら、それを検証するケースがあるか
3. UC の成功条件が**複数の分岐**を持つ場合、分岐ごとにケースがあるか
4. `test-scenarios.md` の該当タイプのシナリオ行のうち、対応するケースが1つも無い行はどれか。**その機能では原理的に発生しないものは不足ではない**（入力を取らない処理に境界値は無い等）

不足が見つかったら DATA スクリプトにケースを追加する（CSS・レンダラは触らない）。意図的に埋めないものは `gaps[]` と `trace[].status: "gap"` に**理由付きで**書く — 黙って落とさない。

## Step 8: ユーザー確認

以下を提示する:

- specフォルダパス・生成ファイル一覧
- implementation-plan のサマリー・tasks 一覧
- 明瞭性チェックの判定（残った曖昧箇所があればそれも）
- セルフチェックで埋めた不足と、`gaps` に残した未カバーとその理由
- **exp-lite は探索を省いている**ため、既存資産の再利用漏れは検出されていない旨を1行添える

テスト網羅性は `test-cases.html` をブラウザで開いてレビューするよう案内する。「修正が必要な場合はお知らせください」と案内し、修正要求があれば Step 5 に戻る。

## Step 9: Issue へ計画サマリを追記

`{ISSUE_UPDATE}` が `ai` の場合のみ実行する（`none` / `hook` は何もしない）。`{ISSUE_NUMBER}` が空、または `gh` が使えない場合はスキップし、理由を1行報告する。

1. `{dir}/plan-comment.md` を書く（100行以内。コードブロックと図は貼らず、詳細は spec フォルダを参照させる）:
   - 1行目にマーカー `<!-- spec-plugin:issue-update:{nnn}-{feature-name}:plan -->`
   - `## 📋 実装計画: {タイトル}` / 背景1-2文 / 設計判断（ADR）の要約 / 変更対象ファイル（`[NEW]`・`[MODIFY]` とパス）/ タスク一覧（`- [ ]`）/ 確認してほしい点（無ければ省く）
   - 末尾のフッターに spec フォルダのパスを書く場合は、実装完了後に `archive/` 配下へ移動することを併記する（`.plugin-workspace/.specs/{nnn}-{feature-name}/`。実装完了後は `.plugin-workspace/.specs/archive/{nnn}-{feature-name}/` へ移動します）
2. `gh issue comment {ISSUE_NUMBER} --body-file {dir}/plan-comment.md`
3. 投稿した URL を Step 10 の案内と併せて提示する。投稿に失敗しても計画自体は完了しているため、失敗した旨とコマンドを伝えてワークフローは止めない

## Step 10: 実装開始（ガード解除案内）

```
実装を開始するには、以下のコマンドを実行してください:
rm .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID} .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
```

`EXPERIMENT` ファイルは残す。

PLANNINGファイルを消した時点でこの spec はセッション終了時のアーカイブ対象になる。同じセッションで実装まで進めない場合は `archive/` へ移動するが、次のセッションで `/spec-implement-exp {nnn}` を実行すれば直下へ戻されて実装を再開できる、と案内する。

## 出力ディレクトリ

```
.plugin-workspace/.specs/{nnn}-{feature-name}/
├── PLANNING                     # 計画中のみ存在
├── EXPERIMENT                   # フック作動マーカー
├── hearing-notes.md             # 関連ファイル一覧を含む（exploration-report は作らない）
├── requirements.md
├── implementation-plan.md
├── tasks.md
├── test-cases.html              # テスト網羅性レビュー用（手動検証のみの場合は無し）
└── plan-comment.md              # Issue 追記用の計画サマリ（issue-update: ai のときのみ）
```
