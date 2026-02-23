#!/bin/bash
# WorktreeRemove hook: git worktree 削除
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

# git worktree 削除
git worktree remove --force "$WORKTREE_PATH" >&2 2>/dev/null || rm -rf "$WORKTREE_PATH"

echo "Removed worktree: $WORKTREE_PATH" >&2
