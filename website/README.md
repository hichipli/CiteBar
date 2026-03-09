# CiteBar Website

Static marketing site for CiteBar.

## Stack

- Plain HTML/CSS/JS (no framework lock-in)
- Runtime GitHub Releases lookup for latest version + direct DMG URL
- Custom domain managed in `CNAME` (`www.citebar.org`)

## Local preview

```bash
cd /Users/chip/GitHub/CiteBar/website
python3 -m http.server 4173
```

Open: `http://localhost:4173`

## Production domain

- Primary URL: `https://www.citebar.org/`
- `website/CNAME` is deployed by GitHub Actions with the site artifact.

## What to update if you move domains

1. Update canonical URL in `index.html`.
2. Update `og:url`, `og:image`, and JSON-LD `url` in `index.html`.
3. Update `Sitemap:` in `robots.txt` and URL entries in `sitemap.xml`.
4. Update `start_url` in `site.webmanifest`.

## Release data source

`app.js` calls:

`https://api.github.com/repos/hichipli/CiteBar/releases/latest`

It picks the best `.dmg` asset and updates:

- Latest version
- Published date
- Download buttons (direct asset URL)
