import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

/// Shown after onboarding success. Lets the user set an email + password
/// to create their identity-linked web account.
class SetPasswordScreen extends StatefulWidget {
  final String deviceId;
  const SetPasswordScreen({super.key, required this.deviceId});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  bool _showPassword = false;
  String? _errorMsg;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      final data = await _api.setPassword(
        deviceId: widget.deviceId,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // Store email so challenge creation uses correct verifier_id
      await _storage.write(key: 'verifia_account_email', value: _emailCtrl.text.trim());
      if (data['account_id'] != null) {
        await _storage.write(key: 'verifia_account_id', value: data['account_id'] as String);
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() {
        _errorMsg = friendlyError(e, context);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Icon(Icons.lock_person_rounded, size: 52, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.setPasswordTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.setPasswordSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.loginEmailLabel,
                    hintText: l10n.loginEmailHint,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.loginEmailRequired;
                    final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!re.hasMatch(v.trim())) return l10n.loginEmailInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    hintText: l10n.setPasswordPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) return l10n.setPasswordPasswordMinLength;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: l10n.setPasswordConfirmLabel,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return l10n.setPasswordPasswordMismatch;
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                if (_errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_errorMsg!, style: TextStyle(color: cs.onErrorContainer)),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.setPasswordCreateButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
