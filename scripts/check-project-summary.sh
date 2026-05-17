#!/usr/bin/env bash

CHANGED_CODE=$(git diff --cached --name-only | grep -E '^(backend|mobile)/' || true)
SUMMARY_CHANGED=$(git diff --cached --name-only | grep -E '^docs/LINKCLIP_PROJECT_SUMMARY\.md$' || true)

if [ -n "$CHANGED_CODE" ] && [ -z "$SUMMARY_CHANGED" ]; then
  echo ""
  echo "Warning: code changed but docs/LINKCLIP_PROJECT_SUMMARY.md was not updated."
  echo "If this change affects behavior, architecture, APIs, flows, limitations, or deployment, update the summary."
  echo ""
fi

exit 0
