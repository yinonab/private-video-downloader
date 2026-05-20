import "package:flutter/material.dart";

import "../l10n/context_l10n.dart";
import "../storage/local_session.dart";
import "../theme/linkclip_palette.dart";
import "branded_loading.dart";
import "language_picker.dart";

/// First frame before [LocalSession.bootstrap] completes — English default + language picker.
class BootstrapGate extends StatelessWidget {
  const BootstrapGate({super.key, required this.session});

  final LocalSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: linkClipPageGradientDecoration(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              BrandedLoadingPanel(message: l10n.bootstrapLoadingShort),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: languagePickerIconButton(context, session),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
