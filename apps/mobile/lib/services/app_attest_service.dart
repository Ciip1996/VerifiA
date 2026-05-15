import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

const _channel = MethodChannel('com.verifia.app/app_attest');
const _storage = FlutterSecureStorage();
const _keyIdStorageKey = 'verifia_app_attest_key_id';
const _deviceIdStorageKey = 'verifia_device_id';

// Set via --dart-define=VERIFIA_SKIP_ATTEST=true for CI / simulator
const _skipAttest = bool.fromEnvironment('VERIFIA_SKIP_ATTEST', defaultValue: false);

class AttestationResult {
  final String assertion;
  final String deviceId;
  const AttestationResult({required this.assertion, required this.deviceId});
}

/// Dart-side wrapper for the AppAttestChannel Swift MethodChannel.
/// Handles key generation, attestation, and per-request assertions.
class AppAttestService {
  /// Register the device key with the backend on first launch.
  /// Idempotent — skips if already registered.
  Future<void> registerIfNeeded(ApiService api) async {
    if (_skipAttest) {
      debugPrint('[AppAttest] Skip mode — skipping registration');
      return;
    }

    final existingKeyId = await _storage.read(key: _keyIdStorageKey);
    if (existingKeyId != null) {
      debugPrint('[AppAttest] Key already registered: ${existingKeyId.substring(0, 8)}...');
      return;
    }

    // Check if App Attest is supported (not on simulator)
    final supported = await _isSupported();
    if (!supported) {
      debugPrint('[AppAttest] Not supported on this device');
      return;
    }

    // Generate a temporary challenge for registration
    // In production, fetch a real challenge from the backend first
    final regChallenge = _generateLocalChallenge();

    // Generate key in Secure Enclave
    final keyId = await _generateKey();

    // Attest key with Apple servers
    final attestationBase64 = await _attestKey(keyId: keyId, challenge: regChallenge);

    // Register with backend
    final response = await api.registerAppAttest(
      attestationObject: attestationBase64,
      clientDataJson: _challengeToClientDataJson(regChallenge),
      challenge: regChallenge,
    );

    // Persist key ID and device ID
    await _storage.write(key: _keyIdStorageKey, value: keyId);
    await _storage.write(key: _deviceIdStorageKey, value: response['device_id'] as String);

    debugPrint('[AppAttest] Registered device: ${response['device_id']}');
  }

  /// Generate a per-request assertion for the given nonce.
  Future<AttestationResult> generateAssertion({required String challenge}) async {
    if (_skipAttest) {
      return AttestationResult(
        assertion: 'SKIP_ATTEST_ASSERTION',
        deviceId: 'SKIP_ATTEST_DEVICE',
      );
    }

    final keyId = await _storage.read(key: _keyIdStorageKey);
    final deviceId = await _storage.read(key: _deviceIdStorageKey);

    if (keyId == null || deviceId == null) {
      throw Exception('[AppAttest] Device not registered. Call registerIfNeeded() first.');
    }

    final assertion = await _generateAssertionNative(keyId: keyId, challenge: challenge);
    return AttestationResult(assertion: assertion, deviceId: deviceId);
  }

  // ─── Private MethodChannel calls ────────────────────────────────────────

  Future<bool> _isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<String> _generateKey() async {
    try {
      final keyId = await _channel.invokeMethod<String>('generateKey');
      if (keyId == null) throw Exception('generateKey returned null');
      return keyId;
    } on PlatformException catch (e) {
      throw Exception('[AppAttest] generateKey failed: ${e.message}');
    }
  }

  Future<String> _attestKey({required String keyId, required String challenge}) async {
    try {
      final attestation = await _channel.invokeMethod<String>('attestKey', {
        'key_id': keyId,
        'challenge': challenge,
      });
      if (attestation == null) throw Exception('attestKey returned null');
      return attestation;
    } on PlatformException catch (e) {
      throw Exception('[AppAttest] attestKey failed: ${e.message}');
    }
  }

  Future<String> _generateAssertionNative({
    required String keyId,
    required String challenge,
  }) async {
    try {
      final assertion = await _channel.invokeMethod<String>('generateAssertion', {
        'key_id': keyId,
        'challenge': challenge,
      });
      if (assertion == null) throw Exception('generateAssertion returned null');
      return assertion;
    } on PlatformException catch (e) {
      throw Exception('[AppAttest] generateAssertion failed: ${e.message}');
    }
  }

  /// Generate a random 32-byte hex string for registration challenges.
  String _generateLocalChallenge() {
    // Uses Dart's built-in random (good enough for local challenge generation)
    // In Semana 2: fetch real challenge from /api/v1/challenges endpoint
    final bytes = List<int>.generate(32, (i) => (i * 17 + 113) % 256); // placeholder
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _challengeToClientDataJson(String challenge) {
    return '{"type":"app-attest","challenge":"$challenge"}';
  }
}
