import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/feedback_service.dart';
import '../services/inbox_service.dart';
import '../services/onesignal_service.dart';
import '../services/sent_challenges_service.dart';
import 'account_profile_screen.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';
import 'create_challenge_screen.dart';
import 'incoming_validations_screen.dart';
import 'user_search_screen.dart';
import 'verification_detail_screen.dart';

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

  bool get _isOffline => _inbox.isOffline || _sent.isOffline;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _inbox.addListener(_onInboxChanged);
    _inbox.start();
    _sent.addListener(_onSentChanged);
    _sent.start();
    // Show one-time push subscription verification dialog once context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) OneSignalService().setupSubscriptionVerification(context);
    });
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
    final l10n = AppLocalizations.of(context)!;
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
            Text(
              l10n.bannerNewRequest,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              challenge.requesterFullName ??
                  challenge.requesterEmail ??
                  l10n.bannerAnonymous,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
            },
            child: Text(l10n.dismiss),
          ),
          FilledButton.tonal(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              setState(() => _tabIndex = 2);
              _inbox.markAllSeen();
            },
            child: Text(l10n.seeAction),
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

    FeedbackService.incoming();
    if (change.newStatus == 'USED') {
      _showVerifiedBanner(change);
    } else {
      _showRejectedBanner(change);
    }
  }

  void _showRejectedBanner(SentStatusChange change) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    final c = change.challenge;
    final isRejected = change.newStatus == 'REJECTED';
    final recipient = c.subjectFullName ?? c.targetEmail ?? l10n.sentRecipient;
    final bannerMsg = isRejected
        ? l10n.bannerRejectedRequest(recipient)
        : l10n.bannerCancelledRequest(recipient);

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
              bannerMsg,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (c.targetEmail != null)
              Text(c.targetEmail!, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: Text(l10n.dismiss),
          ),
          FilledButton.tonal(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              setState(() => _tabIndex = 2);
            },
            child: Text(l10n.seeAction),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  void _showVerifiedBanner(SentStatusChange change) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    final c = change.challenge;
    final name = c.subjectFullName ?? c.targetEmail ?? l10n.sentRecipient;

    messenger.showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF1B5E20).withAlpha(30),
          child: const Icon(
            Icons.verified_rounded,
            color: Color(0xFF2E7D32),
            size: 22,
          ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.bannerVerifiedRequest(name),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (c.targetEmail != null)
              Text(c.targetEmail!, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: Text(l10n.dismiss),
          ),
          FilledButton.tonal(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              setState(() => _tabIndex = 2);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VerificationDetailScreen(challenge: c),
                ),
              );
            },
            child: Text(l10n.seeAction),
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
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final unseenCount = _inbox.unseenCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Image.asset(
          'assets/images/logo_dark.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded),
            color: cs.onSurface,
            iconSize: 24,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountProfileScreen()),
            ),
          ),
        ],
      ),
      // QRScannerScreen is mounted/unmounted on tab switch so the OS camera
      // session is fully released when leaving tab 0.
      // The other three tabs use IndexedStack so their state survives tab changes.
      body: Column(
        children: [
          // ── Offline banner ───────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            height: _isOffline ? 38 : 0,
            color: const Color(0xFFB71C1C),
            child: _isOffline
                ? SafeArea(
                    top: false,
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 7),
                        Text(
                          l10n.homeOfflineBanner,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // ── Tab content ──────────────────────────────────────────────────
          Expanded(
            child: Stack(
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
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: cs.surface,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: l10n.homeTabScan,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: l10n.homeTabCreateQr,
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
            label: l10n.homeTabInbox,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search_rounded),
            label: l10n.homeTabSearch,
          ),
        ],
      ),
    );
  }
}
