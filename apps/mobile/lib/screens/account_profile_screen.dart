import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class AccountProfileScreen extends StatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  State<AccountProfileScreen> createState() => _AccountProfileScreenState();
}

class _AccountProfileScreenState extends State<AccountProfileScreen> {
  late Future<AccountProfile> _profileFuture;
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _profileFuture = ApiService().fetchMe();
  }

  void _retry() => setState(() => _profileFuture = ApiService().fetchMe());

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileLogoutTitle),
        content: Text(l10n.profileLogoutContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profileLogoutButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ApiService.clearSession();
    await _storage.delete(key: 'verifia_account_email');
    await _storage.delete(key: 'verifia_account_id');

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _LoginBridge()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
      ),
      body: FutureBuilder<AccountProfile>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _buildError(cs, snap.error.toString(), l10n);
          }
          return _buildProfile(cs, snap.data!, l10n);
        },
      ),
    );
  }

  Widget _buildError(ColorScheme cs, String message, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: cs.error),
          const SizedBox(height: 16),
          Text(
            l10n.profileLoadError,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message.replaceFirst('Exception: ', ''),
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ]),
      ),
    );
  }

  Widget _buildProfile(ColorScheme cs, AccountProfile profile, AppLocalizations l10n) {
    final hasPhoto = profile.profilePhoto != null && profile.profilePhoto!.isNotEmpty;
    final initials = _initials(profile.fullName ?? profile.email);
    final isVerified = profile.idType != null;

    return SafeArea(
      child: Column(
        children: [
          // Static header — does NOT scroll
          _buildProfileHeader(cs, profile, hasPhoto, initials, isVerified, l10n),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      _infoTile(
                        icon: Icons.email_outlined,
                        label: l10n.profileEmailLabel,
                        value: profile.email,
                        cs: cs,
                        isFirst: true,
                      ),
                      if (profile.idType != null) ...[
                        const Divider(height: 1, indent: 56),
                        _infoTile(
                          icon: Icons.credit_card_rounded,
                          label: l10n.profileIdTypeLabel,
                          value: profile.idType == 'INE' ? l10n.idTypeINE : l10n.idTypePassport,
                          cs: cs,
                        ),
                      ],
                      if (profile.curp != null && profile.curp!.isNotEmpty) ...[
                        const Divider(height: 1, indent: 56),
                        _infoTile(
                          icon: Icons.fingerprint_rounded,
                          label: l10n.profileCurpLabel,
                          value: profile.curp!,
                          monospace: true,
                          cs: cs,
                        ),
                      ],
                      if (profile.dateOfBirth != null && profile.dateOfBirth!.isNotEmpty) ...[
                        const Divider(height: 1, indent: 56),
                        _infoTile(
                          icon: Icons.cake_outlined,
                          label: l10n.profileBirthDateLabel,
                          value: profile.dateOfBirth!,
                          cs: cs,
                          isLast: true,
                        ),
                      ],
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // Static logout button at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: _buildLogoutButton(cs, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    ColorScheme cs,
    AccountProfile profile,
    bool hasPhoto,
    String initials,
    bool isVerified,
    AppLocalizations l10n,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.primaryContainer.withAlpha(128),
            cs.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: cs.primaryContainer,
            backgroundImage: hasPhoto
                ? MemoryImage(base64Decode(profile.profilePhoto!))
                : null,
            child: hasPhoto
                ? null
                : Text(
                    initials,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            profile.fullName ?? profile.email.split('@').first,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (isVerified)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_rounded, size: 14, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                l10n.profileVerifiedBadge,
                style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(ColorScheme cs, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: Icon(Icons.logout_rounded, color: cs.error),
        label: Text(l10n.profileLogoutButtonLabel, style: TextStyle(color: cs.error)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: cs.error.withAlpha(128)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme cs,
    bool monospace = false,
    bool isFirst = false,
    bool isLast = false,
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
          fontFamily: monospace ? 'monospace' : null,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    if (parts.first.isNotEmpty) return parts.first[0].toUpperCase();
    return '?';
  }
}

// Thin bridge used after logout — avoids importing HomeScreen's private _LoginScreen
class _LoginBridge extends StatelessWidget {
  const _LoginBridge();

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
