import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

/// Full detail view for a completed (USED) sent verification request.
/// Shows who verified, when, their selfie, their ID photo, and FaceTec score.
class VerificationDetailScreen extends StatelessWidget {
  const VerificationDetailScreen({super.key, required this.challenge});

  final SentChallenge challenge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasSelfie = challenge.subjectPhoto?.isNotEmpty == true;
    final hasSnapshot = challenge.livenessSnapshot?.isNotEmpty == true;
    final hasIdPhoto = challenge.subjectIdFrontPhoto?.isNotEmpty == true;
    final score = challenge.livenessMatchScore;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: cs.surfaceContainerHighest,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background — selfie if available, else gradient
                  if (hasSelfie)
                    Image.memory(
                      base64Decode(challenge.subjectPhoto!),
                      fit: BoxFit.cover,
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
                  // Gradient overlay so text is readable
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  // Name + badge
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
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

                // ── Timestamps ────────────────────────────────────────────
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

                // ── FaceTec match score ────────────────────────────────────
                if (score != null) ...[
                  Text('Puntuación biométrica', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _ScoreCard(score: score, cs: cs),
                  const SizedBox(height: 16),
                ],

                // ── Liveness snapshot ─────────────────────────────────────
                if (hasSnapshot) ...[
                  Text('Selfie de verificación', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      base64Decode(challenge.livenessSnapshot!),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── ID photo ─────────────────────────────────────────────
                if (hasIdPhoto) ...[
                  Text('Identificación presentada', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      base64Decode(challenge.subjectIdFrontPhoto!),
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ],

              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat("d 'de' MMMM yyyy, HH:mm", 'es_MX').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _idLabel(String? idType) {
    return switch (idType) {
      'INE' => 'INE / IFE',
      'PASSPORT' => 'Pasaporte',
      _ => idType ?? 'Desconocido',
    };
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
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
      _ => (const Color(0xFFC62828), 'Insuficiente'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        // Score circle
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(25),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Center(
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 22,
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
              'Coincidencia biométrica FaceTec',
              style: TextStyle(fontSize: 11, color: color.withAlpha(180)),
            ),
          ]),
        ),
      ]),
    );
  }
}
