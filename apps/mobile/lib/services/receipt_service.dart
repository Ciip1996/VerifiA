import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Backend ES256 public key used for the Level-1 offline signature check.
///
/// Public keys are safe to ship client-side. It is embedded as a compile-time
/// constant so the ticket's authenticity can be checked without a network round
/// trip. Provide the production key at build time with
/// `--dart-define=VERIFIA_RECEIPT_PUBLIC_KEY=...`; the default below is the local
/// dev keypair (matches a locally-run backend).
const _receiptPublicKeyPem = String.fromEnvironment(
  'VERIFIA_RECEIPT_PUBLIC_KEY',
  defaultValue: '''-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAETyXXs+IMKr8Wh3/dKfjM9csNd7iW
kZqSsHlelS5MMaRqoaMgLQnevKD4CllMQt2h6FbSBfzunV4A1a6S8IXQCQ==
-----END PUBLIC KEY-----''',
);

// Audience is a hardcoded backend constant (not env-derived), so it is stable
// across environments and safe to assert during local verification.
const _receiptAudience = 'verifia-receipt';
const _receiptPurpose = 'verification_receipt';

/// Result of the Level-1 (offline) signature check.
///
/// - [authentic]: signature valid, within TTL — the verification is real and current.
/// - [expired]: signature valid but past the 30-day TTL — the verification DID
///   happen, only the durable record lapsed. Emotionally opposite to [invalid].
/// - [invalid]: signature failed / not a receipt — possible tampering or forgery.
/// - [malformed]: not a parseable JWT at all.
enum LocalReceiptStatus { authentic, expired, invalid, malformed }

/// Claims decoded from a receipt JWT (display only — never a security decision
/// beyond the signature check that produced them).
class ReceiptClaims {
  final String receiptId;
  final String nonce;
  final String badgeJti;
  final String? verifiedAt;
  final String? badgeValidFrom;
  final String? badgeValidUntil;
  final String? subjectName;
  final String? challengeAccountId;

  const ReceiptClaims({
    required this.receiptId,
    required this.nonce,
    required this.badgeJti,
    this.verifiedAt,
    this.badgeValidFrom,
    this.badgeValidUntil,
    this.subjectName,
    this.challengeAccountId,
  });

  factory ReceiptClaims.fromPayload(Map<String, dynamic> p) => ReceiptClaims(
        receiptId: p['receipt_id'] as String? ?? p['sub'] as String? ?? '',
        nonce: p['nonce'] as String? ?? '',
        badgeJti: p['badge_jti'] as String? ?? '',
        verifiedAt: p['verified_at'] as String?,
        badgeValidFrom: p['badge_valid_from'] as String?,
        badgeValidUntil: p['badge_valid_until'] as String?,
        subjectName: p['subject_name'] as String?,
        challengeAccountId: p['challenge_account_id'] as String?,
      );
}

class LocalReceiptResult {
  final LocalReceiptStatus status;
  final ReceiptClaims? claims; // present for authentic + expired

  const LocalReceiptResult(this.status, [this.claims]);
}

/// Two-tier receipt verification:
///   Level 1 — offline ES256 signature check against the embedded public key.
///   Level 2 — server confirmation (GET /receipts/:id or POST /receipts/verify)
///             for the current status + owner-only identity media.
class ReceiptService {
  final ApiService _api;
  ReceiptService([ApiService? api]) : _api = api ?? ApiService();

  /// Level 1: verify the receipt JWT locally, with no network.
  LocalReceiptResult verifyLocally(String receiptJwt) {
    final token = receiptJwt.trim();
    if (token.isEmpty) return const LocalReceiptResult(LocalReceiptStatus.malformed);

    try {
      final decoded = JWT.verify(
        token,
        ECPublicKey(_receiptPublicKeyPem),
        // Our backend (jose) does not stamp `typ: JWT` in the protected header.
        checkHeaderType: false,
        audience: Audience.one(_receiptAudience),
      );
      final payload = _asMap(decoded.payload);
      if (payload == null || payload['purpose'] != _receiptPurpose) {
        return const LocalReceiptResult(LocalReceiptStatus.invalid);
      }
      return LocalReceiptResult(
        LocalReceiptStatus.authentic,
        ReceiptClaims.fromPayload(payload),
      );
    } on JWTExpiredException {
      // Signature was valid, only expired — authentic verification, lapsed record.
      final decoded = JWT.tryDecode(token);
      final payload = decoded == null ? null : _asMap(decoded.payload);
      if (payload == null || payload['purpose'] != _receiptPurpose) {
        return const LocalReceiptResult(LocalReceiptStatus.expired);
      }
      return LocalReceiptResult(
        LocalReceiptStatus.expired,
        ReceiptClaims.fromPayload(payload),
      );
    } on JWTParseException catch (e) {
      // Not a parseable JWT at all — unrecognized input, not tampering.
      debugPrint('[ReceiptService] local verify malformed: $e');
      return const LocalReceiptResult(LocalReceiptStatus.malformed);
    } on JWTUndefinedException catch (e) {
      // Underlying parse/format failure (e.g. bad base64) — unrecognized input.
      debugPrint('[ReceiptService] local verify malformed: $e');
      return const LocalReceiptResult(LocalReceiptStatus.malformed);
    } on JWTException catch (e) {
      // Well-formed JWT whose signature/claims failed — possible tampering.
      debugPrint('[ReceiptService] local verify rejected: $e');
      return const LocalReceiptResult(LocalReceiptStatus.invalid);
    } catch (e) {
      debugPrint('[ReceiptService] local verify malformed: $e');
      return const LocalReceiptResult(LocalReceiptStatus.malformed);
    }
  }

  /// Level 2: confirm with the server by submitting the full JWT.
  /// Returns subject_name (proof of possession) plus owner-only identity.
  Future<ReceiptServerResult> confirmWithServer(String receiptJwt) {
    return _api.verifyReceipt(receiptJwt);
  }

  /// Level 2 by bare id (public subset unless the caller is the owner).
  Future<ReceiptServerResult> confirmById(String receiptId) {
    return _api.getReceipt(receiptId);
  }

  static Map<String, dynamic>? _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return payload.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }
}
