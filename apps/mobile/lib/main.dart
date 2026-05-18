import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/qr_scanner_screen.dart';
import 'services/app_attest_service.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Do not block first frame on App Attest / network setup.
  const skipAttest = bool.fromEnvironment('VERIFIA_SKIP_ATTEST', defaultValue: true);
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
    // Non-fatal — will be caught during token issuance
    debugPrint('[VerifiA] App Attest init warning: $e');
  }
}

class VerifiAApp extends StatelessWidget {
  const VerifiAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VerifiA',
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
