import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'public_user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  List<PublicAccountSummary> _results = [];
  bool _searching = false;
  String? _error;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    _debounce?.cancel();

    if (query.length < 2) {
      setState(() { _results = []; _searching = false; _error = null; });
      return;
    }

    setState(() { _searching = true; _error = null; });
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await _api.searchAccounts(query);
      if (!mounted) return;
      setState(() { _results = results; _searching = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _searching = false;
      });
    }
  }

  void _openProfile(PublicAccountSummary user) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PublicUserProfileScreen(accountId: user.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(children: [
      // ── Search field ─────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SearchBar(
          controller: _searchCtrl,
          focusNode: _focusNode,
          hintText: 'Buscar por nombre o correo…',
          leading: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.search_rounded),
          ),
          trailing: [
            if (_searchCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchCtrl.clear();
                  _focusNode.requestFocus();
                },
              ),
          ],
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant),
            ),
          ),
          backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
        ),
      ),

      // ── Progress bar ─────────────────────────────────────────────────────
      if (_searching)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: cs.primary,
          ),
        )
      else
        const SizedBox(height: 6),

      // ── Body ─────────────────────────────────────────────────────────────
      Expanded(child: _buildBody(cs)),
    ]);
  }

  Widget _buildBody(ColorScheme cs) {
    final query = _searchCtrl.text.trim();

    // Empty state — no query yet
    if (query.length < 2 && !_searching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_search_rounded, size: 64, color: cs.onSurfaceVariant.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              'Busca usuarios de VerifiA',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe al menos 2 caracteres para buscar por nombre o correo electrónico.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _search(query),
              child: const Text('Reintentar'),
            ),
          ]),
        ),
      );
    }

    // No results
    if (!_searching && _results.isEmpty && query.length >= 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant.withAlpha(128)),
            const SizedBox(height: 12),
            Text(
              'Sin resultados para "$query"',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Intenta con otro nombre o correo.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    // Results list
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final user = _results[i];
        return _UserResultCard(user: user, onTap: () => _openProfile(user));
      },
    );
  }
}

class _UserResultCard extends StatelessWidget {
  const _UserResultCard({required this.user, required this.onTap});

  final PublicAccountSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPhoto = user.profilePhoto != null && user.profilePhoto!.isNotEmpty;
    final initials = _initials(user.fullName);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              backgroundImage: hasPhoto
                  ? MemoryImage(base64Decode(user.profilePhoto!))
                  : null,
              child: hasPhoto
                  ? null
                  : Text(
                      initials,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
            ),
            const SizedBox(width: 14),

            // Name + email
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.isSelf) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Tú', style: TextStyle(fontSize: 10, color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),

            // ID type chip + chevron
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (user.idType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.idType == 'INE' ? 'INE' : 'Pasaporte',
                    style: TextStyle(fontSize: 10, color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 4),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 18),
            ]),
          ]),
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
