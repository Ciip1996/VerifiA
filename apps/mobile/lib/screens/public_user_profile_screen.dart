import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class PublicUserProfileScreen extends StatefulWidget {
  const PublicUserProfileScreen({super.key, required this.accountId});

  final String accountId;

  @override
  State<PublicUserProfileScreen> createState() => _PublicUserProfileScreenState();
}

class _PublicUserProfileScreenState extends State<PublicUserProfileScreen> {
  final _api = ApiService();
  late Future<PublicAccountProfile> _profileFuture;

  bool _requestSent = false;
  bool _sendingRequest = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _api.fetchPublicProfile(widget.accountId);
  }

  Future<void> _sendRequest(String targetEmail) async {
    setState(() => _sendingRequest = true);
    try {
      await _api.createChallenge(targetEmail: targetEmail);
      if (!mounted) return;
      setState(() { _requestSent = true; _sendingRequest = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Solicitud de verificación enviada'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<PublicAccountProfile>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_off_rounded, size: 56, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudo cargar el perfil',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),
            );
          }
          return _buildContent(context, snap.data!);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, PublicAccountProfile profile) {
    final cs = Theme.of(context).colorScheme;
    final hasPhoto = profile.profilePhoto.isNotEmpty;
    final initials = _initials(profile.fullName);
    final age = _calculateAge(profile.dateOfBirth);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Collapsible hero ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: cs.surface,
            leading: BackButton(color: cs.onSurface),
            title: Text(
              profile.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cs.primaryContainer.withAlpha(100), cs.surface],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Selfie avatar
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage: hasPhoto
                          ? MemoryImage(base64Decode(profile.profilePhoto))
                          : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              initials,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.fullName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (age != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$age años',
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, size: 13, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Identidad verificada con FaceTec',
                        style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500),
                      ),
                    ]),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── FaceTec score card ──────────────────────────────────────
                if (profile.facetecMatchLevel != null) ...[
                  _ScoreCard(score: profile.facetecMatchLevel!, cs: cs),
                  const SizedBox(height: 16),
                ],

                // ── Info card ───────────────────────────────────────────────
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Column(children: [
                    _infoTile(
                      context: context,
                      icon: Icons.email_outlined,
                      label: 'Correo electrónico',
                      value: profile.email,
                      cs: cs,
                    ),
                    if (profile.idType != null) ...[
                      Divider(height: 1, indent: 56, color: cs.outlineVariant),
                      _infoTile(
                        context: context,
                        icon: Icons.credit_card_rounded,
                        label: 'Tipo de ID',
                        value: profile.idType == 'INE' ? 'INE / IFE' : 'Pasaporte',
                        cs: cs,
                      ),
                    ],
                    if (profile.dateOfBirth != null) ...[
                      Divider(height: 1, indent: 56, color: cs.outlineVariant),
                      _infoTile(
                        context: context,
                        icon: Icons.cake_outlined,
                        label: 'Fecha de nacimiento',
                        value: profile.dateOfBirth!,
                        cs: cs,
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),

                // ── ID photo ────────────────────────────────────────────────
                if (profile.idFrontPhoto.isNotEmpty) ...[
                  Text(
                    'Identificación oficial',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      base64Decode(profile.idFrontPhoto),
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Documento escaneado durante el registro',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),

      // ── Sticky CTA button ───────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FutureBuilder<PublicAccountProfile>(
            future: _profileFuture,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final email = snap.data!.email;
              return SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: (_requestSent || _sendingRequest)
                      ? null
                      : () => _sendRequest(email),
                  icon: _sendingRequest
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_requestSent ? Icons.check_circle_rounded : Icons.verified_user_rounded),
                  label: Text(
                    _requestSent
                        ? 'Solicitud enviada'
                        : 'Enviar solicitud de verificación',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: _requestSent ? cs.secondaryContainer : cs.primary,
                    foregroundColor: _requestSent ? cs.onSecondaryContainer : cs.onPrimary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _infoTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme cs,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withAlpha(128),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: cs.primary),
      ),
      title: Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    if (parts.first.isNotEmpty) return parts.first[0].toUpperCase();
    return '?';
  }

  int? _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return null;
    try {
      // Try common formats: YYYY-MM-DD or DD/MM/YYYY
      DateTime? dob;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(dateOfBirth)) {
        dob = DateTime.tryParse(dateOfBirth.substring(0, 10));
      } else if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(dateOfBirth)) {
        final parts = dateOfBirth.split('/');
        dob = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      if (dob == null) return null;
      final today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age > 0 && age < 120 ? age : null;
    } catch (_) {
      return null;
    }
  }
}

// ── FaceTec score card ────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.cs});

  final int score;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (score >= 70) {
      color = const Color(0xFF2E7D32); // green
      label = 'Alta coincidencia';
    } else if (score >= 40) {
      color = const Color(0xFFF57F17); // amber
      label = 'Coincidencia media';
    } else {
      color = cs.error;
      label = 'Coincidencia baja';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        // Score arc/circle
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 5,
              backgroundColor: color.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(color),
            ),
            Text(
              '$score',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.shield_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                'FaceTec ID Match',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              '$label — $score/100',
              style: TextStyle(fontSize: 12, color: color.withAlpha(200)),
            ),
            const SizedBox(height: 2),
            Text(
              'Score de coincidencia cara vs. ID al registrarse',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
      ]),
    );
  }
}
