import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/facetec_service.dart';
import 'liveness_screen.dart';
import 'login_screen.dart';
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
  bool _isCancelled = false;

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
      // Defensive check: a truly completed scan always has a front ID photo
      // and a face scan. If either is missing, treat it as a failed/cancelled
      // scan rather than entering the preview with partial data.
      if (result.idFrontPhoto.isEmpty || result.faceScanBase64.isEmpty) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _errorMsg = l10n.onboardingScanCancelled;
          _step = _Step.form;
          _scanResult = null;
        });
        return;
      }
      setState(() {
        _scanResult = result;
        _step = _Step.preview;
        _ocrRunning = true;
      });
      // Run ML Kit OCR on ID photo as a fallback for when FaceTec's server
      // doesn't return structured OCR data (e.g. the dev server). This
      // heuristic is tuned for the INE layout only — running it against a
      // passport photo page picks up header words like "PASAPORTE" instead
      // of the name, so skip it for non-INE documents.
      final detectedName = _idType == 'INE'
          ? await _extractNameFromPhoto(result.idFrontPhoto)
          : null;
      if (mounted) {
        _nameCtrl.text = result.fullName ?? detectedName ?? '';
        setState(() => _ocrRunning = false);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _scanResult = null;
        _nameCtrl.clear();
        _step = _Step.form;
        // A plain cancel (X button) shouldn't surface as an error banner —
        // only show a message for unexpected failures.
        _errorMsg = e.code == 'ID_MATCH_CANCELLED'
            ? null
            : (e.message ?? l10n.onboardingScanCancelled);
      });
    } catch (e) {
      setState(() {
        _errorMsg = friendlyError(e, context);
        _step = _Step.form;
      });
    }
  }

  Future<void> _startAndroidIDCapture() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _step = _Step.scanning;
      _errorMsg = null;
    });

    try {
      // Step 1: Navigate to LivenessScreen for selfie capture
      final livenessResult = await Navigator.of(context).push<FaceTecResult>(
        MaterialPageRoute(
          builder: (_) => const LivenessScreen(nonce: 'onboarding'),
        ),
      );
      if (!mounted) return;
      if (livenessResult == null) {
        setState(() => _step = _Step.form);
        return;
      }

      // Step 2: Capture ID front photo with rear camera
      String idFrontBase64 = '';
      final cameras = await availableCameras();
      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camCtrl = CameraController(
        rear,
        ResolutionPreset.high,
        enableAudio: false,
      );
      try {
        await camCtrl.initialize();
        if (!mounted) {
          await camCtrl.dispose();
          return;
        }
        final file = await camCtrl.takePicture();
        final bytes = await file.readAsBytes();
        idFrontBase64 = base64Encode(bytes);
      } finally {
        await camCtrl.dispose();
      }

      // Step 3: Synthesize FaceTecIDMatchResult with captured data
      final auditTrail =
          livenessResult.auditTrailImageBase64 ?? livenessResult.faceScanBase64;
      final result = FaceTecIDMatchResult(
        sessionId:
            'android-onboarding-${DateTime.now().millisecondsSinceEpoch}',
        faceScanBase64: livenessResult.faceScanBase64,
        auditTrailImage: auditTrail,
        idFrontPhoto: idFrontBase64,
        matchLevel: 0,
        enrollmentRefId: '',
      );

      if (!mounted) return;
      // Same defensive check as the iOS path: don't enter preview with a
      // partial/failed capture.
      if (result.idFrontPhoto.isEmpty || result.faceScanBase64.isEmpty) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _errorMsg = l10n.onboardingCaptureCancelled;
          _step = _Step.form;
          _scanResult = null;
        });
        return;
      }
      setState(() {
        _scanResult = result;
        _step = _Step.preview;
        _ocrRunning = true;
      });

      // Step 4: ML Kit OCR on the captured ID photo (same as iOS path).
      // INE-tuned heuristic only — skip for passports (see iOS path comment).
      final detectedName = _idType == 'INE'
          ? await _extractNameFromPhoto(result.idFrontPhoto)
          : null;
      if (mounted) {
        _nameCtrl.text = result.fullName ?? detectedName ?? '';
        setState(() => _ocrRunning = false);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _scanResult = null;
        _nameCtrl.clear();
        _errorMsg = e.message ?? l10n.onboardingCaptureCancelled;
        _step = _Step.form;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = friendlyError(e, context);
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
      final fullName = _nameCtrl.text.trim();
      if (fullName.isEmpty) {
        // Register button should already prevent this, but guard anyway.
        setState(() => _step = _Step.preview);
        return;
      }

      // Resolve device_id from App Attest / fallback storage
      final deviceId = await _resolveDeviceId();

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
      if (_step != _Step.confirming) return; // user navigated away
      if (_isCancelled) return;
      setState(() => _step = _Step.done);

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // After registration, let user set up web account password
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SetPasswordScreen(deviceId: deviceId)),
      );
    } catch (e) {
      setState(() {
        _errorMsg = friendlyError(e, context);
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
  ///
  /// Primary strategy: anchor on the "NOMBRE" label (always present, right
  /// above apellido paterno / materno / nombre(s)) and collect up to 3
  /// uppercase lines that follow it. This avoids picking up the card header
  /// ("ESTADOS UNIDOS MEXICANOS", "INSTITUTO NACIONAL ELECTORAL"), which OCR
  /// often garbles into all-caps noise that would otherwise pass a naive
  /// top-down scan (e.g. "UNIDOS ME", "MÉXICO", "XICO").
  ///
  /// Fallback (no NOMBRE anchor found, e.g. a noisy/partial scan): scan from
  /// the top but explicitly filter out known header/label fragments.
  String? _parseINEName(String rawText) {
    if (rawText.isEmpty) return null;
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Stop collecting once we hit these fields (they appear after the name block).
    final stopWords = {'CURP', 'FOLIO', 'VIGENCIA', 'CLAVE', 'SEXO', 'ESTADO', 'DOMICILIO', 'FECHA'};
    final ignoredLabels = {
      'NOMBRE', 'APELLIDO', 'PATERNO', 'MATERNO', 'APELLIDOS',
      'NOMBRE(S)', 'NOMBRES',
    };
    // Substrings of the card header/boilerplate that OCR frequently garbles
    // into all-caps fragments (e.g. "UNIDOS ME", "XICO") which would
    // otherwise slip past the exact-match ignoredLabels check.
    final headerNoise = [
      'ESTADOS', 'UNIDOS', 'MEXICANOS', 'MEXICO', 'MÉXICO',
      'INSTITUTO', 'NACIONAL', 'ELECTORAL', 'CREDENCIAL', 'VOTAR',
    ];
    bool isValidNameLine(String upper) {
      // Must be all-caps alphabetic (with spaces/accents), at least 3 chars
      if (!RegExp(r'^[A-ZÁÉÍÓÚÜÑ\s]{3,}$').hasMatch(upper)) return false;
      if (ignoredLabels.contains(upper.trim())) return false;
      if (headerNoise.any((w) => upper.contains(w))) return false;
      return true;
    }

    // Primary: anchor on the NOMBRE label and take the lines right after it.
    final nombreIndex = lines.indexWhere((l) => l.toUpperCase().trim() == 'NOMBRE');
    if (nombreIndex != -1) {
      final anchored = <String>[];
      for (var i = nombreIndex + 1; i < lines.length && anchored.length < 3; i++) {
        final upper = lines[i].toUpperCase();
        if (stopWords.any((w) => upper.contains(w))) break;
        if (!isValidNameLine(upper)) continue;
        anchored.add(upper.trim());
      }
      if (anchored.isNotEmpty) return anchored.join(' ');
    }

    // Fallback: top-down scan with header-noise filtering.
    final nameParts = <String>[];
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (stopWords.any((w) => upper.contains(w))) break;
      if (!isValidNameLine(upper)) continue;
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
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _step != _Step.confirming,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_step) {
              _Step.form      => _buildForm(cs, l10n),
              _Step.scanning  => _buildScanning(l10n),
              _Step.preview   => _buildPreview(cs, l10n),
              _Step.confirming => _buildConfirming(l10n),
              _Step.done      => _buildDone(cs, l10n),
            },
          ),
        ),
      ),
    );
  }

  // ── Form step ─────────────────────────────────────────────────────────────

  Widget _buildForm(ColorScheme cs, AppLocalizations l10n) {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Image.asset('assets/images/logo_dark.png', height: 36, fit: BoxFit.contain),
            const SizedBox(height: 16),
            Text(l10n.onboardingTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    )),
            const SizedBox(height: 6),
            Text(
              l10n.onboardingSubtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // ID type selector
            Text(l10n.onboardingIdTypeLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                _idTypeChip('INE', Icons.credit_card_rounded, cs, l10n),
                const SizedBox(width: 12),
                _idTypeChip('PASSPORT', Icons.book_rounded, cs, l10n),
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
                onPressed:
                    Platform.isIOS ? _startIDMatch : _startAndroidIDCapture,
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(l10n.onboardingScanButton),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: Text(
                  l10n.onboardingLoginLink,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idTypeChip(String type, IconData icon, ColorScheme cs, AppLocalizations l10n) {
    final selected = _idType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _idType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : cs.outline.withAlpha(80),
              width: 2,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant, size: 28),
            const SizedBox(height: 4),
            Text(
              type == 'INE' ? l10n.idTypeINE : l10n.idTypePassport,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Scanning step ─────────────────────────────────────────────────────────

  Widget _buildScanning(AppLocalizations l10n) {
    return Center(
      key: const ValueKey('scanning'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(l10n.onboardingFacetecStarting, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(l10n.onboardingFacetecInstructions,
            style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }

  // ── Preview step ──────────────────────────────────────────────────────────

  Widget _buildPreview(ColorScheme cs, AppLocalizations l10n) {
    final scan = _scanResult!;
    return SingleChildScrollView(
      key: const ValueKey('preview'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.onboardingPreviewTitle,
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

        // Name field — auto-filled from FaceTec/ML Kit OCR, editable in case
        // the detected name is wrong or missing.
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
                Text(l10n.onboardingNameLabel,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                if (_ocrRunning)
                  Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.onboardingOcrReading, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ])
                else
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: l10n.onboardingNotDetected,
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
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
              l10n.onboardingNameNotDetected,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 12),
        _infoRow(l10n.idTypeLabelShort, _idType == 'INE' ? l10n.idTypeINE : l10n.idTypePassport, cs),
        if (scan.curp?.isNotEmpty == true)
          _infoRow(l10n.curpLabel, scan.curp!, cs),
        if (scan.dateOfBirth?.isNotEmpty == true)
          _infoRow(l10n.onboardingInfoBirthDate, scan.dateOfBirth!, cs),
        if (scan.matchLevel > 0)
          _infoRow(l10n.onboardingInfoFacetecMatch, '${scan.matchLevel}/100', cs),

        const SizedBox(height: 8),

        // ID photos
        if (scan.idFrontPhoto.isNotEmpty) ...[
          Text(l10n.onboardingIdFrontLabel,
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
          Text(l10n.onboardingIdBackLabel,
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
              onPressed: () {
                _isCancelled = true;
                setState(() {
                  _step = _Step.form;
                  _scanResult = null;
                });
              },
              child: Text(l10n.onboardingRepeatButton),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: (_ocrRunning || _nameCtrl.text.trim().isEmpty)
                  ? null
                  : _confirmAndRegister,
              child: Text(l10n.onboardingRegisterButton),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
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

  Widget _buildConfirming(AppLocalizations l10n) {
    return Center(
      key: const ValueKey('confirming'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(l10n.onboardingConfirming),
      ]),
    );
  }

  // ── Done step ─────────────────────────────────────────────────────────────

  Widget _buildDone(ColorScheme cs, AppLocalizations l10n) {
    return Center(
      key: const ValueKey('done'),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_rounded, color: cs.primary, size: 80),
        const SizedBox(height: 16),
        Text(l10n.onboardingSuccess,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.onboardingSuccessSubtitle,
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
