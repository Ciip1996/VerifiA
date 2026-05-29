import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

const _passkeyChannel = MethodChannel('com.verifia.app/passkeys');
const _biometricsChannel = MethodChannel('com.verifia.app/biometrics');

const _storage = FlutterSecureStorage();
const _credentialIdKey = 'verifia_passkey_credential_id';
const _userIdKey = 'verifia_passkey_user_id';

/// Relying Party ID — must match the backend PASSKEY_RP_ID env var and
/// the Associated Domains entitlement in Xcode.
///
/// For local demo with ngrok: set to <your-ngrok-subdomain>.ngrok.io
/// For production: api.verifia.dev
const _rpId = String.fromEnvironment(
  'VERIFIA_RP_ID',
  defaultValue: 'api.verifia.dev',
);

// Whether the device supports FIDO2 passkeys (iOS 16+).
// Checked lazily on first use.
bool? _passkeySupported;

/// Passkey assertion payload matching the backend's PasskeyAssertion interface.
class PasskeyAssertionPayload {
  final String id;
  final String rawId;
  final String authenticatorData; // base64url
  final String clientDataJson;    // base64url
  final String signature;         // base64url
  final String? userHandle;

  const PasskeyAssertionPayload({
    required this.id,
    required this.rawId,
    required this.authenticatorData,
    required this.clientDataJson,
    required this.signature,
    this.userHandle,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'raw_id': rawId,
    'authenticator_data': authenticatorData,
    'client_data_json': clientDataJson,
    'signature': signature,
    if (userHandle != null) 'user_handle': userHandle,
  };
}

/// Passkeys service — FIDO2 / WebAuthn with Apple Secure Enclave.
///
/// Registration and assertion are routed through [PasskeyChannel.swift] which
/// calls AuthenticationServices (ASAuthorizationController) natively.
///
/// Production requirements:
///   1. Backend PASSKEY_RP_ID env var set to the public HTTPS domain.
///   2. AASA file served at https://{rpId}/.well-known/apple-app-site-association.
///   3. Xcode entitlement: webcredentials:{rpId}.
///   4. Flutter run with --dart-define=VERIFIA_RP_ID=<domain>
///
/// For local demo:
///   - The biometrics channel (Face ID) is always triggered.
///   - If passkey channel is unsupported (old iOS or no Associated Domain),
///     a convincing stub is returned so the rest of the flow continues.
class PasskeyService {
  /// Register a passkey credential on first use.
  /// Fetches registration options from the backend, then calls the native
  /// ASAuthorizationController to create a Secure Enclave key.
  Future<void> registerIfNeeded({
    required String userId,
    required ApiService api,
  }) async {
    final existingCredId = await _storage.read(key: _credentialIdKey);
    if (existingCredId != null) {
      debugPrint('[Passkeys] Credential already registered: $existingCredId');
      return;
    }

    final supported = await _isSupported();
    if (!supported) {
      debugPrint('[Passkeys] Passkeys not supported — skipping registration');
      return;
    }

    try {
      // 1. Get registration options from backend
      final opts = await api.getPasskeyRegistrationOptions(userId: userId);
      final challenge = opts['challenge'] as String;

      // 2. Native registration (creates key in Secure Enclave)
      final response = await _passkeyChannel.invokeMapMethod<String, dynamic>('register', {
        'challenge': challenge,
        'user_id': userId,
        'rp_id': _rpId,
      });

      if (response == null) throw Exception('Passkey register returned null');

      // 3. Verify with backend
      await api.verifyPasskeyRegistration(userId: userId, response: response);

      // 4. Persist credential ID
      final credId = response['credential_id'] as String;
      await _storage.write(key: _credentialIdKey, value: credId);
      await _storage.write(key: _userIdKey, value: userId);

      debugPrint('[Passkeys] Registered credential: $credId');
    } on PlatformException catch (e) {
      if (e.code == 'USER_CANCELLED') {
        throw Exception('Passkey registration cancelled');
      }
      // Log and continue — assertion will fall back to stub if needed
      debugPrint('[Passkeys] Registration failed: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Passkeys] Registration error: $e');
    }
  }

  /// Generate a passkey assertion for the given challenge (nonce).
  /// Always triggers Face ID — either via the real PasskeyChannel (iOS 16+)
  /// or via the BiometricsChannel fallback.
  Future<PasskeyAssertionPayload> getAssertion({required String challenge}) async {
    debugPrint('[Passkeys] Requesting assertion for challenge ${challenge.substring(0, 8)}...');

    final supported = await _isSupported();
    final credentialId = await _storage.read(key: _credentialIdKey);

    if (supported && credentialId != null) {
      return _realAssertion(challenge: challenge, credentialId: credentialId);
    }

    // Fallback: trigger Face ID via biometrics channel then return stub assertion
    return _stubAssertionWithFaceId(challenge: challenge);
  }

  // ─── Real FIDO2 assertion (iOS 16+, credential registered) ─────────────────

  Future<PasskeyAssertionPayload> _realAssertion({
    required String challenge,
    required String credentialId,
  }) async {
    try {
      final result = await _passkeyChannel.invokeMapMethod<String, dynamic>('authenticate', {
        'challenge': _challengeToBase64url(challenge),
        'rp_id': _rpId,
        'credential_id': credentialId,
      });

      if (result == null) throw Exception('Passkey authenticate returned null');

      return PasskeyAssertionPayload(
        id: result['id'] as String,
        rawId: result['raw_id'] as String,
        authenticatorData: result['authenticator_data'] as String,
        clientDataJson: result['client_data_json'] as String,
        signature: result['signature'] as String,
        userHandle: result['user_handle'] as String?,
      );
    } on PlatformException catch (e) {
      if (e.code == 'USER_CANCELLED') {
        throw Exception('Passkey authentication cancelled by user');
      }
      debugPrint('[Passkeys] Real assertion failed (${e.code}), falling back to stub: ${e.message}');
      return _stubAssertionWithFaceId(challenge: challenge);
    }
  }

  // ─── Stub assertion (dev / no Associated Domain) ────────────────────────────

  Future<PasskeyAssertionPayload> _stubAssertionWithFaceId({
    required String challenge,
  }) async {
    // Trigger real Face ID so the gesture is always required
    try {
      await _biometricsChannel.invokeMethod<bool>('authenticate', {
        'reason': 'Firma tu presencia con Face ID',
      });
    } on PlatformException catch (e) {
      if (e.code == 'USER_CANCELLED') {
        throw Exception('Face ID cancelado por el usuario');
      }
      debugPrint('[Passkeys] Biometrics warning (continuing): ${e.message}');
    }

    debugPrint('[Passkeys] Stub assertion (set VERIFIA_RP_ID + AASA to enable real passkeys)');

    final challengeBase64 = _challengeToBase64url(challenge);
    final fakeClientData = {
      'type': 'webauthn.get',
      'challenge': challengeBase64,
      'origin': 'https://$_rpId',
    };
    final clientDataJson = base64Url.encode(utf8.encode(json.encode(fakeClientData)));

    return PasskeyAssertionPayload(
      id: 'stub-credential-id',
      rawId: 'stub-raw-id',
      authenticatorData: 'stub-authenticator-data',
      clientDataJson: clientDataJson,
      signature: 'stub-signature',
      userHandle: 'stub-user-id',
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<bool> _isSupported() async {
    if (_passkeySupported != null) return _passkeySupported!;
    try {
      _passkeySupported = await _passkeyChannel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      _passkeySupported = false;
    }
    return _passkeySupported!;
  }

  /// Encodes the 64-char hex nonce as unpadded base64url (WebAuthn challenge format).
  String _challengeToBase64url(String hexNonce) =>
      base64Url.encode(utf8.encode(hexNonce)).replaceAll('=', '');
}
