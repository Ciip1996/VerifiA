import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';
import '../widgets/identity_media.dart';
import '../widgets/qr_share.dart';

/// Unified display status derived from the offline (Level-1) and server
/// (Level-2) checks.
enum _TicketState { valid, expired, invalid, malformed, notFound, loading }

/// The "Ticket" — a shareable, self-verifying proof that a verification happened.
///
/// Two-tier verification:
///   1. Offline ES256 signature check (instant, works with no network).
///   2. Server confirmation for the live status + owner-only identity media.
///
/// Open with [ReceiptDetailScreen.fromJwt] (deep link / QR / paste / share) or
/// [ReceiptDetailScreen.fromId] (push notification / history row).
class ReceiptDetailScreen extends StatefulWidget {
  final String? receiptJwt;
  final String? receiptId;

  /// Injectable for tests; production uses the default [ReceiptService].
  final ReceiptService? service;

  const ReceiptDetailScreen.fromJwt(String this.receiptJwt, {super.key, this.service})
      : receiptId = null;
  const ReceiptDetailScreen.fromId(String this.receiptId, {super.key, this.service})
      : receiptJwt = null;

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late final ReceiptService _service = widget.service ?? ReceiptService();
  final GlobalKey _shareKey = GlobalKey();

  LocalReceiptResult? _local;
  ReceiptServerResult? _server;
  bool _loadingServer = true;
  bool _serverUnreachable = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingServer = true;
      _serverUnreachable = false;
    });

    // Level 1 — offline signature check (only when we hold the full JWT).
    if (widget.receiptJwt != null) {
      _local = _service.verifyLocally(widget.receiptJwt!);
      if (mounted) setState(() {});
    }

    // Level 2 — server confirmation.
    try {
      final result = widget.receiptJwt != null
          ? await _service.confirmWithServer(widget.receiptJwt!)
          : await _service.confirmById(widget.receiptId!);
      if (!mounted) return;
      setState(() {
        _server = result;
        _loadingServer = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingServer = false;
        // If we have a valid offline result, treat this as "offline, unconfirmed";
        // otherwise surface it as a hard failure below.
        _serverUnreachable = true;
      });
    }
  }

  // ── Derived display state ──────────────────────────────────────────────────

  _TicketState get _state {
    if (_server != null) {
      return switch (_server!.status) {
        'VALID' => _TicketState.valid,
        'EXPIRED' => _TicketState.expired,
        'NOT_FOUND' => _TicketState.notFound,
        _ => _TicketState.invalid,
      };
    }
    // No server result — fall back to the offline check.
    if (_local != null) {
      return switch (_local!.status) {
        LocalReceiptStatus.authentic => _TicketState.valid,
        LocalReceiptStatus.expired => _TicketState.expired,
        LocalReceiptStatus.invalid => _TicketState.invalid,
        LocalReceiptStatus.malformed => _TicketState.malformed,
      };
    }
    // Id-only lookup still in flight, or unreachable with no offline fallback.
    if (_loadingServer) return _TicketState.loading;
    return _serverUnreachable ? _TicketState.invalid : _TicketState.notFound;
  }

  String? get _subjectName => _server?.subjectName ?? _local?.claims?.subjectName;
  String? get _verifiedAt => _server?.verifiedAt ?? _local?.claims?.verifiedAt;
  String? get _validFrom => _server?.badgeValidFrom ?? _local?.claims?.badgeValidFrom;
  String? get _validUntil => _server?.badgeValidUntil ?? _local?.claims?.badgeValidUntil;
  ReceiptIdentity? get _identity => _server?.identity;

  // A valid offline result that we couldn't confirm with the server.
  bool get _showOfflineNote =>
      _serverUnreachable &&
      _server == null &&
      _local != null &&
      (_local!.status == LocalReceiptStatus.authentic ||
          _local!.status == LocalReceiptStatus.expired);

  // ── Formatting ─────────────────────────────────────────────────────────────

  static String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
    } catch (_) {
      return iso;
    }
  }

  static String _idLabel(String? idType, AppLocalizations l10n) => switch (idType) {
        'INE' => l10n.idTypeINE,
        'PASSPORT' => l10n.idTypePassport,
        _ => idType ?? l10n.idTypeUnknown,
      };

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(l10n.receiptTitle),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: _state == _TicketState.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _StatusBanner(
                    state: _state,
                    offlineNote: _showOfflineNote,
                  ),
                  const SizedBox(height: 20),
                  ..._buildBody(context, l10n, cs),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildBody(BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    final state = _state;

    if (state == _TicketState.malformed || state == _TicketState.invalid || state == _TicketState.notFound) {
      // Nothing trustworthy to display beyond the banner.
      return [
        if (state == _TicketState.notFound && widget.receiptJwt == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.tonal(onPressed: _load, child: Text(l10n.retry)),
            ),
          ),
      ];
    }

    final tt = Theme.of(context).textTheme;
    final identity = _identity;

    return [
      // ── Core facts ──────────────────────────────────────────────────────
      _InfoCard(children: [
        if (_subjectName != null && _subjectName!.isNotEmpty)
          _KV(l10n.receiptSubjectLabel, _subjectName!),
        _KV(l10n.receiptVerifiedAtLabel, _fmt(_verifiedAt)),
        _KV(l10n.receiptValidityLabel, '${_fmt(_validFrom)}  →  ${_fmt(_validUntil)}'),
      ]),

      // ── Owner-only identity block ───────────────────────────────────────
      if (identity != null) ...[
        const SizedBox(height: 20),
        Text(l10n.receiptIdentityTitle, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _InfoCard(children: [
          _KV(l10n.idTypeLabelShort, _idLabel(identity.idType, l10n)),
          if (identity.curp != null && identity.curp!.isNotEmpty)
            _KV(l10n.curpLabel, identity.curp!),
          if (identity.dateOfBirth != null && identity.dateOfBirth!.isNotEmpty)
            _KV(l10n.birthDateLabel, identity.dateOfBirth!),
        ]),

        if (identity.livenessMatchScore != null) ...[
          const SizedBox(height: 16),
          Text(l10n.receiptScoreTitle, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ScoreCard(score: identity.livenessMatchScore!),
        ],

        if (identity.livenessSnapshot != null && identity.livenessSnapshot!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.receiptSelfieLabel, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TappablePhoto(
            bytes: base64Decode(identity.livenessSnapshot!),
            height: 200,
            fit: BoxFit.cover,
            label: l10n.receiptSelfieLabel,
          ),
        ],

        if (identity.idFrontPhoto != null && identity.idFrontPhoto!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.receiptIdLabel, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TappablePhoto(
            bytes: base64Decode(identity.idFrontPhoto!),
            fit: BoxFit.fitWidth,
            label: l10n.receiptIdLabel,
          ),
        ],
      ],

      // ── Scan-me QR (only when we hold the JWT) ──────────────────────────
      if (widget.receiptJwt != null) ...[
        const SizedBox(height: 28),
        Text(
          l10n.receiptScanMe,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: 'verifia://receipt?jwt=${widget.receiptJwt}',
              version: QrVersions.auto,
              size: 200,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            key: _shareKey,
            onPressed: _sharing ? null : _shareTicket,
            icon: _sharing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(l10n.receiptShareQr),
          ),
        ),
      ],
    ];
  }

  Future<void> _shareTicket() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sharing = true);
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final ok = await shareQrPng(
      context,
      qrData: 'verifia://receipt?jwt=${widget.receiptJwt}',
      text: l10n.badgeShareMessage,
      sharePositionOrigin: origin,
    );
    if (!mounted) return;
    setState(() => _sharing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.badgeShareError)));
    }
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, required this.offlineNote});

  final _TicketState state;
  final bool offlineNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (Color color, IconData icon, String title, String desc) = switch (state) {
      _TicketState.valid => (
          const Color(0xFF22C55E),
          Icons.verified_user_rounded,
          l10n.receiptStatusValid,
          l10n.receiptStatusValidDesc,
        ),
      _TicketState.expired => (
          const Color(0xFFF59E0B),
          Icons.history_rounded,
          l10n.receiptStatusExpired,
          l10n.receiptStatusExpiredDesc,
        ),
      _TicketState.invalid => (
          const Color(0xFFEF4444),
          Icons.gpp_bad_rounded,
          l10n.receiptStatusInvalid,
          l10n.receiptStatusInvalidDesc,
        ),
      _TicketState.malformed => (
          const Color(0xFFEF4444),
          Icons.error_outline_rounded,
          l10n.receiptStatusMalformed,
          l10n.receiptStatusMalformedDesc,
        ),
      _TicketState.notFound => (
          const Color(0xFF757575),
          Icons.search_off_rounded,
          l10n.receiptStatusNotFound,
          l10n.receiptStatusNotFoundDesc,
        ),
      _TicketState.loading => (
          const Color(0xFF757575),
          Icons.hourglass_empty_rounded,
          '',
          '',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 52),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: TextStyle(color: color.withAlpha(220), fontSize: 13),
        ),
        if (offlineNote) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: color.withAlpha(200)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l10n.receiptOfflineNote,
                style: TextStyle(color: color.withAlpha(200), fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Small building blocks ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 2,
          child: Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Expanded(
          flex: 3,
          child: Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
