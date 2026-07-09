import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/identity_media.dart';

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

  static String _idLabel(String? idType, AppLocalizations l10n) {
    return switch (idType) {
      'INE'      => l10n.idTypeINE,
      'PASSPORT' => l10n.idTypePassport,
      _          => idType ?? l10n.idTypeUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      onTap: () => openPhoto(
                        context,
                        base64Decode(challenge.subjectPhoto!),
                        l10n.verificationDetailSelfieLabel,
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
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(l10n.seeAction, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
                            l10n.verificationDetailCompleted,
                            style: tt.labelMedium?.copyWith(color: Colors.white70),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          challenge.subjectFullName ?? challenge.targetEmail ?? l10n.verificationDetailUser,
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
                    _Row(l10n.verificationDetailRequestSent, _fmt(challenge.createdAt)),
                    if (challenge.validatedAt != null)
                      _Row(l10n.verificationDetailVerifiedOn, _fmt(challenge.validatedAt!)),
                    _Row(l10n.verificationDetailIdType, _idLabel(challenge.subjectIdType, l10n)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── FaceTec match score ──────────────────────────────────────
                Text(l10n.verificationDetailBiometricScore, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                score != null
                    ? ScoreCard(score: score)
                    : const ScoreUnavailable(),
                const SizedBox(height: 16),

                // ── Liveness snapshot ────────────────────────────────────────
                if (hasSnapshot) ...[
                  Text(l10n.verificationDetailVerifySelfie, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TappablePhoto(
                    bytes: base64Decode(challenge.livenessSnapshot!),
                    height: 200,
                    fit: BoxFit.cover,
                    label: l10n.verificationDetailVerifySelfie,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── ID photo ─────────────────────────────────────────────────
                if (hasIdPhoto) ...[
                  Text(l10n.verificationDetailIdPresented, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TappablePhoto(
                    bytes: base64Decode(challenge.subjectIdFrontPhoto!),
                    fit: BoxFit.fitWidth,
                    label: l10n.verificationDetailIdPresented,
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

