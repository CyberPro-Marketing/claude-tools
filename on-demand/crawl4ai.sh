#!/usr/bin/env bash
# Installs Crawl4AI (github.com/unclecode/crawl4ai, Apache-2.0) for one session:
# a crawler that turns whole websites into clean Markdown an AI can read.
# On demand, not at session start: it takes ~40 s with uv (~70 s with pip).
# The crawl-site skill (tools/crawl-site.sh) tells Claude to run this.
#
# Playwright is pinned to 1.56.0 because that release drives Chromium build
# 1194, which this container already has in /opt/pw-browsers. Crawl4AI's
# default (newer) Playwright wants a build that is not there and would try to
# download a second browser. If the container's Chromium build changes, find
# the Playwright release whose browsers.json names it and update PLAYWRIGHT.
set -euo pipefail

VENV=/opt/crawl4ai-venv
CRAWL4AI=0.9.5
PLAYWRIGHT=1.56.0
REVISION=1194
log() { printf '[crawl4ai-setup] %s\n' "$*"; }

if "$VENV/bin/python" -c "import crawl4ai, sys; sys.exit(0 if crawl4ai.__version__.__version__ == '$CRAWL4AI' else 1)" 2>/dev/null; then
  log "already installed ($CRAWL4AI)"
else
  [ -d "/opt/pw-browsers/chromium_headless_shell-$REVISION" ] \
    || log "WARNING: Chromium build $REVISION not found in /opt/pw-browsers; crawls may fail. See the note at the top of this script."
  if command -v uv >/dev/null || [ -x "$HOME/.local/bin/uv" ]; then
    UV=$(command -v uv || echo "$HOME/.local/bin/uv")
    "$UV" venv -q "$VENV"
    VIRTUAL_ENV="$VENV" "$UV" pip install -q "crawl4ai==$CRAWL4AI" "playwright==$PLAYWRIGHT"
  else
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q "crawl4ai==$CRAWL4AI" "playwright==$PLAYWRIGHT"
  fi
  log "installed Crawl4AI $CRAWL4AI"
fi
# A wrapper rather than a symlink, so every run hides Crawl4AI's cloud banner.
cat > /usr/local/bin/crwl <<SH
#!/bin/sh
CRAWL4AI_NO_CLOUD_NOTICE=1 exec "$VENV/bin/crwl" "\$@"
SH
chmod 0755 /usr/local/bin/crwl
log "crwl ready"
