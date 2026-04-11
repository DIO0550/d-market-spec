#!/bin/bash
# copilot でレビューを実行する
# Usage: run-copilot-review.sh <prompt-file> <context-file> <output-file>
set -euo pipefail

PROMPT_FILE="${1:?Usage: run-copilot-review.sh <prompt-file> <context-file> <output-file>}"
CONTEXT_FILE="${2:?Usage: run-copilot-review.sh <prompt-file> <context-file> <output-file>}"
OUTPUT_FILE="${3:?Usage: run-copilot-review.sh <prompt-file> <context-file> <output-file>}"

copilot -p "$(cat "$PROMPT_FILE")" < "$CONTEXT_FILE" > "$OUTPUT_FILE"
