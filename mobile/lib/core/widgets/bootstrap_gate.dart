import "package:flutter/material.dart";

import "../l10n/context_l10n.dart";
import "../storage/local_session.dart";
import "language_picker.dart";
import "loading_view.dart";

/// First frame before [LocalSession.bootstrap] completes — English default + language picker.
class BootstrapGate extends StatelessWidget {
  const BootstrapGate({super.key, required this.session});

  final LocalSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            LoadingView(message: l10n.bootstrapPreparingApp),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: languagePickerButton(context, session),
            ),
          ],
        ),
      ),
    );
  }
}
