#!/usr/bin/env bash
# Matrix-themed statusline for Dart Scoring App
# Reads Claude Code JSON from stdin.

input=$(cat)

# ANSI codes
BOLD_GREEN='\x1b[1;32m'
DIM_GREEN='\x1b[2;32m'
RESET='\x1b[0m'

# --- Segments ---

DART='🎯'

# Git branch + dirty indicator
REPO_DIR=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR/.git" ]; then
  BRANCH=$(git --no-optional-locks -C "$REPO_DIR" symbolic-ref --short HEAD 2>/dev/null \
            || git --no-optional-locks -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null)
  DIRTY=$(git --no-optional-locks -C "$REPO_DIR" status --porcelain 2>/dev/null | head -c1)
  if [ -n "$DIRTY" ]; then BRANCH_DISPLAY="${BRANCH}*"; else BRANCH_DISPLAY="${BRANCH}"; fi
else
  BRANCH_DISPLAY="?"
fi

# Model display name
MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "?"')

# 7-day rolling window — build a progress bar of REMAINING tokens
USED=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

build_bar() {
  # $1 = remaining percent (integer 0-100). 10-char bar.
  local remaining="$1"
  local filled=$(( remaining / 10 ))
  if [ "$filled" -gt 10 ]; then filled=10; fi
  if [ "$filled" -lt 0 ]; then filled=0; fi
  local empty=$(( 10 - filled ))
  local bar=""
  local i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i+1)); done
  i=0
  while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i+1)); done
  printf '%s' "$bar"
}

if [ -n "$USED" ] && [ "$USED" != "null" ]; then
  USED_INT=$(awk -v u="$USED" 'BEGIN { printf "%d", u + 0.5 }')
  if [ "$USED_INT" -lt 0 ]; then USED_INT=0; fi
  if [ "$USED_INT" -gt 100 ]; then USED_INT=100; fi
  BAR=$(build_bar "$USED_INT")
  WEEK_LABEL="7d ${BAR} ${USED_INT}%"
else
  CCUSAGE_OUT=$(npx --yes ccusage statusline 2>/dev/null | head -1)
  if [ -n "$CCUSAGE_OUT" ]; then
    WEEK_LABEL="$CCUSAGE_OUT"
  else
    WEEK_LABEL="7d ░░░░░░░░░░ ?%"
  fi
fi

# Matrix decoration
RAIN_END='\xe2\x96\x93'   # ▓
SEP_CHAR='\xe2\x94\x82'   # │
SEP=$(printf "${DIM_GREEN}${SEP_CHAR}${RESET}")

printf "${BOLD_GREEN}${DART} ${BRANCH_DISPLAY}${RESET}"
printf " ${SEP} "
printf "${BOLD_GREEN}${MODEL}${RESET}"
printf " ${SEP} "
printf "${BOLD_GREEN}%s${RESET}" "$WEEK_LABEL"
