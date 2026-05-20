import "package:flutter/material.dart";

/// Premium semantic colors beyond [ColorScheme] (gradients, TikTok accent, shadows).
@immutable
final class LinkClipPalette extends ThemeExtension<LinkClipPalette> {
  const LinkClipPalette({
    required this.gradientTop,
    required this.gradientMid,
    required this.gradientBottom,
    required this.tiktokAccent,
    required this.tiktokAccentSoft,
    required this.tiktokOnAccent,
    required this.loaderBubble,
    required this.successState,
    required this.warningState,
    required this.cardShadows,
  });

  final Color gradientTop;
  final Color gradientMid;
  final Color gradientBottom;
  final Color tiktokAccent;
  final Color tiktokAccentSoft;
  /// Readable label/icon color on [tiktokAccentSoft] or filled TikTok chips.
  final Color tiktokOnAccent;
  final Color loaderBubble;
  final Color successState;
  final Color warningState;
  /// Empty in dark mode (prefer borders).
  final List<BoxShadow> cardShadows;

  static const LinkClipPalette light = LinkClipPalette(
    gradientTop: Color(0xFFF8F7FF),
    gradientMid: Color(0xFFF7F7FB),
    gradientBottom: Color(0xFFFFFFFF),
    tiktokAccent: Color(0xFF2DD4BF),
    tiktokAccentSoft: Color(0xFFCCFBF1),
    tiktokOnAccent: Color(0xFF0F766E),
    loaderBubble: Color(0xFFECEBFF),
    successState: Color(0xFF22C55E),
    warningState: Color(0xFFF59E0B),
    cardShadows: [
      BoxShadow(
        color: Color(0x146C63FF),
        blurRadius: 28,
        offset: Offset(0, 10),
      ),
    ],
  );

  static const LinkClipPalette dark = LinkClipPalette(
    gradientTop: Color(0xFF12132A),
    gradientMid: Color(0xFF0B0C18),
    gradientBottom: Color(0xFF070814),
    tiktokAccent: Color(0xFF2DD4BF),
    tiktokAccentSoft: Color(0xFF134E4A),
    tiktokOnAccent: Color(0xFFCCFBF1),
    loaderBubble: Color(0xFF2A275A),
    successState: Color(0xFF22C55E),
    warningState: Color(0xFFF59E0B),
    cardShadows: [],
  );

  @override
  LinkClipPalette copyWith({
    Color? gradientTop,
    Color? gradientMid,
    Color? gradientBottom,
    Color? tiktokAccent,
    Color? tiktokAccentSoft,
    Color? tiktokOnAccent,
    Color? loaderBubble,
    Color? successState,
    Color? warningState,
    List<BoxShadow>? cardShadows,
  }) {
    return LinkClipPalette(
      gradientTop: gradientTop ?? this.gradientTop,
      gradientMid: gradientMid ?? this.gradientMid,
      gradientBottom: gradientBottom ?? this.gradientBottom,
      tiktokAccent: tiktokAccent ?? this.tiktokAccent,
      tiktokAccentSoft: tiktokAccentSoft ?? this.tiktokAccentSoft,
      tiktokOnAccent: tiktokOnAccent ?? this.tiktokOnAccent,
      loaderBubble: loaderBubble ?? this.loaderBubble,
      successState: successState ?? this.successState,
      warningState: warningState ?? this.warningState,
      cardShadows: cardShadows ?? this.cardShadows,
    );
  }

  @override
  LinkClipPalette lerp(ThemeExtension<LinkClipPalette>? other, double t) {
    if (other is! LinkClipPalette) return this;
    return LinkClipPalette(
      gradientTop: Color.lerp(gradientTop, other.gradientTop, t)!,
      gradientMid: Color.lerp(gradientMid, other.gradientMid, t)!,
      gradientBottom: Color.lerp(gradientBottom, other.gradientBottom, t)!,
      tiktokAccent: Color.lerp(tiktokAccent, other.tiktokAccent, t)!,
      tiktokAccentSoft: Color.lerp(tiktokAccentSoft, other.tiktokAccentSoft, t)!,
      tiktokOnAccent: Color.lerp(tiktokOnAccent, other.tiktokOnAccent, t)!,
      loaderBubble: Color.lerp(loaderBubble, other.loaderBubble, t)!,
      successState: Color.lerp(successState, other.successState, t)!,
      warningState: Color.lerp(warningState, other.warningState, t)!,
      cardShadows: t < 0.5 ? cardShadows : other.cardShadows,
    );
  }
}

extension LinkClipPaletteContext on BuildContext {
  LinkClipPalette get lcPalette =>
      Theme.of(this).extension<LinkClipPalette>() ?? LinkClipPalette.light;
}

BoxDecoration linkClipPageGradientDecoration(BuildContext context) {
  final p = context.lcPalette;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [p.gradientTop, p.gradientMid, p.gradientBottom],
      stops: const [0, 0.42, 1],
    ),
  );
}
