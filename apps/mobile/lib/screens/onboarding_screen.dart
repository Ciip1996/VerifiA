import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../services/api_service.dart';
import '../services/facetec_service.dart';
import 'set_password_screen.dart';

/// First-run onboarding screen.
/// Asks the user to pick an ID type, then launches the FaceTec Photo ID Match
/// flow to capture a selfie + ID scan. On success, registers the profile with
/// the backend and marks the device as onboarded in FlutterSecureStorage.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { form, scanning, preview, confirming, done }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _storage = const FlutterSecureStorage();
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String _idType = 'INE';

  _Step _step = _Step.form;
  String? _errorMsg;
  bool _ocrRunning = false;

  FaceTecIDMatchResult? _scanResult;

  // ─── ID match scan ────────────────────────────────────────────────────────

  Future<void> _startIDMatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _step = _Step.scanning;
      _errorMsg = null;
    });

    try {
      final result = await FaceTecService().startIDMatch(idType: _idType);
      setState(() {
        _scanResult = result;
        _step = _Step.preview;
        _ocrRunning = true;
      });
      // Run ML Kit OCR on ID photo; FaceTec dev server doesn't return OCR data
      final detectedName = await _extractNameFromPhoto(result.idFrontPhoto);
      if (mounted) {
        _nameCtrl.text = detectedName ?? result.fullName ?? '';
        setState(() => _ocrRunning = false);
      }
    } on PlatformException catch (e) {
      setState(() {
        _errorMsg = e.message ?? 'Escaneo cancelado';
        _step = _Step.form;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Error inesperado: $e';
        _step = _Step.form;
      });
    }
  }

  // ─── Profile registration ─────────────────────────────────────────────────

  Future<void> _confirmAndRegister() async {
    final scan = _scanResult;
    if (scan == null) return;

    setState(() {
      _step = _Step.confirming;
      _errorMsg = null;
    });

    try {
      // Resolve device_id from App Attest / fallback storage
      final deviceId = await _resolveDeviceId();

      final fullName = _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : 'Usuario VerifiA';

      await _api.registerProfile(
        deviceId: deviceId,
        fullName: fullName,
        idType: _idType,
        profilePhoto: scan.auditTrailImage,
        idFrontPhoto: scan.idFrontPhoto,
        curp: scan.curp,
        dateOfBirth: scan.dateOfBirth,
        idBackPhoto: scan.idBackPhoto,
        facetecMatchLevel: scan.matchLevel > 0 ? scan.matchLevel : null,
        enrollmentRefId: scan.enrollmentRefId.isNotEmpty ? scan.enrollmentRefId : null,
      );

      // Persist enrollment ID so verification can perform 3D-3D match
      if (scan.enrollmentRefId.isNotEmpty) {
        await _storage.write(
          key: 'facetec_enrollment_ref_id',
          value: scan.enrollmentRefId,
        );
      }

      await _storage.write(key: 'profile_registered', value: 'true');

      if (!mounted) return;
      setState(() => _step = _Step.done);

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // After registration, let user set up web account password
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SetPasswordScreen(deviceId: deviceId)),
      );
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _step = _Step.preview;
      });
    }
  }

  /// Runs ML Kit text recognition on the INE front photo and extracts the name.
  /// INE layout: top section has apellido paterno / apellido materno / nombre(s)
  /// all in uppercase, before the CURP line.
  Future<String?> _extractNameFromPhoto(String base64Photo) async {
    if (base64Photo.isEmpty) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    File? tmpFile;
    try {
      final bytes = base64Decode(base64Photo);
      // ML Kit requires a file path for JPEG input (fromBytes only accepts raw pixel formats)
      final tmpDir = Directory.systemTemp;
      tmpFile = File('${tmpDir.path}/verifia_id_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tmpFile.writeAsBytes(bytes);
      final inputImage = InputImage.fromFilePath(tmpFile.path);
      final result = await recognizer.processImage(inputImage);
      return _parseINEName(result.text);
    } catch (e) {
      debugPrint('[OCR] error: $e');
      return null;
    } finally {
      recognizer.close();
      tmpFile?.deleteSync();
    }
  }

  /// Parses raw OCR text from an INE card to extract the full name.
  /// Strategy: collect all-uppercase lines before the CURP line, skip short
  /// lines that look like labels (NOMBRE, APELLIDO, etc.) or single chars.
  String? _parseINEName(String rawText) {
    if (rawText.isEmpty) return null;
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Stop collecting after we hit the CURP line
    final stopWords = {'CURP', 'FOLIO', 'VIGENCIA', 'CLAVE', 'SEXO', 'ESTADO'};
    final ignoredLabels = {
      'NOMBRE', 'APELLIDO', 'PATERNO', 'MATERNO', 'APELLIDOS',
      'NOMBRE(S)', 'NOMBRES', 'INSTITUTO NACIONAL ELECTORAL',
      'CREDENCIAL PARA VOTAR',
    };

    final nameParts = <String>[];
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (stopWords.any((w) => upper.contains(w))) break;
      // Must be all-caps alphabetic (with spaces/accents), at least 3 chars
      if (!RegExp(r'^[A-ZÁÉÍÓÚÜÑ\s]{3,}$').hasMatch(upper)) continue;
      if (ignoredLabels.contains(upper.trim())) continue;
      nameParts.add(upper.trim());
      if (nameParts.length >= 3) break; // apellido pat + mat + nombre(s)
    }

    if (nameParts.isEmpty) return null;
    // Combine in Mexican order: apellidos first, then nombre
    return nameParts.join(' ');
  }

  Future<String> _resolveDeviceId() async {
    // In skip-attest mode the token always uses SKIP_ATTEST_DEVICE — match it here
    const skipAttest = bool.fromEnvironment('VERIFIA_SKIP_ATTEST', defaultValue: false);
    if (skipAttest) return 'SKIP_ATTEST_DEVICE';

    // Same key used by AppAttestService to store the registered device_id
    final stored = await _storage.read(key: 'verifia_device_id');
    if (stored != null && stored.isNotEmpty) return stored;

    // Fallback: stable per-install ID when App Attest hasn't registered yet
    final fallback = await _storage.read(key: 'fallback_device_id');
    if (fallback != null && fallback.isNotEmpty) return fallback;

    final newId = 'install-${DateTime.now().millisecondsSinceEpoch}';
    await _storage.write(key: 'fallback_device_id', value: newId);
    return newId;
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_step) {
            _Step.form      => _buildForm(cs),
            _Step.scanning  => _buildScanning(),
            _Step.preview   => _buildPreview(cs),
            _Step.confirming => _buildConfirming(),
            _Step.done      => _buildDone(cs),
          },
        ),
      ),
    );
  }

  // ── Form step ─────────────────────────────────────────────────────────────

  Widget _buildForm(ColorScheme cs) {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Icon(Icons.verified_user_rounded, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text('Registro de identidad',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    )),
            const SizedBox(height: 6),
            Text(
              'Para emitir badges de presencia necesitas registrar tu identidad una sola vez. '
              'FaceTec escaneará tu cara y tu identificación oficial.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // ID type selector
            Text('Tipo de identificación',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                _idTypeChip('INE', Icons.credit_card_rounded, cs),
                const SizedBox(width: 12),
                _idTypeChip('PASSPORT', Icons.book_rounded, cs),
              ],
            ),
            const SizedBox(height: 32),

            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: cs.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMsg!,
                        style: TextStyle(color: cs.onErrorContainer)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startIDMatch,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Escanear ID con FaceTec'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idTypeChip(String type, IconData icon, ColorScheme cs) {
    final selected = _idType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _idType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected ? cs.primary : cs.onSurfaceVariant, size: 28),
            const SizedBox(height: 4),
            Text(
              type == 'INE' ? 'INE / IFE' : 'Pasaporte',
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Scanning step ─────────────────────────────────────────────────────────

  Widget _buildScanning() {
    return const Center(
      key: ValueKey('scanning'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('Iniciando FaceTec...', style: TextStyle(fontSize: 16)),
        SizedBox(height: 8),
        Text('Sigue las instrucciones en pantalla',
            style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  // ── Preview step ──────────────────────────────────────────────────────────

  Widget _buildPreview(ColorScheme cs) {
    final scan = _scanResult!;
    return SingleChildScrollView(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirma tu información',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // Selfie
        if (scan.auditTrailImage.isNotEmpty)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(scan.auditTrailImage),
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Name field — read-only, populated from ML Kit OCR
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(12),
            color: cs.surfaceContainerHighest.withAlpha(80),
          ),
          child: Row(children: [
            Icon(Icons.person_outline, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nombre completo',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                if (_ocrRunning)
                  Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Text('Leyendo ID…', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ])
                else
                  Text(
                    _nameCtrl.text.isNotEmpty ? _nameCtrl.text : '(no detectado)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _nameCtrl.text.isNotEmpty ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
              ]),
            ),
            if (!_ocrRunning)
              Icon(
                _nameCtrl.text.isNotEmpty ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 18,
                color: _nameCtrl.text.isNotEmpty ? Colors.green : cs.error,
              ),
          ]),
        ),
        if (!_ocrRunning && _nameCtrl.text.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'No se detectó el nombre en la foto. Continúa y corrígelo en tu perfil.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 12),
        _infoRow('Tipo de ID', _idType == 'INE' ? 'INE / IFE' : 'Pasaporte'),
        if (scan.curp?.isNotEmpty == true)
          _infoRow('CURP', scan.curp!),
        if (scan.dateOfBirth?.isNotEmpty == true)
          _infoRow('Fecha de nac.', scan.dateOfBirth!),
        if (scan.matchLevel > 0)
          _infoRow('Match FaceTec', '${scan.matchLevel}/100'),

        const SizedBox(height: 8),

        // ID photos
        if (scan.idFrontPhoto.isNotEmpty) ...[
          Text('Frente del ID',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              base64Decode(scan.idFrontPhoto),
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (scan.idBackPhoto?.isNotEmpty == true) ...[
          Text('Reverso del ID',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              base64Decode(scan.idBackPhoto!),
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_errorMsg != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_errorMsg!,
                style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],

        const SizedBox(height: 24),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() {
                _step = _Step.form;
                _scanResult = null;
              }),
              child: const Text('Repetir'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _ocrRunning ? null : _confirmAndRegister,
              child: const Text('Registrarme'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ]),
    );
  }

  // ── Confirming step ───────────────────────────────────────────────────────

  Widget _buildConfirming() {
    return const Center(
      key: ValueKey('confirming'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('Registrando perfil...'),
      ]),
    );
  }

  // ── Done step ─────────────────────────────────────────────────────────────

  Widget _buildDone(ColorScheme cs) {
    return Center(
      key: const ValueKey('done'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_rounded, color: cs.primary, size: 80),
        const SizedBox(height: 16),
        const Text('¡Registro exitoso!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Tu identidad fue verificada.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}
