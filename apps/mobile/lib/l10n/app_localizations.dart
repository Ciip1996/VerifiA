import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('es')
  ];

  /// Generic cancel button label
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// Generic dismiss button label
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get dismiss;

  /// Generic 'see/view' button label
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get seeAction;

  /// Generic retry button label
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// Generic back button label
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// Email address field label
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get emailLabel;

  /// Password field label
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// Mexican voter ID type label
  ///
  /// In es, this message translates to:
  /// **'INE / IFE'**
  String get idTypeINE;

  /// Passport ID type label
  ///
  /// In es, this message translates to:
  /// **'Pasaporte'**
  String get idTypePassport;

  /// Short label for ID type field
  ///
  /// In es, this message translates to:
  /// **'Tipo de ID'**
  String get idTypeLabelShort;

  /// CURP identifier label
  ///
  /// In es, this message translates to:
  /// **'CURP'**
  String get curpLabel;

  /// Date of birth field label
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get birthDateLabel;

  /// Unknown ID type fallback
  ///
  /// In es, this message translates to:
  /// **'Desconocido'**
  String get idTypeUnknown;

  /// Generic network error shown to the user
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Verifica tu red e intenta de nuevo.'**
  String get errorNetwork;

  /// Server timeout error message
  ///
  /// In es, this message translates to:
  /// **'El servidor tardó demasiado en responder. Verifica tu conexión e intenta de nuevo.'**
  String get errorTimeout;

  /// Unable to reach server error
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar al servidor. Verifica que estés en la misma red e intenta de nuevo.'**
  String get errorNoConnection;

  /// Unexpected network error
  ///
  /// In es, this message translates to:
  /// **'Error de red inesperado. Intenta de nuevo.'**
  String get errorNetworkUnexpected;

  /// Offline banner shown at the top of HomeScreen
  ///
  /// In es, this message translates to:
  /// **'Sin conexión con el servidor'**
  String get homeOfflineBanner;

  /// Navigation tab label for QR scanner
  ///
  /// In es, this message translates to:
  /// **'Escanear'**
  String get homeTabScan;

  /// Navigation tab label for creating a QR challenge
  ///
  /// In es, this message translates to:
  /// **'Crear QR'**
  String get homeTabCreateQr;

  /// Navigation tab label for incoming/sent validations
  ///
  /// In es, this message translates to:
  /// **'Solicitudes'**
  String get homeTabInbox;

  /// Navigation tab label for user search
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get homeTabSearch;

  /// Title of in-app banner for a new incoming verification request
  ///
  /// In es, this message translates to:
  /// **'Nueva solicitud de verificación'**
  String get bannerNewRequest;

  /// Fallback name when the requester is unknown
  ///
  /// In es, this message translates to:
  /// **'Alguien'**
  String get bannerAnonymous;

  /// Banner shown when a sent challenge has been completed
  ///
  /// In es, this message translates to:
  /// **'{name} ya se verificó'**
  String bannerVerifiedRequest(String name);

  /// Banner shown when the recipient rejected the challenge
  ///
  /// In es, this message translates to:
  /// **'{recipient} rechazó tu solicitud'**
  String bannerRejectedRequest(String recipient);

  /// Banner shown when the recipient cancelled the challenge
  ///
  /// In es, this message translates to:
  /// **'{recipient} canceló tu solicitud'**
  String bannerCancelledRequest(String recipient);

  /// AppBar title for CreateChallengeScreen
  ///
  /// In es, this message translates to:
  /// **'Solicitar verificación'**
  String get createChallengeTitle;

  /// Section header asking how to send the request
  ///
  /// In es, this message translates to:
  /// **'¿Cómo quieres enviar la solicitud?'**
  String get createChallengeModeQuestion;

  /// Mode card title for open QR challenge
  ///
  /// In es, this message translates to:
  /// **'QR Abierto'**
  String get createChallengeModeOpen;

  /// Mode card description for open QR challenge
  ///
  /// In es, this message translates to:
  /// **'Comparte el QR o el link con cualquier app'**
  String get createChallengeModeOpenDesc;

  /// Mode card title for targeted challenge
  ///
  /// In es, this message translates to:
  /// **'Enviar a usuario'**
  String get createChallengeModeTargeted;

  /// Mode card description for targeted challenge
  ///
  /// In es, this message translates to:
  /// **'Directo a alguien, por app o correo'**
  String get createChallengeModeTargetedDesc;

  /// Label for the recipient email input field
  ///
  /// In es, this message translates to:
  /// **'Correo del destinatario'**
  String get createChallengeEmailLabel;

  /// Hint text for the recipient email input
  ///
  /// In es, this message translates to:
  /// **'nombre@ejemplo.com'**
  String get createChallengeEmailHint;

  /// Button label to generate an open QR code
  ///
  /// In es, this message translates to:
  /// **'Generar QR'**
  String get createChallengeButtonGenerate;

  /// Button label when no email has been entered in targeted mode
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo para continuar'**
  String get createChallengeButtonNoEmail;

  /// Button label when the entered email is invalid
  ///
  /// In es, this message translates to:
  /// **'Correo inválido'**
  String get createChallengeButtonInvalidEmail;

  /// Button label to send a request to a registered user
  ///
  /// In es, this message translates to:
  /// **'Enviar solicitud'**
  String get createChallengeButtonSend;

  /// Button label to generate QR and invite a non-registered user
  ///
  /// In es, this message translates to:
  /// **'Generar y preparar invitación'**
  String get createChallengeButtonGenerateInvite;

  /// Hint shown below button when no email is entered
  ///
  /// In es, this message translates to:
  /// **'El correo del destinatario es obligatorio.'**
  String get createChallengeHintEmailRequired;

  /// Hint shown when email format is invalid
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo con formato válido (ej. nombre@ejemplo.com).'**
  String get createChallengeHintEmailFormat;

  /// Hint when recipient is registered in VerifiA
  ///
  /// In es, this message translates to:
  /// **'La solicitud aparecerá en la app del destinatario.'**
  String get createChallengeHintRegistered;

  /// Hint when recipient is not registered in VerifiA
  ///
  /// In es, this message translates to:
  /// **'Después de generar, podrás enviarle una invitación por correo.'**
  String get createChallengeHintUnregistered;

  /// Hint when recipient registration status is unknown
  ///
  /// In es, this message translates to:
  /// **'Si el correo no está en VerifiA, le enviaremos una invitación.'**
  String get createChallengeHintUnknown;

  /// Hint for open QR mode below the generate button
  ///
  /// In es, this message translates to:
  /// **'El QR estará activo 30 minutos. Compártelo por WhatsApp, iMessage o cualquier app.'**
  String get createChallengeHintOpen;

  /// Loading label shown while the QR challenge is being generated
  ///
  /// In es, this message translates to:
  /// **'Generando…'**
  String get createChallengeGenerating;

  /// Status badge when recipient is registered
  ///
  /// In es, this message translates to:
  /// **'Usuario registrado — recibirá la solicitud en la app'**
  String get createChallengeStatusRegistered;

  /// Status badge when recipient is not registered
  ///
  /// In es, this message translates to:
  /// **'No está en VerifiA — podrás enviarle una invitación por correo'**
  String get createChallengeStatusNotRegistered;

  /// Snackbar shown after a targeted challenge is sent to a registered user
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada a {email}'**
  String createChallengeSnackSent(String email);

  /// Snackbar shown after QR is generated for a non-registered user
  ///
  /// In es, this message translates to:
  /// **'QR generado — envía la invitación a {email}'**
  String createChallengeSnackQrGenerated(String email);

  /// Snackbar shown when sharing the QR fails
  ///
  /// In es, this message translates to:
  /// **'No se pudo compartir: {error}'**
  String createChallengeShareError(String error);

  /// Snackbar shown when the challenge link is copied
  ///
  /// In es, this message translates to:
  /// **'Link copiado al portapapeles'**
  String get createChallengeLinkCopied;

  /// Title shown when the generated QR has expired
  ///
  /// In es, this message translates to:
  /// **'QR expirado'**
  String get createChallengeQrExpired;

  /// Subtitle when the QR has expired
  ///
  /// In es, this message translates to:
  /// **'Genera uno nuevo para continuar'**
  String get createChallengeQrExpiredSubtitle;

  /// Title shown when an open QR is ready
  ///
  /// In es, this message translates to:
  /// **'QR listo para compartir'**
  String get createChallengeQrReady;

  /// Subtitle when open QR is ready to share
  ///
  /// In es, this message translates to:
  /// **'Comparte el código o el link por cualquier app'**
  String get createChallengeQrReadySubtitle;

  /// Title shown after targeted QR is sent to registered user
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada'**
  String get createChallengeQrSent;

  /// Subtitle after targeted QR is sent to registered user
  ///
  /// In es, this message translates to:
  /// **'La solicitud está en la app de {email}'**
  String createChallengeQrSentSubtitle(String email);

  /// Title shown when QR is generated for a non-registered user
  ///
  /// In es, this message translates to:
  /// **'QR generado'**
  String get createChallengeQrGenerated;

  /// Subtitle when QR generated for non-registered user
  ///
  /// In es, this message translates to:
  /// **'Envía la invitación por correo para que descargue la app'**
  String get createChallengeQrGeneratedSubtitle;

  /// Short title for QR ready state
  ///
  /// In es, this message translates to:
  /// **'QR listo'**
  String get createChallengeQrReadyShort;

  /// Short subtitle for QR ready state
  ///
  /// In es, this message translates to:
  /// **'Comparte el código o el link'**
  String get createChallengeQrReadyShortSubtitle;

  /// Button to copy the challenge link
  ///
  /// In es, this message translates to:
  /// **'Copiar link'**
  String get createChallengeCopyLink;

  /// Button to share the challenge QR
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get createChallengeShare;

  /// Label shown after the invite email is sent
  ///
  /// In es, this message translates to:
  /// **'Invitación enviada'**
  String get createChallengeInviteSent;

  /// Loading label while sending invite email
  ///
  /// In es, this message translates to:
  /// **'Enviando…'**
  String get createChallengeInviteSending;

  /// Button to send invite email to non-registered recipient
  ///
  /// In es, this message translates to:
  /// **'Enviar invitación por correo'**
  String get createChallengeInviteButton;

  /// Button to generate a new QR after the previous one expired
  ///
  /// In es, this message translates to:
  /// **'Generar nuevo QR'**
  String get createChallengeNewQr;

  /// Subtitle shown on the QR screen when the challenge has been consumed and verified
  ///
  /// In es, this message translates to:
  /// **'La verificación fue completada exitosamente.'**
  String get createChallengeVerifiedSubtitle;

  /// Button to cancel and go back to the form
  ///
  /// In es, this message translates to:
  /// **'Cancelar y volver'**
  String get createChallengeCancelAndBack;

  /// Label below the countdown timer showing time remaining
  ///
  /// In es, this message translates to:
  /// **'restantes'**
  String get createChallengeCountdownLabel;

  /// Snackbar shown when sending invite email fails
  ///
  /// In es, this message translates to:
  /// **'Error al enviar: {error}'**
  String createChallengeInviteError(String error);

  /// Title for the onboarding / identity registration screen
  ///
  /// In es, this message translates to:
  /// **'Registro de identidad'**
  String get onboardingTitle;

  /// Subtitle explaining the onboarding process
  ///
  /// In es, this message translates to:
  /// **'Para emitir badges de presencia necesitas registrar tu identidad una sola vez. FaceTec escaneará tu cara y tu identificación oficial.'**
  String get onboardingSubtitle;

  /// Label for the ID type selector on the onboarding form
  ///
  /// In es, this message translates to:
  /// **'Tipo de identificación'**
  String get onboardingIdTypeLabel;

  /// Button to start the FaceTec ID scan
  ///
  /// In es, this message translates to:
  /// **'Escanear ID con FaceTec'**
  String get onboardingScanButton;

  /// Link to the login screen from onboarding
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? Inicia sesión'**
  String get onboardingLoginLink;

  /// Error shown when the ID scan is cancelled
  ///
  /// In es, this message translates to:
  /// **'Escaneo cancelado'**
  String get onboardingScanCancelled;

  /// Error shown when the photo capture is cancelled on Android
  ///
  /// In es, this message translates to:
  /// **'Captura cancelada'**
  String get onboardingCaptureCancelled;

  /// Message shown while FaceTec SDK is initializing
  ///
  /// In es, this message translates to:
  /// **'Iniciando FaceTec...'**
  String get onboardingFacetecStarting;

  /// Instruction text while FaceTec is running
  ///
  /// In es, this message translates to:
  /// **'Sigue las instrucciones en pantalla'**
  String get onboardingFacetecInstructions;

  /// Title of the preview step in onboarding
  ///
  /// In es, this message translates to:
  /// **'Confirma tu información'**
  String get onboardingPreviewTitle;

  /// Label for the full name field in the preview step
  ///
  /// In es, this message translates to:
  /// **'Nombre completo'**
  String get onboardingNameLabel;

  /// Loading text shown while OCR reads the ID
  ///
  /// In es, this message translates to:
  /// **'Leyendo ID…'**
  String get onboardingOcrReading;

  /// Placeholder when no name was detected by OCR
  ///
  /// In es, this message translates to:
  /// **'(no detectado)'**
  String get onboardingNotDetected;

  /// Warning shown when OCR cannot detect the name
  ///
  /// In es, this message translates to:
  /// **'No se detectó el nombre en la foto. Continúa y corrígelo en tu perfil.'**
  String get onboardingNameNotDetected;

  /// Short label for date of birth in the onboarding preview
  ///
  /// In es, this message translates to:
  /// **'Fecha de nac.'**
  String get onboardingInfoBirthDate;

  /// Label for the FaceTec match score in the preview
  ///
  /// In es, this message translates to:
  /// **'Match FaceTec'**
  String get onboardingInfoFacetecMatch;

  /// Label for the ID front photo in the onboarding preview
  ///
  /// In es, this message translates to:
  /// **'Frente del ID'**
  String get onboardingIdFrontLabel;

  /// Label for the ID back photo in the onboarding preview
  ///
  /// In es, this message translates to:
  /// **'Reverso del ID'**
  String get onboardingIdBackLabel;

  /// Button to repeat the ID scan in the preview step
  ///
  /// In es, this message translates to:
  /// **'Repetir'**
  String get onboardingRepeatButton;

  /// Button to confirm and register the profile
  ///
  /// In es, this message translates to:
  /// **'Registrarme'**
  String get onboardingRegisterButton;

  /// Loading message while the profile is being registered
  ///
  /// In es, this message translates to:
  /// **'Registrando perfil...'**
  String get onboardingConfirming;

  /// Success title shown when onboarding completes
  ///
  /// In es, this message translates to:
  /// **'¡Registro exitoso!'**
  String get onboardingSuccess;

  /// Subtitle shown on successful onboarding
  ///
  /// In es, this message translates to:
  /// **'Tu identidad fue verificada.'**
  String get onboardingSuccessSubtitle;

  /// Title and button label for the login screen
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// Subtitle on the login screen
  ///
  /// In es, this message translates to:
  /// **'Usa tu correo y contraseña de VerifiA'**
  String get loginSubtitle;

  /// Validator message when email field is empty
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo electrónico'**
  String get loginEmailRequired;

  /// Validator message when email format is invalid
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico no válido'**
  String get loginEmailInvalid;

  /// Validator message when password field is empty
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get loginPasswordRequired;

  /// Error shown when login credentials are wrong
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos. Verifica tus datos e intenta de nuevo.'**
  String get loginErrorInvalidCredentials;

  /// Error shown when no account found for the email
  ///
  /// In es, this message translates to:
  /// **'No existe una cuenta con ese correo electrónico.'**
  String get loginErrorAccountNotFound;

  /// Divider label prompting users without an account to register
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta?'**
  String get loginNoAccount;

  /// Link to onboarding from the login screen
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? Regístrate'**
  String get loginRegisterLink;

  /// Title on the anti-coercion confirmation screen
  ///
  /// In es, this message translates to:
  /// **'Confirma tu verificación'**
  String get presenceConfirmTitle;

  /// Subtitle explaining what will happen on confirmation
  ///
  /// In es, this message translates to:
  /// **'Estás a punto de firmar criptográficamente tu presencia para:'**
  String get presenceConfirmSubtitle;

  /// Label for the verifier ID box on the confirmation screen
  ///
  /// In es, this message translates to:
  /// **'Verificador'**
  String get presenceVerifierLabel;

  /// Step 1 title in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'Liveness check'**
  String get presenceStep1Title;

  /// Step 1 subtitle in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'Giro de cabeza para confirmar presencia'**
  String get presenceStep1Subtitle;

  /// Step 2 title in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'FaceTec 3D'**
  String get presenceStep2Title;

  /// Step 2 subtitle in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'Verificación facial anti-spoofing de nivel industrial'**
  String get presenceStep2Subtitle;

  /// Step 3 title in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'Autorización Face ID'**
  String get presenceStep3Title;

  /// Step 3 subtitle in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'Firma criptográfica con Secure Enclave'**
  String get presenceStep3Subtitle;

  /// Step 4 title in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'Badge de presencia'**
  String get presenceStep4Title;

  /// Step 4 subtitle in the presence confirmation flow
  ///
  /// In es, this message translates to:
  /// **'JWT efímero válido por 5 minutos'**
  String get presenceStep4Subtitle;

  /// CTA button to start the verification flow
  ///
  /// In es, this message translates to:
  /// **'Verificar mi presencia'**
  String get presenceConfirmButton;

  /// Status message at the start of the verification flow
  ///
  /// In es, this message translates to:
  /// **'Iniciando...'**
  String get presenceFlowIdle;

  /// Status message during the liveness step
  ///
  /// In es, this message translates to:
  /// **'Gira la cabeza para confirmar\nque eres una persona real'**
  String get presenceFlowLiveness;

  /// Status message during the FaceTec step
  ///
  /// In es, this message translates to:
  /// **'Verificación 3D con FaceTec\nColoca tu cara en el óvalo'**
  String get presenceFlowFacetec;

  /// Status message during the passkey/Face ID step
  ///
  /// In es, this message translates to:
  /// **'Autoriza con Face ID\npara firmar el badge'**
  String get presenceFlowPasskey;

  /// Status message while the badge is being issued
  ///
  /// In es, this message translates to:
  /// **'Emitiendo badge de presencia...'**
  String get presenceFlowIssuing;

  /// Status message when the badge has been successfully issued
  ///
  /// In es, this message translates to:
  /// **'¡Badge emitido!'**
  String get presenceFlowDone;

  /// Step indicator label for liveness check
  ///
  /// In es, this message translates to:
  /// **'Liveness'**
  String get presenceStepLiveness;

  /// Step indicator label for FaceTec
  ///
  /// In es, this message translates to:
  /// **'FaceTec 3D'**
  String get presenceStepFacetec;

  /// Step indicator label for Face ID passkey
  ///
  /// In es, this message translates to:
  /// **'Face ID'**
  String get presenceStepFaceId;

  /// Step indicator label for badge issuance
  ///
  /// In es, this message translates to:
  /// **'Badge'**
  String get presenceStepBadge;

  /// Title on the error screen of the presence challenge flow
  ///
  /// In es, this message translates to:
  /// **'Error en la verificación'**
  String get presenceErrorTitle;

  /// Fallback error message when no specific message is available
  ///
  /// In es, this message translates to:
  /// **'Error desconocido'**
  String get presenceErrorUnknown;

  /// Error when the QR nonce is not found
  ///
  /// In es, this message translates to:
  /// **'El código QR ya no es válido. Pide uno nuevo.'**
  String get presenceErrorQrNotFound;

  /// Error when the QR nonce has already been used
  ///
  /// In es, this message translates to:
  /// **'Este código QR ya fue utilizado.'**
  String get presenceErrorQrUsed;

  /// Error when the QR nonce has expired
  ///
  /// In es, this message translates to:
  /// **'El código QR expiró. Pide uno nuevo.'**
  String get presenceErrorQrExpired;

  /// Error when the passkey/biometric authorization fails
  ///
  /// In es, this message translates to:
  /// **'Error en la autorización biométrica.'**
  String get presenceErrorBiometric;

  /// Tab label for received verification requests
  ///
  /// In es, this message translates to:
  /// **'Recibidas'**
  String get inboxTabReceived;

  /// Tab label for sent verification requests
  ///
  /// In es, this message translates to:
  /// **'Enviadas'**
  String get inboxTabSent;

  /// Empty state title for the received tab
  ///
  /// In es, this message translates to:
  /// **'Sin solicitudes recibidas'**
  String get inboxEmptyReceived;

  /// Empty state description for the received tab
  ///
  /// In es, this message translates to:
  /// **'Cuando alguien te solicite verificar tu identidad, aparecerá aquí.'**
  String get inboxEmptyReceivedDesc;

  /// Dialog title when rejecting an incoming challenge
  ///
  /// In es, this message translates to:
  /// **'¿Rechazar solicitud?'**
  String get inboxRejectTitle;

  /// Dialog body when rejecting an incoming challenge
  ///
  /// In es, this message translates to:
  /// **'Se notificará a {name} que rechazaste la verificación.'**
  String inboxRejectContent(String name);

  /// Button to confirm rejecting an incoming challenge
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get inboxRejectButton;

  /// Snackbar shown after rejecting a challenge
  ///
  /// In es, this message translates to:
  /// **'Solicitud rechazada'**
  String get inboxRejectedSnack;

  /// Time label shown when an incoming challenge has expired
  ///
  /// In es, this message translates to:
  /// **'No verificada a tiempo — caducada'**
  String get inboxTimeExpired;

  /// Time remaining label for hours and minutes
  ///
  /// In es, this message translates to:
  /// **'{hours}h {minutes}m restantes'**
  String inboxTimeHoursMinutes(int hours, int minutes);

  /// Time remaining label for minutes only
  ///
  /// In es, this message translates to:
  /// **'{minutes}m restantes'**
  String inboxTimeMinutes(int minutes);

  /// Fallback sender name for anonymous incoming requests
  ///
  /// In es, this message translates to:
  /// **'Solicitud anónima'**
  String get inboxAnonymousRequest;

  /// Badge label shown when an incoming challenge has expired
  ///
  /// In es, this message translates to:
  /// **'Caducada'**
  String get inboxExpiredLabel;

  /// Button to resume an in-progress verification
  ///
  /// In es, this message translates to:
  /// **'Retomar'**
  String get inboxResumeButton;

  /// Button to start verifying an incoming challenge
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get inboxVerifyButton;

  /// Empty state title for the sent tab
  ///
  /// In es, this message translates to:
  /// **'Sin solicitudes enviadas'**
  String get inboxEmptySent;

  /// Empty state description for the sent tab
  ///
  /// In es, this message translates to:
  /// **'Busca a un usuario y envíale una solicitud de verificación.'**
  String get inboxEmptySentDesc;

  /// Dialog title when cancelling a sent challenge
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar solicitud?'**
  String get inboxCancelTitle;

  /// Dialog body when cancelling a sent challenge
  ///
  /// In es, this message translates to:
  /// **'La solicitud enviada a {email} será cancelada y ya no podrá ser verificada.'**
  String inboxCancelContent(String email);

  /// Button to keep (not cancel) a sent challenge
  ///
  /// In es, this message translates to:
  /// **'No, mantener'**
  String get inboxKeepButton;

  /// Button to confirm cancelling a sent challenge
  ///
  /// In es, this message translates to:
  /// **'Cancelar solicitud'**
  String get inboxCancelButton;

  /// Tooltip on the cancel icon in the sent card
  ///
  /// In es, this message translates to:
  /// **'Cancelar solicitud'**
  String get inboxCancelTooltip;

  /// Snackbar shown after a challenge is cancelled
  ///
  /// In es, this message translates to:
  /// **'Solicitud cancelada'**
  String get inboxCancelledSnack;

  /// Status chip label when a sent challenge is completed (USED)
  ///
  /// In es, this message translates to:
  /// **'Completada'**
  String get sentStatusUsed;

  /// Status chip label when verification is in progress
  ///
  /// In es, this message translates to:
  /// **'Verificando'**
  String get sentStatusInProgress;

  /// Status chip label when a sent challenge has expired
  ///
  /// In es, this message translates to:
  /// **'Expirada'**
  String get sentStatusExpired;

  /// Status chip label when a sent challenge was rejected
  ///
  /// In es, this message translates to:
  /// **'Rechazada'**
  String get sentStatusRejected;

  /// Status chip label when a sent challenge was cancelled
  ///
  /// In es, this message translates to:
  /// **'Cancelada'**
  String get sentStatusCancelled;

  /// Status chip label when a sent challenge is pending
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get sentStatusPending;

  /// Fallback text when recipient name and email are both null
  ///
  /// In es, this message translates to:
  /// **'Destinatario'**
  String get sentRecipient;

  /// Relative time label for minutes ago
  ///
  /// In es, this message translates to:
  /// **'Hace {minutes}m'**
  String sentTimeAgoMinutes(int minutes);

  /// Relative time label for hours ago
  ///
  /// In es, this message translates to:
  /// **'Hace {hours}h'**
  String sentTimeAgoHours(int hours);

  /// AppBar title for the Badge screen
  ///
  /// In es, this message translates to:
  /// **'Badge de Presencia'**
  String get badgeTitle;

  /// Status label shown when the badge has expired
  ///
  /// In es, this message translates to:
  /// **'BADGE EXPIRADO'**
  String get badgeExpired;

  /// Status label shown when the badge is valid
  ///
  /// In es, this message translates to:
  /// **'PRESENCIA VERIFICADA'**
  String get badgeVerified;

  /// Label below the badge countdown timer
  ///
  /// In es, this message translates to:
  /// **'Expira en'**
  String get badgeExpiresIn;

  /// Label for the verifier field in badge details
  ///
  /// In es, this message translates to:
  /// **'Verificador'**
  String get badgeVerifierLabel;

  /// Label for the issued-at field in badge details
  ///
  /// In es, this message translates to:
  /// **'Emitido'**
  String get badgeIssuedLabel;

  /// Label for the expires-at field in badge details
  ///
  /// In es, this message translates to:
  /// **'Expira'**
  String get badgeExpiresLabel;

  /// Label for the badge ID (JTI) field
  ///
  /// In es, this message translates to:
  /// **'Badge ID'**
  String get badgeIdLabel;

  /// Snackbar shown after the JWT is copied
  ///
  /// In es, this message translates to:
  /// **'JWT copiado al portapapeles'**
  String get badgeCopied;

  /// Button to copy the JWT to clipboard
  ///
  /// In es, this message translates to:
  /// **'Copiar JWT'**
  String get badgeCopyJwt;

  /// Dialog title for the logout confirmation
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get profileLogoutTitle;

  /// Dialog body for the logout confirmation
  ///
  /// In es, this message translates to:
  /// **'¿Seguro que quieres cerrar sesión?'**
  String get profileLogoutContent;

  /// Button to confirm logout
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get profileLogoutButton;

  /// Error title when the profile fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el perfil'**
  String get profileLoadError;

  /// Error title when the account session JWT is invalid or expired
  ///
  /// In es, this message translates to:
  /// **'Tu sesión ha expirado'**
  String get profileSessionExpired;

  /// Button to return to login after session expiry
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión de nuevo'**
  String get profileSignInAgain;

  /// AppBar title for the account profile screen
  ///
  /// In es, this message translates to:
  /// **'Mi Perfil'**
  String get profileTitle;

  /// Badge label showing the identity is verified
  ///
  /// In es, this message translates to:
  /// **'Identidad verificada'**
  String get profileVerifiedBadge;

  /// Label for the email info tile in the profile screen
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get profileEmailLabel;

  /// Label for the ID type info tile in the profile screen
  ///
  /// In es, this message translates to:
  /// **'Tipo de ID'**
  String get profileIdTypeLabel;

  /// Label for the CURP info tile in the profile screen
  ///
  /// In es, this message translates to:
  /// **'CURP'**
  String get profileCurpLabel;

  /// Label for the date of birth info tile in the profile screen
  ///
  /// In es, this message translates to:
  /// **'Fecha de nacimiento'**
  String get profileBirthDateLabel;

  /// Logout button label in the profile screen
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get profileLogoutButtonLabel;

  /// Title shown at the top of all liveness screens
  ///
  /// In es, this message translates to:
  /// **'Verificación de Presencia'**
  String get livenessTitle;

  /// Liveness instruction for centering face
  ///
  /// In es, this message translates to:
  /// **'Centra tu cara en el óvalo'**
  String get livenessInstructionCenter;

  /// Liveness instruction to turn head
  ///
  /// In es, this message translates to:
  /// **'Gira la cabeza a un lado'**
  String get livenessInstructionTurn;

  /// Liveness instruction to return to center
  ///
  /// In es, this message translates to:
  /// **'Regresa al centro'**
  String get livenessInstructionReturn;

  /// Liveness instruction shown when verification is complete
  ///
  /// In es, this message translates to:
  /// **'¡Verificación completada!'**
  String get livenessInstructionDone;

  /// Liveness instruction shown in fallback mode
  ///
  /// In es, this message translates to:
  /// **'Verificando presencia...'**
  String get livenessInstructionFallback;

  /// Liveness countdown ready message
  ///
  /// In es, this message translates to:
  /// **'¡Prepárate para la foto!'**
  String get livenessCountdownReady;

  /// Liveness countdown shoot message
  ///
  /// In es, this message translates to:
  /// **'¡Foto!'**
  String get livenessCountdownShoot;

  /// Quality check failure: no face detected
  ///
  /// In es, this message translates to:
  /// **'No se detectó rostro — acércate un poco'**
  String get livenessQualityNoFace;

  /// Quality check failure: eyes not open
  ///
  /// In es, this message translates to:
  /// **'Abre los ojos para la foto'**
  String get livenessQualityEyesClosed;

  /// Quality check failure: face angle too high
  ///
  /// In es, this message translates to:
  /// **'Mira de frente a la cámara'**
  String get livenessQualityFaceAngle;

  /// Quality check failure: head tilted
  ///
  /// In es, this message translates to:
  /// **'Endereza la cabeza'**
  String get livenessQualityTilted;

  /// Error title shown when the QR scanner camera fails to start
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar la cámara'**
  String get scannerCameraError;

  /// Placeholder text while the scanner camera initializes
  ///
  /// In es, this message translates to:
  /// **'Iniciando cámara…'**
  String get scannerStarting;

  /// Title shown when camera permission is denied on scanner screen
  ///
  /// In es, this message translates to:
  /// **'Se necesita acceso a la cámara'**
  String get scannerPermissionTitle;

  /// Instructions to grant camera permission for QR scanner
  ///
  /// In es, this message translates to:
  /// **'Ve a Ajustes → Verifia → Cámara y actívala, luego pulsa Reintentar.'**
  String get scannerPermissionSubtitle;

  /// Bottom instruction label on the QR scanner screen
  ///
  /// In es, this message translates to:
  /// **'Escanea el QR del verificador'**
  String get scannerInstruction;

  /// Hint text in the user search field
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o correo…'**
  String get searchHint;

  /// Empty-state title on the user search screen
  ///
  /// In es, this message translates to:
  /// **'Busca usuarios de VerifiA'**
  String get searchTitle;

  /// Empty-state description on the user search screen
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 2 caracteres para buscar por nombre o correo electrónico.'**
  String get searchDesc;

  /// No-results message on the search screen, includes query
  ///
  /// In es, this message translates to:
  /// **'Sin resultados para \"{query}\"'**
  String searchNoResults(String query);

  /// Secondary no-results hint on the search screen
  ///
  /// In es, this message translates to:
  /// **'Intenta con otro nombre o correo.'**
  String get searchNoResultsDesc;

  /// Badge shown on a search result that is the logged-in user
  ///
  /// In es, this message translates to:
  /// **'Tú'**
  String get searchYou;

  /// Title for the set-password screen after onboarding
  ///
  /// In es, this message translates to:
  /// **'Crea tu acceso web'**
  String get setPasswordTitle;

  /// Subtitle explaining the web account on the set-password screen
  ///
  /// In es, this message translates to:
  /// **'Con una cuenta podrás iniciar sesión en el portal web para generar QRs de verificación y consultar tu historial.'**
  String get setPasswordSubtitle;

  /// Hint text for the email field on the set-password screen
  ///
  /// In es, this message translates to:
  /// **'tu@email.com'**
  String get setPasswordEmailHint;

  /// Validator message when email is empty on set-password screen
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get setPasswordEmailRequired;

  /// Validator message when email format is invalid on set-password screen
  ///
  /// In es, this message translates to:
  /// **'Correo no válido'**
  String get setPasswordEmailInvalid;

  /// Hint text for the password field on set-password screen
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get setPasswordPasswordHint;

  /// Validator message when password is too short
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get setPasswordPasswordMinLength;

  /// Label for the confirm password field
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get setPasswordConfirmLabel;

  /// Validator message when passwords do not match
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get setPasswordPasswordMismatch;

  /// Button to create the web account on set-password screen
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get setPasswordCreateButton;

  /// Button to skip creating a web account for now
  ///
  /// In es, this message translates to:
  /// **'Omitir por ahora'**
  String get setPasswordSkip;

  /// Welcome step title in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a VerifiA'**
  String get wizardWelcomeTitle;

  /// Welcome step description in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'Para ofrecerte la mejor experiencia de verificación de identidad, necesitamos configurar algunos permisos en tu dispositivo.'**
  String get wizardWelcomeDesc;

  /// Network step title in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'Acceso a la red'**
  String get wizardNetworkTitle;

  /// Network step description in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'VerifiA necesita conectarse a internet para emitir y validar badges de presencia en tiempo real de forma segura.'**
  String get wizardNetworkDesc;

  /// Camera step title in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'Acceso a la cámara'**
  String get wizardCameraTitle;

  /// Camera step description in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'VerifiA usa tu cámara para escanear códigos QR de verificadores y para capturar tu selfie durante el proceso de detección de presencia.'**
  String get wizardCameraDesc;

  /// Face ID step title in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'Autenticación con Face ID'**
  String get wizardFaceIdTitle;

  /// Face ID step description in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'Face ID confirma tu identidad antes de cada verificación. Tus datos biométricos nunca salen de tu dispositivo.'**
  String get wizardFaceIdDesc;

  /// Done step title in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'¡Todo listo!'**
  String get wizardDoneTitle;

  /// Done step description in the permissions wizard
  ///
  /// In es, this message translates to:
  /// **'Los permisos están configurados. Ahora crea tu perfil de identidad verificada.'**
  String get wizardDoneDesc;

  /// CTA button label on the welcome step
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get wizardButtonStart;

  /// CTA button label on the network step
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get wizardButtonUnderstood;

  /// CTA button label on the camera step
  ///
  /// In es, this message translates to:
  /// **'Permitir acceso a la cámara'**
  String get wizardButtonCamera;

  /// CTA button label on the Face ID step
  ///
  /// In es, this message translates to:
  /// **'Configurar Face ID'**
  String get wizardButtonFaceId;

  /// CTA button label on the done step
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get wizardButtonContinue;

  /// Skip button label on permission steps
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get wizardButtonLater;

  /// Label for the registration selfie photo in verification detail
  ///
  /// In es, this message translates to:
  /// **'Foto de registro'**
  String get verDetailSelfieLabel;

  /// Zoom hint overlay text on tappable photos
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get verDetailZoomHint;

  /// Label shown in the hero header of a completed verification
  ///
  /// In es, this message translates to:
  /// **'Verificación completada'**
  String get verDetailCompleted;

  /// Label for the sent date in the info card
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada'**
  String get verDetailRequestSent;

  /// Label for the verified date in the info card
  ///
  /// In es, this message translates to:
  /// **'Verificado el'**
  String get verDetailVerifiedAt;

  /// Label for the ID type row in the info card
  ///
  /// In es, this message translates to:
  /// **'Tipo de ID'**
  String get verDetailIdType;

  /// Section title for the FaceTec match score
  ///
  /// In es, this message translates to:
  /// **'Puntuación biométrica'**
  String get verDetailBiometricScore;

  /// Section title and label for the liveness snapshot
  ///
  /// In es, this message translates to:
  /// **'Selfie de verificación'**
  String get verDetailSelfieVerification;

  /// Section title for the submitted ID photo
  ///
  /// In es, this message translates to:
  /// **'Identificación presentada'**
  String get verDetailIdPhotoLabel;

  /// Title shown when the FaceTec score is not available
  ///
  /// In es, this message translates to:
  /// **'No disponible'**
  String get verDetailScoreUnavailable;

  /// Description when FaceTec score is unavailable
  ///
  /// In es, this message translates to:
  /// **'El match FaceTec no generó puntuación en esta sesión (modo desarrollo o SDK no configurado).'**
  String get verDetailScoreUnavailableDesc;

  /// Score label for >= 90
  ///
  /// In es, this message translates to:
  /// **'Excelente'**
  String get verDetailScoreExcellent;

  /// Score label for >= 75
  ///
  /// In es, this message translates to:
  /// **'Muy alto'**
  String get verDetailScoreVeryHigh;

  /// Score label for >= 60
  ///
  /// In es, this message translates to:
  /// **'Aceptable'**
  String get verDetailScoreAcceptable;

  /// Score label for >= 40
  ///
  /// In es, this message translates to:
  /// **'Bajo'**
  String get verDetailScoreLow;

  /// Score label for < 40
  ///
  /// In es, this message translates to:
  /// **'Insuficiente'**
  String get verDetailScoreInsufficient;

  /// Description label below the score bar
  ///
  /// In es, this message translates to:
  /// **'Match cara vs. ID presentado'**
  String get verDetailScoreMatchLabel;

  /// Verified badge text on public profile screen
  ///
  /// In es, this message translates to:
  /// **'Identidad verificada con FaceTec'**
  String get publicProfileVerifiedFacetec;

  /// Age display on public profile screen
  ///
  /// In es, this message translates to:
  /// **'{age} años'**
  String publicProfileAge(int age);

  /// Section title for the official ID photo on public profile
  ///
  /// In es, this message translates to:
  /// **'Identificación oficial'**
  String get publicProfileIdLabel;

  /// Caption below the ID photo on public profile
  ///
  /// In es, this message translates to:
  /// **'Documento escaneado durante el registro'**
  String get publicProfileIdDesc;

  /// Score label for >= 70 on public profile
  ///
  /// In es, this message translates to:
  /// **'Alta coincidencia'**
  String get publicProfileScoreHigh;

  /// Score label for >= 40 on public profile
  ///
  /// In es, this message translates to:
  /// **'Coincidencia media'**
  String get publicProfileScoreMedium;

  /// Score label for < 40 on public profile
  ///
  /// In es, this message translates to:
  /// **'Coincidencia baja'**
  String get publicProfileScoreLow;

  /// Title for the FaceTec score card on public profile
  ///
  /// In es, this message translates to:
  /// **'FaceTec ID Match'**
  String get publicProfileFacetecTitle;

  /// Description for the FaceTec score on public profile
  ///
  /// In es, this message translates to:
  /// **'Score de coincidencia cara vs. ID al registrarse'**
  String get publicProfileFacetecDesc;

  /// Full score label combining label and numeric score on public profile
  ///
  /// In es, this message translates to:
  /// **'{label} — {score}/100'**
  String publicProfileScoreLabelFull(String label, int score);

  /// Snackbar shown after a verification request is sent from public profile
  ///
  /// In es, this message translates to:
  /// **'Solicitud de verificación enviada'**
  String get publicProfileRequestSentSnack;

  /// Button label after the verification request is sent
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada'**
  String get publicProfileButtonSent;

  /// Button to send a verification request from public profile
  ///
  /// In es, this message translates to:
  /// **'Enviar solicitud de verificación'**
  String get publicProfileButtonSend;

  /// Mock liveness instruction 1
  ///
  /// In es, this message translates to:
  /// **'Mantén el teléfono frente a tu cara'**
  String get livenessMockInstruction1;

  /// Mock liveness instruction 2
  ///
  /// In es, this message translates to:
  /// **'Gira lentamente hacia la derecha'**
  String get livenessMockInstruction2;

  /// Mock liveness instruction 3
  ///
  /// In es, this message translates to:
  /// **'Regresa al centro'**
  String get livenessMockInstruction3;

  /// Mock liveness instruction 4
  ///
  /// In es, this message translates to:
  /// **'Gira lentamente hacia la izquierda'**
  String get livenessMockInstruction4;

  /// Mock liveness instruction 5
  ///
  /// In es, this message translates to:
  /// **'Mira directamente a la cámara'**
  String get livenessMockInstruction5;

  /// Progress label when mock liveness is complete
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get livenessMockCompleted;

  /// Email field label on the login screen
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get loginEmailLabel;

  /// Email field placeholder on the login screen
  ///
  /// In es, this message translates to:
  /// **'tu@email.com'**
  String get loginEmailHint;

  /// Password field label on the set-password screen
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get setPasswordLabel;

  /// Password field hint on the set-password screen
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get setPasswordHint;

  /// Primary button label on set-password screen
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get setPasswordButton;

  /// Validation error when passwords don't match
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get setPasswordMismatch;

  /// Validation error when password is too short
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get setPasswordTooShort;

  /// Error title shown when a public profile fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el perfil'**
  String get publicProfileLoadError;

  /// Permissions wizard welcome step title
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a VerifiA'**
  String get permWelcomeTitle;

  /// Permissions wizard welcome step body
  ///
  /// In es, this message translates to:
  /// **'Para ofrecerte la mejor experiencia de verificación de identidad, necesitamos configurar algunos permisos en tu dispositivo.'**
  String get permWelcomeBody;

  /// Permissions wizard network step title
  ///
  /// In es, this message translates to:
  /// **'Acceso a la red'**
  String get permNetworkTitle;

  /// Permissions wizard network step body
  ///
  /// In es, this message translates to:
  /// **'VerifiA necesita conectarse a internet para emitir y validar badges de presencia en tiempo real de forma segura.'**
  String get permNetworkBody;

  /// Permissions wizard camera step title
  ///
  /// In es, this message translates to:
  /// **'Acceso a la cámara'**
  String get permCameraTitle;

  /// Permissions wizard camera step body
  ///
  /// In es, this message translates to:
  /// **'VerifiA usa tu cámara para escanear códigos QR de verificadores y para capturar tu selfie durante el proceso de detección de presencia.'**
  String get permCameraBody;

  /// Permissions wizard Face ID step title
  ///
  /// In es, this message translates to:
  /// **'Autenticación con Face ID'**
  String get permFaceIdTitle;

  /// Permissions wizard Face ID step body
  ///
  /// In es, this message translates to:
  /// **'Face ID confirma tu identidad antes de cada verificación. Tus datos biométricos nunca salen de tu dispositivo.'**
  String get permFaceIdBody;

  /// Permissions wizard done step title
  ///
  /// In es, this message translates to:
  /// **'¡Todo listo!'**
  String get permDoneTitle;

  /// Permissions wizard done step body
  ///
  /// In es, this message translates to:
  /// **'Los permisos están configurados. Ahora crea tu perfil de identidad verificada.'**
  String get permDoneBody;

  /// Permissions wizard CTA for welcome step
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get permCtaBegin;

  /// Permissions wizard CTA for network step
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get permCtaUnderstood;

  /// Permissions wizard CTA for camera step
  ///
  /// In es, this message translates to:
  /// **'Permitir acceso a la cámara'**
  String get permCtaCamera;

  /// Permissions wizard CTA for Face ID step
  ///
  /// In es, this message translates to:
  /// **'Configurar Face ID'**
  String get permCtaFaceId;

  /// Permissions wizard CTA for done step
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get permCtaContinue;

  /// Permissions wizard skip button label
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get permSkip;

  /// Permissions wizard notifications step title
  ///
  /// In es, this message translates to:
  /// **'Notificaciones push'**
  String get permNotificationsTitle;

  /// Permissions wizard notifications step body
  ///
  /// In es, this message translates to:
  /// **'VerifiA te avisa cuando llega una solicitud de verificación, cuando alguien completa la tuya o si una es rechazada o cancelada.'**
  String get permNotificationsBody;

  /// Permissions wizard CTA for notifications step
  ///
  /// In es, this message translates to:
  /// **'Activar notificaciones'**
  String get permCtaNotifications;

  /// Label above the permission checklist on the done step
  ///
  /// In es, this message translates to:
  /// **'Estado de permisos'**
  String get permDoneChecklist;

  /// Checklist row for network/internet permission
  ///
  /// In es, this message translates to:
  /// **'Acceso a internet'**
  String get permCheckNetwork;

  /// Checklist row for push notifications permission
  ///
  /// In es, this message translates to:
  /// **'Notificaciones push'**
  String get permCheckNotifications;

  /// Checklist row for camera permission
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get permCheckCamera;

  /// Checklist row for Face ID/biometrics permission
  ///
  /// In es, this message translates to:
  /// **'Face ID / Biometría'**
  String get permCheckFaceId;

  /// Button to retry a denied permission
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get permRetryButton;

  /// Button to open app settings for permanently denied permission
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get permOpenSettings;

  /// Body shown on done step when some permissions are still denied
  ///
  /// In es, this message translates to:
  /// **'Activa todos los permisos para continuar.'**
  String get permDoneBodyBlocked;

  /// Button label to request camera permission on QR scanner screen
  ///
  /// In es, this message translates to:
  /// **'Permitir cámara'**
  String get scannerAllowCamera;

  /// Button label to open app settings when camera permission is permanently denied
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get scannerOpenSettings;

  /// Hero header label on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Verificación completada'**
  String get verificationDetailCompleted;

  /// Fallback name shown when no subject name/email is available
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get verificationDetailUser;

  /// Row label for request sent date on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada'**
  String get verificationDetailRequestSent;

  /// Row label for verification date on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Verificado el'**
  String get verificationDetailVerifiedOn;

  /// Row label for ID type on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Tipo de ID'**
  String get verificationDetailIdType;

  /// Section title for biometric score on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Puntuación biométrica'**
  String get verificationDetailBiometricScore;

  /// Section title for liveness snapshot on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Selfie de verificación'**
  String get verificationDetailVerifySelfie;

  /// Section title for ID photo on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Identificación presentada'**
  String get verificationDetailIdPresented;

  /// Photo viewer title for selfie in hero header
  ///
  /// In es, this message translates to:
  /// **'Foto de registro'**
  String get verificationDetailSelfieLabel;

  /// Score unavailable title on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'No disponible'**
  String get verificationDetailScoreUnavailable;

  /// Score unavailable description on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'El match FaceTec no generó puntuación en esta sesión (modo desarrollo o SDK no configurado).'**
  String get verificationDetailScoreUnavailableDesc;

  /// Caption under the score bar on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Match cara vs. ID presentado'**
  String get verificationDetailScoreCaption;

  /// Score label for 90+ match on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Excelente'**
  String get scoreExcellent;

  /// Score label for 75-89 match on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Muy alto'**
  String get scoreVeryHigh;

  /// Score label for 60-74 match on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Aceptable'**
  String get scoreAcceptable;

  /// Score label for 40-59 match on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Bajo'**
  String get scoreLow;

  /// Score label for below 40 match on verification detail screen
  ///
  /// In es, this message translates to:
  /// **'Insuficiente'**
  String get scoreInsufficient;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
