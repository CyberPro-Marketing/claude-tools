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
**frontend-design**, **modern-web-guidance**, **Playwright**, **Chrome
DevTools** and **Context7**; plus the **shadcn/ui** component MCP. Claude can design with
intent, check its pages in a real browser, screenshot them, run Lighthouse
audits and pull in polished components. About 12 seconds at session start.
Context7 needs its API key saved as a network secret for `mcp.context7.com`
in the environment's settings; see CLAUDE.md.

### web-premium

The high-end layer on top of web-design, for client sites with motion and
video. **GSAP**'s official skills (ScrollTrigger, SplitText, timelines, React;
GSAP is free for commercial use), 21st.dev's `21st-ui` skill (the 21st.dev MCP
itself is a claude.ai connector, so it needs nothing here), the **Magic UI** MCP
(animated backgrounds, marquees, text effects), and the hosted **Mux** (video
streaming) and **fal.ai** (image, video and 3D models) MCPs. About 4 seconds
at session start. Mux needs a token saved in the environment's settings; fal signs in through `/mcp` when first used. See
CLAUDE.md.

### rea

[REA](https://github.com/morluto/rea) ("Reverse Engineer Anything"): lets
Claude take apart software it has no source for, such as websites,
JavaScript/Electron apps and many file formats, with evidence for each finding.
About 1 second at session start; REA downloads when first used.

**Compiled programs need Ghidra**, which is too big for every session. Ask
Claude to "set up Ghidra" in the session that needs it (about 35 seconds).

## claude.ai connectors

Some tools come from Claude account connectors instead of this repo: 21st Dev,
Figma, Higgsfield, Descript, TinyFish, HyperFrames by HeyGen and Webflow. They
reach every session on their own. CLAUDE.md lists each with its plan limits.

## Prompts

`prompts/` holds ready-to-paste prompts for using these tools. For a website:
paste [`prompts/website-premium.md`](prompts/website-premium.md) (a high-end
client site) or [`prompts/website-warmup.md`](prompts/website-warmup.md) first,
then the filled-in [`prompts/website-template.md`](prompts/website-template.md).

## Adding a tool

1. Add `tools/<name>.sh`. Make it safe to run twice: check before you
   install, so a container that already has the tool spends seconds on it.
2. Set any environment variables the tool needs in `~/.claude/settings.json`
   under `env`, not in a shell profile. Claude's commands always get that
   file's `env`; they do not read `.bashrc`.
3. Try it from a branch first: set `CLAUDE_TOOLS_REF=<branch>` in one
   environment, start a session, and read the `[claude-tools]` lines.
4. Add it to the Tools section above with what it costs at startup.
