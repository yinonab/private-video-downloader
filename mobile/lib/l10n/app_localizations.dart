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

  /// No description provided for @downloadSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved to Downloads'**
  String get downloadSavedToDownloads;

  /// No description provided for @downloadSavedInAppOnly.
  ///
  /// In en, this message translates to:
  /// **'Saved in the app, but could not save to Downloads.'**
  String get downloadSavedInAppOnly;

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
  /// **'Default server from app build'**
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
  /// **'Use server URL from app build'**
  String get settingsRevertToBakedServer;

  /// No description provided for @settingsAdvancedFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Production builds normally use the URL baked into the APK. This section is for development or a temporary server.'**
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
  /// **'Using the server URL from the app build.'**
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
  /// **'The server URL is set by the app build. To change it, open Settings → Advanced.'**
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
