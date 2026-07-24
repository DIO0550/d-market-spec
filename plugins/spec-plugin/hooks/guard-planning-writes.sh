#!/bin/bash
set -euo pipefail

# 計画モード中（.plugin-workspace/.specs/.guard/{session_id} 存在時）に .plugin-workspace/.specs/ 以外への書き込みをブロック
# また、自セッションのガードファイル削除もブロック
# worktree内での起動時は worktree 外への書き込みもブロック
#
# PreToolUse: Write, Edit, Bash
# exit 0 = 許可, exit 2 = ブロック

SPEC_BASE=".plugin-workspace/.specs"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

[ -z "$SESSION_ID" ] && exit 0

GUARD_FILE="${SPEC_BASE}/.guard/${SESSION_ID}"

# ── Bash: ガードファイル削除の検出 & ブロック ──
if [ "$TOOL" = "Bash" ]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  if echo "$CMD" | grep -q '.plugin-workspace/.specs/.guard/' && echo "$CMD" | grep -qE '\brm\b'; then
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

# ── worktree検出（ガードファイル存在時のみ） ──
WORKTREE_ROOT=""
_gd=$(git rev-parse --git-dir 2>/dev/null || true)
_gc=$(git rev-parse --git-common-dir 2>/dev/null || true)
if [ -n "$_gd" ] && [ -n "$_gc" ]; then
  _rgd=$(cd "$_gd" 2>/dev/null && pwd -P || echo "$_gd")
  _rgc=$(cd "$_gc" 2>/dev/null && pwd -P || echo "$_gc")
  if [ "$_rgd" != "$_rgc" ]; then
    WORKTREE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  fi
fi

# ── Write / Edit: 書き込みブロック ──
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ] || [ "$TOOL" = "MultiEdit" ]; then
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

  # worktree外への書き込みをブロック
  if [ -n "$WORKTREE_ROOT" ] && [ -n "$FILE" ]; then
    ABS_FILE=$(realpath -m "$FILE" 2>/dev/null || true)
    if [ -z "$ABS_FILE" ]; then
      if [[ "$FILE" = /* ]]; then ABS_FILE="$FILE"; else ABS_FILE="$(pwd)/$FILE"; fi
    fi
    case "$ABS_FILE" in
      "${WORKTREE_ROOT}/"*|"${WORKTREE_ROOT}") ;;
      *)
        cat >&2 <<EOF
【worktreeガード】${FILE} への書き込みはブロックされました。
worktree (${WORKTREE_ROOT}) 外への書き込みは禁止されています。
worktree内のファイルのみ変更してください。
EOF
        exit 2
        ;;
    esac
  fi

  # .plugin-workspace/.specs/ 内は許可
  echo "$FILE" | grep -qE '(^|/)\.plugin-workspace/\.specs/' && exit 0

  cat >&2 <<EOF
【計画モード】${FILE} への書き込みはブロックされました。
.plugin-workspace/.specs/ 以外への書き込みは禁止されています。
ユーザーから明示的な実装開始の指示があるまで、コードの変更は行わないでください。
ガード解除はユーザーが手動で行います: rm ${GUARD_FILE}
EOF
  exit 2
fi

# ── Bash: 書き込み系コマンドのブロック ──
if [ "$TOOL" = "Bash" ]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  # worktree外への絶対パス操作をブロック（書き込み系コマンドの場合）
  if [ -n "$WORKTREE_ROOT" ] && echo "$CMD" | grep -qE '>\s|>$|>>|tee\s|sed\s+-i|cp\s|mv\s|mkdir\s|rm\s|install\s'; then
    suspect_path=""
    while IFS= read -r _p; do
      [ -z "$_p" ] && continue
      case "$_p" in
        /dev/*|/tmp/*|/proc/*|/sys/*|/usr/*|/bin/*|/opt/*|/etc/*|/var/*|/run/*|/sbin/*|/lib/*) continue ;;
      esac
      case "$_p" in
        "${WORKTREE_ROOT}/"*|"${WORKTREE_ROOT}") ;;
        *) suspect_path="$_p"; break ;;
      esac
    done < <(echo "$CMD" | grep -oE '/[a-zA-Z0-9_./-]+' || true)
    if [ -n "$suspect_path" ]; then
      cat >&2 <<EOF
【worktreeガード】ファイル変更コマンドがブロックされました。
worktree (${WORKTREE_ROOT}) 外のパス (${suspect_path}) への操作は禁止されています。
コマンド: ${CMD:0:200}
worktree内のパスのみ使用してください。
EOF
      exit 2
    fi
  fi

  # .plugin-workspace/.specs/ への操作は許可
  echo "$CMD" | grep -qE '\.plugin-workspace/\.specs/' && exit 0

  # 書き込み系パターンの検出
  if echo "$CMD" | grep -qE '>\s|>$|>>|tee\s|sed\s+-i|cp\s|mv\s|mkdir\s|rm\s|install\s'; then
    cat >&2 <<EOF
【計画モード】ファイル変更コマンドがブロックされました: ${CMD}
.plugin-workspace/.specs/ 以外への変更は禁止されています。
ユーザーから明示的な実装開始の指示があるまで、コードの変更は行わないでください。
ガード解除はユーザーが手動で行います: rm ${GUARD_FILE}
EOF
    exit 2
  fi
fi

exit 0
