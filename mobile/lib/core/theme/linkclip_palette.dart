import "package:flutter/material.dart";

/// Extended semantic palette (gradients, accent tints not on [ColorScheme], status surfaces).
///
/// TikTok-named fields (`tiktok*`) are legacy identifiers — values follow the muted blue accent.
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
    required this.successMutedBg,
    required this.warningState,
    required this.dangerMutedBg,
    required this.cardShadows,
  });

  final Color gradientTop;
  final Color gradientMid;
  final Color gradientBottom;
  final Color tiktokAccent;
  final Color tiktokAccentSoft;
  /// Readable label/icon color on tinted surfaces.
  final Color tiktokOnAccent;
  final Color loaderBubble;
  final Color successState;
  /// Soft background behind success badges / pills.
  final Color successMutedBg;
  final Color warningState;
  /// Soft background behind destructive / error badges.
  final Color dangerMutedBg;
  /// Empty in dark mode (prefer borders).
  final List<BoxShadow> cardShadows;

  static const LinkClipPalette light = LinkClipPalette(
    gradientTop: Color(0xFFF3F5F8),
    gradientMid: Color(0xFFFAFBFC),
    gradientBottom: Color(0xFFF7F8FA),
    tiktokAccent: Color(0xFF4E8FBF),
    tiktokAccentSoft: Color(0xFFD6E8F5),
    tiktokOnAccent: Color(0xFF2C5F82),
    loaderBubble: Color(0xFFE8EEF5),
    successState: Color(0xFF49A078),
    successMutedBg: Color(0xFFE6F4ED),
    warningState: Color(0xFFC9A035),
    dangerMutedBg: Color(0xFFF7EAEA),
    cardShadows: [
      BoxShadow(
        color: Color(0x120D1420),
        blurRadius: 20,
        offset: Offset(0, 6),
      ),
    ],
  );

  static const LinkClipPalette dark = LinkClipPalette(
    gradientTop: Color(0xFF121924),
    gradientMid: Color(0xFF0F1622),
    gradientBottom: Color(0xFF0D1420),
    tiktokAccent: Color(0xFF4E8FBF),
    tiktokAccentSoft: Color(0xFF203548),
    tiktokOnAccent: Color(0xFFA9CCE6),
    loaderBubble: Color(0xFF1B2433),
    successState: Color(0xFF49A078),
    successMutedBg: Color(0xFF163528),
    warningState: Color(0xFFC9A035),
    dangerMutedBg: Color(0xFF3A2024),
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
    Color? successMutedBg,
    Color? warningState,
    Color? dangerMutedBg,
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
      successMutedBg: successMutedBg ?? this.successMutedBg,
      warningState: warningState ?? this.warningState,
      dangerMutedBg: dangerMutedBg ?? this.dangerMutedBg,
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
      successMutedBg: Color.lerp(successMutedBg, other.successMutedBg, t)!,
      warningState: Color.lerp(warningState, other.warningState, t)!,
      dangerMutedBg: Color.lerp(dangerMutedBg, other.dangerMutedBg, t)!,
      cardShadows: t < 0.5 ? cardShadows : other.cardShadows,
    );
  }
}

extension LinkClipPaletteContext on BuildContext {
  LinkClipPalette get lcPalette => Theme.of(this).extension<LinkClipPalette>() ?? LinkClipPalette.light;
}

BoxDecoration linkClipPageGradientDecoration(BuildContext context) {
  final p = context.lcPalette;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [p.gradientTop, p.gradientMid, p.gradientBottom],
      stops: const [0, 0.45, 1],
    ),
  );
}
