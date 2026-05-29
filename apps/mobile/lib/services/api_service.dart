import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'passkey_service.dart';

// Backend URL — set via --dart-define or defaults to local dev
const _baseUrl = String.fromEnvironment(
  'VERIFIA_API_URL',
  defaultValue: 'http://localhost:3001',
);

class IssueTokenResponse {
  final String token;
  final int expiresIn;
  final String expiresAt;
  final Map<String, dynamic> badgeDisplay;

  const IssueTokenResponse({
    required this.token,
    required this.expiresIn,
    required this.expiresAt,
    required this.badgeDisplay,
  });

  factory IssueTokenResponse.fromJson(Map<String, dynamic> json) => IssueTokenResponse(
        token: json['token'] as String,
        expiresIn: json['expires_in'] as int,
        expiresAt: json['expires_at'] as String,
        badgeDisplay: json['badge_display'] as Map<String, dynamic>,
      );
}

/// HTTP client for all VerifiA API calls.
/// Uses Dio with retry interceptor and structured error handling.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  /// Fetch a one-time registration challenge for App Attest key attestation.
  /// Returns the 32-byte hex nonce.
  Future<String> fetchAttestChallenge() async {
    try {
      final response = await _dio.get('/api/v1/app-attest/challenge');
      return (response.data as Map<String, dynamic>)['challenge'] as String;
    } on DioException catch (e) {
      throw _handleDioError(e, 'fetchAttestChallenge');
    }
  }

  /// Register an App Attest attestation object with the backend.
  Future<Map<String, dynamic>> registerAppAttest({
    required String attestationObject,
    required String clientDataJson,
    required String challenge,
  }) async {
    try {
      final response = await _dio.post('/api/v1/app-attest/register', data: {
        'attestation_object': attestationObject,
        'client_data_json': clientDataJson,
        'challenge': challenge,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'registerAppAttest');
    }
  }

  /// Issue a badge token after completing all three verification steps.
  Future<IssueTokenResponse> issueToken({
    required String nonce,
    required String appAttestAssertion,
    required String deviceId,
    required String facetecSessionId,
    required PasskeyAssertionPayload passkeyAssertion,
    String? facetecFaceScan,
    String? facetecAuditTrailImage,
  }) async {
    try {
      final response = await _dio.post('/api/v1/tokens/issue', data: {
        'nonce': nonce,
        'app_attest_assertion': appAttestAssertion,
        'device_id': deviceId,
        'facetec_session_id': facetecSessionId,
        if (facetecFaceScan != null) 'facetec_face_scan': facetecFaceScan,
        if (facetecAuditTrailImage != null) 'facetec_audit_trail_image': facetecAuditTrailImage,
        'passkey_assertion': passkeyAssertion.toJson(),
      });
      return IssueTokenResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'issueToken');
    }
  }

  /// Fetch FIDO2 registration options (challenge + RP config) for a given user.
  Future<Map<String, dynamic>> getPasskeyRegistrationOptions({
    required String userId,
  }) async {
    try {
      final response = await _dio.post('/api/v1/passkeys/register/options', data: {
        'user_id': userId,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'getPasskeyRegistrationOptions');
    }
  }

  /// Verify passkey registration response with the backend.
  Future<void> verifyPasskeyRegistration({
    required String userId,
    required Map<String, dynamic> response,
  }) async {
    try {
      await _dio.post('/api/v1/passkeys/register/verify', data: {
        'user_id': userId,
        'response': response,
      });
    } on DioException catch (e) {
      throw _handleDioError(e, 'verifyPasskeyRegistration');
    }
  }

  Exception _handleDioError(DioException e, String method) {
    if (e.response != null) {
      final data = e.response!.data;
      final message =
          (data is Map) ? (data['error'] ?? 'Error del servidor') : e.message;
      final code = (data is Map) ? data['code'] : null;
      debugPrint(
          '[ApiService] $method error ${e.response!.statusCode}: $message (code: $code)');
      return Exception('[$code] $message');
    }
    // Network-level error — no response received
    final type = e.type;
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      debugPrint('[ApiService] $method timeout');
      return Exception('Network error: timeout connecting to server');
    }
    if (type == DioExceptionType.connectionError) {
      debugPrint('[ApiService] $method connection error: ${e.message}');
      return Exception('Network error: no connection to server');
    }
    debugPrint('[ApiService] $method network error: ${e.message}');
    return Exception('Network error: ${e.message}');
  }
}
