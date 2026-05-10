# レビューループ共通手順

レビュー付きバリアント（Copilot / Codex / Claude Code）で共通のレビューループ手順。
SKILL.md本文で宣言された `{REVIEW_COMMAND}` を使ってレビューを実行する。

---

## レビュー結果の保存先

```bash
mkdir -p .plugin-workspace/.specs/{nnn}-{feature-name}/plan-review
```

レビュー結果は `.plugin-workspace/.specs/{nnn}-{feature-name}/plan-review/review-{NNN}.md` に保存する。
`{NNN}` は3桁の連番（001, 002, 003...）。

---

## プロンプトファイルの組み立て

レビュー実行前に、Writeツールで `.plugin-workspace/.specs/{nnn}-{feature-name}/plan-review/prompt-{NNN}.txt` にレビュー指示文を書き出す。
`{NNN}` は `review-{NNN}.md` と同じ連番。再レビュー時はインクリメントする。

**prompt-{NNN}.txt の内容**:

```
以下の実装計画をレビューしてください。

【重要】ファイルの作成・編集は一切行わないでください。レビュー結果は標準出力のみで回答してください。

レビュー観点:
1. 仕様の曖昧さ・抜け漏れはないか
2. 実装可能性に問題はないか
3. エッジケースは考慮されているか
4. ファイル構成は妥当か
5. 全体アーキテクチャとの整合性はあるか

問題がなければ「問題なし」と回答してください。
問題があれば具体的な指摘と改善案を提示してください。
```

バリアントごとの補足（SKILL.md本文で定義）があればプロンプト末尾に追記する。

---

## レビュー実行

SKILL.md本文で宣言された `{REVIEW_COMMAND}` を使用する。

```bash
{REVIEW_COMMAND}
```

実行結果は `.plugin-workspace/.specs/{nnn}-{feature-name}/plan-review/review-{NNN}.md` に保存される。

---

## ループ処理

1. 保存したレビュー結果ファイルを読み込み、内容を解析
2. 「問題なし」なら次のステップ（ユーザー確認）へ進む
3. 問題があれば:
   - 指摘内容を元に implementation-plan.md を修正
   - **反映履歴は書かない**: 指摘を反映する際、implementation-plan.md にレビュー反映履歴・変更履歴を追記しないこと。設計内容そのものだけを修正する
   - 連番をインクリメントして再度レビューを実行・保存
   - **最大5回**までループ

レビュー観点の詳細は `references/review-criteria.md` を参照。

---

## 出力構造

```
.plugin-workspace/.specs/{nnn}-{feature-name}/
└── plan-review/
    ├── prompt-001.txt
    ├── review-001.md
    ├── prompt-002.txt
    ├── review-002.md
    └── ...
```
