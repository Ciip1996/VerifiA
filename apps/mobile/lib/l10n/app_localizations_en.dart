// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get seeAction => 'View';

  @override
  String get retry => 'Retry';

  @override
  String get back => 'Back';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get idTypeINE => 'INE / IFE';

  @override
  String get idTypePassport => 'Passport';

  @override
  String get idTypeLabelShort => 'ID type';

  @override
  String get curpLabel => 'CURP';

  @override
  String get birthDateLabel => 'Date of birth';

  @override
  String get idTypeUnknown => 'Unknown';

  @override
  String get errorNetwork => 'No connection. Check your network and try again.';

  @override
  String get errorTimeout =>
      'The server took too long to respond. Check your connection and try again.';

  @override
  String get errorNoConnection =>
      'Could not connect to the server. Make sure you are on the same network and try again.';

  @override
  String get errorNetworkUnexpected =>
      'Unexpected network error. Please try again.';

  @override
  String get homeOfflineBanner => 'No server connection';

  @override
  String get homeTabScan => 'Scan';

  @override
  String get homeTabCreateQr => 'Create QR';

  @override
  String get homeTabInbox => 'Activity';

  @override
  String get homeTabSearch => 'Search';

  @override
  String get bannerNewRequest => 'New verification request';

  @override
  String get bannerAnonymous => 'Someone';

  @override
  String bannerVerifiedRequest(String name) {
    return '$name has been verified';
  }

  @override
  String bannerRejectedRequest(String recipient) {
    return '$recipient rejected your request';
  }

  @override
  String bannerCancelledRequest(String recipient) {
    return '$recipient cancelled your request';
  }

  @override
  String get createChallengeTitle => 'Request verification';

  @override
  String get createChallengeModeQuestion =>
      'How do you want to send the request?';

  @override
  String get createChallengeModeOpen => 'Open QR';

  @override
  String get createChallengeModeOpenDesc => 'Share the QR or link via any app';

  @override
  String get createChallengeModeTargeted => 'Send to user';

  @override
  String get createChallengeModeTargetedDesc =>
      'Directly to someone, by app or email';

  @override
  String get createChallengeEmailLabel => 'Recipient email';

  @override
  String get createChallengeEmailHint => 'name@example.com';

  @override
  String get createChallengeButtonGenerate => 'Generate QR';

  @override
  String get createChallengeButtonNoEmail => 'Enter an email to continue';

  @override
  String get createChallengeButtonInvalidEmail => 'Invalid email';

  @override
  String get createChallengeButtonSend => 'Send request';

  @override
  String get createChallengeButtonGenerateInvite =>
      'Generate and prepare invitation';

  @override
  String get createChallengeHintEmailRequired => 'Recipient email is required.';

  @override
  String get createChallengeHintEmailFormat =>
      'Enter a valid email format (e.g. name@example.com).';

  @override
  String get createChallengeHintRegistered =>
      'The request will appear in the recipient\'s app.';

  @override
  String get createChallengeHintUnregistered =>
      'After generating, you can send them an email invitation.';

  @override
  String get createChallengeHintUnknown =>
      'If the email is not in VerifiA, we will send them an invitation.';

  @override
  String get createChallengeHintOpen =>
      'The QR will be active for 30 minutes. Share it via WhatsApp, iMessage or any app.';

  @override
  String get createChallengeGenerating => 'Generating…';

  @override
  String get createChallengeStatusRegistered =>
      'Registered user — will receive the request in the app';

  @override
  String get createChallengeStatusNotRegistered =>
      'Not in VerifiA — you can send them an email invitation';

  @override
  String createChallengeSnackSent(String email) {
    return 'Request sent to $email';
  }

  @override
  String createChallengeSnackQrGenerated(String email) {
    return 'QR generated — send the invitation to $email';
  }

  @override
  String createChallengeShareError(String error) {
    return 'Could not share: $error';
  }

  @override
  String get createChallengeLinkCopied => 'Link copied to clipboard';

  @override
  String get createChallengeQrExpired => 'QR expired';

  @override
  String get createChallengeQrExpiredSubtitle =>
      'Generate a new one to continue';

  @override
  String get createChallengeQrReady => 'QR ready to share';

  @override
  String get createChallengeQrReadySubtitle =>
      'Share the code or link via any app';

  @override
  String get createChallengeQrSent => 'Request sent';

  @override
  String createChallengeQrSentSubtitle(String email) {
    return 'The request is in $email\'s app';
  }

  @override
  String get createChallengeQrGenerated => 'QR generated';

  @override
  String get createChallengeQrGeneratedSubtitle =>
      'Send the email invitation so they can download the app';

  @override
  String get createChallengeQrReadyShort => 'QR ready';

  @override
  String get createChallengeQrReadyShortSubtitle => 'Share the code or link';

  @override
  String get createChallengeCopyLink => 'Copy link';

  @override
  String get createChallengeShare => 'Share';

  @override
  String get createChallengeInviteSent => 'Invitation sent';

  @override
  String get createChallengeInviteSending => 'Sending…';

  @override
  String get createChallengeInviteButton => 'Send email invitation';

  @override
  String get createChallengeNewQr => 'Generate new QR';

  @override
  String get createChallengeVerifiedSubtitle =>
      'Verification was completed successfully.';

  @override
  String get createChallengeCancelAndBack => 'Cancel and go back';

  @override
  String get createChallengeCountdownLabel => 'remaining';

  @override
  String createChallengeInviteError(String error) {
    return 'Error sending: $error';
  }

  @override
  String get onboardingTitle => 'Identity registration';

  @override
  String get onboardingSubtitle =>
      'To issue presence badges you need to register your identity once. FaceTec will scan your face and your official ID.';

  @override
  String get onboardingIdTypeLabel => 'ID type';

  @override
  String get onboardingScanButton => 'Scan ID with FaceTec';

  @override
  String get onboardingLoginLink => 'Already have an account? Sign in';

  @override
  String get onboardingScanCancelled => 'Scan cancelled';

  @override
  String get onboardingCaptureCancelled => 'Capture cancelled';

  @override
  String get onboardingFacetecStarting => 'Starting FaceTec...';

  @override
  String get onboardingFacetecInstructions =>
      'Follow the on-screen instructions';

  @override
  String get onboardingPreviewTitle => 'Confirm your information';

  @override
  String get onboardingNameLabel => 'Full name';

  @override
  String get onboardingOcrReading => 'Reading ID…';

  @override
  String get onboardingNotDetected => '(not detected)';

  @override
  String get onboardingNameNotDetected =>
      'Name not detected in the photo. Continue and correct it in your profile.';

  @override
  String get onboardingInfoBirthDate => 'Date of birth';

  @override
  String get onboardingInfoFacetecMatch => 'FaceTec Match';

  @override
  String get onboardingIdFrontLabel => 'ID front';

  @override
  String get onboardingIdBackLabel => 'ID back';

  @override
  String get onboardingRepeatButton => 'Retry';

  @override
  String get onboardingRegisterButton => 'Register';

  @override
  String get onboardingConfirming => 'Registering profile...';

  @override
  String get onboardingSuccess => 'Registration successful!';

  @override
  String get onboardingSuccessSubtitle => 'Your identity has been verified.';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Use your VerifiA email and password';

  @override
  String get loginEmailRequired => 'Enter your email address';

  @override
  String get loginEmailInvalid => 'Invalid email address';

  @override
  String get loginPasswordRequired => 'Enter your password';

  @override
  String get loginErrorInvalidCredentials =>
      'Incorrect email or password. Check your details and try again.';

  @override
  String get loginErrorAccountNotFound =>
      'No account found with that email address.';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginRegisterLink => 'Don\'t have an account? Register';

  @override
  String get presenceConfirmTitle => 'Confirm your verification';

  @override
  String get presenceConfirmSubtitle =>
      'You are about to cryptographically sign your presence for:';

  @override
  String get presenceVerifierLabel => 'Verifier';

  @override
  String get presenceStep1Title => 'Liveness check';

  @override
  String get presenceStep1Subtitle => 'Head turn to confirm presence';

  @override
  String get presenceStep2Title => 'FaceTec 3D';

  @override
  String get presenceStep2Subtitle =>
      'Industrial-grade anti-spoofing face verification';

  @override
  String get presenceStep3Title => 'Face ID authorization';

  @override
  String get presenceStep3Subtitle =>
      'Cryptographic signature with Secure Enclave';

  @override
  String get presenceStep4Title => 'Presence badge';

  @override
  String get presenceStep4Subtitle => 'Ephemeral JWT valid for 5 minutes';

  @override
  String get presenceConfirmButton => 'Verify my presence';

  @override
  String get presenceFlowIdle => 'Starting...';

  @override
  String get presenceFlowLiveness =>
      'Turn your head to confirm\nyou are a real person';

  @override
  String get presenceFlowFacetec =>
      'FaceTec 3D verification\nPlace your face in the oval';

  @override
  String get presenceFlowPasskey => 'Authorize with Face ID\nto sign the badge';

  @override
  String get presenceFlowIssuing => 'Issuing presence badge...';

  @override
  String get presenceFlowDone => 'Badge issued!';

  @override
  String get presenceStepLiveness => 'Liveness';

  @override
  String get presenceStepFacetec => 'FaceTec 3D';

  @override
  String get presenceStepFaceId => 'Face ID';

  @override
  String get presenceStepBadge => 'Badge';

  @override
  String get presenceErrorTitle => 'Verification error';

  @override
  String get presenceErrorUnknown => 'Unknown error';

  @override
  String get presenceErrorQrNotFound =>
      'The QR code is no longer valid. Request a new one.';

  @override
  String get presenceErrorQrUsed => 'This QR code has already been used.';

  @override
  String get presenceErrorQrExpired =>
      'The QR code has expired. Request a new one.';

  @override
  String get presenceErrorBiometric => 'Biometric authorization error.';

  @override
  String get inboxTabReceived => 'Received';

  @override
  String get inboxTabSent => 'Sent';

  @override
  String get inboxEmptyReceived => 'No received requests';

  @override
  String get inboxEmptyReceivedDesc =>
      'When someone asks you to verify your identity, it will appear here.';

  @override
  String get inboxRejectTitle => 'Reject request?';

  @override
  String inboxRejectContent(String name) {
    return '$name will be notified that you rejected the verification.';
  }

  @override
  String get inboxRejectButton => 'Reject';

  @override
  String get inboxRejectedSnack => 'Request rejected';

  @override
  String get inboxTimeExpired => 'Not verified in time — expired';

  @override
  String inboxTimeHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m remaining';
  }

  @override
  String inboxTimeMinutes(int minutes) {
    return '${minutes}m remaining';
  }

  @override
  String get inboxAnonymousRequest => 'Anonymous request';

  @override
  String get inboxExpiredLabel => 'Expired';

  @override
  String get inboxResumeButton => 'Resume';

  @override
  String get inboxVerifyButton => 'Verify';

  @override
  String get inboxEmptySent => 'No sent requests';

  @override
  String get inboxEmptySentDesc =>
      'Search for a user and send them a verification request.';

  @override
  String get inboxCancelTitle => 'Cancel request?';

  @override
  String inboxCancelContent(String email) {
    return 'The request sent to $email will be cancelled and can no longer be verified.';
  }

  @override
  String get inboxKeepButton => 'No, keep it';

  @override
  String get inboxCancelButton => 'Cancel request';

  @override
  String get inboxCancelTooltip => 'Cancel request';

  @override
  String get inboxCancelledSnack => 'Request cancelled';

  @override
  String get sentStatusUsed => 'Completed';

  @override
  String get sentStatusInProgress => 'Verifying';

  @override
  String get sentStatusExpired => 'Expired';

  @override
  String get sentStatusRejected => 'Rejected';

  @override
  String get sentStatusCancelled => 'Cancelled';

  @override
  String get sentStatusPending => 'Pending';

  @override
  String get sentRecipient => 'Recipient';

  @override
  String sentTimeAgoMinutes(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String sentTimeAgoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String get badgeTitle => 'Presence Badge';

  @override
  String get badgeExpired => 'BADGE EXPIRED';

  @override
  String get badgeVerified => 'PRESENCE VERIFIED';

  @override
  String get badgeExpiresIn => 'Expires in';

  @override
  String get badgeVerifierLabel => 'Verifier';

  @override
  String get badgeIssuedLabel => 'Issued';

  @override
  String get badgeExpiresLabel => 'Expires';

  @override
  String get badgeIdLabel => 'Badge ID';

  @override
  String get badgeCopied => 'JWT copied to clipboard';

  @override
  String get badgeCopyJwt => 'Copy JWT';

  @override
  String get badgeShareTitle => 'Share your receipt';

  @override
  String get badgeShareSubtitle =>
      'A signed proof of this verification, valid for 30 days.';

  @override
  String get badgeShareQr => 'Share QR';

  @override
  String get badgeShareLink => 'Share link';

  @override
  String get badgeCopyLink => 'Copy link';

  @override
  String get badgeLinkCopied => 'Link copied to clipboard';

  @override
  String get badgeShareMessage =>
      'VerifiA verification receipt — scan the QR or open the link to check its authenticity.';

  @override
  String get badgeShareError =>
      'Couldn\'t share the receipt. Please try again.';

  @override
  String get profileLogoutTitle => 'Sign out';

  @override
  String get profileLogoutContent => 'Are you sure you want to sign out?';

  @override
  String get profileLogoutButton => 'Sign out';

  @override
  String get profileLoadError => 'Could not load profile';

  @override
  String get profileSessionExpired => 'Your session has expired';

  @override
  String get profileSignInAgain => 'Sign in again';

  @override
  String get profileTitle => 'My Profile';

  @override
  String get profileVerifiedBadge => 'Identity verified';

  @override
  String get profileEmailLabel => 'Email address';

  @override
  String get profileIdTypeLabel => 'ID type';

  @override
  String get profileCurpLabel => 'CURP';

  @override
  String get profileBirthDateLabel => 'Date of birth';

  @override
  String get profileLogoutButtonLabel => 'Sign out';

  @override
  String get livenessTitle => 'Presence Verification';

  @override
  String get livenessInstructionCenter => 'Center your face in the oval';

  @override
  String get livenessInstructionTurn => 'Turn your head to one side';

  @override
  String get livenessInstructionReturn => 'Return to center';

  @override
  String get livenessInstructionDone => 'Verification complete!';

  @override
  String get livenessInstructionFallback => 'Verifying presence...';

  @override
  String get livenessCountdownReady => 'Get ready for the photo!';

  @override
  String get livenessCountdownShoot => 'Snap!';

  @override
  String get livenessQualityNoFace => 'No face detected — move a bit closer';

  @override
  String get livenessQualityEyesClosed => 'Open your eyes for the photo';

  @override
  String get livenessQualityFaceAngle => 'Look straight at the camera';

  @override
  String get livenessQualityTilted => 'Straighten your head';

  @override
  String get scannerCameraError => 'Could not start camera';

  @override
  String get scannerStarting => 'Starting camera…';

  @override
  String get scannerPermissionTitle => 'Camera access required';

  @override
  String get scannerPermissionSubtitle =>
      'Go to Settings → Verifia → Camera and enable it, then tap Retry.';

  @override
  String get scannerInstruction => 'Scan the verifier\'s QR code';

  @override
  String get searchHint => 'Search by name or email…';

  @override
  String get searchTitle => 'Find VerifiA users';

  @override
  String get searchDesc =>
      'Type at least 2 characters to search by name or email address.';

  @override
  String searchNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get searchNoResultsDesc => 'Try a different name or email.';

  @override
  String get searchYou => 'You';

  @override
  String get setPasswordTitle => 'Create your web access';

  @override
  String get setPasswordSubtitle =>
      'With an account you can sign in to the web portal to generate verification QRs and view your history.';

  @override
  String get setPasswordEmailHint => 'you@email.com';

  @override
  String get setPasswordEmailRequired => 'Enter your email';

  @override
  String get setPasswordEmailInvalid => 'Invalid email';

  @override
  String get setPasswordPasswordHint => 'Minimum 8 characters';

  @override
  String get setPasswordPasswordMinLength => 'Minimum 8 characters';

  @override
  String get setPasswordConfirmLabel => 'Confirm password';

  @override
  String get setPasswordPasswordMismatch => 'Passwords do not match';

  @override
  String get setPasswordCreateButton => 'Create account';

  @override
  String get setPasswordSkip => 'Skip for now';

  @override
  String get wizardWelcomeTitle => 'Welcome to VerifiA';

  @override
  String get wizardWelcomeDesc =>
      'To give you the best identity verification experience, we need to configure some permissions on your device.';

  @override
  String get wizardNetworkTitle => 'Network access';

  @override
  String get wizardNetworkDesc =>
      'VerifiA needs to connect to the internet to issue and validate presence badges in real time securely.';

  @override
  String get wizardCameraTitle => 'Camera access';

  @override
  String get wizardCameraDesc =>
      'VerifiA uses your camera to scan verifier QR codes and to capture your selfie during the presence detection process.';

  @override
  String get wizardFaceIdTitle => 'Face ID authentication';

  @override
  String get wizardFaceIdDesc =>
      'Face ID confirms your identity before each verification. Your biometric data never leaves your device.';

  @override
  String get wizardDoneTitle => 'All set!';

  @override
  String get wizardDoneDesc =>
      'Permissions are configured. Now create your verified identity profile.';

  @override
  String get wizardButtonStart => 'Get started';

  @override
  String get wizardButtonUnderstood => 'Got it';

  @override
  String get wizardButtonCamera => 'Allow camera access';

  @override
  String get wizardButtonFaceId => 'Set up Face ID';

  @override
  String get wizardButtonContinue => 'Continue';

  @override
  String get wizardButtonLater => 'Not now';

  @override
  String get verDetailSelfieLabel => 'Registration photo';

  @override
  String get verDetailZoomHint => 'View';

  @override
  String get verDetailCompleted => 'Verification completed';

  @override
  String get verDetailRequestSent => 'Request sent';

  @override
  String get verDetailVerifiedAt => 'Verified on';

  @override
  String get verDetailIdType => 'ID type';

  @override
  String get verDetailBiometricScore => 'Biometric score';

  @override
  String get verDetailSelfieVerification => 'Verification selfie';

  @override
  String get verDetailIdPhotoLabel => 'Submitted ID';

  @override
  String get verDetailScoreUnavailable => 'Not available';

  @override
  String get verDetailScoreUnavailableDesc =>
      'FaceTec match did not generate a score for this session (development mode or SDK not configured).';

  @override
  String get verDetailScoreExcellent => 'Excellent';

  @override
  String get verDetailScoreVeryHigh => 'Very high';

  @override
  String get verDetailScoreAcceptable => 'Acceptable';

  @override
  String get verDetailScoreLow => 'Low';

  @override
  String get verDetailScoreInsufficient => 'Insufficient';

  @override
  String get verDetailScoreMatchLabel => 'Face vs. submitted ID match';

  @override
  String get publicProfileVerifiedFacetec => 'Identity verified with FaceTec';

  @override
  String publicProfileAge(int age) {
    return '$age years old';
  }

  @override
  String get publicProfileIdLabel => 'Official ID';

  @override
  String get publicProfileIdDesc => 'Document scanned during registration';

  @override
  String get publicProfileScoreHigh => 'High match';

  @override
  String get publicProfileScoreMedium => 'Medium match';

  @override
  String get publicProfileScoreLow => 'Low match';

  @override
  String get publicProfileFacetecTitle => 'FaceTec ID Match';

  @override
  String get publicProfileFacetecDesc =>
      'Face vs. ID match score at registration';

  @override
  String publicProfileScoreLabelFull(String label, int score) {
    return '$label — $score/100';
  }

  @override
  String get publicProfileRequestSentSnack => 'Verification request sent';

  @override
  String get publicProfileButtonSent => 'Request sent';

  @override
  String get publicProfileButtonSend => 'Send verification request';

  @override
  String get livenessMockInstruction1 => 'Hold the phone in front of your face';

  @override
  String get livenessMockInstruction2 => 'Slowly turn to the right';

  @override
  String get livenessMockInstruction3 => 'Return to center';

  @override
  String get livenessMockInstruction4 => 'Slowly turn to the left';

  @override
  String get livenessMockInstruction5 => 'Look directly at the camera';

  @override
  String get livenessMockCompleted => 'Completed';

  @override
  String get loginEmailLabel => 'Email address';

  @override
  String get loginEmailHint => 'you@email.com';

  @override
  String get setPasswordLabel => 'Password';

  @override
  String get setPasswordHint => 'Minimum 8 characters';

  @override
  String get setPasswordButton => 'Create account';

  @override
  String get setPasswordMismatch => 'Passwords do not match';

  @override
  String get setPasswordTooShort => 'Minimum 8 characters';

  @override
  String get publicProfileLoadError => 'Could not load profile';

  @override
  String get permWelcomeTitle => 'Welcome to VerifiA';

  @override
  String get permWelcomeBody =>
      'To offer you the best identity verification experience, we need to configure a few permissions on your device.';

  @override
  String get permNetworkTitle => 'Network access';

  @override
  String get permNetworkBody =>
      'VerifiA needs internet access to issue and validate presence badges in real time securely.';

  @override
  String get permCameraTitle => 'Camera access';

  @override
  String get permCameraBody =>
      'VerifiA uses your camera to scan verifier QR codes and capture your selfie during the presence detection process.';

  @override
  String get permFaceIdTitle => 'Face ID authentication';

  @override
  String get permFaceIdBody =>
      'Face ID confirms your identity before each verification. Your biometric data never leaves your device.';

  @override
  String get permDoneTitle => 'All set!';

  @override
  String get permDoneBody =>
      'Permissions are configured. Now create your verified identity profile.';

  @override
  String get permCtaBegin => 'Get started';

  @override
  String get permCtaUnderstood => 'Got it';

  @override
  String get permCtaCamera => 'Allow camera access';

  @override
  String get permCtaFaceId => 'Set up Face ID';

  @override
  String get permCtaContinue => 'Continue';

  @override
  String get permSkip => 'Not now';

  @override
  String get permNotificationsTitle => 'Push notifications';

  @override
  String get permNotificationsBody =>
      'VerifiA notifies you when a verification request arrives, when someone completes yours, or if one is rejected or cancelled.';

  @override
  String get permCtaNotifications => 'Enable notifications';

  @override
  String get permDoneChecklist => 'Permission status';

  @override
  String get permCheckNetwork => 'Internet access';

  @override
  String get permCheckNotifications => 'Push notifications';

  @override
  String get permCheckCamera => 'Camera';

  @override
  String get permCheckFaceId => 'Face ID / Biometrics';

  @override
  String get permRetryButton => 'Retry';

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get permDoneBodyBlocked => 'Enable all permissions to continue.';

  @override
  String get scannerAllowCamera => 'Allow camera';

  @override
  String get scannerOpenSettings => 'Open settings';

  @override
  String get verificationDetailCompleted => 'Verification completed';

  @override
  String get verificationDetailUser => 'User';

  @override
  String get verificationDetailRequestSent => 'Request sent';

  @override
  String get verificationDetailVerifiedOn => 'Verified on';

  @override
  String get verificationDetailIdType => 'ID type';

  @override
  String get verificationDetailBiometricScore => 'Biometric score';

  @override
  String get verificationDetailVerifySelfie => 'Verification selfie';

  @override
  String get verificationDetailIdPresented => 'ID presented';

  @override
  String get verificationDetailSelfieLabel => 'Registration photo';

  @override
  String get verificationDetailScoreUnavailable => 'Not available';

  @override
  String get verificationDetailScoreUnavailableDesc =>
      'FaceTec match did not generate a score in this session (dev mode or SDK not configured).';

  @override
  String get verificationDetailScoreCaption => 'Face vs. presented ID match';

  @override
  String get scoreExcellent => 'Excellent';

  @override
  String get scoreVeryHigh => 'Very high';

  @override
  String get scoreAcceptable => 'Acceptable';

  @override
  String get scoreLow => 'Low';

  @override
  String get scoreInsufficient => 'Insufficient';

  @override
  String get receiptTitle => 'Verification receipt';

  @override
  String get receiptStatusValid => 'Authentic verification';

  @override
  String get receiptStatusValidDesc =>
      'This receipt is genuine and currently valid.';

  @override
  String get receiptStatusExpired => 'Receipt expired';

  @override
  String get receiptStatusExpiredDesc =>
      'The verification did happen; only the 30-day record lapsed. This is not a sign of fraud.';

  @override
  String get receiptStatusInvalid => 'Could not verify';

  @override
  String get receiptStatusInvalidDesc =>
      'The signature is invalid. This code may have been tampered with or forged.';

  @override
  String get receiptStatusMalformed => 'Unrecognized code';

  @override
  String get receiptStatusMalformedDesc =>
      'This doesn\'t look like a VerifiA receipt.';

  @override
  String get receiptStatusNotFound => 'Receipt not found';

  @override
  String get receiptStatusNotFoundDesc =>
      'We couldn\'t find this receipt on the server.';

  @override
  String get receiptOfflineNote =>
      'Verified offline. Couldn\'t confirm with the server.';

  @override
  String get receiptSubjectLabel => 'Verified person';

  @override
  String get receiptVerifiedAtLabel => 'Verified on';

  @override
  String get receiptValidityLabel => 'Badge validity';

  @override
  String get receiptIdentityTitle => 'Verified identity';

  @override
  String get receiptScoreTitle => 'Biometric match';

  @override
  String get receiptSelfieLabel => 'Liveness selfie';

  @override
  String get receiptIdLabel => 'ID document';

  @override
  String get receiptScanMe => 'Show it to be scanned';

  @override
  String get receiptShareQr => 'Share';

  @override
  String get receiptPasteButton => 'Paste receipt';

  @override
  String get receiptPasteEmpty => 'No valid receipt found in the clipboard.';

  @override
  String get inboxHistoryTitle => 'History';

  @override
  String get inboxHistoryEmpty =>
      'You don\'t have any completed verifications yet.';

  @override
  String get inboxHistoryViewTicket => 'View receipt';
}
