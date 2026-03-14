#!/bin/bash
set -euo pipefail

# 計画モード中（.specs/.guard/{session_id} 存在時）に .specs/ 以外への書き込みをブロック
# また、自セッションのガードファイル削除もブロック
#
# PreToolUse: Write, Edit, Bash
# exit 0 = 許可, exit 2 = ブロック

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

[ -z "$SESSION_ID" ] && exit 0

GUARD_FILE=".specs/.guard/${SESSION_ID}"

# ── Bash: ガードファイル削除の検出 & ブロック ──
if [ "$TOOL" = "Bash" ]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  if echo "$CMD" | grep -q '.specs/.guard/' && echo "$CMD" | grep -qE '\brm\b'; then
    if echo "$CMD" | grep -q "$SESSION_ID"; then
      cat >&2 <<EOF
【計画モード】ガードファイルの削除はブロックされました。
実装を開始するにはユーザーが手動でガードファイルを削除してください:
  rm ${GUARD_FILE}
EOF
      exit 2
    fi
  fi
fi

# ── ガードファイルが存在しなければ素通り ──
[ ! -f "$GUARD_FILE" ] && exit 0

# ── Write / Edit: .specs/ 外への書き込みをブロック ──
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ] || [ "$TOOL" = "MultiEdit" ]; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

  echo "$FILE" | grep -qE '(^|/)\.specs/' && exit 0

  cat >&2 <<EOF
【計画モード】${FILE} への書き込みはブロックされました。
.specs/ 以外への書き込みは禁止されています。
ユーザーから明示的な実装開始の指示があるまで、コードの変更は行わないでください。
ガード解除はユーザーが手動で行います: rm ${GUARD_FILE}
EOF
  exit 2
fi

# ── Bash: 書き込み系コマンドのブロック ──
if [ "$TOOL" = "Bash" ]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  # .specs/ への操作は許可
  echo "$CMD" | grep -qE '\.specs/' && exit 0

  # 書き込み系パターンの検出
  if echo "$CMD" | grep -qE '>\s|>$|>>|tee\s|sed\s+-i|cp\s|mv\s|mkdir\s|rm\s|install\s'; then
    cat >&2 <<EOF
【計画モード】ファイル変更コマンドがブロックされました: ${CMD}
.specs/ 以外への変更は禁止されています。
ユーザーから明示的な実装開始の指示があるまで、コードの変更は行わないでください。
ガード解除はユーザーが手動で行います: rm ${GUARD_FILE}
EOF
    exit 2
  fi
fi

exit 0
