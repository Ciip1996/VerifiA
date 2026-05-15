import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'presence_challenge_screen.dart';

/// QR scanner screen — entry point of the holder flow.
/// Scans a verifia://badge?nonce=... QR code from the verifier portal.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );
  bool _processing = false;

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_processing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final rawValue = barcode.rawValue;
    if (rawValue == null) return;

    final nonce = _extractNonce(rawValue);
    if (nonce == null) return;

    setState(() => _processing = true);
    _controller.stop();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PresenceChallengeScreen(nonce: nonce),
          ),
        )
        .then((_) {
          // Reset when coming back
          setState(() => _processing = false);
          _controller.start();
        });
  }

  /// Extracts nonce from verifia://badge?nonce=<hex64>
  String? _extractNonce(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'verifia' || uri.host != 'badge') return null;
      final nonce = uri.queryParameters['nonce'];
      if (nonce == null || nonce.length != 64) return null;
      return nonce;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'VerifiA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),
          // Overlay with scan frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6C63FF), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'Escanea el QR del verificador',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
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
}
