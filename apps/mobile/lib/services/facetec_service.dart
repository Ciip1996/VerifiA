import 'package:flutter/foundation.dart';

/// Result from a FaceTec liveness session.
class FaceTecResult {
  /// FaceTec session ID — sent to backend for server-side verification.
  final String sessionId;

  /// Base64-encoded encrypted FaceScan (3D mathematical representation).
  /// The video itself is never transmitted — only this encrypted blob.
  final String faceScanBase64;

  /// Audit trail image (low quality) for compliance logging.
  final String? auditTrailImageBase64;

  const FaceTecResult({
    required this.sessionId,
    required this.faceScanBase64,
    this.auditTrailImageBase64,
  });
}

// ─── FaceTec Flutter SDK integration notes ────────────────────────────────
//
// Prerequisites (Fase B):
//  1. Create Developer Account at https://dev.facetec.com (free)
//  2. Download Flutter SDK ZIP from the developer console
//  3. Unzip — you'll get:
//       FaceTec.xcframework            → copy to apps/mobile/ios/Frameworks/
//       facetec_flutter/               → Dart package (put in apps/mobile/packages/)
//       sample_app/                    → reference implementation
//  4. In apps/mobile/ios/Podfile add:
//       pod 'FaceTecSDK', :path => 'Frameworks'
//  5. In apps/mobile/pubspec.yaml add:
//       facetec_flutter:
//         path: packages/facetec_flutter
//  6. In Xcode: Runner target → General → Frameworks → "Embed & Sign" FaceTec.xcframework
//  7. In apps/backend/.env set FACETEC_DEVICE_KEY_IDENTIFIER and FACETEC_PUBLIC_FHD_KEY
//
// Once integrated, replace the stub _runRealSdkSession() implementation below.
//
// ─────────────────────────────────────────────────────────────────────────

/// FaceTec 3D liveness service.
///
/// When [_sdkAvailable] is false (SDK not wired), runLivenessSession() returns
/// a stub result so the rest of the flow continues for development.
class FaceTecService {
  bool _initialized = false;

  // Set to true once the real SDK is linked and initialized.
  static const bool _sdkAvailable = false;

  /// Initialize FaceTec SDK with developer credentials.
  Future<void> initialize() async {
    if (_initialized) return;

    if (_sdkAvailable) {
      // ── Real SDK init ──────────────────────────────────────────────────
      // Uncomment and fill in when SDK is linked:
      //
      // await FaceTecSDK.initializeInDevelopmentMode(
      //   deviceKeyIdentifier: const String.fromEnvironment('FACETEC_DEVICE_KEY'),
      //   publicFaceScanEncryptionKey: const String.fromEnvironment('FACETEC_PUBLIC_KEY'),
      // );
      //
      // OR for production:
      // await FaceTecSDK.initializeInProductionMode(
      //   productionKeyText: const String.fromEnvironment('FACETEC_PRODUCTION_KEY'),
      //   deviceKeyIdentifier: const String.fromEnvironment('FACETEC_DEVICE_KEY'),
      //   publicFaceScanEncryptionKey: const String.fromEnvironment('FACETEC_PUBLIC_KEY'),
      // );
    } else {
      debugPrint('[FaceTec] SDK not linked — running in stub mode');
    }

    _initialized = true;
  }

  /// Run a 3D liveness session.
  ///
  /// The nonce is embedded in the session to bind liveness to the specific
  /// badge request — prevents session replay.
  ///
  /// Returns a [FaceTecResult] with sessionId and encrypted FaceScan.
  Future<FaceTecResult> runLivenessSession({required String nonce}) async {
    await initialize();

    if (_sdkAvailable) {
      return _runRealSdkSession(nonce);
    }

    // Dev stub — returns deterministic fake data so backend dev-mode accepts it
    debugPrint('[FaceTec] Stub session for nonce ${nonce.substring(0, 8)}...');
    await Future.delayed(const Duration(seconds: 2));
    return FaceTecResult(
      sessionId: 'stub-session-${nonce.substring(0, 16)}',
      faceScanBase64: 'STUB_FACE_SCAN',
    );
  }

  /// Real FaceTec SDK session — wired once SDK is linked.
  ///
  /// VerifiAFaceTecProcessor handles the upload-and-verify handshake:
  ///   processSessionResultWhileFaceTecIsInForeground → POST /api/v1/tokens/issue
  ///   (see FaceTec server-side API guide for the full processor pattern)
  Future<FaceTecResult> _runRealSdkSession(String nonce) async {
    // ── Replace with real SDK call ─────────────────────────────────────
    //
    // final processor = VerifiAFaceTecProcessor(nonce: nonce);
    // await FaceTecSDK.startSession(processor);
    // final result = await processor.resultCompleter.future;
    //
    // return FaceTecResult(
    //   sessionId: result.sessionId,
    //   faceScanBase64: result.faceScan,
    //   auditTrailImageBase64: result.auditTrailImage,
    // );
    //
    // ─────────────────────────────────────────────────────────────────
    throw UnimplementedError('FaceTec SDK not yet linked — set _sdkAvailable = true');
  }
}
