# Caption highlight overlay — PoC (V3.4A)

Isolated prototype for Creator Captions word highlight. **Not used by production burn-in.**

## Renderer

**[@napi-rs/canvas](https://github.com/Brooooooklyn/canvas)** — Skia-backed Node bindings:

- Hebrew RTL via `ctx.direction = 'rtl'` and explicit right-to-left token placement
- `measureText` / `fillText` per token (independent normal vs active colors)
- `roundRect` for rounded / pill highlight boxes
- PNG with alpha (transparent background)
- Prebuilt binaries for Linux (Docker) and Windows; no headless browser

## Run

```bash
cd backend
npm run poc:caption-highlight
```

Outputs: `backend/.poc-output/caption-highlight/` (PNGs + optional MP4 + `manifest.json`).

## Font

PoC downloads **Heebo** to `backend/fonts/poc/` if not found. Production Docker path: `/usr/share/fonts/truetype/linkclip/Heebo-Variable.ttf`.

Override: `LINKCLIP_POC_FONT_HEEBO=/path/to/font.ttf`

## Docker (future integration)

Add to production image when wiring V3.4B:

- `@napi-rs/canvas` npm dependency (native module; `npm ci` on target arch)
- No Puppeteer/Chromium
