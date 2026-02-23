#!/bin/bash
# WorktreeRemove hook: .specs/ を元リポジトリへ同期してから git worktree 削除
#
# stdin: { "worktree_path": "...", ... }
# stdout: なし（ログは stderr へ）

set -euo pipefail

input=$(cat)

WORKTREE_PATH=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin)['worktree_path'])")

if [ -z "$WORKTREE_PATH" ] || [ ! -d "$WORKTREE_PATH" ]; then
  echo "Worktree path not found: $WORKTREE_PATH" >&2
  exit 0
fi

# 元リポジトリのパスを取得（.claude/worktrees/{name} → 元リポジトリ）
ORIGINAL_REPO=$(git -C "$WORKTREE_PATH" worktree list --porcelain | head -1 | sed 's/^worktree //')

if [ -z "$ORIGINAL_REPO" ]; then
  echo "Could not determine original repo path" >&2
  exit 0
fi

# .specs/ を元リポジトリへ同期
if [ -d "$WORKTREE_PATH/.specs" ]; then
  # rsync で差分のみ同期（削除は行わない）
  rsync -a --update "$WORKTREE_PATH/.specs/" "$ORIGINAL_REPO/.specs/"
  echo "Synced .specs/ back to original repo: $ORIGINAL_REPO" >&2
fi

# git worktree 削除
git worktree remove --force "$WORKTREE_PATH" >&2 2>/dev/null || rm -rf "$WORKTREE_PATH"

echo "Removed worktree: $WORKTREE_PATH" >&2
