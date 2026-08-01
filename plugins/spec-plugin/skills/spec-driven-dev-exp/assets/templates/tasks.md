# Task: {目的を簡潔に記述}

## Research & Planning

- □ {調査・計画タスク1}
- □ {調査・計画タスク2}
- □ {調査・計画タスク3}

## Implementation

- □ {実装タスク1}
- □ {実装タスク2}
- □ {実装タスク3}
- □ {実装タスク4}

## Verification

- □ {検証タスク1}
- □ {検証タスク2}
- □ {検証タスク3}

---

<!--
使用例 (標準構成):

# Task: Implement Block Button on Ranking Page

## Research & Planning

- □ Analyze Nico Nico ranking page DOM for User ID and Button placement
- □ Explore existing codebase (content scripts, storage)
- □ Create Implementation Plan

## Implementation

- □ Create/Update content script for Ranking Page
- □ Implement generic "Block Button" injection logic
- □ Implement logic to extract User ID from DOM
- □ Connect button to Blocklist Storage

## Verification

- □ Verify button appears on ranking page
- □ Verify clicking blocks the user
- □ Verify blocked videos are hidden

---

構成ルール:

- TDD構成: Pure Logic / 状態管理などテスト主導が有効な場合、Implementation を
  「機能単位 → RED / GREEN / REFACTOR」のサブタスクで構成する
  （順序: シンプルな正常系 → バリエーション → 境界値 → 異常系・エッジケース）
- テスト追加構成: 自動テストは書くがTDDでない場合、Implementation の後に Test セクションを追加
- 手動検証のみ: ロジック・状態管理・外部依存を含まないUI/スタイリング変更のみ
- タスクは1ファイル1変更程度まで分割し、各行に明確な完了条件を持たせる
-->
