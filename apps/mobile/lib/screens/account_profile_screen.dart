import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<AccountProfile>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _buildError(cs, snap.error.toString());
          }
          return _buildProfile(cs, snap.data!);
        },
      ),
    );
  }

  Widget _buildError(ColorScheme cs, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: cs.error),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar el perfil',
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
            label: const Text('Reintentar'),
          ),
        ]),
      ),
    );
  }

  Widget _buildProfile(ColorScheme cs, AccountProfile profile) {
    final hasPhoto = profile.profilePhoto != null && profile.profilePhoto!.isNotEmpty;
    final initials = _initials(profile.fullName ?? profile.email);
    final isVerified = profile.idType != null;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surfaceTint,
          leading: BackButton(color: cs.onSurface),
          title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Container(
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Avatar
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
                  // Name
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
                  // Verified badge
                  if (isVerified)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, size: 14, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Identidad verificada',
                        style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500),
                      ),
                    ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Info card
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  _infoTile(
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: profile.email,
                    cs: cs,
                    isFirst: true,
                  ),
                  if (profile.idType != null) ...[
                    const Divider(height: 1, indent: 56),
                    _infoTile(
                      icon: Icons.credit_card_rounded,
                      label: 'Tipo de ID',
                      value: profile.idType == 'INE' ? 'INE / IFE' : 'Pasaporte',
                      cs: cs,
                    ),
                  ],
                  if (profile.curp != null && profile.curp!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 56),
                    _infoTile(
                      icon: Icons.fingerprint_rounded,
                      label: 'CURP',
                      value: profile.curp!,
                      monospace: true,
                      cs: cs,
                    ),
                  ],
                  if (profile.dateOfBirth != null && profile.dateOfBirth!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 56),
                    _infoTile(
                      icon: Icons.cake_outlined,
                      label: 'Fecha de nacimiento',
                      value: profile.dateOfBirth!,
                      cs: cs,
                      isLast: true,
                    ),
                  ],
                ]),
              ),

              const SizedBox(height: 32),

              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: Icon(Icons.logout_rounded, color: cs.error),
                  label: Text('Cerrar sesión', style: TextStyle(color: cs.error)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: cs.error.withAlpha(128)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
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
