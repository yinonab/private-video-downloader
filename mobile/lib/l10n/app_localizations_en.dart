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
  String get settingsLanguageRowTitle => 'Language';

  @override
  String get settingsLanguageRowSubtitle => 'Choose app language';

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
  String get homeQuickActionsTitle => 'What would you like to do?';

  @override
  String get homeActionPasteLinkTitle => 'Paste link';

  @override
  String get homeActionPasteLinkSubtitle => 'From the web';

  @override
  String get homeActionEditVideoTitle => 'Edit video';

  @override
  String get homeActionEditVideoSubtitle => 'From device';

  @override
  String get homeTabDownloads => 'Downloads';

  @override
  String get homeTabEdits => 'Edits';

  @override
  String get homeNoEditsTitle => 'No edits yet';

  @override
  String get homeNoEditsSubtitle =>
      'Edit a video from your device or from an existing download, and your edits will appear here.';

  @override
  String get editsFilterToday => 'Today';

  @override
  String get editsFilterTwoDays => '2 days';

  @override
  String get editsFilterThreeDays => '3 days';

  @override
  String get editsFilterWeek => 'Week';

  @override
  String get editsFilterTwoWeeks => '2 weeks';

  @override
  String get editsFilterMonth => 'Month';

  @override
  String get editsFilterUnlimited => 'Unlimited';

  @override
  String get editsDeletedLocally => 'Deleted locally';

  @override
  String get editsFromDevice => 'From device';

  @override
  String get editsFromDownload => 'From download';

  @override
  String get editsFileUnavailable => 'File unavailable';

  @override
  String get editsOpen => 'Open';

  @override
  String get editsShare => 'Share';

  @override
  String get editsSave => 'Save';

  @override
  String get editsNoItemsTitle => 'No edits yet';

  @override
  String get editsNoItemsSubtitle =>
      'Edit a video from your device or from an existing download, and your edits will appear here.';

  @override
  String get editsRemoveFromHistory => 'Remove from list';

  @override
  String get deleteEditFromApp => 'Delete from app';

  @override
  String get deleteEditFromAppTitle => 'Delete this edit from the app?';

  @override
  String get deleteEditFromAppBody =>
      'This will remove the edit from history and app storage. Files you saved to your device will not be deleted.';

  @override
  String get removeEditFromList => 'Remove from list';

  @override
  String get editedVideoFallbackTitle => 'Edited video';

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
  String get downloadCardActionsTitle => 'Quick actions';

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
  String get analyzeFormatTabVideo => 'Video';

  @override
  String get analyzeFormatTabAudio => 'Audio';

  @override
  String get formatAudioMp3Subtitle => 'Download audio only';

  @override
  String get formatAudioMp3Description =>
      'Great for music, podcasts, and listening';

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
      'The video is ready. You can save, share, or open it.';

  @override
  String get downloadVideoReadyLocalHint =>
      'The video is ready. You can open, share, or save it.';

  @override
  String get downloadFinalizingLocalChip => 'Finishing preparation…';

  @override
  String get downloadFinalizingLocalHeadline => 'Preparing the file for use…';

  @override
  String get loadingPreparingFileForUseDot => 'Preparing the file for use…';

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
  String get errorDrmProtected =>
      'This link can\'t be downloaded because the content is DRM-protected.';

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
  String get errorYoutubeAuthRequiredTitle => 'YouTube verification required';

  @override
  String get errorYoutubeAuthRequiredBody =>
      'YouTube requires verification for this link. The video may be restricted or YouTube may be asking for a \"not a bot\" check. Try another link or try again later.';

  @override
  String get errorYoutubeGeoRestrictedTitle =>
      'Video unavailable in server region';

  @override
  String get errorYoutubeGeoRestrictedBody =>
      'This video is not available in the download server\'s region. It may only be available in specific countries. Try another link.';

  @override
  String get errorNoDownloadableFormatsTitle => 'No downloadable formats found';

  @override
  String get errorNoDownloadableFormatsBody =>
      'We couldn\'t find downloadable formats for this link. The content may be private, restricted, removed, or not supported right now. Try another link.';

  @override
  String get errorFacebookNoFormatsFoundTitle => 'No Facebook formats found';

  @override
  String get errorFacebookNoFormatsFoundBody =>
      'We couldn\'t find downloadable formats for this Facebook video. The content may be private, restricted, or not supported right now. Try another link.';

  @override
  String get errorServerUrlInvalidConfig =>
      'The server address is invalid. Check settings and try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsServerUrl => 'Server URL';

  @override
  String get settingsDeviceId => 'Device ID';

  @override
  String get settingsBundledProductionSubtitle =>
      'Bundled default production server (https://api.linkclip.win).';

  @override
  String get settingsBundledFromBuildSubtitle =>
      'Using URL from app build (--dart-define).';

  @override
  String get settingsRefreshDevice => 'Refresh device info';

  @override
  String get settingsAdvancedDevelopers => 'Advanced / developer';

  @override
  String get settingsAdvancedCustomSubtitle => 'Custom server';

  @override
  String get settingsAdvancedDefaultSubtitle => 'Bundled default server';

  @override
  String get settingsServerFieldLabel => 'Server URL (LAN / testing)';

  @override
  String get settingsServerFieldHint => 'https://… or http://192.168.x.x:3000';

  @override
  String get settingsSaveCustomServer => 'Save custom server and reconnect';

  @override
  String get settingsRevertToBakedServer => 'Use bundled default server';

  @override
  String get settingsAdvancedFooterNote =>
      'Advanced: use a LAN or staging API base URL. Clearing the field restores the bundled default (production, or the URL from --dart-define when set). You will sign in again after changing servers.';

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
  String get settingsRevertSnack =>
      'Using the bundled default server. Sign in again.';

  @override
  String get settingsEmptyPlaceholder => '(empty)';

  @override
  String get registerTitle => 'Register device';

  @override
  String get registerIntroHelper =>
      'Tap Register device to start. No manual server setup is needed.';

  @override
  String get registerSecureServerLine =>
      'Secure server: https://api.linkclip.win';

  @override
  String get registerHaveInviteCode => 'Have an invite code?';

  @override
  String get registerSettingsTooltip => 'Settings';

  @override
  String get registerServerSection => 'Server';

  @override
  String get registerServerNotSet => '(not set)';

  @override
  String get registerServerBakedHint =>
      'Using the bundled default server URL. For a custom staging or LAN server, open Settings → Advanced.';

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
      'Preparing and processing your video.';

  @override
  String get downloadLoadingSubtitle =>
      'Connecting to the server and preparing the file.';

  @override
  String get fileNoLongerAvailableTitle => 'This file is no longer available';

  @override
  String get fileNoLongerAvailableRedownloadBody =>
      'To continue, download it again.';

  @override
  String get downloadAgainAction => 'Download again';

  @override
  String get uploadSourceNoLongerAvailableBody =>
      'The uploaded video is no longer available. Choose it again.';

  @override
  String get chooseAgainAction => 'Choose it again';

  @override
  String get keepAppOpenUntilFinished =>
      'We recommend keeping the app open until this finishes.';

  @override
  String get keepAppOpenUntilAnalyzeFinished =>
      'We recommend keeping the app open until analysis finishes.';

  @override
  String get keepAppOpenUntilDownloadFinished =>
      'We recommend keeping the app open until preparation finishes.';

  @override
  String get keepAppOpenUntilSaveFinished =>
      'We recommend keeping the app open until the file is saved to your device.';

  @override
  String get keepAppOpenUntilUploadFinished =>
      'We recommend keeping the app open until the upload finishes.';

  @override
  String get keepAppOpenUntilEditFinished =>
      'We recommend keeping the app open until the edit finishes.';

  @override
  String get editServerOutputUnavailable =>
      'This edited video is no longer on the server and wasn\'t found on your device.';

  @override
  String get loadingPreparingDownloadDot => 'Preparing video…';

  @override
  String get loadingDownloadingDot => 'Preparing final file…';

  @override
  String get loadingSavingToDeviceDot => 'Saving to device…';

  @override
  String get loadingPreparingForShareDot => 'Preparing to share…';

  @override
  String get loadingPreparingForOpenDot => 'Preparing to open…';

  @override
  String get loadingFinalizingDot => 'Finalizing…';

  @override
  String get downloadStageQueued => 'Queued';

  @override
  String get downloadStagePreparing => 'Preparing…';

  @override
  String get downloadStageDownloading => 'Preparing file…';

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
  String get downloadStatusLoadingJob => 'Preparing video…';

  @override
  String get stageQueued => 'Queued';

  @override
  String get stagePreparing => 'Preparing your video...';

  @override
  String get stageDownloading => 'Preparing the video...';

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
  String get editCreateEdit => 'Create edit';

  @override
  String get editDoneButton => 'Done';

  @override
  String editTrimSelectedRange(String start, String end) {
    return 'Selected range: $start–$end';
  }

  @override
  String editTrimRemovedLine(String duration) {
    return 'Removed: $duration';
  }

  @override
  String get editCreatingEdit => 'Creating your edit...';

  @override
  String get editCreatingEditKeepOpen =>
      'We recommend keeping the app open until this finishes.';

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
  String get editCropOriginal => 'Original';

  @override
  String get editFormatVideoShapeTitle => 'Video shape';

  @override
  String get editFormatVideoShapeSubtitle => 'Choose aspect presets.';

  @override
  String get editFormatFitModeSectionTitle => 'How should it fit?';

  @override
  String get editFormatFitModeNeedsShapeHint =>
      'Choose a format like 9:16 to decide whether to crop or keep the full video.';

  @override
  String get editFormatFitOptionFill => 'Fill screen';

  @override
  String get editFormatFitOptionFit => 'Keep all';

  @override
  String get editFormatFitFillExplanation =>
      'Fill screen — fills the frame and may crop edges.';

  @override
  String get editFormatFitFitExplanation =>
      'Keep all — keeps the full video with a blurred background.';

  @override
  String get editFormatRotationTitle => 'Rotation';

  @override
  String get editFormatRotationSubtitle =>
      'Rotate the video before fitting it to the selected shape.';

  @override
  String get editMuteLabel => 'Mute audio';

  @override
  String get editCompressSectionTitle => 'Quality';

  @override
  String get editCompressOriginal => 'Original quality';

  @override
  String get editCompressSocial => 'Social';

  @override
  String get editCompressSmall => 'Small file';

  @override
  String get editChooseAtLeastOneChange =>
      'Choose at least one change to create an edit';

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
  String get editLocalVideoSheetTitle => 'Choose a short video to edit';

  @override
  String get editLocalVideoLimitsNote => 'Videos up to 7 minutes and 175MB';

  @override
  String get editLocalVideoPickMedia => 'Device media';

  @override
  String get editLocalVideoPickFiles => 'Browse files';

  @override
  String get editLocalVideoUploading => 'Uploading your video for editing...';

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
  String get editProgressStagePreparing => 'Preparing your video...';

  @override
  String get editProgressStageProcessing => 'Processing the video...';

  @override
  String get editProgressStageApplyingEdits => 'Applying edits...';

  @override
  String get editProgressStageBurningCaptions =>
      'Burning captions into the video...';

  @override
  String get editProgressStageFinalizing => 'Creating the final file...';

  @override
  String get editProgressStagePreparingPreview => 'Preparing preview...';

  @override
  String get editProgressStageAlmostDone => 'Almost done...';

  @override
  String get editProgressEstimatedNote =>
      'Progress is approximate while your edit runs.';

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
  String get editExportSave => 'Save to device';

  @override
  String get editFailedTitle => 'Editing failed';

  @override
  String get operationEditAlreadyInProgress =>
      'An edit is already in progress. Wait for it to finish or reopen it from your history.';

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
  String get errorUnsupportedSpeedFactor =>
      'This speed option is not supported.';

  @override
  String get errorUnsupportedFormatMode => 'This format mode is not supported.';

  @override
  String get errorUnsupportedRotation =>
      'This rotation option is not supported.';

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
  String get editTabSpeed => 'Speed';

  @override
  String get editTabAspectRatio => 'Format';

  @override
  String get editTabCompression => 'Quality';

  @override
  String get editTabAudio => 'Audio';

  @override
  String get editTabCaptions => 'Captions';

  @override
  String get editToolbarMoreTools => 'More tools';

  @override
  String get editToolbarPreviousTools => 'Previous tools';

  @override
  String get editCaptionsSectionTitle => 'Captions';

  @override
  String get editCaptionsSectionSubtitle =>
      'Create captions from the video audio.';

  @override
  String get editCaptionsAutoToggle => 'Auto captions';

  @override
  String get editCaptionsBurnInHelper =>
      'Captions will be burned into the final video.';

  @override
  String get editCaptionsMayTakeLongerNote => 'This may take longer.';

  @override
  String get editCaptionsProcessingNoteLine =>
      'Generating captions may take a little longer.';

  @override
  String get editCaptionsTextSizeLabel => 'Text size';

  @override
  String get editCaptionsSizeExtraSmall => 'Extra small';

  @override
  String get editCaptionsSizeSmall => 'Small';

  @override
  String get editCaptionsSizeMedium => 'Medium';

  @override
  String get editCaptionsSizeLarge => 'Large';

  @override
  String get editCaptionsPositionLabel => 'Position';

  @override
  String get editCaptionsPositionTop => 'Top';

  @override
  String get editCaptionsPositionBottom => 'Bottom';

  @override
  String get editCaptionsColorLabel => 'Color';

  @override
  String get editCaptionsColorWhite => 'White';

  @override
  String get editCaptionsColorYellow => 'Yellow';

  @override
  String get editCaptionsStyleLabel => 'Style';

  @override
  String get editCaptionsStyleClean => 'Clean';

  @override
  String get editCaptionsStyleBold => 'Bold';

  @override
  String get editCaptionsStyleDarkBox => 'Dark box';

  @override
  String get editCaptionsSampleHeading => 'Approximate preview';

  @override
  String get editCaptionsSampleLabel => 'Sample captions';

  @override
  String get editCaptionsSpeechDenseHint =>
      'Use smaller text for videos with a lot of speech.';

  @override
  String get editCaptionsFineTuneTitle => 'Fine tune position';

  @override
  String get editCaptionsResetPosition => 'Reset position';

  @override
  String editCaptionsOffsetCompact(int x, int y) {
    return 'X $x · Y $y';
  }

  @override
  String get editCaptionsPresetLabel => 'Preset';

  @override
  String get editCaptionsPresetMinimal => 'Minimal';

  @override
  String get editCaptionsPresetSocial => 'Social';

  @override
  String get editCaptionsPresetBoldYellow => 'Bold Yellow';

  @override
  String get editCaptionsPresetDarkBox => 'Dark Box';

  @override
  String get editCaptionsPresetTopClean => 'Top Clean';

  @override
  String get editCaptionsPresetManualBadge => 'Manual';

  @override
  String get editCaptionsDraftTextSectionTitle => 'Caption text';

  @override
  String get editCaptionsDraftGenerateButton => 'Generate draft';

  @override
  String get editCaptionsDraftReviewHelper =>
      'Review and edit captions before creating the video.';

  @override
  String get editCaptionsDraftLongVideoHelper =>
      'Longer videos may take more time to process.';

  @override
  String get editCaptionsDraftGenerating => 'Generating captions draft...';

  @override
  String get editCaptionsDraftStaleHelper =>
      'Draft captions need to be regenerated after timing changes.';

  @override
  String get editCaptionsDraftRegenerateButton => 'Regenerate draft';

  @override
  String get editCaptionsDraftRegenerateTitle => 'Regenerate draft?';

  @override
  String get editCaptionsDraftRegenerateBody =>
      'This will replace your current caption edits.';

  @override
  String get editCaptionsDraftRegenerateConfirm => 'Regenerate';

  @override
  String get editCaptionsDraftClearSegment => 'Clear caption text';

  @override
  String get editCaptionsDraftEditTitle => 'Edit caption';

  @override
  String get editCaptionsDraftEditClearText => 'Clear text';

  @override
  String get editCaptionsDraftTimingSectionTitle => 'Timing';

  @override
  String get editCaptionsDraftTimingReset => 'Reset timing';

  @override
  String get editCaptionsDraftTimingAdjusted => 'Adjusted';

  @override
  String get editCaptionsDraftTimingEarlier => 'Earlier';

  @override
  String get editCaptionsDraftTimingLater => 'Later';

  @override
  String get editCaptionsV3AddSectionTitle => 'Add captions';

  @override
  String get editCaptionsV3DraftFlowHelper =>
      'Generate a draft, review the text, then create the final video.';

  @override
  String get editCaptionsV3DraftReady => 'Draft ready';

  @override
  String get editCaptionsV3DraftTapHelper =>
      'Tap a caption to edit its text and timing.';

  @override
  String get editCaptionsV3DraftStaleHelper =>
      'Timing changed. Regenerate the draft before creating the video.';

  @override
  String get editCaptionsV3LookSectionTitle => 'Look';

  @override
  String get editCaptionsV3LookHelper =>
      'Choose how captions appear on the final video.';

  @override
  String get editCaptionsV3MoreStylingTitle => 'More styling options';

  @override
  String get editCaptionsV3PreviewLabel => 'Preview';

  @override
  String get editCaptionsV31EditCaptionsButton => 'Edit captions';

  @override
  String get editCaptionsV31DraftEditHelper =>
      'Tap Edit captions to review text and timing before creating the video.';

  @override
  String editCaptionsV31DraftSummaryCount(int count) {
    return '$count captions';
  }

  @override
  String editCaptionsV31DraftSummaryCountAdjusted(
      int count, int adjustedCount) {
    return '$count captions · $adjustedCount adjusted';
  }

  @override
  String get editCaptionsV31Done => 'Done';

  @override
  String get editCaptionsV31StaleBeforeEdit =>
      'Timing changed. Regenerate the draft before editing captions.';

  @override
  String get editCaptionsV31ScreenTitle => 'Edit captions';

  @override
  String get editCaptionsV32SizeXL => 'XL';

  @override
  String get editCaptionsV32SizeXXL => 'XXL';

  @override
  String get editCaptionsSizeXXXL => 'XXXL';

  @override
  String get editCaptionsSizeMega => 'Mega';

  @override
  String get editCaptionsSizeUltra => 'Ultra';

  @override
  String get editCaptionsV32FontLabel => 'Font';

  @override
  String get editCaptionsV32FontDefault => 'Default';

  @override
  String get editCaptionsV32FontHeebo => 'Heebo';

  @override
  String get editCaptionsV32FontRubik => 'Rubik';

  @override
  String get editCaptionsV32FontAssistant => 'Assistant';

  @override
  String get editCaptionsV32FontNotoSansHebrew => 'Noto Sans Hebrew';

  @override
  String get editCaptionsV32AccentLabel => 'Accent';

  @override
  String get editCaptionsV32ColorPurple => 'Purple';

  @override
  String get editCaptionsV32ColorMint => 'Mint';

  @override
  String get editCaptionsV32StyleCleanPro => 'Clean Pro';

  @override
  String get editCaptionsV32StyleBoldSocial => 'Bold Social';

  @override
  String get editCaptionsV32StyleYellowHeadline => 'Yellow Headline';

  @override
  String get editCaptionsV32StyleDarkBubble => 'Dark Bubble';

  @override
  String get editCaptionsV32StyleHighlightBox => 'Highlight Box';

  @override
  String get editCaptionsV32PresetCreatorHighlight => 'Creator Highlight';

  @override
  String get editCaptionsV32PresetNewsHeadline => 'News Headline';

  @override
  String get editCaptionsV33WordHighlightLabel => 'Word highlight';

  @override
  String get editCaptionsV33WordHighlightOff => 'Off';

  @override
  String get editCaptionsV33WordHighlightColor => 'Color';

  @override
  String get editCaptionsV33WordHighlightBox => 'Box';

  @override
  String get editCaptionsV34NormalTextColor => 'Normal text color';

  @override
  String get editCaptionsV35OutlineLabel => 'Text outline';

  @override
  String get editCaptionsV35OutlineOn => 'On';

  @override
  String get editCaptionsV35OutlineOff => 'Off';

  @override
  String get editCaptionsV35OutlineColor => 'Outline color';

  @override
  String get editCaptionsV35OutlineWidth => 'Outline width';

  @override
  String get editCaptionsV35OutlineWidthThin => 'Thin';

  @override
  String get editCaptionsV35OutlineWidthMedium => 'Medium';

  @override
  String get editCaptionsV35OutlineWidthThick => 'Thick';

  @override
  String get editCaptionsV34ActiveWordColor => 'Active word color';

  @override
  String get editCaptionsV34BoxColor => 'Box color';

  @override
  String get editCaptionsV34BoxShape => 'Box shape';

  @override
  String get editCaptionsV34ColorPink => 'Pink';

  @override
  String get editCaptionsV34ColorBlack => 'Black';

  @override
  String get editCaptionsV34BoxShapeRectangle => 'Rectangle';

  @override
  String get editCaptionsV34BoxShapeRounded => 'Rounded';

  @override
  String get editCaptionsV34BoxShapePill => 'Pill';

  @override
  String get editCaptionsV34CustomizeLook => 'Customize look';

  @override
  String get editCaptionsV34LookEditorTitle => 'Caption look';

  @override
  String get editCaptionsV34TabPresets => 'Presets';

  @override
  String get editCaptionsV34TabText => 'Text';

  @override
  String get editCaptionsV34TabHighlight => 'Highlight';

  @override
  String get editCaptionsV34TabPosition => 'Position';

  @override
  String get editCaptionsV34Done => 'Done';

  @override
  String get editCaptionsV34PresetPinkPop => 'Pink Pop';

  @override
  String get editCaptionsV34PresetYellowViral => 'Yellow Viral';

  @override
  String get editCaptionsV34PresetCleanFocus => 'Clean Focus';

  @override
  String get editCaptionsV34HighlightDraftHint =>
      'Highlight follows the spoken words. Generate a draft for more accurate timing.';

  @override
  String get editCaptionsV34HighlightModeOffHint =>
      'Plain captions, no word highlight';

  @override
  String get editCaptionsV34HighlightModeColorHint =>
      'Highlights the active word with color';

  @override
  String get editCaptionsV34HighlightModeBoxHint =>
      'Highlights the active word with a box';

  @override
  String get editCaptionsV34PositionFineTuneHint =>
      'Move captions slightly if they cover important content.';

  @override
  String get editCaptionsV34PanelActiveStatus => 'Captions on';

  @override
  String get editCaptionsV34PanelTurnOff => 'Turn off captions';

  @override
  String get editCaptionsV34PanelLookTitle => 'Caption look';

  @override
  String get editCaptionsV34PanelDraftTitle => 'Caption draft';

  @override
  String get editCaptionsV34PanelDraftHelper =>
      'Review and edit the text before creating the video.';

  @override
  String get editCaptionsV34PanelDraftTimingHint =>
      'Recommended for more accurate timing.';

  @override
  String get editCaptionsV34PanelDraftReady => 'Draft ready';

  @override
  String get editCaptionsV34PanelDraftReadyHelper =>
      'Review and edit captions before creating the video.';

  @override
  String get editCaptionsV34PanelEditCaptions => 'Edit captions';

  @override
  String get editCaptionsV34OffInviteSubtitle =>
      'Turn speech into styled captions for your video.';

  @override
  String get editCaptionsV34EnableCaptions => 'Enable captions';

  @override
  String get editCaptionsV34BenefitDraft => 'Editable draft';

  @override
  String get editCaptionsV34BenefitStyles => 'Caption styles';

  @override
  String get editCaptionsV34BenefitHighlight => 'Word highlight';

  @override
  String get editCaptionsV34SamplePreviewLabel => 'Sample captions';

  @override
  String get editCaptionsPreviewDraftRequiredTitle =>
      'Create a caption draft to preview real captions.';

  @override
  String get editCaptionsPreviewDraftRequiredBody =>
      'The draft includes the caption text and timing. After it is created, style changes like color, outline, position, and word highlight will appear in the preview.';

  @override
  String get editCaptionsPreviewDraftRequiredCta => 'Create caption draft';

  @override
  String get editAudioScreenTitle => 'Edit audio';

  @override
  String get editAudioFileExplanation =>
      'This is an audio file, so some video edits are unavailable.';

  @override
  String get editAudioVideoEditsUnavailable =>
      'Video editing is not available for MP3 files.';

  @override
  String get editAudioAvailableActions => 'Available actions';

  @override
  String get editAudioSaveFileFirst =>
      'Save the file to your device to open or share it.';

  @override
  String get editAudioLimitationsNote =>
      'Audio files support trim, speed, and quality export.';

  @override
  String get downloadCardEditAudio => 'Edit audio';

  @override
  String get downloadCardEditVideo => 'Edit video';

  @override
  String get downloadCardMp3Badge => 'MP3';

  @override
  String get audioEditPreviewTitle => 'Audio preview';

  @override
  String get audioEditTrimTitle => 'Trim audio';

  @override
  String audioEditTrimRange(String range) {
    return 'Range: $range';
  }

  @override
  String get audioEditTrimStart => 'Start';

  @override
  String get audioEditTrimEnd => 'End';

  @override
  String get audioEditResetTrim => 'Reset trim';

  @override
  String get audioEditQualityTitle => 'Audio quality';

  @override
  String get audioEditQualityStandard => 'Standard';

  @override
  String get audioEditQualityHigh => 'High';

  @override
  String get audioEditQualityBest => 'Best';

  @override
  String get audioEditSpeedAndQualityTitle => 'Speed & quality';

  @override
  String get audioEditCreate => 'Create audio edit';

  @override
  String get audioEditNoChangesYet => 'No audio changes yet';

  @override
  String get audioEditChooseOneChange =>
      'Choose at least one change to create an edit';

  @override
  String get audioEditReadyTitle => 'Ready to save';

  @override
  String get audioEditFailed => 'Audio editing failed';

  @override
  String get audioEditRequiresSaveTitle => 'Save file first';

  @override
  String get audioEditRequiresSaveBody =>
      'To edit audio, save the file to your device first.';

  @override
  String get audioEditRequiresSaveNow => 'Save now';

  @override
  String get audioEditRequiresSaveCancel => 'Cancel';

  @override
  String get audioEditCreatingTitle => 'Creating audio edit...';

  @override
  String get audioEditCreatingKeepOpen =>
      'Keep the app open until the edit is complete.';

  @override
  String get audioEditReadySubtitle =>
      'Your edited audio is ready and saved on your device.';

  @override
  String get audioEditSavedOnDevice => 'The file was saved on your device';

  @override
  String audioEditSavedLocationLine(String path) {
    return 'Saved to:\n$path';
  }

  @override
  String get audioEditMoveStartHint => 'Move start point';

  @override
  String get audioEditMoveEndHint => 'Move end point';

  @override
  String get audioEditPlaySelection => 'Play selection';

  @override
  String get audioEditTrimStartMarkerSemantics => 'Start trim handle';

  @override
  String get audioEditTrimEndMarkerSemantics => 'End trim handle';

  @override
  String get audioEditPlayheadSemantics => 'Playback position';

  @override
  String get audioEditPlaySelectionSemantics => 'Play selected segment';

  @override
  String get audioEditPreviewEndingSemantics => 'Preview ending';

  @override
  String get editsFolderName => 'Edits';

  @override
  String get editsSummaryTrimmed => 'Trimmed';

  @override
  String get editsAudioBadge => 'Audio edit';

  @override
  String get editsMp3Badge => 'MP3';

  @override
  String get errorCaptionsWordHighlightNotSupported =>
      'This word highlight option is not supported.';

  @override
  String get errorCaptionsFontFamilyNotSupported =>
      'This caption font is not supported.';

  @override
  String get errorCaptionsDraftUnavailable =>
      'Could not generate captions draft.';

  @override
  String get errorCaptionsStyleNotSupported =>
      'This captions style is not supported.';

  @override
  String get errorCaptionsPositionNotSupported =>
      'This captions position is not supported.';

  @override
  String get errorCaptionsFontSizeNotSupported =>
      'This captions size is not supported.';

  @override
  String get errorCaptionsColorNotSupported =>
      'This captions color is not supported.';

  @override
  String get errorCaptionsTranscriptionUnavailable =>
      'Captions are temporarily unavailable.';

  @override
  String get errorCaptionsGenerationFailed =>
      'Could not create captions for this video.';

  @override
  String get errorCaptionsOptionNotSupported =>
      'This captions option is not supported.';

  @override
  String get errorCaptionSegmentsInvalid => 'The edited captions are invalid.';

  @override
  String get editSpeedSectionTitle => 'Speed';

  @override
  String get editSpeedSectionSubtitle => 'Choose playback speed';

  @override
  String get editSpeedDurationHint =>
      'Changing speed changes the final video duration.';

  @override
  String get editCompressHelperHint => 'Choose final quality and file size';

  @override
  String get editMuteDescription =>
      'Remove the audio track from the edited video';

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
  String get editTrimTimeFieldHint => 'MM:SS';

  @override
  String editTrimPreview(String formatted) {
    return 'Preview: $formatted';
  }

  @override
  String get editTrimTapToEditHint =>
      'Tap to start fresh — type digits here; apply saves as MM:SS.';
}
