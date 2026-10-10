# claude-tools

> Working on this repo? Read [`CLAUDE.md`](CLAUDE.md) first: the setup, the
> process for adding a tool, and what the cloud container allows.

Tools every Claude Code cloud session installs when it starts, whatever
project it opens. A cloud container is wiped when its session ends, so
anything installed by hand is gone next time. This repo is the one place that
says what every session should have.

## How it is wired

Each cloud environment has a **setup script** (the environment menu in the
session's title bar → Edit → Setup script). It runs at the start of every
session in that environment, before Claude does anything. Put this one line
there:

```bash
curl -fsSL https://raw.githubusercontent.com/CyberPro-Marketing/claude-tools/main/setup.sh | bash
```

`setup.sh` downloads this repo and runs every script in `tools/`. Change a
tool here and the next session on every project picks it up; there is nothing
to copy into each project.

This repo is **public on purpose**: that is what lets the line above download
it with no token. Keep it that way, and never put a key, password or business
data in it. Secrets belong in each environment's own settings.

### Options

Set these in the environment's variables, or put them before `bash` in the
line above (`... | CLAUDE_TOOLS_SKIP=musicgen bash`).

| Variable | Effect |
|---|---|
| `CLAUDE_TOOLS_SKIP` | Space-separated names to skip: a whole tool (`hyperframes`) or a named part (`musicgen`) |
| `CLAUDE_TOOLS_REF` | Install from a branch instead of `main`, for trying a change before it reaches every session |

A tool that fails is logged as `[claude-tools] <name>: FAILED` and skipped. It
never fails the setup script, so one broken tool cannot stop every session
from starting.

## Tools

### hyperframes

[HyperFrames](https://github.com/heygen-com/hyperframes) from HeyGen: write
HTML, render MP4 video. Installs:

- the Claude Code plugin (`/hyperframes` and its skills), at user scope so
  every repo sees it
- `whisper-cli` (whisper.cpp), for transcription and captions
- Kokoro, local text-to-speech
- MusicGen, local background music (CPU-only torch; skip with
  `CLAUDE_TOOLS_SKIP=musicgen`)

It also points HyperFrames at the container's own headless Chromium, so
rendering needs no second browser download.

**Cost at session start:** about 3 minutes and 1.5 GB on a fresh container,
measured 2026-10-06. Most of that is MusicGen; without it, under a minute.
The first voice line downloads 27 MB of voice data, the first transcription
downloads the `small.en` model, and the first music clip downloads 2.3 GB of
weights, each once per session.

### remotion

[Remotion](https://www.remotion.dev)'s official Claude Code plugin: skills for
building videos and stills in React and rendering them. Remotion itself is
added per project by `npx create-video`. About 4 seconds at session start.
**Licence:** free for individuals and companies of up to 3 employees; larger
for-profit companies need a Remotion company licence.

### web-design

Tools for building websites. From Anthropic's official plugin directory:
**frontend-design**, **modern-web-guidance**, **Playwright** and **Chrome
DevTools**; plus the **shadcn/ui** component MCP. Claude can design with
intent, check its pages in a real browser, screenshot them, run Lighthouse
audits and pull in polished components. About 12 seconds at session start.
Context7 (current library docs) will join once there is a free API key.

## Adding a tool

1. Add `tools/<name>.sh`. Make it safe to run twice: check before you
   install, so a container that already has the tool spends seconds on it.
2. Set any environment variables the tool needs in `~/.claude/settings.json`
   under `env`, not in a shell profile. Claude's commands always get that
   file's `env`; they do not read `.bashrc`.
3. Try it from a branch first: set `CLAUDE_TOOLS_REF=<branch>` in one
   environment, start a session, and read the `[claude-tools]` lines.
4. Add it to the Tools section above with what it costs at startup.
