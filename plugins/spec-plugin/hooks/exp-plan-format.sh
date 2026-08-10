#!/bin/bash
# 【実験】spec-driven-dev-exp 用のフォーマット検証フック
# PostToolUse: Write, Edit
#
# サブエージェント（plan-format-checker 等）によるフォーマットチェックの代替として、
# implementation-plan / tasks / test-cases の形式を機械検証し、
# 不備があれば exit 2 + stderr でモデルにフィードバックする。
#
# 作動条件: 書き込み先の spec フォルダに EXPERIMENT マーカーファイルが存在すること
# （安定版スキルの spec には干渉しない）
#
# 検証項目:
#   implementation-plan*.md:
#     - 必須セクション（概要 / 背景 / 設計判断 / システム図 / 変更案 / 検証計画 / Definition of Done）
#     - テンプレートプレースホルダ（{日本語…}）の残留
#     - [NEW] / [MODIFY] エントリ直後のコードブロック有無
#     - [NEW] / [MODIFY] / [DELETE] エントリの **理由**: の有無
#     - コードブロック内の実装省略コメント（... / 省略 / TODO 等）
#   tasks*.md:
#     - 未完了タスク（行頭 □）の存在
#     - テンプレートプレースホルダの残留
#   test-cases*.html（DATA スクリプト部分のみ検証）:
#     - テンプレートプレースホルダの残留
#     - ケースID（id: "TC-xx"）の重複
#     - cat / prio の不正値
#     - trace の欠落・GAP 残り（GAP は正直な申告なので情報表示のみ）
# ※ 図表は enforce-diagrams.sh、コード例の実質性は enforce-code-examples.sh が担当

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

case "$file_path" in
  *implementation-plan*.md | *tasks*.md | *test-cases*.html) ;;
  *) exit 0 ;;
esac

[ -f "$file_path" ] || exit 0

# EXPERIMENT マーカーがある spec フォルダのみ対象
dir=$(dirname "$file_path")
[ -f "${dir}/EXPERIMENT" ] || exit 0

content=$(cat "$file_path")
missing=()

# test-cases.html はレンダラが固定部のため、DATA スクリプト部分だけを検証対象にする
scan_content=$content
case "$file_path" in
  *test-cases*.html)
    scan_content=$(echo "$content" | sed '/===== 以下 レンダラは固定/,$d')
    ;;
esac

# テンプレートプレースホルダの残留（{…} 内に日本語を含むもの）
# 引用符を含む波括弧は実コード（オブジェクトリテラル等）の可能性が高いため除外
placeholders=$(echo "$scan_content" | grep -noE "\\{[^{}\"']*[ぁ-んァ-ヶ一-龠][^{}\"']*\\}" | head -5)
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
    # ##### は before / after 用のサブ見出しなのでエントリの区切りとして扱わない
    entries_without_code=$(echo "$content" | awk '
      /^#### \[(NEW|MODIFY)\]/ {
        if (entry != "" && !has_code) print entry
        entry = $0; has_code = 0; next
      }
      /^#/ && !/^#####/ {
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

    # [NEW] / [MODIFY] / [DELETE] エントリに **理由**: があるか
    entries_without_reason=$(echo "$content" | awk '
      /^#### \[(NEW|MODIFY|DELETE)\]/ {
        if (entry != "" && !has_reason) print entry
        entry = $0; has_reason = 0; next
      }
      /^#/ && !/^#####/ {
        if (entry != "" && !has_reason) print entry
        entry = ""
      }
      /\*\*理由\*\*/ { if (entry != "") has_reason = 1 }
      END { if (entry != "" && !has_reason) print entry }
    ')
    if [ -n "$entries_without_reason" ]; then
      missing+=("**理由**: （なぜこの変更をするか）のない変更案エントリ:")
      while IFS= read -r line; do
        missing+=("    ${line}")
      done <<< "$entries_without_reason"
    fi

    # コードブロック内の実装省略コメント（... だけの行、省略/中略/TODO 等）
    elided=$(echo "$content" | awk '
      /^```/ { in_block = !in_block; next }
      in_block {
        if ($0 ~ /^[[:space:]]*(\/\/|#|\/\*|\*|--)?[[:space:]]*(\.\.\.|…)[[:space:]]*(\*\/)?[[:space:]]*$/ ||
            $0 ~ /(\/\/|#|\/\*|\*|--).*(省略|中略|以下略|割愛|TODO|FIXME)/)
          print "L" NR ": " $0
      }
    ' | head -5)
    if [ -n "$elided" ]; then
      missing+=("コードブロック内で実装がコメントで省略されています（実装骨格を書く）:")
      while IFS= read -r line; do
        missing+=("    ${line}")
      done <<< "$elided"
    fi
    ;;
  *tasks*.md)
    if ! echo "$content" | grep -qE '^[[:space:]]*-?[[:space:]]*[□■]'; then
      missing+=("タスク行（行頭 □ / ■）が1つもありません")
    fi
    ;;
  *test-cases*.html)
    # ケースIDの重複
    dup_ids=$(echo "$scan_content" | grep -oE 'id: "TC-[^"]+"' | sort | uniq -d)
    if [ -n "$dup_ids" ]; then
      missing+=("ケースIDが重複しています:")
      while IFS= read -r line; do
        missing+=("    ${line}")
      done <<< "$dup_ids"
    fi

    # cat / prio の不正値
    bad_cat=$(echo "$scan_content" | grep -oE 'cat: "[^"]+"' | grep -vE '"(normal|boundary|error|edge)"' | sort -u)
    [ -n "$bad_cat" ] && missing+=("cat の不正値: $(echo "$bad_cat" | tr '\n' ' ')（normal/boundary/error/edge のみ）")
    bad_prio=$(echo "$scan_content" | grep -oE 'prio: "[^"]+"' | grep -vE '"(high|med|low)"' | sort -u)
    [ -n "$bad_prio" ] && missing+=("prio の不正値: $(echo "$bad_prio" | tr '\n' ' ')（high/med/low のみ）")

    # trace の存在
    if ! echo "$scan_content" | grep -q 'trace:'; then
      missing+=("trace（要件との対応表）がありません。requirements の UC/要件と対応付けてください")
    fi

    # requirements のユースケースが trace[] に現れているか（UC の丸ごとの漏れを検出）
    # requirements.md は □→■ をユーザーが解消済みの、人間の確認が入った唯一の文書なので
    # 自己申告物どうしの照合にならない
    req_file="${dir}/requirements.md"
    if [ -f "$req_file" ]; then
      untraced=""
      while IFS= read -r uc; do
        [ -n "$uc" ] || continue
        echo "$scan_content" | grep -q "\"${uc}\"" || untraced="${untraced}${uc} "
      done < <(grep -oE '^#{2,4}[[:space:]]+UC-[0-9]+' "$req_file" | grep -oE 'UC-[0-9]+' | sort -u)
      if [ -n "$untraced" ]; then
        missing+=("requirements のユースケースが trace[] にありません: ${untraced}")
        missing+=("    未カバーなら status: \"gap\" で明示的に申告してください（黙って落とさない）")
      fi
    fi

    # 紐づくケースが1件だけの UC（ハッピーパス1件で ok になっている疑い）— 情報表示のみ
    single_tc=$(echo "$scan_content" | awk '
      /id: "UC-[0-9]+"/ && /tcs: \[/ {
        if (match($0, /id: "UC-[0-9]+"/)) uc = substr($0, RSTART + 5, RLENGTH - 6)
        if (match($0, /tcs: \[[^]]*\]/)) {
          arr = substr($0, RSTART + 6, RLENGTH - 7)
          if (arr != "" && split(arr, parts, ",") == 1) print uc
        }
      }' | sort -u | tr '\n' ' ')
    if [ -n "$single_tc" ]; then
      echo ""
      echo "【exp】test-cases: 対応ケースが1件だけのユースケース: ${single_tc}"
      echo "  正常系1件のみになっていないか確認してください（失敗経路・分岐ごとのケースが要るかもしれません）。"
    fi

    # GAP は正直な申告なので情報表示のみ（ブロック・修正要求はしない）
    gap_count=$(echo "$scan_content" | grep -c 'status: "gap"')
    if [ "$gap_count" -gt 0 ]; then
      echo ""
      echo "【exp】test-cases: 対応ケースのない要件（GAP）が ${gap_count} 件あります。意図的な未カバーか確認してください。"
    fi
    ;;
esac

# exit 2 + stderr でモデルにフィードバックする
if [ ${#missing[@]} -gt 0 ]; then
  {
    echo "=== 【exp】フォーマット検証: ${file_path##*/} ==="
    for item in "${missing[@]}"; do
      echo "  - $item"
    done
    echo "テンプレート（assets/templates/）の構成に合わせて修正してから次のステップに進んでください。"
  } >&2
  exit 2
fi

exit 0
