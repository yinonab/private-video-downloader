# Edit Preview — architecture audit & capability matrix

Living reference for Quick Edit in-editor preview. Export (`buildQuickEditOperations` → `POST /edits`) remains authoritative.

## Phase 1 — Architecture audit (code-inspected)

### 1. Where edit state is stored

All composer fields live on `_EditVideoScreenState` in `lib/features/edit/edit_video_screen.dart`:

| Field | Purpose |
|-------|---------|
| `_durationSec`, `_startSec`, `_endSec` | Trim range |
| `_crop`, `_formatFitMode`, `_rotation` | Format |
| `_speed`, `_mute`, `_compress` | Speed / audio / quality |
| `_captionsAuto` + `_captions*` style fields | Captions burn-in |
| `_captionsDraftSegments` | Draft cues from `POST /edits/captions/draft` |
| `_playbackSec` | Current preview playhead (source timeline) |
| `_tabController.index` | Active tool panel |

Look Editor returns `CaptionLookSnapshot` → `_applyCaptionLookSnapshot`.

### 2. Where export payload is built

`edit_video_screen.dart` → `_submitEdit()` → `buildQuickEditOperations(...)` in `lib/core/models/quick_edit_models.dart` → `ApiClient.createEditJob`.

### 3. Where video preview is rendered

`EditVideoPreview` (`lib/features/edit/widgets/edit_video_preview.dart`) inside `_buildComposerBody` preview card.

Stack above player (same screen):

- `CropPreviewOverlay` when Format tab + Fill + non-original crop
- `EditCaptionsPreviewOverlay` when Captions tab + auto captions on (via unified preview state)

### 4. Playback speed in preview

**Before foundation:** speed was export-only; `VideoPlayerController` always played at 1×.

**After foundation:** `EditPreviewState.playbackSpeed` → `EditVideoPreview.playbackSpeed` → `setPlaybackSpeed`.

### 5. Mute in preview

**Before foundation:** `_mute` only sent in export ops; player volume unchanged.

**After foundation:** `EditPreviewState.muted` → `EditVideoPreview.muted` → `setVolume(0|1)`.

### 6. Trim in preview

`EditVideoPreview` loops playback in `trimStartSec..trimEndSec` via `_enforceTrimWindow` and `_seekToTrimStart`. Trim editor reads `_playbackSec` for playhead display.

### 7. Captions overlay attachment

Passive `captionsPreviewOverlay` widget on `EditVideoPreview` (`IgnorePointer`). Shown only on **Captions** tab when auto captions enabled and draft exists with an active cue.

### 8. Caption draft text availability

`_captionsDraftSegments` from draft API; updated by `CaptionDraftEditorScreen` and local segment edits.

### 9. Caption style availability

`_captionsStyle` … `_captionsOffsetY` (+ outline/highlight fields). Summarized via `captionLookSnapshotFrom(...)`.

### 10. What worked vs gaps (pre-foundation)

| Control | Pre-foundation |
|---------|----------------|
| Trim window loop | ✅ Live |
| Rotation visual | ✅ Approximate (Transform) |
| Crop guide (Fill) | ✅ Approximate overlay |
| Fit+blur format | ❌ Export-only |
| Speed | ✅ Live (`setPlaybackSpeed`) |
| Mute | ✅ Live (`setVolume`) |
| Compression | ❌ Export-only |
| Caption style on video | ✅ Captions tab via `CaptionLookSnapshot` |
| Caption draft text | ✅ Real draft cue at `_playbackSec` when draft exists |
| Sample text on video | ✅ Suppressed — no-draft shows Captions tab explanation card |
| Live draft edits | ✅ `onDraftChanged` + segment sheet `onLiveChanged` → parent preview |
| Output thumbnails | ✅ `resolveMediaOutputPreview` prefers final output frame |

## Phase 2 — Capability matrix

| Feature | Classification | Notes |
|---------|----------------|-------|
| Trim | **live preview** | Seek loop in trim range |
| Speed | **live preview** | `setPlaybackSpeed` on preview player |
| Mute | **live preview** | `setVolume` on preview player |
| Rotate | **approximate preview** | CSS-style rotate; export does pixel rotation |
| Crop / Fill | **approximate preview** | `CropPreviewOverlay` guide only |
| Crop / Fit+blur | **export-only** | No blurred letterbox in preview |
| Compression | **export-only** | No preview bitrate change |
| Captions text | **approximate preview** | Draft cue at `_playbackSec`; no trim/speed timeline remap |
| Captions style | **approximate preview** | Flutter/google_fonts vs ASS burn |
| Captions position/offset | **approximate preview** | ASS-scaled clamps |
| Outline | **approximate preview** | Stroke layers in Flutter |
| Word highlight | **approximate preview** | Color/box spans; word timing when `words[]` present |
| Audio Edit screen | **not supported** | Separate flow (`audio_edit_screen.dart`) |

Programmatic mirror: `kEditPreviewCapabilityMatrix` in `lib/core/edit/edit_preview_state.dart`.

## Phase 3 — Unified preview state

`buildEditVideoPreviewState(...)` derives `EditPreviewState` from editor fields + `_playbackSec`.

`buildCaptionPreviewState(...)` derives `CaptionPreviewState` (style + active cue).

Rules:

- Passive / read-only
- No backend calls
- No export mutation
- Sample text allowed only when `allowSampleFallback: true` (Look Editor stage card)

## Intentionally not in scope

- Fullscreen preview
- Device rotation / `SystemChrome`
- VideoPlayer lifecycle rewrite
- Trim/speed timeline remapping for caption cues
- Backend / export schema changes
