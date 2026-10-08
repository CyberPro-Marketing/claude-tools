#!/usr/bin/env bash
# Installs Remotion's official Claude Code plugin: its skills for building
# videos and stills in React (animation, timing, captions, charts, 3D) and
# rendering them to MP4 or PNG.
#
# Remotion itself is not installed here. It is an npm dependency of each video
# project, and `npx create-video` adds it when Claude starts one, so a session
# that never makes a Remotion video pays nothing for it. On a project's first
# render Remotion downloads its own headless Chrome (~236 MB, a few seconds),
# which the cloud proxy allows.
#
# Licence: free for individuals and companies of up to 3 employees; larger
# for-profit companies need a Remotion company licence (remotion.pro/license).
set -euo pipefail

log() { printf '[remotion-setup] %s\n' "$*"; }

if command -v claude >/dev/null; then
  if ! claude plugin list 2>/dev/null | grep -q 'remotion@remotion'; then
    claude plugin marketplace add remotion-dev/claude-code-plugin
    claude plugin install remotion@remotion
  fi
  log "plugin ready"
fi

# Also enable it in user settings, so Claude installs it at startup even when
# the CLI was not on PATH for the call above. Merged, never overwritten.
python3 - <<'PY'
import json, pathlib
path = pathlib.Path.home() / ".claude" / "settings.json"
path.parent.mkdir(parents=True, exist_ok=True)
s = json.loads(path.read_text()) if path.exists() else {}
s.setdefault("extraKnownMarketplaces", {})["remotion"] = {
    "source": {"source": "github", "repo": "remotion-dev/claude-code-plugin"}}
s.setdefault("enabledPlugins", {})["remotion@remotion"] = True
path.write_text(json.dumps(s, indent=2) + "\n")
PY
log "done"
