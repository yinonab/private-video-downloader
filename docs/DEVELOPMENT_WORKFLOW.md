# LinkClip Development Workflow

## Living project summary

The main living handoff document is:

`docs/LINKCLIP_PROJECT_SUMMARY.md`

This file should be reviewed after every meaningful project change.

## Definition of Done

A task is not complete until:

- Code changes are implemented.
- Relevant checks were run.
- Flutter changes ran:
  - `flutter gen-l10n` if localization changed
  - `flutter analyze`
  - `flutter build apk --release` for release-impacting mobile changes
- Backend changes ran:
  - `npm run build`
- `docs/LINKCLIP_PROJECT_SUMMARY.md` was reviewed.
- If the project summary was affected, it was updated.
- If the project summary was not affected, the final report says why.

## When to update the project summary

Update `docs/LINKCLIP_PROJECT_SUMMARY.md` when changing:

- architecture
- backend routes
- request/response schemas
- Flutter flows
- Quick Edit behavior
- analyze/download behavior
- storage paths
- cleanup/retention behavior
- deployment or operations
- rate limits
- dependencies
- important build commands
- known limitations
- important product decisions
- UI/UX behavior that affects users

## Documentation safety rules

Never add:

- secrets
- tokens
- cookie values
- `ADMIN_TOKEN`
- database URLs
- private device IDs
- personal operator-only details

Use generic examples instead.

## Standard final report format

At the end of future tasks, report:

```text
Files changed:
- ...

Checks run:
- ...

Project summary updated: yes/no
Sections changed:
- ...

Notes / limitations:
- ...
```

## Development discipline

- Do not refactor the download pipeline without a strong reason.
- Do not casually change yt-dlp/cookies/platform logic.
- Keep heavy media processing server-side for the MVP.
- Do not add client-side ffmpeg in Flutter unless explicitly planned.
- Test backend API changes before wiring Flutter.
- Keep Android MVP focused.
- Treat iOS as a separate planned platform effort.
