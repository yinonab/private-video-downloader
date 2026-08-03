# Caption Typography Tracker

Single source of truth for **remaining** caption typography polish after the stable checkpoint (shared baseline + canvas font scale `1.75` + nine-size ladder including XXXL / Mega / Ultra).

Do **not** start typography Phase 2 work from memory — use this file. Update statuses after every approved fix and after manual QA.

---

## Process rules

1. Work **one issue at a time**.
2. Do **not** start the next issue until the current one is **✅ Verified by manual QA**.
3. After every approved fix, run the **Regression checklist** below.
4. Status progression for each issue:

   ```
   ☐ Not started → 🔄 In progress → ☑ Fixed → ✅ Verified by manual QA
   ```

5. Preserve hardened behavior unless an issue explicitly changes it:
   - Hebrew / RTL wrapping policy
   - Shared export baseline (Phase 1 `baselineY`)
   - WidgetSpan preview path structure
   - Existing six font-size bases / preview dp / wrap budgets (frozen)
   - Canvas scale formula: `round(base × min(sx,sy) × 1.75)` (do not change without a dedicated issue)
   - ASS PlayRes bases for the original six sizes

---

## Stable checkpoint (implemented — awaiting formal manual QA)

Do **not** mark ✅ Verified until a full manual QA pass is recorded.

| Item | Status | Notes | Date updated |
| ---- | ------ | ----- | ------------ |
| Shared line `baselineY` for word-highlight canvas | ☑ Fixed | Commit `627a0c1` — words on a line share one baseline instead of per-token ascent. Residual float / optical issues tracked under Rendering. | 2026-08-03 |
| Canvas export font scale `CAPTION_HIGHLIGHT_FONT_SCALE = 1.75` | ☑ Fixed | Fixes tiny export fonts on 1080×1920; XXL ≈ 87px. ASS PlayRes bases unchanged. Deployed to prod; still needs formal regression checklist. | 2026-08-03 |
| Size ladder XXXL / Mega / Ultra | ☑ Fixed | API: `xxx_large` / `mega` / `ultra`; bases 54 / 66 / 80; wrap 16 / 14 / 12; preview dp 24.5 / 30.0 / 36.4. Existing six frozen. Prod api+worker rebuilt 2026-08-03. | 2026-08-03 |
| Preview ↔ export size map for new sizes | ☑ Fixed | Flutter preview map + Look chips + l10n EN/HE. Ultra may still clip on small Look stage — tracked under Preview vs Export. | 2026-08-03 |

---

## Rendering

### Shared word baseline

- **Title:** Shared word baseline — residual verification
- **Description:** Confirm all words in the same visual line truly share one baseline in export (and preview where applicable). Investigate any remaining visual misalignment after Phase 1.
- **Evidence / symptoms:** Some exports/previews may still show slight vertical jitter or uneven word seats even after `baselineY`.
- **Suspected root cause:** Per-glyph metrics, highlight plate geometry, font ascent/descent differences, or preview WidgetSpan vs canvas draw path drift.
- **Status:** ☐ Not started
- **Notes:** Phase 1 code is in (`layout` / `renderPlate` / preview after-span). This issue is **verification + residual fix**, not a rewrite of the shared-baseline approach.
- **Date updated:** 2026-08-03

### Optical vertical alignment

- **Title:** Optical vertical alignment (float after shared baseline)
- **Description:** Investigate why some words still appear to float even when the mathematical baseline is shared.
- **Evidence / symptoms:** Highlighted or neighboring words look optically high/low relative to the line; yellow highlight plates may read as vertically “loose.”
- **Suspected root cause:** Optical center vs baseline; plate padding; bold/weight metrics; Hebrew vs Latin glyph boxes; outline/shadow drawing offsets.
- **Status:** ☐ Not started
- **Notes:** Do not conflate with “baseline not shared.” Fix only after shared-baseline residual verification.
- **Date updated:** 2026-08-03

---

## Typography

### Optical centering of caption blocks

- **Title:** Optical centering of caption blocks
- **Description:** Investigate whether mathematically centered captions are visually centered on screen.
- **Evidence / symptoms:** Blocks can feel shifted left/right or up/down despite center math, especially RTL Hebrew and large sizes.
- **Suspected root cause:** Safe margins, ASS `MarginL/R/V`, highlight plate extents, asymmetric glyph side bearings, preview stage letterboxing.
- **Status:** ☐ Not started
- **Notes:** Measure Preview and Export separately before changing margins.
- **Date updated:** 2026-08-03

### Line balancing

- **Title:** Line balancing across valid wraps
- **Description:** Improve choice among multiple valid wrapping solutions; avoid very short last lines.
- **Evidence / symptoms:** Two-line cues with a long first line and a one-word (or very short) second line; uneven visual weight.
- **Suspected root cause:** Greedy wrap / char budgets (`CAPTION_MAX_CHARS_PER_LINE`) without balance scoring; time-chunking interaction with wrap.
- **Status:** ☐ Not started
- **Notes:** Hebrew multi-word-per-line policy must be preserved. Existing six wrap budgets are frozen unless this issue explicitly revises policy.
- **Date updated:** 2026-08-03

### Caption block width

- **Title:** Caption block safe width
- **Description:** Re-evaluate safe width so lines use available space without unnecessary wrapping.
- **Evidence / symptoms:** Early wraps at large sizes; unused horizontal space inside safe margins.
- **Suspected root cause:** Conservative `CAPTION_MARGIN_H` / max line width / wrap char budgets; uniform scale interaction on portrait canvases.
- **Status:** ☐ Not started
- **Notes:** Coordinate with line balancing; do not break RTL or ≤2-line policy without explicit approval.
- **Date updated:** 2026-08-03

### Line spacing

- **Title:** Line spacing for large caption sizes
- **Description:** Review line-height / inter-line gap for XL→Ultra so multi-line cues remain readable and not cramped or airy.
- **Evidence / symptoms:** Large sizes (esp. Mega / Ultra) may look stacked too tightly or too loose; preview clip risk when line box grows.
- **Suspected root cause:** Fixed line metrics scaled only with font size; plate height; Flutter `StrutStyle` / WidgetSpan vs canvas line advance.
- **Status:** ☐ Not started
- **Notes:** Cross-check Look Preview stage height (~82px content) vs Ultra two-line height.
- **Date updated:** 2026-08-03

### Overall typography polish

- **Title:** Overall typography polish
- **Description:** Holistic pass on padding, spacing, visual rhythm, and readability after structural issues above are verified.
- **Evidence / symptoms:** Captions feel “almost right” but lack finished rhythm; inconsistent gaps between plate, text, and frame edges.
- **Suspected root cause:** Accumulated constants tuned independently (margins, plate padding, outline, highlight inset).
- **Status:** ☐ Not started
- **Notes:** Last typography bucket — only after centering, width, balancing, and line spacing decisions land.
- **Date updated:** 2026-08-03

---

## Preview vs Export

### Preview / Export visual parity

- **Title:** Preview vs Export remain visually identical
- **Description:** After every typography change, Preview (Flutter overlay / Look editor) and Export (canvas highlight or ASS) must stay visually matched.
- **Evidence / symptoms:** Historical: export fonts looked tiny vs preview before `1.75` scale; Ultra may clip in Look Preview while export is fine; any future metric change can desync paths.
- **Suspected root cause:** Dual pipelines (WidgetSpan preview vs canvas/ASS export); separate size maps; different stage heights.
- **Status:** ☐ Not started *(standing gate — re-check on every fix)*
- **Notes:** Standing regression gate, not a one-shot bug. Record failures under the specific issue that caused drift.
- **Date updated:** 2026-08-03

### Ultra Look Preview clipping (known risk)

- **Title:** Ultra size clips on Look Preview stage
- **Description:** Look editor preview stage may be too short for Ultra two-line captions (~91px vs ~82px content height).
- **Evidence / symptoms:** Possible bottom/top clip or overflow in Look Preview at Ultra; export may still look correct.
- **Suspected root cause:** Fixed Look preview stage height vs larger preview dp (36.4) and two-line strut.
- **Status:** ☐ Not started
- **Notes:** Device QA to confirm; fix is UI stage/layout, not export bases, unless parity requires both.
- **Date updated:** 2026-08-03

---

## Ops / deploy lesson (closed)

### Production API schema lag for new sizes

- **Title:** Production rejected `xxx_large` / `mega` / `ultra`
- **Description:** APK showed new chips but API returned localized `UNSUPPORTED_CAPTIONS_FONT_SIZE` (“גודל הכתוביות הזה לא נתמך”) until backend image rebuild.
- **Evidence / symptoms:** Device error on XXXL/Mega/Ultra; Jul 30 image lacked new enums in `edit.schemas` / dist.
- **Suspected root cause:** Mobile shipped new API values before api+worker image included schema + `FONT_SIZES` mappings.
- **Status:** ☑ Fixed
- **Notes:** api + worker rebuilt 2026-08-03 with matching image; enums present in src+dist. Treat as ✅ Verified only after device QA confirms XXXL/Mega/Ultra no longer error.
- **Date updated:** 2026-08-03

---

## Regression checklist

After **every** approved typography fix, verify:

| Check | Pass? | Notes |
| ----- | ----- | ----- |
| Hebrew RTL | ☐ | |
| Word Highlight | ☐ | |
| Box Highlight | ☐ | |
| Color Highlight | ☐ | |
| Shared baseline | ☐ | |
| Preview | ☐ | |
| Export | ☐ | |
| Large caption sizes (XL / XXL) | ☐ | |
| New XXXL / Mega / Ultra sizes | ☐ | |
| Analyze flow | ☐ | |
| Download flow | ☐ | |
| Export flow | ☐ | |

Copy a dated checklist subsection under the issue when marking **✅ Verified**.

---

## Suggested work order

1. Shared word baseline — residual verification  
2. Optical vertical alignment  
3. Preview / Export parity gate (ongoing) + Ultra Look clip if confirmed  
4. Optical centering of caption blocks  
5. Caption block width  
6. Line balancing  
7. Line spacing (large sizes)  
8. Overall typography polish  

---

## Update log

| Date | Change |
| ---- | ------ |
| 2026-08-03 | Tracker created at stable checkpoint (baseline + `1.75` scale + nine sizes). Remaining polish issues seeded as ☐ Not started. |
| 2026-08-03 | Checkpoint items set to ☑ Fixed only — no ✅ Verified until formal manual QA. |
