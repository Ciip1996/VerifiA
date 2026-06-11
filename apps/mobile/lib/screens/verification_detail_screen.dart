import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Full detail view for a completed (USED) sent verification request.
/// Shows who verified, when, their selfie, their ID photo, and FaceTec score.
class VerificationDetailScreen extends StatelessWidget {
  const VerificationDetailScreen({super.key, required this.challenge});

  final SentChallenge challenge;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Formats an ISO-8601 date string to local time in Spanish without
  /// requiring locale initialization (avoids the raw "Z" string bug).
  static String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} de ${months[dt.month - 1]} ${dt.year}, $h:$m';
    } catch (_) {
      return iso;
    }
  }

  static String _idLabel(String? idType) {
    return switch (idType) {
      'INE'      => 'INE / IFE',
      'PASSPORT' => 'Pasaporte',
      _          => idType ?? 'Desconocido',
    };
  }

  /// Opens a full-screen photo viewer with pinch-to-zoom.
  static void _openPhoto(BuildContext context, Uint8List bytes, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6.0,
              child: Image.memory(bytes),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasSelfie   = challenge.subjectPhoto?.isNotEmpty == true;
    final hasSnapshot = challenge.livenessSnapshot?.isNotEmpty == true;
    final hasIdPhoto  = challenge.subjectIdFrontPhoto?.isNotEmpty == true;
    final score       = challenge.livenessMatchScore;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: cs.surfaceContainerHighest,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasSelfie)
                    GestureDetector(
                      onTap: () => _openPhoto(
                        context,
                        base64Decode(challenge.subjectPhoto!),
                        'Foto de registro',
                      ),
                      child: Stack(fit: StackFit.expand, children: [
                        Image.memory(
                          base64Decode(challenge.subjectPhoto!),
                          fit: BoxFit.cover,
                        ),
                        // Zoom hint in top-right so it doesn't overlap the name overlay
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(140),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Ver', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      ]),
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primaryContainer, cs.secondaryContainer],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20, right: 20, bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF4CAF50), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Verificación completada',
                            style: tt.labelMedium?.copyWith(color: Colors.white70),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          challenge.subjectFullName ?? challenge.targetEmail ?? 'Usuario',
                          style: tt.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [const Shadow(blurRadius: 8, color: Colors.black)],
                          ),
                        ),
                        if (challenge.targetEmail != null)
                          Text(
                            challenge.targetEmail!,
                            style: tt.bodySmall?.copyWith(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Timestamps ──────────────────────────────────────────────
                _InfoCard(
                  icon: Icons.schedule_rounded,
                  children: [
                    _Row('Solicitud enviada', _fmt(challenge.createdAt)),
                    if (challenge.validatedAt != null)
                      _Row('Verificado el', _fmt(challenge.validatedAt!)),
                    _Row('Tipo de ID', _idLabel(challenge.subjectIdType)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── FaceTec match score ──────────────────────────────────────
                Text('Puntuación biométrica', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                score != null
                    ? _ScoreCard(score: score, cs: cs)
                    : _ScoreUnavailable(cs: cs),
                const SizedBox(height: 16),

                // ── Liveness snapshot ────────────────────────────────────────
                if (hasSnapshot) ...[
                  Text('Selfie de verificación', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _TappablePhoto(
                    bytes: base64Decode(challenge.livenessSnapshot!),
                    height: 200,
                    fit: BoxFit.cover,
                    label: 'Selfie de verificación',
                    onTap: (bytes) => _openPhoto(context, bytes, 'Selfie de verificación'),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── ID photo ─────────────────────────────────────────────────
                if (hasIdPhoto) ...[
                  Text('Identificación presentada', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _TappablePhoto(
                    bytes: base64Decode(challenge.subjectIdFrontPhoto!),
                    fit: BoxFit.fitWidth,
                    label: 'Identificación presentada',
                    onTap: (bytes) => _openPhoto(context, bytes, 'Identificación presentada'),
                  ),
                ],

              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable photo with zoom-hint overlay ─────────────────────────────────────

class _TappablePhoto extends StatelessWidget {
  const _TappablePhoto({
    required this.bytes,
    required this.fit,
    required this.label,
    required this.onTap,
    this.height,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final String label;
  final void Function(Uint8List) onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(bytes),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              bytes,
              width: double.infinity,
              height: height,
              fit: fit,
            ),
            // Zoom hint badge in bottom-right corner
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Ver', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.children});

  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
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

class _ScoreUnavailable extends StatelessWidget {
  const _ScoreUnavailable({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Icon(Icons.face_retouching_off_rounded, size: 36, color: cs.onSurfaceVariant.withAlpha(120)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'No disponible',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              'El match FaceTec no generó puntuación en esta sesión (modo desarrollo o SDK no configurado).',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withAlpha(180)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.cs});

  final int score;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (score) {
      >= 90 => (const Color(0xFF2E7D32), 'Excelente'),
      >= 75 => (const Color(0xFF558B2F), 'Muy alto'),
      >= 60 => (const Color(0xFFF57F17), 'Aceptable'),
      >= 40 => (const Color(0xFFE65100), 'Bajo'),
      _     => (const Color(0xFFC62828), 'Insuficiente'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        // Score circle with % sign
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(25),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Center(
            child: Text(
              '$score%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                color: color,
                backgroundColor: color.withAlpha(30),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Match cara vs. ID presentado',
              style: TextStyle(fontSize: 11, color: color.withAlpha(180)),
            ),
          ]),
        ),
      ]),
    );
  }
}
