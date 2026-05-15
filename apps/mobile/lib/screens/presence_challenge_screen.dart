import 'package:flutter/material.dart';
import '../services/facetec_service.dart';
import '../services/passkey_service.dart';
import '../services/app_attest_service.dart';
import '../services/api_service.dart';
import 'badge_screen.dart';

/// Orchestrates the 3-layer verification flow:
/// 1. FaceTec 3D liveness
/// 2. App Attest assertion
/// 3. Passkey (Face ID) assertion
/// 4. Token issuance
class PresenceChallengeScreen extends StatefulWidget {
  final String nonce;

  const PresenceChallengeScreen({super.key, required this.nonce});

  @override
  State<PresenceChallengeScreen> createState() => _PresenceChallengeScreenState();
}

enum _FlowStep {
  idle,
  facetec,
  passkey,
  issuing,
  done,
  error,
}

class _PresenceChallengeScreenState extends State<PresenceChallengeScreen> {
  _FlowStep _step = _FlowStep.idle;
  String? _errorMessage;

  // Results collected at each step
  String? _facetecSessionId;
  String? _appAttestAssertion;
  String? _deviceId;

  final _facetec = FaceTecService();
  final _appAttest = AppAttestService();
  final _passkeys = PasskeyService();
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    // Auto-start the flow
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  Future<void> _startFlow() async {
    try {
      // Step 1: FaceTec 3D liveness
      setState(() => _step = _FlowStep.facetec);
      final facetecResult = await _facetec.runLivenessSession(nonce: widget.nonce);
      _facetecSessionId = facetecResult.sessionId;

      // Step 2: App Attest assertion (proves this is legit VerifiA on real Apple device)
      final attestResult = await _appAttest.generateAssertion(challenge: widget.nonce);
      _appAttestAssertion = attestResult.assertion;
      _deviceId = attestResult.deviceId;

      // Step 3: Passkey assertion (Face ID gate — proves owner authorized this)
      setState(() => _step = _FlowStep.passkey);
      final passkeyAssertion = await _passkeys.getAssertion(challenge: widget.nonce);

      // Step 4: Issue token
      setState(() => _step = _FlowStep.issuing);
      final tokenResponse = await _api.issueToken(
        nonce: widget.nonce,
        appAttestAssertion: _appAttestAssertion!,
        deviceId: _deviceId!,
        facetecSessionId: _facetecSessionId!,
        passkeyAssertion: passkeyAssertion,
      );

      setState(() => _step = _FlowStep.done);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BadgeScreen(tokenResponse: tokenResponse),
        ),
      );
    } catch (e) {
      setState(() {
        _step = _FlowStep.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              if (_step == _FlowStep.error) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver a intentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      ('Liveness 3D', _FlowStep.facetec),
      ('Face ID', _FlowStep.passkey),
      ('Emitiendo badge', _FlowStep.issuing),
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
                                style: const TextStyle(color: Colors.white54),
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
                color: isDone ? const Color(0xFF22C55E) : const Color(0xFF2A2A38),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatus() {
    if (_step == _FlowStep.error) {
      return Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 16),
          Text(
            'Error en la verificación',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Error desconocido',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final messages = {
      _FlowStep.idle: 'Iniciando verificación...',
      _FlowStep.facetec: 'Completando liveness 3D\n(mueve tu cabeza siguiendo las instrucciones)',
      _FlowStep.passkey: 'Autoriza con Face ID para firmar el badge',
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
}
