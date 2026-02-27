import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../core/constants.dart';

/// Shown when the logged-in member has no active membership.
/// Displays the gym logo and an invitation to visit reception.
class NoMembershipScreen extends StatelessWidget {
  const NoMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final member = auth.member;
    final gym = member?.gym;
    final logoPath = auth.gymLogoFilePath != null
        ? auth.gymLogoFilePath
        : (gym?.logoPath != null ? '${AppConstants.baseUrl}/${gym!.logoPath}' : null);
    final gymName = gym?.name ?? 'GymFlow';

    // Gym primary color (falls back to accent teal)
    Color accentColor = GFColors.accent;
    if (gym?.primaryColor != null && gym!.primaryColor!.startsWith('#') && gym.primaryColor!.length == 7) {
      final hex = int.tryParse(gym.primaryColor!.substring(1), radix: 16);
      if (hex != null) accentColor = Color(0xFF000000 | hex);
    }

    return Scaffold(
      backgroundColor: GFColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Gym logo ─────────────────────────────────────────────────
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GFColors.surface,
                    border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.15),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: logoPath != null
                        ? (auth.gymLogoFilePath != null
                            ? Image.asset(auth.gymLogoFilePath!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _gymInitial(gymName, accentColor))
                            : Image.network(logoPath, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _gymInitial(gymName, accentColor)))
                        : _gymInitial(gymName, accentColor),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Gym name ─────────────────────────────────────────────────
                Text(
                  gymName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: GFColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Greeting ─────────────────────────────────────────────────
                Text(
                  '¡Hola, ${member?.name.split(' ').first ?? 'bienvenido'}! 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Card ─────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: GFColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.fitness_center_rounded,
                        size: 38,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tu cuenta está activa pero todavía no tenés una membresía vigente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: GFColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Acercate a recepción para activar tu plan y empezar a reservar clases. 🏋️',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: GFColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Logout ───────────────────────────────────────────────────
                TextButton.icon(
                  onPressed: () => context.read<AuthProvider>().logout(),
                  icon: const Icon(Icons.logout_rounded, size: 16, color: GFColors.textMuted),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: GFColors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gymInitial(String name, Color color) => Container(
        color: GFColors.surface,
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'G',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      );
}
