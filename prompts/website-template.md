# Website design brief template

Send this **after** the warm-up in [`website-warmup.md`](website-warmup.md).
Fill in the bracketed parts and delete any section that doesn't apply. It works
for a brand-new site or a redesign; say which in the first line.

```
[Build / Redesign] the website for [BUSINESS NAME]. Work in this repo.

WHAT IT IS
[One or two sentences: what the business does, where, and for whom.]
Highlights to feature: [awards, notable venues or partners, years running, numbers that impress.]
The site's jobs, in order: [e.g. 1. sell tickets  2. get vendors and sponsors to apply  3. show what the event is like].
The main action I want visitors to take: [e.g. "Buy Tickets", "Book Now", "Apply as a Vendor"].

AUDIENCE
[Who visits: e.g. 25–45 locals looking for weekend events; vendors deciding whether to apply.]

STACK
Next.js (App Router) with TypeScript and Tailwind, deployed on Vercel. Fully
responsive and built for phones first. Fast: optimised images, lazy-loaded video,
good Lighthouse scores.
[For a redesign: keep the existing stack and content, and don't break existing URLs;
add redirects for any page that moves.]

LOOK AND FEEL
[Mood in a few words: e.g. "premium and warm, not cheesy", "bold and festive",
"clean and trustworthy".]
Brand colours: [list them, or "take them from the current site/logo"].
References I like: [links to sites or screenshots, and what you like about each].
Avoid: [anything you don't want, e.g. stock-photo look, neon, clutter].

PAGES AND SECTIONS
1. Home: [hero (video, photo or animation), main call to action, key sections].
2. [Page]: [what it must include].
3. [Page]: [what it must include].
4. [Page]: [what it must include].
5. Contact / [Book / Apply]: [form fields wanted, where submissions go].
[Anything that changes often (dates, vendors, menus, pricing) goes in one data file I
can edit easily.]

VIDEO AND MOTION (optional; use /hyperframes)
- [Hero loop: 10–15 second seamless background loop, no text, MP4 plus a still poster.]
- [Promo reel: 20–30 second vertical 9:16 clip for Instagram and TikTok, ending on the
  main call to action and the site address.]

ASSETS
- Logo: [upload, or "design a simple wordmark"]
- Photos: [upload or links; otherwise use clearly marked placeholders]
- Videos: [links]
- Copy/text: [paste it, link the current site, or "write it from what's above"]
- Dates, prices, events: [list them; otherwise mark samples as SAMPLE]
- Socials: [links]
- Contact email/phone: [fill in]

SEO
Target searches: [e.g. "tequila festival Cleveland", "food trucks Cleveland events"].
Add proper titles, descriptions, social share images, a sitemap and structured data
(e.g. Event, LocalBusiness, FAQ) where it fits.

HOW TO WORK
Use the frontend-design skill for the design direction; shadcn/ui, 21st.dev and
Magic UI for components; GSAP for scroll and entrance motion; Context7 for current
Next.js docs; the Figma connector for any figma.com links I give you; /hyperframes
(or fal, if signed in) for hero video. Check every page
with Playwright screenshots and a Chrome DevTools Lighthouse audit before showing me.
Show me the design direction (colours, type, hero mock-up) before building every
page. Don't invent facts, dates, prices or quotes; use marked placeholders and give
me a list of everything you still need from me. When it's done, run it, take
screenshots at phone and desktop sizes, and show me those along with the Lighthouse
scores and any videos.
```

## Tips

- **References matter most.** Two or three links to sites you like, with a word on
  why, steer the design better than any adjective.
- **Real content beats placeholders.** Upload the actual photos and logo if you can.
- **One site per session.** Each site gets a clean start and its own record.
