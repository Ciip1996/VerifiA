import 'package:flutter/services.dart';

/// Result from a FaceTec 3D liveness session.
class FaceTecResult {
  final String sessionId;
  final String faceScanBase64;
  final String? auditTrailImageBase64;
  /// 3D-vs-3D match score (0–100) comparing live face to registration enrollment.
  /// Null if no enrollmentRefId was provided (user not yet registered).
  final int? livenessMatchScore;

  const FaceTecResult({
    required this.sessionId,
    required this.faceScanBase64,
    this.auditTrailImageBase64,
    this.livenessMatchScore,
  });
}

/// Result from a FaceTec Photo ID Match session.
class FaceTecIDMatchResult {
  final String sessionId;
  final String faceScanBase64;
  final String auditTrailImage;
  final String idFrontPhoto;
  final String? idBackPhoto;
  final String? fullName;
  final String? curp;
  final String? dateOfBirth;
  final int matchLevel;
  /// The externalDatabaseRefID used in /enrollment-3d (stored for later 3D-3D match at verification)
  final String enrollmentRefId;

  const FaceTecIDMatchResult({
    required this.sessionId,
    required this.faceScanBase64,
    required this.auditTrailImage,
    required this.idFrontPhoto,
    this.idBackPhoto,
    this.fullName,
    this.curp,
    this.dateOfBirth,
    required this.matchLevel,
    required this.enrollmentRefId,
  });
}

/// FaceTec 3D liveness service — bridges to the native FaceTecChannel.swift.
class FaceTecService {
  static const _channel = MethodChannel('verifia/facetec');

  /// Run a 3D liveness session and return the encrypted FaceScan data.
  ///
  /// Pass [enrollmentRefId] (from registration) to perform a 3D-3D match at
  /// verification. The score (0–100) is returned in [FaceTecResult.livenessMatchScore].
  Future<FaceTecResult> runLivenessSession({
    required String nonce,
    String? enrollmentRefId,
  }) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'startLiveness',
      {
        'nonce': nonce,
        if (enrollmentRefId != null) 'enrollmentRefId': enrollmentRefId,
      },
    );

    return FaceTecResult(
      sessionId: result['sessionId'] as String? ?? '',
      faceScanBase64: result['faceScanBase64'] as String? ?? '',
      auditTrailImageBase64: result['auditTrailImage'] as String?,
      livenessMatchScore: result['livenessMatchScore'] as int?,
    );
  }

  /// Run a Photo ID Match session (3D liveness + ID document scan + face match).
  ///
  /// [idType] must be 'INE' or 'PASSPORT'.
  /// Returns OCR data + photos + match score extracted by FaceTec.
  Future<FaceTecIDMatchResult> startIDMatch({required String idType}) async {
    final Map<dynamic, dynamic> result =
        await _channel.invokeMethod('startIDMatch', {'idType': idType});

    return FaceTecIDMatchResult(
      sessionId: result['sessionId'] as String? ?? '',
      faceScanBase64: result['faceScanBase64'] as String? ?? '',
      auditTrailImage: result['auditTrailImage'] as String? ?? '',
      idFrontPhoto: result['idFrontPhoto'] as String? ?? '',
      idBackPhoto: result['idBackPhoto'] as String?,
      fullName: result['fullName'] as String?,
      curp: result['curp'] as String?,
      dateOfBirth: result['dateOfBirth'] as String?,
      matchLevel: result['matchLevel'] as int? ?? 0,
      enrollmentRefId: result['enrollmentRefId'] as String? ?? '',
    );
  }
}
