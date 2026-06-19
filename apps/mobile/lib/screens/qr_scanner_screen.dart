import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import 'presence_challenge_screen.dart';

/// QR scanner screen — entry point of the holder flow.
/// Scans a verifia://badge?nonce=... QR code from the verifier portal.
/// This widget is mounted only while tab 0 is active; navigating away
/// unmounts it and fully releases the camera session via dispose().
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _processing = false;

  /// Null while the initial permission check is in flight.
  PermissionStatus? _cameraStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _controller.addListener(_onControllerChanged);
    _checkPermission();
  }

  /// Checks the current camera permission status and updates state.
  /// Starts the scanner automatically when granted.
  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() => _cameraStatus = status);
    if (status.isGranted && !_controller.value.isRunning) {
      unawaited(_controller.start());
    }
  }

  /// Requests camera permission from the OS (for the `denied` state).
  /// If the user grants it, starts the scanner immediately.
  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraStatus = status);
    if (status.isGranted && !_controller.value.isRunning) {
      unawaited(_controller.start());
    }
  }

  /// Opens the app's Settings page (for `permanentlyDenied` / `restricted`).
  Future<void> _openSettings() => openAppSettings();

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _safeStart() {
    if (!_controller.value.isRunning) {
      unawaited(_controller.start());
    }
  }

  void _safeStop() {
    if (_controller.value.isRunning) {
      unawaited(_controller.stop());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_processing) {
      // Re-check permission every time the user returns (e.g. from Settings).
      _checkPermission();
    } else if (state == AppLifecycleState.inactive) {
      _safeStop();
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_processing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final rawValue = barcode.rawValue;
    if (rawValue == null) return;

    final qrData = _extractQRData(rawValue);
    if (qrData == null) return;

    setState(() => _processing = true);
    _safeStop();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PresenceChallengeScreen(
              nonce: qrData.nonce,
              verifierId: qrData.verifierId,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          setState(() => _processing = false);
          _safeStart();
        });
  }

  /// Parses nonce and verifier_id from verifia://badge?nonce=<hex64>&verifier=<id>
  ({String nonce, String verifierId})? _extractQRData(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'verifia' || uri.host != 'badge') return null;
      final nonce = uri.queryParameters['nonce'];
      if (nonce == null || nonce.length != 64) return null;
      final verifierId = uri.queryParameters['verifier'] ?? 'Verificador';
      return (nonce: nonce, verifierId: verifierId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Waiting for the initial permission status check.
    if (_cameraStatus == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    // Permission not granted — show appropriate action button.
    if (!_cameraStatus!.isGranted) {
      final isPermanent = _cameraStatus == PermissionStatus.permanentlyDenied ||
          _cameraStatus == PermissionStatus.restricted;
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: _buildMessage(
          icon: Icons.no_photography_outlined,
          title: l10n.scannerPermissionTitle,
          subtitle: l10n.scannerPermissionSubtitle,
          actionLabel:
              isPermanent ? l10n.scannerOpenSettings : l10n.scannerAllowCamera,
          onAction: isPermanent ? _openSettings : _requestPermission,
        ),
      );
    }

    // Permission granted — show the live scanner.
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Keep this widget stable — rebuilding it breaks the camera texture.
          MobileScanner(
            key: const ValueKey('verifia_mobile_scanner'),
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error) => _buildMessage(
              icon: Icons.videocam_off_outlined,
              title: l10n.scannerCameraError,
              subtitle: error.errorDetails?.message ?? error.errorCode.message,
              actionLabel: l10n.retry,
              onAction: () {
                _safeStop();
                Future.delayed(const Duration(milliseconds: 300), _safeStart);
              },
            ),
            placeholderBuilder: (context) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  const SizedBox(height: 16),
                  Text(l10n.scannerStarting),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6C63FF), width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Text(
                l10n.scannerInstruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return ColoredBox(
      color: const Color(0xFF121212),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
