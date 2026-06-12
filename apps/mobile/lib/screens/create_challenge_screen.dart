import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../services/feedback_service.dart';

enum _SendMode { open, targeted }

/// Tab screen for generating a QR verification challenge.
///
/// Two modes:
///   open     — anonymous QR shared via the OS share sheet (PNG + text)
///   targeted — directed at a specific user by email; autocompletes registered
///              users and falls back to a Resend invitation for non-registered ones.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _api = ApiService();
  final _emailCtrl = TextEditingController();
  final _shareButtonKey = GlobalKey();

  // Mode
  _SendMode _mode = _SendMode.open;

  // Generation
  bool _loading = false;
  String? _errorMsg;
  Map<String, dynamic>? _challenge;

  // Countdown
  DateTime? _expiresAt;
  int _timeLeft = 0;
  int _timerTotal = 600;
  bool _timerActive = false;

  // Share
  bool _sharing = false;

  // Email autocomplete
  List<PublicAccountSummary> _suggestions = [];
  bool? _targetIsRegistered; // null = unknown, true = found, false = not registered

  // Invite email
  bool _sendingInvite = false;
  bool _inviteSent = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _timerActive = true;
    _tick();
  }

  void _tick() {
    if (!mounted || !_timerActive || _expiresAt == null) return;
    final remaining = _expiresAt!.difference(DateTime.now()).inSeconds;
    final t = math.max(0, remaining);
    setState(() => _timeLeft = t);
    if (t > 0) {
      Future.delayed(const Duration(milliseconds: 500), _tick);
    } else {
      _timerActive = false;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _challenge = null);
      });
    }
  }

  // ── Mode ───────────────────────────────────────────────────────────────────

  void _setMode(_SendMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _suggestions = [];
      _targetIsRegistered = null;
      _inviteSent = false;
      if (mode == _SendMode.open) _emailCtrl.clear();
    });
  }

  // ── Email autocomplete ─────────────────────────────────────────────────────

  void _onEmailChanged() {
    final q = _emailCtrl.text.trim();
    setState(() {
      _targetIsRegistered = null;
      _inviteSent = false;
    });
    if (q.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_emailCtrl.text.trim() == q) _fetchSuggestions(q);
    });
  }

  Future<void> _fetchSuggestions(String q) async {
    try {
      final results = await _api.searchAccounts(q);
      if (!mounted) return;
      setState(() => _suggestions = results);
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  void _pickSuggestion(PublicAccountSummary user) {
    _emailCtrl.text = user.email;
    _emailCtrl.selection = TextSelection.collapsed(offset: user.email.length);
    setState(() {
      _suggestions = [];
      _targetIsRegistered = true;
    });
    FocusScope.of(context).unfocus();
  }

  // ── Challenge generation ───────────────────────────────────────────────────

  Future<void> _generate() async {
    final targetEmail = _mode == _SendMode.targeted ? _emailCtrl.text.trim() : null;

    // Resolve registered status from suggestions if still unknown
    if (targetEmail != null && targetEmail.isNotEmpty && _targetIsRegistered == null) {
      _targetIsRegistered = _suggestions
          .any((u) => u.email.toLowerCase() == targetEmail.toLowerCase());
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
      _challenge = null;
      _suggestions = [];
    });

    try {
      final data = await _api.createChallenge(
        targetEmail: targetEmail?.isNotEmpty == true ? targetEmail : null,
      );
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 600;
      final expiresAt = DateTime.tryParse(data['expires_at'] as String? ?? '');
      setState(() {
        _challenge = data;
        _loading = false;
        _timeLeft = expiresIn;
        _timerTotal = expiresIn;
        _expiresAt = expiresAt;
        _inviteSent = false;
      });
      _startCountdown();
      FeedbackService.sent();

      if (mounted && _mode == _SendMode.targeted && targetEmail != null && targetEmail.isNotEmpty) {
        final msg = _targetIsRegistered == true
            ? 'Solicitud enviada a $targetEmail'
            : 'QR generado — envía la invitación a $targetEmail';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      setState(() {
        _errorMsg = friendlyError(e);
        _loading = false;
      });
    }
  }

  // ── Share ──────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    final qrData = _challenge?['qr_data'] as String?;
    // Prefer the HTTPS redirect URL (clickable in WhatsApp/iMessage); fall back to deep link
    final shareUrl = (_challenge?['redirect_url'] as String?)?.isNotEmpty == true
        ? _challenge!['redirect_url'] as String
        : _challenge?['deep_link'] as String? ?? '';
    final expiresAt = DateTime.tryParse(_challenge?['expires_at'] as String? ?? '');
    if (qrData == null || qrData.isEmpty || _sharing) return;

    setState(() => _sharing = true);
    File? tmpFile;
    try {
      const size = 900.0;
      const padding = 48.0;
      const qrSize = size - padding * 2;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, size, size),
        Paint()..color = Colors.white,
      );

      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );
      canvas.save();
      canvas.translate(padding, padding);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('No se pudo generar la imagen');

      tmpFile = File(
        '${Directory.systemTemp.path}/verifia_qr_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tmpFile.writeAsBytes(byteData.buffer.asUint8List());

      final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(100, 600, 200, 50);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tmpFile.path, mimeType: 'image/png', name: 'verifia_qr.png')],
          text: _buildShareText(shareUrl, expiresAt),
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo compartir: $e')),
        );
      }
    } finally {
      tmpFile?.deleteSync();
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _buildShareText(String deepLink, DateTime? expiresAt) {
    String expStr = 'pronto';
    if (expiresAt != null) {
      final dt = expiresAt.toLocal();
      const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      expStr = '${dt.day} de ${months[dt.month - 1]} ${dt.year} a las $h:$m';
    }
    return '🔐 Te pido que verifiques tu identidad con VerifiA\n\n'
        'Sigue estos pasos:\n'
        '1. Descarga la app VerifiA (próximamente en App Store)\n'
        '2. Crea tu cuenta y completa el registro con tu INE\n'
        '3. Abre el QR adjunto o toca el enlace directo:\n'
        '   $deepLink\n\n'
        '⏱ Este QR expira el $expStr\n\n'
        'VerifiA — verificación de identidad criptográfica efímera.';
  }

  // ── Invite (Resend) ────────────────────────────────────────────────────────

  Future<void> _sendInvite() async {
    final email = _emailCtrl.text.trim();
    final nonce = _challenge?['nonce'] as String?;
    if (email.isEmpty || nonce == null) return;

    setState(() => _sendingInvite = true);
    try {
      await _api.sendInvite(nonce: nonce, email: email);
      if (mounted) setState(() { _inviteSent = true; _sendingInvite = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _sendingInvite = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: ${friendlyError(e)}')),
        );
      }
    }
  }

  void _copyLink() {
    final link = (_challenge?['redirect_url'] as String?)?.isNotEmpty == true
        ? _challenge!['redirect_url'] as String
        : _challenge?['deep_link'] as String? ?? '';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado al portapapeles'), duration: Duration(seconds: 2)),
    );
  }

  void _reset() {
    _timerActive = false;
    setState(() {
      _challenge = null;
      _emailCtrl.clear();
      _targetIsRegistered = null;
      _inviteSent = false;
      _expiresAt = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Solicitar verificación'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: _challenge == null ? _buildForm(cs) : _buildQRView(cs),
      ),
    );
  }

  // ── Form (pre-generation) ──────────────────────────────────────────────────

  Widget _buildForm(ColorScheme cs) {
    final isTargeted = _mode == _SendMode.targeted;
    final email = _emailCtrl.text.trim();
    final hasEmail = email.isNotEmpty;
    final emailValid = !isTargeted || _isValidEmail(email);
    final isRegistered = _targetIsRegistered == true;
    final isUnregistered = _targetIsRegistered == false;

    // Button is disabled in targeted mode until a valid email is entered
    final canGenerate = !_loading && emailValid;

    // Button label
    final String buttonLabel;
    if (!isTargeted) {
      buttonLabel = 'Generar QR';
    } else if (!hasEmail) {
      buttonLabel = 'Ingresa un correo para continuar';
    } else if (!emailValid) {
      buttonLabel = 'Correo inválido';
    } else if (isRegistered) {
      buttonLabel = 'Enviar solicitud';
    } else {
      buttonLabel = 'Generar y preparar invitación';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          '¿Cómo quieres enviar la solicitud?',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 14),

        // ── Mode selector cards ──────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _ModeCard(
              icon: Icons.qr_code_2_rounded,
              title: 'QR Abierto',
              description: 'Comparte el QR o el link con cualquier app',
              selected: _mode == _SendMode.open,
              onTap: () => _setMode(_SendMode.open),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ModeCard(
              icon: Icons.send_rounded,
              title: 'Enviar a usuario',
              description: 'Directo a alguien, por app o correo',
              selected: _mode == _SendMode.targeted,
              onTap: () => _setMode(_SendMode.targeted),
            ),
          ),
        ]),

        // ── Email field (targeted mode only) ──────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: isTargeted
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Correo del destinatario',
                        hintText: 'nombre@ejemplo.com',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        suffixIcon: hasEmail && _targetIsRegistered != null
                            ? Icon(
                                isRegistered ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                color: isRegistered ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                              )
                            : null,
                      ),
                    ),

                    // Autocomplete dropdown
                    if (_suggestions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _SuggestionsDropdown(
                        suggestions: _suggestions,
                        onPick: _pickSuggestion,
                      ),
                    ],

                    // Status badge
                    if (hasEmail && _targetIsRegistered != null) ...[
                      const SizedBox(height: 10),
                      _StatusBadge(
                        isRegistered: isRegistered,
                        email: email,
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 24),

        // Error
        if (_errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_errorMsg!, style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
          ),
          const SizedBox(height: 14),
        ],

        // Generate button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canGenerate ? _generate : null,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.qr_code_2_rounded),
            label: Text(_loading ? 'Generando…' : buttonLabel, textAlign: TextAlign.center),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        // Contextual hint below button
        const SizedBox(height: 12),
        Text(
          isTargeted
              ? !hasEmail
                  ? 'El correo del destinatario es obligatorio.'
                  : !emailValid
                      ? 'Ingresa un correo con formato válido (ej. nombre@ejemplo.com).'
                      : isRegistered
                          ? 'La solicitud aparecerá en la app del destinatario.'
                          : isUnregistered
                              ? 'Después de generar, podrás enviarle una invitación por correo.'
                              : 'Si el correo no está en VerifiA, le enviaremos una invitación.'
              : 'El QR estará activo 30 minutos. Compártelo por WhatsApp, iMessage o cualquier app.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── QR display (post-generation) ───────────────────────────────────────────

  Widget _buildQRView(ColorScheme cs) {
    final isExpired = _timeLeft <= 0;
    final targetEmail = _mode == _SendMode.targeted ? _emailCtrl.text.trim() : null;
    final showInviteButton = !isExpired
        && _mode == _SendMode.targeted
        && targetEmail != null
        && targetEmail.isNotEmpty
        && _targetIsRegistered == false;

    // Title & subtitle based on mode/state
    final String title;
    final String subtitle;
    if (isExpired) {
      title = 'QR expirado';
      subtitle = 'Genera uno nuevo para continuar';
    } else if (_mode == _SendMode.open) {
      title = 'QR listo para compartir';
      subtitle = 'Comparte el código o el link por cualquier app';
    } else if (_targetIsRegistered == true && targetEmail != null) {
      title = 'Solicitud enviada';
      subtitle = 'La solicitud está en la app de $targetEmail';
    } else if (_targetIsRegistered == false && targetEmail != null) {
      title = 'QR generado';
      subtitle = 'Envía la invitación por correo para que descargue la app';
    } else {
      title = 'QR listo';
      subtitle = 'Comparte el código o el link';
    }

    return Center(
      child: Column(children: [
        const SizedBox(height: 8),

        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isExpired ? cs.error : null,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Countdown ring
        _CountdownRing(timeLeft: _timeLeft, total: _timerTotal),
        const SizedBox(height: 20),

        // QR code
        AnimatedOpacity(
          opacity: isExpired ? 0.25 : 1.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
              ],
            ),
            child: QrImageView(
              data: _challenge!['qr_data'] as String,
              version: QrVersions.auto,
              size: 220,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Action buttons
        if (!isExpired) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            FilledButton.tonalIcon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar link'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: _shareButtonKey,
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Compartir'),
            ),
          ]),

          // Invite non-registered user
          if (showInviteButton) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _inviteSent
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Invitación enviada',
                        style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w600),
                      ),
                    ])
                  : OutlinedButton.icon(
                      onPressed: _sendingInvite ? null : _sendInvite,
                      icon: _sendingInvite
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                            )
                          : const Icon(Icons.mark_email_unread_outlined, size: 18),
                      label: Text(_sendingInvite ? 'Enviando…' : 'Enviar invitación por correo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),
          ],
        ],

        const SizedBox(height: 20),
        TextButton(
          onPressed: _reset,
          child: Text(isExpired ? 'Generar nuevo QR' : 'Cancelar y volver'),
        ),
      ]),
    );
  }
}

// ── Mode selection card ───────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.18)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 26,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? cs.primary : cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: selected ? cs.primary.withValues(alpha: 0.75) : cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Autocomplete dropdown ─────────────────────────────────────────────────────

class _SuggestionsDropdown extends StatelessWidget {
  const _SuggestionsDropdown({required this.suggestions, required this.onPick});

  final List<PublicAccountSummary> suggestions;
  final ValueChanged<PublicAccountSummary> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: suggestions.take(5).toList().asMap().entries.map((entry) {
          final user = entry.value;
          final isLast = entry.key == (suggestions.length - 1).clamp(0, 4);
          ImageProvider? imageProvider;
          if (user.profilePhoto != null && user.profilePhoto!.isNotEmpty) {
            try {
              imageProvider = MemoryImage(base64Decode(user.profilePhoto!));
            } catch (_) {}
          }
          return Column(
            children: [
              InkWell(
                onTap: () => onPick(user),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? Text(
                              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(user.email,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    Icon(Icons.person_add_alt_1_rounded, size: 16, color: cs.primary),
                  ]),
                ),
              ),
              if (!isLast) Divider(height: 1, indent: 14, color: cs.outlineVariant),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isRegistered, required this.email});

  final bool isRegistered;
  final String email;

  @override
  Widget build(BuildContext context) {
    final color = isRegistered ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    final icon = isRegistered ? Icons.check_circle_rounded : Icons.info_outline_rounded;
    final label = isRegistered
        ? 'Usuario registrado — recibirá la solicitud en la app'
        : 'No está en VerifiA — podrás enviarle una invitación por correo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

// ── Countdown ring ────────────────────────────────────────────────────────────

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.timeLeft, required this.total});

  final int timeLeft;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (timeLeft / total).clamp(0.0, 1.0) : 0.0;
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    final isExpired = timeLeft <= 0;

    final Color color;
    if (isExpired) {
      color = Theme.of(context).colorScheme.error;
    } else if (pct < 0.2) {
      color = const Color(0xFFEF4444);
    } else if (pct < 0.4) {
      color = const Color(0xFFF59E0B);
    } else {
      color = const Color(0xFF22C55E);
    }

    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 6,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(
            child: isExpired
                ? Icon(Icons.timer_off_rounded, color: color, size: 30)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'restantes',
                      style: TextStyle(fontSize: 8, color: color.withAlpha(180)),
                    ),
                  ]),
          ),
        ],
      ),
    );
  }
}
