#!/bin/bash
# 【実験】spec-driven-dev-exp 用のフォーマット検証フック
# PostToolUse: Write, Edit
#
# サブエージェント（plan-format-checker 等）によるフォーマットチェックの代替として、
# implementation-plan / tasks の形式を機械検証してリマインドする（ブロックはしない）。
#
# 作動条件: 書き込み先の spec フォルダに EXPERIMENT マーカーファイルが存在すること
# （安定版スキルの spec には干渉しない）
#
# 検証項目:
#   implementation-plan*.md:
#     - 必須セクション（概要 / 背景 / 設計判断 / システム図 / 変更案 / 検証計画 / Definition of Done）
#     - テンプレートプレースホルダ（{日本語…}）の残留
#     - [NEW] / [MODIFY] エントリ直後のコードブロック有無
#   tasks*.md:
#     - 未完了タスク（行頭 □）の存在
#     - テンプレートプレースホルダの残留
# ※ 図表は enforce-diagrams.sh、コード例の実質性は enforce-code-examples.sh が担当

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

case "$file_path" in
  *implementation-plan*.md | *tasks*.md) ;;
  *) exit 0 ;;
esac

[ -f "$file_path" ] || exit 0

# EXPERIMENT マーカーがある spec フォルダのみ対象
dir=$(dirname "$file_path")
[ -f "${dir}/EXPERIMENT" ] || exit 0

content=$(cat "$file_path")
missing=()

# テンプレートプレースホルダの残留（{…} 内に日本語を含むもの）
placeholders=$(echo "$content" | grep -noE '\{[^{}]*[ぁ-んァ-ヶ一-龠][^{}]*\}' | head -5)
if [ -n "$placeholders" ]; then
  missing+=("テンプレートプレースホルダが残っています:")
  while IFS= read -r line; do
    missing+=("    L${line}")
  done <<< "$placeholders"
fi

case "$file_path" in
  *implementation-plan*.md)
    # 必須セクション
    for sec in "概要" "背景" "設計判断" "システム図" "変更案" "検証計画" "Definition of Done"; do
      if ! echo "$content" | grep -qE "^#{1,4} .*${sec}"; then
        missing+=("必須セクション「## ${sec}」がありません")
      fi
    done

    # [NEW] / [MODIFY] エントリの直後（次の見出しまで）にコードブロックがあるか
    entries_without_code=$(echo "$content" | awk '
      /^#### \[(NEW|MODIFY)\]/ {
        if (entry != "" && !has_code) print entry
        entry = $0; has_code = 0; next
      }
      /^#/ {
        if (entry != "" && !has_code) print entry
        entry = ""
      }
      /^```/ { if (entry != "") has_code = 1 }
      END { if (entry != "" && !has_code) print entry }
    ')
    if [ -n "$entries_without_code" ]; then
      missing+=("コードブロック（型定義・シグネチャ・before/after）のない変更案エントリ:")
      while IFS= read -r line; do
        missing+=("    ${line}")
      done <<< "$entries_without_code"
    fi
    ;;
  *tasks*.md)
    if ! echo "$content" | grep -qE '^[[:space:]]*-?[[:space:]]*[□■]'; then
      missing+=("タスク行（行頭 □ / ■）が1つもありません")
    fi
    ;;
esac

if [ ${#missing[@]} -gt 0 ]; then
  echo ""
  echo "=== 【exp】フォーマット検証: ${file_path##*/} ==="
  echo ""
  for item in "${missing[@]}"; do
    echo "  - $item"
  done
  echo ""
  echo "テンプレート（assets/templates/）の構成に合わせて修正してから次のステップに進んでください。"
  echo "==="
fi

exit 0
