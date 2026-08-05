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

## Typography (verified composition)

### Line balancing

- **Title:** Caption block balancing (line balancing)
- **Description:** Improve choice among multiple valid wrapping solutions; avoid very short last lines. Produce CapCut-/Captions-like visual balance without shortening captions.
- **Evidence / symptoms:** Greedy wrap fills line 1 to max width then dumps remainder on line 2 (e.g. long first line + short question on second).
- **Suspected root cause:** Greedy wrap / char budgets (`CAPTION_MAX_CHARS_PER_LINE`) without balance scoring; time-chunking interaction with wrap; Preview may wrap independently of export.
- **Status:** ✅ Verified by manual QA
- **Notes:** Backend/export balancing verified by manual QA. Source of Truth is stable. Existing rendering behavior preserved. Preview parity remains a separate future task.
- **Date updated:** 2026-08-05

### Backend/export line-break Source of Truth

- **Title:** Backend/export line-break Source of Truth
- **Description:** Unify ASS, highlight timing, and highlight plate under one greedy `breakCaptionLines` SoT; plate consumes forced `lines[]` (no flatten / no pixel re-wrap for breaks).
- **Evidence / symptoms:** Multiple independent wrap engines caused Preview/Export and ASS/plate divergence risk.
- **Suspected root cause:** Duplicated greedy wrap + plate `wrapTokensToLines` + newline flatten.
- **Status:** ✅ Verified by manual QA
- **Notes:** Backend/export consumers (ASS, highlight timing, highlight plate) now share a single logical line-break source (`breakCaptionLines` in `captionLineBreak.ts`). Manual QA: stable shared breaks; no independent wrap decisions; no newline-flatten / baseline / plate-centering / export regressions. Preview still uses Flutter softWrap (Phase B). Caption block balancing v1 also lives in this SoT.
- **Date updated:** 2026-08-04

---

## Typography Polish (future roadmap)

Do **not** start these until explicitly approved. Backend/export composition (SoT + balancing) is the current verified checkpoint.

### Preview parity (Phase B)

- **Title:** Preview parity (Phase B)
- **Description:** Flutter Preview should consume the same logical `lines[]` from the shared break algorithm (Dart twin or equivalent) instead of engine `softWrap`.
- **Status:** ☐ Not started
- **Notes:** Intentionally deferred. Export SoT + balancing verified without Preview twin.
- **Date updated:** 2026-08-05

### Word spacing polish

- **Title:** Word spacing polish
- **Description:** Review inter-word gaps / tokenGap for large sizes and RTL readability.
- **Status:** ☐ Not started
- **Notes:** Future polish only.
- **Date updated:** 2026-08-05

### Optical block centering

- **Title:** Optical block centering
- **Description:** Investigate whether mathematically centered caption blocks are optically centered (esp. Hebrew RTL, large sizes).
- **Status:** ☐ Not started
- **Notes:** Formerly under Typography; deferred to this roadmap.
- **Date updated:** 2026-08-05

### Line-height review

- **Title:** Line-height review
- **Description:** Review inter-line gap / line-height for XL→Ultra multi-line cues.
- **Status:** ☐ Not started
- **Notes:** Includes Look Preview stage height vs Ultra risk.
- **Date updated:** 2026-08-05

### Advanced semantic balancing

- **Title:** Advanced semantic balancing
- **Description:** Phrase-aware / punctuation-aware splits beyond v1 char-score heuristics.
- **Status:** ☐ Not started
- **Notes:** Only after v1 balancing remains satisfactory; do not reopen v1 without regression.
- **Date updated:** 2026-08-05

### Typography fine tuning

- **Title:** Typography fine tuning
- **Description:** Holistic padding, spacing, visual rhythm, and readability pass.
- **Status:** ☐ Not started
- **Notes:** Last bucket after structural polish items above.
- **Date updated:** 2026-08-05

---

## Preview vs Export (standing gate)

### Preview / Export visual parity

- **Title:** Preview vs Export remain visually identical
- **Description:** Standing regression gate after typography changes.
- **Status:** ☐ Not started *(standing gate — see Typography Polish → Preview parity Phase B)*
- **Notes:** Export path verified for SoT + balancing; Preview still softWrap until Phase B.
- **Date updated:** 2026-08-05

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

**Verified (do not reopen without regression):** Shared baseline → Optical vertical alignment → Backend/export line-break SoT → Caption block balancing.

**Next (Typography Polish — wait for approval):**
1. Preview parity (Phase B)  
2. Word spacing polish  
3. Optical block centering  
4. Line-height review  
5. Advanced semantic balancing  
6. Typography fine tuning  

Standing gate: Preview / Export visual parity (tracks Phase B).

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
| 2026-08-04 | **Caption block balancing** → ☑ Fixed (v1 score inside `captionLineBreak.ts`; not ✅ Verified; Preview Phase B pending). |
| 2026-08-05 | **Caption block balancing** → ✅ Verified by manual QA. Added **Typography Polish** future roadmap (Preview Phase B, word spacing, optical block centering, line-height, advanced balancing, fine tuning). Wait for approval before next typography task. |
