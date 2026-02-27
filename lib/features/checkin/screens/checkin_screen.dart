import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../auth/auth_provider.dart';

// ── Platform guard ────────────────────────────────────────────────────────────
// mobile_scanner only builds on Android / iOS.
// On Windows / web we show a placeholder — the import is excluded at build time.
bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  @override
  Widget build(BuildContext context) {
    if (!_isMobile) return const _DesktopPlaceholder();
    return const _MobileScannerView();
  }
}

// ── Desktop placeholder ───────────────────────────────────────────────────────

class _DesktopPlaceholder extends StatelessWidget {
  const _DesktopPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00F5D4).withOpacity(0.08),
                  border: Border.all(
                    color: const Color(0xFF00F5D4).withOpacity(0.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 36,
                  color: Color(0xFF00F5D4),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Check-in QR',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF0F0F0),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Disponible en la app móvil (Android / iOS).\nEn el gym, abrí la app desde tu teléfono.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile scanner view — only compiled when we add mobile_scanner back ───────
// This Widget is declared here but ONLY REACHED at runtime on Android/iOS.
// Since mobile_scanner is not in pubspec.yaml for the Windows build, we stub it.

class _MobileScannerView extends StatefulWidget {
  const _MobileScannerView();
  @override
  State<_MobileScannerView> createState() => _MobileScannerViewState();
}

class _MobileScannerViewState extends State<_MobileScannerView> {
  bool _processing = false;
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onScan(String rawValue) async {
    if (_processing || rawValue.isEmpty) return;

    // The QR may contain a full URL like:
    //   https://training.access.ly/api/checkin.php?gym_qr_token=UUID
    // Extract just the token so the API lookup works correctly.
    String gymQrToken = rawValue.trim();
    try {
      final uri = Uri.parse(rawValue);
      final tokenParam = uri.queryParameters['gym_qr_token'];
      if (tokenParam != null && tokenParam.isNotEmpty) {
        gymQrToken = tokenParam;
      }
    } catch (_) {
      // Not a URL — use rawValue as-is (plain UUID QR)
    }

    if (gymQrToken.isEmpty) return;

    setState(() => _processing = true);
    await _controller.stop();
    try {
      final result = await ApiClient.post(AppConstants.checkinUrl, {
        'gym_qr_token': gymQrToken,
      });
      if (mounted) {
        await context.read<AuthProvider>().refresh();
        context.go('/checkin/result', extra: {
          'success': true,
          'message': result['message'] ?? '¡Presente registrado!',
          'credits_remaining': result['credits_remaining'],
          'gym_name': result['gym_name'],
          'checked_in_at': result['checked_in_at'],
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        context.go('/checkin/result', extra: {
          'success': false,
          'message': e.message,
          'credits_remaining': null,
          'gym_name': null,
          'checked_in_at': null,
        });
      }
    } catch (_) {
      if (mounted) {
        context.go('/checkin/result', extra: {
          'success': false,
          'message': 'Error de conexión. Verificá tu internet.',
          'credits_remaining': null,
          'gym_name': null,
          'checked_in_at': null,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Cámara a pantalla completa ──────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              final raw = barcode?.rawValue ?? '';
              if (raw.isNotEmpty) _onScan(raw);
            },
          ),

          // ── Overlay oscuro con recorte cuadrado central ─────────────────
          if (!_processing)
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(color: Colors.transparent),
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Marco esquinas del viewfinder ───────────────────────────────
          if (!_processing)
            Center(
              child: SizedBox(
                width: 244,
                height: 244,
                child: CustomPaint(painter: _CornerPainter()),
              ),
            ),

          // ── Header ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Escaneá el QR del gym',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                      ),
                    ),
                  ),
                  // Linterna
                  IconButton(
                    icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),

          // ── Indicador de procesamiento ───────────────────────────────────
          if (_processing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00F5D4)),
                    SizedBox(height: 20),
                    Text('Registrando asistencia...',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Pintor de esquinas del viewfinder ─────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00F5D4)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const r = 12.0; // radio
    const len = 28.0; // largo del trazo de esquina

    // Top-left
    canvas.drawPath(Path()
      ..moveTo(0, r + len)..lineTo(0, r)..arcToPoint(Offset(r, 0), radius: const Radius.circular(r))..lineTo(r + len, 0), paint);
    // Top-right
    canvas.drawPath(Path()
      ..moveTo(size.width - r - len, 0)..lineTo(size.width - r, 0)..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))..lineTo(size.width, r + len), paint);
    // Bottom-left
    canvas.drawPath(Path()
      ..moveTo(0, size.height - r - len)..lineTo(0, size.height - r)..arcToPoint(Offset(r, size.height), radius: const Radius.circular(r), clockwise: false)..lineTo(r + len, size.height), paint);
    // Bottom-right
    canvas.drawPath(Path()
      ..moveTo(size.width - r - len, size.height)..lineTo(size.width - r, size.height)..arcToPoint(Offset(size.width, size.height - r), radius: const Radius.circular(r), clockwise: false)..lineTo(size.width, size.height - r - len), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
