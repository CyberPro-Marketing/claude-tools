#!/usr/bin/env bash
# Premium website tools for every session: the motion, animated components and
# video tools that turn a clean site into a high-end one. Adds to
# tools/web-design.sh (frontend-design, Playwright, Chrome DevTools, Context7,
# shadcn/ui).
#
#   - gsap-skills   Claude Code plugin, GreenSock's official skills: core,
#                   timelines, ScrollTrigger, plugins (SplitText, Flip,
#                   ScrollSmoother...), React, performance. GSAP and all its
#                   plugins are free, including for commercial client work.
#   - 21st          21st.dev's MCP (search 10,000+ React/Tailwind components,
#                   install them, logos as SVG, AI UI generation when the account
#                   has AI access), through 21st's own stdio proxy, plus its
#                   21st-ui skill. Needs a 21st API key; see CLAUDE.md.
#   - magicui       Magic UI's official MCP: animated backgrounds, marquees, text
#                   effects, shimmer buttons. No key.
#   - mux           Mux's hosted MCP: upload and stream hero video. Auth through
#                   the environment's Network secrets for mcp.mux.com; see CLAUDE.md.
#   - fal           fal.ai's hosted MCP: image, video and 3D models, pay per run.
#                   Signs in through /mcp in the session that uses it.
#
# Versions are pinned where a bad release would break every session at once.
set -euo pipefail

MAGIC_VERSION=0.2.3                                    # @21st-dev/magic on npm
SKILL_SHA=6b5299e8a83ceffa73d4fc4e148905bb3eeeeb55     # 21st-dev/magic-mcp commit
SKILLS="$HOME/.claude/skills"
log() { printf '[web-premium-setup] %s\n' "$*"; }

# 1. The GSAP plugin, through the CLI when it is on PATH.
if command -v claude >/dev/null; then
  claude plugin marketplace list 2>/dev/null | grep -q gsap-skills \
    || claude plugin marketplace add greensock/gsap-skills
  claude plugin list 2>/dev/null | grep -q 'gsap-skills@gsap-skills' \
    || claude plugin install gsap-skills@gsap-skills
  log "gsap plugin ready"
fi

# 2. The 21st-ui skill, from the pinned commit (raw.githubusercontent.com is
# allowed through the cloud proxy; GitHub archives are not).
stamp="$SKILLS/21st-ui/.sha"
if [ "$(cat "$stamp" 2>/dev/null)" != "$SKILL_SHA" ]; then
  mkdir -p "$SKILLS/21st-ui"
  curl -fsSL "https://raw.githubusercontent.com/21st-dev/magic-mcp/$SKILL_SHA/skills/21st-ui/SKILL.md" \
    -o "$SKILLS/21st-ui/SKILL.md"
  echo "$SKILL_SHA" > "$stamp"
fi
log "21st-ui skill ready"

# 3. Settings fallback for the GSAP plugin, and the MCP servers at user scope.
# Merged, never overwritten.
MAGIC_VERSION="$MAGIC_VERSION" python3 - <<'PY'
import json, os, pathlib
home = pathlib.Path.home()
path = home / ".claude" / "settings.json"
path.parent.mkdir(parents=True, exist_ok=True)
s = json.loads(path.read_text()) if path.exists() else {}
s.setdefault("extraKnownMarketplaces", {})["gsap-skills"] = {
    "source": {"source": "github", "repo": "greensock/gsap-skills"}}
s.setdefault("enabledPlugins", {})["gsap-skills@gsap-skills"] = True
path.write_text(json.dumps(s, indent=2) + "\n")

state = home / ".claude.json"
c = json.loads(state.read_text()) if state.exists() else {}
servers = c.setdefault("mcpServers", {})
# 21st: the proxy reads API_KEY_21ST from the environment when it is set; with a
# Network secret for 21st.dev instead, the proxy injects the key on the way out.
servers["21st"] = {"type": "stdio", "command": "npx",
    "args": ["-y", f"@21st-dev/magic@{os.environ['MAGIC_VERSION']}"], "env": {}}
servers.setdefault("magicui", {
    "type": "stdio", "command": "npx", "args": ["-y", "@magicuidesign/mcp@latest"], "env": {}})
servers.setdefault("mux", {"type": "http", "url": "https://mcp.mux.com"})
servers.setdefault("fal", {"type": "http", "url": "https://mcp.fal.ai/mcp-relay"})
state.write_text(json.dumps(c, indent=2) + "\n")
PY
log "mcp servers ready (21st, magicui, mux, fal)"
log "done"
