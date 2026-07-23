# LinkClip Fix Tracking

## Purpose

Track the current cleanup/fix phase for LinkClip, including what is done, what remains open, what was intentionally deferred, and validation status after each fix.

This file is the **single source of truth** for the prioritized fix list. Update it after every fix or meaningful investigation.

---

## Current Stable Baseline

Preserve the following hardened behavior — do not regress:

* **Active operation resume** is done and should be preserved.
* **Download** does not break after background/resume.
* **Edit/export** does not break after background/resume.
* **Polling** resumes on screen dispose / app `resumed` / cold start.
* **Duplicate jobs** are prevented.
* **OperationWakelock** works while the app is foreground-visible.
* Foreground-only wake lock; released on success/failure/cancel/back/dispose.

Related implementation: `ActiveOperationStore`, `OperationController`, `operation_wakelock.dart`, download status + edit screen wiring.

---

## Fix List

| ID | Area | Priority | Status | Summary | Last Updated | Notes |
| -- | ---- | -------- | ------ | ------- | ------------ | ----- |
| F1 | Captions | High | Open | Hebrew/RTL captions can wrap badly (unnatural line breaks / word stacking). Fix preview and final export behavior. | 2026-07-20 | Preview + burn/export consistency |
| F2 | Thumbnails / preview | High-Medium | Failed QA / Partially Done | Prior “cover + image aspect” still failed device QA: Captain Marvel TikTok thumb is a **portrait canvas with baked letterbox bars**. Aspect-from-bitmap alone kept a portrait tile. New fix: letterbox content detection + crop + landscape tile from **content** aspect. Device QA pending. | 2026-07-21 | Large preview screens unchanged |
| F3 | Edit performance | High | Open | Edit/export (especially with captions) can take a long time. Need instrumentation before optimization. | 2026-07-20 | Measure first; no premature optimization |
| F4 | Progress UX / ETA | Medium-High | Partially Done | Progress reliability improved; still need clearer elapsed time, stages, and honest ETA. | 2026-07-20 | Build on `edit_progress_display` |
| F5 | External floating window | Medium | Deferred | User wants a Moovit-like floating window outside the app during long ops (likely Android PiP). Not MiniCard. Needs separate design. | 2026-07-20 | No PiP / MiniCard until designed |
| F6 | Unified final-file readiness | High | Partially Done | **Cache-only auto-finalize:** `downloadJobMedia` / `ensureLocalJobMedia` no longer MediaStore-publish. Public Downloads copy only on explicit Save (`publishLocalJobMediaToDevice`). Share/Open use app cache. Device QA pending: confirm no public file before Save; Share after ready does not create another public copy. | 2026-07-22 | No DownloadManager / PiP / MiniCard |
| F7 | Analyze / caption draft resume | Low-Medium | Deferred | Analyze and caption draft are not truly resumable (no async backend jobIds). | 2026-07-20 | Needs product/API design |
| F8 | AudioEditScreen parity | Medium-Low | Open | Align AudioEditScreen with OperationWakelock / ActiveOperationStore / resume / progress behavior. | 2026-07-20 | Parity with video edit |
| F9 | Clean UI / large-preview | High | Partially Done | Edit/analyze/status large-preview kept. Home list: **aspect-aware project tiles** (not full-width landscape banners). Continue device QA. | 2026-07-20 | Previous Home full-width card approach rejected |

---

## Completed Fixes

*(Move items here when Done, using the template below.)*

_None yet in this tracking phase. Prior work (active operation resume, OperationWakelock, large-preview UI) is recorded under **Current Stable Baseline** and Fix List statuses rather than as completed entries here until formally closed with QA._

### Template

### \<Fix name\>

* Status:
* Date:
* Summary:
* Changed files:
* Behavior preserved:
* Validation:
* Manual QA:
* Remaining limitations:

---

## Active Work

### Current fix: Captain Marvel letterboxed thumbnail (F2) — Failed QA retry

* Status: **Failed QA** on prior fix; **retry in progress / Pending device QA**.
* Screenshot failure: Downloads list showed Captain Marvel in a narrow portrait slot with large black bars above/below.
* Root cause: remote TikTok thumbnail bitmap is often a **portrait frame with landscape content letterboxed inside**. Using full-image width÷height treated it as portrait; `BoxFit.cover` cannot remove baked-in bars.
* Fix applied: decode thumbnail → detect near-black bars → size tile from **content** aspect → crop paint to content region (`thumbnail_letterbox.dart`, `LinkClipMediaThumbnail`).
* Debug: `kDebugMode` logs `thumbnail aspect: pathType=… width=… height=… mode=… letterboxed=…` (no URLs/tokens).
* Out of scope: backend, APIs, OperationWakelock, analyze/edit/status large-preview stages.
* Do **not** mark Done until Captain Marvel screenshot case passes on device.
* Validation: `flutter analyze`, `flutter build apk --debug`.

---

## Rules for Updating This File

1. Update this file after every fix or meaningful investigation.
2. Do not mark a fix as **Done** unless:
   * automated validation passed
   * manual QA was performed or explicitly marked as pending
   * remaining limitations are documented
3. If a fix is only partially implemented, mark it as **Partially Done**, not Done.
4. If a fix is intentionally delayed, mark it as **Deferred** and explain why.
5. For every fix, list **changed files**.
6. For every fix, state what was **not** changed, especially:
   * backend
   * YouTube / cookies / secrets
   * OperationWakelock
   * ActiveOperationStore
   * OperationController
   * caption renderer / export
   * PiP / DownloadManager / Foreground Service
7. Keep this document concise but useful.
8. Do not use this file as a dump of long logs.
9. Keep it updated in the same PR/commit as each fix.

---

## Current Recommended Order

1. **QA and commit** the current clean UI / large-preview changes if they pass (F9).
2. **Caption text layout / wrapping** (F1).
3. **External output thumbnail consistency** (F2).
4. **Edit/export performance instrumentation** (F3).
5. **Progress UX / ETA** (F4).
6. **Moovit-like external floating window / PiP design** (F5) — design first.
7. **Background final-file DownloadManager** if needed (F6).
8. **AudioEditScreen parity** (F8).

_(F7 remains deferred until async job design exists.)_

---

## Related docs

* Living product handoff: `docs/LINKCLIP_PROJECT_SUMMARY.md`
* Update the project summary for meaningful product/behavior changes; use **this** file for the prioritized fix board.
