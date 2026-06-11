import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import '../services/feedback_service.dart';
import '../services/inbox_service.dart';
import '../services/sent_challenges_service.dart';
import 'account_profile_screen.dart';
import 'onboarding_screen.dart';
import 'qr_scanner_screen.dart';
import 'create_challenge_screen.dart';
import 'incoming_validations_screen.dart';
import 'user_search_screen.dart';

/// Main scaffold shown after successful onboarding + account setup.
/// Four tabs: QR Scanner, Create QR, Solicitudes, Buscar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  String? _fullName;
  static const _storage = FlutterSecureStorage();

  final _inbox = InboxService.instance;
  final _sent = SentChallengesService.instance;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _inbox.addListener(_onInboxChanged);
    _inbox.start();
    _sent.addListener(_onSentChanged);
    _sent.start();
  }

  @override
  void dispose() {
    _inbox.removeListener(_onInboxChanged);
    _sent.removeListener(_onSentChanged);
    super.dispose();
  }

  void _onInboxChanged() {
    if (!mounted) return;
    setState(() {});

    // Show in-app banner only when the user is NOT already on the inbox tab
    final newChallenge = _inbox.consumeLatestNew();
    if (newChallenge != null && _tabIndex != 2) {
      FeedbackService.incoming();
      _showInAppBanner(newChallenge);
    }
  }

  void _showInAppBanner(IncomingChallenge challenge) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    final hasPhoto = challenge.requesterProfilePhoto != null &&
        challenge.requesterProfilePhoto!.isNotEmpty;

    messenger.showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 20,
          backgroundImage: hasPhoto
              ? MemoryImage(base64Decode(challenge.requesterProfilePhoto!))
              : null,
          child: hasPhoto
              ? null
              : Text(
                  (challenge.requesterEmail?.substring(0, 1) ?? '?').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nueva solicitud de verificación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              challenge.requesterFullName ??
                  challenge.requesterEmail ??
                  'Alguien',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
            },
            child: const Text('Descartar'),
          ),
          FilledButton.tonal(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              setState(() => _tabIndex = 2);
              _inbox.markAllSeen();
            },
            child: const Text('Ver'),
          ),
        ],
      ),
    );

    // Auto-dismiss after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  void _onSentChanged() {
    if (!mounted) return;
    setState(() {});

    final change = _sent.consumeLatestChange();
    if (change == null) return;

    // Play haptic/sound feedback and show banner
    FeedbackService.incoming(); // reuse warning haptic — it signals "attention needed"
    _showRejectedBanner(change);
  }

  void _showRejectedBanner(SentStatusChange change) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    final c = change.challenge;
    final isRejected = change.newStatus == 'REJECTED';
    final label = isRejected ? 'rechazó' : 'canceló';
    final recipient = c.subjectFullName ?? c.targetEmail ?? 'El destinatario';

    messenger.showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: isRejected
              ? const Color(0xFFC62828).withAlpha(30)
              : const Color(0xFF757575).withAlpha(30),
          child: Icon(
            isRejected ? Icons.cancel_rounded : Icons.block_rounded,
            color: isRejected ? const Color(0xFFC62828) : const Color(0xFF757575),
            size: 22,
          ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$recipient $label tu solicitud',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (c.targetEmail != null)
              Text(c.targetEmail!, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('Descartar'),
          ),
          FilledButton.tonal(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              setState(() => _tabIndex = 2); // go to Solicitudes tab
            },
            child: const Text('Ver'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  Future<void> _loadProfile() async {
    try {
      final sessionToken = await ApiService.getSessionToken();
      if (sessionToken == null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const _LoginScreen()),
        );
        return;
      }
      final email = await _storage.read(key: 'verifia_account_email');
      if (email != null && mounted) {
        setState(() => _fullName = email.split('@').first);
      }
    } catch (_) {}
  }

  void _onTabSelected(int i) {
    setState(() => _tabIndex = i);
    if (i == 2) {
      // User opened inbox — mark everything seen and dismiss banner
      _inbox.markAllSeen();
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unseenCount = _inbox.unseenCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.shield_rounded, color: cs.primary, size: 26),
            const SizedBox(width: 8),
            const Text('VerifiA', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(Icons.person_rounded, size: 16, color: cs.onSecondaryContainer),
              label: Text(
                _fullName ?? '···',
                style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
              ),
              backgroundColor: cs.secondaryContainer,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountProfileScreen()),
              ),
            ),
          ),
        ],
      ),
      // QRScannerScreen is mounted/unmounted on tab switch so the OS camera
      // session is fully released when leaving tab 0.
      // The other three tabs use IndexedStack so their state survives tab changes.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Tabs 1-3: kept alive behind an Offstage when scanner is visible
          Offstage(
            offstage: _tabIndex == 0,
            child: IndexedStack(
              index: (_tabIndex - 1).clamp(0, 2),
              children: const [
                CreateChallengeScreen(),
                IncomingValidationsScreen(),
                UserSearchScreen(),
              ],
            ),
          ),
          // Tab 0: scanner is only in the tree when actively selected
          if (_tabIndex == 0) const QRScannerScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: cs.surface,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Escanear',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Crear QR',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unseenCount > 0,
              label: Text(
                unseenCount > 9 ? '9+' : '$unseenCount',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unseenCount > 0,
              label: Text(
                unseenCount > 9 ? '9+' : '$unseenCount',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.inbox_rounded),
            ),
            label: 'Solicitudes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Buscar',
          ),
        ],
      ),
    );
  }

}

// ─── Simple Mobile Login Screen ────────────────────────────────────────────

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  // Returns true when both fields pass their validators
  bool get _canSubmit {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    return email.isNotEmpty &&
        RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email) &&
        password.isNotEmpty;
  }

  String _mapError(String raw) {
    final msg = raw.replaceFirst('Exception: ', '').toLowerCase();
    if (msg.contains('invalid_credentials') || msg.contains('unauthorized') || msg.contains('401')) {
      return 'Correo o contraseña incorrectos. Verifica tus datos e intenta de nuevo.';
    }
    if (msg.contains('account_not_found') || msg.contains('404')) {
      return 'No existe una cuenta con ese correo electrónico.';
    }
    if (msg.contains('timeout') || msg.contains('no connection') || msg.contains('network')) {
      return 'Sin conexión. Verifica tu red e intenta de nuevo.';
    }
    return 'Error del servidor. Intenta más tarde.';
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await _api.loginAccount(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      const storage = FlutterSecureStorage();
      await storage.write(key: 'verifia_account_email', value: profile.email);
      if (profile.id.isNotEmpty) {
        await storage.write(key: 'verifia_account_id', value: profile.id);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() { _error = _mapError(e.toString()); _loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() => setState(() {}));
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_rounded, size: 52, color: cs.primary),
              const SizedBox(height: 16),
              Text('Iniciar sesión', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Usa tu correo y contraseña de VerifiA', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa tu correo electrónico';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Correo electrónico no válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_loading || !_canSubmit) ? null : _login,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Iniciar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  ),
                  child: Text(
                    '¿No tienes cuenta? Regístrate',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
