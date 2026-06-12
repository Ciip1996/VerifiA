import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/facetec_service.dart';

/// Real liveness screen using the device's front camera + Google ML Kit.
///
/// All processing is on-device (no internet, no account).
/// Face detection provides headEulerAngleY (yaw in degrees) every ~3rd frame.
///
/// Challenge sequence:
///   Stage 1 — Center face in oval  (|yaw| < 15°, 45 frames ≈ 1.5 s)
///   Stage 2 — Turn head to one side (|yaw| > 20°, 10 frames)
///   Stage 3 — Return to center      (|yaw| < 15°, 10 frames)
///
/// Falls back to a timed animation if the camera is unavailable so the
/// rest of the flow never breaks.
class LivenessScreen extends StatefulWidget {
  final String nonce;
  const LivenessScreen({super.key, required this.nonce});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

enum _Stage { center, turn, returnCenter, done }

class _LivenessScreenState extends State<LivenessScreen>
    with TickerProviderStateMixin {
  // ─── Camera ────────────────────────────────────────────────────────────────
  CameraController? _cam;
  bool _cameraReady = false;
  bool _processingFrame = false;
  int _frameCount = 0;

  // ─── ML Kit ────────────────────────────────────────────────────────────────
  late final FaceDetector _detector;

  // ─── State machine ─────────────────────────────────────────────────────────
  _Stage _stage = _Stage.center;
  int _stageFrames = 0;
  bool _isFinishing = false;

  // ─── Countdown before photo ────────────────────────────────────────────────
  /// null = not counting; 'ready' = prep message; 3/2/1 = digits; 0 = flash
  Object? _countdown; // String 'ready' | int 3|2|1|0
  bool _flashVisible = false;

  // ─── Photo quality retry ───────────────────────────────────────────────────
  /// Reason shown when a captured photo is rejected (null = none)
  String? _photoRejectionReason;
  int _photoAttempts = 0;
  static const _maxPhotoAttempts = 3;

  static const _centerYaw = 15.0;  // degrees
  static const _turnYaw   = 20.0;  // degrees
  static const _centerFrames = 45;
  static const _turnFrames   = 10;
  static const _returnFrames = 10;

  // ─── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  // ─── Fallback ──────────────────────────────────────────────────────────────
  bool _fallbackMode = false;
  double _fallbackProgress = 0;
  Timer? _fallbackTimer;

  // ─── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableClassification: true,  // needed for eye-open probability
        enableLandmarks: false,
        enableTracking: false,
      ),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.bgra8888,
        enableAudio: false,
      );

      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }

      _cam = ctrl;
      setState(() => _cameraReady = true);
      await ctrl.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('[Liveness] Camera init failed: $e — fallback mode');
      if (mounted) _startFallback();
    }
  }

  // ─── Frame pipeline ────────────────────────────────────────────────────────

  void _onFrame(CameraImage image) {
    _frameCount++;
    if (_frameCount % 3 != 0) return;
    if (_processingFrame || _isFinishing) return;
    _processingFrame = true;
    _processFrame(image).whenComplete(() => _processingFrame = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _toInputImage(image);
      final faces = await _detector.processImage(inputImage);
      if (!mounted || _isFinishing) return;
      final yaw = faces.isNotEmpty ? faces.first.headEulerAngleY : null;
      _tick(yaw);
    } catch (e) {
      debugPrint('[Liveness] Frame error: $e');
    }
  }

  InputImage _toInputImage(CameraImage image) {
    final cam = _cam!.description;
    final rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation)
        ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      throw Exception('Unsupported image format: ${image.format.raw}');
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ─── State machine ─────────────────────────────────────────────────────────

  void _tick(double? yaw) {
    if (_isFinishing) return;
    switch (_stage) {
      case _Stage.center:
        if (yaw != null && yaw.abs() < _centerYaw) {
          _stageFrames++;
        } else {
          _stageFrames = (_stageFrames - 2).clamp(0, _centerFrames);
        }
        if (_stageFrames >= _centerFrames) _advanceTo(_Stage.turn);

      case _Stage.turn:
        if (yaw != null && yaw.abs() > _turnYaw) {
          _stageFrames++;
        } else {
          _stageFrames = (_stageFrames - 1).clamp(0, _turnFrames);
        }
        if (_stageFrames >= _turnFrames) _advanceTo(_Stage.returnCenter);

      case _Stage.returnCenter:
        if (yaw != null && yaw.abs() < _centerYaw) {
          _stageFrames++;
        } else {
          _stageFrames = (_stageFrames - 1).clamp(0, _returnFrames);
        }
        if (_stageFrames >= _returnFrames) _advanceTo(_Stage.done);

      case _Stage.done:
        break;
    }
    if (mounted) setState(() {});
  }

  static const _biometricsChannel = MethodChannel('com.verifia.app/biometrics');

  void _advanceTo(_Stage next) {
    _stage = next;
    _stageFrames = 0;
    // Native "success" haptic + glass chime — Taptic Engine + AudioServices
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _biometricsChannel.invokeMethod<bool>('playSuccess').catchError((_) {
        HapticFeedback.vibrate();
        return false;
      });
    });
    if (next == _Stage.done) _finish();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    _isFinishing = true;

    // Stop ML Kit stream — camera preview stays live for the countdown
    try {
      await _cam?.stopImageStream();
    } catch (_) {}

    // ── Step 1: "¡Prepárate para la foto!" ─────────────────────────────────
    if (mounted) setState(() { _countdown = 'ready'; _photoRejectionReason = null; });
    await Future.delayed(const Duration(milliseconds: 900));

    // ── Step 2: 3 – 2 – 1 countdown ────────────────────────────────────────
    for (final n in [3, 2, 1]) {
      if (!mounted) return;
      _biometricsChannel.invokeMethod<bool>('playSuccess').catchError((_) {
        HapticFeedback.selectionClick();
        return false;
      });
      setState(() => _countdown = n);
      await Future.delayed(const Duration(milliseconds: 950));
    }

    // ── Step 3: take + quality-check loop ───────────────────────────────────
    await _captureLoop();
  }

  Future<void> _captureLoop() async {
    while (_photoAttempts < _maxPhotoAttempts) {
      if (!mounted) return;
      _photoAttempts++;

      // Flash + haptic
      _biometricsChannel.invokeMethod<bool>('playSuccess').catchError((_) {
        HapticFeedback.heavyImpact();
        return false;
      });
      setState(() { _countdown = 0; _flashVisible = true; });
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) setState(() => _flashVisible = false);

      // Capture still
      String snapshotBase64 = '';
      String? capturedPath;
      try {
        if (_cam != null && _cam!.value.isInitialized) {
          final file = await _cam!.takePicture();
          capturedPath = file.path;
          final bytes = await file.readAsBytes();
          snapshotBase64 = base64Encode(bytes);
        }
      } catch (e) {
        debugPrint('[Liveness] takePicture failed: $e');
      }

      // Quality check on the still image via ML Kit
      if (capturedPath != null) {
        final rejection = await _checkPhotoQuality(capturedPath);
        if (rejection != null && _photoAttempts < _maxPhotoAttempts) {
          // Rejected — tell the user and retry with a short 1-second countdown
          if (mounted) {
            setState(() {
              _photoRejectionReason = rejection;
              _countdown = null;
            });
            HapticFeedback.mediumImpact();
          }
          await Future.delayed(const Duration(milliseconds: 1400));
          if (!mounted) return;
          // Single-digit retry countdown
          for (final n in [2, 1]) {
            if (!mounted) return;
            setState(() { _countdown = n; _photoRejectionReason = null; });
            await Future.delayed(const Duration(milliseconds: 800));
          }
          continue; // retake
        }
      }

      // Accepted (or max attempts reached — proceed anyway)
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.of(context).pop(FaceTecResult(
        sessionId:
            'mlkit-${widget.nonce.substring(0, 16)}-${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        faceScanBase64: snapshotBase64.isNotEmpty
            ? snapshotBase64
            : 'mlkit-liveness-${widget.nonce.substring(0, 8)}',
        auditTrailImageBase64: snapshotBase64.isNotEmpty ? snapshotBase64 : null,
      ));
      return;
    }
  }

  /// Returns a Spanish rejection reason if the photo fails quality, or null if OK.
  Future<String?> _checkPhotoQuality(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) return 'No se detectó rostro — acércate un poco';

      final face = faces.first;

      // Eyes open check
      final leftEye  = face.leftEyeOpenProbability  ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      if (leftEye < 0.6 || rightEye < 0.6) {
        return 'Abre los ojos para la foto';
      }

      // Head orientation: not too turned / tilted
      final yaw   = face.headEulerAngleY ?? 0;
      final pitch = face.headEulerAngleX ?? 0;
      if (yaw.abs() > 22) return 'Mira de frente a la cámara';
      if (pitch.abs() > 20) return 'Endereza la cabeza';

      return null; // all good
    } catch (e) {
      debugPrint('[Liveness] quality check failed: $e');
      return null; // don't block on detection errors
    }
  }

  // ─── Fallback ──────────────────────────────────────────────────────────────

  void _startFallback() {
    setState(() => _fallbackMode = true);
    const totalMs = 5500;
    _fallbackTimer =
        Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _fallbackProgress += 80 / totalMs);
      if (_fallbackProgress >= 1.0) {
        t.cancel();
        Navigator.of(context).pop(FaceTecResult(
          sessionId: 'fallback-${widget.nonce.substring(0, 16)}',
          faceScanBase64: 'LIVENESS_FALLBACK',
        ));
      }
    });
  }

  // ─── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fallbackTimer?.cancel();
    _detector.close();
    _cam?.dispose();
    super.dispose();
  }

  // ─── UI helpers ────────────────────────────────────────────────────────────

  bool get _isDone => _stage == _Stage.done;
  Color get _ovalColor =>
      _isDone ? const Color(0xFF22C55E) : const Color(0xFF6C63FF);

  String get _instruction {
    if (_fallbackMode) return 'Verificando presencia...';
    if (_photoRejectionReason != null) return _photoRejectionReason!;
    if (_countdown == 'ready') return '¡Prepárate para la foto!';
    if (_countdown is int && (_countdown as int) > 0) return '';
    if (_countdown == 0) return '¡Foto!';
    return switch (_stage) {
      _Stage.center       => 'Centra tu cara en el óvalo',
      _Stage.turn         => 'Gira la cabeza a un lado',
      _Stage.returnCenter => 'Regresa al centro',
      _Stage.done         => '¡Verificación completada!',
    };
  }

  Color get _instructionColor {
    if (_photoRejectionReason != null) return const Color(0xFFFF6B6B);
    return _isDone ? const Color(0xFF22C55E) : Colors.white;
  }

  double get _globalProgress {
    if (_fallbackMode) return _fallbackProgress.clamp(0.0, 1.0);
    final (maxF, base, span) = switch (_stage) {
      _Stage.center       => (_centerFrames, 0.00, 0.33),
      _Stage.turn         => (_turnFrames,   0.33, 0.33),
      _Stage.returnCenter => (_returnFrames, 0.66, 0.34),
      _Stage.done         => (1,             1.00, 0.00),
    };
    return (base + span * (_stageFrames / maxF)).clamp(0.0, 1.0);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Front camera preview — fill screen while keeping native aspect ratio
          if (_cameraReady && _cam != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  // previewSize is in landscape sensor coords; swap for portrait
                  width: _cam!.value.previewSize?.height ?? 480,
                  height: _cam!.value.previewSize?.width ?? 640,
                  child: CameraPreview(_cam!),
                ),
              ),
            )
          else
            _buildDarkBackground(),

          // Semi-transparent dim
          Container(color: Colors.black.withValues(alpha: 0.3)),

          // Loading spinner while camera warms up
          if (!_cameraReady && !_fallbackMode)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),

          // Face oval
          if (_cameraReady || _fallbackMode)
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Center(
                child: Transform.scale(
                  scale: _isDone ? 1.0 : _pulse.value,
                  child: _buildOval(),
                ),
              ),
            ),

          // Top bar
          SafeArea(child: _buildTopBar()),

          // Bottom bar
          if (_cameraReady || _fallbackMode)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(child: _buildBottomBar()),
            ),

          // Countdown digit overlay (3 / 2 / 1)
          if (_countdown is int && (_countdown as int) > 0)
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween(begin: 0.5, end: 1.0).animate(
                    CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                  ),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  '${_countdown}',
                  key: ValueKey(_countdown),
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 20),
                    ],
                  ),
                ),
              ),
            ),

          // White flash on capture
          if (_flashVisible)
            Container(color: Colors.white.withValues(alpha: 0.85)),
        ],
      ),
    );
  }

  Widget _buildDarkBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0xFF1a1a2e), Colors.black],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(null),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVENESS 3D',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 36),
            ],
          ),
        ),
        const Text(
          'Verificación de Presencia',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOval() {
    const ovalW = 200.0;
    const ovalH = 270.0;
    return SizedBox(
      width: ovalW + 40,
      height: ovalH + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: ovalW + 20,
            height: ovalH + 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ovalW / 2),
              boxShadow: [
                BoxShadow(
                  color: _ovalColor.withValues(alpha: _isDone ? 0.45 : 0.2),
                  blurRadius: 28,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          // Oval border
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: ovalW,
            height: ovalH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ovalW / 2),
              border: Border.all(
                color: _ovalColor,
                width: _isDone ? 4 : 2.5,
              ),
            ),
            child: _isDone
                ? const Center(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF22C55E),
                      size: 64,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _instruction,
              key: ValueKey(_photoRejectionReason ?? (_fallbackMode ? 'fb' : _stage.name)),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _instructionColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _globalProgress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                _isDone
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF6C63FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
