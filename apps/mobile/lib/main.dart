import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/onboarding_screen.dart';
import 'screens/presence_challenge_screen.dart';
import 'screens/home_screen.dart';
import 'services/app_attest_service.dart' show AppAttestService;
import 'services/api_service.dart';

// Global navigator key so deep link handler can push routes from outside widget tree
final _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const skipAttest = bool.fromEnvironment('VERIFIA_SKIP_ATTEST', defaultValue: false);
  if (!skipAttest) unawaited(_initAppAttest());

  runApp(const VerifiAApp());
}

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
  Widget _home = const HomeScreen();

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

    final registered = await storage.read(key: 'profile_registered');
    if (!mounted) return;
    if (registered != 'true') {
      setState(() => _home = const OnboardingScreen());
    }
    // If registered, HomeScreen handles showing login if session is missing
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: _home,
    );
  }
}
