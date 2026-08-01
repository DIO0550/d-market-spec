#!/bin/bash
set -euo pipefail

# devスキル発火時にガードファイルを自動作成する
# PostToolUse: Skill
#
# 対象スキル: spec-driven-dev, spec-driven-dev-lite, spec-driven-dev-exp
# ガードファイル: .plugin-workspace/.specs/.guard/${SESSION_ID}

SPEC_BASE=".plugin-workspace/.specs"

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

[ "$TOOL" != "Skill" ] && exit 0
[ -z "$SESSION_ID" ] && exit 0

SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty')
SKILL_BASE="${SKILL##*:}"

case "$SKILL_BASE" in
  spec-driven-dev|spec-driven-dev-lite|spec-driven-dev-exp) ;;
  *) exit 0 ;;
esac

mkdir -p "${SPEC_BASE}/.guard"
touch "${SPEC_BASE}/.guard/${SESSION_ID}"

jq -n --arg sid "$SESSION_ID" '{
  systemMessage: ("【ガード有効化】計画モードのガードファイルを自動作成しました: .plugin-workspace/.specs/.guard/" + $sid + "\n.plugin-workspace/.specs/ 以外への書き込みはブロックされます。")
}'
