#!/bin/bash
# spec関連コマンドを自動許可し、未許可コマンドはAIに通知する
# PreToolUse: Bash
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# 前後の空白を除去
CMD=$(echo "$CMD" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

# 絶対パスを相対パスに正規化（AIがフルパスを使う場合の対策）
CWD=$(pwd)
CMD=$(echo "$CMD" | sed "s|${CWD}/\\.specs/|.specs/|g")

allow() {
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow"
    }
  }'
  exit 0
}

notify() {
  local msg="$1"
  jq -n --arg m "$msg" '{ systemMessage: $m }'
  exit 0
}

# ============================================================
# 1. spec番号取得コマンド
# ============================================================
if echo "$CMD" | grep -qE '^(next_num=.*)?ls -1d \.specs/\[0-9\].*sort -rn.*head -1'; then
  allow
fi

# printf "%03d" $((...)) 形式（spec番号のゼロ埋めインクリメント）
if [ "$CMD" = 'next_num=$(printf "%03d" $(( 10#${next_num:-0} + 1 )))' ]; then
  allow
fi

# ============================================================
# 2. .specs/ 配下のディレクトリ作成・ファイル操作
# ============================================================
if echo "$CMD" | grep -qE '^mkdir -p \.specs/'; then allow; fi
if echo "$CMD" | grep -qE '^touch \.specs/'; then allow; fi
if echo "$CMD" | grep -qE '^mkdir -p \.specs/\.guard && touch \.specs/\.guard/'; then allow; fi
if echo "$CMD" | grep -qE '^rm \.specs/[^/]+/PLANNING$'; then allow; fi
if echo "$CMD" | grep -qE '^rm \.specs/\.guard/'; then allow; fi
if echo "$CMD" | grep -qE '^echo .* > \.specs/[^/]+/PLANNING$'; then allow; fi

# ============================================================
# 3. cat heredoc/redirect → .specs/
# ============================================================
if echo "$CMD" | grep -qE '^cat >+ ?\.specs/'; then allow; fi

# ============================================================
# 4. 副作用のないコマンド（リダイレクトなし）
# ============================================================
if echo "$CMD" | grep -qE '^echo ' && ! echo "$CMD" | grep -qE '>'; then allow; fi

# ============================================================
# 5. レビューCLI (codex / copilot / claude) → .specs/ 限定
#    複合コマンド対応: すべてのリダイレクト先が .specs/ 内か検証
# ============================================================
if echo "$CMD" | grep -qE '(codex exec|copilot|claude (-p|--print))'; then
  # リダイレクト先を抽出（2>&1 等のFDリダイレクトは除外）
  redirect_targets=$(echo "$CMD" | grep -oE '[12]?>>? ?[^ ]+' | grep -v '>&' | sed 's/^[12]*>>* *//')

  if [ -n "$redirect_targets" ]; then
    all_in_specs=true
    while IFS= read -r target; do
      if ! echo "$target" | grep -qE '^\.specs/'; then
        all_in_specs=false
        break
      fi
    done <<< "$redirect_targets"

    if [ "$all_in_specs" = true ]; then
      allow
    fi
  fi
fi

# ============================================================
# 6. 通知: .specs/ 関連だが自動許可されなかったコマンド
#    systemMessage でAIにフィードバックする
#    許可済みパターン一覧を提示してコマンド修正を促す
# ============================================================
if echo "$CMD" | grep -qE '\.specs/'; then
  notify "[spec-guard] .specs/ に関連するBashコマンドが自動許可パターンに一致しませんでした。
コマンド: ${CMD:0:200}

自動許可されるパターン:
- ls -1d .specs/[0-9]... | sort -rn | head -1 (spec番号取得)
- next_num=\$(printf \"%03d\" \$(( 10#\${next_num:-0} + 1 ))) (spec番号インクリメント)
- mkdir -p .specs/...
- touch .specs/...
- rm .specs/{name}/PLANNING
- rm .specs/.guard/...
- echo ... > .specs/{name}/PLANNING
- cat > .specs/... (heredoc含む)
- echo ... (リダイレクトなし)
- codex exec ... > .specs/... (全リダイレクト先が .specs/ 内)
- copilot ... > .specs/... (全リダイレクト先が .specs/ 内)
- claude -p|--print ... > .specs/... (全リダイレクト先が .specs/ 内)

上記パターンに合わせてコマンドを書き直すか、ユーザーに許可を求めてください。"
fi

exit 0
