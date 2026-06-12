import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'passkey_service.dart';

// Backend URL — set via --dart-define or defaults to local dev
const _baseUrl = String.fromEnvironment(
  'VERIFIA_API_URL',
  defaultValue: 'http://localhost:3001',
);

/// Thrown for all network-level failures (no response received).
/// [isNetwork] is true when the server was unreachable (timeout, no route).
class NetworkException implements Exception {
  final String message;
  final bool isNetwork;
  const NetworkException(this.message, {this.isNetwork = false});
  @override
  String toString() => message;
}

/// Top-level helper — maps any thrown object to a user-friendly Spanish string.
/// Import this wherever raw error strings are shown to the user.
String friendlyError(Object e) {
  if (e is NetworkException) return e.message;
  final s = e.toString().replaceFirst('Exception: ', '');
  final lower = s.toLowerCase();
  if (lower.contains('timeout') || lower.contains('no connection') ||
      lower.contains('network') || lower.contains('connection')) {
    return 'Sin conexión. Verifica tu red e intenta de nuevo.';
  }
  return s;
}

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

class AccountProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? idType;
  final String? profilePhoto;
  final String? curp;
  final String? dateOfBirth;

  const AccountProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.idType,
    this.profilePhoto,
    this.curp,
    this.dateOfBirth,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        idType: json['id_type'] as String?,
        profilePhoto: json['profile_photo'] as String?,
        curp: json['curp'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
      );
}

class PublicAccountSummary {
  final String id;
  final String email;
  final String fullName;
  final String? profilePhoto;
  final String? idType;
  final String? dateOfBirth;
  final int? facetecMatchLevel;
  final bool isSelf;

  const PublicAccountSummary({
    required this.id,
    required this.email,
    required this.fullName,
    this.profilePhoto,
    this.idType,
    this.dateOfBirth,
    this.facetecMatchLevel,
    this.isSelf = false,
  });

  factory PublicAccountSummary.fromJson(Map<String, dynamic> json) =>
      PublicAccountSummary(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        profilePhoto: json['profile_photo'] as String?,
        idType: json['id_type'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        facetecMatchLevel: json['facetec_match_level'] as int?,
        isSelf: json['is_self'] as bool? ?? false,
      );
}

class PublicAccountProfile {
  final String id;
  final String email;
  final String fullName;
  final String? dateOfBirth;
  final String? idType;
  final String profilePhoto;
  final String idFrontPhoto;
  final int? facetecMatchLevel;

  const PublicAccountProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.dateOfBirth,
    this.idType,
    required this.profilePhoto,
    required this.idFrontPhoto,
    this.facetecMatchLevel,
  });

  factory PublicAccountProfile.fromJson(Map<String, dynamic> json) =>
      PublicAccountProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        dateOfBirth: json['date_of_birth'] as String?,
        idType: json['id_type'] as String?,
        profilePhoto: json['profile_photo'] as String? ?? '',
        idFrontPhoto: json['id_front_photo'] as String? ?? '',
        facetecMatchLevel: json['facetec_match_level'] as int?,
      );
}

class SentChallenge {
  final String nonce;
  final String status;
  final String? targetEmail;
  final String createdAt;
  final String expiresAt;
  // Subject (person who responded to the challenge)
  final String? subjectFullName;
  final String? subjectPhoto;
  final String? subjectIdType;
  final String? subjectIdFrontPhoto;
  // Token (verification result)
  final String? validatedAt;
  final int? livenessMatchScore;
  final String? livenessSnapshot;

  const SentChallenge({
    required this.nonce,
    required this.status,
    this.targetEmail,
    required this.createdAt,
    required this.expiresAt,
    this.subjectFullName,
    this.subjectPhoto,
    this.subjectIdType,
    this.subjectIdFrontPhoto,
    this.validatedAt,
    this.livenessMatchScore,
    this.livenessSnapshot,
  });

  factory SentChallenge.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as Map<String, dynamic>?;
    final token = json['token'] as Map<String, dynamic>?;
    return SentChallenge(
      nonce: json['nonce'] as String,
      status: json['status'] as String,
      targetEmail: json['target_email'] as String?,
      createdAt: json['created_at'] as String,
      expiresAt: json['expires_at'] as String,
      subjectFullName: subject?['full_name'] as String?,
      subjectPhoto: subject?['profile_photo'] as String?,
      subjectIdType: subject?['id_type'] as String?,
      subjectIdFrontPhoto: subject?['id_front_photo'] as String?,
      validatedAt: token?['validated_at'] as String?,
      livenessMatchScore: (token?['liveness_match_score'] as num?)?.toInt(),
      livenessSnapshot: token?['liveness_snapshot'] as String?,
    );
  }
}

class IncomingChallenge {
  final String nonce;
  final String verifierId;
  final String createdAt;
  final String expiresAt;
  final String? requesterEmail;
  final String? requesterFullName;
  final String? requesterProfilePhoto;

  const IncomingChallenge({
    required this.nonce,
    required this.verifierId,
    required this.createdAt,
    required this.expiresAt,
    this.requesterEmail,
    this.requesterFullName,
    this.requesterProfilePhoto,
  });

  factory IncomingChallenge.fromJson(Map<String, dynamic> json) {
    final req = json['requester'] as Map<String, dynamic>?;
    return IncomingChallenge(
      nonce: json['nonce'] as String,
      verifierId: json['verifier_id'] as String,
      createdAt: json['created_at'] as String,
      expiresAt: json['expires_at'] as String,
      requesterEmail: req?['email'] as String?,
      requesterFullName: req?['full_name'] as String?,
      requesterProfilePhoto: req?['profile_photo'] as String?,
    );
  }
}

/// HTTP client for all VerifiA API calls.
/// Uses Dio with retry interceptor and structured error handling.
class ApiService {
  late final Dio _dio;
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'account_session_token';

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

    // Inject session token from storage before each request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _sessionKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
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

  static Future<String?> getSessionToken() => _storage.read(key: _sessionKey);
  static Future<void> clearSession() => _storage.delete(key: _sessionKey);

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
    int? livenessMatchScore,
  }) async {
    try {
      final response = await _dio.post('/api/v1/tokens/issue', data: {
        'nonce': nonce,
        'app_attest_assertion': appAttestAssertion,
        'device_id': deviceId,
        'facetec_session_id': facetecSessionId,
        if (facetecFaceScan != null) 'facetec_face_scan': facetecFaceScan,
        if (facetecAuditTrailImage != null) 'facetec_audit_trail_image': facetecAuditTrailImage,
        if (livenessMatchScore != null) 'liveness_match_score': livenessMatchScore,
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

  /// Register a user identity profile after FaceTec Photo ID Match.
  /// Stores OCR data, photos, match score, and enrollment ID in the backend.
  Future<void> registerProfile({
    required String deviceId,
    required String fullName,
    required String idType,
    required String profilePhoto,
    required String idFrontPhoto,
    String? curp,
    String? dateOfBirth,
    String? idBackPhoto,
    int? facetecMatchLevel,
    String? enrollmentRefId,
  }) async {
    try {
      await _dio.post('/api/v1/profile/register', data: {
        'device_id': deviceId,
        'full_name': fullName,
        'id_type': idType,
        'profile_photo': profilePhoto,
        'id_front_photo': idFrontPhoto,
        if (curp != null) 'curp': curp,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (idBackPhoto != null) 'id_back_photo': idBackPhoto,
        if (facetecMatchLevel != null) 'facetec_match_level': facetecMatchLevel,
        if (enrollmentRefId != null && enrollmentRefId.isNotEmpty)
          'enrollment_ref_id': enrollmentRefId,
      });
    } on DioException catch (e) {
      throw _handleDioError(e, 'registerProfile');
    }
  }

  /// Set account password after onboarding. Creates identity-linked web account.
  Future<Map<String, dynamic>> setPassword({
    required String deviceId,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/set-password', data: {
        'device_id': deviceId,
        'email': email,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      // Persist session token
      if (data['session_token'] != null) {
        await _storage.write(key: _sessionKey, value: data['session_token'] as String);
      }
      return data;
    } on DioException catch (e) {
      throw _handleDioError(e, 'setPassword');
    }
  }

  /// Login with email + password. Returns account profile.
  Future<AccountProfile> loginAccount({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = response.data as Map<String, dynamic>;
      if (data['session_token'] != null) {
        await _storage.write(key: _sessionKey, value: data['session_token'] as String);
      }
      return AccountProfile.fromJson(data['account'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'loginAccount');
    }
  }

  /// Fetch the authenticated account's full profile from the backend.
  Future<AccountProfile> fetchMe() async {
    try {
      final response = await _dio.get('/api/v1/auth/me');
      return AccountProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'fetchMe');
    }
  }

  /// Create a new verification challenge (QR code) from the mobile app.
  Future<Map<String, dynamic>> createChallenge({String? targetEmail}) async {
    try {
      // Use account email as verifier_id when available
      final token = await _storage.read(key: _sessionKey);
      final storedAccount = await _storage.read(key: 'verifia_account_email');
      final verifierId = storedAccount ?? 'mobile-user';
      final response = await _dio.post('/api/v1/challenges', data: {
        'verifier_id': verifierId,
        if (targetEmail != null && targetEmail.isNotEmpty) 'target_email': targetEmail,
      }, options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      ));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'createChallenge');
    }
  }

  /// Send an invitation email to a non-registered address via Resend.
  Future<void> sendInvite({required String nonce, required String email}) async {
    try {
      await _dio.post(
        '/api/v1/challenges/send-invite',
        data: {'nonce': nonce, 'email': email},
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'sendInvite');
    }
  }

  /// Search registered accounts by name or email (debounced by caller).
  Future<List<PublicAccountSummary>> searchAccounts(String query) async {
    try {
      final response = await _dio.get('/api/v1/accounts/search', queryParameters: {'q': query});
      final data = response.data as Map<String, dynamic>;
      return (data['results'] as List<dynamic>)
          .map((e) => PublicAccountSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'searchAccounts');
    }
  }

  /// Fetch the full public identity profile for a given account ID.
  Future<PublicAccountProfile> fetchPublicProfile(String accountId) async {
    try {
      final response = await _dio.get('/api/v1/accounts/$accountId/public-profile');
      return PublicAccountProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'fetchPublicProfile');
    }
  }

  /// Fetch challenges sent by the current account (history).
  Future<List<SentChallenge>> getSentChallenges() async {
    try {
      final response = await _dio.get('/api/v1/challenges/history');
      final data = response.data as Map<String, dynamic>;
      return (data['items'] as List<dynamic>)
          .map((e) => SentChallenge.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'getSentChallenges');
    }
  }

  /// Fetch challenges targeted at the current account's email.
  Future<List<IncomingChallenge>> getIncomingChallenges() async {
    try {
      final response = await _dio.get('/api/v1/challenges/incoming');
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((e) => IncomingChallenge.fromJson(e as Map<String, dynamic>))
          .toList();
      return items;
    } on DioException catch (e) {
      throw _handleDioError(e, 'getIncomingChallenges');
    }
  }

  /// Recipient rejects an incoming PENDING challenge targeted at their email.
  Future<void> rejectChallenge(String nonce) async {
    try {
      await _dio.patch('/api/v1/challenges/$nonce/reject');
    } on DioException catch (e) {
      throw _handleDioError(e, 'rejectChallenge');
    }
  }

  /// Sender cancels a PENDING challenge they created.
  Future<void> cancelChallenge(String nonce) async {
    try {
      await _dio.patch('/api/v1/challenges/$nonce/cancel');
    } on DioException catch (e) {
      throw _handleDioError(e, 'cancelChallenge');
    }
  }

  /// Marks a challenge as IN_PROGRESS when the recipient begins verification.
  /// Fire-and-forget: errors are swallowed by the caller.
  Future<void> startChallenge(String nonce) async {
    try {
      await _dio.patch('/api/v1/challenges/$nonce/start');
    } on DioException catch (e) {
      throw _handleDioError(e, 'startChallenge');
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
      return const NetworkException(
        'El servidor tardó demasiado en responder. Verifica tu conexión e intenta de nuevo.',
        isNetwork: true,
      );
    }
    if (type == DioExceptionType.connectionError) {
      debugPrint('[ApiService] $method connection error: ${e.message}');
      return const NetworkException(
        'No se pudo conectar al servidor. Verifica que estés en la misma red e intenta de nuevo.',
        isNetwork: true,
      );
    }
    debugPrint('[ApiService] $method network error: ${e.message}');
    return const NetworkException(
      'Error de red inesperado. Intenta de nuevo.',
      isNetwork: true,
    );
  }
}
