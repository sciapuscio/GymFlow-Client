import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CheckinResultScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const CheckinResultScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final success = data['success'] as bool? ?? false;
    final message = data['message'] as String? ?? '';
    final creditsRemaining = data['credits_remaining'];
    final gymName = data['gym_name'] as String?;
    final checkedInAt = data['checked_in_at'] as String?;

    final timeStr = checkedInAt != null
        ? DateFormat('HH:mm — dd/MM/yyyy').format(DateTime.parse(checkedInAt))
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),

              // ── Status icon ────────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: success
                      ? const Color(0xFF00F5D4).withOpacity(0.12)
                      : const Color(0xFFEF4444).withOpacity(0.12),
                  border: Border.all(
                    color: success ? const Color(0xFF00F5D4) : const Color(0xFFEF4444),
                    width: 2,
                  ),
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.close_rounded,
                  size: 56,
                  color: success ? const Color(0xFF00F5D4) : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 28),

              // ── Gym name ───────────────────────────────────────────────────
              if (gymName != null)
                Text(
                  gymName,
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 14, letterSpacing: 0.5),
                ),
              const SizedBox(height: 8),

              // ── Main message ───────────────────────────────────────────────
              Text(
                success ? '¡Presente registrado!' : 'Check-in rechazado',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF0F0F0),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),

              if (success) ...[
                const SizedBox(height: 32),

                // ── Credits remaining ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF14141E),
                    border: Border.all(color: const Color(0xFF00F5D4).withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      if (creditsRemaining != null) ...[
                        Text(
                          '$creditsRemaining',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00F5D4),
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'créditos restantes',
                          style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                        ),
                      ] else ...[
                        const Icon(Icons.all_inclusive, size: 40, color: Color(0xFF00F5D4)),
                        const SizedBox(height: 4),
                        const Text(
                          'Plan ilimitado',
                          style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                        ),
                      ],
                      if (timeStr != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          timeStr,
                          style: const TextStyle(color: Color(0xFF555555), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // ── Actions ────────────────────────────────────────────────────
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? const Color(0xFF00F5D4) : const Color(0xFF14141E),
                  foregroundColor: success ? const Color(0xFF080810) : const Color(0xFFF0F0F0),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Ir al inicio', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (!success) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/checkin'),
                  child: const Text('Volver a escanear', style: TextStyle(color: Color(0xFF888888))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
