import "package:flutter/material.dart";

import "../l10n/context_l10n.dart";
import "../storage/local_session.dart";

Future<void> showAppLanguagePicker(BuildContext context, LocalSession session) async {
  final l10n = context.l10n;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final selected = session.locale.languageCode;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(l10n.languageSelectTitle, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              title: Text(l10n.languageEnglish),
              trailing: selected == "en" ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                await session.setLocale(const Locale("en"));
              },
            ),
            ListTile(
              title: Text(l10n.languageHebrewOption),
              trailing: selected == "he" ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                await session.setLocale(const Locale("he"));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Compact TextButton for AppBars / bootstrap.
Widget languagePickerButton(BuildContext context, LocalSession session) {
  return TextButton(
    onPressed: () => showAppLanguagePicker(context, session),
    child: Text(context.l10n.languageSelectButton),
  );
}

/// Icon-only control for tight AppBars (e.g. registration).
Widget languagePickerIconButton(BuildContext context, LocalSession session) {
  return IconButton(
    icon: const Icon(Icons.language_rounded),
    tooltip: context.l10n.languageSectionTitle,
    onPressed: () => showAppLanguagePicker(context, session),
  );
}
