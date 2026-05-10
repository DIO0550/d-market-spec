---
name: spec-driven-fix-review
description: "spec-viewerで付けたレビューコメント（.comments/impl.json）を読み取り、implementation-plan.mdとtasks.mdに修正を反映するスキル。spec-driven-devの計画レビュー後に使用する。「レビュー反映」「コメント反映」「fix review」「レビュー修正」「コメントを適用」「spec-viewerの指摘を反映」「レビュー結果を反映して」などで積極的に使用すること。"
---

# Spec-Driven Fix Review

spec-viewerの未解決レビューコメントを implementation-plan.md と tasks.md に反映する。

---

## ワークフロー

### Step 1: コメントと計画を読み込む

現在作業中のspecフォルダ（会話コンテキストから既知）を `$SPEC_DIR` とする。

`$SPEC_DIR/.comments/impl.json` と `$SPEC_DIR/implementation-plan.md` を Read で読み込む。

impl.json が存在しない、または `resolved: false` のコメントが0件なら、その旨を通知して終了。

### Step 2: コメントを修正指示として適用

未解決コメントを `anchor.blockIndex` の昇順で処理する。コメントごとに:

1. `anchor.textSnippet` で implementation-plan.md 内の対象箇所を特定する。見つからなければ `anchor.blockType` と `anchor.blockIndex` で推定する
2. `body` の修正指示に従って Edit で修正する
3. 修正がタスク構成に影響する場合は `$SPEC_DIR/tasks.md` も更新する

**システム図の保護**: ASCII罫線図のシステム図は spec-driven-dev が必須としている成果物のため、削除せず図自体を更新する。

### Step 3: 修正結果を報告

コメントごとに1行で報告する:

```
- [cmt_xxx...xxx] 「{textSnippet}」 → {修正内容の要約}
```

spec-viewerでの確認を案内する。
