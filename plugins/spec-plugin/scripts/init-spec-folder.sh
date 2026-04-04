#!/bin/bash
# specフォルダを初期化する
# Usage: init-spec-folder.sh <feature-name> [session-id]
#   feature-name : スペック名（例: user-auth）
#   session-id   : CLAUDE_SESSION_ID（指定時はguardファイルも作成）
set -euo pipefail

FEATURE_NAME="${1:?Usage: init-spec-folder.sh <feature-name> [session-id]}"
SESSION_ID="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEXT_NUM=$("$SCRIPT_DIR/get-next-spec-num.sh")

SPEC_DIR=".specs/${NEXT_NUM}-${FEATURE_NAME}"

# specフォルダ + PLANNINGファイル作成
mkdir -p "$SPEC_DIR"
echo "${SESSION_ID:-planning}" > "$SPEC_DIR/PLANNING"

# session-id指定時はguardファイルも作成
if [ -n "$SESSION_ID" ]; then
  mkdir -p .specs/.guard
  touch ".specs/.guard/${SESSION_ID}"
fi

echo "$SPEC_DIR"
