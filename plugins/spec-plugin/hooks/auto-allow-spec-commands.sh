#!/bin/bash
# spec関連コマンドを自動許可する
# PreToolUse: Bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# 前後の空白を除去
CMD=$(echo "$CMD" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

# --- プラグインスクリプトの実行 ---
if echo "$CMD" | grep -qE 'spec-plugin/scripts/(get-next-spec-num|init-spec-folder|run-codex-review|run-copilot-review|run-claude-review)\.sh'; then
  echo '{"decision":"allow"}'
  exit 0
fi

# --- spec番号取得コマンド（パターンマッチ・後方互換） ---
if echo "$CMD" | grep -qE '^(next_num=.*)?ls -1d \.specs/\[0-9\].*sort -rn.*head -1'; then
  echo '{"decision":"allow"}'
  exit 0
fi

# --- .specs/ 配下のディレクトリ作成・ファイル操作 ---
if echo "$CMD" | grep -qE '^mkdir -p \.specs/'; then
  echo '{"decision":"allow"}'
  exit 0
fi

if echo "$CMD" | grep -qE '^touch \.specs/'; then
  echo '{"decision":"allow"}'
  exit 0
fi

if echo "$CMD" | grep -qE '^mkdir -p \.specs/\.guard && touch \.specs/\.guard/'; then
  echo '{"decision":"allow"}'
  exit 0
fi

if echo "$CMD" | grep -qE '^rm \.specs/[^/]+/PLANNING$'; then
  echo '{"decision":"allow"}'
  exit 0
fi

if echo "$CMD" | grep -qE '^rm \.specs/\.guard/'; then
  echo '{"decision":"allow"}'
  exit 0
fi

if echo "$CMD" | grep -qE '^echo .* > \.specs/[^/]+/PLANNING$'; then
  echo '{"decision":"allow"}'
  exit 0
fi

exit 0
