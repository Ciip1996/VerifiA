import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shared identity-media widgets used by both the sent-verification detail screen
/// and the received-verification receipt (Ticket) screen. Extracted so the two
/// screens render biometric evidence identically.

/// Opens a full-screen, pinch-to-zoom photo viewer.
void openPhoto(BuildContext context, Uint8List bytes, String title) {
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

/// A photo with a rounded frame and a "Ver" zoom-hint badge that opens [openPhoto].
class TappablePhoto extends StatelessWidget {
  const TappablePhoto({
    super.key,
    required this.bytes,
    required this.fit,
    required this.label,
    this.height,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final String label;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => openPhoto(context, bytes, label),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(bytes, width: double.infinity, height: height, fit: fit),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(l10n.seeAction,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown when no FaceTec biometric match score is available.
class ScoreUnavailable extends StatelessWidget {
  const ScoreUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
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
              l10n.verificationDetailScoreUnavailable,
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.verificationDetailScoreUnavailableDesc,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withAlpha(180)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// FaceTec biometric match score card (color-coded by score band).
class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (Color color, String label) = switch (score) {
      >= 90 => (const Color(0xFF2E7D32), l10n.scoreExcellent),
      >= 75 => (const Color(0xFF558B2F), l10n.scoreVeryHigh),
      >= 60 => (const Color(0xFFF57F17), l10n.scoreAcceptable),
      >= 40 => (const Color(0xFFE65100), l10n.scoreLow),
      _     => (const Color(0xFFC62828), l10n.scoreInsufficient),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
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
              l10n.verificationDetailScoreCaption,
              style: TextStyle(fontSize: 11, color: color.withAlpha(180)),
            ),
          ]),
        ),
      ]),
    );
  }
}
