import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permissions_wizard_screen.dart';
import 'screens/presence_challenge_screen.dart';
import 'services/app_attest_service.dart' show AppAttestService;
import 'services/api_service.dart';
// Global navigator key so deep link handler can push routes from outside widget tree
final _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const VerifiAApp());
}

// ignore: unused_element
Future<void> _initAppAttest() async {
  const storage = FlutterSecureStorage();
  final appAttest = AppAttestService();
  final api = ApiService();
  try {
    await appAttest.registerIfNeeded(api);
  } catch (e) {
    debugPrint('[VerifiA] App Attest init warning: $e');
    // If registration fails (e.g. stale key from previous install), reset profile flag
    // so the user is directed to onboarding on next launch.
    await storage.delete(key: 'profile_registered');
  }
}

// Parses verifia://badge?nonce=<hex64>&verifier=<id> and pushes PresenceChallengeScreen
void _handleDeepLink(Uri uri) {
  if (uri.scheme != 'verifia' || uri.host != 'badge') return;
  final nonce = uri.queryParameters['nonce'];
  if (nonce == null || nonce.length != 64) return;
  final verifierId = uri.queryParameters['verifier'] ?? 'Verificador';

  final navigator = _navigatorKey.currentState;
  if (navigator == null) return;

  // Pop back to root (QRScannerScreen) then push the challenge screen
  navigator.popUntil((route) => route.isFirst);
  navigator.push(
    MaterialPageRoute(
      builder: (_) => PresenceChallengeScreen(
        nonce: nonce,
        verifierId: verifierId,
      ),
    ),
  );
}

class VerifiAApp extends StatefulWidget {
  const VerifiAApp({super.key});

  @override
  State<VerifiAApp> createState() => _VerifiAAppState();
}

class _VerifiAAppState extends State<VerifiAApp> {
  StreamSubscription<Uri>? _linkSub;
  Widget _home = const _SplashPlaceholder();

  static const bool _skipAttest =
      bool.fromEnvironment('VERIFIA_SKIP_ATTEST', defaultValue: false);

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _resolveHome();
  }

  Future<void> _resolveHome() async {
    const storage = FlutterSecureStorage();

    if (_skipAttest) {
      final storedDeviceId = await storage.read(key: 'verifia_device_id');
      if (storedDeviceId != null) {
        // Stale real-attest keys present — clear so onboarding runs fresh
        await storage.delete(key: 'profile_registered');
        await storage.delete(key: 'verifia_device_id');
        await storage.delete(key: 'verifia_app_attest_key_id');
      }
    }

    // Allow resetting the wizard for testing via dart-define
    const resetWizard = bool.fromEnvironment('VERIFIA_RESET_WIZARD', defaultValue: false);
    if (resetWizard) {
      await storage.delete(key: 'permissions_wizard_done');
    }

    // Detect fresh install: Documents dir is cleared on uninstall, but the
    // Keychain is not. If the marker file is absent, treat this as a new
    // install — clear the wizard-done flag AND any leftover account state
    // (profile_registered, session token, cached email/id) so a reinstall
    // never skips onboarding/login using stale Keychain data from a
    // previous install.
    final docsDir = await getApplicationDocumentsDirectory();
    final installMarker = File('${docsDir.path}/.install_marker');
    if (!await installMarker.exists()) {
      await storage.delete(key: 'permissions_wizard_done');
      await storage.delete(key: 'profile_registered');
      await storage.delete(key: 'verifia_account_email');
      await storage.delete(key: 'verifia_account_id');
      await ApiService.clearSession();
      await installMarker.create(recursive: true);
    }

    // Show permissions wizard on first launch before anything else
    final wizardDone = await storage.read(key: 'permissions_wizard_done');
    if (wizardDone != 'true') {
      if (!mounted) return;
      setState(() => _home = const PermissionsWizardScreen());
      return;
    }

    final registered = await storage.read(key: 'profile_registered');
    if (!mounted) return;
    if (registered != 'true') {
      setState(() => _home = const OnboardingScreen());
      return;
    }

    // Even if profile_registered is set, the session token may be missing,
    // expired, or issued against a different backend/environment. Validate
    // it against the backend before routing into HomeScreen — otherwise the
    // user lands on tabs (profile, search) that immediately fail with
    // "Invalid or expired session token".
    final sessionToken = await ApiService.getSessionToken();
    if (sessionToken == null) {
      setState(() => _home = const LoginScreen());
      return;
    }

    try {
      await ApiService().fetchMe();
      if (!mounted) return;
      setState(() => _home = const HomeScreen());
    } catch (e) {
      if (!mounted) return;
      if (ApiService.isUnauthorized(e)) {
        setState(() => _home = const LoginScreen());
      } else {
        // Network/transient error — don't lock the user out while offline.
        setState(() => _home = const HomeScreen());
      }
    }
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // Cold start: app was closed and opened via deep link
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        // Delay until navigator is ready
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink(initial));
      }
    } catch (e) {
      debugPrint('[VerifiA] Deep link init error: $e');
    }

    // Hot: app already open, new link arrives (e.g. user taps another link)
    _linkSub = appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) => debugPrint('[VerifiA] Deep link stream error: $e'),
    );
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VerifiA',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      theme: _buildTheme(),
      darkTheme: _buildTheme(),
      themeMode: ThemeMode.dark,
      home: _home,
    );
  }
}

// ─── Design system ────────────────────────────────────────────────────────────

// Brand tokens
const _colorPrimary   = Color(0xFF06142A); // dark navy — surfaces
const _colorSecondary = Color(0xFF00EAF2); // cyan — primary accent / CTAs
const _colorTertiary  = Color(0xFF147BFF); // blue — secondary accent
const _colorNeutral   = Color(0xFFF4F8FF); // near-white — body text
const _colorSurface   = Color(0xFF0D2040); // elevated surface
const _colorBg        = Color(0xFF020B1E); // page background

ThemeData _buildTheme() {
  const colorScheme = ColorScheme(
    brightness:      Brightness.dark,
    primary:         _colorSecondary,  // cyan — buttons, active states
    onPrimary:       _colorPrimary,
    secondary:       _colorTertiary,   // blue — chips, indicators
    onSecondary:     _colorNeutral,
    surface:         _colorSurface,
    onSurface:       _colorNeutral,
    error:           Color(0xFFEF4444),
    onError:         _colorNeutral,
    surfaceContainerHighest: _colorPrimary,
    surfaceContainer:        _colorPrimary,
  );

  final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

  final textTheme = baseTextTheme.copyWith(
    displayLarge:   GoogleFonts.hankenGrotesk(color: _colorNeutral, fontWeight: FontWeight.w700),
    displayMedium:  GoogleFonts.hankenGrotesk(color: _colorNeutral, fontWeight: FontWeight.w700),
    displaySmall:   GoogleFonts.hankenGrotesk(color: _colorNeutral, fontWeight: FontWeight.w600),
    headlineLarge:  GoogleFonts.hankenGrotesk(color: _colorNeutral, fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.hankenGrotesk(color: _colorNeutral, fontWeight: FontWeight.w600),
    headlineSmall:  GoogleFonts.hankenGrotesk(color: _colorNeutral, fontWeight: FontWeight.w500),
    labelSmall:     GoogleFonts.jetBrainsMono(color: _colorNeutral, fontSize: 11),
    labelMedium:    GoogleFonts.jetBrainsMono(color: _colorNeutral, fontSize: 12),
  );

  return ThemeData(
    useMaterial3:            true,
    colorScheme:             colorScheme,
    scaffoldBackgroundColor: _colorBg,
    textTheme:               textTheme,
    cardColor:               _colorSurface,
    dividerColor:            const Color(0xFF1E293B),
  );
}

// Blank screen shown while _resolveHome() is running.
// Prevents HomeScreen (and its camera-using widgets) from rendering
// before routing is determined, which would trigger premature permission dialogs.
class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF020B1E),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF00EAF2), strokeWidth: 2),
      ),
    );
  }
}
