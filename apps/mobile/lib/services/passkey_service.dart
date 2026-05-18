import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

const _storage = FlutterSecureStorage();
const _credentialIdKey = 'verifia_passkey_credential_id';
const _userIdKey = 'verifia_passkey_user_id';

/// Relying Party configuration for VerifiA Passkeys.
///
/// The RP ID must match the domain in apple-app-site-association.
/// For Railway deployment: use the Railway subdomain as RP ID.
/// For production: use verifia.app or verifia.dev
///
/// The AASA file must be served at:
/// https://{rpId}/.well-known/apple-app-site-association
const _rpId = String.fromEnvironment(
  'VERIFIA_RP_ID',
  defaultValue: 'api.verifia.dev',
);

const _rpName = 'VerifiA';

/// Passkey assertion payload matching the backend's PasskeyAssertionPayload interface.
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

/// Passkeys service (WebAuthn / Secure Enclave).
///
/// Handles:
/// - First-time registration (creates ES256 key in Secure Enclave)
/// - Per-request assertion (Face ID gate → ECDSA signature over nonce)
///
/// Requires:
/// - AASA file at https://{rpId}/.well-known/apple-app-site-association
/// - Associated Domains entitlement in Xcode: webcredentials:{rpId}
///
/// TODO (Semana 3): Wire up full registration + assertion flow.
class PasskeyService {
  /// Register a passkey credential on first use.
  /// The credential is stored in the Secure Enclave and synced to iCloud Keychain.
  Future<void> registerIfNeeded({required String userId, required String challenge}) async {
    final existingCredId = await _storage.read(key: _credentialIdKey);
    if (existingCredId != null) {
      debugPrint('[Passkeys] Credential already registered');
      return;
    }

    debugPrint('[Passkeys] Registering new credential for user $userId');

    // TODO (Semana 3): Implement full passkey registration
    // final response = await _plugin.register(
    //   RelyingParty(id: _rpId, name: _rpName),
    //   User(id: userId, name: userId, displayName: 'VerifiA User'),
    //   challenge: base64Url.decode(challenge),
    // );
    // await _storage.write(key: _credentialIdKey, value: response.id);
    // await _storage.write(key: _userIdKey, value: userId);

    debugPrint('[Passkeys] Registration stub — implement in Semana 3');
  }

  /// Generate a passkey assertion for the given challenge (nonce).
  /// Triggers Face ID prompt — user must authenticate to proceed.
  Future<PasskeyAssertionPayload> getAssertion({required String challenge}) async {
    debugPrint('[Passkeys] Requesting assertion for challenge ${challenge.substring(0, 8)}...');

    // Encode nonce as base64url (WebAuthn challenge format)
    final challengeBase64 = base64Url.encode(utf8.encode(challenge));

    // TODO (Semana 3): Replace with real passkey assertion
    // final response = await _plugin.authenticate(
    //   RelyingParty(id: _rpId, name: _rpName),
    //   challenge: base64Url.decode(challengeBase64),
    // );
    // return PasskeyAssertionPayload(
    //   id: response.id,
    //   rawId: response.rawId,
    //   authenticatorData: response.authenticatorData,
    //   clientDataJson: response.clientDataJSON,
    //   signature: response.signature,
    //   userHandle: response.userHandle,
    // );

    debugPrint('[Passkeys] Assertion stub — implement in Semana 3');

    // Stub — returns fake assertion with correctly embedded challenge
    await Future.delayed(const Duration(milliseconds: 800)); // simulate Face ID

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
}
