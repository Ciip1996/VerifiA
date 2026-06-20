import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../services/app_attest_service.dart' show AppAttestService;
import '../services/api_service.dart';
import '../services/onesignal_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

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
enum _WizardStep { welcome, network, notifications, camera, faceId, done }

class _PermissionsWizardScreenState extends State<PermissionsWizardScreen>
    with SingleTickerProviderStateMixin {
  _WizardStep _step = _WizardStep.welcome;
  bool _loading = false;

  // ignore: prefer_final_fields
  bool _networkGranted = true;      // internet is always available on iOS
  bool _notificationsGranted = false;
  bool _notificationsPermanentlyDenied = false;
  bool _cameraGranted = false;
  bool _cameraPermanentlyDenied = false;
  bool _faceIdGranted = false;

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
    // Start App Attest in background — no dialog, just network calls
    unawaited(AppAttestService().registerIfNeeded(ApiService()));
    // Initialize OneSignal SDK (no permission dialog yet)
    OneSignalService().initialize();
    await _advance(_WizardStep.notifications);
  }

  Future<void> _requestNotifications() async {
    setState(() => _loading = true);
    final granted = await OneSignal.Notifications.requestPermission(true);
    if (!mounted) return;
    // Check if permanently denied (for iOS: denied twice = permanently denied)
    final status = await Permission.notification.status;
    setState(() {
      _notificationsGranted = granted;
      _notificationsPermanentlyDenied = status.isPermanentlyDenied;
      _loading = false;
    });
    await _advance(_WizardStep.camera);
  }

  Future<void> _requestCamera() async {
    setState(() => _loading = true);
    final status = await Permission.camera.request();
    setState(() {
      _cameraGranted = status.isGranted;
      _cameraPermanentlyDenied = status.isPermanentlyDenied;
      _loading = false;
    });
    await _advance(_WizardStep.faceId);
  }

  Future<void> _requestFaceId() async {
    setState(() => _loading = true);
    try {
      await _biometricsChannel.invokeMethod('authenticate');
      setState(() => _faceIdGranted = true);
    } catch (_) {
      // User may deny; still advance
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
            registered == 'true' ? const HomeScreen() : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ─── Retry helpers ─────────────────────────────────────────────────────────

  Future<void> _retryNotifications() async {
    setState(() => _loading = true);
    final granted = await OneSignal.Notifications.requestPermission(true);
    final status = await Permission.notification.status;
    setState(() {
      _notificationsGranted = granted;
      _notificationsPermanentlyDenied = status.isPermanentlyDenied;
      _loading = false;
    });
  }

  Future<void> _retryCamera() async {
    setState(() => _loading = true);
    final status = await Permission.camera.request();
    setState(() {
      _cameraGranted = status.isGranted;
      _cameraPermanentlyDenied = status.isPermanentlyDenied;
      _loading = false;
    });
  }

  Future<void> _retryFaceId() async {
    setState(() => _loading = true);
    try {
      await _biometricsChannel.invokeMethod('authenticate');
      setState(() => _faceIdGranted = true);
    } catch (_) {}
    setState(() => _loading = false);
  }

  // ─── Computed state ────────────────────────────────────────────────────────

  bool get _allGranted =>
      _networkGranted && _notificationsGranted && _cameraGranted && _faceIdGranted;

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                Expanded(child: _buildStepContent(l10n)),
                _buildDots(),
                const SizedBox(height: 20),
                _buildCTA(l10n),
                if (_step == _WizardStep.network ||
                    _step == _WizardStep.notifications ||
                    _step == _WizardStep.camera ||
                    _step == _WizardStep.faceId)
                  _buildSkip(l10n),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Step content ──────────────────────────────────────────────────────────

  Widget _buildStepContent(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: switch (_step) {
          _WizardStep.welcome => [
              _buildHeroIcon(Icons.verified_user_rounded),
              const SizedBox(height: 32),
              _buildTitle(l10n.permWelcomeTitle),
              const SizedBox(height: 14),
              _buildBody(l10n.permWelcomeBody),
            ],
          _WizardStep.network => [
              _buildHeroIcon(Icons.wifi_rounded),
              const SizedBox(height: 32),
              _buildTitle(l10n.permNetworkTitle),
              const SizedBox(height: 14),
              _buildBody(l10n.permNetworkBody),
            ],
          _WizardStep.notifications => [
              _buildHeroIcon(Icons.notifications_rounded),
              const SizedBox(height: 32),
              _buildTitle(l10n.permNotificationsTitle),
              const SizedBox(height: 14),
              _buildBody(l10n.permNotificationsBody),
            ],
          _WizardStep.camera => [
              _buildHeroIcon(Icons.camera_alt_rounded),
              const SizedBox(height: 32),
              _buildTitle(l10n.permCameraTitle),
              const SizedBox(height: 14),
              _buildBody(l10n.permCameraBody),
            ],
          _WizardStep.faceId => [
              _buildHeroIcon(Icons.face_rounded),
              const SizedBox(height: 32),
              _buildTitle(l10n.permFaceIdTitle),
              const SizedBox(height: 14),
              _buildBody(l10n.permFaceIdBody),
            ],
          _WizardStep.done => [
              _buildHeroIcon(Icons.check_circle_rounded, success: _allGranted),
              const SizedBox(height: 32),
              _buildTitle(l10n.permDoneTitle),
              const SizedBox(height: 14),
              if (!_allGranted)
                _buildBody(l10n.permDoneBodyBlocked)
              else
                _buildBody(l10n.permDoneBody),
              const SizedBox(height: 20),
              _buildChecklist(l10n),
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

  Widget _buildCTA(AppLocalizations l10n) {
    final (label, action) = switch (_step) {
      _WizardStep.welcome       => (l10n.permCtaBegin, () => _advance(_WizardStep.network)),
      _WizardStep.network       => (l10n.permCtaUnderstood, _requestNetwork),
      _WizardStep.notifications => (l10n.permCtaNotifications, _requestNotifications),
      _WizardStep.camera        => (l10n.permCtaCamera, _requestCamera),
      _WizardStep.faceId        => (l10n.permCtaFaceId, _requestFaceId),
      _WizardStep.done          => (l10n.permCtaContinue, _allGranted ? _finish : null),
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

  Widget _buildSkip(AppLocalizations l10n) {
    return Center(
      child: TextButton(
        onPressed: _loading
            ? null
            : () {
                switch (_step) {
                  case _WizardStep.notifications:
                    setState(() => _notificationsGranted = false);
                    _advance(_WizardStep.camera);
                  case _WizardStep.camera:
                    setState(() => _cameraGranted = false);
                    _advance(_WizardStep.faceId);
                  case _WizardStep.faceId:
                    setState(() => _faceIdGranted = false);
                    _advance(_WizardStep.done);
                  default:
                    _advance(switch (_step) {
                      _WizardStep.network => _WizardStep.notifications,
                      _ => _WizardStep.done,
                    });
                }
              },
        child: Text(
          l10n.permSkip,
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
      ),
    );
  }

  // ─── Checklist ─────────────────────────────────────────────────────────────

  Widget _buildChecklist(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.permDoneChecklist,
          style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildCheckRow(l10n.permCheckNetwork, _networkGranted, canRetry: false, l10n: l10n),
        _buildCheckRow(l10n.permCheckNotifications, _notificationsGranted,
            permanentlyDenied: _notificationsPermanentlyDenied,
            onRetry: _notificationsPermanentlyDenied ? () => openAppSettings() : _retryNotifications,
            l10n: l10n),
        _buildCheckRow(l10n.permCheckCamera, _cameraGranted,
            permanentlyDenied: _cameraPermanentlyDenied,
            onRetry: _cameraPermanentlyDenied ? () => openAppSettings() : _retryCamera,
            l10n: l10n),
        _buildCheckRow(l10n.permCheckFaceId, _faceIdGranted,
            onRetry: _retryFaceId,
            l10n: l10n),
      ],
    );
  }

  Widget _buildCheckRow(
    String label,
    bool granted, {
    bool canRetry = true,
    bool permanentlyDenied = false,
    VoidCallback? onRetry,
    required AppLocalizations l10n,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(
          granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: granted ? const Color(0xFF22C55E) : _muted,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: granted ? _text : _muted,
              fontSize: 14,
            ),
          ),
        ),
        if (!granted && canRetry && onRetry != null)
          TextButton(
            onPressed: _loading ? null : onRetry,
            style: TextButton.styleFrom(
              foregroundColor: _cyan,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              permanentlyDenied ? l10n.permOpenSettings : l10n.permRetryButton,
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ]),
    );
  }
}
