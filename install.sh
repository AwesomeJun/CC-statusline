#!/usr/bin/env bash
# ============================================================================
# Awesome CC Statusline — installer (macOS / Linux / Windows-GitBash)
# ----------------------------------------------------------------------------
# Usage:
#   ./install.sh                 # install
#   ./install.sh l               # install by abbreviation
#   ./install.sh large           # install by full name
#
# Sizes (smallest -> largest):
#   xsmall (xs)   2 lines, 10-block bars, minimal
#   small  (s)    2 lines, 10-block bars, labels + %
#   medium (m)    4 lines, classic layout
#   large  (l)    5 lines, 20-block bars, cost/time
#   xlarge (xl)   5 lines, 40-block bars, full detail (git ahead/behind, env)
#
# What it does:
#   1. ensures `jq` is installed (auto-installs via the system package manager)
#   2. copies the chosen size script to ~/.claude/awesome-statusline.sh
#   3. sets settings.json -> statusLine.command (existing settings preserved,
#      a timestamped backup is made first)
#
# Honors $CLAUDE_CONFIG_DIR (defaults to ~/.claude) so it is safe to test.
# ============================================================================
set -euo pipefail

# --- paths ------------------------------------------------------------------
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
DEST="$CLAUDE_DIR/awesome-statusline.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/scripts"
REPO_RAW="${AWESOME_STATUSLINE_RAW:-https://raw.githubusercontent.com/AwesomeJun/CC-statusline/main}"

# --- output helpers ---------------------------------------------------------
err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
info() { printf '\033[36m%s\033[0m\n' "$*"; }

# map abbreviation OR full name -> canonical full name
normalize_mode() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    xs|xsmall)  echo "xsmall" ;;
    s|small)    echo "small"  ;;
    m|medium)   echo "medium" ;;
    l|large)    echo "large"  ;;
    xl|xlarge)  echo "xlarge" ;;
    *) return 1 ;;
  esac
}

# --- dependency: jq (auto-install) ------------------------------------------
install_jq() {
  info "jq not found — attempting automatic install…"
  if   command -v brew    >/dev/null 2>&1; then brew install jq
  elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y jq
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y jq
  elif command -v yum     >/dev/null 2>&1; then sudo yum install -y jq
  elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --noconfirm jq
  elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y jq
  elif command -v apk     >/dev/null 2>&1; then sudo apk add jq
  elif command -v winget  >/dev/null 2>&1; then winget install --silent --accept-package-agreements --accept-source-agreements jqlang.jq
  elif command -v scoop   >/dev/null 2>&1; then scoop install jq
  elif command -v choco   >/dev/null 2>&1; then choco install jq -y
  else
    err "No supported package manager found. Please install jq manually:"
    err "  https://jqlang.github.io/jq/download/"
    return 1
  fi
}

ensure_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    install_jq || exit 1
    command -v jq >/dev/null 2>&1 || { err "jq install did not succeed."; exit 1; }
    ok "jq installed."
  fi
}

# --- pick size --------------------------------------------------------------
MODE="large"
if [ "$#" -ge 1 ]; then
  if ! MODE="$(normalize_mode "$1")"; then
    err "Unknown size: '$1'"
    err "Valid: xsmall|xs  small|s  medium|m  large|l  xlarge|xl"
    exit 1
  fi
fi

# --- run --------------------------------------------------------------------
ensure_jq
mkdir -p "$CLAUDE_DIR"

SRC="$SRC_DIR/awesome-statusline-$MODE.sh"
if [ -f "$SRC" ]; then
  cp "$SRC" "$DEST"
else
  info "Local scripts/ not found, downloading size '$MODE' from repo…"
  curl -fsSL "$REPO_RAW/scripts/awesome-statusline-$MODE.sh" -o "$DEST" \
    || { err "Download failed. Check network or \$AWESOME_STATUSLINE_RAW."; exit 1; }
fi
chmod +x "$DEST"

# Invoke via `bash <script>` (not the bare path) so the statusline runs
# identically on every platform. On Windows a bare `.sh` path is opened through
# its file association (`bash --login -i ...`), which spawns visible terminal
# windows and breaks stdin/stdout — calling bash explicitly avoids that.
STATUSLINE_JSON='{"type":"command","command":"bash ~/.claude/awesome-statusline.sh"}'
if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  jq --argjson sl "$STATUSLINE_JSON" '.statusLine = $sl' "$SETTINGS" > "$SETTINGS.tmp" \
    && mv "$SETTINGS.tmp" "$SETTINGS"
  info "Existing settings backed up to: $BACKUP"
else
  jq -n --argjson sl "$STATUSLINE_JSON" '{statusLine: $sl}' > "$SETTINGS"
fi

ok "Installed Awesome CC Statusline (size: $MODE)"
echo "  script:   $DEST"
echo "  settings: $SETTINGS  (statusLine set)"
echo
echo "Change size later:  ./install.sh <xsmall|small|medium|large|xlarge>  (or xs/s/m/l/xl)"
echo "Restart Claude Code (or reload) to see it."
