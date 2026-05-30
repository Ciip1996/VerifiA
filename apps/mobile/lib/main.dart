import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'screens/presence_challenge_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'services/app_attest_service.dart';
import 'services/api_service.dart';

// Global navigator key so deep link handler can push routes from outside widget tree
final _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const skipAttest = bool.fromEnvironment('VERIFIA_SKIP_ATTEST', defaultValue: false);
  if (!skipAttest) {
    unawaited(_initAppAttest());
  }

  runApp(const VerifiAApp());
}

Future<void> _initAppAttest() async {
  final appAttest = AppAttestService();
  final api = ApiService();
  try {
    await appAttest.registerIfNeeded(api);
  } catch (e) {
    debugPrint('[VerifiA] App Attest init warning: $e');
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

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
      home: const QRScannerScreen(),
    );
  }
}
