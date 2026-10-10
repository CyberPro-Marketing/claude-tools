#!/usr/bin/env bash
# Website-building tools for every session.
#   From Anthropic's official plugin directory (anthropics/claude-plugins-official):
#   - frontend-design      Anthropic's skill for distinctive, non-generic design
#   - modern-web-guidance  Google Chrome's current web best practices
#   - playwright           Microsoft's browser MCP: open pages, click, screenshot
#   - chrome-devtools-mcp  Google's browser MCP: Lighthouse, performance traces,
#                          network and console inspection
#   - context7             Upstash's current docs for Next.js, React, Tailwind
#                          and thousands of libraries. Its hosted server needs
#                          an API key: the environment's Network secrets inject
#                          it for mcp.context7.com, so it never touches this repo
#   Plus:
#   - shadcn               the shadcn/ui MCP: search and add components from the
#                          shadcn registry
#   - a Chrome launcher at /opt/google/chrome/chrome, because both browser MCPs
#     look for Google Chrome there and this container only has Playwright's
#     Chromium. Without it both fail with "Chrome not found".
set -euo pipefail

MARKET=claude-plugins-official
PLUGINS=(frontend-design modern-web-guidance playwright chrome-devtools-mcp context7)
log() { printf '[web-design-setup] %s\n' "$*"; }

# 1. The Chrome launcher. Only written when no real Chrome is there, so a
# container that ships Google Chrome keeps it.
launcher=/opt/google/chrome/chrome
if [ ! -e "$launcher" ] || grep -q 'claude-tools' "$launcher" 2>/dev/null; then
  mkdir -p "$(dirname "$launcher")"
  cat > "$launcher" <<'SH'
#!/bin/sh
# Launcher installed by claude-tools: browser MCPs (Playwright, Chrome DevTools)
# look for Google Chrome here. Run the container's Chromium instead, without the
# sandbox (the container runs as root, where Chromium refuses to start with it)
# and headless when there is no display.
CHROMIUM=$(ls -d /opt/pw-browsers/chromium-*/chrome-linux/chrome 2>/dev/null | tail -1)
extra=""
if [ -z "$DISPLAY" ]; then
  case " $* " in *" --headless"*) ;; *) extra="--headless=new" ;; esac
fi
exec "$CHROMIUM" --no-sandbox $extra "$@"
SH
  chmod 0755 "$launcher"
fi
log "chrome launcher ready"

# 2. The plugins, through the CLI when it is on PATH.
if command -v claude >/dev/null; then
  if ! claude plugin marketplace list 2>/dev/null | grep -q "$MARKET"; then
    claude plugin marketplace add anthropics/claude-plugins-official
  fi
  installed=$(claude plugin list 2>/dev/null || true)
  for p in "${PLUGINS[@]}"; do
    grep -q "$p@$MARKET" <<<"$installed" || claude plugin install "$p@$MARKET"
  done
  log "plugins ready"
fi

# 3. Settings fallback for the plugins (Claude installs them at startup if the
# CLI was unavailable above), and the shadcn MCP server at user scope, which
# lives in ~/.claude.json. Both merged, never overwritten.
PLUGINS="${PLUGINS[*]}" MARKET="$MARKET" python3 - <<'PY'
import json, os, pathlib
home = pathlib.Path.home()
path = home / ".claude" / "settings.json"
path.parent.mkdir(parents=True, exist_ok=True)
s = json.loads(path.read_text()) if path.exists() else {}
s.setdefault("extraKnownMarketplaces", {})[os.environ["MARKET"]] = {
    "source": {"source": "github", "repo": "anthropics/claude-plugins-official"}}
for p in os.environ["PLUGINS"].split():
    s.setdefault("enabledPlugins", {})[f"{p}@{os.environ['MARKET']}"] = True
path.write_text(json.dumps(s, indent=2) + "\n")

state = home / ".claude.json"
c = json.loads(state.read_text()) if state.exists() else {}
c.setdefault("mcpServers", {}).setdefault("shadcn", {
    "type": "stdio", "command": "npx", "args": ["-y", "shadcn@latest", "mcp"], "env": {}})
state.write_text(json.dumps(c, indent=2) + "\n")
PY
log "done"
