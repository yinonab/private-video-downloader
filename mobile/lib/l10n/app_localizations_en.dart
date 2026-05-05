// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LinkClip';

  @override
  String get bootstrapPreparingApp => 'Preparing the app…';

  @override
  String get bootstrapConnectingServer => 'Connecting to the server…';

  @override
  String get bootstrapConnectionFailed => 'Could not connect to the server';

  @override
  String get bootstrapConnectionHint => 'Check your connection and try again.';

  @override
  String get bootstrapRetry => 'Retry';

  @override
  String get bootstrapAdvancedSettings => 'Advanced settings';

  @override
  String get languageSelectButton => 'Select language';

  @override
  String get languageSelectTitle => 'Select language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrewOption => 'עברית';

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get homeTitle => 'LinkClip';

  @override
  String get homeHeroTitle => 'Download videos easily';

  @override
  String get homeHeroSubtitle =>
      'Share a video from another app or paste a link to get started.';

  @override
  String get homeHeroSubtitleCompact =>
      'Share a video or paste a link to get started.';

  @override
  String get homeShareTip =>
      'Tip: Tap Share in Instagram, Facebook or TikTok, then choose LinkClip.';

  @override
  String get homePasteLinkFab => 'Paste a link';

  @override
  String get homePasteLinkShort => 'Paste link here';

  @override
  String get homeRecentDownloads => 'Recent downloads';

  @override
  String get homeLoading => 'Loading…';

  @override
  String get homeErrorGeneric => 'Something went wrong.';

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeEmptyTitle => 'No downloads yet';

  @override
  String get homeEmptySubtitle => 'Shared or pasted videos will appear here.';

  @override
  String get homePasteLinkButton => 'Paste a link';

  @override
  String get homeInvalidLink => 'Invalid link.';

  @override
  String get homePasteDialogTitle => 'Paste a link';

  @override
  String get homePasteDialogHint =>
      'Paste the link from the original app here.';

  @override
  String get homeCancel => 'Cancel';

  @override
  String get homeContinue => 'Continue';

  @override
  String get homeDeleteDownloadTitle => 'Delete download?';

  @override
  String get homeDeleteConfirm => 'Delete';

  @override
  String get downloadCardStatusDetails => 'Status details';

  @override
  String get downloadCardRetry => 'Retry';

  @override
  String get downloadCardDelete => 'Delete';

  @override
  String durationChip(String duration) {
    return 'Duration $duration';
  }

  @override
  String get analyzeTitle => 'Analyze link';

  @override
  String get analyzeLoading => 'Analyzing video…';

  @override
  String get analyzeVideoFound => 'Video found';

  @override
  String get analyzeChooseQuality => 'Choose quality';

  @override
  String get analyzePrepareDownload => 'Prepare download';

  @override
  String get analyzeMissingLink => 'Missing link.';

  @override
  String get analyzeQualityUnavailableSnack =>
      'This quality is not available for this video.';

  @override
  String get formatBestMp4 => 'Best MP4';

  @override
  String get format1080pMp4 => '1080p MP4';

  @override
  String get format720pMp4 => '720p MP4';

  @override
  String get format480pMp4 => '480p MP4';

  @override
  String get formatAudioMp3 => 'Audio MP3';

  @override
  String get qualityUnavailableForVideo => 'Not available for this video';

  @override
  String get downloadStatusTitle => 'Download status';

  @override
  String get downloadStatusQueued => 'Queued';

  @override
  String get downloadStatusRunning => 'Preparing your video…';

  @override
  String get downloadStatusDone => 'Ready to save';

  @override
  String get downloadStatusFailed => 'Download failed';

  @override
  String get downloadStatusCanceled => 'Canceled';

  @override
  String get downloadStatusUnknown => 'Unknown';

  @override
  String get downloadVideoReadyHint =>
      'The video is ready to save to your device.';

  @override
  String downloadSpeed(String speed) {
    return 'Speed: $speed';
  }

  @override
  String downloadEta(String eta) {
    return 'ETA: $eta';
  }

  @override
  String get downloadRetry => 'Retry';

  @override
  String get downloadSaveToDevice => 'Save to device';

  @override
  String get downloadOpen => 'Open';

  @override
  String get downloadShare => 'Share';

  @override
  String get downloadSavedToDownloads => 'Saved to Downloads';

  @override
  String get downloadSavedInAppOnly =>
      'Saved in the app, but could not save to Downloads.';

  @override
  String get downloadSavedGeneric => 'Saved';

  @override
  String get untitledVideo => 'Untitled';

  @override
  String get unknownPlatform => 'Unknown';

  @override
  String get errorNetwork => 'Network error. Please try again.';

  @override
  String get errorBadRequest => 'Invalid request.';

  @override
  String get errorUnsupportedQuality =>
      'The selected quality is not supported. Try another quality.';

  @override
  String get errorNoSharedLink => 'No shared link was found.';

  @override
  String get errorUnexpected => 'Something went wrong.';

  @override
  String get errorUnauthorized => 'You are not authorized.';

  @override
  String get errorInvalidUrl => 'Invalid link.';

  @override
  String get errorRateLimited => 'Daily limit reached.';

  @override
  String get errorConflict => 'Another download is already in progress.';

  @override
  String get errorJobNotFound => 'Download not found.';

  @override
  String get errorFileNotFound => 'File not found.';

  @override
  String get errorAnalyzeFailed => 'Could not analyze the link.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsServerUrl => 'Server URL';

  @override
  String get settingsDeviceId => 'Device ID';

  @override
  String get settingsRefreshDevice => 'Refresh device info';

  @override
  String get settingsAdvancedDevelopers => 'Advanced / developer';

  @override
  String get settingsAdvancedCustomSubtitle => 'Custom server';

  @override
  String get settingsAdvancedDefaultSubtitle => 'Default server from app build';

  @override
  String get settingsServerFieldLabel => 'Server URL (LAN / testing)';

  @override
  String get settingsServerFieldHint => 'https://… or http://192.168.x.x:3000';

  @override
  String get settingsSaveCustomServer => 'Save custom server and reconnect';

  @override
  String get settingsRevertToBakedServer => 'Use server URL from app build';

  @override
  String get settingsAdvancedFooterNote =>
      'Production builds normally use the URL baked into the APK. This section is for development or a temporary server.';

  @override
  String get settingsFactoryResetTitle => 'Reset app';

  @override
  String get settingsFactoryResetBody =>
      'This clears local sign-in and saved history on this device.';

  @override
  String get settingsFactoryResetConfirm => 'Reset';

  @override
  String get settingsEnterServerSnack => 'Enter a server URL.';

  @override
  String get settingsInvalidServerSnack => 'Invalid server URL.';

  @override
  String get settingsServerUpdatedSnack => 'Server updated. Signing in again.';

  @override
  String get settingsNoBakedUrlSnack => 'No baked-in server URL in this build.';

  @override
  String get settingsRevertSnack => 'Using the server URL from the app build.';

  @override
  String get settingsEmptyPlaceholder => '(empty)';

  @override
  String get registerTitle => 'Register device';

  @override
  String get registerSettingsTooltip => 'Settings';

  @override
  String get registerServerSection => 'Server';

  @override
  String get registerServerNotSet => '(not set)';

  @override
  String get registerServerBakedHint =>
      'The server URL is set by the app build. To change it, open Settings → Advanced.';

  @override
  String get registerServerUrlLabel => 'Server URL';

  @override
  String get registerInviteOptional => 'Invite code (optional)';

  @override
  String get registerDeviceNameOptional => 'Device name (optional)';

  @override
  String get registerSubmit => 'Register device';

  @override
  String get registerValidationRequired => 'Required';

  @override
  String get registerValidationBadUrl => 'Invalid URL';

  @override
  String get registerNeedServer =>
      'Enter a valid server URL or update advanced settings.';

  @override
  String get registerInvalidServerHost => 'Invalid server address.';

  @override
  String get autoRegisterTitle => 'Connecting';

  @override
  String get autoRegisterConnecting => 'Connecting to the server…';

  @override
  String get autoRegisterFailedGeneric => 'Connection failed';

  @override
  String get autoRegisterManualSetup => 'Manual / advanced setup';

  @override
  String get downloadJobErrorGeneric =>
      'Could not download in an available format.';

  @override
  String get downloadJobErrorQuality =>
      'The selected quality is not available for this video. Try another quality or Best MP4.';

  @override
  String get shareNoLinkInContent => 'No shared link was found.';

  @override
  String get settingsMeStatusLabel => 'System status';

  @override
  String get settingsMeNameLabel => 'Name on server';

  @override
  String get settingsMeDailyDownloadsLabel => 'Daily download limit';

  @override
  String get settingsMeDailyAnalyzeLabel => 'Daily analyze limit';

  @override
  String get savedMustDownloadFirst =>
      'Download the file to your device first.';

  @override
  String get savedCannotOpenFile => 'Could not open the file.';

  @override
  String get savedCannotShareFile => 'Could not share the file.';

  @override
  String get savedShareFailedHint =>
      'Sharing failed. Try opening the file or sharing from your files app.';

  @override
  String analyzeDurationLabel(String duration) {
    return 'Duration $duration';
  }

  @override
  String get shareAnalyzingVideo => 'Analyzing shared video…';

  @override
  String get shareLinkFound => 'Shared link found';

  @override
  String get loadingAnalyzingDot => 'Analyzing…';

  @override
  String get loadingPreparingDownloadDot => 'Preparing download…';

  @override
  String get loadingDownloadingDot => 'Downloading…';

  @override
  String get loadingSavingToDeviceDot => 'Saving to device…';

  @override
  String get loadingFinalizingDot => 'Finalizing…';

  @override
  String get downloadStageQueued => 'Queued';

  @override
  String get downloadStagePreparing => 'Preparing…';

  @override
  String get downloadStageDownloading => 'Downloading…';

  @override
  String get downloadStageFinalizing => 'Finalizing…';

  @override
  String get downloadStageReadyServer => 'Ready — save to your device';

  @override
  String get downloadStageFailed => 'Failed';

  @override
  String get downloadStageCanceled => 'Canceled';

  @override
  String get downloadStageUnknown => 'Working…';

  @override
  String downloadPercentValue(int percent) {
    return '$percent%';
  }

  @override
  String get downloadStatusSavedOnDeviceTitle => 'Saved on device';

  @override
  String get downloadStatusLoadingJob => 'Loading download…';

  @override
  String get bootstrapLoadingShort => 'Starting LinkClip…';
}
