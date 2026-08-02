#!/bin/bash
# implementation-plan / design-doc に状態マシン図・データフロー図が含まれているか検証するフック
# PostToolUse: Write, Edit
#
# 対象: *implementation-plan*.md, *design-doc*.md
# 書き込み後にファイルを読み、不足があれば標準出力でリマインドする

input=$(cat)

# file_path を抽出（tool_input のみを対象にする）
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# 対象ファイルかどうか判定
case "$file_path" in
  *implementation-plan*.md | *design-doc*.md) ;;
  *) exit 0 ;;
esac

# ファイルが存在しなければスキップ
[ -f "$file_path" ] || exit 0

content=$(cat "$file_path")

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

# 結果判定（exit 2 + stderr でモデルにフィードバックする）
if [ ${#missing[@]} -gt 0 ]; then
  {
    echo "=== 図表が不足しています: ${file_path##*/} ==="
    for item in "${missing[@]}"; do
      echo "  - $item"
    done
    echo "「## 状態マシン図」「## データフロー図」の見出し + ASCII罫線図（優先）or mermaid を追加してください。"
  } >&2
  exit 2
fi

exit 0
