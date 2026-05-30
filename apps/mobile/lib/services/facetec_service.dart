import 'package:flutter/services.dart';

/// Result from a FaceTec liveness session.
class FaceTecResult {
  final String sessionId;
  final String faceScanBase64;
  final String? auditTrailImageBase64;

  const FaceTecResult({
    required this.sessionId,
    required this.faceScanBase64,
    this.auditTrailImageBase64,
  });
}

/// FaceTec 3D liveness service — bridges to the native FaceTecChannel.swift.
///
/// The native side (FaceTecChannel.swift) initializes the FaceTecSDK, obtains
/// a session token from the FaceTec dev server, presents the native 3D liveness
/// VC, and returns the face scan data when the user completes the challenge.
class FaceTecService {
  static const _channel = MethodChannel('verifia/facetec');

  /// Run a 3D liveness session and return the encrypted FaceScan data.
  ///
  /// Throws [PlatformException] if the session is cancelled or fails.
  Future<FaceTecResult> runLivenessSession({required String nonce}) async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('startLiveness', {'nonce': nonce});

    return FaceTecResult(
      sessionId: result['sessionId'] as String? ?? '',
      faceScanBase64: result['faceScanBase64'] as String? ?? '',
      auditTrailImageBase64: result['auditTrailImage'] as String?,
    );
  }
}
