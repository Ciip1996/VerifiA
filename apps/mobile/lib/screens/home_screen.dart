import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/app_attest_service.dart' show AppAttestService;
import '../services/feedback_service.dart';
import '../services/inbox_service.dart';
import '../services/notification_dedupe.dart';
import '../services/onesignal_service.dart';
import '../services/sent_challenges_service.dart';
import 'account_profile_screen.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';
import 'create_challenge_screen.dart';
import 'incoming_validations_screen.dart';
import 'receipt_detail_screen.dart';
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

  /// Drives which sub-tab (0 = Recibidas, 1 = Enviadas) is shown inside the
  /// Activity tab. Notified when a notification about a sent challenge is
  /// tapped/opened so the user lands on the relevant sub-tab instead of
  /// always defaulting to Recibidas.
  final _activityTabSwitch = ValueNotifier<int>(0);

  /// Push `data.type` values this screen has dedicated in-app handling for.
  static const _knownPushTypes = {
    'CHALLENGE_INVITE',
    'CHALLENGE_IN_PROGRESS',
    'CHALLENGE_REJECTED',
    'CHALLENGE_CANCELLED',
    'CHALLENGE_USED',
    'VERIFICATION_COMPLETED_SELF',
  };

  bool get _isOffline => _inbox.isOffline || _sent.isOffline;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _inbox.addListener(_onInboxChanged);
    _inbox.start();
    _sent.addListener(_onSentChanged);
    _sent.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OneSignalService().initialize();
        OneSignalService().setupSubscriptionVerification(context);
        OneSignalService().addClickListener(_onNotificationClick);
        OneSignalService().addForegroundListener(_onForegroundNotification);
        const skipAttest = bool.fromEnvironment('VERIFIA_SKIP_ATTEST', defaultValue: false);
        if (!skipAttest) {
          unawaited(AppAttestService().registerIfNeeded(ApiService()));
        }
      }
    });
  }

  /// Handles a tapped push notification (background/closed case). When the
  /// payload carries a receipt_id (a completed verification), open the
  /// Ticket directly; otherwise route to the Activity tab, landing on the
  /// sub-tab relevant to the notification type (Enviadas for notifications
  /// about a challenge *we* sent, Recibidas otherwise).
  void _onNotificationClick(dynamic event) {
    if (!mounted) return;
    final data = event.notification.additionalData;
    final type = data is Map ? data['type'] as String? : null;
    final receiptId = data is Map ? data['receipt_id'] as String? : null;
    if (receiptId != null && receiptId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReceiptDetailScreen.fromId(receiptId)),
      );
      return;
    }
    setState(() => _tabIndex = 2);
    if (_isSentSideType(type)) {
      _activityTabSwitch.value = 1;
    } else {
      _activityTabSwitch.value = 0;
      _inbox.markAllSeen();
    }
  }

  static bool _isSentSideType(String? type) =>
      type == 'CHALLENGE_IN_PROGRESS' ||
      type == 'CHALLENGE_REJECTED' ||
      type == 'CHALLENGE_USED';

  /// Maps a push `type` to the challenge-status vocabulary used by
  /// [SentChallengesService]'s poll-based transition detection, so both
  /// paths can dedupe against the same key. Returns null for types that
  /// have no polling-based fallback counterpart (no collision risk).
  static String? _statusKeyForType(String type) {
    switch (type) {
      case 'CHALLENGE_IN_PROGRESS':
        return 'IN_PROGRESS';
      case 'CHALLENGE_REJECTED':
        return 'REJECTED';
      case 'CHALLENGE_CANCELLED':
        return 'CANCELLED';
      case 'CHALLENGE_USED':
        return 'USED';
      default:
        return null;
    }
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'CHALLENGE_IN_PROGRESS':
        return Icons.hourglass_top_rounded;
      case 'CHALLENGE_REJECTED':
        return Icons.cancel_rounded;
      case 'CHALLENGE_CANCELLED':
        return Icons.block_rounded;
      case 'CHALLENGE_USED':
      case 'VERIFICATION_COMPLETED_SELF':
        return Icons.verified_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static Color _colorForType(String type) {
    switch (type) {
      case 'CHALLENGE_IN_PROGRESS':
        return const Color(0xFF1565C0);
      case 'CHALLENGE_REJECTED':
        return const Color(0xFFC62828);
      case 'CHALLENGE_CANCELLED':
        return const Color(0xFF757575);
      case 'CHALLENGE_USED':
      case 'VERIFICATION_COMPLETED_SELF':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF616161);
    }
  }

  void _onEventBannerTap(String type, String? receiptId) {
    if (receiptId != null && receiptId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReceiptDetailScreen.fromId(receiptId)),
      );
      return;
    }
    setState(() => _tabIndex = 2);
    if (_isSentSideType(type)) {
      _activityTabSwitch.value = 1;
    } else {
      _activityTabSwitch.value = 0;
      _inbox.markAllSeen();
    }
  }

  /// Handles a push notification arriving while the app is in the foreground.
  /// OneSignal displays a native banner automatically for every push unless
  /// we intervene. For every lifecycle event we recognize we suppress the
  /// native banner and show our own in-app banner immediately — using the
  /// push's own (already-localized) title/body — then silently refresh the
  /// relevant polling service so list state stays in sync. A shared dedupe
  /// guard ([NotificationDedupe]) ensures the polling services' independent
  /// transition detection (kept as a fallback for missed/delayed pushes)
  /// never shows a second banner for the same event.
  void _onForegroundNotification(dynamic event) {
    final notification = event.notification;
    final data = notification.additionalData;
    final type = data is Map ? data['type'] as String? : null;
    if (type == null || !_knownPushTypes.contains(type)) return;

    event.preventDefault();

    final nonce = data is Map ? data['nonce'] as String? : null;
    final receiptId = data is Map ? data['receipt_id'] as String? : null;
    final statusKey = _statusKeyForType(type);
    final alreadyShown = nonce != null &&
        statusKey != null &&
        !NotificationDedupe.instance.tryMark('$nonce:$statusKey');

    switch (type) {
      case 'CHALLENGE_INVITE':
        // The richer avatar banner (requester photo/name) is shown by
        // _onInboxChanged once polling notices the new arrival — just force
        // an immediate poll instead of waiting for the next 5s tick.
        _inbox.refresh();
        return;
      case 'CHALLENGE_CANCELLED':
      case 'VERIFICATION_COMPLETED_SELF':
        _inbox.refresh();
        break;
      case 'CHALLENGE_IN_PROGRESS':
      case 'CHALLENGE_REJECTED':
      case 'CHALLENGE_USED':
        _sent.refresh();
        break;
    }

    if (alreadyShown) return;

    _showEventBanner(
      icon: _iconForType(type),
      color: _colorForType(type),
      title: notification.title as String? ?? '',
      body: notification.body as String? ?? '',
      onTap: () => _onEventBannerTap(type, receiptId),
    );
  }

  @override
  void dispose() {
    _inbox.removeListener(_onInboxChanged);
    _sent.removeListener(_onSentChanged);
    _activityTabSwitch.dispose();
    super.dispose();
  }

  void _onInboxChanged() {
    if (!mounted) return;
    setState(() {});

    // Show in-app banner only when the user is NOT already on the inbox tab.
    // Guarded by the shared dedupe set as a safety net in case a duplicate/
    // redelivered push already forced a refresh that produced this same
    // "new arrival" — in practice this path is the only one that ever fires
    // for CHALLENGE_INVITE, so this is mostly defensive.
    final newChallenge = _inbox.consumeLatestNew();
    if (newChallenge != null &&
        _tabIndex != 2 &&
        NotificationDedupe.instance.tryMark('${newChallenge.nonce}:NEW')) {
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

  /// Poll-based fallback for status changes on challenges the user SENT.
  /// [SentChallengesService] detects these transitions independently of
  /// push (up to its 8s poll interval later), so this only shows a banner
  /// if the equivalent push-driven banner hasn't already fired for the same
  /// nonce+status — see [NotificationDedupe].
  void _onSentChanged() {
    if (!mounted) return;
    setState(() {});

    final change = _sent.consumeLatestChange();
    if (change == null) return;
    if (!NotificationDedupe.instance
        .tryMark('${change.challenge.nonce}:${change.newStatus}')) {
      return;
    }

    FeedbackService.incoming();
    final l10n = AppLocalizations.of(context)!;
    final c = change.challenge;
    final recipient = c.subjectFullName ?? c.targetEmail ?? l10n.sentRecipient;

    if (change.newStatus == 'USED') {
      _showEventBanner(
        icon: Icons.verified_rounded,
        color: const Color(0xFF2E7D32),
        title: l10n.bannerVerifiedRequest(recipient),
        body: c.targetEmail ?? '',
        onTap: () {
          setState(() => _tabIndex = 2);
          _activityTabSwitch.value = 1;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VerificationDetailScreen(challenge: c)),
          );
        },
      );
    } else {
      final isRejected = change.newStatus == 'REJECTED';
      _showEventBanner(
        icon: isRejected ? Icons.cancel_rounded : Icons.block_rounded,
        color: isRejected ? const Color(0xFFC62828) : const Color(0xFF757575),
        title: isRejected
            ? l10n.bannerRejectedRequest(recipient)
            : l10n.bannerCancelledRequest(recipient),
        body: c.targetEmail ?? '',
        onTap: () {
          setState(() => _tabIndex = 2);
          _activityTabSwitch.value = 1;
        },
      );
    }
  }

  /// Unified in-app banner used for every lifecycle event except the
  /// incoming-request one (which keeps its own richer avatar variant, see
  /// [_showInAppBanner]).
  void _showEventBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();

    messenger.showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color, size: 22),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 12)),
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
              onTap();
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

      final profile = await ApiService().fetchMe();
      if (!mounted) return;
      setState(() => _fullName = profile.fullName ?? profile.email.split('@').first);
      await _storage.write(key: 'verifia_account_email', value: profile.email);
      if (profile.id.isNotEmpty) {
        await _storage.write(key: 'verifia_account_id', value: profile.id);
      }
    } catch (e) {
      if (ApiService.isUnauthorized(e) && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
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
                    children: [
                      const CreateChallengeScreen(),
                      IncomingValidationsScreen(switchToTab: _activityTabSwitch),
                      const UserSearchScreen(),
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
