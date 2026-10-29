# Yoerger Renovations website

Static marketing site for Yoerger Renovations, LTD. (Ryan Yoerger's remodeling business, Kent, Ohio).
Live at https://www.yoergerrenovations.com, served by GitHub Pages from `main:/docs`. Built by Jordan
(Ryan's brother), who maintains it. Goal: a motion-rich, SEO-strong site where adding new job photos
is a folder drop, no code. Read `README.md` too; it is the owner-facing how-to and is accurate.

## Layout

- `photos/<project>/` - content model. One folder per job: `project.txt` (title, category, location,
  summary, featured, optional cover/order) plus photos named `01 Caption text.jpg`. The filename words
  become caption, alt text and SEO description. `NN Caption (before).jpg` next to a photo = drag slider.
  Categories: kitchens | bathrooms | basements | decks | living-rooms. Folder names start with the category.
- `src/data/site.json` - business facts, `heroOrder`, `bentoOrder`, service-area `areas`, `reviews`,
  `homeVideo`, `formEndpoint`, `indexNowKey`, `customDomainLive` (true since go-live).
- `src/data/services.json` - the six service pages (five rooms + handyman) copy, highlights, FAQs.
- `src/data/home-faq.json` - homepage FAQ (also emitted as FAQPage JSON-LD).
- `src/templates/*.html` - page templates; `src/css/site.css`; `src/js/site.js`; `src/icons/` (vendored
  Phosphor SVGs used as `{{icon-name}}` tokens); `src/fonts/` (self-hosted woff2); `src/img/` (logo, headshot).
- `src/static/` - copied verbatim (recursively) into `docs/`: `/review` redirect, `/post-maker/`
  (unlisted, noindex canvas tool for social posts), redirect stubs for old Squarespace URLs
  (`/home`, `/contact`, `/services-store/...`), robots.txt, manifest, `video/room-by-room.mp4` + poster.
- `tools/quote-mailer.gs` - Google Apps Script web app that emails quote-form submissions with photos.
- `build.ps1` - the generator. `docs/` - OUTPUT, committed, this IS the website. `site/` - empty, unused.
- `artifact/`, `artifact-files.json` - flat preview copy for a claude.ai artifact (gitignored).
- `brag-output*/` - promo video projects and renders (gitignored, see "Not in the repo").

## Commands (Windows PowerShell 5.1 + .NET System.Drawing; no Node needed)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1            # photos + src -> docs/
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Artifact  # also writes artifact/
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Force     # re-encode every image
powershell -NoProfile -ExecutionPolicy Bypass -File serve.ps1 -Port 8765 # preview docs/ at localhost:8765
```

Double-click wrappers: `Build Site.cmd`, `Preview Site.cmd`, `Publish.cmd` (build, then
`git add -A`, commit "Update site photos and content", `git push`; Pages updates in a minute or two).
Build resizes photos to 1400/700 px JPEGs (skips already-processed ones), renders home, six service
pages, work gallery, 404, sitemap (with image + video entries), llms.txt, JSON-LD, and the post-maker
`photos.json`. After deploys, optionally ping IndexNow (`https://api.indexnow.org/indexnow?url=<page>&key=<indexNowKey>`).

## Decisions and preferences (from Jordan - keep these)

- Based in **Kent, OH 44240, not Stow** (corrected 2026-09-30). Stow stays in the served-towns list.
- Service area is **Summit and Portage counties only. No Cleveland / Cuyahoga County work**; the copy says so.
  The phone area code is not the service area. The `areas` town list is a best guess; edit freely.
- Six services: kitchens, bathrooms, basements, decks, living rooms, plus "Handyman services available".
- Brand: forest green (only accent) + brass (ornament only). Fonts: Big Shoulders Display, Hanken Grotesk,
  IBM Plex Mono. Header 80 px. All quote buttons are green `btn-primary`; no brass buttons.
- Logo integrated seamlessly at the top (build makes transparent `logo*.png` + small `logo-head*.png`).
- Nav underline (brass) follows the section/tab in view.
- Hero: 4:3 frame inside the column, photos never crop or bleed. Non-4:3 shots (all bathroom photos are
  portrait) show whole over a blurred copy (`Fit-Photo` in build.ps1). Wipe-in, no Ken Burns.
  Rotation order = `heroOrder`: bathroom first, **kitchen LAST**.
- Five Rooms bento: basements is the big tile, kitchen in the small slot under bathrooms. DOM order =
  `bentoOrder`; the grid areas in `site.css` must match it.
- Page always opens at the top (scrollRestoration manual; in-page links leave no `#hash`).
- Homepage video `#tour` sits right under the hero: autoplays MUTED when >=50% visible, pauses when it
  leaves, "Sound on" pill; user pause/unmute takes over; skipped for reduced motion / Save-Data.
  To swap: replace the two files in `src/static/video/` and update `homeVideo` in site.json.
- SEO (2026-10-11): H1 "Home Remodeling in Kent, Ohio" (eyebrow-styled), "<service> in Kent, Ohio"
  kickers, keyword-first titles, LocalBusiness/FAQPage/VideoObject schema, image sitemap, robots.txt
  welcomes AI crawlers, llms.txt, 404 noindex. Later hero slides lazy-load via `data-src`.
- Mobile: 44 px targets under `(pointer:coarse),(max-width:1023px)`, labels >= 13 px, menu scrolls inside
  itself, compact header in short landscape.

## Quote form

Form posts text/plain JSON (photos shrunk in-browser to 2000 px JPEG, max 8 files / 18 MB) to the Apps
Script web app URL in `formEndpoint`. Blank `formEndpoint` = photo field hidden + Copy/Text/Email
fallback. If `tools/quote-mailer.gs` is edited, redeploy as a **new version of the same deployment**
(Deploy > Manage deployments > Edit) or the `/exec` URL changes. Setup steps are in README.md.

## Gotchas

- PowerShell 5.1: don't name a function `H` (Get-History alias); `$home` is read-only;
  `ConvertFrom-Json` returns a JSON array as one object (unroll with `| ForEach-Object { $_ }`).
- Write files as UTF-8 **without BOM** (build.ps1 uses `UTF8Encoding($false)`); `Set-Content -Encoding utf8`
  in 5.1 adds a BOM.
- In an embedded/background browser pane, IntersectionObserver and rAF only fire when the pane paints;
  take a screenshot to force a frame when testing the video or scroll effects.
- Google Search Console deep links (inspect?...) 404 when shared; give manual navigation steps instead.
- `.gitattributes` forces CRLF for .cmd/.ps1; keep it.

## Not in the repo / external services

- DNS at Squarespace Domains: apex A records to GitHub Pages IPs, `www` CNAME to the Pages host,
  `docs/CNAME` = www host; HTTPS enforced in Pages settings. Leave the registrar's existing TXT/email-security
  presets and the Search Console verification TXT alone. Keep domain auto-renew on.
- Google Apps Script mailer deployment, Google Search Console (domain property), Bing Webmaster,
  Google Business Profile: all managed in the web consoles, not here.
- `brag-output/` (23 s promo reel) and `brag-output-2026-09-29-160547/` (Facebook 4:5 + 9:16 ad, synth
  soundtrack in `work/synth.mjs`) are gitignored HyperFrames projects; copy them separately if needed.
- The claude.ai artifact preview was published from the old Claude account; republish from `artifact/`
  (run `build.ps1 -Artifact`) to get a new one.
- Original full-size camera photos beyond those in `photos/` live with Jordan/Ryan.

## New machine

- `.claude/launch.json` (gitignored, local only) hardcodes old paths at lines 7 and 13; recreate it with
  repo-relative `serve.ps1` if using a preview launcher. `brag-output/composition-brief.md` lines 15, 90, 101
  reference old absolute paths (docs only, gitignored).
- Git push needs GitHub auth for the repo owner (Git Credential Manager or `gh auth login`).

## Open items

- The Facebook ad cut in `brag-output-2026-09-29-160547/` still says Stow; needs a re-render saying Kent.
- No reviews in `site.json` yet (Kind Words section appears automatically once one is added); consider
  linking the Google review profile.
- No street address in schema (by choice so far). Service-area town list unconfirmed.
- Four gallery photos (old-site "Updated ... pic", 1024 px) look AI-retouched; replace with camera originals.
- Idea discussed, not built: AI "re-imagine your room" module (would need a serverless proxy such as a
  Cloudflare Worker holding the image-model key, bot check, rate and spend caps).
- Possible: embed the deck transformation or brand film videos on the Decks page / homepage.
