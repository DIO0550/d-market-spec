#!/bin/bash
# /spec-driven-dev, /spec-implement の起動を検出し sessionTitle を設定する
# プラグイン名前空間つき (/spec-plugin:spec-driven-dev など) にも対応
# UserPromptSubmit

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
[ -z "$PROMPT" ] && exit 0

# プラグイン名前空間プレフィックスを取り除いた形で判定する
CMD=$(echo "$PROMPT" | sed -E 's|^/[a-z0-9_-]+:|/|')

case "$CMD" in
  /spec-driven-dev*)  LABEL="📋 plan" ;;
  /spec-implement*)   LABEL="🔨 impl" ;;
  *) exit 0 ;;
esac

# 番号抽出: #N > 引数の数字 > specs ディレクトリから自動取得
NUM=$(grep -oE '#[0-9]+' <<<"$PROMPT" | head -1)

if [ -z "$NUM" ]; then
  SPEC_NUM=$(echo "$CMD" | sed -nE 's|^/spec-[a-z-]+ +([0-9]+).*|\1|p')
  if [ -z "$SPEC_NUM" ]; then
    SPEC_NUM=$(ls -1d .plugin-workspace/.specs/[0-9][0-9][0-9]-*/ 2>/dev/null \
      | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' | sort -rn | head -1)
  fi
  [ -n "$SPEC_NUM" ] && NUM="#${SPEC_NUM}"
fi

[ -n "$NUM" ] && LABEL="${LABEL} ${NUM}"

jq -nc --arg t "$LABEL" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}'
