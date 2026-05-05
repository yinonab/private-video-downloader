import "package:flutter/material.dart";

import "branded_loading.dart";

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BrandedLoadingPanel(message: message, compact: compact);
  }
}
