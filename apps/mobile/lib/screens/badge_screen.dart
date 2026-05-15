import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'qr_scanner_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const QRScannerScreen()),
            (_) => false,
          ),
        ),
        title: const Text('Badge de Presencia', style: TextStyle(color: Colors.white)),
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
                      _isExpired ? 'BADGE EXPIRADO' : 'PRESENCIA VERIFICADA',
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
                        'Expira en',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Badge details
              _DetailTile(
                label: 'Verificador',
                value: widget.tokenResponse.badgeDisplay['verifier'] ?? '-',
              ),
              _DetailTile(
                label: 'Emitido',
                value: _formatTime(widget.tokenResponse.badgeDisplay['issued_at'] ?? ''),
              ),
              _DetailTile(
                label: 'Expira',
                value: _formatTime(widget.tokenResponse.badgeDisplay['expires_at'] ?? ''),
              ),
              _DetailTile(
                label: 'Badge ID',
                value: (widget.tokenResponse.badgeDisplay['jti'] ?? '').substring(0, 8) + '...',
                monospace: true,
              ),

              const Spacer(),

              // Copy JWT button
              if (!_isExpired)
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.tokenResponse.token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JWT copiado al portapapeles')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar JWT'),
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
