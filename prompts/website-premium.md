# Premium website session: master prompt

Paste this as the **first** message of a new website session, in the Default
environment with the site's repo selected. It does the warm-up and sets the
premium standard for the whole job. When Claude replies with its summary, send
the filled-in brief from [`website-template.md`](website-template.md).

```
This session is a premium website build for a CyberPro Marketing client. The
standard is high-end agency work: a site that makes people stop scrolling and
that we can win bids with. Don't build anything yet; get set up first.

THE STANDARD
- Cinematic hero: full-bleed video header (seamless loop, muted, autoplay,
  playsinline, poster image, lazy beyond the fold) or an animated/3D hero when
  video doesn't fit. Bold headline with a split-text reveal.
- Motion with intent: GSAP ScrollTrigger for scroll-pinned sections, scrubbed
  timelines, parallax and staggered reveals; Lenis or ScrollSmoother-style smooth
  scroll; micro-interactions on buttons, cards and nav. Every animation respects
  prefers-reduced-motion and never blocks reading or the main call to action.
- Distinctive design: the frontend-design skill's direction, a real type pairing,
  a confident colour system, generous spacing. No generic template look, no
  stock-photo clichés.
- Animated components where they lift the design: 21st.dev and Magic UI
  (animated backgrounds, marquees, text effects, shimmer buttons) on top of
  shadcn/ui.
- Share-ready: a branded Open Graph image for every page, generated in code,
  plus titles, descriptions, sitemap and structured data.
- Still fast: Lighthouse 90+ on mobile for performance, accessibility, best
  practices and SEO, with the video header in place. Compressed video (MP4 H.264
  plus WebM), a still poster for slow connections and phones, optimised images.
- Stack: Next.js (App Router), TypeScript, Tailwind, deployed on Vercel. Phone
  first.

SET UP
1. Run `claude plugin list` and `claude mcp list`. I expect plugins
   frontend-design, modern-web-guidance, playwright, chrome-devtools-mcp,
   context7, gsap-skills, hyperframes and remotion; MCP servers shadcn and magicui
   connected; and the 21st-ui skill. The 21st Dev connector comes from my Claude
   account, so it isn't in `claude mcp list`: check that its tools
   (mcp__21st_Dev__search and others) are available. mux and fal may say "Needs
   authentication"; tell me only if this job needs them. If Context7 or 21st Dev
   isn't connected, tell me so I can fix it with /mcp or claude.ai's connector
   settings.
2. Load the frontend-design, modern-web-guidance, gsap-skills and 21st-ui
   skills now.
3. Look at this repo: empty, or an existing site? If existing, tell me the
   stack, the pages, and anything that affects a redesign. Never break existing
   URLs; add redirects for anything that moves.
4. Reply with a short summary: which tools are ready, what each will do on this
   job, and what you found in the repo. Then wait for my brief.

HOW TO WORK
- Show me the design direction first: palette, type, a hero mock-up and a
  description of the motion, before building every page.
- Hero video: /hyperframes for motion-graphic loops and promo clips; fal for AI
  footage if I've signed it in; my own footage if I upload it. Mux to host
  video-heavy sites.
- Context7 for current Next.js, GSAP and Tailwind docs before writing code
  against them.
- Figma: if I share a figma.com link, read the design with the Figma connector
  and build from it. My Figma seat is view-only, so read, don't edit.
- Before showing me anything: Playwright screenshots at phone (390 px) and
  desktop (1440 px), a Chrome DevTools Lighthouse audit on mobile, and a check
  that the animations run smoothly and switch off with reduced motion.
- Don't invent facts, dates, prices, reviews or quotes; use clearly marked
  placeholders and keep a list of everything you still need from me.
- When it's done, give me the Vercel preview link, the screenshots, the
  Lighthouse scores and any videos.
```
