#!/bin/bash
# 次のspec番号（3桁ゼロ埋め）を標準出力に出力する
set -eu

max=$(
  { ls -1d .specs/[0-9][0-9][0-9]-* .specs/archive/[0-9][0-9][0-9]-* 2>/dev/null || true; } \
    | sed 's|.*/\([0-9]\{3\}\)-.*|\1|' \
    | sort -rn \
    | head -1
)
max=${max#"${max%%[!0]*}"}  # 先頭のゼロを除去
max=${max:-0}

printf "%03d" $(( max + 1 ))
