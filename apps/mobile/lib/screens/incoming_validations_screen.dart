import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/inbox_service.dart';
import 'presence_challenge_screen.dart';
import 'verification_detail_screen.dart';

/// Displays pending verification requests (Recibidas) and sent requests (Enviadas).
class IncomingValidationsScreen extends StatelessWidget {
  const IncomingValidationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          tabs: [
            Tab(text: 'Recibidas'),
            Tab(text: 'Enviadas'),
          ],
          labelStyle: TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(
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
  bool _initialLoad = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _inbox.addListener(_onInboxUpdate);
    // If service already has data, no longer waiting for initial load.
    if (_inbox.items.isNotEmpty) _initialLoad = false;
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

  void _open(IncomingChallenge c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PresenceChallengeScreen(nonce: c.nonce, verifierId: c.verifierId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final items = _inbox.items;

    if (_initialLoad && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mark_email_unread_outlined, size: 56, color: cs.onSurfaceVariant.withAlpha(128)),
            const SizedBox(height: 16),
            Text('Sin solicitudes recibidas', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Cuando alguien te solicite verificar tu identidad, aparecerá aquí.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _inbox.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = items[i];
          final expiresAt = DateTime.tryParse(c.expiresAt);
          final minLeft = expiresAt != null ? expiresAt.difference(DateTime.now()).inMinutes : 0;

          return Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _avatar(c, cs),
              title: Text(
                c.requesterFullName ?? c.requesterEmail ?? 'Solicitud anónima',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                c.requesterEmail != null && c.requesterFullName != null
                    ? '${c.requesterEmail} · ${minLeft}m restantes'
                    : '${minLeft}m restantes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              trailing: FilledButton(
                onPressed: () => _open(c),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Verificar'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _avatar(IncomingChallenge c, ColorScheme cs) {
    if (c.requesterProfilePhoto != null && c.requesterProfilePhoto!.isNotEmpty) {
      try {
        return CircleAvatar(
          backgroundImage: MemoryImage(base64Decode(c.requesterProfilePhoto!)),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      backgroundColor: cs.primaryContainer,
      child: Text(
        (c.requesterEmail?.substring(0, 1) ?? '?').toUpperCase(),
        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
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
  final _api = ApiService();
  List<SentChallenge> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final all = await _api.getSentChallenges();
      // Only show challenges that were sent to a specific person
      final targeted = all.where((c) => c.targetEmail != null).toList();
      if (!mounted) return;
      setState(() { _items = targeted; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
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
            Text('Sin solicitudes enviadas', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Busca a un usuario y envíale una solicitud de verificación.',
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
          return _SentCard(challenge: c, cs: cs);
        },
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.challenge, required this.cs});

  final SentChallenge challenge;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final status = challenge.status;
    final isCompleted = status == 'USED';
    final hasPhoto = challenge.subjectPhoto != null && challenge.subjectPhoto!.isNotEmpty;

    final (Color chipColor, String chipLabel, IconData chipIcon) = switch (status) {
      'USED' => (const Color(0xFF2E7D32), 'Completada', Icons.check_circle_rounded),
      'EXPIRED' => (const Color(0xFF757575), 'Expirada', Icons.schedule_rounded),
      'REJECTED' => (const Color(0xFFC62828), 'Rechazada', Icons.cancel_rounded),
      _ => (const Color(0xFFF57F17), 'Pendiente', Icons.hourglass_top_rounded),
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
                    (challenge.targetEmail?.substring(0, 1) ?? '?').toUpperCase(),
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                challenge.subjectFullName ?? challenge.targetEmail ?? 'Destinatario',
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
                _formatDate(challenge.createdAt),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          // Status chip + chevron for completed
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

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
