#!/bin/bash
# spec番号取得コマンドを自動許可する（完全一致）
# PreToolUse: Bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# SKILL.mdで指定されているspec番号取得の完全コマンド
read -r -d '' FULL_CMD << 'EXPECTED'
next_num=$(printf "%03d" $(( $(ls -1d .specs/[0-9][0-9][0-9]-* .specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1 | sed 's/^0*//; s/^$/0/') + 1 )))
EXPECTED

# 内側のパイプラインだけの場合
read -r -d '' INNER_CMD << 'EXPECTED'
ls -1d .specs/[0-9][0-9][0-9]-* .specs/archive/[0-9][0-9][0-9]-* 2>/dev/null | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1
EXPECTED

if [ "$CMD" = "$FULL_CMD" ] || [ "$CMD" = "$INNER_CMD" ]; then
  echo '{"decision":"allow"}'
fi

exit 0
