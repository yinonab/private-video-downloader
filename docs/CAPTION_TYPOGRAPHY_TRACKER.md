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
- **Status:** ✅ Verified by manual QA
- **Notes:** Shared baseline verified. Plate optical centering improved without clipping or baseline regression. Minor optical variance between Hebrew glyphs is accepted and no further work is planned unless future regressions appear. Implementation: `highlightPlateBoxFromBaseline` (font bounds + active ink floor); text draw Y / `baselineY` / layout boxes / Preview unchanged.
- **Date updated:** 2026-08-04

### Optical vertical alignment

- **Title:** Optical vertical alignment (float after shared baseline)
- **Description:** Investigate why some words still appear to float even when the mathematical baseline is shared.
- **Evidence / symptoms:** Highlighted or neighboring words look optically high/low relative to the line; yellow highlight plates may read as vertically “loose.”
- **Suspected root cause:** Optical center vs baseline; plate padding; bold/weight metrics; Hebrew vs Latin glyph boxes; outline/shadow drawing offsets.
- **Status:** ✅ Verified by manual QA
- **Notes:** No remaining rendering defect. All tokens share one alphabetic `baselineY`; outline and plate do not alter text Y. Remaining visual differences are natural Hebrew glyph variance; no further rendering work is planned unless future regressions appear.
- **Date updated:** 2026-08-04

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

- **Title:** Caption block balancing (line balancing)
- **Description:** Improve choice among multiple valid wrapping solutions; avoid very short last lines. Produce CapCut-/Captions-like visual balance without shortening captions.
- **Evidence / symptoms:** Greedy wrap fills line 1 to max width then dumps remainder on line 2 (e.g. long first line + short question on second).
- **Suspected root cause:** Greedy wrap / char budgets (`CAPTION_MAX_CHARS_PER_LINE`) without balance scoring; time-chunking interaction with wrap; Preview may wrap independently of export.
- **Status:** 🔄 In progress
- **Notes:** Backend/export line-break SoT completed (Phase A — still greedy, no balancing). Balancing algorithm not implemented. Flutter Preview still uses engine softWrap — Phase B Preview parity required before this item can be ✅ Verified. Do not treat Phase A as product Preview/Export parity.
- **Date updated:** 2026-08-04

### Backend/export line-break Source of Truth

- **Title:** Backend/export line-break Source of Truth
- **Description:** Unify ASS, highlight timing, and highlight plate under one greedy `breakCaptionLines` SoT; plate consumes forced `lines[]` (no flatten / no pixel re-wrap for breaks).
- **Evidence / symptoms:** Multiple independent wrap engines caused Preview/Export and ASS/plate divergence risk.
- **Suspected root cause:** Duplicated greedy wrap + plate `wrapTokensToLines` + newline flatten.
- **Status:** ✅ Verified by manual QA
- **Notes:** Backend/export consumers (ASS, highlight timing, highlight plate) now share a single logical line-break source (`breakCaptionLines` in `captionLineBreak.ts`). Manual QA: stable shared breaks; no independent wrap decisions; no newline-flatten / baseline / plate-centering / export regressions. Preview still uses Flutter softWrap (Phase B). Balancing not included — see Caption block balancing.
- **Date updated:** 2026-08-04

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
| 2026-08-03 | **Shared word baseline — residual verification** → 🔄 In progress (investigation only; no code changes). |
| 2026-08-03 | **Shared word baseline — residual verification** → ☑ Fixed (plate-only optical centering; not ✅ Verified). |
| 2026-08-04 | **Shared word baseline — residual verification** → ✅ Verified by manual QA (plate centering + baseline; Hebrew glyph variance accepted). |
| 2026-08-04 | **Optical vertical alignment** → 🔄 In progress (investigation only; no code yet). |
| 2026-08-04 | **Optical vertical alignment** → ✅ Verified by manual QA (natural Hebrew glyph variance accepted; no further rendering work unless regressions). |
| 2026-08-04 | **Caption block balancing (line balancing)** → 🔄 In progress (investigation only; no code yet). |
| 2026-08-04 | **Backend/export line-break Source of Truth** → ☑ Fixed (Phase A greedy SoT; Preview parity + balancing still pending). |
| 2026-08-04 | **Caption block balancing** remains 🔄 In progress (SoT done; balancing + Preview Phase B not done). |
| 2026-08-04 | **Backend/export line-break Source of Truth** → ✅ Verified by manual QA. Caption block balancing remains 🔄 (composition). |
