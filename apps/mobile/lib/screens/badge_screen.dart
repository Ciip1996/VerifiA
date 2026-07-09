import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/qr_share.dart';

/// Badge screen — displays the issued JWT badge with a countdown timer.
/// Also shows a QR of the JWT so the verifier can scan it (optional flow).
class BadgeScreen extends StatefulWidget {
  final IssueTokenResponse tokenResponse;

  const BadgeScreen({super.key, required this.tokenResponse});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsLeft = 0;
  late AnimationController _pulseController;
  final GlobalKey _shareQrKey = GlobalKey();
  bool _sharingQr = false;

  @override
  void initState() {
    super.initState();

    final expiresAt = DateTime.parse(widget.tokenResponse.expiresAt);
    _secondsLeft = expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 600);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = DateTime.parse(widget.tokenResponse.expiresAt)
          .difference(DateTime.now())
          .inSeconds
          .clamp(0, 600);
      if (!mounted) return;
      setState(() => _secondsLeft = remaining);
      if (remaining == 0) {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isExpired => _secondsLeft <= 0;

  String get _formattedTime {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: Text(l10n.badgeTitle, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _isExpired ? const Color(0xFF1A0A0A) : const Color(0xFF0A1A10),
                  border: Border.all(
                    color: _isExpired ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Icon(
                        _isExpired ? Icons.cancel_outlined : Icons.verified_user,
                        color: _isExpired
                            ? const Color(0xFFEF4444)
                            : Color.lerp(
                                const Color(0xFF22C55E),
                                const Color(0xFF16A34A),
                                _pulseController.value,
                              ),
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isExpired ? l10n.badgeExpired : l10n.badgeVerified,
                      style: TextStyle(
                        color: _isExpired ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isExpired ? '00:00' : _formattedTime,
                      style: TextStyle(
                        color: _secondsLeft < 60 ? const Color(0xFFEF4444) : Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (!_isExpired)
                      Text(
                        l10n.badgeExpiresIn,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Badge details
              _DetailTile(
                label: l10n.badgeVerifierLabel,
                value: widget.tokenResponse.badgeDisplay['verifier'] ?? '-',
              ),
              _DetailTile(
                label: l10n.badgeIssuedLabel,
                value: _formatTime(widget.tokenResponse.badgeDisplay['issued_at'] ?? ''),
              ),
              _DetailTile(
                label: l10n.badgeExpiresLabel,
                value: _formatTime(widget.tokenResponse.badgeDisplay['expires_at'] ?? ''),
              ),
              _DetailTile(
                label: l10n.badgeIdLabel,
                value: (widget.tokenResponse.badgeDisplay['jti'] ?? '').substring(0, 8) + '...',
                monospace: true,
              ),

              const Spacer(),

              // Persistent share section — the durable receipt (constancia) can
              // be shared as a scannable QR image, as a deep link, or copied.
              if (widget.tokenResponse.receipt != null)
                _buildShareSection(l10n, widget.tokenResponse.receipt!)
              else if (!_isExpired)
                // Fallback (non-P2P badge with no receipt): copy the raw JWT.
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.tokenResponse.token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.badgeCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(l10n.badgeCopyJwt),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Color(0xFF2A2A38)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareSection(AppLocalizations l10n, ReceiptSummary receipt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.badgeShareTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.badgeShareSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: _shareQrKey,
          onPressed: _sharingQr ? null : () => _shareReceiptQr(l10n, receipt),
          icon: _sharingQr
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.qr_code_2_rounded, size: 18),
          label: Text(l10n.badgeShareQr),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00EAF2),
            foregroundColor: const Color(0xFF06142A),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _shareReceiptLink(receipt),
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: Text(l10n.badgeShareLink),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Color(0xFF2A2A38)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _copyReceiptLink(l10n, receipt),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(l10n.badgeCopyLink),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Color(0xFF2A2A38)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _shareReceiptQr(AppLocalizations l10n, ReceiptSummary receipt) async {
    setState(() => _sharingQr = true);
    final box = _shareQrKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final ok = await shareQrPng(
      context,
      qrData: receipt.deepLink,
      text: l10n.badgeShareMessage,
      sharePositionOrigin: origin,
    );
    if (!mounted) return;
    setState(() => _sharingQr = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.badgeShareError)),
      );
    }
  }

  void _shareReceiptLink(ReceiptSummary receipt) {
    final box = _shareQrKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    SharePlus.instance.share(
      ShareParams(text: receipt.deepLink, sharePositionOrigin: origin),
    );
  }

  void _copyReceiptLink(AppLocalizations l10n, ReceiptSummary receipt) {
    Clipboard.setData(ClipboardData(text: receipt.deepLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.badgeLinkCopied)),
    );
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '-';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _DetailTile({required this.label, required this.value, this.monospace = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: monospace ? 'Courier' : null,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
