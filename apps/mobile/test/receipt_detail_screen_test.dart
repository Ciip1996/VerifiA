import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifia_mobile/l10n/app_localizations.dart';
import 'package:verifia_mobile/screens/receipt_detail_screen.dart';
import 'package:verifia_mobile/services/api_service.dart';
import 'package:verifia_mobile/services/receipt_service.dart';

/// Dev keypair (matches the embedded public key default in receipt_service.dart).
const _devPrivateKeyPem = '''-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgaAasLgFrQnRQEt0j
Oi6bHcdPHvKvQGHxWmvtBlTC7lihRANCAARPJdez4gwqvxaHf90p+Mz1yw13uJaR
mpKweV6VLkwxpGqhoyAtCd68oPgKWUxC3aHoVtIF/O6dXgDVrpLwhdAJ
-----END PRIVATE KEY-----''';

/// Fake API that always fails Level-2 confirmation, forcing the screen onto the
/// offline (Level-1) path so the tests are hermetic (no real network).
class _OfflineApi extends ApiService {
  @override
  Future<ReceiptServerResult> verifyReceipt(String receiptJwt) =>
      Future.error(const NetworkException('offline', isNetwork: true));
  @override
  Future<ReceiptServerResult> getReceipt(String id) =>
      Future.error(const NetworkException('offline', isNetwork: true));
}

String _signReceipt({required Duration expiresIn}) {
  final jwt = JWT(
    {
      'purpose': 'verification_receipt',
      'receipt_id': 'r-1',
      'nonce': 'n-1',
      'badge_jti': 'b-1',
      'verified_at': '2026-01-01T12:00:00.000Z',
      'badge_valid_from': '2026-01-01T12:00:00.000Z',
      'badge_valid_until': '2026-01-01T12:05:00.000Z',
      'subject_name': 'Ada Lovelace',
    },
    audience: Audience.one('verifia-receipt'),
    issuer: 'https://api.verifia.dev',
    subject: 'r-1',
    jwtId: 'j-1',
  );
  return jwt.sign(
    ECPrivateKey(_devPrivateKeyPem),
    algorithm: JWTAlgorithm.ES256,
    expiresIn: expiresIn,
  );
}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      home: child,
    );

void main() {
  testWidgets('shows AUTHENTIC banner for a validly-signed, current receipt', (tester) async {
    final token = _signReceipt(expiresIn: const Duration(days: 30));
    await tester.pumpWidget(_wrap(
      ReceiptDetailScreen.fromJwt(token, service: ReceiptService(_OfflineApi())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Verificación auténtica'), findsOneWidget);
    // Level-2 failed → offline note shown, verification still trusted offline.
    expect(find.text('Verificado sin conexión. No se pudo confirmar con el servidor.'), findsOneWidget);
    // Subject name from the signed claims is displayed.
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('shows EXPIRED banner (verification happened, record lapsed)', (tester) async {
    final token = _signReceipt(expiresIn: const Duration(days: -1));
    await tester.pumpWidget(_wrap(
      ReceiptDetailScreen.fromJwt(token, service: ReceiptService(_OfflineApi())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('La constancia venció'), findsOneWidget);
    // Emotionally distinct from tampering — reassures that it did happen.
    expect(
      find.textContaining('La verificación sí ocurrió'),
      findsOneWidget,
    );
  });

  testWidgets('shows INVALID banner for a tampered signature', (tester) async {
    final token = _signReceipt(expiresIn: const Duration(days: 30));
    // Flip the FIRST signature character — this always changes the decoded
    // signature bytes (the last base64 char has unused low bits that can flip
    // without altering the bytes, which would leave the signature valid).
    final parts = token.split('.');
    final sig = parts[2];
    final tamperedSig = (sig[0] == 'A' ? 'B' : 'A') + sig.substring(1);
    final tampered = '${parts[0]}.${parts[1]}.$tamperedSig';
    await tester.pumpWidget(_wrap(
      ReceiptDetailScreen.fromJwt(tampered, service: ReceiptService(_OfflineApi())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo verificar'), findsOneWidget);
    expect(find.textContaining('manipulado'), findsOneWidget);
    // A tampered receipt must never surface identity claims.
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('shows MALFORMED banner for a non-JWT string', (tester) async {
    await tester.pumpWidget(_wrap(
      ReceiptDetailScreen.fromJwt('this-is-not-a-jwt', service: ReceiptService(_OfflineApi())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Código no reconocido'), findsOneWidget);
  });
}
