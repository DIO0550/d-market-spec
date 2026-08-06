#!/bin/bash
# 実装フェーズの計画内容・タスク進捗を、紐づく GitHub Issue のコメントへ自動反映するフック
# PostToolUse: Write, Edit, MultiEdit
#
# 動作条件（1つでも満たさなければ何もせず exit 0）:
#   1. 書き込み先が .plugin-workspace/.specs/{nnn}-*/ の tasks / implementation-plan
#   2. .plugin-workspace/.specs/.config.yml の issue-update が hook
#   3. 自セッションのガードファイルが存在しない（= 計画フェーズではない）
#   4. implementation-plan に `**関連Issue**: #123` がある
#   5. gh CLI が利用可能で、カレントリポジトリに対する API 呼び出しが成功する
#
# spec フォルダごとに1件のコメント（先頭にマーカー）を作成し、以降は同じコメントを編集する。
# 本文が前回と同じ場合は API を呼ばない（状態は .plugin-workspace/.specs/.issue-sync/ に保存）。

set -uo pipefail

SPEC_BASE=".plugin-workspace/.specs"
CONFIG_FILE="${SPEC_BASE}/.config.yml"
STATE_DIR="${SPEC_BASE}/.issue-sync"
MAX_TASK_LINES=200
MAX_FILE_LINES=50

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')

[ -n "$file_path" ] || exit 0

# ── 1. 対象ファイル判定 ──
echo "$file_path" \
  | grep -qE '\.plugin-workspace/\.specs/[0-9]{3}-[^/]+/(tasks|implementation-plan)\.' || exit 0

spec_name=$(echo "$file_path" | sed -E 's|^.*\.plugin-workspace/\.specs/([0-9]{3}-[^/]+)/.*$|\1|')
spec_dir="${SPEC_BASE}/${spec_name}"
[ -d "$spec_dir" ] || exit 0

# ── 2. issue-update 設定の確認 ──
[ -f "$CONFIG_FILE" ] || exit 0
mode=$(sed -nE 's/^issue-update:[[:space:]]*"?([A-Za-z-]+)"?[[:space:]]*(#.*)?$/\1/p' "$CONFIG_FILE" | head -1)
[ "$mode" = "hook" ] || exit 0

# ── 3. 計画フェーズ中はスキップ（Issue へ出すのは実装フェーズの内容） ──
if [ -n "$session_id" ] && [ -f "${SPEC_BASE}/.guard/${session_id}" ]; then
  exit 0
fi

# ── 4. 関連Issue番号の抽出 ──
plan_file=$(ls -1 "${spec_dir}"/implementation-plan.* 2>/dev/null | head -1)
[ -n "$plan_file" ] || exit 0

issue_num=$(grep -oE '関連Issue[^0-9]*#[0-9]+' "$plan_file" 2>/dev/null | grep -oE '[0-9]+$' | head -1)
[ -n "$issue_num" ] || exit 0

# ── 5. gh CLI の存在確認 ──
if ! command -v gh >/dev/null 2>&1; then
  echo "[issue-sync] gh CLI が見つからないため Issue #${issue_num} への追記をスキップしました"
  exit 0
fi

# ============================================================
# 本文の組み立て
# ============================================================
marker="<!-- spec-plugin:issue-update:${spec_name}:progress -->"

plan_title=$(grep -m1 -E '^#[[:space:]]+' "$plan_file" 2>/dev/null | sed -E 's/^#[[:space:]]+//')

# 変更対象ファイル（`#### [NEW] \`path\`` 形式の見出しから抽出）
changed_files=$(grep -hE '^#{2,6}[[:space:]]*\[(NEW|MODIFY|DELETE)\]' "$plan_file" 2>/dev/null \
  | sed -E 's/^#+[[:space:]]*//' | tr -d '`' | head -n "$MAX_FILE_LINES")

# タスク一覧（□ / ■ → GitHub のチェックリスト形式。HTMLコメント内の記述例は除外）
tasks_file=$(ls -1 "${spec_dir}"/tasks.* 2>/dev/null | head -1)
task_lines=""
if [ -n "$tasks_file" ]; then
  task_lines=$(awk '
    BEGIN { skip = 0 }
    {
      if (index($0, "<!--") > 0) skip = 1
      if (skip == 0) {
        line = $0
        is_done = (index(line, "■") > 0)
        is_todo = (index(line, "□") > 0)
        if (is_done || is_todo) {
          match(line, /^[ \t]*/)
          indent = substr(line, 1, RLENGTH)
          body = substr(line, RLENGTH + 1)
          sub(/^[-*][ \t]*/, "", body)
          sub(/^■[ \t]*/, "", body)
          sub(/^□[ \t]*/, "", body)
          printf "%s- [%s] %s\n", indent, (is_done ? "x" : " "), body
        }
      }
      if (index($0, "-->") > 0) skip = 0
    }
  ' "$tasks_file")
fi

total=$(printf '%s\n' "$task_lines" | grep -cE '^[[:space:]]*- \[')
completed=$(printf '%s\n' "$task_lines" | grep -cE '^[[:space:]]*- \[x\]')

progress="タスク未検出"
if [ "$total" -gt 0 ]; then
  progress="${completed}/${total} ($((completed * 100 / total))%)"
fi

truncated=""
if [ "$total" -gt "$MAX_TASK_LINES" ]; then
  task_lines=$(printf '%s\n' "$task_lines" | head -n "$MAX_TASK_LINES")
  truncated="…（残り $((total - MAX_TASK_LINES)) 件は ${spec_dir}/ のタスクリストを参照）"
fi

heading="## 🔨 実装進捗: ${spec_name}"
[ -n "$plan_title" ] && heading="${heading} — ${plan_title}"

body=$(
  printf '%s\n\n' "$marker"
  printf '%s\n\n' "$heading"
  printf '**進捗**: %s\n' "$progress"
  if [ -n "$changed_files" ]; then
    printf '\n### 変更対象ファイル\n\n'
    printf '%s\n' "$changed_files" | sed -E 's/^/- /'
  fi
  if [ -n "$task_lines" ]; then
    printf '\n### タスク\n\n'
    printf '%s\n' "$task_lines"
    [ -n "$truncated" ] && printf '%s\n' "$truncated"
  fi
  printf '\n---\n'
  printf '<sub>spec-plugin が `%s/` の更新を検知して自動更新しています（`issue-update: hook`）。</sub>\n' "$spec_dir"
)

# ============================================================
# 前回と同じ内容なら API を呼ばない
# ============================================================
mkdir -p "$STATE_DIR" 2>/dev/null
state_file="${STATE_DIR}/${spec_name}.state"
id_file="${STATE_DIR}/${spec_name}.comment"

hash=$(printf '%s' "$body" | cksum | awk '{print $1 "-" $2}')
if [ -f "$state_file" ] && [ "$(cat "$state_file" 2>/dev/null)" = "$hash" ]; then
  exit 0
fi

# ============================================================
# コメントの作成 / 更新
# ============================================================
payload=$(jq -n --arg body "$body" '{body: $body}')

comment_id=""
[ -f "$id_file" ] && comment_id=$(cat "$id_file" 2>/dev/null)

# 既知のコメントIDがなければマーカーで既存コメントを探す
if [ -z "$comment_id" ]; then
  comment_id=$(gh api "repos/{owner}/{repo}/issues/${issue_num}/comments" --paginate \
    --jq "[.[] | select(.body | contains(\"${marker}\")) | .id] | last // empty" 2>/dev/null | tail -1)
fi

updated=0
if [ -n "$comment_id" ]; then
  if printf '%s' "$payload" \
    | gh api -X PATCH "repos/{owner}/{repo}/issues/comments/${comment_id}" --input - >/dev/null 2>&1; then
    updated=1
  else
    # コメントが削除された等で編集に失敗した場合は新規作成にフォールバック
    comment_id=""
  fi
fi

if [ "$updated" -eq 0 ]; then
  comment_id=$(printf '%s' "$payload" \
    | gh api "repos/{owner}/{repo}/issues/${issue_num}/comments" --input - --jq '.id' 2>/dev/null)
  if [ -n "$comment_id" ]; then
    updated=1
  fi
fi

if [ "$updated" -eq 1 ]; then
  printf '%s' "$comment_id" > "$id_file"
  printf '%s' "$hash" > "$state_file"
  echo "[issue-sync] Issue #${issue_num} の進捗コメントを更新しました（${spec_name}: ${progress}）"
else
  echo "[issue-sync] Issue #${issue_num} への追記に失敗しました（gh の認証状態・リポジトリ設定を確認してください）"
fi

exit 0
