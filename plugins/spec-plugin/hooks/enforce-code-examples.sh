#!/bin/bash
# implementation-plan にコードブロック（型定義・使用例等）が含まれているか検証するフック
# PostToolUse: Write, Edit
#
# 対象: *implementation-plan*.md (コード必須)
# 情報表示のみ: *design-doc*.md, *hearing-notes*.md, *exploration-report*.md, *tasks*.md
# 書き込み後にファイルを読み、不足があれば標準出力でリマインドする

input=$(cat)

# file_path を抽出（tool_input のみを対象にする）
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# --- implementation-plan のみ検証対象 ---
case "$file_path" in
  *implementation-plan*.md) ;;
  *) exit 0 ;;
esac

# --- ここ以降は implementation-plan のみ ---

# ファイルが存在しなければスキップ
[ -f "$file_path" ] || exit 0

content=$(cat "$file_path")

missing=()

# --- Check 1: コードブロックの存在 ---
# ``` で囲まれた区間に実質的なコード内容があるか
has_code_block=$(echo "$content" | awk '
  /^```/ { if (in_block) { if (has_content) found=1; in_block=0; has_content=0 } else { in_block=1 } next }
  in_block && /[^ \t]/ { has_content=1 }
  END { print (found ? "yes" : "no") }
')

if [ "$has_code_block" != "yes" ]; then
  missing+=("コードブロック（\`\`\` で囲まれたコード例）が見つかりません")
fi

# --- Check 2: コード関連セクション内のコードブロック ---
# "主要コンポーネント" / "変更案" / "使用例" セクション内にコードがあるか
code_section_pattern='^#{1,4}.*(主要コンポーネント|変更案|使用例)'

if echo "$content" | grep -qE "$code_section_pattern"; then
  has_section_code="no"
  for section_name in "主要コンポーネント" "変更案" "使用例"; do
    if echo "$content" | grep -qE "^#{1,4}.*${section_name}"; then
      section=$(echo "$content" | sed -n "/^#\{1,4\}.*${section_name}/,/^#\{1,4\} /p" | tail -n +2)
      if echo "$section" | grep -q '```'; then
        has_section_code="yes"
        break
      fi
    fi
  done
  if [ "$has_section_code" != "yes" ]; then
    missing+=("コード関連セクション（主要コンポーネントの設計 / 変更案 / 使用例）内にコードブロックがありません")
  fi
fi

# --- 結果判定（exit 2 + stderr でモデルにフィードバックする）---
if [ ${#missing[@]} -gt 0 ]; then
  {
    echo "=== コードブロックが不足しています: ${file_path##*/} ==="
    for item in "${missing[@]}"; do
      echo "  - $item"
    done
    echo "型定義・実装例・使用例のコードブロックを追加してファイルを更新してください。"
  } >&2
  exit 2
fi

exit 0
