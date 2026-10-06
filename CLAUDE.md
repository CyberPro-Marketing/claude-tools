# Claude Tools

Adam Bossin's shared toolbox for Claude Code cloud sessions. Every tool in
`tools/` is installed at the start of **every** session in his cloud
environment, whatever project that session opens: one of his sites, the
Orion repo, or something new. Add a tool here once and every project has it.

This repo is the record of what is installed and why. Adam finds a tool, and
the Claude Tools session works out how to install it, tests it, writes it up
here, and pushes. **If you are that session, this file is your brief. Read it
before changing anything.**

---

## How it works

A cloud container starts empty and is wiped when its session ends, so anything
installed by hand is lost. The fix is the environment's **setup script**, which
runs when each new session starts, before Claude Code launches.

The setup script of Adam's **Default** environment holds exactly this, set by
Adam on 2026-10-06:

```bash
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/CyberPro-Marketing/claude-tools/main/setup.sh | bash
```

`setup.sh` then:

1. clones this repo (shallow, from `main` or `CLAUDE_TOOLS_REF`);
2. runs every `tools/*.sh` in name order, skipping any named in
   `CLAUDE_TOOLS_SKIP`;
3. logs each one as `[claude-tools] <name>: ready in Ns` or `FAILED`;
4. **always exits 0.** One broken tool must never stop a session on every
   project from starting. Do not change this.

### Where Adam changes the setup script

claude.ai → any session → the environment menu in the session's title bar →
**Edit** → **Setup script** (the last box, above *Save changes*). The grey
`#!/bin/bash` / `npm install` shown in an empty box is placeholder text, not a
value. Changes apply to **new** sessions only. Each environment has its own
setup script, so a second environment needs the same line pasted into it.

A Claude session cannot edit the environment itself. Say exactly what to paste
and where, and let Adam do it.

### Options

Set these in the environment's **Environment variables** box, or inline in the
setup line (`... | CLAUDE_TOOLS_SKIP=musicgen bash`):

| Variable | Effect |
|---|---|
| `CLAUDE_TOOLS_SKIP` | Space-separated names to skip: a whole tool (`hyperframes`) or a named part (`musicgen`) |
| `CLAUDE_TOOLS_REF` | Install from a branch instead of `main`, to try a change in one environment first |

---

## Starting a session

- **A normal working session (any project):** start it in the Default
  environment as usual. The tools install on their own while it starts. There
  is nothing to type.
- **The Claude Tools session (this repo):** start it with
  `CyberPro-Marketing/claude-tools` selected as the repository. Use it for
  adding, changing, fixing or removing tools.
- **To check the tools arrived:** in any new session, ask Claude to run
  `npx hyperframes doctor`. Transcription (whisper-cpp), voice (Kokoro), music
  (MusicGen) and Chrome should all show ✓. If one doesn't, ask it to look for
  `[claude-tools]` lines from the setup run, which name what failed.

---

## Tools installed

| Tool | What it gives every session | Startup cost (fresh container) |
|---|---|---|
| **hyperframes** (`tools/hyperframes.sh`) | HeyGen's [HyperFrames](https://github.com/heygen-com/hyperframes): write HTML, render MP4 video. The Claude Code plugin (`/hyperframes` and its skills), `whisper-cli` for transcription and captions, Kokoro for local voice, MusicGen for local background music, all pointed at the container's own headless Chromium | ~2 min 46 s and ~1.5 GB, measured 2026-10-06; a repeat run is ~5 s. Most of it is MusicGen; `CLAUDE_TOOLS_SKIP=musicgen` brings it under a minute |

Downloads that happen on **first use** in a session, not at startup: 27 MB of
Kokoro voice data, whisper's `small.en` model, and 2.3 GB of MusicGen weights.

Measured end to end on 2026-10-06:
- A 10-second 1080p render took 14 s.
- A Kokoro voice line transcribed back by whisper came out word for word.
- MusicGen produced a 5-second clip in 45 s.

**Not yet observed:** a real setup-script run in a brand-new session. The
script was tested from scratch inside a session, and the exact `curl` line was
run against the live repo, but the first new session after Adam saved the
setup script is the first true run. Note here when one has been confirmed.

---

## Adding a tool: the process

1. **Read the tool's own install docs from its source**, not its marketing.
   Find what it needs: binaries, Python or Node packages, models, environment
   variables, a browser.
2. **Install it by hand in this session first** and use it for real. A
   successful install proves nothing until the tool produces output. Render
   the video, transcribe the file, call the API.
3. **Write `tools/<name>.sh`** following the rules below.
4. **Test from scratch.** Uninstall what step 2 installed, then run the
   installer against a local clone:

   ```bash
   sed "s#https://github.com/\$REPO.git#/home/user/claude-tools#" setup.sh > /tmp/t.sh && bash /tmp/t.sh
   ```

   Run it twice: the second run must take seconds.
5. **Push to a branch** if the change is risky, and have Adam set
   `CLAUDE_TOOLS_REF=<branch>` in one environment and start a session.
   Otherwise push to `main`.
6. **Update the *Tools installed* table** with the measured startup cost and
   date, and the README's Tools section.
7. **Tell Adam in plain words** what every session now has, what it costs at
   startup, and how to check it.

### Rules every installer follows

- **Safe to run twice.** Check before installing (`command -v`, an import
  probe, a version check), because it runs at the start of every session.
- **Exit non-zero only on a real failure.** `setup.sh` logs it and moves on.
- **Environment variables go in `~/.claude/settings.json` under `env`**,
  merged, never overwritten (see the Python block in `tools/hyperframes.sh`).
  Claude's commands always get that `env`; they do not read `.bashrc` or
  `/etc/profile.d`. That was tried first and does not reach them.
- **Claude Code plugins are installed two ways**: `claude plugin install`
  when the CLI is on PATH, and `extraKnownMarketplaces` + `enabledPlugins` in
  user settings as the fallback. The setup script runs before Claude Code
  launches, and the CLI may not be available then.
- **Python packages go in their own venv** under `/opt/<tool>-venv`, pointed
  to by whatever variable the tool reads. The system Python refuses
  `pip install` (PEP 668), and a venv keeps tools from breaking each other.
- **No secrets, ever.** This repo is public. That is what lets the setup line
  download it with no token. An API key belongs in the environment's **API
  credentials** or **Environment variables** box, never in a script here. A
  tool that needs a key should check for it and say plainly that it is
  missing, rather than fail.
- **Mind startup time.** Every second here is paid at the start of every
  session on every project. Prefer first-use downloads for large models, and
  give anything slow its own `CLAUDE_TOOLS_SKIP` name.

---

## What the cloud container allows, measured 2026-10-06

Things learned by being refused, so the next tool does not rediscover them:

- **GitHub archive downloads are blocked** (`codeload.github.com`, `/archive/`
  tarballs both answer 403 through the proxy). `git clone` of a public repo
  works, and so does `raw.githubusercontent.com`. That is why `setup.sh`
  clones.
- **Git LFS files do not come through** for repos outside the session's
  sources. The HyperFrames plugin warns about 84 LFS files; none are in its
  skills, so it is harmless there. Check before relying on LFS content.
- **Chromium is preinstalled** at `/opt/pw-browsers/`, including a headless
  shell. Point tools at it rather than letting them download their own. Never
  run `playwright install`.
- **Already present:** Node 22, Python 3.13, ffmpeg/ffprobe, git, cmake, gcc,
  Docker (installed, not running), the `claude` CLI.
- **The Claude GitHub app cannot create repositories** (403 "Resource not
  accessible by integration"). Adam creates a new repo on github.com himself;
  then the session attaches it.
- Disk is a fixed allowance per session (~29 GB free at the start). Large
  models count against it.

---

## Related

- `kingadam333/adam-bossin-nextjs` also carries a project-level
  `.claude/settings.json` enabling the HyperFrames plugin for that one repo,
  on branch `ccr-3eaa5708-849xzm` (not merged to `main` as of 2026-10-06).
  It was added before this repo existed and is redundant with the setup
  script. Merging it or dropping it are both fine, since both set the same
  values.
- HyperFrames' own docs: https://hyperframes.heygen.com/introduction
