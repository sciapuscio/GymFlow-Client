import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../../core/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _glow;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    // Breathing: 3s inhale → 3s exhale, loops forever
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.88, end: 1.06).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );

    // Screen fade-in
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // NOTE: AuthProvider.init() is called from main.dart.
    // Failsafe: if init() hangs for any reason, force navigation after 4s.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        context.read<AuthProvider>().forceTimeout();
      }
    });
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final member = auth.member;
    // Prefer local cached file (instant, no network), fallback to URL
    final gymLogoFilePath = auth.gymLogoFilePath;
    final gymLogoPath = auth.gymLogoUrl;
    final gymName = member?.gym?.name ?? 'GymFlow';
    final hasGymLogo = gymLogoFilePath != null || gymLogoPath != null;

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: FadeTransition(
        opacity: _fade,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [Color(0xFF0D1018), Color(0xFF080810)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Breathing logo ────────────────────────────────────────────
              AnimatedBuilder(
                animation: _breathCtrl,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scale.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F5D4)
                                    .withOpacity(_glow.value * 0.3),
                                blurRadius: 60 + (_glow.value * 40),
                                spreadRadius: 10 + (_glow.value * 20),
                              ),
                            ],
                          ),
                        ),
                        // Logo container
                        Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF0D1018), Color(0xFF1a1d27)],
                            ),
                            border: Border.all(
                              color: Color.lerp(
                                const Color(0xFF1E2030),
                                const Color(0xFF00F5D4),
                                _glow.value * 0.45,
                              )!,
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: hasGymLogo
                                ? _GymLogo(
                                    filePath: gymLogoFilePath,
                                    logoUrl: gymLogoPath,
                                  )
                                : _GFLogo(glowAmount: _glow.value),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Name ──────────────────────────────────────────────────────
              Text(
                gymName,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF0F0F0),
                  letterSpacing: 1.5,
                ),
              ),
              if (hasGymLogo) ...[
                const SizedBox(height: 4),
                const Text(
                  'powered by GymFlow',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF444466),
                    letterSpacing: 0.5,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 4),
                const Text(
                  'Tu entrenamiento, en tu mano',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666688),
                    letterSpacing: 0.5,
                  ),
                ),
              ],

              const SizedBox(height: 60),

              // ── Breathing dots ────────────────────────────────────────────
              AnimatedBuilder(
                animation: _breathCtrl,
                builder: (ctx, _) => _BreathingDots(t: _breathCtrl.value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gym logo (file-first, URL fallback) ─────────────────────────────────────
class _GymLogo extends StatelessWidget {
  final String? filePath;
  final String? logoUrl;
  const _GymLogo({this.filePath, this.logoUrl});

  String? get _resolvedUrl {
    if (logoUrl == null) return null;
    return logoUrl!.startsWith('http')
        ? logoUrl!
        : '${AppConstants.baseUrl}/$logoUrl';
  }

  @override
  Widget build(BuildContext context) {
    // Use local file if available — instant, no network needed
    if (filePath != null) {
      final file = File(filePath!);
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _networkFallback(),
        ),
      );
    }
    return _networkFallback();
  }

  Widget _networkFallback() {
    final url = _resolvedUrl;
    if (url == null) return const _GFLogo(glowAmount: 0.5);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _GFLogo(glowAmount: 0.5),
      ),
    );
  }
}

// ── GF fallback logo ──────────────────────────────────────────────────────────
class _GFLogo extends StatelessWidget {
  final double glowAmount;
  const _GFLogo({super.key, required this.glowAmount});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GFLogoPainter(glowAmount: glowAmount),
      size: const Size(148, 148),
    );
  }
}

class _GFLogoPainter extends CustomPainter {
  final double glowAmount;
  const _GFLogoPainter({required this.glowAmount});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0a0b0f), Color(0xFF1a1d27)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // G (lime-green)
    final gColor = Color.lerp(
      const Color(0xFFe5ff3d),
      const Color(0xFF00F5D4),
      glowAmount * 0.4,
    )!;
    _drawLetter(canvas, 'G', w * 0.06, h * 0.06, w * 0.50, gColor);

    // F (white)
    _drawLetter(canvas, 'F', w * 0.52, h * 0.06, w * 0.50,
        Colors.white.withOpacity(0.92));

    // Accent bar
    final accentPaint = Paint()
      ..color = const Color(0xFFe5ff3d)
          .withOpacity(0.55 + glowAmount * 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.83, w * 0.84, h * 0.055),
        const Radius.circular(4),
      ),
      accentPaint,
    );
  }

  void _drawLetter(
      Canvas canvas, String letter, double x, double y, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          fontFamily: 'Arial',
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_GFLogoPainter old) => old.glowAmount != glowAmount;
}

// ── Breathing dots ────────────────────────────────────────────────────────────
class _BreathingDots extends StatelessWidget {
  final double t;
  const _BreathingDots({required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = ((t + (1 - i / 3.0)) % 1.0);
        final pulse = sin(phase * pi);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: 0.7 + pulse * 0.5,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F5D4)
                    .withOpacity(0.2 + pulse * 0.7),
              ),
            ),
          ),
        );
      }),
    );
  }
}
