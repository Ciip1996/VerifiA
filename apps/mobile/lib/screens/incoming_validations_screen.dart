import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/feedback_service.dart';
import '../services/inbox_service.dart';
import '../services/sent_challenges_service.dart';
import 'presence_challenge_screen.dart';
import 'receipt_detail_screen.dart';
import 'verification_detail_screen.dart';

/// Displays pending verification requests (Recibidas) and sent requests (Enviadas).
class IncomingValidationsScreen extends StatelessWidget {
  const IncomingValidationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          tabs: [
            Tab(text: l10n.inboxTabReceived),
            Tab(text: l10n.inboxTabSent),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const Expanded(
          child: TabBarView(children: [
            _ReceivedTab(),
            _SentTab(),
          ]),
        ),
      ]),
    );
  }
}

// ─── Recibidas ────────────────────────────────────────────────────────────────

class _ReceivedTab extends StatefulWidget {
  const _ReceivedTab();

  @override
  State<_ReceivedTab> createState() => _ReceivedTabState();
}

class _ReceivedTabState extends State<_ReceivedTab> with AutomaticKeepAliveClientMixin {
  final _inbox = InboxService.instance;
  final _api = ApiService();
  bool _initialLoad = true;

  List<IncomingHistoryItem> _history = [];
  bool _historyLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _inbox.addListener(_onInboxUpdate);
    // If service already has data, no longer waiting for initial load.
    if (_inbox.items.isNotEmpty) _initialLoad = false;
    _loadHistory();
  }

  @override
  void dispose() {
    _inbox.removeListener(_onInboxUpdate);
    super.dispose();
  }

  void _onInboxUpdate() {
    if (!mounted) return;
    setState(() => _initialLoad = false);
  }

  Future<void> _loadHistory() async {
    try {
      final items = await _api.getIncomingHistory();
      if (!mounted) return;
      setState(() {
        _history = items;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_inbox.refresh(), _loadHistory()]);
  }

  void _openHistory(IncomingHistoryItem item) {
    if (item.receiptId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReceiptDetailScreen.fromId(item.receiptId!)),
    );
  }

  void _open(IncomingChallenge c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PresenceChallengeScreen(nonce: c.nonce, verifierId: c.verifierId),
    ));
  }

  Future<void> _reject(IncomingChallenge c) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inboxRejectTitle),
        content: Text(
          l10n.inboxRejectContent(c.requesterFullName ?? c.requesterEmail ?? l10n.bannerAnonymous),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: Text(l10n.inboxRejectButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.rejectChallenge(c.nonce);
      _inbox.removeItem(c.nonce);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inboxRejectedSnack), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, context))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = _inbox.items;

    if (_initialLoad && items.isEmpty && _historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Pending requests + a "Historial" section of terminal ones (with tap-to-Ticket
    // when a receipt was issued). Both live in one scroll view so the whole tab
    // pulls to refresh together.
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Pending ────────────────────────────────────────────────────
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mark_email_unread_outlined, size: 52, color: cs.onSurfaceVariant.withAlpha(128)),
                const SizedBox(height: 14),
                Text(l10n.inboxEmptyReceived, style: tt.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  l10n.inboxEmptyReceivedDesc,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ]),
            )
          else
            ...items.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReceivedCard(
                    challenge: c,
                    isInProgress: c.status == 'IN_PROGRESS',
                    onVerify: () => _open(c),
                    onReject: () => _reject(c),
                  ),
                )),

          // ── Historial ──────────────────────────────────────────────────
          const SizedBox(height: 8),
          Row(children: [
            Text(l10n.inboxHistoryTitle,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 10),
          if (_historyLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history_rounded, size: 44, color: cs.onSurfaceVariant.withAlpha(110)),
                const SizedBox(height: 10),
                Text(
                  l10n.inboxHistoryEmpty,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ]),
            )
          else
            ..._history.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HistoryCard(item: h, onTap: () => _openHistory(h)),
                )),
        ],
      ),
    );
  }
}

// ─── Historial card (terminal incoming request) ───────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.onTap});

  final IncomingHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasReceipt = item.receiptId != null;

    final (Color chipColor, String chipLabel, IconData chipIcon) = switch (item.status) {
      'USED'      => (const Color(0xFF2E7D32), l10n.sentStatusUsed,      Icons.check_circle_rounded),
      'EXPIRED'   => (const Color(0xFF757575), l10n.sentStatusExpired,   Icons.schedule_rounded),
      'REJECTED'  => (const Color(0xFFC62828), l10n.sentStatusRejected,  Icons.cancel_rounded),
      'CANCELLED' => (const Color(0xFF757575), l10n.sentStatusCancelled, Icons.block_rounded),
      _           => (const Color(0xFF757575), item.status,             Icons.info_outline_rounded),
    };

    final name = item.requesterFullName ?? item.requesterEmail ?? l10n.inboxAnonymousRequest;

    Widget avatar() {
      if (item.requesterProfilePhoto != null && item.requesterProfilePhoto!.isNotEmpty) {
        try {
          return CircleAvatar(
            radius: 20,
            backgroundImage: MemoryImage(base64Decode(item.requesterProfilePhoto!)),
          );
        } catch (_) {}
      }
      return CircleAvatar(
        radius: 20,
        backgroundColor: cs.surfaceContainerHighest,
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
        ),
      );
    }

    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(_fmtDate(item.verifiedAt ?? item.createdAt),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chipColor.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: chipColor.withAlpha(80)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(chipIcon, size: 12, color: chipColor),
                const SizedBox(width: 4),
                Text(chipLabel, style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (hasReceipt) ...[
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_rounded, size: 13, color: cs.primary),
                const SizedBox(width: 3),
                Text(l10n.inboxHistoryViewTicket,
                    style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600)),
              ]),
            ],
          ]),
        ]),
      ),
    );

    if (!hasReceipt) return card;
    return InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: card);
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Received card with live countdown progress bar ───────────────────────────

class _ReceivedCard extends StatefulWidget {
  const _ReceivedCard({
    required this.challenge,
    required this.onVerify,
    required this.onReject,
    this.isInProgress = false,
  });
  final IncomingChallenge challenge;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  final bool isInProgress;

  @override
  State<_ReceivedCard> createState() => _ReceivedCardState();
}

class _ReceivedCardState extends State<_ReceivedCard> {
  Timer? _ticker;
  late Duration _remaining;
  late Duration _total;

  @override
  void initState() {
    super.initState();
    _compute();
    // Tick every 10 seconds — fine-grained enough for a minute display
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _compute());
    });
  }

  void _compute() {
    final expiresAt = DateTime.tryParse(widget.challenge.expiresAt);
    if (expiresAt == null) {
      _remaining = Duration.zero;
      _total = const Duration(minutes: 30);
      return;
    }
    final now = DateTime.now();
    _remaining = expiresAt.difference(now);
    if (_remaining.isNegative) _remaining = Duration.zero;

    // Estimate total TTL: use createdAt if available, else assume 30 min
    final createdAt = DateTime.tryParse(widget.challenge.createdAt);
    _total = createdAt != null
        ? expiresAt.difference(createdAt)
        : const Duration(minutes: 30);
    if (_total.inSeconds <= 0) _total = const Duration(minutes: 30);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final c = widget.challenge;
    final isExpired = _remaining.inSeconds <= 0;
    final pct = (_remaining.inSeconds / _total.inSeconds).clamp(0.0, 1.0);

    // Progress bar color
    final Color barColor;
    if (isExpired) {
      barColor = cs.outlineVariant;
    } else if (pct > 0.5) {
      barColor = const Color(0xFF22C55E);
    } else if (pct > 0.2) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = const Color(0xFFEF4444);
    }

    // Time label
    final String timeLabel;
    if (isExpired) {
      timeLabel = l10n.inboxTimeExpired;
    } else if (_remaining.inHours >= 1) {
      timeLabel = l10n.inboxTimeHoursMinutes(_remaining.inHours, _remaining.inMinutes.remainder(60));
    } else {
      timeLabel = l10n.inboxTimeMinutes(_remaining.inMinutes);
    }

    // Avatar helper
    Widget avatar() {
      if (c.requesterProfilePhoto != null && c.requesterProfilePhoto!.isNotEmpty) {
        try {
          return CircleAvatar(
            backgroundImage: MemoryImage(base64Decode(c.requesterProfilePhoto!)),
          );
        } catch (_) {}
      }
      return CircleAvatar(
        backgroundColor: isExpired ? cs.surfaceContainerHighest : cs.primaryContainer,
        child: Text(
          (c.requesterEmail?.substring(0, 1) ?? '?').toUpperCase(),
          style: TextStyle(
            color: isExpired ? cs.onSurfaceVariant : cs.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isExpired ? cs.outlineVariant.withAlpha(100) : cs.outlineVariant,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(children: [
          // Card body
          Opacity(
            opacity: isExpired ? 0.55 : 1.0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Row(children: [
                avatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      c.requesterFullName ?? c.requesterEmail ?? l10n.inboxAnonymousRequest,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isExpired ? cs.onSurfaceVariant : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.requesterEmail != null && c.requesterFullName != null)
                      Text(
                        c.requesterEmail!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isExpired ? cs.onSurfaceVariant : barColor,
                        fontWeight: isExpired ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.inboxExpiredLabel,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    FilledButton(
                      onPressed: widget.onVerify,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(90, 36),
                      ),
                      child: Text(
                        widget.isInProgress ? l10n.inboxResumeButton : l10n.inboxVerifyButton,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton(
                      onPressed: widget.onReject,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828)),
                        minimumSize: const Size(90, 36),
                      ),
                      child: Text(l10n.inboxRejectButton, style: const TextStyle(fontSize: 13)),
                    ),
                  ]),
              ]),
            ),
          ),

          // Progress bar
          LinearProgressIndicator(
            value: isExpired ? 0.0 : pct,
            minHeight: 4,
            backgroundColor: cs.outlineVariant.withAlpha(60),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ]),
      ),
    );
  }
}

// ─── Enviadas ─────────────────────────────────────────────────────────────────

class _SentTab extends StatefulWidget {
  const _SentTab();

  @override
  State<_SentTab> createState() => _SentTabState();
}

class _SentTabState extends State<_SentTab> with AutomaticKeepAliveClientMixin {
  final _sentService = SentChallengesService.instance;
  List<SentChallenge> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sentService.addListener(_onServiceUpdate);
    // If the service already has data, use it immediately
    if (_sentService.items.isNotEmpty) {
      _items = _sentService.items.where(_shouldShow).toList();
      _loading = false;
    } else {
      _load();
    }
  }

  // Show targeted challenges always; show open (no email) ones only when completed.
  static bool _shouldShow(SentChallenge c) =>
      c.targetEmail != null || c.status == 'USED';

  @override
  void dispose() {
    _sentService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {
      _items = _sentService.items.where(_shouldShow).toList();
      _loading = false;
    });
  }

  Future<void> _cancel(SentChallenge c) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.inboxCancelTitle),
        content: Text(
          l10n.inboxCancelContent(c.targetEmail ?? l10n.sentRecipient),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.inboxKeepButton)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.inboxCancelButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService().cancelChallenge(c.nonce);
      _sentService.updateStatus(c.nonce, 'CANCELLED');
      FeedbackService.sent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inboxCancelledSnack), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, context))),
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _sentService.refresh();
      if (!mounted) return;
      setState(() { _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = friendlyError(e, context); });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
          ]),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.send_outlined, size: 56, color: cs.onSurfaceVariant.withAlpha(128)),
            const SizedBox(height: 16),
            Text(l10n.inboxEmptySent, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              l10n.inboxEmptySentDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = _items[i];
          return _SentCard(
            challenge: c,
            cs: cs,
            onCancel: (c.status == 'PENDING' || c.status == 'IN_PROGRESS') ? () => _cancel(c) : null,
          );
        },
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.challenge, required this.cs, this.onCancel});

  final SentChallenge challenge;
  final ColorScheme cs;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = challenge.status;
    final isCompleted = status == 'USED';
    final hasPhoto = challenge.subjectPhoto != null && challenge.subjectPhoto!.isNotEmpty;

    final (Color chipColor, String chipLabel, IconData chipIcon) = switch (status) {
      'USED'        => (const Color(0xFF2E7D32), l10n.sentStatusUsed,       Icons.check_circle_rounded),
      'IN_PROGRESS' => (const Color(0xFF1565C0), l10n.sentStatusInProgress, Icons.sync_rounded),
      'EXPIRED'     => (const Color(0xFF757575), l10n.sentStatusExpired,    Icons.schedule_rounded),
      'REJECTED'    => (const Color(0xFFC62828), l10n.sentStatusRejected,   Icons.cancel_rounded),
      'CANCELLED'   => (const Color(0xFF757575), l10n.sentStatusCancelled,  Icons.block_rounded),
      _             => (const Color(0xFFF57F17), l10n.sentStatusPending,    Icons.hourglass_top_rounded),
    };

    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCompleted ? const Color(0xFF2E7D32).withAlpha(80) : cs.outlineVariant,
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.primaryContainer,
            backgroundImage: hasPhoto
                ? MemoryImage(base64Decode(challenge.subjectPhoto!))
                : null,
            child: hasPhoto
                ? null
                : Text(
                    (challenge.subjectFullName?.substring(0, 1) ??
                            challenge.targetEmail?.substring(0, 1) ??
                            '?')
                        .toUpperCase(),
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                challenge.subjectFullName ?? challenge.targetEmail ?? l10n.sentRecipient,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (challenge.subjectFullName != null && challenge.targetEmail != null)
                Text(
                  challenge.targetEmail!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Text(
                _formatDate(challenge.createdAt, l10n),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          // Status chip + cancel icon (horizontal) + chevron for completed
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chipColor.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: chipColor.withAlpha(80)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(chipIcon, size: 12, color: chipColor),
                const SizedBox(width: 4),
                Text(chipLabel, style: TextStyle(fontSize: 11, color: chipColor, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (onCancel != null) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton.outlined(
                  onPressed: onCancel,
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  style: IconButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withAlpha(100)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.inboxCancelTooltip,
                ),
              ),
            ],
            if (isCompleted) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
            ],
          ]),
        ]),
      ),
    );

    if (!isCompleted) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerificationDetailScreen(challenge: challenge),
        ),
      ),
      child: card,
    );
  }

  String _formatDate(String isoDate, AppLocalizations l10n) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return l10n.sentTimeAgoMinutes(diff.inMinutes);
      if (diff.inHours < 24) return l10n.sentTimeAgoHours(diff.inHours);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
