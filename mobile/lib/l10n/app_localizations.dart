import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LinkClip'**
  String get appTitle;

  /// No description provided for @bootstrapPreparingApp.
  ///
  /// In en, this message translates to:
  /// **'Preparing the app…'**
  String get bootstrapPreparingApp;

  /// No description provided for @bootstrapConnectingServer.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the server…'**
  String get bootstrapConnectingServer;

  /// No description provided for @bootstrapConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the server'**
  String get bootstrapConnectionFailed;

  /// No description provided for @bootstrapConnectionHint.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get bootstrapConnectionHint;

  /// No description provided for @bootstrapRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get bootstrapRetry;

  /// No description provided for @bootstrapAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get bootstrapAdvancedSettings;

  /// No description provided for @languageSelectButton.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get languageSelectButton;

  /// No description provided for @languageSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get languageSelectTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHebrewOption.
  ///
  /// In en, this message translates to:
  /// **'עברית'**
  String get languageHebrewOption;

  /// No description provided for @languageSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// No description provided for @settingsLanguageRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageRowTitle;

  /// No description provided for @settingsLanguageRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose app language'**
  String get settingsLanguageRowSubtitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'LinkClip'**
  String get homeTitle;

  /// No description provided for @homeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Download videos easily'**
  String get homeHeroTitle;

  /// No description provided for @homeHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share a video or paste a link to get started.'**
  String get homeHeroSubtitle;

  /// No description provided for @homeHeroSubtitleCompact.
  ///
  /// In en, this message translates to:
  /// **'Share a video or paste a link to get started.'**
  String get homeHeroSubtitleCompact;

  /// No description provided for @homeShareTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: Tap Share in Instagram, Facebook or TikTok, then choose LinkClip.'**
  String get homeShareTip;

  /// No description provided for @homePasteLinkFab.
  ///
  /// In en, this message translates to:
  /// **'Paste a link'**
  String get homePasteLinkFab;

  /// No description provided for @homePasteLinkShort.
  ///
  /// In en, this message translates to:
  /// **'Paste link here'**
  String get homePasteLinkShort;

  /// No description provided for @homeRecentDownloads.
  ///
  /// In en, this message translates to:
  /// **'Recent downloads'**
  String get homeRecentDownloads;

  /// No description provided for @homeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get homeLoading;

  /// No description provided for @homeErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get homeErrorGeneric;

  /// No description provided for @homeRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetry;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No downloads yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shared or pasted videos will appear here.'**
  String get homeEmptySubtitle;

  /// No description provided for @homePasteLinkButton.
  ///
  /// In en, this message translates to:
  /// **'Paste a link'**
  String get homePasteLinkButton;

  /// No description provided for @homeQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get homeQuickActionsTitle;

  /// No description provided for @homeActionPasteLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste link'**
  String get homeActionPasteLinkTitle;

  /// No description provided for @homeActionPasteLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From the web'**
  String get homeActionPasteLinkSubtitle;

  /// No description provided for @homeActionEditVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get homeActionEditVideoTitle;

  /// No description provided for @homeActionEditVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From device'**
  String get homeActionEditVideoSubtitle;

  /// No description provided for @homeTabDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get homeTabDownloads;

  /// No description provided for @homeTabEdits.
  ///
  /// In en, this message translates to:
  /// **'Edits'**
  String get homeTabEdits;

  /// No description provided for @homeNoEditsTitle.
  ///
  /// In en, this message translates to:
  /// **'No edits yet'**
  String get homeNoEditsTitle;

  /// No description provided for @homeNoEditsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit a video from your device or from an existing download, and your edits will appear here.'**
  String get homeNoEditsSubtitle;

  /// No description provided for @editsFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get editsFilterToday;

  /// No description provided for @editsFilterTwoDays.
  ///
  /// In en, this message translates to:
  /// **'2 days'**
  String get editsFilterTwoDays;

  /// No description provided for @editsFilterThreeDays.
  ///
  /// In en, this message translates to:
  /// **'3 days'**
  String get editsFilterThreeDays;

  /// No description provided for @editsFilterWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get editsFilterWeek;

  /// No description provided for @editsFilterTwoWeeks.
  ///
  /// In en, this message translates to:
  /// **'2 weeks'**
  String get editsFilterTwoWeeks;

  /// No description provided for @editsFilterMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get editsFilterMonth;

  /// No description provided for @editsFilterUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get editsFilterUnlimited;

  /// No description provided for @editsDeletedLocally.
  ///
  /// In en, this message translates to:
  /// **'Deleted locally'**
  String get editsDeletedLocally;

  /// No description provided for @editsFromDevice.
  ///
  /// In en, this message translates to:
  /// **'From device'**
  String get editsFromDevice;

  /// No description provided for @editsFromDownload.
  ///
  /// In en, this message translates to:
  /// **'From download'**
  String get editsFromDownload;

  /// No description provided for @editsFileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File unavailable'**
  String get editsFileUnavailable;

  /// No description provided for @editsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get editsOpen;

  /// No description provided for @editsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get editsShare;

  /// No description provided for @editsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editsSave;

  /// No description provided for @editsNoItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'No edits yet'**
  String get editsNoItemsTitle;

  /// No description provided for @editsNoItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit a video from your device or from an existing download, and your edits will appear here.'**
  String get editsNoItemsSubtitle;

  /// No description provided for @editsRemoveFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get editsRemoveFromHistory;

  /// No description provided for @deleteEditFromApp.
  ///
  /// In en, this message translates to:
  /// **'Delete from app'**
  String get deleteEditFromApp;

  /// No description provided for @deleteEditFromAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this edit from the app?'**
  String get deleteEditFromAppTitle;

  /// No description provided for @deleteEditFromAppBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the edit from history and app storage. Files you saved to your device will not be deleted.'**
  String get deleteEditFromAppBody;

  /// No description provided for @removeEditFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get removeEditFromList;

  /// No description provided for @editedVideoFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Edited video'**
  String get editedVideoFallbackTitle;

  /// No description provided for @homeInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid link.'**
  String get homeInvalidLink;

  /// No description provided for @homePasteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a link'**
  String get homePasteDialogTitle;

  /// No description provided for @homePasteDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the link from the original app here.'**
  String get homePasteDialogHint;

  /// No description provided for @homeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get homeCancel;

  /// No description provided for @homeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get homeContinue;

  /// No description provided for @homeDeleteDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get homeDeleteDownloadTitle;

  /// No description provided for @homeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get homeDeleteConfirm;

  /// No description provided for @downloadCardStatusDetails.
  ///
  /// In en, this message translates to:
  /// **'Status details'**
  String get downloadCardStatusDetails;

  /// No description provided for @downloadCardRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadCardRetry;

  /// No description provided for @downloadCardDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get downloadCardDelete;

  /// No description provided for @downloadCardActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get downloadCardActionsTitle;

  /// No description provided for @durationChip.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}'**
  String durationChip(String duration);

  /// No description provided for @analyzeTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze link'**
  String get analyzeTitle;

  /// No description provided for @analyzeLoading.
  ///
  /// In en, this message translates to:
  /// **'Analyzing video…'**
  String get analyzeLoading;

  /// No description provided for @analyzeVideoFound.
  ///
  /// In en, this message translates to:
  /// **'Video found'**
  String get analyzeVideoFound;

  /// No description provided for @analyzeChooseQuality.
  ///
  /// In en, this message translates to:
  /// **'Choose quality'**
  String get analyzeChooseQuality;

  /// No description provided for @analyzePrepareDownload.
  ///
  /// In en, this message translates to:
  /// **'Prepare download'**
  String get analyzePrepareDownload;

  /// No description provided for @analyzeMissingLink.
  ///
  /// In en, this message translates to:
  /// **'Missing link.'**
  String get analyzeMissingLink;

  /// No description provided for @analyzeQualityUnavailableSnack.
  ///
  /// In en, this message translates to:
  /// **'This quality is not available for this video.'**
  String get analyzeQualityUnavailableSnack;

  /// No description provided for @formatBestMp4.
  ///
  /// In en, this message translates to:
  /// **'Best MP4'**
  String get formatBestMp4;

  /// No description provided for @format1080pMp4.
  ///
  /// In en, this message translates to:
  /// **'1080p MP4'**
  String get format1080pMp4;

  /// No description provided for @format720pMp4.
  ///
  /// In en, this message translates to:
  /// **'720p MP4'**
  String get format720pMp4;

  /// No description provided for @format480pMp4.
  ///
  /// In en, this message translates to:
  /// **'480p MP4'**
  String get format480pMp4;

  /// No description provided for @formatAudioMp3.
  ///
  /// In en, this message translates to:
  /// **'Audio MP3'**
  String get formatAudioMp3;

  /// No description provided for @qualityTikTokReady.
  ///
  /// In en, this message translates to:
  /// **'TikTok-ready MP4'**
  String get qualityTikTokReady;

  /// No description provided for @qualityTikTokReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'Optimized for TikTok and social apps. May take longer.'**
  String get qualityTikTokReadyDescription;

  /// No description provided for @qualityTikTokReadyBadge.
  ///
  /// In en, this message translates to:
  /// **'Recommended for upload'**
  String get qualityTikTokReadyBadge;

  /// No description provided for @downloadPreparingTikTokReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing TikTok-ready video'**
  String get downloadPreparingTikTokReadyTitle;

  /// No description provided for @downloadPreparingTikTokReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'This video is being optimized for TikTok and social apps. It may take a few minutes.'**
  String get downloadPreparingTikTokReadySubtitle;

  /// No description provided for @downloadChipTikTokReady.
  ///
  /// In en, this message translates to:
  /// **'TikTok-ready'**
  String get downloadChipTikTokReady;

  /// No description provided for @qualityUnavailableForVideo.
  ///
  /// In en, this message translates to:
  /// **'Not available for this video'**
  String get qualityUnavailableForVideo;

  /// No description provided for @downloadStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Download status'**
  String get downloadStatusTitle;

  /// No description provided for @downloadStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadStatusQueued;

  /// No description provided for @downloadStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Preparing your video…'**
  String get downloadStatusRunning;

  /// No description provided for @downloadStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Ready to save'**
  String get downloadStatusDone;

  /// No description provided for @downloadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadStatusFailed;

  /// No description provided for @downloadStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get downloadStatusCanceled;

  /// No description provided for @downloadStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get downloadStatusUnknown;

  /// No description provided for @downloadVideoReadyHint.
  ///
  /// In en, this message translates to:
  /// **'The video is ready to save to your device.'**
  String get downloadVideoReadyHint;

  /// No description provided for @downloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed: {speed}'**
  String downloadSpeed(String speed);

  /// No description provided for @downloadEta.
  ///
  /// In en, this message translates to:
  /// **'ETA: {eta}'**
  String downloadEta(String eta);

  /// No description provided for @downloadRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get downloadRetry;

  /// No description provided for @downloadSaveToDevice.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get downloadSaveToDevice;

  /// No description provided for @downloadOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get downloadOpen;

  /// No description provided for @downloadShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get downloadShare;

  /// No description provided for @mediaExportDownloadsWord.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get mediaExportDownloadsWord;

  /// No description provided for @downloadSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'The video was saved to:\n{path}'**
  String downloadSavedToDownloads(String path);

  /// No description provided for @downloadSavedInAppOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved inside the app.\nCouldn\'t copy to public Downloads right now:\n{path}'**
  String downloadSavedInAppOnly(String path);

  /// No description provided for @downloadSavedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get downloadSavedGeneric;

  /// No description provided for @untitledVideo.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledVideo;

  /// No description provided for @unknownPlatform.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownPlatform;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get errorNetwork;

  /// No description provided for @errorBadRequest.
  ///
  /// In en, this message translates to:
  /// **'Invalid request.'**
  String get errorBadRequest;

  /// No description provided for @errorUnsupportedQuality.
  ///
  /// In en, this message translates to:
  /// **'The selected quality is not supported. Try another quality.'**
  String get errorUnsupportedQuality;

  /// No description provided for @errorNoSharedLink.
  ///
  /// In en, this message translates to:
  /// **'No shared link was found.'**
  String get errorNoSharedLink;

  /// No description provided for @errorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorUnexpected;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'You are not authorized.'**
  String get errorUnauthorized;

  /// No description provided for @errorInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid link.'**
  String get errorInvalidUrl;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached.'**
  String get errorRateLimited;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'Another download is already in progress.'**
  String get errorConflict;

  /// No description provided for @errorJobNotFound.
  ///
  /// In en, this message translates to:
  /// **'Download not found.'**
  String get errorJobNotFound;

  /// No description provided for @errorFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get errorFileNotFound;

  /// No description provided for @errorAnalyzeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not analyze the link.'**
  String get errorAnalyzeFailed;

  /// No description provided for @errorDrmProtected.
  ///
  /// In en, this message translates to:
  /// **'This link can\'t be downloaded because the content is DRM-protected.'**
  String get errorDrmProtected;

  /// No description provided for @errorThreadsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Threads links are not supported for download yet. Try an Instagram, TikTok, Facebook, or YouTube link.'**
  String get errorThreadsUnsupported;

  /// No description provided for @errorPlatformUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This link is not supported for download yet. Try an Instagram, TikTok, Facebook, or YouTube link.'**
  String get errorPlatformUnsupported;

  /// No description provided for @errorAnalyzeMetadataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not load format options for this video. The link may be restricted or temporarily unavailable.'**
  String get errorAnalyzeMetadataUnavailable;

  /// No description provided for @errorFacebookExtractFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read this Facebook video right now. This link may require special access or Facebook may be blocking access to it. Try another link or try again later.'**
  String get errorFacebookExtractFailed;

  /// No description provided for @errorServerUrlInvalidConfig.
  ///
  /// In en, this message translates to:
  /// **'The server address is invalid. Check settings and try again.'**
  String get errorServerUrlInvalidConfig;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsServerUrl;

  /// No description provided for @settingsDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get settingsDeviceId;

  /// No description provided for @settingsBundledProductionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bundled default production server (https://api.linkclip.win).'**
  String get settingsBundledProductionSubtitle;

  /// No description provided for @settingsBundledFromBuildSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Using URL from app build (--dart-define).'**
  String get settingsBundledFromBuildSubtitle;

  /// No description provided for @settingsRefreshDevice.
  ///
  /// In en, this message translates to:
  /// **'Refresh device info'**
  String get settingsRefreshDevice;

  /// No description provided for @settingsAdvancedDevelopers.
  ///
  /// In en, this message translates to:
  /// **'Advanced / developer'**
  String get settingsAdvancedDevelopers;

  /// No description provided for @settingsAdvancedCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Custom server'**
  String get settingsAdvancedCustomSubtitle;

  /// No description provided for @settingsAdvancedDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bundled default server'**
  String get settingsAdvancedDefaultSubtitle;

  /// No description provided for @settingsServerFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL (LAN / testing)'**
  String get settingsServerFieldLabel;

  /// No description provided for @settingsServerFieldHint.
  ///
  /// In en, this message translates to:
  /// **'https://… or http://192.168.x.x:3000'**
  String get settingsServerFieldHint;

  /// No description provided for @settingsSaveCustomServer.
  ///
  /// In en, this message translates to:
  /// **'Save custom server and reconnect'**
  String get settingsSaveCustomServer;

  /// No description provided for @settingsRevertToBakedServer.
  ///
  /// In en, this message translates to:
  /// **'Use bundled default server'**
  String get settingsRevertToBakedServer;

  /// No description provided for @settingsAdvancedFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Advanced: use a LAN or staging API base URL. Clearing the field restores the bundled default (production, or the URL from --dart-define when set). You will sign in again after changing servers.'**
  String get settingsAdvancedFooterNote;

  /// No description provided for @settingsFactoryResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get settingsFactoryResetTitle;

  /// No description provided for @settingsFactoryResetBody.
  ///
  /// In en, this message translates to:
  /// **'This clears local sign-in and saved history on this device.'**
  String get settingsFactoryResetBody;

  /// No description provided for @settingsFactoryResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsFactoryResetConfirm;

  /// No description provided for @settingsEnterServerSnack.
  ///
  /// In en, this message translates to:
  /// **'Enter a server URL.'**
  String get settingsEnterServerSnack;

  /// No description provided for @settingsInvalidServerSnack.
  ///
  /// In en, this message translates to:
  /// **'Invalid server URL.'**
  String get settingsInvalidServerSnack;

  /// No description provided for @settingsServerUpdatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Server updated. Signing in again.'**
  String get settingsServerUpdatedSnack;

  /// No description provided for @settingsNoBakedUrlSnack.
  ///
  /// In en, this message translates to:
  /// **'No baked-in server URL in this build.'**
  String get settingsNoBakedUrlSnack;

  /// No description provided for @settingsRevertSnack.
  ///
  /// In en, this message translates to:
  /// **'Using the bundled default server. Sign in again.'**
  String get settingsRevertSnack;

  /// No description provided for @settingsEmptyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get settingsEmptyPlaceholder;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register device'**
  String get registerTitle;

  /// No description provided for @registerIntroHelper.
  ///
  /// In en, this message translates to:
  /// **'Tap Register device to start. No manual server setup is needed.'**
  String get registerIntroHelper;

  /// No description provided for @registerSecureServerLine.
  ///
  /// In en, this message translates to:
  /// **'Secure server: https://api.linkclip.win'**
  String get registerSecureServerLine;

  /// No description provided for @registerHaveInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Have an invite code?'**
  String get registerHaveInviteCode;

  /// No description provided for @registerSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get registerSettingsTooltip;

  /// No description provided for @registerServerSection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get registerServerSection;

  /// No description provided for @registerServerNotSet.
  ///
  /// In en, this message translates to:
  /// **'(not set)'**
  String get registerServerNotSet;

  /// No description provided for @registerServerBakedHint.
  ///
  /// In en, this message translates to:
  /// **'Using the bundled default server URL. For a custom staging or LAN server, open Settings → Advanced.'**
  String get registerServerBakedHint;

  /// No description provided for @registerServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get registerServerUrlLabel;

  /// No description provided for @registerInviteOptional.
  ///
  /// In en, this message translates to:
  /// **'Invite code (optional)'**
  String get registerInviteOptional;

  /// No description provided for @registerDeviceNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Device name (optional)'**
  String get registerDeviceNameOptional;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Register device'**
  String get registerSubmit;

  /// No description provided for @registerValidationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get registerValidationRequired;

  /// No description provided for @registerValidationBadUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL'**
  String get registerValidationBadUrl;

  /// No description provided for @registerNeedServer.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server URL or update advanced settings.'**
  String get registerNeedServer;

  /// No description provided for @registerInvalidServerHost.
  ///
  /// In en, this message translates to:
  /// **'Invalid server address.'**
  String get registerInvalidServerHost;

  /// No description provided for @autoRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get autoRegisterTitle;

  /// No description provided for @autoRegisterConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the server…'**
  String get autoRegisterConnecting;

  /// No description provided for @autoRegisterFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get autoRegisterFailedGeneric;

  /// No description provided for @autoRegisterManualSetup.
  ///
  /// In en, this message translates to:
  /// **'Manual / advanced setup'**
  String get autoRegisterManualSetup;

  /// No description provided for @downloadJobErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not download in an available format.'**
  String get downloadJobErrorGeneric;

  /// No description provided for @downloadJobErrorQuality.
  ///
  /// In en, this message translates to:
  /// **'The selected quality is not available for this video. Try another quality or Best MP4.'**
  String get downloadJobErrorQuality;

  /// No description provided for @downloadJobErrorNormalizeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the video in a supported format.'**
  String get downloadJobErrorNormalizeFailed;

  /// No description provided for @downloadErrorInstagramRestricted.
  ///
  /// In en, this message translates to:
  /// **'This Instagram video can\'t be downloaded right now. It may be restricted, require login, or be temporarily blocked. Try another link.'**
  String get downloadErrorInstagramRestricted;

  /// No description provided for @downloadErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again or use another link.'**
  String get downloadErrorGeneric;

  /// No description provided for @downloadErrorUnsupportedOrPrivate.
  ///
  /// In en, this message translates to:
  /// **'This link can\'t be downloaded. The content may be private, removed, or unsupported.'**
  String get downloadErrorUnsupportedOrPrivate;

  /// No description provided for @openDescription.
  ///
  /// In en, this message translates to:
  /// **'Open description'**
  String get openDescription;

  /// No description provided for @hideDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide description'**
  String get hideDescription;

  /// No description provided for @shareNoLinkInContent.
  ///
  /// In en, this message translates to:
  /// **'No shared link was found.'**
  String get shareNoLinkInContent;

  /// No description provided for @settingsMeStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'System status'**
  String get settingsMeStatusLabel;

  /// No description provided for @settingsMeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name on server'**
  String get settingsMeNameLabel;

  /// No description provided for @settingsMeDailyDownloadsLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily download limit'**
  String get settingsMeDailyDownloadsLabel;

  /// No description provided for @settingsMeDailyAnalyzeLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily analyze limit'**
  String get settingsMeDailyAnalyzeLabel;

  /// No description provided for @savedMustDownloadFirst.
  ///
  /// In en, this message translates to:
  /// **'Download the file to your device first.'**
  String get savedMustDownloadFirst;

  /// No description provided for @savedCannotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file.'**
  String get savedCannotOpenFile;

  /// No description provided for @savedCannotShareFile.
  ///
  /// In en, this message translates to:
  /// **'Could not share the file.'**
  String get savedCannotShareFile;

  /// No description provided for @savedShareFailedHint.
  ///
  /// In en, this message translates to:
  /// **'Sharing failed. Try opening the file or sharing from your files app.'**
  String get savedShareFailedHint;

  /// No description provided for @analyzeDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}'**
  String analyzeDurationLabel(String duration);

  /// No description provided for @shareAnalyzingVideo.
  ///
  /// In en, this message translates to:
  /// **'Analyzing shared video…'**
  String get shareAnalyzingVideo;

  /// No description provided for @shareLinkFound.
  ///
  /// In en, this message translates to:
  /// **'Shared link found'**
  String get shareLinkFound;

  /// No description provided for @loadingAnalyzingDot.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get loadingAnalyzingDot;

  /// No description provided for @analyzeProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checking the video and preparing available formats.'**
  String get analyzeProcessingSubtitle;

  /// No description provided for @downloadProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading and processing your video.'**
  String get downloadProcessingSubtitle;

  /// No description provided for @downloadLoadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing your download and connecting to the server.'**
  String get downloadLoadingSubtitle;

  /// No description provided for @fileNoLongerAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'This file is no longer available'**
  String get fileNoLongerAvailableTitle;

  /// No description provided for @fileNoLongerAvailableRedownloadBody.
  ///
  /// In en, this message translates to:
  /// **'To continue, download it again.'**
  String get fileNoLongerAvailableRedownloadBody;

  /// No description provided for @downloadAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get downloadAgainAction;

  /// No description provided for @uploadSourceNoLongerAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'The uploaded video is no longer available. Choose it again.'**
  String get uploadSourceNoLongerAvailableBody;

  /// No description provided for @chooseAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Choose it again'**
  String get chooseAgainAction;

  /// No description provided for @keepAppOpenUntilFinished.
  ///
  /// In en, this message translates to:
  /// **'We recommend keeping the app open until this finishes.'**
  String get keepAppOpenUntilFinished;

  /// No description provided for @keepAppOpenUntilAnalyzeFinished.
  ///
  /// In en, this message translates to:
  /// **'We recommend keeping the app open until analysis finishes.'**
  String get keepAppOpenUntilAnalyzeFinished;

  /// No description provided for @keepAppOpenUntilDownloadFinished.
  ///
  /// In en, this message translates to:
  /// **'We recommend keeping the app open until the download finishes.'**
  String get keepAppOpenUntilDownloadFinished;

  /// No description provided for @keepAppOpenUntilUploadFinished.
  ///
  /// In en, this message translates to:
  /// **'We recommend keeping the app open until the upload finishes.'**
  String get keepAppOpenUntilUploadFinished;

  /// No description provided for @keepAppOpenUntilEditFinished.
  ///
  /// In en, this message translates to:
  /// **'We recommend keeping the app open until the edit finishes.'**
  String get keepAppOpenUntilEditFinished;

  /// No description provided for @editServerOutputUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This edited video is no longer on the server and wasn\'t found on your device.'**
  String get editServerOutputUnavailable;

  /// No description provided for @loadingPreparingDownloadDot.
  ///
  /// In en, this message translates to:
  /// **'Preparing download…'**
  String get loadingPreparingDownloadDot;

  /// No description provided for @loadingDownloadingDot.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get loadingDownloadingDot;

  /// No description provided for @loadingSavingToDeviceDot.
  ///
  /// In en, this message translates to:
  /// **'Saving to device…'**
  String get loadingSavingToDeviceDot;

  /// No description provided for @loadingFinalizingDot.
  ///
  /// In en, this message translates to:
  /// **'Finalizing…'**
  String get loadingFinalizingDot;

  /// No description provided for @downloadStageQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadStageQueued;

  /// No description provided for @downloadStagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get downloadStagePreparing;

  /// No description provided for @downloadStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloadStageDownloading;

  /// No description provided for @downloadStageFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing…'**
  String get downloadStageFinalizing;

  /// No description provided for @downloadStageReadyServer.
  ///
  /// In en, this message translates to:
  /// **'Ready — save to your device'**
  String get downloadStageReadyServer;

  /// No description provided for @downloadStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadStageFailed;

  /// No description provided for @downloadStageCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get downloadStageCanceled;

  /// No description provided for @downloadStageUnknown.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get downloadStageUnknown;

  /// No description provided for @downloadPercentValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String downloadPercentValue(int percent);

  /// No description provided for @downloadStatusSavedOnDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved on device'**
  String get downloadStatusSavedOnDeviceTitle;

  /// No description provided for @downloadStatusLoadingJob.
  ///
  /// In en, this message translates to:
  /// **'Loading download…'**
  String get downloadStatusLoadingJob;

  /// No description provided for @stageQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get stageQueued;

  /// No description provided for @stagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing your video...'**
  String get stagePreparing;

  /// No description provided for @stageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get stageDownloading;

  /// No description provided for @stageCheckingCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Checking video compatibility...'**
  String get stageCheckingCompatibility;

  /// No description provided for @stageRemuxing.
  ///
  /// In en, this message translates to:
  /// **'Preparing video...'**
  String get stageRemuxing;

  /// No description provided for @stageNormalizingAudio.
  ///
  /// In en, this message translates to:
  /// **'Optimizing audio...'**
  String get stageNormalizingAudio;

  /// No description provided for @stageFullTranscoding.
  ///
  /// In en, this message translates to:
  /// **'Processing video...'**
  String get stageFullTranscoding;

  /// No description provided for @stageFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing...'**
  String get stageFinalizing;

  /// No description provided for @stageDone.
  ///
  /// In en, this message translates to:
  /// **'Ready to save'**
  String get stageDone;

  /// No description provided for @stageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get stageFailed;

  /// No description provided for @fullTranscodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Extra processing needed'**
  String get fullTranscodeTitle;

  /// No description provided for @fullTranscodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This video needs extra processing to work well with TikTok and other apps. It may take a few minutes.'**
  String get fullTranscodeSubtitle;

  /// No description provided for @progressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String progressPercent(int percent);

  /// No description provided for @downloadUnknownProgress.
  ///
  /// In en, this message translates to:
  /// **'Working on it...'**
  String get downloadUnknownProgress;

  /// No description provided for @bootstrapLoadingShort.
  ///
  /// In en, this message translates to:
  /// **'Starting LinkClip…'**
  String get bootstrapLoadingShort;

  /// No description provided for @editScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get editScreenTitle;

  /// No description provided for @editExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get editExit;

  /// No description provided for @editSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editSave;

  /// No description provided for @editCreateEdit.
  ///
  /// In en, this message translates to:
  /// **'Create edit'**
  String get editCreateEdit;

  /// No description provided for @editDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editDoneButton;

  /// No description provided for @editTrimSelectedRange.
  ///
  /// In en, this message translates to:
  /// **'Selected range: {start}–{end}'**
  String editTrimSelectedRange(String start, String end);

  /// No description provided for @editTrimRemovedLine.
  ///
  /// In en, this message translates to:
  /// **'Removed: {duration}'**
  String editTrimRemovedLine(String duration);

  /// No description provided for @editCreatingEdit.
  ///
  /// In en, this message translates to:
  /// **'Creating your edit...'**
  String get editCreatingEdit;

  /// No description provided for @editCreatingEditKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'We recommend keeping the app open until this finishes.'**
  String get editCreatingEditKeepOpen;

  /// No description provided for @editTrimSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get editTrimSectionTitle;

  /// No description provided for @editTrimVideoDuration.
  ///
  /// In en, this message translates to:
  /// **'Video duration'**
  String get editTrimVideoDuration;

  /// No description provided for @editTrimSelectedClip.
  ///
  /// In en, this message translates to:
  /// **'Selected clip'**
  String get editTrimSelectedClip;

  /// No description provided for @editTrimRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get editTrimRemoved;

  /// No description provided for @editTrimStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get editTrimStart;

  /// No description provided for @editTrimEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get editTrimEnd;

  /// No description provided for @editTrimReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get editTrimReset;

  /// No description provided for @editCropOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get editCropOriginal;

  /// No description provided for @editFormatVideoShapeTitle.
  ///
  /// In en, this message translates to:
  /// **'Video shape'**
  String get editFormatVideoShapeTitle;

  /// No description provided for @editFormatVideoShapeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose aspect presets.'**
  String get editFormatVideoShapeSubtitle;

  /// No description provided for @editFormatFitModeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'How should it fit?'**
  String get editFormatFitModeSectionTitle;

  /// No description provided for @editFormatFitModeNeedsShapeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a format like 9:16 to decide whether to crop or keep the full video.'**
  String get editFormatFitModeNeedsShapeHint;

  /// No description provided for @editFormatFitOptionFill.
  ///
  /// In en, this message translates to:
  /// **'Fill screen'**
  String get editFormatFitOptionFill;

  /// No description provided for @editFormatFitOptionFit.
  ///
  /// In en, this message translates to:
  /// **'Keep all'**
  String get editFormatFitOptionFit;

  /// No description provided for @editFormatFitFillExplanation.
  ///
  /// In en, this message translates to:
  /// **'Fill screen — fills the frame and may crop edges.'**
  String get editFormatFitFillExplanation;

  /// No description provided for @editFormatFitFitExplanation.
  ///
  /// In en, this message translates to:
  /// **'Keep all — keeps the full video with a blurred background.'**
  String get editFormatFitFitExplanation;

  /// No description provided for @editFormatRotationTitle.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get editFormatRotationTitle;

  /// No description provided for @editFormatRotationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rotate the video before fitting it to the selected shape.'**
  String get editFormatRotationSubtitle;

  /// No description provided for @editMuteLabel.
  ///
  /// In en, this message translates to:
  /// **'Mute audio'**
  String get editMuteLabel;

  /// No description provided for @editCompressSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get editCompressSectionTitle;

  /// No description provided for @editCompressOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original quality'**
  String get editCompressOriginal;

  /// No description provided for @editCompressSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get editCompressSocial;

  /// No description provided for @editCompressSmall.
  ///
  /// In en, this message translates to:
  /// **'Small file'**
  String get editCompressSmall;

  /// No description provided for @editChooseAtLeastOneChange.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one change to create an edit'**
  String get editChooseAtLeastOneChange;

  /// No description provided for @editPreviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading preview…'**
  String get editPreviewLoading;

  /// No description provided for @editPreviewError.
  ///
  /// In en, this message translates to:
  /// **'Could not load video info.'**
  String get editPreviewError;

  /// No description provided for @editDurationApproxHint.
  ///
  /// In en, this message translates to:
  /// **'Duration is approximate until loaded.'**
  String get editDurationApproxHint;

  /// No description provided for @editLocalVideoComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Editing a video from your device is coming soon'**
  String get editLocalVideoComingSoon;

  /// No description provided for @editLocalVideoSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a short video to edit'**
  String get editLocalVideoSheetTitle;

  /// No description provided for @editLocalVideoLimitsNote.
  ///
  /// In en, this message translates to:
  /// **'Videos up to 7 minutes and 175MB'**
  String get editLocalVideoLimitsNote;

  /// No description provided for @editLocalVideoPickMedia.
  ///
  /// In en, this message translates to:
  /// **'Device media'**
  String get editLocalVideoPickMedia;

  /// No description provided for @editLocalVideoPickFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get editLocalVideoPickFiles;

  /// No description provided for @editLocalVideoUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading your video for editing...'**
  String get editLocalVideoUploading;

  /// No description provided for @downloadCardEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get downloadCardEdit;

  /// No description provided for @editSourceExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'The video expired on the server'**
  String get editSourceExpiredTitle;

  /// No description provided for @editSourceExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'To edit this video, download it again. After the download finishes, you\'ll be able to edit it right away.'**
  String get editSourceExpiredBody;

  /// No description provided for @editSourceExpiredDownloadNow.
  ///
  /// In en, this message translates to:
  /// **'Download now'**
  String get editSourceExpiredDownloadNow;

  /// No description provided for @editSourceExpiredCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editSourceExpiredCancel;

  /// No description provided for @editSourceMissingOriginalUrl.
  ///
  /// In en, this message translates to:
  /// **'The original link is missing. Paste the link again to download and edit it.'**
  String get editSourceMissingOriginalUrl;

  /// No description provided for @editProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving your edit…'**
  String get editProcessingTitle;

  /// No description provided for @editProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The edited file will be saved on your device'**
  String get editProcessingSubtitle;

  /// No description provided for @editProcessingServerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re editing your video on LinkClip. This usually takes a few seconds.'**
  String get editProcessingServerSubtitle;

  /// No description provided for @editProcessingDontClose.
  ///
  /// In en, this message translates to:
  /// **'Do not close the app'**
  String get editProcessingDontClose;

  /// No description provided for @editProcessingSecondsHint.
  ///
  /// In en, this message translates to:
  /// **'This should only take a few seconds'**
  String get editProcessingSecondsHint;

  /// No description provided for @editProcessingDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading edited file…'**
  String get editProcessingDownloading;

  /// No description provided for @editDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your edit is ready'**
  String get editDoneTitle;

  /// No description provided for @editDoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The edited file is ready.\nThe video was saved to:\n{path}'**
  String editDoneSubtitle(String path);

  /// No description provided for @editExportOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get editExportOpen;

  /// No description provided for @editExportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get editExportShare;

  /// No description provided for @editExportSave.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get editExportSave;

  /// No description provided for @editFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Editing failed'**
  String get editFailedTitle;

  /// No description provided for @editTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get editTryAgain;

  /// No description provided for @editSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'The video was saved to:\n{path}'**
  String editSavedToDownloads(String path);

  /// No description provided for @editSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save the video right now.'**
  String get editSaveFailed;

  /// No description provided for @errorEditJobNotFound.
  ///
  /// In en, this message translates to:
  /// **'Edit job not found.'**
  String get errorEditJobNotFound;

  /// No description provided for @errorEditInvalidSource.
  ///
  /// In en, this message translates to:
  /// **'This video cannot be edited right now.'**
  String get errorEditInvalidSource;

  /// No description provided for @errorEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Edit processing failed.'**
  String get errorEditFailed;

  /// No description provided for @errorUploadFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This video is too large to edit right now. You can upload videos up to 175MB.'**
  String get errorUploadFileTooLarge;

  /// No description provided for @errorUploadVideoTooLong.
  ///
  /// In en, this message translates to:
  /// **'This video is too long to edit right now. You can upload clips up to 7 minutes.'**
  String get errorUploadVideoTooLong;

  /// No description provided for @errorUploadUnsupportedType.
  ///
  /// In en, this message translates to:
  /// **'This file type is not supported. Try an MP4 video.'**
  String get errorUploadUnsupportedType;

  /// No description provided for @errorUploadInvalidVideo.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t read this video. Try another video.'**
  String get errorUploadInvalidVideo;

  /// No description provided for @errorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t upload this video. Try again.'**
  String get errorUploadFailed;

  /// No description provided for @errorUploadSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The uploaded video is no longer available. Choose it again.'**
  String get errorUploadSourceUnavailable;

  /// No description provided for @errorEditUploadNotReady.
  ///
  /// In en, this message translates to:
  /// **'The uploaded video is not ready for editing yet. Try again in a moment.'**
  String get errorEditUploadNotReady;

  /// No description provided for @errorEditSourceRequired.
  ///
  /// In en, this message translates to:
  /// **'No edit source was selected.'**
  String get errorEditSourceRequired;

  /// No description provided for @errorEditMultipleSources.
  ///
  /// In en, this message translates to:
  /// **'Too many edit sources were selected. Try again.'**
  String get errorEditMultipleSources;

  /// No description provided for @errorUnsupportedSpeedFactor.
  ///
  /// In en, this message translates to:
  /// **'This speed option is not supported.'**
  String get errorUnsupportedSpeedFactor;

  /// No description provided for @errorUnsupportedFormatMode.
  ///
  /// In en, this message translates to:
  /// **'This format mode is not supported.'**
  String get errorUnsupportedFormatMode;

  /// No description provided for @errorUnsupportedRotation.
  ///
  /// In en, this message translates to:
  /// **'This rotation option is not supported.'**
  String get errorUnsupportedRotation;

  /// No description provided for @editStageQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to start…'**
  String get editStageQueued;

  /// No description provided for @editStageValidating.
  ///
  /// In en, this message translates to:
  /// **'Checking the video…'**
  String get editStageValidating;

  /// No description provided for @editStageProbing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the video for editing…'**
  String get editStageProbing;

  /// No description provided for @editStageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Editing the video…'**
  String get editStageProcessing;

  /// No description provided for @editStageFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing and saving…'**
  String get editStageFinalizing;

  /// No description provided for @editStageDone.
  ///
  /// In en, this message translates to:
  /// **'Your edit is ready'**
  String get editStageDone;

  /// No description provided for @editStageFailed.
  ///
  /// In en, this message translates to:
  /// **'Editing failed'**
  String get editStageFailed;

  /// No description provided for @editLeaveWhileProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave editing?'**
  String get editLeaveWhileProcessingTitle;

  /// No description provided for @editLeaveWhileProcessingBody.
  ///
  /// In en, this message translates to:
  /// **'Your edit is still processing. Leaving now will not cancel the server job, but you will need to reopen this screen to see progress.'**
  String get editLeaveWhileProcessingBody;

  /// No description provided for @editTabTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get editTabTrim;

  /// No description provided for @editTabSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get editTabSpeed;

  /// No description provided for @editTabAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get editTabAspectRatio;

  /// No description provided for @editTabCompression.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get editTabCompression;

  /// No description provided for @editTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get editTabAudio;

  /// No description provided for @editTabCaptions.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get editTabCaptions;

  /// No description provided for @editToolbarMoreTools.
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get editToolbarMoreTools;

  /// No description provided for @editToolbarPreviousTools.
  ///
  /// In en, this message translates to:
  /// **'Previous tools'**
  String get editToolbarPreviousTools;

  /// No description provided for @editCaptionsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Captions'**
  String get editCaptionsSectionTitle;

  /// No description provided for @editCaptionsSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create captions from the video audio.'**
  String get editCaptionsSectionSubtitle;

  /// No description provided for @editCaptionsAutoToggle.
  ///
  /// In en, this message translates to:
  /// **'Auto captions'**
  String get editCaptionsAutoToggle;

  /// No description provided for @editCaptionsBurnInHelper.
  ///
  /// In en, this message translates to:
  /// **'Captions will be burned into the final video.'**
  String get editCaptionsBurnInHelper;

  /// No description provided for @editCaptionsMayTakeLongerNote.
  ///
  /// In en, this message translates to:
  /// **'This may take longer.'**
  String get editCaptionsMayTakeLongerNote;

  /// No description provided for @editCaptionsProcessingNoteLine.
  ///
  /// In en, this message translates to:
  /// **'Generating captions may take a little longer.'**
  String get editCaptionsProcessingNoteLine;

  /// No description provided for @editCaptionsTextSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get editCaptionsTextSizeLabel;

  /// No description provided for @editCaptionsSizeExtraSmall.
  ///
  /// In en, this message translates to:
  /// **'Extra small'**
  String get editCaptionsSizeExtraSmall;

  /// No description provided for @editCaptionsSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get editCaptionsSizeSmall;

  /// No description provided for @editCaptionsSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get editCaptionsSizeMedium;

  /// No description provided for @editCaptionsSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get editCaptionsSizeLarge;

  /// No description provided for @editCaptionsPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get editCaptionsPositionLabel;

  /// No description provided for @editCaptionsPositionTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get editCaptionsPositionTop;

  /// No description provided for @editCaptionsPositionBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get editCaptionsPositionBottom;

  /// No description provided for @editCaptionsColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get editCaptionsColorLabel;

  /// No description provided for @editCaptionsColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get editCaptionsColorWhite;

  /// No description provided for @editCaptionsColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get editCaptionsColorYellow;

  /// No description provided for @editCaptionsStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get editCaptionsStyleLabel;

  /// No description provided for @editCaptionsStyleClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get editCaptionsStyleClean;

  /// No description provided for @editCaptionsStyleBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get editCaptionsStyleBold;

  /// No description provided for @editCaptionsStyleDarkBox.
  ///
  /// In en, this message translates to:
  /// **'Dark box'**
  String get editCaptionsStyleDarkBox;

  /// No description provided for @editCaptionsSampleHeading.
  ///
  /// In en, this message translates to:
  /// **'Approximate preview'**
  String get editCaptionsSampleHeading;

  /// No description provided for @editCaptionsSampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample captions'**
  String get editCaptionsSampleLabel;

  /// No description provided for @editCaptionsSpeechDenseHint.
  ///
  /// In en, this message translates to:
  /// **'Use smaller text for videos with a lot of speech.'**
  String get editCaptionsSpeechDenseHint;

  /// No description provided for @editCaptionsFineTuneTitle.
  ///
  /// In en, this message translates to:
  /// **'Fine tune position'**
  String get editCaptionsFineTuneTitle;

  /// No description provided for @editCaptionsResetPosition.
  ///
  /// In en, this message translates to:
  /// **'Reset position'**
  String get editCaptionsResetPosition;

  /// No description provided for @editCaptionsOffsetCompact.
  ///
  /// In en, this message translates to:
  /// **'X {x} · Y {y}'**
  String editCaptionsOffsetCompact(int x, int y);

  /// No description provided for @editCaptionsPresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get editCaptionsPresetLabel;

  /// No description provided for @editCaptionsPresetMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get editCaptionsPresetMinimal;

  /// No description provided for @editCaptionsPresetSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get editCaptionsPresetSocial;

  /// No description provided for @editCaptionsPresetBoldYellow.
  ///
  /// In en, this message translates to:
  /// **'Bold Yellow'**
  String get editCaptionsPresetBoldYellow;

  /// No description provided for @editCaptionsPresetDarkBox.
  ///
  /// In en, this message translates to:
  /// **'Dark Box'**
  String get editCaptionsPresetDarkBox;

  /// No description provided for @editCaptionsPresetTopClean.
  ///
  /// In en, this message translates to:
  /// **'Top Clean'**
  String get editCaptionsPresetTopClean;

  /// No description provided for @editCaptionsPresetManualBadge.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get editCaptionsPresetManualBadge;

  /// No description provided for @editCaptionsDraftTextSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption text'**
  String get editCaptionsDraftTextSectionTitle;

  /// No description provided for @editCaptionsDraftGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Generate draft'**
  String get editCaptionsDraftGenerateButton;

  /// No description provided for @editCaptionsDraftReviewHelper.
  ///
  /// In en, this message translates to:
  /// **'Review and edit captions before creating the video.'**
  String get editCaptionsDraftReviewHelper;

  /// No description provided for @editCaptionsDraftLongVideoHelper.
  ///
  /// In en, this message translates to:
  /// **'Longer videos may take more time to process.'**
  String get editCaptionsDraftLongVideoHelper;

  /// No description provided for @editCaptionsDraftGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating captions draft...'**
  String get editCaptionsDraftGenerating;

  /// No description provided for @editCaptionsDraftStaleHelper.
  ///
  /// In en, this message translates to:
  /// **'Draft captions need to be regenerated after timing changes.'**
  String get editCaptionsDraftStaleHelper;

  /// No description provided for @editCaptionsDraftRegenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Regenerate draft'**
  String get editCaptionsDraftRegenerateButton;

  /// No description provided for @editCaptionsDraftRegenerateTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate draft?'**
  String get editCaptionsDraftRegenerateTitle;

  /// No description provided for @editCaptionsDraftRegenerateBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace your current caption edits.'**
  String get editCaptionsDraftRegenerateBody;

  /// No description provided for @editCaptionsDraftRegenerateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get editCaptionsDraftRegenerateConfirm;

  /// No description provided for @editCaptionsDraftClearSegment.
  ///
  /// In en, this message translates to:
  /// **'Clear caption text'**
  String get editCaptionsDraftClearSegment;

  /// No description provided for @editCaptionsDraftEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit caption'**
  String get editCaptionsDraftEditTitle;

  /// No description provided for @editCaptionsDraftEditClearText.
  ///
  /// In en, this message translates to:
  /// **'Clear text'**
  String get editCaptionsDraftEditClearText;

  /// No description provided for @editCaptionsDraftTimingSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get editCaptionsDraftTimingSectionTitle;

  /// No description provided for @editCaptionsDraftTimingReset.
  ///
  /// In en, this message translates to:
  /// **'Reset timing'**
  String get editCaptionsDraftTimingReset;

  /// No description provided for @editCaptionsDraftTimingAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Adjusted'**
  String get editCaptionsDraftTimingAdjusted;

  /// No description provided for @editCaptionsDraftTimingEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get editCaptionsDraftTimingEarlier;

  /// No description provided for @editCaptionsDraftTimingLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get editCaptionsDraftTimingLater;

  /// No description provided for @editCaptionsV3AddSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add captions'**
  String get editCaptionsV3AddSectionTitle;

  /// No description provided for @editCaptionsV3DraftFlowHelper.
  ///
  /// In en, this message translates to:
  /// **'Generate a draft, review the text, then create the final video.'**
  String get editCaptionsV3DraftFlowHelper;

  /// No description provided for @editCaptionsV3DraftReady.
  ///
  /// In en, this message translates to:
  /// **'Draft ready'**
  String get editCaptionsV3DraftReady;

  /// No description provided for @editCaptionsV3DraftTapHelper.
  ///
  /// In en, this message translates to:
  /// **'Tap a caption to edit its text and timing.'**
  String get editCaptionsV3DraftTapHelper;

  /// No description provided for @editCaptionsV3DraftStaleHelper.
  ///
  /// In en, this message translates to:
  /// **'Timing changed. Regenerate the draft before creating the video.'**
  String get editCaptionsV3DraftStaleHelper;

  /// No description provided for @editCaptionsV3LookSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get editCaptionsV3LookSectionTitle;

  /// No description provided for @editCaptionsV3LookHelper.
  ///
  /// In en, this message translates to:
  /// **'Choose how captions appear on the final video.'**
  String get editCaptionsV3LookHelper;

  /// No description provided for @editCaptionsV3MoreStylingTitle.
  ///
  /// In en, this message translates to:
  /// **'More styling options'**
  String get editCaptionsV3MoreStylingTitle;

  /// No description provided for @editCaptionsV3PreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get editCaptionsV3PreviewLabel;

  /// No description provided for @editCaptionsV31EditCaptionsButton.
  ///
  /// In en, this message translates to:
  /// **'Edit captions'**
  String get editCaptionsV31EditCaptionsButton;

  /// No description provided for @editCaptionsV31DraftEditHelper.
  ///
  /// In en, this message translates to:
  /// **'Tap Edit captions to review text and timing before creating the video.'**
  String get editCaptionsV31DraftEditHelper;

  /// No description provided for @editCaptionsV31DraftSummaryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} captions'**
  String editCaptionsV31DraftSummaryCount(int count);

  /// No description provided for @editCaptionsV31DraftSummaryCountAdjusted.
  ///
  /// In en, this message translates to:
  /// **'{count} captions · {adjustedCount} adjusted'**
  String editCaptionsV31DraftSummaryCountAdjusted(int count, int adjustedCount);

  /// No description provided for @editCaptionsV31Done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editCaptionsV31Done;

  /// No description provided for @editCaptionsV31StaleBeforeEdit.
  ///
  /// In en, this message translates to:
  /// **'Timing changed. Regenerate the draft before editing captions.'**
  String get editCaptionsV31StaleBeforeEdit;

  /// No description provided for @editCaptionsV31ScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit captions'**
  String get editCaptionsV31ScreenTitle;

  /// No description provided for @editCaptionsV32SizeXL.
  ///
  /// In en, this message translates to:
  /// **'XL'**
  String get editCaptionsV32SizeXL;

  /// No description provided for @editCaptionsV32SizeXXL.
  ///
  /// In en, this message translates to:
  /// **'XXL'**
  String get editCaptionsV32SizeXXL;

  /// No description provided for @editCaptionsV32FontLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get editCaptionsV32FontLabel;

  /// No description provided for @editCaptionsV32FontDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get editCaptionsV32FontDefault;

  /// No description provided for @editCaptionsV32FontHeebo.
  ///
  /// In en, this message translates to:
  /// **'Heebo'**
  String get editCaptionsV32FontHeebo;

  /// No description provided for @editCaptionsV32FontRubik.
  ///
  /// In en, this message translates to:
  /// **'Rubik'**
  String get editCaptionsV32FontRubik;

  /// No description provided for @editCaptionsV32FontAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get editCaptionsV32FontAssistant;

  /// No description provided for @editCaptionsV32FontNotoSansHebrew.
  ///
  /// In en, this message translates to:
  /// **'Noto Sans Hebrew'**
  String get editCaptionsV32FontNotoSansHebrew;

  /// No description provided for @editCaptionsV32AccentLabel.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get editCaptionsV32AccentLabel;

  /// No description provided for @editCaptionsV32ColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get editCaptionsV32ColorPurple;

  /// No description provided for @editCaptionsV32ColorMint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get editCaptionsV32ColorMint;

  /// No description provided for @editCaptionsV32StyleCleanPro.
  ///
  /// In en, this message translates to:
  /// **'Clean Pro'**
  String get editCaptionsV32StyleCleanPro;

  /// No description provided for @editCaptionsV32StyleBoldSocial.
  ///
  /// In en, this message translates to:
  /// **'Bold Social'**
  String get editCaptionsV32StyleBoldSocial;

  /// No description provided for @editCaptionsV32StyleYellowHeadline.
  ///
  /// In en, this message translates to:
  /// **'Yellow Headline'**
  String get editCaptionsV32StyleYellowHeadline;

  /// No description provided for @editCaptionsV32StyleDarkBubble.
  ///
  /// In en, this message translates to:
  /// **'Dark Bubble'**
  String get editCaptionsV32StyleDarkBubble;

  /// No description provided for @editCaptionsV32StyleHighlightBox.
  ///
  /// In en, this message translates to:
  /// **'Highlight Box'**
  String get editCaptionsV32StyleHighlightBox;

  /// No description provided for @editCaptionsV32PresetCreatorHighlight.
  ///
  /// In en, this message translates to:
  /// **'Creator Highlight'**
  String get editCaptionsV32PresetCreatorHighlight;

  /// No description provided for @editCaptionsV32PresetNewsHeadline.
  ///
  /// In en, this message translates to:
  /// **'News Headline'**
  String get editCaptionsV32PresetNewsHeadline;

  /// No description provided for @editCaptionsV33WordHighlightLabel.
  ///
  /// In en, this message translates to:
  /// **'Word highlight'**
  String get editCaptionsV33WordHighlightLabel;

  /// No description provided for @editCaptionsV33WordHighlightOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get editCaptionsV33WordHighlightOff;

  /// No description provided for @editCaptionsV33WordHighlightColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get editCaptionsV33WordHighlightColor;

  /// No description provided for @editCaptionsV33WordHighlightBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get editCaptionsV33WordHighlightBox;

  /// No description provided for @editCaptionsV34NormalTextColor.
  ///
  /// In en, this message translates to:
  /// **'Normal text color'**
  String get editCaptionsV34NormalTextColor;

  /// No description provided for @editCaptionsV34ActiveWordColor.
  ///
  /// In en, this message translates to:
  /// **'Active word color'**
  String get editCaptionsV34ActiveWordColor;

  /// No description provided for @editCaptionsV34BoxColor.
  ///
  /// In en, this message translates to:
  /// **'Box color'**
  String get editCaptionsV34BoxColor;

  /// No description provided for @editCaptionsV34BoxShape.
  ///
  /// In en, this message translates to:
  /// **'Box shape'**
  String get editCaptionsV34BoxShape;

  /// No description provided for @editCaptionsV34ColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get editCaptionsV34ColorPink;

  /// No description provided for @editCaptionsV34ColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get editCaptionsV34ColorBlack;

  /// No description provided for @editCaptionsV34BoxShapeRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get editCaptionsV34BoxShapeRectangle;

  /// No description provided for @editCaptionsV34BoxShapeRounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded'**
  String get editCaptionsV34BoxShapeRounded;

  /// No description provided for @editCaptionsV34BoxShapePill.
  ///
  /// In en, this message translates to:
  /// **'Pill'**
  String get editCaptionsV34BoxShapePill;

  /// No description provided for @editCaptionsV34CustomizeLook.
  ///
  /// In en, this message translates to:
  /// **'Customize look'**
  String get editCaptionsV34CustomizeLook;

  /// No description provided for @editCaptionsV34LookEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption look'**
  String get editCaptionsV34LookEditorTitle;

  /// No description provided for @editCaptionsV34TabPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get editCaptionsV34TabPresets;

  /// No description provided for @editCaptionsV34TabText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get editCaptionsV34TabText;

  /// No description provided for @editCaptionsV34TabHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get editCaptionsV34TabHighlight;

  /// No description provided for @editCaptionsV34TabPosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get editCaptionsV34TabPosition;

  /// No description provided for @editCaptionsV34Done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editCaptionsV34Done;

  /// No description provided for @editCaptionsV34PresetPinkPop.
  ///
  /// In en, this message translates to:
  /// **'Pink Pop'**
  String get editCaptionsV34PresetPinkPop;

  /// No description provided for @editCaptionsV34PresetYellowViral.
  ///
  /// In en, this message translates to:
  /// **'Yellow Viral'**
  String get editCaptionsV34PresetYellowViral;

  /// No description provided for @editCaptionsV34PresetCleanFocus.
  ///
  /// In en, this message translates to:
  /// **'Clean Focus'**
  String get editCaptionsV34PresetCleanFocus;

  /// No description provided for @editCaptionsV34HighlightDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Highlight follows the spoken words. Generate a draft for more accurate timing.'**
  String get editCaptionsV34HighlightDraftHint;

  /// No description provided for @editCaptionsV34HighlightModeOffHint.
  ///
  /// In en, this message translates to:
  /// **'Plain captions, no word highlight'**
  String get editCaptionsV34HighlightModeOffHint;

  /// No description provided for @editCaptionsV34HighlightModeColorHint.
  ///
  /// In en, this message translates to:
  /// **'Highlights the active word with color'**
  String get editCaptionsV34HighlightModeColorHint;

  /// No description provided for @editCaptionsV34HighlightModeBoxHint.
  ///
  /// In en, this message translates to:
  /// **'Highlights the active word with a box'**
  String get editCaptionsV34HighlightModeBoxHint;

  /// No description provided for @editCaptionsV34PositionFineTuneHint.
  ///
  /// In en, this message translates to:
  /// **'Move captions slightly if they cover important content.'**
  String get editCaptionsV34PositionFineTuneHint;

  /// No description provided for @editCaptionsV34PanelActiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Captions on'**
  String get editCaptionsV34PanelActiveStatus;

  /// No description provided for @editCaptionsV34PanelTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off captions'**
  String get editCaptionsV34PanelTurnOff;

  /// No description provided for @editCaptionsV34PanelLookTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption look'**
  String get editCaptionsV34PanelLookTitle;

  /// No description provided for @editCaptionsV34PanelDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption draft'**
  String get editCaptionsV34PanelDraftTitle;

  /// No description provided for @editCaptionsV34PanelDraftHelper.
  ///
  /// In en, this message translates to:
  /// **'Review and edit the text before creating the video.'**
  String get editCaptionsV34PanelDraftHelper;

  /// No description provided for @editCaptionsV34PanelDraftTimingHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended for more accurate timing.'**
  String get editCaptionsV34PanelDraftTimingHint;

  /// No description provided for @editCaptionsV34PanelDraftReady.
  ///
  /// In en, this message translates to:
  /// **'Draft ready'**
  String get editCaptionsV34PanelDraftReady;

  /// No description provided for @editCaptionsV34PanelDraftReadyHelper.
  ///
  /// In en, this message translates to:
  /// **'Review and edit captions before creating the video.'**
  String get editCaptionsV34PanelDraftReadyHelper;

  /// No description provided for @editCaptionsV34PanelEditCaptions.
  ///
  /// In en, this message translates to:
  /// **'Edit captions'**
  String get editCaptionsV34PanelEditCaptions;

  /// No description provided for @editCaptionsV34OffInviteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn speech into styled captions for your video.'**
  String get editCaptionsV34OffInviteSubtitle;

  /// No description provided for @editCaptionsV34EnableCaptions.
  ///
  /// In en, this message translates to:
  /// **'Enable captions'**
  String get editCaptionsV34EnableCaptions;

  /// No description provided for @editCaptionsV34BenefitDraft.
  ///
  /// In en, this message translates to:
  /// **'Editable draft'**
  String get editCaptionsV34BenefitDraft;

  /// No description provided for @editCaptionsV34BenefitStyles.
  ///
  /// In en, this message translates to:
  /// **'Caption styles'**
  String get editCaptionsV34BenefitStyles;

  /// No description provided for @editCaptionsV34BenefitHighlight.
  ///
  /// In en, this message translates to:
  /// **'Word highlight'**
  String get editCaptionsV34BenefitHighlight;

  /// No description provided for @editCaptionsV34SamplePreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample captions'**
  String get editCaptionsV34SamplePreviewLabel;

  /// No description provided for @editAudioScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit audio'**
  String get editAudioScreenTitle;

  /// No description provided for @editAudioFileExplanation.
  ///
  /// In en, this message translates to:
  /// **'This is an audio file, so some video edits are unavailable.'**
  String get editAudioFileExplanation;

  /// No description provided for @editAudioVideoEditsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video editing is not available for MP3 files.'**
  String get editAudioVideoEditsUnavailable;

  /// No description provided for @editAudioAvailableActions.
  ///
  /// In en, this message translates to:
  /// **'Available actions'**
  String get editAudioAvailableActions;

  /// No description provided for @editAudioSaveFileFirst.
  ///
  /// In en, this message translates to:
  /// **'Save the file to your device to open or share it.'**
  String get editAudioSaveFileFirst;

  /// No description provided for @editAudioLimitationsNote.
  ///
  /// In en, this message translates to:
  /// **'Audio files support trim, speed, and quality export.'**
  String get editAudioLimitationsNote;

  /// No description provided for @downloadCardEditAudio.
  ///
  /// In en, this message translates to:
  /// **'Edit audio'**
  String get downloadCardEditAudio;

  /// No description provided for @downloadCardEditVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get downloadCardEditVideo;

  /// No description provided for @downloadCardMp3Badge.
  ///
  /// In en, this message translates to:
  /// **'MP3'**
  String get downloadCardMp3Badge;

  /// No description provided for @audioEditPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio preview'**
  String get audioEditPreviewTitle;

  /// No description provided for @audioEditTrimTitle.
  ///
  /// In en, this message translates to:
  /// **'Trim audio'**
  String get audioEditTrimTitle;

  /// No description provided for @audioEditTrimRange.
  ///
  /// In en, this message translates to:
  /// **'Range: {range}'**
  String audioEditTrimRange(String range);

  /// No description provided for @audioEditTrimStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get audioEditTrimStart;

  /// No description provided for @audioEditTrimEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get audioEditTrimEnd;

  /// No description provided for @audioEditResetTrim.
  ///
  /// In en, this message translates to:
  /// **'Reset trim'**
  String get audioEditResetTrim;

  /// No description provided for @audioEditQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio quality'**
  String get audioEditQualityTitle;

  /// No description provided for @audioEditQualityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get audioEditQualityStandard;

  /// No description provided for @audioEditQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get audioEditQualityHigh;

  /// No description provided for @audioEditQualityBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get audioEditQualityBest;

  /// No description provided for @audioEditCreate.
  ///
  /// In en, this message translates to:
  /// **'Create audio edit'**
  String get audioEditCreate;

  /// No description provided for @audioEditNoChangesYet.
  ///
  /// In en, this message translates to:
  /// **'No audio changes yet'**
  String get audioEditNoChangesYet;

  /// No description provided for @audioEditChooseOneChange.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one change to create an edit'**
  String get audioEditChooseOneChange;

  /// No description provided for @audioEditReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to save'**
  String get audioEditReadyTitle;

  /// No description provided for @audioEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio editing failed'**
  String get audioEditFailed;

  /// No description provided for @audioEditRequiresSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save file first'**
  String get audioEditRequiresSaveTitle;

  /// No description provided for @audioEditRequiresSaveBody.
  ///
  /// In en, this message translates to:
  /// **'To edit audio, save the file to your device first.'**
  String get audioEditRequiresSaveBody;

  /// No description provided for @audioEditRequiresSaveNow.
  ///
  /// In en, this message translates to:
  /// **'Save now'**
  String get audioEditRequiresSaveNow;

  /// No description provided for @audioEditRequiresSaveCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get audioEditRequiresSaveCancel;

  /// No description provided for @audioEditCreatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Creating audio edit...'**
  String get audioEditCreatingTitle;

  /// No description provided for @audioEditCreatingKeepOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep the app open until the edit is complete.'**
  String get audioEditCreatingKeepOpen;

  /// No description provided for @audioEditReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your edited audio is ready and saved on your device.'**
  String get audioEditReadySubtitle;

  /// No description provided for @audioEditSavedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'The file was saved on your device'**
  String get audioEditSavedOnDevice;

  /// No description provided for @audioEditSavedLocationLine.
  ///
  /// In en, this message translates to:
  /// **'Saved to:\n{path}'**
  String audioEditSavedLocationLine(String path);

  /// No description provided for @audioEditMoveStartHint.
  ///
  /// In en, this message translates to:
  /// **'Move start point'**
  String get audioEditMoveStartHint;

  /// No description provided for @audioEditMoveEndHint.
  ///
  /// In en, this message translates to:
  /// **'Move end point'**
  String get audioEditMoveEndHint;

  /// No description provided for @editsFolderName.
  ///
  /// In en, this message translates to:
  /// **'Edits'**
  String get editsFolderName;

  /// No description provided for @editsSummaryTrimmed.
  ///
  /// In en, this message translates to:
  /// **'Trimmed'**
  String get editsSummaryTrimmed;

  /// No description provided for @editsAudioBadge.
  ///
  /// In en, this message translates to:
  /// **'Audio edit'**
  String get editsAudioBadge;

  /// No description provided for @editsMp3Badge.
  ///
  /// In en, this message translates to:
  /// **'MP3'**
  String get editsMp3Badge;

  /// No description provided for @errorCaptionsWordHighlightNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This word highlight option is not supported.'**
  String get errorCaptionsWordHighlightNotSupported;

  /// No description provided for @errorCaptionsFontFamilyNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This caption font is not supported.'**
  String get errorCaptionsFontFamilyNotSupported;

  /// No description provided for @errorCaptionsDraftUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not generate captions draft.'**
  String get errorCaptionsDraftUnavailable;

  /// No description provided for @errorCaptionsStyleNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This captions style is not supported.'**
  String get errorCaptionsStyleNotSupported;

  /// No description provided for @errorCaptionsPositionNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This captions position is not supported.'**
  String get errorCaptionsPositionNotSupported;

  /// No description provided for @errorCaptionsFontSizeNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This captions size is not supported.'**
  String get errorCaptionsFontSizeNotSupported;

  /// No description provided for @errorCaptionsColorNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This captions color is not supported.'**
  String get errorCaptionsColorNotSupported;

  /// No description provided for @errorCaptionsTranscriptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Captions are temporarily unavailable.'**
  String get errorCaptionsTranscriptionUnavailable;

  /// No description provided for @errorCaptionsGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create captions for this video.'**
  String get errorCaptionsGenerationFailed;

  /// No description provided for @errorCaptionsOptionNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This captions option is not supported.'**
  String get errorCaptionsOptionNotSupported;

  /// No description provided for @errorCaptionSegmentsInvalid.
  ///
  /// In en, this message translates to:
  /// **'The edited captions are invalid.'**
  String get errorCaptionSegmentsInvalid;

  /// No description provided for @editSpeedSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get editSpeedSectionTitle;

  /// No description provided for @editSpeedSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose playback speed'**
  String get editSpeedSectionSubtitle;

  /// No description provided for @editSpeedDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Changing speed changes the final video duration.'**
  String get editSpeedDurationHint;

  /// No description provided for @editCompressHelperHint.
  ///
  /// In en, this message translates to:
  /// **'Choose final quality and file size'**
  String get editCompressHelperHint;

  /// No description provided for @editMuteDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove the audio track from the edited video'**
  String get editMuteDescription;

  /// No description provided for @editTrimFieldStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get editTrimFieldStart;

  /// No description provided for @editTrimFieldEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get editTrimFieldEnd;

  /// No description provided for @editTrimTimeExample.
  ///
  /// In en, this message translates to:
  /// **'Example: 02:04'**
  String get editTrimTimeExample;

  /// No description provided for @editTrimInvalidStartTime.
  ///
  /// In en, this message translates to:
  /// **'Invalid start time'**
  String get editTrimInvalidStartTime;

  /// No description provided for @editTrimInvalidEndTime.
  ///
  /// In en, this message translates to:
  /// **'Invalid end time'**
  String get editTrimInvalidEndTime;

  /// No description provided for @editTrimEndMustBeAfterStart.
  ///
  /// In en, this message translates to:
  /// **'End must be after start'**
  String get editTrimEndMustBeAfterStart;

  /// No description provided for @editTrimRangeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get editTrimRangeFrom;

  /// No description provided for @editTrimRangeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get editTrimRangeTo;

  /// No description provided for @editLeaveWhileProcessingStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get editLeaveWhileProcessingStay;

  /// No description provided for @editLeaveWhileProcessingExit.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get editLeaveWhileProcessingExit;

  /// No description provided for @editTrimSheetTitleStart.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get editTrimSheetTitleStart;

  /// No description provided for @editTrimSheetTitleEnd.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get editTrimSheetTitleEnd;

  /// No description provided for @editTrimSheetApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get editTrimSheetApply;

  /// No description provided for @editTrimTimeFieldHint.
  ///
  /// In en, this message translates to:
  /// **'MM:SS'**
  String get editTrimTimeFieldHint;

  /// No description provided for @editTrimPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview: {formatted}'**
  String editTrimPreview(String formatted);

  /// No description provided for @editTrimTapToEditHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to start fresh — type digits here; apply saves as MM:SS.'**
  String get editTrimTapToEditHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
