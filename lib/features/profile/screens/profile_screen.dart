import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../../schedule/screens/my_reservations_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFF0F0F0))),
        content: const Text(
          '¿Seguro que querés cerrar sesión?',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<AuthProvider>().member;
    final ms = member?.membership;

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header gradient ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1F1C), Color(0xFF080810)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF00F5D4), Color(0xFF00BFFF)],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          member?.name.isNotEmpty == true ? member!.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF080810),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      member?.name ?? '...',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0F0F0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member?.email ?? '',
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                    ),
                    if (ms?.planName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF00F5D4).withOpacity(0.1),
                          border: Border.all(color: const Color(0xFF00F5D4).withOpacity(0.4)),
                        ),
                        child: Text(
                          ms!.planName!,
                          style: const TextStyle(
                            color: Color(0xFF00F5D4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Membership summary ───────────────────────────────────
                    if (ms != null) ...[
                      const Text(
                        'MI MEMBRESÍA',
                        style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF666666), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      _InfoCard(children: [
                        _InfoRow(icon: Icons.calendar_today_outlined, label: 'Vencimiento', value: DateFormat('dd/MM/yyyy').format(ms.endDate)),
                        _InfoRow(icon: Icons.bolt_outlined, label: 'Créditos restantes', value: ms.sessionsLimit != null ? '${ms.creditsRemaining} / ${ms.sessionsLimit}' : 'Ilimitados'),
                        _InfoRow(icon: Icons.check_circle_outline, label: 'Clases realizadas', value: '${ms.sessionsUsed}'),
                      ]),
                      const SizedBox(height: 24),
                    ],

                    // ── Mis Reservas shortcut ─────────────────────────────────
                    const Text(
                      'MIS RESERVAS',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF666666), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF14141E),
                          border: Border.all(color: const Color(0x1EFFFFFF)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF00F5D4)),
                            SizedBox(width: 12),
                            Text('Ver mis reservas', style: TextStyle(color: Color(0xFFF0F0F0), fontSize: 14)),
                            Spacer(),
                            Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF555566)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Personal data ─────────────────────────────────────────
                    const Text(
                      'MIS DATOS',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Color(0xFF666666), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    _InfoCard(children: [
                      _InfoRow(icon: Icons.person_outline, label: 'Nombre', value: member?.name ?? ''),
                      _InfoRow(icon: Icons.email_outlined, label: 'Email', value: member?.email ?? ''),
                      if (member?.phone != null)
                        _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: member!.phone!),
                    ]),
                    const SizedBox(height: 32),

                    // ── Logout ────────────────────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.4)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (_, snap) {
                          final v = snap.data?.version ?? '...';
                          return Text(
                            'GymFlow v$v',
                            style: const TextStyle(
                                color: Color(0xFF333333), fontSize: 12),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFF14141E),
      border: Border.all(color: const Color(0x1EFFFFFF)),
    ),
    child: Column(
      children: children.indexed.map((entry) {
        final (i, child) = entry;
        return Column(
          children: [
            child,
            if (i < children.length - 1)
              const Divider(height: 1, color: Color(0x1EFFFFFF), indent: 48),
          ],
        );
      }).toList(),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00F5D4)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Color(0xFFF0F0F0), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
