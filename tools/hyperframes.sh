#!/usr/bin/env bash
# Installs HyperFrames and its optional local extras into a Claude Code cloud
# container. Safe to run twice: every step checks before it installs.
#   - the hyperframes Claude Code plugin (user scope, so every repo sees it)
#   - whisper.cpp's whisper-cli, for transcription and captions
#   - Kokoro, a local text-to-speech fallback
#   - MusicGen (transformers + CPU torch), a local background-music fallback
set -euo pipefail

VENV=/opt/hyperframes-venv
log() { printf '[hyperframes-setup] %s\n' "$*"; }

# 1. The plugin. User scope rather than project scope so it works in any repo.
if command -v claude >/dev/null; then
  if ! claude plugin list 2>/dev/null | grep -q 'hyperframes@hyperframes'; then
    claude plugin marketplace add heygen-com/hyperframes
    claude plugin install hyperframes@hyperframes
  fi
  log "plugin ready"
fi

# 2. whisper.cpp. HyperFrames looks for whisper-cli on PATH first.
if ! command -v whisper-cli >/dev/null; then
  src=$(mktemp -d)
  git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git "$src/whisper.cpp"
  cmake -S "$src/whisper.cpp" -B "$src/whisper.cpp/build" -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF >/dev/null
  cmake --build "$src/whisper.cpp/build" -j"$(nproc)" --target whisper-cli >/dev/null
  install -m 0755 "$src/whisper.cpp/build/bin/whisper-cli" /usr/local/bin/whisper-cli
  rm -rf "$src"
fi
log "whisper-cli ready"

# 3 + 4. Python extras in their own venv; HYPERFRAMES_PYTHON points at it.
# CPU-only torch: the default wheel pulls ~2 GB of CUDA libraries no container uses.
if [ ! -x "$VENV/bin/python" ]; then python3 -m venv "$VENV"; fi
if ! "$VENV/bin/python" -c 'import kokoro_onnx, soundfile' 2>/dev/null; then
  "$VENV/bin/pip" install -q kokoro-onnx soundfile
fi
# MusicGen is the slow part (~2 minutes, ~1.3 GB). CLAUDE_TOOLS_SKIP=musicgen
# leaves it out; HyperFrames then reports local music as unavailable.
if [[ " ${CLAUDE_TOOLS_SKIP:-} " == *" musicgen "* ]]; then
  log "musicgen skipped"
elif ! "$VENV/bin/python" -c 'import torch, transformers, numpy' 2>/dev/null; then
  "$VENV/bin/pip" install -q torch --index-url https://download.pytorch.org/whl/cpu
  "$VENV/bin/pip" install -q transformers numpy soundfile
fi
log "python extras ready"

# Point HyperFrames at the venv and the container's preinstalled headless
# Chromium. Written into Claude Code's user settings rather than a shell
# profile: a non-interactive shell never reads bashrc, and Claude's commands
# always get the settings file's `env`. The plugin is enabled there too, so
# Claude installs it at startup even if the `claude plugin` call above failed.
chromium=$(ls -d /opt/pw-browsers/chromium_headless_shell-*/chrome-linux/headless_shell 2>/dev/null | tail -1 || true)
VENV="$VENV" CHROMIUM="$chromium" python3 - <<'PY'
import json, os, pathlib
path = pathlib.Path.home() / ".claude" / "settings.json"
path.parent.mkdir(parents=True, exist_ok=True)
s = json.loads(path.read_text()) if path.exists() else {}
s.setdefault("extraKnownMarketplaces", {})["hyperframes"] = {
    "source": {"source": "github", "repo": "heygen-com/hyperframes"}}
s.setdefault("enabledPlugins", {})["hyperframes@hyperframes"] = True
env = s.setdefault("env", {})
env["HYPERFRAMES_PYTHON"] = os.environ["VENV"] + "/bin/python"
if os.environ.get("CHROMIUM"):
    env["HYPERFRAMES_BROWSER_PATH"] = os.environ["CHROMIUM"]
path.write_text(json.dumps(s, indent=2) + "\n")
PY
log "done"
