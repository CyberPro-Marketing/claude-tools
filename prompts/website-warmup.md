# Website session warm-up

Paste this as the **first** message of a new website session, in the Default
environment with the site's repo selected. When Claude replies with its
summary, send the design brief from [`website-template.md`](website-template.md).

```
Before we start, get set up for a website design job. Don't build anything yet.

1. Check the tools are here: run `claude plugin list` and `claude mcp list`.
   I expect these plugins: frontend-design, modern-web-guidance, playwright,
   chrome-devtools-mcp, context7, hyperframes and remotion, plus the shadcn MCP
   server connected. If any are missing or not connected, tell me which and why.
   If Context7 isn't connected, tell me so I can reconnect it with /mcp.

2. Load the frontend-design and modern-web-guidance skills now, so they shape
   the work from the start.

3. Look at this repo: is it empty or an existing site? If it's existing, tell me
   the stack, the pages, and anything that would affect a redesign.

4. Reply with a short summary: which tools are ready, what each will be used for
   on this job, and what you found in the repo. Then wait for my design prompt.

How to work on this job:
- frontend-design for the design direction (not a generic template look).
- shadcn/ui for components.
- Context7 for current Next.js, React and Tailwind docs.
- /hyperframes for any hero videos, loops or promo clips.
- Playwright screenshots at phone and desktop sizes, and a Chrome DevTools
  Lighthouse audit, on every page before you show me anything.
- Show me the design direction before building every page.
- Don't invent facts, dates, prices or quotes; use marked placeholders and list
  what you still need from me.
```
