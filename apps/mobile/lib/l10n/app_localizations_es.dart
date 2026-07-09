// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get cancel => 'Cancelar';

  @override
  String get dismiss => 'Descartar';

  @override
  String get seeAction => 'Ver';

  @override
  String get retry => 'Reintentar';

  @override
  String get back => 'Volver';

  @override
  String get emailLabel => 'Correo electrónico';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get idTypeINE => 'INE / IFE';

  @override
  String get idTypePassport => 'Pasaporte';

  @override
  String get idTypeLabelShort => 'Tipo de ID';

  @override
  String get curpLabel => 'CURP';

  @override
  String get birthDateLabel => 'Fecha de nacimiento';

  @override
  String get idTypeUnknown => 'Desconocido';

  @override
  String get errorNetwork =>
      'Sin conexión. Verifica tu red e intenta de nuevo.';

  @override
  String get errorTimeout =>
      'El servidor tardó demasiado en responder. Verifica tu conexión e intenta de nuevo.';

  @override
  String get errorNoConnection =>
      'No se pudo conectar al servidor. Verifica que estés en la misma red e intenta de nuevo.';

  @override
  String get errorNetworkUnexpected =>
      'Error de red inesperado. Intenta de nuevo.';

  @override
  String get homeOfflineBanner => 'Sin conexión con el servidor';

  @override
  String get homeTabScan => 'Escanear';

  @override
  String get homeTabCreateQr => 'Crear QR';

  @override
  String get homeTabInbox => 'Actividad';

  @override
  String get homeTabSearch => 'Buscar';

  @override
  String get bannerNewRequest => 'Nueva solicitud de verificación';

  @override
  String get bannerAnonymous => 'Alguien';

  @override
  String bannerVerifiedRequest(String name) {
    return '$name ya se verificó';
  }

  @override
  String bannerRejectedRequest(String recipient) {
    return '$recipient rechazó tu solicitud';
  }

  @override
  String bannerCancelledRequest(String recipient) {
    return '$recipient canceló tu solicitud';
  }

  @override
  String get createChallengeTitle => 'Solicitar verificación';

  @override
  String get createChallengeModeQuestion =>
      '¿Cómo quieres enviar la solicitud?';

  @override
  String get createChallengeModeOpen => 'QR Abierto';

  @override
  String get createChallengeModeOpenDesc =>
      'Comparte el QR o el link con cualquier app';

  @override
  String get createChallengeModeTargeted => 'Enviar a usuario';

  @override
  String get createChallengeModeTargetedDesc =>
      'Directo a alguien, por app o correo';

  @override
  String get createChallengeEmailLabel => 'Correo del destinatario';

  @override
  String get createChallengeEmailHint => 'nombre@ejemplo.com';

  @override
  String get createChallengeButtonGenerate => 'Generar QR';

  @override
  String get createChallengeButtonNoEmail => 'Ingresa un correo para continuar';

  @override
  String get createChallengeButtonInvalidEmail => 'Correo inválido';

  @override
  String get createChallengeButtonSend => 'Enviar solicitud';

  @override
  String get createChallengeButtonGenerateInvite =>
      'Generar y preparar invitación';

  @override
  String get createChallengeHintEmailRequired =>
      'El correo del destinatario es obligatorio.';

  @override
  String get createChallengeHintEmailFormat =>
      'Ingresa un correo con formato válido (ej. nombre@ejemplo.com).';

  @override
  String get createChallengeHintRegistered =>
      'La solicitud aparecerá en la app del destinatario.';

  @override
  String get createChallengeHintUnregistered =>
      'Después de generar, podrás enviarle una invitación por correo.';

  @override
  String get createChallengeHintUnknown =>
      'Si el correo no está en VerifiA, le enviaremos una invitación.';

  @override
  String get createChallengeHintOpen =>
      'El QR estará activo 30 minutos. Compártelo por WhatsApp, iMessage o cualquier app.';

  @override
  String get createChallengeGenerating => 'Generando…';

  @override
  String get createChallengeStatusRegistered =>
      'Usuario registrado — recibirá la solicitud en la app';

  @override
  String get createChallengeStatusNotRegistered =>
      'No está en VerifiA — podrás enviarle una invitación por correo';

  @override
  String createChallengeSnackSent(String email) {
    return 'Solicitud enviada a $email';
  }

  @override
  String createChallengeSnackQrGenerated(String email) {
    return 'QR generado — envía la invitación a $email';
  }

  @override
  String createChallengeShareError(String error) {
    return 'No se pudo compartir: $error';
  }

  @override
  String get createChallengeLinkCopied => 'Link copiado al portapapeles';

  @override
  String get createChallengeQrExpired => 'QR expirado';

  @override
  String get createChallengeQrExpiredSubtitle =>
      'Genera uno nuevo para continuar';

  @override
  String get createChallengeQrReady => 'QR listo para compartir';

  @override
  String get createChallengeQrReadySubtitle =>
      'Comparte el código o el link por cualquier app';

  @override
  String get createChallengeQrSent => 'Solicitud enviada';

  @override
  String createChallengeQrSentSubtitle(String email) {
    return 'La solicitud está en la app de $email';
  }

  @override
  String get createChallengeQrGenerated => 'QR generado';

  @override
  String get createChallengeQrGeneratedSubtitle =>
      'Envía la invitación por correo para que descargue la app';

  @override
  String get createChallengeQrReadyShort => 'QR listo';

  @override
  String get createChallengeQrReadyShortSubtitle =>
      'Comparte el código o el link';

  @override
  String get createChallengeCopyLink => 'Copiar link';

  @override
  String get createChallengeShare => 'Compartir';

  @override
  String get createChallengeInviteSent => 'Invitación enviada';

  @override
  String get createChallengeInviteSending => 'Enviando…';

  @override
  String get createChallengeInviteButton => 'Enviar invitación por correo';

  @override
  String get createChallengeNewQr => 'Generar nuevo QR';

  @override
  String get createChallengeVerifiedSubtitle =>
      'La verificación fue completada exitosamente.';

  @override
  String get createChallengeCancelAndBack => 'Cancelar y volver';

  @override
  String get createChallengeCountdownLabel => 'restantes';

  @override
  String createChallengeInviteError(String error) {
    return 'Error al enviar: $error';
  }

  @override
  String get onboardingTitle => 'Registro de identidad';

  @override
  String get onboardingSubtitle =>
      'Para emitir badges de presencia necesitas registrar tu identidad una sola vez. FaceTec escaneará tu cara y tu identificación oficial.';

  @override
  String get onboardingIdTypeLabel => 'Tipo de identificación';

  @override
  String get onboardingScanButton => 'Escanear ID con FaceTec';

  @override
  String get onboardingLoginLink => '¿Ya tienes cuenta? Inicia sesión';

  @override
  String get onboardingScanCancelled => 'Escaneo cancelado';

  @override
  String get onboardingCaptureCancelled => 'Captura cancelada';

  @override
  String get onboardingFacetecStarting => 'Iniciando FaceTec...';

  @override
  String get onboardingFacetecInstructions =>
      'Sigue las instrucciones en pantalla';

  @override
  String get onboardingPreviewTitle => 'Confirma tu información';

  @override
  String get onboardingNameLabel => 'Nombre completo';

  @override
  String get onboardingOcrReading => 'Leyendo ID…';

  @override
  String get onboardingNotDetected => '(no detectado)';

  @override
  String get onboardingNameNotDetected =>
      'No se detectó el nombre en la foto. Continúa y corrígelo en tu perfil.';

  @override
  String get onboardingInfoBirthDate => 'Fecha de nac.';

  @override
  String get onboardingInfoFacetecMatch => 'Match FaceTec';

  @override
  String get onboardingIdFrontLabel => 'Frente del ID';

  @override
  String get onboardingIdBackLabel => 'Reverso del ID';

  @override
  String get onboardingRepeatButton => 'Repetir';

  @override
  String get onboardingRegisterButton => 'Registrarme';

  @override
  String get onboardingConfirming => 'Registrando perfil...';

  @override
  String get onboardingSuccess => '¡Registro exitoso!';

  @override
  String get onboardingSuccessSubtitle => 'Tu identidad fue verificada.';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get loginSubtitle => 'Usa tu correo y contraseña de VerifiA';

  @override
  String get loginEmailRequired => 'Ingresa tu correo electrónico';

  @override
  String get loginEmailInvalid => 'Correo electrónico no válido';

  @override
  String get loginPasswordRequired => 'Ingresa tu contraseña';

  @override
  String get loginErrorInvalidCredentials =>
      'Correo o contraseña incorrectos. Verifica tus datos e intenta de nuevo.';

  @override
  String get loginErrorAccountNotFound =>
      'No existe una cuenta con ese correo electrónico.';

  @override
  String get loginNoAccount => '¿No tienes cuenta?';

  @override
  String get loginRegisterLink => '¿No tienes cuenta? Regístrate';

  @override
  String get presenceConfirmTitle => 'Confirma tu verificación';

  @override
  String get presenceConfirmSubtitle =>
      'Estás a punto de firmar criptográficamente tu presencia para:';

  @override
  String get presenceVerifierLabel => 'Verificador';

  @override
  String get presenceStep1Title => 'Liveness check';

  @override
  String get presenceStep1Subtitle => 'Giro de cabeza para confirmar presencia';

  @override
  String get presenceStep2Title => 'FaceTec 3D';

  @override
  String get presenceStep2Subtitle =>
      'Verificación facial anti-spoofing de nivel industrial';

  @override
  String get presenceStep3Title => 'Autorización Face ID';

  @override
  String get presenceStep3Subtitle => 'Firma criptográfica con Secure Enclave';

  @override
  String get presenceStep4Title => 'Badge de presencia';

  @override
  String get presenceStep4Subtitle => 'JWT efímero válido por 5 minutos';

  @override
  String get presenceConfirmButton => 'Verificar mi presencia';

  @override
  String get presenceFlowIdle => 'Iniciando...';

  @override
  String get presenceFlowLiveness =>
      'Gira la cabeza para confirmar\nque eres una persona real';

  @override
  String get presenceFlowFacetec =>
      'Verificación 3D con FaceTec\nColoca tu cara en el óvalo';

  @override
  String get presenceFlowPasskey =>
      'Autoriza con Face ID\npara firmar el badge';

  @override
  String get presenceFlowIssuing => 'Emitiendo badge de presencia...';

  @override
  String get presenceFlowDone => '¡Badge emitido!';

  @override
  String get presenceStepLiveness => 'Liveness';

  @override
  String get presenceStepFacetec => 'FaceTec 3D';

  @override
  String get presenceStepFaceId => 'Face ID';

  @override
  String get presenceStepBadge => 'Badge';

  @override
  String get presenceErrorTitle => 'Error en la verificación';

  @override
  String get presenceErrorUnknown => 'Error desconocido';

  @override
  String get presenceErrorQrNotFound =>
      'El código QR ya no es válido. Pide uno nuevo.';

  @override
  String get presenceErrorQrUsed => 'Este código QR ya fue utilizado.';

  @override
  String get presenceErrorQrExpired => 'El código QR expiró. Pide uno nuevo.';

  @override
  String get presenceErrorBiometric => 'Error en la autorización biométrica.';

  @override
  String get inboxTabReceived => 'Recibidas';

  @override
  String get inboxTabSent => 'Enviadas';

  @override
  String get inboxEmptyReceived => 'Sin solicitudes recibidas';

  @override
  String get inboxEmptyReceivedDesc =>
      'Cuando alguien te solicite verificar tu identidad, aparecerá aquí.';

  @override
  String get inboxRejectTitle => '¿Rechazar solicitud?';

  @override
  String inboxRejectContent(String name) {
    return 'Se notificará a $name que rechazaste la verificación.';
  }

  @override
  String get inboxRejectButton => 'Rechazar';

  @override
  String get inboxRejectedSnack => 'Solicitud rechazada';

  @override
  String get inboxTimeExpired => 'No verificada a tiempo — caducada';

  @override
  String inboxTimeHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m restantes';
  }

  @override
  String inboxTimeMinutes(int minutes) {
    return '${minutes}m restantes';
  }

  @override
  String get inboxAnonymousRequest => 'Solicitud anónima';

  @override
  String get inboxExpiredLabel => 'Caducada';

  @override
  String get inboxResumeButton => 'Retomar';

  @override
  String get inboxVerifyButton => 'Verificar';

  @override
  String get inboxEmptySent => 'Sin solicitudes enviadas';

  @override
  String get inboxEmptySentDesc =>
      'Busca a un usuario y envíale una solicitud de verificación.';

  @override
  String get inboxCancelTitle => '¿Cancelar solicitud?';

  @override
  String inboxCancelContent(String email) {
    return 'La solicitud enviada a $email será cancelada y ya no podrá ser verificada.';
  }

  @override
  String get inboxKeepButton => 'No, mantener';

  @override
  String get inboxCancelButton => 'Cancelar solicitud';

  @override
  String get inboxCancelTooltip => 'Cancelar solicitud';

  @override
  String get inboxCancelledSnack => 'Solicitud cancelada';

  @override
  String get sentStatusUsed => 'Completada';

  @override
  String get sentStatusInProgress => 'Verificando';

  @override
  String get sentStatusExpired => 'Expirada';

  @override
  String get sentStatusRejected => 'Rechazada';

  @override
  String get sentStatusCancelled => 'Cancelada';

  @override
  String get sentStatusPending => 'Pendiente';

  @override
  String get sentRecipient => 'Destinatario';

  @override
  String sentTimeAgoMinutes(int minutes) {
    return 'Hace ${minutes}m';
  }

  @override
  String sentTimeAgoHours(int hours) {
    return 'Hace ${hours}h';
  }

  @override
  String get badgeTitle => 'Badge de Presencia';

  @override
  String get badgeExpired => 'BADGE EXPIRADO';

  @override
  String get badgeVerified => 'PRESENCIA VERIFICADA';

  @override
  String get badgeExpiresIn => 'Expira en';

  @override
  String get badgeVerifierLabel => 'Verificador';

  @override
  String get badgeIssuedLabel => 'Emitido';

  @override
  String get badgeExpiresLabel => 'Expira';

  @override
  String get badgeIdLabel => 'Badge ID';

  @override
  String get badgeCopied => 'JWT copiado al portapapeles';

  @override
  String get badgeCopyJwt => 'Copiar JWT';

  @override
  String get badgeShareTitle => 'Comparte tu constancia';

  @override
  String get badgeShareSubtitle =>
      'Una prueba firmada de esta verificación, válida por 30 días.';

  @override
  String get badgeShareQr => 'Compartir QR';

  @override
  String get badgeShareLink => 'Compartir enlace';

  @override
  String get badgeCopyLink => 'Copiar enlace';

  @override
  String get badgeLinkCopied => 'Enlace copiado al portapapeles';

  @override
  String get badgeShareMessage =>
      'Constancia de verificación VerifiA — escanea el QR o abre el enlace para comprobar su autenticidad.';

  @override
  String get badgeShareError =>
      'No se pudo compartir la constancia. Intenta de nuevo.';

  @override
  String get profileLogoutTitle => 'Cerrar sesión';

  @override
  String get profileLogoutContent => '¿Seguro que quieres cerrar sesión?';

  @override
  String get profileLogoutButton => 'Cerrar sesión';

  @override
  String get profileLoadError => 'No se pudo cargar el perfil';

  @override
  String get profileSessionExpired => 'Tu sesión ha expirado';

  @override
  String get profileSignInAgain => 'Iniciar sesión de nuevo';

  @override
  String get profileTitle => 'Mi Perfil';

  @override
  String get profileVerifiedBadge => 'Identidad verificada';

  @override
  String get profileEmailLabel => 'Correo electrónico';

  @override
  String get profileIdTypeLabel => 'Tipo de ID';

  @override
  String get profileCurpLabel => 'CURP';

  @override
  String get profileBirthDateLabel => 'Fecha de nacimiento';

  @override
  String get profileLogoutButtonLabel => 'Cerrar sesión';

  @override
  String get livenessTitle => 'Verificación de Presencia';

  @override
  String get livenessInstructionCenter => 'Centra tu cara en el óvalo';

  @override
  String get livenessInstructionTurn => 'Gira la cabeza a un lado';

  @override
  String get livenessInstructionReturn => 'Regresa al centro';

  @override
  String get livenessInstructionDone => '¡Verificación completada!';

  @override
  String get livenessInstructionFallback => 'Verificando presencia...';

  @override
  String get livenessCountdownReady => '¡Prepárate para la foto!';

  @override
  String get livenessCountdownShoot => '¡Foto!';

  @override
  String get livenessQualityNoFace => 'No se detectó rostro — acércate un poco';

  @override
  String get livenessQualityEyesClosed => 'Abre los ojos para la foto';

  @override
  String get livenessQualityFaceAngle => 'Mira de frente a la cámara';

  @override
  String get livenessQualityTilted => 'Endereza la cabeza';

  @override
  String get scannerCameraError => 'No se pudo iniciar la cámara';

  @override
  String get scannerStarting => 'Iniciando cámara…';

  @override
  String get scannerPermissionTitle => 'Se necesita acceso a la cámara';

  @override
  String get scannerPermissionSubtitle =>
      'Ve a Ajustes → Verifia → Cámara y actívala, luego pulsa Reintentar.';

  @override
  String get scannerInstruction => 'Escanea el QR del verificador';

  @override
  String get searchHint => 'Buscar por nombre o correo…';

  @override
  String get searchTitle => 'Busca usuarios de VerifiA';

  @override
  String get searchDesc =>
      'Escribe al menos 2 caracteres para buscar por nombre o correo electrónico.';

  @override
  String searchNoResults(String query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String get searchNoResultsDesc => 'Intenta con otro nombre o correo.';

  @override
  String get searchYou => 'Tú';

  @override
  String get setPasswordTitle => 'Crea tu acceso web';

  @override
  String get setPasswordSubtitle =>
      'Con una cuenta podrás iniciar sesión en el portal web para generar QRs de verificación y consultar tu historial.';

  @override
  String get setPasswordEmailHint => 'tu@email.com';

  @override
  String get setPasswordEmailRequired => 'Ingresa tu correo';

  @override
  String get setPasswordEmailInvalid => 'Correo no válido';

  @override
  String get setPasswordPasswordHint => 'Mínimo 8 caracteres';

  @override
  String get setPasswordPasswordMinLength => 'Mínimo 8 caracteres';

  @override
  String get setPasswordConfirmLabel => 'Confirmar contraseña';

  @override
  String get setPasswordPasswordMismatch => 'Las contraseñas no coinciden';

  @override
  String get setPasswordCreateButton => 'Crear cuenta';

  @override
  String get wizardWelcomeTitle => 'Bienvenido a VerifiA';

  @override
  String get wizardWelcomeDesc =>
      'Para ofrecerte la mejor experiencia de verificación de identidad, necesitamos configurar algunos permisos en tu dispositivo.';

  @override
  String get wizardNetworkTitle => 'Acceso a la red';

  @override
  String get wizardNetworkDesc =>
      'VerifiA necesita conectarse a internet para emitir y validar badges de presencia en tiempo real de forma segura.';

  @override
  String get wizardCameraTitle => 'Acceso a la cámara';

  @override
  String get wizardCameraDesc =>
      'VerifiA usa tu cámara para escanear códigos QR de verificadores y para capturar tu selfie durante el proceso de detección de presencia.';

  @override
  String get wizardFaceIdTitle => 'Autenticación con Face ID';

  @override
  String get wizardFaceIdDesc =>
      'Face ID confirma tu identidad antes de cada verificación. Tus datos biométricos nunca salen de tu dispositivo.';

  @override
  String get wizardDoneTitle => '¡Todo listo!';

  @override
  String get wizardDoneDesc =>
      'Los permisos están configurados. Ahora crea tu perfil de identidad verificada.';

  @override
  String get wizardButtonStart => 'Comenzar';

  @override
  String get wizardButtonUnderstood => 'Entendido';

  @override
  String get wizardButtonCamera => 'Permitir acceso a la cámara';

  @override
  String get wizardButtonFaceId => 'Configurar Face ID';

  @override
  String get wizardButtonContinue => 'Continuar';

  @override
  String get wizardButtonLater => 'Ahora no';

  @override
  String get verDetailSelfieLabel => 'Foto de registro';

  @override
  String get verDetailZoomHint => 'Ver';

  @override
  String get verDetailCompleted => 'Verificación completada';

  @override
  String get verDetailRequestSent => 'Solicitud enviada';

  @override
  String get verDetailVerifiedAt => 'Verificado el';

  @override
  String get verDetailIdType => 'Tipo de ID';

  @override
  String get verDetailBiometricScore => 'Puntuación biométrica';

  @override
  String get verDetailSelfieVerification => 'Selfie de verificación';

  @override
  String get verDetailIdPhotoLabel => 'Identificación presentada';

  @override
  String get verDetailScoreUnavailable => 'No disponible';

  @override
  String get verDetailScoreUnavailableDesc =>
      'El match FaceTec no generó puntuación en esta sesión (modo desarrollo o SDK no configurado).';

  @override
  String get verDetailScoreExcellent => 'Excelente';

  @override
  String get verDetailScoreVeryHigh => 'Muy alto';

  @override
  String get verDetailScoreAcceptable => 'Aceptable';

  @override
  String get verDetailScoreLow => 'Bajo';

  @override
  String get verDetailScoreInsufficient => 'Insuficiente';

  @override
  String get verDetailScoreMatchLabel => 'Match cara vs. ID presentado';

  @override
  String get publicProfileVerifiedFacetec => 'Identidad verificada con FaceTec';

  @override
  String publicProfileAge(int age) {
    return '$age años';
  }

  @override
  String get publicProfileIdLabel => 'Identificación oficial';

  @override
  String get publicProfileIdDesc => 'Documento escaneado durante el registro';

  @override
  String get publicProfileScoreHigh => 'Alta coincidencia';

  @override
  String get publicProfileScoreMedium => 'Coincidencia media';

  @override
  String get publicProfileScoreLow => 'Coincidencia baja';

  @override
  String get publicProfileFacetecTitle => 'FaceTec ID Match';

  @override
  String get publicProfileFacetecDesc =>
      'Score de coincidencia cara vs. ID al registrarse';

  @override
  String publicProfileScoreLabelFull(String label, int score) {
    return '$label — $score/100';
  }

  @override
  String get publicProfileRequestSentSnack =>
      'Solicitud de verificación enviada';

  @override
  String get publicProfileButtonSent => 'Solicitud enviada';

  @override
  String get publicProfileButtonSend => 'Enviar solicitud de verificación';

  @override
  String get livenessMockInstruction1 => 'Mantén el teléfono frente a tu cara';

  @override
  String get livenessMockInstruction2 => 'Gira lentamente hacia la derecha';

  @override
  String get livenessMockInstruction3 => 'Regresa al centro';

  @override
  String get livenessMockInstruction4 => 'Gira lentamente hacia la izquierda';

  @override
  String get livenessMockInstruction5 => 'Mira directamente a la cámara';

  @override
  String get livenessMockCompleted => 'Completado';

  @override
  String get loginEmailLabel => 'Correo electrónico';

  @override
  String get loginEmailHint => 'tu@email.com';

  @override
  String get setPasswordLabel => 'Contraseña';

  @override
  String get setPasswordHint => 'Mínimo 8 caracteres';

  @override
  String get setPasswordButton => 'Crear cuenta';

  @override
  String get setPasswordMismatch => 'Las contraseñas no coinciden';

  @override
  String get setPasswordTooShort => 'Mínimo 8 caracteres';

  @override
  String get publicProfileLoadError => 'No se pudo cargar el perfil';

  @override
  String get permWelcomeTitle => 'Bienvenido a VerifiA';

  @override
  String get permWelcomeBody =>
      'Para ofrecerte la mejor experiencia de verificación de identidad, necesitamos configurar algunos permisos en tu dispositivo.';

  @override
  String get permNetworkTitle => 'Acceso a la red';

  @override
  String get permNetworkBody =>
      'VerifiA necesita conectarse a internet para emitir y validar badges de presencia en tiempo real de forma segura.';

  @override
  String get permCameraTitle => 'Acceso a la cámara';

  @override
  String get permCameraBody =>
      'VerifiA usa tu cámara para escanear códigos QR de verificadores y para capturar tu selfie durante el proceso de detección de presencia.';

  @override
  String get permFaceIdTitle => 'Autenticación con Face ID';

  @override
  String get permFaceIdBody =>
      'Face ID confirma tu identidad antes de cada verificación. Tus datos biométricos nunca salen de tu dispositivo.';

  @override
  String get permDoneTitle => '¡Todo listo!';

  @override
  String get permDoneBody =>
      'Los permisos están configurados. Ahora crea tu perfil de identidad verificada.';

  @override
  String get permCtaBegin => 'Comenzar';

  @override
  String get permCtaUnderstood => 'Entendido';

  @override
  String get permCtaCamera => 'Permitir acceso a la cámara';

  @override
  String get permCtaFaceId => 'Configurar Face ID';

  @override
  String get permCtaContinue => 'Continuar';

  @override
  String get permSkip => 'Ahora no';

  @override
  String get permNotificationsTitle => 'Notificaciones push';

  @override
  String get permNotificationsBody =>
      'VerifiA te avisa cuando llega una solicitud de verificación, cuando alguien completa la tuya o si una es rechazada o cancelada.';

  @override
  String get permCtaNotifications => 'Activar notificaciones';

  @override
  String get permDoneChecklist => 'Estado de permisos';

  @override
  String get permCheckNetwork => 'Acceso a internet';

  @override
  String get permCheckNotifications => 'Notificaciones push';

  @override
  String get permCheckCamera => 'Cámara';

  @override
  String get permCheckFaceId => 'Face ID / Biometría';

  @override
  String get permRetryButton => 'Reintentar';

  @override
  String get permOpenSettings => 'Abrir ajustes';

  @override
  String get permDoneBodyBlocked => 'Activa todos los permisos para continuar.';

  @override
  String get scannerAllowCamera => 'Permitir cámara';

  @override
  String get scannerOpenSettings => 'Abrir ajustes';

  @override
  String get verificationDetailCompleted => 'Verificación completada';

  @override
  String get verificationDetailUser => 'Usuario';

  @override
  String get verificationDetailRequestSent => 'Solicitud enviada';

  @override
  String get verificationDetailVerifiedOn => 'Verificado el';

  @override
  String get verificationDetailIdType => 'Tipo de ID';

  @override
  String get verificationDetailBiometricScore => 'Puntuación biométrica';

  @override
  String get verificationDetailVerifySelfie => 'Selfie de verificación';

  @override
  String get verificationDetailIdPresented => 'Identificación presentada';

  @override
  String get verificationDetailSelfieLabel => 'Foto de registro';

  @override
  String get verificationDetailScoreUnavailable => 'No disponible';

  @override
  String get verificationDetailScoreUnavailableDesc =>
      'El match FaceTec no generó puntuación en esta sesión (modo desarrollo o SDK no configurado).';

  @override
  String get verificationDetailScoreCaption => 'Match cara vs. ID presentado';

  @override
  String get scoreExcellent => 'Excelente';

  @override
  String get scoreVeryHigh => 'Muy alto';

  @override
  String get scoreAcceptable => 'Aceptable';

  @override
  String get scoreLow => 'Bajo';

  @override
  String get scoreInsufficient => 'Insuficiente';

  @override
  String get receiptTitle => 'Constancia de verificación';

  @override
  String get receiptStatusValid => 'Verificación auténtica';

  @override
  String get receiptStatusValidDesc =>
      'Esta constancia es genuina y está vigente.';

  @override
  String get receiptStatusExpired => 'La constancia venció';

  @override
  String get receiptStatusExpiredDesc =>
      'La verificación sí ocurrió; solo venció el registro de 30 días. No es señal de fraude.';

  @override
  String get receiptStatusInvalid => 'No se pudo verificar';

  @override
  String get receiptStatusInvalidDesc =>
      'La firma no es válida. Este código pudo haber sido manipulado o falsificado.';

  @override
  String get receiptStatusMalformed => 'Código no reconocido';

  @override
  String get receiptStatusMalformedDesc =>
      'Esto no parece una constancia de VerifiA.';

  @override
  String get receiptStatusNotFound => 'Constancia no encontrada';

  @override
  String get receiptStatusNotFoundDesc =>
      'No encontramos esta constancia en el servidor.';

  @override
  String get receiptOfflineNote =>
      'Verificado sin conexión. No se pudo confirmar con el servidor.';

  @override
  String get receiptSubjectLabel => 'Persona verificada';

  @override
  String get receiptVerifiedAtLabel => 'Verificado el';

  @override
  String get receiptValidityLabel => 'Validez de la insignia';

  @override
  String get receiptIdentityTitle => 'Identidad verificada';

  @override
  String get receiptScoreTitle => 'Coincidencia biométrica';

  @override
  String get receiptSelfieLabel => 'Selfie de liveness';

  @override
  String get receiptIdLabel => 'Identificación';

  @override
  String get receiptScanMe => 'Muéstralo para que lo escaneen';

  @override
  String get receiptShareQr => 'Compartir';

  @override
  String get receiptPasteButton => 'Pegar constancia';

  @override
  String get receiptPasteEmpty =>
      'No se encontró una constancia válida en el portapapeles.';

  @override
  String get inboxHistoryTitle => 'Historial';

  @override
  String get inboxHistoryEmpty => 'Aún no tienes verificaciones completadas.';

  @override
  String get inboxHistoryViewTicket => 'Ver constancia';
}
