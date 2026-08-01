---
name: spec-driven-dev-exp
description: "軽量な仕様駆動開発ワークフロー。ヒアリング→探索→requirements→実装計画→解説+クイズのタブHTML生成。「exp」「軽量スペック」「トークン節約で計画」などでトリガー。"
disable-model-invocation: true
allowed-tools: Bash(ls *), Bash(mkdir *), Bash(touch *), Bash(echo *), Bash(printf *), Bash(rm .plugin-workspace/.specs/*/PLANNING)
---

# Spec-Driven Dev Exp

## 絶対厳守事項

1. 最初に Step 1（フォルダ + PLANNING + EXPERIMENT 作成）を実行してから質問・探索に進む
2. PLANNINGファイルがある間はコード実装禁止
3. ヒアリング（AskUserQuestion）と requirements の `□` 解消はスキップ禁止
4. フックのリマインド（セクション不足・図表不足・プレースホルダ残留など）が出たら、次のステップに進む前に該当ファイルを修正する

## ワークフロー

```
1. specフォルダ + PLANNING + EXPERIMENT 作成
2. ヒアリング（AskUserQuestion 1バッチ）→ hearing-notes.md
3. コードベース探索（Explore サブエージェント1回）→ exploration-report.md
4. requirements.md 確定（□ を AskUserQuestion で解消 — hook が縛る）
5. implementation-plan.md + tasks.md をオーケストレーターが生成（hook が形式を検証）
6. ユーザー確認 → 修正
7. 解説+クイズのタブHTML生成（understanding-quiz-plan.html）
8. ガード解除案内
```

## Step 1: specフォルダ作成

```bash
n=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-* .plugin-workspace/.specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's#.*/\([0-9]\{3\}\)-.*#\1#' | sort -rn | head -1)
next=$(printf '%03d' $((10#${n:-0} + 1)))
dir=".plugin-workspace/.specs/${next}-{feature-name}"
mkdir -p "$dir"
echo "${CLAUDE_SESSION_ID}" > "$dir/PLANNING"
touch "$dir/EXPERIMENT"
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

テンプレート `assets/templates/requirements.md` を埋めて `{dir}/requirements.md` を生成する。

- ユースケース・機能/非機能要件・制約を記述
- コードベースから判断できず**ユーザーにしか決められない分岐**を「未解決の確認事項」に行頭 `□` で列挙
- `□` があれば AskUserQuestion で確認し `■` に解消（なければ「なし」）

> `□` が残ったまま implementation-plan を書くと `guard-requirements.sh` がブロックする。

## Step 5: 実装計画生成

テンプレート `assets/templates/implementation-plan.md` / `assets/templates/tasks.md` を埋めて、オーケストレーター自身が `{dir}/implementation-plan.md` と `{dir}/tasks.md` を生成する。形式はフックが機械検証する（リマインドが出たら修正）。

守ること:
- 冒頭の **概要 / 背景 / 設計判断（ADR）** は重要セクション。設計判断には採用した理由と、検討して不採用にした案の理由を書く
- 変更対象は `#### [NEW]` / `#### [MODIFY]` / `#### [DELETE]` + コードブロック。[MODIFY] は `##### before` / `##### after` の見出しでコードブロックを分ける
- 各エントリに `**理由**:` を書く（なぜこの変更・この形にするか）
- コードブロック内で実装を `...` や「省略」「TODO」コメントで端折らない。骨格（シグネチャ・分岐・主要ロジック）まで書く
- 検証計画はテスト戦略と実行コマンドまで（詳細なテストケース設計はしない）
- tasks.md は Research & Planning → Implementation → Verification の3セクション、行頭 `□`

## Step 6: ユーザー確認

specフォルダパス・生成ファイル一覧・implementation-plan のサマリー・tasks 一覧を提示し、「修正が必要な場合はお知らせください」と案内する。修正要求があれば Step 5 に戻る。

## Step 7: 解説+クイズのタブHTML生成

テンプレート `assets/templates/understanding-quiz-tabbed.html` を使い、`{dir}/understanding-quiz-plan.html` を生成する。**解説タブとクイズタブを切り替えられる自己完結HTML**。

1. テンプレートを Read し、先頭の DATA スクリプト（`const PAGE`）だけを実データで置き換える。CSS・レンダラは1文字も変更しない
2. `<title>` の `{機能名}` を置換し、プレースホルダを残さない
3. **解説タブ（`PAGE.explain`）**: 計画の要点を読み物として解説する — 設計判断とその理由・データフロー・変わりやすい箇所・requirements で確定した分岐。実装フェーズで計画と実装がズレた場合の追記欄（`changes` セクション）は空配列で用意しておく
4. **クイズタブ（`PAGE.quiz`）**: 5〜8問（choice / boolean / order）。「なぜこの設計にしたか」「この制約が壊れると何が起きるか」を問う。誤答はもっともらしい別設計にする。ある設問の解説が別の設問の答えを含まないようにする
5. 出力後、パスを提示し「push 前に開いて設計理解を確認してください（advisory ゲート。落ちた設問＝設計が固まっていない箇所）」と案内する

## Step 8: 実装開始（ガード解除案内）

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
└── understanding-quiz-plan.html # 解説+クイズ（タブ切替）
```
