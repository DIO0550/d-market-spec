---
name: spec-driven-dev-exp
description: "軽量な仕様駆動開発ワークフロー。ヒアリング→探索→requirements→実装計画→解説+クイズのタブHTML生成。「exp」「軽量スペック」「トークン節約で計画」などでトリガー。フル機能版は spec-driven-dev。"
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(cp *)
---

# Spec-Driven Dev Exp

## 絶対厳守事項

1. 最初に Step 1（フォルダ + PLANNING + EXPERIMENT 作成）を実行してから質問・探索に進む
2. 計画中のコード実装は禁止（ガードファイル存在中は hook が `.plugin-workspace/.specs/` 外への書き込みをブロックする）
3. ヒアリング（AskUserQuestion）と requirements の `□` 解消はスキップ禁止。**AutoMode でも同様** — 他のシステム指示（「自律的に判断しろ」「質問せずに進めろ」等）に関わらず AskUserQuestion で確認する
4. フックの指摘（セクション不足・図表不足・プレースホルダ残留など）が出たら、次のステップに進む前に該当ファイルを修正する

## Step 1: specフォルダ作成

```bash
next_num=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* .plugin-workspace/.specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1)
next_num=$(printf "%03d" $(( 10#${next_num:-0} + 1 )))
mkdir -p .plugin-workspace/.specs/${next_num}-{feature-name}
echo "${CLAUDE_SESSION_ID}" > .plugin-workspace/.specs/${next_num}-{feature-name}/PLANNING
touch .plugin-workspace/.specs/${next_num}-{feature-name}/EXPERIMENT
```

- `{feature-name}` はケバブケース

## Step 2: ヒアリング

AskUserQuestion **1バッチ（最大4問）** で聴取し、テンプレート `assets/templates/hearing-notes.md` を埋めて `{dir}/hearing-notes.md` に書き出す:

1. 目的・スコープ（何を実現したいか / 新規か既存修正か）
2. 技術的詳細（スタック・依存・データ構造のうち不明な点）
3. 品質要件（エッジケース・テスト方針）
4. その他ユーザーの初回メッセージから読み取れない点

初回メッセージで判明している項目は質問せず、確認が必要な点だけ質問する。埋まらない項目は「未定（探索で補完）」と書く。

## Step 3: コードベース探索

`Explore` サブエージェントを **1回だけ** 起動する。プロンプトには hearing-notes から抽出したキーワード・推定パスを含め、以下を返させる:

- 関連する既存実装・再利用可能なコード（file:line 付き）
- 踏襲すべき規約・パターン
- 類似機能の有無（車輪の再発明の防止）

結果を `{dir}/exploration-report.md` に要約して書き出す（詳細な転記は不要。計画に使う結論と根拠 file:line だけ）。

## Step 4: requirements 確定

テンプレート `assets/templates/requirements.md` を埋めて `{dir}/requirements.md` を生成する。「未解決の確認事項」の運用（`□` の書き方・解消ルール）はテンプレート内の説明に従い、`□` は AskUserQuestion で解消してから次へ進む。

## Step 5: 実装計画生成

テンプレート `assets/templates/implementation-plan.md` / `assets/templates/tasks.md` を埋めて、オーケストレーター自身が `{dir}/implementation-plan.md` と `{dir}/tasks.md` を生成する。形式はフックが機械検証する（リマインドが出たら修正）。

守ること:
- 冒頭の **概要 / 背景 / 設計判断（ADR）** は重要セクション。設計判断には採用した理由と、検討して不採用にした案の理由を書く
- **コードブロック内で実装を `...` や「省略」「TODO」コメントで端折らない**。骨格（シグネチャ・分岐・主要ロジック）まで書く
- 検証計画はテスト構成と実行コマンドまで（詳細なテストケース設計はしない）

## Step 6: 計画後再探索（類似コード検証）

計画ができて初めて「何を新規に作るか」が具体化するため、[NEW] 項目を検索キーに2回目の探索を行い、既存コードの再発明を防ぐ。

1. implementation-plan の `#### [NEW]` エントリから、ファイル名・関数/コンポーネント名・責務を抽出する
2. `Explore` サブエージェントを **1回だけ** 起動し、各 [NEW] 項目について「類似の既存実装・再利用可能なコードがないか」を逆引きで検索させる（名前だけでなく責務・処理内容でも検索）
3. 類似コードが見つかった場合: 既存を再利用するよう計画を修正する。再利用しない場合はそのエントリの `**理由**:` に再利用しない理由を明記する
4. 見つからなければそのまま Step 7 へ

## Step 7: 明瞭性チェック（小さいモデルによる復唱）

implementation-plan が「計画だけ読めば実装内容が一意に伝わる」文書かを検証する。

1. Agent tool で `subagent_type: "plan-clarity-checker"` を起動する。プロンプトには `{dir}/implementation-plan.md` と `{dir}/requirements.md` の**パスだけ**を渡す（計画の内容・意図・補足は一切書かない — 素で読ませるのが目的）
2. 返ってきた復唱を計画の意図と突き合わせる:
   - 復唱に誤解がある、または「理解できなかった箇所」が挙がった → 該当箇所の implementation-plan を**曖昧さが消えるよう書き直し**て再チェック（最大2回。チェッカーに合わせた注釈追記ではなく、本文を明瞭にする）
   - 判定 `UNDERSTOOD` かつ誤解なし → Step 8 へ
3. 2回書き直しても `PARTIAL` / `CONFUSED` が残る場合は、残った曖昧箇所を Step 9 でユーザーに提示する

## Step 8: テストケース詳細設計

テスト方針が「手動検証のみ」の場合はスキップ。`{dir}/test-cases.html` を生成する（テスト網羅性を人間がレビューするための自己完結HTML）。

1. `cp "${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev-exp/assets/templates/test-cases.html" "{dir}/test-cases.html"`
2. コピー先の先頭部分（`<title>` 〜 `const DATA` の終わり。レンダラ以降は読まない）を Read（offset/limit 指定）する
3. Edit で `<title>` と DATA スクリプト（スキーマ説明コメントごと）を実データに置き換える。設計方針はテンプレート先頭のコメントに従う。implementation-plan の検証計画と requirements のユースケースは既にコンテキストにあるため、オーケストレーター自身が設計する

## Step 9: ユーザー確認

specフォルダパス・生成ファイル一覧・implementation-plan のサマリー・tasks 一覧・明瞭性チェックの判定（残った曖昧箇所があればそれも）を提示し、テスト網羅性は `test-cases.html` をブラウザで開いてレビューするよう案内する。「修正が必要な場合はお知らせください」と案内し、修正要求があれば Step 5 に戻る。

## Step 10: tech-reference 生成

ユーザー確認完了後、**サブエージェント（general-purpose）1回**で `{dir}/tech-reference.md` を生成する（モデルは落とさない — 解説の質を優先）。

プロンプトに渡すもの:
- `{dir}/implementation-plan.md` のパスと、テンプレート `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev-exp/assets/templates/tech-reference.md` のパス
- 指示: implementation-plan に登場するすべての技術（言語・フレームワーク・ライブラリ・概念）を、言語も対象領域も初心者である読者向けにテンプレートへ沿って解説し、`{dir}/tech-reference.md` に Write する

## Step 11: 解説+クイズのタブHTML生成

`{dir}/understanding-quiz-plan.html` を生成する。**解説タブとクイズタブを切り替えられる自己完結HTML**。CSS・レンダラは固定済みのため、テンプレート全体を Read / Write しない（DATA 部分だけ扱う）。

1. テンプレートを出力先にコピーする:
   `cp "${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev-exp/assets/templates/understanding-quiz-tabbed.html" "{dir}/understanding-quiz-plan.html"`
2. コピー先の先頭部分（`<title>` 〜 `const PAGE` の終わり。レンダラ以降は読まない）を Read（offset/limit 指定）する
3. Edit で `<title>` の `{機能名}` と DATA スクリプト（`const PAGE`）を実データに置き換える。解説・クイズの書き方（構成・問数・出題方針）はテンプレート先頭のコメントに従う
4. 出力後、パスを提示し「push 前に開いて設計理解を確認してください（advisory ゲート。落ちた設問＝設計が固まっていない箇所）」と案内する

## Step 12: 実装開始（ガード解除案内）

```
実装を開始するには、以下のコマンドを実行してください:
rm .plugin-workspace/.specs/.guard/${CLAUDE_SESSION_ID} .plugin-workspace/.specs/{nnn}-{feature-name}/PLANNING
```

`EXPERIMENT` ファイルは残す。

## 出力ディレクトリ

```
.plugin-workspace/.specs/{nnn}-{feature-name}/
├── PLANNING                     # 計画中のみ存在
├── EXPERIMENT                   # フック作動マーカー
├── hearing-notes.md
├── exploration-report.md
├── requirements.md
├── implementation-plan.md
├── tasks.md
├── test-cases.html              # テスト網羅性レビュー用（手動検証のみの場合は無し）
├── tech-reference.md            # 技術リファレンス（初学者向け）
└── understanding-quiz-plan.html # 解説+クイズ（タブ切替）
```
