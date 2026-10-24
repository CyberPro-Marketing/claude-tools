# Website session warm-up

Paste this as the **first** message of a new website session, in the Default
environment with the site's repo selected. When Claude replies with its
summary, send the design brief from [`website-template.md`](website-template.md).

```
Before we start, get set up for a website design job. Don't build anything yet.

1. Check the tools are here: run `claude plugin list` and `claude mcp list`.
   I expect these plugins: frontend-design, modern-web-guidance, playwright,
   chrome-devtools-mcp, context7, gsap-skills, hyperframes and remotion, plus
   the shadcn and magicui MCP servers connected, and the 21st-ui skill. The 21st
   Dev connector comes from my Claude account, so it isn't in `claude mcp list`:
   check that its tools (mcp__21st_Dev__search and others) are available.
   mux and fal may say "Needs authentication"; that's fine unless this job
   needs them. If any are missing or not connected, tell me which and why.
   If Context7 isn't connected, tell me so I can reconnect it with /mcp.

2. Load the frontend-design, modern-web-guidance, gsap-skills and 21st-ui
   skills now, so they shape the work from the start.

3. Look at this repo: is it empty or an existing site? If it's existing, tell me
   the stack, the pages, and anything that would affect a redesign.

4. Reply with a short summary: which tools are ready, what each will be used for
   on this job, and what you found in the repo. Then wait for my design prompt.

How to work on this job:
- frontend-design for the design direction (not a generic template look).
- shadcn/ui, 21st.dev and Magic UI for components; animated ones from 21st
  and Magic UI where they lift the design.
- GSAP (ScrollTrigger, SplitText) for scroll and entrance motion, with
  prefers-reduced-motion respected.
- Context7 for current Next.js, React and Tailwind docs.
- /hyperframes for any hero videos, loops or promo clips; fal for AI video or
  images if I've signed it in; Mux to host heavy video.
- Playwright screenshots at phone and desktop sizes, and a Chrome DevTools
  Lighthouse audit, on every page before you show me anything.
- Show me the design direction before building every page.
- Don't invent facts, dates, prices or quotes; use marked placeholders and list
  what you still need from me.
```
