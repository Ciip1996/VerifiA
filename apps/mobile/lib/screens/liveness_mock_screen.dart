import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/facetec_service.dart';

/// Liveness verification mock screen.
///
/// Shows the front camera with an oval face guide, animated instructions,
/// and a progress bar. After ~3.5 seconds completes and returns a FaceTecResult.
///
/// This is the demo-mode implementation. In Semana 2 this is replaced by
/// the real FaceTec Flutter SDK (XCFramework + Dart wrapper), which runs
/// on-device 3D liveness and returns an encrypted FaceScan blob.
class LivenessMockScreen extends StatefulWidget {
  final String nonce;

  const LivenessMockScreen({super.key, required this.nonce});

  @override
  State<LivenessMockScreen> createState() => _LivenessMockScreenState();
}

class _LivenessMockScreenState extends State<LivenessMockScreen>
    with TickerProviderStateMixin {
  late final MobileScannerController _camera;
  late final AnimationController _progressController;
  late final AnimationController _pulseController;

  int _instructionIndex = 0;
  bool _completed = false;

  static const _instructions = [
    'Mantén el teléfono frente a tu cara',
    'Gira lentamente hacia la derecha',
    'Regresa al centro',
    'Gira lentamente hacia la izquierda',
    'Mira directamente a la cámara',
  ];

  static const _totalDurationMs = 3500;

  @override
  void initState() {
    super.initState();

    _camera = MobileScannerController(
      facing: CameraFacing.front,
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoStart: false,
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    )
      ..addListener(_onProgress)
      ..addStatusListener(_onProgressStatus);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Start camera first, then begin the progress bar
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _camera.start();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _progressController.forward();
    });
  }

  void _onProgress() {
    final newIndex =
        (_progressController.value * _instructions.length).floor().clamp(
              0,
              _instructions.length - 1,
            );
    if (newIndex != _instructionIndex && mounted) {
      setState(() => _instructionIndex = newIndex);
    }
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_completed && mounted) {
      setState(() => _completed = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop(
            FaceTecResult(
              sessionId: 'stub-session-${widget.nonce.substring(0, 16)}',
              faceScanBase64: 'STUB_FACE_SCAN_BASE64',
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _camera.dispose();
    _progressController
      ..removeListener(_onProgress)
      ..removeStatusListener(_onProgressStatus)
      ..dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Front camera live preview (autoStart disabled — started manually after 200ms)
          MobileScanner(
            controller: _camera,
            fit: BoxFit.cover,
            onDetect: (_) {}, // required but ignored — not scanning
          ),

          // Dark overlay for readability
          Container(color: Colors.black.withValues(alpha: 0.5)),

          // Top title
          Positioned(
            top: 64,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Verificación de Presencia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Text(
                    'LIVENESS 3D',
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Face oval guide with pulse animation
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final pulse =
                    _completed ? 1.0 : 0.97 + 0.03 * _pulseController.value;
                return Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 210,
                    height: 270,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(120),
                      border: Border.all(
                        color: _completed
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF6C63FF),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_completed
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF6C63FF))
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _completed
                        ? const Center(
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFF22C55E),
                              size: 72,
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Corner bracket decorators (top-left and bottom-right)
          ..._buildCornerBrackets(),

          // Instruction text
          Positioned(
            bottom: 140,
            left: 32,
            right: 32,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                _completed
                    ? '¡Verificación completada!'
                    : _instructions[_instructionIndex],
                key: ValueKey(_completed ? 'done' : _instructionIndex),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _completed ? const Color(0xFF22C55E) : Colors.white,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight:
                      _completed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),

          // Progress bar
          Positioned(
            bottom: 80,
            left: 48,
            right: 48,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) => Column(
                children: [
                  LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _completed
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF6C63FF),
                    ),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _completed
                        ? 'Completado'
                        : '${(_progressController.value * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBrackets() {
    const color = Color(0xFF6C63FF);
    const size = 24.0;
    const thick = 3.0;
    const offset = 60.0;

    Widget bracket({
      required double? top,
      required double? bottom,
      required double? left,
      required double? right,
      required BorderRadius radius,
    }) =>
        Positioned(
          top: top,
          bottom: bottom,
          left: left,
          right: right,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: (top != null && left != null) || (top != null && right != null)
                    ? const BorderSide(color: color, width: thick)
                    : BorderSide.none,
                bottom: (bottom != null && left != null) || (bottom != null && right != null)
                    ? const BorderSide(color: color, width: thick)
                    : BorderSide.none,
                left: (top != null && left != null) || (bottom != null && left != null)
                    ? const BorderSide(color: color, width: thick)
                    : BorderSide.none,
                right: (top != null && right != null) || (bottom != null && right != null)
                    ? const BorderSide(color: color, width: thick)
                    : BorderSide.none,
              ),
              borderRadius: radius,
            ),
          ),
        );

    return [
      bracket(top: offset, left: offset, bottom: null, right: null,
          radius: const BorderRadius.only(topLeft: Radius.circular(4))),
      bracket(top: offset, right: offset, bottom: null, left: null,
          radius: const BorderRadius.only(topRight: Radius.circular(4))),
      bracket(bottom: offset, left: offset, top: null, right: null,
          radius: const BorderRadius.only(bottomLeft: Radius.circular(4))),
      bracket(bottom: offset, right: offset, top: null, left: null,
          radius: const BorderRadius.only(bottomRight: Radius.circular(4))),
    ];
  }
}
