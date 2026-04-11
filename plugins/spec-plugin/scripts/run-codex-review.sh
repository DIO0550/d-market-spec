#!/bin/bash
# codex でレビューを実行する
# Usage: run-codex-review.sh <prompt-file> <output-file>
set -euo pipefail

PROMPT_FILE="${1:?Usage: run-codex-review.sh <prompt-file> <output-file>}"
OUTPUT_FILE="${2:?Usage: run-codex-review.sh <prompt-file> <output-file>}"

codex exec --cd "$PWD" --dangerously-bypass-approvals-and-sandbox "$(cat "$PROMPT_FILE")" > "$OUTPUT_FILE"
