#!/usr/bin/env bash
# ContextBar installer.
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/VocanicZ/ContextBar/main/install.sh | bash
#
# With options:
#   curl -fsSL .../install.sh | bash -s -- --scope user --max-bar 150000
#
# Flags:
#   --scope    project | user | system   where to write the statusLine setting
#   --max-bar  N                          bar full-point in tokens (the indicator)
#   --actual-max N                        override the model context limit in tokens
#   --help
#
# If --scope / --max-bar are omitted and a terminal is attached, you'll be prompted.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/VocanicZ/ContextBar/main"
INSTALL_DIR="$HOME/.claude/contextbar"
SCRIPT_DST="$INSTALL_DIR/statusline.sh"

SCOPE=""
MAX_BAR=""
ACTUAL_MAX=""

die() { echo "contextbar: $*" >&2; exit 1; }

# ---- Parse flags ------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --scope)      SCOPE="${2:-}"; shift 2 ;;
    --max-bar)    MAX_BAR="${2:-}"; shift 2 ;;
    --actual-max) ACTUAL_MAX="${2:-}"; shift 2 ;;
    --help|-h)
      sed -n '2,20p' "$0" 2>/dev/null || true
      exit 0 ;;
    *) die "unknown flag: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required (apt install jq / brew install jq)"

# ---- Interactive prompts (only if a TTY is reachable) -----------------------
TTY=""
[ -e /dev/tty ] && TTY=/dev/tty
ask() { # prompt default -> echoes answer
  local prompt="$1" def="$2" ans=""
  if [ -n "$TTY" ]; then
    printf '%s [%s]: ' "$prompt" "$def" > "$TTY"
    IFS= read -r ans < "$TTY" || ans=""
  fi
  echo "${ans:-$def}"
}

if [ -z "$SCOPE" ]; then
  SCOPE=$(ask "Scope (project/user/system)" "user")
fi
case "$SCOPE" in
  project) SETTINGS="$PWD/.claude/settings.json" ;;
  user)    SETTINGS="$HOME/.claude/settings.json" ;;
  system)  SETTINGS="/etc/claude-code/managed-settings.json" ;;
  *) die "invalid scope: $SCOPE (expected project|user|system)" ;;
esac

if [ -z "$MAX_BAR" ]; then
  MAX_BAR=$(ask "Max bar full-point in tokens (the indicator)" "150000")
fi
case "$MAX_BAR" in *[!0-9]*|'') die "--max-bar must be a positive integer" ;; esac

# ---- Place statusline.sh ----------------------------------------------------
mkdir -p "$INSTALL_DIR"
SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/statusline.sh" ]; then
  cp "$SELF_DIR/statusline.sh" "$SCRIPT_DST"            # installing from a clone
else
  curl -fsSL "$REPO_RAW/statusline.sh" -o "$SCRIPT_DST"  # installing via curl|bash
fi
chmod +x "$SCRIPT_DST"

# ---- Build the statusLine command (max_bar baked in per scope) --------------
CMD="CONTEXTBAR_MAX_BAR=$MAX_BAR"
[ -n "$ACTUAL_MAX" ] && CMD="$CMD CONTEXTBAR_ACTUAL_MAX=$ACTUAL_MAX"
CMD="$CMD bash $SCRIPT_DST"

# ---- Patch the chosen settings.json -----------------------------------------
SUDO=""
if [ "$SCOPE" = "system" ] && [ ! -w "$(dirname "$SETTINGS")" ]; then
  SUDO="sudo"
fi
$SUDO mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' | $SUDO tee "$SETTINGS" >/dev/null

TMP="$(mktemp)"
$SUDO cat "$SETTINGS" | jq \
  --arg cmd "$CMD" \
  '.statusLine = {type:"command", command:$cmd, refreshInterval:5}' > "$TMP"
$SUDO cp "$TMP" "$SETTINGS"
rm -f "$TMP"

echo "✓ ContextBar installed"
echo "  script:   $SCRIPT_DST"
echo "  settings: $SETTINGS  (scope: $SCOPE)"
echo "  max_bar:  $MAX_BAR tokens${ACTUAL_MAX:+   actual_max override: $ACTUAL_MAX}"
echo "  Restart Claude Code (or wait for refresh) to see the bar."
