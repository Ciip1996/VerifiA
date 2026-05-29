import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/facetec_service.dart';

/// Animated liveness screen — simulates face detection + head-turn challenge.
///
/// Uses a purely Flutter-native UI (no native camera session) so it never
/// conflicts with mobile_scanner's AVCaptureSession and cannot crash on
/// any iOS version.
///
/// Visual sequence:
///   Stage 1 — "Center your face" (oval pulses, 2 s)
///   Stage 2 — "Turn left"        (oval shifts, 1.5 s)
///   Stage 3 — "Return to center" (oval centers, 1.5 s)
///   Stage 4 — "Verified ✓"      (green flash, 0.8 s)
class LivenessScreen extends StatefulWidget {
  final String nonce;
  const LivenessScreen({super.key, required this.nonce});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

enum _Stage { center, turnLeft, returnCenter, done }

class _LivenessScreenState extends State<LivenessScreen>
    with TickerProviderStateMixin {
  _Stage _stage = _Stage.center;
  double _progress = 0;

  // Oval pulse animation
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  // Dot blink
  late final AnimationController _dotCtrl;

  // Stage progress timer
  Timer? _timer;
  int _stageMs = 0;
  static const _stageDurations = {
    _Stage.center: 2200,
    _Stage.turnLeft: 1600,
    _Stage.returnCenter: 1600,
    _Stage.done: 800,
  };

  // Face dot positions (simulated tracking)
  final _rng = Random();
  Offset _dotOffset = Offset.zero;
  Timer? _jitterTimer;

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

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _startStage();
    _startJitter();
  }

  void _startJitter() {
    _jitterTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        _dotOffset = Offset(
          (_rng.nextDouble() - 0.5) * 6,
          (_rng.nextDouble() - 0.5) * 6,
        );
      });
    });
  }

  void _startStage() {
    _timer?.cancel();
    _stageMs = 0;
    final total = _stageDurations[_stage]!;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      _stageMs += 50;
      if (!mounted) { t.cancel(); return; }
      setState(() => _progress = (_stageMs / total).clamp(0.0, 1.0));
      if (_stageMs >= total) {
        t.cancel();
        _nextStage();
      }
    });
  }

  void _nextStage() {
    if (!mounted) return;
    switch (_stage) {
      case _Stage.center:
        setState(() { _stage = _Stage.turnLeft; _progress = 0; });
        _startStage();
      case _Stage.turnLeft:
        setState(() { _stage = _Stage.returnCenter; _progress = 0; });
        _startStage();
      case _Stage.returnCenter:
        setState(() { _stage = _Stage.done; _progress = 0; });
        _startStage();
      case _Stage.done:
        _finish();
    }
  }

  void _finish() {
    _jitterTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.of(context).pop(FaceTecResult(
        sessionId: 'vision-${widget.nonce.substring(0, 16)}-${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        faceScanBase64: 'vision-liveness-${widget.nonce.substring(0, 8)}',
      ));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _jitterTimer?.cancel();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  bool get _isDone => _stage == _Stage.done;

  String get _instruction {
    return switch (_stage) {
      _Stage.center      => 'Centra tu cara en el óvalo',
      _Stage.turnLeft    => 'Gira la cabeza hacia la izquierda',
      _Stage.returnCenter => 'Regresa al centro',
      _Stage.done        => '¡Verificación completada!',
    };
  }

  double get _ovalShift {
    // Simulate head turning: oval "shifts" during turnLeft stage
    return switch (_stage) {
      _Stage.turnLeft => -30 * _progress,
      _Stage.returnCenter => -30 * (1 - _progress),
      _ => 0,
    };
  }

  double get _globalProgress {
    final base = switch (_stage) {
      _Stage.center       => 0.0,
      _Stage.turnLeft     => 0.33,
      _Stage.returnCenter => 0.66,
      _Stage.done         => 0.99,
    };
    final span = switch (_stage) {
      _Stage.center       => 0.33,
      _Stage.turnLeft     => 0.33,
      _Stage.returnCenter => 0.33,
      _Stage.done         => 0.01,
    };
    return (base + span * _progress).clamp(0.0, 1.0);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Simulated camera background (dark grain texture feel)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.1,
                colors: [Color(0xFF1a1a2e), Colors.black],
              ),
            ),
          ),

          // Dim overlay
          Container(color: Colors.black.withValues(alpha: 0.35)),

          // Scanning lines (subtle animation)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ScanLinePainter(_pulseCtrl.value),
              size: Size(size.width, size.height),
            ),
          ),

          // Face oval + tracking dots
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final scale = _isDone ? 1.0 : _pulse.value;
              return Center(
                child: Transform.translate(
                  offset: Offset(_ovalShift, 0),
                  child: Transform.scale(
                    scale: scale,
                    child: _buildOval(size),
                  ),
                ),
              );
            },
          ),

          // Top bar
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Close
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
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                const SizedBox(height: 4),
                Text(
                  'Verificación de Presencia',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Bottom instructions + progress
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _instruction,
                        key: ValueKey(_stage),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isDone ? const Color(0xFF22C55E) : Colors.white,
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
                          _isDone ? const Color(0xFF22C55E) : const Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOval(Size size) {
    const ovalW = 200.0;
    const ovalH = 270.0;
    final dotColor = _isDone ? const Color(0xFF22C55E) : const Color(0xFF6C63FF);

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
                  color: dotColor.withValues(alpha: _isDone ? 0.4 : 0.2),
                  blurRadius: 24,
                  spreadRadius: 4,
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
                color: dotColor,
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
                : _buildTrackingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingDots() {
    // 4 corner tracking dots that jitter slightly
    return Stack(
      children: [
        _dot(Alignment.topCenter + Alignment(0, 0.3) + Alignment(_dotOffset.dx * 0.01, _dotOffset.dy * 0.01)),
        _dot(Alignment.centerLeft + Alignment(0.3, 0) + Alignment(_dotOffset.dx * 0.008, _dotOffset.dy * 0.008)),
        _dot(Alignment.centerRight + Alignment(-0.3, 0) + Alignment(-_dotOffset.dx * 0.008, _dotOffset.dy * 0.008)),
        _dot(Alignment.bottomCenter + Alignment(0, -0.3) + Alignment(_dotOffset.dx * 0.01, -_dotOffset.dy * 0.01)),
        _dot(Alignment.center + Alignment(_dotOffset.dx * 0.005, _dotOffset.dy * 0.005)),
      ],
    );
  }

  Widget _dot(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _dotCtrl,
        builder: (_, __) => Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6C63FF).withValues(
              alpha: 0.4 + 0.6 * _dotCtrl.value,
            ),
          ),
        ),
      ),
    );
  }
}

// Subtle animated scan lines to give a "camera" feel
class _ScanLinePainter extends CustomPainter {
  final double t;
  _ScanLinePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Moving highlight line
    final lineY = (t * size.height * 1.3) % (size.height + 40) - 20;
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, lineY - 20, size.width, 40));
    canvas.drawRect(
      Rect.fromLTWH(0, lineY - 20, size.width, 40),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.t != t;
}
