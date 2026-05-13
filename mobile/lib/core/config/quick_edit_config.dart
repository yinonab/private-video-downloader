/// Conservative window after which server-side source media may no longer exist for `/edits`.
///
/// TODO(linkclip): Replace with backend fields such as `canEdit` / `editableUntil` on download detail.
const Duration kQuickEditServerSourceRetention = Duration(minutes: 30);

/// Unknown / sentinel timestamps (e.g. list parser fallback to epoch) → treat as unknown for expiry checks.
DateTime? quickEditSanitizedRetentionReference(DateTime? dt) {
  if (dt == null) return null;
  if (dt.millisecondsSinceEpoch <= 0) return null;
  return dt;
}

/// Returns true when [referenceUtc] is older than [kQuickEditServerSourceRetention].
///
/// When [referenceUtc] is null (unknown), returns **false** (optimistic — server may still accept).
bool quickEditServerSourceLikelyExpired(DateTime? referenceUtc) {
  final ref = quickEditSanitizedRetentionReference(referenceUtc);
  if (ref == null) return false;
  final now = DateTime.now().toUtc();
  return now.difference(ref.toUtc()) > kQuickEditServerSourceRetention;
}
