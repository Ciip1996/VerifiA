import 'dart:async';

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
        enableClassification: false,
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

  void _finish() {
    if (_isFinishing) return;
    _isFinishing = true;
    _cam?.stopImageStream();

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      Navigator.of(context).pop(FaceTecResult(
        sessionId:
            'mlkit-${widget.nonce.substring(0, 16)}-${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        faceScanBase64: 'mlkit-liveness-${widget.nonce.substring(0, 8)}',
      ));
    });
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
    return switch (_stage) {
      _Stage.center       => 'Centra tu cara en el óvalo',
      _Stage.turn         => 'Gira la cabeza a un lado',
      _Stage.returnCenter => 'Regresa al centro',
      _Stage.done         => '¡Verificación completada!',
    };
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
          // Real camera preview (mirrored so user sees themselves naturally)
          if (_cameraReady && _cam != null)
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
              child: CameraPreview(_cam!),
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
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'LIVENESS 3D',
                  style: TextStyle(
                    color: Color(0xFF6C63FF),
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
              key: ValueKey(_fallbackMode ? 'fb' : _stage.name),
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    _isDone ? const Color(0xFF22C55E) : Colors.white,
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
