#!/usr/bin/env bash
# ContextBar — Claude Code status line.
# Renders a /context-style colored block bar for the FIRST line of context usage.
#
# Format:  <cur>k <bar> (<max_bar%>|<actual_max%>)
#   cur        current total context tokens, in thousands (e.g. 82.7k)
#   bar        20 colored blocks spanning 0..MAX_BAR (fills full at MAX_BAR)
#   max_bar%   cur as a percentage of MAX_BAR     (the configurable indicator)
#   actual%    cur as a percentage of ACTUAL_MAX  (the model's real context limit)
#
# Config (environment, usually baked into settings.json by install.sh):
#   CONTEXTBAR_MAX_BAR     full-point of the bar, in tokens. Default min(150000, ACTUAL_MAX).
#   CONTEXTBAR_ACTUAL_MAX  override the model context limit, in tokens.
#   CONTEXTBAR_BLOCKS      number of blocks in the bar. Default 20.

input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
model_id=$(echo "$input"   | jq -r '.model.id // empty')

# ---- Resolve the model's actual context limit -------------------------------
# Lookup table by model.id substring. Override with CONTEXTBAR_ACTUAL_MAX.
resolve_actual_max() {
  case "$1" in
    *sonnet*) echo 1000000 ;;   # Sonnet 1M context
    *opus*)   echo 200000  ;;
    *haiku*)  echo 200000  ;;
    *)        echo 200000  ;;   # safe default
  esac
}
if [ -n "${CONTEXTBAR_ACTUAL_MAX:-}" ]; then
  ACTUAL_MAX=$CONTEXTBAR_ACTUAL_MAX
else
  ACTUAL_MAX=$(resolve_actual_max "$model_id")
fi

# ---- Resolve the configurable bar full-point --------------------------------
if [ -n "${CONTEXTBAR_MAX_BAR:-}" ]; then
  MAX_BAR=$CONTEXTBAR_MAX_BAR
else
  MAX_BAR=150000
  [ "$MAX_BAR" -gt "$ACTUAL_MAX" ] && MAX_BAR=$ACTUAL_MAX   # default min(150k, actual)
fi
# A bar wider than the real limit is meaningless; clamp.
[ "$MAX_BAR" -gt "$ACTUAL_MAX" ] && MAX_BAR=$ACTUAL_MAX
[ "$MAX_BAR" -lt 1 ] && MAX_BAR=1

BLOCKS=${CONTEXTBAR_BLOCKS:-20}
PER_BLOCK=$(( MAX_BAR / BLOCKS ))
[ "$PER_BLOCK" -lt 1 ] && PER_BLOCK=1

# ---- Approximate fixed overhead (matches /context category sizes) -----------
# Estimates — only the assistant's internal /context knows exact values.
SYS_PROMPT=8800
SYS_TOOLS=11800
AGENTS=700
MEMORY=100
SKILLS=3600

# ---- Pull most recent usage block from the transcript -----------------------
total=0
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  total=$(tac "$transcript" 2>/dev/null | grep -m1 '"usage"' | jq -r '
    (.message.usage // .usage // empty) |
    if . == null or . == "" then 0
    else
      ((.input_tokens // 0)
        + (.cache_creation_input_tokens // 0)
        + (.cache_read_input_tokens // 0))
    end
  ' 2>/dev/null)
fi
[ -z "$total" ] || [ "$total" = "null" ] && total=0

fixed=$(( SYS_PROMPT + SYS_TOOLS + AGENTS + MEMORY + SKILLS ))
messages=$(( total - fixed ))
[ $messages -lt 0 ] && messages=0

# ---- Colors (match /context) ------------------------------------------------
C_SYS_PROMPT=$'\033[38;2;136;136;136m'
C_SYS_TOOLS=$'\033[38;2;153;153;153m'
C_AGENTS=$'\033[38;2;177;185;249m'
C_MEMORY=$'\033[38;2;215;119;87m'
C_SKILLS=$'\033[38;2;255;193;7m'
C_MESSAGES=$'\033[38;2;130;125;189m'
C_FREE=$'\033[38;2;153;153;153m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
R=$'\033[0m'

FILLED='⛁'
HALF='⛀'
EMPTY='⛶'

# ---- Build the bar: walk segments, assign blocks by cumulative tokens -------
segments=(
  "$SYS_PROMPT|$C_SYS_PROMPT|$FILLED"
  "$SYS_TOOLS|$C_SYS_TOOLS|$FILLED"
  "$AGENTS|$C_AGENTS|$HALF"
  "$MEMORY|$C_MEMORY|$HALF"
  "$SKILLS|$C_SKILLS|$FILLED"
  "$messages|$C_MESSAGES|$FILLED"
)

bar=""
placed=0
acc=0
for seg in "${segments[@]}"; do
  IFS='|' read -r tk color sym <<< "$seg"
  acc=$(( acc + tk ))
  target=$(( acc / PER_BLOCK ))
  [ $target -gt $BLOCKS ] && target=$BLOCKS
  while [ $placed -lt $target ]; do
    bar+="${color}${sym}${R} "
    placed=$(( placed + 1 ))
  done
done
while [ $placed -lt $BLOCKS ]; do
  bar+="${C_FREE}${EMPTY}${R} "
  placed=$(( placed + 1 ))
done

# ---- Labels -----------------------------------------------------------------
k=$(awk -v t="$total" 'BEGIN { printf "%.1f", t/1000 }')
k=${k%.0}
max_pct=$(awk    -v t="$total" -v w="$MAX_BAR"    'BEGIN { printf "%.0f", t*100/w }')
actual_pct=$(awk -v t="$total" -v w="$ACTUAL_MAX" 'BEGIN { printf "%.0f", t*100/w }')

printf '%s%sk%s %s%s(%s%%|%s%%)%s\n' \
  "$BOLD" "$k" "$R" "$bar" "$DIM" "$max_pct" "$actual_pct" "$R"
