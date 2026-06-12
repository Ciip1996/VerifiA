import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/facetec_service.dart';
import '../services/passkey_service.dart';
import '../services/app_attest_service.dart';
import '../services/api_service.dart';
import 'badge_screen.dart';
import 'liveness_screen.dart';

/// Orchestrates the 3-layer verification flow:
/// 0. Anti-coercion confirmation (TC-U03)
/// 1. FaceTec 3D liveness — navigates to LivenessMockScreen
/// 2. App Attest assertion
/// 3. Passkey (Face ID) assertion
/// 4. Token issuance
class PresenceChallengeScreen extends StatefulWidget {
  final String nonce;
  final String verifierId;

  const PresenceChallengeScreen({
    super.key,
    required this.nonce,
    required this.verifierId,
  });

  @override
  State<PresenceChallengeScreen> createState() =>
      _PresenceChallengeScreenState();
}

enum _Phase { confirm, flow, done, error }

enum _FlowStep { idle, liveness, facetec, passkey, issuing, done }

class _PresenceChallengeScreenState extends State<PresenceChallengeScreen> {
  _Phase _phase = _Phase.confirm;
  _FlowStep _step = _FlowStep.idle;
  String? _errorMessage;

  String? _facetecSessionId;
  String? _appAttestAssertion;
  String? _deviceId;

  final _appAttest = AppAttestService();
  final _passkeys = PasskeyService();
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  // ── Confirmation / Anti-coercion ──────────────────────────────────────────

  String get _displayVerifier {
    final v = widget.verifierId;
    // Truncate very long verifier IDs for display
    if (v.length > 32) return '${v.substring(0, 28)}…';
    return v;
  }

  void _onConfirm() {
    setState(() => _phase = _Phase.flow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  void _onCancel() => Navigator.of(context).pop();

  // ── Main flow ─────────────────────────────────────────────────────────────

  Future<void> _startFlow() async {
    try {
      // Signal to the backend (and the sender) that verification has begun.
      // Fire-and-forget: don't block the flow if this fails.
      _api.startChallenge(widget.nonce).catchError((_) {});

      // Ensure App Attest key is registered before the flow starts.
      // Idempotent — no-op if already registered on startup.
      await _appAttest.registerIfNeeded(_api);

      // Step 1: ML Kit liveness — head-turn challenge (our custom Flutter screen)
      setState(() => _step = _FlowStep.liveness);
      final mlKitResult = await Navigator.of(context).push<FaceTecResult>(
        MaterialPageRoute(builder: (_) => LivenessScreen(nonce: widget.nonce)),
      );
      if (!mounted) return;
      if (mlKitResult == null) {
        Navigator.of(context).pop();
        return;
      }

      // Step 2: FaceTec 3D liveness — native SDK presents its own full-screen UI
      setState(() => _step = _FlowStep.facetec);
      // Read stored enrollment ID to perform 3D-3D match during liveness
      final enrollmentRefId = await _storage.read(key: 'facetec_enrollment_ref_id');
      final FaceTecResult facetecResult;
      try {
        facetecResult = await FaceTecService().runLivenessSession(
          nonce: widget.nonce,
          enrollmentRefId: enrollmentRefId,
        );
      } on PlatformException catch (e) {
        if (!mounted) return;
        if (e.code == 'LIVENESS_CANCELLED') {
          Navigator.of(context).pop();
          return;
        }
        rethrow;
      }

      if (!mounted) return;
      _facetecSessionId = facetecResult.sessionId;
      final facetecFaceScan = facetecResult.faceScanBase64;
      final facetecAuditTrail = facetecResult.auditTrailImageBase64;
      final livenessMatchScore = facetecResult.livenessMatchScore;

      // Step 2: App Attest assertion
      final attestResult =
          await _appAttest.generateAssertion(challenge: widget.nonce);
      _appAttestAssertion = attestResult.assertion;
      _deviceId = attestResult.deviceId;

      // Step 3: Passkey assertion (Face ID gate)
      setState(() => _step = _FlowStep.passkey);
      // Ensure credential is registered (idempotent — no-op if already done)
      await _passkeys.registerIfNeeded(
        userId: _deviceId!,
        api: _api,
      );
      final passkeyAssertion =
          await _passkeys.getAssertion(challenge: widget.nonce);

      // Step 4: Issue token
      setState(() => _step = _FlowStep.issuing);
      final tokenResponse = await _api.issueToken(
        nonce: widget.nonce,
        appAttestAssertion: _appAttestAssertion!,
        deviceId: _deviceId!,
        facetecSessionId: _facetecSessionId!,
        facetecFaceScan: facetecFaceScan,
        facetecAuditTrailImage: facetecAuditTrail,
        livenessMatchScore: livenessMatchScore,
        passkeyAssertion: passkeyAssertion,
      );

      setState(() {
        _step = _FlowStep.done;
        _phase = _Phase.done;
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BadgeScreen(tokenResponse: tokenResponse),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = _mapFlowError(e);
      });
    }
  }

  String _mapFlowError(Object e) {
    // Network-level errors: use the global friendly message.
    if (e is NetworkException) return e.message;
    final raw = e.toString();
    if (raw.contains('NONCE_NOT_FOUND') || raw.contains('not found')) {
      return 'El código QR ya no es válido. Pide uno nuevo.';
    }
    if (raw.contains('NONCE_USED')) {
      return 'Este código QR ya fue utilizado.';
    }
    if (raw.contains('NONCE_EXPIRED') || raw.contains('expired')) {
      return 'El código QR expiró. Pide uno nuevo.';
    }
    if (raw.contains('PASSKEY') || raw.contains('challenge')) {
      return 'Error en la autorización biométrica.';
    }
    return friendlyError(e);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.confirm => _buildConfirmScreen(),
      _Phase.flow => _buildFlowScreen(),
      _Phase.done => const Scaffold(
          backgroundColor: Color(0xFF0F0F13),
          body: Center(child: CircularProgressIndicator()),
        ),
      _Phase.error => _buildErrorScreen(),
    };
  }

  // ── Confirm screen (TC-U03 anti-coercion) ────────────────────────────────

  Widget _buildConfirmScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: _onCancel,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Shield icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF6C63FF),
                  size: 40,
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Confirma tu verificación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Estás a punto de firmar criptográficamente tu presencia para:',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Verifier box
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.business_outlined,
                      color: Color(0xFF6C63FF),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verificador',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _displayVerifier,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // What happens next
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildStep(
                      '1',
                      'Liveness check',
                      'Giro de cabeza para confirmar presencia',
                    ),
                    const SizedBox(height: 10),
                    _buildStep(
                      '2',
                      'FaceTec 3D',
                      'Verificación facial anti-spoofing de nivel industrial',
                    ),
                    const SizedBox(height: 10),
                    _buildStep(
                      '3',
                      'Autorización Face ID',
                      'Firma criptográfica con Secure Enclave',
                    ),
                    const SizedBox(height: 10),
                    _buildStep(
                      '4',
                      'Badge de presencia',
                      'JWT efímero válido por 5 minutos',
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Confirm button
              FilledButton(
                onPressed: _onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Verificar mi presencia',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: _onCancel,
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Flow screen ──────────────────────────────────────────────────────────

  Widget _buildFlowScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 48),
              _buildStatus(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      ('Liveness', _FlowStep.liveness),
      ('FaceTec 3D', _FlowStep.facetec),
      ('Face ID', _FlowStep.passkey),
      ('Badge', _FlowStep.issuing),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.asMap().entries.map((entry) {
        final idx = entry.key;
        final (label, step) = entry.value;
        final stepIdx = _FlowStep.values.indexOf(step);
        final currentIdx = _FlowStep.values.indexOf(_step);
        final isDone = currentIdx > stepIdx;
        final isActive = _step == step;

        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF22C55E)
                        : isActive
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF2A2A38),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : isActive
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                '${idx + 1}',
                                style:
                                    const TextStyle(color: Colors.white54),
                              ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? Colors.white : Colors.white38,
                  ),
                ),
              ],
            ),
            if (idx < steps.length - 1)
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: isDone
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF2A2A38),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatus() {
    final messages = {
      _FlowStep.idle: 'Iniciando...',
      _FlowStep.liveness: 'Gira la cabeza para confirmar\nque eres una persona real',
      _FlowStep.facetec: 'Verificación 3D con FaceTec\nColoca tu cara en el óvalo',
      _FlowStep.passkey: 'Autoriza con Face ID\npara firmar el badge',
      _FlowStep.issuing: 'Emitiendo badge de presencia...',
      _FlowStep.done: '¡Badge emitido!',
    };

    return Text(
      messages[_step] ?? '',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  // ── Error screen ─────────────────────────────────────────────────────────

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 56,
              ),
              const SizedBox(height: 20),
              const Text(
                'Error en la verificación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Error desconocido',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text(
                      'Volver',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _phase = _Phase.confirm;
                        _step = _FlowStep.idle;
                        _errorMessage = null;
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
