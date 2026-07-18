# web-playground

## Goal

An interactive isnow playground at `tsvsheet.com/functions/isnow/playground/` (in `tsvsheet/www.tsvsheet.com`), powered by `@tsvsheet/isnow`.

## Requirements

- R1. A live "is it now?" panel: an isnow input, real-time verdict against the visitor's clock and zone, canonical form, English explanation, and the next 5 occurrences.
- R2. A builder: per-field inputs (the builder vocabulary) that compose an isnow live, with copy-to-clipboard.
- R3. A gallery of expressive examples (the README set and beyond) that load into the panel on click.
- R4. The JS library is bundled at build time from the sibling checkout (no CDN, no network calls); the page fits the site's existing Hugo layout and deploys through its existing Cloudflare pipeline.

## Acceptance criteria

- AC1. `make -C www.tsvsheet.com` site build succeeds with the page included; no console errors in the built page.
- AC2. Typing `M,W,F noon` shows the correct canonical form, verdict, and occurrences in the visitor's zone.
- AC3. Builder output round-trips: composing then parsing yields the same canonical form.
