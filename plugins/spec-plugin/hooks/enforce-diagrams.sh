#!/bin/bash
# implementation-plan / design-doc に状態マシン図・データフロー図が含まれているか検証するフック
# PreToolUse: Write
#
# 対象: *implementation-plan*.md, *design-doc*.md
# exit 0 = 許可, exit 2 = ブロック（メッセージ付き）

input=$(cat)

# file_path を抽出
file_path=$(echo "$input" | grep -oE '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//')

# 対象ファイルかどうか判定
case "$file_path" in
  *implementation-plan*.md | *design-doc*.md) ;;
  *) exit 0 ;;
esac

# content を抽出（JSON文字列のエスケープを復元）
content=$(echo "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # tool_input.content or content
    c = data.get('tool_input', data).get('content', '')
    print(c)
except:
    sys.exit(1)
" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$content" ]; then
  # content取得失敗時はブロックしない
  exit 0
fi

missing=()

# --- Check 1: 状態マシンセクションヘッダー ---
if ! echo "$content" | grep -qE '^#{1,4}.*状態マシン'; then
  missing+=("状態マシン図セクション（見出し）")
fi

# --- Check 2: データフローセクションヘッダー ---
if ! echo "$content" | grep -qE '^#{1,4}.*データフロー'; then
  missing+=("データフロー図セクション（見出し）")
fi

# --- Check 3: 各セクション内に図表コンテンツがあるか ---
# ASCII罫線文字 or mermaidコードブロック
diagram_pattern='[┌┐└┘│─├┤┬┴┼▼▶▷▲◀◁→←↓↑►◄]|```mermaid'

# 状態マシンセクションの図チェック（ヘッダーが存在する場合のみ）
if echo "$content" | grep -qE '^#{1,4}.*状態マシン'; then
  # セクション開始から次の同レベル以上のヘッダーまでを抽出
  section=$(echo "$content" | sed -n '/^#\{1,4\}.*状態マシン/,/^#\{1,4\} /p' | tail -n +2)
  if ! echo "$section" | grep -qE "$diagram_pattern"; then
    missing+=("状態マシン図セクション内の図表（ASCII罫線 or mermaidブロック）")
  fi
fi

# データフローセクションの図チェック（ヘッダーが存在する場合のみ）
if echo "$content" | grep -qE '^#{1,4}.*データフロー'; then
  section=$(echo "$content" | sed -n '/^#\{1,4\}.*データフロー/,/^#\{1,4\} /p' | tail -n +2)
  if ! echo "$section" | grep -qE "$diagram_pattern"; then
    missing+=("データフロー図セクション内の図表（ASCII罫線 or mermaidブロック）")
  fi
fi

# 結果判定
if [ ${#missing[@]} -gt 0 ]; then
  cat >&2 <<'BLOCK'
=== WRITE BLOCKED: 図表が不足しています ===

このファイルは図表なしでは書き込めません。これはシステム制約です。
cat・echo等の別コマンドによる迂回も禁止されています。

【必須アクション】図表を含めた上で、再度 Write ツールで書き出してください。

必要な図表:
BLOCK
  for item in "${missing[@]}"; do
    echo "  - $item" >&2
  done
  cat >&2 <<'BLOCK'

最低限の要件:
  1. 「## 状態マシン図」見出し + mermaid or ASCII罫線による図
  2. 「## データフロー図」見出し + mermaid or ASCII罫線による図

図を省略する方法はありません。図を作成してください。
===
BLOCK
  exit 2
fi

exit 0
