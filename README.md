# Yoerger Renovations website

Static site for https://www.yoergerrenovations.com, generated from a folder of photos and two small
data files by `build.ps1`. No installs are needed: PowerShell 5.1 and .NET (both already on Windows) do
all the image resizing and page assembly.

```
yoerger-renovations\
  photos\                      <- ONE FOLDER PER PROJECT (this is the only place Ryan needs to touch)
    decks-pool-view\
      project.txt              <- title, category, summary, featured
      01 Deck and railing overlooking the pool.jpg
      02 Brown composite decking with white railing.jpg
  src\
    data\site.json             <- phone, email, service area list, form endpoint, reviews
    data\services.json         <- the five service pages: copy, highlights, FAQs, hero photo
    templates\ css\ js\ img\   <- page templates, stylesheet, script, logo + headshot
  build.ps1                    <- the generator
  Build Site.cmd               <- double-click: rebuilds docs\
  Publish.cmd                  <- double-click: rebuild + git commit + push (GitHub Pages)
  docs\                        <- OUTPUT. This folder is the website. Deploy it as-is.
  artifact\                    <- optional flat copy used for the claude.ai preview (build with -Artifact)
```

## Adding new work photos (the whole workflow)

1. Make a folder inside `photos\` for the job. Start the folder name with the room type so it sorts
   nicely, for example `kitchens-white-shaker-lakewood`. Lowercase, dashes, no spaces.
2. Copy the phone photos in (JPEG or PNG; HEIC needs to be exported as JPEG first, or set the iPhone
   camera to Settings > Camera > Formats > Most Compatible).
3. Rename each photo to a short caption with a number in front:
   `01 White shaker cabinets and quartz island.jpg`. The number sets the order, the words become the
   caption, the alt text and the search-engine description. Photo 01 is the cover unless `cover =` says otherwise.
4. Drop in a `project.txt` (copy one from another folder) and fill it in:

   ```
   title = White shaker kitchen with a quartz island
   category = kitchens          (kitchens | bathrooms | basements | decks | living-rooms)
   location = Lakewood
   summary = One or two sentences about what was done.
   featured = yes               (featured projects show on the home page, up to nine)
   cover = 01                   (optional)
   order = 10                   (optional, lower numbers first)
   ```

5. Double-click `Build Site.cmd`. It resizes every new photo (1400px and 700px JPEGs, camera
   orientation fixed), rebuilds every page, the gallery, the filters, the sitemap and the structured data.
   Photos that were already processed are skipped, so rebuilds are quick.
6. Double-click `Publish.cmd` (once the GitHub Pages setup below is done). Live in a minute or two.

Before-and-after: put a second file next to a photo with the same name plus ` (before)`, for example
`03 New tub and surround.jpg` and `03 New tub and surround (before).jpg`. That tile becomes a drag slider.

## Editing words, phone, area, reviews

- `src\data\site.json`: phone, email, Facebook link, service-area towns (please edit `areas` to match
  where Ryan really works), and `reviews` (paste real reviews and a Kind Words section appears).
- `src\data\services.json`: everything on the five service pages. Plain text; keep the JSON quotes intact.
- `src\templates\home.html`: hero headline, process steps, about copy.

## Contact form

Submissions are emailed by a small Google Apps Script (`tools\quote-mailer.gs`, free, runs in the Gmail
account). Visitors can attach up to 8 photos or PDFs; the browser shrinks photos to 2000px JPEGs first, so
they arrive as normal email attachments. Replying to the email answers the customer.

Setup, once, signed in to the Google account that should send the emails (Ryan's Gmail):

1. Go to https://script.google.com, click New project, replace the sample code with the contents of
   `tools\quote-mailer.gs`, and save. (Change `OWNER_EMAIL` at the top if the emails should go elsewhere.)
2. Choose `testSend` in the toolbar and click Run. Approve the permissions; because it is your own script,
   Google shows "Google hasn't verified this app", so click Advanced, then Go to the project. A test
   email with a tiny test photo arrives.
3. Deploy > New deployment > Select type: Web app. Execute as: Me. Who has access: Anyone. Deploy.
4. Copy the Web app URL (ends in `/exec`) into `formEndpoint` in `src\data\site.json`, rebuild, publish.

If you edit the script later, use Deploy > Manage deployments > Edit > Version: New version so the URL
stays the same. While `formEndpoint` is blank the photo field is hidden, and submitting shows the visitor
their message with Copy / Text Ryan / Email Ryan buttons instead.

## Hosting on GitHub Pages (free) and pointing the domain

The repo is `github.com/jgyoerger1/yoerger-renovations`, and Pages serves the `docs` folder from `main`.
Until the domain is moved, the preview lives at `https://jgyoerger1.github.io/yoerger-renovations/`.
`customDomainLive` in `src\data\site.json` is `false` for that phase: no `CNAME` file is written and the
404 page uses the `/yoerger-renovations/` base path.

Cutover day:

1. At the domain registrar (Squarespace Domains if the domain was bought there), set DNS:
   - `www`  CNAME  `jgyoerger1.github.io`
   - apex `@`  A records  185.199.108.153, 185.199.109.153, 185.199.110.153, 185.199.111.153
2. Set `customDomainLive` to `true` in `site.json`, then run `Publish.cmd`. That writes `docs\CNAME`
   with `www.yoergerrenovations.com`, which is how GitHub learns the custom domain.
3. Repo Settings > Pages: confirm the custom domain shows a green check, then turn on "Enforce HTTPS"
   once the certificate is issued (usually within an hour).
4. Cancel the Squarespace site subscription after the new site is confirmed live.

Any static host works the same way (Cloudflare Pages, Netlify): point it at the `docs` folder.

## After launch: search engine checklist

- Add the site to Google Search Console and Bing Webmaster Tools; submit `https://www.yoergerrenovations.com/sitemap.xml`.
- Create or claim the Google Business Profile with the same name, phone and email; link it to the site.
- Add a street address or at least a city to `site.json` and the schema once Ryan decides what to publish.
- Ask happy customers for Google and Facebook reviews; paste the best into `site.json`.

## Notes for whoever maintains this

- Four photos in the current gallery came from the old site at 1024x1536 or 1024x1024 and look
  AI-retouched (the "Updated ... pic" files). Replace them with camera originals when available.
  The old site also contained one obviously AI-generated bathroom render; it was left out.
- `build.ps1 -Artifact` also writes `artifact\`, a flat copy (`kitchen-remodeling.html` instead of
  `kitchen-remodeling/`) with CSS and JS inlined, for previewing as a claude.ai artifact.
- `build.ps1 -Force` re-encodes every image.
