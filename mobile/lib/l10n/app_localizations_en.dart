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
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get homeTitle => 'LinkClip';

  @override
  String get homeHeroTitle => 'Download videos easily';

  @override
  String get homeHeroSubtitle =>
      'Share a video or paste a link to get started.';

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
  String get qualityTikTokReady => 'TikTok-ready MP4';

  @override
  String get qualityTikTokReadyDescription =>
      'Optimized for TikTok and social apps. May take longer.';

  @override
  String get qualityTikTokReadyBadge => 'Recommended for upload';

  @override
  String get downloadPreparingTikTokReadyTitle =>
      'Preparing TikTok-ready video';

  @override
  String get downloadPreparingTikTokReadySubtitle =>
      'This video is being optimized for TikTok and social apps. It may take a few minutes.';

  @override
  String get downloadChipTikTokReady => 'TikTok-ready';

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
  String get mediaExportDownloadsWord => 'Downloads';

  @override
  String downloadSavedToDownloads(String path) {
    return 'The video was saved to:\n$path';
  }

  @override
  String downloadSavedInAppOnly(String path) {
    return 'Saved inside the app.\nCouldn\'t copy to public Downloads right now:\n$path';
  }

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
  String get errorThreadsUnsupported =>
      'Threads links are not supported for download yet. Try an Instagram, TikTok, Facebook, or YouTube link.';

  @override
  String get errorPlatformUnsupported =>
      'This link is not supported for download yet. Try an Instagram, TikTok, Facebook, or YouTube link.';

  @override
  String get errorAnalyzeMetadataUnavailable =>
      'Could not load format options for this video. The link may be restricted or temporarily unavailable.';

  @override
  String get errorFacebookExtractFailed =>
      'We couldn\'t read this Facebook video right now. This link may require special access or Facebook may be blocking access to it. Try another link or try again later.';

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
  String get downloadJobErrorNormalizeFailed =>
      'Could not prepare the video in a supported format.';

  @override
  String get downloadErrorInstagramRestricted =>
      'This Instagram video can\'t be downloaded right now. It may be restricted, require login, or be temporarily blocked. Try another link.';

  @override
  String get downloadErrorGeneric =>
      'Download failed. Please try again or use another link.';

  @override
  String get downloadErrorUnsupportedOrPrivate =>
      'This link can\'t be downloaded. The content may be private, removed, or unsupported.';

  @override
  String get openDescription => 'Open description';

  @override
  String get hideDescription => 'Hide description';

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
  String get analyzeProcessingSubtitle =>
      'Checking the video and preparing available formats.';

  @override
  String get downloadProcessingSubtitle =>
      'Downloading and processing your video.';

  @override
  String get downloadLoadingSubtitle =>
      'Preparing your download and connecting to the server.';

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
  String get stageQueued => 'Queued';

  @override
  String get stagePreparing => 'Preparing your video...';

  @override
  String get stageDownloading => 'Downloading...';

  @override
  String get stageCheckingCompatibility => 'Checking video compatibility...';

  @override
  String get stageRemuxing => 'Preparing video...';

  @override
  String get stageNormalizingAudio => 'Optimizing audio...';

  @override
  String get stageFullTranscoding => 'Processing video...';

  @override
  String get stageFinalizing => 'Finalizing...';

  @override
  String get stageDone => 'Ready to save';

  @override
  String get stageFailed => 'Failed';

  @override
  String get fullTranscodeTitle => 'Extra processing needed';

  @override
  String get fullTranscodeSubtitle =>
      'This video needs extra processing to work well with TikTok and other apps. It may take a few minutes.';

  @override
  String progressPercent(int percent) {
    return '$percent%';
  }

  @override
  String get downloadUnknownProgress => 'Working on it...';

  @override
  String get bootstrapLoadingShort => 'Starting LinkClip…';

  @override
  String get editScreenTitle => 'Edit video';

  @override
  String get editExit => 'Exit';

  @override
  String get editSave => 'Save';

  @override
  String get editTrimSectionTitle => 'Trim';

  @override
  String get editTrimVideoDuration => 'Video duration';

  @override
  String get editTrimSelectedClip => 'Selected clip';

  @override
  String get editTrimRemoved => 'Removed';

  @override
  String get editTrimStart => 'Start';

  @override
  String get editTrimEnd => 'End';

  @override
  String get editTrimReset => 'Reset';

  @override
  String get editCropSectionTitle => 'Aspect ratio';

  @override
  String get editCropOriginal => 'Original';

  @override
  String get editMuteLabel => 'Mute audio';

  @override
  String get editCompressSectionTitle => 'Compression';

  @override
  String get editCompressOriginal => 'Original quality';

  @override
  String get editCompressSocial => 'Social optimized';

  @override
  String get editCompressSmall => 'Small file';

  @override
  String get editChooseAtLeastOneChange =>
      'Choose at least one edit to continue';

  @override
  String get editPreviewLoading => 'Loading preview…';

  @override
  String get editPreviewError => 'Could not load video info.';

  @override
  String get editDurationApproxHint => 'Duration is approximate until loaded.';

  @override
  String get editLocalVideoComingSoon =>
      'Editing a video from your device is coming soon';

  @override
  String get downloadCardEdit => 'Edit';

  @override
  String get editSourceExpiredTitle => 'The video expired on the server';

  @override
  String get editSourceExpiredBody =>
      'To edit this video, download it again. After the download finishes, you\'ll be able to edit it right away.';

  @override
  String get editSourceExpiredDownloadNow => 'Download now';

  @override
  String get editSourceExpiredCancel => 'Cancel';

  @override
  String get editSourceMissingOriginalUrl =>
      'The original link is missing. Paste the link again to download and edit it.';

  @override
  String get editProcessingTitle => 'Saving your edit…';

  @override
  String get editProcessingSubtitle =>
      'The edited file will be saved on your device';

  @override
  String get editProcessingServerSubtitle =>
      'We\'re editing your video on LinkClip. This usually takes a few seconds.';

  @override
  String get editProcessingDontClose => 'Do not close the app';

  @override
  String get editProcessingSecondsHint => 'This should only take a few seconds';

  @override
  String get editProcessingDownloading => 'Downloading edited file…';

  @override
  String get editDoneTitle => 'Your edit is ready';

  @override
  String editDoneSubtitle(String path) {
    return 'The edited file is ready.\nThe video was saved to:\n$path';
  }

  @override
  String get editExportOpen => 'Open';

  @override
  String get editExportShare => 'Share';

  @override
  String get editExportSave => 'Save';

  @override
  String get editFailedTitle => 'Editing failed';

  @override
  String get editTryAgain => 'Try again';

  @override
  String editSavedToDownloads(String path) {
    return 'The video was saved to:\n$path';
  }

  @override
  String get editSaveFailed => 'We couldn\'t save the video right now.';

  @override
  String get errorEditJobNotFound => 'Edit job not found.';

  @override
  String get errorEditInvalidSource => 'This video cannot be edited right now.';

  @override
  String get errorEditFailed => 'Edit processing failed.';

  @override
  String get errorUploadFileTooLarge =>
      'This video is too large to edit right now. You can upload videos up to 175MB.';

  @override
  String get errorUploadVideoTooLong =>
      'This video is too long to edit right now. You can upload clips up to 7 minutes.';

  @override
  String get errorUploadUnsupportedType =>
      'This file type is not supported. Try an MP4 video.';

  @override
  String get errorUploadInvalidVideo =>
      'We couldn’t read this video. Try another video.';

  @override
  String get errorUploadFailed => 'We couldn’t upload this video. Try again.';

  @override
  String get errorUploadSourceUnavailable =>
      'The uploaded video is no longer available. Choose it again.';

  @override
  String get errorEditUploadNotReady =>
      'The uploaded video is not ready for editing yet. Try again in a moment.';

  @override
  String get errorEditSourceRequired => 'No edit source was selected.';

  @override
  String get errorEditMultipleSources =>
      'Too many edit sources were selected. Try again.';

  @override
  String get editStageQueued => 'Waiting to start…';

  @override
  String get editStageValidating => 'Checking the video…';

  @override
  String get editStageProbing => 'Preparing the video for editing…';

  @override
  String get editStageProcessing => 'Editing the video…';

  @override
  String get editStageFinalizing => 'Finalizing and saving…';

  @override
  String get editStageDone => 'Your edit is ready';

  @override
  String get editStageFailed => 'Editing failed';

  @override
  String get editLeaveWhileProcessingTitle => 'Leave editing?';

  @override
  String get editLeaveWhileProcessingBody =>
      'Your edit is still processing. Leaving now will not cancel the server job, but you will need to reopen this screen to see progress.';

  @override
  String get editTabTrim => 'Trim';

  @override
  String get editTabAspectRatio => 'Aspect ratio';

  @override
  String get editTabCompression => 'Compression';

  @override
  String get editTabAudio => 'Audio';

  @override
  String get editCompressHelperHint =>
      'Choose how much to compress the final video';

  @override
  String get editMuteDescription =>
      'Remove the audio track from the edited video';

  @override
  String get editCropTabHint =>
      'Preview shows the framed area that will be kept (center crop).';

  @override
  String get editTrimFieldStart => 'Start';

  @override
  String get editTrimFieldEnd => 'End';

  @override
  String get editTrimTimeExample => 'Example: 02:04';

  @override
  String get editTrimInvalidStartTime => 'Invalid start time';

  @override
  String get editTrimInvalidEndTime => 'Invalid end time';

  @override
  String get editTrimEndMustBeAfterStart => 'End must be after start';

  @override
  String get editTrimRangeFrom => 'From';

  @override
  String get editTrimRangeTo => 'To';

  @override
  String get editLeaveWhileProcessingStay => 'Stay';

  @override
  String get editLeaveWhileProcessingExit => 'Leave';

  @override
  String get editTrimSheetTitleStart => 'Start time';

  @override
  String get editTrimSheetTitleEnd => 'End time';

  @override
  String get editTrimSheetApply => 'Apply';

  @override
  String get editTrimTapToEditHint => 'Tap to enter exactly';
}
