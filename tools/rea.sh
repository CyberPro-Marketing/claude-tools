#!/usr/bin/env bash
# REA ("Reverse Engineer Anything", github.com/morluto/rea, MIT): an MCP
# server and skill that let Claude take apart software it has no source for —
# websites, JavaScript/Electron apps, many file formats, and (with Ghidra)
# compiled programs.
#
# Every session gets the MCP registration and the skill. REA itself (~250 MB
# with dependencies) downloads through npx when Claude starts it, not here.
# Ghidra (~840 MB) is NOT installed here: a session that needs it runs
# on-demand/ghidra.sh, which the ghidra-setup skill below tells Claude to do.
#
# The version is pinned: REA publishes several releases a day, and a bad one
# would otherwise break every session at once. Bump REA_VERSION on purpose,
# after testing.
set -euo pipefail

REA_VERSION=6.7.0
SKILLS="$HOME/.claude/skills"
log() { printf '[rea-setup] %s\n' "$*"; }

# 1. The skill REA ships, matching the pinned version. Taken from the npm
# tarball (a few MB) rather than the git repo, whose main branch moves hourly.
stamp="$SKILLS/reverse-engineer-anything/.rea-version"
if [ "$(cat "$stamp" 2>/dev/null)" != "$REA_VERSION" ]; then
  tmp=$(mktemp -d)
  (cd "$tmp" && npm pack -q "rea-agents@$REA_VERSION" >/dev/null && tar -xzf rea-agents-*.tgz)
  mkdir -p "$SKILLS"
  rm -rf "$SKILLS/reverse-engineer-anything"
  cp -r "$tmp/package/skills/reverse-engineer-anything" "$SKILLS/"
  echo "$REA_VERSION" > "$stamp"
  rm -rf "$tmp"
fi
log "skill ready ($REA_VERSION)"

# 2. A small skill that tells any session how to add Ghidra when it is needed.
mkdir -p "$SKILLS/ghidra-setup"
cat > "$SKILLS/ghidra-setup/SKILL.md" <<'MD'
---
name: ghidra-setup
description: Install Ghidra so REA can decompile compiled programs (.exe, ELF, Mach-O, .so/.dll, firmware). Use when a reverse-engineering task targets native code, REA reports a missing analysis engine for native analysis, or the user says "set up Ghidra". Not needed for websites or JavaScript/Electron apps.
---

# Set up Ghidra for REA

Ghidra is not installed at session start because it is ~840 MB; install it in
this session only:

```bash
curl -fsSL https://raw.githubusercontent.com/CyberPro-Marketing/claude-tools/main/on-demand/ghidra.sh | bash
```

It takes about a minute. It installs Ghidra 12.1.x (the version REA supports)
to `/opt/ghidra` from Kali Linux's package archive, verified against Kali's
published SHA-256, and links `ghidraRun` onto PATH, where REA finds it.

Then confirm with REA's own check and look for `"ghidra"` with `"ok": true`:

```bash
npx -y rea-agents@REA_VERSION_PLACEHOLDER doctor --format json
```

Native analysis then works through REA's MCP tools or the CLI, for example
`npx -y rea-agents@REA_VERSION_PLACEHOLDER decompile /abs/path/app entry --provider ghidra`.
MD
sed -i "s/REA_VERSION_PLACEHOLDER/$REA_VERSION/g" "$SKILLS/ghidra-setup/SKILL.md"
log "ghidra-setup skill ready"

# 3. The MCP registration (user scope, ~/.claude.json), and a longer MCP
# connect timeout: on a fresh container npx needs ~27 s to fetch REA before
# the server answers, close to Claude Code's default. Merged, never overwritten.
REA_VERSION="$REA_VERSION" python3 - <<'PY'
import json, os, pathlib
home = pathlib.Path.home()
state = home / ".claude.json"
c = json.loads(state.read_text()) if state.exists() else {}
c.setdefault("mcpServers", {})["rea"] = {
    "type": "stdio", "command": "npx",
    "args": ["-y", f"rea-agents@{os.environ['REA_VERSION']}", "mcp"], "env": {}}
state.write_text(json.dumps(c, indent=2) + "\n")

path = home / ".claude" / "settings.json"
path.parent.mkdir(parents=True, exist_ok=True)
s = json.loads(path.read_text()) if path.exists() else {}
s.setdefault("env", {}).setdefault("MCP_TIMEOUT", "90000")
path.write_text(json.dumps(s, indent=2) + "\n")
PY
log "done"
