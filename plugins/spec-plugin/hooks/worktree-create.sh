#!/bin/bash
# WorktreeCreate hook: git worktree作成 + .specs/ コピー
#
# stdin: { "name": "...", "cwd": "...", ... }
# stdout: 作成したworktreeの絶対パス（これ以外は stderr へ）

set -euo pipefail

input=$(cat)

NAME=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
CWD=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin)['cwd'])")

WORKTREE_DIR="$CWD/.claude/worktrees/$NAME"
BRANCH="claude-worktree-$NAME"

# git worktree 作成
git -C "$CWD" worktree add -b "$BRANCH" "$WORKTREE_DIR" HEAD >&2

# .specs/ が存在すればコピー
if [ -d "$CWD/.specs" ]; then
  cp -r "$CWD/.specs" "$WORKTREE_DIR/.specs"
  echo "Copied .specs/ to worktree" >&2
fi

# stdout にパスを出力（Claude Code がこれを読む）
echo "$WORKTREE_DIR"
