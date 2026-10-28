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
| **find-skills** (`tools/find-skills.sh`) | Vercel's [find-skills](https://github.com/vercel-labs/skills) skill (MIT, 4.1M installs on skills.sh), pinned to commit `533c7df`: when Adam asks "is there a skill for X", Claude searches skills.sh with `npx skills find`, checks installs, source and stars, and recommends. One local rule is appended to it: recommend freely, **ask before installing**, and send lasting additions through this repo | ~1 s fresh, 0 s repeat, measured 2026-10-27 |
| **hyperframes** (`tools/hyperframes.sh`) | HeyGen's [HyperFrames](https://github.com/heygen-com/hyperframes): write HTML, render MP4 video. The Claude Code plugin (`/hyperframes` and its skills), `whisper-cli` for transcription and captions, Kokoro for local voice, MusicGen for local background music, all pointed at the container's own headless Chromium | ~2 min 46 s and ~1.5 GB, measured 2026-10-06; a repeat run is ~5 s. Most of it is MusicGen; `CLAUDE_TOOLS_SKIP=musicgen` brings it under a minute |
| **rea** (`tools/rea.sh`) | [REA](https://github.com/morluto/rea) ("Reverse Engineer Anything", MIT): an MCP server (`rea`, pinned `rea-agents@6.7.0` via npx) and its `reverse-engineer-anything` skill, for taking apart software without its source: websites (attaches to a Chromium over CDP), JavaScript/Electron apps, Go/Rust/WASM/SQLite and many other formats, and compiled programs once Ghidra is added. Also a `ghidra-setup` skill that tells any session how to add Ghidra on demand, and `MCP_TIMEOUT=90000` | ~1 s, measured 2026-10-22. REA itself (~250 MB with dependencies) downloads through npx when Claude starts the server: ~27 s on a fresh container |
| **remotion** (`tools/remotion.sh`) | Remotion's official Claude Code plugin: 12 skills (`remotion-create`, `remotion-best-practices`, `remotion-render`, `remotion-captions`, `remotion-maps`, …) for building videos and stills in React and rendering them to MP4 or PNG. Remotion itself is a per-project npm dependency that `npx create-video` adds, so it costs nothing until a session makes a Remotion project | ~4 s fresh, ~0 s repeat, measured 2026-10-08. A project's first render downloads Remotion's own headless Chrome (~236 MB, a few seconds) |
| **video-watch** (`tools/video-watch.sh`) | Lets Claude watch a video. [yt-dlp](https://github.com/yt-dlp/yt-dlp) (public domain) in `/opt/yt-dlp-venv`, linked at `/usr/local/bin/yt-dlp`, set to `--js-runtimes node`, upgraded when its release is over 14 days old (not pinned: sites change and old releases stop working). `/usr/local/bin/watch-video <link or file> [folder]` downloads (720p max), transcribes with whisper-cli and takes 12 frames plus a contact sheet. A `watch-video` skill says when to use it and its limits | ~13 s fresh, ~1 s repeat, measured 2026-10-27 |
| **web-design** (`tools/web-design.sh`) | For building websites. From Anthropic's official plugin directory: **frontend-design** (Anthropic's skill for distinctive, non-generic design), **modern-web-guidance** (Google Chrome's current web practices), **playwright** (Microsoft's browser MCP: open, click, screenshot) **chrome-devtools-mcp** (Google's: Lighthouse audits, performance traces, network and console) and **context7** (current library docs; needs the Context7 network secret). Plus the **shadcn/ui MCP** (search and add components) at user scope, and a Chrome launcher at `/opt/google/chrome/chrome` that both browser MCPs need | ~12 s fresh, ~2 s repeat, measured 2026-10-10. Each MCP's npm package downloads on first use |
| **web-premium** (`tools/web-premium.sh`) | The high-end layer for client sites. **gsap-skills** plugin (GreenSock's 8 official skills: core, timeline, ScrollTrigger, plugins, utils, React, performance, frameworks; GSAP and every plugin are free for commercial use). 21st.dev's `21st-ui` skill pinned to commit `6b5299e` (the 21st MCP itself is Adam's claude.ai connector, "21st Dev"). **magicui** MCP (Magic UI's animated components). Hosted **mux** MCP (video upload and streaming) and **fal** MCP (image, video and 3D models, pay per run) | ~4 s fresh, ~2 s repeat, measured 2026-10-24 |

Downloads that happen on **first use** in a session, not at startup: 27 MB of
Kokoro voice data, whisper's `small.en` model, and 2.3 GB of MusicGen weights.

Measured end to end on 2026-10-06:
- A 10-second 1080p render took 14 s.
- A Kokoro voice line transcribed back by whisper came out word for word.
- MusicGen produced a 5-second clip in 45 s.
- Remotion (2026-10-08): `npx create-video --yes --hello-world` scaffolded a
  project; it rendered a 5-second 1080p H.264 MP4 in 14 s and a PNG still.
  Passing `--browser-executable=` with the container's headless shell (now
  `/opt/pw-browsers/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell`)
  to `npx remotion render` reuses the preinstalled browser instead of the
  236 MB download; it worked, and is optional.

- Web design tools (2026-10-10), each called over MCP with real requests:
  Playwright opened adambossin.com and returned a correct screenshot; Chrome
  DevTools ran a mobile Lighthouse audit of it (Accessibility 96, Best
  Practices 96, SEO 100); shadcn searched its registry ("dialog": 9 items) and
  returned the button component's details. `claude mcp list` shows all three
  connected after a from-scratch install.

**Context7** (added 2026-10-10) gives Claude current docs for Next.js, React,
Tailwind and thousands of libraries. Its hosted server needs an API key, and
the key lives in the Default environment's **Network secrets** (Edit → Network
secrets → Add secret): name `Context7`, type Bearer, allowed website
`mcp.context7.com`, header `Authorization` with prefix `Bearer`. The proxy
injects it on every request to that host, so the key never touches this repo
or the chat. Verified: the endpoint answered 200 instead of 401, a real
`resolve-library-id` lookup for Next.js returned `/vercel/next.js` with its
versions, and `claude mcp list` shows the plugin connected. Without the secret
(another environment, say) the plugin shows "Needs authentication" and nothing
else breaks.

**Known startup glitch (seen 2026-10-13 and 2026-10-21):** when a session
starts, Claude Code sometimes marks Context7 "requires authentication", and its
tools are then missing from that session. Minutes later the endpoint answers
200 and `claude mcp list` shows it connected, so the key is fine; the check at
launch seems to run before the secret is applied. Fix in the session: `/mcp` →
Context7 → reconnect. The website warm-up prompt asks Claude to flag this.

**web-premium keys and sign-ins** (added 2026-10-24):

- **21st.dev** is Adam's **claude.ai connector** "21st Dev" (Settings →
  Connectors → custom connector, URL `https://21st.dev/api/mcp`, signed in with
  his 21st account; added 2026-10-24). Connectors follow his Claude account, so
  it appears in claude.ai chats and in every Claude Code cloud session by
  itself, as `mcp__21st_Dev__*` tools, with no key in any environment.
  `claude mcp list` does not show claude.ai connectors; check for the tools
  instead (the prompts say so).
  Verified 2026-10-24: it appeared in a running cloud session within a minute,
  and a live `search` for "video background hero" returned real components.
  His account has AI generation (`generate`, `iterate_generation`) and 21st's
  video tools. This repo only adds the `21st-ui` skill. An earlier version of
  this script also registered a key-based `21st` server; it now removes that
  entry, so there is one 21st server, not two. (Background: 21st replaced its
  old Magic MCP and reset every old Magic key.)
- **Mux** needs an access token (a token ID and secret, made in the Mux dashboard).
  Save a Network secret for `mcp.mux.com`, header `Authorization`, value
  `Basic <base64 of TOKEN_ID:TOKEN_SECRET>` (Mux's documented non-OAuth form).
  Not yet tested with a real token.
- **fal.ai** has only browser sign-in: `/mcp` → fal → Authenticate, in the
  session that needs it. The container is wiped after, so each session that
  uses fal signs in again.
- Without their auth, Mux and fal show "Needs authentication" and nothing else
  breaks.

Tested 2026-10-24: from-scratch setup run twice (4 s, then 2 s); the
gsap-skills plugin installs all 8 skills; Magic UI connects and a real
`searchRegistryItems` for "marquee" returned 5 components; Mux and fal show
"Needs authentication".

**Tried and left out:** `mcp-server-lottiefiles` (community) connects, but
every search returns 404 from LottieFiles' API, so it is broken upstream.
**Figma** and **Webflow** are better added as claude.ai connectors (Settings →
Connectors) than here: those keep their sign-in across sessions, and this
container forgets an OAuth login when it is wiped.

- REA (2026-10-22): inspected adambossin.com through a live Chromium (32
  scripts, 19 resources, DOM and storage, with cookies and values withheld by
  design); analysed the site's Next.js page bundle as a JavaScript app (4
  modules, 14 findings); with Ghidra, mapped `/usr/bin/true` (133 functions,
  122 strings, 26 s) and decompiled its entry point to C-like code. `claude mcp
  list` connects REA even from a cold npm cache (27 s).

**Ghidra is on demand, not in every session** (Adam's choice, 2026-10-22). It
is ~840 MB unpacked, and most sessions never decompile anything.
`on-demand/ghidra.sh` installs it in one session in ~35 s; the `ghidra-setup`
skill tells Claude to run it with
`curl -fsSL https://raw.githubusercontent.com/CyberPro-Marketing/claude-tools/main/on-demand/ghidra.sh | bash`.
It installs to `/opt/ghidra` and links `/usr/local/bin/ghidraRun`, where REA
finds it without `GHIDRA_INSTALL_DIR`. The source is **Kali Linux's package
archive**, because GitHub release downloads are blocked here (see below); the
`.deb` is checked against the SHA-256 in Kali's index and only its files are
used. REA supports Ghidra **12.1.x only**: when Kali moves past 12.1, the
script refuses with a clear message, and the fix is to check REA's docs and
update `WANT` in the script together with `REA_VERSION` in `tools/rea.sh`.

**REA's version is pinned on purpose.** It publishes several releases a day.
To update: bump `REA_VERSION` in `tools/rea.sh`, rerun the tests above, push.

- find-skills and video-watch (2026-10-27): `watch-video` on a public Facebook
  reel (54 s) gave a correct transcript, 12 frames and a contact sheet in
  40 s. yt-dlp from a cloud session: **Facebook and Archive.org work; YouTube**
  ("Sign in to confirm you're not a bot", HTTP 429), **Vimeo** (login
  required), **Instagram and TikTok refuse**. Logged-in cookies would get past
  that and are **not used, by policy**: they put Adam's accounts at risk and
  break those sites' terms. For his own YouTube or Instagram videos, he
  downloads the file (YouTube Studio, Instagram's data download) and uploads
  it; `watch-video` accepts a file. The first `npx skills find` was blocked by
  this session's auto-mode safety check (code from the internet); a later one,
  run when Adam asked for a search, went through and returned results (a
  search for remote-job skills found `firecrawl/skills@firecrawl-job-postings`,
  611 installs, which needs a paid Firecrawl key; Adam chose to hold, not
  installed). Expect the check to ask for approval now and then.

**Remotion's licence is Adam's call, not a technical one.** It is free for
individuals, non-profits and for-profit companies of **up to 3 employees**;
a larger for-profit company using it commercially needs a paid company
licence (remotion.pro/license). HyperFrames (Apache 2.0) has no such limit and
covers most of the same ground. If the business a video is for has more than
three employees, check before rendering client work with Remotion.

**Not yet observed:** a real setup-script run in a brand-new session. The
script was tested from scratch inside a session, and the exact `curl` line was
run against the live repo, but the first new session after Adam saved the
setup script is the first true run. Note here when one has been confirmed.

---

## claude.ai connectors

These are not installed by this repo. Adam adds them in claude.ai (Settings →
Connectors) and they follow his Claude account into every session, cloud ones
included, as `mcp__<Name>__*` tools. `claude mcp list` does not show them;
check for their tools instead. Nothing here needs to change when one is added,
except this table and, if it matters for websites, the prompts.

Checked 2026-10-25 with one read-only call each:

| Connector | What it is for | Account state when checked |
|---|---|---|
| **21st Dev** | Premium and animated components; AI component generation; video blocks | Paid tier, AI generation on, 100 credits a month (reset 2026-11-01). Details under web-premium above |
| **Figma** | Read designs into code; push pages into Figma | Signed in as Adam Bossin, Starter plan, **View seat**: reading designs works, creating or editing in Figma likely needs a paid editor seat |
| **Higgsfield** (Katana) | AI image, video, 3D, ads, AI influencers, a website builder | **Free plan, 3 credits**: about one generation |
| **Descript** | Edit video and audio by editing the transcript; captions; exports | Connected to "Adam Bossin's Drive" |
| **TinyFish** | Web automation, deep research, site monitoring | Wallet $8.20, pay per use (deep research $2–3 a run; search and fetch free) |
| **HyperFrames by HeyGen** (hosted) | HeyGen's cloud HyperFrames projects and renders | Connected, no projects. Its `compose` and `render_video` refuse Claude Code by design; in Claude Code use the local `hyperframes` plugin from `tools/hyperframes.sh` |
| **Webflow** | Build and manage Webflow sites | Connected, not exercised: Adam's sites are Next.js |
| **Apify** | Run any Apify Store Actor: Google Maps places and photos, plus Instagram, Facebook, Yelp, TikTok and other scrapers. Tools appear as `mcp__apify__*` (`search-actors`, `fetch-actor-details`, `call-actor`, `get-dataset-items`, `apify--web-fetch`, `apify--rag-web-browser`) | Added 2026-10-28 (custom connector, URL `https://mcp.apify.com`, OAuth with Adam's Apify account). **Bronze tier**, pay per use. Details below |

Spending connectors (Higgsfield, TinyFish, 21st AI credits, Apify) cost money or
credits per use; say what a run will cost before starting one.

**Apify notes** (verified 2026-10-28):

- **Google Maps** is the Actor `compass/crawler-google-places` (Google Maps
  Scraper, 4.7 stars, ~670k users). Bronze-tier prices: $0.003 per place,
  $0.0005 per image, $0.002 per place for contact enrichment (emails/socials
  from the business's site), $0.0005 per review. A place with 10 photos is
  about $0.01.
- Tested: `call-actor` with
  `{"searchStringsArray": ["El Portal Sedona Hotel"], "locationQuery": "Sedona, Arizona", "maxCrawledPlacesPerSearch": 1, "maxImages": 8, "language": "en"}`
  succeeded in 28 s and returned address, phone, website, rating, `placeId`,
  `imageCategories` (Exterior, Rooms, By owner, From visitors…) and 8
  `imageUrls` at 1920×1080 (`=w1920-h1080` suffix). Read results with
  `get-dataset-items` and a `fields` list to keep the output small.
- `callOptions.maxTotalChargeUsd` must be **at least $0.50** (Apify refuses
  lower); it is a cap, not a charge.
- Check an Actor's input schema with `fetch-actor-details` before the first
  call; field names change between versions.
- Up to ~20 names can go in one `searchStringsArray` run; match results back
  by name and address.
- Use for: filling SedonaPassport (and other directory) listings with photos
  when the business's own site has too few; food-truck and business lead
  lists. Instagram/TikTok scraping Actors also exist in the Store.

---

## On-demand tools

`on-demand/` holds installers that are too big for every session start.
`setup.sh` never runs them; a skill installed by a `tools/` script tells
Claude when and how. Currently: `ghidra.sh` (via the `ghidra-setup` skill).

---

## Prompts

`prompts/` holds the prompts Adam pastes into sessions: `website-premium.md`
(first message of a premium client-site session: warm-up plus the high-end
standard), `website-warmup.md` (first message of a plain website session) and
`website-template.md` (the design brief). `setup.sh` never runs anything there. **When a tool is added or removed,
update the tool lists in `website-premium.md` and `website-warmup.md` and the
HOW TO WORK line in `website-template.md`**, or the warm-up will report a missing tool that was
removed on purpose, or never ask for a new one.

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
  download it with no token. An API key belongs in the environment's **Network
  secrets** (formerly "API credentials") or **Environment variables** box, never in a script here. A
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
  run `playwright install`. **Its folder layout changes with the image's
  Playwright version** (seen 2026-10-27): `chromium-1194/chrome-linux/chrome`
  became `chromium-1243/chrome-linux64/chrome`, and the headless shell moved to
  `chrome-headless-shell-linux64/chrome-headless-shell`. Glob for both layouts,
  never one path; a stale path broke Chrome DevTools MCP and HyperFrames'
  browser in every session until it was fixed.
- **There is no Google Chrome**, and tools that use the "chrome" channel
  (Playwright MCP, Chrome DevTools MCP, Puppeteer's default) look for it at
  `/opt/google/chrome/chrome`. `tools/web-design.sh` puts a launcher there that
  runs the preinstalled Chromium.
- **Sessions run as root, where Chromium refuses its sandbox** ("To avoid the
  sandboxing issue…", or "Target closed" from Puppeteer). The launcher adds
  `--no-sandbox`, and `--headless=new` when there is no display.
- **GitHub release downloads and web pages are blocked** for repos not attached
  to the session (403 from the proxy; `add_repo` grants git reads only). Find
  another published source for prebuilt binaries, as `on-demand/ghidra.sh` does.
- **Java 21 (OpenJDK) is already installed.**
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
