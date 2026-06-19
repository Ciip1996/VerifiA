import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart';

class PermissionsWizardScreen extends StatefulWidget {
  const PermissionsWizardScreen({super.key});

  @override
  State<PermissionsWizardScreen> createState() => _PermissionsWizardScreenState();
}

// ─── Design tokens (mirror main.dart) ────────────────────────────────────────
const _bg      = Color(0xFF020B1E);
const _surface = Color(0xFF0D2040);
const _cyan    = Color(0xFF00EAF2);
const _blue    = Color(0xFF147BFF);
const _text    = Color(0xFFF4F8FF);
const _muted   = Color(0xFF8BA0B8);

// ─── Step data ────────────────────────────────────────────────────────────────
enum _WizardStep { welcome, network, camera, faceId, done }

class _PermissionsWizardScreenState extends State<PermissionsWizardScreen>
    with SingleTickerProviderStateMixin {
  _WizardStep _step = _WizardStep.welcome;
  bool _loading = false;

  static const _biometricsChannel = MethodChannel('com.verifia.app/biometrics');
  static const _storage = FlutterSecureStorage();

  late final AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _advance(_WizardStep next) async {
    await _animCtrl.reverse();
    if (!mounted) return;
    setState(() => _step = next);
    _animCtrl.forward();
  }

  // ─── Permission actions ────────────────────────────────────────────────────

  Future<void> _requestNetwork() async {
    await _advance(_WizardStep.camera);
  }

  Future<void> _requestCamera() async {
    setState(() => _loading = true);
    await Permission.camera.request();
    setState(() => _loading = false);
    await _advance(_WizardStep.faceId);
  }

  Future<void> _requestFaceId() async {
    setState(() => _loading = true);
    try {
      await _biometricsChannel.invokeMethod('authenticate');
    } catch (_) {
      // Surface the iOS Face ID dialog; ignore result — user may deny and proceed
    }
    setState(() => _loading = false);
    await _advance(_WizardStep.done);
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    await _storage.write(key: 'permissions_wizard_done', value: 'true');

    final registered = await _storage.read(key: 'profile_registered');
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            registered == 'true' ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Logo — always visible at top, centered
                Center(
                  child: Image.asset(
                    'assets/images/logo_dark.png',
                    height: 48,
                    fit: BoxFit.contain,
                  ),
                ),
                Expanded(child: _buildStepContent()),
                _buildDots(),
                const SizedBox(height: 20),
                _buildCTA(),
                if (_step == _WizardStep.network ||
                    _step == _WizardStep.camera ||
                    _step == _WizardStep.faceId)
                  _buildSkip(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Step content ──────────────────────────────────────────────────────────

  Widget _buildStepContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: switch (_step) {
          _WizardStep.welcome => [
              _buildHeroIcon(Icons.verified_user_rounded),
              const SizedBox(height: 32),
              _buildTitle('Bienvenido a VerifiA'),
              const SizedBox(height: 14),
              _buildBody(
                'Para ofrecerte la mejor experiencia de verificación de identidad, '
                'necesitamos configurar algunos permisos en tu dispositivo.',
              ),
            ],
          _WizardStep.network => [
              _buildHeroIcon(Icons.wifi_rounded),
              const SizedBox(height: 32),
              _buildTitle('Acceso a la red'),
              const SizedBox(height: 14),
              _buildBody(
                'VerifiA necesita conectarse a internet para emitir y validar '
                'badges de presencia en tiempo real de forma segura.',
              ),
            ],
          _WizardStep.camera => [
              _buildHeroIcon(Icons.camera_alt_rounded),
              const SizedBox(height: 32),
              _buildTitle('Acceso a la cámara'),
              const SizedBox(height: 14),
              _buildBody(
                'VerifiA usa tu cámara para escanear códigos QR de verificadores '
                'y para capturar tu selfie durante el proceso de detección de presencia.',
              ),
            ],
          _WizardStep.faceId => [
              _buildHeroIcon(Icons.face_rounded),
              const SizedBox(height: 32),
              _buildTitle('Autenticación con Face ID'),
              const SizedBox(height: 14),
              _buildBody(
                'Face ID confirma tu identidad antes de cada verificación. '
                'Tus datos biométricos nunca salen de tu dispositivo.',
              ),
            ],
          _WizardStep.done => [
              _buildHeroIcon(Icons.check_circle_rounded, success: true),
              const SizedBox(height: 32),
              _buildTitle('¡Todo listo!'),
              const SizedBox(height: 14),
              _buildBody(
                'Los permisos están configurados. Ahora crea tu perfil de identidad verificada.',
              ),
            ],
        },
      ),
    );
  }

  Widget _buildHeroIcon(IconData icon, {bool success = false}) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: success
              ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
              : [_cyan, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (success ? const Color(0xFF22C55E) : _cyan).withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 48, color: _bg),
    );
  }

  Widget _buildTitle(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _text,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
  }

  Widget _buildBody(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _muted,
        fontSize: 15,
        height: 1.6,
      ),
    );
  }

  // ─── Progress dots ─────────────────────────────────────────────────────────

  Widget _buildDots() {
    const steps = _WizardStep.values;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.map((s) {
        final active = s == _step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _cyan : _surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? _cyan : _muted.withValues(alpha: 0.3)),
          ),
        );
      }).toList(),
    );
  }

  // ─── CTA button ────────────────────────────────────────────────────────────

  Widget _buildCTA() {
    final (label, action) = switch (_step) {
      _WizardStep.welcome  => ('Comenzar', () => _advance(_WizardStep.network)),
      _WizardStep.network  => ('Entendido', _requestNetwork),
      _WizardStep.camera   => ('Permitir acceso a la cámara', _requestCamera),
      _WizardStep.faceId   => ('Configurar Face ID', _requestFaceId),
      _WizardStep.done     => ('Continuar', _finish),
    };

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_cyan, _blue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : action,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: _bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _bg,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _bg,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSkip() {
    return Center(
      child: TextButton(
        onPressed: _loading
            ? null
            : () => _advance(switch (_step) {
                  _WizardStep.network => _WizardStep.camera,
                  _WizardStep.camera  => _WizardStep.faceId,
                  _                   => _WizardStep.done,
                }),
        child: const Text(
          'Ahora no',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      ),
    );
  }
}
