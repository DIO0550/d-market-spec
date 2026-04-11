#!/bin/bash
# claude でレビューを実行する
# Usage: run-claude-review.sh <prompt-file> <context-file> <output-file>
set -euo pipefail

PROMPT_FILE="${1:?Usage: run-claude-review.sh <prompt-file> <context-file> <output-file>}"
CONTEXT_FILE="${2:?Usage: run-claude-review.sh <prompt-file> <context-file> <output-file>}"
OUTPUT_FILE="${3:?Usage: run-claude-review.sh <prompt-file> <context-file> <output-file>}"

claude -p "$(cat "$PROMPT_FILE")" "$CONTEXT_FILE" > "$OUTPUT_FILE"
