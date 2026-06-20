#!/bin/bash
set -euo pipefail

# requirements.md の「未解決の確認事項」に未確認項目（行頭 □）が残ったまま
# implementation-plan への書き込み（＝計画フェーズへの進行）をブロックする。
# コードベースを調べても解決できない分岐をユーザーに確認させるためのゲート。
#
# PreToolUse: Write, Edit, MultiEdit
# exit 0 = 許可, exit 2 = ブロック

SPEC_BASE=".plugin-workspace/.specs"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

[ -z "$SESSION_ID" ] && exit 0

GUARD_FILE="${SPEC_BASE}/.guard/${SESSION_ID}"

# ── 計画フェーズ中（ガードファイル存在時）のみ作動 ──
# archive 内や計画外の implementation-plan には干渉しない
[ ! -f "$GUARD_FILE" ] && exit 0

# ── Write / Edit / MultiEdit 以外は対象外 ──
case "$TOOL" in
  Write | Edit | MultiEdit) ;;
  *) exit 0 ;;
esac

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0

# ── implementation-plan への書き込みのみ判定対象 ──
case "$FILE" in
  *implementation-plan*) ;;
  *) exit 0 ;;
esac

# ── 同ディレクトリの requirements ファイルを探す（.md=通常スキル / .html=HTMLスキル）──
DIR=$(dirname "$FILE")
REQ_FILE=""
for ext in md html; do
  if [ -f "${DIR}/requirements.${ext}" ]; then
    REQ_FILE="${DIR}/requirements.${ext}"
    break
  fi
done

# ── requirements が無い → 先に作って確定させる ──
if [ -z "$REQ_FILE" ]; then
  cat >&2 <<EOF
【requirements フェーズ】implementation-plan の作成はまだできません。
先に ${DIR}/requirements.md（HTML出力時は requirements.html）を作成し、
ユースケース・要件・制約と「未解決の確認事項」を確定させてください
（research → requirements → plan の順）。
EOF
  exit 2
fi

# ── 「未解決の確認事項」セクション内に未確認項目が残るか確認 ──
# .md  : セクションは「# 見出し」、未確認は行頭 □（凡例は引用 "> " ゆえ行頭 □ にならず誤検出しない）
# .html: セクションは <h*>...未解決の確認事項...</h*>、未確認は <span class="checkbox">
#        （解決済みは class="checkbox done"、凡例の &lt;span ...&gt; は < 始まりでないので誤検出しない）
content=$(cat "$REQ_FILE")
case "$REQ_FILE" in
  *.html)
    section=$(echo "$content" | sed -n '/未解決の確認事項/,/<h[1-4][ >]/p')
    # 実体の未チェック項目だけにマッチ（解決済みは class="checkbox done"、
    # 凡例内のエスケープ表記 &lt;span ...&gt; は < で始まらないので誤検出しない）
    unresolved_pattern='<span class="checkbox">'
    ;;
  *)
    section=$(echo "$content" | sed -n '/^#\{1,4\}.*未解決の確認事項/,/^#\{1,4\} /p')
    unresolved_pattern='^[[:space:]]*□'
    ;;
esac

if echo "$section" | grep -qE "$unresolved_pattern"; then
  cat >&2 <<EOF
【requirements フェーズ】未解決の確認事項が残っています: ${REQ_FILE}
コードベースを調べても解決できない分岐は、AskUserQuestion でユーザーに確認し、
回答を requirements に反映（.md は □ → ■ / .html は checkbox に done 付与、
または「なし」）してから implementation-plan に進んでください。
EOF
  exit 2
fi

exit 0
