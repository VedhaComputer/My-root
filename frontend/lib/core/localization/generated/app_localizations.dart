import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('hi')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'My Root'**
  String get appTitle;

  /// App tagline
  ///
  /// In en, this message translates to:
  /// **'Preserving Local Knowledge'**
  String get tagline;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Explore navigation label
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// Submit navigation label
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get navSubmit;

  /// Profile navigation label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @categoryHistoricalRecord.
  ///
  /// In en, this message translates to:
  /// **'Historical Record'**
  String get categoryHistoricalRecord;

  /// No description provided for @categoryCurrentFact.
  ///
  /// In en, this message translates to:
  /// **'Current Fact'**
  String get categoryCurrentFact;

  /// No description provided for @categoryFolklore.
  ///
  /// In en, this message translates to:
  /// **'Folklore / Proverb'**
  String get categoryFolklore;

  /// No description provided for @categoryPersonalExperience.
  ///
  /// In en, this message translates to:
  /// **'Personal Experience'**
  String get categoryPersonalExperience;

  /// No description provided for @categoryPublicOpinion.
  ///
  /// In en, this message translates to:
  /// **'Public Opinion'**
  String get categoryPublicOpinion;

  /// No description provided for @categorySurveyData.
  ///
  /// In en, this message translates to:
  /// **'Survey Data'**
  String get categorySurveyData;

  /// No description provided for @categoryDisputedClaim.
  ///
  /// In en, this message translates to:
  /// **'Disputed Claim'**
  String get categoryDisputedClaim;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmitted;

  /// No description provided for @statusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get statusUnderReview;

  /// No description provided for @statusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get statusVerified;

  /// No description provided for @statusPartiallyVerified.
  ///
  /// In en, this message translates to:
  /// **'Partially Verified'**
  String get statusPartiallyVerified;

  /// No description provided for @statusUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get statusUnverified;

  /// No description provided for @statusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get statusDisputed;

  /// No description provided for @statusInsufficientEvidence.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Evidence'**
  String get statusInsufficientEvidence;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get statusArchived;

  /// No description provided for @locationCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get locationCountry;

  /// No description provided for @locationState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get locationState;

  /// No description provided for @locationDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get locationDistrict;

  /// No description provided for @locationTehsil.
  ///
  /// In en, this message translates to:
  /// **'Tehsil'**
  String get locationTehsil;

  /// No description provided for @locationCityTown.
  ///
  /// In en, this message translates to:
  /// **'City / Town'**
  String get locationCityTown;

  /// No description provided for @locationVillage.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get locationVillage;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Content not found.'**
  String get errorNotFound;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingLabel;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @submitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to My Root'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover and preserve the stories, history, and wisdom of your community.'**
  String get welcomeSubtitle;

  /// No description provided for @exploreButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Explore Stories'**
  String get exploreButtonLabel;

  /// No description provided for @contributeButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Contribute'**
  String get contributeButtonLabel;

  /// No description provided for @verifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedBadge;

  /// No description provided for @unverifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get unverifiedBadge;

  /// No description provided for @disputedBadge.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get disputedBadge;

  /// No description provided for @folkloreNote.
  ///
  /// In en, this message translates to:
  /// **'This is folklore and has not been independently verified as historical fact.'**
  String get folkloreNote;

  /// No description provided for @selfApprovalNote.
  ///
  /// In en, this message translates to:
  /// **'You cannot approve your own submission.'**
  String get selfApprovalNote;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerButton;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get logoutButton;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get alreadyHaveAccount;

  /// No description provided for @invalidEmailError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get invalidEmailError;

  /// No description provided for @shortPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get shortPasswordError;

  /// No description provided for @emptyNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your display name'**
  String get emptyNameError;

  /// No description provided for @authSuccess.
  ///
  /// In en, this message translates to:
  /// **'Authentication successful'**
  String get authSuccess;

  /// No description provided for @authLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Successfully signed out'**
  String get authLoggedOut;

  /// No description provided for @placesTitle.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesTitle;

  /// No description provided for @placesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Geographic Hierarchy across India'**
  String get placesSubtitle;

  /// No description provided for @searchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search places...'**
  String get searchPlaces;

  /// No description provided for @filterByLevel.
  ///
  /// In en, this message translates to:
  /// **'Filter by level'**
  String get filterByLevel;

  /// No description provided for @allLevels.
  ///
  /// In en, this message translates to:
  /// **'All Levels'**
  String get allLevels;

  /// No description provided for @noPlacesFound.
  ///
  /// In en, this message translates to:
  /// **'No places found'**
  String get noPlacesFound;

  /// No description provided for @placeHierarchy.
  ///
  /// In en, this message translates to:
  /// **'Hierarchy'**
  String get placeHierarchy;

  /// No description provided for @canonicalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Canonical Name'**
  String get canonicalNameLabel;

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelLabel;

  /// No description provided for @parentPlaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent Place'**
  String get parentPlaceLabel;

  /// No description provided for @childrenPlaces.
  ///
  /// In en, this message translates to:
  /// **'Sub-places'**
  String get childrenPlaces;

  /// No description provided for @noChildrenPlaces.
  ///
  /// In en, this message translates to:
  /// **'No sub-places found under this location'**
  String get noChildrenPlaces;

  /// No description provided for @addPlaceButton.
  ///
  /// In en, this message translates to:
  /// **'Add Place'**
  String get addPlaceButton;

  /// No description provided for @createPlaceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Place created successfully'**
  String get createPlaceSuccess;

  /// No description provided for @deletePlaceButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Place'**
  String get deletePlaceButton;

  /// No description provided for @deletePlaceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Place deleted successfully'**
  String get deletePlaceSuccess;

  /// No description provided for @localizedNamesLabel.
  ///
  /// In en, this message translates to:
  /// **'Localized Names'**
  String get localizedNamesLabel;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @enterCanonicalName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a canonical name'**
  String get enterCanonicalName;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get profileTitle;

  /// No description provided for @activityHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity History'**
  String get activityHistoryTitle;

  /// No description provided for @tabClaims.
  ///
  /// In en, this message translates to:
  /// **'Stories & Claims'**
  String get tabClaims;

  /// No description provided for @tabEvidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get tabEvidence;

  /// No description provided for @tabPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places & Features'**
  String get tabPlaces;

  /// No description provided for @noActivityFound.
  ///
  /// In en, this message translates to:
  /// **'No contributions found yet'**
  String get noActivityFound;

  /// No description provided for @userRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get userRoleLabel;

  /// No description provided for @memberSinceLabel.
  ///
  /// In en, this message translates to:
  /// **'Member Since'**
  String get memberSinceLabel;

  /// No description provided for @identityVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Identity Verified'**
  String get identityVerifiedBadge;

  /// No description provided for @unverifiedIdentityBadge.
  ///
  /// In en, this message translates to:
  /// **'Unverified Identity'**
  String get unverifiedIdentityBadge;

  /// No description provided for @totalContributionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Contributions'**
  String get totalContributionsLabel;

  /// No description provided for @folkloreNoticeBanner.
  ///
  /// In en, this message translates to:
  /// **'Folklore & Oral Tradition: Community-shared folklore is not independently verified as historical fact.'**
  String get folkloreNoticeBanner;

  /// No description provided for @publicOpinionNoticeBanner.
  ///
  /// In en, this message translates to:
  /// **'Community Opinions: Subjective viewpoints submitted by local contributors.'**
  String get publicOpinionNoticeBanner;

  /// No description provided for @verifiedFactsSection.
  ///
  /// In en, this message translates to:
  /// **'Verified History & Facts'**
  String get verifiedFactsSection;

  /// No description provided for @folkloreSection.
  ///
  /// In en, this message translates to:
  /// **'Folklore & Oral Traditions'**
  String get folkloreSection;

  /// No description provided for @opinionsSection.
  ///
  /// In en, this message translates to:
  /// **'Public & Community Opinions'**
  String get opinionsSection;

  /// No description provided for @otherClaimsSection.
  ///
  /// In en, this message translates to:
  /// **'Under Review & Other Submissions'**
  String get otherClaimsSection;

  /// No description provided for @noVerifiedClaims.
  ///
  /// In en, this message translates to:
  /// **'No verified historical records or facts for this location yet.'**
  String get noVerifiedClaims;

  /// No description provided for @noFolkloreClaims.
  ///
  /// In en, this message translates to:
  /// **'No folklore or oral traditions recorded for this location yet.'**
  String get noFolkloreClaims;

  /// No description provided for @noOpinionClaims.
  ///
  /// In en, this message translates to:
  /// **'No community opinions recorded for this location.'**
  String get noOpinionClaims;

  /// No description provided for @noOtherClaims.
  ///
  /// In en, this message translates to:
  /// **'No pending claims under review.'**
  String get noOtherClaims;

  /// No description provided for @matrbhoomiTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrbhoomi History'**
  String get matrbhoomiTitle;

  /// No description provided for @matrbhoomiQuestion1.
  ///
  /// In en, this message translates to:
  /// **'Do you know about the glorious history of your homeland?'**
  String get matrbhoomiQuestion1;

  /// No description provided for @matrbhoomiChoiceYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I know'**
  String get matrbhoomiChoiceYes;

  /// No description provided for @matrbhoomiChoiceNo.
  ///
  /// In en, this message translates to:
  /// **'No, I want to learn'**
  String get matrbhoomiChoiceNo;

  /// No description provided for @matrbhoomiQuestion2.
  ///
  /// In en, this message translates to:
  /// **'Would you like to learn about the glorious history of your homeland?'**
  String get matrbhoomiQuestion2;

  /// No description provided for @matrbhoomiChoiceLearnYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, show history'**
  String get matrbhoomiChoiceLearnYes;

  /// No description provided for @matrbhoomiChoiceLearnNo.
  ///
  /// In en, this message translates to:
  /// **'No, not now'**
  String get matrbhoomiChoiceLearnNo;

  /// No description provided for @matrbhoomiContributePrompt.
  ///
  /// In en, this message translates to:
  /// **'Contribute to the glorious history, traditions, personalities, and historical events of your homeland.'**
  String get matrbhoomiContributePrompt;

  /// No description provided for @matrbhoomiContributeButton.
  ///
  /// In en, this message translates to:
  /// **'Contribute History'**
  String get matrbhoomiContributeButton;

  /// No description provided for @matrbhoomiNoApprovedHistory.
  ///
  /// In en, this message translates to:
  /// **'No approved historical records are available for this place yet.'**
  String get matrbhoomiNoApprovedHistory;

  /// No description provided for @matrbhoomiFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Feedback & Corroboration'**
  String get matrbhoomiFeedbackTitle;

  /// No description provided for @matrbhoomiFeedbackPrompt.
  ///
  /// In en, this message translates to:
  /// **'Share your perspective on this history'**
  String get matrbhoomiFeedbackPrompt;

  /// No description provided for @matrbhoomiFeedbackQ1.
  ///
  /// In en, this message translates to:
  /// **'Did you already know about this?'**
  String get matrbhoomiFeedbackQ1;

  /// No description provided for @matrbhoomiFeedbackQ1Yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get matrbhoomiFeedbackQ1Yes;

  /// No description provided for @matrbhoomiFeedbackQ1No.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get matrbhoomiFeedbackQ1No;

  /// No description provided for @matrbhoomiFeedbackQ1Partial.
  ///
  /// In en, this message translates to:
  /// **'Partially'**
  String get matrbhoomiFeedbackQ1Partial;

  /// No description provided for @matrbhoomiFeedbackQ2.
  ///
  /// In en, this message translates to:
  /// **'Do you agree with this information?'**
  String get matrbhoomiFeedbackQ2;

  /// No description provided for @matrbhoomiFeedbackQ2Agree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get matrbhoomiFeedbackQ2Agree;

  /// No description provided for @matrbhoomiFeedbackQ2Disagree.
  ///
  /// In en, this message translates to:
  /// **'Disagree'**
  String get matrbhoomiFeedbackQ2Disagree;

  /// No description provided for @matrbhoomiFeedbackQ2NeedEvidence.
  ///
  /// In en, this message translates to:
  /// **'Need Evidence'**
  String get matrbhoomiFeedbackQ2NeedEvidence;

  /// No description provided for @matrbhoomiFeedbackQ2NotSure.
  ///
  /// In en, this message translates to:
  /// **'Not Sure'**
  String get matrbhoomiFeedbackQ2NotSure;

  /// No description provided for @matrbhoomiFeedbackQ3.
  ///
  /// In en, this message translates to:
  /// **'Would you like to write something about this?'**
  String get matrbhoomiFeedbackQ3;

  /// No description provided for @matrbhoomiFeedbackQ3Hint.
  ///
  /// In en, this message translates to:
  /// **'Write your thoughts or complementary context (optional)...'**
  String get matrbhoomiFeedbackQ3Hint;

  /// No description provided for @matrbhoomiFeedbackQ4.
  ///
  /// In en, this message translates to:
  /// **'Do you know the author of this information?'**
  String get matrbhoomiFeedbackQ4;

  /// No description provided for @matrbhoomiFeedbackQ4Personally.
  ///
  /// In en, this message translates to:
  /// **'Know personally'**
  String get matrbhoomiFeedbackQ4Personally;

  /// No description provided for @matrbhoomiFeedbackQ4ByName.
  ///
  /// In en, this message translates to:
  /// **'Know by name'**
  String get matrbhoomiFeedbackQ4ByName;

  /// No description provided for @matrbhoomiFeedbackQ4NotKnown.
  ///
  /// In en, this message translates to:
  /// **'Do not know'**
  String get matrbhoomiFeedbackQ4NotKnown;

  /// No description provided for @matrbhoomiFeedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get matrbhoomiFeedbackSubmit;

  /// No description provided for @matrbhoomiFeedbackSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your feedback has been recorded securely.'**
  String get matrbhoomiFeedbackSuccess;

  /// No description provided for @matrbhoomiFeedbackRecorded.
  ///
  /// In en, this message translates to:
  /// **'You have submitted feedback for this record.'**
  String get matrbhoomiFeedbackRecorded;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordButton;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailButton;

  /// No description provided for @resendVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Resend Verification Email'**
  String get resendVerificationTitle;

  /// No description provided for @resendVerificationButton.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Link'**
  String get resendVerificationButton;

  /// No description provided for @verificationTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification Token'**
  String get verificationTokenLabel;

  /// No description provided for @verificationTokenHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 64-character token from your email'**
  String get verificationTokenHint;

  /// No description provided for @passwordResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get passwordResetTitle;

  /// No description provided for @requestResetButton.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get requestResetButton;

  /// No description provided for @confirmResetButton.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get confirmResetButton;

  /// No description provided for @resetTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset Token'**
  String get resetTokenLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @enterTokenError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the token from your email'**
  String get enterTokenError;

  /// No description provided for @verifyEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'Need to verify an unverified or legacy account?'**
  String get verifyEmailHelper;

  /// No description provided for @resetPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Have a reset token? Confirm new password below.'**
  String get resetPasswordHelper;

  /// No description provided for @viewDutiesButton.
  ///
  /// In en, this message translates to:
  /// **'View Powers & Duties'**
  String get viewDutiesButton;

  /// No description provided for @infoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Information Not Available'**
  String get infoNotAvailable;

  /// No description provided for @electedRepresentativesTitle.
  ///
  /// In en, this message translates to:
  /// **'Applicable Elected Representatives'**
  String get electedRepresentativesTitle;

  /// No description provided for @representativeDutiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Elected Representatives & Constitutional Duties'**
  String get representativeDutiesTitle;
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
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
